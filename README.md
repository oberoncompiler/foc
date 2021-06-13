# Console Compiler for Component Pascal (Oberon)
*Under construction*

(now supports Linux & Windows on x86; uses BlackBox)

* [YouTube-channel about the project](https://www.youtube.com/channel/UCfaaot6JjktvqQCUOkXxEsA)
* [Free Oberon website](https://free.oberon.org/en)

*Engish version in the bottom*

# Консольный компилятор Компонентного Паскаля (Оберона)
*В разработке*

(сейчас поддерживает Линукс и Виндоус на x86; использует BlackBox)

* [Ютуб-канал о данном проекте](https://www.youtube.com/channel/UCfaaot6JjktvqQCUOkXxEsA)
* [Сайт Free Oberon](https://free.oberon.org)

## Быстрый старт

1. На Линуксе или на Виндоусе зайдите в командной строке в каталог `foc` и наберите:
```
make
```

2. Для компиляции и запуска тестовой программы (`Main.Mod`) наберите:

На Линуксе:
```
./foc Main
./Main
```

На Виндоусе:
```
foc Main
Main
```

### Примечания для Линукса

Чтобы собрать проект, у вас должна быть установлена программа `make`,
считывающая файл `Makefile` и запускающая команды, указанные в нём.

Для её установки `make` на Дебиане (а также Убунту и т. п.) запустите:
```
sudo apt-get install make
```

Можно обойтись и без `make`, выполнив команды в файле `Makefile` вручную.

### Примечания для Виндоуса

На Виндоусе вместо программы `make` используется сценарий `make.bat`.
Перед сборкой компилятора он переименовывает следующие файлы и каталоги:

* `__WIN_BlackBox` → `BlackBox`
* `Host\Mod\__Win_Args.Mod` → `Host\Mod\Args.Mod`
* `Host\Mod\__Win_Files.Mod` → `Host\Mod\Files.Mod`
* `Freeoberon\Mod\__Win_LinkerProxy.Mod` → `Freeoberon\Mod\LinkerProxy.Mod`

При этом соответствующие Линукс-версии файлов получают префикс `__LIN_` (например, `__LIN_Files.Mod`).

## Инструкция по использованию

В данной версии компилятора для его корректной работы вы должны
находиться в каталоге с исполнимым файлом `foc` (`foc.exe`).
Все файлы модулей компилируемой вами программы также должны находиться в этом каталоге.

Запуск на Линуксе:
```
./foc <название_главного_модуля>
```
На Виндоусе:
```
foc <название_главного_модуля>
```

Компилятор дописывает к названию модуля `.Mod`, открывает
соответствующиий файл, а затем рекурсивно обходит все Mod-файлы проекта.
Все файлы должны находиться в текущем каталоге.

## Как пересобрать ББКП для обновления подкаталога BlackBox

Вам необходим Git. На Виндоусе он тоже [доступен](https://git-scm.com).

1. Скачать ББКП из Git-репозитория с помощью команды `git clone`:
```
git clone https://github.com/bbcb/bbcp.git
```

2. Внутри ББКП зайти в подкаталог `BlackBox` и с помощью следующей
команды перейти в ветку `dev18` (возможно, в будущих версиях ББКП в
этом шаге не будет необходимости):
```
git checkout dev18
```

3. Установить режим `Linux Interp` (или `Windows Interp`):
```
./switch-target Linux Interp
./build
./export ../Interp
```
Затем каталог `Interp` переименовать в `BlackBox` и расположить
внутри каталога `foc` (заменив то, что есть).

На Виндоусе можно вместо `switch-target` скопировать содержимое
подкаталогов `_Windows`, `_Windows_Interp` и `__Interp` в
каталог ББКП и запустить сценарий `build.bat`. Всё это описанов
в файле `README` в проекте ББКП.

__________________________________

# ENGLISH VERSION

## Quick Start

1.On Linux or Windows, go to the `foc` directory in the command line and type:
```
make
```

2. To compile and run the test program (`Main.Mod`), type:

On Linux:
```
./foc Main
./Main
```

On Windows:
```
foc Main
Main
```

### Notes for Linux

To build the project, you must have `make` program installed,
which reads `Makefile` and runs commands specified in it.

To install `make` on Debian (as well as Ubuntu, etc.), run:
```
sudo apt-get install make
```

You can also do without `make` by manually executing the commands in the` Makefile`.

### Notes for Windows

On Windows, the `make.bat` script is used instead of the `make` program.
Before building the compiler, it renames the following files and directories:

* `__WIN_BlackBox` → `BlackBox`
* `Host\Mod\__Win_Args.Mod` → `Host\Mod\Args.Mod`
* `Host\Mod\__Win_Files.Mod` → `Host\Mod\Files.Mod`
* `Freeoberon\Mod\__Win_LinkerProxy.Mod` → `Freeoberon\Mod\LinkerProxy.Mod`

The corresponding Linux versions of files are renamed by adding the `__LIN_` prefix (for example,` __LIN_Files.Mod`).

## Usage

In this version of the compiler, for it to work correctly, you must
run it from the directory with the executable file `foc` (`foc.exe`).
All module files of the program you are compiling must also reside in
this directory.

Running on Linux:
```
./foc <main_module_name>
```
On Windows:
```
foc <main_module_name>
```

The compiler appends `.Mod` to the name of the module, opens the
corresponding file, and then recursively traverses all Mod-files
in the project. All files must be in the current directory.

## How to rebuild the BBCP to update the BlackBox subdirectory

You need Git. On Windows it is also [available](https://git-scm.com).

1. Download BBCP from the Git repository using `git clone` command:
```
git clone https://github.com/bbcb/bbcp.git
```

2. Inside BBCP go to the `BlackBox` subdirectory and use the following
commands to switch to the `dev18` branch (in future versions of the
BBCP this step might be unnecessary):
```
git checkout dev18
```

3. Switch mode to `Linux Interp` (or `Windows Interp`):
```
./switch-target Linux Interp
./build
./export ../Interp
```
Then rename the `Interp` directory to `BlackBox` and move
it inside the `foc` directory (replacing what is there now).

On Windows, instead of using `switch-target`, you can copy the content
of the subdirectories `_Windows`,` _Windows_Interp` and `__Interp` into
the BBCP directory and then run the `build.bat` script. All this is
described in the `README` file in the BBCP project.
