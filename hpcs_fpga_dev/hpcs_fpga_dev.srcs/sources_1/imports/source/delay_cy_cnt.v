/*
计数器延时模块，可用于大延时
*/

module delay_cy_cnt #(
    parameter cycles = 1000
) (
    input clk,
    input rst_n,
    input signal_in,

    output reg signal_out
);
    reg flag_r, flag_f;
    reg [1:0] sin;
    reg [15:0] cnt_r,cnt_f;

    wire sin_pe, sin_ne;

    assign sin_pe = sin[0] == 1 && sin[1] == 0;
    assign sin_ne = sin[0] == 0 && sin[1] == 1;
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            flag_r <= 0;
            flag_f <= 0;
            sin <= 2'b00;
        end
        else begin
            sin[0] <= signal_in;
            sin[1] <= sin[0];
            if (sin_pe) begin
                flag_r <= 1;
            end
            else if (sin_ne) begin
                flag_f <= 1;
            end

            if(cnt_r == cycles) begin
                flag_r <= 0;
            end
            else if (cnt_f == cycles) begin
                flag_f <= 0;
            end

        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            signal_out <= 0;
            cnt_r <= 0;
            cnt_f <= 0;
        end
        else begin
            if(cnt_r == cycles) begin
                cnt_r <= 0;
                signal_out <= 1;
            end else if(flag_r == 1) begin
                cnt_r <= cnt_r + 1;
            end

            if(cnt_f == cycles) begin
                cnt_f <= 0;
                signal_out <= 0;
            end else if(flag_f == 1) begin
                cnt_f <= cnt_f + 1;
            end
        end
    end

endmodule