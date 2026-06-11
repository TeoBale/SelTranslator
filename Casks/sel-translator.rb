cask "sel-translator" do
  version "0.1.5"
  sha256 "6fd42660a48ee1b9dbcfda5ea512d12abadad00d252ae16e9d4c86637bcfac3f"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
