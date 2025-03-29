#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}Grammar Correction Tool Uninstaller${NC}"
echo "This script will uninstall the grammar correction tool."
read -p "Are you sure you want to continue? (y/n): " confirm

if [[ "$confirm" != [Yy]* ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop xbindkeys
echo -e "\n${YELLOW}Stopping xbindkeys...${NC}"
pkill xbindkeys 2>/dev/null

# Remove script
echo -e "\n${YELLOW}Removing script...${NC}"
if [ -f ~/grammar_correct.sh ]; then
    rm ~/grammar_correct.sh
    echo "Removed ~/grammar_correct.sh"
else
    echo "Script not found at ~/grammar_correct.sh"
fi

# Remove log file
echo -e "\n${YELLOW}Removing log file...${NC}"
if [ -f ~/grammar_correction_errors.log ]; then
    rm ~/grammar_correction_errors.log
    echo "Removed ~/grammar_correction_errors.log"
else
    echo "Log file not found"
fi

# Remove keyboard shortcut config
echo -e "\n${YELLOW}Removing keyboard shortcut configuration...${NC}"
if [ -f ~/.xbindkeysrc ]; then
    # Check if the file only contains our shortcut
    if grep -q "grammar_correct.sh" ~/.xbindkeysrc && [ $(wc -l < ~/.xbindkeysrc) -le 2 ]; then
        rm ~/.xbindkeysrc
        echo "Removed ~/.xbindkeysrc"
    else
        # Remove just our shortcut
        sed -i '/grammar_correct.sh/,+1d' ~/.xbindkeysrc
        echo "Removed our shortcut from ~/.xbindkeysrc"
    fi
else
    echo "Keyboard shortcut config not found"
fi

# Remove autostart entry
echo -e "\n${YELLOW}Removing autostart entry...${NC}"
if [ -f ~/.config/autostart/xbindkeys.desktop ]; then
    rm ~/.config/autostart/xbindkeys.desktop
    echo "Removed autostart entry"
else
    echo "Autostart entry not found"
fi

# Option to remove API key from .bashrc
echo -e "\n${YELLOW}API Key Management${NC}"
read -p "Do you want to remove the OPENAI_API_KEY from your .bashrc? (y/n): " remove_key

if [[ "$remove_key" =~ ^[Yy]$ ]]; then
    if grep -q "export OPENAI_API_KEY" ~/.bashrc; then
        sed -i '/export OPENAI_API_KEY/d' ~/.bashrc
        echo "Removed API key from ~/.bashrc"
        echo "Please restart your terminal or run 'source ~/.bashrc' to apply the changes."
    else
        echo "No API key found in ~/.bashrc"
    fi
fi

echo -e "\n${GREEN}Uninstallation complete!${NC}"
echo "You may want to restart your session to ensure all changes take effect."