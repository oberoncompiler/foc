MODULE FreeoberonMain;
IMPORT Compiler := FreeoberonCompiler, Scan := FreeoberonScanner,
  Linker := FreeoberonLinker, Kernel, Errors := FreeoberonErrors,
  Converters, Out := Log, Files, Args;

TYPE
  String = ARRAY 255 OF CHAR;

  Item = POINTER TO ItemDesc;
  ItemDesc = RECORD
    name: String; (*имя модуля*)
    fname: String; (*имя файла с исходным кодом модуля
             ЛИБО путь к каталогу, в котором находятся каталоги Code и Sym*)
    system: BOOLEAN; (*модули Files, In, Out и т. п. будут здесь TRUE*)
    hasSource: BOOLEAN; (*имеет ли данный модуль исходный код*)
    next: Item
  END;

VAR
  modules: Item;
  workDir, sysDir: String;

(*Добавляет название модуля mod в список list.*)
PROCEDURE AddModule(VAR list: Item; mod, fname: ARRAY OF CHAR;
    system, hasSource: BOOLEAN);
VAR m, p: Item;
BEGIN
  NEW(m);
  m.name := mod$;
  m.fname := fname$;
  m.system := system;
  m.hasSource := hasSource;
  m.next := NIL;
  IF list = NIL THEN
    list := m
  ELSE
    p := list;
    WHILE p.next # NIL DO
      p := p.next
    END;
    p.next := m
  END
END AddModule;

(*Выводит на экран содержимое списка из глобальной переменной modules.*)
PROCEDURE ShowModules(list: Item);
VAR p: Item;
BEGIN
  Out.String('Modules: ');
  p := list;
  WHILE p # NIL DO
    Out.String(p.name);
    IF p.system THEN Out.String(' (system)') END;
    Out.String('; ');
    p := p.next
  END;
  Out.Ln
END ShowModules;

(*Есть ли модуль под названием mod в глобальном списке modules.*)
PROCEDURE InList(list: Item; mod: ARRAY OF CHAR): BOOLEAN;
VAR p: Item;
BEGIN
  p := list;
  WHILE (p # NIL) & (mod # p.name) DO p := p.next END;
  RETURN p # NIL
END InList;

PROCEDURE MaybeAddExtension(IN mod: ARRAY OF CHAR;
    IN ext: ARRAY OF CHAR; OUT fname: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0; WHILE (mod[i] # 0X) & (mod[i] # '.') DO INC(i) END;
  IF mod[i] # 0X THEN fname := mod$
  ELSE fname := mod + '.' + ext
  END
END MaybeAddExtension;

PROCEDURE FileOld(fname: ARRAY OF CHAR): Files.File;
VAR F: Files.File;
  loc: Files.Locator;
  path: ARRAY 256 OF CHAR;
  i, j: INTEGER;
BEGIN
  i := 0; WHILE fname[i] # 0X DO INC(i) END;
  WHILE (i >= 0) & (fname[i] # '/') & (fname[i] # '\') DO DEC(i) END;

  IF i >= 0 THEN
    path[i] := 0X; j := i - 1;
    WHILE j >= 0 DO path[j] := fname[j]; DEC(j) END;
    j := 0; INC(i);
    WHILE fname[i] # 0X DO fname[j] := fname[i]; INC(i); INC(j) END;
    fname[j] := 0X
  ELSE path := ''
  END;

  (*Out.String(' path=[' + path + ']'); Out.Ln;
  Out.String('fname=[' + fname + ']'); Out.Ln; Out.Ln;*)

  loc := Files.dir.This(path$);
  IF loc # NIL THEN
    F := Files.dir.Old(loc, fname$, TRUE)
  ELSE F := NIL
  END;
  RETURN F
END FileOld;

(*Открывает файл fname, возвращает TRUE и записывает бегунок в r.
  В случае ошибки возвращает FALSE и записывает NIL в r.*)
PROCEDURE TryOpen(IN fname: ARRAY OF CHAR; OUT r: Files.Reader): BOOLEAN;
VAR F: Files.File;
BEGIN r := NIL;
  (*Out.String('ПРОБУЮ "' + fname + '"');*)
  F := FileOld(fname$);
  IF F # NIL THEN r := F.NewReader(NIL) END;
  (*IF r # NIL THEN Out.String(' - ЕСТЬ') END; Out.Ln;*)
  RETURN r # NIL
END TryOpen;

(*Находит файл модуля mod, открывает его, возвращая бегунок.
  Если exactFname = TRUE, то mod - имя файла. exactFname = TRUE
  для главного модуля в случае, если пользователь указал ключ "--exact".
  В fname записывается найденное имя файла. system устанавливается
  в TRUE в случае, если модуль оказался системным.
  Если не удалось найти или открыть файл, возвращает NIL.
  В случае вызова `foc Games/Game1/Tetris`, в mod идёт только 'Tetris'.
  Примеры mod: 'Prog', 'Prog.Mod', 'code.txt'. *)
PROCEDURE OpenModule(mod: ARRAY OF CHAR; exactFname: BOOLEAN;
    OUT fname: ARRAY OF CHAR;
    OUT system, hasSource: BOOLEAN): Files.Reader;
VAR r: Files.Reader;
  sysfname: String;
BEGIN
  IF exactFname THEN fname := mod$
  ELSE MaybeAddExtension(mod, 'Mod', fname);
    MaybeAddExtension(mod, 'osf', sysfname);
  END;

  (* 1. В рабочем каталоге: EngineMain.Mod *)
  IF TryOpen(workDir + fname, r) THEN
    system := FALSE; hasSource := TRUE;
    fname := workDir + fname
                    (* 2. В рабочем каталоге: Sym/EngineMain.osf *)
                    (* 3. В рабочем каталоге: Engine/Main.Mod *)
                    (* 4. В рабочем каталоге: Engine/Mod/Main.Mod *)
                    (* 5. В рабочем каталоге: Engine/Sym/Main.osf *)
  (* 6. В системном каталоге: Sym/EngineMain.osf *)
  ELSIF TryOpen(sysDir + 'Sym/' + sysfname, r) THEN
    system := TRUE; hasSource := FALSE;
    fname := sysDir + 'Sym/' + sysfname
  END;
                    (* 7. В системном каталоге: Engine/Sym/Main.osf *)
  RETURN r
END OpenModule;

(*Считывает исходный текст модуля до слова IMPORT, составляет
  список (непосредственного) импорта этого модуля, возвращает
  его в виде списка (Item). Название модуля помещает в modName.*)
PROCEDURE ReadImportListFromSource(r: Files.Reader; VAR error: BOOLEAN;
    OUT modName: ARRAY OF CHAR): Item;
VAR list: Item;
  sym: INTEGER;
  name: String;
BEGIN
  error := TRUE; list := NIL; Scan.Init(r); Scan.Get(sym);
  (*Доходим до MODULE*)
  WHILE (sym # Scan.eot) & (sym # Scan.module) DO Scan.Get(sym) END;
  IF sym = Scan.module THEN Scan.Get(sym);
    IF sym = Scan.ident THEN modName := Scan.id$ END;
    (*Доходим до IMPORT*)
    WHILE (sym # Scan.eot) & (sym # Scan.import) DO Scan.Get(sym) END;

    IF sym = Scan.import THEN
      Scan.Get(sym);
      error := FALSE;
      REPEAT
        IF sym = Scan.ident THEN
          name := Scan.id$;
          Scan.Get(sym);
          IF sym = Scan.becomes THEN (* := *)
            Scan.Get(sym);
            IF sym = Scan.ident THEN
              name := Scan.id$;
              Scan.Get(sym)
            ELSE error := TRUE
            END
          END;
          IF ~error THEN
            IF ~InList(list, name$) THEN
              AddModule(list, name$, '', FALSE, FALSE)
            ELSE error := TRUE
            END;
            IF sym = Scan.comma THEN Scan.Get(sym)
            ELSIF sym # Scan.semicol THEN error := TRUE
            END
          END
        ELSE error := TRUE
        END
      UNTIL error OR (sym # Scan.ident)
    END
  END;
  RETURN list
END ReadImportListFromSource;

(*Считывает список непосредственного импорта из символьный файла
  модуля, возвращает его в виде списка (Item).
  Название модуля помещает в modName.*)
PROCEDURE ReadImportListFromSym(r: Files.Reader; VAR error: BOOLEAN;
    OUT modName: ARRAY OF CHAR): Item;
VAR list: Item;
  name: String;
BEGIN (*!TODO это заглушка*)
  error := FALSE;
  list := NIL;
  modName := 'Log';
  RETURN list
END ReadImportListFromSym;

PROCEDURE ReadImportList(r: Files.Reader; isSource: BOOLEAN;
    VAR error: BOOLEAN; OUT modName: ARRAY OF CHAR): Item;
VAR list: Item;
BEGIN
  IF isSource THEN list := ReadImportListFromSource(r, error, modName)
  ELSE list := ReadImportListFromSym(r, error, modName)
  END;
  RETURN list
END ReadImportList;

(*Получает имя модуля (например, 'Main') или имя файла
  с исходным кодом модуля (в этом случае exactFname = TRUE).
  Рекурсивно обходит граф импортируемых модулей, создаёт
  и возвращает список для компиляции в правильном порядке.
  В случае успеха возвращает TRUE.*)
PROCEDURE Import(mod: ARRAY OF CHAR; exactFname: BOOLEAN): BOOLEAN;
VAR list, p: Item;
  r: Files.Reader;
  isSystem, hasSource, error: BOOLEAN;
  realModName, fname: String;
BEGIN
  r := OpenModule(mod$, exactFname, fname, isSystem, hasSource);
  IF r # NIL THEN
    list := ReadImportList(r, hasSource, error, realModName);
    IF ~error THEN
      p := list;
      WHILE ~error & (p # NIL) DO
        IF ~InList(modules, p.name$) THEN
          IF ~Import(p.name$, FALSE) THEN error := TRUE END
        END;
        p := p.next
      END;
      IF ~error THEN
        AddModule(modules, realModName$, fname$, isSystem, hasSource)
      END
    ELSE
      Out.String('Произошла ошибка при чтении списка импорта из модуля "');
      Out.String(mod$); Out.String('".'); Out.Ln
    END
  ELSE error := TRUE;
    Out.String('Невозможно найти модуль "'); Out.String(mod$);
    Out.String('".'); Out.Ln
  END;
  RETURN ~error
END Import;

(*Компилирует исходный код модуля в указанном файле.
  В случае успеха возвращает TRUE.*)
PROCEDURE CompileModule(fname: ARRAY OF CHAR; OUT errors: Errors.List): BOOLEAN;
BEGIN
  RETURN Compiler.Compile(fname$, errors)
END CompileModule;

(*Компилирует все модули в списке в указанном порядке.
  В случае успеха возвращает TRUE.*)
PROCEDURE CompileAll(list: Item; OUT errors: Errors.List): BOOLEAN;
VAR p: Item;
  error: BOOLEAN;
BEGIN
  error := FALSE;
  p := list;
  WHILE ~error & (p # NIL) DO
    IF ~p.system THEN
      IF ~CompileModule(p.fname$, errors) THEN error := TRUE END
    END;
    p := p.next
  END;
  RETURN ~error
END CompileAll;

(*Компонует указанные модули в исполнимый файл.
  В случае успеха возвращает TRUE.*)
PROCEDURE Link(list: Item): BOOLEAN;
VAR p, last: Item;
  s: ARRAY 4000 OF CHAR;
  i, j: INTEGER;
BEGIN
  p := list; i := 0;
  WHILE p # NIL DO
    j := 0;
    WHILE p.name[j] # 0X DO s[i] := p.name[j]; INC(i); INC(j) END;
    s[i] := ' '; INC(i);
    last := p; p := p.next
  END;
  s[i - 1] := 0X;
  RETURN Linker.Link(last.name + Linker.postfix, s)
END Link;

PROCEDURE Do*;
VAR s: String;
  errors: Errors.List;
BEGIN
  IF Args.ParamCount() # 2 THEN
    Out.String('Программа ожидает ровно один параметр.'); Out.Ln;
    Out.String('Пример:'); Out.Ln;
    Out.String('  '); Args.GetParam(0, s); Out.String(s);
    Out.String(' Myprogram'); Out.Ln
  ELSE
    Args.GetParam(1, s);
    modules := NIL;
    IF Import(s, FALSE(*!TODO проверять ключ --exact*)) THEN
      IF CompileAll(modules, errors) THEN
        IF Link(modules) THEN
          Out.String('Исполнимый файл создан.'); Out.Ln
        ELSE Out.String('Не удалось скомпоновать.'); Out.Ln
        END
      ELSE Errors.ShowList(errors)
      END
    ELSE Out.String('Не удалось составить список импорта.'); Out.Ln
    END
  END
END Do;

PROCEDURE Init;
BEGIN
  Converters.Register('Documents.ImportDocument',
    'Documents.ExportDocument', '', 'odc', {});
  Converters.Register('HostTextConv.ImportUtf8',
    'HostTextConv.ExportUtf8', 'TextViews.View', 'Mod',
    {Converters.importAll})
END Init;

BEGIN
  Init;
  workDir := ''; sysDir := 'BlackBox/';
  Do;
  Kernel.Quit(0)
END FreeoberonMain.
