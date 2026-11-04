# Chatty

<p align="center">
  <img src="images/icon.png" width="96" height="96" alt="Chatty Logo" style="border-radius: 20px;">
</p>

<p align="center">
  <b>A sleek, Telegram & iOS 26+ grade real-time messenger built with Flutter, Firebase, and Cloudflare R2.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android-black" alt="Platforms">
  <img src="https://img.shields.io/badge/Database-Cloud%20Firestore-FFCA28?logo=firebase&logoColor=black" alt="Firestore">
  <img src="https://img.shields.io/badge/Storage-Cloudflare%20R2%20%2B%20Firebase-F38020?logo=cloudflare&logoColor=white" alt="Storage">
  <img src="https://img.shields.io/badge/UI%2FUX-Telegram%20%26%20iOS%20Liquid%20Glass-white?logo=apple&logoColor=black" alt="Liquid Glass UI">
</p>

---

## Overview

**Chatty** is a modern, high-performance messaging application crafted with Flutter, designed to offer a fluid, tactile chat experience on both iOS and Android. Built with a pure monochrome aesthetic, frosted liquid glass effects, interactive slidable tiles, seekable audio waveforms, and dual-tier cloud storage, Chatty delivers seamless real-time communication.

---

## Key Features

### 💎 Telegram & iOS 26+ Liquid Glass UI/UX
- **Liquid Glass Bubbles**: Multi-stop translucent gradients (`#28282E` to `#1D1D22` in dark mode; `#FFFFFF` to `#ECECEF` in light mode) with `0.75px` - `0.85px` specular edge refraction borders that catch ambient light without heavy full-screen blur overhead.
- **iOS 3D Touch Magnetic Pop-Up**:
  - Touch compression feedback (`0.97x`) on press down.
  - Heavy haptic trigger on hold (`AppHaptics.heavy()`).
  - Spring-scale magnetic elevation (`1.04x`) above a full-screen frosted glass blur backdrop (`sigma: 16`).
  - Integrated quick reaction emoji capsule and native context menu (`Reply`, `Copy`, `Edit`, `Delete`).
- **Double-Tap Quick Heart (`❤️`) Reaction**: Instant double-tap gesture on any message bubble produces a spring-scale particle burst with tactile haptic feedback and real-time Firestore sync.
- **Message Clustering**: Dynamic corner radii and snug consecutive message grouping.
- **Ambient Depth Canvas**: Subtle gradient background depth that accentuates message bubble translucency.

### ⚡ Interactive Multi-Action Slidable Tiles
- **Swipe Right**:
  - 📌 **Pin / Unpin** (Amber `#F59E0B`): Pin critical conversations to the top.
  - 📬 **Mark Read / Unread** (Royal Blue `#2563EB`): Toggle conversation unread state with instant badge updates.
- **Swipe Left**:
  - ⚙️ **More / Options** (Slate `#4B5563`): Quick context menu for profile viewing and notifications.
  - 🗑️ **Delete** (Crimson `#DC2626`): Complete conversation wipe with confirmation bottom sheet.
- **Physics**: Natural rubber-band resistance beyond the 148px threshold with spring snapping and tap-to-close behavior.

### 🎙️ Seekable Audio Waveform Voice Notes
- **Interactive Speech Envelope Waveform**: Contoured 26-bar waveform visualization reflecting natural speech cadence.
- **Drag-to-Scrub**: Drag or tap anywhere on the waveform for smooth seekable playback.
- **Speed Multiplier**: Instant one-tap cycling between `1.0x`, `1.5x`, and `2.0x` speeds.
- **Zero-Latency State Machine**: Immediate transition to animated play/pause states without loading spinner stutter.

### 📸 High-Resolution Media & Cloudflare R2 Storage
- **Intelligent Dual Storage Pipeline**: Primary uploads route through **Cloudflare R2** (S3-compatible bucket) for ultra-low latency and zero egress fees, with automated fallback to **Firebase Storage**.
- **Smart Compression**: On-device image optimization keeps photo transfers under 100KB while preserving visual clarity.
- **Media Viewer**: Full-screen interactive viewer with pinch-to-zoom, hero animations, and pan dismissal.

### ⚡ Real-Time Engine & Presence
- **Instant Messaging**: Low-latency message synchronization powered by Google Cloud Firestore.
- **Live Online Presence**: Knockout indicator badges on 52pt rounded avatars reflecting real-time user connectivity.
- **Live Typing Wave**: Animated bouncing dot wave indicators with automatic timeouts.
- **Delivery Receipts**: Outgoing status indicators (single check sent, double check read).
- **In-Chat Message Search**: Search within conversations with matching counter, up/down stepper navigation, and persistent scroll position.
- **Global User Search**: Instant user lookup across the database by `@username` handle or email.

### 🔒 Privacy & Hygiene
- **Complete Wipe**: Conversation deletion purges both Firestore message records and associated Cloudflare R2 / Firebase media assets.
- **Credential Isolation**: Cloudflare R2 keys and bucket settings are isolated in `r2_credentials.dart` (strictly git-ignored).

---

## Tech Stack & Architecture

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Impeller 120Hz display optimization) |
| **Language** | Dart 3.x |
| **Backend & DB** | Google Cloud Firestore |
| **Authentication** | Firebase Auth & Google Sign-In |
| **Media Storage** | Cloudflare R2 (S3 API) + Firebase Storage Fallback |
| **Audio Engine** | `just_audio` + `record` |
| **Typography** | Lexend (Custom font scale) |
| **Design System** | Custom Liquid Glass monochrome theme system |

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.2.3`)
- Xcode 15+ (for iOS builds)
- Android Studio / Android SDK (for Android builds)
- A Firebase project with Authentication & Cloud Firestore enabled

### 1. Clone the Repository
```bash
git clone https://github.com/imransihab0/Chatty.git
cd Chatty
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Configuration
- Run `flutterfire configure` to generate `lib/firebase_options.dart` for your Firebase project, or place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in their respective platform directories.

### 4. (Optional) Cloudflare R2 Storage Setup
To enable zero-egress Cloudflare R2 media storage:
1. Copy the example credentials template:
   ```bash
   cp lib/services/r2_credentials.dart.example lib/services/r2_credentials.dart
   ```
2. Fill in your R2 credentials:
   ```dart
   class R2Credentials {
     static const String accountId = 'your_cloudflare_account_id';
     static const String accessKeyId = 'your_r2_access_key_id';
     static const String secretAccessKey = 'your_r2_secret_access_key';
     static const String bucketName = 'your_bucket_name';
     static const String publicDomain = 'https://pub-your_id.r2.dev';
   }
   ```
*(If omitted, Chatty will automatically fallback to standard Firebase Storage).*

### 5. Run the App
```bash
# Debug mode
flutter run

# Release mode on iOS physical device
flutter run -d <device_id> --release
```

---

## Building Releases

### Android (Split-per-ABI APKs)
```bash
flutter build apk --split-per-abi --release
```
Outputs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~21.4 MB)
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (~19.4 MB)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (~22.9 MB)

### iOS (Release)
```bash
flutter build ios --release
```

---

## Download

Pre-built Android release binaries can be found in the [GitHub Releases](https://github.com/imransihab0/Chatty/releases) section.

---

## Author

Crafted by **Imran Sihab**
- GitHub: [@imransihab0](https://github.com/imransihab0)
- Portfolio: [imransihab.wordpress.com](https://imransihab.wordpress.com/projects)

---

## License

This project is released for personal and portfolio demonstration purposes. All rights reserved.
