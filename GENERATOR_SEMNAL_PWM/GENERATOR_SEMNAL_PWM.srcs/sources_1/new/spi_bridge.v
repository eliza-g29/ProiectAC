`default_nettype none
module spi_bridge (
    input  wire clk,
    input  wire rst_n,
    input  wire sclk,
    input  wire cs_n,
    input  wire mosi,
    output wire miso,
    output wire        byte_sync,
    output wire [7:0] data_in,
    input  wire [7:0] data_out
);
    // receptie MOSI in domeniul SCLK (MSB-first)
    reg [7:0] shift_in;
    reg [7:0] data_buffer; // buffer pentru stabilitate
    reg [2:0] bit_cnt;
    reg       byte_tgl;

    always @(posedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_in    <= 8'h00;
            data_buffer <= 8'h00;
            bit_cnt     <= 3'd0;
            byte_tgl    <= 1'b0;
        end else if (cs_n) begin
            bit_cnt  <= 3'd0;
        end else begin
            // Shiftam bitul curent
            shift_in <= {shift_in[6:0], mosi};

            if (bit_cnt == 3'd7) begin
                bit_cnt  <= 3'd0;
                byte_tgl <= ~byte_tgl; // marcheaza completarea unui byte

                // salvam octetul complet in buffer exact cand e gata
                data_buffer <= {shift_in[6:0], mosi};
            end else begin
                bit_cnt <= bit_cnt + 3'd1;
            end
        end
    end

    // data_in citeste din buffer-ul stabil, nu din shift_in care se misca
    assign data_in = data_buffer;

    // sincronizare toggling (puls 1 ciclu in domeniul clk)
    reg t_s1, t_s2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t_s1 <= 1'b0;
            t_s2 <= 1'b0;
        end else begin
            t_s1 <= byte_tgl;
            t_s2 <= t_s1;
        end
    end
    assign byte_sync = (t_s1 ^ t_s2);

    // emisie MISO in domeniul SCLK 
    reg [7:0] shift_out;
    reg cs_q;
    always @(posedge sclk or negedge rst_n)
    if (!rst_n) cs_q <= 1'b1; else cs_q <= cs_n;

    wire cs_fall = cs_q & ~cs_n;

    always @(negedge sclk or negedge rst_n) begin
        if (!rst_n) begin
            shift_out <= 8'h00;
        end else if (cs_fall) begin
            shift_out <= data_out; // ia byte-ul la inceputul cadrului
        end else if (!cs_n) begin
            shift_out <= {shift_out[6:0], 1'b0};
        end
    end

    assign miso = shift_out[7];
endmodule
`default_nettype wire