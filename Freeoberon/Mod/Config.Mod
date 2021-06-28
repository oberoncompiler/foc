MODULE FreeoberonConfig;

IMPORT WinApi(*!FIXME move out*);

CONST
  debug* = FALSE;

VAR
  sysDir-: ARRAY 256 OF CHAR;

PROCEDURE SetSysDir*(IN dir: ARRAY OF CHAR);
BEGIN
  sysDir := dir$
END SetSysDir;

PROCEDURE GetAppDir*(OUT dir: ARRAY OF CHAR);
VAR s: ARRAY 1000 OF CHAR;
  c: CHAR;
  i: INTEGER;
BEGIN
  IF WinApi.GetModuleFileNameW(0, s, LEN(s)) = 0 THEN END;
  s[LEN(s) - 1] := 0X;

  i := 0; WHILE s[i] # 0X DO INC(i) END;

  c := s[0]; s[0] := '\';
  REPEAT DEC(i) UNTIL s[i] = '\';
  s[0] := c;

  s[i + 1] := 0X;
  dir := s$
END GetAppDir;

END FreeoberonConfig.
