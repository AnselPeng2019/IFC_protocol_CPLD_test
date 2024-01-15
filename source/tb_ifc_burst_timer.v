`timescale  1ns / 1ps

module tb_ifc_burst_timer;

// ifc_burst_timer Parameters
parameter PERIOD = 5 ;
parameter freq  = 200;

// ifc_burst_timer Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   en                                   = 0 ;
reg   [7:0] cnt                            = 0 ;

// ifc_burst_timer Outputs
wire  rw_burst_flag                        ;    


initial
begin
    forever #(2.5)  clk=~clk;
end

initial
begin
    #20         rst_n  =  1;
    #103        en = 1;
    #5          en = 0;
    #100        en = 1;
    #5          en = 0;
    #500 $finish;
end

ifc_burst_timer #(
    .freq ( freq ))
 u_ifc_burst_timer (
    .clk                     ( clk             ),
    .rst_n                   ( rst_n           ),
    .en                      ( en              ),

    .rw_burst_flag           ( rw_burst_flag   ),
    .cnt                     ( cnt             )
);

endmodule