# Parameterized DRAM Behavioral Model

## Overview

This project implements a **parameterized behavioral model of a DRAM (Dynamic Random-Access Memory)** using Verilog HDL.

The model represents the basic operation of a DRAM with:

* Row and column addressing
* RAS (Row Address Strobe)
* CAS (Column Address Strobe)
* Lower and upper byte write enables
* Output enable
* Bidirectional data bus
* CAS-before-RAS (CBR) refresh detection
* Parameterized memory size and word width

The design is intended for **RTL/Verilog learning, functional simulation, and verification** of DRAM-like memory behavior.

> **Note:** This is a behavioral simulation model and is not intended to be synthesized into physical DRAM hardware.

---

## Features

* Parameterized **word size**
* Parameterized **number of rows and columns**
* Multiplexed address input
* Row address capture using `RAS_N`
* Column address capture using `CAS_N`
* Lower-byte and upper-byte write operations
* Full-word write operation
* Tri-state bidirectional data bus
* Read operation controlled by `OE_N`
* CAS-before-RAS (CBR) refresh detection
* Refresh row counter
* Linear address generation from row and column addresses

---

## Module Parameters

The DRAM size and word width can be configured using parameters.

```verilog
module parameterized_DRAM #(
    parameter WORD_SIZE = 16,
    parameter ROWS      = 32,
    parameter COLUMNS   = 32
)
```

| Parameter   | Default Value | Description                        |
| ----------- | ------------- | ---------------------------------- |
| `WORD_SIZE` | 16            | Number of bits in each memory word |
| `ROWS`      | 32            | Number of rows in the DRAM         |
| `COLUMNS`   | 32            | Number of columns in the DRAM      |

### Default Memory Configuration

With the default parameters:

```text
WORD_SIZE = 16 bits
ROWS      = 32
COLUMNS   = 32
```

Total number of memory locations:

```text
32 × 32 = 1024 locations
```

Total memory capacity:

```text
1024 × 16 bits = 16384 bits = 2 KB
```

---

## Module Interface

```verilog
module parameterized_DRAM #(
    parameter WORD_SIZE = 16,
    parameter ROWS      = 32,
    parameter COLUMNS   = 32
)(
    input  [$clog2((ROWS>COLUMNS)?ROWS:COLUMNS)-1:0] MA,
    input  RAS_N,
    input  CAS_N,
    input  LWE_N,
    input  UWE_N,
    input  OE_N,
    inout  [WORD_SIZE-1:0] DATA
);
```

### Signals

| Signal  | Direction | Description                                               |
| ------- | --------- | --------------------------------------------------------- |
| `MA`    | Input     | Multiplexed address bus used for row and column addresses |
| `RAS_N` | Input     | Active-low Row Address Strobe                             |
| `CAS_N` | Input     | Active-low Column Address Strobe                          |
| `LWE_N` | Input     | Active-low lower-word/byte write enable                   |
| `UWE_N` | Input     | Active-low upper-word/byte write enable                   |
| `OE_N`  | Input     | Active-low output enable                                  |
| `DATA`  | Inout     | Bidirectional data bus                                    |

`_N` indicates that the corresponding control signal is **active low**.

---

## DRAM Organization

The memory is modeled as a two-dimensional logical organization:

```text
             COLUMNS
        0   1   2   ... 31
      +---+---+---+-----+
Row 0 |   |   |   | ... |
      +---+---+---+-----+
Row 1 |   |   |   | ... |
      +---+---+---+-----+
 ...  |   |   |   | ... |
      +---+---+---+-----+
Row31 |   |   |   | ... |
      +---+---+---+-----+
```

Internally, the memory is implemented as a one-dimensional array:

```verilog
reg [WORD_SIZE-1:0] mem[0:(ROWS*COLUMNS)-1];
```

The linear memory address is calculated as:

```verilog
linear_address = (row_address * COLUMNS) + column_address;
```

Therefore:

```text
Linear Address = Row Address × Number of Columns + Column Address
```

---

## Address Multiplexing

The same `MA` bus is used for both row and column addresses.

### Row Address

When `RAS_N` transitions from HIGH to LOW:

```verilog
if(!RAS_N && last_ras)
    row_address = MA;
```

The value on `MA` is captured as the row address.

### Column Address

When `CAS_N` transitions from HIGH to LOW:

```verilog
if(!CAS_N && last_cas)
    column_address = MA;
```

The value on `MA` is captured as the column address.

This models the address multiplexing commonly used in DRAM interfaces.

---

## Read Operation

The `DATA` bus is driven by the memory contents when:

```text
OE_N = 0
LWE_N = 1
UWE_N = 1
```

The corresponding Verilog statement is:

```verilog
assign DATA = (!OE_N && LWE_N == 1 && UWE_N == 1) ?
              mem[linear_address] :
              {WORD_SIZE{1'bz}};
```

When output enable is inactive, the data bus is placed in the high-impedance state:

```text
DATA = Z
```

This allows the same bus to be used for both reading and writing.

---

## Write Operation

The model supports three write modes.

### 1. Lower Half Write

When:

```text
LWE_N = 0
UWE_N = 1
```

only the lower half of the word is written.

```verilog
mem[linear_address][(WORD_SIZE/2)-1:0] =
    DATA[(WORD_SIZE/2)-1:0];
```

For a 16-bit word:

```text
DATA[7:0] → Memory[7:0]
```

---

### 2. Upper Half Write

When:

```text
LWE_N = 1
UWE_N = 0
```

only the upper half is written.

```verilog
mem[linear_address][WORD_SIZE-1:(WORD_SIZE/2)] =
    DATA[WORD_SIZE-1:(WORD_SIZE/2)];
```

For a 16-bit word:

```text
DATA[15:8] → Memory[15:8]
```

---

### 3. Full Word Write

When:

```text
LWE_N = 0
UWE_N = 0
```

the complete word is written.

```verilog
mem[linear_address] = DATA;
```

For the default configuration:

```text
DATA[15:0] → Memory[15:0]
```

---

## CBR Refresh

The model also detects a **CAS-before-RAS (CBR) refresh** condition.

A CBR refresh is detected when `CAS_N` becomes active before `RAS_N`:

```verilog
if(!CAS_N && last_cas && RAS_N)
    CBR_refresh_pending = 1;
```

Once a refresh is pending and `RAS_N` becomes active:

```verilog
if(!RAS_N && last_ras && CBR_refresh_pending)
```

the refresh row counter is updated.

```verilog
if(refresh_row == ROWS-1)
    refresh_row = 0;
else
    refresh_row = refresh_row + 1;
```

This models sequential advancement through the DRAM refresh rows.

---

## Internal Registers

The main internal registers are:

| Register              | Purpose                                       |
| --------------------- | --------------------------------------------- |
| `mem`                 | Stores DRAM contents                          |
| `row_address`         | Stores the captured row address               |
| `column_address`      | Stores the captured column address            |
| `refresh_row`         | Tracks the refresh row                        |
| `linear_address`      | Converts row/column address into memory index |
| `last_ras`            | Stores previous RAS state                     |
| `last_cas`            | Stores previous CAS state                     |
| `CBR_refresh_pending` | Indicates a pending CBR refresh               |

---

## Basic Operation

The general DRAM access sequence is:

```text
              Address Bus (MA)
                     |
                     v
             +---------------+
             | Row Address   |
             |   RAS_N       |
             +-------+-------+
                     |
                     v
             +---------------+
             | Column Address|
             |   CAS_N       |
             +-------+-------+
                     |
                     v
             +---------------+
             | Linear Address|
             +-------+-------+
                     |
                     v
             +---------------+
             | DRAM Memory   |
             +-------+-------+
                     |
                     v
               DATA Bus
```

### Read

```text
1. Apply row address on MA
2. Activate RAS_N
3. Apply column address on MA
4. Activate CAS_N
5. Enable OE_N
6. Memory drives DATA
```

### Write

```text
1. Apply row address on MA
2. Activate RAS_N
3. Apply column address on MA
4. Activate CAS_N
5. Drive data on DATA
6. Select LWE_N/UWE_N
7. Data is written into memory
```

---

## Example Configuration

The default configuration creates:

```verilog
parameterized_DRAM #(
    .WORD_SIZE(16),
    .ROWS(32),
    .COLUMNS(32)
) dram_inst (
    .MA(MA),
    .RAS_N(RAS_N),
    .CAS_N(CAS_N),
    .LWE_N(LWE_N),
    .UWE_N(UWE_N),
    .OE_N(OE_N),
    .DATA(DATA)
);
```

Another possible configuration is:

```verilog
parameterized_DRAM #(
    .WORD_SIZE(32),
    .ROWS(64),
    .COLUMNS(64)
) dram_inst (...);
```

This creates:

```text
64 × 64 = 4096 memory locations
4096 × 32 bits = 131072 bits
```

---

## Simulation

This project can be simulated using Verilog simulators such as:

* Icarus Verilog
* ModelSim
* QuestaSim
* Vivado Simulator

A testbench should verify:

* Row address capture
* Column address capture
* Full-word write
* Lower-half write
* Upper-half write
* Read operation
* Tri-state behavior of `DATA`
* CBR refresh detection
* Different parameter configurations

### Example Icarus Verilog Commands

Compile:

```bash
iverilog -o dram_sim parameterized_DRAM.v dram_tb.v
```

Run:

```bash
vvp dram_sim
```

If waveform generation is enabled in the testbench:

```bash
gtkwave dram.vcd
```

---

## Verification Checklist

| Test                   | Expected Result                       |
| ---------------------- | ------------------------------------- |
| Row address capture    | Correct row stored                    |
| Column address capture | Correct column stored                 |
| Full-word write        | Entire word updated                   |
| Lower-half write       | Lower half updated                    |
| Upper-half write       | Upper half updated                    |
| Read                   | Correct memory data appears on `DATA` |
| Output disabled        | `DATA` becomes high impedance         |
| CBR refresh            | Refresh row advances                  |
| Last refresh row       | Refresh counter wraps to zero         |

---

## Important Design Note

This implementation is a **behavioral DRAM model** intended for simulation and functional verification.

It models DRAM concepts such as:

* Multiplexed row/column addressing
* RAS/CAS control
* Write enables
* Bidirectional data
* CBR refresh

It does **not** model physical DRAM characteristics such as:

* Capacitor charge/discharge
* Sense amplifiers
* Precharge circuits
* Timing parameters
* Memory cell leakage
* Physical row activation
* Real DRAM refresh timing

Therefore, the design should be considered a **behavioral simulation model rather than a synthesizable DRAM implementation**.

---

## Project Structure

A recommended project structure is:

```text
Parameterized-DRAM/
│
├── parameterized_DRAM.v
├── dram_tb.v
├── README.md
│
└── waveform/
    └── dram.vcd
```

---

## Applications

This project can be useful for:

* Learning Verilog behavioral modeling
* Understanding DRAM architecture
* Practicing memory modeling
* RTL design practice
* Verification practice
* Understanding multiplexed addresses
* Understanding bidirectional buses
* Studying memory refresh concepts

---

## Future Improvements

Possible extensions include:

* Adding realistic DRAM timing parameters
* Adding setup and hold-time checks
* Implementing row activation/precharge behavior
* Adding refresh timing checks
* Adding burst access support
* Adding self-refresh mode
* Adding a SystemVerilog testbench
* Adding assertions for protocol checking
* Developing a cocotb-based verification environment

---

## Author

**Chintapalli Varun Naga Sai Narayana**

### Project

**Parameterized DRAM Behavioral Model**

### Language

**Verilog HDL**

### Focus

**RTL Design | Memory Design | Digital Design | Verification**
