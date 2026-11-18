# FlashAlert 3.4 — автозапуск после перезагрузки

Минимальное обновление поверх **FlashAlert 3.3**. Не изменяет оформление Liquid Glass, настройки, Flutter, FlashEngine, Gradle, SDK и NDK. **Нет отдельного постоянно работающего сервиса:** после загрузки Android отправляется запрос на восстановление связи с уже разрешённой службой уведомлений. Она при подключении восстанавливает слушатель состояния звонков. Это не гарантирует работу, если HiOS блокирует автозапуск или приложение переведено в «Ограничено».

## Установка

1. Закройте `flutter run` через `q` и сделайте резервную копию проекта.
2. Распакуйте ZIP, откройте PowerShell в папке распакованного обновления.
3. Запустите:

```powershell
.\install_flashalert_3_4.ps1 -Project 'F:\Development\flash_alert'
```

Если политики PowerShell не разрешают выполнение сценария, вместо изменения глобальной политики можно открыть сценарий в редакторе и перенести два фрагмента в `android/app/src/main/AndroidManifest.xml` вручную, затем скопировать `BootReceiver.kt` из архива по соответствующему пути. Сценарий сохраняет `AndroidManifest.xml.backup-before-3.4`, не затрагивает других файлов проекта и прерывается, если настройки автозапуска уже имеются.

**Изменения AndroidManifest.xml:**

Внутри `<manifest>` перед `<application>`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Внутри `<application>`:

```xml
<receiver android:name=".BootReceiver" android:enabled="true" android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
    </intent-filter>
</receiver>
```

4. Соберите через VS Code:

```powershell
cd F:\Development\flash_alert
flutter run -d 105035436L107865
```

5. На TECNO откройте FlashAlert и проверьте системный доступ к уведомлениям и разрешение на состояние телефона. В HiOS/Phone Master включите автозапуск приложения, а в настройках батареи выберите «Без ограничений» или аналогичный пункт, если он доступен. Для проверки перезагрузите телефон, **разблокируйте его первый раз после запуска** и посмотрите в диагностике FlashAlert, подключена ли служба уведомлений; затем проверьте реальным уведомлением, не открывая FlashAlert перед тестом.

## Ограничения

- Android сам управляет `NotificationListenerService`; запуск UI после перезагрузки не выполняется.
- Первое разблокирование после перезагрузки может быть необходимо для обычного (не direct-boot-aware) приложения.
- При ограниченной фоновой активности Android 13/HiOS может задержать BOOT_COMPLETED или заблокировать службу. Нет 100%-ной гарантии автозапуска.
- Никаких новых тестовых имитаций звонка нет.
- Android APK в этой среде не собирался; сборку нужно проверить на TECNO.
