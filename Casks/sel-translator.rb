cask "sel-translator" do
  version "0.1.2"
  sha256 "3fa33eb145e5086b18d99f6edf67a1b6707004858701ed9910ab1aa9b79d7b76"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
