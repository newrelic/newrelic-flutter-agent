#!/bin/bash

# --- 1. REQUIRE VERSION ---
if [ -z "$PASSED_VERSION" ]; then
    echo "::error::PASSED_VERSION missing"
    exit 1
fi

VERSION=$PASSED_VERSION

# --- 2. PARSE CHANGELOG.MD ---
# Get the full block for this version first
VERSION_BLOCK=$(awk "/^### ${VERSION}/{flag=1;next} /^### [0-9]/{flag=0} flag" CHANGELOG.md)

# Function to extract sub-sections and format bullets
extract_section() {
    local section_name=$1
    # Find the section header, take everything until the next '##' or end of block
    echo "$VERSION_BLOCK" | awk "/## ${section_name}/{flag=1;next} /^## /{flag=0} flag" | \
    grep "^[[:space:]]*-" | sed 's/^[[:space:]]*- /* /'
}

ENHANCEMENTS=$(extract_section "Enhancements")
BUG_FIXES=$(extract_section "Bug Fixes")

# --- 3. CONSTRUCT CONTENT ---
CONTENT=""

if [ -n "$ENHANCEMENTS" ]; then
    CONTENT="${CONTENT}## Enhancements${BASH_RELOAD}\n\n${ENHANCEMENTS}\n\n"
fi

if [ -n "$BUG_FIXES" ]; then
    CONTENT="${CONTENT}## Bug Fixes\n\n${BUG_FIXES}\n\n"
fi

# Fallback if both are empty
if [ -z "$CONTENT" ]; then
    CONTENT="## Improvements\n\n* Updated version.\n\n"
fi

# --- 4. CREATE THE MDX ---
RELEASE_DATE=$(date +%Y-%m-%d)
FINAL_DOWNLOAD_URL="https://pub.dev/packages/newrelic_mobile/versions/${VERSION}"

cat > "release-notes.mdx" << EOF
---
subject: ${AGENT_TITLE}
releaseDate: '${RELEASE_DATE}'
version: ${VERSION}
downloadLink: '${FINAL_DOWNLOAD_URL}'
---

$(echo -e "$CONTENT")

EOF

# --- 5. EXPORT CONTRACT ---
echo "FINAL_VERSION=$VERSION" > release_info.env
echo "✅ Generated release-notes.mdx for version $VERSION"