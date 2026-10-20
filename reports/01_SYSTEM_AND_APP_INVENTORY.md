# 01 — System & Application Inventory

## Investigation Date
2026-10-18

## System Environment

| Property | Value |
|---|---|
| **Model** | MacBook Air (Mac17,4) |
| **Chip** | Apple M5 (4 Super + 6 Efficiency cores) |
| **Memory** | 32 GB unified |
| **OS** | macOS 27.2 (26B5112a) / Darwin 27.2.0 |
| **SIP** | Enabled |
| **User** | Nilambar Behera (nilambarbehera) |
| **Uptime** | 1 day, 7 hours at time of investigation |

## Blip Application Bundle

| Property | Value | Evidence |
|---|---|---|
| **Path** | `/Applications/Blip.app` | `mdfind` Spotlight query |
| **Bundle Identifier** | `net.blip.macos` | Info.plist `CFBundleIdentifier` |
| **Display Name** | Blip | Info.plist `AppDisplayName` |
| **Version** | 1.2.3 (build 20260927200815) | Info.plist `CFBundleShortVersionString` / `CFBundleVersion` |
| **Executable** | `Contents/MacOS/Blip` | Info.plist `CFBundleExecutable` |
| **Format** | Mach-O universal binary (x86_64 + arm64) | `lipo -info`, `file` |
| **Bundle Size** | 67 MB | `du -sh` |
| **Category** | Productivity | Info.plist `LSApplicationCategoryType` |
| **Min macOS** | 12.0 | Info.plist `LSMinimumSystemVersion` |
| **LSUIElement** | `true` (menu-bar / background app, no Dock icon) | Info.plist |
| **URL Scheme** | `blip://` | Info.plist `CFBundleURLTypes` |
| **Server URL** | `https://prod.blip.net` | Info.plist `ServerURL` |
| **Web App URL** | `https://blip.net` | Info.plist `WebAppURL` |
| **Auto-Update** | Sparkle 2.9.1, appcast at `https://static.blip.net/mac/appcast.xml` | Info.plist `SUFeedURL` |
| **Copyright** | © 2026 Blip Studio Inc. | Info.plist |
| **App Group** | `AY8UB8KTUX.blip` | Info.plist `AppGroupName` |
| **Team ID** | `AY8UB8KTUX` | `codesign -dv` |
| **Principal Class** | `DesktopApplication` | Info.plist `NSPrincipalClass` |
| **NIB** | MainMenu.nib | Info.plist `NSMainNibFile` |
| **Build toolchain** | Xcode 26.6 (17F113), macOS SDK 26.5 | Info.plist `DTXcode`/`DTSDKName` |

## Code Signing

| Property | Value |
|---|---|
| **Authority Chain** | Developer ID Application: Blip Studio Inc. (AY8UB8KTUX) → Developer ID Certification Authority → Apple Root CA |
| **Notarization** | Stapled ticket present |
| **Runtime** | Hardened Runtime v26.5.0 |
| **Code Directory** | v20500, SHA-256, 109+7 hashes |
| **Timestamp** | 28 Sep 2026 01:40:15 |
| **Sealed Resources** | v2, 13 rules, 16 files |

## Entitlements

```xml
com.apple.security.application-groups: [AY8UB8KTUX.blip]
com.apple.security.cs.disable-library-validation: true
com.apple.security.personal-information.photos-library: true
```

> [!NOTE]
> **Not sandboxed** — no `com.apple.security.app-sandbox` entitlement. The app runs outside the macOS App Sandbox.
> `disable-library-validation` allows loading the Go-based BlipKit framework which contains cgo-compiled code.

## Embedded Frameworks

| Framework | Size | Purpose |
|---|---|---|
| `BlipKit.framework` | ~54 MB (universal) | Core transfer engine — Go + Swift hybrid |
| `Sparkle.framework` | ~1.6 MB | Auto-update (Sparkle 2.9.1) |
| `libswiftCompatibilitySpan.dylib` | 184 KB | Swift ABI compatibility |

## App Extensions (PlugIns)

| Extension | Bundle ID | Type | Purpose |
|---|---|---|---|
| `BlipPreviewProvider.appex` | `net.blip.macos.preview-provider` | QuickLook Preview | File preview thumbnails |
| `BlipShare.appex` | `net.blip.macos.share` | Share Extension | macOS Share Sheet integration |

## Login Items

| Component | Path |
|---|---|
| `LaunchAtLoginHelper.app` | `Contents/Library/LoginItems/LaunchAtLoginHelper.app` |

## macOS Services

Blip registers a macOS Service with keyboard shortcut ⌘B that accepts:
- `public.content`
- `public.url`
- `public.directory`
- `public.folder`

## Resources

| File | Size | Purpose |
|---|---|---|
| `AppIcon.icns` | 42 KB | Application icon |
| `Assets.car` (main) | 3.3 MB | Compiled asset catalog |
| `Intents.intentdefinition` | 10 KB | Siri Intents (INSendMessageIntent) |
| `MainMenu.nib` | 22 KB | Main menu interface |
| `SwiftProtobuf_SwiftProtobuf.bundle` | Privacy manifest | Protocol Buffers |
| `SwiftImageReadWrite.bundle` | Privacy manifest | Image I/O |
| `QRCode_QRCode.bundle` | Privacy manifest | QR code generation |

## BlipKit Resources

| File | Purpose |
|---|---|
| `Chime.wav` (164 KB) | Transfer received sound |
| `Fail.wav` (167 KB) | Transfer error sound |
| `Out.wav` (188 KB) | Transfer sent sound |
| `Resolve.wav` (110 KB) | Connection resolved sound |
| `Assets.car` (38 KB) | Framework assets |

## User Data Footprint

| Location | Size | Purpose |
|---|---|---|
| `~/Library/Preferences/net.blip.macos.plist` | 4 KB | User preferences |
| `~/Library/Group Containers/AY8UB8KTUX.blip/` | ≈0 | Shared app group container |
| `~/Library/Caches/net.blip.macos/` | 136 KB | Application cache |
| `~/Library/HTTPStorages/net.blip.macos/` | 60 KB | HTTP cookie storage |
| `~/Library/Caches/SentryCrash/Blip/` | 4 KB | Crash reporter data |
| `~/Library/Containers/net.blip.macos.share/` | 36 KB | Share extension sandbox |
| `~/Library/Containers/net.blip.macos.preview-provider/` | 4 KB | Preview extension sandbox |
| **Total user data** | **≈244 KB** | Minimal persistent footprint |

## Confidence Assessment
- **Observation method**: Standard macOS inspection tools (`plutil`, `codesign`, `lipo`, `file`, `otool`, `du`, `mdfind`, `find`)
- **Confidence**: ★★★★★ High — all data from read-only system tools on the installed bundle
- **Limitation**: Cannot inspect encrypted preferences content without running the app interactively
