cask "stretch-cat" do
  version "1.1.0"
  sha256 "2a4556c4b3b8b3b1274b3e46bf540b6eda15d0ae7063468e8f9b4632c37c61c7"

  url "https://github.com/VoMinhKhoii/StretchCat/releases/download/v1.1.0/StretchCat.dmg"
  name "Stretch Cat"
  desc "Menu-bar reminder to stand up and stretch every 2 hours, with an animated cat"
  homepage "https://github.com/VoMinhKhoii/StretchCat"

  depends_on macos: ">= :ventura"

  app "StretchCat.app"

  zap trash: [
    "~/Library/Preferences/com.khoivo.stretchcat.plist",
  ]
end
