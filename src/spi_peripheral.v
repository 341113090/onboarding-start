`default_nettype none

module spi_peripheral (
    input  wire       clk,      // clock
    input  wire       rst_n,     // reset_n - low to reset
    input  wire       SCLK, 
    input  wire       COPI,
    input  wire       nCS,
    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle
);
    // for payload
    localparam clock_limit = 16;
    localparam address_limit = 7;

    reg transaction_ready;
    
    // 2 stage flip flop registers
    reg [2:0] nCS_sync;
    reg [2:0] COPI_sync;
    reg [2:0] SCLK_sync;

    // for actual payload
    reg [4:0] clock_counter;
    reg [15:0] payload;

    wire valid = payload[15];
    wire rising_edge = SCLK_sync[1] && ~SCLK_sync[2];

    always @(posedge clk or negedge rst_n) begin
        
        if (~rst_n) begin
            nCS_sync <= 3'b0;
            COPI_sync <= 3'b0;
            SCLK_sync <= 3'b0;
            transaction_ready <= 1'b0;
            clock_counter <= 5'b0;
            payload <= 16'b0;
            en_reg_out_7_0 <= 8'b0;
            en_reg_out_15_8 <= 8'b0;
            en_reg_pwm_7_0 <= 8'b0;
            en_reg_pwm_15_8 <= 8'b0;
            pwm_duty_cycle <= 8'b0;
        end else begin
            // grab signals
            nCS_sync <= {nCS_sync[1:0],nCS};
            COPI_sync <= {COPI_sync[1:0],COPI};
            SCLK_sync <= {SCLK_sync[1:0], SCLK};

            // if the SPI has just been selected and it was not selected before
            if (nCS_sync[1] == 1'b0 && rising_edge) begin
                payload <= {payload[14:0],COPI_sync[1]};
                clock_counter <= clock_counter + 1;
            end
            else begin
                // if the 16 clock cycles have elapsed reset the clock and flag the transaction
                if(clock_counter == clock_limit) begin
                    transaction_ready <= 1'b1;
                    clock_counter <= 5'b00000;
                end
            end
            if(transaction_ready == 1'b1) begin
                if (valid) begin
                    case(payload[14:8])
                        7'd0: en_reg_out_7_0[7:0] <= payload[7:0];
                        7'd1: en_reg_out_15_8[7:0] <= payload[7:0];
                        7'd2: en_reg_pwm_7_0[7:0] <= payload[7:0];
                        7'd3: en_reg_pwm_15_8[7:0] <= payload[7:0];
                        7'd4: pwm_duty_cycle[7:0] <= payload[7:0];
                        default: ;
                    endcase
                end
                // reset transaction
                transaction_ready <= 1'b0;
            end
        end
    end
endmodule