MODULE FreeoberonConfig;

CONST
  debug* = FALSE;

VAR
  sysDir-: ARRAY 256 OF CHAR;

PROCEDURE SetSysDir*(IN dir: ARRAY OF CHAR);
BEGIN
  sysDir := dir$
END SetSysDir;

END FreeoberonConfig.
