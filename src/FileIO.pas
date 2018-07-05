UNIT FileIO;

INTERFACE

CONST
  BitSetSize = 16;     (* number of bits in BITSET type *)

  PasExt = '.pas';     (* generated Pascal units have this extension. *)
  PathSep = ':';       (* separate components in path environment variables DOS = ';'  UNIX = ':' *)
  DirSep  = '/';       (* separate directory element of file specifiers DOS = '\'  UNIX = '/' *)

VAR
  Okay: BOOLEAN;       (* Status of last I/O operation. *)

PROCEDURE Open (VAR f: TEXT; fileName: STRING; newFile: BOOLEAN);
(* Opens file f whose full name is specified by fileName. Opening mode is specified by newFile:
       TRUE:  the specified file is opened for output only.  A file with the same name is deleted.
      FALSE:  the specified file is opened for input only.
   FileIO.Okay indicates whether the file f has been opened successfully. *)

PROCEDURE SearchFile (VAR f: TEXT; envVar, fileName: STRING; newFile: BOOLEAN);
(* As for Open, but tries to open file of given fileName by searching each directory specified by the environment variable named by envVar. *)

PROCEDURE ExtractDirectory (fullName: STRING; VAR directory: STRING);
(* Extracts D:\DIRECTORY\ portion of fullName. *)

PROCEDURE ExtractFileName (fullName: STRING; VAR fileName: STRING);
(* Extracts PRIMARY.EXT portion of fullName. *)

PROCEDURE AppendExtension (oldName, ext: STRING; VAR newName: STRING);
(* Constructs newName as complete file name by appending ext to oldName if it doesn't end with "."  Examples: (assume ext = <ext>)
         old.any ==> old.<ext>
         old.    ==> old.
         old     ==> old.<ext>
   This is not a file renaming facility, merely a string manipulation routine. *)

PROCEDURE ChangeExtension (oldName, ext: STRING; VAR newName: STRING);
(* Constructs newName as a complete file name by changing extension of oldName to ext.  Examples: (assume ext = <ext>)
         old.any ==> old.<ext>
         old.    ==> old.<ext>
         old     ==> old.<ext>
   This is not a file renaming facility, merely a string manipulation routine. *)

IMPLEMENTATION

USES DOS;

PROCEDURE Open (VAR f: TEXT; fileName: STRING; newFile: BOOLEAN);
BEGIN
  Assign(f, fileName);
  {$I-} IF newFile THEN Rewrite(f) ELSE Reset(f);
  Okay := IOResult = 0; {$I+}
END;

PROCEDURE SearchFile (VAR f: TEXT; envVar, fileName: STRING; newFile: BOOLEAN);
  VAR
    i, j, k : INTEGER;
    c : CHAR;
    paths, fname : STRING;
BEGIN
  FOR k := 1 TO Length(envVar) DO envVar[k] := UpCase(envVar[k]);
  paths := GetEnv(envVar); Okay := FALSE;
  IF paths <> '' THEN
    BEGIN
      i := 1;
      REPEAT
        j := 1;
        REPEAT
          c := paths[i]; fname[j] := c; INC(i); INC(j)
        UNTIL (c = PathSep) OR (i > Length(paths));
        IF (j > 1) AND (fname[j-1] = DirSep)
          THEN DEC(j) ELSE fname[j] := DirSep;
        fname[0] := CHR(j);
        Open(f, Concat(fname, fileName), newFile);
      UNTIL (i > Length(paths)) OR Okay
    END
END;

PROCEDURE ExtractDirectory (fullName : STRING; VAR directory : STRING);
  VAR
    i, start : INTEGER;
BEGIN
  start := 0; i := 1;
  WHILE i <= Length(fullName) DO BEGIN
    IF i <= 255 THEN directory[i] := fullName[i];
    IF (fullName[i] = ':') OR (fullName[i] = DirSep) THEN start := i;
    INC(i)
  END;
  directory[0] := CHR(start);
END;

PROCEDURE ExtractFileName (fullName : STRING; VAR fileName : STRING);
  VAR
    i, l, start : INTEGER;
BEGIN
  start := 1; l := 1;
  WHILE l <= Length(fullName) DO BEGIN
    IF (fullName[l] = ':') OR (fullName[l] = DirSep) THEN start := l + 1;
    INC(l)
  END;
  i := 1;
  WHILE start <= Length(fullName) DO BEGIN
    fileName[i] := fullName[start]; INC(start); INC(i)
  END;
  fileName[0] := CHR(i - 1)
END;

PROCEDURE AppendExtension (oldName, ext : STRING; VAR newName : STRING);
  VAR
    i, j : INTEGER;
    fn :  STRING;
BEGIN
  ExtractDirectory(oldName, newName);
  ExtractFileName(oldName, fn);
  i := 1; j := 0;
  WHILE (i <= Length(fn)) DO BEGIN
    IF fn[i] = '.' THEN j := i + 1; INC(i)
  END;
  IF Pos('.', ext) = 1 THEN Delete(ext, 1, 1);
  IF (j <> i) (* then name did not end with "." *)
    THEN
      BEGIN
        IF j <> 0 THEN Delete(fn, j - 1, 255);
        newName := Concat(newName, fn, '.', ext)
      END
    ELSE newName := oldName
END;

PROCEDURE ChangeExtension (oldName, ext : STRING; VAR newName : STRING);
  VAR
    i, j : INTEGER;
    fn : STRING;
BEGIN
  ExtractDirectory(oldName, newName);
  ExtractFileName(oldName, fn);
  i := 1; j := 0;
  WHILE (i <= Length(fn)) DO BEGIN
    IF fn[i] = '.' THEN j := i + 1; INC(i)
  END;
  IF Pos('.', ext) = 1 THEN Delete(ext, 1, 1);
  IF j <> 0 THEN Delete(fn, j - 1, 255);
  newName := Concat(newName, fn, '.', ext)
END;

END.