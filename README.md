# Duo Breakout

Brick breaker made for the foldable iPhone Duo.

- **Closed or tent mode** - one player on the small screen. Works in any direction.
- **Open** - lay the phone flat between two friends. Each player drags a paddle on their half and the bricks sit on the fold.
- Power-ups: **W** wide paddle, **3** multi-ball, **S** slow ball, **♥** extra life.

## Where things are

- `DuoBreakout.swiftpm/` - all the game code. Open it in Swift Playgrounds on iPad to play right away.
- `project.yml` - builds the App Store app from the same code (XcodeGen).
- `AppAssets/` - app icon and Info.plist. Redraw the icon with `python3 scripts/make_icon.py`.

## TestFlight

Needs the repo secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (App Store Connect API key, Admin).
Run the "Upload to TestFlight" action, or push a commit with `[testflight]` in the message.
