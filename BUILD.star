# bulb port of BUILD.bazel. Same sources, flags and tests, reshaped around
# what bulb's prelude can express; see bulb/README.md for each compromise.
#
#   bulb build //:highs                    the library (four archives, see README)
#   bulb run //:highs-bin -- model.mps     the `highs` solver
#   bulb run //:call-highs-example
#   bulb build //:TestBasis                one test binary; run it from the repo root

# ---- shared declarations -------------------------------------------------------------

# Bazel's `hdrs` of :highs. bulb checks every header a compile opens against
# the declared ones, and has no header-only targets on macOS, so each target
# that compiles HiGHS code declares this list.
HEADERS = [
    "highs/mip/feasibilityjump.hh",
] + glob([
    "**/*.h",
    "highs/pdlp/hipdlp/*.hpp",
    "highs/qpsolver/*.hpp",
    "extern/zstr/*.hpp",
])

# Bazel's `includes` of :highs, plus bulb/include, where the checked-in
# HConfig.h lives.
INCLUDES = ["bulb/include", "extern", "extern/catch", "highs"]

# Bazel's `defines` and `copts` of :highs, as compile flags (a select cannot
# be concatenated with a list, so the define is in both branches).
FLAGS = select("@prelude//config:os", {
    "windows": ["-DCUPDLP_CPU"],
    "DEFAULT": [
        "-DCUPDLP_CPU",
        "-fexceptions",
        "-Wno-unused-variable",
        "-Wno-unused-but-set-variable",
    ],
})

_MSVC_KEYS = ["VCToolsVersion", "VCToolsInstallDir", "WindowsSDKVersion", "WindowsSdkDir", "VSCMD_VER", "VSINSTALLDIR"]

# ---- toolchains: stand-ins for `defines`, `copts` and C compiles -------------------------

# C++ with Bazel's `defines` of :highs (which reach every dependent in Bazel)
# and its `copts`.
cxx_toolchain(
    name = "highs-cxx",
    compile_flags = FLAGS,
)

# C: the same flags, compiled by $CC instead of $CXX. cl.exe picks the
# language from the file suffix, so Windows keeps $CXX.
cxx_toolchain(
    name = "highs-c",
    cxx = select("@prelude//config:os", {"windows": "$CXX", "DEFAULT": "$CC"}),
    compile_flags = FLAGS,
    compile_env_keys = select("@prelude//config:os", {
        "windows": ["PATH", "INCLUDE", "CXX"] + _MSVC_KEYS,
        "DEFAULT": ["PATH", "CC", "CPPFLAGS", "CXXFLAGS"],
    }),
)

# The tests: as highs-cxx, plus `<new>` forced in. Catch v2.13.8 uses
# std::nothrow without including it, which conda-forge's libc++ (unlike
# Apple's) no longer pulls in through other headers.
cxx_toolchain(
    name = "highs-test-cxx",
    compile_flags = select("@prelude//config:os", {
        "windows": ["-DCUPDLP_CPU"],
        "DEFAULT": [
            "-DCUPDLP_CPU",
            "-fexceptions",
            "-Wno-unused-variable",
            "-Wno-unused-but-set-variable",
            "-include",
            "new",
        ],
    }),
)

# ---- the library: Bazel's :highs, split in four ------------------------------------

cxx_library(
    name = "highs-basiclu",
    srcs = glob(["highs/ipm/basiclu/*.c"]),
    headers = HEADERS,
    include_directories = INCLUDES,
    cxx_toolchain = ":highs-c",
)

cxx_library(
    name = "highs-cupdlp",
    srcs = glob(["highs/pdlp/cupdlp/*.c"]),
    headers = HEADERS,
    include_directories = INCLUDES,
    cxx_toolchain = ":highs-c",
)

cxx_library(
    name = "highs-core",
    srcs = [
        "highs/HighsExternalApi.cpp",
        "highs/HighsExternalDeps.cpp",
    ] + glob([
        "highs/io/*.cpp",
        "highs/ipm/*.cpp",
        "highs/ipm/ipx/*.cc",
        "highs/ipm/hipo/ipm/*.cpp",
        "highs/ipm/hipo/factorhighs/*.cpp",
        "highs/ipm/hipo/auxiliary/*.cpp",
        "highs/lp_data/*.cpp",
        "highs/mip/*.cpp",
        "highs/model/*.cpp",
        "highs/parallel/*.cpp",
        "highs/pdlp/*.cpp",
        "highs/pdlp/hipdlp/*.cc",
        "highs/presolve/*.cpp",
        "highs/simplex/*.cpp",
        "highs/util/*.cpp",
    ]),
    exported_headers = HEADERS,
    public_include_directories = INCLUDES,
    # Bazel's `linkopts`.
    exported_linker_flags = select("@prelude//config:os", {
        "windows": ["-DEFAULTLIB:shell32.lib"],
        "linux": ["-Wl,--no-as-needed", "-ldl", "-pthread"],
        "DEFAULT": ["-lpthread"],
    }),
    deps = [":highs-basiclu", ":highs-cupdlp"],
    cxx_toolchain = ":highs-cxx",
)

# qpsolver/basis.cpp and qpsolver/scaling.cpp share basenames with
# ipm/ipx/basis.cc and pdlp/hipdlp/scaling.cc, so they need a target of their own.
cxx_library(
    name = "highs-qpsolver",
    srcs = glob(["highs/qpsolver/*.cpp"]),
    deps = [":highs-core"],
    cxx_toolchain = ":highs-cxx",
)

# What dependents use, as in Bazel. Links as highs, highs-core, ...,
# highs-qpsolver, highs-core, ...: core and qpsolver call each other, and
# repeating core after qpsolver lets single-pass linkers (GNU ld) resolve both.
cxx_library(
    name = "highs",
    srcs = ["highs/interfaces/highs_c_api.cpp"],
    deps = [":highs-core", ":highs-qpsolver"],
    cxx_toolchain = ":highs-cxx",
)

# ---- binaries ---------------------------------------------------------------------------

cxx_binary(
    name = "highs-bin",
    srcs = ["app/RunHighs.cpp"],
    # Bazel's header-only :highs-runtime-opts.
    headers = [
        "extern/cli11/CLI11.hpp",
        "app/HighsRuntimeOptions.h",
    ],
    deps = [":highs"],
    cxx_toolchain = ":highs-cxx",
)

cxx_binary(
    name = "call-highs-example",
    srcs = ["examples/call_highs_from_cpp.cpp"],
    deps = [":highs"],
    cxx_toolchain = ":highs-cxx",
)

# ---- tests ------------------------------------------------------------------------------

cxx_library(
    name = "test_lib",
    srcs = [
        "check/Avgas.cpp",
        "check/TestMain.cpp",
    ],
    exported_headers = [
        "check/Avgas.h",
        "check/SpecialLps.h",
        "check/matrix_multiplication.hpp",
        "extern/catch/catch.hpp",
        "bulb/check-include/HCheckConfig.h",
    ],
    public_include_directories = ["check", "bulb/check-include"],
    deps = [":highs"],
    cxx_toolchain = ":highs-test-cxx",
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

[cxx_binary(
    name = name,
    srcs = ["check/%s.cpp" % name],
    deps = [
        ":highs",
        ":test_lib",
    ],
    cxx_toolchain = ":highs-test-cxx",
) for name in TEST_NAMES]
