UNIT CRX;
(* CRX   Parser Generation
   ===   =================

   Uses the top-down graph and the computed sets of terminal start symbols
   from CRTable to generate recursive descent parsing procedures.

   Errors are reported by error numbers. The corresponding error messages
   are written to <grammar name>.err.

   ---------------------------------------------------------------------*) 

INTERFACE

PROCEDURE GenCompiler;
(* Generates the target compiler (parser). *)

PROCEDURE WriteStatistics;
(* Writes statistics about compilation to list file. *)

IMPLEMENTATION

USES CRS, CRTable, CRA, FileIO, Sets;


CONST
  symSetSize = 100; (* max.number of symbol sets of the generated parser *)
  maxTerm = 5;      (* sets of size < maxTerm are enumerated *)
  maxAlter = 5;     (* more than maxAlter alternatives are handled with
                       a case statement *)(* kinds of generated error messages *) 
  tErr = 0;         (* unmatched terminal symbol *)
  altErr = 1;       (* unmatched alternatives *)
  syncErr = 2;      (* error reported at synchronization point *)

VAR
  symSet : ARRAY [0 .. symSetSize] OF CRTable.CRTSet;  (* symbol sets in the
                                                          generated parser *)
  maxSS : INTEGER;        (* number of symbol sets *)
  errorNr : INTEGER;      (* number of last generated error message*)
  curSy : INTEGER;        (* symbol whose production is currently generated *)
  err : TEXT;             (* output: error message texts *)
  fram : TEXT;            (* input:  parser frame parser.frm *)
  syn : TEXT;             (* output: generated parser *)
  NewLine : BOOLEAN;
  IndDisp : INTEGER;

(* Put                  Write ch
----------------------------------------------------------------------*) 

PROCEDURE Put (ch : CHAR);
  BEGIN
    Write(syn, ch)
  END;

(* PutLn                Write line mark
----------------------------------------------------------------------*) 

PROCEDURE PutLn;
  BEGIN
    WriteLn(syn)
  END;

(* PutB                 Write n blanks
----------------------------------------------------------------------*) 

PROCEDURE PutB (n : INTEGER); FAR;
  BEGIN
    IF n > 0 THEN Write(syn, ' ':n)
  END;

(* Indent               Indent n characters
----------------------------------------------------------------------*) 

PROCEDURE Indent (n : INTEGER); FAR;
  BEGIN
    IF NewLine THEN PutB(n) ELSE NewLine := TRUE
  END;

(* IndentProc           IndentProc n characters with additional IndDisp
----------------------------------------------------------------------*) 

PROCEDURE IndentProc (n : INTEGER); FAR;
  BEGIN
    Indent(n + IndDisp);
  END;

(* PutS                 Shortcut for WriteString(syn, ..)
----------------------------------------------------------------------*) 

PROCEDURE PutS (s : STRING); FAR;
  VAR
    i : INTEGER;
  BEGIN
    FOR i := 1 TO Length(s) DO
      IF s[i] = '$' THEN WriteLn(syn) ELSE Write(syn, s[i]);
  END;

(* PutI                 Shortcut for WriteInt(syn, i, 1)
----------------------------------------------------------------------*) 

PROCEDURE PutI (i : INTEGER);
  BEGIN
    Write(syn, i:1)
  END;

(* PutI2                Shortcut for WriteInt(syn, i, 2)
----------------------------------------------------------------------*) 

PROCEDURE PutI2 (i : INTEGER);
  BEGIN
    Write(syn, i:2)
  END;

(* PutSI                Writes i or named constant of symbol i
----------------------------------------------------------------------*) 

PROCEDURE PutSI (i : INTEGER);
  VAR
    sn : CRTable.SymbolNode;

  BEGIN
    CRTable.GetSym(i, sn);
    IF Length(sn.constant) > 0
      THEN PutS(sn.constant)
      ELSE PutI(i);
  END;

(* PutSet               Enumerate bitset
----------------------------------------------------------------------*) 

PROCEDURE PutSet (s : BITSET; offset : INTEGER);
  CONST
    MaxLine = 76;
  VAR
    first : BOOLEAN;
    i : INTEGER;
    l, len : INTEGER;
    sn : CRTable.SymbolNode;
  BEGIN
    i := 0;
    first := TRUE;
    len := 20;
    WHILE (i < Sets.size) AND (offset + i <= ORD(CRTable.maxT)) DO BEGIN
      IF i IN s
        THEN
          BEGIN
            IF first
              THEN first := FALSE
              ELSE BEGIN PutS(', '); INC(len, 2) END;
            CRTable.GetSym(offset + i, sn);
            l := Length(sn.constant);
            IF l > 0
              THEN
                BEGIN
                  IF len + l > MaxLine THEN
                    BEGIN PutS('$                    '); len := 20 END;
                  PutS(sn.constant);
                  INC(len, l);
                  IF offset > 0 THEN
                    BEGIN Put('-'); PutI(offset); INC(len, 3) END;
                END
              ELSE
                BEGIN
                  IF len + l > MaxLine THEN
                    BEGIN PutS('$                    '); len := 20 END;
                  PutI(i); INC(len, i DIV 10 + 1);
                END;
          END;
      INC(i)
    END
  END;

(* PutSet1              Enumerate long set
----------------------------------------------------------------------*) 

PROCEDURE PutSet1 (s : CRTable.CRTSet);
  VAR
    i : INTEGER;
    first : BOOLEAN;
  BEGIN
    i := 0;
    first := TRUE;
    WHILE i <= CRTable.maxT DO BEGIN
      IF Sets.IsIn(s, i) THEN
        BEGIN
          IF first THEN first := FALSE ELSE PutS(', ');
          PutSI(i)
        END;
      INC(i)
    END
  END;

(* Alternatives         Count alternatives of gp
----------------------------------------------------------------------*) 

FUNCTION Alternatives (gp : INTEGER) : INTEGER;
  VAR
    gn : CRTable.GraphNode;
    n : INTEGER;
  BEGIN
    n := 0;
    WHILE gp > 0 DO BEGIN
      CRTable.GetNode(gp, gn); gp := gn.p2; INC(n);
    END;
    Alternatives := n;
  END;

(* CopyFramePart        Copy from file <fram> to file <syn> until <stopStr>
----------------------------------------------------------------------*) 

PROCEDURE CopyFramePart (stopStr : STRING; VAR leftMarg : INTEGER);
  BEGIN
    CRA.CopyFramePart(stopStr, leftMarg, fram, syn);
  END;

TYPE
  IndentProcType = PROCEDURE (i : INTEGER);

(* CopySourcePart       Copy sequence <pos> from input file to file <syn>
----------------------------------------------------------------------*) 

PROCEDURE CopySourcePart (pos : CRTable.Position; indent : INTEGER; indentProc : IndentProcType);
  LABEL
    999;
  CONST
    CR = #13;
    LF = #10;
    EF = #0;
  VAR
    lastCh, ch : CHAR;
    extra, col, i : INTEGER;
    bp : LONGINT;
    nChars : LONGINT;
  BEGIN
    IF pos.beg >= 0 THEN
      BEGIN
        bp := pos.beg;
        nChars := pos.len;
        col := pos.col - 1;
        ch := ' ';
        extra := 0;
        WHILE (nChars > 0) AND ((ch = ' ') OR (ch = CHR(9))) DO BEGIN
        (* skip leading white space *)
        (* skip leading blanks *)
          ch := CRS.CharAt(bp); INC(bp); DEC(nChars); INC(col);
        END;
        indentProc(indent);
        WHILE TRUE DO BEGIN
          WHILE (ch = CR) OR (ch = LF) DO BEGIN
          (* Write blank lines with the correct number of leading blanks *)
            WriteLn(syn);
            lastCh := ch;
            IF nChars > 0
              THEN BEGIN ch := CRS.CharAt(bp); INC(bp); DEC(nChars); END
              ELSE GOTO 999;
            IF (ch = LF) AND (lastCh = CR)
              THEN
                BEGIN
                  extra := 1
                  (* must be MS-DOS format *) ;
                  IF nChars > 0
                    THEN BEGIN ch := CRS.CharAt(bp); INC(bp); DEC(nChars); END
                    ELSE EXIT;
                END;
            IF (ch <> CR) AND (ch <> LF) THEN
            (* we have something on this line *)
              BEGIN
                indentProc(indent);
                i := col - 1 - extra;
                WHILE ((ch = ' ') OR (ch = CHR(9))) AND (i > 0) DO BEGIN
                (* skip at most "col-1" white space chars at start of line *)
                  IF nChars > 0
                    THEN BEGIN ch := CRS.CharAt(bp); INC(bp); DEC(nChars); END
                    ELSE EXIT;
                  DEC(i);
                END;
              END;
          END;
          (* Handle extra blanks *)
          i := 0;
          WHILE ch = ' ' DO BEGIN
            IF nChars > 0
              THEN BEGIN ch := CRS.CharAt(bp); INC(bp); DEC(nChars) END
              ELSE EXIT;
            INC(i);
          END;
          IF (ch <> CR) AND (ch <> LF) AND (ch <> EF) THEN
            BEGIN
              IF i > 0 THEN PutB(i);
              Write(syn, ch);
              IF nChars > 0
                THEN BEGIN ch := CRS.CharAt(bp); INC(bp); DEC(nChars) END
                ELSE GOTO 999;
            END;
        END;
      999:
      END;
  END;

(* GenErrorMsg          Generate an error message and return its number
----------------------------------------------------------------------*) 

PROCEDURE GenErrorMsg (errTyp, errSym : INTEGER; VAR errNr : INTEGER);
  VAR
    i : INTEGER;
    name : CRTable.Name;
    sn : CRTable.SymbolNode;

  BEGIN
    INC(errorNr);
    errNr := errorNr;
    CRTable.GetSym(errSym, sn);
    name := sn.name;
    FOR i := 1 TO Length(name) DO
      IF name[i] = '''' THEN name[i] := '"';
    Write(err, ' ', errNr:3, ' : Msg(''');
    CASE errTyp OF
      tErr    : Write(err, name, ' expected');
      altErr  : Write(err, 'invalid ', name);
      syncErr : Write(err, 'this symbol not expected in ', name);
    END;
    WriteLn(err, ''');');
  END;

(* NewCondSet    Generate a new condition set, if set not yet exists
----------------------------------------------------------------------*) 

FUNCTION NewCondSet (newSet : CRTable.CRTSet) : INTEGER;
  VAR
    i : INTEGER;
  BEGIN
    i := 1; (*skip symSet[0]*)
    WHILE i <= maxSS DO BEGIN
      IF Sets.Equal(newSet, symSet[i]) THEN BEGIN NewCondSet := i; EXIT END;
      INC(i)
    END;
    INC(maxSS);
    IF maxSS > symSetSize THEN CRTable.Restriction(5, symSetSize);
    symSet[maxSS] := newSet;
    NewCondSet := maxSS
  END;

(* GenCond              Generate code to check if sym is in set
----------------------------------------------------------------------*) 

PROCEDURE GenCond (newSet : CRTable.CRTSet; indent : INTEGER);
  VAR
    i, n : INTEGER;

  FUNCTION Small (s : CRTable.CRTSet) : BOOLEAN;
    BEGIN
      i := Sets.size;
      WHILE i <= CRTable.maxT DO BEGIN
        IF Sets.IsIn(s, i) THEN BEGIN Small := FALSE; EXIT END;
        INC(i)
      END;
      Small := TRUE
    END;

  BEGIN
    n := Sets.Elements(newSet, i);
    IF n = 0
      THEN PutS(' FALSE') (*this branch should never be taken*)
      ELSE IF n <= maxTerm THEN
        BEGIN
          i := 0;
          WHILE i <= CRTable.maxT DO BEGIN
            IF Sets.IsIn(newSet, i) THEN
              BEGIN
                PutS(' (sym = '); PutSI(i); Put(')'); DEC(n);
                IF n > 0 THEN
                  BEGIN
                    PutS(' OR');
                    IF CRTable.ddt['N'] THEN BEGIN PutLn; IndentProc(indent) END
                  END
              END;
            INC(i)
          END
        END
      ELSE IF Small(newSet) THEN
        BEGIN
          PutS(' (sym < '); PutI2(Sets.size);
          PutS(') (* prevent range error *) AND$');
          IndentProc(indent); PutS(' (sym IN ['); PutSet(newSet[0], 0); PutS(']) ')
        END
      ELSE
        BEGIN PutS(' _In(symSet['); PutI(NewCondSet(newSet)); PutS('], sym)') END;
  END;

(* GenCode              Generate code for graph gp in production curSy
----------------------------------------------------------------------*) 

PROCEDURE GenCode (gp, indent : INTEGER; checked : CRTable.CRTSet);
  VAR
    gn, gn2 : CRTable.GraphNode;
    sn : CRTable.SymbolNode;
    s1, s2 :CRTable.CRTSet;
    gp2, errNr, alts, indent1, addInd, errSemNod : INTEGER;
    FirstCase, equal, OldNewLine : BOOLEAN;
  BEGIN
    WHILE gp > 0 DO BEGIN
      CRTable.GetNode(gp, gn);
      CASE gn.typ OF
        CRTable.nt :
          BEGIN
            IndentProc(indent); CRTable.GetSym(gn.p1, sn);
            PutS('_'); PutS(sn.name);
            IF gn.pos.beg >= 0 THEN
              BEGIN
                Put('('); NewLine := FALSE;
                indent1 := indent + Length(sn.name) + 2;
                CopySourcePart(gn.pos, indent1, IndentProc);
                (* was      CopySourcePart(gn.pos, 0, IndentProc); ++++ *)
                Put(')')
              END;
            PutS(';$')
          END;
        CRTable.t :
          BEGIN
            CRTable.GetSym(gn.p1, sn);
            IndentProc(indent);
            IF Sets.IsIn(checked, gn.p1)
              THEN PutS('Get;$')
              ELSE BEGIN PutS('Expect('); PutSI(gn.p1); PutS(');$') END
          END;
        CRTable.wt :
          BEGIN
            CRTable.CompExpected(ABS(gn.next), curSy, s1);
            CRTable.GetSet(0, s2); Sets.Unite(s1, s2);
            CRTable.GetSym(gn.p1, sn);
            IndentProc(indent);
            PutS('ExpectWeak('); PutSI(gn.p1); PutS(', ');
            PutI(NewCondSet(s1)); PutS(');$')
          END;
        CRTable.any :
          BEGIN IndentProc(indent); PutS('Get;$') END;
        CRTable.eps :
        (* nothing *) 
          BEGIN END;
        CRTable.sem :
          BEGIN CopySourcePart(gn.pos, indent, IndentProc); PutS(';$') END;
        CRTable.sync :
          BEGIN
            CRTable.GetSet(gn.p1, s1);
            GenErrorMsg(syncErr, curSy, errNr);
            IndentProc(indent); PutS('WHILE NOT (');
            GenCond(s1, indent + 9);
            PutS(') DO BEGIN SynError('); PutI(errNr); PutS('); Get END;$') END;
        CRTable.alt :
          BEGIN
            CRTable.CompFirstSet(gp, s1);
            equal := Sets.Equal(s1, checked);
            alts := Alternatives(gp);
            OldNewLine := NewLine;
            IF alts > maxAlter THEN
              BEGIN IndentProc(indent); PutS('CASE sym OF$') END;
            gp2 := gp;
            IF alts > maxAlter
              THEN addInd := 4
              ELSE addInd := 2;
            errSemNod :=  - 1;
            FirstCase := TRUE;
            WHILE gp2 <> 0 DO BEGIN
              CRTable.GetNode(gp2, gn2);
              CRTable.CompExpected(gn2.p1, curSy, s1);
              IndentProc(indent);
              IF alts > maxAlter
                THEN
                  BEGIN PutS('  '); PutSet1(s1); PutS(' : BEGIN$') END
                ELSE IF gp2 = gp THEN
                  BEGIN PutS('IF'); GenCond(s1, indent + 2); PutS(' THEN BEGIN$') END
                ELSE IF (gn2.p2 = 0) AND equal THEN
                  BEGIN PutS('END ELSE BEGIN$') END
                ELSE
                  BEGIN PutS('END ELSE IF'); GenCond(s1, indent + 5); PutS(' THEN BEGIN$') END;
              Sets.Unite(s1, checked);
              GenCode(gn2.p1, indent + addInd, s1);
              NewLine := TRUE;
              IF alts > maxAlter THEN
                BEGIN IndentProc(indent); PutS('    END;$'); END;
              gp2 := gn2.p2;
            END;
            IF NOT equal THEN
              BEGIN
                GenErrorMsg(altErr, curSy, errNr);
                IndentProc(indent);
                IF NOT (alts > maxAlter) THEN
                  BEGIN PutS('END '); END;
                PutS('ELSE BEGIN SynError(');
                PutI(errNr);
                PutS(');$');
                IF alts > maxAlter THEN
                  BEGIN IndentProc(indent); PutS('    END;$'); END;
              END;
            IndentProc(indent);
            PutS('END;$');
          END;
        CRTable.iter :
          BEGIN
            CRTable.GetNode(gn.p1, gn2);
            IndentProc(indent);
            PutS('WHILE');
            IF gn2.typ = CRTable.wt
              THEN
                BEGIN
                  CRTable.CompExpected(ABS(gn2.next), curSy, s1);
                  CRTable.CompExpected(ABS(gn.next), curSy, s2);
                  CRTable.GetSym(gn2.p1, sn);
                  PutS(' WeakSeparator('); PutSI(gn2.p1); PutS(', ');
                  PutI(NewCondSet(s1)); PutS(', '); PutI(NewCondSet(s2));
                  Put(')');
                  Sets.Clear(s1);
                  (*for inner structure*) 
                  IF gn2.next > 0
                    THEN gp2 := gn2.next
                    ELSE gp2 := 0;
                END
              ELSE
                BEGIN
                  gp2 := gn.p1; CRTable.CompFirstSet(gp2, s1); GenCond(s1, indent + 5)
                END;
            PutS(' DO BEGIN$');
            GenCode(gp2, indent + 2, s1);
            IndentProc(indent);
            PutS('END;$');
          END;
        CRTable.opt :
          BEGIN
            CRTable.CompFirstSet(gn.p1, s1);
            IF Sets.Equal(checked, s1)
              THEN GenCode(gn.p1, indent, checked)
              ELSE
                BEGIN
                  IndentProc(indent); PutS('IF');
                  GenCond(s1, indent + 2);
                  PutS(' THEN BEGIN$');
                  GenCode(gn.p1, indent + 2, s1);
                  IndentProc(indent); PutS('END;$');
                END
          END;
      END;
      IF (gn.typ <> CRTable.eps) AND (gn.typ <> CRTable.sem) AND (gn.typ <> CRTable.sync)
        THEN Sets.Clear(checked);
      gp := gn.next;
    END; (* WHILE gp > 0 *)
  END;

(* GenPragmaCode        Generate code for pragmas
----------------------------------------------------------------------*) 

PROCEDURE GenPragmaCode (leftMarg : INTEGER; gramName : STRING);
  LABEL
    999;
  VAR
    i : INTEGER;
    sn : CRTable.SymbolNode;
    FirstCase : BOOLEAN;

  BEGIN
    i := CRTable.maxT + 1;
    IF i > CRTable.maxP THEN EXIT;
    FirstCase := TRUE;
    PutS('CASE sym OF$'); PutB(leftMarg);
    WHILE TRUE DO BEGIN
      CRTable.GetSym(i, sn);
      IF FirstCase
        THEN BEGIN FirstCase := FALSE; PutS('  ') END
        ELSE BEGIN PutS('  ') END;
      PutSI(i); PutS(': BEGIN '); NewLine := FALSE;
      CopySourcePart(sn.semPos, leftMarg + 6, Indent);
      PutS(' END;');
      IF i = CRTable.maxP THEN GOTO 999;
      INC(i); PutLn; PutB(leftMarg);
    END;
    999:
    PutLn;
    PutB(leftMarg); PutS('END;$');
    PutB(leftMarg); PutS(gramName);
    PutS('S.nextPos := '); PutS(gramName); PutS('S.pos;$');
    PutB(leftMarg); PutS(gramName);
    PutS('S.nextCol := '); PutS(gramName); PutS('S.col;$');
    PutB(leftMarg); PutS(gramName);
    PutS('S.nextLine := '); PutS(gramName); PutS('S.line;$');
    PutB(leftMarg); PutS(gramName);
    PutS('S.nextLen := '); PutS(gramName); PutS('S.len;');
  END;

(* GenProcedureHeading  Generate procedure heading
----------------------------------------------------------------------*) 

PROCEDURE GenProcedureHeading (sn : CRTable.SymbolNode);
  BEGIN
    PutS('PROCEDURE '); PutS('_'); PutS(sn.name);
    IF sn.attrPos.beg >= 0 THEN
      BEGIN
        PutS(' ('); NewLine := FALSE;
        CopySourcePart(sn.attrPos, 13 + Length(sn.name), Indent);
        Put(')')
      END;
    Put(';')
  END;

(* GenForwardRefs       Generate forward references for one-pass compilers
----------------------------------------------------------------------*) 

PROCEDURE GenForwardRefs;
  VAR
    sp : INTEGER;
    sn : CRTable.SymbolNode;

  BEGIN
    sp := CRTable.firstNt;
    WHILE sp <= CRTable.lastNt DO BEGIN (* for all nonterminals *)
      CRTable.GetSym(sp, sn);
      GenProcedureHeading(sn); PutS(' FORWARD;$'); INC(sp)
    END;
    WriteLn(syn);
  END;

(* GenProductions       Generate code for all productions
----------------------------------------------------------------------*) 

PROCEDURE GenProductions;
  VAR
    sn : CRTable.SymbolNode;
    checked : CRTable.CRTSet;

  BEGIN
    curSy := CRTable.firstNt;
    NewLine := TRUE; (* Bug fix PDT*)
    WHILE curSy <= CRTable.lastNt DO BEGIN (* for all nonterminals *)
      CRTable.GetSym(curSy, sn); GenProcedureHeading(sn); WriteLn(syn);
      IF sn.semPos.beg >= 0 THEN
        BEGIN CopySourcePart(sn.semPos, 2, IndentProc); PutLn END;
      PutB(2);
      PutS('BEGIN$');
      {may like to add PutS(" (* "); PutS("_"); PutS(sn.name); PutS(" *)$");}
      Sets.Clear(checked);
      GenCode(sn.struct, 4, checked); PutB(2); PutS('END;$$');
      INC(curSy);
    END;
  END;

(* GenSetInits          Initialise all sets
----------------------------------------------------------------------*) 

PROCEDURE InitSets;
  VAR
    i, j : INTEGER;

  BEGIN
    CRTable.GetSet(0, symSet[0]);
    NewLine := FALSE;
    i := 0;
    WHILE i <= maxSS DO BEGIN
      IF i <> 0 THEN PutLn;
      j := 0;
      WHILE j <= CRTable.maxT DIV Sets.size DO BEGIN
        IF j <> 0 THEN PutLn;
        Indent(2); PutS('symSet['); PutI2(i); PutS(', '); PutI(j);
        PutS('] := ['); PutSet(symSet[i, j], j * Sets.size); PutS('];');
        INC(j);
      END;
      INC(i)
    END
  END;

(* GenCompiler          Generate the target compiler
----------------------------------------------------------------------*) 

PROCEDURE GenCompiler;
  VAR
    Digits, len, pos, LeftMargin : INTEGER;
    errNr, i : INTEGER;
    checked : CRTable.CRTSet;
    gn : CRTable.GraphNode;
    sn : CRTable.SymbolNode;
    gramName, fGramName, fn, ParserFrame : STRING;
    temp : TEXT;
    ch : CHAR;
  BEGIN
    ParserFrame := Concat(CRS.directory, 'parser.frm');
    FileIO.Open(fram, ParserFrame, FALSE);
    IF NOT FileIO.Okay THEN
      BEGIN
        FileIO.SearchFile(fram, 'CRFRAMES', 'parser.frm', FALSE);
        IF NOT FileIO.Okay THEN
          BEGIN WriteLn('"parser.frm" not found - Aborted.'); HALT END
      END;
    LeftMargin := 0;
    CRTable.GetNode(CRTable.root, gn);
    CRTable.GetSym(gn.p1, sn);
    gramName := Copy(sn.name, 1, 7);
    fGramName := Concat(CRS.directory, gramName);
    (*----- write *.err -----*)
    fn := Concat(fGramName, '.err');
    FileIO.Open(err, fn, TRUE);
    i := 0;
    WHILE i <= CRTable.maxT DO BEGIN GenErrorMsg(tErr, i, errNr); INC(i) END;
    IF (CRTable.ddt['N'] OR CRTable.symNames) AND NOT CRTable.ddt['D'] THEN
    (*----- write *g.pas -----*)
      BEGIN
        fn := Concat(fGramName, 'g.pas');
        FileIO.Open(syn, fn, TRUE);
        PutS('UNIT '); PutS(gramName); PutS('G;$$');
        PutS('INTERFACE$$');
        PutS('CONST');
        i := 0;
        pos := CRA.MaxSourceLineLength + 1;
        REPEAT
          CRTable.GetSym(i, sn);
          len := Length(sn.constant);
          IF len > 0 THEN
            BEGIN
              errNr := i; Digits := 1;
              WHILE errNr >= 10 DO
                BEGIN INC(Digits); errNr := errNr DIV 10 END;
              INC(len, 3 + Digits + 1);
              IF pos + len > CRA.MaxSourceLineLength THEN
                BEGIN PutLn; pos := 0 END;
              PutS('  '); PutS(sn.constant); PutS(' = '); PutI(i); Put(';');
              INC(pos, len + 2);
            END;
        INC(i);
        UNTIL i > CRTable.maxP;
        PutS('$$IMPLEMENTATION$');
        PutS('END.$');
        Close(syn);
      END;
    (* IF CRTable.ddt["N"] OR CRTable.symNames *)
    (*----- write *p.pas -----*)
    fn := Concat(fGramName, 'P.$$$');
    FileIO.Open(syn, fn, TRUE);
    CopyFramePart('-->modulename', LeftMargin);
    PutS(gramName); Put('P');
    CopyFramePart('-->scanner', LeftMargin);
    IF CRTable.hasUses THEN
      BEGIN CopySourcePart(CRTable.useDeclPos, 0, PutB); PutS(', ') END;
    PutS(gramName);
    Put('S');
    IF CRTable.ddt['N'] OR CRTable.symNames
      THEN CRA.ImportSymConsts(', ', PutS)
      ELSE PutS(';$');
    CopyFramePart('-->declarations', LeftMargin);
    CopySourcePart(CRTable.semDeclPos, 0, PutB);
    CopyFramePart('-->constants', LeftMargin);
    PutS('maxT = '); PutI(CRTable.maxT); Put(';');
    IF CRTable.maxP > CRTable.maxT THEN
      BEGIN PutLn; PutB(LeftMargin); PutS('maxP = '); PutI(CRTable.maxP); Put(';') END;
    CopyFramePart('-->symSetSize', LeftMargin);
    Write(syn, chr(255)); (* marker *)
    CopyFramePart('-->error', LeftMargin);
    PutS(gramName); PutS('S.Error(errNo, ');
    PutS(gramName); PutS('S.line, ');
    PutS(gramName); PutS('S.col, ');
    PutS(gramName); PutS('S.pos);');
    CopyFramePart('-->error', LeftMargin);
    PutS(gramName); PutS('S.Error(errNo, ');
    PutS(gramName); PutS('S.nextLine, ');
    PutS(gramName); PutS('S.nextCol, ');
    PutS(gramName); PutS('S.nextPos);');
    CopyFramePart('-->scanner', LeftMargin);
    PutS(gramName); Put('S');
    CopyFramePart('-->pragmas', LeftMargin);
    GenPragmaCode(LeftMargin, gramName);
    FOR i := 1 TO 13 DO
      BEGIN
        CopyFramePart('-->scanner', LeftMargin);
        PutS(gramName); Put('S');
      END;
    CopyFramePart('-->productions', LeftMargin);
    GenForwardRefs;
    GenProductions;
    CopyFramePart('-->parseRoot', LeftMargin);
    PutS('_Reset; Get;$');
    Sets.Clear(checked);
    GenCode(CRTable.root, LeftMargin, checked);
    CopyFramePart('-->initialization', LeftMargin);
    InitSets;
    CopyFramePart('-->modulename', LeftMargin);
    PutS(gramName + 'P *)$');
    Close(syn); Close(fram); Close(err);
    IF maxSS < 0 THEN maxSS := 0;
    FileIO.Open(temp, fn, FALSE);
    fn := Concat(fGramName, 'p.pas');
    FileIO.Open(syn, fn, TRUE);
    WHILE NOT eof(temp) DO BEGIN
      Read(temp, ch);
      IF ch = CHR(255) THEN Write(syn, maxSS:3) ELSE Write(syn, ch)
    END;
    Close(syn); Close(temp); Erase(temp)
  END;

(* WriteStatistics      Write statistics about compilation to list file
----------------------------------------------------------------------*) 

PROCEDURE WriteStatistics;

  PROCEDURE WriteNumbers (used, available : INTEGER);
    BEGIN
      WriteLn(CRS.lst, used + 1:6, ' (limit ', available:5, ')');
    END;

  BEGIN
    WriteLn(CRS.lst, 'Statistics:'); WriteLn(CRS.lst);
    Write(CRS.lst, '  nr of terminals:    ');
    WriteNumbers(CRTable.maxT, CRTable.maxTerminals);
    Write(CRS.lst, '  nr of non-terminals:');
    WriteNumbers(CRTable.lastNt - CRTable.firstNt, CRTable.maxNt);
    Write(CRS.lst, '  nr of pragmas:      ');
    WriteNumbers(CRTable.maxSymbols - CRTable.lastNt - 2, CRTable.maxSymbols - CRTable.maxT - 1);
    Write(CRS.lst, '  nr of symbolnodes:  ');
    WriteNumbers(CRTable.maxSymbols - CRTable.firstNt + CRTable.maxT, CRTable.maxSymbols);
    Write(CRS.lst, '  nr of graphnodes:   ');
    WriteNumbers(CRTable.nNodes, CRTable.maxNodes);
    Write(CRS.lst, '  nr of conditionsets:');
    WriteNumbers(maxSS, symSetSize);
    Write(CRS.lst, '  nr of charactersets:');
    WriteNumbers(CRTable.maxC, CRTable.maxClasses);
    WriteLn(CRS.lst);
    WriteLn(CRS.lst);
  END;

BEGIN (* CRX *)
  errorNr := -1;
  maxSS := 0;  (*symSet[0] reserved for allSyncSyms*)
  NewLine := TRUE;
  IndDisp := 0;
END.
