## Активатор

Активатор Windows и Office с открытым исходным кодом, включающий методы активации HWID, Ohook, KMS38 и Online KMS, а также расширенные возможности устранения неполадок.

```
irm https://get.activated.win | iex
```

## Удаленный доступ - RustDesk

https://github.com/rustdesk/rustdesk

```
==Qfi0TRzgzSQtSOWVmeoVWQjNWTTpkUzpGN2AnNWdDd5JXYzAndxwUNYhjdE9EWiojI5V2aiwiIiojIpBXYiwiI1cTMuQzMx4CO14CO1EjI6ISehxWZyJCLiUzNx4CNzEjL4UjL4UTMiojI0N3boJye
```

## Удаление програм.

https://github.com/Klocman/Bulk-Crap-Uninstaller

### Дравера - программа с открытм исходным кодом

https://sdi-tool.org/download/

## NTP-сервер

31.28.161.68 - ntp2.ntp-servers.net\
5.39.80.51 - ntp5.ntp-servers.net\
192.168.31.1 - мой в локальной сети\

## WinGet

```
winget install -e --id Mobatek.MobaXterm
winget install -e --id SoftMaker.FreeOffice.2021
winget install -e --id PuTTY.PuTTY
winget install -e --id Klocman.BulkCrapUninstaller
winget install -e --id GlennDelahoy.SnappyDriverInstallerOrigin
winget install -e --scope machine --id Opera.Opera
```

```
winget install -e --scope machine --id Google.Chrome
winget install -e --scope machine --id dotPDN.PaintDotNet
winget install -e --scope machine --id Telegram.TelegramDesktop
winget install -e --scope machine --id WhatsApp.WhatsApp
winget install -e --scope machine --id 7zip.7zip
winget install -e --scope machine --id VideoLAN.VLC
winget install -e --scope machine --id RustDesk.RustDesk
winget install -e --scope machine --id SumatraPDF.SumatraPDF
winget install -e --scope machine --id Hibbiki.Chromium
winget install -e --scope machine --id Skillbrains.Lightshot
winget install -e --scope machine --id Cyanfish.NAPS2
winget install -e --scope machine --id PDFgear.PDFgear
winget install -e --scope machine --id Microsoft.VCRedist.2015+.x64
winget install -e --scope machine --id sylikc.JPEGView
```

--source msstore - приложение из Microsoft Store\
--source winget - из основного источника winget

### сайт для поиска пакетов

https://winstall.app \
https://winget.run

## Установка winget

```
irm winget.pro | iex
```

```
irm https://github.com/asheroto/winget-install/releases/latest/download/winget-install.ps1 | iex
```

```
Invoke-WebRequest https://raw.githubusercontent.com/asheroto/winget-installer/master/winget-install.ps1 -UseBasicParsing | iex
```

```
Install-Script winget-install -Force
```

### On Windows 11 IoT

```
irm asheroto.com/winget | iex
```

```
irm https://github.com/asheroto/winget-install/releases/latest/download/winget-install.ps1 | iex
```

## Отимизатор

```
irm "https://christitus.com/win"| iex
```

## Директория для программ

```
PortableApps
```

## Настроки системы

Перезапуск проводника CMD

```
taskkill /f /im explorer.exe & start explorer.exe
```

Перезапуск проводника ПОУЕР ШЕЛ

```
Stop-Process -Name explorer -Force; Start-Process explorer.exe
```

Переименовение пользователя Win + R

```
lusrmgr.msc
```

Создать пользователя с установленным паролем:
`net user "Пользователь" "Пароль" /add`

```
net user User 1111 /add
```

```
net user EnergoEffect 2413 /add
```

Удалить пользователя:
`net user "Пользователь" /delete`

```
net user User /delete
```

Удаление папки пользователя:

```
rmdir /s /q "C:\Users\User"
Remove-Item -Path "C:\Users\User" -Recurse -Force
```

Через панле упрвалену удаление лучще (так как удаляется все файлы и папки) \
`Панель управления\Учетные записи пользователей\Учетные записи пользователей\Управление учетными записями`

Изменить пароль уже существующего пользователя: \
`net user "Пользователь" "Пароль"`

```
net user User 2222
```

Отключить обязательную смену/установку пароля при первом входе пользователя: \
`net user "Пользователь" /passwordreq:no`

```
net user User /passwordreq:no
```

Добавить пользователя в локальную группу:

```
net localgroup "Администраторы" EnergoEffect /add
```

Удалить пользователя из локальной группы:

```
net localgroup "Администраторы" EnergoEffect /delete
```

## Сохранить драйверы Windows 11 в директорию PowerShell

```
Export-WindowsDriver -Online -Destination "\\192.168.31.12\1. обмен\27. IT\Driver"
```

```
Export-WindowsDriver -Online -Destination "C:\Driver-test"
```

Автоматически установить драйверы, которые подходят текущему оборудованию через powershell

```
dism /Online /Add-Driver /Driver:"\\192.168.31.12\1. обмен\27. IT\Driver" /Recurse
```
