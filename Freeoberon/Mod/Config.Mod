MODULE FreeoberonConfig;

VAR
  sysDir-: ARRAY 256 OF CHAR;
  debug-: BOOLEAN;
  isOsFile-: BOOLEAN; (* If currently compiled module is OS-specific *)
  curOs-: ARRAY 30 OF CHAR;

PROCEDURE SetSysDir*(IN dir: ARRAY OF CHAR);
BEGIN
  sysDir := dir$
END SetSysDir;

PROCEDURE SetCurOs*(IN os: ARRAY OF CHAR);
BEGIN
  curOs := os$
END SetCurOs;

PROCEDURE SetOsFile*(yes: BOOLEAN);
BEGIN
  isOsFile := yes
END SetOsFile;

BEGIN isOsFile := FALSE;
  curOs[0] := 0X; sysDir[0] := 0X;
  debug := FALSE
END FreeoberonConfig.
