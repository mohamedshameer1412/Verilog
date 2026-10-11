#!/usr/bin/env python3
"""Minimal assembler for the supported RV32I subset -> $readmemh hex (one word/line).

usage: asm.py prog.S prog.hex
Supported: add sub and or xor slt addi andi ori xori slti lw sw beq bne jal
Labels ("name:"), '#' comments, registers x0..x31, immediates dec/hex.
"""
import re, sys

R = {'add': (0x00, 0b000), 'sub': (0x20, 0b000), 'and': (0x00, 0b111),
     'or': (0x00, 0b110), 'xor': (0x00, 0b100), 'slt': (0x00, 0b010)}
I = {'addi': 0b000, 'andi': 0b111, 'ori': 0b110, 'xori': 0b100, 'slti': 0b010}


def reg(t):
    m = re.fullmatch(r'x(\d+)', t.strip())
    if not m or int(m.group(1)) > 31:
        raise ValueError(f'bad register {t!r}')
    return int(m.group(1))


def enc(op, a, pc, labels):
    def imm(t, lo, hi):
        v = labels[t] - pc if t in labels else int(t, 0)
        if not lo <= v <= hi:
            raise ValueError(f'immediate {v} out of range for {op}')
        return v
    if op in R:
        f7, f3 = R[op]
        return (f7 << 25) | (reg(a[2]) << 20) | (reg(a[1]) << 15) | (f3 << 12) | (reg(a[0]) << 7) | 0x33
    if op in I:
        return ((imm(a[2], -2048, 2047) & 0xFFF) << 20) | (reg(a[1]) << 15) | (I[op] << 12) | (reg(a[0]) << 7) | 0x13
    if op in ('lw', 'sw'):
        m = re.fullmatch(r'(-?\w+)\((x\d+)\)', a[1].strip())
        if not m:
            raise ValueError(f'bad memory operand {a[1]!r}')
        i = imm(m.group(1), -2048, 2047) & 0xFFF
        rb = reg(m.group(2))
        if op == 'lw':
            return (i << 20) | (rb << 15) | (0b010 << 12) | (reg(a[0]) << 7) | 0x03
        return ((i >> 5) << 25) | (reg(a[0]) << 20) | (rb << 15) | (0b010 << 12) | ((i & 0x1F) << 7) | 0x23
    if op in ('beq', 'bne'):
        o = imm(a[2], -4096, 4094) & 0x1FFF
        f3 = 0b000 if op == 'beq' else 0b001
        return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (reg(a[1]) << 20) | (reg(a[0]) << 15) | \
               (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | 0x63
    if op == 'jal':
        o = imm(a[1], -(1 << 20), (1 << 20) - 2) & 0x1FFFFF
        return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
               (((o >> 12) & 0xFF) << 12) | (reg(a[0]) << 7) | 0x6F
    raise ValueError(f'unsupported instruction {op!r}')


def main(src, dst):
    lines, labels, pc = [], {}, 0
    for raw in open(src):
        t = raw.split('#')[0].strip()
        while ':' in t:
            lab, t = t.split(':', 1)
            labels[lab.strip()] = pc
            t = t.strip()
        if t:
            lines.append((pc, t, raw.rstrip()))
            pc += 4
    out = []
    for pc, t, raw in lines:
        parts = t.split(None, 1)
        args = [x.strip() for x in parts[1].split(',')] if len(parts) > 1 else []
        w = enc(parts[0], args, pc, labels)
        out.append(f'{w:08x}')
        print(f'{pc:04x}: {w:08x}  {t}')
    open(dst, 'w').write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
