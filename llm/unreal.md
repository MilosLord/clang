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
| Anything | never `new` a UObject; never a raw `UObject*` member without `UPROPERTY` (GC frees it) |

`IsValid(Obj)`, not `Obj != nullptr`, for anything that could have been destroyed.

**Reflection:** `GENERATED_BODY()` first in the class; `*.generated.h` last include; reflected
members use reflection-compatible types only (no `std::`, no trailing returns, no non-constant
default args).

**Lifecycle:** call `Super::` in overridden lifecycle methods unless the base contract or a
documented pattern says otherwise (rare — say which). Set `PrimaryActorTick.bCanEverTick`
deliberately; ticking is not free.

**Threading:** assume nothing is thread-safe unless the API documents it. UObject access and
world mutation on the game thread; return there with `AsyncTask(ENamedThreads::GameThread, …)`.

**Modules:** cross-module headers live in `Public/`, exported with `<MODULE>_API`; dependencies
go in `*.Build.cs` (`Public…` vs `Private…DependencyModuleNames`). Editor-only code under
`#if WITH_EDITOR`; never link `UnrealEd` from a Runtime module.

**Logging:** `UE_LOG(LogCategory, Verbosity, TEXT("…"), …)` with a declared category. No
`printf`, no `std::cout`.

**Tooling:** after adding/removing sources or touching `Build.cs`, regenerate
`compile_commands.json` (`RunUBT.sh -Mode=GenerateClangDatabase …`, copied from the engine root
into the project). Keep clang-tidy/clangd on the same LLVM major as the engine's bundled clang
(`Engine/Extras/ThirdPartyNotUE/SDKs/…/v<N>_clang-<ver>`; 5.8 → clang 20) or newer — an older
tidy reports false positives on C++20 constructs. Third-party plugins (`Plugins/AirSim`,
`Plugins/CesiumForUnreal`, …) are upstream code: no restyling, no warning "fixes", minimal
marked patches only.

**Build & run — learned the hard way, all verified on Linux:**
- Build: `Engine/Build/BatchFiles/Linux/Build.sh <Project>Editor Linux Development
  -Project=/abs/path/<Project>.uproject -WaitMutex`. `Build.sh` only forwards to UBT; without
  `-Project=` it builds the wrong thing, without `-WaitMutex` it fails when another UBT runs.
- **Close the Editor before building.** With `UnrealEditor` running UBT switches to hot-reload
  and dies with `Hot-reloadable files are expected to contain a hyphen, eg. UnrealEditor-Core` —
  nowhere near the cause. `pgrep -x UnrealEditor` first, every time.
- **Never run UE as root** — `Refusing to run with the root privileges` then a core dump. Agents
  often are root; switch user before touching the editor, commandlets or a packaged build.
- Headless (no X server): every editor/commandlet/automation invocation needs
  `-RenderOffscreen -Unattended -NoSound -nosplash` (or `-nullrhi` when rendering is not under
  test); e.g. `-ExecCmds="Automation RunTests <Name>"` crashes without them.
- **Editor-clean ≠ package-clean.** Assets loaded dynamically at runtime (Blueprints by path,
  plugin content) are skipped by the cooker unless listed in `DefaultGame.ini`
  `[/Script/UnrealEd.ProjectPackagingSettings]` `+DirectoriesToAlwaysCook`; the failure shows up
  only at packaged startup (`Failed to load asset class …_C`). Cook/package at least once when
  assets, plugins or packaging config change, and put it in the Done report.
- Config ≠ runtime: `LogConfig: Set CVar [[t.MaxFPS:30]]` proves the ini was read, not that the
  value survived startup (something later overrode it; only `-ExecCmds` stuck). Measure.
- Editor Python (headless tooling): `unreal.log()` does not reach stdout in commandlet mode —
  write to a file or use `print`; `unreal.EditorLevelLibrary.new_level()` silently no-ops when the
  map exists. **Always keyword arguments for math structs in UE Python.** `Rotator` has three
  different orders — C++ `TRotator(Pitch, Yaw, Roll)`, reflected fields `Pitch, Yaw, Roll`
  (`NoExportTypes.h`), Python positional `(roll, pitch, yaw)` — so reading the header and writing
  the same order in Python gives a silently wrong rotation. `unreal.Rotator(roll=0, pitch=-10,
  yaw=90)` cannot be wrong; `unreal.Rotator(-10, 90, 0)` was.
