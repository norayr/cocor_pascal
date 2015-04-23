UNIT TC;

INTERFACE

CONST
  ADD = 0; SUB = 1; MUL = 2; DIVI = 3; EQUc = 4; LSSc = 5; GTRc = 6; (*opcodes*)
  LOAD = 7; LIT = 8; STO = 9; CALL = 10; RET = 11; RES = 12;
  JMP = 13; FJMP = 14; HALTc = 15; NEG = 16; READc = 17; WRITEc = 18;

VAR
  progStart: INTEGER;     (*address of first instruction of main program*)
  pc:        INTEGER;     (*program counter*)

PROCEDURE Emit (op: INTEGER);

PROCEDURE Emit2 (op, val: INTEGER);

PROCEDURE Emit3 (op, level, val: INTEGER);

PROCEDURE Fixup (adr: INTEGER);

PROCEDURE Interpret;

IMPLEMENTATION

USES TasteP;

CONST
  MemSize = 15000;

VAR
  code: ARRAY [0 .. MemSize] OF Byte;
  GeneratingCode : BOOLEAN;

PROCEDURE Emit (op: INTEGER);
  BEGIN
    IF GeneratingCode THEN
      IF pc >= MemSize - 4
        THEN BEGIN TasteP.SemError(125); GeneratingCode := FALSE END
        ELSE BEGIN code[pc] := op; INC(pc) END
  END;

PROCEDURE Emit2 (op, val: INTEGER);
  BEGIN
    IF GeneratingCode THEN
      BEGIN
        Emit(op);
        code[pc] := val DIV 256; code[pc+1] := val MOD 256;
        INC(pc, 2)
      END
  END;

PROCEDURE Emit3 (op, level, val: INTEGER);
  BEGIN
    IF GeneratingCode THEN
      BEGIN
        Emit(op); code[pc] := level;
        code[pc+1] := val DIV 256; code[pc+2] := val MOD 256;
        INC(pc, 3)
      END
  END;

PROCEDURE Fixup (adr: INTEGER);
  BEGIN
    IF GeneratingCode THEN
      BEGIN
        code[adr] := pc DIV 256; code[adr+1] := pc MOD 256
      END
  END;

PROCEDURE Interpret;
  VAR
    stack:     ARRAY [0 .. 1000] OF INTEGER;
    top:       INTEGER;
    base:      INTEGER;
    val,a,lev: INTEGER;
    ch:        Byte;
    HaltCode:  BOOLEAN;
    i1, i2:    INTEGER;

  FUNCTION Next: INTEGER;
    BEGIN
      INC(pc);
      Next := code[pc-1]
    END;

  FUNCTION Next2: INTEGER;
    VAR
      x, y: WORD;
    BEGIN
      x := code[pc]; y := code[pc+1]; INC(pc, 2);
      Next2 := x*256 + y
    END;

  PROCEDURE Push(val:INTEGER);
    BEGIN
      stack[top] := val; INC(top)
    END;

  FUNCTION Pop: INTEGER;
    BEGIN
      DEC(top);
      Pop := stack[top]
    END;

  FUNCTION Up (level: INTEGER): INTEGER;
    VAR
      b: INTEGER;
    BEGIN
      b := base; WHILE level > 0 DO BEGIN b := stack[b]; DEC(level) END;
      Up := b
    END;

  BEGIN
    WriteLn('Interpreting');
    pc := progStart; base := 0; top := 3; HaltCode := FALSE;
    REPEAT
      CASE Next OF
        LOAD:  BEGIN lev := Next; a := Next2; Push(stack[Up(lev) + a]) END;
        LIT:   Push(Next2);
        STO:   BEGIN lev := Next; a := Next2; stack[Up(lev) + a] := Pop END;
        ADD:   BEGIN val := Pop; Push(Pop + val); END;
        SUB:   BEGIN val := Pop; Push(Pop - val); END;
        DIVI:  BEGIN val := Pop; Push(Pop DIV val); END;
        MUL:   BEGIN val := Pop; Push(Pop * val); END;
        EQUc:  BEGIN val := Pop; IF Pop = val THEN Push(1) ELSE PUSH(0) END;
        LSSc:  BEGIN val := Pop; IF Pop < val THEN Push(1) ELSE PUSH(0) END;
        GTRc:  BEGIN val := Pop; IF Pop > val THEN Push(1) ELSE PUSH(0) END;
        CALL:  BEGIN Push(Up(Next)); Push(base); Push(pc+2);
               pc := Next2; base := top - 3; END;
        RET:   BEGIN top := base; base := stack[top+1]; pc := stack[top+2] END;
        RES:   INC(top, Next2);
        JMP:   pc := Next2;
        FJMP:  BEGIN a := Next2; IF Pop = 0 THEN pc := a; END;
        HALTc: HaltCode := TRUE;
        NEG:   Push(-Pop);
        READc: BEGIN lev := Next; a := Next2;
               Write('? '); ReadLn(val);
               stack[Up(lev) + a] := val; END;
        WRITEc:WriteLn(Pop:6);
      ELSE BEGIN WriteLn('Unknown code at pos ', pc-1); HALT; END;
      END
    UNTIL HaltCode = TRUE;
  END;

BEGIN
  pc := 1
END.
