# bettrWrite

# Universal Text Processing Tool for Linux (OpenAI & Ollama)

A simple yet powerful tool that lets you process selected text using AI models by pressing configurable keyboard shortcuts. Send selected text to OpenAI's API or a local Ollama instance, get the processed version back, and automatically replace the original text.

Ideal for grammar correction, summarization, translation, code explanation, and more!

## Features

-   **Configurable Shortcuts:** Define multiple keyboard shortcuts for different tasks (e.g., `Ctrl+E` for grammar, `Ctrl+S` for summary).
-   **Multiple Backends:** Supports both **OpenAI API** (GPT-4o, etc.) and **local Ollama models** (Llama3, Mistral, etc.).
-   **Custom Prompts:** Assign a unique system prompt to each shortcut to tailor the AI's task.
-   **Works System-Wide:** Use it in any Linux application that allows text selection.
-   **Preserves Meaning (Optional):** Default prompt focuses on grammar correction without changing meaning, but you can customize prompts for any text transformation.
-   **Notifications:** Desktop notifications for operation status.
-   **Error Logging:** Logs errors to `~/bettrwrite_errors.log`.

## Requirements

-   Linux system (tested on Debian/Ubuntu derivatives like Mint, should work on others).
-   Required packages: `xclip`, `xdotool`, `jq`, `curl`, `xbindkeys`, `libnotify-bin`.
-   **If using OpenAI:** An OpenAI API key.
-   **If using Ollama:**
    -   Ollama installed and running (see [https://ollama.com](https://ollama.com)).
    -   Desired Ollama models pulled (e.g., `ollama pull llama3.2`).

## Installation

1.  Clone this repository:
    ```bash
    git clone https://github.com/yourusername/bettrwrite.git # Replace with actual repo URL
    cd bettrwrite
    ```

2.  Run the installer script:
    ```bash
    ./install.sh
    ```
    The script will:
    -   Install required dependencies if missing (using `sudo apt-get`).
    -   Ask if you want to configure OpenAI and/or Ollama.
    -   Guide you through setting up the API key (for OpenAI) or selecting and validating a local model (for Ollama).
    -   Create a configuration file at `~/.config/bettrwrite/config.json`.
    -   Set up a default shortcut (`Ctrl+E`) for grammar correction using your chosen backend.
    -   Configure `xbindkeys` to handle the shortcuts and start automatically on login.

## Usage

1.  Select text in any application.
2.  Press the configured keyboard shortcut (e.g., `Ctrl+E` for the default grammar correction).
3.  Wait a moment for the AI model to process the text.
4.  The selected text will be automatically replaced with the processed version.

## Configuration: Adding Custom Shortcuts & Prompts

You can define your own text processing actions by editing two files:

1.  **Configuration (`~/.config/bettrwrite/config.json`):**
    -   Defines the *behavior* of each shortcut.
    -   Add new JSON objects to the `shortcuts` array. Each object needs:
        -   `id`: A unique name (string, no spaces) for this shortcut (e.g., "summarize", "translate_es").
        -   `keys`: The key combination string used by `xbindkeys` (e.g., "control + s", "alt + shift + t").
        -   `backend`: `"openai"` or `"ollama"`.
        -   `model`: The specific model name (e.g., `"gpt-4o"`, `"llama3.2:latest"`).
        -   `prompt`: The system prompt telling the AI what to do. **Important:** Instruct the model to output *only* the desired text, otherwise, you might get conversational fluff pasted back.
        -   `ollama_options` / `openai_options`: Optional JSON objects for backend-specific parameters (like `temperature`). See the respective API docs.
    -   You can also edit the `settings` section to change the Ollama URL or update the OpenAI key.

    **Example `shortcuts` entry in `config.json` for summarization:**
    ```json
     {
       "id": "summarize_short",
       "keys": "control + shift + s",
       "backend": "ollama",
       "model": "mistral:latest",
       "prompt": "Summarize the following text into a single short sentence. Output ONLY the summary sentence.",
       "ollama_options": { "temperature": 0.6 }
     }
    ```

2.  **Keybindings (`~/.xbindkeysrc`):**
    -   Maps the physical key presses to execute the script with the correct `id`.
    -   For each *new* shortcut defined in `config.json`, add a corresponding entry here. The format is:
        ```
        "/path/to/bettrwrite.sh <id>"
          <keys>
        ```
    -   The script path is typically `~/.config/bettrwrite/bettrwrite.sh`.
    -   `<id>` must match the `id` you defined in `config.json`.
    -   `<keys>` must match the `keys` you defined in `config.json`.

    **Example entry in `~/.xbindkeysrc` corresponding to the summarization example:**
    ```
    "~/.config/bettrwrite/bettrwrite.sh summarize_short"
      control + shift + s
    ```

3.  **Apply Changes:** After editing `~/.xbindkeysrc`, you need to reload `xbindkeys`:
    ```bash
    pkill xbindkeys && xbindkeys
    ```
    Changes to `config.json` are read by the script each time it runs, so no restart is needed for those.

**Common Shortcut Ideas:**

-   `Control + Alt + C`: Explain selected code.
-   `Control + T`: Translate selected text (specify target language in prompt).
-   `Control + Shift + E`: Change tone of selected text (e.g., make more formal/casual).
-   `Control + Alt + S`: Spell check only.

## Troubleshooting

-   **Check Logs:** Look for errors in `~/bettrwrite_errors.log`.
-   **xbindkeys Running?** Check with `ps aux | grep xbindkeys`. If not running, start it with `xbindkeys`. If it fails, check `~/.xbindkeys_errors`.
-   **xbindkeys Configuration:** Ensure `~/.xbindkeysrc` has the correct path to `bettrwrite.sh` and the correct `id` and `keys` matching `config.json`. Reload `xbindkeys` after changes (`pkill xbindkeys && xbindkeys`).
-   **Ollama Issues:**
    -   Is the Ollama server running? (`ollama ps` or `curl http://localhost:11434/`). Start it if necessary.
    -   Does the specified model exist locally? (`ollama list`). Pull it if needed (`ollama pull <model_name>`).
    -   Is the `ollama_base_url` in `config.json` correct?
-   **OpenAI Issues:**
    -   Is the API key correct? (Check `config.json` or `OPENAI_API_KEY` environment variable).
    -   Test the key directly (see original README example or OpenAI docs).
-   **Permissions:** Ensure `~/.config/bettrwrite/bettrwrite.sh` is executable (`chmod +x ~/.config/bettrwrite/bettrwrite.sh`).
-   **Dependencies:** Make sure `jq`, `curl`, `xclip`, `xdotool`, `libnotify-bin` are installed.

## Uninstallation

Run the `uninstall.sh` script:
```bash
./uninstall.sh