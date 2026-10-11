# Sample program: arithmetic loop -> data memory -> APB timer.
# Expected final state: x2=55 x3=55 x7=1 x9=0 x10=0x40000000, dmem[64]=55
        addi x1, x0, 10
        addi x2, x0, 0
loop:   add  x2, x2, x1          # x2 = 10+9+...+1
        addi x1, x1, -1
        bne  x1, x0, loop
        sw   x2, 256(x0)         # dmem word 64 = 55
        lw   x3, 256(x0)
        addi x10, x0, 1          # no LUI in the subset: build 0x4000_0000 = 1<<30
        addi x4, x0, 30
dbl:    add  x10, x10, x10
        addi x4, x4, -1
        bne  x4, x0, dbl
        addi x5, x0, 4
        sw   x5, 8(x10)          # RELOAD  = 4
        sw   x5, 4(x10)          # COUNTER = 4
        addi x6, x0, 3
        sw   x6, 0(x10)          # CONTROL = enable | auto-reload
poll:   lw   x7, 12(x10)         # poll STATUS.expired
        beq  x7, x0, poll
        sw   x0, 0(x10)          # stop timer
        addi x8, x0, 1
        sw   x8, 12(x10)         # STATUS W1C
        lw   x9, 12(x10)         # reads 0
halt:   jal  x0, halt
