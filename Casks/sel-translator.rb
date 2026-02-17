cask "sel-translator" do
  version "0.1.0"
  sha256 "0edc7090a0f512169848499710e7802b765e2723296790e2f26f82025bdd0306"

  url "https://github.com/teobale/sel-translator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/teobale/sel-translator"

  app "SelTranslator.app"
end
