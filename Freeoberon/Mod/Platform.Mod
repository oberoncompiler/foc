MODULE FreeoberonPlatform;

IMPORT HostEnv;

CONST os* = 'Win';

PROCEDURE GetAppDir*(OUT dir: ARRAY OF CHAR);
VAR s: ARRAY 1000 OF CHAR;
  c: CHAR;
  i, res: INTEGER;
BEGIN
  HostEnv.GetPar('_', s, res);
  s[LEN(s) - 1] := 0X;

  i := 0; WHILE s[i] # 0X DO INC(i) END;

  c := s[0]; s[0] := '/';
  REPEAT DEC(i) UNTIL s[i] = '/';
  s[0] := c;

  s[i + 1] := 0X;
  dir := s$
END GetAppDir;

END FreeoberonPlatform.
