#!/bin/bash

# Script assumes it's located in ~/.config/bettrwrite/bettrwrite.sh
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config.json"
LOG_FILE="$HOME/bettrwrite_errors.log"
SHORTCUT_ID="$1" # Get the identifier passed by xbindkeys

# --- Configuration Loading ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE" >> "$LOG_FILE"
    notify-send "bettrWrite Error" "Config file not found." --icon=dialog-error
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it." >> "$LOG_FILE"
    notify-send "bettrWrite Error" "jq is required but not installed." --icon=dialog-error
    exit 1
fi

# Find the shortcut configuration using jq
shortcut_config=$(jq -r --arg id "$SHORTCUT_ID" '.shortcuts[] | select(.id == $id)' "$CONFIG_FILE")

if [ -z "$shortcut_config" ]; then
    echo "Error: Shortcut configuration for ID '$SHORTCUT_ID' not found in $CONFIG_FILE" >> "$LOG_FILE"
    notify-send "bettrWrite Error" "Shortcut '$SHORTCUT_ID' not configured." --icon=dialog-error
    exit 1
fi

# Extract details from the shortcut config
backend=$(echo "$shortcut_config" | jq -r '.backend')
model=$(echo "$shortcut_config" | jq -r '.model')
system_prompt=$(echo "$shortcut_config" | jq -r '.prompt')
ollama_options=$(echo "$shortcut_config" | jq -r '.ollama_options // {}')
openai_options=$(echo "$shortcut_config" | jq -r '.openai_options // {}')

# Extract global settings
ollama_base_url=$(jq -r '.settings.ollama_base_url // "http://localhost:11434"' "$CONFIG_FILE")
openai_api_key_from_config=$(jq -r '.settings.openai_api_key // ""' "$CONFIG_FILE")

# --- Helper Functions ---
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SHORTCUT_ID] $1" >> "$LOG_FILE"
}

notify() {
    notify-send "bettrWrite ($SHORTCUT_ID)" "$1" --icon=dialog-information
}

notify_error() {
    log_error "$1"
    notify-send "bettrWrite Error ($SHORTCUT_ID)" "$1" --icon=dialog-error
}

# --- Main Logic ---

# Get selected text
selected_text=$(xclip -o -selection primary)

# Check if text was selected
if [ -z "$selected_text" ]; then
    notify "No text selected"
    exit 1
fi

# Prepare text for JSON (more robust escaping needed for complex content)
# Basic escaping for quotes and newlines - might need improvement
json_escaped_text=$(echo "$selected_text" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

corrected_text=""
error_message=""

# --- Backend API Calls ---
if [ "$backend" == "openai" ]; then
    # --- OpenAI Logic ---
    API_KEY="${OPENAI_API_KEY:-$openai_api_key_from_config}"
    if [ -z "$API_KEY" ] || [ "$API_KEY" == "YOUR_OPENAI_API_KEY_OR_NULL" ]; then
        notify_error "OpenAI API key not configured."
        exit 1
    fi

    # Prepare JSON payload
    # Combine system prompt and user text in messages array
    # Merge options from config
    payload=$(jq -n --arg sys_prompt "$system_prompt" --arg user_text "$json_escaped_text" --arg model "$model" --argjson options "$openai_options" \
     '{ model: $model, messages: [ {role: "system", content: $sys_prompt}, {role: "user", content: $user_text} ] } + $options' )

    response=$(curl -s https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "$payload")

    # Check for API errors
     if echo "$response" | jq -e '.error' > /dev/null; then
        error_message=$(echo "$response" | jq -r '.error.message // "Unknown OpenAI error"')
    else
        # Extract corrected text
        corrected_text=$(echo "$response" | jq -r '.choices[0].message.content // empty')
         if [ -z "$corrected_text" ]; then
             error_message="Failed to extract corrected text from OpenAI response."
             log_error "OpenAI Response: $response"
         fi
    fi

elif [ "$backend" == "ollama" ]; then
    # --- Ollama Logic ---
    ollama_api_url="$ollama_base_url/api/generate"

    # Prepare JSON payload (embedding system prompt within the user prompt for /api/generate)
    full_prompt="${system_prompt}\n\nText to process:\n${selected_text}"
    json_escaped_full_prompt=$(echo "$full_prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    payload=$(jq -n --arg model "$model" --arg prompt "$json_escaped_full_prompt" --argjson options "$ollama_options" \
     '{ model: $model, prompt: $prompt, options: $options, stream: false }' )

    response=$(curl -s "$ollama_api_url" -d "$payload")

    # Check for API errors (Ollama might return 200 OK with an error field)
    if echo "$response" | jq -e '.error' > /dev/null; then
        error_message=$(echo "$response" | jq -r '.error // "Unknown Ollama error"')
    else
        # Extract corrected text
        corrected_text=$(echo "$response" | jq -r '.response // empty')
         if [ -z "$corrected_text" ]; then
             error_message="Failed to extract text from Ollama response."
             log_error "Ollama Response: $response"
         fi
    fi

else
    error_message="Invalid backend specified: $backend"
fi

# --- Output Handling ---
if [ -n "$error_message" ]; then
    notify_error "$error_message"
    exit 1
fi

if [ -z "$corrected_text" ]; then
    notify_error "Processing failed: Received empty result."
    exit 1
fi

# Trim leading/trailing whitespace/newlines that models sometimes add
corrected_text=$(echo "$corrected_text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# Copy corrected text to clipboard (secondary buffer)
echo -n "$corrected_text" | xclip -selection clipboard

# Simulate keyboard to paste the corrected text (delete selected text and paste from clipboard)
# Add a small delay to ensure clipboard is ready and focus is correct
sleep 0.1
xdotool key Delete
sleep 0.1
xdotool key ctrl+v

notify "Text processed and replaced"

exit 0