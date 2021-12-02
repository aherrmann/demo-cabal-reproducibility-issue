Demonstrates how Cabal not supporting `${pkgroot}` or similar in
`--extra-include-dirs` and `--extra-lib-dirs` makes builds of Cabal packages
non-relocatable and non-reproducible.

This repository contains:

- A C library in `myclib`.
- A Cabal package in `mypackage` that depends on the C library.
- A build and install script in `build.sh`.

The build script builds and installs the C library and Cabal package into
`install1` and `install2` next to the build script.

The build is configured to produce relocatable and reproducible outputs.
However, because Cabal requires that `--extra-include-dirs` and
`--extra-lib-dirs` be absolute paths, the install directory leaks into the
outputs, making them neither relocatable nor reproducible if the install dir is
non-deterministic.

This models the [Bazel][bazel] use-case with [`rules_haskell`][rules_haskell],
where the Cabal package is built and installed within a Bazel controlled
sandbox directory. This directory is created by Bazel under a non-deterministic
path.

The install directory leaks into the output in two places:

1. The GHC package configuration and cached package-db in the `library-dirs`,
   `dynamic-library-dirs`, and `include-dirs` fields.
2. In the flag hash of the generated interface files.

1\. can be fixed retroactively by replacing the absolute install path by
`${pkgroot}` in the package configuration file and re-caching the package-db.

2\. poses a problem.

```
$ ./build.sh
$ diff -ru install1 install2
Binary files install1/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.dyn_hi and install2/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.dyn_hi differ
Binary files install1/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.hi and install2/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.hi differ

$ diff -u <(ghc --show-iface install1/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.dyn_hi) <(ghc --show-iface install2/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.dyn_hi)
--- /dev/fd/63  2021-12-02 18:28:50.384451386 +0100
+++ /dev/fd/62  2021-12-02 18:28:50.384451386 +0100
@@ -9,7 +9,7 @@
   ABI hash: 40c998ce5a2efd19318802ef4b6e99c8
   export-list hash: fabac45b1ffe69f3e298cb12c382dbdd
   orphan hash: 693e9af84d3dfcc71e640e005bdc5e2e
-  flag hash: 11ce02affc63497bd31721d744d1d5aa
+  flag hash: f6e9c244bf005cd7b0940ab9a3cf58a6
   opt_hash: cb09a535710eb16767a299f2ded44a31
   hpc_hash: 93b885adfe0da089cdf634904fd59f71
   plugin_hash: ad164012d6b1e14942349d58b1132007

$ diff -u <(ghc --show-iface install1/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.hi) <(ghc --show-iface install2/mypackage/lib/x86_64-linux-ghc-8.10.4/mypackage-0.1.0.0/MyLib.hi)
--- /dev/fd/63  2021-12-02 18:28:21.115660287 +0100
+++ /dev/fd/62  2021-12-02 18:28:21.115660287 +0100
@@ -9,7 +9,7 @@
   ABI hash: 40c998ce5a2efd19318802ef4b6e99c8
   export-list hash: fabac45b1ffe69f3e298cb12c382dbdd
   orphan hash: 693e9af84d3dfcc71e640e005bdc5e2e
-  flag hash: 11ce02affc63497bd31721d744d1d5aa
+  flag hash: f6e9c244bf005cd7b0940ab9a3cf58a6
   opt_hash: cb09a535710eb16767a299f2ded44a31
   hpc_hash: 93b885adfe0da089cdf634904fd59f71
   plugin_hash: ad164012d6b1e14942349d58b1132007
```

[bazel]: https://bazel.build
[rules_haskell]: https://haskell.build
