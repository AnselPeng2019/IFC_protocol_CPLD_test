`timescale  1ns / 1ps

module tb_delay_cy;

// delay_cy Parameters
parameter PERIOD  = 10  ;
parameter cycles  = 0;

// delay_cy Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   signal_in                            = 0 ;

// delay_cy Outputs
wire  signal_out                           ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

delay_cy #(
    .cycles ( cycles ))
 u_delay_cy (
    .clk                     ( clk          ),
    .rst_n                   ( rst_n        ),
    .signal_in               ( signal_in    ),

    .signal_out              ( signal_out   )
);

initial
begin
    #50  signal_in <= 1;
    #20  signal_in <= 0;
    $finish;
end

endmodule