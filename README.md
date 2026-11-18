# FlashAlert ⚡

Android application that uses the camera flashlight to signal incoming calls and notifications.

**Version:** 3.4  
**Author:** DeadRave738  
**Developed with assistance from:** ChatGPT by OpenAI

## Features

- Flash alerts for incoming calls
- Flash alerts for app notifications
- Customizable flashing patterns
- Quiet hours
- Battery and thermal safety controls
- Notification listener recovery after reboot
- Dark Liquid Glass-style interface

## Requirements

- Android smartphone with a camera flashlight
- Notification access permission
- Phone-state permission for call alerts
- Background activity permission where required by the device manufacturer

## Build from source

Install Flutter and the Android development tools.

```powershell
flutter pub get
flutter build apk --release
The APK is generated at:

build/app/outputs/flutter-apk/app-release.apk

Note: The current project uses a debug signing key for release builds.
Configure a private production signing key before distributing official APKs.
Compatibility
Tested on TECNO Spark 10 Pro, Android 13 / HiOS.

Some manufacturers restrict background activity, so automatic recovery after reboot is not guaranteed on every device.
License
MIT License. See LICENSE.
Credits
Created by DeadRave738 with the assistance of ChatGPT by OpenAI.
