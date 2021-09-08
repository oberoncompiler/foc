MODULE Out; (* Windows *)
IMPORT SYSTEM, WinApi;

CONST
  inBufLen = 128;

VAR
  out: WinApi.HANDLE;
  ss: ARRAY 4096 OF SHORTCHAR;

(*
  in: WinApi.HANDLE;
  inBuf: ARRAY[untagged] inBufLen OF SHORTCHAR;
  inBufW, inBufR: INTEGER; (* 0 <= inBufR <= inBufW <= inBufLen *)

PROCEDURE ReadLn(OUT text: ARRAY OF CHAR);
VAR W: INTEGER;
  res: WinApi.BOOL;
  i: INTEGER;
  done: BOOLEAN;
  res1: INTEGER;
BEGIN
  (* ReadLine -> ss, W *)
  W := 0;
  done := FALSE;
  REPEAT
    i := inBufR;
    WHILE (i < inBufW) & (inBuf[i] # 0AX) & (W < LEN(ss)) DO
      ss[W] := inBuf[i];
      INC(W);
      INC(i)
    END;
    IF i = inBufW THEN
      inBufW := 0; inBufR := 0;
      res := WinApi.ReadFile(in, SYSTEM.ADR(inBuf[0]), inBufLen, i, NIL);
      IF res # 0 THEN (* TRUE *)
        inBufW := i
      ELSE
        (* W := 0; *) done := TRUE
      END
    ELSIF inBuf[i] = 0AX THEN
      ss[W] := 0AX; INC(W); done := TRUE;
      inBufR := i + 1
    ELSE (* ss is too small *)
      W := 0; done := TRUE
    END
  UNTIL done;

  IF W > 0 THEN
    res1 := WinApi.MultiByteToWideChar(WinApi.CP_OEMCP, {}, ss, W, text, LEN(text) - 1);
    IF (res1 > 0) & (res1 < LEN(text)) THEN
      text[res1] := 0X
    ELSE
      text[0] := 0X
    END
  ELSE
    text[0] := 0X
  END
END ReadLn;*)

PROCEDURE Print(IN s: ARRAY OF CHAR; len: INTEGER);
VAR res, written: INTEGER;
BEGIN
  IF len > 0 THEN
    res := WinApi.WideCharToMultiByte(WinApi.CP_OEMCP, {}, s, len, ss, LEN(ss), NIL, NIL);
    IF (res > 0) & (res <= LEN(ss)) THEN
      res := WinApi.WriteFile(out, SYSTEM.ADR(ss[0]), res, written, NIL)
    END
  END
END Print;

PROCEDURE Char*(c: CHAR);
VAR s: ARRAY 1 OF CHAR;
BEGIN s[0] := c; Print(s, 1)
END Char;

PROCEDURE String*(IN text: ARRAY OF CHAR);
BEGIN Print(text, LEN(text$))
END String;

PROCEDURE Ln*;
BEGIN Print(0DX + 0AX, 2)
END Ln;

PROCEDURE Init;
VAR res: WinApi.BOOL;
BEGIN
  out := WinApi.GetStdHandle(WinApi.STD_OUTPUT_HANDLE);
  (*in := WinApi.GetStdHandle(WinApi.STD_INPUT_HANDLE);
  inBufW := 0; inBufR := 0*)
END Init;

BEGIN
	Init
END Out.
