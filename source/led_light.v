/**********************************************************
LED点亮模块
run   LED 单板加电之后就会闪烁，闪烁频率为5Hz
error LED 
***********************************************************/

module led_light (
        input           clk,
        input           rst_n,
        input           error_in,
        input           error_en,           //
        output reg      runLED,
        output reg      errorLED
    );

    localparam PRE_FREQ = 10000000;//50MHz / 5Hz

    reg [31:0] timer = 0;

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            timer <= 0;
            runLED <= 1;
            errorLED <= 1;
        end
        else if(timer == PRE_FREQ) begin
            timer <= 0;
            if(error_in && error_en) begin
                errorLED <= ~errorLED;
                // runLED   <= 1;
                runLED   <= ~runLED;
            end
            else begin
                runLED   <= ~runLED;
            end
        end
        else begin
            timer <= timer + 1;
        end
    end
endmodule
