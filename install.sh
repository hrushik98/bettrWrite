#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}bettrWrite Enhanced Installer${NC}"
echo "This script will install the bettrWrite tool with OpenAI and/or Ollama support."

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${RED}Please do not run this script as root or with sudo.${NC}"
    exit 1
fi

# Config locations
CONFIG_DIR="$HOME/.config/bettrwrite"
SCRIPT_DEST="$CONFIG_DIR/bettrwrite.sh"
CONFIG_FILE="$CONFIG_DIR/config.json"
XBINDKEYSRC_FILE="$HOME/.xbindkeysrc"
AUTOSTART_FILE="$HOME/.config/autostart/xbindkeys.desktop"

# Create config directory
echo -e "\n${YELLOW}Creating configuration directory...${NC}"
mkdir -p "$CONFIG_DIR" || { echo -e "${RED}Failed to create config directory $CONFIG_DIR${NC}"; exit 1; }
mkdir -p "$HOME/.config/autostart" # Ensure autostart dir exists

# Install dependencies
echo -e "\n${YELLOW}Installing dependencies...${NC}"
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v xclip &> /dev/null || ! command -v xdotool &> /dev/null || ! command -v xbindkeys &> /dev/null || ! command -v notify-send &> /dev/null; then
    echo "Attempting to install: jq, curl, xclip, xdotool, xbindkeys, libnotify-bin"
    sudo apt-get update || { echo -e "${RED}Failed to update package list${NC}"; exit 1; }
    sudo apt-get install -y jq curl xclip xdotool xbindkeys libnotify-bin || {
        echo -e "${RED}Failed to install dependencies automatically.${NC}"
        echo "Please install them manually: sudo apt-get install jq curl xclip xdotool xbindkeys libnotify-bin"
        exit 1
    }
else
    echo "Dependencies seem to be installed."
fi


# Copy the script
echo -e "\n${YELLOW}Installing bettrWrite script...${NC}"
# Ensure script exists in current directory before copying
if [ ! -f "bettrwrite.sh" ]; then
    echo -e "${RED}Error: bettrwrite.sh not found in the current directory.${NC}"
    echo "Make sure you are in the project directory and the script is named correctly."
    exit 1
fi
cp bettrwrite.sh "$SCRIPT_DEST" || { echo -e "${RED}Failed to copy script to $SCRIPT_DEST${NC}"; exit 1; }
chmod +x "$SCRIPT_DEST" || { echo -e "${RED}Failed to make script executable${NC}"; exit 1; }

# --- Configuration Setup ---
echo -e "\n${YELLOW}Backend Configuration${NC}"

openai_enabled=false
ollama_enabled=false
openai_api_key="YOUR_OPENAI_API_KEY_OR_NULL"
ollama_model=""
ollama_base_url="http://localhost:11434" # Default Ollama URL

# Ask about OpenAI (Default Yes)
read -p "Configure OpenAI backend? (Y/n): " configure_openai_prompt
if [[ -z "$configure_openai_prompt" || "$configure_openai_prompt" =~ ^[Yy]$ ]]; then
    openai_enabled=true
    read -p "Enter your OpenAI API key (leave blank to use environment variable later): " temp_key
    if [ -n "$temp_key" ]; then
        openai_api_key="$temp_key"
        echo -e "${GREEN}OpenAI API key will be stored in the config file ($CONFIG_FILE).${NC}"
        echo -e "${YELLOW}Alternatively, set the OPENAI_API_KEY environment variable.${NC}"
    else
        echo -e "${YELLOW}OpenAI API key not provided now. Ensure OPENAI_API_KEY environment variable is set before use.${NC}"
    fi
else
    echo "Skipping OpenAI configuration."
fi

# Ask about Ollama (Default Yes)
read -p "Configure Ollama (local LLM) backend? (Y/n): " configure_ollama_prompt
if [[ -z "$configure_ollama_prompt" || "$configure_ollama_prompt" =~ ^[Yy]$ ]]; then

    # Check if ollama command exists
    if ! command -v ollama &> /dev/null; then
        echo -e "${RED}Ollama command not found.${NC}"
        echo "Please install Ollama first (see https://ollama.com) and ensure it's in your PATH."
        echo "Skipping Ollama configuration."
    else
        echo "Checking available Ollama models..."
        # Check if ollama service might be down before listing
        if ! ollama list > /dev/null 2>&1; then
             echo -e "${YELLOW}Could not list Ollama models. Is the Ollama service running?${NC}"
             echo "Skipping Ollama configuration for now. You can configure it manually later."
        else
            ollama list # Show list now that we know it works
            echo "-------------------------------------"
            read -p "Enter the NAME of the Ollama model you want to use for the default action (e.g., llama3.2:latest): " temp_model

            if [ -n "$temp_model" ]; then
                echo "Verifying Ollama server and model '$temp_model'..."
                # Simple test call
                test_payload=$(jq -n --arg model "$temp_model" '{ model: $model, prompt: "Hi", stream: false }')
                # Try default URL first
                response=$(curl -s -o /dev/null -w "%{http_code}" "$ollama_base_url/api/generate" -d "$test_payload" --max-time 5 --connect-timeout 3)

                if [ "$response" == "200" ]; then
                    echo -e "${GREEN}Ollama server is running and model seems accessible.${NC}"
                    ollama_enabled=true
                    ollama_model="$temp_model"
                else
                    # Try asking for URL if connection failed (000) or potentially wrong URL
                    if [ "$response" == "000" ]; then
                        echo -e "${YELLOW}Could not connect to Ollama server at default $ollama_base_url.${NC}"
                    else
                        echo -e "${YELLOW}Ollama server responded with HTTP code $response (expected 200) at $ollama_base_url.${NC}"
                        echo "Model '$temp_model' might not exist, be misspelled, or the server URL might be wrong."
                        echo "You can pull models using: ollama pull <model_name>"
                    fi
                    read -p "Enter the Ollama server URL if it's different (or press Enter to skip Ollama setup): " custom_ollama_url
                    if [ -n "$custom_ollama_url" ]; then
                        ollama_base_url="$custom_ollama_url"
                        echo "Retrying with $ollama_base_url..."
                        response=$(curl -s -o /dev/null -w "%{http_code}" "$ollama_base_url/api/generate" -d "$test_payload" --max-time 5 --connect-timeout 3)
                        if [ "$response" == "200" ]; then
                            echo -e "${GREEN}Ollama server is running and model seems accessible at $ollama_base_url.${NC}"
                            ollama_enabled=true
                            ollama_model="$temp_model"
                        else
                             echo -e "${RED}Still could not connect or model failed at $ollama_base_url (HTTP: $response). Ollama setup skipped.${NC}"
                             ollama_model="" # Reset model if test fails
                        fi
                    else
                        echo -e "${YELLOW}Ollama setup skipped.${NC}"
                    fi
                fi # End initial response check
            else
                echo -e "${YELLOW}No Ollama model specified. Skipping Ollama setup.${NC}"
            fi # End check for non-empty model name
        fi # End check if ollama list worked
    fi # End check for ollama command existence
else
    echo "Skipping Ollama configuration."
fi

# Check if at least one backend was enabled
if ! $openai_enabled && ! $ollama_enabled; then
    echo -e "${RED}No backend (OpenAI or Ollama) was successfully configured. Installation aborted.${NC}"
    echo "Please run the installer again or configure $CONFIG_FILE manually."
    # Clean up potentially created files/dirs
    rm -f "$SCRIPT_DEST"
    rmdir "$CONFIG_DIR" 2>/dev/null # Remove dir only if empty
    exit 1
fi

# --- Configure Initial Shortcut ---
echo -e "\n${YELLOW}Configure Initial Shortcut${NC}"

default_shortcut_id="grammar_correct"
default_keys="control + e"
default_prompt="You are a helpful assistant that corrects grammar and spelling errors in the provided text without changing its meaning or tone. Only fix errors - don't rewrite the text. Output ONLY the corrected text."
default_backend=""
default_model=""

# Choose backend+model for the default shortcut
if $ollama_enabled && $openai_enabled; then
    read -p "Use Ollama or OpenAI for the default shortcut? (ollama/openai) [ollama]: " backend_choice
    if [[ "$backend_choice" == "openai" ]]; then
        default_backend="openai"
        default_model="gpt-4o" # Or prompt for specific model? Keep simple for now.
    else
        default_backend="ollama"
        default_model="$ollama_model"
    fi
elif $ollama_enabled; then
    default_backend="ollama"
    default_model="$ollama_model"
    echo "Default shortcut will use Ollama ($ollama_model)."
else # Only OpenAI enabled
    default_backend="openai"
    default_model="gpt-4o"
     echo "Default shortcut will use OpenAI (gpt-4o)."
fi

# Ask to customize
read -p "Customize the default shortcut keys and prompt? (Current: '$default_keys' for grammar correction) (y/N): " customize_shortcut
if [[ "$customize_shortcut" =~ ^[Yy]$ ]]; then
    echo "Current keys: '$default_keys'"
    read -p "Enter new key combination (e.g., 'alt + g', 'control + shift + c'): " custom_keys
    if [ -n "$custom_keys" ]; then
        default_keys="$custom_keys"
    fi

    echo "Current prompt: '$default_prompt'"
    echo "Enter the new system prompt below. Press Ctrl+D (or Enter then Ctrl+D) when finished:"
    # Read multi-line input until EOF (Ctrl+D)
    custom_prompt=$(cat)
    if [ -n "$custom_prompt" ]; then
        default_prompt="$custom_prompt"
    fi
    echo "Default shortcut configured with:"
    echo "  Keys: $default_keys"
    echo "  Backend: $default_backend ($default_model)"
    echo "  Prompt: $default_prompt"
else
    echo "Using default shortcut: '$default_keys' for grammar correction with $default_backend ($default_model)."
fi


# --- Create Configuration File ---
echo -e "\n${YELLOW}Creating configuration file...${NC}"

# Create config JSON using jq
jq -n \
  --arg key "$openai_api_key" \
  --arg ollama_url "$ollama_base_url" \
  --argjson shortcuts "[
    {
      \"id\": \"$default_shortcut_id\",
      \"keys\": \"$default_keys\",
      \"backend\": \"$default_backend\",
      \"model\": \"$default_model\",
      \"prompt\": \"$default_prompt\",
      \"ollama_options\": { \"temperature\": 0.3 },
      \"openai_options\": { \"temperature\": 0.3 }
    }
  ]" \
'{ settings: { openai_api_key: $key, ollama_base_url: $ollama_url }, shortcuts: $shortcuts }' > "$CONFIG_FILE" || {
    echo -e "${RED}Failed to create configuration file $CONFIG_FILE${NC}"; exit 1;
}

echo "Configuration written to $CONFIG_FILE"

# --- Setup Keyboard Shortcuts with xbindkeys ---
echo -e "\n${YELLOW}Setting up keyboard shortcuts via xbindkeys...${NC}"

# Ensure .xbindkeysrc exists
touch "$XBINDKEYSRC_FILE"

# Remove any existing bettrwrite bindings first to avoid duplicates
# Make the pattern more specific to avoid removing unrelated lines if user named script similarly
sed -i '\@'"$SCRIPT_DEST"'@d' "$XBINDKEYSRC_FILE" # Remove lines containing the script path and its associated keybinding line
sed -i '/# bettrWrite Shortcuts (Managed by installer)/d' "$XBINDKEYSRC_FILE" # Remove the header comment

# Add shortcut(s) from config to .xbindkeysrc
echo -e "\n# bettrWrite Shortcuts (Managed by installer)" >> "$XBINDKEYSRC_FILE"
jq -r '.shortcuts[] | "\"'"$SCRIPT_DEST"' \(.id)\"\n  \(.keys)"' "$CONFIG_FILE" >> "$XBINDKEYSRC_FILE" || {
    echo -e "${RED}Failed to add shortcut to $XBINDKEYSRC_FILE${NC}"; exit 1;
}

# Kill and restart xbindkeys
echo "Restarting xbindkeys..."
pkill xbindkeys 2>/dev/null
sleep 1 # Give it a moment to die
xbindkeys || { echo -e "${RED}Failed to start xbindkeys. Check ~/.xbindkeys_errors perhaps.${NC}"; }

# --- Setup Autostart ---
echo -e "\n${YELLOW}Setting up xbindkeys to start on login...${NC}"
echo "[Desktop Entry]
Type=Application
Name=XBindKeys
Comment=Starts xbindkeys for custom keyboard shortcuts (used by bettrWrite)
Exec=xbindkeys
StartupNotify=false
Terminal=false
Hidden=false" > "$AUTOSTART_FILE" || {
    echo -e "${RED}Failed to create autostart entry $AUTOSTART_FILE${NC}";
    # Don't exit, maybe user doesn't want autostart
}

# --- Final Instructions ---
echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "Initial shortcut ${YELLOW}${default_keys}${NC} is configured."
echo -e "Backend: ${YELLOW}${default_backend}${NC}, Model: ${YELLOW}${default_model}${NC}"
echo -e "Prompt: \"${default_prompt}\""
echo -e "\nYou can add more shortcuts by editing:"
echo -e "  1. Configuration: ${YELLOW}$CONFIG_FILE${NC} (add new entries to the 'shortcuts' list)"
echo -e "  2. Keybindings:   ${YELLOW}$XBINDKEYSRC_FILE${NC} (add the corresponding keybinding line)"
echo -e "Example - To add Ctrl+S for summarization (after adding to config.json with id 'summarize'):"
echo -e "  Add this to ${YELLOW}$XBINDKEYSRC_FILE${NC}:"
echo -e '    "'"$SCRIPT_DEST"' summarize"'
echo -e '      control + s'
echo -e "\nRemember to restart xbindkeys after editing ${YELLOW}$XBINDKEYSRC_FILE${NC} (${GREEN}pkill xbindkeys && xbindkeys${NC})"
echo -e "\nIf you experience issues, check the log file: ${YELLOW}$HOME/bettrwrite_errors.log${NC}"