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
- [Data & Control Flow](#data--control-flow)
- [APB Register Map](#apb-register-map)
- [Verification Testbench](#verification-testbench)
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

* **RTL Modules Breakdown**
    * **GPIO Top-Level** – [`gpio_32_top.v`](gpio_32_top.v)  
        Integrates all submodules (APB registers, pin interface, debounce logic, interrupt controller) into one coherent GPIO peripheral.
    * **APB Register File** – [`gpio_32_apb_regs.v`](gpio_32_apb_regs.v)  
        Implements memory-mapped registers: direction, output value, debounce configuration, interrupt mask/type/polarity, and W1C interrupt status.
    * **Pin Interface + 2-FF Synchronizer** – [`gpio_32_pins.v`](gpio_32_pins.v)  
        Handles GPIO direction, drives output values to pads, and safely synchronizes asynchronous external inputs using a dual flip-flop synchronizer.
    * **Debounce Engine** – [`gpio_32_debounce.v`](gpio_32_debounce.v)  
        Provides per-bit digital debounce with configurable timeout, filtering out mechanical bounce and noise before data reaches the CPU or interrupt system.
    * **Interrupt Controller** – [`gpio_32_interrupts.v`](gpio_32_interrupts.v)  
        Detects rising/falling edges and level-based events, maintains sticky interrupt status bits, and produces a bank-level IRQ signal.
    * **Verification Testbench** – [`tb_gpio_32.v`](tb_gpio_32.v)  
        Self-checking SystemVerilog testbench validating GPIO direction, debounce behavior, rising/level interrupt functionality, and W1C clearing.

---

## Data & Control Flow

The architecture is designed around a unidirectional data flow for configuration and a bidirectional flow for I/O operations. The system ensures safe clock-domain crossing and noise immunity before signals reach the internal logic.

```mermaid
graph TD
    subgraph "CPU / Bus Master"
    APB[APB Bus Interface]
    end

    subgraph "GPIO Peripheral"
    Regs[APB Register File]
    IntCtrl[Interrupt Controller]
    Debounce[Debounce Engine]
    Sync[2FF Synchronizer]
    Pins[Pin Interface]
    end

    subgraph "External World"
    Pads((Physical Pads))
    end

    %% Write Path
    APB -- "PWDATA (Write)" --> Regs
    Regs -- "GPIO_OUT / DIR" --> Pins
    Pins -- "Drive Output" --> Pads

    %% Read Path
    Pads -- "Raw Input" --> Sync
    Sync -- "Synchronized" --> Debounce
    Debounce -- "Stable Signal" --> Regs
    Regs -- "PRDATA (Read)" --> APB

    %% Interrupt Path
    Debounce -- "Clean Edges" --> IntCtrl
    Regs -- "Mask / Polarity" --> IntCtrl
    IntCtrl -- "IRQ Signal" --> APB
