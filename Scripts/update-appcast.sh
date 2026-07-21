#!/bin/bash
# Signs a freshly-built release dmg with Sparkle's generate_appcast and merges
# the result into appcast.xml, without disturbing any existing entries.
#
# generate_appcast rewrites the enclosure URL (and drops the release-notes/
# path prefix) for every dmg it finds in the directory it's pointed at - if
# that's appcast.xml's own directory (which holds every past release's dmg
# path, not the files themselves, but generate_appcast wants the actual dmgs
# present to hash/sign), it clobbers older entries' URLs to match whatever's
# there now (see BACKLOG.md's generate_appcast entry - this bit every release
# through 0.4.0, requiring a manual XML fix each time). Pointing it at a
# throwaway directory containing ONLY the new dmg sidesteps this: it can only
# ever emit the one entry we actually want, and nothing else is there to
# clobber.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(cat VERSION)}"
DMG_PATH="${2:-.build/Ramona-${VERSION}.dmg}"
REPO_URL="https://github.com/LexxaRRioo/ramona-game"

if [ ! -f "$DMG_PATH" ]; then
    echo "error: $DMG_PATH not found - build it first (Scripts/build-release-dmg.sh)" >&2
    exit 1
fi

if [ ! -f "release-notes/Ramona-${VERSION}.md" ]; then
    echo "error: release-notes/Ramona-${VERSION}.md not found - write release notes before updating the appcast" >&2
    exit 1
fi

GENERATE_APPCAST=""
for candidate in $(find .build -iname "generate_appcast" -type f 2>/dev/null); do
    if [ -x "$candidate" ]; then
        GENERATE_APPCAST="$candidate"
        break
    fi
done
if [ -z "$GENERATE_APPCAST" ]; then
    echo "error: generate_appcast binary not found under .build - run 'swift build' first to resolve the Sparkle package" >&2
    exit 1
fi

DROPBOX=$(mktemp -d)
trap 'rm -rf "$DROPBOX"' EXIT
cp "$DMG_PATH" "$DROPBOX/"
"$GENERATE_APPCAST" "$DROPBOX" >&2

ED_SIGNATURE=$(grep -o 'sparkle:edSignature="[^"]*"' "$DROPBOX/appcast.xml" | head -1 | sed -E 's/sparkle:edSignature="(.*)"/\1/')
PUB_DATE=$(grep -o '<pubDate>[^<]*</pubDate>' "$DROPBOX/appcast.xml" | head -1 | sed -E 's/<pubDate>(.*)<\/pubDate>/\1/')
LENGTH=$(stat -f%z "$DMG_PATH")

if [ -z "$ED_SIGNATURE" ] || [ -z "$PUB_DATE" ]; then
    echo "error: couldn't parse generate_appcast's output" >&2
    exit 1
fi

ENTRY="        <item>
            <title>${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
            <link>${REPO_URL}</link>
            <sparkle:releaseNotesLink>https://raw.githubusercontent.com/LexxaRRioo/ramona-game/main/release-notes/Ramona-${VERSION}.md</sparkle:releaseNotesLink>
            <enclosure url=\"${REPO_URL}/releases/download/v${VERSION}/Ramona-${VERSION}.dmg\" length=\"${LENGTH}\" type=\"application/octet-stream\" sparkle:edSignature=\"${ED_SIGNATURE}\"/>
        </item>"

python3 - "$ENTRY" <<'PYEOF'
import sys
entry = sys.argv[1]
path = "appcast.xml"
with open(path) as f:
    content = f.read()
marker = "<title>Ramona</title>\n"
idx = content.index(marker) + len(marker)
content = content[:idx] + entry + "\n" + content[idx:]
with open(path, "w") as f:
    f.write(content)
PYEOF

echo "Inserted ${VERSION} into appcast.xml"
