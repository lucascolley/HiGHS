# Building HiGHS with bulb

`BUILD.star` is a port of `BUILD.bazel`: the same targets, sources, flags,
binaries and tests, built with bulb's prelude rules (`cxx_library`,
`cxx_binary`, `expand_template`). It needs bulb 0.1.1 or later.

```sh
bulb build //:highs                   # the library
bulb run //:highs-bin -- model.mps    # the solver
bulb run //:call-highs-example
bulb build //:TestBasis               # one test; run it from the repo root (see Tests)
```

Status: all 40 tests pass on osx-arm64 (native) and on linux-64 (cross-built
from osx-arm64 and run in a Linux container). Nothing has been built on
Windows. `bulb.lock` solves all five platforms.

Coming from Bazel? See [FROM-BAZEL.md](FROM-BAZEL.md).

## Compromises

**1. Tests are plain binaries.** bulb has no C++ test rule. `bulb run` runs a
binary in its own work directory, so test cases that read `check/instances`
fail there (e.g. 12 of `TestFilereader`'s 23), since `HIGHS_DIR` is `"."`, as
with Bazel. Run the binaries from the repo root instead:

```sh
for t in $(grep -oE '^    "Test[A-Za-z]+"' BUILD.star | tr -d ' "'); do
  bin=$(bulb build //:$t 2>&1 | awk '/^outputs:/ { getline; print $1 }')
  "$bin" || echo "FAILED $t"
done
```

## Other differences

- **Catch needs `<new>`.** The tests add `-include new`, because Catch v2.13.8
  uses `std::nothrow` without including `<new>`. Apple's libc++ gets it
  indirectly through other headers; conda-forge's newer libc++ doesn't. This
  isn't a bulb gap.

## Not ported

- **CUDA:** the `cupdlp` target and the `--//:cupdlp_gpu` flag. bulb has no
  CUDA rules, so the CPU build (Bazel's default) is the only one.
- **zlib:** Bazel links `@zlib`, but `HConfig.h.bazel.in` doesn't define
  `ZLIB_FOUND`, so no HiGHS code uses it. The port drops the dependency.
- `testonly`, `visibility` and `data` have no bulb equivalent.
