module sample_timer #(
    parameter freq  = 100          //MHz,10ns period
) (
    input clk,
    input rst_n,
    input en1,
    input en2,
    input en3,
    input en4,
    input en5,
    input [9:0] scp_period,    //scope sampling period, unit 10ns, max time = 2^32*10ns=42.9s
    input [1:0] scp_unit,    //scope sampling unit

    output reg clk_o1,          //20kHz
    output reg clk_o2,          //10kHz
    output reg clk_o3,          //5kHz
    output reg clk_o4,          //2kHz
    output reg clk_o5           //user defined, for scope timer
);
    localparam div1 = freq * 1000000 / (20 * 1000) ;//20khz 50us
    localparam div2 = freq * 1000000 / (10 * 1000) ;//10khz 100us
    localparam div3 = freq * 1000000 / (5  * 1000) ;//5khz  200us
    localparam div4 = freq * 1000000 / (2  * 1000) ;//2khz  500us

    reg [16:0] i1,i2,i3,i4;//16bit, max 65536
    reg [31:0] i5;
    reg [7:0] ns_cnt,us_cnt, ms_cnt,s_cnt;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            i1 <= 0;
            i2 <= 0;
            i3 <= 0;
            i4 <= 0;
            clk_o1 <= 0;
            clk_o2 <= 0;
            clk_o3 <= 0;
            clk_o4 <= 0;
            ns_cnt <= 0;
            us_cnt <= 0;
            ms_cnt <= 0;
            s_cnt  <= 0;
        end else begin
            if(en1) begin
                if(i1 < div1/2 - 1) begin
                    i1 <= i1 + 1;
                end else begin
                    i1 <= 0;
                    clk_o1 <= ~clk_o1;
                end
            end else begin
                i1 <= 0;
                clk_o1 <= 0;
            end
            if(en2) begin
                if(i2 < div2/2 - 1) begin
                    i2 <= i2 + 1;
                end else begin
                    i2 <= 0;
                    clk_o2 <= ~clk_o2;
                end        
            end else begin
                i2 <= 0;
                clk_o2 <= 0;
            end
            if(en3) begin
                if(i3 < div3/2 - 1) begin
                    i3 <= i3 + 1;
                end else begin
                    i3 <= 0;
                    clk_o3 <= ~clk_o3;
                end        
            end else  begin
                i3 <= 0;
                clk_o3 <= 0;
            end
            if(en4) begin
                if(i4 < div4/2 - 1) begin
                    i4 <= i4 + 1;
                end else begin
                    i4 <= 0;
                    clk_o4 <= ~clk_o4;
                end        
            end else begin
                i4 <= 0;
                clk_o4 <= 0;
            end
            if(en5) begin
                if(i5 < scp_period/2 ) begin
                    ns_cnt <= ns_cnt + 1;
                    if(ns_cnt == 99) begin
                        ns_cnt <= 0;
                        us_cnt <= us_cnt + 1;
                    end
                    if(us_cnt == 999) begin
                        us_cnt <= 0;
                        ms_cnt <= ms_cnt + 1;
                    end
                    if(ms_cnt == 999) begin
                        ms_cnt <= 0;
                        s_cnt <= s_cnt + 1;
                    end
                    case (scp_unit)
                        00: i5 <= us_cnt;
                        01: i5 <= ms_cnt;
                        02: i5 <= s_cnt;
                        default: i5 <= us_cnt;
                    endcase
                end else begin
                    i5     <= 0;
                    clk_o5 <= ~clk_o5;
                    ns_cnt <= 0;
                    us_cnt <= 0;
                    ms_cnt <= 0;
                    s_cnt  <= 0;
                end        
            end else begin
                i5     <= 0;
                clk_o5 <= 0;
                ns_cnt <= 0;
                us_cnt <= 0;
                ms_cnt <= 0;
                s_cnt  <= 0;
            end
        end 
        
    end
    
endmodule