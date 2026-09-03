# clang

Moji clang-format / clang-tidy / clangd profili + pre-commit hook koji ih enforcuje.

```
std/      .clang-format  .clang-tidy  .clangd    generalni C++23 (trailing return, PascalCase)
unreal/   .clang-format  .clang-tidy  .clangd    Unreal Engine (tabovi, Allman, UHT-safe)
hooks/pre-commit                                 fail-closed: format, NOLINT disciplina, hard cap 50, ostali pragovi
tests/run.sh                                     installer + hook + samples; isto sto CI pokrece
install.sh                                       ubaci profil + hook + LLM instrukcije u projekat
llm/AGENTS.md                                    instrukcije za Claude Code / Codex (ide kao AGENTS.md + CLAUDE.md)
llm/cmake.md                                     CMake sekcija; install.sh je ulepi samo u std profil
llm/unreal.md                                    UE sekcija; install.sh je ulepi samo u unreal profil
samples/                                         referentni kod + moderni CMake; CI gradi na Linux/Windows/macOS
.editorconfig
```

## LLM instrukcije

`llm/AGENTS.md` je jedan fajl sa svime sto model treba da zna da ne moras da ponavljas.
Pravila su u tri nivoa da model zna sta sme da prekrsi kad se sudare:
**MUST** (tacnost, ownership, production-only, minimalan scope, prati postojeci kod, ne izmisljaj API,
verifikuj pre izvestaja, izvestavaj posteno) → **SHOULD** (≤30 linija / one-shot 30–50, asserti za
*stvarne* invariante, testovi po granama koje pozivalac vidi + eksplicitna lista nepokrivenog, jezik
profila kad pojednostavljuje a ne ritualno) → **STYLE** (alati su vlasnici). UE sekcija: hijerarhija
autoriteta (engine source ove verzije → Epic standard → docs), tabela lifetime obrazaca
(`TObjectPtr`/`TWeakObjectPtr`/subobject/raw lokalni), refleksija, `Super::` osim kad ugovor kaze
drugacije, threading kao "nista nije thread-safe dok API ne kaze", moduli, tooling. Na kraju
"Done" sablon za izvestaj. `install.sh` ga kopira kao `AGENTS.md` (Codex) i `CLAUDE.md` (Claude Code)
sa upisanim aktivnim profilom. Markeri se pri instalaciji **zamenjuju sadrzajem** (ne referencom —
agent koji dobije "see llm/x.md" ga cesto ne otvori; finalni fajl je samodovoljan):
`<!-- {{CMAKE}} -->` → `llm/cmake.md` samo za `std`, `<!-- {{UNREAL}} -->` → `llm/unreal.md` samo za
`unreal`. Nije samo sum: 55 linija UE pravila u cistom C++23 projektu su direktna kontradikcija sa
STYLE sekcijom (trailing return obavezan vs. zabranjen, UPROPERTY, `.generated.h`).
Menjaj ovde, ne u projektu.

Za sto manje revizija model pre prve izmene mapira ugovor, implementaciju, pozivaoce, testove i
build/CI putanju, pa u istom change-u zatvara svaki pogođeni caller, mock, config,
serialization/reflection boundary i dokumentaciju. Value semantics i stack su default; heap
postoji samo zbog konkretnog lifetime/size/stable-address/polymorphism razloga, bez
`unique_ptr`/`shared_ptr` over-engineeringa. Veliki/runtime-neograniceni bufferi i `UObject` su
namerni izuzeci.

## Instalacija u projekat

```sh
./install.sh std    ~/Projects/Foo
./install.sh unreal /opt/starling/StarlingSim
./install.sh unreal /opt/starling/StarlingSim --link    # .clang-* kao simlink na repo
./install.sh std    ~/Projects/Foo --force              # pregazi postojece
```

Kopira `.clang-format`, `.clang-tidy`, `.clangd`, `.editorconfig`, `AGENTS.md`, `CLAUDE.md`
u root projekta i `hooks/pre-commit` u `<git-dir>/hooks/` (apsolutna putanja — radi iz bilo kog cwd-a).
Postojece fajlove ne dira bez `--force`. `--link` simlinkuje **samo** tri `.clang-*` fajla;
`.editorconfig` (generisan za unreal), `AGENTS.md`/`CLAUDE.md` (upisan profil) i hook su uvek kopije.
Pazi: `--force` pregazi i lokalno prilagodjen `.clangd` (npr. fragment koji gasi tidy za third-party plugine).

Alati (bez sudo, pip wheel):

```sh
python3 -m venv ~/.local/opt/clang-tools
~/.local/opt/clang-tools/bin/pip install --upgrade clang-format clang-tidy
ln -s ~/.local/opt/clang-tools/bin/clang-{format,tidy} ~/.local/bin/
```

Lokalno verzije nisu zakucane: koristi novije alate ako oba configa parsiraju i
`./tests/run.sh` prolazi. Po mogucnosti drzi clang-format/clang-tidy/clangd na istom LLVM majoru;
PyPI release ritam to ponekad ne dozvoljava, pa uvek prijavi stvarne verzije. CI zasebno pin-uje
poslednji testirani baseline radi reproduktivnosti; taj pin nije zabrana novijeg toolchain-a.

## Pravila koja vaze za SVE profile

| Pravilo | Gde se enforcuje |
|---|---|
| Funkcija ≤ 30 linija | clang-tidy warning u editoru (`readability-function-size`) |
| 30–50 linija | dozvoljeno **samo** uz `// NOLINTNEXTLINE(readability-function-size) one-shot: <razlog>` |
| > 50 linija | **pre-commit odbija commit**. NOLINT ne pomaze — hook proverava kopiju sa izbrisanim NOLINT-ovima |
| ≤ 5 parametara, nesting ≤ 4, branches ≤ 8, variables ≤ 12 | clang-tidy **i** hook na kopiji bez NOLINT-a — one-shot izuzetak vazi samo za broj linija |
| NOLINT disciplina | hook: `NOLINT*` bez liste check-ova (gasi sve) je zabranjen; za function-size jedini oblik je one-shot sa razlogom |
| Fail-closed | hook: nema clang-format/clang-tidy/python3 → odbijeno; clang-tidy ne moze da parsira fajl (UE bez `compile_commands.json`) → odbijeno |
| Kognitivna kompleksnost ≤ 15 | clang-tidy |
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

## Moderni CMake / platforme

LLM instrukcije ne govore "uvek najnoviji CMake" naslepo. Model prvo cita podrzane CI image-e,
toolchain fajlove, preset-e i dokumentaciju projekta. Za novi projekat postavlja:

```cmake
cmake_minimum_required(VERSION <najnoviji-na-najstarijem-podrzanom-sistemu>...<najnoviji-testiran>)
```

Donja granica je stvarni compatibility floor, a gornja ukljucuje moderne policy-je bez blokiranja
novijeg CMake-a. Postojecem projektu se minimum ne podize radi jedne convenience komande bez
namernog prekida podrske i istovremene izmene CI/docs.

`samples/std/CMakeLists.txt` demonstrira target-based CMake: `target_compile_features(cxx_std_23)`,
ispravan `PRIVATE/PUBLIC/INTERFACE`, bez globalnih flagova, MSVC/clang-cl naspram GNU/Clang
frontend flagova, CTest i bez transitive `-Werror`. `CMakePresets.json` je prenosiv i ne zakucava
generator: bira native default, dok build/test preset ispravno prosledjuje `Debug` i multi-config
generatorima. Machine-local putanje pripadaju u nepraceni `CMakeUserPresets.json`.

CI configure/build/test-uje isti sample na `ubuntu-latest`, `windows-latest` i `macos-latest`;
tek posle toga sme da se zove cross-platform. Za clang tooling na Windows-u, gde Visual Studio
generator ne emituje `compile_commands.json`, instrukcije traze poseban Ninja tooling preset uz
zadrzan native MSVC build kao autoritativnu proveru.

`compile_commands.json` se ne dobija sam od sebe: instrukcije traze
`"CMAKE_EXPORT_COMPILE_COMMANDS": true` u `cacheVariables` configure preseta (kao u
`samples/std/CMakePresets.json`), a ne `set(... CACHE ...)` u `CMakeLists.txt` — to je alat
developera, ne deo build ugovora koji `add_subdirectory`/`FetchContent` potrosac nasledjuje.
Postuje ga samo Makefile/Ninja generator; Visual Studio i Xcode cute i ne emituju nista.

Hook nalazi bazu u rootu i u uobicajenim/preset build direktorijumima. Ako postoji vise build
stabala, ne pogadja nasumicno nego odbija; izaberi jednom po repo-u:
`git config clang.tidyBuildDir build/<preset>` (ili po commitu `CLANG_TIDY_BUILD_DIR=... git commit`).
Oba prihvataju direktorijum ili direktnu putanju do `compile_commands.json`.

### UE: lekcije iz prakse (u AGENTS-u, sekcija "Build & run")

Iz prave sesije na StarlingSim-u, sve provereno: `Build.sh` traži `-Project=/abs/… -WaitMutex`;
build puca sa besmislenom hot-reload porukom ako je Editor otvoren (`pgrep -x UnrealEditor` pre
svakog builda); UE odbija root (`Refusing to run with the root privileges` + core dump); headless
traži `-RenderOffscreen -Unattended -NoSound -nosplash`; **Editor-clean ≠ package-clean** — dinamički
učitani Blueprint-ovi (AirSim) ispadaju iz cook-a bez `+DirectoriesToAlwaysCook`, vidi se tek pri
startu paketa; `LogConfig: Set CVar` znači *postavljeno*, ne *primenjeno* — meri efekat; editor Python:
`unreal.log()` ne ide na stdout u commandlet režimu, `new_level()` ćuti ako mapa postoji, a za math
strukture **uvek keyword argumenti** — `Rotator` ima tri razlicita redosleda (C++ `Pitch,Yaw,Roll`,
reflektovana polja `Pitch,Yaw,Roll`, Python pozicioni `roll,pitch,yaw`), pa prepisivanje iz headera
daje tiho pogresnu rotaciju. Python redosled se ne vidi iz izvora (genericki
`TPyWrapperInlineStructFactory<FRotator>`), pa je izmeren; `tests/unreal/rotator_order_test.py`
to fiksira — pokrece se rucno na masini sa engine-om (komanda u zaglavlju skripte), CI ga samo
`py_compile`-uje. Done šablon ima poseban red za cook/package.

### UE: compile_commands.json

Bez njega je clangd slep (`CoreMinimal.h not found`). UBT ga pise u **engine** root, ne u projekat:

```sh
Engine/Build/BatchFiles/RunUBT.sh -Mode=GenerateClangDatabase \
    -Project=/path/Foo.uproject -Target="FooEditor Linux Development"
cp <EngineRoot>/compile_commands.json /path/Foo/
```

(`milos_unreal` u nvim-u ovo radi sam preko `:MURegen`.)

## Testovi / CI

`./tests/run.sh` (isto pokrece `.github/workflows/lint.yml`, sa reproduktivnim testiranim baseline-om
`clang-format==23.1.0`, `clang-tidy==22.1.8`): installer iz tudjeg cwd-a stavlja hook u pravi repo, `unreal --link` nema
pokvarenih simlinkova, placeholder zamenjen; hook — 20 linija prolazi, 40 one-shot sa razlogom
prolazi, bez razloga pada, 60 sa one-shot pada (hard cap), `NOLINTBEGIN` pada, goli `NOLINTNEXTLINE`
pada, NOLINT za drugi check prolazi, neformatiran pada, 7 parametara sa one-shot pada, neparsirljiv
fajl pada, clang-tidy crash/nenulti status pada, bez clang-tidy pada, collision-safe temp kopija ne
dira korisnikov istoimeni fajl i nema zaostalih temp fajlova; samples — formatirani, tidy-clean sa
`--warnings-as-errors=*`, `RunOnce` je *stvarno* >30 linija, `SampleTest` se kompajlira i prolazi,
CMake `--workflow --preset dev` (configure + build + CTest) prolazi i emituje `compile_commands.json`; dve compile baze bez izbora padaju, `git config clang.tidyBuildDir` ih resava.
Ako promenis profil a ne azuriras `samples/` — pukne. Namerno.

`samples/std/` prati `llm/AGENTS.md` doslovno: `[[nodiscard]]` gde rezultat nosi informaciju,
`assert` samo za interne invariante, `std::expected` za greske pozivaoca, `SampleTest.cpp` sa
assertom po grani i listom pokrivenog u zaglavlju.

Re-formatiranje sample-ova posle izmene profila:

```sh
clang-format --style=file:std/.clang-format    -i samples/std/*.cpp samples/std/*.h
clang-format --style=file:unreal/.clang-format -i samples/unreal/*.{cpp,h} samples/unreal/stub/CoreMinimal.h
```
