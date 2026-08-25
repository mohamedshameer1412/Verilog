# SystemVerilog Learning Curriculum
## UNIT I & II – Complete Practical Guide

A hands-on, structured guide to SystemVerilog for VLSI Design Verification.

---

## Folder Structure

```
Verilog/
+-- README.md                          ? You are here
+-- UNIT_I/
¦   +-- 01_VLSI_Overview/
¦   ¦   +-- notes.md                  ? Theory: VLSI Flow, SoC, IP
¦   +-- 02_SV_Basics/
¦       +-- 01_hello_world.sv          ? Intro: modules, initial, $display
¦       +-- 02_data_types.sv           ? logic, bit, int, enum, struct, union
¦       +-- 03_operators.sv            ? All operators with examples
¦       +-- 04_arrays.sv               ? Fixed, Dynamic, Associative, Queues
¦       +-- 05_interfaces.sv           ? Interfaces, modports, clocking blocks
+-- UNIT_II/
    +-- 01_Procedural_Statements/
    ¦   +-- 01_procedural.sv           ? always_ff/comb, if/case, loops, fork-join
    +-- 02_Processes/
    ¦   +-- 01_processes.sv            ? Events, Semaphores, Mailboxes
    +-- 03_Tasks_Functions/
    ¦   +-- 01_tasks_functions.sv      ? Tasks, Functions, Automatic, Recursive
    +-- 04_OOP_Classes_Objects/
    ¦   +-- 01_classes_objects.sv      ? Classes, Objects, new(), this, static
    +-- 05_Randomization_Constraints/
    ¦   +-- 01_randomization.sv        ? rand/randc, constraints, dist, solve-before
    +-- 06_Inheritance_Polymorphism/
        +-- 01_inheritance_polymorphism.sv  ? extends, virtual, $cast, abstract
```

---

## Curriculum Map

### UNIT I – VLSI Development Flow & SystemVerilog Basics

| # | File | Topics |
|---|------|--------|
| 1 | `01_VLSI_Overview/notes.md` | VLSI Tech, IP types, SoC architecture, RTL?GDSII flow, Verification flow |
| 2 | `02_SV_Basics/01_hello_world.sv` | Module, initial block, $display, #delay, $monitor, $finish |
| 3 | `02_SV_Basics/02_data_types.sv` | logic, bit, byte, int, real, string, enum, struct, union, typedef, parameter |
| 4 | `02_SV_Basics/03_operators.sv` | Arithmetic, Relational (==/===), Logical, Bitwise, Reduction, Shift, Ternary, Concatenation |
| 5 | `02_SV_Basics/04_arrays.sv` | Fixed, Dynamic (new[]), Associative (dict), Queue ($), sort/find/sum methods |
| 6 | `02_SV_Basics/05_interfaces.sv` | Interface, modport, clocking block, interface tasks, virtual interface |

### UNIT II – Advanced SystemVerilog Concepts

| # | File | Topics |
|---|------|--------|
| 7 | `01_Procedural_Statements/01_procedural.sv` | always_comb/ff/latch, if-else, case/casez, for/while/do-while/foreach/repeat/forever, break/continue, fork-join/any/none |
| 8 | `02_Processes/01_processes.sv` | Events (->/@), Semaphores (get/put), Mailboxes (put/get/peek), producer-consumer |
| 9 | `03_Tasks_Functions/01_tasks_functions.sv` | Functions (return), Tasks (delay), automatic, void, recursive, inout args |
| 10 | `04_OOP_Classes_Objects/01_classes_objects.sv` | class, properties, methods, new(), this, static, local/protected, copy |
| 11 | `05_Randomization_Constraints/01_randomization.sv` | rand/randc, constraint blocks, inside, dist, implication, solve-before, pre/post_randomize |
| 12 | `06_Inheritance_Polymorphism/01_inheritance_polymorphism.sv` | extends, super, virtual, override, abstract class, $cast, polymorphism |

---

## How to Run

### Option 1: EDA Playground (FREE, no install needed)
1. Go to https://www.edaplayground.com
2. Create account (free)
3. Select: **Language** = SystemVerilog/Verilog, **Simulator** = Aldec Riviera-PRO or Synopsys VCS
4. Paste the code and click Run

### Option 2: Icarus Verilog (Free, install locally)
```bash
# Install (Windows)
# Download from: http://bleyer.org/icarus/
iverilog -g2012 -o out 01_hello_world.sv && vvp out
```

### Option 3: ModelSim / QuestaSim
```bash
vlog -sv 01_hello_world.sv
vsim -c work.hello_world -do "run -all; quit"
```

### Option 4: VCS (Synopsys)
```bash
vcs -sverilog -o sim 01_hello_world.sv && ./sim
```

---

## Recommended Study Order
1. Read `UNIT_I/01_VLSI_Overview/notes.md` (theory)
2. Run `01_hello_world.sv` — just get it working!
3. Work through `02_data_types.sv` — understand each type
4. Do `03_operators.sv` — try each exercise
5. `04_arrays.sv` — practice dynamic arrays especially
6. `05_interfaces.sv` — critical for real verification work
7. `01_procedural.sv` — master fork-join!
8. `01_processes.sv` — events/semaphores/mailboxes are everywhere in UVM
9. `01_tasks_functions.sv` — know automatic vs static
10. `01_classes_objects.sv` — foundation of OOP in SV
11. `01_randomization.sv` — constrained random is THE CORE of SV verification
12. `01_inheritance_polymorphism.sv` — powers UVM component hierarchy

---

## Key Concepts Cheatsheet

```systemverilog
// Data types
logic [7:0] x;          // 4-state
bit   [7:0] y;          // 2-state (faster)
int i; real r;           // integer / float
string s = "hello";
enum {A, B, C} e;
typedef struct {int id; logic v;} pkt_t;

// Arrays
int fixed[8];            // fixed
int dyn[];  dyn=new[8]; // dynamic
int aa[string];          // associative
int q[$];                // queue

// Interface
interface my_if(input clk);
  logic data, valid;
  modport master(output data, valid, input clk);
endinterface

// Class
class Foo;
  rand int x;
  constraint c { x inside {[0:100]}; }
  function new(); x=0; endfunction
  virtual function void print(); $display(x); endfunction
endclass

// Inheritance
class Bar extends Foo;
  function new(); super.new(); endfunction
  virtual function void print(); super.print(); endfunction
endclass
```

---

> Made for learning SystemVerilog from scratch to advanced verification concepts.
