1     ;#define HRC_28M
2
3
4     $nomod51
5     ;------------------------------------------------------------------------------
6     ;  This file is part of the C51 Compiler package
7     ;  Copyright (c) 1988-2005 Keil Elektronik GmbH and Keil Software, Inc.
8     ;  Version 8.01
9     ;
10     ;  *** <<< Use Configuration Wizard in Context Menu >>> ***
11     ;------------------------------------------------------------------------------
12     ;  STARTUP.A51:  This code is executed after processor reset.
13     ;
14     ;  To translate this file use A51 with the following invocation:
15     ;
16     ;     A51 STARTUP.A51
17     ;
18     ;  To link the modified STARTUP.OBJ file to your application use the following
19     ;  Lx51 invocation:
20     ;
21     ;     Lx51 your object file list, STARTUP.OBJ  controls
22     ;
23     ;------------------------------------------------------------------------------
24     ;
25     ;  User-defined <h> Power-On Initialization of Memory
26     ;
27     ;  With the following EQU statements the initialization of memory
28     ;  at processor reset can be defined:
29     ;
30     ; <o> IDATALEN: IDATA memory size <0x0-0x100>
31     ;     <i> Note: The absolute start-address of IDATA memory is always 0
32     ;     <i>       The IDATA space overlaps physically the DATA and BIT areas.
0100                33     IDATALEN        EQU     100H
34     ;
35     ; <o> XDATASTART: XDATA memory start address <0x0-0xFFFF>
36     ;     <i> The absolute start address of XDATA memory
0000                37     XDATASTART      EQU     0
38     ;
39     ; <o> XDATALEN: XDATA memory size <0x0-0xFFFF>
40     ;     <i> The length of XDATA memory in bytes.
0100                41     XDATALEN        EQU     100H
42     ;
43     ; <o> PDATASTART: PDATA memory start address <0x0-0xFFFF>
44     ;     <i> The absolute start address of PDATA memory
0000                45     PDATASTART      EQU     0H
46     ;
47     ; <o> PDATALEN: PDATA memory size <0x0-0xFF>
48     ;     <i> The length of PDATA memory in bytes.
0000                49     PDATALEN        EQU     0H
50     ;
51     ;</h>
52     ;------------------------------------------------------------------------------
53     ;
54     ;<h> Reentrant Stack Initialization
55     ;
56     ;  The following EQU statements define the stack pointer for reentrant
57     ;  functions and initialized it:
58     ;
59     ; <h> Stack Space for reentrant functions in the SMALL model.
60     ;  <q> IBPSTACK: Enable SMALL model reentrant stack
61     ;     <i> Stack space for reentrant functions in the SMALL model.
0000                62     IBPSTACK        EQU     0       ; set to 1 if small reentrant is used.
63     ;  <o> IBPSTACKTOP: End address of SMALL model stack <0x0-0xFF>
64     ;     <i> Set the top of the stack to the highest location.
0100                65     IBPSTACKTOP     EQU     0xFF +1     ; default 0FFH+1
66     ; </h>
67     ;
68     ; <h> Stack Space for reentrant functions in the LARGE model.
69     ;  <q> XBPSTACK: Enable LARGE model reentrant stack
70     ;     <i> Stack space for reentrant functions in the LARGE model.
0000                71     XBPSTACK        EQU     0       ; set to 1 if large reentrant is used.
72     ;  <o> XBPSTACKTOP: End address of LARGE model stack <0x0-0xFFFF>
73     ;     <i> Set the top of the stack to the highest location.
0000                74     XBPSTACKTOP     EQU     0xFFFF +1   ; default 0FFFFH+1
75     ; </h>
76     ;
77     ; <h> Stack Space for reentrant functions in the COMPACT model.
78     ;  <q> PBPSTACK: Enable COMPACT model reentrant stack
79     ;     <i> Stack space for reentrant functions in the COMPACT model.
0000                80     PBPSTACK        EQU     0       ; set to 1 if compact reentrant is used.
81     ;
82     ;   <o> PBPSTACKTOP: End address of COMPACT model stack <0x0-0xFFFF>
83     ;     <i> Set the top of the stack to the highest location.
0100                84     PBPSTACKTOP     EQU     0xFF +1     ; default 0FFH+1
85     ; </h>
86     ;</h>
87     ;------------------------------------------------------------------------------
88     ;
89     ;  Memory Page for Using the Compact Model with 64 KByte xdata RAM
90     ;  <e>Compact Model Page Definition
91     ;
92     ;  <i>Define the XDATA page used for PDATA variables.
94     ;
95     ; Enable pdata memory page initalization
97     ;
99     ; <i> uppermost 256-byte address of the page used for PDATA variables.
101     ;
102     ; <o> SFR address which supplies uppermost address byte <0x0-0xFF>
103     ; <i> most 8051 variants use P2 as uppermost address byte
105     ;
106     ; </e>
107     ;------------------------------------------------------------------------------
108
109     ; Standard SFR Symbols
00E0               110     ACC     DATA    0E0H
00F0               111     B       DATA    0F0H
0081               112     SP      DATA    81H
0082               113     DPL     DATA    82H
0083               114     DPH     DATA    83H
115
116                     NAME    ?C_STARTUP
117
118
119     ?C_C51STARTUP   SEGMENT   CODE
120     ?STACK          SEGMENT   IDATA
121
----                 122                     RSEG    ?STACK
0000                 123                     DS      1
124
125                     EXTRN CODE (?C_START)
126                     PUBLIC  ?C_STARTUP
127
----                 128                     CSEG    AT      0
0000 020000   F      129     ?C_STARTUP:     LJMP    STARTUP1
130
----                 131                     RSEG    ?C_C51STARTUP
132
0000                 133     STARTUP1:
0000 758410          134                     mov     084h, #010h
135
136     IF IDATALEN <> 0
0003 78FF            137                     MOV     R0,#IDATALEN - 1
0005 E4              138                     CLR     A
0006 F6              139     IDATALOOP:      MOV     @R0,A
0007 D8FD            140                     DJNZ    R0,IDATALOOP
141     ENDIF
142
143     IF XDATALEN <> 0
0009 900000          144                     MOV     DPTR,#XDATASTART
000C 7F00            145                     MOV     R7,#LOW (XDATALEN)
146       IF (LOW (XDATALEN)) <> 0
MOV     R6,#(HIGH (XDATALEN)) +1
ELSE
000E 7E01            149                     MOV     R6,#HIGH (XDATALEN)
150       ENDIF
0010 E4              151                     CLR     A
0011 F0              152     XDATALOOP:      MOVX    @DPTR,A
0012 A3              153                     INC     DPTR
0013 DFFC            154                     DJNZ    R7,XDATALOOP
0015 DEFA            155                     DJNZ    R6,XDATALOOP
156     ENDIF
157
ENDIF
161
162     IF PDATALEN <> 0
MOV     R0,#LOW (PDATASTART)
MOV     R7,#LOW (PDATALEN)
CLR     A
PDATALOOP:      MOVX    @R0,A
INC     R0
DJNZ    R7,PDATALOOP
ENDIF
170
171     IF IBPSTACK <> 0
EXTRN DATA (?C_IBP)
MOV     ?C_IBP,#LOW IBPSTACKTOP
ENDIF
176
177     IF XBPSTACK <> 0
EXTRN DATA (?C_XBP)
MOV     ?C_XBP,#HIGH XBPSTACKTOP
MOV     ?C_XBP+1,#LOW XBPSTACKTOP
ENDIF
183
184     IF PBPSTACK <> 0
EXTRN DATA (?C_PBP)
MOV     ?C_PBP,#LOW PBPSTACKTOP
ENDIF
188
0017 758100   F      189                     MOV     SP,#?STACK-1
190
191     ; This code is required if you use L51_BANK.A51 with Banking Mode 4
192     ;<h> Code Banking
193     ; <q> Select Bank 0 for L51_BANK.A51 Mode 4
194
199     ;</h>
200
201     ;cal pr 0x9090~0x909f
001A 909080          202                     mov     dptr, #09080h
001D 74A5            203                     mov     a, #0a5h
001F F0              204                     movx    @dptr, a
205
0020 908020          206                     mov     dptr, #08020h
0023 7400            207                     mov     a, #00h
0025 93              208                     movc    a, @a+dptr
209
0026 909082          210                     mov     dptr, #09082h
0029 F0              211                     movx    @dptr, a
212
002A 7430            213                             mov     a, #030h
002C 909083          214                     mov     dptr, #09083h
002F F0              215                     movx    @dptr, a
216
0030 9090F0          217                     mov     dptr, #090f0h
0033 E0              218                     movx    a, @dptr
0034 4480            219                     orl     a, #080h
0036 F0              220                     movx    @dptr, a
221
0037 758AA0          222                     mov     8ah,#0a0h
223
003A 908027          224                             mov     dptr, #08027h
225
226
003D 7400            229                     mov     a, #00h
003F 93              230                     movc    a, @a+dptr
0040 F58A            231                     mov     8ah,a
232
0042 908026          233                     mov     dptr, #08026h
234
235
0045 7400            238                     mov     a, #00h
0047 93              239                     movc    a, @a+dptr
0048 F589            240                     mov     89h,a
241
004A 909080          242                     mov     dptr, #09080h
004D 745A            243                     mov     a, #05ah
004F F0              244                     movx    @dptr, a
245
0050 020000   F      246                     LJMP    ?C_START
247
248                     END
SYMBOL TABLE LISTING
------ ----- -------
N A M E             T Y P E  V A L U E   ATTRIBUTES
?C_C51STARTUP. . .  C SEG    0053H       REL=UNIT
?C_START . . . . .  C ADDR   -----       EXT
?C_STARTUP . . . .  C ADDR   0000H   A
?STACK . . . . . .  I SEG    0001H       REL=UNIT
ACC. . . . . . . .  D ADDR   00E0H   A
B. . . . . . . . .  D ADDR   00F0H   A
DPH. . . . . . . .  D ADDR   0083H   A
DPL. . . . . . . .  D ADDR   0082H   A
IBPSTACK . . . . .  N NUMB   0000H   A
IBPSTACKTOP. . . .  N NUMB   0100H   A
IDATALEN . . . . .  N NUMB   0100H   A
IDATALOOP. . . . .  C ADDR   0006H   R   SEG=?C_C51STARTUP
PBPSTACK . . . . .  N NUMB   0000H   A
PBPSTACKTOP. . . .  N NUMB   0100H   A
PDATALEN . . . . .  N NUMB   0000H   A
PDATASTART . . . .  N NUMB   0000H   A
SP . . . . . . . .  D ADDR   0081H   A
STARTUP1 . . . . .  C ADDR   0000H   R   SEG=?C_C51STARTUP
XBPSTACK . . . . .  N NUMB   0000H   A
XBPSTACKTOP. . . .  N NUMB   0000H   A
XDATALEN . . . . .  N NUMB   0100H   A
XDATALOOP. . . . .  C ADDR   0011H   R   SEG=?C_C51STARTUP
XDATASTART . . . .  N NUMB   0000H   A
REGISTER BANK(S) USED: 0
ASSEMBLY COMPLETE.  0 WARNING(S), 0 ERROR(S)