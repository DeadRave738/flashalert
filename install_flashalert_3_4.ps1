# FlashAlert 3.4: minimal boot receiver installer.
# Run from any PowerShell location: .\install_flashalert_3_4.ps1 -Project 'F:\Development\flash_alert'
param([string]$Project = 'F:\Development\flash_alert')
$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path -LiteralPath $Project).Path
$manifest = Join-Path $projectDir 'android\app\src\main\AndroidManifest.xml'
$receiverSource = Join-Path $PSScriptRoot 'android\app\src\main\kotlin\com\flashalert\flash_alert\BootReceiver.kt'
$receiverTarget = Join-Path $projectDir 'android\app\src\main\kotlin\com\flashalert\flash_alert\BootReceiver.kt'
if (-not (Test-Path -LiteralPath $manifest) -or -not (Test-Path -LiteralPath $receiverSource)) {
    throw 'Не найден AndroidManifest.xml проекта или BootReceiver.kt обновления.'
}
if (Test-Path -LiteralPath $receiverTarget) {
    throw 'BootReceiver.kt уже существует. Ничего не перезаписано.'
}
$raw = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
if ($raw -notmatch '<manifest\b' -or $raw -notmatch '</application>') { throw 'Неожиданная структура AndroidManifest.xml.' }
if ($raw -match 'android\.permission\.RECEIVE_BOOT_COMPLETED' -or $raw -match 'android:name="\.BootReceiver"') {
    throw 'В манифесте уже есть настройки автозапуска. Обновление остановлено во избежание дублирования.'
}
# Preserve the original byte-for-byte backup and only change this project's manifest.
$backup = "$manifest.backup-before-3.4"
if (Test-Path -LiteralPath $backup) { throw "Резервная копия уже существует: $backup" }
Copy-Item -LiteralPath $manifest -Destination $backup -ErrorAction Stop
$permission = '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />'
$receiver = @'
        <receiver android:name=".BootReceiver" android:enabled="true" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
'@
$updated = $raw -replace '(?=<application\b)', ($permission + "`r`n    ")
$updated = $updated -replace '</application>', ($receiver + "`r`n    </application>")
try {
    [xml]$parsed = $updated
    Copy-Item -LiteralPath $receiverSource -Destination $receiverTarget -ErrorAction Stop
    # UTF-8 without BOM for Android manifest compatibility.
    [System.IO.File]::WriteAllText($manifest, $updated, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Готово. BootReceiver добавлен; исходный AndroidManifest.xml сохранён:' -ForegroundColor Green
    Write-Host $backup
} catch {
    if (Test-Path -LiteralPath $receiverTarget) { Remove-Item -LiteralPath $receiverTarget -Force }
    Copy-Item -LiteralPath $backup -Destination $manifest -Force
    throw
}
