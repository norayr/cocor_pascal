PROGRAM -->Grammar;
(* Simple Taste Compiler/Interpreter *)

USES -->Scanner, (* lst, src, errors, Error, CharAt *)
     -->Parser,  (* Parse *)
     TC;

PROCEDURE AppendExtension (OldName, Ext : STRING; VAR NewName : STRING);
  VAR
    i : INTEGER;
  BEGIN
    i := System.Length(OldName);
    WHILE (i > 0) AND (OldName[i] <> '.') AND (OldName[i] <> '\') DO DEC(i);
    IF (i > 0) AND (OldName[i] = '.') THEN System.Delete(OldName, i, 255);
    IF System.Pos('.', Ext) = 1 THEN System.Delete(Ext, 1, 1);
    NewName := OldName + '.' + Ext
  END;

(* ------------------- Source Listing and Error handler -------------- *)

  TYPE
    CHARSET = SET OF CHAR;
    Err = ^ErrDesc;
    ErrDesc = RECORD
      nr, line, col: INTEGER;
      next: Err
    END;

  CONST
    TAB  = #09;
    _LF  = #10;
    _CR  = #13;
    _EF  = #0;
    LineEnds : CHARSET = [_CR, _LF, _EF];

  VAR
    firstErr, lastErr: Err;
    Extra : INTEGER;

  PROCEDURE StoreError (nr, line, col: INTEGER; pos: LONGINT); FAR;
  (* Store an error message for later printing *)
    VAR
      nextErr: Err;
    BEGIN
      NEW(nextErr);
      nextErr^.nr := nr; nextErr^.line := line; nextErr^.col := col;
      nextErr^.next := NIL;
      IF firstErr = NIL
        THEN firstErr := nextErr
        ELSE lastErr^.next := nextErr;
      lastErr := nextErr;
      INC(errors)
    END;

  PROCEDURE GetLine (VAR pos  : LONGINT;
                     VAR line : STRING;
                     VAR eof  : BOOLEAN);
  (* Read a source line. Return empty line if eof *)
    VAR
      ch: CHAR;
      i:  INTEGER;
    BEGIN
      i := 1; eof := FALSE; ch := CharAt(pos); INC(pos);
      WHILE NOT (ch IN LineEnds) DO BEGIN
        line[i] := ch; INC(i); ch := CharAt(pos); INC(pos);
      END;
      line[0] := Chr(i-1);
      eof := (i = 1) AND (ch = _EF);
      IF ch = _CR THEN BEGIN (* check for MsDos *)
        ch := CharAt(pos);
        IF ch = _LF THEN BEGIN INC(pos); Extra := 0 END
      END
    END;

  PROCEDURE PrintErr (line : STRING; nr, col: INTEGER);
  (* Print an error message *)

    PROCEDURE Msg (s: STRING);
      BEGIN
        Write(lst, s)
      END;

    PROCEDURE Pointer;
      VAR
        i : INTEGER;
      BEGIN
        Write(lst, '*****  ');
        i := 0;
        WHILE i < col + Extra - 2 DO BEGIN
          IF line[i] = TAB
            THEN Write(lst, TAB)
            ELSE Write(lst, ' ');
          INC(i)
        END;
        Write(lst, '^ ')
      END;

    BEGIN
      Pointer;
      CASE nr OF
      -->Errors (* rest are application defined *)
       117 : Msg('Identifier redeclared');
       118 : Msg('Undeclared identifier');
       119 : Msg('Block identifier mismatch');
       120 : Msg('Integer type expected');
       121 : Msg('Incompatible types');
       122 : Msg('Boolean type expected');
       123 : Msg('Variable expected');
       124 : Msg('Invalid procedure call');
       125 : Msg('Program too long');
      ELSE BEGIN Msg('Error: '); Write(lst, nr); END
      END;
      WriteLn(lst);
    END;

  PROCEDURE PrintListing;
  (* Print a source listing with error messages *)
    VAR
      nextErr:   Err;
      eof:       BOOLEAN;
      lnr, errC: INTEGER;
      srcPos:    LONGINT;
      line:      STRING;
    BEGIN
      WriteLn(lst, 'Listing:');
      WriteLn(lst);
      srcPos := 0; nextErr := firstErr;
      GetLine(srcPos, line, eof); lnr := 1; errC := 0;
      WHILE NOT eof DO BEGIN
        WriteLn(lst, lnr:5, '  ', line);
        WHILE (nextErr <> NIL) AND (nextErr^.line = lnr) DO BEGIN
          PrintErr(line, nextErr^.nr, nextErr^.col); INC(errC);
          nextErr := nextErr^.next
        END;
        GetLine(srcPos, line, eof); INC(lnr);
      END;
      IF nextErr <> NIL THEN BEGIN
        WriteLn(lst, lnr:5);
        WHILE nextErr <> NIL DO BEGIN
          PrintErr(line, nextErr^.nr, nextErr^.col); INC(errC);
          nextErr := nextErr^.next
        END
      END;
      WriteLn(lst);
      Write(lst, errC:5, ' error');
      IF errC <> 1 THEN Write(lst, 's');
      WriteLn(lst); WriteLn(lst); WriteLn(lst);
    END;

(* --------------------------- main module ------------------------------- *)

VAR
  sourceName, listName : STRING;

BEGIN
   firstErr := NIL; Extra := 1;

  (* check on correct parameter usage *)
   IF ParamCount < 1 THEN BEGIN
     WriteLn('No input file specified');
     HALT;
   END;
   sourceName := ParamStr(1);

  (* open the source file Scanner.src *)
  Assign(src, sourceName);
  {$I-} Reset(src, 1); {$I+}
  IF IOResult <> 0 THEN BEGIN
    WriteLn('Could not open input file');
    HALT;
  END;

  (* install error reporting procedure *)
  -->Scanner.Error := StoreError;

  (* instigate the compilation *)
  WriteLn('Parsing');
  Parse;

  (* examine the outcome from Scanner.errors *)
  IF errors <> 0
    THEN BEGIN
      (* open the output file for the source listing (* Scanner.lst *)
      AppendExtension(sourceName, 'LST', listName);
      WriteLn('Compilation errors - see ', listName);
      Assign(lst, listName);
      {$I-} Rewrite(lst); {$I+}
      IF IOResult <> 0 THEN BEGIN
        Close(lst);
        WriteLn('Could not open listing file');
        (* default Scanner.lst to screen *)
        Assign(lst, ''); Rewrite(lst);
      END;
      PrintListing; Close(lst);
    END ELSE BEGIN
      WriteLn('Parsed correctly');
      TC.Interpret;
  END;
END. (* -->Grammar *)
