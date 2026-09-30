This folder contains optimized renders of the Git Extensions logo.

The original SVG file from which the icons were rendered is in the `Artwork` folder.

The 1024-pixel PNG is rendered from `git-extensions-logo.svg` for the macOS
512-point Retina icon. It uses the existing artwork, with transparency preserved.
To reproduce it with Node.js and sharp 0.35.4 (libvips 8.18.6 / librsvg 2.62.91):

```js
const sharp = require("sharp");
sharp("setup/assets/Logo/git-extensions-logo.svg", { density: 921.6 })
    .resize(1024, 1024)
    .png()
    .toFile("setup/assets/Logo/git-extensions-logo-1024px.png");
```

`eng/avalonia/package-macos-app.sh` assembles the existing PNG sizes and this render
into Apple's standard iconset names and invokes `iconutil` to generate the `.icns`.
Normal builds need no SVG renderer or Node.js installation.
