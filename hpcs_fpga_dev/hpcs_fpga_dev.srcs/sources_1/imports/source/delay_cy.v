/***************************************************************************************
delay whole wave
                     delay 1 cycle
                     ↓    ↓
clk:          __|¯|__|¯|__|¯|__|¯|__|¯|__|¯|__
signal in:    _______|¯¯|_____________________
signbal out:  ____________|¯¯¯¯|______________
cycles >=1 
****************************************************************************************/


module delay_cy #(
    parameter cycles = 10
) (
    input clk,
    input rst_n,
    input signal_in,

    output reg signal_out
);
  reg [cycles-1:0] prev_data;

  always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
      prev_data <= 0;  // 初始化前 100 个时钟周期的数据为 0
      signal_out <= 0;
    end else begin
      prev_data <= {prev_data[cycles-1:0], signal_in};  // 将当前时钟周期的输入数据存储到 prev_data 中
      signal_out <= prev_data[cycles-1];  // 输出前 100 个时钟周期之前的数据
    end
  end

endmodule