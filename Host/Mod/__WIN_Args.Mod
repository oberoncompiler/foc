MODULE HostArgs;
IMPORT Args, WinApi;
  
TYPE
  Hook = POINTER TO RECORD (Args.Hook) END;

VAR
  loaded: BOOLEAN;
  params: ARRAY 100, 256 OF CHAR;
  count: INTEGER;

(*Crashes if count of params > 100*)
PROCEDURE MaybeLoadParams();
VAR x: WinApi.PtrWSTR;
  i, j: INTEGER;
BEGIN
  IF ~loaded THEN
    x := WinApi.GetCommandLineW();
    count := 0; i := 0;

    (*Skip leading whitespaces if any*)
    WHILE (x[i] # 0X) & (x[i] <= ' ') DO INC(i) END;
    
    WHILE x[i] # 0X DO
      IF x[i] = '"' THEN
        INC(i); j := 0;
        WHILE (x[i] # 0X) & (x[i] # '"') DO
          IF j < LEN(params, 1) - 1 THEN params[count][j] := x[i]; INC(j) END;
          INC(i)
        END;
        IF x[i] = '"' THEN INC(i) END
      ELSE
        j := 0;
        WHILE x[i] > ' ' DO
          IF j < LEN(params, 1) - 1 THEN params[count][j] := x[i]; INC(j) END;
          INC(i)
        END
      END;
      params[count][j] := 0X;
      INC(count);
      
      (*Skip whitespaces*)
      WHILE (x[i] # 0X) & (x[i] <= ' ') DO INC(i) END
    END;
    loaded := TRUE
  END
END MaybeLoadParams;

PROCEDURE (h: Hook) GetParam*(n: INTEGER; OUT s: ARRAY OF CHAR);
BEGIN
  MaybeLoadParams();
  IF (0 <= n) & (n < count) THEN
    s := params[n]$
  ELSE
    s := ''
  END
END GetParam;

PROCEDURE (h: Hook) ParamCount*(): INTEGER;
BEGIN
  MaybeLoadParams();
  RETURN count
END ParamCount;

PROCEDURE Init;
VAR hook: Hook; 
BEGIN
  loaded := FALSE;
  NEW(hook); Args.SetHook(hook)
END Init;

BEGIN
  Init
END HostArgs.
