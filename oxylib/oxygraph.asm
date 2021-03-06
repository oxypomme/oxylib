DSEG     SEGMENT
    ; Define colors
    _BLACK_         EQU 00h
    _BLUE_          EQU 01h
    _GREEN_         EQU 02h
    _CYAN_          EQU 03h
    _RED_           EQU 04h
    _MAGENTA_       EQU 05h
    _BROWN_         EQU 06h
    _WHITE_         EQU 07h
    _GRAY_          EQU 08h
    _LBLUE_         EQU 09h
    _LGREEN_        EQU 0Ah
    _LCYAN_         EQU 0Bh
    _LRED_          EQU 0Ch
    _LMAGENTA_      EQU 0Dh
    _YELLOW_        EQU 0Eh
    _BWHITE_        EQU 0Fh

    _DPURPLE_       EQU 22h
    _PURPLE_        EQU 23h
    _LPURPLE_       EQU 3Ah

    _DRED_          EQU 70h

    _DYELLOW_       EQU 74h
DSEG     ENDS

RESETVIDEOMEM PROC NEAR
    push AX
    mov  AX, 0A000h
    mov  ES, AX     ; Beginning of VGA memory in segment 0xA000
    pop  AX
    ret
RESETVIDEOMEM ENDP

SETVIDEOMODE PROC NEAR
    push AX
    mov  AX, 13h    ; Mode VGA de l'affichage, 13h signifie une mémoire de 320*200 avec 256 couleurs
    int  10h
    pop  AX
    ret
SETVIDEOMODE ENDP

SETVIDEOMODEVESA PROC NEAR
    push AX
    push BX
    mov  AX, 4F02h 
    mov  BX, 101h ; 640x480
    int  10h
    pop  BX
    pop  AX
    ret
SETVIDEOMODEVESA ENDP

; SETUPGRAPHICS
;   initialize few things before we start
oxgSETUPGRAPHICS PROC NEAR
    call RESETVIDEOMEM
    call SETVIDEOMODE
    ret
oxgSETUPGRAPHICS ENDP

oxgSETUPGRAPHICSVESA PROC NEAR
    call RESETVIDEOMEM
    call SETVIDEOMODEVESA
    ret
oxgSETUPGRAPHICSVESA ENDP

; FILL
;   fill the screen (only VGA modes)
;
;   xA : x coordinate of the top left point (in chunks, 8 pixels)
;   yA : y coordinate of the top left point (in chunks, 8 pixels)
;   xB : x coordinate of the bottom right point (in chunks, 8 pixels)
;   yB : y coordinate of the bottom right point (in chunks, 8 pixels)
;   color : color to be filled with (in hex code)
oxgFILLS MACRO xA, yA, xB, yB, color
    ; on stocke les registres
    push AX
    push DS
    push BX
    push CX
    push DI

    mov  AH, 06h
    mov  AL, 0      ; on remonte toutes les lignes
    mov  BH, color  ; on attribue de nouvelles lignes
    mov  CL, xA     ; la colonne la plus basse
    mov  CH, yA     ; la colonne la plus haute
    mov  DL, xB
    mov  DH, yB     ; le coin en bas à droite
    int  10h        ; on affiche

    oxgSETCURSOR 0, 0

    ; on restore les registres
    pop  DI
    pop  CX
    pop  BX
    pop  DS
    pop  AX
ENDM

; CLEAR
;   fill the screen with black color
oxgCLEAR MACRO
    oxgFILLS 0, 0, 39, 24, _BLACK_
ENDM

oxgCLEARVESA MACRO
    call SETVIDEOMODE
ENDM

; CLEARSOMETHING
;   clears a chunk of the screen
;
;   X : x coordinate of the top left point (in pixels)
;   Y : y coordinate of the top left point (in pixels)
;   sizeX : width of the chunk to clear (in chunks, 8 pixels)
;   sizeY : height of the chunk to clear (in chunks, 8 pixels)
oxg_CLEARSOMETHING MACRO X, Y, sizeX, sizeY
    push AX
    push BX
    push CX
    push DX
    
    mov  AX, X
    mov  BX, Y
    sar  AX, 3
    sar  BX, 3
    mov  CL, AL
    mov  CH, BL
    mov  DX, CX
    add  DL, sizeX
    add  DH, sizeY
     
    oxgFILLS CL, CH, DL, DH, _BLACK_
     
    pop  DX
    pop  CX
    pop  BX
    pop  AX
ENDM

; SETCURSOR
;   set the cursor at a position at page 0
;
;   x : x coordinate of the new cursor (in chunks, 8 pixels)
;   y : y coordinate of the new cursor (in chunks, 8 pixels)
oxgSETCURSOR MACRO x, y
    push BX         ; on stocke les registres 
    push DX
    push AX

    mov  BH, 0      ; page actuelle
    mov  DL, x      ; collonne actuelle
    mov  DH, y      ; ligne actuelle
    mov  AH, 02     ; on change la position du curseur
    int  10h        ; et on affiche

    pop  AX         ; on restore les registres
    pop  DX
    pop  BX
ENDM

; SHOWPIXEL
;   draw a pixel 
;
;   xA : x coordinate of the top left point (in pixels)
;   yA : y coordinate of the top left point (in pixels)
;   color : color of the pixel (hex code)
oxgSHOWPIXEL MACRO xA, yA, color
    push AX         ; on stocke les registres 
    push CX
    push DX
    push BX

    mov  CX, xA     ; position x du point
    mov  DX, yA     ; position y du point
    mov  AL, color

    mov  AH, 0Ch    ; On veut afficher un pixel
    mov  BH, 1      ; page no - critical while animating
    int  10h        ; affichage

    pop  BX         ; on restore les registres
    pop  DX
    pop  CX
    pop  AX
ENDM

; SHOWHORLINE
;   draw a horizontal line 
;  
;   xA : x coordinate of the left point (in pixels)
;   yA : y coordinate of the left point (in pixels)
;   xB : x coordinate of the right point (in pixels)
;   color : color of the line (hex code)
oxgSHOWHORLINE MACRO xA, yA, xB, color
    local drawLoop  ; on définit un label local
    
    push CX         ; on sauvegarde le registre

    mov  CX, xA     ; on met xA dans CX
    drawLoop:
         ; on dessine le pixel
         oxgSHOWPIXEL CX, yA, color

         inc CX     ; on augmente la position x

         cmp CX, xB ; on vérifie que la nouvelle position est <= au max. Oui => On recommence, non => on arrête.
         jle drawLoop 
    
    pop  CX         ; on restaure le registre
ENDM

; SHOWVERTLINE
;   draw a vertical line
;  
;   xA : x coordinate of the top point (in pixels)
;   yA : y coordinate of the top point (in pixels)
;   yB : y coordinate of the bottom point (in pixels)
;   color : color of the line (hex code)
oxgSHOWVERTLINE MACRO xA, yA, yB, color
    local drawLoop  ; on définit un label local

    push DX         ; on sauvegarde le registre

    mov DX, yA      ; on met yA dans DX
    drawLoop:
         ; on dessine le pixel
         oxgSHOWPIXEL xA, DX, color

         inc DX     ; on augmente sa position y

         cmp DX, yB ; on vérifie que la nouvelle position est <= au max. Oui => On recommence, non => on arrête
         jle drawLoop

    pop  DX         ; on restaure le registre
ENDM

; SHOWSQUARE
;   draw a square
;  
;   xA : x coordinate of the top left point (in pixels)
;   yA : y coordinate of the top left point (in pixels)
;   xB : x coordinate of the bottom right point (in pixels)
;   xB : y coordinate of the bottom right point (in pixels)
;   color : color of the square (hex code)
oxgSHOWSQUARE MACRO xA, yA, xB, yB, color
    ; on dessine la ligne en haut
    oxgSHOWHORLINE xA, yA, xB, color

    ; on dessine la ligne à gauche
    oxgSHOWVERTLINE xA, yA, yB, color

    ; on dessine la ligne en bas
    oxgSHOWHORLINE xA, yB, xB, color

    ; on dessine la ligne à droite
    oxgSHOWVERTLINE xB, yA, yB, color
ENDM

; SHOWPLAINSQUARE
;   draw a filled square
;  
;   xA : x coordinate of the top left point (in pixels)
;   yA : y coordinate of the top left point (in pixels)
;   xB : x coordinate of the bottom right point (in pixels)
;   xB : y coordinate of the bottom right point (in pixels)
;   color : color of the square (hex code)
oxgSHOWPLAINSQUARE MACRO xA, yA, xB, yB, color
    local drawLoop  ; on définit un label local

    push DX         ; on sauvegarde le registre

    mov  DX, yA     ; on met yA dans DX
    drawLoop:
         ; on dessine la ligne
         oxgSHOWHORLINE xA, DX, xB, color

         inc DX     ; on passe à la nouvelle ligne

         cmp DX, yB ; on vérifie que la nouvelle position est <= au max. Oui => On recommence, non => on arrête
         jle drawLoop

    pop  DX         ; on restaure le registre
ENDM
