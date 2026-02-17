# SelTranslator

Native macOS menu-bar application that translates currently selected text from any app using Apple's `Translation` framework.

## Behavior

- Select text anywhere.
- Press `Control + Option + Command + T`.
- If the selection is editable, the selected text is replaced with translated text.
- If the selection is not editable, translated text is copied to clipboard.
- A lightweight overlay confirms success or error.
- Target language is selectable from the menu-bar app menu.

## Requirements

- macOS 26 or newer.
- Accessibility permission enabled for the app.
- Apple translation language models installed for source/target languages.

## Run from source

```bash
swift run SelTranslator
```

On first run, allow Accessibility access when prompted.

## Troubleshooting

- If you see a translation error overlay saying models are missing:
  1. Open System Settings.
  2. Go to General > Language & Region > Translation Languages.
  3. Download the source and target languages.
  4. Retry hotkey translation.
- Runtime errors are now printed to terminal with `[SelTranslator]` prefix.

## Build `.app` artifact

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

This generates:

- `dist/SelTranslator.app`
- `dist/SelTranslator-macos.zip`

## Homebrew distribution design

This repository includes:

- `packaging/homebrew/Casks/sel-translator.rb` (template cask)
- `scripts/make-cask.sh` (helper that computes SHA256 from a release asset URL)

Typical release flow:

1. Build zip artifact with `./scripts/build-app.sh`.
2. Publish `dist/SelTranslator-macos.zip` to GitHub Releases.
3. Generate cask content with:
   ```bash
   chmod +x scripts/make-cask.sh
   ./scripts/make-cask.sh 0.1.0 https://github.com/<org>/<repo>/releases/download/v0.1.0/SelTranslator-macos.zip
   ```
4. Commit the cask file in your Homebrew tap repository.
