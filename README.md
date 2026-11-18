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
