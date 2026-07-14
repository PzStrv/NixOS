# https://search.nixos.org/options | NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
imports =
  [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./modules/packages.nix
    ./modules/network.nix
  ];

# Use the systemd-boot EFI boot loader.
boot.loader = {
	systemd-boot.enable = true;
	systemd-boot.consoleMode = "keep";
	efi.canTouchEfiVariables = true;
	systemd-boot.configurationLimit = 5;
	timeout = 0; # For the menu hold space on startup
};

# Use latest kernel.
boot.kernelPackages = pkgs.linuxPackages_latest;

# Bluetooth
hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
  settings = {
    General = {
      # Shows battery charge of connected devices on supported
      # Bluetooth adapters. Defaults to 'false'.
      Experimental = true;
      # When enabled other devices can connect faster to us, however
      # the tradeoff is increased power consumption. Defaults to
      # 'false'.
      FastConnectable = true;
    };
    Policy = {
      # Enable all controllers when they are found. This includes
      # adapters present on start as well as adapters that are plugged
      # in later on. Defaults to 'true'.
      AutoEnable = true;
    };
  };
};



# Enables codium file-saving for root owned files
security.wrappers.pkexec = {
  owner = "root";
  group = "root";
  setuid = true;
  enable = lib.mkForce true;
  source = "${pkgs.polkit.bin}/bin/pkexec";
};

# Define your hostname.
networking.hostName = "ppingo";

# Configure network connections interactively with nmcli or nmtui.
networking.networkmanager.enable = true;

# Set your time zone.
time.timeZone = "Europe/Ljubljana";

# Locale
i18n.defaultLocale = "en_US.UTF-8";

# Login/KDE
services = {
  desktopManager.plasma6.enable = true;
  displayManager.sddm.enable = true;
  displayManager.sddm.wayland.enable = true;
};

# Hint Electron apps (VS Code, Discord, etc.) to use Wayland
environment.sessionVariables.NIXOS_OZONE_WL = "1";

# Enable CUPS to print documents.
services.printing.enable = true;

# Enable sound.
services.pipewire = {
  enable = true;
  pulse.enable = true;
};

# Define a user account. Don't forget to set a password with ‘passwd’
users.users.maj = {
  isNormalUser = true;
  extraGroups = [ "wheel" "input" "docker" ]; # User groups
};

# Enables flakes
nix.settings.experimental-features = [ "nix-command" "flakes" ];

# GPG key
programs.mtr.enable = true;
programs.gnupg.agent = {
  enable = true;
  enableSSHSupport = true;
};

# Services:
services.openssh.enable = true;
services.flatpak.enable = true;
services.gvfs.enable = true;

# Programs:
programs.firefox.enable = true;
programs.steam.enable = true;

# Docker:
virtualisation.docker.enable = true;
virtualisation.docker.storageDriver = "btrfs";


# DO NOT CHANGE THE VERSION
# For more information, see https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
system.stateVersion = "26.05";
}
