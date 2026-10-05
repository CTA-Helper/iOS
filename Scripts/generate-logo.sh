#!/bin/bash
#
# generate-logo.sh — renders the app icon into the Logo image set the loading screen shows.
#
#   Scripts/generate-logo.sh
#
# The logo is the app icon itself, so it is exported from AppIcon.icon rather than drawn twice:
# Icon Composer's ictool renders the Default rendition for light appearance and the Dark rendition
# for dark, at @2x and @3x of the 200-point width the loading screen draws it at. Rerun it after
# editing the icon and commit what it writes.

set -euo pipefail

readonly ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
readonly POINTS=200

root="$(cd "$(dirname "$0")/.." && pwd)"
readonly icon="$root/CTA Helper/AppIcon.icon"
readonly imageset="$root/CTA Helper/Assets.xcassets/Logo.imageset"

# Renders one rendition of the icon at one scale.
#   $1 — the ictool rendition (Default, Dark)
#   $2 — the scale factor (2, 3)
#   $3 — the output filename, inside the image set
export_rendition() {
  "$ICTOOL" "$icon" --export-image \
    --output-file "$imageset/$3" \
    --platform iOS --rendition "$1" \
    --width "$POINTS" --height "$POINTS" --scale "$2" >/dev/null
}

write_contents() {
  cat >"$imageset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "Logo@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "Logo-Dark@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "Logo@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "Logo-Dark@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

[[ -x "$ICTOOL" ]] || {
  echo "ictool not found at $ICTOOL; install Xcode with Icon Composer." >&2
  exit 1
}

rm -rf "$imageset"
mkdir -p "$imageset"

for scale in 2 3; do
  export_rendition Default "$scale" "Logo@${scale}x.png"
  export_rendition Dark "$scale" "Logo-Dark@${scale}x.png"
done
write_contents

echo "Wrote $imageset"
