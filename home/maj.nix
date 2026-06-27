{ pkgs, ... }:
{

home.file = {
# .bahrc config
".bashrc".source = ./bash/bashrc;
".bash_profile".source = ./bash/bash_profile;

# Nvim config
".config/nvim/init.lua".source = ./configs/singleFile/configs/nvim.lua;
# Fastfetch config
".config/fastfetch/config.jsonc".source = ./configs/singleFile/configs/fastfetch.jsonc;

# Hyprland config
".config/hypr/hyprland.lua".source = ./configs/hyprland/hyprland.lua;
".config/waybar/config.jsonc".source = ./configs/hyprland/waybar.jsonc;
".config/waybar/style.css".source = ./configs/hyprland/waybar.css;
};

home.username = "maj";
home.homeDirectory = "/home/maj";
home.stateVersion = "24.11";

home.packages = with pkgs; [
# Gaem
    heroic

# Code
    zed-editor
    vscodium

# System
    fastfetch
    btop

# Editing/REC
	kdePackages.kdenlive
	krita
	obs-studio

# Other
    discord
];
}
