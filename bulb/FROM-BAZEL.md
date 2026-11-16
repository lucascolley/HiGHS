# From Bazel to bulb (WIP)

> **Work in progress.** The bulb build has only been built and tested on
> osx-arm64. It also depends on six compromises that are listed in
> [README.md](README.md#compromises). Keep using Bazel for anything that
> matters until those compromises are resolved.

`BUILD.star` mirrors `BUILD.bazel`: it has the same sources, flags, binaries and
tests. bulb gets its compilers and other tools from conda-forge, pinned in
`bulb.lock`. You don't need a system toolchain, `MODULE.bazel` or `.bazelrc`.

## Install

```sh
pixi global install -c https://prefix.dev/prefix-dev/bulb bulb
```

## Command map

| Bazel | bulb |
|---|---|
| `bazel build //:highs` | `bulb build //:highs` |
| `bazel run //:highs-bin -- model.mps` | `bulb run //:highs-bin -- $PWD/model.mps` |
| `bazel run //:call-highs-example` | `bulb run //:call-highs-example` |
| `bazel test //:TestBasis` | `bulb build //:TestBasis && .bulb/work/_root/TestBasis/bin/TestBasis` |
| `bazel test //...` | the loop in [README.md](README.md#compromises) (compromise 6) |
| `bazel build //...` | no equivalent: build one label at a time |
| `bazel clean` | `bulb clean` |
| `bazel-bin/<target>` | `.bulb/work/_root/<target>/bin/<target>` |
| `--platforms=...` | `--platform linux-64` (any conda subdir in `bulb.toml`) |
| `MODULE.bazel.lock` | `bulb.lock` (regenerate with `bulb lock`) |

## Differences to know about

- **Paths passed to `bulb run`.** The binary runs inside its own work
  directory, not in the repo root, so pass absolute paths such as `$PWD/...`.
- **Tests.** There is no `bulb test`. The test targets are plain binaries.
  Run them from the repo root so that they can find `check/instances`.
- **Target names.** `//:highs` is the target to depend on, as in Bazel. It
  pulls in four internal targets: `highs-core`, `highs-qpsolver`,
  `highs-basiclu` and `highs-cupdlp`. Bazel's `:highs-config`,
  `:highs-runtime-opts`, `:check-config` and `:cupdlp` have no bulb
  equivalent.
- **Config headers.** If you edit `highs/HConfig.h.bazel.in` or
  `check/HCheckConfig.h.bazel.in`, copy the change into `bulb/include/` or
  `bulb/check-include/` by hand.
- **Flags.** To change `copts` or `defines`, edit the `FLAGS` select and the
  `highs-test-cxx` toolchain in `BUILD.star`. Edit the targets themselves
  only to change other settings. bulb has no `--copt` flag and no `.bazelrc`
  configs, so `--config=asan` and the other sanitizer configs are not
  available yet.
- **Not ported.** The CUDA build (`--//:cupdlp_gpu`) and the unused zlib
  dependency are not ported.
- **New sources.** Add each source file to the matching target in
  `BUILD.star` as well as in `BUILD.bazel`. If its basename matches an
  existing file in the same target, it has to go in a separate target
  (compromise 4).
