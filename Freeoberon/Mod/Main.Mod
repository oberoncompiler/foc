MODULE FreeoberonMain;
IMPORT Compiler := FreeoberonCompiler, Scan := FreeoberonScanner,
  Linker := FreeoberonLinker, Kernel, Errors := FreeoberonErrors,
  Config := FreeoberonConfig, Platform := FreeoberonPlatform,
  Converters, Out := Log, Files, HostFiles, Args, CharUtils;

CONST
  (* Константы для OpenFile *)
  modFile  = 0;
  symFile  = 1;
  codeFile = 2;
  cpFile   = 3;

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
  result: INTEGER;
  extensions: ARRAY 4, 4 OF CHAR;
  textFileTypes: SET;

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
PROCEDURE MaybeRemoveExtension(VAR mod: ARRAY OF CHAR; OUT extension: ARRAY OF CHAR);
VAR i, ei,
    mpos, epos: INTEGER;
    extFound: BOOLEAN;
BEGIN
  i := 0; extFound := FALSE;
  REPEAT
    mpos := 0; WHILE mod[mpos] # 0X DO INC(mpos) END;
    epos := 0; WHILE extensions[i][epos] # 0X DO INC(epos) END;

    IF mpos > epos + 1 THEN
      REPEAT DEC(mpos); DEC(epos) UNTIL (epos = -1) OR (mod[mpos] # extensions[i][epos]);
      extFound := (epos = -1) & (mod[mpos] = '.');
      IF extFound THEN
        ei := 0; WHILE extensions[i][ei] # 0X DO extension[ei] := extensions[i][ei]; INC(ei); END; extension[ei] := 0X;
        mod[mpos] := 0X;
      END;
    END;
    INC(i);
  UNTIL extFound OR (i = LEN(extensions));
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

(** Открывает файл, имя которого конструируется по специальному алгоритму,
    опирающемуся на useSysDir, useFolder, useOs, ftype, mod, w1 и w2. В случае
    успеха возвращает TRUE, записывает бегунок в r, в fname записывает путь к
    файлу. В случае провала не меняет значения бегунка r и параметра fname. *)
PROCEDURE OpenFile(IN mod, w1, w2: ARRAY OF CHAR;
    useSysDir, useFolder, useOs: BOOLEAN; ftype: INTEGER;
    VAR fname: ARRAY OF CHAR; VAR r: Files.Reader): BOOLEAN;
VAR F: Files.File;
  r2: Files.Reader;
  s: ARRAY 1024 OF CHAR;
BEGIN
  r2 := NIL;
  IF useSysDir THEN s := Config.sysDir$ ELSE s := '' END;
  IF ~(ftype IN textFileTypes) THEN s := s + '_Build/' END;
  IF useFolder THEN s := s + w1 + '/' + w2 ELSE s := s + mod END;
  IF useOs THEN s := s + '-' + Config.curOs END;

  s := s + '.' + extensions[ftype];

  IF Config.debug THEN Out.String('ПРОБУЮ "' + s + '"') END;
  F := FileOld(s$);
  IF F # NIL THEN
    IF Config.debug THEN Out.String(' - О!') END;
    r2 := F.NewReader(NIL);
    IF r2 # NIL THEN r := r2; fname := s$ END
  END;
  IF Config.debug THEN IF r2 # NIL THEN Out.String(' - УДАЛОСЬ') END; Out.Ln END;
  RETURN r2 # NIL
END OpenFile;

(** Помещает в w1 и w2 две части имени модуля. Если имя состоит из одной части,
    просто дублирует его в w1 и w2.
Пример: 'GameScripts' -> ['Game', 'Scripts'].
        'Allegro5' -> ['Allegro5', 'Allegro5']. *)
PROCEDURE SplitModName(IN mod: ARRAY OF CHAR; OUT w1, w2: ARRAY OF CHAR);
VAR i, j, k: INTEGER;
BEGIN
  i := 1;
  (* i := position of the first capital letter that follows a non-capital letter. *)
  WHILE (mod[i] # 0X) & ~(CharUtils.IsUpper(mod[i]) & CharUtils.IsLower(mod[i - 1])) DO INC(i) END;

  IF mod[i] = 0X THEN k := 0 ELSE k := i; END;

  (* Copy first part (or the whole name) into w1 *)
  j := 0; WHILE j < i DO w1[j] := mod[j]; INC(j) END;
  w1[j] := 0X;

  (* Copy second part (or the whole name again) into w2 *)
  j := 0; WHILE mod[k] # 0X DO w2[j] := mod[k]; INC(j); INC(k) END;
  w2[j] := 0X
END SplitModName;

(*Находит файл модуля mod, открывает его, возвращая бегунок.
  Если exactFname = TRUE, то mod - имя файла. exactFname = TRUE
  для главного модуля в случае, если пользователь указал ключ "--exact".
  В fname записывается найденное имя файла. system устанавливается
  в TRUE в случае, если модуль оказался системным.
  Если не удалось найти файл, возвращает NIL.
  В случае вызова `foc Games/Game1/Tetris`, в mod идёт только 'Tetris'.
  Примеры mod: 'Prog', 'Prog.Mod', 'code.txt'. *)
PROCEDURE OpenModule(
  mod: ARRAY OF CHAR;
  exactFname: BOOLEAN;
  OUT fname: ARRAY OF CHAR;
  OUT system, hasSource, hasCode: BOOLEAN
  ): Files.Reader;
VAR
  r: Files.Reader;
  w1, w2: String;
  extension: ARRAY 4 OF CHAR;
  ftype, i: INTEGER;
BEGIN
  r := NIL; extension := '';
  IF exactFname THEN (*!TODO*)
  ELSE MaybeRemoveExtension(mod, extension)
  END;

  ftype := modFile; i := 0;
  IF extension[0] # 0X THEN
    WHILE (i < LEN(extensions)) & (extensions[i] # extension) DO INC(i) END;
    IF i < LEN(extensions) THEN ftype := i; END;
  END;

  SplitModName(mod, w1, w2);
  IF Config.debug THEN
    Out.String(mod); Out.String(' разбито на '); Out.String(w1);
    Out.String(' и '); Out.String(w2); Out.Ln
  END;

  (*                   |sysdir|folder|use OS| *)
  (* 1. TableBox.Mod   |      |      |      | *)
  IF    OpenFile(mod, w1, w2, FALSE, FALSE, FALSE, ftype, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 2. TableBox-Linux.Mod *)
  ELSIF OpenFile(mod, w1, w2, FALSE, FALSE, TRUE , ftype, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 3. Table/Box.Mod или Oneword/Oneword.Mod *)
  ELSIF OpenFile(mod, w1, w2, FALSE, TRUE , FALSE, ftype, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 4. Table/Box-Linux.Mod или Oneword/Oneword-Linux.Mod *)
  ELSIF OpenFile(mod, w1, w2, FALSE, TRUE , TRUE , ftype, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 5. TableBox.cp   |      |      |      | *)
  ELSIF    OpenFile(mod, w1, w2, FALSE, FALSE, FALSE, cpFile, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 6. TableBox-Linux.cp *)
  ELSIF OpenFile(mod, w1, w2, FALSE, FALSE, TRUE , cpFile, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 7. Table/Box.cp или Oneword/Oneword.cp *)
  ELSIF OpenFile(mod, w1, w2, FALSE, TRUE , FALSE, cpFile, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 8. Table/Box-Linux.cp или Oneword/Oneword-Linux.cp *)
  ELSIF OpenFile(mod, w1, w2, FALSE, TRUE , TRUE , cpFile, fname, r) THEN
    system := FALSE; hasSource := TRUE; hasCode := FALSE
  (* 9. _Build/TableBox.sym *)
  ELSIF OpenFile(mod, w1, w2, FALSE, FALSE, FALSE, symFile, fname, r) THEN
    system := FALSE; hasSource := FALSE;
    (* 9a. _Build/TableBox.ocf *)
    hasCode := OpenFile(mod, w1, w2, FALSE, FALSE, FALSE, codeFile, fname, r)
  (* 10. _Build/TableBox-Linux.sym *)
  ELSIF OpenFile(mod, w1, w2, FALSE, FALSE, TRUE , symFile, fname, r) THEN
    system := FALSE; hasSource := FALSE;
    (* 10a. _Build/TableBox-Linux.ocf *)
    hasCode := OpenFile(mod, w1, w2, FALSE, FALSE, TRUE, codeFile, fname, r)
  (* 11. SYSDIR/_Build/TableBox.sym *)
  ELSIF OpenFile(mod, w1, w2, TRUE , FALSE, FALSE, symFile, fname, r) THEN
    system := TRUE; hasSource := FALSE;
    (* 11a. _Build/TableBox.ocf *)
    hasCode := OpenFile(mod, w1, w2, TRUE, FALSE, FALSE, codeFile, fname, r)
  (* 12. SYSDIR/_Build/TableBox-Linux.sym *)
  ELSIF OpenFile(mod, w1, w2, TRUE , FALSE, TRUE, symFile, fname, r) THEN
    system := TRUE; hasSource := FALSE;
    (* 12a. _Build/TableBox-Linux.ocf *)
    hasCode := OpenFile(mod, w1, w2, TRUE, FALSE, TRUE, codeFile, fname, r)
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
  x: BYTE;
  n, i: INTEGER;
BEGIN
  r.SetPos(1CH);
  r.ReadByte(x);
  n := x;
  isBinding := FALSE;

  i := 0; x := 1;
  WHILE ~r.eof & (x # 0) DO
    r.ReadByte(x);
    modName[i] := CHR(x);
    INC(i)
  END;

  list := NIL;
  WHILE ~r.eof & (n # 0) DO
    i := 0;
    r.ReadByte(x);
    WHILE ~r.eof & (x # 0) DO
      name[i] := CHR(x);
      INC(i);
      r.ReadByte(x)
    END;
    name[i] := 0X;
    IF name[0] # '$' THEN 
      AddModule(list, name, '', FALSE, FALSE, FALSE)
    END;
    DEC(n)
  END;

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
  isSystem, hasSource, hasCode, isBinding, error: BOOLEAN;
  realModName, fname: String;
BEGIN error := FALSE;
  r := OpenModule(mod$, exactFname, fname, isSystem, hasSource, hasCode);
  IF (r # NIL) & ~hasSource & ~hasCode THEN (* Sym file returned, assume binding *)
    AddModule(modules, mod$, fname$, isSystem, hasSource, TRUE)
  ELSIF r # NIL THEN
    list := ReadImportList(r, hasSource, error, realModName, isBinding);
    IF ~error THEN
      p := list;
      WHILE ~error & (p # NIL) DO
        IF (p.name # 'SYSTEM') & (p.name # 'COM') &
           ~InList(modules, p.name$) THEN
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
    Out.String('  system    = ');
    IF p.system THEN Out.Char('Y') ELSE Out.Char('N') END; Out.Ln;
    Out.String('  hasSource = ');
    IF p.hasSource THEN Out.Char('Y') ELSE Out.Char('N') END; Out.Ln
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
    IF ~p.binding & (p.name # 'Kernel') THEN
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
          result := 0;
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
VAR s: ARRAY 1000 OF CHAR;
BEGIN
  extensions[modFile] := 'Mod';
  extensions[symFile] := 'sym';
  extensions[codeFile] := 'ocf';
  extensions[cpFile] := 'cp';

  textFileTypes := {modFile, cpFile};

  result := 1;
  Converters.Register('Documents.ImportDocument',
    'Documents.ExportDocument', '', 'odc', {});
  Converters.Register('HostTextConv.ImportUtf8',
    'HostTextConv.ExportUtf8', 'TextViews.View', 'Mod',
    {Converters.importAll});

  workDir := '';
  Platform.GetAppDir(s); Config.SetSysDir(s + 'Lib/');
  Config.SetCurOs(Platform.os);
  HostFiles.IgnoreAsk
END Init;

BEGIN
  Init;
  Do;
  Kernel.Quit(result)
END FreeoberonMain.
