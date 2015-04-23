(*$M 32000, 0, 655360 *)  (* Turbo Pascal directives *)

(* CR   Main Module of Coco/R
   ==   =====================

   This is a compiler generator that produces a scanner and a parser
   from an attributed grammar, and optionally a complete small compiler.

   Original code in Oberon by Hanspeter Moessenboeck, ETH Zurich
   Ported at ETH to Apple Modula, and thence to JPI-2 Modula.

   JPI version of 27 January 1991 was then modified to make more
   portable by Pat Terry, January - October 1992

   This is the IBM-PC MS-DOS Turbo Pascal version for generating Turbo Pascal
   based on the port first done by Volker Pohlers, October 1995


Usage:
          COCOR [-options] GrammarName[.atg] [$options]

Input:
  attributed grammar   input grammar
  scanner.frm          frame file
  parser.frm           frame file
  compiler.frm         frame file (optional)

(Frame files must be in the sme directory as the grammar, or may be
found on a path specified by DOS environment variable CRFRAMES).

Output:
  <GrammarName>S.pas  generated scanner
  <GrammarName>P.pas  generated parser
  <GrammarName>.err   error numbers and corresponding error messages
  <GrammarName>.lst   source listing with error messages and trace output

Optionally

  <GrammarName>G.pas  generated symbolic names
  <GrammarName>.pas   generated compiler main module

Implementation restrictions
  1  too many nodes in graph (>1500)                 CRTable.NewNode
  2  too many symbols (>500)                         CRTable.NewSym, MovePragmas
  3  too many sets (>256 ANY-syms or SYNC syms)      CRTable.NewSet,
  4  too many character classes (>250)               CRTable.NewClass
  5  too many conditions in generated code (>100)    CRX.NewCondSet
  6  too many token names in "NAMES" (>100)          CRTable.NewName
  7  too many states in automata (>500)              CRA.NewState

Trace output
(To activate a trace switch, write "${letter}" in the input grammar, or
invoke Coco with a second command line parameter)

  A  Prints states of automaton

  C  Generates complete compiler module

  F  Prints start symbols and followers of nonterminals.

  G  Prints the top-down graph.

  I  Trace of start symbol set computation.

  L  Forces a listing (otherwise a listing is only printed if errors are found).
  
  N  Uses default names for symbol value constants.  This generates an
     extra module <grammar name>G, and corresponding import statements
     using constant names instead of numbers for symbols in parser and
     scanner.
     The constants are used unqualified and hence all needed constants
     have to be imported; so a complete import list for these constants
     is generated.
     There is no decision whether a constant is actually needed.

     The default conventions are (only terminals or pragmas can have names):
     single character   -->  <ASCII name (lowercase)>Sym
          eg. "+"       -->  plusSym
     character string   -->  <string>Sym
          eg. "PROGRAM" -->  PROGRAMSym
     scanner token      -->  <token name>Sym
          eg. ident     -->  identSym

  O  Trace of follow set computation (not yet implemented).

  P  Generates parser only

  S  Prints the symbol list.

  T  Suppresses generation of units (grammar tests only).

  X  Prints a cross reference list.

==========================================================================*)

PROGRAM -->Grammar;

USES -->Scanner, (* lst, src, errors, directory, Error, CharAt *)
     -->Parser, (* Parse *)
     CRC, CRTable, CRA, CRX, FileIO;

CONST
  ATGExt = '.atg';
  LSTExt = '.lst';
  Version = '1.53 (for Pascal)';
  ReleaseDate = '17 September 2002';

VAR
  Options, GrammarName, ATGFileName, lstFileName : STRING;
  ll1 : BOOLEAN; (* TRUE, if grammar is LL(1) *)
  ok : BOOLEAN;  (* TRUE, if grammar tests ok so far *)
  P : INTEGER;   (* ParamCount *)

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
        line[i] := ch; INC(i); ch := CharAt(pos); INC(pos)
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
       -->Errors
        101 : Msg('character set may not be empty');
        102 : Msg('string literal may not extend over line end');
        103 : Msg('a literal must not have attributes');
        104 : Msg('this symbol kind not allowed in production');
        105 : Msg('attribute mismatch between declaration and use');
        106 : Msg('undefined string in production');
        107 : Msg('name declared twice');
        108 : Msg('this type not allowed on left side of production');
        109 : Msg('earlier semantic action was not terminated');
        111 : Msg('missing production for grammar name');
        112 : Msg('grammar symbol must not have attributes');
        113 : Msg('a literal must not be declared with a structure');
        114 : Msg('semantic action not allowed here');
        115 : Msg('undefined name');
        116 : Msg('attributes not allowed in token declaration');
        117 : Msg('name does not match grammar name');
        118 : Msg('unacceptable constant value');
        119 : Msg('may not ignore CHR(0)');
        120 : Msg('token might be empty');
        121 : Msg('token must not start with an iteration');
        122 : Msg('comment delimiters may not be structured');
        123 : Msg('only terminals may be weak');
        124 : Msg('literal tokens may not contain white space');
        125 : Msg('comment delimiter must be 1 or 2 characters long');
        126 : Msg('character set contains more than one character');
        127 : Msg('could not make deterministic automaton');
        128 : Msg('semantic action text too long - please split it');
        129 : Msg('literal tokens may not be empty');
        130 : Msg('IGNORE CASE must appear earlier');
        ELSE BEGIN Msg('Error: '); Write(lst, nr) END
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
      WriteLn(lst, 'Listing:'); WriteLn(lst);
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

PROCEDURE SetOption (s : STRING);
(* Set compiler options *) 
  VAR
    i : INTEGER;
  BEGIN
    FOR i := 2 TO Length(s) DO
      BEGIN
        s[i] := UpCase(s[i]);
        IF s[i] IN ['A' .. 'Z'] THEN CRTable.ddt[s[i]] := TRUE
      END;
  END;

PROCEDURE Msg (S : STRING);
  BEGIN
    WriteLn(S);
  END;

(* --------------------------- Help ------------------------------- *)

PROCEDURE Help;
  BEGIN
    Msg('Usage: COCOR [-Options] [Grammar[.atg]] [-Options]');
    Msg('Example: COCOR -cs Test');
    Msg('');
    Msg('Options are');
    Msg('a  - Trace automaton');
    Msg('c  - Generate compiler module');
    Msg('f  - Give Start and Follower sets');
    Msg('g  - Print top-down graph');
    Msg('i  - Trace start set computations');
    Msg('l  - Force listing');
    Msg('n  - Generate symbolic names');
    Msg('p  - Generate parser only');
    Msg('s  - Print symbol table');
    Msg('t  - Grammar tests only - no code generated');
    Msg('x  - Print cross reference list');
    Msg('COMPILER.FRM, SCANNER.FRM and PARSER.FRM must be in the working directory,');
    Msg('or on the path specified by the environment variable CRFRAMES');
  END;

BEGIN
  firstErr := NIL; Extra := 1; P := 1;
  Write('Coco/R (MS-DOS) - Compiler-Compiler V');
  WriteLn(Version);
  WriteLn('Turbo Pascal (TM) version by Pat Terry/Volker Pohlers ', ReleaseDate);
  GrammarName := ParamStr(1);
  IF (GrammarName = '?') OR (GrammarName = '') OR (GrammarName = '/?') THEN
    BEGIN Help; HALT END;
  WHILE (Length(GrammarName) > 0) AND (GrammarName[1] IN ['-', '/']) DO BEGIN
  (* accept options before filename *) 
    SetOption(GrammarName);
    INC(P); GrammarName := ParamStr(P);
  END;
  ok := GrammarName <> '';
  REPEAT
    IF NOT ok THEN
      BEGIN
        Write('Grammar[.atg] ? : ');
        ReadLn(GrammarName);
        IF GrammarName = '' THEN HALT;
      END;
    FileIO.AppendExtension(GrammarName, ATGExt, ATGFileName);
    GrammarName := ATGFileName;
    Assign(src, GrammarName);
    {$I-} Reset(src, 1); {$I+}
    ok := IOResult = 0;
    IF NOT ok THEN WriteLn('File <', GrammarName, '> not found.');
  UNTIL ok;
  INC(P); Options := ParamStr(P);
  IF Options <> '' THEN SetOption(Options);
  FileIO.ExtractDirectory(GrammarName, directory);
  FileIO.ChangeExtension(GrammarName, LSTExt, lstFileName);
  FileIO.Open(lst, lstFileName, TRUE);
  WriteLn(lst, 'Coco/R - Compiler-Compiler V', Version);
  WriteLn(lst, 'Turbo Pascal (TM) version by Volker Pohlers/Pat Terry ', ReleaseDate);
  WriteLn(lst, 'Source file: ', GrammarName);
  WriteLn(lst);
  WriteLn; WriteLn('parsing file ', GrammarName);
  -->Scanner.Error := StoreError;
  CRP.Parse;
  IF errors = 0
    THEN
      BEGIN
        Msg('testing grammar');
        WriteLn(lst, 'Grammar Tests:'); WriteLn(lst);
        CRTable.CompSymbolSets;
        CRTable.TestCompleteness(ok);
        IF ok THEN CRTable.TestIfAllNtReached(ok);
        IF ok THEN CRTable.FindCircularProductions(ok);
        IF ok THEN CRTable.TestIfNtToTerm(ok);
        IF ok THEN CRTable.LL1Test(ll1);
        WriteLn(lst);
        IF NOT ok OR NOT ll1 OR CRTable.ddt['L'] OR CRTable.ddt['X'] THEN
          BEGIN
            Msg('listing'); PrintListing;
            IF CRTable.ddt['X'] THEN CRTable.XRef;
          END;
        IF CRTable.ddt['N'] OR CRTable.symNames THEN
          BEGIN
            Msg('symbol name assignment');
            CRTable.AssignSymNames(CRTable.ddt['N'], CRTable.symNames);
          END;
        IF ok AND NOT CRTable.ddt['T'] THEN
          BEGIN
            Msg('generating parser');
            CRX.GenCompiler;
            IF CRTable.genScanner AND NOT CRTable.ddt['P'] THEN
              BEGIN
                Msg('generating scanner');
                CRA.WriteScanner(ok);
                IF CRTable.ddt['A'] THEN CRA.PrintStates;
              END;
            IF CRTable.ddt['C'] THEN
              BEGIN Msg('generating compiler'); CRC.WriteDriver END;
            CRX.WriteStatistics;
          END;
        IF NOT ok
          THEN Msg('Compilation ended with errors in grammar tests.')
          ELSE IF NOT ll1 THEN Msg('Compilation ended with LL(1) errors.')
          ELSE Msg('Compilation completed. No errors detected.');
      END
    ELSE
      BEGIN
        Msg('listing'); PrintListing;
        IF CRTable.ddt['X'] THEN CRTable.XRef;
        Msg('*** errors detected ***');
      END;
  IF CRTable.ddt['G'] THEN CRTable.PrintGraph;
  IF CRTable.ddt['S'] THEN CRTable.PrintSymbolTable;
  Close(lst);
  Close(src);
END. (* -->Grammar *)
