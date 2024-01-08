`timescale  1ns / 1ps

module tb_sample_timer;

// sample_timer Parameters
parameter PERIOD = 10;
parameter freq  = 100;

// sample_timer Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   en1                                  = 0 ;
reg   en2                                  = 0 ;
reg   en3                                  = 0 ;
reg   en4                                  = 0 ;
reg   en5                                  = 0 ;

// sample_timer Outputs
wire  clk_o1                               ;
wire  clk_o2                               ;
wire  clk_o3                               ;
wire  clk_o4                               ;
wire  clk_o5                               ;

reg   [9:0] scp_period;
reg   [1:0] scp_unit;
initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

sample_timer #(
    .freq ( freq )
) u_sample_timer (
    .clk                     ( clk          ),
    .rst_n                   ( rst_n        ),
    .en1                     ( en1          ),
    .en2                     ( en2          ),
    .en3                     ( en3          ),
    .en4                     ( en4          ),
    .en5                     ( en5          ),
    .scp_period              ( scp_period   ),
    .scp_unit                ( scp_unit   ),

    .clk_o1                  ( clk_o1       ),
    .clk_o2                  ( clk_o2       ),
    .clk_o3                  ( clk_o3       ),
    .clk_o4                  ( clk_o4       ),
    .clk_o5                  ( clk_o5       )
);
initial
begin
    #100 en1 = 1;
         en2 = 1;
         en3 = 1;
         en4 = 1;
         scp_period = 10;
         scp_unit = 0;
         en5 = 1;

    #1955 scp_period = 20;

    #2000 $finish;
end

endmodule