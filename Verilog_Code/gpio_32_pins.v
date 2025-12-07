module gpio_32_pins (
    input  wire        PCLK,
    input  wire        PRESETn,

    // Configuration from APB register file
    input  wire [31:0] gpio_dir,       // 1 = output, 0 = input
    input  wire [31:0] gpio_out_reg,   // value to drive when output

    // Physical pin input (raw, asynchronous)
    input  wire [31:0] gpio_in_raw,    // direct pin value

    // Outputs toward physical pads
    output wire [31:0] gpio_out,       // driven value when OE = 1
    output wire [31:0] gpio_oe,        // output enable for each pin

    // Synchronized input (safe to use in logic)
    output wire [31:0] sync_gpio_in
);

    // -------------------------------------------------------
    // Direction → Output Enable
    // -------------------------------------------------------
    // gpio_dir[i] = 1 → pin is OUTPUT (driver enabled)
    // gpio_dir[i] = 0 → pin is INPUT  (driver in Hi-Z state)
    assign gpio_oe = gpio_dir;

    // -------------------------------------------------------
    // Output Value
    // -------------------------------------------------------
    // This is the value driven to the pad when the pin is set as output.
    assign gpio_out = gpio_out_reg;

    // -------------------------------------------------------
    // 2-Stage Synchronizer (Metastability Protection)
    // -------------------------------------------------------
    // Every external input must be synchronized to PCLK before
    // it can be safely used inside the chip.
    // sync_ff1 may go metastable → sync_ff2 cleans it.
    reg [31:0] sync_ff1, sync_ff2;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            sync_ff1 <= 32'h0;
            sync_ff2 <= 32'h0;
        end else begin
            sync_ff1 <= gpio_in_raw;   // first stage capture
            sync_ff2 <= sync_ff1;      // second stage stabilized output
        end
    end

    // The synchronized version of the pin input
    assign sync_gpio_in = sync_ff2;

endmodule
