# GPIO-Bank-32-bit-with-Debounce-Interrupts
Full APB based 32 bit GPIO peripheral featuring 2FF input synchronization, programmable debounce, edge/level interrupt controller, and a clean top level integration of pins and APB register file.

# 32-Bit APB GPIO Bank with Debounce & Interrupts (Verilog HDL)

**Author:** Noam Malca  
**Institution:** Bar-Ilan University  
**Focus:** Digital Design - GPIO, APB, Debounce, and Interrupts

This project implements a complete 32-bit GPIO peripheral in Verilog HDL, suitable for integration into APB-based SoC designs.  
It includes a memory-mapped APB register file, a 2-flop input synchronizer, per-bit digital debounce, a configurable edge/level interrupt controller, and a self-checking SystemVerilog testbench (`tb_gpio_32`) that verifies GPIO direction, debounce behavior, and interrupt functionality.

The design is fully modular and built from the ground up to handle real-world GPIO use cases such as button inputs, status signals, and event-driven interrupts, while protecting against metastability and mechanical switch bounce.

---

## Table of Contents

- [Introduction](#introduction)
- [System Overview](#system-overview)
- [Modules Description](#modules-description)
    - [APB Register Map](#apb-register-map)
- [Data & Control Flow](#data--control-flow)
- [Verification Testbench](#verification-testbench)
    - [Test 1 Analysis](#Test 1 Analysis (Direction & Output))
- [Simulation and Waveforms](#simulation-and-waveforms)
- [License](#license)

---

## Introduction

This project demonstrates a robust 32-bit General-Purpose Input/Output (GPIO) peripheral with:

- APB slave interface for CPU/bus access  
- 32 configurable pins (input or output per bit)  
- 2-flip-flop synchronization for asynchronous external inputs  
- Programmable debounce in clock cycles for all input bits  
- Configurable edge and level interrupts with per-bit masking and polarity  
- A single bank-level interrupt output (`gpio_irq`)

The system is implemented and verified in Verilog/SystemVerilog using a 100 MHz clock (`PCLK`) with a VCD waveform dump (`dump.vcd`) for inspection in tools such as GTKWave.

---

## System Overview

The design is split into four main RTL blocks, connected by a clean top-level module:

- **`gpio_32_apb_regs`** – APB register file  
- **`gpio_32_pins`** – pad interface + 2-FF synchronizer  
- **`gpio_32_debounce`** – per-bit digital debounce engine  
- **`gpio_32_interrupts`** – edge/level interrupt controller  

Top-level module: **`gpio_32_top`** Testbench: **`tb_gpio_32`**

---

## Modules Description

- **RTL Modules Breakdown**

    - **GPIO Top-Level** – [`gpio_32_top.v`](Verilog_Code/gpio_32_top.v)  
      The integration layer that connects the APB bus interface to the internal logic blocks. It handles the signal routing between the register file and the functional units (debounce, interrupt, pins).
      - **Key Feature:** Acts as the bridge between the system clock domain (`PCLK`) and the external asynchronous world.

    - **APB Register File** – [`gpio_32_apb_regs.v`](Verilog_Code/gpio_32_apb_regs.v)  
      A memory-mapped register bank compliant with the APB protocol. It manages configuration and status reporting.

      **Register Address Map (Offsets):**
      | Offset | Name | Type | Description |
      | :--- | :--- | :--- | :--- |
      | `0x00` | **GPIO_DIR** | RW | Direction Control (0=Input, 1=Output). |
      | `0x04` | **GPIO_OUT** | RW | Output Data Register (Value to drive when DIR=1). |
      | `0x08` | **GPIO_IN** | RO | Input Data Register (Read-only, debounced value). |
      | `0x0C` | **INT_MASK** | RW | Interrupt Mask (1=Enable, 0=Masked). |
      | `0x10` | **INT_STATUS** | RW1C | Interrupt Status (Write '1' to Clear). Sticky bit. |
      | `0x14` | **INT_TYPE** | RW | Interrupt Type (0=Level, 1=Edge). |
      | `0x18` | **INT_POL** | RW | Polarity (0=Fall/Low, 1=Rise/High). |
      | `0x1C` | **DEBOUNCE** | RW | Debounce Duration (16-bit cycle count). |

    - **Pin Interface + 2-FF Synchronizer** – [`gpio_32_pins.v`](Verilog_Code/gpio_32_pins.v)  
      The physical interface layer.
      - **Synchronization:** Uses a standard **2-Flip-Flop synchronizer** chain to mitigate metastability risks when asynchronous external signals enter the `PCLK` domain.
      - **Tri-State Control:** Implements the buffer logic where `gpio_dir` acts as the Output Enable (OE) for the pads.

    - **Debounce Engine** – [`gpio_32_debounce.v`](Verilog_Code/gpio_32_debounce.v)  
      Filters out noise and mechanical switch bounce.
      - **Algorithm:** Maintains a dedicated counter for each of the 32 bits. The counter increments only when the signal is stable. If the signal changes value before the target count (`debounce_cfg`) is reached, the counter resets. This ensures only "clean" transitions are propagated.

    - **Interrupt Controller** – [`gpio_32_interrupts.v`](Verilog_Code/gpio_32_interrupts.v)  
      A flexible interrupt generation unit.
      - **Logic:** Combines the synchronized/debounced inputs with the configuration registers (Mask, Type, Polarity).
      - **Status Handling:** Implements "Sticky" status bits—once an event is detected, the bit remains set until explicitly cleared by software (W1C), ensuring no events are missed by the CPU.

    - **Verification Testbench** – [`tb.v`](Verilog_Code/tb.v)  
      A comprehensive SystemVerilog testbench.
      - **Tests:** Includes directed tests for basic I/O, glitch injection (to prove debounce), rising-edge detection, and level-triggered interrupt clearance sequences.

---

## Data & Control Flow

The architecture is designed around a unidirectional data flow for configuration and a bidirectional flow for I/O operations. The system ensures safe clock-domain crossing and noise immunity before signals reach the internal logic.

```mermaid
graph TD
    subgraph "CPU / Bus Master"
    APB[APB Bus Interface]
    end

    subgraph "GPIO Peripheral (Top Level)"
    Regs["APB Register File<br/>(gpio_32_apb_regs.v)"]
    IntCtrl["Interrupt Controller<br/>(gpio_32_interrupts.v)"]
    Debounce["Debounce Engine<br/>(gpio_32_debounce.v)"]
    Sync["Pin Interface & Sync<br/>(gpio_32_pins.v)"]
    end

    subgraph "External World"
    Pads((Physical Pads))
    end

    %% APB Interface
    APB -- "PADDR, PWDATA, Control" --> Regs
    
    %% Internal Logic Flow
    Regs -- "gpio_out / dir" --> Sync
    Regs -- "Config (Debounce Cycles)" --> Debounce
    
    Regs -- "Enables (Rise/Fall/Level)" --> IntCtrl

    %% Output to Pads
    Sync -- "Drive Output" --> Pads

    %% Input from Pads
    Pads -- "Raw Input" --> Sync
    Sync -- "Synchronized" --> Debounce
    
    %% Split Flows
    Debounce -- "Stable Signal" --> Regs
    Debounce -- "Clean Edges / Levels" --> IntCtrl

    %% Returns to CPU
    Regs -- "PRDATA (Read)" --> APB
    
    %% Interrupt Notification
    IntCtrl -- "Event Notification (IRQ)" --> APB
```


## Verification Testbench

The project includes a comprehensive Verilog testbench (`tb_gpio_32.sv`) that performs the following automated tests:

1.  **Direction & Output Test:** Configures pins as outputs and verifies driven values.
2.  **Debounce Logic Test:** Injects short glitches (ignored) and long stable signals (accepted) to verify the debounce counter.
3.  **Interrupt Logic Test:** Triggers edge events and verifies that the IRQ signal asserts and clears correctly upon Write-1-to-Clear.

### Test 1 Analysis (Direction & Output)

The first test in the verification environment focuses on validating basic APB write operations to the GPIO direction register (`GPIO_DIR`) and the output data register (`GPIO_OUT`).  
This test demonstrates correct APB timing, register update behavior, and propagation of control signals into the GPIO pins module.

#### Waveform Analysis - Step-by-Step

**1. Direction Configuration (`GPIO_DIR`):** Upon the clock's rising edge, the testbench asserts `PSEL` and `PWRITE`, while updating `PWDATA` to `0xFF`. Although `PADDR` points to `0x00` (which might not show a visible transition if the bus was previously zero), the address is valid.  
Crucially, the data is latched into the internal `gpio_dir` register (in the APB module) only when **`PENABLE` asserts high** (Access Phase). This update immediately propagates to the Pins module, where `gpio_oe` (Output Enable) is updated to match. This confirms that the 8 Least Significant Bits (LSBs) are now configured as **outputs**.

**2. Output Data Drive (`GPIO_OUT`):** Subsequently, a write transaction targets `ADDR_GPIO_OUT`. `PADDR` updates to `0x04` and `PWDATA` updates to `0xA5A500FF`.  
On the next rising edge when **`PENABLE` asserts high**, the `gpio_out_reg` updates, and simultaneously `gpio_out` reflects the value `0xA5A500FF`.

**Observation (Masking Effect):** Although `gpio_out` holds the full `0xA5A500FF` pattern, since we only configured the lower 8 bits as OUTPUTs in the previous step, the physical effect is **masked**:
- Only the `0xFF` portion is actively driven to the physical pads.
- The upper bits (`0xA5A5...`), despite having data in the register, remain in a high-impedance state (Hi-Z) externally.

<img width="1614" height="362" alt="image" src="https://github.com/user-attachments/assets/f23ba249-fd70-43f2-b9df-fc01a708cbc2" />


