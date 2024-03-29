MODULE LinDl ["libdl.so.2"];
IMPORT SYSTEM;

CONST
  (* dlOpen mode parameters *)
  RTLD_LAZY* = 01H;  (* Lazy function call binding. *)
  RTLD_NOW* = 02H;  (* Immediate function call binding. *)
  RTLD_BINDING_MASK* = 03H;  (* Mask of binding time value. *)
  RTLD_NOLOAD* = 04H;  (* Do not load the object. *)
  RTLD_LOCAL* = 0;
  RTLD_GLOBAL* = 100H;
  RTDL_NODELETE* = 1000H;
  
  NULL* = 0;

TYPE
  PtrVoid* = INTEGER;
  HANDLE* = PtrVoid;
  PtrSTR* = POINTER TO ARRAY [untagged] OF SHORTCHAR;

PROCEDURE [ccall] dlopen* (file: PtrSTR; mode: INTEGER): HANDLE; 
PROCEDURE [ccall] dlsym* (handle: HANDLE; name: PtrSTR): HANDLE; 
PROCEDURE [ccall] dlclose* (handle: HANDLE): INTEGER;
PROCEDURE [ccall] dlerror* (): PtrSTR;

END LinDl.
