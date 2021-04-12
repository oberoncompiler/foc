MODULE HostFiles;
(**
	project	= "BlackBox"
	organization	= "www.oberon.ch"
	contributors	= "Oberon microsystems"
	version	= "System/Rsrc/About"
	copyright	= "System/Rsrc/About"
	license	= "Docu/BB-License"
	changes	= ""
	issues	= ""

**)

	IMPORT SYSTEM, Kernel, Files, Libc := LinLibc, Utf, HostEnv;

	CONST
		tempName = "odcxxxxx";
		docType = "odc";

		pathLen* = 260;

		nofbufs = 4;	(* max number of buffers per file *)
		bufsize = 2 * 1024;	(* size of each buffer *)

		invalid = Libc.NULL;
		
		temp = 0; new = 1; shared = 2; hidden = 3; exclusive = 4; closed = 5;	(* file states *)
		create = -1;
		
		ok = 0;
		invalidName = 1;
		invalidNameErr = MAX(INTEGER);
		paramErr = 87;
		notFound = 2;
		fileNotFoundErr = Libc.ENOENT;
		pathNotFoundErr = Libc.ENOENT;
		existsAlready = 3;
		fileExistsErr = Libc.EEXIST;
		alreadyExistsErr = Libc.EEXIST; (* is alreadyExistsErr needed? *)
		writeProtected = 4;
		writeProtectedErr = Libc.EACCES;
		ioError = 5; (* same as Libc.EIO *)
		accessDenied = 6;
		accessDeniedErr = Libc.EACCES;
		sharingErr = Libc.EACCES;
		netAccessDeniedErr = Libc.EACCES;
		notEnoughMem = 80;
		notEnoughMemoryErr = Libc.ENOMEM;
		notEnoughDisk = 81;
		diskFullErr = Libc.EDQUOT;
		tooManyOpenFilesErr = Libc.EMFILE;
		
		noMoreFilesErr = 18;
		
		cancel = -8; retry = -9;
		invalidUtf8 = -66;	(* errors that can occur in Register *)
		resolvedPathTooLong = -67;
		canonicalizeFailed = -68;

	TYPE
		FullName* = ARRAY pathLen OF CHAR;

		Locator* = POINTER TO RECORD (Files.Locator)
			path-: FullName;	(* without trailing "/" *)
			maxLen-: INTEGER;	(* maximum name length *)
			caseSens-: BOOLEAN;	(* case sensitive file compares *)
			rootLen-: INTEGER	(* for network version *)
		END;

		Buffer = POINTER TO RECORD
			dirty: BOOLEAN;
			org, len: INTEGER;
			data: ARRAY bufsize OF BYTE
		END;

		File = POINTER TO RECORD (Files.File)
			state: INTEGER;
			name: FullName;
			ref: Libc.PtrFILE;
			loc: Locator;
			swapper: INTEGER;	(* index into file table / next buffer to swap *)
			len: INTEGER;
			bufs: ARRAY nofbufs OF Buffer;
			t: LONGINT	(* time stamp of last file operation *)
		END;

		Reader = POINTER TO RECORD (Files.Reader)
			base: File;
			org, offset: INTEGER;
			buf: Buffer
		END;

		Writer = POINTER TO RECORD (Files.Writer)
			base: File;
			org, offset: INTEGER;
			buf: Buffer
		END;

		Directory = POINTER TO RECORD (Files.Directory)
			temp, startup: Locator
		END;

		Identifier = RECORD (Kernel.Identifier)
			name: FullName
		END;
		
		Searcher = RECORD (Kernel.Identifier)
			t0: INTEGER;
			f: File
		END;
		
		Counter = RECORD (Kernel.Identifier)
			count: INTEGER
		END;
		
		ShortName = ARRAY pathLen * 4 OF SHORTCHAR;

	VAR
		MapParamString*: PROCEDURE(in, p0, p1, p2: ARRAY OF CHAR; OUT out: ARRAY OF CHAR);
		ignoreAsk-: BOOLEAN; (* file/directory operations ignore the 'ask' parameter and don't ask; used for scripting *)
		dir: Directory;
		wildcard: Files.Type;
		primaryDir: FullName;
		primaryLen: INTEGER;
		secondaryDir: FullName;
		secondaryLen: INTEGER;
		isSecondarySet, isTertiarySet: BOOLEAN;
		res: INTEGER;
		
		errString: PROCEDURE (IN string: ARRAY OF CHAR);
		errLn: PROCEDURE;

	(* debugging functions *)

	PROCEDURE SetErr* (string: PROCEDURE(IN msg: ARRAY OF CHAR); ln: PROCEDURE);
	BEGIN errString := string; errLn := ln
	END SetErr;

	PROCEDURE ErrString (IN msg: ARRAY OF CHAR);
	BEGIN IF errString # NIL THEN errString(msg) END;
	END ErrString;

	PROCEDURE ErrLn;
	BEGIN IF errLn # NIL THEN errLn END;
	END ErrLn;

	PROCEDURE Msg (IN msg: ARRAY OF CHAR);
	BEGIN ErrString(msg); ErrLn
	END Msg;

	PROCEDURE DefErrLn;
		VAR res: INTEGER;
	BEGIN
		res := Libc.printf(0AX);
		res := Libc.fflush(0)
	END DefErrLn;

	PROCEDURE DefErrString (IN str: ARRAY OF CHAR);
		CONST max = 1024;
		VAR ss: ARRAY max + 2 OF SHORTCHAR; i, j, res, len: INTEGER;
	BEGIN len := LEN(str); ss[max + 1] := 0X;
		i := 0; j := 0; WHILE (i < len) & (str[i] # 0X) DO ss[j] := SHORT(str[i]); INC(i);
			IF j = max THEN res := Libc.printf(ss); j := 0 ELSE INC(j) END
		END;
		IF j > 0 THEN ss[j] := 0X; res := Libc.printf(ss) END
	END DefErrString;
	
	
	PROCEDURE Int (x: LONGINT);
		VAR j, k: INTEGER; ch: CHAR; a, s: ARRAY 32 OF CHAR;
	BEGIN
		IF x # MIN(LONGINT) THEN
			IF x < 0 THEN s[0] := "-"; k := 1; x := -x ELSE k := 0 END;
			j := 0; REPEAT a[j] := CHR(x MOD 10 + ORD("0")); x := x DIV 10; INC(j) UNTIL x = 0
		ELSE
			a := "8085774586302733229"; s[0] := "-"; k := 1;
			j := 0; WHILE a[j] # 0X DO INC(j) END
		END;
		ASSERT(k + j < LEN(s), 20);
		REPEAT DEC(j); ch := a[j]; s[k] := ch; INC(k) UNTIL j = 0;
		s[k] := 0X;
		Msg(s);
	END Int;
	
	(* end of debugging functions *)


	(*	get error num from linux	*)
	PROCEDURE Libc_errno (): INTEGER;
		VAR
			addr, errno: INTEGER;
	BEGIN
		addr := Libc.__errno_location();
		SYSTEM.GET(addr, errno);
		RETURN errno
	END Libc_errno;
	
	PROCEDURE Error (n: INTEGER): INTEGER;
		VAR res: INTEGER;
	BEGIN
		IF n = ok THEN res := ok
		ELSIF n = invalidNameErr THEN res := invalidName
		ELSIF (n = fileNotFoundErr) OR (n = pathNotFoundErr) THEN res := notFound
		ELSIF (n = fileExistsErr) OR (n = alreadyExistsErr) THEN res := existsAlready
		ELSIF n = writeProtectedErr THEN res := writeProtected
		ELSIF (n = sharingErr) OR (n = accessDeniedErr) OR (n = netAccessDeniedErr) THEN res := accessDenied
		ELSIF n = notEnoughMemoryErr THEN res := notEnoughMem
		ELSIF (n = diskFullErr) OR (n = tooManyOpenFilesErr) THEN res := notEnoughDisk
		ELSE res := -n
		END;
		RETURN res
	END Error;

	PROCEDURE Diff (IN a, b: ARRAY OF CHAR; caseSens: BOOLEAN): INTEGER;
		VAR i: INTEGER; cha, chb: CHAR;
	BEGIN
		i := 0;
		REPEAT
			cha := a[i]; chb := b[i]; INC(i);
			IF cha # chb THEN
				IF ~caseSens THEN
					cha := Kernel.Upper(cha);
					chb := Kernel.Upper(chb);
				END;
				IF cha = "\" THEN cha := "/" END;
				IF chb = "\" THEN chb := "/" END;
				IF cha # chb THEN RETURN ORD(cha) - ORD(chb) END
			END
		UNTIL cha = 0X;
		RETURN 0
	END Diff;
	
	PROCEDURE Stat (IN fname: FullName; VAR buf: Libc.stat_t; OUT res: INTEGER);
		VAR s: ShortName; ok1: INTEGER;
	BEGIN
		Utf.StringToUtf8(fname, s, ok1);
		res := Libc.__xstat(Libc._STAT_VER_LINUX, s, buf); (* macro expansion of "stat" *)
	END Stat;
	
	PROCEDURE ModeToAttr (mode: SET; OUT attr: SET; OUT isDir: BOOLEAN);
		CONST read = 8; write = 7; execute = 6; file = 15; (* bits for permissions for the current user (see man chmod) *)
	BEGIN
		attr := {};
		IF ~(write IN mode) THEN INCL(attr, Files.readOnly) END;
		isDir := ~(file IN mode) (* see "man 2 stat" for details *)
	END ModeToAttr;

	PROCEDURE NewLocator* (IN fname: ARRAY OF CHAR): Locator;
		VAR loc: Locator; i: INTEGER;
	BEGIN
		NEW(loc); loc.path := fname$;
		i := LEN(loc.path$);
		IF (i > 1) & ((loc.path[i-1] = "/") OR (loc.path[i-1] = "\")) THEN
			loc.path[i-1] := 0X
		END;
		loc.maxLen := Libc.NAME_MAX; loc.caseSens := TRUE;
		RETURN loc
	END NewLocator;

	PROCEDURE GetType (IN name: ARRAY OF CHAR; VAR type: Files.Type);
		VAR i, j: INTEGER; ch: CHAR;
	BEGIN
		i := 0; j := 0;
		WHILE name[i] # 0X DO INC(i) END;
		WHILE (i > 0) & (name[i] # ".") DO DEC(i) END;
		IF i > 0 THEN
			INC(i); ch := name[i];
			WHILE (j < LEN(type) - 1) & (ch # 0X) DO
				ch := Kernel.Lower(ch);
				type[j] := ch; INC(j);
				INC(i); ch := name[i]
			END
		END;
		type[j] := 0X
	END GetType;

	PROCEDURE Append (IN path, name: ARRAY OF CHAR; type: Files.Type; max: INTEGER;
		VAR res: ARRAY OF CHAR
	);
		VAR i, j, n, m, dot: INTEGER; ch: CHAR;
	BEGIN
		i := 0;
		WHILE path[i] # 0X DO res[i] := path[i]; INC(i) END;
		IF (path # "") & ((path # "/") OR (path # "\")) THEN
			ASSERT((res[i-1] # "/") & (res[i-1] # "\"), 100);
			res[i] := "/"; INC(i)
		END;
		j := 0; ch := name[0]; n := 0; m := max; dot := -1;
		IF max = 12 THEN m := 8 END;
		WHILE (i < LEN(res) - 1) & (ch # 0X) DO
			IF (ch = "/") OR (ch = "\") THEN
				res[i] := ch; INC(i); n := 0; m := max; dot := -1;
				IF max = 12 THEN m := 8 END
			ELSIF (n < m) OR (ch = ".") & (n = 8) THEN
				res[i] := ch; INC(i); INC(n);
				IF ch = "." THEN dot := n;
					IF max = 12 THEN m := n + 3 END
				END
			END;
			INC(j); ch := name[j]
		END;
		IF (dot = -1) & (type # "") THEN
			IF max = 12 THEN m := n + 4 END;
			IF (n < m) & (i < LEN(res) - 1) THEN res[i] := "."; INC(i); INC(n); dot := n END
		END;
		IF n = dot THEN j := 0;
			WHILE (n < m) & (i < LEN(res) - 1) & (type[j] # 0X) DO res[i] := type[j]; INC(i); INC(j) END
		END;
		res[i] := 0X
	END Append;
	
	PROCEDURE CloseFileHandle (f: File; VAR res: INTEGER);
	BEGIN
		IF (f.ref = invalid) OR (Libc.fclose(f.ref) = 0) THEN res := ok	(* !!! *)
		ELSE res := Libc_errno()
		END;
		f.ref := invalid
	END CloseFileHandle;

	PROCEDURE CloseFile (f: File; VAR res: INTEGER);
		VAR s: INTEGER; n: ShortName; ok1: INTEGER;
	BEGIN
		IF f.state = exclusive THEN 
			f.Flush;
			res := Libc.fflush(f.ref)
		 END;
		s := f.state; f.state := closed;
		CloseFileHandle (f, res);
		IF (s IN {temp, new, hidden}) & (f.name # "") THEN
			Utf.StringToUtf8(f.name, n, ok1);
			res := Libc.remove(n)
		END
	END CloseFile;

	PROCEDURE (f: File) FINALIZE;
		VAR res: INTEGER;
	BEGIN
		IF f.state # closed THEN CloseFile(f, res) END
	END FINALIZE;
	
	PROCEDURE (VAR id: Identifier) Identified (): BOOLEAN;
		VAR f: File;
	BEGIN
		f := id.obj(File);
		RETURN (f.state IN {shared, exclusive}) & (Diff(f.name, id.name, f.loc.caseSens) = 0)
	END Identified;

	PROCEDURE ThisFile (IN name: FullName): File;
		VAR id: Identifier; p: ANYPTR;
	BEGIN
		id.typ := SYSTEM.TYP(File); id.name := name$;
		p := Kernel.ThisFinObj(id);
		IF p # NIL THEN RETURN p(File)
		ELSE RETURN NIL
		END
	END ThisFile;

	PROCEDURE (VAR s: Searcher) Identified (): BOOLEAN;
		VAR f: File;
	BEGIN
		f := s.obj(File);
		IF (f.ref # invalid) & ((s.f = NIL) OR (f.t < s.f.t)) THEN s.f := f END;
		RETURN FALSE
	END Identified;
	
	PROCEDURE SearchFileToClose;
		VAR s: Searcher; p: ANYPTR; (* res: LONGINT; *)
	BEGIN
		s.typ := SYSTEM.TYP(File); s.f := NIL;
		p := Kernel.ThisFinObj(s);
		IF s.f # NIL THEN
			res := Libc.fclose(s.f.ref); s.f.ref := invalid;
			IF res = 0 THEN res := Libc_errno(); HALT(100) END
		END
	END SearchFileToClose;
	
	PROCEDURE ExistingFile (VAR n: ShortName): BOOLEAN;
		VAR f: Libc.PtrFILE; ret: BOOLEAN; res: INTEGER;
	BEGIN
		f := Libc.fopen(n, "r");
		IF f  # Libc.NULL THEN
			res := Libc.fclose(f); 
			ret := TRUE
		ELSE
			ret := FALSE
		END;
		RETURN ret
	END ExistingFile;
	
	PROCEDURE MoveFile (VAR old, new: ShortName; VAR res: INTEGER); (* as the WinApi.MoveFile *)
	BEGIN
		IF ExistingFile(new) THEN
			res := fileExistsErr
		ELSE
			IF Libc.rename(old, new) = 0 THEN res := ok
			ELSE res := Libc_errno();
			END
		END
	END MoveFile;
	
	PROCEDURE NewFileRef (state: INTEGER; VAR name: FullName; VAR ref, res: INTEGER);
		VAR n: ShortName; ok1: INTEGER;
	BEGIN
		Utf.StringToUtf8(name, n, ok1);
		IF state = create THEN (* Create should fail if file already exists *)
			IF ExistingFile(n) THEN
				ref := invalid; res := fileExistsErr
			ELSE
				ref := Libc.fopen(n, "w+");
				IF ref = invalid THEN res := Libc_errno() ELSE res := ok END
			END
		ELSIF state = shared THEN
			ref := Libc.fopen(n, "r");
			IF ref = invalid THEN res := Libc_errno() ELSE res := ok END
		ELSE
			ref := Libc.fopen(n, "r+");
			IF ref = invalid THEN res := Libc_errno() ELSE res := ok END
		END
	END NewFileRef;
	
	PROCEDURE OpenFile (state: INTEGER; VAR name: FullName; VAR ref, res: INTEGER);
	BEGIN
		NewFileRef(state, name, ref, res);
		IF ref = invalid THEN
			IF res = tooManyOpenFilesErr THEN
				Kernel.Collect;
				NewFileRef(state, name, ref, res);
				IF ref = invalid THEN
					res := Libc_errno();
					IF res = tooManyOpenFilesErr THEN
						SearchFileToClose;
						NewFileRef(state, name, ref, res);
					END
				ELSE res := ok
				END
			END
		ELSE res := ok
		END
	END OpenFile;
	
	PROCEDURE GetTempFileName (IN path: FullName; OUT name: FullName; num: INTEGER);
		VAR i: INTEGER; str: ARRAY 16 OF CHAR;
	BEGIN
		str := tempName; i := 7;
		WHILE i > 2 DO
			str[i] := CHR(num MOD 10 + ORD("0")); DEC(i); num := num DIV 10
		END;
		Append(path, str, "", 8, name)
	END GetTempFileName;
	
	PROCEDURE CreateFile (f: File; VAR res: INTEGER);
		VAR num, n: INTEGER;
	BEGIN
		IF f.name = "" THEN
			num := Libc.clock(); n := 200;
			REPEAT
				GetTempFileName(f.loc.path, f.name, num); INC(num); DEC(n);
				OpenFile(create, f.name, f.ref, res)
			UNTIL (res # fileExistsErr) OR (n = 0)
		ELSE
			OpenFile(f.state, f.name, f.ref, res)
		END
	END CreateFile;

	PROCEDURE Delete (IN fname, path: FullName; VAR res: INTEGER); 
		VAR num, n: INTEGER; f: File; new: FullName; attr: SET; fn, nn: ShortName; buf: Libc.stat_t; isDir: BOOLEAN;
			ok1: INTEGER;
	BEGIN
		ASSERT(fname # "", 100);
		f := ThisFile(fname); Utf.StringToUtf8(fname, fn, ok1);
		IF f = NIL THEN
			IF Libc.remove(fn) = 0 THEN 
				res := ok
			ELSE 
				res := Libc.fflush(0);
				IF Libc.remove(fn) = 0 THEN res := ok ELSE res := Libc_errno() END
			END
		ELSE (* still in use => make it anonymous *)
			IF f.ref # invalid THEN res := Libc.fclose(f.ref); f.ref := invalid END;	(* !!! *)
			Stat(f.name, buf, res);
			ModeToAttr(buf.st_mode, attr, isDir);
			IF (res = ok) & ~(Files.readOnly IN attr) THEN
				num := Libc.clock(); n := 200;
				REPEAT
					GetTempFileName(path, new, num); INC(num); DEC(n);
					Utf.StringToUtf8(new, nn, ok1);
					MoveFile(fn, nn, res);
				UNTIL (res # fileExistsErr) OR (n = 0);
				IF res = ok THEN
					f.state := hidden; f.name := new$
				END
			ELSE
				res := writeProtectedErr
			END
		END
	END Delete;

	PROCEDURE FlushBuffer (f: File; i: INTEGER);
		VAR buf: Buffer; res: INTEGER;
	BEGIN
		buf := f.bufs[i];
		IF (buf # NIL) & buf.dirty THEN
			IF f.ref = invalid THEN CreateFile(f, res) (* ASSERT(res = ok, 100) *) END;
			IF f.ref # invalid THEN
				res := Libc.fseek(f.ref, buf.org, Libc.SEEK_SET);
				IF Libc.fwrite(SYSTEM.ADR(buf.data), 1, buf.len, f.ref) < buf.len THEN
					res := Libc_errno(); HALT(101)
				END;
				res := Libc.fflush(f.ref);
				buf.dirty := FALSE; f.t := Kernel.Time()
			END
		END
	END FlushBuffer;

	(* File *)

	PROCEDURE (f: File) NewReader (old: Files.Reader): Files.Reader;
		VAR r: Reader;
	BEGIN	(* portable *)
		ASSERT(f.state # closed, 20);
		IF (old # NIL) & (old IS Reader) THEN r := old(Reader) ELSE NEW(r) END;
		IF r.base # f THEN
			r.base := f; r.buf := NIL; r.SetPos(0)
		END;
		r.eof := FALSE;
		RETURN r
	END NewReader;

	PROCEDURE (f: File) NewWriter (old: Files.Writer): Files.Writer;
		VAR w: Writer;
	BEGIN	(* portable *)
		ASSERT(f.state # closed, 20); ASSERT(f.state # shared, 21);
		IF (old # NIL) & (old IS Writer) THEN w := old(Writer) ELSE NEW(w) END;
		IF w.base # f THEN
			w.base := f; w.buf := NIL; w.SetPos(f.len)
		END;
		RETURN w
	END NewWriter;

	PROCEDURE (f: File) Length (): INTEGER;
	BEGIN	(* portable *)
		RETURN f.len
	END Length;
	
	PROCEDURE (f: File) Flush;
		VAR i: INTEGER;
	BEGIN	(* portable *)
		i := 0; WHILE i # nofbufs DO FlushBuffer(f, i); INC(i) END
	END Flush;
	
	PROCEDURE GetPath (IN fname: FullName; OUT path: FullName);
		VAR i: INTEGER;
	BEGIN
		path := fname$; i := LEN(path$);
		WHILE (i > 0) & (path[i] # "\") & (path[i] # "/") & (path[i-1] # ":") DO DEC(i) END;
		path[i] := 0X
	END GetPath;
	
	PROCEDURE CreateDir (VAR path: FullName; VAR res: INTEGER);
		VAR (*sec: KERNEL32.SecurityAttributes;*) p: FullName; s: ShortName; ok1: INTEGER;
	BEGIN
		ASSERT(path # "", 100);
		Utf.StringToUtf8(path, s, ok1);
		res := Libc.mkdir(s, {0..MAX(SET)}); (* full rights are masked with the umask, is this correct? *)
		IF res # ok THEN
			res := Libc_errno();
			IF (res = Libc.ENOTDIR) OR (res = Libc.ENOENT) THEN
				GetPath(path, p);
				IF path # p THEN
					CreateDir(p, res);	(* recursive call *)
					IF res = ok THEN
						res := Libc.mkdir(s, {0..MAX(SET)}); (* full rights are masked with the umask, is this correct? *)
						IF res # ok THEN res := Libc_errno() END
					END
				END
			END
		END
	END CreateDir;
	
	PROCEDURE CheckPath (VAR path: FullName; ask: BOOLEAN; VAR res: INTEGER);
		VAR s: ARRAY 300 OF CHAR; t: ARRAY 32 OF CHAR;
	BEGIN
		IF ask & ~ignoreAsk THEN
			IF MapParamString # NIL THEN
				MapParamString("#Host:CreateDir", path, "", "", s);
				MapParamString("#Host:MissingDirectory", "", "", "", t)
			ELSE
				s := path$; t := "Missing Directory"
			END;
			res := Kernel.MessageBox(t, s, {Kernel.mbOk, Kernel.mbCancel})
		ELSE
			res := Kernel.mbOk
		END;
		IF res = Kernel.mbOk THEN CreateDir(path, res)
		ELSIF res = Kernel.mbCancel THEN res := cancel
		END
	END CheckPath;

	PROCEDURE CheckDelete (IN fname, path: FullName; ask: BOOLEAN; VAR res: INTEGER);
		VAR s: ARRAY 300 OF CHAR; t: ARRAY 16 OF CHAR; 
	BEGIN
		REPEAT
			Delete(fname, path, res);
			IF (res = writeProtectedErr)
				OR (res = sharingErr)
				OR (res = accessDeniedErr)
				OR (res = netAccessDeniedErr)
			THEN
				IF ask & ~ignoreAsk THEN
					IF MapParamString # NIL THEN
						IF res = writeProtectedErr THEN
							MapParamString("#Host:ReplaceWriteProtected", fname, 0DX, "", s)
						ELSIF (res = accessDeniedErr) OR (res = netAccessDeniedErr) THEN
							MapParamString("#Host:ReplaceAccessDenied", fname, 0DX, "", s)
						ELSE
							MapParamString("#Host:ReplaceInUse", fname, 0DX, "", s)
						END;
						MapParamString("#Host:FileError", "", "", "", t)
					ELSE
						s := fname$; t := "File Error"
					END;
					res := Kernel.MessageBox(t, s, {Kernel.mbRetry, Kernel.mbCancel});
					IF res = Kernel.mbCancel THEN res := cancel
					ELSIF res = Kernel.mbRetry THEN res := retry
					END
				ELSE
					res := cancel
				END
			ELSE
				res := ok
			END
		UNTIL res # retry
	END CheckDelete;
	
	PROCEDURE GetThisPath (IN n: FullName; OUT p: FullName);
		VAR i, len: INTEGER;
	BEGIN i := LEN(n$); WHILE (i > 0) & (n[i] # "/") DO DEC(i) END;
		p[i] := 0X; 
		REPEAT DEC(i); p[i] := n[i] UNTIL i = 0
	END GetThisPath;

	PROCEDURE (f: File) Register (name: Files.Name; type: Files.Type; ask: BOOLEAN; OUT res: INTEGER);
		VAR b: INTEGER; fname: FullName; fn, nn: ShortName; res1: INTEGER; 
			target: Libc.PtrSTR; len: INTEGER; path: FullName;
	BEGIN
		ASSERT(f.state = new, 20); ASSERT(name # "", 21);
		Append(f.loc.path, name, type, f.loc.maxLen, fname);
		Utf.StringToUtf8(fname, nn, res1);
		path := f.loc.path$;
		res := Libc.fopen(nn, "a+");	(* if nn is a symlink with a missing last element, "a+" creates the file *)
		IF res = invalid THEN res := 0
			(* the file may be write-protected (thus not allowing "a+"), but the dir may allow to remove it *)
		ELSE res := Libc.fclose(res)
		END;
		IF res = ok THEN 
			target := Libc.canonicalize_file_name(nn);
			IF target = NIL THEN res := canonicalizeFailed
			ELSE len := LEN(target$);
				IF len > LEN(ShortName) - 1 THEN res := resolvedPathTooLong
				ELSE res := ok;
					Utf.Utf8ToString(SYSTEM.THISARRAY(SYSTEM.VAL(INTEGER, target), len + 1), fname, res1);
					GetThisPath(fname, path)
				END;
				Libc.free(SYSTEM.VAL(Libc.PtrVoid, target))
			END
		END;
		(* { res = ok => fname = normalized name (all symlinks followed, last missing element allowed), path 
		is fname's path } *)
		CheckDelete(fname, path, ask,  res); ASSERT(res # paramErr, 100); 
		IF res = ok THEN
			IF f.name = "" THEN
				f.name := fname$;
				OpenFile(create, f.name, f.ref, res);
				IF res = ok THEN
					f.state := exclusive; CloseFile(f, res);
					(*Utf8.StringToUtf8(f.name, fn, res1);*)
				END 
			ELSE
				f.state := exclusive; CloseFile(f, res);
				Utf.StringToUtf8(f.name, fn, res1); Utf.StringToUtf8(fname, nn, res1);
				MoveFile(fn, nn, res);
				IF res = ok THEN
					Append(f.loc.path, name, type, f.loc.maxLen, f.name);
					(*Utf8.StringToUtf8(f.name, fn, res1);*)
				ELSE
					ASSERT(res # paramErr, 101);
					Utf.StringToUtf8(f.name, fn, res1);
					b := Libc.remove(fn);
				END
			END
		END;
		res := Error(res)
	END Register;

	PROCEDURE (f: File) Close;
		VAR res: INTEGER;
	BEGIN	(* portable *)
		IF f.state # closed THEN
(*
			IF f.state = exclusive THEN
				CloseFile(f, res)
			ELSE
				CloseFileHandle(f, res)
			END
*)
			CloseFile(f, res)
		END
	END Close;

	PROCEDURE (f: File) Closed(): BOOLEAN;
	BEGIN
		RETURN f.state = closed
	END Closed;

	(* Locator *)

	PROCEDURE (loc: Locator) This* (IN path: ARRAY OF CHAR): Locator;
		VAR new: Locator; i: INTEGER;
	BEGIN
		IF path = "" THEN
			NEW(new); new^ := loc^
		ELSIF path[0] = "/" THEN	(* absolute path *)
			new := NewLocator(path);
			new.rootLen := 0
		ELSIF (path[0] = "\") OR (path[0] = "/") THEN
			IF (path[1] = "\") OR (path[1] = "/") THEN	(* network path *)
				new := NewLocator(path);
				new.rootLen := 0
			ELSE
				NEW(new); new^ := dir.startup^;
				new.res := invalidName;
				RETURN new
			END
		ELSE
			NEW(new); Append(loc.path, path, "", loc.maxLen, new.path);
			i := 0; WHILE new.path[i] # 0X DO INC(i) END;
			IF (new.path[i-1] = "/") OR (new.path[i-1] = "\") THEN new.path[i-1] := 0X END;
			new.maxLen := loc.maxLen;
			new.caseSens := loc.caseSens;
			new.rootLen := loc.rootLen
		END;
		new.res := ok;
		RETURN new
	END This;

	(* Reader *)

	PROCEDURE (r: Reader) Base (): Files.File;
	BEGIN	(* portable *)
		RETURN r.base
	END Base;

	PROCEDURE (r: Reader) SetPos (pos: INTEGER);
		VAR f: File; org, offset, i, count, res: INTEGER; buf: Buffer; 
	BEGIN
		f := r.base; ASSERT(f # NIL, 20); ASSERT(f.state # closed, 25);
		ASSERT(pos >= 0, 22); ASSERT(pos <= f.len, 21);
		offset := pos MOD bufsize; org := pos - offset;
		i := 0; WHILE (i # nofbufs) & (f.bufs[i] # NIL) & (org # f.bufs[i].org) DO INC(i) END;
		IF i # nofbufs THEN
			buf := f.bufs[i];
			IF buf = NIL THEN	(* create new buffer *)
				NEW(buf); f.bufs[i] := buf; buf.org := -1
			END
		ELSE	(* choose an existing buffer *)
			f.swapper := (f.swapper + 1) MOD nofbufs;
			FlushBuffer(f, f.swapper); buf := f.bufs[f.swapper]; buf.org := -1
		END;
		IF buf.org # org THEN
			IF org + bufsize > f.len THEN buf.len := f.len - org ELSE buf.len := bufsize END;
			count := buf.len;
			IF count > 0 THEN
				IF f.ref = invalid THEN CreateFile(f, res) (* ASSERT(res = ok, 100) *) END;
				IF f.ref # invalid THEN
					IF Libc.fseek(f.ref, org, Libc.SEEK_SET) # 0 THEN
						res := Libc_errno(); HALT(101)
					END;
					IF  Libc.fread(SYSTEM.ADR(buf.data), 1, count, f.ref) < count THEN
						res := Libc_errno();  HALT(102)
					END;
					f.t := Kernel.Time()
				END
			END;
			buf.org := org; buf.dirty := FALSE
		END;
		r.buf := buf; r.org := org; r.offset := offset; r.eof := FALSE
		(* 0<= r.org <= r.base.len *)
		(* 0 <= r.offset < bufsize *)
		(* 0 <= r.buf.len <= bufsize *)
		(* r.offset <= r.base.len *)
		(* r.offset <= r.buf.len *)
	END SetPos;

	PROCEDURE (r: Reader) Pos (): INTEGER;
	BEGIN	(* portable *)
		ASSERT(r.base # NIL, 20);
		RETURN r.org + r.offset
	END Pos;

	PROCEDURE (r: Reader) ReadByte (OUT x: BYTE);
	BEGIN	(* portable *)
		IF (r.org # r.buf.org) OR (r.offset >= bufsize) THEN r.SetPos(r.org + r.offset) END;
		IF r.offset < r.buf.len THEN
			x := r.buf.data[r.offset]; INC(r.offset)
		ELSE
			x := 0; r.eof := TRUE
		END
	END ReadByte;

	PROCEDURE (r: Reader) ReadBytes (VAR x: ARRAY OF BYTE; beg, len: INTEGER);
		VAR from, to, count, restInBuf: INTEGER;
	BEGIN	(* portable *)
		ASSERT(beg >= 0, 21);
		IF len > 0 THEN
			ASSERT(beg + len <= LEN(x), 23);
			WHILE len # 0 DO
				IF (r.org # r.buf.org) OR (r.offset >= bufsize) THEN r.SetPos(r.org + r.offset) END;
				restInBuf := r.buf.len - r.offset; 
				IF restInBuf = 0 THEN r.eof := TRUE; RETURN
				ELSIF restInBuf <= len THEN count := restInBuf
				ELSE count := len
				END;
				from := SYSTEM.ADR(r.buf.data[r.offset]); to := SYSTEM.ADR(x) + beg;
				SYSTEM.MOVE(from, to, count);
				INC(r.offset, count); INC(beg, count); DEC(len, count)
			END;
			r.eof := FALSE
		ELSE ASSERT(len = 0, 22)
		END
	END ReadBytes;

	(* Writer *)

	PROCEDURE (w: Writer) Base (): Files.File;
	BEGIN	(* portable *)
		RETURN w.base
	END Base;

	PROCEDURE (w: Writer) SetPos (pos: INTEGER);
		VAR f: File; org, offset, i, count, res: INTEGER; buf: Buffer;
	BEGIN
		f := w.base; ASSERT(f # NIL, 20); ASSERT(f.state # closed, 25);
		ASSERT(pos >= 0, 22); ASSERT(pos <= f.len, 21);
		offset := pos MOD bufsize; org := pos - offset;
		i := 0; WHILE (i # nofbufs) & (f.bufs[i] # NIL) & (org # f.bufs[i].org) DO INC(i) END;
		IF i # nofbufs THEN
			buf := f.bufs[i];
			IF buf = NIL THEN	(* create new buffer *)
				NEW(buf); f.bufs[i] := buf; buf.org := -1
			END
		ELSE	(* choose an existing buffer *)
			f.swapper := (f.swapper + 1) MOD nofbufs;
			FlushBuffer(f, f.swapper); buf := f.bufs[f.swapper]; buf.org := -1
		END;
		IF buf.org # org THEN
			IF org + bufsize > f.len THEN buf.len := f.len - org ELSE buf.len := bufsize END;
			count := buf.len;
			IF count > 0 THEN
				IF f.ref = invalid THEN CreateFile(f, res) (* ASSERT(res = ok, 100) *) END;
				IF f.ref # invalid THEN
					IF Libc.fseek(f.ref, org, Libc.SEEK_SET) # 0 THEN
						res := Libc_errno(); HALT(101)
					END;
					IF  Libc.fread(SYSTEM.ADR(buf.data), 1, count, f.ref) < count THEN
						res := Libc_errno();  HALT(102)
					END;
					f.t := Kernel.Time()
				END
			END;
			buf.org := org; buf.dirty := FALSE
		END;
		w.buf := buf; w.org := org; w.offset := offset
		(* 0<= w.org <= w.base.len *)
		(* 0 <= w.offset < bufsize *)
		(* 0 <= w.buf.len <= bufsize *)
		(* w.offset <= w.base.len *)
		(* w.offset <= w.buf.len *)
	END SetPos;

	PROCEDURE (w: Writer) Pos (): INTEGER;
	BEGIN	(* portable *)
		ASSERT(w.base # NIL, 20);
		RETURN w.org + w.offset
	END Pos;

	PROCEDURE (w: Writer) WriteByte (x: BYTE);
	BEGIN	(* portable *)
		ASSERT(w.base.state # closed, 25);
		IF (w.org # w.buf.org) OR (w.offset >= bufsize) THEN w.SetPos(w.org + w.offset) END;
		w.buf.data[w.offset] := x; w.buf.dirty := TRUE;
		IF w.offset = w.buf.len THEN INC(w.buf.len); INC(w.base.len) END;
		INC(w.offset)
	END WriteByte;

	PROCEDURE (w: Writer) WriteBytes (IN x: ARRAY OF BYTE; beg, len: INTEGER);
		VAR from, to, count, restInBuf: INTEGER;
	BEGIN	(* portable *)
		ASSERT(beg >= 0, 21); ASSERT(w.base.state # closed, 25);
		IF len > 0 THEN
			ASSERT(beg + len <= LEN(x), 23);
			WHILE len # 0 DO
				IF (w.org # w.buf.org) OR (w.offset >= bufsize) THEN w.SetPos(w.org + w.offset) END;
				restInBuf := bufsize - w.offset;
				IF restInBuf <= len THEN count := restInBuf ELSE count := len END;
				from := SYSTEM.ADR(x) + beg; to := SYSTEM.ADR(w.buf.data[w.offset]);
				SYSTEM.MOVE(from, to, count);
				INC(w.offset, count); INC(beg, count); DEC(len, count);
				IF w.offset > w.buf.len THEN INC(w.base.len, w.offset - w.buf.len); w.buf.len := w.offset END;
				w.buf.dirty := TRUE
			END
		ELSE ASSERT(len = 0, 22)
		END
	END WriteBytes;

	(* Directory *)

	PROCEDURE (d: Directory) This (IN path: ARRAY OF CHAR): Files.Locator;
	BEGIN
		RETURN d.startup.This(path)
	END This;

	PROCEDURE (d: Directory) New (loc: Files.Locator; ask: BOOLEAN): Files.File;
		VAR f: File; res: INTEGER; attr: SET; isDir: BOOLEAN; buf: Libc.stat_t;
	BEGIN
		ASSERT(loc # NIL, 20); f := NIL; res := ok;
		WITH loc: Locator DO
			IF loc.path # "" THEN
				Stat(loc.path, buf, res);
				IF res # ok THEN
					IF loc.res = 76 THEN CreateDir(loc.path, res)
					ELSE CheckPath(loc.path, ask, res)
					END
				ELSE
					ModeToAttr(buf.st_mode, attr, isDir); 
					IF  ~isDir THEN res := fileExistsErr END
				END
			END;
			IF res = ok THEN
				NEW(f); f.loc := loc; f.name := "";
				f.state := new; f.swapper := -1; f.len := 0; f.ref := invalid
			END
		ELSE res := invalidNameErr
		END;
		loc.res := Error(res);
		RETURN f
	END New;
	
	PROCEDURE (d: Directory) Temp (): Files.File;
		VAR f: File;
	BEGIN
		NEW(f); f.loc := d.temp; f.name := "";
		f.state := temp; f.swapper := -1; f.len := 0; f.ref := invalid;
		RETURN f
	END Temp;
	
	PROCEDURE GetPrimaryDir (loc: Locator; OUT dir: FullName);
		VAR i, j: INTEGER;
	BEGIN
		dir := primaryDir$; i := primaryLen; j := loc.rootLen;
		WHILE loc.path[j] # 0X DO dir[i] := loc.path[j]; INC(i); INC(j) END;
		dir[i] := 0X
	END GetPrimaryDir;
	
	PROCEDURE GetSecondaryDir (loc: Locator; OUT dir: FullName);
		VAR i, j: INTEGER;
	BEGIN
		dir := secondaryDir$; i := secondaryLen; j := loc.rootLen;
		WHILE loc.path[j] # 0X DO dir[i] := loc.path[j]; INC(i); INC(j) END;
		dir[i] := 0X
	END GetSecondaryDir;

	PROCEDURE (d: Directory) Old (loc: Files.Locator; name: Files.Name; shrd: BOOLEAN): Files.File;
		VAR res: INTEGER; f: File; ref: Libc.PtrFILE; fname: FullName; type: Files.Type; s: BYTE; buf: Libc.stat_t;
	BEGIN
		ASSERT(loc # NIL, 20); ASSERT(name # "", 21);
		res := ok; f := NIL;
		WITH loc: Locator DO
			Append(loc.path, name, "", loc.maxLen, fname);
			f := ThisFile(fname);
			IF f # NIL THEN
				IF ~shrd OR (f.state = exclusive) THEN loc.res := Error(sharingErr); RETURN NIL
				ELSE loc.res := ok; RETURN f
				END
			END;
			IF shrd THEN s := shared ELSE s := exclusive END;
			OpenFile(s, fname, ref, res);
			
			IF ((res = fileNotFoundErr) OR (res = pathNotFoundErr)) & (isTertiarySet & isSecondarySet) THEN
				GetSecondaryDir(loc, fname);
				Append(fname, name, "", loc.maxLen, fname);
				f := ThisFile(fname);
				IF f # NIL THEN
					IF ~shrd OR (f.state = exclusive) THEN loc.res := Error(sharingErr); RETURN NIL
					ELSE loc.res := ok; RETURN f
					END
				END;
				OpenFile(s, fname, ref, res)
			END;
			
			IF ((res = fileNotFoundErr) OR (res = pathNotFoundErr)) & (isSecondarySet  OR isTertiarySet) THEN
				GetPrimaryDir(loc, fname);
				Append(fname, name, "", loc.maxLen, fname);
				f := ThisFile(fname);
				IF f # NIL THEN
					IF ~shrd OR (f.state = exclusive) THEN loc.res := Error(sharingErr); RETURN NIL
					ELSE loc.res := ok; RETURN f
					END
				END;
				OpenFile(s, fname, ref, res)
			END;
			
			IF res = ok THEN
				NEW(f); f.loc := loc;
				f.swapper := -1; 
				GetType(name, type);
				f.InitType(type);
				ASSERT(ref # invalid, 107);
				f.ref := ref; f.name := fname$; f.state := s; f.t := Kernel.Time();
				Stat(f.name, buf, res);
				f.len := buf.st_size;
				res := Libc.fseek(ref, 0, Libc.SEEK_SET);
			END
		END;
		loc.res := Error(res);
		RETURN f
	END Old;

	PROCEDURE (d: Directory) Delete* (loc: Files.Locator; name: Files.Name);
		VAR res: INTEGER; fname: FullName;
	BEGIN
		ASSERT(loc # NIL, 20);
		WITH loc: Locator DO
			Append(loc.path, name, "", loc.maxLen, fname);
			Delete(fname, loc.path, res)
		ELSE res := invalidNameErr
		END;
		loc.res := Error(res)
	END Delete;

	PROCEDURE (d: Directory) Rename* (loc: Files.Locator; old, new: Files.Name; ask: BOOLEAN);
		VAR res, i: INTEGER; oldname, newname: FullName; f: File; on, nn, tn: ShortName; buf: Libc.stat_t;
			ok1: INTEGER; tName: FullName;
	BEGIN
		ASSERT(loc # NIL, 20);
		WITH loc: Locator DO
			Append(loc.path, old, "", loc.maxLen, oldname); Append(loc.path, new, "", loc.maxLen, newname);
			Utf.StringToUtf8(oldname, on, ok1); Utf.StringToUtf8(newname, nn, ok1);
			Stat(oldname, buf, res);
			IF res = ok THEN
				f := ThisFile(oldname);
				IF (f # NIL) & (f.ref # invalid) THEN res := Libc.fclose(f.ref); f.ref := invalid END;
				IF Diff(oldname, newname, loc.caseSens) # 0 THEN
					CheckDelete(newname, loc.path, ask, res);
					IF res = ok THEN
						IF Libc.rename(on, nn) = 0 THEN
							IF f # NIL THEN	(* still in use => update file table *)
								f.name := newname$
							END
						ELSE res := Libc_errno()
						END
					END
				ELSE	(* destination is same file as source *)
					tName := oldname; i := LEN(tName$) - 1;
					REPEAT
						tName[i] := CHR(ORD(tName[i]) + 1);
						Utf.StringToUtf8(tName, tn, ok1);
						MoveFile(on, tn, res);
					UNTIL (res # fileExistsErr) & (res # alreadyExistsErr) & (res # paramErr);
					IF res = ok THEN
						MoveFile(tn, nn, res)
					END
				END
			ELSE res := fileNotFoundErr
			END
		ELSE res := invalidNameErr
		END;
		loc.res := Error(res)
	END Rename;

	PROCEDURE (d: Directory) SameFile* (loc0: Files.Locator; name0: Files.Name;
		loc1: Files.Locator; name1: Files.Name
	): BOOLEAN;
		VAR p0, p1: FullName;
	BEGIN
		ASSERT(loc0 # NIL, 20); ASSERT(loc1 # NIL, 21);
		WITH loc0: Locator DO Append(loc0.path, name0, "", loc0.maxLen, p0) END;
		WITH loc1: Locator DO Append(loc1.path, name1, "", loc1.maxLen, p1) END;
		RETURN Diff(p0, p1, loc0(Locator).caseSens) = 0
	END SameFile;

	PROCEDURE (d: Directory) FileList* (loc: Files.Locator): Files.FileInfo;
		VAR diff, res, firstRes: INTEGER; first, last, info: Files.FileInfo; s: FullName;
			ss, fname: ShortName; dirp: Libc.PtrDIR; dp: Libc.PtrDirent; buf: Libc.stat_t; tm: Libc.tm;
			isDir: BOOLEAN; attr: SET; ok1: INTEGER; dName: FullName;
	BEGIN
		ASSERT(loc # NIL, 20);
		first := NIL; last :=NIL;
		WITH loc: Locator DO
			Utf.StringToUtf8(loc.path, ss, ok1);
			dirp := Libc.opendir(ss);
			IF dirp # Libc.NULL THEN
				dp := Libc.readdir(dirp);
				WHILE dp # NIL DO
					Utf.Utf8ToString(dp.d_name$, dName, ok1);
					IF (ok1 = 0) & (dp.d_name # ".") & (dp.d_name # "..") & (LEN(dName$) < LEN(info.name)) THEN
						fname := ss + "/" + dp.d_name;
						res := Libc.__xstat(Libc._STAT_VER_LINUX, fname, buf); (* macro expansion of "stat" *)
						ModeToAttr(buf.st_mode, attr, isDir);
						IF ~isDir THEN
							info := first; last := NIL; s := dName;
							WHILE (info # NIL) & (Diff(info.name, s, loc.caseSens) < 0) DO last := info; info := info.next END;
							NEW(info);
							info.name := dName$;
							GetType(info.name, info.type);
							info.length := buf.st_size; 
							tm := Libc.localtime(buf.st_mtim.tv_sec);
							IF tm # NIL THEN 
								info.modified.year := tm.tm_year  + 1900;
								info.modified.month := tm.tm_mon + 1;
								info.modified.day := tm.tm_mday;
								info.modified.hour := tm.tm_hour;
								info.modified.minute := tm.tm_min;
								info.modified.second := tm.tm_sec
							END;
							info.attr := attr;
							IF last = NIL THEN info.next := first; first := info ELSE info.next := last.next; last.next := info END
						END
					END;
					dp := Libc.readdir(dirp)
				END;
				res := Libc.closedir(dirp)
			ELSE res := Libc_errno()
			END;
			firstRes := res;
			
			(* check secondary directory *)
			IF (isTertiarySet & isSecondarySet)
				& ((res = ok) OR (res = fileNotFoundErr) OR (res = pathNotFoundErr)) THEN
				GetSecondaryDir(loc, s);
				Utf.StringToUtf8(s, ss, ok1);
				dirp := Libc.opendir(ss);
				IF dirp # Libc.NULL THEN
					dp := Libc.readdir(dirp);
					WHILE dp # NIL DO
						Utf.Utf8ToString(dp.d_name$, dName, ok1);
						IF (ok1 = 0) & (dp.d_name # ".") & (dp.d_name # "..") & (LEN(dName$) < LEN(info.name)) THEN
							fname := ss + "/" + dp.d_name;
							res := Libc.__xstat(Libc._STAT_VER_LINUX, fname, buf); (* macro expansion of "stat" *)
							ModeToAttr(buf.st_mode, attr, isDir);
							IF ~isDir THEN	
								info := first; last := NIL; s := dName;
								IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END;
								WHILE (info # NIL) & (diff < 0) DO 
									last := info; info := info.next; 
									IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END
								END;
								IF (info = NIL) OR (diff # 0) THEN
									NEW(info);
									info.name := dName$;
									GetType(info.name, info.type);
									info.length := buf.st_size; 
									tm := Libc.localtime(buf.st_mtim.tv_sec);
									IF tm # NIL THEN 
										info.modified.year := tm.tm_year  + 1900;
										info.modified.month := tm.tm_mon + 1;
										info.modified.day := tm.tm_mday;
										info.modified.hour := tm.tm_hour;
										info.modified.minute := tm.tm_min;
										info.modified.second := tm.tm_sec
									END;
									info.attr := attr;
									IF last = NIL THEN info.next := first; first := info ELSE info.next := last.next; last.next := info END
								END
							END
						END;
						dp := Libc.readdir(dirp)
					END;
					res := Libc.closedir(dirp)
				ELSE res := Libc_errno()
				END
			END;
			
			(* check primary directory *)
			IF (isTertiarySet OR isSecondarySet)
				& ((res = ok) OR (res = fileNotFoundErr) OR (res = pathNotFoundErr)) THEN
				GetPrimaryDir(loc, s);
				Utf.StringToUtf8(s, ss, ok1);
				dirp := Libc.opendir(ss);
				IF dirp # Libc.NULL THEN
					dp := Libc.readdir(dirp);
					WHILE dp # NIL DO
						Utf.Utf8ToString(dp.d_name$, dName, ok1);
						IF (ok1 = 0) & (dp.d_name # ".") & (dp.d_name # "..") & (LEN(dName$) < LEN(info.name)) THEN
							fname := ss + "/" + dp.d_name;
							res := Libc.__xstat(Libc._STAT_VER_LINUX, fname, buf); (* macro expansion of "stat" *)
							ModeToAttr(buf.st_mode, attr, isDir);
							IF ~isDir THEN	
								info := first; last := NIL; s := dName;
								IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END;
								WHILE (info # NIL) & (diff < 0) DO 
									last := info; info := info.next; 
									IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END
								END;
								IF (info = NIL) OR (diff # 0) THEN
									NEW(info);
									info.name := dName$;
									GetType(info.name, info.type);
									info.length := buf.st_size; 
									tm := Libc.localtime(buf.st_mtim.tv_sec);
									IF tm # NIL THEN 
										info.modified.year := tm.tm_year  + 1900;
										info.modified.month := tm.tm_mon + 1;
										info.modified.day := tm.tm_mday;
										info.modified.hour := tm.tm_hour;
										info.modified.minute := tm.tm_min;
										info.modified.second := tm.tm_sec
									END;
									info.attr := attr;
									IF last = NIL THEN info.next := first; first := info ELSE info.next := last.next; last.next := info END
								END
							END
						END;
						dp := Libc.readdir(dirp)
					END;
					res := Libc.closedir(dirp)
				ELSE res := Libc_errno()
				END
			END;
			
			IF (res = fileNotFoundErr) OR (res = pathNotFoundErr) THEN res := firstRes END;
			loc.res := Error(res)
		ELSE
			loc.res := invalidName
		END;
		
		
		RETURN first
	END FileList;
	
	PROCEDURE (d: Directory) LocList* (loc: Files.Locator): Files.LocInfo;
		VAR diff, res, firstRes: INTEGER; first, last, info: Files.LocInfo; s: FullName; isDir: BOOLEAN; attr: SET;
			ss, fname: ShortName; dirp: Libc.PtrDIR; dp: Libc.PtrDirent; buf: Libc.stat_t;
			ok1: INTEGER; dName: FullName;
	BEGIN
		ASSERT(loc # NIL, 20);
		first := NIL; last :=NIL;
		WITH loc: Locator DO
			Utf.StringToUtf8(loc.path, ss, ok1);
			dirp := Libc.opendir(ss);
			IF dirp # Libc.NULL THEN
				dp := Libc.readdir(dirp);
				WHILE dp # NIL DO
					Utf.Utf8ToString(dp.d_name$, dName, ok1);
					IF (ok1 = 0) & (dp.d_name # ".") & (dp.d_name # "..") & (LEN(dName$) < LEN(info.name)) THEN
						fname := ss + "/" + dp.d_name;
						res := Libc.__xstat(Libc._STAT_VER_LINUX, fname, buf); (* macro expansion of "stat" *)
						ModeToAttr(buf.st_mode, attr, isDir);
						IF isDir THEN	
							info := first; last := NIL; s := dName;
							WHILE (info # NIL) & (Diff(info.name, s, loc.caseSens) < 0) DO last := info; info := info.next END;
							NEW(info);
							info.name := dName$;
							info.attr := attr;
							IF last = NIL THEN info.next := first; first := info ELSE info.next := last.next; last.next := info END
						END
					END;
					dp := Libc.readdir(dirp)
				END;
				res := Libc.closedir(dirp)
			ELSE res := Libc_errno()
			END;
			firstRes := res;
			
			(* check secondary directory *)
			IF (isTertiarySet & isSecondarySet)
				& ((res = ok) OR (res = fileNotFoundErr) OR (res = pathNotFoundErr)) THEN
				GetSecondaryDir(loc, s);
				Utf.StringToUtf8(s, ss, ok1);
				dirp := Libc.opendir(ss);
				IF dirp # Libc.NULL THEN
					dp := Libc.readdir(dirp);
					WHILE dp # NIL DO
						Utf.Utf8ToString(dp.d_name$, dName, ok1);
						IF (ok1 = 0) & (dp.d_name # ".") & (dp.d_name # "..") & (LEN(dName$) < LEN(info.name)) THEN
							fname := ss + "/" + dp.d_name;
							res := Libc.__xstat(Libc._STAT_VER_LINUX, fname, buf); (* macro expansion of "stat" *)
							ModeToAttr(buf.st_mode, attr, isDir);
							IF isDir THEN	
								info := first; last := NIL; s := dName;
								IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END;
								WHILE (info # NIL) & (diff < 0) DO 
									last := info; info := info.next; 
									IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END
								END;
								IF (info = NIL) OR (diff # 0) THEN
									NEW(info);
									info.name := dName$;
									info.attr := attr;
									IF last = NIL THEN info.next := first; first := info ELSE info.next := last.next; last.next := info END
								END
							END
						END;
						dp := Libc.readdir(dirp)
					END;
					res := Libc.closedir(dirp)
				ELSE res := Libc_errno()
				END
			END;
			
			(* check primary directory *)
			IF (isTertiarySet OR isSecondarySet)
				& ((res = ok) OR (res = fileNotFoundErr) OR (res = pathNotFoundErr)) THEN
				GetPrimaryDir(loc, s);
				Utf.StringToUtf8(s, ss, ok1);
				dirp := Libc.opendir(ss);
				IF dirp # Libc.NULL THEN
					dp := Libc.readdir(dirp);
					WHILE dp # NIL DO
						Utf.Utf8ToString(dp.d_name$, dName, ok1);
						IF (ok1 = 0) & (dp.d_name # ".") & (dp.d_name # "..") & (LEN(dName$) < LEN(info.name)) THEN
							fname := ss + "/" + dp.d_name;
							res := Libc.__xstat(Libc._STAT_VER_LINUX, fname, buf); (* macro expansion of "stat" *)
							ModeToAttr(buf.st_mode, attr, isDir);
							IF isDir THEN	
								info := first; last := NIL; s := dName;
								IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END;
								WHILE (info # NIL) & (diff < 0) DO 
									last := info; info := info.next; 
									IF info # NIL THEN diff := Diff(info.name, s, loc.caseSens) END
								END;
								IF (info = NIL) OR (diff # 0) THEN
									NEW(info);
									info.name := dName$;
									info.attr := attr;
									IF last = NIL THEN info.next := first; first := info ELSE info.next := last.next; last.next := info END
								END
							END
						END;
						dp := Libc.readdir(dirp)
					END;
					res := Libc.closedir(dirp)
				ELSE res := Libc_errno()
				END
			END;
			
			IF (res = fileNotFoundErr) OR (res = pathNotFoundErr) THEN res := firstRes END;
			loc.res := Error(res)
		ELSE loc.res := invalidName
		END;
		RETURN first
	END LocList;

	PROCEDURE (d: Directory) GetFileName (name: Files.Name; type: Files.Type; OUT filename: Files.Name);
	BEGIN
		Append("", name, type, LEN(filename), filename)
	END GetFileName;

	(** Miscellaneous **)
	
	PROCEDURE (VAR id: Counter) Identified (): BOOLEAN;
		VAR f: File;
	BEGIN
		f := id.obj(File);
		IF f.state # closed THEN INC(id.count) END;
		RETURN FALSE
	END Identified;

	PROCEDURE NofFiles* (): INTEGER;
		VAR p: ANYPTR; cnt: Counter;
	BEGIN
		cnt.typ := SYSTEM.TYP(File);
		cnt.count := 0; p := Kernel.ThisFinObj(cnt);
		RETURN cnt.count
	END NofFiles;
	
	PROCEDURE GetModDate* (f: Files.File; VAR year, month, day, hour, minute, second: INTEGER);
		VAR buf: Libc.stat_t; tm: Libc.tm;
	BEGIN
		ASSERT(f IS File, 20);
		Stat(f(File).name, buf, res);
		IF res = ok THEN
			tm := Libc.gmtime(buf.st_mtim.tv_sec);
			IF tm # NIL THEN
				year := tm.tm_year  + 1900; month := tm.tm_mon + 1; day := tm.tm_mday;
				hour := tm.tm_hour; minute := tm.tm_min; second := tm.tm_sec
			ELSE
				res := -1
			END
		END;
		IF res # ok THEN year := 0; month := 0; day := 0; hour := 0; minute := 0; second := 0 END
	END GetModDate;
	
	PROCEDURE SetRootDir* (path: ARRAY OF CHAR);
		VAR i: INTEGER;
	BEGIN
		dir.startup := NewLocator(path);
		dir.startup.rootLen := 0; i := 0;
		WHILE primaryDir[i] # 0X DO INC(i) END;
		primaryLen := i;
		isSecondarySet := FALSE;
		isTertiarySet := FALSE;
	END SetRootDir;

	PROCEDURE IsDir (IN fname: FullName): BOOLEAN;
		VAR	res: BOOLEAN; res1: INTEGER; buf: Libc.stat_t; attr: SET;
	BEGIN
		Stat(fname, buf, res1); res := res1 = ok;
		IF res THEN ModeToAttr(buf.st_mode, attr, res) END;
		RETURN res
	END IsDir;

	PROCEDURE Init;
		CONST
			bbPrimaryDir = "BB_PRIMARY_DIR";
			bbSecondaryDir = "BB_SECONDARY_DIR";
			bbTertiaryDir = "BB_TERTIARY_DIR";
		VAR
			res1, res2, res: INTEGER; p: Libc.PtrSTR;
			isDir: BOOLEAN; fname: FullName; ok1: INTEGER;
	BEGIN
		(* set debug out *)
		SetErr(DefErrString, DefErrLn);
		
		ignoreAsk := FALSE;

		wildcard := "*"; NEW(dir);

		(*HostEnv.GetPar(bbPrimaryDir, fname, res1);*) (* <- LINE IS REPLACED WITH: *)
		fname := 'BlackBox'; res1 := 0;
		(* END OF REPLACE *)

		IF res1 = 2 THEN
		ELSIF res1 IN {1, 3} THEN
			res1 := 2;	(* не найдено *)
			Msg("HostFiles: Failed to get " + bbPrimaryDir + ", using cwd")
		ELSIF ~IsDir(fname) THEN
			res1 := 2;	(* не найдено *)
			Msg("HostFiles: Value of " + bbPrimaryDir + " isn't directory, using cwd; " + bbPrimaryDir + " =" + fname)
		END;
		IF res1 # 0 THEN
			p := NIL; p := Libc.getcwd(p, 0);
			Utf.Utf8ToString(p$, fname, ok1);
			IF ~ (ok1 = 0) THEN fname := "." END;
			Libc.free(SYSTEM.VAL(Libc.PtrVoid, p))
		END;
		primaryDir := fname; primaryLen := LEN(primaryDir$);
		dir.startup := NewLocator(primaryDir);
		dir.startup.rootLen := 0;

		isSecondarySet := FALSE;

		(*HostEnv.GetPar(bbSecondaryDir, fname, res2);*) (* <- LINE IS REPLACED WITH: *)
		fname := '.'; res2 := 0;
		(* END OF REPLACE *)

		IF (res1 # 0) OR (res2 = 2) THEN
		ELSIF res2 IN {1, 3} THEN
			Msg("HostFiles: Failed to get " + bbSecondaryDir)
		ELSIF ~IsDir(fname) THEN
			Msg("HostFiles: Value of " + bbSecondaryDir + " isn't directory: " + fname)
		ELSE
			secondaryDir := fname; secondaryLen := LEN(secondaryDir$);
			dir.startup := NewLocator(fname);
			dir.startup.rootLen := secondaryLen;
			isSecondarySet := TRUE;
		END;
		
		isTertiarySet := FALSE;
		HostEnv.GetPar(bbTertiaryDir, fname, res2);
		IF (res1 # 0) OR (res2 = 2) THEN
		ELSIF res2 IN {1, 3} THEN
			Msg("HostFiles: Failed to get " + bbTertiaryDir)
		ELSIF ~IsDir(fname) THEN
			Msg("HostFiles: Value of " + bbTertiaryDir + " isn't directory: " + fname)
		ELSE
			dir.startup := NewLocator(fname);
			dir.startup.rootLen := LEN(fname$);
			isTertiarySet := TRUE;
		END;
		
		dir.temp := NewLocator(Libc.P_tmpdir);
		Files.SetDir(dir)
	END Init;

	(* use this mode e.g. for scripting, i.e. when modal dialog boxes are not appropriate; 
		implicitly uses OK in OK/Cancel dialogs and Cancel in Retry/Cancel dialogs *)
	PROCEDURE IgnoreAsk*;
	BEGIN ignoreAsk := TRUE
	END IgnoreAsk;

	(* use this mode for interactive usage of BlackBox, i.e. when modal dialog boxes are appropriate; 
		this is the default behavior. *)
	PROCEDURE UseAsk*;
	BEGIN ignoreAsk := FALSE
	END UseAsk;

BEGIN
	Init
END HostFiles.

