MODULE HostArgs;
IMPORT Args, Kernel;
	
TYPE
	Hook = POINTER TO RECORD (Args.Hook) END;

PROCEDURE (h: Hook) GetParam* (n: INTEGER; OUT s: ARRAY OF CHAR);
BEGIN
	IF (0 <= n) & (n < Kernel.argc) THEN
		s := Kernel.argv[n]$
	ELSE
		s := ''
	END
END GetParam;

PROCEDURE (h: Hook) ParamCount* (): INTEGER;
BEGIN
	RETURN Kernel.argc
END ParamCount;

PROCEDURE Init;
VAR hook: Hook; 
BEGIN
	NEW(hook); Args.SetHook(hook)
END Init;

BEGIN
	Init
END HostArgs.

