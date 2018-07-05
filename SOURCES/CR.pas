(*
1990
	Original code in Oberon by Hanspeter Moessenboeck, ETH Zurich. Ported at ETH to Apple Modula-2 and thence to JPI-2 Modula-2.
1992
	JPI version of 27 January 1991 was then modified to make more portable by Terry Pat, January - October 1992.
	This is the IBM-PC MS-DOS Turbo Pascal version for generating Turbo Pascal programs based on the port first done by Pohlers Volker, October 1995.
2018.161
	FreeBSD fpc version
	options are prefexed with "-", "/" is not allowed anymore
	scanner.frm -> scanner.frame, parser.frm -> parser.frame, compiler.frm -> compiler.frame
	indentation by tabs, declarations on program level are not indented; no blanks between identifier and colon
	CR.atg led to cr.lst instead of CR.lst

Main Module of Coco/R

This is a compiler generator that produces a scanner and a parser from an attributed grammar, and optionally a complete small compiler.

Usage	CR {-options} GrammarName[.atg] {-options}

Input
	attributed grammar   input grammar
	scanner.frame          frame file
	parser.frame            frame file
	compiler.frame         frame file (optional)

Frame files must be in the same directory as the grammar, i.e. the atg file, or may be found on a path specified by the environment variable CRFRAMES.

Output
	<GrammarName>S.pas generated scanner
	<GrammarName>P.pas generated parser
	<GrammarName>.err error numbers and corresponding error messages
	<GrammarName>.lst source listing with error messages and trace output
Optionally
	<GrammarName>G.pas generated symbolic names [option N]
	<GrammarName>.pas generated compiler main module [option C]

Implementation restrictions
	1  too many nodes in graph (>1500)                 CRTable.NewNode
	2  too many symbols (>500)                         CRTable.NewSym, MovePragmas
	3  too many sets (>256 ANY-syms or SYNC syms)      CRTable.NewSet,
	4  too many character classes (>250)               CRTable.NewClass
	5  too many conditions in generated code (>100)    CRX.NewCondSet
	6  too many token names in "NAMES" (>100)          CRTable.NewName
	7  too many states in automata (>500)              CRA.NewState

Trace output
	To activate a trace switch, write "${letter}" in the input grammar, or invoke Coco/R with a second command line parameter.

	A  Print states of automaton.
	C  Generate compiler module <GrammerName>.pas.
	F  Print start symbols and followers of nonterminals.
	G  Print the top-down graph..
	I  Trace of start symbol set computation.
	L  Force a listing, otherwise a listing is only printed if errors occurred.
	N  Use default names for symbol value constants. This generates an extra module <grammar name>G, and corresponding import statements
		using constant names instead of numbers for symbols in parser and scanner.
		The constants are used unqualified and hence all needed constants have to be imported; so a complete import list for these constants is generated.
		There is no decision whether a constant is actually needed.
		The default conventions are (only terminals or pragmas can have names):
		single character  -->  <ASCII name (lowercase)>Sym, eg. "+"  -->  plusSym
		character string  -->  <string>Sym, eg. "PROGRAM"  -->  PROGRAMSym
		scanner token  -->  <token name>Sym, eg. ident  -->  identSym
	O  Trace of follow set computation (not yet implemented).
	P  Generate parser only
	S  Print the symbol list
	T  Suppress generation of units, i.e. check only the grammar
	X  Print a cross reference list
*)

PROGRAM CR;

USES CRS, (* lst, src, errors, directory, Error, CharAt *)
	CRP, (* Parse *)
	CRC, CRTable, CRA, CRX, FileIO;

CONST
	ATGExt = '.atg';
	LSTExt = '.lst';
	Version = '1.54 (for Pascal)';
	ReleaseDate = '2018.161';

VAR
	GrammarName, lstFileName : STRING;
	ll1 : BOOLEAN; (* TRUE, if grammar is LL(1) *)
	ok : BOOLEAN;  (* TRUE, if grammar tests ok so far *)
	P : INTEGER;   (* ParamCount *)

(* ------------------- Source Listing and Error handler -------------- *)

TYPE
	CHARSET = SET OF CHAR;
	Err = ^ErrDesc; ErrDesc = RECORD nr, line, col: INTEGER; next: Err END;

CONST
	TAB  = #09;
	_LF  = #10;
	_CR  = #13;
	_EF  = #0;
	LineEnds : CHARSET = [_CR, _LF, _EF];

VAR
	firstErr, lastErr: Err;
	Extra : INTEGER;

PROCEDURE StoreError(nr, line, col: INTEGER; pos: LONGINT);
	(* Store an error message for later printing *)
	VAR nextErr: Err;
BEGIN NEW(nextErr);
	nextErr^.nr := nr; nextErr^.line := line; nextErr^.col := col;
	nextErr^.next := NIL;
	IF firstErr = NIL
	THEN firstErr := nextErr
	ELSE lastErr^.next := nextErr;
	lastErr := nextErr;
	INC(errors)
END;

PROCEDURE GetLine (VAR pos  : LONGINT; VAR line : STRING; VAR eof: BOOLEAN);
	(* Read a source line. Return empty line if eof *)
	VAR ch: CHAR; i:  INTEGER;
BEGIN i := 1; eof := FALSE; ch := CharAt(pos); INC(pos);
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

	PROCEDURE Msg (s: STRING); BEGIN Write(lst, s) END;

	PROCEDURE Pointer;
		VAR i : INTEGER;
	BEGIN Write(lst, '*****  ');
		i := 0;
		WHILE i < col + Extra - 2 DO BEGIN
			IF line[i] = TAB THEN Write(lst, TAB) ELSE Write(lst, ' ');
			INC(i)
		END;
		Write(lst, '^ ')
	END;

BEGIN Pointer;
	CASE nr OF
	0 : Msg('EOF expected');
	1 : Msg('ident expected');
	2 : Msg('string expected');
	3 : Msg('badstring expected');
	4 : Msg('number expected');
	5 : Msg('"COMPILER" expected');
	6 : Msg('"USES" expected');
	7 : Msg('"," expected');
	8 : Msg('";" expected');
	9 : Msg('"PRODUCTIONS" expected');
	10 : Msg('"=" expected');
	11 : Msg('"." expected');
	12 : Msg('"END" expected');
	13 : Msg('"CHARACTERS" expected');
	14 : Msg('"TOKENS" expected');
	15 : Msg('"NAMES" expected');
	16 : Msg('"PRAGMAS" expected');
	17 : Msg('"COMMENTS" expected');
	18 : Msg('"FROM" expected');
	19 : Msg('"TO" expected');
	20 : Msg('"NESTED" expected');
	21 : Msg('"IGNORE" expected');
	22 : Msg('"CASE" expected');
	23 : Msg('"+" expected');
	24 : Msg('"-" expected');
	25 : Msg('".." expected');
	26 : Msg('"ANY" expected');
	27 : Msg('"CHR" expected');
	28 : Msg('"(" expected');
	29 : Msg('")" expected');
	30 : Msg('"|" expected');
	31 : Msg('"WEAK" expected');
	32 : Msg('"[" expected');
	33 : Msg('"]" expected');
	34 : Msg('"{" expected');
	35 : Msg('"}" expected');
	36 : Msg('"SYNC" expected');
	37 : Msg('"CONTEXT" expected');
	38 : Msg('"<" expected');
	39 : Msg('">" expected');
	40 : Msg('"<." expected');
	41 : Msg('".>" expected');
	42 : Msg('"(." expected');
	43 : Msg('".)" expected');
	44 : Msg('not expected');
	45 : Msg('invalid TokenFactor');
	46 : Msg('invalid Factor');
	47 : Msg('invalid Factor');
	48 : Msg('invalid Term');
	49 : Msg('invalid Symbol');
	50 : Msg('invalid SingleChar');
	51 : Msg('invalid SimSet');
	52 : Msg('invalid NameDecl');
	53 : Msg('this symbol not expected in TokenDecl');
	54 : Msg('invalid TokenDecl');
	55 : Msg('invalid Attribs');
	56 : Msg('invalid Declaration');
	57 : Msg('invalid Declaration');
	58 : Msg('invalid Declaration');
	59 : Msg('this symbol not expected in CR');
	60 : Msg('invalid CR');

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
	WriteLn(lst)
END;

PROCEDURE PrintListing;
	(* Print a source listing with error messages *)
	VAR nextErr:   Err; eof:       BOOLEAN; lnr, errC: INTEGER; srcPos:    LONGINT; line:      STRING;
BEGIN WriteLn(lst, 'Listing:'); WriteLn(lst);
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
	WriteLn(lst); WriteLn(lst); WriteLn(lst)
END;

PROCEDURE SetOption(s : STRING);
	(* Set compiler options *) 
	VAR i : INTEGER;
BEGIN
	FOR i := 2 TO Length(s) DO BEGIN
		s[i] := UpCase(s[i]);
		IF s[i] IN ['A' .. 'Z'] THEN CRTable.ddt[s[i]] := TRUE
	END
END;

PROCEDURE Msg (S : STRING); BEGIN WriteLn(S) END;

(* --------------------------- Help ------------------------------- *)

PROCEDURE Help;
BEGIN
	Msg('Usage: CR {-Options} [Grammar[.atg]] {-Options}');
	Msg('Example: CR -cs Test');
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
	Msg('compiler.frame, scanner.frame and parser.frame must be in the working directory or may be found on a path specified by the environment variable CRFRAMES');
END;

BEGIN firstErr := NIL; Extra := 1; P := 1;
	Write('Coco/R-Compiler-Compiler V'); WriteLn(Version);
	WriteLn('Turbo Pascal (TM) version by Terry Pat/Pohlers Volker ', ReleaseDate);
	GrammarName := ParamStr(1);
	IF (GrammarName = '?') OR (GrammarName = '-?') OR (GrammarName = '-h') THEN Help
	ELSE BEGIN
		WHILE (Length(GrammarName) > 0) AND (GrammarName[1] = '-') DO BEGIN (* accept options before filename *) 
			SetOption(GrammarName); INC(P); GrammarName := ParamStr(P)
		END;
		ok := GrammarName <> '';
		REPEAT
			IF NOT ok THEN BEGIN
				Write('Grammar[.atg] ? : ');
				ReadLn(GrammarName);
				IF GrammarName = '' THEN HALT
			END;
			FileIO.AppendExtension(GrammarName, ATGExt, GrammarName);
			Assign(src, GrammarName);
			{$I-} Reset(src, 1); ok := IOResult = 0; {$I+}
			IF NOT ok THEN WriteLn('"', GrammarName, '" not found.')
		UNTIL ok;
		INC(P); IF ParamStr(P) <> '' THEN SetOption(ParamStr(P));
		FileIO.ExtractDirectory(GrammarName, directory);
		FileIO.ChangeExtension(GrammarName, LSTExt, lstFileName);
		FileIO.Open(lst, lstFileName, TRUE);
		WriteLn(lst, 'Coco/R - Compiler-Compiler V', Version);
		WriteLn(lst, 'Turbo Pascal version by Pohlers Volker/Terry Pat ', ReleaseDate);
		WriteLn(lst, 'Source file: ', GrammarName);
		WriteLn(lst);
		WriteLn('parsing file ', GrammarName);
		CRS.Error := StoreError;
		CRP.Parse();
		IF errors = 0 THEN BEGIN
			Msg('testing grammar');
			WriteLn(lst, 'Grammar Tests:'); WriteLn(lst);
			CRTable.CompSymbolSets();
			CRTable.TestCompleteness(ok);
			IF ok THEN CRTable.TestIfAllNtReached(ok);
			IF ok THEN CRTable.FindCircularProductions(ok);
			IF ok THEN CRTable.TestIfNtToTerm(ok);
			IF ok THEN CRTable.LL1Test(ll1);
			WriteLn(lst);
			IF NOT ok OR NOT ll1 OR CRTable.ddt['L'] OR CRTable.ddt['X'] THEN BEGIN
				Msg('listing'); PrintListing;
				IF CRTable.ddt['X'] THEN CRTable.XRef()
			END;
			IF CRTable.ddt['N'] OR CRTable.symNames THEN BEGIN
				Msg('symbol name assignment');
				CRTable.AssignSymNames(CRTable.ddt['N'], CRTable.symNames)
			END;
			IF ok AND NOT CRTable.ddt['T'] THEN BEGIN
				Msg('generating parser');
				CRX.GenCompiler();
				IF CRTable.genScanner AND NOT CRTable.ddt['P'] THEN BEGIN
					Msg('generating scanner');
					CRA.WriteScanner(ok);
					IF CRTable.ddt['A'] THEN CRA.PrintStates()
				END;
				IF CRTable.ddt['C'] THEN BEGIN Msg('generating compiler'); CRC.WriteDriver() END;
				CRX.WriteStatistics()
			END;
			IF NOT ok THEN Msg('Compilation ended with errors in grammar tests.')
			ELSE IF NOT ll1 THEN Msg('Compilation ended with LL(1) errors.')
			ELSE Msg('Compilation completed. No errors detected.')
		END
		ELSE BEGIN
			Msg('listing'); PrintListing();
			IF CRTable.ddt['X'] THEN CRTable.XRef();
			Msg('*** errors detected ***')
		END;
		IF CRTable.ddt['G'] THEN CRTable.PrintGraph();
		IF CRTable.ddt['S'] THEN CRTable.PrintSymbolTable();
		Close(lst);
		Close(src)
	END
END. (* CR *)