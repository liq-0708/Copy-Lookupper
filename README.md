# Copy Lookupper

A lightweight macOS menu bar application designed for seamless text lookup and translation. It provides an intuitive way to interact with on-screen text using optical character recognition (OCR) and native macOS translation features.

## Features

* **On-Screen Dictionary Lookup:** Extracts text directly from your screen using OCR, highlights the matched word, and instantly displays the native macOS Dictionary definition.
* **Full-Text Translation:** Select any text across the system and instantly bring up the native macOS Translation overlay without needing to copy-paste into a separate app.
* **Menu Bar Integration:** Runs quietly in the background as a menu bar agent.

## Requirements

* macOS 14.4 or later (required for the native Translation API).
* Screen Recording Permission (required for OCR text capture).
* Accessibility Permission (required for global text selection).

## Installation

1. Go to the [Releases](../../releases) page and download the latest `.dmg` or `.app.zip` file.
2. Move `Copy Lookupper.app` to your `/Applications` folder.
3. **Important Security Note:** Because this open-source app is not signed with a paid Apple Developer certificate, macOS Gatekeeper may flag it as "damaged" upon first launch. To resolve this, open your Terminal and run the following command to remove the quarantine attribute:
   ```bash
   xattr -cr /Applications/Copy\ Lookupper.app
   ```
4. Launch the app. You will be prompted to grant Screen Recording and Accessibility permissions in System Settings.

## Usage

The app operates entirely via global keyboard shortcuts:

* `Cmd + Shift + E`: Hover your mouse over any word on the screen and press this shortcut. The app will recognize the word, highlight it in yellow, and open the macOS Dictionary.
* `Cmd + Shift + T`: Highlight any text in any application and press this shortcut. The app will read the selected text and display the native macOS Translation popover.

## License

This project is licensed under the MIT License.
