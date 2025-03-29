#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Grammar Correction Tool Installer${NC}"
echo "This script will install the grammar correction tool."

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${RED}Please do not run this script as root or with sudo.${NC}"
    exit 1
fi

# Install dependencies
echo -e "\n${YELLOW}Installing dependencies...${NC}"
sudo apt-get update || { echo -e "${RED}Failed to update package list${NC}"; exit 1; }
sudo apt-get install -y xclip xdotool jq curl xbindkeys libnotify-bin || { 
    echo -e "${RED}Failed to install dependencies${NC}"
    echo "Please install them manually: xclip xdotool jq curl xbindkeys libnotify-bin"
    exit 1
}

# Copy the script
echo -e "\n${YELLOW}Installing grammar correction script...${NC}"
cp grammar_correct.sh ~/grammar_correct.sh || { echo -e "${RED}Failed to copy script${NC}"; exit 1; }
chmod +x ~/grammar_correct.sh || { echo -e "${RED}Failed to make script executable${NC}"; exit 1; }

# API key setup
echo -e "\n${YELLOW}OpenAI API Key Setup${NC}"
read -p "Do you want to set up your OpenAI API key now? (y/n): " setup_key

if [[ "$setup_key" =~ ^[Yy]$ ]]; then
    read -p "Enter your OpenAI API key: " api_key
    if [ -n "$api_key" ]; then
        # Check if OPENAI_API_KEY is already in .bashrc
        if grep -q "export OPENAI_API_KEY" ~/.bashrc; then
            # Update existing export
            sed -i "s|export OPENAI_API_KEY=.*|export OPENAI_API_KEY=\"$api_key\"|" ~/.bashrc
        else
            # Add new export
            echo "export OPENAI_API_KEY=\"$api_key\"" >> ~/.bashrc
        fi
        echo -e "${GREEN}API key added to ~/.bashrc${NC}"
        echo "Please restart your terminal or run 'source ~/.bashrc' to apply the changes."
    else
        echo -e "${YELLOW}No API key provided.${NC}"
        echo "You will need to set the OPENAI_API_KEY environment variable later."
    fi
else
    echo -e "${YELLOW}Skipping API key setup.${NC}"
    echo "You will need to set the OPENAI_API_KEY environment variable later."
fi

# Set up keyboard shortcut
echo -e "\n${YELLOW}Setting up keyboard shortcut...${NC}"
echo '"~/grammar_correct.sh"
  control + e' > ~/.xbindkeysrc || { echo -e "${RED}Failed to create .xbindkeysrc${NC}"; exit 1; }

# Kill xbindkeys if it's running
pkill xbindkeys 2>/dev/null

# Start xbindkeys
xbindkeys || { echo -e "${RED}Failed to start xbindkeys${NC}"; exit 1; }

# Set up autostart
echo -e "\n${YELLOW}Setting up autostart...${NC}"
mkdir -p ~/.config/autostart
echo "[Desktop Entry]
Type=Application
Name=XBindKeys
Exec=xbindkeys
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true" > ~/.config/autostart/xbindkeys.desktop || { 
    echo -e "${RED}Failed to create autostart entry${NC}"
    exit 1
}

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "You can now use ${YELLOW}Ctrl+E${NC} to correct text grammar."
echo -e "If you experience any issues, check the log file at: ${YELLOW}~/grammar_correction_errors.log${NC}"