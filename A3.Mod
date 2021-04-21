MODULE A3;
IMPORT O := Log, C := Console;

PROCEDURE Number*(n: INTEGER);
BEGIN O.Char(CHR(ORD('0') + n))
END Number;

PROCEDURE EndLine*;
BEGIN O.Ln
END EndLine;

PROCEDURE Space*;
BEGIN O.Char(' ')
END Space;

PROCEDURE Read*(OUT x: INTEGER);
VAR s: ARRAY 100 OF CHAR;
BEGIN O.String('> '); C.ReadLn(s);
  x := ORD(s[0]) - ORD('0')
END Read;

END A3.
