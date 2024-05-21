.data
.align 1
.byte 0
.byte 0
header: .space 54 
filename: .asciz "mandelbrot.bmp"

    .text
    .globl load_header
    
# ------------------------------
# s0 - image width
# s1 - image height
# s2 - image size in bytes
# s3 - heap address
# s4 - padding offset

# ------------------------------

load_header:
    # Opening file in read-only mode
	li a7, 1024
	li a1, 0
	la a0, filename
	ecall
	

    # Saving file descriptor in s6 register
	mv s6, a0

    # File descriptor is in a0 register
	li a7, 63
	la a1, header
	li a2, 54 # Header is 54-bytes long
	ecall

    # Header has been successfully loaded, we can close the file
    	li a7, 57
    	mv a0, s6
    	ecall

get_file_info:

	la t0, header

    # Image size in bytes stored in s2 register
	addi t0, t0, 2
	lw s2, (t0)

    # Image width loaded into s0 register
   	addi t0, t0, 16
  	lw s0, (t0)

   
    # Image height loaded into s1 register
	addi t0, t0, 4
	lw s1, (t0)
	mv s9, s1

	
    # Calculating padding
    	andi s4, s0, 3

prepare_image_creation:
    # s8 - RE_START
    # s7 - RE_END
    # s6 - IM_START 
    # s5 - IM_END
	li s8, -2
	slli s8, s8, 20
	li s7, 1
	slli s7, s7 20
	li s6, -1
	slli  s6, s6, 20
	li s5, 1
	slli s5, s5, 20



    # Creatin heap memory with starting address in s3 register
	li a7, 9
	mv a0, s2
	ecall
	mv s3, a0
	
	mv t0, s3
	li t1, 0

recreate_header:
	la t6, header
	li t5, 54

recreate_header_loop:
	lb t4, (t6)
	addi t6, t6, 1
	sb t4, (t0)
	addi t0, t0, 1
	addi t5, t5, -1
	bnez t5, recreate_header_loop

row_loop:
	j compute_pixel_colour
after_computing_in_loop:
	sb t6, (t0)
	addi t0, t0, 3
	

	addi t1, t1, 1
	bne t1, s0, row_loop

main_loop:
    # Adding padding
	add t0, t0, s4

    # Checkig for image end
	addi s1, s1, -1
	li t1, 0
	bnez s1, row_loop
	

save_to_file: 

    # Saving file descriptor to s4 register
	li a7, 1024
	la a0, filename
	li a1, 1
	ecall
	mv s6, a0
 
	li a7, 64
	mv a1, s3
	mv a2, s2
	ecall

	li a7, 57
    	mv a0, s6
    	ecall

end:
	li a7, 1
	li a0, 10
	ecall
	li a7, 10
	ecall

compute_pixel_colour:
    # a0 - x
    # a1 - y
    # s1 - pixel  y
    # t1 - pixel x
    # s9 - HEIGHT
    # s0 - WIDTH
    # 12.20 - Fixed point arithetic format


	slli t2, t1, 20
	divu a0, t2, s0
	
	sub t2, s7, s8 # RE_END - RE_START
	mv a6, a0
	mv a7, t2
	jal multiply_fixed_point


	add a0, s8, t3
	# Ukoñczonno RE
	
	slli t2, s1, 20
	divu a1, t2, s9
	sub t2, s5, s6 # IM_END - IM_START

	mv a6, a1
	mv a7, t2
	jal multiply_fixed_point
	add a1, s6, t3

	# Ukoñczonno IM

# a2 - Re(z)
# a3 - Im(z)
# a4 - MAX_ITER
# t6 - i
# t5 - limit
computing_header:
	li t5, 4
	slli t5, t5, 20
	li t6, 0
	li a2, 0
	li a3, 0
	li a4, 63

computing_loop:
	# z*z = (a + ib)^2 = a^2 - b^2 + 2abi
	mv a6, a2
	mv a7, a2
	jal multiply_fixed_point # a^2
	mv t2, t3
	
	mv a6, a3
	mv a7, a3
	jal multiply_fixed_point # b^2
	mv s10, t3
	
	mv a6, a2
	mv a7, a3
	jal multiply_fixed_point # ab
	mv s11, t3
	
	slli a3, s11, 1 # 2ab
	sub a2, t2, s10 # a^2 - b^2
	
	add a2, a2, a0 # Adding Re(p)
	add a3, a3, a1 # Adding Im(p)
	
	
    # Calculating |z|
	mv a6, a2
	mv a7, a2
	jal multiply_fixed_point # Re(z)^2
	mv t2, t3 
	
	mv a6, a3
	mv a7, a3
	jal multiply_fixed_point # Im(z)^2
	
	add t2, t2, t3 # Re(z)^2 + Im(z)^2 = |z|^2
	
	addi t6, t6, 1
	bgt t2, t5, end_computing # |z| > 2
	bge t6, a4, end_computing # n >= iterations
	j computing_loop
	
end_computing:
	slli t6, t6, 2
	j after_computing_in_loop


multiply_fixed_point:
# arguments in a7 and a6 registers
# Multiplying integer values
# a5, t2, t3 and t4 are assistant
# return in t3
	mul t4, a6, a7
	mulh t3, a6, a7
	srli t4, t4, 20
	slli t3, t3, 12
	or t3, t3, t4
	ret