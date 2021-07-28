MODULE ConsMultiCompiler;

IMPORT C := ConsCompiler;

PROCEDURE Get(IN s: ARRAY OF CHAR; VAR i: INTEGER; OUT o: ARRAY OF CHAR);
VAR j: INTEGER;
BEGIN j := 0;
  WHILE s[i] = ';' DO INC(i) END;
  WHILE (s[i] # 0X) & (s[i] # ';') DO
    IF j < LEN(o) - 1 THEN o[j] := s[i]; INC(j) END;
    INC(i)
  END;
  o[j] := 0X
END Get;

PROCEDURE Split(VAR path, name: ARRAY OF CHAR);
VAR i, j, x: INTEGER; c: CHAR;
BEGIN x := 0;
  WHILE path[x] # 0X DO INC(x) END;

  c := path[0]; path[0] := '/';
  REPEAT DEC(x) UNTIL (path[x] = '/') OR (path[x] = '\');
  path[0] := c;

  j := 0; i := x;
  IF (path[i] = '/') OR (path[i] = '\') THEN INC(i) END;

  WHILE path[i] # 0X DO name[j] := path[i]; INC(i); INC(j) END;
  name[j] := 0X; path[x] := 0X
END Split;

(**`s' is a semicolon-separated list of file names that
  will be passed to ConsCompiler.Compile as `path' and `name'.*)
PROCEDURE Compile*(IN s: ARRAY OF CHAR);
VAR path, name: ARRAY 100 OF CHAR;
  i, j: INTEGER;
BEGIN
  i := 0;
  Get(s, i, path);
  WHILE path # '' DO
    Split(path, name);
    C.Compile(path, name);
    Get(s, i, path)
  END
END Compile;

END ConsMultiCompiler.
