module circular_buffer
#(
  parameter BUFFER_SIZE = 10,
  parameter DATA_WIDTH = 16
) (
  input wire clk,
  input wire rst_n,
  input wire write_enable,
  input wire read_enable,
  input wire [DATA_WIDTH-1:0] data_in,
  output reg [DATA_WIDTH-1:0] data_out
);


    reg [DATA_WIDTH-1:0] buffer [0:BUFFER_SIZE-1];
    reg [DATA_WIDTH-1:0] read_ptr;
    reg [DATA_WIDTH-1:0] write_ptr;

    reg [7:0] i;
    always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
        read_ptr <= 0;
        write_ptr <= 0;
        for (i = 0;i<BUFFER_SIZE;i=i+1) begin
            buffer[i] <= 0;
        end
    end else begin
        if (write_enable) begin
        buffer[write_ptr] <= data_in;
        write_ptr <= write_ptr + 1;
        if (write_ptr >= BUFFER_SIZE)
            write_ptr <= 0;
        end

        if (read_enable) begin
        data_out <= buffer[read_ptr];
        read_ptr <= read_ptr + 1;
        if (read_ptr >= BUFFER_SIZE)
            read_ptr <= 0;
        end
    end
    end

endmodule
