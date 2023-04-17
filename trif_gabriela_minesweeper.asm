.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc 

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; sectiunile programului, date, respectiv cod
.data
; aici declaram date
window_title DB "Minesweeper",0
area_width EQU 360
area_height EQU 450
area DD 0

counter DD 0 ; numara evenimentele de tip timer
counterOK DD 0


arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

button_x EQU 500
button_y EQU 150
button_size EQU 80

;vector dd 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


vector  dd 81 dup (0)
lung_patrat dd 33
coord_x dd 0
coord_y dd 0 
bmb dd 1
viz dd 81 dup (0)
poz_x dd 0
poz_y dd 0
nr_casute dd 9 
aux dd 36
bomba dd 0

format db "%d ", 13, 10, 0	  


.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm



line_horizontal macro x,y, len , color
	local bucla_linie
	mov eax, y ; EAX =y
	mov ebx, area_width								
	mul ebx 	; 	eax=y*area_width					|	desen cruce
	add eax, x	;eax=y*area_width +x		|
	shl eax,2 	;eax= (y*area_width +x ) * 4
	add eax, area
	mov ecx, len 
bucla_linie:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla_linie
endm

line_vertical macro x,y, len , color
	local bucla_linie
	mov eax, y ; EAX =y
	mov ebx, area_width								
	mul ebx 	; 	eax=y*area_width					|	desen cruce
	add eax, x	;eax=y*area_width +x		|
	shl eax,2 	;eax= (y*area_width +x ) * 4
	add eax, area
	mov ecx, len 
bucla_linie:
	mov dword ptr[eax], color
	add eax, area_width *4
	loop bucla_linie
endm



afisare_linie macro poz_y_init, poz_mat_init, poz_mat
	local afis_el
	local fin
	local not_bmb

	mov poz_x, 40
	mov poz_y, poz_y_init
	mov eax,poz_mat_init
	mov ebx, poz_mat
	afis_el :
		mov ecx, viz[eax]
		cmp ecx, 1 
		jl fin 
		
		mov edx, vector[eax]
		mov esi, '0'
		add edx, esi 
		make_text_macro edx, area , poz_x, poz_y
		cmp vector[eax], 9
		jne fin 
		make_text_macro 'X', area , poz_x, poz_y
		fin:
		add poz_x, 33

		
		add eax, 4
		
		cmp eax, ebx 
		jne afis_el

endm



; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	; mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
	; mov eax, [ebp + arg3] ; EAX =y
	; mov ebx, area_width								|
	; mul ebx 	; 	eax=y*area_width					|	desen cruce
	; add eax, [ebp+ arg2]	;eax=y*area_width +x		|
	; shl eax,2 	;eax= (y*area_width +x ) * 4
	; add eax, area
	; mov dword ptr [eax], 0FF0000h
	; mov dword ptr [eax +4], 0FF0000h
	; mov dword ptr [eax - 4], 0FF0000h
	; mov dword ptr [eax + 4*area_width], 0FF0000h
	; mov dword ptr [eax - 4*area_width], 0FF0000h
	;line_vertical [ebp+arg2], [ebp+arg3], 30, 0FFh
	
	; mov eax, [ebp+arg2]
	; cmp eax, button_x
	; JL button_fail
	; cmp eax, button_x+button_size
	; JG button_fail
	; mov eax, [ebp+arg3]
	; cmp eax, button_y
	; JL button_fail
	; cmp eax, button_y+button_size
	; JG button_fail
	;;s-a dat click in button
	; make_text_macro 'O', area, button_x + button_size/2 - 5 , button_y + button_size/2 +10
	; make_text_macro 'K', area, button_x + button_size/2 + 5 , button_y + button_size/2 +10
	; mov counterOK, 0
	; jmp afisare_litere
	
; button_fail:
	; make_text_macro ' ', area, button_x + button_size/2 - 5 , button_y + button_size/2 +10
	; make_text_macro ' ', area, button_x + button_size/2 + 5 , button_y + button_size/2 +10
	
	cmp bomba, 1
	je final_draw
	
	;coord_y=( [ebp+arg2] - 30 ) /33
	mov eax, [ebp+ arg2]
	sub eax, 30 
	mov edx, 0
	div lung_patrat
	mov coord_y, eax
	
	;coord_x=( [epb+arg3] - 100 ) / 33
	
	mov eax , [ ebp + arg3]
	sub eax, 100
	mov edx, 0
	div lung_patrat
	mov coord_x, eax
	
	mov ebx, coord_x
	mov ecx, coord_y
	
	mov eax, 9
	mul coord_x
	add eax, coord_y
	shl eax, 2
	
	cmp vector[eax], 9
	jne etic
	mov bomba, 1
	make_text_macro 'G', area, 210, 55
	make_text_macro 'A', area, 220, 55
	make_text_macro 'M', area, 230, 55
	make_text_macro 'E', area, 240, 55
	make_text_macro '0', area, 260, 55
	make_text_macro 'V', area, 270, 55
	make_text_macro 'E', area, 280, 55
	make_text_macro 'R', area, 290, 55

	mov viz[eax], 1
	etic:
	cmp viz[eax], 1
	;je skip
	je afisare_litere
	
	mov viz[eax], 1
	
	mov ebx, eax
	
	sub ebx, 36
	cmp vector[ebx], 9
	jne skip1
	inc vector[eax]
	
	skip1:
	sub ebx, 4
	cmp vector[ebx], 9
	jne skip2
	inc vector[eax]
	
	skip2:
	add ebx, 8
	cmp vector[ebx], 9
	jne skip3
	inc vector[eax]
	
	skip3:
	add ebx, 36
	cmp vector[ebx], 9
	jne skip4
	inc vector[eax]
	
	skip4:
	sub ebx, 8
	cmp vector[ebx], 9
	jne skip5
	inc vector[eax]
	
	skip5:
	add ebx, 36
	cmp vector[ebx], 9
	jne skip6
	inc vector[eax]
	
	skip6:
	add ebx, 4
	cmp vector[ebx], 9
	jne skip7
	inc vector[eax]
	
	
	skip7:
	add ebx, 4
	cmp vector[ebx], 9
	jne skip
	add vector[eax], 1
	
	skip:
	mov edx, vector[eax]
	cmp vector[eax], 9
	je game_over 
	;je afisare_litere_game_over
	;mov vector[eax], 1
	
	
	
	
	
	
	
	jmp afisare_litere
	
	game_over:
	; push 0
	; push offset format 
	; call printf
	; add esp, 8 
	
	make_text_macro 'G', area, 210, 55
	 make_text_macro 'A', area, 220, 55
	make_text_macro 'M', area, 230, 55
	make_text_macro 'E', area, 240, 55
	make_text_macro '0', area, 260, 55
	 make_text_macro 'V', area, 270, 55
	make_text_macro 'E', area, 280, 55
	make_text_macro 'R', area, 290, 55
	
	mov viz[0], 0
	mov viz[4], 0
	mov viz[8], 0
	mov viz[12], 0
	mov viz[16], 0
	mov viz[20], 0
	mov viz[24], 0
	mov viz[28], 0
	mov viz[32], 0
	mov viz[36], 0
	mov viz[40], 0
	mov viz[44], 0
	mov viz[48], 0
	mov viz[52], 0
	mov viz[56], 0
	mov viz[60], 0
	mov viz[64], 0
	mov viz[68], 0
	mov viz[72], 0
	mov viz[76], 0
	mov viz[80], 0
	mov viz[84], 0
	mov viz[88], 0
	mov viz[92], 0
	mov viz[96], 0
	mov viz[100], 0
	mov viz[104], 0
	mov viz[108], 0
	mov viz[112], 0
	mov viz[116], 0
	mov viz[120], 0
	mov viz[124], 0
	mov viz[128], 0
	mov viz[132], 0
	mov viz[136], 0
	mov viz[140], 0
	mov viz[144], 0
	mov viz[148], 0
	mov viz[152], 0
	mov viz[156], 0
	mov viz[160], 0
	mov viz[164], 0
	mov viz[168], 0
	mov viz[172], 0
	mov viz[176], 0
	mov viz[180], 0
	mov viz[184], 0
	mov viz[188], 0
	mov viz[192], 0
	mov viz[196], 0
	mov viz[200], 0
	mov viz[204], 0
	mov viz[208], 0
	mov viz[212], 0
	mov viz[216], 0
	mov viz[220], 0
	mov viz[224], 0
	mov viz[228], 0
	mov viz[232], 0
	mov viz[236], 0
	mov viz[240], 0
	mov viz[244], 0
	mov viz[248], 0
	mov viz[252], 0
	mov viz[256], 0
	mov viz[260], 0
	mov viz[264], 0
	mov viz[268], 0
	mov viz[272], 0
	mov viz[276], 0
	mov viz[280], 0
	mov viz[284], 0
	mov viz[288], 0
	mov viz[292], 0
	mov viz[296], 0
	mov viz[300], 0
	mov viz[304], 0
	mov viz[308], 0
	mov viz[312], 0
	mov viz[316], 0
	mov viz[320], 0
	jmp afisare_litere
	
evt_timer:
	inc counter
	inc counterOK
	; cmp counterOK, 15
	; JE button_fail

	

	
	
afisare_litere:
	; afisam valoarea counter-ului curent (sute, zeci si unitati)

	mov ebx, 10
	mov eax, counter
	; cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 115, 55
	; cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 105, 55
	; cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 95, 55
	
	mov eax, 320
	mov edx, vector[eax]
	add esi, '0'
	add edx, esi
	;cmp edx, bmb
	;je afisare_litere
	 ;make_text_macro edx, area, 7, 72
	; make_text_macro edx, area, 40, 105
	; make_text_macro edx, area, 73, 105
	
	; mov eax, 16
	; mov edx, vector[eax]
	; mov esi,'0'
	; add edx, esi
	; mov poz_x, 40
	; mov poz_y, 105
	;make_text_macro '5', area, poz_x, poz_y
	;make_text_macro edx, area, 73, 105
	
	; scriem un mesaj
	; make_text_macro 'P', area, 110, 100
	; make_text_macro 'R', area, 120, 100
	; make_text_macro 'O', area, 130, 100
	; make_text_macro 'I', area, 140, 100
	; make_text_macro 'E', area, 150, 100
	; make_text_macro 'C', area, 160, 100
	; make_text_macro 'T', area, 170, 100
	
	; make_text_macro 'L', area, 130, 120
	; make_text_macro 'A', area, 140, 120
	
	; make_text_macro 'A', area, 100, 140
	; make_text_macro 'S', area, 110, 140
	; make_text_macro 'A', area, 120, 140
	; make_text_macro 'M', area, 130, 140
	; make_text_macro 'B', area, 140, 140
	; make_text_macro 'L', area, 150, 140
	; make_text_macro 'A', area, 160, 140
	; make_text_macro 'R', area, 170, 140
	; make_text_macro 'E', area, 180, 140
	
	; line_horizontal button_x, button_y, button_size, 0
	; line_horizontal button_x, button_y+button_size, button_size, 0
	; line_vertical button_x, button_y, button_size, 0
	; line_vertical button_x+button_size, button_y, button_size, 0
	

	
	
	line_horizontal 195, 45, 120, 0										;button_x=55  l=40
	line_horizontal 195, 85, 120, 0										;button_y=45	L=100
	line_vertical 195, 45, 40, 0			
	line_vertical 315, 45, 40, 0
	
	line_horizontal 55, 45, 120, 0										;button_x=55  l=40
	line_horizontal 55, 85, 120, 0										;button_y=45	L=100
	line_vertical 55, 45, 40, 0			
	line_vertical 175, 45, 40, 0
	
	line_vertical 30, 30, 300, 0
	line_vertical 330, 30, 300, 0
	line_vertical 30, 100, 300, 0
	line_vertical 63, 100, 300, 0
	line_vertical 96, 100, 300, 0
	line_vertical 129, 100, 300, 0
	line_vertical 162, 100, 300, 0
	line_vertical 195, 100, 300, 0
	line_vertical 228, 100, 300, 0
	line_vertical 261, 100, 300, 0
	line_vertical 294, 100, 300, 0
	line_vertical 330, 100, 300, 0
	line_horizontal 30, 100, 300, 0
	
	line_horizontal 30, 30, 300, 0
	line_horizontal 30, 100, 300, 0
	line_horizontal 30, 133, 300, 0
	line_horizontal 30, 166, 300, 0
	line_horizontal 30, 199, 300, 0
	line_horizontal 30, 232, 300, 0
	line_horizontal 30, 265, 300, 0
	line_horizontal 30, 298, 300, 0
	line_horizontal 30, 331, 300, 0
	line_horizontal 30, 364, 300, 0
	line_horizontal 30, 400, 300, 0
	
	; make_text_macro 'M', area, 200, 55
	; make_text_macro 'I', area, 210, 55
	; make_text_macro 'N', area, 220, 55
	; make_text_macro 'E', area, 230, 55
	; make_text_macro 'S', area, 240, 55
	; make_text_macro 'W', area, 250, 55
	; make_text_macro 'E', area, 260, 55
	; make_text_macro 'E', area, 270, 55
	; make_text_macro 'P', area, 280, 55
	; make_text_macro 'E', area, 290, 55
	; make_text_macro 'R', area, 300, 55
	
	make_text_macro 'T', area, 25, 415
	make_text_macro 'R', area, 35, 415
	make_text_macro 'I', area, 45, 415
	make_text_macro 'F', area, 55, 415
	
	make_text_macro 'G', area, 75, 415
	make_text_macro 'A', area, 85, 415
	make_text_macro 'B', area, 95, 415
	make_text_macro 'R', area, 105, 415
	make_text_macro 'I', area, 115, 415
	make_text_macro 'E', area, 125, 415
	make_text_macro 'L', area, 135, 415
	make_text_macro 'A', area, 145, 415
	
	make_text_macro '3', area, 175, 415
	make_text_macro '0', area, 185, 415
	make_text_macro '2', area, 195, 415
	make_text_macro '1', area, 205, 415
	make_text_macro '1', area, 215, 415
	;for vizitat/ nevizitat
	
	afisare_matrice:
		afisare_linie 105, 0, 36
		afisare_linie 138, 36, 72
		afisare_linie 171, 72, 108
		afisare_linie 204, 108, 144
		afisare_linie 237, 144, 180 
		afisare_linie 270, 180, 216
		afisare_linie 303, 216, 252
		afisare_linie 336, 252, 288
		afisare_linie 369, 288, 324
		
	
	

final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:

	mov vector[16], 9   ;1
	mov vector[48], 9	;2
	mov vector[76], 9	;3
	mov vector[104], 9	;4
	mov vector[132], 9	;5
	mov vector[160], 9	;6
	mov vector[188], 9	;7
	mov vector[216], 9	;8
	mov vector[272], 9	;9
	mov vector[316], 9	;10
	
	; mov viz[16], 1
	; mov viz[48], 1
	; mov viz[76], 1
	; mov viz[104], 1
	; mov viz[132], 1
	; mov viz[160], 1
	; mov viz[188], 1
	; mov viz[216], 1
	; mov viz[272], 1
	; mov viz[316], 1
	
	; alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	; apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	; terminarea programului
	push 0
	call exit
end start
