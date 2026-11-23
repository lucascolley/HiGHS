# bulb port of BUILD.bazel: the same targets, sources, flags and tests.
# See bulb/README.md for what differs.
#
#   bulb build //:highs                    the library
#   bulb run //:highs-bin -- model.mps     the `highs` solver
#   bulb run //:call-highs-example
#   bulb build //:TestBasis                one test binary; run it from the repo root

expand_template(
    name = "highs-config",
    template = "highs/HConfig.h.bazel.in",
    out = "HConfig.h",
)

COPTS = match("@prelude//config:os", {"windows": []}, default = [
    "-fexceptions",
    "-Wno-unused-variable",
    "-Wno-unused-but-set-variable",
])

cxx_library(
    name = "highs",
    srcs = [
        "highs/interfaces/highs_c_api.cpp",
        "highs/HighsExternalApi.cpp",
        "highs/HighsExternalDeps.cpp",
    ] + glob([
        "highs/io/*.cpp",
        "highs/ipm/*.cpp",
        "highs/ipm/ipx/*.cc",
        "highs/ipm/basiclu/*.c",
        "highs/ipm/hipo/ipm/*.cpp",
        "highs/ipm/hipo/factorhighs/*.cpp",
        "highs/ipm/hipo/auxiliary/*.cpp",
        "highs/lp_data/*.cpp",
        "highs/mip/*.cpp",
        "highs/model/*.cpp",
        "highs/parallel/*.cpp",
        "highs/pdlp/*.cpp",
        "highs/pdlp/cupdlp/*.c",
        "highs/pdlp/hipdlp/*.cc",
        "highs/presolve/*.cpp",
        "highs/qpsolver/*.cpp",
        "highs/simplex/*.cpp",
        "highs/util/*.cpp",
    ]),
    # Bazel's `hdrs`, plus the generated HConfig.h, which Bazel's :config
    # provides. Headers are included by their paths, as in Bazel.
    exported_headers = {"HConfig.h": ":highs-config"} | {h: h for h in [
        "highs/mip/feasibilityjump.hh",
    ] + glob([
        "**/*.h",
        "highs/pdlp/hipdlp/*.hpp",
        "highs/qpsolver/*.hpp",
        "extern/zstr/*.hpp",
    ])},
    header_namespace = "",
    public_include_directories = [
        "extern",
        "extern/catch",
        "highs",
    ],
    compiler_flags = COPTS,
    # Bazel's `defines`, which reach every dependent.
    exported_preprocessor_flags = ["-DCUPDLP_CPU"],
    exported_linker_flags = match("@prelude//config:os", {
        "windows": ["-DEFAULTLIB:shell32.lib"],
        "linux": ["-Wl,--no-as-needed", "-ldl", "-pthread"],
    }, default = ["-lpthread"]),
)

cxx_library(
    name = "highs-runtime-opts",
    exported_headers = [
        "extern/cli11/CLI11.hpp",
        "app/HighsRuntimeOptions.h",
    ],
    header_namespace = "",
)

cxx_binary(
    name = "highs-bin",
    srcs = ["app/RunHighs.cpp"],
    deps = [
        ":highs",
        ":highs-runtime-opts",
    ],
)

cxx_binary(
    name = "call-highs-example",
    srcs = ["examples/call_highs_from_cpp.cpp"],
    deps = [":highs"],
)

expand_template(
    name = "highs-check-config",
    template = "check/HCheckConfig.h.bazel.in",
    out = "HCheckConfig.h",
)

# Bazel's test `copts`, plus `<new>` forced in: Catch v2.13.8 uses
# std::nothrow without including it, which conda-forge's libc++ (unlike
# Apple's) no longer pulls in through other headers.
TEST_COPTS = COPTS + match("@prelude//config:os", {"windows": []}, default = ["-include", "new"])

cxx_library(
    name = "test_lib",
    srcs = [
        "check/Avgas.cpp",
        "check/TestMain.cpp",
    ],
    exported_headers = {"HCheckConfig.h": ":highs-check-config"} | {h: h for h in [
        "check/Avgas.h",
        "check/SpecialLps.h",
        "check/matrix_multiplication.hpp",
        "extern/catch/catch.hpp",
    ]},
    header_namespace = "",
    public_include_directories = ["check"],
    compiler_flags = TEST_COPTS,
    deps = [":highs"],
)

TEST_NAMES = [
    "TestAlienBasis",
    "TestBasis",
    "TestBasisSolves",
    "TestCheckSolution",
    "TestCrossover",
    "TestDualize",
    "TestEkk",
    "TestFactor",
    "TestFilereader",
    "TestHighsGFkSolve",
    "TestHighsHash",
    "TestHighsHessian",
    "TestHighsIntegers",
    "TestHighsModel",
    "TestHighsParallel",
    "TestHighsRbTree",
    "TestHiPdlp",
    "TestHSet",
    "TestICrash",
    "TestInfo",
    "TestIO",
    "TestIpx",
    "TestLogging",
    "TestLpModification",
    "TestLpOrientation",
    "TestLpSolvers",
    "TestLpValidation",
    "TestMipSolver",
    "TestPresolve",
    "TestPresolveRules",
    "TestQpOracle",
    "TestQpSolver",
    "TestRanging",
    "TestRunData",
    "TestRays",
    "TestSemiVariables",
    "TestSetup",
    "TestSort",
    "TestSpecialLps",
    "TestThrow",
]

# Bazel's cc_test targets, as binaries: bulb has no C++ test rule.
[cxx_binary(
    name = name,
    srcs = ["check/%s.cpp" % name],
    compiler_flags = TEST_COPTS,
    deps = [
        ":highs",
        ":test_lib",
    ],
) for name in TEST_NAMES]
