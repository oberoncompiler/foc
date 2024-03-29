MODULE LinLibW ["libc.so.6"];

(*
  GNU/Linux
  i386
*)

IMPORT Libc := LinLibc;

CONST
  LC_CTYPE* = 0;
  LC_NUMERIC* = 1;
  LC_TIME* = 2;
  LC_COLLATE* = 3;
  LC_MONETARY* = 4;
  LC_MESSAGES* = 5;
  LC_ALL* = 6;
  LC_PAPER* = 7;
  LC_NAME* = 8;
  LC_ADDRESS* = 9;
  LC_TELEPHONE* = 10;
  LC_MEASUREMENT* = 11;
  LC_IDENTIFICATION* = 12;

TYPE
  (* int, wchar_t, wint_t, size_t, mbstate_t *)
  int* = INTEGER;
  wchar_t* = INTEGER;
  wint_t* = INTEGER;
  size_t* = INTEGER;
  mbstate_t* = LONGINT;

  PtrWSTR* = POINTER [untagged] TO ARRAY [untagged] OF wchar_t;

PROCEDURE [ccall] setlocale* (category: int; locale: Libc.PtrSTR): Libc.PtrSTR;

PROCEDURE [ccall] mbsinit* (VAR [nil] ps: mbstate_t): int;

PROCEDURE [ccall] wctomb* (s: Libc.PtrSTR; wchar: wchar_t): int;
PROCEDURE [ccall] wcstombs* (s: Libc.PtrSTR; pwcs: PtrWSTR; n: size_t): size_t;

PROCEDURE [ccall] wcrtomb* (s: Libc.PtrSTR; wc: wchar_t; VAR [nil] ps: mbstate_t): size_t;
PROCEDURE [ccall] wcsrtombs* (dst: Libc.PtrSTR; VAR src: PtrWSTR; len: size_t; VAR [nil] ps: mbstate_t): size_t;
PROCEDURE [ccall] wcsnrtombs* (dst: Libc.PtrSTR; VAR src: PtrWSTR; nwc: size_t; len: size_t; VAR [nil] ps: mbstate_t): size_t;

PROCEDURE [ccall] mbtowc* (pwc: PtrWSTR; s: Libc.PtrSTR; n: size_t): int;
PROCEDURE [ccall] mbstowcs* (pwcs: PtrWSTR; s: Libc.PtrSTR; n: size_t): size_t;
PROCEDURE [ccall] mblen* (s: Libc.PtrSTR; n: size_t): int;

PROCEDURE [ccall] mbrtowc* (wc: PtrWSTR; s: Libc.PtrSTR; n: size_t; VAR [nil] mbs: mbstate_t): size_t;
PROCEDURE [ccall] mbsrtowcs* (dst: PtrWSTR; VAR src: Libc.PtrSTR; len: size_t; VAR [nil] ps:  mbstate_t): size_t;
PROCEDURE [ccall] mbsnrtowcs* (dst: PtrWSTR; VAR src: Libc.PtrSTR; nmc: size_t; len: size_t; VAR [nil] ps: mbstate_t): size_t;
PROCEDURE [ccall] mbrlen* (s: Libc.PtrSTR; n: size_t; VAR [nil] ps: mbstate_t): size_t;

PROCEDURE [ccall] iswalpha* (wc: wint_t): int;
PROCEDURE [ccall] iswlower* (wc: wint_t): int;
PROCEDURE [ccall] iswupper* (wc: wint_t): int;
PROCEDURE [ccall] towlower* (wc: wint_t): wint_t;
PROCEDURE [ccall] towupper* (wc: wint_t): wint_t;

PROCEDURE [ccall] wprintf* (fmt: PtrWSTR): int;
PROCEDURE [ccall] fputws* (ws: PtrWSTR; fp: Libc.PtrFILE): int;
PROCEDURE [ccall] fgetws* (ws: PtrWSTR; n: int; fp: Libc.PtrFILE): PtrWSTR;

END LinLibW.
