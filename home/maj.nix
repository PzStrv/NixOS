{ pkgs, ... }:
{
home.file.".bashrc".source = ./bashrc;
home.file.".bash_profile".source = ./bash_profile;

home.file.".config/nvim/init.lua".source = ./configs/nvim.lua;
home.file.".config/fastfetch/config.jsonc".source = ./configs/fastfetch.jsonc;

home.file.".config/hypr/hyprland.lua".source = ./hyprland/hyprland.lua;
home.file.".config/waybar/config.jsonc".source = ./hyprland/waybar.jsonc;
home.file.".config/waybar/style.css".source = ./hyprland/waybar.css;

home.username = "maj";
home.homeDirectory = "/home/maj";
home.stateVersion = "24.11";

home.packages = with pkgs; [
# Gaem

# Code
    zed-editor

# System
    fastfetch
    btop

# Other
    discord
];
}
