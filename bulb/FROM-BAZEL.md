# From Bazel to bulb (WIP)

> **Work in progress.** The bulb build has been tested on osx-arm64 and
> linux-64, but not on Windows. Tests are still plain binaries (see
> [README.md](README.md#compromises)). Keep using Bazel for anything that
> matters for now.

`BUILD.star` mirrors `BUILD.bazel`: it has the same targets, sources, flags and
tests. bulb gets its compilers and other tools from conda-forge, pinned in
`bulb.lock`. You don't need a system toolchain, `MODULE.bazel` or `.bazelrc`.

## Install

bulb 0.1.1 or later is required.

```sh
pixi global install -c https://prefix.dev/prefix-dev/bulb bulb
```

## Command map

| Bazel | bulb |
|---|---|
| `bazel build //:highs` | `bulb build //:highs` |
| `bazel run //:highs-bin -- model.mps` | `bulb run //:highs-bin -- $PWD/model.mps` |
| `bazel run //:call-highs-example` | `bulb run //:call-highs-example` |
| `bazel test //:TestBasis` | `bulb build //:TestBasis`, then run the binary it prints |
| `bazel test //...` | the loop in [README.md](README.md#compromises) |
| `bazel build //...` | no equivalent: build one label at a time |
| `bazel clean` | `bulb clean` |
| `bazel-bin/<target>` | the path `bulb build` prints under `outputs:` |
| `--platforms=...` | `--platform linux-64` (any conda subdir in `bulb.toml`) |
| `MODULE.bazel.lock` | `bulb.lock` (regenerate with `bulb lock`) |

## Differences to know about

- **Paths passed to `bulb run`.** The binary runs inside its own work
  directory, not in the repo root, so pass absolute paths such as `$PWD/...`.
- **Tests.** There is no `bulb test`. The test targets are plain binaries.
  Run them from the repo root so that they can find `check/instances`.
- **Target names.** The targets are Bazel's, except that `:config` and
  `:check-config` are folded into `:highs` and `:test_lib`, and `:cupdlp` is
  not ported.
- **Flags.** `compiler_flags` is Bazel's `copts`, and
  `exported_preprocessor_flags` is Bazel's `defines`. bulb has no `--copt`
  flag and no `.bazelrc` configs, so `--config=asan` and the other sanitizer
  configs are not available yet.
- **Not ported.** The CUDA build (`--//:cupdlp_gpu`) and the unused zlib
  dependency are not ported.
- **New sources.** Add each source file to `BUILD.star` as well as to
  `BUILD.bazel`.
