# clang

Moji clang-format / clang-tidy / clangd profili + pre-commit hook koji ih enforcuje.

```
std/      .clang-format  .clang-tidy  .clangd    generalni C++23 (trailing return, PascalCase)
unreal/   .clang-format  .clang-tidy  .clangd    Unreal Engine (tabovi, Allman, UHT-safe)
hooks/pre-commit                                 format check + hard cap 50 linija po funkciji
install.sh                                       ubaci profil + hook + LLM instrukcije u projekat
llm/AGENTS.md                                    instrukcije za Claude Code / Codex (ide kao AGENTS.md + CLAUDE.md)
samples/                                         referentni kod; CI ga formatira i tidy-uje
.editorconfig
```

## LLM instrukcije

`llm/AGENTS.md` je jedan fajl sa svime sto model treba da zna da ne moras da ponavljas:
C++23 / UE C++20, production-only kod, ≤30 linija po funkciji (30–50 samo one-shot, 50 hard cap),
svaka funkcija verifikovana (asserti u kodu + test po svakoj grani, cilj 100 % assertion coverage),
format + tidy + build + testovi pre "gotovo", UE sekcija (Epic docs i engine source pre memorije,
UPROPERTY/GC, `.generated.h`, bez trailing return na UFUNCTION…), i "definition of done"
sablon za izvestaj. `install.sh` ga kopira kao `AGENTS.md` (Codex) i `CLAUDE.md` (Claude Code)
sa upisanim aktivnim profilom. Menjaj ga ovde, ne u projektu.

## Instalacija u projekat

```sh
./install.sh std    ~/Projects/Foo
./install.sh unreal /opt/starling/StarlingSim
./install.sh unreal /opt/starling/StarlingSim --link    # simlink umesto kopije (prati repo)
./install.sh std    ~/Projects/Foo --force              # pregazi postojece
```

Kopira `.clang-format`, `.clang-tidy`, `.clangd`, `.editorconfig`, `AGENTS.md`, `CLAUDE.md`
u root projekta i `hooks/pre-commit` u `.git/hooks/`. Postojece fajlove ne dira bez `--force`.

Alati (bez sudo, pip wheel):

```sh
python3 -m venv ~/.local/opt/clang-tools
~/.local/opt/clang-tools/bin/pip install clang-format clang-tidy
ln -s ~/.local/opt/clang-tools/bin/clang-{format,tidy} ~/.local/bin/
```

## Pravila koja vaze za SVE profile

| Pravilo | Gde se enforcuje |
|---|---|
| Funkcija ≤ 30 linija | clang-tidy warning u editoru (`readability-function-size`) |
| 30–50 linija | dozvoljeno **samo** uz `// NOLINTNEXTLINE(readability-function-size) one-shot: <razlog>` |
| > 50 linija | **pre-commit odbija commit**. NOLINT ne pomaze — hook proverava kopiju sa izbrisanim NOLINT-ovima |
| Kognitivna kompleksnost ≤ 15 | clang-tidy |
| ≤ 5 parametara, ugnezdenje ≤ 4 | clang-tidy |
| Obavezne viticaste (`if (x) { … }`) | clang-format `InsertBraces` + tidy `braces-around-statements` (error) |
| Fajl formatiran | pre-commit (`--dry-run --Werror` na staged sadrzaju) |
| PascalCase (kao UE) | `readability-identifier-naming`; 1–2 slova (`i`, `dt`) prolaze |
| `bugprone-*`, `performance-*` | clang-tidy; use-after-move, dangling, infinite-loop su error |

Hook se zaobilazi sa `git commit --no-verify` — i onda napisi u poruci zasto.

## std vs unreal

| | std | unreal |
|---|---|---|
| Standard | C++23 | C++20 |
| Uvlacenje | 4 space | tab (Epic) |
| Return tip | `auto F() -> int` **obavezan** (error) | klasican — UHT ne parsira trailing return na `UFUNCTION` |
| Poravnanje | Go-style (assignments, declarations, macros, comments) | iskljuceno — razbija `UPROPERTY` blokove |
| Kratke funkcije u 1 red | da | ne |
| Magic numbers | check ON | OFF (gameplay tuning) |
| Include-i | `"own"` → `<std>` → `<lib.h>` → `<windows/d3d>` | `"own"` → `CoreMinimal` → engine → `*.generated.h` **poslednji** |
| `.clangd` | `-Wall -Wextra -Wpedantic -Wshadow -Wconversion …`, `UnusedIncludes: Strict` | brise MSVC flagove iz UBT db-a; isti sadrzaj koji `milos_unreal` nvim plugin pise |
| Naming ogranicenja | — | prefiksi `A/U/F/E/I/T` i `b` za bool **ne mogu** clang-tidy-jem (ne zna baznu klasu / tip) — code review |

`unreal/.clang-format` ima `StatementMacros` za `UPROPERTY/UFUNCTION/GENERATED_BODY/…`
i `TypenameMacros` za `TObjectPtr/TSubclassOf/…` da formatter ne lomi makroe.

### UE: compile_commands.json

Bez njega je clangd slep (`CoreMinimal.h not found`). UBT ga pise u **engine** root, ne u projekat:

```sh
Engine/Build/BatchFiles/RunUBT.sh -Mode=GenerateClangDatabase \
    -Project=/path/Foo.uproject -Target="FooEditor Linux Development"
cp <EngineRoot>/compile_commands.json /path/Foo/
```

(`milos_unreal` u nvim-u ovo radi sam preko `:MURegen`.)

## CI

`.github/workflows/lint.yml`: oba profila parsiraju, `samples/` su formatirani i prolaze tidy
sa 0 warninga, i hook u praznom repo-u odbija funkciju od 60 linija. Ako promenis profil a
ne azuriras `samples/` — CI pukne. Namerno.

Re-formatiranje sample-ova posle izmene profila:

```sh
clang-format --style=file:std/.clang-format    -i samples/std/*
clang-format --style=file:unreal/.clang-format -i samples/unreal/*.{cpp,h} samples/unreal/stub/CoreMinimal.h
```
