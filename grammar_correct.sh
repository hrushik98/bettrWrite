#!/bin/bash

# File path for logging errors
LOG_FILE="$HOME/grammar_correction_errors.log"

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to notify user
notify() {
    notify-send "Grammar Correction" "$1" --icon=dialog-information
}

# Get selected text
selected_text=$(xclip -o -selection primary)

# Check if text was selected
if [ -z "$selected_text" ]; then
    notify "No text selected"
    exit 1
fi

# Prepare text for API (escape quotes and special characters)
escaped_text=$(echo "$selected_text" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Send to OpenAI API
# Using API Key from environment variable for security
API_KEY="${OPENAI_API_KEY:-YOUR_API_KEY}"
response=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{
    \"model\": \"gpt-4o\",
    \"messages\": [{\"role\": \"system\", \"content\": \"You are a helpful assistant that corrects grammar and spelling errors in the text without changing its meaning or tone. Only fix errors - don't rewrite the text.\"}, {\"role\": \"user\", \"content\": \"$escaped_text\"}],
    \"temperature\": 0.3
  }")

# Check if the API call was successful - using POSIX compatible syntax
if echo "$response" | grep -q "error"; then
    error_message=$(echo "$response" | jq -r '.error.message // "Unknown error"')
    log_error "API Error: $error_message"
    notify "Error: Failed to correct text. Check log for details."
    exit 1
fi

# Extract corrected text from response based on the actual API structure
corrected_text=$(echo "$response" | jq -r '.choices[0].message.content')

# If extraction failed
if [ -z "$corrected_text" ]; then
    log_error "Failed to extract corrected text from API response"
    log_error "Response was: $response"
    notify "Error: Failed to process correction"
    exit 1
fi

# Copy corrected text to clipboard
echo -n "$corrected_text" | xclip -selection clipboard

# Simulate keyboard to paste the corrected text (delete selected text and paste)
xdotool key Delete
xdotool key ctrl+v

notify "Text corrected and replaced"