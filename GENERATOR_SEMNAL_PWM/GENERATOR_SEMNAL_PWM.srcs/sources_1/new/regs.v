module regs (
    input clk,
    input rst_n,

    // interfata cu un decodor de registri (citire/scriere)
    input read,
    input write,
    input [5:0] addr,
    output reg [7:0] data_read,
    input [7:0] data_write,

    // semnale de la/de la un modul de numarare (counter)
    input  [15:0] counter_val,
    output reg [15:0] period,
    output reg en,
    output reg count_reset,
    output reg upnotdown,
    output reg [7:0] prescale,

    // semnale legate de modulul pwm
    output reg pwm_en,
    output reg [7:0] functions,
    output reg [15:0] compare1,
    output reg [15:0] compare2
);
    // adresele registrilor accesibili (harta de memorie)
    localparam ADDR_PERIOD_L      = 6'h00; // octetul low din perioada
    localparam ADDR_PERIOD_H      = 6'h01; // octetul high din perioada

    localparam ADDR_COUNTER_EN    = 6'h02; // activare counter (bit 0)

    localparam ADDR_COMPARE1_L    = 6'h03; // compare1 - octet low
    localparam ADDR_COMPARE1_H    = 6'h04; // compare1 - octet high

    localparam ADDR_COMPARE2_L    = 6'h05; // compare2 - octet low
    localparam ADDR_COMPARE2_H    = 6'h06; // compare2 - octet high

    localparam ADDR_COUNTER_RESET = 6'h07; // reset temporar al counter-ului (bit 0 = 1)

    localparam ADDR_COUNTER_VAL_L = 6'h08; // valoare curenta a counter-ului - low
    localparam ADDR_COUNTER_VAL_H = 6'h09; // valoare curenta a counter-ului - high

    localparam ADDR_PRESCALE      = 6'h0A; // factor de divizare al ceasului
    localparam ADDR_UPNOTDOWN     = 6'h0B; // sensul de numarare (1 = sus, 0 = jos)
    localparam ADDR_PWM_EN        = 6'h0C; // activeaza semnalul pwm
    localparam ADDR_FUNCTIONS     = 6'h0D; // configuratii suplimentare (doar bitii [1:0])

    // logica de scriere (executata la front de clock)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // resetam toate valorile interne
            period      <= 16'h0000;
            en          <= 1'b0;
            upnotdown   <= 1'b0;
            prescale    <= 8'h00;
            pwm_en      <= 1'b0;
            functions   <= 8'h00;
            compare1    <= 16'h0000;
            compare2    <= 16'h0000;
            count_reset <= 1'b0;
        end else begin
            // semnalul de reset este doar un puls (valabil 1 ciclu)
            count_reset <= 1'b0;

            if (write) begin
                case (addr)

                    // perioada - 16 biti
                    ADDR_PERIOD_L:  period[7:0]  <= data_write;
                    ADDR_PERIOD_H:  period[15:8] <= data_write;

                    // activare counter (bit 0)
                    ADDR_COUNTER_EN: en <= data_write[0];

                    // compare1 - 16 biti
                    ADDR_COMPARE1_L: compare1[7:0]  <= data_write;
                    ADDR_COMPARE1_H: compare1[15:8] <= data_write;

                    // compare2 - 16 biti
                    ADDR_COMPARE2_L: compare2[7:0]  <= data_write;
                    ADDR_COMPARE2_H: compare2[15:8] <= data_write;

                    // reset pentru counter (daca bitul 0 este 1, se activeaza count_reset pentru un ciclu)
                    ADDR_COUNTER_RESET: if (data_write[0]) count_reset <= 1'b1;

                    // prescaler
                    ADDR_PRESCALE: prescale <= data_write;

                    // sensul de numarare (1 = sus, 0 = jos)
                    ADDR_UPNOTDOWN: upnotdown <= data_write[0];

                    // activare semnal pwm
                    ADDR_PWM_EN: pwm_en <= data_write[0];

                    // configurare functii speciale (doar bitii 1:0 sunt folositi)
                    ADDR_FUNCTIONS: functions[1:0] <= data_write[1:0];

                    default: ;
                endcase
            end
        end
    end

    // logica de citire (combinationala)
    always @(*) begin
        case (addr)

            // perioada
            ADDR_PERIOD_L:      data_read = period[7:0];
            ADDR_PERIOD_H:      data_read = period[15:8];

            // activare counter
            ADDR_COUNTER_EN:    data_read = {7'b0, en};

            // compare1
            ADDR_COMPARE1_L:    data_read = compare1[7:0];
            ADDR_COMPARE1_H:    data_read = compare1[15:8];

            // compare2
            ADDR_COMPARE2_L:    data_read = compare2[7:0];
            ADDR_COMPARE2_H:    data_read = compare2[15:8];

            // valoarea actuala a counter-ului (doar pentru citire)
            ADDR_COUNTER_VAL_L: data_read = counter_val[7:0];
            ADDR_COUNTER_VAL_H: data_read = counter_val[15:8];

            // prescaler
            ADDR_PRESCALE:      data_read = prescale;

            // directia de numarare
            ADDR_UPNOTDOWN:     data_read = {7'b0, upnotdown};

            // activare pwm
            ADDR_PWM_EN:        data_read = {7'b0, pwm_en};

            // functii (doar bitii [1:0] sunt folositi)
            ADDR_FUNCTIONS:     data_read = {6'b0, functions[1:0]};

            // adresa necunoscuta ? returnam 0
            default:            data_read = 8'h00;
        endcase
    end

endmodule
