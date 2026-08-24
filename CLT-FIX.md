# Fixing the broken Apple developer tools on this Mac

**Written:** 24 August 2026
**Machine:** macOS 26.5.2, Apple Silicon
**Status:** Diagnosed, tested, and ready to fix. Two commands needed. Both need your password.

---

## The short version

Apple's Command Line Tools — the free toolkit that turns Swift source code into a
running Mac app — has been updated many times on this machine over the years.
Each update laid down new files but **failed to clean up three old ones**. Those
leftovers, dated 2023 and 2024, now sit alongside their modern replacements and
argue with them.

The result is two separate breakages:

1. **Any Swift app that uses the Mac interface toolkit fails to build.** That is
   essentially every Mac app, including Thyme Custom.
2. **The Swift package manager is broken too** — a second, independent problem
   caused by the same kind of leftover, which I found while checking for others.

Neither is a problem with your code. Neither will fix itself. Both are fixed by
deleting six stale files, which takes about five seconds and needs your password
once.

---

## Problem 1: the duplicate instruction file

### What is going on

Inside the toolkit there is a folder of "module maps" — small text files that
tell the compiler what building blocks exist and where to find them. Think of
them as an index card catalogue.

That folder contains two cards describing the *same* building block, called
`SwiftBridging`:

| File | Date | Verdict |
|---|---|---|
| `bridging.modulemap` | 14 Oct 2025 | **Current. Keep it.** |
| `module.modulemap` | 17 Aug 2023 | **Stale leftover. Delete it.** |

The two files are byte-for-byte identical apart from one line: the copyright
year reads 2023 in one and 2024 in the other. That is the fingerprint of an old
file the installer renamed rather than replaced — Apple moved the card from
`module.modulemap` to `bridging.modulemap` and forgot to throw the original away.

The compiler reads every card in the folder. It finds two cards for the same
thing, cannot decide which is authoritative, and stops with an error.

### The evidence

Building the simplest possible Mac program — two lines, "load the Mac interface
toolkit, print hello" — fails like this:

```
/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap:13:8:
    error: redefinition of module 'SwiftBridging'
/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap:13:8:
    note: previously defined here
```

Two further pieces confirm which file is the stale one:

- There is a **third, master index file** one folder up
  (`/Library/Developer/CommandLineTools/usr/include/module.modulemap`, dated
  October 2025). It contains a single instruction: *"find `SwiftBridging` in
  `swift/bridging.modulemap`."* The current toolkit points at
  `bridging.modulemap` by name. Nothing anywhere points at the 2023 file.
- The 2023 file is one of only a handful of files in the entire toolkit still
  dated before 2025. Everything around it was replaced in October/November 2025.

### Proof the fix works

I could not delete the file (it is owned by the system and I have no password),
so I tested the removal without touching anything, using a compiler feature that
lets you pretend a file has different contents for the duration of one build.
I told the compiler to treat the 2023 file as empty — the same thing it sees if
the file is not there — and rebuilt.

- **Before:** build fails with the duplicate-definition error.
- **After (file treated as absent):** builds cleanly and the program runs. I
  repeated this with a larger test loading five major Apple toolkits at once
  (Mac interface, Foundation, SwiftUI, notifications, Combine). Clean build,
  program ran, no errors.

So **deleting that one file fully fixes problem 1.** Nothing else is implicated,
and `bridging.modulemap` must stay — it is the card the toolkit actually uses.

---

## Problem 2: the broken Swift package manager (found while checking)

You asked me to look for other leftovers. I found one, and it is a live
breakage rather than a theoretical risk.

### What is going on

The Swift package manager (`swift build`, used by most modern Swift projects to
pull in libraries and compile) reads a project's `Package.swift` settings file.
To understand that file it consults a specification of what settings are legal.

That specification exists twice in the same folder, in "public" and "private"
versions — and the package manager always prefers the private one:

| File | Built by | Date | Verdict |
|---|---|---|---|
| `…swiftinterface` (public) | Swift 6.2.1 | 17 Oct 2025 | Current |
| `…private.swiftinterface` | Swift 5.10 | 15 Feb 2024 | **Stale leftover** |

So the package manager reads a two-year-old specification, builds against it,
and then tries to connect that to the actual October 2025 library — which no
longer has the pieces the 2024 specification promised. The connection fails.

There are four such stale files: a private specification for each of the two
chip types (Apple Silicon and Intel), in each of the two folders `ManifestAPI`
and `PluginAPI`.

### The evidence

Creating a brand-new, empty, three-line Swift package and running `swift build`:

```
error: 'pkgtest': Invalid manifest
Undefined symbols for architecture arm64:
  "PackageDescription.Package.__allocating_init(name:…)"
ld: symbol(s) not found for architecture arm64
```

That is on a package with no dependencies and no code — so it is the toolkit,
not any project.

### Proof the fix works

I copied the folder to a scratch area, deleted only the four stale private
specification files from the copy, and built the same package settings file
against the copy:

- **Copy with the stale files removed:** build succeeded.
- **Identical copy with the stale files left in:** same failure as above.

Same file, same command, only difference is the four leftovers. **Deleting them
fixes problem 2.**

---

## What I checked and found to be fine

So you know the rest of the toolkit is healthy:

- **No other duplicate index cards.** I listed every module map in the toolkit
  and inside the current Mac SDK. `SwiftBridging` is the only building block
  defined twice anywhere.
- **The toolchain path is correct.** `xcode-select` points at
  `/Library/Developer/CommandLineTools`, which is right for a machine without
  full Xcode installed.
- **SDK versions line up.** The default SDK is macOS 26.1, symlinks all resolve
  to real folders, none dangling. Your OS is 26.5.2 — an SDK trailing the OS by
  a minor version is completely normal and is not a problem.
- **C and Objective-C builds already work.** Only Swift is affected, because
  only Swift looks in the folder holding the duplicate card.
- **The older-looking folders are meant to be there.** `swift-5.0`, `swift-5.5`,
  `clang/15.0.0`, `clang/16`, and the matching `tapi` folders are compatibility
  support Apple ships deliberately so that apps built with older tools keep
  running. Leave them alone.

**Total genuinely stale files in the whole installation: six.** All six are
listed in the fix below.

---

## Backups (already done)

I copied every file that the fix touches, plus the one good file sitting next to
them, to:

```
/Users/paulclancy/_thymecustom/build/clt-backup/
```

Contents:

```
module.modulemap                                   (the 2023 leftover)
bridging.modulemap                                 (the good file — copied for reference, not being touched)
swiftpm/ManifestAPI/arm64-apple-macos.private.swiftinterface
swiftpm/ManifestAPI/x86_64-apple-macos.private.swiftinterface
swiftpm/PluginAPI/arm64-apple-macos.private.swiftinterface
swiftpm/PluginAPI/x86_64-apple-macos.private.swiftinterface
```

Nothing under `/Library` has been modified. Original dates are preserved on the
copies, so they can be put back byte-for-byte if anything unexpected happens.

---

## The fix — commands to run

Open **Terminal** and paste these. Each will ask for your Mac login password;
type it and press Return (the password will not appear as you type — that is
normal).

**Step 1 — remove the duplicate index card (fixes problem 1):**

```
sudo rm /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
```

**Step 2 — remove the four stale package-manager specifications (fixes problem 2):**

```
sudo rm /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface \
        /Library/Developer/CommandLineTools/usr/lib/swift/pm/PluginAPI/PackagePlugin.swiftmodule/*.private.swiftinterface
```

Step 1 is the one you need for building Thyme Custom. Step 2 only matters if you
or a tool ever runs `swift build` — but since it is already broken and the fix
is the same five seconds, do both.

**Do not** run `softwareupdate`, reinstall the Command Line Tools, or change
`xcode-select`. Those are slow, disruptive, and would not reliably remove these
leftovers anyway — a reinstall is what left them behind in the first place.

---

## What to expect afterwards

- Both commands print nothing at all. Silence means success. Any output is worth
  reading.
- **You no longer need the workaround.** The file
  `/Users/paulclancy/_thymecustom/build/vfs-overlay.yaml` and the
  `-vfsoverlay` flag in the Thyme Custom build were only there to paper over
  problem 1. After the fix they are harmless but unnecessary, and can be removed
  from the build script whenever convenient.
- Nothing else on the Mac changes. No app, no setting, no restart.

---

## How to verify it worked

Paste this into Terminal. No password needed.

```
printf 'import AppKit\nprint("compiler is healthy")\n' > /tmp/clt-test.swift && \
swiftc -o /tmp/clt-test /tmp/clt-test.swift && /tmp/clt-test
```

**Success looks like:** the words `compiler is healthy` and nothing else.

**Still broken looks like:** a block of text containing
`error: redefinition of module 'SwiftBridging'`.

To check the package manager as well:

```
mkdir -p /tmp/pkgcheck/Sources/pkgcheck && cd /tmp/pkgcheck && \
printf '// swift-tools-version:5.9\nimport PackageDescription\nlet package = Package(name: "pkgcheck", targets: [.executableTarget(name: "pkgcheck")])\n' > Package.swift && \
echo 'print("package manager is healthy")' > Sources/pkgcheck/main.swift && \
swift run
```

**Success looks like:** some "Compiling" and "Build complete" lines, then
`package manager is healthy`.

**Still broken looks like:** `error: 'pkgcheck': Invalid manifest` and
`Undefined symbols`.

---

## If something goes wrong

Put the files back from the backup — again with your password:

```
sudo cp -p /Users/paulclancy/_thymecustom/build/clt-backup/module.modulemap \
           /Library/Developer/CommandLineTools/usr/include/swift/
sudo cp -p /Users/paulclancy/_thymecustom/build/clt-backup/swiftpm/ManifestAPI/*.private.swiftinterface \
           /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/
sudo cp -p /Users/paulclancy/_thymecustom/build/clt-backup/swiftpm/PluginAPI/*.private.swiftinterface \
           /Library/Developer/CommandLineTools/usr/lib/swift/pm/PluginAPI/PackagePlugin.swiftmodule/
```

That returns the machine exactly to its current (broken) state, and the
`-vfsoverlay` workaround would work again.
