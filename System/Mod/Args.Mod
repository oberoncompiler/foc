MODULE Args;
IMPORT Kernel;

TYPE
	Hook* = POINTER TO ABSTRACT RECORD (Kernel.Hook) END;

VAR
	hook: Hook;

PROCEDURE (h: Hook) GetParam* (n: INTEGER; OUT s: ARRAY OF CHAR), NEW, ABSTRACT;
PROCEDURE (h: Hook) ParamCount* (): INTEGER, NEW, ABSTRACT;

PROCEDURE SetHook*(h: Hook);
BEGIN
	hook := h
END SetHook;

(** Puts nth command line argument in s. Argument Nr. 0 is the application name. *)
PROCEDURE GetParam* (n: INTEGER; OUT s: ARRAY OF CHAR);
BEGIN
	ASSERT(hook # NIL, 101);
	hook.GetParam(n, s)
END GetParam;

(** Returns the total number of command line arguments, including argument Nr. 0. *)
PROCEDURE ParamCount* (): INTEGER;
BEGIN
	ASSERT(hook # NIL, 101);
	RETURN hook.ParamCount()
END ParamCount;

END Args.
