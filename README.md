# CheckM8 Activator — macOS

A macOS tool for bypassing iCloud activation on jailbroken iOS devices. Connects over USB SSH, installs the required tweaks, patches the activation record and MobileGestalt cache, then triggers a userspace reboot to apply the changes.

---

## Requirements

- macOS 12 Monterey or later (Apple Silicon or Intel)
- Xcode command line tools installed
- Target device must be **jailbroken** with SSH enabled (root / alpine)

---

## Supported Devices - A5-A11

**iPhones:** iPhone 4s - iPhoneX

---

## How It Works

1. Connects to the device over USB using `iproxy` to tunnel SSH
2. Verifies the jailbreak is accessible via SSH (`root@127.0.0.1:2222`)
3. Remounts the root filesystem read/write
4. Uploads and extracts **ElleKit** (`ref/ellekit`) to `/var/jb/`
5. Installs **HASNIDylib** (activation patch tweak) via MobileSubstrate
6. Clears existing activation records from the system
7. Uploads `activation_record.plist` and locks it immutable with `chflags`
8. Patches **MobileGestalt** cache using bundled `getkey`, `z`, and `recache` tools
9. Disables OTA update daemons
10. Triggers `launchctl reboot userspace`

---

## Usage

1. Jailbreak the device and make sure SSH is running
2. Connect the device via USB
3. Launch `CheckM8.app`
4. Wait for the device info to populate (Model, S/N, iOS version)
5. Click **Activate iDevice**
6. Wait for the process to complete — the device will reboot userspace automatically

---

## Project Structure

```
CheckM8.xcodeproj           - Xcode project
build.sh                    - Build script (Debug / Release, Universal)
CheckM8/
  main.swift                - Entry point
  AppDelegate.swift         - App lifecycle
  MainViewController.swift  - Main UI (programmatic NSView)
  DeviceManager.swift       - USB device polling via idevice_id
  ActivationEngine.swift    - Core activation logic (SSH, SCP, plist merge)
  Resources/
    Tools/                  - Bundled idevice toolchain (iproxy, ideviceinfo, idevice_id, idevicepair)
    ref/                    - Runtime files deployed to the device
      ellekit               - ElleKit tweak injector (tar)
      activation_record.plist - Fallback activation record
      HASNIDylib            - Activation patch tweak
      HASNIDylib.plist      - MobileSubstrate filter plist
      getkey / z / recache  - MobileGestalt cache tools
      imobiledevice/        - Working directory for gestalt plist operations
    Assets.xcassets/        - App icon
    Info.plist              - Bundle metadata
```

---

## Building

Requires macOS with Xcode installed.

```bash
./build.sh            # Debug build (default)
./build.sh --release  # Release build
./build.sh --clean    # Clean before building
```

Output: `build/Build/Products/Debug/CheckM8.app` (Universal — arm64 + x86_64)

---

## Notes

- SSH credentials are hardcoded to `root` / `alpine` (standard jailbreak defaults)
- The app is built unsigned (`CODE_SIGN_IDENTITY="-"`) — Gatekeeper may require a right-click → Open on first launch
- All idevice tools in `Resources/Tools/` must be executable; the build script does not chmod them automatically
