cask "sel-translator" do
  version "0.1.3"
  sha256 "b82a0a3e6c5e727c9c03d29b20680799e28a1290d616cb765290ac3693e664a1"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
