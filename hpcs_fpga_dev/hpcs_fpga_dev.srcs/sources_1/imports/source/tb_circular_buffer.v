

module tb_circular_buffer;

// circular_buffer Parameters
parameter PERIOD       = 10;
parameter BUFFER_SIZE  = 10;
parameter DATA_WIDTH   = 16;

// circular_buffer Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   write_enable                         = 0 ;
reg   read_enable                          = 0 ;
reg   [DATA_WIDTH-1:0]  data_in            = 0 ;

// circular_buffer Outputs
wire  [DATA_WIDTH-1:0]  data_out           ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

circular_buffer #(
    .BUFFER_SIZE ( BUFFER_SIZE ),
    .DATA_WIDTH  ( DATA_WIDTH  ))
 u_circular_buffer (
    .clk                     ( clk                            ),
    .rst_n                   ( rst_n                          ),
    .write_enable            ( write_enable                   ),
    .read_enable             ( read_enable                    ),
    .data_in                 ( data_in       [DATA_WIDTH-1:0] ),

    .data_out                ( data_out      [DATA_WIDTH-1:0] )
);

reg [7:0] i;
initial
begin
    #100 write_enable <= 1;
    for (i = 0; i<5; i=i+1) begin
            #10;
            data_in <= data_in + 1;
            $display("write data %h at %d time. \n", data_in, i);
    end
        write_enable <= 0;
    #20 read_enable <= 1;
    for (i = 0; i<3; i=i+1) begin
            #10;
            data_in <= 16'h1234;
            $display("read data %h at %d time. \n", data_in, i);
    end
        read_enable <= 0;
    $display("readptr  is %d.\n", u_circular_buffer.read_ptr);
    $display("writeptr is %d.\n", u_circular_buffer.write_ptr);

    $finish;
end

endmodule