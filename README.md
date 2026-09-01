# Всем привет!

### Настрока сисетмы через Nala (стандарные пакеты + docker)

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/bootstrap/nala_debian_13.sh | sudo bash
```

### Установка Hawser-агента в Edge Mode

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/setup/install-hawser-edge.sh | sudo bash
```

### Удаление Hawser-агента

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/setup/uninstall-hawser-edge.sh | sudo bash
```

### Обновление конфигурации Hawser-агента

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/setup/update-hawser-config.sh | sudo bash
```

## Главное правило

adminds — монорепозиторий.

Каждый корневой каталог — отдельное направление автоматизации

```
adminds/
│
├── scripts/     → Linux/Bash automation
├── docker/      → Docker-related automation
├── OpenWrt/     → OpenWrt automation
└── ...
```

И каждое направление может иметь свою внутреннюю систему сборки.

То есть мы не пытаемся сделать один гигантский универсальный builder для всего adminds.

```
adminds/
├── .github/
│   └── workflows/
│       └── scripts-ci.yml
│
├── scripts/
│   ├── src/
│   │   ├── lib/ 						- Переиспользуемые библиотеки
│   │   │   ├── colors.sh
│   │   │   └── log.sh
│   │   │
│   │   ├── tasks/ 						- Атомарные действия
│   │   │   ├── check_os.sh
│   │   │   ├── update_system.sh
│   │   │   ├── install_packages.sh
│   │   │   ├── configure_locale.sh
│   │   │   ├── configure_timezone.sh
│   │   │   └── install_docker.sh
│   │   │
│   │   └── workflows/ 					- Здесь описывается последовательность выполнения tasks
│   │       └── nala_debian_13.sh
│   │
│   └── tests/
│       ├── test_colors.sh
│       ├── test_log.sh
│       └── ...
│
└── README.md
```
