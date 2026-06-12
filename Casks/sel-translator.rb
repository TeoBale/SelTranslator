cask "sel-translator" do
  version "0.1.6"
  sha256 "e561a5d00b318a057f075779ae274d6f8dcdbb0f428e42993845ba2ad5debd16"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
