cask "sel-translator" do
  version "0.1.5"
  sha256 "1118d6d3fcd1b27335b554a6188ab6c63d6950bc9250d808ebb4a8762f083f10"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
