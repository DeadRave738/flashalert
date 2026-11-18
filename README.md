#Почему я создал это приложение

В Play Market а так же на просторах интернета есть куча таких приложений которые используют вспышку для оповещений
но столько сайтов с вредоносными программами и всякими странными архивами что просто решил "НАВАЙБКОДИТЬ" приложение сам,
НУ и заодно если кому то понадобится выложил сюда.

Всем добра (меньше чем три <3)

 
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
