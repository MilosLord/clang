#!/usr/bin/env bash
# install.sh — ubaci profil u projekat.
#
#   ./install.sh std    ~/Projects/Foo          # generalni C++23
#   ./install.sh unreal /opt/starling/StarlingSim
#   ./install.sh unreal /opt/starling/StarlingSim --link   # simlink umesto kopije
#
# Radi:
#   * kopira (ili simlinkuje) <profil>/.clang-format .clang-tidy .clangd u root projekta
#   * kopira .editorconfig (za unreal: prepisuje C++ blok na tabove)
#   * instalira hooks/pre-commit u .git/hooks/ ako je projekat git repo
#
# Postojece fajlove NE pregazi bez --force.

set -euo pipefail

usage() { sed -n '2,15p' "$0"; exit 1; }

profile="${1:-}"; target="${2:-}"; shift 2 2>/dev/null || usage
mode="copy"; force=0
for a in "$@"; do
    case "$a" in
        --link)  mode="link" ;;
        --force) force=1 ;;
        *) echo "nepoznat flag: $a"; usage ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "$profile" == "std" || "$profile" == "unreal" ]] || { echo "profil mora biti std|unreal"; usage; }
[[ -d "$target" ]] || { echo "nema direktorijuma: $target"; exit 1; }
target="$(cd "$target" && pwd)"

put() {  # put <src> <dst>
    local src="$1" dst="$2"
    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ $force -eq 0 ]]; then
            echo "  skip   $(basename "$dst")  (postoji; --force da pregazis)"
            return
        fi
        rm -f "$dst"
    fi
    if [[ "$mode" == "link" ]]; then
        ln -s "$src" "$dst"; echo "  link   $(basename "$dst") -> $src"
    else
        cp "$src" "$dst";    echo "  copy   $(basename "$dst")"
    fi
}

echo "profil: $profile  ->  $target  ($mode)"
for f in .clang-format .clang-tidy .clangd; do
    put "$here/$profile/$f" "$target/$f"
done

# .editorconfig: za unreal C++ ide na tabove
if [[ "$profile" == "unreal" ]]; then
    tmp="$(mktemp)"
    sed -e '/^# std profil/,/^max_line_length = 120$/{
        s/^indent_style = space$/indent_style = tab/
        s/^max_line_length = 120$/max_line_length = 140/
        s/^# std profil: 4 space$/# unreal profil: tabovi/
    }' "$here/.editorconfig" > "$tmp"
    put "$tmp" "$target/.editorconfig"; rm -f "$tmp"
else
    put "$here/.editorconfig" "$target/.editorconfig"
fi

# git hook
if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    hooks_dir="$(git -C "$target" rev-parse --git-path hooks)"
    mkdir -p "$hooks_dir"
    dst="$hooks_dir/pre-commit"
    if [[ -e "$dst" && $force -eq 0 ]]; then
        echo "  skip   .git/hooks/pre-commit (postoji; --force da pregazis)"
    else
        cp "$here/hooks/pre-commit" "$dst"; chmod +x "$dst"
        echo "  hook   .git/hooks/pre-commit"
    fi
else
    echo "  (nije git repo — hook preskocen)"
fi

# UE: podseti na compile_commands.json
if [[ "$profile" == "unreal" ]] && [[ ! -f "$target/compile_commands.json" ]]; then
    up="$(find "$target" -maxdepth 1 -name '*.uproject' | head -1)"
    echo
    echo "  NAPOMENA: nema compile_commands.json u rootu. clangd ce biti slep dok ga ne generises:"
    echo "    RunUBT.sh -Mode=GenerateClangDatabase -Project=${up:-<X>.uproject} -Target=\"<X>Editor Linux Development\""
    echo "  UBT ga pise u ENGINE root; kopiraj ga u projekat (nvim milos_unreal :MURegen to radi sam)."
fi
echo "gotovo."
