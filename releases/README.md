# Chatty Android Release APKs (Split-per-ABI)

These release APKs are compiled with `--split-per-abi` for optimized package sizes and maximum hardware compatibility:

| APK File | Architecture | Target Devices | Size |
|---|---|---|---|
| `app-arm64-v8a-release.apk` | 64-bit ARM (AArch64) | **Recommended for almost all modern Android phones** (Samsung, Xiaomi, Pixel, OnePlus, etc.) | ~22.4 MB |
| `app-armeabi-v7a-release.apk` | 32-bit ARM | Older 32-bit Android phones and legacy devices | ~20.3 MB |
| `app-x86_64-release.apk` | 64-bit x86 | Android emulators, ChromeOS / Chromebooks, and Intel-based tablets | ~24.0 MB |

### Installation Instructions
1. Download the APK matching your device (for almost any phone from 2016 onwards, choose `app-arm64-v8a-release.apk`).
2. Open the downloaded file on your Android device.
3. If prompted, allow "Install unknown apps" from your browser/file manager.
4. Tap **Install** to enjoy Chatty!
