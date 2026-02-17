# SelTranslator

Native macOS menu-bar application that translates currently selected text from any app using Apple's `Translation` framework.

## Behavior

- Select text anywhere.
- Press `Control + Option + Command + T`.
- If the selection is editable, the selected text is replaced with translated text.
- If the selection is not editable, translated text is copied to clipboard.
- A lightweight overlay confirms success or error.
- Target language is selectable from the menu-bar app menu.
- A Settings window is available from the menu bar to configure target language and global hotkey.
- If translation models are missing, onboarding UI opens and can request model downloads.

## Requirements

- macOS 26 or newer.
- Accessibility permission enabled for the app.
- Apple translation language models installed for source/target languages.

## Install with Homebrew

Single command:

```bash
brew install --cask https://raw.githubusercontent.com/teobale/sel-translator/main/Casks/sel-translator.rb
```

After future releases:

```bash
brew upgrade --cask sel-translator
```

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


## Automated releases (GitHub Actions)

This repository includes:

- `.github/workflows/release.yml` (tag-based release pipeline)
- `Casks/sel-translator.rb` (Homebrew cask used by brew install)
- `scripts/update-cask.sh` (cask updater used by CI)

Release flow:

1. Create and push a version tag:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
2. GitHub Actions automatically:
   - builds `SelTranslator.app`
   - zips and uploads `SelTranslator-macos.zip` to GitHub Releases
   - computes SHA256
   - updates `Casks/sel-translator.rb` on the default branch with the new version and checksum
