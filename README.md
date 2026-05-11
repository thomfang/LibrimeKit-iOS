# LibrimeKit-iOS

Pre-built [librime](https://github.com/rime/librime) XCFrameworks for iOS, packaged for use in the Scripting app's custom keyboard extension.

## Quick start

```bash
make framework
```

This downloads the latest published `Frameworks.tgz` from GitHub Releases and extracts to `./Frameworks/`. Consumers (the Scripting app) point their Xcode project to these XCFrameworks.

## Build from source

```bash
git clone --recurse-submodules https://github.com/thomfang/LibrimeKit-iOS.git
cd LibrimeKit-iOS
make build
```

`make build` runs the full pipeline:

1. Boost via [imfuxiao/boost-iosx](https://github.com/imfuxiao/boost-iosx) (submodule)
2. Small deps (yaml-cpp, leveldb, marisa, opencc, glog) cross-compiled for iOS
3. librime 1.16.1 linked against the above
4. Packaged into XCFrameworks under `./Frameworks/`

Total cold build is ~1h on Apple Silicon (Boost dominates).

## Slice coverage

Each produced XCFramework contains:

- `ios-arm64` — device
- `ios-arm64_x86_64-simulator` — simulator (both archs lipo'd)

`make build PLATFORMS=ios,maccatalyst` adds Catalyst (optional).

## License

The build scripts in this repository are MIT-licensed. The produced binaries inherit the upstream licenses (librime BSD-3, Boost BSL-1.0, glog BSD-3, opencc Apache-2.0, yaml-cpp MIT, leveldb BSD-3, marisa BSD-2).
