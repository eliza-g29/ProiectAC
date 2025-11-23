module counter (
    // peripheral clock signals
    input clk,
    input rst_n,
    // register facing signals
    output[15:0] count_val,
    input[15:0] period,
    input en,
    input count_reset,
    input upnotdown,
    input[7:0] prescale
);
    //registri interni
    reg [15:0] cnt_r;      // numaratorul
    reg [8:0]  ps_cnt;     // contorul de prescalare (poate numara pana la 255)

    assign count_val = cnt_r;

    // calcul limita pentru prescaler: 2^prescale - 1, cu limitare la 2^8-1
    function [8:0] prescale_limit;
        input [7:0] ps;
        begin
            if (ps == 8'd0)       prescale_limit = 9'd0;          // divide by 1 (tick la fiecare clk)
            else if (ps >= 8'd8)  prescale_limit = 9'd255;        // clamp: maxim 2^8 - 1
            else                  prescale_limit = (9'd1 << ps) - 1;
        end
    endfunction

    wire [8:0] ps_lim  = prescale_limit(prescale);
    wire       tick    = en && (ps_cnt == ps_lim); // impuls de avans pentru cnt_r
    // logica secventiala
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_r  <= 16'd0;
            ps_cnt <= 9'd0;
        end else if (count_reset) begin
            // reset software al numaratorului
            cnt_r  <= 16'd0;
            ps_cnt <= 9'd0;
        end else begin
            // prescalerul ruleaza doar cand en=1
            if (en) begin
                // numara pana la ps_lim si apoi genereaza tick (ps_cnt revine la 0)
                if (ps_cnt == ps_lim)
                    ps_cnt <= 9'd0;
                else
                    ps_cnt <= ps_cnt + 9'd1;

                // avansul numaratorului are loc DOAR la "tick"
                if (tick) begin
                    if (upnotdown) begin
                        // UP: 0,1,2,...,PERIOD,0,1,...
                        if (cnt_r >= period)
                            cnt_r <= 16'd0;
                        else
                            cnt_r <= cnt_r + 16'd1;
                    end else begin
                        // DOWN: PERIOD,PERIOD-1,...,0,PERIOD,...
                        if (cnt_r == 16'd0)
                            cnt_r <= period;
                        else
                            cnt_r <= cnt_r - 16'd1;
                    end
                end
            end
            // daca en=0 pastram valorile (numaratorul ingheata)
        end
    end
endmodule
