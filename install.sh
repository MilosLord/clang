#!/usr/bin/env bash
# install.sh — ubaci profil u projekat.
#
#   ./install.sh std    ~/Projects/Foo          # generalni C++23
#   ./install.sh unreal /opt/starling/StarlingSim
#   ./install.sh unreal /opt/starling/StarlingSim --link   # .clang-* kao simlink na repo
#   ./install.sh std    ~/Projects/Foo --force              # pregazi postojece
#
# Radi:
#   * .clang-format .clang-tidy .clangd  -> root projekta  (kopija, ili simlink sa --link)
#   * .editorconfig                      -> UVEK kopija (za unreal se generise: tabovi)
#   * AGENTS.md + CLAUDE.md              -> UVEK kopija (upisan profil; std += llm/cmake.md, unreal += llm/unreal.md)
#   * hooks/pre-commit                   -> <git-dir>/hooks/pre-commit, UVEK kopija
#
# --link dakle prati repo samo za tri .clang-* fajla; ostalo je snapshot.
# Postojece fajlove NE pregazi bez --force.

set -euo pipefail

usage() { sed -n '2,17p' "$0"; exit 1; }

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

# put <src> <dst> <copy|link>
put() {
    local src="$1" dst="$2" how="$3"
    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ $force -eq 0 ]]; then
            echo "  skip   $(basename "$dst")  (postoji; --force da pregazis)"
            return
        fi
        rm -f "$dst"
    fi
    if [[ "$how" == "link" ]]; then
        ln -s "$src" "$dst"; echo "  link   $(basename "$dst") -> $src"
    else
        cp "$src" "$dst";    echo "  copy   $(basename "$dst")"
    fi
}

echo "profil: $profile  ->  $target  ($mode)"
for f in .clang-format .clang-tidy .clangd; do
    put "$here/$profile/$f" "$target/$f" "$mode"
done

# .editorconfig: generisan za unreal (tabovi), pa uvek kopija.
tmp="$(mktemp)"
if [[ "$profile" == "unreal" ]]; then
    sed -e '/^# std profil/,/^max_line_length = 120$/{
        s/^indent_style = space$/indent_style = tab/
        s/^max_line_length = 120$/max_line_length = 140/
        s/^# std profil: 4 space$/# unreal profil: tabovi/
    }' "$here/.editorconfig" > "$tmp"
else
    cp "$here/.editorconfig" "$tmp"
fi
put "$tmp" "$target/.editorconfig" copy
rm -f "$tmp"

# LLM instrukcije: AGENTS.md (Codex & co) + CLAUDE.md (Claude Code), isti sadrzaj,
# sa upisanim aktivnim profilom -> uvek kopija.
tmp="$(mktemp)"
# Markeri se ZAMENJUJU sadrzajem pri instalaciji (ne referencom — agenti nepouzdano prate
# "see llm/x.md"; finalni fajl mora biti samodovoljan):
#   <!-- {{CMAKE}} -->  -> llm/cmake.md   samo za std    (unreal gradi UBT)
#   <!-- {{UNREAL}} --> -> llm/unreal.md  samo za unreal (u std bi UPROPERTY/.generated.h/bez
#                                          trailing return bili direktna kontradikcija sa STYLE)
if [[ "$profile" == "std" ]]; then
    sed -e "s/{{PROFILE}}/$profile/g" \
        -e "/<!-- {{CMAKE}} -->/{r $here/llm/cmake.md" -e "d}" \
        -e "/<!-- {{UNREAL}} -->/d" "$here/llm/AGENTS.md" > "$tmp"
else
    sed -e "s/{{PROFILE}}/$profile/g" \
        -e "/<!-- {{UNREAL}} -->/{r $here/llm/unreal.md" -e "d}" \
        -e "/<!-- {{CMAKE}} -->/d" "$here/llm/AGENTS.md" > "$tmp"
fi
for name in AGENTS.md CLAUDE.md; do
    put "$tmp" "$target/$name" copy
done
rm -f "$tmp"

# git hook — apsolutna putanja, inace bi relativni ".git/hooks" pokazivao na cwd
# (tj. na OVAJ repo kad se install.sh pokrene odavde).
if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    hooks_dir="$(git -C "$target" rev-parse --path-format=absolute --git-path hooks)"
    mkdir -p "$hooks_dir"
    dst="$hooks_dir/pre-commit"
    if [[ -e "$dst" && $force -eq 0 ]]; then
        echo "  skip   $dst (postoji; --force da pregazis)"
    else
        cp "$here/hooks/pre-commit" "$dst"; chmod +x "$dst"
        echo "  hook   $dst"
    fi
else
    echo "  (nije git repo — hook preskocen)"
fi

# UE: podseti na compile_commands.json
if [[ "$profile" == "unreal" ]] && [[ ! -f "$target/compile_commands.json" ]]; then
    up="$(find "$target" -maxdepth 1 -name '*.uproject' | head -1)"
    echo
    echo "  NAPOMENA: nema compile_commands.json u rootu. clangd ce biti slep, a pre-commit"
    echo "  hook ce ODBIJATI UE fajlove (ne moze da ih parsira bez engine include-a):"
    echo "    RunUBT.sh -Mode=GenerateClangDatabase -Project=${up:-<X>.uproject} -Target=\"<X>Editor Linux Development\""
    echo "  UBT ga pise u ENGINE root; kopiraj ga u projekat (nvim milos_unreal :MURegen to radi sam)."
fi
echo "gotovo."
