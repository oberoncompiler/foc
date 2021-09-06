MODULE FreeoberonCompiler;

IMPORT Out := Log, DevCompiler, DevMarkers, TextModels, TextViews,
  Views, Files, Errors := FreeoberonErrors, Config := FreeoberonConfig;

PROCEDURE PosToLine(r: TextModels.Reader; OUT pos, row, col: INTEGER;
    OUT line: ARRAY OF CHAR);
VAR c: CHAR;
  i, tmp: INTEGER;
BEGIN
  tmp := r.Pos();
  pos := 1; row := 1; col := 1; i := 0;
  r.SetPos(0);
  r.ReadChar(c);
  WHILE ~r.eot & (r.Pos() < tmp) DO
    IF c = 0DX THEN (* New line *)
      INC(row); col := 1; i := 0;
      INC(pos)
    ELSIF c >= ' ' THEN
      IF (i - 1 < LEN(line)) & ((c > ' ') OR (i # 0)) THEN
        line[i] := c; INC(i)
      END;
      INC(col);
      IF c < 80X THEN INC(pos) ELSE INC(pos, 2) END
    END;
    r.ReadChar(c)
  END;
  WHILE ~r.eot & (i - 1 < LEN(line)) & (c # 0DX) DO
    IF c >= ' ' THEN line[i] := c; INC(i) END;
    r.ReadChar(c)
  END;
  line[i] := 0X;
  r.SetPos(tmp)
END PosToLine;

PROCEDURE GetErrors(r: TextModels.Reader; IN fname: ARRAY OF CHAR;
  OUT list: Errors.List);
VAR v: Views.View;
  v1: DevMarkers.View;
  row, col, pos: INTEGER;
  line: ARRAY 2000 OF CHAR;
BEGIN
  Errors.NewList(list);
  r.SetPos(0);
  r.ReadView(v);
  WHILE ~r.eot DO
    IF v IS DevMarkers.View THEN
      v1 := v(DevMarkers.View);
      v1.SetMode(DevMarkers.message);

      (*!TODO Take error message not from v1.msg, but generate from v1.err.*)
      PosToLine(r, pos, row, col, line);
      Errors.Add(list, fname, row, col, pos, v1.err, v1.msg$, line);
    END;
    r.ReadView(v)
  END
END GetErrors;

(*Компилирует модуль в указанном файле.
  В случае успеха возвращает TRUE. Иначе записывает
  список ошибок в errors. *)
PROCEDURE Compile*(IN fname: ARRAY OF CHAR;
  OUT errors: Errors.List): BOOLEAN;
VAR loc: Files.Locator;
  f: Files.File;
  v: Views.View;
  src: TextModels.Model;
  error: BOOLEAN;
  i: INTEGER;
BEGIN
  error := TRUE;
  loc := Files.dir.This('');
  IF loc.res = 0 THEN
    
    i := 0;
    WHILE (Config.curOs[i] # 0X) & (Config.curOs[i] = fname[i]) DO INC(i) END;
    Config.SetOsFile((Config.curOs[i] = 0X) & (fname[i] = '/'));

    Out.String(' OPEN VIEW "' + fname + '".      OSFILE = ');
    IF Config.isOsFile THEN Out.String('TRUE') ELSE Out.String('FALSE') END; Out.Ln;

    v := Views.OldView(loc, fname$);
    IF v # NIL THEN
      WITH v: TextViews.View DO
        src := v.ThisModel();
        DevCompiler.CompileText(src, 0, error);
        IF error THEN GetErrors(src.NewReader(NIL), fname, errors) END
      ELSE Out.String('Ошибка открытия файла: '); Out.String(fname); Out.Ln
      END
    ELSE Out.String('Файл не найден: '); Out.String(fname); Out.Ln
    END
  ELSE Out.String('Не удалось создать локатор.'); Out.Ln
  END;
  RETURN ~error
END Compile;

END FreeoberonCompiler.
