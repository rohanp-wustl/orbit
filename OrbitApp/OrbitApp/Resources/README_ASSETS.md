# Assets

This scaffold can't hand you a real `Assets.xcasset` bundle, Lottie `.json`
animation files, or custom fonts — those are binary/Xcode-native and need to
be added inside Xcode directly:

1. Create `Assets.xcassets` via Xcode's New File dialog (it's created for you
   automatically if you start from the "App" template).
2. Add background/sticker/frame images as named image sets matching the
   strings used in `docs/AI_CONTRACT.md`'s asset catalog (e.g.
   `kraft_paper_02`, `tape_blue`, `polaroid`) — the AI only ever returns
   strings, so whatever you name the asset is what the AI will reference.
   Keep the catalog doc and your actual asset names in sync as Design adds more.
3. Add the display/handwritten font (`.ttf`/`.otf`) via Xcode: drag into the
   target, then register it in Info.plist under "Fonts provided by application".
4. Add `lottie-ios` via Swift Package Manager
   (https://github.com/airbnb/lottie-ios) once Design has exported the
   launch/unboxing/mascot animations as `.json` from After Effects.
