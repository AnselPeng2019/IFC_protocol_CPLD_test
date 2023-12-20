
`timescale  1ns / 100ps

module tb_src3cpld;

    // src3cpld Parameters
    parameter PERIOD      = 20    ;
    parameter idle        = 3'b000;
    parameter pwr_on      = 3'b001;
    parameter system_up   = 3'b010;
    parameter swr_assert  = 3'b100;

    // src3cpld Inputs
    reg   ifc_cs                               = 1 ;
    reg   ifc_we_b                             = 1 ;
    reg   ifc_oe_b                             = 1 ;
    reg   ifc_avd                              = 0 ;
    reg   clock_50MHz                          = 0 ;
    reg   [1:0]  pcb_ver                       = 0 ;
    reg   voltage_drop                         = 0 ;
    reg   [15:0]  io_in                        = 0 ;
    reg   pll_100M                             = 0 ;

    // src3cpld Outputs
    wire  irq                                  ;
    wire  status_led                           ;
    wire  error_led                            ;
    wire  [15:0]  io_out                       ;

    // src3cpld Bidirs
    wire  [15:0]  ifc_ad                     ;
    reg   [15:0]  ifc_ad_r = 0                     ;
    reg   [7:0]  ifc_add_lt = 0;

    wire uart_tx;
    wire uart_rx;


    //模拟AC掉电检测
    // initial begin
    //     #100 voltage_drop <= 1;
    //     #40  voltage_drop <= 0;
    // end

    //模拟50MHz时钟输入
    initial begin
        forever
            #(PERIOD/2)  clock_50MHz = ~clock_50MHz;
    end

    //模拟100MHz时钟PLL输出
    // initial begin
    //     forever
    //         #(PERIOD/4)  pll_100M = ~pll_100M;
    // end

    //模拟16bit IFC总线写操作
    reg [7:0]addr = 34;
    reg [15:0]dataT = 16'b0000_0001_0010_0011;
    reg [15:0]dataR = 0;
    parameter START = 50;
    initial begin
        //写操作
        #100    addr[7:0] <= 34;
                // dataT <= 8'b0000_0001;
        #300    ifc_ad_r[7:0]   <= {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
                ifc_ad_r[15:8]  <= 0;
                ifc_avd <= 1;
        #10     ifc_add_lt[7:0] <= ifc_ad_r[7:0];
        #40     ifc_avd <= 0;
        #20     ifc_ad_r[15:0] <= {dataT[0],dataT[1],dataT[2], dataT[3], dataT[4], dataT[5], dataT[6], dataT[7],
                                   dataT[8],dataT[9],dataT[10],dataT[11],dataT[12],dataT[13],dataT[14],dataT[15]};
        #30     ifc_cs <= 0;
        #50     ifc_we_b <= 0;
        #80     ifc_we_b <= 1;
                ifc_cs <= 1;
        #50     ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;

        //写操作
        // #3000   addr[7:0] <= 26;
        //         dataT <= 8'b0001_0001;
        // #50     ifc_ad_r[7:0]   <= {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
        //         ifc_add_lt[7:0] <= {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
        //         ifc_avd <= 1;
        // #40     ifc_avd <= 0;
        // #20     ifc_ad_r[7:0] <= {dataT[0],dataT[1],dataT[2],dataT[3],dataT[4],dataT[5],dataT[6],dataT[7]};
        // #30     ifc_cs <= 0;
        // #50     ifc_we_b <= 0;
        // #80     ifc_we_b <= 1;
        //         ifc_cs <= 1;
        // #10     ifc_ad_r[7:0] <= 8'bxxxx_xxxx;

        //读操作
                // addr[7:0] <= 34;
        #50     ifc_ad_r[7:0] <= {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
                ifc_ad_r[15:8]  <= 0;
                ifc_avd <= 1;
        #10     ifc_add_lt[7:0] <= ifc_ad_r[7:0];
        #40     ifc_avd <= 0;
        #40     ifc_cs <= 0;
        #40     ifc_oe_b <= 0;
        #30     dataR[15:0] <= {ifc_ad[0],ifc_ad[1],ifc_ad[2], ifc_ad[3], ifc_ad[4], ifc_ad[5], ifc_ad[6], ifc_ad[7],
                               ifc_ad[8],ifc_ad[9],ifc_ad[10],ifc_ad[11],ifc_ad[12],ifc_ad[13],ifc_ad[14],ifc_ad[15]};
        #10     ifc_oe_b <= 1;
                ifc_cs   <= 1;
        #30     ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;

        //读操作
                addr[7:0] <= 0;
        #50     ifc_ad_r[7:0] <= {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
                ifc_ad_r[15:8]  <= 0;
                ifc_avd <= 1;
        #10     ifc_add_lt[7:0] <= ifc_ad_r[7:0];
        #40     ifc_avd <= 0;
        #40     ifc_cs <= 0;
        #40     ifc_oe_b <= 0;
        #30     dataR[15:0] <= {ifc_ad[0],ifc_ad[1],ifc_ad[2], ifc_ad[3], ifc_ad[4], ifc_ad[5], ifc_ad[6], ifc_ad[7],
                               ifc_ad[8],ifc_ad[9],ifc_ad[10],ifc_ad[11],ifc_ad[12],ifc_ad[13],ifc_ad[14],ifc_ad[15]};
        #10     ifc_oe_b <= 1;
                ifc_cs   <= 1;
        #30     ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;
        // //写操作
        // #50     addr[7:0] <= 0;
        //         ifc_ad_r[7:0] <= {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
        //         ifc_avd <= 1;
        // #40     ifc_avd <= 0;
        //         dataT[7:0] = 8'b0000_0000;
        // #20     ifc_ad_r[7:0] <= {dataT[0],dataT[1],dataT[2],dataT[3],dataT[4],dataT[5],dataT[6],dataT[7]};
        // #30     ifc_cs <= 0;
        // #50     ifc_we_b <= 0;
        // #80     ifc_we_b <= 1;
        //         ifc_cs <= 1;
        // #10     ifc_ad_r[7:0] <= 8'bxxxx_xxxx;

        #100 $finish;
    end


    assign ifc_ad[15:0] = ifc_oe_b ? ifc_ad_r[15:0] : 16'bzzzz_zzzz_zzzz_zzzz;


    src3cpld #(
                 .idle                    ( idle       ),
                 .pwr_on                  ( pwr_on     ),
                 .system_up               ( system_up  ),
                 .swr_assert              ( swr_assert ))
             u_src3cpld (
                 .ifc_cs                  ( ifc_cs               ),
                 .ifc_we_b                ( ifc_we_b             ),
                 .ifc_oe_b                ( ifc_oe_b             ),
                 .ifc_avd                 ( ifc_avd              ),
                 .clock_50MHz             ( clock_50MHz          ),
                 .pcb_ver                 ( pcb_ver       [1:0]  ),
                 .voltage_drop            ( voltage_drop         ),
                 .io_in                   ( io_in         [15:0] ),
                 .uart_rx                 ( uart_rx              ),

                 .irq                     ( irq                  ),
                 .status_led              ( status_led           ),
                 .error_led               ( error_led            ),
                 .io_out                  ( io_out        [15:0] ),
                 .uart_tx                 ( uart_tx              ),

                 .ifc_ad                  ( ifc_ad        [15:0]  ),
                 .ifc_addr                ( ifc_add_lt    [7:0]  )
             );

    initial begin
        // #1000
        // $finish;
    end

endmodule
