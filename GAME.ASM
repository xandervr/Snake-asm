;=============================================================================
; © Copyright Arthur Chomé & Xander Van Raemdonck
; 2BA Computerwetenschappen - Computersystemen
; Snake Game in 8086 Assembly
;=============================================================================
IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

;=============================================================================
; INCLUDES
;=============================================================================
INCLUDE "rand.inc"

;=============================================================================
; CODE
;=============================================================================
CODESEG

; Procedure to wait for a v-blank event (synchronizes game loop to 60Hz in mode 13h)
PROC waitVBlank
	USES eax, edx

	mov dx, 03dah
	@@waitVBlank_wait1:
	in al, dx
	and al, 8
	jnz @@waitVBlank_wait1
	@@waitVBlank_wait2:
	in al, dx
	and al, 8
	jz @@waitVBlank_wait2

	cld
  mov esi, offset videoBuffer
  mov edi, 0a0000h
  mov ecx, 64000 / 4
  rep movsd

	ret
ENDP waitVBlank

PROC setupVideo
	USES eax

	mov	ax, 13h
	int	10h

	ret
ENDP setupVideo

PROC unsetupVideo
	USES eax

	mov	ax, 03h
	int	10h

	ret
ENDP unsetupVideo

; Procedure to exit the program
PROC exit
	USES eax

	call unsetupVideo
	mov	eax, 4c00h
	int 21h
	ret
ENDP exit

; Draw Sprites
PROC drawSprite
	ARG @@spritePtr :dword, \
			@@x:dword, \
			@@y:dword
	LOCAL @@w:dword, @@h:dword
	USES eax , ebx , ecx , edx , esi , edi

	mov      esi , [ @@spritePtr ]
	xor      eax , eax
	lodsw    ; read width in AX
	mov      [@@w] , eax
	lodsw    ; read height in AX
	mov      [@@h] , eax
	mov      edi , offset videoBuffer
	mov      eax , [@@y]
	mov      ebx , [SCREEN_WIDTH]
	mul      ebx
	add      edi, eax
	add      edi, [@@x]   ; EDI points to forst pixel
	mov      ecx, [@@h]
@@drawLine:
	push     ecx
	mov      ecx, [@@w]    ; need to copy a line of the sprite
	rep      movsb         ; copy from esi to edi
	add      edi, [SCREEN_WIDTH]
	sub      edi, [@@w]    ; edit now points to the next line in dst
	pop      ecx
	dec      ecx
	jnz      @@drawLine

	ret
ENDP drawSprite

PROC drawText
	USES edi, esi, eax
	mov di, 158
	mov al, 40h
	mov [es:di], al
	inc di
	mov al, 79h
	mov [es:di], al
	ret
ENDP drawText

; Procedure to handle user input
PROC handleUserInput
	USES eax

	mov ah, 01h ; function 01h (test key pressed)
	int 16h		; call keyboard BIOS
	jz @@no_key_pressed
	mov ah, 00h
	int 16h

	; process key code here (scancode in AH, ascii code in AL)
	cmp ah, 01	; scancode for ESCAPE key
	jne	@@n1
	call exit
	jmp @@no_key_pressed

@@n1:
	cmp ah, 77	; arrow right
	jne @@n2
	mov eax, 0
	add eax, [TILE_SIZE]
	mov [DIRECTION_X], eax
	mov [DIRECTION_Y], 0
	jmp @@no_key_pressed

@@n2:
	cmp ah, 75	; arrow left
	jne @@n3
	mov eax, 0
	sub eax, [TILE_SIZE]
	mov [DIRECTION_X], eax
	mov [DIRECTION_Y], 0
	jmp @@no_key_pressed

@@n3:
	cmp ah, 80	; arrow down
	jne @@n4
	mov [DIRECTION_X], 0
	mov eax, 0
	add eax, [TILE_SIZE]
	mov [DIRECTION_Y], eax
	jmp @@no_key_pressed

@@n4:
	cmp ah, 72	; arrow up
	jne @@n5
	mov [DIRECTION_X], 0
	mov eax, 0
	sub eax, [TILE_SIZE]
	mov [DIRECTION_Y], eax
	jmp @@no_key_pressed

@@n5:
@@no_key_pressed:
	ret
ENDP handleUserInput

; Procedure to initialize a new game
PROC initGameState
	call rand_init
	mov [SNAKE_ARRAY_X], 0
	mov eax, [TILE_SIZE]
	mov [SNAKE_ARRAY_Y], eax
	call spawnRandomApple
	ret
ENDP initGameState

; Procedure to update the game world status (like enemies, collisions, events, ...)
PROC updateGameState
	USES eax, ebx

	mov eax, [SNAKE_ARRAY_X]
	mov ebx, [SNAKE_ARRAY_Y]
	cmp eax, [APPLE_X]
	jne @@noAppleHit
	cmp ebx, [APPLE_Y]
	jne @@noAppleHit
	inc [SCORE]
	call addSegment
	call spawnRandomApple
	@@noAppleHit:

	inc [gameLoopCounter]
	ret
ENDP updateGameState

; Procedure to draw everything on screen
PROC drawAll
	call waitVBlank

	ret
ENDP drawAll

PROC spawnRandomApple
	USES eax, ebx, ecx

	call rand
	mov edx, 0
	mov ebx, [GRID_WIDTH]
	div ebx
	imul edx, [TILE_SIZE]
	mov [APPLE_X], edx

	call rand
	mov edx, 0
	mov ebx, [GRID_HEIGHT]
	div ebx
	imul edx, [TILE_SIZE]
	mov [APPLE_Y], edx

	mov ebx, [APPLE_Y]
	cmp ebx, 0
	jne @@end
	call spawnRandomApple
	@@end:
	ret
ENDP spawnRandomApple

PROC drawApple

	call drawSprite, offset _apple, [APPLE_X], [APPLE_Y]
	ret
ENDP drawApple

PROC addSegment
	USES eax, ebx, ecx

  mov eax, [SNAKE_ARRAY_LEN]
	mov ebx, [SNAKE_ARRAY_X+4*eax]
	mov ecx, [SNAKE_ARRAY_Y+4*eax]
	add eax, 1
	mov [SNAKE_ARRAY_X+4*eax], ebx
	mov [SNAKE_ARRAY_Y+4*eax], ecx
	mov [SNAKE_ARRAY_LEN], eax

	ret
ENDP addSegment

PROC clearSnakeSegment
	USES eax
	mov eax, [SNAKE_ARRAY_LEN]
	dec eax
	call drawSprite, offset _black, [SNAKE_ARRAY_X + eax * 4], [SNAKE_ARRAY_Y + eax * 4]

	ret
ENDP clearSnakeSegment

PROC moveBlock
	ARG amount:dword
	USES eax, edx
mov ah, 9
mov edx, offset moveMsg
int 21h
	ret
ENDP moveBlock

PROC drawSnake
	LOCAL @@counter	:dword
	USES eax, ebx, ecx, edx

	mov ebx, [SNAKE_ARRAY_X]
	add ebx, [DIRECTION_X] ; ebx = new X
	mov ecx, [SNAKE_ARRAY_Y]
	add ecx, [DIRECTION_Y] ; ecx = new Y

	; collisions
	@@left_wall_hit:
		mov eax, 0
		sub eax, [TILE_SIZE]
		cmp ebx, eax
		jne @@right_wall_hit
		mov eax, [SCREEN_WIDTH]
		sub eax, [TILE_SIZE]
		mov ebx, eax
	@@right_wall_hit:
		mov edx, [SCREEN_WIDTH]
		cmp ebx, edx
		jne @@upper_wall_hit
		mov ebx, 0
	@@upper_wall_hit:
		mov eax, 0
		cmp ecx, eax
		jne @@lower_wall_hit
		mov ecx, [SCREEN_HEIGHT]
	@@lower_wall_hit:
		mov edx, [SCREEN_HEIGHT]
		add edx, [TILE_SIZE]
		cmp ecx, edx
		jne @@end
		mov ecx, 0
	@@end:
		call clearSnakeSegment
	 	call drawSprite, offset _snakeSegment, ebx, ecx

	mov eax, 0
	;;;; loopen
	@@loop:
		cmp eax, [SNAKE_ARRAY_LEN]
		je  @@loopEnd
		mov edx, [SNAKE_ARRAY_X + 4*eax]
		mov [SNAKE_ARRAY_X + 4*eax], ebx
		mov ebx, edx
		mov edx, [SNAKE_ARRAY_Y + 4*eax]
		mov [SNAKE_ARRAY_Y + 4*eax], ecx
		mov ecx, edx
		inc eax
		jmp @@loop
	@@loopEnd:
	; TODO

			ret
ENDP drawSnake


; MAIN Start of program
start:
  sti                             ; Set The Interrupt Flag
  cld                             ; Clear The Direction Flag

  push ds 						; Put value of DS register on the stack
  pop es 							; And write this value to ES

	; Setup and initialization
	call setupVideo
	call initGameState

	; Main game (endless) loop
	@@gameLoop:
	call handleUserInput


	call drawAll
	call drawApple
	call drawText

	mov eax, [gameLoopCounter]
	cmp eax, 10
	jl @@move_over
	call updateGameState
	call drawSnake
	mov [gameLoopCounter], 0
	@@move_over:
	call updateGameState

	jmp @@gameLoop

	; Code can never get here

;=============================================================================
; DATA
;=============================================================================
DATASEG
	; Counts the gameloops. Useful for timing and planning events.
	gameLoopCounter		dd 0

	SCREEN_WIDTH dd 320
	SCREEN_HEIGHT dd 200

	TILE_SIZE dd 8
	GRID_WIDTH dd 39
	GRID_HEIGHT dd 24

	DIRECTION_X dd 8
	DIRECTION_Y dd 0

	APPLE_X dd 0
	APPLE_Y dd 0

	SCORE dd 0

	videoBuffer db 64320 dup(?)
	SNAKE_ARRAY_X dd 320 * 200 dup (?)
	SNAKE_ARRAY_Y dd 320 * 200 dup (?)
	SNAKE_ARRAY_LEN dd 1

	moveMsg		db 'moveBlock$'

	_snakeSegment dw 8, 8
	db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4
  db 4, 4, 4, 4, 4, 4, 4, 4

	_apple dw 8, 8
	db 0, 2, 2, 0, 2, 2, 0, 0
  db 0, 0, 0, 2, 0, 0, 0, 0
  db 0, 0, 6, 6, 6, 0, 0, 0
  db 0, 6, 6, 6, 6, 6, 0, 0
  db 0, 6, 6, 6, 6, 6, 0, 0
  db 0, 6, 6, 6, 6, 6, 0, 0
  db 0, 0, 6, 6, 6, 0, 0, 0
  db 0, 0, 0, 6, 0, 0, 0, 0

	_black dw 8, 8
	db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0


;=============================================================================
; STACK
;=============================================================================
STACK 1000h

END start
