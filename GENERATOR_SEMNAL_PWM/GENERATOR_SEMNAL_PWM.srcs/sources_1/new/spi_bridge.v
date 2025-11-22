
module spi_bridge (
    // peripheral clock signals
    input clk,
    input rst_n,
    // SPI master facing signals
    input sclk,
    input cs_n,
    input mosi,
    output miso,
    // internal facing 
    output byte_sync,
    output[7:0] data_in,
    input[7:0] data_out
);

    reg [7:0] shift_in;
    reg [2:0] bit_count = 3'd0;
    reg byte_done = 0;
    reg [7:0] shift_out;
    
    always @(posedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_in <= 8'd0;
            bit_count <= 3'd0;
            byte_done <= 1'b0;
        end else if (cs_n) begin
            bit_count <= 3'd0;
            byte_done <= 1'b0;
        end else begin        
            shift_in <= {shift_in[6:0], mosi};
            
            if (bit_count == 3'd7) begin
                bit_count <= 3'd0;
                byte_done = 1;
            end else begin
                bit_count <= bit_count + 3'd1;
                byte_done = 0;
            end
        end
    end
    
    always @(negedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_out <= 8'b0;
        end else if (cs_n) begin
            shift_out <= data_out;
        end else begin
            shift_out <= {shift_out[6:0], 1'b0};
        end
    end

endmodule
