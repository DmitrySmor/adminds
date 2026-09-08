# adminds

> Modular infrastructure automation toolkit for Linux, Docker and server provisioning.

`adminds` — монорепозиторий с набором инструментов для автоматизации настройки серверов, Linux-систем, Docker и другой инфраструктуры.

Проект состоит из независимых направлений автоматизации. Каждое направление может иметь собственную внутреннюю архитектуру и систему сборки.

---

## Quick Start

### Debian 13 — base server setup

Базовая настройка нового Debian 13 сервера.

Workflow выполняет стандартную подготовку системы, установку необходимых пакетов и Docker.

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/main/build/nala_debian_13.sh | sudo bash
```

---

## Hawser

### Install Hawser agent — Edge Mode

Установка Hawser-агента в Edge Mode.

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/setup/install-hawser-edge.sh | sudo bash
```

### Uninstall Hawser agent

Удаление Hawser-агента.

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/setup/uninstall-hawser-edge.sh | sudo bash
```

### Update Hawser configuration

Обновление конфигурации Hawser-агента.

```bash
curl -fsSL https://raw.githubusercontent.com/DmitrySmor/adminds/refs/heads/main/scripts/setup/update-hawser-config.sh | sudo bash
```

---

## Architecture

### Monorepository

`adminds` — монорепозиторий.

Каждый корневой каталог представляет отдельное направление автоматизации:

```text
adminds/
├── scripts/     → Linux / Bash automation
├── docker/      → Docker-related automation
├── OpenWrt/     → OpenWrt automation
└── ...
```

Каждое направление может иметь собственную внутреннюю структуру, правила разработки и систему сборки.

Мы не пытаемся создавать единый универсальный builder для всего репозитория.

---

## Scripts

Текущее направление `scripts` предназначено для автоматизации Linux-систем с использованием Bash.

```text
adminds/
├── .github/
│   └── workflows/
│       └── scripts-ci.yml
│
├── scripts/
│   ├── src/
│   │   ├── lib/              → Переиспользуемые библиотеки
│   │   │   ├── colors.sh
│   │   │   └── log.sh
│   │   │
│   │   ├── tasks/            → Атомарные действия
│   │   │   ├── check_os.sh
│   │   │   ├── update_system.sh
│   │   │   ├── install_packages.sh
│   │   │   ├── configure_locale.sh
│   │   │   ├── configure_timezone.sh
│   │   │   └── install_docker.sh
│   │   │
│   │   └── workflows/        → Последовательности выполнения
│   │       └── nala_debian_13.sh
│   │
│   └── build.sh              → Сборка workflow
│
├── build/                    → Собранные standalone-скрипты
│
└── README.md
```

---

## Components

### `lib`

Переиспользуемые библиотеки с общей функциональностью.

Например:

- логирование;
- форматирование вывода;
- цвета терминала;
- другие вспомогательные функции.

Библиотеки подключаются в каждый собираемый workflow.

### `tasks`

Атомарные действия.

Каждый task отвечает за одну конкретную операцию и вызывается непосредственно из workflow.

Например:

```text
check_os
update_system
configure_locale
configure_timezone
install_packages
install_docker
```

Tasks не определяют общий порядок выполнения системы.

### `workflows`

Workflow определяет последовательность выполнения tasks.

Workflow является источником истины для конкретного сценария автоматизации.

Например:

```text
nala_debian_13
```

является базовым workflow для подготовки нового Debian 13 сервера.

Дополнительные workflow создаются поверх базовой конфигурации и добавляют необходимые действия для конкретных сервисов.

---

## Build System

Для всех workflow используется единый builder:

```bash
./scripts/build.sh <workflow>
```

Например:

```bash
./scripts/build.sh nala_debian_13
```

В результате создаётся standalone-скрипт:

```text
build/nala_debian_13.sh
```

Собранный файл содержит необходимые библиотеки, используемые tasks и сам workflow.

После сборки его можно запускать непосредственно на сервере:

```bash
sudo ./build/nala_debian_13.sh
```

Или использовать удалённый запуск через `curl`, как показано в разделе [Quick Start](#quick-start).

---

## Workflow Model

Базовый workflow используется как основа для подготовки нового сервера.

Например:

```text
Base workflow
      │
      ├── System preparation
      ├── Base packages
      ├── Docker
      └── Common configuration
             │
             ▼
     Additional workflow
             │
             ├── System update
             ├── Service packages
             ├── Service installation
             └── Service configuration
```

Такой подход позволяет разделить:

- общую подготовку сервера;
- установку базовых компонентов;
- настройку конкретных сервисов;
- переиспользуемую функциональность;
- порядок выполнения операций.

---

## Design Principles

### Small and reusable

Функциональность разбивается на небольшие независимые tasks, которые могут использоваться в разных workflow.

### Workflow as source of truth

Workflow определяет, какие действия необходимы и в каком порядке они должны выполняться.

### One builder per direction

Каждое направление автоматизации может иметь собственную систему сборки.

Для `scripts` используется единый:

```text
scripts/build.sh
```

### Standalone output

Каждый собранный workflow превращается в самостоятельный Bash-скрипт, который можно запускать без исходной структуры проекта.

### No unnecessary dependency system

Проект не использует сложную систему зависимостей между tasks.

Порядок выполнения определяется непосредственно workflow.

---

## Creating a Workflow

Новый workflow для направления `scripts` создаётся в:

```text
scripts/src/workflows/
```

Например:

```text
scripts/src/workflows/my_service.sh
```

Внутри workflow указывается необходимая последовательность действий:

```bash
check_root
check_os
update_system
install_packages
install_my_service
configure_my_service
```

После этого workflow собирается стандартным builder'ом:

```bash
./scripts/build.sh my_service
```

Результат:

```text
build/my_service.sh
```

Builder проверяет:

- Bash-синтаксис исходных файлов;
- существование вызываемых функций;
- отсутствие дублирующихся task-функций;
- отсутствие дублирующихся lib-функций.

Если workflow вызывает неизвестную функцию, сборка завершается с ошибкой.

---

## Repository Structure

Общая структура репозитория остаётся независимой для каждого направления:

```text
adminds/
├── .github/
│   └── workflows/
│
├── scripts/
│   ├── src/
│   │   ├── lib/
│   │   ├── tasks/
│   │   └── workflows/
│   │
│   ├── build.sh
│   └── ...
│
├── docker/
├── OpenWrt/
├── build/
└── README.md
```

Новые направления могут добавляться независимо и не обязаны использовать архитектуру `scripts`.

---

## Quick Development

Клонирование репозитория:

```bash
git clone https://github.com/DmitrySmor/adminds.git
cd adminds
```

Сборка базового workflow:

```bash
./scripts/build.sh nala_debian_13
```

Запуск:

```bash
sudo ./build/nala_debian_13.sh
```

---

## License

This project is licensed under the GNU General Public License v3.0.
See the [LICENSE](LICENSE) file for details.
