;Guido Ruiz
;Jorge Travieso

;_________________________________________________________________________________________________________
;------------------------------------------ QUICKSORT STRING SORT ----------------------------------------

; compile:	nasm -g -f elf -F dwarf filesort.asm
; link:		64 bit: ld -o filesort filesort.o -melf_i386
;		32 bit: ld -o filesort filesort.o
; execute:	./filesort <input_file> <output_file>


; Macros for system call numbers
; The complete list of system calls can be found here: http://lxr.free-electrons.com/source/arch/m32r/kernel/syscall_table.S

%assign SYS_EXIT 1
%assign SYS_WRITE 4
%assign SYS_READ 3
%assign SYS_OPEN 5
%assign SYS_CLOSE 6
%assign SYS_CREATE 8
%assign SYS_MMAP 192
%assign SYS_FSTAT 108 

; Macros for open mode
%assign O_RDONLY 000000q
%assign O_WDONLY 000001q
%assign O_RDWR 000002q

; Macros for file permissions
%assign S_IRUSR 00400q
%assign S_IWUSR 00200q
%assign S_IXUSR 00100q

%define DELIMITER '	'			; '\t' tab character
;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------



;_________________________________________________________________________________________________________
;------------------------------------------------- MACROS ------------------------------------------------

; Macros for printing a message
%macro print 2					; Print macro that takes two arguments: the message, and the message length
	pushad					; Save all registers to stack
	mov	edx, %2				; Length of the message to print
	lea	ecx, [%1]			; The message to print
	mov	eax, SYS_WRITE
	mov	ebx, 1
	int	0x80
        popad					; Restore all registers from the stack
%endmacro

%macro print2 1                                ; Print macro that takes only one argument: the message
        section .data                          ; Data section for the macro
        %%str db %1,0xa
        %%strlen equ $-%%str                   ; Obtain the message length

        section .text
        print %%str, %%strlen                  ; Invoke the two arguments and print the macro
%endmacro

%macro printToFile 2				; System call to print to output file
	pushad					; Save all registers to stack
	mov	eax, SYS_WRITE
	mov	ebx, [handle2]			; Handle2 is the output file that contains file descripter
	mov	ecx, %1
	mov	edx, %2
	int	0x80	
	test	eax, eax			; Check for errors	
	js	writerror			; Jump if write error
	popad					; Restore all registers from the stack
%endmacro

;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------



;_________________________________________________________________________________________________________
;--------------------------------------- SETTING UP ------------------------------------------------------

section .data
	handle1		dd	0		; Input file handler
	handle2		dd	0		; Output file handler
	noread	  	dd	0		; # of bytes read from input
	cmpR	  	dd	0		; Used to compare strings
	garbage	  	dd	0	  	; Used to pop garbage from the stack
	stat_struct:	times	64 db 0
	
section .bss
	pointers	resd	8388608		; Reserve more than 8 million space for pointers (8 megabytes)  

section .text
	global _start

_start:
	mov	eax, SYS_OPEN			; Open the file to be mapped into memory
	mov	ebx, [esp+8]
	mov	ecx, O_RDONLY
	mov	edx, S_IRUSR
	int	0x80
	test	eax, eax
	js	openerror
	mov	[handle1], eax			; Copy file handle to handle var
	
	mov	eax, SYS_CREATE			; Create output file
	mov	ebx, [esp+12]			; Output filename is the fourth item from the top of the stack
	mov	ecx, S_IRUSR|S_IWUSR		; Create the file with read/write permissions for user
	int	0x80
	test	eax, eax
	js	createrror
	mov	[handle2], eax			; Save the output file handle
	
fstat:						; Call fstat to figure out the size of the input file (fstat(fd, struct stat))
	mov	ecx, stat_struct
	mov	ebx, [handle1]			; Handle1 contains file descripter
	mov	eax, SYS_FSTAT
	int	80h				; Call the fstat(). The size of file is in stat->st_size (in bytes)
	cmp	eax, -1				; Eax is -1 if error
	je	fstaterror
	mov	ecx, [ecx + 20] 		; Offset 16 of stat_struct points to the size field of the stats for the file.

mmap_private:					; Allocate memory using a file
	push	esi				; Save the non-general-purpose registers
	push	edi
	push	ebp
						; Make the mmap system call 
	mov	edi, [handle1]			; Fd
	mov	ebp, 0				; Offset
	mov	esi, 0x2			; Flags = MAP_PRIVATE
	mov	edx, 0x1			; Prot = PROT_READ
	or	edx, 0x2			; Prot |= PROT_WRITE
						; Ecx already contains size
	mov	ebx, 0				; *addr = NULL
	mov	eax, 192			; Mmap system call
	int	0x80
	cmp	eax, -1				; Eax is -1 if there is an error
	je	mmaperror

	pop	ebp				; Restore all registers from the stack
	pop	edi
	pop	esi
	
	mov    	[noread], ecx			; Size
;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------


;_________________________________________________________________________________________________________
;------------------------------------ CREATING THE ARRAY OF POINTERS -------------------------------------

	push 	eax				; Save eax (the starting address of the strings)
	xor	edx, edx     			; Clear ebx to count
	mov 	edi, eax			; First address of the mapped file

validate_tabs:
	movzx 	ecx, byte[eax]			; Check a single string
	cmp	ecx, DELIMITER			; Compare with tab
	je	firstptr			; If tab, go to firstptr
	cmp	edx, [noread]			; Ecx contains size
	je	no_tab_found			; If no tab found, print string
	inc 	edx				
	inc 	eax
	jmp	validate_tabs			; Validate the tabs of the file
     
no_tab_found:
	printToFile edi, edx			; Print a single string to file
	jmp 	exit				; Done with special case (one string)

;---------------------------------------------------------------------------------------------------------

firstptr:
	mov	edx, 1				; Counter for number of characters in the file  
	pop	eax
	xor	ebx, ebx			; Ebx is offset
	mov	[pointers], eax			; [pointers + 0] is the first pointer
						; Print	eax, 1
parsestring:
	inc 	eax
	inc 	edx
	movzx 	ecx, byte [eax]			; Get first byte or character
	cmp 	ecx, 0xa			; Compare with '\n'
	je  	change_last_char		; If ecx = EOL(\n), jump to printLat
	cmp 	edx, [noread]			; If edx = size, read from file
	je	no_eol
	cmp	ecx, DELIMITER			; If ecx is a tab, jump to tab_case
	je 	tab_case			
	jmp 	parsestring			; Repeat for every byte
	
no_eol:
	inc 	eax
	jmp	change_last_char
	
tab_case:
	inc	eax
	inc     edx
	add     ebx, 4				; Increment offset += 4, the index of pointers
	mov	[ebx + pointers], eax   	; Copy next address into pointers
	jmp	parsestring
	
change_last_char:
	mov	byte[eax], DELIMITER		; Change the last char if it is an EOL or a non-existing char
;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------


;_________________________________________________________________________________________________________
;------------------------------------------ SORTING ------------------------------------------------------
	
sort:						
	mov	eax, ebx			; Ebx contains the last offset 4 * numberItems - 4
	xor	edx, edx			; Clear edx for division
	mov	ecx, 4				; Move 4 to ecx (initial value)
	div	ecx				; After division edx:eax will have numberItems - 1	
	
	push	eax 				; Second arg = eax
	push	dword pointers			; First	arg = pointers array	
	call	QUICK				; Call QUICK procedure

;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------


;_________________________________________________________________________________________________________
;------------------------------------- PRINTING TO FILE --------------------------------------------------
	
	xor	eax, eax			; Offset
	add	ebx, 4				; 4n
	
getPointer:	
        mov	esi, [pointers+eax]     	; Esi is the starting address of the array of pointers
        add 	eax, 4				; Increment offset
        cmp 	eax, ebx			; Compare offset with 4n (n = numberItems)
        jg	exit				; If greater, we are done

	xor	edx, edx			; Clear edx
	mov 	edi, esi			; Copy the original address
	
getSize:    
	movzx	ecx, byte[esi]			; Get a byte from esi array of pointers
	inc 	edx				; Increment edx that stores size of file
	inc 	esi				; Increment esi for the next byte
	cmp	ecx, DELIMITER			; Compare ecx to \t
	je	printPointer	  		; If equals, skip to print pointer
	jmp 	getSize				; Else, tab was not found. Loop again
	
printPointer:	
	printToFile edi, edx			; Call printToFile macro
	jmp	getPointer			; Go back to getPointer

exit:                                        
        mov     eax, SYS_EXIT			; We are done saving the output file
        mov     ebx, 0
        int     0x80

;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------


;_________________________________________________________________________________________________________
;------------------------------------- ERROR HANDLING ----------------------------------------------------

openerror:
        print2  "Could not open the file"
        jmp     exiterror
createrror:
	print2	"Could not create the file"
	jmp	exiterror        
        
fstaterror:
        print2  "Could not fstat the file"
        jmp     exiterror

mmaperror:
	print2 "Mmap failed"
	jmp	exiterror

readerror:
	print2	"Could not read the file"
	jmp	exiterror
	
writerror:
	print2	"Could not write the file"
	jmp	exiterror

exiterror:                                
        mov     eax, SYS_EXIT
        mov     ebx, -1
        int     0x80

;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------


;_________________________________________________________________________________________________________
;-------------------------------------- FUNCTIONS --------------------------------------------------------

compareTo:           			;compareTo( char * a, char * b, int size)
        
       pushad				; Store registers in stack
       mov	esi, [esp+36]		; First argument	
       mov	edi, [esp+40]		; Second argument

L1:
	movzx	eax, byte[esi]		; Get a character of both arguments and compare them	
	inc	esi	
	movzx	ebx, byte[edi]
	inc	edi
	cmp	eax, DELIMITER		; Check to see if there is a \t
	je 	tab_found

substract:  	
	sub	eax, ebx		; Subtract both characters
	cmp	eax, 0			; If they are not equal, we are done
	jne	doneL1			; Else, compare the next character
	jmp	L1
	
tab_found:
	cmp	ebx, DELIMITER		; Check to see if ebx is also a \t
	je	equal_case
	jmp 	substract		; If not, continue with substract
		
equal_case:
	mov	eax, 0			; Just in case
	
doneL1:
	mov	[esp+36], eax		; Move result from the function to the stack
	mov	[esp+40], dword 0	; Garbage to balance the stack
	popad				; Restore registers from stack
	
	ret				; Return from call      

QUICK:
	push 	ebp			; Save registers that will be used
	mov 	ebp, ESP
	push	ebx
	push 	esi
	push 	edi
	
	mov 	esi, [ebp+8]    	; Get array
	mov 	eax, [ebp+12]		; Get number of items
	
	mov 	ecx, 4			; Ecx = 4 for 4n multiplication
	mul 	ecx			
	mov 	ecx, eax
	
	xor 	eax, eax		; Eax = low
	mov 	ebx, ecx		; Ebx = high
	
	call 	RECURSION		; Sort the file

	pop 	edi			; Restore registers
	pop 	esi
	pop 	ebx
	pop 	ebp

	ret

RECURSION:
	cmp 	eax, ebx		; If low is greater or equal than high
	jge 	finish			; We are done
	
	push 	eax			; Else save low and high    
	push 	ebx    
	add 	ebx, 4  		; Prepare ebx for next pointer
	mov 	edi, [esi+eax]		; Edi = pivot point for QuickSort

outsideLoop:

loopi:
	add 	eax, 4			; Increase low pointer until low >= high
	cmp 	eax, ebx
	jge 	finish_loopi
	
	push 	edi  			; Call compareTo function for strings
	push 	dword[esi+eax] 
	call 	compareTo
	pop  	dword[cmpR]		
	pop  	dword[garbage]
	
	cmp 	dword[cmpR], 0		; Compare results
	jge 	finish_loopi		; Greater than 0? We are done
	jmp 	loopi

finish_loopi:			

loopj:
	sub 	ebx, 4			; Decrease high pointer until high <= low 
	
	push 	edi			; Call compareTo function for strings
	push 	dword [esi+ebx]
	call 	compareTo
	pop 	dword[cmpR]	 
	pop 	dword[garbage]
	
	cmp 	dword[cmpR], 0		; Compare resutls
	jle 	finish_loopj		; Lower than 0? We are done
	jmp 	loopj
	
	cmp 	eax, ebx

finish_loopj:
	cmp 	eax, ebx		; Swap function
	jge 	end_outsideLoop	
	
	push 	dword[esi+eax]		; Uses stack to swap two dwords
	push 	dword[esi+ebx]
	pop 	dword[esi+eax]
	pop 	dword[esi+ebx]
	
	jmp 	outsideLoop

end_outsideLoop:        
	pop 	edi
	pop 	ecx
	cmp 	ecx, ebx
	je 	end_Swap
	
	push 	dword[esi+ecx]		; Uses stack to swap two dwords
	push 	dword[esi+ebx]
	pop 	dword[esi+ecx]
	pop 	dword[esi+ebx]

end_Swap:
	mov 	eax, ecx 
	push 	edi    
	push 	ebx    
	sub 	ebx, 4  

	call 	RECURSION

	pop 	eax
	add 	eax, 4  
	pop	ebx

	call 	RECURSION

finish:
	ret

;_________________________________________________________________________________________________________
;---------------------------------------------------------------------------------------------------------