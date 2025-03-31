# bettrWrite

# Grammar Correction Tool for Linux

A simple yet powerful tool that lets you correct grammar in any text by selecting it and pressing a keyboard shortcut (ctrl+e). The tool sends the selected text to OpenAI's API, gets a grammatically corrected version, and automatically replaces the original text.

## Features

- One-key shortcut (ctrl+e) for quick grammar corrections
- Works across all Linux applications
- Uses OpenAI's latest GPT-4o model for high-quality corrections
- Preserves text meaning while fixing grammatical issues
- Desktop notifications for operation status
- Error logging for troubleshooting

## Requirements

- Linux system (tested on Linux Mint, should work on other distributions)
- OpenAI API key
- Required packages: xclip, xdotool, jq, curl, xbindkeys, libnotify-bin

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/grammar-correction-linux.git
   cd grammar-correction-linux
   ```

2. Install required dependencies:
   ```bash
   sudo apt-get update
   sudo apt-get install xclip xdotool jq curl xbindkeys libnotify-bin
   ```

3. Copy the script to your home directory:
   ```bash
   cp grammar_correct.sh ~/
   chmod +x ~/grammar_correct.sh
   ```

4. Set up your OpenAI API key:
   ```bash
   echo 'export OPENAI_API_KEY="your-api-key-here"' >> ~/.bashrc
   source ~/.bashrc
   ```
   Or edit the script to include your API key directly (less secure).

5. Configure the keyboard shortcut:
   ```bash
   echo '"~/grammar_correct.sh"
     control + e' > ~/.xbindkeysrc
   
   # Start xbindkeys
   xbindkeys
   
   # Make xbindkeys start automatically on login
   mkdir -p ~/.config/autostart
   echo "[Desktop Entry]
   Type=Application
   Name=XBindKeys
   Exec=xbindkeys
   Hidden=false
   NoDisplay=false
   X-GNOME-Autostart-enabled=true" > ~/.config/autostart/xbindkeys.desktop
   ```

## Usage

1. Select text in any application
2. Press ctrl+e
3. Wait a moment for the API to process the text
4. The selected text will be replaced with the grammatically corrected version

## Troubleshooting

- Check the log file at `~/grammar_correction_errors.log` for errors
- Make sure xbindkeys is running: `ps aux | grep xbindkeys`
- Try restarting xbindkeys: `killall xbindkeys && xbindkeys`
- Test API key: `curl -s https://api.openai.com/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $OPENAI_API_KEY" -d '{"model":"gpt-4o","messages":[{"role":"user","content":"test"}]}'`

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome. Please feel free to submit a Pull Request.