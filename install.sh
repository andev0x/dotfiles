#!/bin/bash

# This script is used to set up the dotfiles using stow.

# List of packages to stow
PACKAGES=(
    alacritty
    bash
    custom-scripts
    fish
    git
    gtk-3.0
    hypr
    kitty
    nvim
    picom
    spicetify
    tmux
    vscode
    waybar
    wlogout
    wofi
    xorg
    zsh
)

# Stow the packages
echo "This script will stow the following packages:"
for package in "${PACKAGES[@]}"; do
    echo "  - $package"
done

read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for package in "${PACKAGES[@]}"; do
        echo "Stowing $package..."
        stow "$package"
    done
    echo "All packages have been stowed."
else
    echo "Aborting."
fi
