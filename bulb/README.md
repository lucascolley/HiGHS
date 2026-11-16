# Building HiGHS with bulb

`BUILD.star` is a port of `BUILD.bazel`: the same sources, flags, binaries and
tests, built with bulb's prelude rules (`cxx_library`, `cxx_binary`,
`cxx_toolchain`). bulb cannot load workspace rule files yet, so the port uses
only those rules. Each compromise below is a gap between Bazel's `rules_cc`
and bulb's C++ rules.

```sh
bulb build //:highs                   # the library
bulb run //:highs-bin -- model.mps    # the solver
bulb run //:call-highs-example
bulb build //:TestBasis               # one test; run it from the repo root (see Tests)
```

Status: built and run on osx-arm64 only, where all 40 tests pass. `bulb.lock`
solves all five platforms, but nothing else has been built.

## Compromises

**1. Checked-in config headers.** bulb has no `copy_file` or other generating
rule, and C++ targets only take source paths. So `bulb/include/HConfig.h` and
`bulb/check-include/HCheckConfig.h` are copies of `highs/HConfig.h.bazel.in`
and `check/HCheckConfig.h.bazel.in`. Update them when the originals change.

**2. `defines` and `copts` live in toolchains.** `cxx_library` has neither. The
`highs-cxx` toolchain's `compile_flags` carry `-DCUPDLP_CPU` and Bazel's
`copts`. Toolchain flags don't pass to dependents the way Bazel's `defines`
do, so every target that compiles HiGHS code names a toolchain. A `select`
can't be added to a list, so the flags are written out in each branch.

**3. C sources use their own toolchain.** `cxx_library` compiles every source
with the toolchain's C++ command. The `highs-c` toolchain points that command
at `$CC` for basiclu and cupdlp. On Windows it stays `$CXX`, because `cl.exe`
picks the language by file suffix. C compiles still receive `$CXXFLAGS`.

**4. `:highs` is five targets.** bulb names object files by basename, so sources
that share one can't be in the same target:

| Target | Sources |
|---|---|
| `highs-basiclu` | `highs/ipm/basiclu/*.c` (C) |
| `highs-cupdlp` | `highs/pdlp/cupdlp/*.c` (C) |
| `highs-qpsolver` | `highs/qpsolver/*.cpp`: `basis` and `scaling` clash with ipx and hipdlp |
| `highs-core` | everything else |
| `highs` | `highs_c_api.cpp`; the target dependents use, as in Bazel |

`highs-core` and `highs-qpsolver` call each other, so `highs` links core, then
qpsolver, then core again. That order is meant for single-pass linkers (GNU
ld) but has only been linked with Apple's linker.

**5. Headers are declared per target.** bulb rejects any header a compile opens
that the target didn't declare. A header-only `cxx_library` fails on macOS,
because `ar` refuses an empty archive. So `HEADERS` and `INCLUDES` are
declared on each target that needs them, and Bazel's header-only
`:highs-runtime-opts` became `headers` of `highs-bin`. Bazel's implicit
include of the workspace root is dropped: bulb rejects `.`, and HiGHS doesn't
rely on it.

**6. Tests are plain binaries.** bulb has no test rule. `bulb run` runs a binary
in its own work directory, so test cases that read `check/instances` fail
there (e.g. 12 of `TestFilereader`'s 23), since `HIGHS_DIR` is `"."`, as with
Bazel. Run the binaries from the
repo root instead:

```sh
for t in $(grep -oE '^    "Test[A-Za-z]+"' BUILD.star | tr -d ' "'); do
  bulb build //:$t && .bulb/work/_root/$t/bin/$t || echo "FAILED $t"
done
```

The tests also use the `highs-test-cxx` toolchain, which adds `-include new`.
Catch v2.13.8 uses `std::nothrow` without including `<new>`. Apple's libc++
gets it indirectly through other headers; conda-forge's newer libc++ doesn't.
This one isn't a bulb gap.

## Not ported

- **CUDA:** the `cupdlp` target and the `--//:cupdlp_gpu` flag. bulb has no
  CUDA rules, so the CPU build (Bazel's default) is the only one.
- **zlib:** Bazel links `@zlib`, but `HConfig.h.bazel.in` doesn't define
  `ZLIB_FOUND`, so no HiGHS code uses it. The port drops the dependency.
- `testonly`, `visibility` and `data` have no bulb equivalent.
