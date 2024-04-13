; Часы-будильник (в числовом и графическом виде)
; Группа ИСТ-261
; Авторы:
; Филатов Максим


.model tiny
.386
.code
org 100h


start:
					push es
					mov ax, 354Ah							; get current int 4Ah vector
					int 21h
					mov word ptr [saved_4Ah], bx			; old offset
					mov word ptr [saved_4Ah + 2], es		; old segment
					pop es

					mov ax, 254Ah							; new vector for 4Ah
					mov dx, offset int4Ah_procedure			; our int 4Ah procedure
					int 21h


					call start_graphic_mode
					finit
					call draw_background
					call show_messages

	@@main_loop:
					call get_DOS_date
					call get_DOS_time

					mov bx, 0E0Fh							; цвет отображения даты и времени
					call show_date_time						; отобразить цифровые часы

					call get_BIOS_time
					call update_angles						; рассчитать углы стрелок

					mov cx, 0D0Bh							; цвет стрелок
					call draw_pointers						; нарисовать часовые стрелки
		
	@@get_key:
					call get_keys_status
					jz @@redraw								; нет нажатых клавиш
					call get_key
					cmp ah, 1								; KEY_ESC scan-code
					je @@exit_process
					cmp ah, 3Ch								; F2 scan-code
					je @@switch_timer

	@@redraw:
					call check_timer

					mov cx, 0								; цвет стрелок (стираем текущие стрелки)
					call draw_pointers						; стираем часовые стрелки
					jmp @@main_loop


	@@switch_timer:
					xor cx, cx
					call draw_pointers

					cmp byte ptr [timer_enabled], 0
					jne @@disable_timer
					
					call enable_timer
					jmp @@main_loop

	@@disable_timer:
					call disable_timer
					jmp @@main_loop


	@@exit_process:
					call disable_timer				; отключаем будильник (необходимо, если он был установлен)

					mov ax, 254Ah
					lds dx, dword ptr [saved_4Ah]	; restore saved 4Ah vector
					int 21h
					
					mov ax, 03h						; reset to text mode
					int 10h

					mov ax, 4C00h					; exit to DOS
					int 21h

; Процедура-обработчик прерывания 4Ah
int4Ah_procedure:
					sti
					pusha
					mov bx, 4
					mov si, offset sound_freq
@@next_freq:		lodsw
					mov cx, ax
					call play_sound
					dec bx
					jnz @@next_freq
					popa
					iret

; Вывести звук на динамик
play_sound			proc near
					push ax bx dx
					mov bx, ax
					mov al, 182
					out 43h, al
					mov ax, bx
					out 42h, al
					mov al, ah
					out 42h, al
					in al, 61h
					or al, 03h
					out 61h, al

					mov cx, 03
					xor dx, dx
					call sleep_ms

					in al, 61h
					and al, 0FCh
					out 61h, al
					pop ax bx dx
					retn
play_sound			endp


enable_timer		proc near
					mov dx, 1800h
					push dx
					mov bl, 0Ah
					mov byte ptr [timer_enabled], 1
					mov si, offset enter_msg
					call put_string
		
					mov si, offset timerHeader
					call show_timer_msg
		
					call enter_timer
					pop dx
		
					cmp byte ptr [timer_enabled], 1
					je @@enableTimerNext
					call disable_timer
					jmp @@enableTimerDone

	@@enableTimerNext:
					mov bl, 02h
					mov si, offset reset_msg
					call put_string
					
					mov bx, 60
					mov ax, word ptr [timer_hour]
					mul bx
					mov bx, word ptr [timer_min]
					add ax, bx
					mov word ptr [timer_total], ax

					mov ax, word ptr [timer_hour]
					call convert_bin_to_bcd
					mov ch, al							; timer hours
					mov ax, word ptr [timer_min]
					call convert_bin_to_bcd
					mov cl, al							; timer minutes
					xor dh, dh							; timer seconds
					mov ah, 06h							; enable timer
					int 1Ah
					jnc @@enableTimerDone
					call disable_timer					; if error - disable timer
	@@enableTimerDone:
					retn
enable_timer		endp


disable_timer		proc near
					mov ah, 07h						; disable timer
					int 1Ah

					mov dx, 1800h
					mov bl, 02h
					mov byte ptr [timer_enabled], 0
					mov si, offset timer_msg
					call put_string

					mov si, offset resetHeader
					call show_timer_msg

					xor cx, cx
					call draw_timer

					retn
disable_timer		endp


enter_timer			proc near
					pusha
					add dx, 0103h
					push dx
					call set_cursor

					mov di, offset timer_hour
					call get_number

					pop dx
					add dl, 3
					call set_cursor
		
					cmp word ptr [timer_hour], 23				; max hours
					jbe @@enter_min
					mov byte ptr [timer_enabled], 0
					jmp @@enterTimerDone
	@@enter_min:
					mov di, offset timer_min
					call get_number
					cmp word ptr [timer_min], 59				; max minutes
					jbe @@enterTimerDone
					mov byte ptr [timer_enabled], 0
		
	@@enterTimerDone:
					popa
					retn
enter_timer			endp

; Ввод числа, в DI адрес куда сохранить
get_number			proc near
					pusha
					mov cx, 2
					xor bx, bx
					mov si, 10
	@@getNextKey:	
					call get_key
					xor ah, ah
					cmp al, '0'
					jb @@getNextKey
					cmp al, '9'
					ja @@getNextKey
					call put_timer_char
					sub al, '0'
					push ax
					mov ax, bx
					mul si
					mov bx, ax
					pop ax
					add bx, ax
					loop @@getNextKey
	@@getNumberDone:
					mov byte ptr [di], bl
					popa
					retn
get_number			endp


put_timer_char		proc near
					push bx
					mov bl, 0Eh
					call put_char
					pop bx
					retn
put_timer_char		endp

show_timer_msg		proc near
					mov bl, 0Fh
					mov dx, 1645h
					call put_string
					retn
show_timer_msg		endp


get_DOS_time		proc near
					pusha
					mov ah, 2Ch
					int 21h
					mov byte ptr [currHour], ch
					mov byte ptr [currMin], cl
					mov byte ptr [currSec], dh
					popa
					retn
get_DOS_time		endp


get_DOS_date		proc near
					pusha
					mov ah, 2Ah
					int 21h
					mov word ptr [currYear], cx
					mov byte ptr [currMonth], dh
					mov byte ptr [currDay], dl
					mov byte ptr [currDoW], al
					popa
					retn
get_DOS_date		endp


get_BIOS_time		proc near
					mov ah, 02h
					int 1Ah

					mov al, dh
					call convert_bcd_to_bin
					mov ah, 0
					mov word ptr [data_seconds], ax

					mov al, cl
					call convert_bcd_to_bin
					mov ah, 0
					mov word ptr [data_minutes], ax

					mov al, ch
					call convert_bcd_to_bin
					mov ah, 0
					mov word ptr [data_hrs], ax				; часы
					
					mov bx, 60								; для пересчета часов в минуты
					xor dx, dx
					mul bx
					add ax, word ptr [data_minutes]
					mov word ptr [data_hours], ax			; часы в минутах
		
					retn
get_BIOS_time		endp


check_timer			proc near
					push ax
					mov ax, word ptr [data_seconds]
					or ax, ax
					jnz @@do_sleep
					mov ax, word ptr [data_hrs]
					cmp ax, word ptr [timer_hour]
					jne @@do_sleep
					mov ax, word ptr [data_minutes]
					cmp ax, word ptr [timer_min]
					jne @@do_sleep

					int 4Ah							; call timer
					jmp short @@check_done

	@@do_sleep:		call sleep_half_s
	@@check_done:	pop ax
					retn
check_timer			endp


; Перекодирование значений даты и времени в текстовый вид
decode_date_time	proc near
					pusha
					mov bx, 10								; система счисления

					xor ah, ah
					mov al, byte ptr [currDay]
					mov di, offset dateValue[2]
					call decode_number
				
					mov al, byte ptr [currMonth]
					mov di, offset dateValue[5]
					call decode_number

					mov ax, word ptr [currYear]
					mov di, offset dateValue[8]
					call decode_number

					xor ah, ah
					mov al, byte ptr [currHour]
					mov di, offset timeValue[2]
					call decode_number

					mov al, byte ptr [currMin]
					mov di, offset timeValue[5]
					call decode_number

					mov al, byte ptr [currSec]
					mov di, offset timeValue[8]
					call decode_number

					popa
					retn
decode_date_time	endp

; Вывод текущих значений даты и времени в текстовом виде
show_date_time		proc near
					pusha
					call decode_date_time
					
					mov dx, 0000h
					mov si, offset dateHeader
					call put_string
					
					mov dx, 001Ch
					mov si, offset timeHeader
					xchg bh, bl
					call put_string
					
					popa
					ret
show_date_time		endp


show_messages		proc near
					pusha

					mov bl, 0Dh
					mov dx, 0300h
					mov si, offset authors
					call put_string

					mov bl, 01h
					mov dx, 1400h
					mov si, offset copyright
					call put_string

					mov bl, 02h
					mov dx, 1700h
					mov si, offset exit_msg
					call put_string

					mov dx, 1800h
					mov si, offset timer_msg
					call put_string

					popa
					retn
show_messages		endp

; Вывести на экран символ, переданный в AL
put_char			proc near
					push ax
					mov ah, 0Eh		; Output symbol on cursor position
					int 10h
					pop ax
					retn
put_char			endp

; Установить курсор в позицию, заданную в регистре dx
set_cursor			proc near
					push ax
					push bx
					mov ah, 02h
					xor bh, bh
					int 10h
					pop bx
					pop ax
					retn
set_cursor			endp


put_string			proc near
					pusha
	@@nextLine:		call set_cursor
					push dx
	@@nextChar:		lodsb
					or al, al
					jz @@tryNextLine
					call put_char
					jmp @@nextChar
	@@tryNextLine:	pop dx
					lodsb
					or al, al
					jz @@doneString
					dec si
					inc dh
					jmp @@nextLine
	@@doneString:	popa
					retn
put_string			endp


; Получить состояние клавиатуры
get_keys_status		proc near
					push ax
					mov ah, 11h	  				; Получить состояние клавиатуры
					int 16h
					pop ax
					retn
get_keys_status		endp

; Получить состояние клавиатуры
get_key				proc near
					mov ah, 10h	  				; Читать буфер клавиатуры
					int 16h
					retn
get_key				endp

; перекодирование числа (в AX) и сохранение его в [DI]
decode_number		proc near
					pusha
					mov si, bx
					mov bx, 1
					mov cx, 0
					cmp ax, 10
					jae @@putNext1
					mov byte ptr [di], '0'
					inc di
@@putNext1:			mov dx, 0
					div si
					push bx
					mov bx, dx
					mov dl, byte ptr charsTable[bx]
					pop bx
					push dx
					inc cx
					cmp ax, 0
					jnz @@putNext1
@@putNext2:			pop ax
					mov byte ptr [di], al
					inc di
					inc bx
					loop @@putNext2
					popa
					retn
decode_number		endp


update_pointer		proc near
					fld qword ptr [di]
					fcos
					fld qword ptr [si]
					fmul st, st(1)
					fistp word ptr [data_x]
					ffree st(0)
					fld qword ptr [di]
					fsin
					fld qword ptr [si]
					fmul st, st(1)
					fistp word ptr [data_y]
					ffree st(0)
					retn
update_pointer		endp

; обновить углы для всех стрелок
update_angles		proc near
					mov bx, offset data_v720
					mov si, offset data_hours
					mov di, offset data_angle_h
					call update_angle

					mov bx, offset data_v60
					mov si, offset data_minutes
					mov di, offset data_angle_m
					call update_angle

					mov bx, offset data_v60
					mov si, offset data_seconds
					mov di, offset data_angle_s
					call update_angle

					mov bx, offset data_v720
					mov si, offset timer_total
					mov di, offset data_angle_t
					call update_angle
					retn
update_angles		endp

; обновить угол стрелки
update_angle		proc near
					fld qword ptr [data_v90deg]
					fld qword ptr [data_pi2]
					fld qword ptr [bx]
					fild word ptr [si]
					fdiv st, st(1)
					fmul st, st(2)
					fsub st, st(3)
					fstp qword ptr [di]
					ffree st(0)
					ffree st(1)
					ffree st(2)
					retn
update_angle		endp


draw_pointers		proc near
					push cx
					mov di, offset data_angle_h
					mov si, offset data_size50
					call update_pointer
					mov di, cx
					call draw_pointer

					mov di, offset data_angle_m
					mov si, offset data_size80
					call update_pointer
					mov di, cx
					call draw_pointer

					mov di, offset data_angle_s
					mov si, offset data_size80
					call update_pointer
					pop cx
					mov cl, ch
					mov di, cx
					call draw_pointer
				
					cmp byte ptr [timer_enabled], 0
					je draw_pointers_done
					dec cl
					call draw_timer

draw_pointers_done:
					retn
draw_pointers		endp


draw_timer			proc near
					mov di, offset data_angle_t
					mov si, offset data_size50
					call update_pointer
					mov di, cx
					call draw_pointer
					retn
draw_timer			endp


draw_pointer		proc near
					pusha
					mov ax, 160
					mov bx, 100
					mov cx, 160
					mov dx, 100
					add cx, word ptr [data_x]
					add dx, word ptr [data_y]
					call draw_line
					popa
					retn
draw_pointer		endp

; 	in:
;	cx = number of steps
;	bx = angle incrementation
;   di = angle variable
;   si = radius
draw_circle			proc near
	@@next_draw_circle:
					fld qword ptr [bx]
					fld qword ptr [di]
					fadd st, st(1)
					fstp qword ptr [di]
					ffree st(0)

					mov di, offset data_angle_s
					call update_pointer

					pusha
					mov al, 15
					mov cx, 160
					add cx, word ptr [data_x]
					mov bx, 100
					add bx, word ptr [data_y]
					call pset
					popa
		
					loop @@next_draw_circle
					retn
draw_circle			endp

		
draw_hours_indications proc near
					mov cx, 12
	@@next_indication:
					push cx

					fld qword ptr [data_v30deg]
					fld qword ptr [data_angle_h]
					fadd st, st(1)
					fstp qword ptr [data_angle_h]
					ffree st(0)

					mov di, offset data_angle_h
					mov si, offset data_size85
					call update_pointer

	@@draw_square:
					mov ax, 159
					mov dx, 99
	@@next_dot:		
					call draw_square_dot
					inc ax
					cmp ax, 162
					jb @@next_dot
	@@dot_next_y:
					mov ax, 159
					inc dx
					cmp dx, 102
					jb @@next_dot

					pop cx
					loop @@next_indication

					retn
draw_hours_indications endp


draw_square_dot		proc near
					pusha
					mov cx, ax
					add cx, word ptr [data_x]
					mov bx, dx
					add bx, word ptr [data_y]
					mov al, 15
					call pset
					popa
					retn
draw_square_dot		endp


draw_background		proc near
					mov cx, 720
					mov bx, offset data_vhalf_deg
					mov si, offset data_size90
					mov di, offset data_angle_s
					call draw_circle

					mov cx, 60
					mov bx, offset data_v6deg
					mov si, offset data_size85
					mov di, offset data_angle_m
					call draw_circle

					call draw_hours_indications
					retn
draw_background		endp



convert_bcd_to_bin	proc near
					push bx cx dx
					mov bh, 0
					mov bl, al
					and bl, 0Fh
					mov ch, 0
					mov cl, al
					shr cx, 4
					xor dx, dx
					mov ax, 10
					mul cx
					add ax, bx
					pop dx cx bx
					retn
convert_bcd_to_bin	endp


convert_bin_to_bcd	proc near
					push bx
					xor bx, bx
	@@next_digit:	cmp ax, 10
					jb @@bcd_done
					sub ax, 10
					add bx, 10h
					jmp @@next_digit
	@@bcd_done:		add bx, ax
					mov ax, bx
					pop bx
					retn
convert_bin_to_bcd	endp
	

sleep_half_s		proc near
					push cx dx
					mov cx, 07h
					mov dx, 0A120h
					call sleep_ms
					pop dx cx
					retn
sleep_half_s		endp


sleep_ms			proc near
					push ax
					mov ah, 86h
					int 15h
					pop ax
					retn
sleep_ms			endp


	include lab5_2.inc


	data_angle_s	dq 0
	data_angle_m	dq 0
	data_angle_h	dq 0
	data_angle_t	dq 0


	data_hrs		dw 0
	data_hours		dw 0
	data_minutes	dw 0
	data_seconds	dw 0

	data_size90		dq 90.0
	data_size85		dq 85.0
	data_size80		dq 80.0
	data_size50		dq 50.0
		
	data_pi2		dq 6.28318
		
	data_vhalf_deg	dq 0.00872665
	data_v6deg		dq 0.10472
	data_v90deg		dq 1.5708
	data_v30deg		dq 0.523599
		
	data_v60		dq 60.0
	data_v720		dq 720.0
		
	data_x 			dw 0
	data_y 			dw 0
		
	data_tmp		dw 0

	dateHeader		db "╓ Date ──────╖", 0h
	dateValue		db "║ 00-00-0000 ║", 0h
	dateFooter		db "╙────────────╜", 0h, 0h

	timeHeader		db "╓ Time ────╖", 0h
	timeValue		db "║ 00:00:00 ║", 0h
	timeFooter		db "╙──────────╜", 0h, 0h

	timerHeader		db "╓─ Timer ─╖", 0h
	timerValue		db "║  00:00  ║", 0h
	timerFooter		db "╙─────────╜", 0h, 0h

	resetHeader		db "           ", 0h
	resetValue		db "           ", 0h
	resetFooter		db "           ", 0h, 0h

	copyright		db "(C) 2024", 0, "IST-261", 0h, 0h
	exit_msg:		db "<ESC>: exit", 0h, 0h
	timer_msg		db "<F2> : set timer  ", 0h, 0h
	enter_msg		db "Please enter timer", 0h, 0h
	reset_msg		db "<F2> : reset timer", 0h, 0h


	authors			db "Authors:", 0h
					db "M.Filatov", 0h
					db "E.Utigenova", 0h
					db "V.Ulasik", 0h
					db "B.Ilyich", 0h, 0h

	charsTable		db "0123456789ABCDEF"

	currYear		dw 0
	currMonth		db 0
	currDay			db 0
	currDoW			db 0
	currHour		db 0
	currMin			db 0
	currSec			db 0

	timer_hour		dw 0		; timer: часы
	timer_min		dw 0		; timer: минуты
	timer_total		dw 0		; значение timer-а в минутах

	timer_enabled	db 0

	saved_4Ah		dw 0, 0		; адрес предыдущего обработчика int 4Ah
	
	sound_freq		dw 600, 200, 500, 300		; частоты будильника

end start