#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}bettrWrite Uninstaller${NC}"
echo "This script will remove the bettrWrite tool and its configuration."
read -p "Are you sure you want to continue? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Config locations
CONFIG_DIR="$HOME/.config/bettrwrite"
LOG_FILE="$HOME/bettrwrite_errors.log"
XBINDKEYSRC_FILE="$HOME/.xbindkeysrc"
AUTOSTART_FILE="$HOME/.config/autostart/xbindkeys.desktop"

# Stop xbindkeys (optional, user might have other bindings)
echo -e "\n${YELLOW}Stopping xbindkeys (if running)...${NC}"
pkill xbindkeys 2>/dev/null

# Remove configuration directory and script
echo -e "\n${YELLOW}Removing configuration directory and script...${NC}"
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo "Removed $CONFIG_DIR"
else
    echo "Configuration directory not found at $CONFIG_DIR"
fi

# Remove log file
echo -e "\n${YELLOW}Removing log file...${NC}"
if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE"
    echo "Removed $LOG_FILE"
else
    echo "Log file not found at $LOG_FILE"
fi

# Remove keyboard shortcut config from .xbindkeysrc
echo -e "\n${YELLOW}Removing keyboard shortcut configuration from $XBINDKEYSRC_FILE...${NC}"
if [ -f "$XBINDKEYSRC_FILE" ]; then
    # Count lines before
    lines_before=$(wc -l < "$XBINDKEYSRC_FILE")
    # Remove lines containing the script path and comment lines added by installer
    sed -i '/bettrwrite\.sh/d' "$XBINDKEYSRC_FILE"
    sed -i '/# bettrWrite Shortcuts (Managed by installer)/d' "$XBINDKEYSRC_FILE"
     # Remove blank lines at the end potentially left by sed
    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$XBINDKEYSRC_FILE"
    lines_after=$(wc -l < "$XBINDKEYSRC_FILE")
    if [ "$lines_before" -ne "$lines_after" ]; then
        echo "Removed bettrWrite shortcuts from $XBINDKEYSRC_FILE"
        echo -e "${YELLOW}You may need to restart xbindkeys manually if it was running (${GREEN}xbindkeys${NC}).${NC}"
    else
         echo "No bettrWrite shortcuts found in $XBINDKEYSRC_FILE"
    fi
else
    echo "Keyboard shortcut config file ($XBINDKEYSRC_FILE) not found"
fi

# Remove autostart entry
echo -e "\n${YELLOW}Removing autostart entry...${NC}"
if [ -f "$AUTOSTART_FILE" ]; then
    rm "$AUTOSTART_FILE"
    echo "Removed autostart entry $AUTOSTART_FILE"
else
    echo "Autostart entry not found"
fi

# Option to remove API key from .bashrc (though it's now primarily in config)
echo -e "\n${YELLOW}API Key Cleanup (Optional)${NC}"
echo "Note: API key is primarily stored in $CONFIG_DIR/config.json (which was removed)."
if grep -q "export OPENAI_API_KEY" ~/.bashrc; then
 read -p "Do you want to remove the OPENAI_API_KEY export from your ~/.bashrc? (y/n): " remove_key_bashrc
 if [[ "$remove_key_bashrc" =~ ^[Yy]$ ]]; then
        sed -i '/export OPENAI_API_KEY/d' ~/.bashrc
        echo "Removed API key export from ~/.bashrc"
        echo "Please restart your terminal or run 'source ~/.bashrc' to apply the changes."
 fi
fi


echo -e "\n${GREEN}Uninstallation complete!${NC}"
echo "If xbindkeys was managing other shortcuts, you might need to restart it manually ('xbindkeys')."