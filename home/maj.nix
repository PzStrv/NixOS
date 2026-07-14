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

# https://search.nixos.org/packages
home.packages = with pkgs; [
# Gaem
    heroic

# Code
	zed-editor
	gcc

# System
    fastfetch
    btop

# Other
    discord
	proton-vpn
	qbittorrent
];
}
