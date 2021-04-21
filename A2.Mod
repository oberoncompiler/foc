MODULE A2;
IMPORT A3;

PROCEDURE Line*(k, n: INTEGER);
VAR i: INTEGER;
BEGIN
  FOR i := 1 TO n - k DO A3.Space END;
  FOR i := 1 TO k DO A3.Number(i) END;
  FOR i := k - 1 TO 1 BY -1 DO A3.Number(i) END;
  A3.EndLine
END Line;

END A2.
