MODULE FreeoberonMain;
IMPORT Compiler := FreeoberonCompiler, Scan := FreeoberonScanner,
  Linker := FreeoberonLinker, Kernel, Errors := FreeoberonErrors,
  Converters, Out := Log, Files, Args;

TYPE
  String = ARRAY 50 OF CHAR;

  Item = POINTER TO ItemDesc;
  ItemDesc = RECORD
    name: String;
    system: BOOLEAN; (*модули Files, In, Out и т. п. будут здесь TRUE*)
    next: Item
  END;

VAR
  modules: Item;
  systemModules: ARRAY 5 OF String;

(*Является ли модуль с указанным названием системным.*)
PROCEDURE IsSystemModule(mod: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i # LEN(systemModules)) & (mod # systemModules[i]) DO INC(i) END;
  RETURN i # LEN(systemModules)
END IsSystemModule;

(*Добавляет название модуля mod в список list.*)
PROCEDURE AddModule(VAR list: Item; mod: ARRAY OF CHAR; system: BOOLEAN);
VAR m, p: Item;
BEGIN
  NEW(m);
  m.name := mod$;
  m.system := system;
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

(*Находит файл с модулем mod, открывает его, возвращая бегунок.
  Если не удалось найти или открыть файл, возвращает NIL.
  Примеры mod: 'Prog', 'Prog.Mod'. *)
PROCEDURE OpenModule(mod: ARRAY OF CHAR): Files.Reader;
VAR L: INTEGER;
  fname: String;
  r: Files.Reader;
  loc: Files.Locator;
  F: Files.File;
BEGIN
  L := 0; WHILE mod[L] # 0X DO INC(L) END;
  (*Заканчивается ли mod на '.Mod'?*)
  IF (L < 4) OR (mod[L-4] # '.') OR (mod[L-3] # 'M') OR
     (mod[L-2] # 'o') OR (mod[L-1] # 'd') THEN
    (*Дописать .Mod *)
    fname := mod$ + '.Mod';
  ELSE
    fname := mod$
  END;
  r := NIL;
  loc := Files.dir.This('');
  F := Files.dir.Old(loc, fname$, TRUE);
  IF F # NIL THEN r := F.NewReader(NIL) END;
  RETURN r
END OpenModule;

(*Считывает текст модуля до слова IMPORT, составляет
  список (непосредственного) импорта этого модуля, возвращает
  его в виде списка (Item).*)
PROCEDURE ReadImportList(r: Files.Reader; VAR error: BOOLEAN): Item;
VAR list: Item;
  sym: INTEGER;
  name: String;
BEGIN
  error := FALSE;
  list := NIL;
  Scan.Init(r);
  Scan.Get(sym);
  (*Доходим до IMPORT*)
  WHILE (sym # Scan.eot) & (sym # Scan.import) DO Scan.Get(sym) END;

  IF sym = Scan.import THEN
    Scan.Get(sym);
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
            AddModule(list, name$, FALSE)
          ELSE error := TRUE
          END;
          IF sym = Scan.comma THEN Scan.Get(sym)
          ELSIF sym # Scan.semicol THEN error := TRUE
          END
        END
      ELSE error := TRUE
      END
    UNTIL error OR (sym # Scan.ident)
  END;
  RETURN list
END ReadImportList;

(*Получает имя модуля (например, 'Main').
  Рекурсивно обходит граф импортируемых модулей, создаёт
  и возвращает список для компиляции в правильном порядке.
  В случае успеха возвращает TRUE.*)
PROCEDURE Import(mod: ARRAY OF CHAR): BOOLEAN;
VAR list, p: Item;
  r: Files.Reader;
  error: BOOLEAN;
BEGIN
  r := OpenModule(mod$);
  IF r # NIL THEN
    list := ReadImportList(r, error);
    IF ~error THEN
      p := list;
      WHILE ~error & (p # NIL) DO
        IF ~InList(modules, p.name$) THEN
          IF ~Import(p.name$) THEN error := TRUE END
        END;
        p := p.next
      END;
      IF ~error THEN AddModule(modules, mod, FALSE) END
    ELSE
      Out.String('Произошла ошибка при чтении списка импорта из модуля "');
      Out.String(mod$); Out.String('".'); Out.Ln
    END
  ELSIF IsSystemModule(mod$) THEN
    AddModule(modules, mod$, TRUE)
  ELSE
    error := TRUE;
    Out.String('Невозможно открыть модуль "'); Out.String(mod);
    Out.String('".'); Out.Ln
  END;
  RETURN ~error
END Import;

(*Компилирует указанный модуль. В случае успеха возвращает TRUE.*)
PROCEDURE CompileModule(mod: ARRAY OF CHAR; OUT errors: Errors.List): BOOLEAN;
BEGIN
  RETURN Compiler.Compile('', mod + '.Mod', errors)
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
      IF ~CompileModule(p.name$, errors) THEN error := TRUE END
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
    IF Import(s) THEN
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
  systemModules[0] := 'In';
  systemModules[1] := 'Log';
  systemModules[2] := 'Math';
  systemModules[3] := 'Files';
  systemModules[4] := 'Strings';
  Do;
  Kernel.Quit(0)
END FreeoberonMain.
