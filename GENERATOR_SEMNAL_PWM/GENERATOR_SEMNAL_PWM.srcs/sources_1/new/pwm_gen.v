`default_nettype none
module pwm_gen (
    input  wire        clk,
    input  wire        rst_n,
    // config
    input  wire        pwm_en,
    input  wire [15:0] period,
    input  wire [7:0]  functions,
    input  wire [15:0] compare1,
    input  wire [15:0] compare2,
    input  wire [15:0] count_val,
    output wire        pwm_out
);
    // copii active ale configuratiei
    reg [15:0] period_act, c1_act, c2_act;
    reg [1:0]  func_act;

    // clamp local la period
    wire [15:0] c1_cl = (compare1 > period) ? period : compare1;
    wire [15:0] c2_cl = (compare2 > period) ? period : compare2;

    // detectam startul ciclului (overflow)
    wire start_of_cycle = (count_val == 16'd0);

    // detectam daca numaratorul este oprit
    reg [15:0] prev_count_val;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prev_count_val <= 16'hFFFF;
        else        prev_count_val <= count_val;
    end

    // daca valoarea nu s-a schimbat fata de ciclul anterior, counter-ul e oprit
    wire counter_stopped = (count_val == prev_count_val);

    // conditia de actualizare a registrelor interne
    wire cfg_update = (!pwm_en) | start_of_cycle | counter_stopped;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period_act <= 16'd0;
            c1_act     <= 16'd0;
            c2_act     <= 16'd0;
            func_act   <= 2'b00;
        end else if (cfg_update) begin
            period_act <= period;
            c1_act     <= c1_cl;
            c2_act     <= c2_cl;
            func_act   <= functions[1:0];
        end
    end

    // decodare mod
    wire aliniat   = (func_act[1] == 1'b0);
    wire dreapta   = (func_act[0] == 1'b1);
    wire interval  = (func_act == 2'b10);

    // ALIGN_LEFT: activ [0, compare1]. 
    // Fix Test 5: Daca compare1 este 0, fortam 0 (evitam pulsul de 1 ciclu la count=0).
    wire win_left   = (c1_act == 16'd0) ? 1'b0 : (count_val <= c1_act);

    // ALIGN_RIGHT: activ [compare1, period]
    wire win_right  = (count_val >= c1_act);

    // RANGE: activ [compare1, compare2)
    wire win_range  = (c1_act < c2_act) && (count_val >= c1_act) && (count_val < c2_act);

    // selectorul de baza
    wire pwm_logic = interval ? win_range
    : (dreapta ? win_right : win_left);

    // calcul final cu override
    wire pwm_calc = (c1_act == c2_act) ? 1'b0 : pwm_logic;

    reg pwm_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)       pwm_q <= 1'b0;
        else if (pwm_en)  pwm_q <= pwm_calc;
        // latch behavior cand pwm_en=0
    end

    assign pwm_out = pwm_q;
endmodule
`default_nettype wire