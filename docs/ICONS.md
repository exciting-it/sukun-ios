# App icon

The repository ships **placeholder** icons (an eight-pointed star) in
`Sukun/Resources/Assets.xcassets/AppIcon.appiconset`:

| File | Use | Notes |
|---|---|---|
| `AppIcon.png` | Default (light) | 1024×1024, opaque, sRGB |
| `AppIcon-Dark.png` | Dark appearance | Charcoal + Sukun green |
| `AppIcon-Tinted.png` | Tinted appearance | Grayscale on black; iOS applies the tint |

## Making the final icon

1. Design on a **1024 × 1024 px** canvas. Keep the motif inside the central ~80% (iOS masks the corners).
   No rounded corners, no transparency, no text.
2. Export three variants:
   - **Light:** sand background `#F6F1EA` → `#EFE6D8`, sage motif `#8FA998`
   - **Dark:** charcoal `#0E1110` → `#171B1A`, green motif `#8CC3A5` (matches the app's dark mode). A transparent background is allowed for dark;
     iOS fills it with its own dark backdrop.
   - **Tinted:** grayscale motif (light grey on black). iOS colors it with the user's tint.
3. Replace the three PNGs, keeping the file names, or drag them into Xcode's AppIcon slots
   (Any / Dark / Tinted, *Single Size*).
4. **Xcode 26+ (Liquid Glass):** you can also build a layered `.icon` with **Icon Composer**
   (Xcode → Open Developer Tool → Icon Composer). Use the star as the foreground layer and a flat sand or night
   background, add the `.icon` file to the app target, and set `ASSETCATALOG_COMPILER_APPICON_NAME` to its name.
5. Check the icon at small sizes (Settings, Spotlight, notifications). Thin strokes vanish below 40 pt,
   so make the outline heavier than looks right at full size.

Xcode generates every smaller size from the 1024 px master. No other sizes are needed.
