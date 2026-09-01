# C++ project instructions

Active profile: **{{PROFILE}}** (`std` = general C++23, `unreal` = Unreal Engine C++20).
Installed from `MilosLord/clang`; the `.clang-format` / `.clang-tidy` / `.clangd` next to this
file are the source of truth for style and lint. Do not edit any of them here — change upstream.

Rules are tiered. When they collide, a higher tier wins:

- **MUST** — correctness, ownership, compatibility, verification, scope. Never traded away.
- **SHOULD** — structure and testing defaults. Deviate only with a stated reason.
- **STYLE** — owned by the tools. You do not reason about it, you run `clang-format`/`clang-tidy`.

## MUST

1. **Correct over fast.** No UB, no data races, no narrowing that loses data silently, no
   unchecked assumptions about input that comes from outside the module.
2. **Ownership and lifetime are explicit.** Every pointer has a known owner. No raw owning
   pointers, no `new`/`delete` outside RAII. (UE specifics in §UE.)
3. **Production code only.** No stubs, no `TODO: implement`, no placeholder returns, no
   "simplified for now". If it cannot be done properly, stop and say so.
4. **Minimal scope.** Do what was asked. No drive-by refactors, no renames, no new
   abstractions the task did not need. Public signatures and existing tests keep working
   unless the task says otherwise. Ask when two readings of the spec give materially
   different code.
5. **Follow the existing code.** Its error model (`std::expected` vs exceptions vs
   error codes), its ownership pattern, its naming of concepts. Do not import your defaults
   into a codebase that already made those choices. The style config makes formatting
   identical; everything else you learn by reading the neighbours first.
6. **Never invent an API.** If unsure a function exists or what it takes, open the header:
   `std` → cppreference / the installed standard library; `unreal` → the engine source on
   this machine (`<EngineRoot>/Engine/Source`), which outranks online docs for signatures.
7. **Verify before you report** — per changed function:
   - build actually run (`std`: the project's target; `unreal`: UBT Editor target);
   - `clang-format -i` and `clang-tidy` on touched files, findings fixed;
   - tests run; the pre-commit hook passes (never `--no-verify`).
8. **Report honestly**, in the §Done format: what ran, what it printed, what was not
   verified and why. "Should work" is not a status.

## SHOULD

- **Functions ≤ 30 lines**, one job, one level of abstraction. 30–50 only for a genuine
  one-shot (straight-line setup / registration / dispatch where splitting would hide the
  order) and only marked `// NOLINTNEXTLINE(readability-function-size) one-shot: <reason>`.
  50 is a hard cap the hook enforces. Do **not** shatter a coherent 35-line function into
  five 7-line pieces to satisfy the number — that is worse; mark it one-shot instead.
- Cognitive complexity ≤ 15, ≤ 5 parameters, nesting ≤ 4 (the one-shot marker does not
  relax these).
- **Assert real invariants**, not everything. An `assert`/`check` belongs where a violation
  means a bug in *this* module. Caller-supplied input is validated and reported through the
  project's error model, never asserted. No assert that restates the line above it.
- **Test the behaviour that matters:** every public function's success path, every error
  path you introduced, and every branch a caller can observe. Glue, lifecycle overrides and
  logging do not need a test each — say so in the report rather than faking one. Target is
  branch coverage of the changed code with concrete assertions, and an explicit list of what
  is not covered and why.
- Use the project's test framework. If none: `std` → propose Catch2; `unreal` → UE
  Automation tests (`IMPLEMENT_SIMPLE_AUTOMATION_TEST`, run with
  `-ExecCmds="Automation RunTests <Name>"`). Adding a framework is a decision to surface,
  not to make silently.
- **Use the language the profile targets when it simplifies the code**, not as a ritual:
  `std` C++23 — `std::expected`, ranges, `constexpr`, `[[nodiscard]]` where the result carries
  information the caller must not drop. `unreal` — UE types (`TArray`, `FString`, `TMap`,
  `int32`, `TObjectPtr`) over std equivalents. Check the toolchain actually supports a feature
  before using it.
- Prefer editing over adding, deleting over keeping. Small, reviewable diffs; commit messages
  say *why*.

## STYLE (tools own this)

Trailing return types (`auto F() -> T`) in `std`; classic in `unreal` (UHT cannot parse trailing
returns on reflected members). PascalCase everywhere except `UPPER_CASE` macros and 1–2 letter
locals; `bIsActive` for bools in UE. Braces on every control statement. Include order, alignment,
spacing: whatever `clang-format` emits. If you disagree with the formatter, you are wrong here.
No `// clang-format off`, no `NOLINT` without a check list, no `NOLINT` on `readability-function-size`
except the one-shot form above.

Forbidden regardless of tier: C-style casts, `using namespace` in headers, magic numbers,
macros for constants, `goto`, `std::endl`, exceptions in UE code.

## UE — `unreal` profile only

**Authority order:** engine source of *this* engine version (signatures, behaviour) → Epic
coding standard (style/idiom) → other docs → memory.
Coding standard: https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine

**Object lifetime — pick the right tool, not "always X":**

| Need | Use |
|---|---|
| Strong reference that keeps a UObject alive (member) | `UPROPERTY() TObjectPtr<T>` |
| Observer that must not keep it alive / may go stale | `TWeakObjectPtr<T>` + `IsValid()` before use |
| Component or subobject this object owns | `CreateDefaultSubobject<T>` in ctor, stored as `UPROPERTY()` |
| Spawned actor | `World->SpawnActor<T>`; owner decides who holds the `UPROPERTY` |
| Short-lived local within one call | raw pointer is fine when the lifetime is obvious |
| Anything | never `new` a UObject; never a raw `UObject*` member without `UPROPERTY` (GC will free it) |

`IsValid(Obj)`, not `Obj != nullptr`, for anything that could have been destroyed.

**Reflection:** `GENERATED_BODY()` first in the class; `*.generated.h` last include; reflected
members use reflection-compatible types only (no `std::`, no trailing returns, no non-constant
default args).

**Lifecycle:** call `Super::` in overridden lifecycle methods unless the base contract or a
documented pattern says otherwise (rare — say which). Set `PrimaryActorTick.bCanEverTick`
deliberately; ticking is not free.

**Threading:** assume nothing is thread-safe unless the API documents it. UObject access and
world mutation on the game thread; return there with `AsyncTask(ENamedThreads::GameThread, …)`.

**Modules:** headers used across modules live in `Public/` and are exported with `<MODULE>_API`;
dependencies go in `*.Build.cs` (`Public…` vs `Private…DependencyModuleNames`), not include-path
hacks. Editor-only code under `#if WITH_EDITOR`; never link `UnrealEd` from a Runtime module.

**Logging:** `UE_LOG(LogCategory, Verbosity, TEXT("…"), …)` with a declared category. No
`printf`, no `std::cout`.

**Tooling:** after adding/removing sources or touching `Build.cs`, regenerate
`compile_commands.json` (`RunUBT.sh -Mode=GenerateClangDatabase …`, copied from the engine
root into the project) so clangd, clang-tidy and the hook see the truth. Third-party plugins
(`Plugins/AirSim`, `Plugins/CesiumForUnreal`, …) are upstream code: no restyling, no warning
"fixes", minimal marked patches only.

## Done — copy into your final report

```
Files changed: …
Build: <command> → OK / FAIL (paste)
clang-format: clean
clang-tidy: clean / <n> remaining: <list + justification>
Functions > 30 lines: none / <list + one-shot reason>
Tests: <command> → <pass/fail counts>
Branches NOT covered: none / <list + reason>
Assertions added: <where, which invariant> / none
Not verified: none / <what and why>
```
