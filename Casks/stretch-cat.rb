cask "stretch-cat" do
  version "1.2.0"
  sha256 "a83a72012726135927ad0b8eec348d00b9e682c5715c914dab65768a17d3058f"

  url "https://github.com/VoMinhKhoii/StretchCat/releases/download/v1.2.0/StretchCat.dmg"
  name "Stretch Cat"
  desc "Menu-bar reminder to stand up and stretch every 2 hours, with an animated cat"
  homepage "https://github.com/VoMinhKhoii/StretchCat"

  depends_on macos: ">= :ventura"

  app "StretchCat.app"

  zap trash: [
    "~/Library/Preferences/com.khoivo.stretchcat.plist",
  ]
end
