module gpio_32_apb_regs (
    input  wire        PCLK,
    input  wire        PRESETn,

    // APB slave interface
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [7:0]  PADDR,
    input  wire [31:0] PWDATA,

    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,

    // incoming read-only values from other blocks
    input  wire [31:0] read_gpio_in,     // from debounce block
    input  wire [31:0] read_int_status,  // from interrupt controller

    // outgoing control registers
    output reg  [31:0] gpio_dir,
    output reg  [31:0] gpio_out_reg,
    output reg  [31:0] int_mask,
    output reg  [31:0] int_type,
    output reg  [31:0] int_polarity,
    output reg  [15:0] debounce_cfg,

    // write-1-to-clear pulse towards interrupt controller
    output reg  [31:0] int_clear
);

    // -------------------------------------------------------------------------
    // Address map – BYTE addresses (must match testbench!)
    // -------------------------------------------------------------------------
    localparam [7:0] ADDR_GPIO_DIR      = 8'h00; // 0x00
    localparam [7:0] ADDR_GPIO_OUT      = 8'h04; // 0x04
    localparam [7:0] ADDR_GPIO_IN       = 8'h08; // 0x08
    localparam [7:0] ADDR_INT_MASK      = 8'h0C; // 0x0C
    localparam [7:0] ADDR_INT_STATUS    = 8'h10; // 0x10
    localparam [7:0] ADDR_INT_TYPE      = 8'h14; // 0x14
    localparam [7:0] ADDR_INT_POLARITY  = 8'h18; // 0x18
    localparam [7:0] ADDR_DEBOUNCE_CFG  = 8'h1C; // 0x1C

    // -------------------------------------------------------------------------
    // APB static outputs
    // -------------------------------------------------------------------------
    assign PREADY  = 1'b1;   // zero wait-states
    assign PSLVERR = 1'b0;   // no error

    // -------------------------------------------------------------------------
    // APB access / read / write strobes (APB3-style)
    //  - SETUP:  PSEL=1, PENABLE=0
    //  - ACCESS: PSEL=1, PENABLE=1  
    // -------------------------------------------------------------------------
    wire apb_access = PSEL & PENABLE;
    wire apb_write  = apb_access &  PWRITE;
    wire apb_read   = apb_access & ~PWRITE;

    // -------------------------------------------------------------------------
    // Write logic (register update on ACCESS write)
    // -------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            gpio_dir      <= 32'h0000_0000;
            gpio_out_reg  <= 32'h0000_0000;
            int_mask      <= 32'h0000_0000;
            int_type      <= 32'h0000_0000;
            int_polarity  <= 32'h0000_0000;
            debounce_cfg  <= 16'h0000;
            int_clear     <= 32'h0000_0000;
        end else begin
            // default: no clear this cycle
            int_clear <= 32'h0000_0000;

            if (apb_write) begin
                case (PADDR)
                    // GPIO direction: 1 = output, 0 = input
                    ADDR_GPIO_DIR: begin
                        gpio_dir <= PWDATA;
                    end

                    // GPIO output value
                    ADDR_GPIO_OUT: begin
                        gpio_out_reg <= PWDATA;
                    end

                    // Interrupt mask: 1 = enabled, 0 = masked
                    ADDR_INT_MASK: begin
                        int_mask <= PWDATA;
                    end

                    // Interrupt type: 0 = level, 1 = edge
                    ADDR_INT_TYPE: begin
                        int_type <= PWDATA;
                    end

                    // Interrupt polarity:
                    //   if edge: 1 = rising, 0 = falling
                    //   if level: 1 = high,   0 = low
                    ADDR_INT_POLARITY: begin
                        int_polarity <= PWDATA;
                    end

                    // Debounce configuration (lower 16 bits)
                    ADDR_DEBOUNCE_CFG: begin
                        debounce_cfg <= PWDATA[15:0];
                    end

                    // INT_STATUS – Write-1-to-Clear (W1C)
                    ADDR_INT_STATUS: begin
                        int_clear <= PWDATA;
                    end

                    default: begin
                        // unknown address: do nothing
                    end
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Read logic (PRDATA mux)
    // -------------------------------------------------------------------------
    always @(*) begin
        PRDATA = 32'h0000_0000;

        case (PADDR)
            // GPIO direction register
            ADDR_GPIO_DIR: begin
                PRDATA = gpio_dir;
            end

            // GPIO output register
            ADDR_GPIO_OUT: begin
                PRDATA = gpio_out_reg;
            end

            // GPIO input (from debounce/sync block)
            ADDR_GPIO_IN: begin
                PRDATA = read_gpio_in;
            end

            // Interrupt mask
            ADDR_INT_MASK: begin
                PRDATA = int_mask;
            end

            // Interrupt status (read-only, from interrupt controller)
            ADDR_INT_STATUS: begin
                PRDATA = read_int_status;
            end

            // Interrupt type
            ADDR_INT_TYPE: begin
                PRDATA = int_type;
            end

            // Interrupt polarity
            ADDR_INT_POLARITY: begin
                PRDATA = int_polarity;
            end

            // Debounce configuration (zero-extended)
            ADDR_DEBOUNCE_CFG: begin
                PRDATA = {16'h0000, debounce_cfg};
            end

            default: begin
                PRDATA = 32'h0000_0000;
            end
        endcase
    end

endmodule
