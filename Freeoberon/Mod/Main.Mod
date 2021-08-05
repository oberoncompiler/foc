MODULE FreeoberonMain;
IMPORT Compiler := FreeoberonCompiler, Scan := FreeoberonScanner,
  Linker := FreeoberonLinker, Kernel, Errors := FreeoberonErrors,
  Config := FreeoberonConfig, Platform := FreeoberonPlatform,
  Converters, Out := Log, Files, HostFiles, Args;

TYPE
  String = ARRAY 255 OF CHAR;

  Item = POINTER TO ItemDesc;
  ItemDesc = RECORD
    name: String; (*имя модуля*)
    fname: String; (*имя файла с исходным кодом модуля
             ЛИБО путь к каталогу, в котором находятся каталоги Code и Sym*)
    system: BOOLEAN; (*модули Files, In, Out и т. п. будут здесь TRUE*)
    binding: BOOLEAN; (*является ли данный модуль модулем-привязкой*)
    hasSource: BOOLEAN; (*имеет ли данный модуль исходный код*)
    next: Item
  END;

VAR
  modules: Item;
  workDir: String;

(*Добавляет название модуля mod в список list.*)
PROCEDURE AddModule(VAR list: Item; mod, fname: ARRAY OF CHAR;
    system, hasSource, isBinding: BOOLEAN);
VAR m, p: Item;
BEGIN
  NEW(m);
  m.name := mod$;
  m.fname := fname$;
  m.system := system;
  m.hasSource := hasSource;
  m.binding := isBinding;
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

(*Есть ли модуль под названием mod в глобальном списке modules.*)
PROCEDURE InList(list: Item; mod: ARRAY OF CHAR): BOOLEAN;
VAR p: Item;
BEGIN
  p := list;
  WHILE (p # NIL) & (mod # p.name) DO p := p.next END;
  RETURN p # NIL
END InList;

(*Удаляет расширение файла ext в строке mod, если оно там есть.*)
PROCEDURE MaybeRemoveExtension(VAR mod: ARRAY OF CHAR;
    IN ext: ARRAY OF CHAR);
VAR i, j: INTEGER;
BEGIN
  i := 0; WHILE mod[i] # 0X DO INC(i) END;
  j := 0; WHILE ext[j] # 0X DO INC(j) END;
  IF i > j + 1 THEN
    REPEAT DEC(i); DEC(j) UNTIL (j = -1) OR (mod[i] # ext[j]);
    IF (j = -1) & (mod[i] = '.') THEN mod[i] := 0X END
  END
  (*              i
  mod = EngineMain.Mod
  ext =            Mod
                  j    *)
END MaybeRemoveExtension;

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

(*Открывает файл fname, возвращает TRUE, записывает бегунок в r,
  а fname копирует в fname2 (для удобства).
  В случае ошибки возвращает FALSE.*)
PROCEDURE TryOpen(IN fname: ARRAY OF CHAR; OUT r: Files.Reader;
    OUT fname2: ARRAY OF CHAR): BOOLEAN;
VAR F: Files.File;
BEGIN
  IF Config.debug THEN Out.String('ПРОБУЮ "' + fname + '"') END;
  F := FileOld(fname$);
  IF F # NIL THEN r := F.NewReader(NIL); fname2 := fname$ END;
  IF Config.debug THEN
    IF r # NIL THEN Out.String(' - ЕСТЬ') END; Out.Ln
  END;
  RETURN r # NIL
END TryOpen;

PROCEDURE SplitModName(IN mod: ARRAY OF CHAR;
    OUT w1, w2: ARRAY OF CHAR): BOOLEAN;
VAR i, j, k: INTEGER;
BEGIN i := 1;
  WHILE (mod[i] # 0X) &
    ~(('A' <= mod[i]) & (mod[i] <= 'Z') &
    ~(('A' <= mod[i - 1]) & (mod[i - 1] <= 'Z')))
  DO INC(i) END;

  IF mod[i] # 0X THEN k := i;
    j := 0; WHILE j < i DO w1[j] := mod[j]; INC(j) END;
    w1[j] := 0X;

    j := 0; WHILE mod[k] # 0X DO w2[j] := mod[k]; INC(j); INC(k) END;
    w2[j] := 0X
  END;

  RETURN mod[i] # 0X
END SplitModName;

(*Находит файл модуля mod, открывает его, возвращая бегунок.
  Если exactFname = TRUE, то mod - имя файла. exactFname = TRUE
  для главного модуля в случае, если пользователь указал ключ "--exact".
  В fname записывается найденное имя файла. system устанавливается
  в TRUE в случае, если модуль оказался системным.
  Если не удалось найти файл, возвращает NIL.
  В случае вызова `foc Games/Game1/Tetris`, в mod идёт только 'Tetris'.
  Примеры mod: 'Prog', 'Prog.Mod', 'code.txt'. *)
PROCEDURE OpenModule(mod: ARRAY OF CHAR; exactFname: BOOLEAN;
    OUT fname: ARRAY OF CHAR;
    OUT system, hasSource: BOOLEAN): Files.Reader;
VAR r, r2: Files.Reader;
  w1, w2, fname2: String;
  twoWords: BOOLEAN;
BEGIN
  IF exactFname THEN (*!TODO*)
  ELSE MaybeRemoveExtension(mod, 'Mod')
  END;

  twoWords := SplitModName(mod, w1, w2);
  IF Config.debug THEN
    IF twoWords THEN Out.String('ДВА СЛОВА') ELSE Out.String('ОДНО СЛОВО') END;
    Out.String(" " + mod); Out.Ln
  END;

  (* 1. В рабочем каталоге: EngineMain.Mod *)
  IF TryOpen(workDir + mod + '.Mod', r, fname) THEN
    system := FALSE; hasSource := TRUE
  (* 2. В рабочем каталоге: Code/EngineMain.ocf   ← *)
  ELSIF TryOpen(workDir + 'Code/' + mod + '.ocf', r, fname) &
        TryOpen(workDir + 'Sym/' + mod + '.osf', r2, fname2) THEN
    system := FALSE; hasSource := FALSE
  (* 3. В рабочем каталоге: Engine/Main.Mod *)
  ELSIF twoWords & TryOpen(workDir + w1 + '/' + w2 + '.Mod', r, fname) THEN
    system := FALSE; hasSource := TRUE
  (* 4. В рабочем каталоге: Engine/Mod/Main.Mod *)
  ELSIF twoWords & TryOpen(workDir + w1 + '/Mod/' + w2 + '.Mod', r, fname) THEN
    system := FALSE; hasSource := TRUE
  (* 5. В рабочем каталоге: Engine/Code/Main.ocf  ← *)
  ELSIF twoWords & TryOpen(workDir + w1 + '/Code/' + w2 + '.ocf', r, fname) &
                   TryOpen(workDir + w1 + '/Sym/' + w2 + '.osf', r2, fname2) THEN
    system := FALSE; hasSource := FALSE
  (* 6. В системном каталоге: Code/EngineMain.ocf *)
  ELSIF TryOpen(Config.sysDir + 'Code/' + mod + '.ocf', r, fname) &
        TryOpen(Config.sysDir + 'Sym/' + mod + '.osf', r2, fname2) THEN
    system := TRUE; hasSource := FALSE
  (* 7. В системном каталоге: Engine/Code/Main.ocf *)
  ELSIF twoWords & TryOpen(Config.sysDir + w1 + '/Code/' + w2 + '.ocf', r, fname) &
                   TryOpen(Config.sysDir + w1 + '/Sym/' + w2 + '.osf', r2, fname2) THEN
    system := TRUE; hasSource := FALSE
  ELSE r := NIL
  END;
  RETURN r
END OpenModule;

(*Считывает исходный текст модуля до слова IMPORT, составляет
  список (непосредственного) импорта этого модуля, возвращает
  его в виде списка (Item). Название модуля помещает в modName.
  В isBinding записывает TRUE, если модуль - привязка.*)
PROCEDURE ReadImportListFromSource(r: Files.Reader; VAR error: BOOLEAN;
    OUT modName: ARRAY OF CHAR; OUT isBinding: BOOLEAN): Item;
VAR list: Item;
  sym: INTEGER;
  name: String;
BEGIN
  error := TRUE; isBinding := FALSE; list := NIL;
  Scan.Init(r); Scan.Get(sym);
  (*Доходим до MODULE*)
  WHILE (sym # Scan.eot) & (sym # Scan.module) DO Scan.Get(sym) END;
  IF sym = Scan.module THEN Scan.Get(sym);
    IF sym = Scan.ident THEN modName := Scan.id$; Scan.Get(sym)
    ELSE modName := ''; error := TRUE
    END;
    (*Проверяем, является ли модуль модулем-привязкой*)
    IF sym = Scan.lbrak THEN Scan.Get(sym); isBinding := TRUE END;
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
              AddModule(list, name$, '', FALSE, FALSE, FALSE)
            ELSE error := TRUE
            END;
            IF sym = Scan.comma THEN Scan.Get(sym)
            ELSIF sym # Scan.semicol THEN error := TRUE
            END
          END
        ELSE error := TRUE
        END
      UNTIL error OR (sym # Scan.ident)
    ELSE error := FALSE
    END
  END;
  RETURN list
END ReadImportListFromSource;

(*Считывает список непосредственного импорта из файла с машинным
  кодом модуля и возвращает его в виде списка (Item).
  Название модуля помещает в modName.*)
PROCEDURE ReadImportListFromCode(r: Files.Reader; VAR error: BOOLEAN;
    OUT modName: ARRAY OF CHAR; OUT isBinding: BOOLEAN): Item;
VAR list: Item;
  name: String;
BEGIN (*!TODO это заглушка*)
  error := FALSE;
  list := NIL;
  modName := 'Log';
  RETURN list
END ReadImportListFromCode;

PROCEDURE ReadImportList(r: Files.Reader; isSource: BOOLEAN;
    VAR error: BOOLEAN; OUT modName: ARRAY OF CHAR;
    OUT isBinding: BOOLEAN): Item;
VAR list: Item;
BEGIN
  IF isSource THEN
    list := ReadImportListFromSource(r, error, modName, isBinding)
  ELSE list := ReadImportListFromCode(r, error, modName, isBinding)
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
  isSystem, hasSource, isBinding, error: BOOLEAN;
  realModName, fname: String;
BEGIN
  r := OpenModule(mod$, exactFname, fname, isSystem, hasSource);
  IF r # NIL THEN
    list := ReadImportList(r, hasSource, error, realModName, isBinding);
    IF ~error THEN
      p := list;
      WHILE ~error & (p # NIL) DO
        IF (p.name # 'SYSTEM') & ~InList(modules, p.name$) THEN
          IF ~Import(p.name$, FALSE) THEN error := TRUE END
        END;
        p := p.next
      END;
      IF ~error THEN
        AddModule(modules, realModName$, fname$,
          isSystem, hasSource, isBinding)
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

PROCEDURE OutInfo(p: Item);
BEGIN
  IF Config.debug THEN
    Out.String('ИНФОРМАЦИЯ О МОДУЛЕ ' + p.name); Out.Ln;
    Out.String('  fname     = ' + p.fname); Out.Ln;
    Out.String('  system    = '); IF p.system THEN Out.Char('Д') ELSE Out.Char('Н') END; Out.Ln;
    Out.String('  hasSource = '); IF p.hasSource THEN Out.Char('Д') ELSE Out.Char('Н') END; Out.Ln;
    Out.Ln
  END
END OutInfo;

(*Компилирует все модули в списке в указанном порядке.
  В случае успеха возвращает TRUE.*)
PROCEDURE CompileAll(list: Item; OUT errors: Errors.List): BOOLEAN;
VAR p: Item;
  error: BOOLEAN;
BEGIN
  error := FALSE;
  p := list;
  WHILE ~error & (p # NIL) DO
    OutInfo(p);
    IF p.hasSource THEN
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
    IF ~p.binding THEN
      j := 0;
      WHILE p.name[j] # 0X DO s[i] := p.name[j]; INC(i); INC(j) END;
      s[i] := ' '; INC(i); last := p
    END;
    p := p.next
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
      IF Config.debug THEN Out.String('===== НАЧИНАЮ КОМПИЛЯЦИЮ ====='); Out.Ln END;
      IF CompileAll(modules, errors) THEN
        IF Config.debug THEN Out.String('===== НАЧИНАЮ КОМПОНОВКУ ====='); Out.Ln END;
        IF Link(modules) THEN
          IF Config.debug THEN Out.String('Исполнимый файл создан.'); Out.Ln END
        ELSE Out.String('Не удалось скомпоновать.'); Out.Ln
        END
      ELSE Errors.ShowList(errors)
      END
    ELSE Out.String('Не удалось составить список импорта.'); Out.Ln
    END
  END
END Do;

PROCEDURE Init;
VAR dir: ARRAY 1000 OF CHAR;
BEGIN
  Converters.Register('Documents.ImportDocument',
    'Documents.ExportDocument', '', 'odc', {});
  Converters.Register('HostTextConv.ImportUtf8',
    'HostTextConv.ExportUtf8', 'TextViews.View', 'Mod',
    {Converters.importAll});

  workDir := '';
  Platform.GetAppDir(dir);
  Config.SetSysDir(dir + 'BlackBox/');
  HostFiles.IgnoreAsk
END Init;

BEGIN
  Init;
  Do;
  Kernel.Quit(0)
END FreeoberonMain.
