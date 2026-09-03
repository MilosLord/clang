## Build system — CMake (`std` profile)

The project's supported environments are the constraint, not the newest CMake on this machine.
Before touching build files read `CMakeLists.txt`, presets/toolchain files, lockfiles, CI images
and the documented compiler/OS support; print the actual CMake and compiler versions. Do not
replace a working build system with CMake unless asked.

- `cmake_minimum_required(VERSION <floor>...<tested>)` before `project()`. New project: floor =
  newest CMake on the **oldest supported environment**, ceiling = newest CMake actually tested.
  Existing project: never raise the floor for a convenience feature; only when support is
  intentionally dropped, with CI/docs updated in the same change.
- Target-based only: `target_sources` / `target_include_directories` / `target_link_libraries` /
  `target_compile_features(cxx_std_23)` with correct `PRIVATE`/`PUBLIC`/`INTERFACE`. No hand-written
  `-std=`, no global `CMAKE_CXX_FLAGS`, `include_directories`, `link_directories`, `add_definitions`.
- Compiler flags follow the **frontend** (`CMAKE_CXX_COMPILER_FRONTEND_VARIANT`): MSVC-style for
  MSVC/clang-cl, GNU-style for GCC/Clang/AppleClang. `-Werror` is a CI/developer setting, never a
  transitive requirement on consumers or third-party targets.
- Portable `CMakePresets.json` checked in; machine-local paths and secrets in untracked
  `CMakeUserPresets.json`. Do not assume `CMAKE_BUILD_TYPE` exists — multi-config generators pick
  the configuration at build/test time. Drive with `cmake --build` / `ctest`, never raw
  `make`/`ninja`/`msbuild` in portable scripts.
- Pin fetched dependencies to a release or immutable commit; follow the project's package
  manager/lockfile. No floating `main`, no surprise network downloads.
- `compile_commands.json` (needed by clangd / clang-tidy / the pre-commit hook) is a build
  artifact you must ask for: set `"CMAKE_EXPORT_COMPILE_COMMANDS": true` in the configure
  preset's `cacheVariables` (see `samples/std/CMakePresets.json`), not with `set(... CACHE ...)`
  in `CMakeLists.txt` — it is a developer/tooling setting, not part of the project's build
  contract, and a consumer adding the project via `add_subdirectory`/`FetchContent` should not
  inherit it. Only Makefile and Ninja generators honour it; Visual Studio and Xcode silently
  emit nothing, so on Windows keep the native MSVC build as the authoritative verification and
  add a separate Ninja tooling preset just for the database.
- Keep exactly one database reachable: the tools look in the repo root and in the usual build
  dirs, and refuse to guess when several build trees exist. Either symlink the chosen one to the
  root (`ln -s build/dev/compile_commands.json .`, gitignored) or pin it once per repo with
  `git config clang.tidyBuildDir build/<preset>`. Regenerate it after any change to sources,
  flags or targets — a stale database makes clang-tidy analyse code that no longer exists.
- Platform branches express a real API/ABI/filesystem difference, not a guessed compiler. A change
  is "cross-platform" only after configure + build + tests ran on every claimed OS/compiler family.

Tool versions pinned in CI are a reproducible tested baseline, not a ban on newer local tools.
Prefer clang-format / clang-tidy / clangd from the same LLVM major; if they differ, the configs
must parse and every check must pass — and report the exact versions used.
