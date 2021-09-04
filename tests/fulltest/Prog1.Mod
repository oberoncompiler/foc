MODULE Prog1;
IMPORT Out, Mod1;
CONST N = 26;
VAR s: ARRAY N + 1 OF CHAR;
  i: INTEGER;
BEGIN
  FOR i := 0 TO N - 1 DO
    s[i] := CHR(ORD('A') + i)
  END;
  s[N] := 0X;
  Out.String(s);
  Out.Ln;
  FOR i := 1 TO 5 DO Mod1.P END
END Prog1.
