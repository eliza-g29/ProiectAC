
module instr_dcd (
    // peripheral clock signals
    input clk,
    input rst_n,
    // towards SPI slave interface signals
    input byte_sync,
    input[7:0] data_in,
    output[7:0] data_out,
    // register access signals
    output read,
    output write,
    output[5:0] addr,
    input[7:0] data_read,
    output[7:0] data_write
);

    localparam IDLE = 2'd0;
    localparam WAIT_FOR_DATA = 2'd1; // asteptam bitul al doilea pt citire sau scriere
    localparam SEND_READ_BYTE = 2'd2; //pt citire: data_out preia data_read cand master-ul da mai departe urmatorul tip
        
    reg [1:0] state, next_state;
    reg       cmd_is_write;   // stores whether last command was write(1)/read(0)
    reg [7:0] out_reg;        // registered data_out
    reg [5:0] addr_reg;
    reg read_reg;
    reg write_reg;
    reg [7:0] data_write_reg;

    // default assignments
    assign data_out = out_reg;
    assign addr = addr_reg;
    assign read = read_reg;
    assign write = write_reg;
    assign data_write = data_write_reg;

    // FSM sequential
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
            // default de-assert pulses
            read_reg  <= 1'b0;
            write_reg <= 1'b0;

            state <= next_state;

            // state actions on byte_sync edges / other events:
            case (state)
                IDLE: begin
                    if (byte_sync) begin
                        // parse command byte
                        cmd_is_write <= data_in[7];
                        // address is bits [5:0]
                        addr_reg <= data_in[5:0];

                        if (data_in[7]) begin
                            // write command -> wait for next byte (payload)
                            // do not assert write now; wait for payload
                            // next_state will be WAIT_FOR_DATA
                        end else begin
                            // read command -> pulse read for 1 clk so memory puts data_read on bus
                            read_reg <= 1'b1;
                            // After pulsing read, we need to place data_read to data_out when master requests next byte.
                            // Move to SEND_READ_BYTE to await next byte_sync and then drive out_reg.
                        end
                    end
                end

                WAIT_FOR_DATA: begin
                    if (byte_sync) begin
                        // This byte is the payload for a write command.
                        // Latch payload and pulse write for one cycle.
                        data_write_reg <= data_in;
                        write_reg <= 1'b1;
                        // Optionally, also prepare out_reg to some ack value (e.g., echo or 0)
                        out_reg <= 8'd0;
                    end
                end

                SEND_READ_BYTE: begin
                    if (byte_sync) begin
                        // On next byte_sync (master is clocking a byte), present data_read
                        out_reg <= data_read;
                        // After sending the read data, return to IDLE
                    end
                end

                default: ;
            endcase
        end
    end

    // FSM combinational next-state logic (synchronous decisions depend on current state and byte_sync)
    always @(*) begin
        // default next state is current
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
                end else begin
                    next_state = IDLE;
                end
            end

            WAIT_FOR_DATA: begin
                if (byte_sync) begin
                    // after receiving data byte for write, go idle
                    next_state = IDLE;
                end else begin
                    next_state = WAIT_FOR_DATA;
                end
            end

            SEND_READ_BYTE: begin
                if (byte_sync) begin
                    // after placing data_read on data_out for the master's byte, go idle
                    next_state = IDLE;
                end else begin
                    next_state = SEND_READ_BYTE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
