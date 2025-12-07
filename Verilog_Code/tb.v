`timescale 1ns/1ns

module tb_gpio_32;

  // ---------------------------------------------------------------------------
  // Waveform dump (VCD)
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_gpio_32);
  end

  // ---------------------------------------------------------------------------
  // Clock / Reset
  // ---------------------------------------------------------------------------
  logic        PCLK;
  logic        PRESETn;

  // APB interface
  logic        PSEL;
  logic        PENABLE;
  logic        PWRITE;
  logic [7:0]  PADDR;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;
  logic        PREADY;
  logic        PSLVERR;

  // GPIO pads
  logic [31:0] gpio_in_raw;
  wire  [31:0] gpio_out;
  wire  [31:0] gpio_oe;

  // IRQ
  wire         gpio_irq;

  // ---------------------------------------------------------------------------
  // DUT Instance
  // ---------------------------------------------------------------------------
  gpio_32_top dut (
    .PCLK        (PCLK),
    .PRESETn     (PRESETn),

    .PSEL        (PSEL),
    .PENABLE     (PENABLE),
    .PWRITE      (PWRITE),
    .PADDR       (PADDR),
    .PWDATA      (PWDATA),
    .PRDATA      (PRDATA),
    .PREADY      (PREADY),
    .PSLVERR     (PSLVERR),

    .gpio_in_raw (gpio_in_raw),
    .gpio_out    (gpio_out),
    .gpio_oe     (gpio_oe),

    .gpio_irq    (gpio_irq)
  );

  // ---------------------------------------------------------------------------
  // Clock generation: 100 MHz (10 ns period)
  // ---------------------------------------------------------------------------
  initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
  end

  // ---------------------------------------------------------------------------
  // APB helper tasks
  // ---------------------------------------------------------------------------
  task automatic apb_idle();
    begin
      PSEL    = 0;
      PENABLE = 0;
      PWRITE  = 0;
      PADDR   = '0;
      PWDATA  = '0;
    end
  endtask

  task automatic apb_write(input [7:0] addr, input [31:0] data);
    begin
      // SETUP phase
      @(posedge PCLK);
      PSEL    = 1;
      PWRITE  = 1;
      PENABLE = 0;
      PADDR   = addr;
      PWDATA  = data;

      // ACCESS phase
      @(posedge PCLK);
      PENABLE = 1;

      // Complete transfer
      @(posedge PCLK);
      apb_idle();
    end
  endtask

  task automatic apb_read(input [7:0] addr, output [31:0] data);
    begin
      // SETUP phase
      @(posedge PCLK);
      PSEL    = 1;
      PWRITE  = 0;
      PENABLE = 0;
      PADDR   = addr;

      // ACCESS phase
      @(posedge PCLK);
      PENABLE = 1;

      // Sample
      @(posedge PCLK);
      data = PRDATA;

      apb_idle();
    end
  endtask

  // ---------------------------------------------------------------------------
  // Address map (byte offsets)
  // ---------------------------------------------------------------------------
  localparam [7:0] ADDR_GPIO_DIR      = 8'h00;
  localparam [7:0] ADDR_GPIO_OUT      = 8'h04;
  localparam [7:0] ADDR_GPIO_IN       = 8'h08;
  localparam [7:0] ADDR_INT_MASK      = 8'h0C;
  localparam [7:0] ADDR_INT_STATUS    = 8'h10;
  localparam [7:0] ADDR_INT_TYPE      = 8'h14;
  localparam [7:0] ADDR_INT_POLARITY  = 8'h18;
  localparam [7:0] ADDR_DEBOUNCE_CFG  = 8'h1C;

  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------
  initial begin
    int i;
    reg [31:0] rdata;

    apb_idle();
    gpio_in_raw = 32'h00000000;

    // Reset sequence
    PRESETn = 0;
    repeat (5) @(posedge PCLK);
    PRESETn = 1;
    repeat (5) @(posedge PCLK);

    $display("[%0t] Starting GPIO32 tests", $time);

    // =======================================================================
    // TEST 1 — GPIO direction + output register
    // =======================================================================
    apb_write(ADDR_GPIO_DIR, 32'h0000_00FF);
    apb_write(ADDR_GPIO_OUT, 32'hA5A5_00FF);

    repeat (2) @(posedge PCLK);

    if (gpio_oe !== 32'h0000_00FF)
      $error("TEST1: gpio_oe mismatch: %h", gpio_oe);

    if (gpio_out[7:0] !== 8'hFF)
      $error("TEST1: gpio_out mismatch (lower byte)");

    $display("[%0t] TEST1 done", $time);

    // =======================================================================
    // TEST 2 — Debounce filtering
    // =======================================================================
    apb_write(ADDR_DEBOUNCE_CFG, 32'h0000_0004);
    apb_write(ADDR_GPIO_DIR, 32'h0000_00FE); // bit 0 is input

    gpio_in_raw[0] = 0;
    repeat (2) @(posedge PCLK);

    gpio_in_raw[0] = 1; @(posedge PCLK);
    gpio_in_raw[0] = 0; @(posedge PCLK);
    gpio_in_raw[0] = 1; @(posedge PCLK);
    gpio_in_raw[0] = 0;

    repeat (5) @(posedge PCLK);

    apb_read(ADDR_GPIO_IN, rdata);
    if (rdata[0] !== 1'b0)
      $error("TEST2: short bounce incorrectly passed debounce");

    gpio_in_raw[0] = 1;
    repeat (6) @(posedge PCLK);

    apb_read(ADDR_GPIO_IN, rdata);
    if (rdata[0] !== 1'b1)
      $error("TEST2: long pulse did not pass debounce");

    $display("[%0t] TEST2 done", $time);

    // =======================================================================
    // TEST 3 — EDGE interrupt (rising edge)
    // =======================================================================
    apb_write(ADDR_INT_MASK,     32'h0000_0001);
    apb_write(ADDR_INT_TYPE,     32'h0000_0001); // EDGE
    apb_write(ADDR_INT_POLARITY, 32'h0000_0001); // rising

    apb_write(ADDR_INT_STATUS, 32'hFFFF_FFFF); // clear all
    repeat (2) @(posedge PCLK);

    gpio_in_raw[0] = 0;
    repeat (6) @(posedge PCLK);

    gpio_in_raw[0] = 1; // rising edge
    repeat (6) @(posedge PCLK);

    apb_read(ADDR_INT_STATUS, rdata);

    if (!gpio_irq)
      $error("TEST3: gpio_irq not asserted");

    if (rdata[0] !== 1'b1)
      $error("TEST3: INT_STATUS[0] not set");

    $display("[%0t] TEST3 interrupt asserted OK", $time);

    apb_write(ADDR_INT_STATUS, 32'h0000_0001); // W1C
    repeat (2) @(posedge PCLK);

    apb_read(ADDR_INT_STATUS, rdata);

    if (rdata[0] !== 1'b0)
      $error("TEST3: failed to clear INT_STATUS[0]");

    if (gpio_irq)
      $error("TEST3: gpio_irq still high after clear");

    $display("[%0t] TEST3 interrupt clear OK", $time);

    // =======================================================================
    // TEST 4 — LEVEL interrupt (ACTIVE HIGH)
    // =======================================================================
    $display("[%0t] TEST4: LEVEL-HIGH interrupt test", $time);

    // Configure LEVEL-HIGH on bit 0:
    //  int_mask     = 1  (enable)
    //  int_type     = 0  (LEVEL)
    //  int_polarity = 1  (ACTIVE-HIGH)
    apb_write(ADDR_INT_MASK,     32'h0000_0001);
    apb_write(ADDR_INT_TYPE,     32'h0000_0000);
    apb_write(ADDR_INT_POLARITY, 32'h0000_0001);

    apb_write(ADDR_INT_STATUS, 32'hFFFF_FFFF); // clear any leftovers
    repeat (2) @(posedge PCLK);

    // Ensure input LOW
    gpio_in_raw[0] = 0;
    repeat (6) @(posedge PCLK);

    // Drive input HIGH: LEVEL-HIGH should assert interrupt immediately
    gpio_in_raw[0] = 1;
    repeat (6) @(posedge PCLK);

    apb_read(ADDR_INT_STATUS, rdata);

    if (!gpio_irq)
      $error("TEST4: gpio_irq not asserted for LEVEL-HIGH");

    if (rdata[0] !== 1'b1)
      $error("TEST4: INT_STATUS[0] not set for LEVEL-HIGH");

    $display("[%0t] TEST4: LEVEL-HIGH interrupt asserted OK", $time);

    // Try clearing while level is STILL HIGH → expected to reassert
    apb_write(ADDR_INT_STATUS, 32'h0000_0001);
    repeat (2) @(posedge PCLK);

    apb_read(ADDR_INT_STATUS, rdata);

    if (rdata[0] !== 1'b1)
      $error("TEST4: INT_STATUS cleared even though level is HIGH");

    if (!gpio_irq)
      $error("TEST4: gpio_irq deasserted while level still HIGH");

    $display("[%0t] TEST4: LEVEL-HIGH stays active as expected", $time);

    // Now drop input LOW → level condition disappears
    gpio_in_raw[0] = 0;
    repeat (6) @(posedge PCLK);

    // Now clear should succeed
    apb_write(ADDR_INT_STATUS, 32'h0000_0001);
    repeat (2) @(posedge PCLK);

    apb_read(ADDR_INT_STATUS, rdata);

    if (rdata[0] !== 1'b0)
      $error("TEST4: INT_STATUS did not clear after level went LOW");

    if (gpio_irq)
      $error("TEST4: gpio_irq still high after deassert + clear");

    $display("[%0t] TEST4: LEVEL-HIGH interrupt clear OK", $time);

    // -----------------------------------------------------------------------
    $display("[%0t] All tests finished", $time);
    #50;
    $finish;
  end

endmodule
