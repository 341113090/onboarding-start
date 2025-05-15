`default_nettype none

module spi_peripheral (
    input  wire       clk,      // clock
    input  wire       rst_n,     // reset_n - low to reset
    input wire [7:0] ui_in, // nCS [2] COPI [1] SCLK [0]
    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle
);
    // for payload
    localparam clock_limit = 16;
    localparam address_limit = 7;

    // for control signals
    wire nCS, COPI, SCLK;
    assign nCS = ui_in[2];
    assign COPI = ui_in[1];
    assign SCLK = ui_in[0];
    
    // 2 stage flip flop registers
    reg [2:0] nCS_sync;
    reg [2:0] COPI_sync;
    reg [2:0] SCLK_sync;

    // keep track of transaction
    reg selected;
    reg valid_action;
    reg transaction_ready;

    // for actual payload
    reg [5:0] clock_counter;
    reg [7:0] payload;
    reg [6:0] address;

    always @(posedge clk or negedge rst_n) begin
        
        if (!rst_n) begin
            selected <= 1'b0;
            valid_action <= 1'b0;
            transaction_ready <= 1'b0;
            nCS_sync <= 3'b000;
            COPI_sync <= 3'b000;
            SCLK_sync <= 3'b000;
            clock_counter <= 5'b00000;
            payload <= 7'b0000000;
            address <= 6'b000000;
            en_reg_out_7_0 <= 8'b00000000;
            en_reg_out_15_8 <= 8'b00000000;
            en_reg_pwm_7_0 <= 8'b00000000;
            en_reg_pwm_15_8 <= 8'b00000000;
            pwm_duty_cycle <= 8'b00000000;
        end else begin
            // grab signals
            nCS_sync <= {nCS_sync[1:0],nCS};
            COPI_sync <= {COPI_sync[1:0],COPI};
            SCLK_sync <= {SCLK_sync[1:0], SCLK};

            // if the SPI has just been selected and it was not selected before
            if (!selected && nCS_sync == 3'b110) begin
                // indicate seelction
                selected <= 1'b1;

                // check if the action can be completed (if it is a write)
                valid_action <= (COPI_sync[0] == 1) ? 1'b1 : 1'b0;

                if (valid_action) begin
                    // intializing everything to beginning
                    address <= 6'b000000;
                    payload <= 7'b0000000;
                    clock_counter <= 5'b000000;
                end
                // else will execute if the SPI is selected and detects a rising edge
            end else if(selected && (SCLK_sync[1:0]==2'b01)) begin
                // if the action is valid, keep track of data
                if (valid_action) begin
                    if(clock_counter < address_limit) begin
                        address <= {address[6:1],COPI_sync[0]};
                    end else begin
                        payload <= {payload[6:1],COPI_sync[0]};
                    end
                end
                // regardless of validity, increase counter
                clock_counter <= clock_counter + 1;

                // if the 16 clock cycles have elapsed reset the clock and flag the transaction
                if(clock_counter == clock_limit) begin
                    transaction_ready <= 1'b1;
                    clock_counter <= 5'b00000;
                end
            end else if(transaction_ready) begin
                if (valid_action) begin
                    case(address)
                        6'b000000: en_reg_out_7_0[7:0] <= payload[7:0];
                        6'b000001: en_reg_out_15_8[7:0] <= payload[7:0];
                        6'b000010: en_reg_pwm_7_0[7:0] <= payload[7:0];
                        6'b000011: en_reg_pwm_15_8[7:0] <= payload[7:0];
                        6'b000100: pwm_duty_cycle[7:0] <= payload[7:0];
                    endcase
                end
                // reset all variables and do nothing
                selected <= 1'b0;
                valid_action <= 1'b0;
                transaction_ready <= 1'b0;
            end
        end
    end
endmodule