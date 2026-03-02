#!/bin/bash
# Fetch all library dependencies from GitHub into libs/
# Reads externals from .pkgmeta and clones via git
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBS_DIR="$SCRIPT_DIR/libs"

# Parse .pkgmeta externals block
# Format:
#   libs/Name:
#     url: https://github.com/owner/repo
#     tag: latest
parse_externals() {
    local current_path=""
    local current_url=""
    local in_externals=false

    while IFS= read -r line; do
        # Detect externals block start/end
        if [[ "$line" =~ ^externals: ]]; then
            in_externals=true
            continue
        fi
        if $in_externals && [[ "$line" =~ ^[a-z] ]]; then
            # Non-indented line means we left the externals block
            # Emit last entry if pending
            if [[ -n "$current_path" && -n "$current_url" ]]; then
                echo "$current_path|$current_url"
            fi
            break
        fi

        if ! $in_externals; then continue; fi

        # Match path line: "  libs/Foo:"
        if [[ "$line" =~ ^[[:space:]]+(libs/[^:]+): ]]; then
            # Emit previous entry
            if [[ -n "$current_path" && -n "$current_url" ]]; then
                echo "$current_path|$current_url"
            fi
            current_path="${BASH_REMATCH[1]}"
            current_url=""
        fi

        # Match url line: "    url: https://..."
        if [[ "$line" =~ url:[[:space:]]+(https://[^[:space:]]+) ]]; then
            current_url="${BASH_REMATCH[1]}"
        fi
    done < "$SCRIPT_DIR/.pkgmeta"

    # Emit last entry
    if [[ -n "$current_path" && -n "$current_url" ]]; then
        echo "$current_path|$current_url"
    fi
}

# Resolve "tag: latest" — find the newest tag, fall back to default branch
resolve_ref() {
    local url="$1"
    # Try to find the latest tag by version sort
    local latest_tag
    latest_tag=$(git ls-remote --tags --sort=-v:refname "$url" 2>/dev/null \
        | grep -v '\^{}' \
        | head -1 \
        | sed 's/.*refs\/tags\///')

    if [[ -n "$latest_tag" ]]; then
        echo "$latest_tag"
    else
        echo ""  # Will use default branch
    fi
}

clone_lib() {
    local path="$1"
    local url="$2"
    local target="$LIBS_DIR/${path#libs/}"

    # Always fresh clone (libs/ is gitignored, not precious)
    if [[ -d "$target" ]]; then
        rm -rf "$target"
    fi

    echo "  Cloning $path..."
    local ref
    ref=$(resolve_ref "$url")
    if [[ -n "$ref" ]]; then
        git clone --quiet --depth 1 --branch "$ref" "$url" "$target"
    else
        git clone --quiet --depth 1 "$url" "$target"
    fi

    # Clean up .git directory (not needed at runtime)
    rm -rf "$target/.git"
}

# Post-clone fixes for libraries cloned from GitHub mirrors
# These repos have issues that the CurseForge packager normally handles
post_clone_cleanup() {
    echo ""
    echo "Running post-clone cleanup..."

    # Remove bundled LibStub/CallbackHandler from non-Ace3 libs
    # (Ace3's copies are the authoritative ones, loaded first via embeds.xml)
    local bundled_dirs=(
        "$LIBS_DIR/LibSharedMedia-3.0/LibStub"
        "$LIBS_DIR/LibSharedMedia-3.0/CallbackHandler-1.0"
        "$LIBS_DIR/LibWindow-1.1/LibStub.lua"
        "$LIBS_DIR/LibDeflate/LibStub"
    )
    for item in "${bundled_dirs[@]}"; do
        if [[ -e "$item" ]]; then
            rm -rf "$item"
            echo "  Removed bundled: ${item#$LIBS_DIR/}"
        fi
    done

    # Remove test/example directories
    local test_dirs=(
        "$LIBS_DIR/Ace3/tests"
        "$LIBS_DIR/LibDeflate/tests"
        "$LIBS_DIR/LibDeflate/examples"
        "$LIBS_DIR/LibDeflate/docs"
        "$LIBS_DIR/LibSharedMedia-3.0/tests"
    )
    for dir in "${test_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            echo "  Removed: ${dir#$LIBS_DIR/}"
        fi
    done

    # Fix SVN $Revision$ keywords that don't expand from GitHub clones
    # LibWindow-1.1 uses $Revision$ for its MINOR version — set to a high number
    local libwindow="$LIBS_DIR/LibWindow-1.1/LibWindow-1.1/LibWindow-1.1.lua"
    if [[ -f "$libwindow" ]] && grep -q '\$Revision\$' "$libwindow"; then
        sed -i 's/\$Revision\$/99/' "$libwindow"
        echo "  Fixed: LibWindow-1.1 \$Revision\$ → 99"
    fi

    # Fix SharedMediaWidgets: LoadAddOn() was removed in WoW 11.0 (The War Within)
    # Replace with C_AddOns.LoadAddOn fallback
    local smw_proto="$LIBS_DIR/AceGUI-3.0-SharedMediaWidgets/AceGUI-3.0-SharedMediaWidgets/prototypes.lua"
    if [[ -f "$smw_proto" ]] && grep -q '^LoadAddOn(' "$smw_proto"; then
        sed -i 's/^LoadAddOn(/(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn)(/' "$smw_proto"
        echo "  Fixed: SharedMediaWidgets LoadAddOn → C_AddOns.LoadAddOn fallback"
    fi

    # Fix SharedMediaWidgets: $Revision$ / @project-revision@ for version
    if [[ -f "$smw_proto" ]] && grep -q '@project-revision@' "$smw_proto"; then
        sed -i 's/@project-revision@/99/' "$smw_proto"
        echo "  Fixed: SharedMediaWidgets @project-revision@ → 99"
    fi
}

echo "Fetching libraries into $LIBS_DIR..."
echo ""

mkdir -p "$LIBS_DIR"

while IFS='|' read -r path url; do
    clone_lib "$path" "$url"
done < <(parse_externals)

post_clone_cleanup

echo ""
echo "Done. Libraries installed:"
ls -1d "$LIBS_DIR"/*/ 2>/dev/null | sed "s|$LIBS_DIR/|  libs/|"
