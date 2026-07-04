{pkgs, ...}:

{
# https://search.nixos.org
nixpkgs.config.allowUnfree = true;
environment.systemPackages = with pkgs; [
# KDE Utilities
  kdePackages.kcalc # Calculator
  kdePackages.kcolorchooser # Color picker
  kdePackages.ksystemlog # System log viewer
  kdePackages.sddm-kcm # SDDM configuration module

# Hardware/System Utilities (Optional)
  kdePackages.isoimagewriter # Write hybrid ISOs to USB
  kdePackages.partitionmanager # Disk and partition management
  hardinfo2 # System benchmarks and hardware info
  wayland-utils # Wayland diagnostic tools
  wl-clipboard # Wayland copy/paste support

# Editors
	onlyoffice-desktopeditors
	neovim
	micro

# Default apps
	kdePackages.gwenview
	kdePackages.kate
	nemo    # Found via "Files"
	kdePackages.ark
	vlc

# Code
	gcc

# Other
	wget
	git
	duf
	zip
	unzip
	rar
	unrar
	docker-compose
	appimage-run
];
}

