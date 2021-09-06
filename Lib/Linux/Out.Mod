MODULE Out;

IMPORT Utf, Libc := LinLibc;

(*
VAR input: Libc.PtrFILE;

PROCEDURE ReadLn*(OUT s: ARRAY OF CHAR);
CONST maxLineLen = 2048 - 1; ( * without null terminating shortchar * )
VAR str: Libc.PtrSTR;
  ss: ARRAY maxLineLen + 1 OF SHORTCHAR;
  res: INTEGER;
BEGIN
  ss[LEN(ss) - 1] := 0X;
  str := Libc.fgets(ss, LEN(ss), input);
  IF (str # NIL) & (ss[LEN(ss) - 1] = 0X) THEN
    ASSERT(LEN(ss$) < LEN(s), 20);
    Utf.Utf8ToString(ss, s, res);
    ASSERT(res = 0, 60)
  ELSE s[0] := 0X END
END ReadLn;
*)

PROCEDURE Printf(IN s: ARRAY OF CHAR; len: INTEGER);
VAR res, i, n: INTEGER; tmp: ARRAY 64 OF CHAR;
  ss: ARRAY 128 OF SHORTCHAR;
BEGIN
  i := 0;
  WHILE i < len DO
    n := 0;
    WHILE (i < len) & (n < LEN(tmp) - 1) DO
      tmp[n] := s[i];
      INC(n); INC(i)
    END;
    tmp[n] := 0X;
    Utf.StringToUtf8(tmp, ss, res);
    IF res # 0 THEN
      (* fallback ascii conversion *)
      ss := SHORT(tmp)
    END;
    res := Libc.printf(ss);
    res := Libc.fflush(Libc.NULL)
  END
END Printf;

PROCEDURE Char*(c: CHAR);
VAR s: ARRAY 1 OF CHAR;
BEGIN
  s[0] := c;
  Printf(s, 1)
END Char;

PROCEDURE String*(IN text: ARRAY OF CHAR);
BEGIN
  Printf(text, LEN(text$))
END String;

PROCEDURE Ln*;
BEGIN
  Printf(0AX, 1)
END Ln;

PROCEDURE Ln2*;
BEGIN
  Printf('!!!', 3);
  Printf(0AX, 1)
END Ln2;

PROCEDURE Init;
BEGIN
  (*input := Libc.fdopen(Libc.STDIN_FILENO, 'rb');
  ASSERT(input # Libc.NULL, 100)*)
END Init;

PROCEDURE Close;
VAR res: INTEGER;
BEGIN
  (*res := Libc.fclose(input)*)
END Close;

BEGIN
  Init
CLOSE
  Close
END Out.
