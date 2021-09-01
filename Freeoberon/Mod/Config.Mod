MODULE FreeoberonConfig;

VAR
  sysDir-: ARRAY 256 OF CHAR;
  debug-: BOOLEAN;

PROCEDURE SetSysDir*(IN dir: ARRAY OF CHAR);
BEGIN
  sysDir := dir$
END SetSysDir;

BEGIN debug := TRUE
END FreeoberonConfig.
