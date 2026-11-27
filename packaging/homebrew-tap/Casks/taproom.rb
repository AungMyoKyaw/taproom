cask "taproom" do
  version "0.2.0"
  sha256 "b363824efc655cb3895f679093b4ff6c0800867207d1050f0a7a4077ede075b1"

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
