# Console Compiler for Component Pascal (Oberon)
*Under construction*

(now supports Linux & Windows on x86;  uses BlackBox)

* [YouTube-channel about this project](https://www.youtube.com/channel/UCfaaot6JjktvqQCUOkXxEsA)
* [Free Oberon website](https://free.oberon.org)

# Консольный компилятор Компонентного Паскаля (Оберона)
*В разработке*

(сейчас поддерживает Линукс и Виндоус на x86; использует BlackBox)

* [Ютуб-канал о данном проекте](https://www.youtube.com/channel/UCfaaot6JjktvqQCUOkXxEsA)
* [Сайт Free Oberon](https://free.oberon.org)

## Как собрать проект

На Линуксе можно сразу приступить к сборке.
Чтобы получить версию для Виндоуса, надо переименовать
несколько файлов и каталогов, а именно:
```
__WIN_BlackBox            ->  BlackBox
Host\Mod\__Win_Args.Mod   ->  Host\Mod\Args.Mod
Host\Mod\__Win_Files.Mod  ->  Host\Mod\Files.Mod
Freeoberon\Mod\__Win_LinkerProxy.Mod  ->  Freeoberon\Mod\LinkerProxy.Mod
```

Линукс-версии файлов (например, Files.Mod) можно удалить или переименовать.

На Линуксе у вас должна быть установлена программа make,
считывающая файл Makefile и запускающая команды в нём.
Для её установки на Дебиане или Убунту запустите:
```
sudo apt-get install make
```
На Виндоусе вместо неё используется `make.bat`

Зайдите в консоли в каталог foc и запустите:
```
make
```
## Как запустить foc из консоли

В данной версии для её корректной работы вы должны находиться
в каталоге с исполнимым файлом foc (или foc.exe).

На Линуксе:
```
./foc <название_главного_модуля>
```
На Виндоусе:
```
foc <название_главного_модуля>
```

Например:
```
foc Main
```

## Как пересобрать ББКП для обновления подкаталога BlackBox

Вам необходим Git. На Виндоусе он тоже доступен.

1. Скачать ББКП из Git-репозитория с помощью команды `git clone`:
```
git clone https://github.com/bbcb/bbcp.git
```

2. Зайти в ББКП в подкаталог `BlackBox` и перейти в ветку `dev18`
   (возможно, в будущем в этом шаге не будет необходимости):
```
git checkout dev18
```

3. Установить режим `Linux Interp` (или `Windows Interp`):
```
./switch-target Linux Interp
./build
./export ../Interp
```
Затем каталог `Interp` назвать как `BlackBox` и расположить
внутри каталога `foc`.

В случае Виндоуса можно вместо этого скопировать содержимое
подкаталогов `_Windows`, `_Windows_Interp` и `__Interp` в
каталог ББКП и запустить сценарий `build.bat`.
