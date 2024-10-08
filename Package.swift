// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "whisper",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "whisper", targets: ["whisper"]),
    ],
    targets: [
         .target(
             name: "whisper",
             dependencies: [
                .target(name: "whisper_coreml"),
             ],
             path: ".",
             exclude: [
                "bindings",
                "cmake",
                "examples",
                "models",
                "samples",
                "tests",
                "CMakeLists.txt",
                "Makefile"
             ],
             sources: [
                 "ggml/src/ggml.c",
                 "src/whisper.cpp",
                 "ggml/src/ggml-aarch64.c",
                 "ggml/src/ggml-alloc.c",
                 "ggml/src/ggml-backend.cpp",
                 "ggml/src/ggml-quants.c",
                 "ggml/src/ggml-metal.m"
             ],
             resources: [.process("ggml/src/ggml-metal.metal")],
             publicHeadersPath: "spm-headers",
             cSettings: [
                 .unsafeFlags(["-Wno-shorten-64-to-32", "-O3", "-ffast-math", "-fno-finite-math-only", "-DNDEBUG"]),
                 .define("GGML_USE_ACCELERATE"),
                 .unsafeFlags(["-fno-objc-arc"]),
                 .define("GGML_USE_METAL"),
                 .define("ACCELERATE_NEW_LAPACK"),
                 .define("ACCELERATE_LAPACK_ILP64"),
                 .define("WHISPER_USE_COREML"),
             ],
             linkerSettings: [
                 .linkedFramework("Accelerate")
             ]
         ),
        .target(
            name: "whisper_coreml",
            path: ".",
            exclude: [
               "bindings",
               "cmake",
               "examples",
               "models",
               "samples",
               "tests",
               "CMakeLists.txt",
               "Makefile",
               "ggml/src/ggml-metal.metal",
            ],
            sources: [
                "src/coreml/whisper-encoder-impl.m",
                "src/coreml/whisper-encoder.mm",
            ],
            cSettings: [
                .unsafeFlags(["-mf16c"]),
                .unsafeFlags(["-Wno-shorten-64-to-32", "-O3", "-ffast-math", "-fno-finite-math-only", "-DNDEBUG"]),
                .define("GGML_USE_ACCELERATE"),
                .unsafeFlags(["-fobjc-arc"]),
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64"),
                .define("WHISPER_USE_COREML"),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate")
            ]
        ),
    ],
    cxxLanguageStandard: .cxx11
)
