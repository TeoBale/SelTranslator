cask "sel-translator" do
  version "0.1.0"
  sha256 "<REPLACE_WITH_SHA256>"

  url "https://github.com/teobale/sel-translator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/teobale/sel-translator"

  app "SelTranslator.app"
end
