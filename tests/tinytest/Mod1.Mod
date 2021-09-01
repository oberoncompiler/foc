MODULE Mod1;
IMPORT Out;

VAR n: INTEGER;

PROCEDURE P*;
BEGIN
  Out.String('  --- ');
  (*Out.Int(n, 0);*) Out.Char(CHR(ORD('0') + n));
  Out.String(' ---');
  Out.Ln;
  INC(n)
END P;

BEGIN
  n := 1
END Mod1.
