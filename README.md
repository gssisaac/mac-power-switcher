# Mac Power Switcher

Menu bar app for macOS 13+ that toggles whether your Mac stays awake when the lid is closed (`pmset disablesleep` on AC power).

## Local build (unsigned)

```bash
./build.sh
open dist/MacPowerSwitcher.dmg
```

## Release build (sign + notarize)

Same flow as [Duck Launcher](https://github.com/gssisaac/duck-launcher): credentials in `scripts/deploy/apple-signing.env` (see `apple-signing.env.example`).

```bash
bash scripts/deploy/build-macos.sh
```

## GitHub release

```bash
export MAC_POWER_SWITCHER_VERSION=1.0.0
export MAC_POWER_SWITCHER_RELEASE_NOTES=release-notes/1.0.0.md
bash scripts/deploy/github-release.sh
```

## License

Open source — see repository license file.
