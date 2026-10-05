load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# AyuGram core: settings, ghost-mode state, message filters, edits-history storage.
# Dependency-free so that TelegramCore can use it.
swift_library(
    name = "AyuCore",
    module_name = "AyuCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
