UNIT CRP;
(* Parser generated by Coco/R (Pascal version) *)

INTERFACE

PROCEDURE Parse;

FUNCTION Successful : BOOLEAN;
(* Returns TRUE if no errors have been recorded while parsing *)

PROCEDURE SynError (errNo: INTEGER);
(* Report syntax error with specified errNo *)

PROCEDURE SemError (errNo: INTEGER);
(* Report semantic error with specified errNo *)

PROCEDURE LexString (VAR Lex : STRING);
(* Retrieves Lex as exact spelling of current token *)

PROCEDURE LexName (VAR Lex : STRING);
(* Retrieves Lex as name of current token (capitalized if IGNORE CASE) *)

PROCEDURE LookAheadString (VAR Lex : STRING);
(* Retrieves Lex as exact spelling of lookahead token *)

PROCEDURE LookAheadName (VAR Lex : STRING);
(* Retrieves Lex as name of lookahead token (capitalized if IGNORE CASE) *)

IMPLEMENTATION

USES CRTable, CRA, Sets, CRS;


CONST
  ident = 0; stringSym = 1;  (* symbol kind *)

PROCEDURE FixString (VAR name: STRING; len: INTEGER);
  VAR
    double, spaces: BOOLEAN;
    i: INTEGER;
  BEGIN
    IF len = 2 THEN BEGIN SemError(129); EXIT END;
    IF CRTable.ignoreCase THEN (* force uppercase *)
      FOR i := 2 TO len - 1 DO name[i] := UpCase(name[i]);
    double := FALSE; spaces := FALSE;
    FOR i := 2 TO len - 1 DO (* search for interior " or spaces *) BEGIN
      IF name[i] = '"' THEN double := TRUE;
      IF name[i] <= ' ' THEN spaces := TRUE;
    END;
    IF NOT double THEN (* force delimiters to be " quotes *) BEGIN
      name[1] := '"'; name[len] := '"'
    END;
    IF spaces THEN SemError(124);
  END;

PROCEDURE MatchLiteral (sp: INTEGER);
(* store string either as token or as literal *)
  VAR
    sn, sn1:  CRTable.SymbolNode;
    matchedSp: INTEGER;
  BEGIN
    CRTable.GetSym(sp, sn);
    CRA.MatchDFA(sn.name, sp, matchedSp);
    IF matchedSp <> CRTable.noSym
      THEN
        BEGIN
          CRTable.GetSym(matchedSp, sn1);
          sn1.struct := CRTable.classLitToken;
          CRTable.PutSym(matchedSp, sn1);
          sn.struct := CRTable.litToken
        END
      ELSE sn.struct := CRTable.classToken;
    CRTable.PutSym(sp, sn)
  END;

PROCEDURE SetCtx (gp: INTEGER);
(* set transition code to CRTable.contextTrans *)
  VAR
    gn: CRTable.GraphNode;
  BEGIN
    WHILE gp > 0 DO BEGIN
      CRTable.GetNode(gp, gn);
      IF (gn.typ = CRTable.chart) OR (gn.typ = CRTable.class)
        THEN BEGIN gn.p2 := CRTable.contextTrans; CRTable.PutNode(gp, gn) END
        ELSE IF (gn.typ = CRTable.opt) OR (gn.typ = CRTable.iter) THEN SetCtx(gn.p1)
        ELSE IF gn.typ = CRTable.alt THEN BEGIN SetCtx(gn.p1); SetCtx(gn.p2) END;
      gp := gn.next
    END
  END;

PROCEDURE SetOption (s: STRING);
  VAR
    i: INTEGER;
  BEGIN
    FOR i := 1 TO Length(s) DO
      BEGIN
        s[i] := UpCase(s[i]);
        IF s[i] IN ['A' .. 'Z'] THEN CRTable.ddt[s[i]] := TRUE;
      END;
  END;

(*----------------------------------------------------------------------------*)



CONST
  maxT = 44;
  maxP = 45;
  minErrDist  =  2;  (* minimal distance (good tokens) between two errors *)
  setsize     = 16;  (* sets are stored in 16 bits *)

TYPE
  BITSET = SET OF 0 .. 15;
  SymbolSet = ARRAY [0 .. maxT DIV setsize] OF BITSET;

VAR
  symSet:  ARRAY [0 ..  18] OF SymbolSet; (*symSet[0] = allSyncSyms*)
  errDist: INTEGER;   (* number of symbols recognized since last error *)
  sym:     INTEGER;   (* current input symbol *)

PROCEDURE  SemError (errNo: INTEGER);
  BEGIN
    IF errDist >= minErrDist THEN BEGIN
      CRS.Error(errNo, CRS.line, CRS.col, CRS.pos);
    END;
    errDist := 0;
  END;

PROCEDURE  SynError (errNo: INTEGER);
  BEGIN
    IF errDist >= minErrDist THEN BEGIN
      CRS.Error(errNo, CRS.nextLine, CRS.nextCol, CRS.nextPos);
    END;
    errDist := 0;
  END;

PROCEDURE  Get;
  VAR
    s: STRING;
  BEGIN
    REPEAT
      CRS.Get(sym);
      IF sym <= maxT THEN
        INC(errDist)
      ELSE BEGIN
        CASE sym OF
          45: BEGIN CRS.GetName(CRS.nextPos, CRS.nextLen, s); SetOption(s); END;
        END;
        CRS.nextPos := CRS.pos;
        CRS.nextCol := CRS.col;
        CRS.nextLine := CRS.line;
        CRS.nextLen := CRS.len;
      END;
    UNTIL sym <= maxT
  END;

FUNCTION  _In (VAR s: SymbolSet; x: INTEGER): BOOLEAN;
  BEGIN
    _In := x MOD setsize IN s[x DIV setsize];
  END;

PROCEDURE  Expect (n: INTEGER);
  BEGIN
    IF sym = n THEN Get ELSE SynError(n);
  END;

PROCEDURE  ExpectWeak (n, follow: INTEGER);
  BEGIN
    IF sym = n
    THEN Get
    ELSE BEGIN
      SynError(n); WHILE NOT _In(symSet[follow], sym) DO Get;
    END
  END;

FUNCTION  WeakSeparator (n, syFol, repFol: INTEGER): BOOLEAN;
  VAR
    s: SymbolSet;
    i: INTEGER;
  BEGIN
    IF sym = n
    THEN BEGIN Get; WeakSeparator := TRUE; EXIT; END
    ELSE IF _In(symSet[repFol], sym) THEN BEGIN WeakSeparator := FALSE; exit END
    ELSE BEGIN
      i := 0;
      WHILE i <= maxT DIV setsize DO BEGIN
        s[i] := symSet[0, i] + symSet[syFol, i] + symSet[repFol, i]; INC(i)
      END;
      SynError(n); WHILE NOT _In(s, sym) DO Get;
      WeakSeparator := _In(symSet[syFol], sym)
    END
  END;

PROCEDURE LexName (VAR Lex : STRING);
  BEGIN
    CRS.GetName(CRS.pos, CRS.len, Lex)
  END;

PROCEDURE LexString (VAR Lex : STRING);
  BEGIN
    CRS.GetString(CRS.pos, CRS.len, Lex)
  END;

PROCEDURE LookAheadName (VAR Lex : STRING);
  BEGIN
    CRS.GetName(CRS.nextPos, CRS.nextLen, Lex)
  END;

PROCEDURE LookAheadString (VAR Lex : STRING);
  BEGIN
    CRS.GetString(CRS.nextPos, CRS.nextLen, Lex)
  END;

FUNCTION Successful : BOOLEAN;
  BEGIN
    Successful := CRS.errors = 0
  END;

PROCEDURE _TokenFactor (VAR gL, gR: INTEGER); FORWARD;
PROCEDURE _TokenTerm (VAR gL, gR: INTEGER); FORWARD;
PROCEDURE _Factor (VAR gL, gR: INTEGER); FORWARD;
PROCEDURE _Term (VAR gL, gR: INTEGER); FORWARD;
PROCEDURE _Symbol (VAR name: CRTable.Name; VAR kind: INTEGER); FORWARD;
PROCEDURE _SingleChar (VAR n: INTEGER); FORWARD;
PROCEDURE _SimSet (VAR oneSet: CRTable.CRTSet); FORWARD;
PROCEDURE _Set (VAR oneSet: CRTable.CRTSet); FORWARD;
PROCEDURE _TokenExpr (VAR gL, gR: INTEGER); FORWARD;
PROCEDURE _NameDecl; FORWARD;
PROCEDURE _TokenDecl (typ: INTEGER); FORWARD;
PROCEDURE _SetDecl; FORWARD;
PROCEDURE _Expression (VAR gL, gR: INTEGER); FORWARD;
PROCEDURE _SemText (VAR semPos: CRTable.Position); FORWARD;
PROCEDURE _Attribs (VAR attrPos: CRTable.Position); FORWARD;
PROCEDURE _Declaration (VAR startedDFA: BOOLEAN); FORWARD;
PROCEDURE _Ident (VAR name: CRTable.Name); FORWARD;
PROCEDURE _CR; FORWARD;

PROCEDURE _TokenFactor (VAR gL, gR: INTEGER);
  VAR
    kind, c: INTEGER;
    oneSet:  CRTable.CRTSet;
    name:    CRTable.Name;
  BEGIN
    gL :=0; gR := 0;
    IF (sym = 1) OR (sym = 2) THEN BEGIN
      _Symbol(name, kind);
      IF kind = ident
        THEN
          BEGIN
            c := CRTable.ClassWithName(name);
            IF c < 0 THEN BEGIN
              SemError(115);
              Sets.Clear(oneSet); c := CRTable.NewClass(name, oneSet)
            END;
            gL := CRTable.NewNode(CRTable.class, c, 0); gR := gL
          END
        ELSE (* string *)
          CRTable.StrToGraph(name, gL, gR);
    END ELSE IF (sym = 28) THEN BEGIN
      Get;
      _TokenExpr(gL, gR);
      Expect(29);
    END ELSE IF (sym = 32) THEN BEGIN
      Get;
      _TokenExpr(gL, gR);
      Expect(33);
      CRTable.MakeOption(gL, gR);
    END ELSE IF (sym = 34) THEN BEGIN
      Get;
      _TokenExpr(gL, gR);
      Expect(35);
      CRTable.MakeIteration(gL, gR);
    END ELSE BEGIN SynError(45);
    END;
  END;

PROCEDURE _TokenTerm (VAR gL, gR: INTEGER);
  VAR
    gL2, gR2: INTEGER;
  BEGIN
    _TokenFactor(gL, gR);
    WHILE (sym = 1) OR (sym = 2) OR (sym = 28) OR (sym = 32) OR (sym = 34) DO BEGIN
      _TokenFactor(gL2, gR2);
      CRTable.ConcatSeq(gL, gR, gL2, gR2);
    END;
    IF (sym = 37) THEN BEGIN
      Get;
      Expect(28);
      _TokenExpr(gL2, gR2);
      SetCtx(gL2); CRTable.ConcatSeq(gL, gR, gL2, gR2);
      Expect(29);
    END;
  END;

PROCEDURE _Factor (VAR gL, gR: INTEGER);
  VAR
    sp, kind:    INTEGER;
    name:        CRTable.Name;
    gn:          CRTable.GraphNode;
    sn:          CRTable.SymbolNode;
    oneSet:      CRTable.CRTSet;
    undef, weak: BOOLEAN;
    pos:         CRTable.Position;
  BEGIN
    gL :=0; gR := 0; weak := FALSE;
    CASE sym OF
      1, 2, 31 : BEGIN
        IF (sym = 31) THEN BEGIN
          Get;
          weak := TRUE;
        END;
        _Symbol(name, kind);
        sp := CRTable.FindSym(name); undef := sp = CRTable.noSym;
        IF undef THEN
          IF kind = ident
            THEN  (* forward nt *)
              sp := CRTable.NewSym(CRTable.nt, name, 0)
            ELSE IF CRTable.genScanner THEN
              BEGIN
                sp := CRTable.NewSym(CRTable.t, name, CRS.line);
                MatchLiteral(sp)
              END
            ELSE BEGIN (* undefined string in production *)
              SemError(106); sp := 0
            END;
        CRTable.GetSym(sp, sn);
        IF (sn.typ <> CRTable.t) AND (sn.typ <> CRTable.nt) THEN SemError(104);
        IF weak THEN
          IF sn.typ = CRTable.t
            THEN sn.typ := CRTable.wt
            ELSE SemError(123);
        gL := CRTable.NewNode(sn.typ, sp, CRS.line); gR := gL;
        IF (sym = 38) OR (sym = 40) THEN BEGIN
          _Attribs(pos);
          CRTable.GetNode(gL, gn); gn.pos := pos;
          CRTable.PutNode(gL, gn);
          CRTable.GetSym(sp, sn);
          IF sn.typ <> CRTable.nt THEN SemError(103);
          IF undef THEN
            BEGIN sn.attrPos := pos; CRTable.PutSym(sp, sn) END
            ELSE IF sn.attrPos.beg < 0 THEN SemError(105);
        END ELSE IF _In(symSet[1], sym) THEN BEGIN
          CRTable.GetSym(sp, sn);
          IF sn.attrPos.beg >= 0 THEN SemError(105);
        END ELSE BEGIN SynError(46);
        END;
        END;
      28 : BEGIN
        Get;
        _Expression(gL, gR);
        Expect(29);
        END;
      32 : BEGIN
        Get;
        _Expression(gL, gR);
        Expect(33);
        CRTable.MakeOption(gL, gR);
        END;
      34 : BEGIN
        Get;
        _Expression(gL, gR);
        Expect(35);
        CRTable.MakeIteration(gL, gR);
        END;
      42 : BEGIN
        _SemText(pos);
        gL := CRTable.NewNode(CRTable.sem, 0, 0); gR := gL;
        CRTable.GetNode(gL, gn);
        gn.pos := pos;
        CRTable.PutNode(gL, gn);
        END;
      26 : BEGIN
        Get;
        Sets.Fill(oneSet); Sets.Excl(oneSet, CRTable.eofSy);
        gL := CRTable.NewNode(CRTable.any, CRTable.NewSet(oneSet), 0); gR := gL;
        END;
      36 : BEGIN
        Get;
        gL := CRTable.NewNode(CRTable.sync, 0, 0); gR := gL;
        END;
    ELSE BEGIN SynError(47);
        END;
    END;
  END;

PROCEDURE _Term (VAR gL, gR: INTEGER);
  VAR
    gL2, gR2: INTEGER;
  BEGIN
    gL := 0; gR := 0;
    IF _In(symSet[2], sym) THEN BEGIN
      _Factor(gL, gR);
      WHILE _In(symSet[2], sym) DO BEGIN
        _Factor(gL2, gR2);
        CRTable.ConcatSeq(gL, gR, gL2, gR2);
      END;
    END ELSE IF (sym = 11) OR (sym = 29) OR (sym = 30) OR (sym = 33) OR (sym = 35) THEN BEGIN
      gL := CRTable.NewNode(CRTable.eps, 0, 0); gR := gL;
    END ELSE BEGIN SynError(48);
    END;
  END;

PROCEDURE _Symbol (VAR name: CRTable.Name; VAR kind: INTEGER);
  VAR
    myName: STRING;
  BEGIN
    IF (sym = 1) THEN BEGIN
      _Ident(name);
      kind := ident;
    END ELSE IF (sym = 2) THEN BEGIN
      Get;
      CRS.GetName(CRS.pos, CRS.len, myName);
      kind := stringSym;
      FixString(myName, CRS.len);
      name := myName;
    END ELSE BEGIN SynError(49);
    END;
  END;

PROCEDURE _SingleChar (VAR n: INTEGER);
  VAR
    dummy: INTEGER;
    s: STRING;
  BEGIN
    Expect(27);
    Expect(28);
    IF (sym = 4) THEN BEGIN
      Get;
      CRS.GetName(CRS.pos, CRS.len, s);
      Val(s, n, dummy);
      IF n > 255 THEN BEGIN SemError(118); n := n MOD 256 END;
      IF CRTable.ignoreCase THEN n := ORD(UpCase(CHR(n)));
    END ELSE IF (sym = 2) THEN BEGIN
      Get;
      CRS.GetName(CRS.pos, CRS.len, s);
      IF CRS.len <> 3 THEN SemError(118);
      IF CRTable.ignoreCase THEN s[2] := UpCase(s[2]);
      n := ORD(s[2]);
    END ELSE BEGIN SynError(50);
    END;
    Expect(29);
  END;

PROCEDURE _SimSet (VAR oneSet: CRTable.CRTSet);
  VAR
    i, n1, n2: INTEGER;
    name:      CRTable.Name;
    s:         STRING;
  BEGIN
    Sets.Clear(oneSet);
    IF (sym = 1) THEN BEGIN
      _Ident(name);
      i := CRTable.ClassWithName(name);
      IF i < 0
        THEN SemError(115)
        ELSE CRTable.GetClass(i, oneSet);
    END ELSE IF (sym = 2) THEN BEGIN
      Get;
      CRS.GetName(CRS.pos, CRS.len, s);
      i := 2;
      WHILE s[i] <> s[1] DO BEGIN
        IF CRTable.ignoreCase THEN s[i] := UpCase(s[i]);
        Sets.Incl(oneSet, ORD(s[i])); INC(i)
      END;
    END ELSE IF (sym = 27) THEN BEGIN
      _SingleChar(n1);
      Sets.Incl(oneSet, n1);
      IF (sym = 25) THEN BEGIN
        Get;
        _SingleChar(n2);
        FOR i := n1 TO n2 DO Sets.Incl(oneSet, i);
      END;
    END ELSE IF (sym = 26) THEN BEGIN
      Get;
      FOR i := 0 TO 255 DO Sets.Incl(oneSet, i);
    END ELSE BEGIN SynError(51);
    END;
  END;

PROCEDURE _Set (VAR oneSet: CRTable.CRTSet);
  VAR
    set2: CRTable.CRTSet;
  BEGIN
    _SimSet(oneSet);
    WHILE (sym = 23) OR (sym = 24) DO BEGIN
      IF (sym = 23) THEN BEGIN
        Get;
        _SimSet(set2);
        Sets.Unite(oneSet, set2);
      END ELSE BEGIN
        Get;
        _SimSet(set2);
        Sets.Differ(oneSet, set2);
      END;
    END;
  END;

PROCEDURE _TokenExpr (VAR gL, gR: INTEGER);
  VAR
    gL2, gR2: INTEGER;
    first:    BOOLEAN;
  BEGIN
    _TokenTerm(gL, gR);
    first := TRUE;
    WHILE WeakSeparator(30, 3, 4) DO BEGIN
      _TokenTerm(gL2, gR2);
      IF first THEN BEGIN
        CRTable.MakeFirstAlt(gL, gR); first := FALSE
      END;
      CRTable.ConcatAlt(gL, gR, gL2, gR2);
    END;
  END;

PROCEDURE _NameDecl;
  VAR
    name: CRTable.Name;
    str: STRING;
  BEGIN
    _Ident(name);
    Expect(10);
    IF (sym = 1) THEN BEGIN
      Get;
      CRS.GetName(CRS.pos, CRS.len, str);
    END ELSE IF (sym = 2) THEN BEGIN
      Get;
      CRS.GetName(CRS.pos, CRS.len, str);
      FixString(str, CRS.len);
    END ELSE BEGIN SynError(52);
    END;
    CRTable.NewName(name, str);
    Expect(11);
  END;

PROCEDURE _TokenDecl (typ: INTEGER);
  VAR
    kind:       INTEGER;
    name:       CRTable.Name;
    pos:        CRTable.Position;
    sp, gL, gR: INTEGER;
    sn:         CRTable.SymbolNode;
  BEGIN
    _Symbol(name, kind);
    IF CRTable.FindSym(name) <> CRTable.noSym
      THEN SemError(107)
      ELSE BEGIN
        sp := CRTable.NewSym(typ, name, CRS.line);
        CRTable.GetSym(sp, sn); sn.struct := CRTable.classToken;
        CRTable.PutSym(sp, sn)
      END;
    WHILE NOT ( _In(symSet[5], sym)) DO BEGIN SynError(53); Get END;
    IF (sym = 10) THEN BEGIN
      Get;
      _TokenExpr(gL, gR);
      IF kind <> ident THEN SemError(113);
      CRTable.CompleteGraph(gR);
      CRA.ConvertToStates(gL, sp);
      Expect(11);
    END ELSE IF _In(symSet[6], sym) THEN BEGIN
      IF kind = ident
        THEN CRTable.genScanner := FALSE
        ELSE MatchLiteral(sp);
    END ELSE BEGIN SynError(54);
    END;
    IF (sym = 42) THEN BEGIN
      _SemText(pos);
      IF typ = CRTable.t THEN SemError(114);
      CRTable.GetSym(sp, sn); sn.semPos := pos;
      CRTable.PutSym(sp, sn);
    END;
  END;

PROCEDURE _SetDecl;
  VAR
    c:    INTEGER;
    oneSet:  CRTable.CRTSet;
    name: CRTable.Name;
  BEGIN
    _Ident(name);
    c := CRTable.ClassWithName(name);
    IF c >= 0 THEN SemError(107);
    Expect(10);
    _Set(oneSet);
    IF Sets.Empty(oneSet) THEN SemError(101);
    c := CRTable.NewClass(name, oneSet);
    Expect(11);
  END;

PROCEDURE _Expression (VAR gL, gR: INTEGER);
  VAR
    gL2, gR2: INTEGER;
    first:    BOOLEAN;
  BEGIN
    _Term(gL, gR);
    first := TRUE;
    WHILE WeakSeparator(30, 1, 7) DO BEGIN
      _Term(gL2, gR2);
      IF first THEN BEGIN
        CRTable.MakeFirstAlt(gL, gR); first := FALSE
      END;
      CRTable.ConcatAlt(gL, gR, gL2, gR2);
    END;
  END;

PROCEDURE _SemText (VAR semPos: CRTable.Position);
  BEGIN
    Expect(42);
    semPos.beg := CRS.pos + 2; semPos.col := CRS.col + 2;
    WHILE _In(symSet[8], sym) DO BEGIN
      IF _In(symSet[9], sym) THEN BEGIN
        Get;
      END ELSE IF (sym = 3) THEN BEGIN
        Get;
        SemError(102);
      END ELSE BEGIN
        Get;
        SemError(109);
      END;
    END;
    Expect(43);
    semPos.len := (CRS.pos - semPos.beg);
  END;

PROCEDURE _Attribs (VAR attrPos: CRTable.Position);
  BEGIN
    IF (sym = 38) THEN BEGIN
      Get;
      attrPos.beg := CRS.pos + 1; attrPos.col := CRS.col + 1;
      WHILE _In(symSet[10], sym) DO BEGIN
        IF _In(symSet[11], sym) THEN BEGIN
          Get;
        END ELSE BEGIN
          Get;
          SemError(102);
        END;
      END;
      Expect(39);
      attrPos.len := (CRS.pos - attrPos.beg);
    END ELSE IF (sym = 40) THEN BEGIN
      Get;
      attrPos.beg := CRS.pos + 2; attrPos.col := CRS.col + 2;
      WHILE _In(symSet[12], sym) DO BEGIN
        IF _In(symSet[13], sym) THEN BEGIN
          Get;
        END ELSE BEGIN
          Get;
          SemError(102);
        END;
      END;
      Expect(41);
      attrPos.len := (CRS.pos - attrPos.beg);
    END ELSE BEGIN SynError(55);
    END;
  END;

PROCEDURE _Declaration (VAR startedDFA: BOOLEAN);
  VAR
    gL1, gR1, gL2, gR2: INTEGER;
    nested:             BOOLEAN;
  BEGIN
    CASE sym OF
      13 : BEGIN
        Get;
        WHILE (sym = 1) DO BEGIN
          _SetDecl;
        END;
        END;
      14 : BEGIN
        Get;
        WHILE (sym = 1) OR (sym = 2) DO BEGIN
          _TokenDecl(CRTable.t);
        END;
        END;
      15 : BEGIN
        Get;
        WHILE (sym = 1) DO BEGIN
          _NameDecl;
        END;
        END;
      16 : BEGIN
        Get;
        WHILE (sym = 1) OR (sym = 2) DO BEGIN
          _TokenDecl(CRTable.pr);
        END;
        END;
      17 : BEGIN
        Get;
        Expect(18);
        _TokenExpr(gL1, gR1);
        Expect(19);
        _TokenExpr(gL2, gR2);
        IF (sym = 20) THEN BEGIN
          Get;
          nested := TRUE;
        END ELSE IF _In(symSet[14], sym) THEN BEGIN
          nested := FALSE;
        END ELSE BEGIN SynError(56);
        END;
        CRA.NewComment(gL1, gL2, nested);
        END;
      21 : BEGIN
        Get;
        IF (sym = 22) THEN BEGIN
          Get;
          IF startedDFA THEN SemError(130);
          CRTable.ignoreCase := TRUE;
        END ELSE IF (sym = 1) OR (sym = 2) OR (sym = 26) OR (sym = 27) THEN BEGIN
          _Set(CRTable.ignored);
          IF Sets.IsIn(CRTable.ignored, 0) THEN SemError(119);
        END ELSE BEGIN SynError(57);
        END;
        END;
    ELSE BEGIN SynError(58);
        END;
    END;
    startedDFA := TRUE;
  END;

PROCEDURE _Ident (VAR name: CRTable.Name);
  VAR
    str: STRING;
  BEGIN
    Expect(1);
    CRS.GetName(CRS.pos, CRS.len, str);
    name := str;
  END;

PROCEDURE _CR;
  VAR
    startedDFA, ok, undef, hasAttrs: BOOLEAN; gR, gramLine, sp: INTEGER;
    name, gramName: CRTable.Name; sn: CRTable.SymbolNode;
  BEGIN
    Expect(5);
    gramLine := CRS.line;
    IF CRTable.NewSym(CRTable.t, 'EOF', 0) = 0 THEN;
    CRTable.genScanner := TRUE; CRTable.ignoreCase := FALSE;
    Sets.Clear(CRTable.ignored);
    startedDFA := FALSE;;
    _Ident(gramName);
    IF (sym = 6) THEN BEGIN
      Get;
      CRTable.useDeclPos.beg := CRS.nextPos;
      CRTable.hasUses := TRUE;
      Expect(1);
      WHILE (sym = 7) DO BEGIN
        Get;
        Expect(1);
      END;
      CRTable.useDeclPos.len := CRS.nextPos - CRTable.useDeclPos.beg;
      CRTable.useDeclPos.col := 0;
      Expect(8);
    END;
    CRTable.semDeclPos.beg := CRS.nextPos;
    WHILE _In(symSet[15], sym) DO BEGIN
      Get;
    END;
    CRTable.semDeclPos.len := CRS.nextPos - CRTable.semDeclPos.beg;
    CRTable.semDeclPos.col := 0;
    WHILE _In(symSet[16], sym) DO BEGIN
      _Declaration(startedDFA);
    END;
    WHILE NOT ( (sym = 0) OR (sym = 9)) DO BEGIN SynError(59); Get END;
    Expect(9);
    ok := Successful;
    IF ok AND CRTable.genScanner THEN CRA.MakeDeterministic(ok);
    IF NOT ok THEN SemError(127);
    CRTable.nNodes := 0;
    WHILE (sym = 1) DO BEGIN
      _Ident(name);
      sp := CRTable.FindSym(name); undef := sp = CRTable.noSym;
      IF undef
        THEN BEGIN
            sp := CRTable.NewSym(CRTable.nt, name, CRS.line);
            CRTable.GetSym(sp, sn)
          END
        ELSE BEGIN
          CRTable.GetSym(sp, sn);
          IF sn.typ = CRTable.nt
            THEN
              BEGIN IF sn.struct > 0 THEN SemError(107) END
            ELSE SemError(108);
          sn.line := CRS.line
        END;
      hasAttrs := sn.attrPos.beg >= 0;
      IF (sym = 38) OR (sym = 40) THEN BEGIN
        _Attribs(sn.attrPos);
        IF NOT undef AND NOT hasAttrs THEN SemError(105);
        CRTable.PutSym(sp, sn);
      END ELSE IF (sym = 10) OR (sym = 42) THEN BEGIN
        IF NOT undef AND hasAttrs THEN SemError(105);
      END ELSE BEGIN SynError(60);
      END;
      IF (sym = 42) THEN BEGIN
        _SemText(sn.semPos);
      END;
      ExpectWeak(10, 17);
      _Expression(sn.struct, gR);
      CRTable.CompleteGraph(gR); CRTable.PutSym(sp, sn);
      ExpectWeak(11, 18);
    END;
    Expect(12);
    _Ident(name);
    sp := CRTable.FindSym(gramName);
    IF sp = CRTable.noSym THEN SemError(111)
    ELSE BEGIN
      CRTable.GetSym(sp, sn);
      IF sn.attrPos.beg >= 0 THEN SemError(112);
      CRTable.root := CRTable.NewNode(CRTable.nt, sp, gramLine);
    END;
    IF name <> gramName THEN SemError(117);
    Expect(11);
    IF CRTable.NewSym(CRTable.t, 'not', 0) = 0 THEN;
  END;



PROCEDURE  Parse;
  BEGIN
    _Reset; Get;
    _CR;

  END;

BEGIN
  errDist := minErrDist;
  symSet[ 0, 0] := [0, 1, 2, 9, 10, 13, 14, 15];
  symSet[ 0, 1] := [0, 1, 5];
  symSet[ 0, 2] := [10];
  symSet[ 1, 0] := [1, 2, 11];
  symSet[ 1, 1] := [10, 12, 13, 14, 15];
  symSet[ 1, 2] := [0, 1, 2, 3, 4, 10];
  symSet[ 2, 0] := [1, 2];
  symSet[ 2, 1] := [10, 12, 15];
  symSet[ 2, 2] := [0, 2, 4, 10];
  symSet[ 3, 0] := [1, 2];
  symSet[ 3, 1] := [12];
  symSet[ 3, 2] := [0, 2];
  symSet[ 4, 0] := [9, 11, 13, 14, 15];
  symSet[ 4, 1] := [0, 1, 3, 4, 5, 13];
  symSet[ 4, 2] := [1, 3];
  symSet[ 5, 0] := [0, 1, 2, 9, 10, 13, 14, 15];
  symSet[ 5, 1] := [0, 1, 5];
  symSet[ 5, 2] := [10];
  symSet[ 6, 0] := [1, 2, 9, 13, 14, 15];
  symSet[ 6, 1] := [0, 1, 5];
  symSet[ 6, 2] := [10];
  symSet[ 7, 0] := [11];
  symSet[ 7, 1] := [13];
  symSet[ 7, 2] := [1, 3];
  symSet[ 8, 0] := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[ 8, 1] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[ 8, 2] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12];
  symSet[ 9, 0] := [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[ 9, 1] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[ 9, 2] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12];
  symSet[10, 0] := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[10, 1] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[10, 2] := [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12];
  symSet[11, 0] := [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[11, 1] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[11, 2] := [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12];
  symSet[12, 0] := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[12, 1] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[12, 2] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12];
  symSet[13, 0] := [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[13, 1] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[13, 2] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12];
  symSet[14, 0] := [9, 13, 14, 15];
  symSet[14, 1] := [0, 1, 5];
  symSet[14, 2] := [];
  symSet[15, 0] := [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12];
  symSet[15, 1] := [2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  symSet[15, 2] := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  symSet[16, 0] := [13, 14, 15];
  symSet[16, 1] := [0, 1, 5];
  symSet[16, 2] := [];
  symSet[17, 0] := [0, 1, 2, 9, 10, 11, 13, 14, 15];
  symSet[17, 1] := [0, 1, 5, 10, 12, 14, 15];
  symSet[17, 2] := [0, 2, 4, 10];
  symSet[18, 0] := [0, 1, 2, 9, 10, 12, 13, 14, 15];
  symSet[18, 1] := [0, 1, 5];
  symSet[18, 2] := [10];
END. (* CRP *)