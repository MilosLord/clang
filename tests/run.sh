#!/usr/bin/env bash
# tests/run.sh — testira installer, hook i sample-ove. Pokrece ga CI; radi i lokalno:
#   ./tests/run.sh
# Zahteva: clang-format, clang-tidy, python3, git, c++ i cmake (za sample build).

set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
pass=0; failn=0
ok()   { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { failn=$((failn+1)); printf '  \033[31mFAIL\033[0m %s\n%s\n' "$1" "${2:-}"; }
expect_reject() { # <name> <dir> <commit-msg> <reason-regex>   (commit must FAIL for THAT reason)
    local out; out="$(git -C "$2" commit -q -m "$3" 2>&1)"; local rc=$?
    if [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -qE "$4"; then ok "$1"
    elif [[ $rc -ne 0 ]]; then bad "$1" "    odbijen, ali iz POGRESNOG razloga (trazio: $4):$(printf '\n%s' "$out" | sed 's/^/    /')"
    else bad "$1" "    commit je PROSAO, a nije smeo"; fi
    git -C "$2" reset -q 2>/dev/null || true
}
expect_pass() {
    local out; out="$(git -C "$2" commit -q -m "$3" 2>&1)"; local rc=$?
    if [[ $rc -eq 0 ]]; then ok "$1"; else bad "$1" "$(printf '%s\n' "$out" | sed 's/^/    /')"; fi
}
newrepo() { local d="$work/$1"; mkdir -p "$d"; git -C "$d" init -q; git -C "$d" config user.email t@t; git -C "$d" config user.name t; echo "$d"; }
# fn <file> <lines-in-body> [prefix-lines...]  -> pise formatiranu funkciju
fn() {
    local file="$1" n="$2"; shift 2
    { for p in "$@"; do printf '%s\n' "$p"; done
      printf 'auto Fn() -> int\n{\n    int X = 0;\n'
      for ((i = 0; i < n; i++)); do printf '    X += 1;\n'; done
      printf '    return X;\n}\n'; } > "$file"
    clang-format -i "$file"
}

echo "== installer"
r="$(newrepo inst)"
( cd "$work" && "$here/install.sh" std "$r" >/dev/null )       # cwd != target != repo
[[ -x "$r/.git/hooks/pre-commit" ]] && ok "hook u TARGET/.git/hooks (pokrenut iz drugog cwd-a)" || bad "hook nije u target repo-u"
[[ ! -e "$here/.git/hooks/pre-commit" ]] && ok "hook NIJE u clang/.git/hooks" || bad "hook zavrsio u clang/.git/hooks"
grep -q 'Active profile: \*\*std\*\*' "$r/AGENTS.md" && ! grep -qE '\{\{PROFILE\}\}|\{\{CMAKE\}\}' "$r/AGENTS.md" "$r/CLAUDE.md" && ok "AGENTS/CLAUDE placeholderi zamenjeni" || bad "placeholder"
grep -q '^## Build system — CMake' "$r/AGENTS.md" && ok "std AGENTS.md sadrzi CMake sekciju" || bad "std AGENTS.md nema CMake sekciju"
cmp -s "$r/AGENTS.md" "$r/CLAUDE.md" && ok "AGENTS.md == CLAUDE.md" || bad "AGENTS != CLAUDE"

l="$(newrepo link)"; mkdir -p "$l/Source"
"$here/install.sh" unreal "$l" --link >/dev/null
broken="$(find "$l" -maxdepth 1 -xtype l)"
[[ -z "$broken" ]] && ok "unreal --link: nema pokvarenih simlinkova" || bad "unreal --link: pokvareni simlinkovi" "    $broken"
[[ -L "$l/.clang-format" && -f "$l/.editorconfig" && ! -L "$l/.editorconfig" ]] && ok "--link: .clang-* link, .editorconfig kopija" || bad "--link semantika"
grep -q '^indent_style = tab' "$l/.editorconfig" && ok "unreal .editorconfig ima tabove" || bad "unreal .editorconfig nema tabove"
! grep -qE '^## Build system — CMake|\{\{CMAKE\}\}' "$l/AGENTS.md" && ok "unreal AGENTS.md bez CMake sekcije i bez markera" || bad "unreal AGENTS.md ima CMake sekciju/marker"

echo "== hook"
h="$(newrepo hook)"; "$here/install.sh" std "$h" >/dev/null
fn "$h/A.cpp" 10;  git -C "$h" add A.cpp
expect_pass   "20-line funkcija prolazi" "$h" a
fn "$h/B.cpp" 36 '// NOLINTNEXTLINE(readability-function-size) one-shot: sekvencijalni setup';  git -C "$h" add B.cpp
expect_pass   "40-line one-shot SA razlogom prolazi" "$h" b
fn "$h/C.cpp" 36 '// NOLINTNEXTLINE(readability-function-size)';  git -C "$h" add C.cpp
expect_reject "40-line one-shot BEZ razloga odbijen" "$h" c "nedozvoljen NOLINT"
fn "$h/D.cpp" 55 '// NOLINTNEXTLINE(readability-function-size) one-shot: probam';  git -C "$h" add D.cpp
expect_reject "60-line sa one-shot odbijen (hard cap)" "$h" d "hard cap"
fn "$h/E.cpp" 55 '// NOLINTBEGIN(readability-function-size)';  printf '// NOLINTEND(readability-function-size)\n' >> "$h/E.cpp"; git -C "$h" add E.cpp
expect_reject "NOLINTBEGIN blok odbijen" "$h" e "nedozvoljen NOLINT"
fn "$h/F.cpp" 5 '// NOLINTNEXTLINE';  git -C "$h" add F.cpp
expect_reject "goli NOLINTNEXTLINE (gasi sve) odbijen" "$h" f "nedozvoljen NOLINT"
printf '// NOLINTNEXTLINE(readability-magic-numbers)\nauto G() -> int { return 12345; }\n' > "$h/G.cpp"; clang-format -i "$h/G.cpp"; git -C "$h" add G.cpp
expect_pass   "NOLINT za DRUGI check prolazi" "$h" g
fn "$h/Collision.cpp" 10; printf 'korisnikov fajl — ne diraj\n' > "$h/.precommit_Collision.cpp"; git -C "$h" add Collision.cpp
expect_pass   "hook ne pregazi korisnikov .precommit_* fajl" "$h" collision
if grep -q 'korisnikov fajl' "$h/.precommit_Collision.cpp"; then
    ok "korisnikov .precommit_* fajl sacuvan"
else
    bad "hook je pregazio/obrisao korisnikov .precommit_* fajl"
fi
rm -f "$h/.precommit_Collision.cpp"
printf 'auto  Ugly(  ) -> int {return 1;}\n' > "$h/H.cpp"; git -C "$h" add H.cpp
expect_reject "neformatiran fajl odbijen" "$h" h "nisu formatirani"
{ printf '// NOLINTNEXTLINE(readability-function-size) one-shot: mnogo parametara\n'
  printf 'auto Many(int A, int B, int C, int D, int E, int F, int G) -> int\n{\n    return A + B + C + D + E + F + G;\n}\n'; } > "$h/I.cpp"
clang-format -i "$h/I.cpp"; git -C "$h" add I.cpp
expect_reject "7 parametara sa one-shot NOLINT odbijen (one-shot vazi samo za linije)" "$h" i "prekoracen prag"
printf '#include "NemaMe.h"\nauto J() -> int { return 1; }\n' > "$h/J.cpp"; clang-format -i "$h/J.cpp"; git -C "$h" add J.cpp
expect_reject "fajl koji clang-tidy ne moze da parsira odbijen (fail-closed)" "$h" j "ne moze da analizira"
printf '#!/usr/bin/env bash\nexit 86\n' > "$work/clang-tidy-crash"; chmod +x "$work/clang-tidy-crash"
fn "$h/Crash.cpp" 10; git -C "$h" add Crash.cpp
out="$(CLANG_TIDY="$work/clang-tidy-crash" git -C "$h" commit -q -m crash 2>&1)"; rc=$?
[[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q "statusom 86" && ok "clang-tidy crash odbijen (exit status se ne gubi)" || bad "clang-tidy crash prosao / status izgubljen" "$out"
git -C "$h" reset -q
mkdir -p "$h/build/dev" "$h/build/rel"
for d in dev rel; do printf '[{"directory":"%s","file":"%s/L.cpp","command":"c++ -std=c++23 -c L.cpp"}]\n' "$h" "$h" > "$h/build/$d/compile_commands.json"; done
fn "$h/L.cpp" 10; git -C "$h" add L.cpp
expect_reject "dve compile baze bez izbora odbijeno" "$h" l "vise compile baza"
git -C "$h" config clang.tidyBuildDir build/dev; git -C "$h" add L.cpp
expect_pass   "git config clang.tidyBuildDir resava dve baze" "$h" l2
git -C "$h" config --unset clang.tidyBuildDir; rm -rf "$h/build"
fn "$h/K.cpp" 10; git -C "$h" add K.cpp
out="$(CLANG_TIDY=/nonexistent/clang-tidy git -C "$h" commit -q -m k 2>&1)"; rc=$?
[[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q "nije na PATH" && ok "bez clang-tidy commit odbijen (fail-closed)" || bad "bez clang-tidy commit prosao / pogresan razlog" "$out"
git -C "$h" reset -q
[[ -z "$(find "$h" -name '.precommit_*')" ]] && ok "nema zaostalih .precommit_* fajlova" || bad "zaostali .precommit_*"

echo "== samples"
( cd "$here" && clang-format --style=file:std/.clang-format    --dry-run --Werror samples/std/*.cpp samples/std/*.h ) && ok "std samples formatirani" || bad "std samples nisu formatirani"
( cd "$here" && clang-format --style=file:unreal/.clang-format --dry-run --Werror samples/unreal/*.cpp samples/unreal/*.h samples/unreal/stub/CoreMinimal.h ) && ok "unreal samples formatirani" || bad "unreal samples nisu formatirani"
out="$(cd "$here" && clang-tidy --config-file=std/.clang-tidy --quiet --warnings-as-errors='*' samples/std/Sample.cpp samples/std/SampleTest.cpp -- -std=c++23 -Isamples/std 2>&1 | grep -E 'warning|error')"
[[ -z "$out" ]] && ok "std samples tidy-clean" || bad "std samples tidy" "$out"
out="$(cd "$here" && clang-tidy --config-file=unreal/.clang-tidy --quiet --warnings-as-errors='*' samples/unreal/SampleActor.cpp -- -std=c++20 -Isamples/unreal/stub -Isamples/unreal 2>&1 | grep -E 'warning|error')"
[[ -z "$out" ]] && ok "unreal samples tidy-clean" || bad "unreal samples tidy" "$out"
# RunOnce mora STVARNO biti 30..50 linija da bi sample demonstrirao one-shot slucaj:
out="$(cd "$here" && sed 's/NOLINT/NOLINT_OFF/' samples/std/Sample.cpp > "$work/S.cpp" && clang-tidy --checks='-*,readability-function-size' --config='{CheckOptions: {readability-function-size.LineThreshold: 30}}' --quiet "$work/S.cpp" -- -std=c++23 -Isamples/std 2>&1 | grep -E "RunOnce.*exceeds")"
[[ -n "$out" ]] && ok "sample RunOnce je zaista >30 linija (one-shot demonstriran)" || bad "sample RunOnce je <30 linija — NOLINT u sample-u je laz"
if command -v c++ >/dev/null 2>&1; then
    if ( cd "$here" && c++ -std=c++23 -Wall -Wextra -UNDEBUG -Isamples/std samples/std/Sample.cpp samples/std/SampleTest.cpp -o "$work/SampleTest" ) && "$work/SampleTest"; then
        ok "SampleTest build + run"
    else
        bad "SampleTest build/run"
    fi
else
    printf '  SKIP c++ nije na PATH-u (SampleTest)\n'
fi
if command -v cmake >/dev/null 2>&1 && command -v c++ >/dev/null 2>&1; then
    cmake_out="$work/cmake.out"; cp -r "$here/samples/std" "$work/cmake"
    # workflow preset = configure + build + test kroz CMakePresets.json; ako preset istrune, ovo pada
    if ( cd "$work/cmake" && cmake --workflow --preset dev ) >"$cmake_out" 2>&1 \
        && [[ -f "$work/cmake/build/dev/compile_commands.json" ]]; then
        ok "CMake sample: workflow preset 'dev' (configure + build + CTest) + compile_commands.json"
    else
        bad "CMake sample workflow preset" "$(sed 's/^/    /' "$cmake_out")"
    fi
else
    printf '  SKIP cmake/c++ nije na PATH-u (CMake sample)\n'
fi

echo
printf 'passed: %d  failed: %d\n' "$pass" "$failn"
[[ $failn -eq 0 ]]
