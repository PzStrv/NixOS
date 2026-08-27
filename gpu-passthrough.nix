# gpu-passthrough.nix
#
# Single-GPU VFIO passthrough module for NixOS.
#   Host:  AMD CPU, AMD RX 9060 XT GPU, KDE Plasma / SDDM.
#   Guest: AMD RX 9060 XT passed through to a VM via virt-manager.
#
# NOTE: this file does NOT configure hardware.graphics / videoDrivers --
# those belong in your existing configuration.nix. This file
# only adds IOMMU/VFIO/libvirt bits on top of whatever driver setup you
# already have.
#
# HOW TO USE:
#   1. Save this file as /etc/nixos/gpu-passthrough.nix
#   2. In configuration.nix add to `imports = [ ... ./gpu-passthrough.nix ];`
#   3. sudo nixos-rebuild switch && reboot
#
# PCI addresses were confirmed with lspci on this machine:
#   0b:00.0  RX 9060 XT VGA      [1002:7590]
#   0b:00.1  Navi 48 HDMI Audio  [1002:ab40]

{ lib, pkgs, ... }:

let
  gpuAddrVga   = "0000:0b:00.0";  # RX 9060 XT VGA [1002:7590]
  gpuAddrAudio = "0000:0b:00.1";  # Navi 48 HDMI/DP Audio [1002:ab40]

  username = "maj";

  # Name you will give the VM in virt-manager. Must match exactly --
  # the hook script only runs for a VM with this name.
  vmName = "win11";
in
{
  # =====================================================================
  # IOMMU / kernel boot params
  # =====================================================================
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    # amdgpu.reset_method=4 can help ensure a clean GPU reset between
    # host/guest handoffs on newer RDNA cards. Try without first;
    # add if you see hangs or a black screen on VM shutdown.
    # "amdgpu.reset_method=4"
  ];

  # vfio_virqfd merged into vfio core in kernel 6.2; not listed to avoid
  # a "module not found" warning. vfio_iommu_type1 is harmless to list
  # explicitly even if built-in.
  boot.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];

  # Do NOT blacklist amdgpu -- the host uses it normally.
  # vfio-pci takes over only during VM runtime via the hook script.

  boot.extraModprobeConfig = ''
    # Prevents Windows guests (esp. Win 11) BSODing on AMD hosts when
    # Windows probes MSRs that KVM doesn't emulate.
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';

  # =====================================================================
  # Virtualisation stack
  # =====================================================================
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true; # TPM 2.0 emulation -- required for Windows 11
      # No `ovmf` block needed: nixpkgs bundles OVMF firmware with qemu.
      # Pick the UEFI/secboot firmware in virt-manager's VM creation wizard.
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win           # VirtIO drivers ISO for Windows guest
    psmisc               # fuser -- used by the GPU hook
    looking-glass-client # optional: mirror guest framebuffer into a host
                         # window instead of losing display entirely
  ];

  # =====================================================================
  # Dynamic GPU bind/unbind hook
  #
  # KDE uses SDDM as its display manager, running as a systemd service.
  # The sequence is:
  #   prepare/begin  -> stop SDDM (takes KDE/Plasma down with it)
  #                  -> kill any remaining GPU users
  #                  -> unbind fbcon, unload amdgpu, hand device to vfio
  #   release/end    -> reattach device, reload amdgpu, rebind fbcon
  #                  -> restart SDDM (brings KDE back up)
  # =====================================================================
  environment.etc."libvirt/hooks/qemu" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env bash
      set -x
      exec >> /var/log/gpu-passthrough-hook.log 2>&1
      echo "=== $(date -Is) hook called: $* ==="

      VM_NAME="$1"
      OPERATION="$2"
      SUB_OPERATION="$3"

      TARGET_VM="${vmName}"
      USERNAME="${username}"
      DEV_VGA="${gpuAddrVga}"
      DEV_AUDIO="${gpuAddrAudio}"

      if [ "$VM_NAME" != "$TARGET_VM" ]; then
        exit 0
      fi

      pci_slot_name() {
        # 0000:0b:00.0 -> pci_0000_0b_00_0
        echo "pci_$(echo "$1" | sed 's/[:.]/_/g')"
      }

      kill_gpu_users() {
        # After SDDM stops, stray processes (e.g. anything that was
        # already running before KDE launched, or crash-survivors) may
        # still hold DRI device nodes open. Kill them so amdgpu can unload.
        local drm_dir="/sys/bus/pci/devices/${gpuAddrVga}/drm"
        if [ -d "$drm_dir" ]; then
          for devnode in $(ls "$drm_dir" 2>/dev/null | grep -E '^(card|renderD)'); do
            ${pkgs.psmisc}/bin/fuser -k -TERM "/dev/dri/$devnode" 2>/dev/null || true
          done
          sleep 1
          for devnode in $(ls "$drm_dir" 2>/dev/null | grep -E '^(card|renderD)'); do
            ${pkgs.psmisc}/bin/fuser -k -KILL "/dev/dri/$devnode" 2>/dev/null || true
          done
        fi
      }

      unbind_fb_vtconsoles() {
        # fbcon may stay attached to amdgpu's framebuffer even after the
        # display manager exits. Unbind before touching the driver or
        # modprobe -r amdgpu will fail.
        for vtcon in /sys/class/vtconsole/vtcon*; do
          [ -e "$vtcon/name" ] || continue
          if grep -qi "frame buffer" "$vtcon/name"; then
            echo 0 > "$vtcon/bind" || true
          fi
        done
      }

      rebind_fb_vtconsoles() {
        for vtcon in /sys/class/vtconsole/vtcon*; do
          [ -e "$vtcon/name" ] || continue
          if grep -qi "frame buffer" "$vtcon/name"; then
            echo 1 > "$vtcon/bind" || true
          fi
        done
      }

      unload_amdgpu_stack() {
        # modprobe -r resolves the full dependency tree automatically --
        # no need to enumerate drm_ttm_helper, gpu_sched, etc. by hand
        # (those names shift across kernel versions).
        # drm core is intentionally left loaded; vfio-pci only needs
        # amdgpu gone from the PCI device, not drm itself.
        for i in $(seq 1 10); do
          if ! lsmod | grep -q "^amdgpu "; then
            break
          fi
          modprobe -r amdgpu && break
          sleep 0.5
        done
        if lsmod | grep -q "^amdgpu "; then
          echo "ERROR: amdgpu still loaded after retries, aborting" >&2
          exit 1
        fi
      }

      case "$OPERATION" in
        prepare)
          if [ "$SUB_OPERATION" = "begin" ]; then
            # 1. Stop SDDM -- this brings down the entire KDE session.
            #    systemctl stop is synchronous: it waits until SDDM and
            #    all its child processes have actually exited.
            systemctl stop sddm.service

            # 2. Kill any processes still holding GPU device nodes open.
            kill_gpu_users

            # 3. Unbind fbcon before touching the driver.
            unbind_fb_vtconsoles
            sleep 0.5

            # 4. Unload amdgpu, with retries.
            unload_amdgpu_stack

            # 5. Hand the PCI device to vfio-pci.
            virsh nodedev-detach "$(pci_slot_name "$DEV_VGA")"   || true
            virsh nodedev-detach "$(pci_slot_name "$DEV_AUDIO")" || true
          fi
          ;;
        release)
          if [ "$SUB_OPERATION" = "end" ]; then
            # 1. Return the PCI device to the host.
            virsh nodedev-reattach "$(pci_slot_name "$DEV_VGA")"   || true
            virsh nodedev-reattach "$(pci_slot_name "$DEV_AUDIO")" || true

            # 2. Reload amdgpu. drm core stayed loaded throughout.
            modprobe amdgpu

            # 3. Give fbcon its framebuffer back.
            sleep 0.5
            rebind_fb_vtconsoles

            # 4. Restart SDDM -- brings KDE back up on the returned GPU.
            systemctl start sddm.service
          fi
          ;;
      esac

      exit 0
    '';
  };
}
