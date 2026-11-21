Info taken from [here](https://www.oxyron.de/html/opcodes02.html).
Better info [here](https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes)

## What they do

`SLO` {adr}:={adr}*2; A:=A or {adr}
  - ASL then ORA

`RLA` {adr}:={adr}rol; A:=A and {adr}
  - ROL then AND

`SRE` {adr}:={adr}/2; A:=A exor {adr}
  - LSR then EOR

`RRA` {adr}:={adr}ror; A:=A adc {adr}
  - ROR then ADC

`SAX` {adr}:=A&X

`LAX`	A,X:={adr}

`DCP` {adr}:={adr}-1; A-{adr}
  - DEC then CMP

`ISC` {adr}:={adr}+1; A:=A-{adr}
  - INC then SBC

`ANC` A:=A&#{imm}

`ALR` A:=(A&#{imm})/2
  - AND then LSR

`ARR` A:=(A&#{imm})/2
  - AND then ROR

`XAA` A:=X&#{imm} (very unstable)
  - See https://www.nesdev.org/wiki/Visual6502wiki/6502_Opcode_8B_(XAA,_ANE)

`LAX` A,X:=#{imm} (very unstable)
  - LDA then TAX

`AXS` X:=A&X-#{imm}
  - AND then subract w/o borrow

`SBC` A:=A-#{imm}
  - Duplicate of SBC

`AHX` {adr}:=A&X&H (slightly unstable)
  - ??? What is H

`SHY` {adr}:=Y&H (slightly unstable)

`SHX` {adr}:=X&H (slightly unstable)

`TAS` S:=A&X {adr}:=S&H (slightly unstable)

`LAS` A,X,S:={adr}&S

--- 

`KIL` = halts the CPU. the data bus will be set to #$FF
