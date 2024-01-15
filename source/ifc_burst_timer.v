/*
当有输入en时，会输出3个脉冲（bursr length = 2时），用来触发读写操作，每两个脉冲间隔为15ns（需要根据实际的twp调整）
*/

module ifc_burst_timer #(
    parameter freq  = 200          //MHz,10ns period
) (
    input clk,
    input rst_n,
    input en,

    output reg rw_burst_flag,          //15ns
    output reg [7:0] cnt          //15ns
);

    reg [7:0] i1;
    reg clk_o1, start;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            i1              <= 0;
            rw_burst_flag   <= 0;
            cnt             <= 0;
            start           <= 0;
        end else begin
            if(en) begin
                start <= 1;
                cnt   <= 0;
            end
            if(start) begin
                if(cnt == 3) begin
                    start <= 0;
                    // cnt <= 0;
                    rw_burst_flag <= 0;
                end else if(i1 == 3) begin
                    i1 <= 0;
                    rw_burst_flag <= 1;
                    cnt <= cnt + 1;
                end else begin
                    i1 <= i1 + 1;
                    rw_burst_flag <= 0;
                end
            end
        end 
    end


    
endmodule