{ pkgs, ... }:
{

home.file = {
# .bahrc config
".bashrc".source = ./bash/bashrc;
".bash_profile".source = ./bash/bash_profile;

# Nvim config
".config/nvim/init.lua".source = ./configs/nvim.lua;
# Fastfetch config
".config/fastfetch/config.jsonc".source = ./configs/fastfetch.jsonc;
};

home.username = "maj";
home.homeDirectory = "/home/maj";
home.stateVersion = "26.05";

# https://search.nixos.org/paackages
home.packages = with pkgs; [
# Gaem
	heroic
	satisfactorymodmanager
	prismlauncher
	lunar-client
	oversteer

# Code
	vscodium
	zed-editor

# System
	fastfetch
	btop

# Editing/REC
	kdePackages.kdenlive
	krita

# Other
	discord
	proton-vpn
	qbittorrent
	lufus
	freecad
];
}
