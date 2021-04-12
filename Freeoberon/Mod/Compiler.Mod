MODULE FreeoberonCompiler;

IMPORT Out := Log, DevCompiler, DevMarkers, TextModels, TextViews,
  Views, Files, Errors := FreeoberonErrors;

PROCEDURE PosToLine(r: TextModels.Reader; OUT pos, row, col: INTEGER;
    OUT line: ARRAY OF CHAR);
VAR c: CHAR;
  i, tmp: INTEGER;
BEGIN
  tmp := r.Pos();
  pos := 1; row := 1; col := 1;
  r.SetPos(0);
  r.ReadChar(c);
  WHILE ~r.eot & (r.Pos() < tmp) DO
    IF c = 0DX THEN (* New line *)
      INC(row); col := 1;
      INC(pos)
    ELSIF c # 2X THEN
      IF col - 2 < LEN(line) THEN line[col - 1] := c END;
      INC(col);
      IF c < 80X THEN INC(pos) ELSE INC(pos, 2) END
    END;
    r.ReadChar(c)
  END;
  i := col - 1;
  WHILE ~r.eot & (i - 1 < LEN(line)) & (c # 0DX) DO
    line[i] := c; INC(i);
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

PROCEDURE Compile*(IN path, name: ARRAY OF CHAR;
  OUT errors: Errors.List): BOOLEAN;
VAR loc: Files.Locator;
  f: Files.File;
  v: Views.View;
  src: TextModels.Model;
  error: BOOLEAN;
BEGIN
  error := TRUE;
  loc := Files.dir.This(path);
  IF loc.res = 0 THEN
    v := Views.OldView(loc, name$);
    IF v # NIL THEN
      WITH v: TextViews.View DO
        src := v.ThisModel();
        DevCompiler.CompileText(src, 0, error);
        IF error THEN GetErrors(src.NewReader(NIL), name, errors) END
      ELSE
        Out.String("file open error: ");
          Out.String(path); Out.String(" "); Out.String(name); Out.Ln
      END
    ELSE
      Out.String("file not found: ");
        Out.String(path); Out.String(" "); Out.String(name); Out.Ln
    END
  ELSE
    Out.String("path not found: ");
      Out.String(path); Out.Ln
  END;
  RETURN ~error
END Compile;

END FreeoberonCompiler.
