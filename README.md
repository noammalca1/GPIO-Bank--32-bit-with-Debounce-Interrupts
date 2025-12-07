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
- [APB Register Map](#apb-register-map)
- [GPIO Direction & Data Path](#gpio-direction--data-path)
- [Debounce Architecture](#debounce-architecture)
- [Interrupt System](#interrupt-system)
- [Top-Level Integration](#top-level-integration)
- [Verification Testbench](#verification-testbench)
- [Simulation and Waveforms](#simulation-and-waveforms)
- [Design Insights](#design-insights)
- [Future Improvements](#future-improvements)
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

Top-level module: **`gpio_32_top`**  
Testbench: **`tb_gpio_32`**

### Data & Control Flow


