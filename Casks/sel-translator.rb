cask "sel-translator" do
  version "0.1.1"
  sha256 "9b91c827c222eee9e2e6e94ee1d93e1909f98c8a23227eb09875e866f348c4ec"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
