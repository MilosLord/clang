# C++ project instructions

Active profile: **{{PROFILE}}** (`std` = general C++23, `unreal` = Unreal Engine C++20).
This file is installed by `MilosLord/clang`. Do not edit it in the project — change it upstream.

## 0. Setup (do this first, once per machine)

```sh
git clone https://github.com/MilosLord/clang ~/clang        # profiles, hook, this file
~/clang/install.sh {{PROFILE}} <project_dir>                 # .clang-format .clang-tidy .clangd .editorconfig AGENTS.md CLAUDE.md + pre-commit hook
python3 -m venv ~/.local/opt/clang-tools && ~/.local/opt/clang-tools/bin/pip install clang-format clang-tidy
ln -s ~/.local/opt/clang-tools/bin/clang-{format,tidy} ~/.local/bin/
```

`~/clang/README.md` documents every rule below and why. The `.clang-format` / `.clang-tidy`
in the project root are the source of truth for style; never argue with them, never override
them locally, never add `// clang-format off` to dodge them.

## 1. Mindset

- Every line is production code. No stubs, no `TODO: implement`, no "simplified for now",
  no placeholder return values. If something cannot be done properly, stop and say so.
- Correctness over speed of delivery. A function you did not verify is a function that is broken.
- You are not done when it compiles. You are done when it is formatted, tidy-clean, built,
  tested, and you have reported exactly what was verified and what was not.
- Do the task as asked. No scope creep, no "while I was here" refactors, no unrequested
  abstractions. Ask when two readings of the spec would produce materially different code.

## 2. Language and standard

- `std` profile: **C++23**. Use it: `std::expected`, `std::print`, deducing this, `std::ranges`,
  `constexpr` everywhere it applies, `[[nodiscard]]` on every non-void function whose result
  matters (that is nearly all of them).
- `unreal` profile: **C++20** as configured by UBT. UE types over std types (`TArray`, `FString`,
  `TMap`, `int32`, `TObjectPtr`). See §6.
- Trailing return type `auto F() -> T` is **mandatory** in `std`, **forbidden on reflected
  members** in `unreal` (UHT cannot parse it on `UFUNCTION`/`UPROPERTY` declarations).
- Naming: PascalCase for everything except macros (`UPPER_CASE`) and 1–2 letter locals
  (`i`, `dt`). `bIsActive` for bools in UE.
- Forbidden: C-style casts, `using namespace` in headers, raw owning pointers, `new`/`delete`
  outside of RAII wrappers, magic numbers (name them), macros for constants, `goto`,
  `std::endl`, exceptions in UE code, silent narrowing conversions.
- Includes: own header first, then groups as the profile sorts them. In UE, `*.generated.h` is
  always the last include of a header. Include what you use — clangd reports unused/missing
  includes (`std` profile) and those are errors to fix, not to ignore.

## 3. Function rules (enforced by clang-tidy + pre-commit hook)

| Limit | Value | Enforced by |
|---|---|---|
| Lines per function | **≤ 30** | `readability-function-size` warning |
| Lines per function, one-shot exception | 30–50 | only with `// NOLINTNEXTLINE(readability-function-size) one-shot: <reason>` on the line above |
| Lines per function, hard cap | **50** | pre-commit hook rejects the commit; NOLINT does not help |
| Cognitive complexity | ≤ 15 | `readability-function-cognitive-complexity` |
| Parameters | ≤ 5 | `readability-function-size` |
| Nesting depth | ≤ 4 | `readability-function-size` |
| Braces on every `if`/`for`/`while` | always | `InsertBraces` + `readability-braces-around-statements` (error) |

A "one-shot" is a straight-line sequence that runs once (setup, registration, a big
`switch` dispatch) where splitting would only hide the order of operations. Nothing else
qualifies. When you hit 30 lines, split by responsibility, not by line count.

One function, one job, one level of abstraction. If you need a comment to separate "phases"
inside a function, those phases are functions.

## 4. Verification — every function, every time

For **each** function you write or modify:

1. **Contracts in the code.** Preconditions and postconditions are asserted, not commented.
   - `std`: `assert(...)` for internal invariants; return `std::expected` / throw for
     recoverable caller errors. Never `assert` on user input.
   - `unreal`: `check(...)` / `checkf(...)` for invariants that must never fail,
     `ensure(...)` / `ensureMsgf(...)` for "should not happen but continue", `IsValid(Obj)`
     before touching any UObject pointer you did not just create.
2. **Every branch exercised by a test.** Aim for **100 % assertion coverage**: every branch,
   every early return, every error path has a test that asserts the observable result.
   Untested branches are listed explicitly in your final report as "not covered", with the
   reason. "Trivial" is not a reason.
3. **Build it.** Not "it should compile" — run the build. `std`: the project's CMake/Make
   target. `unreal`: UBT for the Editor target (`Build.sh <Project>Editor Linux Development`
   or the `milos_unreal` `:MUBuild`). Warnings are errors in your head even if not in the flags.
4. **Run `clang-format -i` and `clang-tidy` on the touched files** and fix everything they
   report before you say you are done. The pre-commit hook will reject unformatted files and
   functions over 50 lines; do not bypass it with `--no-verify`.
5. **Report honestly.** State what you ran and what it printed. If a test fails, paste the
   failure. If you skipped a step, say which and why. Never write "should work".

Test framework: use whatever the project already has. If it has none, `std` → propose Catch2
(single header, no build dance); `unreal` → UE Automation tests (`IMPLEMENT_SIMPLE_AUTOMATION_TEST`),
runnable headless with `-ExecCmds="Automation RunTests <Name>"`. Do not add a framework
without saying so.

## 5. Working style

- Read the surrounding code before editing. Match its idioms; the style config makes the
  formatting identical, but naming of concepts, error handling strategy and ownership model
  come from the existing code, not from your defaults.
- Prefer editing an existing function over adding a parallel one. Prefer deleting code over
  adding it.
- Public signatures and existing tests keep working unless the task says otherwise.
- Small, reviewable diffs. One concern per commit. Commit messages say *why*.
- Never invent an API. If you are not sure a function exists or what it takes, look it up in
  the actual headers (std: cppreference; UE: the engine source on this machine) and cite it.

## 6. Unreal Engine specifics (`unreal` profile only)

- **Follow Epic's documentation and the engine source, in that order, over memory.**
  Docs: https://dev.epicgames.com/documentation/en-us/unreal-engine/ — coding standard:
  https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine
  The engine source is local (`<EngineRoot>/Engine/Source`); grep it before guessing a signature.
- Reflection rules, non-negotiable:
  - every `UObject*` member is `UPROPERTY()` (else GC will free it under you) — prefer `TObjectPtr<T>`;
  - `GENERATED_BODY()` first in the class; `*.generated.h` last include;
  - no trailing return types, no default arguments of non-constant expressions, no `std::` types
    on reflected members;
  - `UFUNCTION` params/returns must be reflection-compatible types.
- Lifetime: never cache raw pointers to actors/components across frames without `TWeakObjectPtr`;
  `IsValid()` not `!= nullptr`; `NewObject`/`SpawnActor`/`CreateDefaultSubobject` — never `new`.
- Always call `Super::` in overridden lifecycle methods (`BeginPlay`, `Tick`, `EndPlay`,
  `PostInitProperties`…). Set `PrimaryActorTick.bCanEverTick` deliberately — ticking is not free.
- Logging: `UE_LOG(LogCategory, Verbosity, TEXT("..."), ...)` with a category declared via
  `DECLARE_LOG_CATEGORY_EXTERN` / `DEFINE_LOG_CATEGORY`. No `printf`, no `std::cout`.
- Module boundaries: a header used by another module is `Public/`, exported with `<MODULE>_API`;
  dependencies go in `*.Build.cs` (`PublicDependencyModuleNames` vs `Private...`), not by
  include path hacks.
- Editor-only code under `#if WITH_EDITOR`; never link `UnrealEd` from a Runtime module.
- Threading: game thread unless proven otherwise; `AsyncTask(ENamedThreads::GameThread, ...)`
  to come back. No UObject access off the game thread.
- After adding/removing source files or changing `Build.cs`, regenerate
  `compile_commands.json` (`RunUBT.sh -Mode=GenerateClangDatabase ...`, copied from the engine
  root to the project) so clangd and clang-tidy see the truth.
- Third-party plugins (`Plugins/AirSim`, `Plugins/CesiumForUnreal`, …) are upstream code: do not
  restyle them, do not "fix" their warnings, keep patches minimal and marked.

## 7. Definition of done — copy this into your final report

```
Files changed: …
Build: <command> → OK / FAIL (paste)
clang-format: clean
clang-tidy: clean / <n> remaining: <list with justification>
Functions > 30 lines: none / <list with one-shot reason>
Tests: <command> → <pass/fail counts>; branches NOT covered: none / <list + reason>
Assertions added: <where, what invariant>
Not verified: none / <what and why>
```
