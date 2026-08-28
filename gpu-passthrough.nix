# gpu-passthrough.nix
#
# Single-GPU VFIO passthrough module for NixOS.
#   Host:  AMD CPU, AMD RX 9060 XT GPU, KDE Plasma / SDDM.
#   Guest: AMD RX 9060 XT passed through to a VM via virt-manager.
#
# PCI addresses confirmed with lspci:
#   0b:00.0  RX 9060 XT VGA      [1002:7590]
#   0b:00.1  Navi 48 HDMI Audio  [1002:ab40]

{ lib, pkgs, config, ... }:

let
  gpuAddrVga   = "0000:0b:00.0";  # RX 9060 XT VGA [1002:7590]
  gpuAddrAudio = "0000:0b:00.1";  # Navi 48 HDMI/DP Audio [1002:ab40]

  username = "maj";
  vmName   = "win11";
in
{
  # =====================================================================
  # IOMMU / Kernel Boot Parameters
  # =====================================================================
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "pcie_aspm=off"
    "initcall_blacklist=sysfb_init"
    "video=efifb:off"
    "video=vesafb:off"
    "video=simplefb:off"
    # "amdgpu.reset_method=4"  -- causes black screen on Navi 44, leave disabled
  ];

  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
  boot.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];

  boot.extraModprobeConfig = ''
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';

  # =====================================================================
  # Virtualisation Stack
  # =====================================================================
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
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
    virtio-win
    psmisc
    looking-glass-client
  ];

  # =====================================================================
  # Dynamic GPU Bind / Unbind Hook Script
  #
  # Uses the remove/rescan method for RDNA 4 (Navi 44/48) compatibility.
  # This gives the GPU a clean PCI re-enumeration on release, which is
  # the key difference that makes RDNA 4 passthrough work reliably.
  # =====================================================================
  systemd.tmpfiles.rules = [
      "L+ /var/lib/libvirt/hooks/qemu - - - - /etc/libvirt/hooks/qemu"
  ];

  environment.etc."libvirt/hooks/qemu" = {
    mode = "0755";
    text = ''
#!${pkgs.bash}/bin/bash
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

      # Read vendor/device IDs for new_id/remove_id sysfs interface
      gpu_vd="$(cat /sys/bus/pci/devices/$DEV_VGA/vendor | sed 's/0x//') $(cat /sys/bus/pci/devices/$DEV_VGA/device | sed 's/0x//')"
      aud_vd="$(cat /sys/bus/pci/devices/$DEV_AUDIO/vendor | sed 's/0x//') $(cat /sys/bus/pci/devices/$DEV_AUDIO/device | sed 's/0x//')"

      kill_gpu_users() {
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
        for vtcon in /sys/class/vtconsole/vtcon*; do
          [ -e "$vtcon/name" ] || continue
          grep -qi "frame buffer" "$vtcon/name" && echo 0 > "$vtcon/bind" || true
        done
      }

      rebind_fb_vtconsoles() {
        for vtcon in /sys/class/vtconsole/vtcon*; do
          [ -e "$vtcon/name" ] || continue
          grep -qi "frame buffer" "$vtcon/name" && echo 1 > "$vtcon/bind" || true
        done
      }

      unload_amdgpu_stack() {
        for i in $(seq 1 20); do
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
            # 1. Stop display manager and wait for full exit
			systemctl stop display-manager.service
			loginctl terminate-user maj 2>/dev/null || true
			sleep 2

            # 2. Kill remaining GPU users

            # 3. Unbind fbcon
            unbind_fb_vtconsoles
            sleep 0.5

            # 4. Unload amdgpu
            unload_amdgpu_stack

			# 4.5 Resize BAR2 to 8MB -- required for RDNA 4
            echo 3 > /sys/bus/pci/devices/0000:0b:00.0/resource2_resize || true
            sleep 2

            # 5. Bind to vfio-pci using new_id (RDNA 4 compatible method)
            echo "$DEV_VGA"   > "/sys/bus/pci/devices/$DEV_VGA/driver/unbind"   2>/dev/null || true
            echo "$DEV_AUDIO" > "/sys/bus/pci/devices/$DEV_AUDIO/driver/unbind" 2>/dev/null || true
            echo "$gpu_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
            echo "$aud_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
          fi
          ;;
        release)
          if [ "$SUB_OPERATION" = "end" ]; then
            # 1. Remove device IDs from vfio-pci
            echo "$gpu_vd" > /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true
            echo "$aud_vd" > /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true

            # 2. Remove the PCI devices from the bus entirely
            echo 1 > "/sys/bus/pci/devices/$DEV_VGA/remove"
            echo 1 > "/sys/bus/pci/devices/$DEV_AUDIO/remove"

            # 3. Rescan PCI bus -- GPU re-enumerates cleanly, amdgpu picks it up
            echo 1 > /sys/bus/pci/rescan

            # 4. Rebind fbcon
            sleep 1
            rebind_fb_vtconsoles

            # 5. Restart display manager
            systemctl start display-manager.service
          fi
          ;;
      esac

      exit 0
    '';
  };
}
