MODULE Utf;

PROCEDURE Utf8ToString* (IN in: ARRAY OF SHORTCHAR; OUT out: ARRAY OF CHAR; 
                    OUT res: INTEGER);
VAR i, j, val, max: INTEGER; ch: SHORTCHAR;
  
  PROCEDURE FormatError();
  BEGIN out := in$; res := 2 (*format error*)
  END FormatError;
  
BEGIN
  ch := in[0]; i := 1; j := 0; max := LEN(out) - 1;
  WHILE (ch # 0X) & (j < max) DO
    IF ch < 80X THEN
      out[j] := ch; INC(j)
    ELSIF ch < 0E0X THEN
      val := ORD(ch) - 192;
      IF val < 0 THEN FormatError; RETURN END ;
      ch := in[i]; INC(i); val := val * 64 + ORD(ch) - 128;
      IF (ch < 80X) OR (ch >= 0E0X) THEN FormatError; RETURN END ;
      out[j] := CHR(val); INC(j)
    ELSIF ch < 0F0X THEN 
      val := ORD(ch) - 224;
      ch := in[i]; INC(i); val := val * 64 + ORD(ch) - 128;
      IF (ch < 80X) OR (ch >= 0E0X) THEN FormatError; RETURN END ;
      ch := in[i]; INC(i); val := val * 64 + ORD(ch) - 128;
      IF (ch < 80X) OR (ch >= 0E0X) THEN FormatError; RETURN END ;
      out[j] := CHR(val); INC(j)
    ELSE
      FormatError; RETURN
    END ;
    ch := in[i]; INC(i)
  END;
  out[j] := 0X;
  IF ch = 0X THEN res := 0 (*ok*) ELSE res := 1 (*truncated*) END
END Utf8ToString;

PROCEDURE StringToUtf8* (IN in: ARRAY OF CHAR; OUT out: ARRAY OF SHORTCHAR; 
                    OUT res: INTEGER);
VAR i, j, val, max: INTEGER;
BEGIN
  i := 0; j := 0; max := LEN(out) - 3;
  WHILE (in[i] # 0X) & (j < max) DO
    val := ORD(in[i]); INC(i);
    IF val < 128 THEN
      out[j] := SHORT(CHR(val)); INC(j)
    ELSIF val < 2048 THEN
      out[j] := SHORT(CHR(val DIV 64 + 192)); INC(j);
      out[j] := SHORT(CHR(val MOD 64 + 128)); INC(j)
    ELSE
      out[j] := SHORT(CHR(val DIV 4096 + 224)); INC(j); 
      out[j] := SHORT(CHR(val DIV 64 MOD 64 + 128)); INC(j);
      out[j] := SHORT(CHR(val MOD 64 + 128)); INC(j)
    END;
  END;
  out[j] := 0X;
  IF in[i] = 0X THEN res := 0 (*ok*) ELSE res :=  1 (*truncated*) END
END StringToUtf8;

END Utf.
