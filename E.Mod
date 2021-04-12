MODULE E;
IMPORT Out := Log;
VAR i: INTEGER;
BEGIN
  Out.String('Hello. I am the newest E.');
  FOR i := 1 TO 10 DO Out.Int(i) END;
  Out.Ln
END E.
