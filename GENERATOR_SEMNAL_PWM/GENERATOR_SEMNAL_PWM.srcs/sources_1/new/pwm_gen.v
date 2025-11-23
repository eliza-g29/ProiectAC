
module pwm_gen (
    // peripheral clock signals
    input clk,
    input rst_n,
    // PWM signal register configuration
    input pwm_en,
    input[15:0] period,
    input[7:0] functions,
    input[15:0] compare1,
    input[15:0] compare2,
    input[15:0] count_val,
    // top facing signals
    output pwm_out
);
    // copie activa a configuratiei (se actualizeaza la inceput de ciclu sau cand este oprit)
    reg [15:0] period_act, comp1_act, comp2_act;
    reg [1:0]  func_act;

    // faza locala in cadrul ciclului 0..period_act (independenta de directia contorului)
    reg [15:0] phase;     // creste cu 1 la fiecare tick al numaratorului
    reg [15:0] count_d;   // esantion anterior al count_val

    // detectie inceput de ciclu indiferent de UP/DOWN:
    //  UP: trecere period -> 0
    //  DOWN: trecere 0 -> period
    wire cycle_wrap = (count_d == period_act && count_val == 16'd0) ||
                      (count_d == 16'd0      && count_val == period_act);

    // tick observat cand s-a schimbat count_val (prescalerul a generat un pas)
    wire tick_seen = (count_val != count_d);

    // limitam pragurile la period ca sa evitam comparatii invalide
    wire [15:0] c1_s = (compare1 > period) ? period : compare1;
    wire [15:0] c2_s = (compare2 > period) ? period : compare2;

    // actualizam configuratia activa la inceput de ciclu sau cand PWM este oprit
    wire cfg_update = cycle_wrap || !pwm_en;

    // registri secventiali: retinere count anterior, faza si configuratia activa
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_d    <= 16'd0;
            phase      <= 16'd0;
            period_act <= 16'd0;
            comp1_act  <= 16'd0;
            comp2_act  <= 16'd0;
            func_act   <= 2'b00;
        end else begin
            count_d <= count_val;

            if (cfg_update) begin
                // fotografie a registrelor externe intr-un moment sigur
                period_act <= period;
                comp1_act  <= c1_s;
                comp2_act  <= c2_s;
                func_act   <= functions[1:0];
                phase      <= 16'd0;          // resetam faza la inceput de ciclu
            end else if (tick_seen) begin
                if (phase < period_act)
                    phase <= phase + 16'd1;   // avanseaza faza cu fiecare tick
            end
        end
    end

    // logica PWM combinationala pe baza configuratiei active si a fazei
    wire aliniat   = (func_act[1] == 1'b0);
    wire dreapta   = (func_act[0] == 1'b1);

    // aliniat stanga: iesire 1 pentru phase < comp1_act
    wire win_stanga = (phase < comp1_act);

    // aliniat dreapta: iesire 1 pe ultimele comp1_act trepte din ciclu
    wire [15:0] start_dreapta = (period_act > comp1_act) ? (period_act - comp1_act) : 16'd0;
    wire win_dreapta = (phase >= start_dreapta);

    // nealiniat: iesire 1 in intervalul [comp1_act, comp2_act) daca comp1_act < comp2_act
    wire win_nealiniat = (comp1_act < comp2_act) &&
                         (phase >= comp1_act) && (phase < comp2_act);

    wire pwm_calc = aliniat ? (dreapta ? win_dreapta : win_stanga)
                            : win_nealiniat;

    // registru de iesire: cand pwm_en=0 mentinem starea
    reg pwm_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)       pwm_q <= 1'b0;
        else if (pwm_en)  pwm_q <= pwm_calc;
        else              pwm_q <= pwm_q;   // mentine ultima valoare cand este dezactivat
    end

    assign pwm_out = pwm_q;
endmodule
