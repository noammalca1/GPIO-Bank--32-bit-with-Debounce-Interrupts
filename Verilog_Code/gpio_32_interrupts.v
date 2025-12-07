// -----------------------------------------------------------------------------
// GPIO Interrupt Controller (32-bit)
//  - Rising edge enable per bit
//  - Falling edge enable per bit
//  - Level-based events per bit (active-high / active-low, pre-masked in top)
//  - Sticky interrupt status (set by edges/levels, cleared by W1C)
//  - One IRQ output = OR of all status bits
//  - Uses debounced input
// -----------------------------------------------------------------------------
module gpio_32_interrupts
(
    input  wire         PCLK,
    input  wire         PRESETn,

    // Debounced GPIO inputs (from debounce block)
    input  wire [31:0]  debounced_gpio_in,

    // Edge-based interrupt enables
    input  wire [31:0]  int_rise_en,
    input  wire [31:0]  int_fall_en,

    // Level-based interrupt "set" mask (already masked by type/mask/polarity)
    input  wire [31:0]  int_level_set,

    // Write-1-to-Clear command for INT_STATUS
    input  wire [31:0]  int_status_w1c,

    // Output: interrupt status and bank-level IRQ
    output reg  [31:0]  int_status,
    output wire         gpio_irq
);

    // Previous sampled value for edge detection
    reg [31:0] debounced_d;

    // -------------------------------------------------------------------------
    // Sample input for edge detection
    // -------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            debounced_d <= 32'h0000_0000;
        else
            debounced_d <= debounced_gpio_in;
    end

    // Rising and falling pulses (one-cycle)
    wire [31:0] rise_pulse = ~debounced_d &  debounced_gpio_in;
    wire [31:0] fall_pulse =  debounced_d & ~debounced_gpio_in;

    // Edge-based set bits
    wire [31:0] int_set_from_edges =
        (rise_pulse & int_rise_en) |
        (fall_pulse & int_fall_en);

    // Total set events: edges OR levels
    wire [31:0] int_set_total = int_set_from_edges | int_level_set;

    // -------------------------------------------------------------------------
    // Sticky INT_STATUS (set on edge/level, cleared on W1C)
    // -------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            int_status <= 32'h0000_0000;
        end else begin
            // OR-in new events, AND-out cleared bits
            int_status <= (int_status | int_set_total) & ~int_status_w1c;
        end
    end

    // -------------------------------------------------------------------------
    // Bank-level IRQ
    // -------------------------------------------------------------------------
    assign gpio_irq = |int_status;

endmodule
