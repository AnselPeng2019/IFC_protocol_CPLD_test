
`timescale  1ns / 10ps

module tb_src3cpld;

    // src3cpld Parameters
    parameter PERIOD      = 20    ;
    parameter idle        = 3'b000;
    parameter pwr_on      = 3'b001;
    parameter system_up   = 3'b010;
    parameter swr_assert  = 3'b100;

    parameter ip_clk  = 2.85; //350Mhz
    parameter ifc_clk = 10;  //100MHz
    parameter trad   = 18*ip_clk;
    parameter taco   = 1*ip_clk;
    parameter tcs    = 1*ip_clk;
    parameter twp    = 6*ip_clk;
    parameter teadc  = 2*ip_clk;
    parameter tacse  = 3*ip_clk;
    parameter teahc  = 5*ip_clk;
    parameter tch    = 0*ip_clk;

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

    reg [7:0]addr   = 8'hxx;
    reg [15:0]dataT = 0;
    reg [15:0]dataR = 0;
    reg [15:0] data_len = 0;
    reg [15:0] data_checksum = 0;


    //char testdata[12] = {0x01,0x12, 0x33,0x44,0x55,0x66,  0x02,0x23, 0x77,0x88,0x99,0xaa};
    reg [15:0] data_write [0:5];
    initial begin
        data_write[0] = 16'h0112;
        data_write[1] = 16'h3344;
        data_write[2] = 16'h5566;
        data_write[3] = 16'h0223;
        data_write[4] = 16'h7788;
        data_write[5] = 16'h99aa;
    end
    //模拟AC掉电检测
    // initial begin
    //     #100 voltage_drop <= 1;
    //     #40  voltage_drop <= 0;
    // end

    task read_operation;
            input [7:0] address;
            // input data;
            output reg [15:0] data;
            begin
                    #150            addr[7:0]     = address;
                                    ifc_ad_r[7:0] = {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
                                    ifc_avd = 1;
                                    ifc_add_lt[7:0] = ifc_ad_r[7:0];
                    #teadc          ifc_avd = 0;
                    #(teahc+tacse)  ifc_cs  = 0;
                    #taco           ifc_oe_b = 0;
                    #trad           data[15:0] = {ifc_ad[0],ifc_ad[1],ifc_ad[2], ifc_ad[3], ifc_ad[4], ifc_ad[5], ifc_ad[6], ifc_ad[7],
                                            ifc_ad[8],ifc_ad[9],ifc_ad[10],ifc_ad[11],ifc_ad[12],ifc_ad[13],ifc_ad[14],ifc_ad[15]};
                                    ifc_oe_b  = 1;
                                    ifc_cs    = 1;
                    // #50             ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;
            end
    endtask
    
    task read_operation_set_1;
        reg [7:0] i;
        begin
            //读状态
            read_operation(8'h10,dataR);
            #50    ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;    
            //写操作,准备连续读大块数据
            write_operation(8'h40, 16'b0000_0001_0000_0011);    
            //读操作,确认是否ready
            read_operation(8'h40,dataR);
            #50    ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;
            
            //读操作,读数据长度
            read_operation(8'h52,data_len);
            #50    ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;    
            //确认ready后连续读6次操作
            
            if (dataR[3] == 1) begin
                for ( i = 0; i<(data_len/2); i=i+1) begin
                //读操作,读出6个16bit数据
                read_operation(8'h54,dataR);
                #50    ifc_ad_r[15:0] <= 16'bxxxx_xxxx_xxxx_xxxx;
                end
            end
            //read checksum 
            read_operation(8'h50,data_checksum);
            //写操作,读大块数据操作结束
            write_operation(8'h40, 16'b0000_0001_0000_0000);
        end
    endtask
    
    task write_operation;
            input [7:0] address;
            // input data;
            input [15:0] data;
            begin
            #150        addr[7:0]     = address;
                            ifc_ad_r[7:0] = {addr[0],addr[1],addr[2],addr[3],addr[4],addr[5],addr[6],addr[7]};
                            ifc_ad_r[15:8] = 8'h00;
                            ifc_avd <= 1;
                            ifc_add_lt[7:0] = ifc_ad_r[7:0];
            #teadc      ifc_avd <= 0;
            #teahc      ifc_ad_r[15:0] = {data[0],data[1],data[2], data[3], data[4], data[5], data[6], data[7],
                                            data[8],data[9],data[10],data[11],data[12],data[13],data[14],data[15]};
            #tacse      ifc_cs  = 0;
            #tcs        ifc_we_b = 0;
            #twp        ifc_we_b = 1;
            #tch        ifc_cs = 1;
            #50         ifc_ad_r[15:0] = 16'bxxxx_xxxx_xxxx_xxxx;
            end
    endtask
    
    task write_operation_set_1;
        reg [7:0] i;
            begin
                //写操作,准备连续写大块数据
                write_operation(8'h40, 16'b0000_0001_0000_0101);

                //写操作,写数据长度
                write_operation(8'h52, data_len);

                        for ( i = 0; i<(data_len/2); i=i+1) begin
                                //写操作,连续写6个16bit数据
                                write_operation(8'h54,data_write[i]);
                        end

                //写操作,连续写大块数据操作结束
                write_operation(8'h40, 16'b0000_0001_0000_0000);
            end
    endtask


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

//     reg [7:0] i = 0;
    initial begin
        //读操作
        #150
        read_operation_set_1;
        write_operation_set_1;
        read_operation_set_1;

        #200 $finish;
    end


        assign ifc_ad[15:0] = ifc_oe_b ? ifc_ad_r[15:0] : 16'bzzzz_zzzz_zzzz_zzzz;

        //probe
        wire [15:0] cpld_data;
        wire high_cpld_clk;
        wire [2:0] current_state;
        assign cpld_data = u_src3cpld.cpld_data;
        assign high_cpld_clk = u_src3cpld.high_cpld_clk;
        assign current_state = u_src3cpld.current_state;
        wire [7:0] cpld_addr;
        assign cpld_addr = u_src3cpld.cpld_addr;
        wire write_status;
        assign write_status = u_src3cpld.write_status;
        wire read_status;
        assign read_status  = u_src3cpld.read_status;
        wire [15:0] FPGA_HANDSHAKE_CHANNEL0;
        assign FPGA_HANDSHAKE_CHANNEL0 = u_src3cpld.FPGA_HANDSHAKE_CHANNEL0;
        wire [15:0] FPGA_COMM_DATA;
        assign FPGA_COMM_DATA = u_src3cpld.FPGA_COMM_DATA;

    src3cpld #(
                .st_idle        ( 3'b000 ),
                .st_pwr_on      ( 3'b001 ),
                .st_system_up   ( 3'b010 ),
                .st_swr_assert  ( 3'b100 ),
                .st_read_block  ( 3'b101 ),
                .st_write_block ( 3'b110 ),
                .BSN            ( 4      ),
                .BRN            ( 4      ),
                .CLK_FRE        ( 50     ),
                .BAUD_RATE      ( 115200 ),
                .bytes_n        ( 10     ))
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
