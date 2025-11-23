
module spi_bridge (
    // semnalele de ceas periferice
    input clk,
    input rst_n,
    // semnalele de ceas SPI
    input sclk,
    input cs_n,
    
    input mosi,
    output miso,
    output byte_sync,
    output[7:0] data_in,
    input[7:0] data_out
);

    // Registru de shift IN (MOSI) - front crescator SCLK
    
    reg [7:0] shift_in;
    reg [2:0] bit_count;
    reg byte_done;
    
    
    always @(posedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_in <= 8'd0;
            bit_count <= 3'd0;
            byte_done <= 1'b0;
            
        end else if (cs_n) begin
            bit_count <= 3'd0;
            byte_done <= 1'b0;
            
        end else begin     
            // MOSI este stocat in partea LSB a shift_in
               
            shift_in <= {shift_in[6:0], mosi};
            
            if (bit_count == 3'd7) begin
                // byte-ul shift_in este gata pt. a fi transmis catre decodor
                bit_count <= 3'd0;
                byte_done <= 1'b1;
            end else begin
                bit_count <= bit_count + 3'd1;
                byte_done <= 1'b0;
            end
            
        end
    end
    
    assign data_in = shift_in;
    
    // Registru de shift OUT (MISO) - front descrescator SCLK
    
    reg [7:0] shift_out;
    
    always @(negedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_out <= 8'b0;
            
        end else if (cs_n) begin
            // shift_out preia byte-ul transmis de catre decodor
            shift_out <= data_out;
            
        end else begin
            // se shifteaza byte-ul la stanga dupa ce s-a transmis bitul MSB ciclul trecut
            shift_out <= {shift_out[6:0], 1'b0};
        end
    end
    
    assign miso = shift_out[7]; // MISO preia bitul MSB din byte-ul stocat
    
    // Generarea byte_sync in domeniul clk (sincron cu SCLK)
    
    reg bd_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bd_d1 <= 1'b0;
            
        else
            bd_d1 <= byte_done;
            
    end

    assign byte_sync = (byte_done & ~bd_d1);

endmodule
