cask "taproom" do
  version "0.2.0"
  sha256 :no_check

  url "https://github.com/AungMyoKyaw/taproom/releases/download/v#{version}/Taproom.dmg"
  name "Taproom"
  desc "Native macOS Liquid Glass Homebrew cockpit"
  homepage "https://github.com/AungMyoKyaw/taproom"

  depends_on macos: ">= :tahoe"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Taproom.app"

  zap trash: [
    "~/Library/Application Support/Taproom",
    "~/Library/Preferences/dev.taproom.app.plist",
    "~/Library/Saved Application State/dev.taproom.app.savedState",
  ]
end
