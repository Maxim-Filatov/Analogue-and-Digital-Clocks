start_graphic_mode	proc near
					mov ax, 0A000h
					mov es, ax
					mov ax, 13h
					int 10h
					retn
start_graphic_mode	endp


draw_line			proc near
					mov word ptr [draw_line_x1], ax
					mov word ptr [draw_line_y1], bx
					mov word ptr [draw_line_x2], cx
					mov word ptr [draw_line_y2], dx
					sub cx, ax
					sub dx, bx
					mov word ptr [draw_line_dx], cx
					mov word ptr [draw_line_dy], dx
					cmp cx, 0
					jl @@dx_less
		
	@@dx_greater:
					cmp dx, 0
					jge @@dx_greater_dy_greater
					jl @@dx_greater_dy_less
	@@dx_less:
					cmp dx, 0
					jge @@dx_less_dy_greater
					jl @@dx_less_dy_less
		
	@@dx_greater_dy_greater:
					mov ax, word ptr [draw_line_dx]
					mov bx, word ptr [draw_line_dy]
					mov word ptr [draw_line_quadrant_dx], ax
					mov word ptr [draw_line_quadrant_dy], bx
					mov ax, word ptr [draw_line_x1]
					mov bx, word ptr [draw_line_y1]
					mov cx, word ptr [draw_line_x2]
					mov dx, word ptr [draw_line_y2]
					mov si, 0
					jmp @@draw_line_continue
	@@dx_greater_dy_less:
					mov ax, word ptr [draw_line_dy]
					neg ax
					mov bx, word ptr [draw_line_dx]
					mov word ptr [draw_line_quadrant_dx], ax
					mov word ptr [draw_line_quadrant_dy], bx
					mov ax, word ptr [draw_line_y1]
					neg ax
					mov bx, word ptr [draw_line_x1]
					mov cx, word ptr [draw_line_y2]
					neg cx
					mov dx, word ptr [draw_line_x2]
					mov si, 3
					jmp @@draw_line_continue
	@@dx_less_dy_greater:
					mov ax, word ptr [draw_line_dy]
					mov bx, word ptr [draw_line_dx]
					neg bx
					mov word ptr [draw_line_quadrant_dx], ax
					mov word ptr [draw_line_quadrant_dy], bx
					mov ax, word ptr [draw_line_y1]
					mov bx, word ptr [draw_line_x1]
					neg bx
					mov cx, word ptr [draw_line_y2]
					mov dx, word ptr [draw_line_x2]
					neg dx
					mov si, 1
					jmp @@draw_line_continue
	@@dx_less_dy_less:
					mov ax, word ptr [draw_line_dx]
					neg ax
					mov bx, word ptr [draw_line_dy]
					neg bx
					mov word ptr [draw_line_quadrant_dx], ax
					mov word ptr [draw_line_quadrant_dy], bx
					mov ax, word ptr [draw_line_x1]
					neg ax
					mov bx, word ptr [draw_line_y1]
					neg bx
					mov cx, word ptr [draw_line_x2]
					neg cx
					mov dx, word ptr [draw_line_y2]
					neg dx
					mov si, 2

	@@draw_line_continue:
					call draw_line_quadrant
					retn
draw_line			endp

		
; ax = x1
; bx = y1
; cx = x2
; dx = y2
; di = color index
; si = quadrant
draw_line_quadrant	proc near
					add si, si
					push cx
					push dx
					mov cx, word ptr [draw_line_quadrant_dx]
					mov dx, word ptr [draw_line_quadrant_dy]
					cmp cx, dx
					jge @@not_swap
	@@swap:
					pop dx
					pop cx
					xchg ax, bx
					xchg cx, dx
					inc si
					jmp @@quadrant_continue
	@@not_swap:
					pop dx
					pop cx
	@@quadrant_continue:
					call draw_line_octant
					retn
draw_line_quadrant	endp

		
; ax = x1
; bx = y1
; cx = x2
; dx = y2
; di = color index
; si = octant
draw_line_octant	proc near
					mov word ptr [octant_x2], cx
					sub cx, ax
					sub dx, bx
					add dx, dx 
					mov word ptr [octant_2dy], dx
					sub dx, cx
					add cx, cx
					mov word ptr [octant_2dx], cx
					mov cx, ax
					mov ax, di
	@@next_point:
					call pset_octant
					cmp dx, 0
					jle @@d_less_or_equal
	@@d_greater:
					add dx, word ptr [octant_2dy]
					sub dx, word ptr [octant_2dx]
					inc bx
					jmp @@octant_continue
	@@d_less_or_equal:
					add dx, word ptr [octant_2dy]
	@@octant_continue:
					inc cx
					cmp cx, word ptr [octant_x2]
					jbe @@next_point
					retn
draw_line_octant	endp


; al = color index
; bx = row
; cx = col
; si = octant
pset_octant			proc near
					push bx
					push cx
					cmp si, 0
					jz @@octant_0
					cmp si, 1
					jz @@octant_1
					cmp si, 2
					jz @@octant_2
					cmp si, 3
					jz @@octant_3
					cmp si, 4
					jz @@octant_4
					cmp si, 5
					jz @@octant_5
					cmp si, 6
					jz @@octant_6
					cmp si, 7
					jz @@octant_7
	@@octant_0:
					jmp @@pset_continue
	@@octant_1:
					xchg bx, cx
					jmp @@pset_continue
	@@octant_2:
					neg bx
					xchg bx, cx
					jmp @@pset_continue
	@@octant_3:
					neg cx
					jmp @@pset_continue
	@@octant_4:
					neg cx
					neg bx
					jmp @@pset_continue
	@@octant_5:
					neg cx
					neg bx
					xchg bx, cx
					jmp @@pset_continue
	@@octant_6:
					neg cx
					xchg bx, cx
					jmp @@pset_continue
	@@octant_7:
					neg bx

	@@pset_continue:
					call pset
					pop cx
					pop bx
					ret
pset_octant			endp

		
; al = color index
; bx = row
; cx = col
pset				proc near
					pusha
					xor dx, dx
					push ax
					mov ax, 320
					mul bx
					add ax, cx
					mov bx, ax
					pop ax
					mov byte ptr es:[bx], al
					popa
					retn
pset				endp



	draw_line_x1 dw 0
	draw_line_y1 dw 0
	draw_line_x2 dw 0
	draw_line_y2 dw 0
	draw_line_dx dw 0
	draw_line_dy dw 0

	draw_line_quadrant_dx dw 0
	draw_line_quadrant_dy dw 0

	octant_x2 dw 0
	octant_2dx dw 0
	octant_2dy dw 0
