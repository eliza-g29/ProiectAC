
module instr_dcd (
    // semnale periferice de ceas
    input clk,
    input rst_n,
    // semnale venite de la bridge-ul de comunicatie
    input byte_sync,
    input[7:0] data_in,
    output[7:0] data_out,
    // semnale pt registru
    output read,
    output write,
    output[5:0] addr,
    input[7:0] data_read,
    output[7:0] data_write
);

    localparam IDLE = 2'd0;
    localparam WAIT_FOR_DATA = 2'd1; // asteapta payload pentru write
    localparam SEND_READ_BYTE = 2'd2; // trimite data_read la master
        
    reg [1:0] state, next_state;
    reg       cmd_is_write;   // 1 = write, 0 = read
    reg [7:0] out_reg;        // data_out registru
    reg [5:0] addr_reg; // addr registru
    reg read_reg; // read registru
    reg write_reg; // write registru
    reg [7:0] data_write_reg; // data_write registru

    assign data_out = out_reg;
    assign addr = addr_reg;
    assign read = read_reg;
    assign write = write_reg;
    assign data_write = data_write_reg;

    // FSM secvential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            addr_reg <= 6'b0;
            cmd_is_write <= 1'b0;
            read_reg <= 1'b0;
            write_reg <= 1'b0;
            data_write_reg <= 8'd0;
            out_reg <= 8'd0;
            
        end else begin
            // dezactiveaza pulsurile in mod implicit
            read_reg  <= 1'b0;
            write_reg <= 1'b0;

            state <= next_state;

            // actiuni FSM pe stari
            case (state)
                IDLE: begin
                    if (byte_sync) begin
                        // stabileste tipul comenzii
                        cmd_is_write <= data_in[7];
                        // extrage adresa
                        addr_reg <= data_in[5:0];

                        if (!cmd_is_write) begin
                            // Read: pulseaza read pentru un ciclu
                            read_reg <= 1'b1;
                        end
                        
                    end
                end

                WAIT_FOR_DATA: begin
                    if (byte_sync) begin
                        // Latch payload pentru write si pulseaza write
                        data_write_reg <= data_in;
                        write_reg <= 1'b1;
                        
                        out_reg <= 8'd0;
                    end
                end

                SEND_READ_BYTE: begin
                    if (byte_sync) begin
                        // Plaseaza data_read pe data_out pentru master
                        out_reg <= data_read;
                    end
                end

                default: ;
            endcase
        end
    end

    // FSM combinational (next-state logic)
    always @(*) begin
        // urmatoarea stare este implicit cea curenta
        next_state = state;

        case (state)
            IDLE: begin
                if (byte_sync) begin
                    if (data_in[7]) begin
                        // write command -> wait payload
                        next_state = WAIT_FOR_DATA;
                    end else begin
                        // read command -> pulse read now, then wait for master to request the next byte
                        next_state = SEND_READ_BYTE;
                    end
                end
            end

            WAIT_FOR_DATA: begin
                if (byte_sync) begin
                    // dupa ce a primit byte-ul pt scriere, va sta in stand-by
                    next_state = IDLE;
                end
            end

            SEND_READ_BYTE: begin
                if (byte_sync) begin
                    // dupa ce data_out preia byte-ul de la data_read pt. bridge-ul de comunicatie, se muta in stand-by
                    next_state = IDLE;
                end
            end

            default: ;
        endcase
    end

endmodule
