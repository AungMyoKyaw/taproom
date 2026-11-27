.PHONY: all dev build release dmg notarize run test generate clean help

DERIVED_DATA = .build
SCHEME = Taproom
CONFIGURATION = Debug
PROJECT = Taproom.xcodeproj
APP_BUNDLE = $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Taproom.app
APP_BIN = $(APP_BUNDLE)/Contents/MacOS/Taproom

all: build

help:
	@echo "Taproom Makefile targets:"
	@echo "  make dev       - Build and run Taproom in the foreground"
	@echo "  make build     - Generate Xcode project & build Taproom.app"
	@echo "  make run       - Launch Taproom.app in the background via 'open'"
	@echo "  make test      - Run unit tests with Swift Testing"
	@echo "  make release   - Build Release signed with Developer ID"
	@echo "  make dmg       - Package Release Taproom.app into a compressed DMG"
	@echo "  make notarize  - Build DMG, notarize, staple, and verify Gatekeeper"
	@echo "  make generate  - Regenerate Taproom.xcodeproj via xcodegen"
	@echo "  make clean     - Remove build artifacts and derived data"

generate:
	@which xcodegen >/dev/null 2>&1 || (echo "xcodegen not found. Run 'brew install xcodegen'" && exit 1)
	xcodegen generate

$(PROJECT): project.yml
	@$(MAKE) generate

build: $(PROJECT)
	@mkdir -p $(DERIVED_DATA)
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		build

dev: build
	@echo "==> Launching Taproom (Ctrl+C to quit)..."
	@pkill -x Taproom 2>/dev/null || true
	@"$(APP_BIN)"

run: build
	@echo "==> Opening Taproom.app..."
	@open "$(APP_BUNDLE)"

test: $(PROJECT)
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		test -destination 'platform=macOS'

clean:
	rm -rf $(DERIVED_DATA)

release: $(PROJECT)
	@mkdir -p $(DERIVED_DATA)
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		build

dmg: release
	@rm -rf $(DERIVED_DATA)/dmg-staging $(DERIVED_DATA)/Taproom.dmg
	@mkdir -p $(DERIVED_DATA)/dmg-staging
	@cp -R "$(DERIVED_DATA)/Build/Products/Release/Taproom.app" "$(DERIVED_DATA)/dmg-staging/"
	@ln -s /Applications "$(DERIVED_DATA)/dmg-staging/Applications"
	hdiutil create -volname "Taproom" -srcfolder "$(DERIVED_DATA)/dmg-staging" -ov -format UDZO "$(DERIVED_DATA)/Taproom.dmg"
	@rm -rf $(DERIVED_DATA)/dmg-staging

notarize: dmg
	xcrun notarytool submit "$(DERIVED_DATA)/Taproom.dmg" --keychain-profile "taproom-notary" --wait
	xcrun stapler staple "$(DERIVED_DATA)/Taproom.dmg"
	spctl --assess --verbose=4 --type open --context context:primary-signature "$(DERIVED_DATA)/Taproom.dmg"
