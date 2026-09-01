# C++ project instructions

Active profile: **{{PROFILE}}** (`std` = general C++23, `unreal` = Unreal Engine C++20).
Installed from `MilosLord/clang`; the `.clang-format` / `.clang-tidy` / `.clangd` next to this
file are the source of truth for style and lint. Do not edit any of them here — change upstream.

Rules are tiered; when they collide, the higher tier wins:
**MUST** (correctness, ownership, scope, verification — never traded) →
**SHOULD** (structure/testing defaults — deviate only with a stated reason) →
**STYLE** (owned by the tools — you run them, you do not reason about it).

## MUST

1. **Correct over fast.** No UB, no data races, no silent narrowing, no unchecked assumptions
   about input from outside the module. Every error path leaves state valid.
2. **Ownership is explicit.** Every pointer has a known owner. No raw owning pointers, no
   `new`/`delete` outside RAII. Values and automatic storage by default; heap needs a concrete
   lifetime / size / stable-address / polymorphism reason. (UE: §UE.)
3. **Production code only.** No stubs, `TODO: implement`, placeholder returns or "simplified
   for now". If it cannot be done properly, stop and say so.
4. **Minimal scope.** Do what was asked; no drive-by refactors, renames or new abstractions.
   Public signatures and existing tests keep working unless the task says otherwise. Ask when
   two readings of the spec give materially different code.
5. **Follow the existing code** — its error model (`std::expected` / exceptions / codes), its
   ownership pattern, its naming of concepts. Read the neighbours before writing.
6. **Map before editing.** Establish the acceptance criteria, then read the contract, the
   implementation, every caller (search by symbol), the tests and the build/CI path that the
   change touches. For a bug, make a regression test fail for the real cause before fixing it.
7. **Close the whole change surface in one pass**: every affected caller, mock, test, config,
   serialization/reflection boundary and user-facing doc, in the same change. No
   half-migrations, no temporary dual paths. Keep compatibility unless breaking it is in scope.
8. **Never invent an API.** Unsure of a signature → open the header (`std`: cppreference / the
   installed stdlib; `unreal`: `<EngineRoot>/Engine/Source`, which outranks online docs).
9. **Verify before you report**: build actually run on the relevant compiler/config (`std`:
   the project's target; `unreal`: UBT Editor target, and a cook/package when assets, plugins
   or packaging config changed — see §UE); `clang-format -i` + `clang-tidy` on touched files,
   findings fixed; focused regression test, then the relevant suite; pre-commit passes (never
   `--no-verify`). A test that did not exercise the changed path is not evidence. **Verify the
   effect, not the setting**: a value echoed in a log or config was *set*, not necessarily
   *applied* — measure the observable result.
10. **Report honestly** in the §Done format: what ran, what it printed, what was not verified
    and why. "Should work" is not a status.

## SHOULD

- **Functions ≤ 30 lines**, one job, one level of abstraction. 30–50 only for a genuine one-shot
  (straight-line setup / registration / dispatch where splitting would hide the order), marked
  `// NOLINTNEXTLINE(readability-function-size) one-shot: <reason>`. 50 is a hard cap the hook
  enforces. Do **not** shatter a coherent 35-line function into five 7-line pieces to satisfy
  the number — mark it one-shot instead.
- Cognitive complexity ≤ 15, ≤ 5 parameters, nesting ≤ 4 (the one-shot marker does not relax
  these).
- **Assert real invariants only** — where a violation means a bug in *this* module. Caller
  input is validated and reported through the project's error model, never asserted. No assert
  that restates the line above it.
- **Test what matters:** every public function's success path, every error path you introduced,
  every branch a caller can observe. Glue, lifecycle overrides and logging need no test each —
  say so instead of faking one. Deliverable: branch coverage of the changed code with concrete
  assertions, plus an explicit list of what is not covered and why.
- Tests are deterministic and isolated: no sleeps, live network, wall-clock, uncontrolled
  randomness, order dependence or shared mutable state. A flaky test is a defect.
- Use the project's test framework. If none: `std` → propose Catch2; `unreal` → Automation
  tests (`IMPLEMENT_SIMPLE_AUTOMATION_TEST`, `-ExecCmds="Automation RunTests <Name>"`). Adding
  a framework is a decision to surface, not to make silently.
- **Use the profile's language when it simplifies the code, not as ritual.** `std` C++23 —
  `std::expected`, ranges, `constexpr`, `[[nodiscard]]` where the result must not be dropped.
  `unreal` — UE types (`TArray`, `FString`, `TMap`, `int32`, `TObjectPtr`) over std. Check the
  toolchain supports a feature before using it.
- Validate malformed / empty / boundary / overflow input at the boundary that owns validation.
  Never swallow an error, catch-all-and-continue, or log the same failure at every layer.
- No smart pointer "for flexibility", no shared ownership without a real shared owner; prefer
  values, references, `optional`, contiguous containers. Conversely, no huge or unbounded
  buffers on the stack. `UObject` always follows UE's factory/GC model.
- No intuition-driven "optimization"; measure a claimed improvement on the relevant workload.
- Comments say *why* and non-obvious lifetime/threading facts; never narrate syntax. Stale
  comments are removed with the code they described.
- Prefer editing over adding, deleting over keeping. Small diffs; commit messages say *why*.

## STYLE (tools own this)

Trailing return types (`auto F() -> T`) in `std`; classic in `unreal` (UHT cannot parse them on
reflected members). PascalCase except `UPPER_CASE` macros and 1–2 letter locals; `bIsActive` for
UE bools. Braces on every control statement. Everything else: whatever `clang-format` emits.
No `// clang-format off`, no `NOLINT` without a check list, no `NOLINT` on
`readability-function-size` except the one-shot form.

Forbidden regardless of tier: C-style casts, `using namespace` in headers, macros for constants,
`goto`, `std::endl`, exceptions in UE code. Protocol values, limits and domain constants get
names; obvious literals and idiomatic UE gameplay-tuning values do not.

## Comments

Code explains itself; comments explain what code cannot.

- **Never comment what the code does.** `// increment counter`, `// loop over the actors`,
  `// return the result` — delete on sight. If a function needs a comment to be readable, the
  function is wrong: rename it or split it (see MUST on function size).
- **Comment only the non-obvious *why*:** an upstream bug being worked around, a constraint not
  visible locally, the provenance of a magic value, a deliberate tradeoff, an ordering that looks
  arbitrary but is not. One or two lines, directly above the declaration, plain prose. No banners,
  no `====` separators, no ASCII art, no restating the signature.
- **Rare by default.** A file with a comment on every function was written by a machine and reads
  like it. If much more than one function in ten needs one, the code is too clever.
- Doc comments on *public* API in a header are a separate thing and are fine: contract, ownership,
  units, thread affinity, lifetime. Still nothing about the implementation.
- Never leave commentary about your own process: no `// Fixed the bug`, `// As requested`,
  `// Changed from the previous version`, no dated notes, no initials. Git holds that.

## Git

- **No AI attribution, ever.** No `Co-Authored-By:` naming an assistant, no `Generated with …`,
  no tool name, no session link, no emoji robot — not in the subject, body or trailers. Some
  agents add these by default; turn it off. The commit reads as if a person wrote it, because a
  person is responsible for it. Enforced by the `commit-msg` hook.
- Subject: imperative, ≤ 72 chars, no trailing period. No `type:` prefix unless the repo already
  uses one. `Fix rotator argument order in level generator`, not
  `feat: implemented a fix for the rotator argument ordering issue`.
- Body only when the *why* is not obvious from the diff: what broke, what constraint forced this
  shape, what was measured. Wrap at 72. Never a bullet-point restatement of the diff.
- One concern per commit. Never `--no-verify`.

<!-- {{CMAKE}} -->

<!-- {{UNREAL}} -->

## Done — copy into your final report

```
Files changed: …
Build: <OS, compiler, config, command> → OK / FAIL (paste)
Package/cook (unreal, when assets/plugins/packaging changed): <command> → OK / FAIL / not needed because …
clang-format: clean
clang-tidy: clean / <n> remaining: <list + justification>
Functions > 30 lines: none / <list + one-shot reason>
Tests: <command> → <pass/fail counts>
Branches NOT covered: none / <list + reason>
Assertions added: <where, which invariant> / none
Compatibility: preserved / <intentional break + migration>
Not verified: none / <what and why>
```
