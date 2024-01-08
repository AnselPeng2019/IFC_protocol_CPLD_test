
`timescale 1ns/10ps

module src3cpld (
        ifc_ad,
        ifc_addr,
        ifc_cs,
        ifc_we_b,
        ifc_oe_b,
        ifc_avd,
        irq,
        clock_50MHz,
        status_led,
        error_led,
        pcb_ver,
        voltage_drop,
        io_in,
        io_out,
        uart_rx,
        uart_tx,
        tp13,
        tp14
    );

    inout	[15:0]ifc_ad;			//IFC data and address
    input   [7:0 ]ifc_addr;
    input	ifc_cs;					//IFC chip select
    input	ifc_we_b;				//IFC WE and POR pin
    input	ifc_oe_b;			    //IFC OE
    input	ifc_avd;			    //IFC AVD
    output	irq;			        //IRQ input of LS1046A
    input	clock_50MHz;			//50MHz input
    output	status_led;			    //Status LED control
    output  error_led;
    input	[1:0]pcb_ver;		    //PCB Revision
    input   voltage_drop;
    input   [15:0]io_in;
    output  [15:0]io_out;
    input   uart_rx;
    output  uart_tx;
    output  tp13;
    output  tp14;


    // statemachine parameters
    parameter	[3:0]st_idle            = 4'b0000;					//0 Idle
    parameter	[3:0]st_pwr_on          = 4'b0001;		    		//1 Power on
    parameter	[3:0]st_system_up       = 4'b0010;		        	//2 System up
    parameter	[3:0]st_swr_assert      = 4'b0011;	        		//3 CPLD software reset, reserve CPLD Registers value
    parameter	[3:0]st_read_block      = 4'b0100;	        		//4 read block data
    parameter	[3:0]st_write_block     = 4'b0101;	        		//5 write block data
    parameter	[3:0]st_r_frf_block     = 4'b0110;	        		//6 read frf block data
    parameter	[3:0]st_w_frf_block     = 4'b0111;	        		//7 write frf block data
    parameter	[3:0]st_r_scp_block     = 4'b1000;	        		//8 read scope block data
    parameter	[3:0]st_w_scp_block     = 4'b1001;	        		//9 write scope block data

    // uart_def Parameters
    parameter BSN        = 6     ;
    parameter BRN        = 4     ;
    parameter CLK_FRE    = 50    ;
    parameter BAUD_RATE  = 115200;

    parameter bytes_n    = 10;

    // wire	por_drive_n;			//POR drive control
    reg		pll_rst;			//PLL  ##删除赋初值
    wire	pll_lock;
    wire	pll_100M;
    wire    pll_200M;
    wire	high_cpld_clk;			//100MHz from PLL
    wire    clk;
    reg	    [7:0] cpld_addr;		//CPLD Registers address
    wire	[15:0]cpld_data;		//CPLD Registers data
    wire	cpld_cs;				//CPLD Registers chip select
    wire	reset_req;
    wire	[2:0]qspi_bank;			//QSPI Flash bank select
    wire    clk_gtp;
    wire    pll_out0;
    wire    pll_out1;

    assign  clk  = clk_gtp;
    assign  high_cpld_clk = pll_200M;

    GTP_CLKBUFG CLKBUFG_1  (
                    .CLKOUT(clk_gtp),// OUTPUT
                    .CLKIN(clock_50MHz)  // INPUT
                );

    GTP_CLKBUFG CLKBUFG_2  (
                    .CLKOUT(pll_200M),// OUTPUT
                    .CLKIN(pll_out0)  // INPUT
                );
    GTP_CLKBUFG CLKBUFG_3  (
                    .CLKOUT(pll_100M),// OUTPUT
                    .CLKIN(pll_out1)  // INPUT
                );


    reg	    pwr_hrst_n;					//CPLD internal hardware reset 
    reg	    sw_rst_n;				    //CPLD internal software reset
    reg	    pmic_pwron;

    //创建一个poweron的信号，让开机后，会从idle进入到pow_on状态对寄存器进行初始化
    reg     cpld_poweron;//

    reg	    [1:0]pll_count;
    reg	    [6:0]delay2;
    reg	    delay_flag2;


    reg	    [3:0]current_state;//
    reg	    [3:0]next_state;
    reg	    [15:0]regd;
    reg	    non_reg;
    wire    error_in;
    reg     [7:0]error_source;

    assign  error_in = |error_source;       //只要有一个error就会闪烁红灯，在单板上

    // uart_def Inputs
    reg                 uart_send_flag;
    reg                 uart_send_en;
    reg   [BSN*8-1:0]   dataT;

    // uart_def Outputs
    wire                sys_clk;
    wire                rst_n;
    wire                uart_send_comlete;
    wire  [BRN*8-1:0]   dataR;
    wire                uart_rx;
    wire                uart_tx;


    assign  tp13 = cpld_addr[0];                  //测试点信号定义
    assign  tp14 = cpld_data[0];

    //*******************************
    /*CPLD Registers uesed for input        register address*/
    reg	[15:0]cpld_ver;		            	//00, CPLD版本号
    reg	system_rst = 1'b0;					//01, CPLD软复位




    /*used for FPGA test                             reg address*/
    reg [15:0] FPGA_SYS_INFO_SERIALNUMBER;         //0x00, 设备序列号
    reg [15:0] FPGA_SYS_INFO_HWREVISION;           //0x02, 设备硬件版本号
    reg [15:0] FPGA_SYS_INFO_SOFTREVISION;         //0x04, 软件版本号
    reg [15:0] FPGA_SYS_STA_STATUS;                //0x10, FPGA 状态寄存器
    reg [15:0] FPGA_SYS_STA_ERROR;                 //0x12, 运行错误码
    reg [15:0] FPGA_SYS_STA_TIMESINCESTART;        //0x14, 设备运行时间
    reg [15:0] FPGA_HANDSHAKE_CHANNEL0;            //0x40, FPGA 握手同步寄存器
    reg [15:0] FPGA_HANDSHAKE_CHANNEL1;            //0x42, FPGA 握手同步寄存器
    reg [15:0] FPGA_COMM_CHECKSUM;                 //0x50, 设备通信通讯通道校验码
    reg [15:0] FPGA_COMM_DATALEN;                  //0x52, 设备通信通讯通道传输数据长度
    reg [15:0] FPGA_COMM_DATA;                     //0x54, 设备通信通讯通道传输数据
    reg [15:0] FPGA_APP_SCOPE_SAMPLING;            //0x56, 设备通信通讯通道传输数据长度；在FPGA中使用0x2000

    reg [7:0] freq_scp;
    wire [9:0] scp_period;
    wire [1:0] scp_unit;

    reg frf_data_avl,scope_data_avl;

    wire [63:0] sampling_cnt;
    wire [1:0] sampling_unit;

    wire hs_lock, hs_read, hs_write, hs_ready, hs_write_ok;
    wire [7:0] hs_cmd;

    wire HS1_SCOPE_FUN_EN, HS1_FRF_FUN_EN;

    assign hs_lock                   =     FPGA_HANDSHAKE_CHANNEL0[0];
    assign hs_read                   =     FPGA_HANDSHAKE_CHANNEL0[1];
    assign hs_write                  =     FPGA_HANDSHAKE_CHANNEL0[2];
    assign hs_ready                  =     FPGA_HANDSHAKE_CHANNEL0[3];
    assign hs_write_ok               =     FPGA_HANDSHAKE_CHANNEL0[4];
    assign hs_cmd[7:0]               =     FPGA_HANDSHAKE_CHANNEL0[15:8];

    assign HS1_SCOPE_FUN_EN          =     FPGA_HANDSHAKE_CHANNEL1[0];
    assign HS1_FRF_FUN_EN            =     FPGA_HANDSHAKE_CHANNEL1[1];

    assign scp_period[9:0]         =     FPGA_APP_SCOPE_SAMPLING[9:0];
    assign scp_unit[1:0]           =     FPGA_APP_SCOPE_SAMPLING[11:10];

    // circular_buffer Inputs
    wire   cb_write_enable;
    wire   cb_read_enable;
    reg   [16-1:0]  cb_data_in;
    wire  [16-1:0]  cb_data_out;

    //**************************************************************************
    //IRQ Assignment irq
    reg	irq = 0;
    reg [2:0] vd_edge = 0;//voltage drop signal edge
    wire vd_pe, vd_ne;
    assign vd_pe = vd_edge[0] == 1 && vd_edge[1] == 0;
    assign vd_ne = vd_edge[0] == 0 && vd_edge[1] == 1;
    
    //获取电压跌落信号的上升沿
    always @(posedge high_cpld_clk or negedge rst_n ) begin
        if(rst_n == 0) begin
            vd_edge <= 0;
        end
        else begin
            vd_edge[0] <= voltage_drop;
            vd_edge[1] <= vd_edge[0];
        end
    end


    //CPLD data and address assignment
    // assign	cpld_addr[7:0] = (ifc_avd) ? {ifc_ad[0], ifc_ad[1], ifc_ad[2], ifc_ad[3], ifc_ad[4], ifc_ad[5], ifc_ad[6], ifc_ad[7]} : cpld_addr[7:0];
    // assign	cpld_addr[7:0] = (ifc_avd) ? {ifc_addr[0], ifc_addr[1], ifc_addr[2], ifc_addr[3], ifc_addr[4], ifc_addr[5], ifc_addr[6], ifc_addr[7]} : cpld_addr[7:0];
    assign	cpld_data[15:0] = {ifc_ad[0], ifc_ad[1], ifc_ad[2],  ifc_ad[3],  ifc_ad[4],  ifc_ad[5],  ifc_ad[6],  ifc_ad[7],
                               ifc_ad[8], ifc_ad[9], ifc_ad[10], ifc_ad[11], ifc_ad[12], ifc_ad[13], ifc_ad[14], ifc_ad[15]};//
    assign	cpld_cs = ifc_cs;
    assign  ifc_ad[15:0] = (cpld_cs==0 && ifc_oe_b==0) ? {regd[0], regd[1], regd[2],  regd[3],  regd[4],  regd[5],  regd[6],  regd[7],
                                                          regd[8], regd[9], regd[10], regd[11], regd[12], regd[13], regd[14], regd[15]} : 16'bzzzz_zzzz_zzzz_zzzz;


    wire cs_ne, cs_pe;
    get_signal_edge  u_get_signal_edge_cs (
        .clk                     ( high_cpld_clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( cpld_cs     ),

        .pos_edge                ( cs_pe   ),
        .neg_edge                ( cs_ne   )
    );    
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_cs_pe_1 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( cs_pe    ),

        .signal_out              ( cs_pe_1cy   )
    );
    wire      avd_ne, avd_pe, avd_ne_1cy;
    get_signal_edge  u_get_signal_edge_avd (
        .clk                     ( high_cpld_clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( ifc_avd     ),

        .pos_edge                ( avd_pe   ),
        .neg_edge                ( avd_ne   )
    );    
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_avd_1 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( avd_ne    ),

        .signal_out              ( avd_ne_1cy   )
    );
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            cpld_addr <= 0;
        end
        else begin
            if (avd_ne) begin
                cpld_addr[7:0] <= {ifc_addr[0], ifc_addr[1], ifc_addr[2], ifc_addr[3], ifc_addr[4], ifc_addr[5], ifc_addr[6], ifc_addr[7]};
            end
            else begin
                cpld_addr[7:0] <= cpld_addr[7:0];
            end
        end
    end

    wire get_in_read_st;
    wire get_out_read_st;
    get_signal_edge  u_get_signal_edge_read_st (
        .clk                     ( high_cpld_clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( current_state == st_read_block     ),

        .pos_edge                ( get_in_read_st   ),
        .neg_edge                ( get_out_read_st   )
        );
    
    wire get_in_write_st, get_out_write_st;
    get_signal_edge  u_get_signal_edge_write_st (
        .clk                     ( high_cpld_clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( current_state == st_write_block     ),

        .pos_edge                ( get_in_write_st   ),
        .neg_edge                ( get_out_write_st   )
        );

    //********************************begin statemachine begin************************************************************************
    //statemachine
    always@(*)	//posedge cpld_clk
    begin
        case (current_state)
            st_idle: begin
                next_state = st_pwr_on;
            end
            st_pwr_on: begin
                if(cpld_poweron)
                    next_state = st_system_up;
                else
                    next_state = st_pwr_on;
            end
            st_system_up: begin
                if (system_rst)
                    next_state = st_swr_assert;
                else if(hs_lock && hs_read )
                    next_state = st_read_block;
                else if(hs_lock && hs_write)
                    next_state = st_write_block;
                // else if(hs_lock && hs_read  && hs_cmd == 8'h01)
                //     next_state = st_read_block;
                // else if(hs_lock && hs_write && hs_cmd == 8'h01)
                //     next_state = st_write_block;
                // else if(hs_lock && hs_write && hs_cmd == 8'h02)
                //     next_state = st_w_frf_block;
                // else if(hs_lock && hs_read  && hs_cmd == 8'h02)
                //     next_state = st_r_frf_block;
                else
                    next_state = st_system_up;
            end
            st_swr_assert: begin
                if (delay_flag2)
                    next_state = st_idle;
                else
                    next_state = st_swr_assert;
            end
            st_read_block: begin
                if (system_rst)
                    next_state = st_swr_assert;
                else if(hs_lock == 0 && hs_read == 0)
                    next_state = st_system_up;
                else
                    next_state = st_read_block;
            end
            st_write_block: begin
                if (system_rst)
                    next_state = st_swr_assert;
                else if(hs_lock == 0 && hs_write == 0)
                    next_state = st_system_up;
                else
                    next_state = st_write_block;
            end
            st_w_frf_block: begin
                if (system_rst)
                    next_state = st_swr_assert;
                else if(hs_lock == 0 && hs_write == 0)
                    next_state = st_system_up;
                else
                    next_state = st_w_frf_block;
            end
            st_r_frf_block: begin
                if (system_rst)
                    next_state = st_swr_assert;
                else if(hs_lock == 0 && hs_read == 0)
                    next_state = st_system_up;
                else
                    next_state = st_r_frf_block;
            end
            default:
                next_state = st_idle;
        endcase
    end


    always@(posedge clk)	//negedge cpld_clk
    begin
        current_state <= next_state;
    end

    //output per each state
    always@(posedge clk)	//next_state
    begin
        case (next_state)
            st_idle: begin
                pwr_hrst_n <= 1'b1;
                sw_rst_n <= 1'b1;
                pmic_pwron <= 1'b0;
                cpld_poweron <= 1'b0;
            end
            st_pwr_on: begin
                pwr_hrst_n <= 1'b0;
                sw_rst_n <= 1'b1;
                pmic_pwron <= 1'b1;
                cpld_poweron <= 1'b1;
            end
            st_system_up: begin
                pwr_hrst_n <= 1'b1;
                sw_rst_n <= 1'b1;
                pmic_pwron <= 1'b1;
            end
            // por_assert:
            // 	begin
            // 		pwr_hrst_n <= 1'b0;
            // 		sw_rst_n <= 1'b1;
            // 		pmic_pwron <= 1'b1;
            // 	end
            st_swr_assert: begin
                pwr_hrst_n <= 1'b1;
                sw_rst_n <= 1'b0;
                pmic_pwron <= 1'b1;
            end
            default: begin
                pwr_hrst_n <= 1'b1;
                sw_rst_n <= 1'b1;
                pmic_pwron <= 1'b0;
                cpld_poweron <= 1'b0;
            end
        endcase
    end

    //delay 20ns*128=2.56us
    always@(posedge clk) begin
        if (current_state == st_swr_assert) begin
            if (delay2 == 7'b111_1111) begin
                delay_flag2 <= 1'b1;
                delay2 <= 7'b0;
            end
            else
                delay2 <= delay2 +1;
        end
        else begin
            delay_flag2 <= 1'b0;
            delay2 <= 7'b0;
        end
    end
    
    //********************************end   statemachine end  ************************************************************************


    //读寄存器********************************************************************************
    //获取ifc_oe_b的下降沿
    wire oe_pe, oe_ne;
    get_signal_edge  u_get_signal_edge_oe (
        .clk                     ( high_cpld_clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( ifc_oe_b     ),

        .pos_edge                ( oe_pe   ),
        .neg_edge                ( oe_ne   )
    );    

    //延时5cycles，用于获取read_status
    delay_cy #(
        .cycles ( 5 ))
    u_delay_cy_cs_5 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               (  cpld_cs    ),

        .signal_out              ( cpld_cs_5cy   )
    );

    wire    read_status;
    wire    oe_ne_1cy;
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_rs_1 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               (  ~cpld_cs_5cy && oe_pe    ),

        .signal_out              ( read_status   )
    );

    delay_cy #(
        .cycles ( 2 ))
    u_delay_cy_oe_ne_1 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( oe_ne    ),

        .signal_out              ( oe_ne_1cy   )
    );

    //read registers
    always@(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            regd <= 0;
            cpld_ver <= 16'b0010_0001_0011_0100;//0x2134
        end
        else begin
            if (~cpld_cs && oe_ne_1cy) begin
                case (cpld_addr[7:0])
                    0:
                        regd[15:0] <= {cpld_ver[15:0]};
                    1:
                        regd[7:0] <= {7'b0,  system_rst};
                    16:
                        regd[15:0] <= {FPGA_SYS_STA_STATUS[15:0]};//0x10
                    8'h40:
                        regd[15:0] <= FPGA_HANDSHAKE_CHANNEL0;
                    8'h42:
                        regd[15:0] <= FPGA_HANDSHAKE_CHANNEL1;
                    8'h50:
                        regd[15:0] <= FPGA_COMM_CHECKSUM;
                    8'h52:
                        regd[15:0] <= FPGA_COMM_DATALEN;
                    8'h54:
                        regd[15:0] <= FPGA_COMM_DATA;
                    8'h56:
                        regd[15:0] <= FPGA_APP_SCOPE_SAMPLING;
                    default:
                        regd[15:0] <= 0;
                endcase
            end
        end
    end



    //write registers********************************************************************************************************
    //negedge ifc_we_b or negedge pwr_hrst_n or negedge sw_rst_n or posedge uart_send_comlete or negedge uart_send_flag


    wire we_pe,we_ne;
    get_signal_edge  u_get_signal_edge_we (
    .clk                     ( high_cpld_clk        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( ifc_we_b     ),

    .pos_edge                ( we_pe   ),
    .neg_edge                ( we_ne   )
    );
    wire sw_pe,sw_ne;
    get_signal_edge  u_get_signal_edge_sw (
    .clk                     ( high_cpld_clk        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( sw_rst_n     ),

    .pos_edge                ( sw_pe   ),
    .neg_edge                ( sw_ne   )
    );
    wire uart_sc_pe,uart_sc_ne;
    get_signal_edge  u_get_signal_edge_uart_sc (
    .clk                     ( high_cpld_clk        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( uart_send_comlete     ),

    .pos_edge                ( uart_sc_pe   ),
    .neg_edge                ( uart_sc_ne   )
    );

    wire write_status;
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_ws1 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( ~cpld_cs && we_ne    ),

        .signal_out              ( write_status   )
    );

    wire write_status_1cy;
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_ws2 (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( write_status    ),

        .signal_out              ( write_status_1cy   )
    );

    always@(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            /*CPLD Registers uesed for output                                 寄存器地址*/

        end     
        else begin
            if (sw_ne == 1) begin
                system_rst <= 1'b0;
            end
            else if (~cpld_cs && we_ne) begin
                case (cpld_addr[7:0])
                    1:
                        system_rst     <= cpld_data[0];
                    default:
                        non_reg        <= cpld_data[0];
                endcase

            end
            // else if(uart_sc_pe[0] == 1 && uart_sc_pe[1] == 0) begin //在发送数据完成后复位send flag信号
            //     uart_send_flag <= 0;
            // end
        end
    end

    /*******************begin protocol begin**********************/
    // reg [15:0] data_block    [0:119];
    // task reset_data_block;
    //     begin
    //         data_block[ 0] <= 16'h0000;data_block[ 1] <= 16'h0000;data_block[ 2] <= 16'h0000;data_block[ 3] <= 16'h0000;data_block[ 4] <= 16'h0000;data_block[ 5] <= 16'h0000;data_block[ 6] <= 16'h0000; data_block[ 7] <= 16'h0000; data_block[ 8] <= 16'h0000; data_block[ 9] <= 16'h0000;data_block[10] <= 16'h0000;data_block[11] <= 16'h0000;data_block[12] <= 16'h0000; data_block[13] <= 16'h0000; data_block[14] <= 16'h0000;
    //         data_block[15] <= 16'h0000;data_block[16] <= 16'h0000;data_block[17] <= 16'h0000;data_block[18] <= 16'h0000;data_block[19] <= 16'h0000;data_block[20] <= 16'h0000;data_block[21] <= 16'h0000; data_block[22] <= 16'h0000; data_block[23] <= 16'h0000; data_block[24] <= 16'h0000;data_block[25] <= 16'h0000;data_block[26] <= 16'h0000;data_block[27] <= 16'h0000; data_block[28] <= 16'h0000; data_block[29] <= 16'h0000;
    //         data_block[30] <= 16'h0000;data_block[31] <= 16'h0000;data_block[32] <= 16'h0000;data_block[33] <= 16'h0000;data_block[34] <= 16'h0000;data_block[35] <= 16'h0000;data_block[36] <= 16'h0000; data_block[37] <= 16'h0000; data_block[38] <= 16'h0000; data_block[39] <= 16'h0000;data_block[40] <= 16'h0000;data_block[41] <= 16'h0000;data_block[42] <= 16'h0000; data_block[43] <= 16'h0000; data_block[44] <= 16'h0000;
    //         data_block[45] <= 16'h0000;data_block[46] <= 16'h0000;data_block[47] <= 16'h0000;data_block[48] <= 16'h0000;data_block[49] <= 16'h0000;data_block[50] <= 16'h0000;data_block[51] <= 16'h0000; data_block[52] <= 16'h0000; data_block[53] <= 16'h0000; data_block[54] <= 16'h0000;data_block[55] <= 16'h0000;data_block[56] <= 16'h0000;data_block[57] <= 16'h0000; data_block[58] <= 16'h0000; data_block[59] <= 16'h0000;
    //         data_block[60] <= 16'h0000;data_block[61] <= 16'h0000;data_block[62] <= 16'h0000;data_block[63] <= 16'h0000;data_block[64] <= 16'h0000;data_block[65] <= 16'h0000;data_block[66] <= 16'h0000; data_block[67] <= 16'h0000; data_block[68] <= 16'h0000; data_block[69] <= 16'h0000;data_block[70] <= 16'h0000;data_block[71] <= 16'h0000;data_block[72] <= 16'h0000; data_block[73] <= 16'h0000; data_block[74] <= 16'h0000;
    //         data_block[75] <= 16'h0000;data_block[76] <= 16'h0000;data_block[77] <= 16'h0000;data_block[78] <= 16'h0000;data_block[79] <= 16'h0000;data_block[80] <= 16'h0000;data_block[81] <= 16'h0000; data_block[82] <= 16'h0000; data_block[83] <= 16'h0000; data_block[84] <= 16'h0000;data_block[85] <= 16'h0000;data_block[86] <= 16'h0000;data_block[87] <= 16'h0000; data_block[88] <= 16'h0000; data_block[89] <= 16'h0000;
    //         data_block[90] <= 16'h0000;data_block[91] <= 16'h0000;data_block[92] <= 16'h0000;data_block[93] <= 16'h0000;data_block[94] <= 16'h0000;data_block[95] <= 16'h0000;data_block[96] <= 16'h0000; data_block[97] <= 16'h0000; data_block[98] <= 16'h0000; data_block[99] <= 16'h0000;data_block[100]<= 16'h0000;data_block[101]<= 16'h0000;data_block[102]<= 16'h0000; data_block[103]<= 16'h0000; data_block[104]<= 16'h0000;
    //         data_block[105]<= 16'h0000;data_block[106]<= 16'h0000;data_block[107]<= 16'h0000;data_block[108]<= 16'h0000;data_block[109]<= 16'h0000;data_block[110]<= 16'h0000;data_block[111]<= 16'h0000; data_block[112]<= 16'h0000; data_block[113]<= 16'h0000; data_block[114]<= 16'h0000;data_block[115]<= 16'h0000;data_block[116]<= 16'h0000;data_block[117]<= 16'h0000; data_block[118]<= 16'h0000; data_block[119]<= 16'h0000;
    //     end
    // endtask

    reg [15:0] data_period    [0:59];
    task reset_period_data;
        begin
            data_period[ 0] <= 16'h0003;data_period[ 1] <= 16'h1122;data_period[ 2] <= 16'h3344;data_period[ 3] <= 16'h0004;data_period[ 4] <= 16'h1122;data_period[ 5] <= 16'h3344;data_period[ 6] <= 16'h0005; data_period[ 7] <= 16'h1122; data_period[ 8] <= 16'h3344; data_period[ 9] <= 16'h0006;data_period[10] <= 16'h1122;data_period[11] <= 16'h3344;data_period[12] <= 16'h0007; data_period[13] <= 16'h1122; data_period[14] <= 16'h3344;
            data_period[15] <= 16'h1003;data_period[16] <= 16'h1122;data_period[17] <= 16'h3344;data_period[18] <= 16'h1004;data_period[19] <= 16'h1122;data_period[20] <= 16'h3344;data_period[21] <= 16'h0005; data_period[22] <= 16'h1122; data_period[23] <= 16'h3344; data_period[24] <= 16'h0006;data_period[25] <= 16'h1122;data_period[26] <= 16'h3344;data_period[27] <= 16'h0007; data_period[28] <= 16'h1122; data_period[29] <= 16'h3344;
            data_period[30] <= 16'h2003;data_period[31] <= 16'h1122;data_period[32] <= 16'h3344;data_period[33] <= 16'h2004;data_period[34] <= 16'h1122;data_period[35] <= 16'h3344;data_period[36] <= 16'h0005; data_period[37] <= 16'h1122; data_period[38] <= 16'h3344; data_period[39] <= 16'h0006;data_period[40] <= 16'h1122;data_period[41] <= 16'h3344;data_period[42] <= 16'h0007; data_period[43] <= 16'h1122; data_period[44] <= 16'h3344;
            data_period[45] <= 16'h3003;data_period[46] <= 16'h1122;data_period[47] <= 16'h3344;data_period[48] <= 16'h3004;data_period[49] <= 16'h1122;data_period[50] <= 16'h3344;data_period[51] <= 16'h0005; data_period[52] <= 16'h1122; data_period[53] <= 16'h3344; data_period[54] <= 16'h0006;data_period[55] <= 16'h1122;data_period[56] <= 16'h3344;data_period[57] <= 16'h0007; data_period[58] <= 16'h1122; data_period[59] <= 16'h3344;
        end
    endtask

    reg [15:0]  pi;
    reg checksum_clear;
    wire checksum_en_r,checksum_en_w,checksum_en_w_2cy;
    wire [15:0] checksum_out;
    wire check_result;
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            FPGA_SYS_INFO_SERIALNUMBER              <= 16'h0000;
            FPGA_SYS_INFO_HWREVISION                <= 16'h0000;
            FPGA_SYS_INFO_SOFTREVISION              <= 16'h0000;
            FPGA_SYS_STA_STATUS                     <= 16'h0003;        //0000_0000_0000_0011
            FPGA_SYS_STA_ERROR                      <= 16'h0000;
            FPGA_SYS_STA_TIMESINCESTART             <= 16'h0000;
            FPGA_HANDSHAKE_CHANNEL0                 <= 16'h0000;        //0x40
            FPGA_HANDSHAKE_CHANNEL1                 <= 16'h0000;        //0x42
            FPGA_COMM_CHECKSUM                      <= 16'h0000;        //0x50
            FPGA_COMM_DATALEN                       <= 16'h0000;        //0x52
            FPGA_COMM_DATA                          <= 16'h0000;        //0x54
            FPGA_APP_SCOPE_SAMPLING                 <= {5'b0_0000, 2'b00, 9'd50}; //0x
            freq_scp                                <= 16'h0001;        //scope frequency, kHz
            pi                                      <= 0; 
            checksum_clear                          <= 0;
            // scp_period                              <= 5000;            //50us
            // reset_data_block;
            reset_period_data;
        end
        else begin
            if (~cpld_cs) begin//update registers
                FPGA_SYS_STA_STATUS[2] <= frf_data_avl;
                FPGA_SYS_STA_STATUS[3] <= scope_data_avl;
            end
            if (write_status) begin       //写操作
                case (cpld_addr[7:0]) 
                    8'h40:
                        FPGA_HANDSHAKE_CHANNEL0     <= cpld_data[15:0];
                    8'h42:
                        FPGA_HANDSHAKE_CHANNEL1     <= cpld_data[15:0];
                    8'h50:
                        FPGA_COMM_CHECKSUM          <= cpld_data[15:0];
                    8'h52:
                        FPGA_COMM_DATALEN           <= cpld_data[15:0];
                    8'h54:
                        FPGA_COMM_DATA              <= cpld_data[15:0];
                    8'h56:
                        FPGA_APP_SCOPE_SAMPLING     <= cpld_data[15:0];
                    default:
                        ;
                endcase
            end
            if(current_state == st_read_block && cs_ne && cpld_addr == 8'h54) begin
                $display("read block.\n");
                if(pi <= FPGA_COMM_DATALEN/2 - 1) begin
                    if(hs_cmd == 8'h01) begin //period mode
                        FPGA_COMM_DATA <= data_period[pi];
                        $display(".....Read data in period mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, data_period[pi]);
                    end else if(hs_cmd == 8'h02) begin //frf mode
                        FPGA_COMM_DATA <= data_period[pi];
                        $display(".....Read data in frf   mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, data_period[pi]);
                    end else if(hs_cmd == 8'h03) begin //scope mode
                        FPGA_COMM_DATA <= data_period[pi];
                        $display(".....Read data in scope mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, data_period[pi]);
                    end else if(hs_cmd == 8'h04) begin //para mode
                        $display(".....Here should assign FPGA_COMM_DATA with patameter data.....\n");
                    end
                    pi <= pi + 1;
                end
            end
            else if (current_state == st_write_block && cs_pe_1cy && cpld_addr == 8'h54) begin
                if(pi <= FPGA_COMM_DATALEN/2 - 1) begin
                    if(hs_cmd == 8'h01) begin //period mode
                        // data_block[pi] <= FPGA_COMM_DATA;
                        $display(".....Write data in period mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, FPGA_COMM_DATA);
                    end else if(hs_cmd == 8'h02) begin //frf mode
                        $display(".....Write data in frf    mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, FPGA_COMM_DATA);
                    end else if(hs_cmd == 8'h03) begin //scope mode
                        $display(".....Write data in scope  mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, FPGA_COMM_DATA);
                    end else if(hs_cmd == 8'h04) begin //para mode
                        $display(".....Write data in para   mode: id = %d, FPGA_COMM_DATA = %h.....\n", pi, FPGA_COMM_DATA);
                    end
                    pi <= pi + 1;
                end
            end            
            else if (current_state == st_w_frf_block && cs_pe_1cy && cpld_addr == 8'h54) begin
                if(pi <= FPGA_COMM_DATALEN/2 - 1) begin
                    // data_block[pi] <= FPGA_COMM_DATA;
                    pi <= pi + 1;
                end
            end
            else if(get_in_read_st) begin
                if(hs_cmd == 8'h01)begin        //period mode
                    // reset_data_block();
                    FPGA_HANDSHAKE_CHANNEL0[3] <= 1;//ready bit
                    FPGA_COMM_DATALEN <= 120;
                    $display(".....Ready bit is assigned %d in period mode.....\n", 120);
                    $display(".....FPGA_COMM_DATALEN was assigned %d in period mode.....\n", 120);
                end else if(hs_cmd == 8'h02) begin      //frf mode
                    $display(".....Check if frf data available.....\n");
                    if(frf_data_avl == 1) begin
                        FPGA_HANDSHAKE_CHANNEL0[3] <= 1;//set ready bit
                        FPGA_COMM_DATALEN <= 120;
                        $display(".....FPGA_COMM_DATALEN was assigned %d in period mode.....\n", 120);
                    end
                end else if(hs_cmd == 8'h03) begin      //scope mode
                    $display(".....Check if scope data available.....\n");
                    if(scope_data_avl == 1) begin
                        FPGA_HANDSHAKE_CHANNEL0[3] <= 1;//set ready bit
                        FPGA_COMM_DATALEN <= 120;
                        $display(".....FPGA_COMM_DATALEN was assigned %d in period mode.....\n", 120);
                    end
                end else if(hs_cmd == 8'h04) begin      //para  mode
                    // FPGA_HANDSHAKE_CHANNEL0[3] <= 1; //ready bit
                    FPGA_COMM_DATALEN <= 120;
                    $display(".....Ready bit is assigned in para mode.....\n");
                    $display(".....FPGA_COMM_DATALEN was assigned %d in para mode.....\n", 120);
                end
                pi <= 0;
                checksum_clear <= 0;
            end
            else if(get_in_write_st) begin
                pi <= 0;
                checksum_clear <= 0;
                FPGA_HANDSHAKE_CHANNEL0[4] <= 0;
            end
            else if(get_out_read_st) begin
                FPGA_HANDSHAKE_CHANNEL0[3] <= 0;
                checksum_clear <= 1;
            end
            else if(get_out_write_st) begin
                checksum_clear <= 1;
            end            
            else if(pi == FPGA_COMM_DATALEN/2 && read_status) begin
                FPGA_COMM_CHECKSUM <= checksum_out;
            end
            else if(pi == FPGA_COMM_DATALEN/2 && checksum_en_w_2cy) begin
                if(checksum_out == FPGA_COMM_CHECKSUM) begin //write ok check
                    FPGA_HANDSHAKE_CHANNEL0[4] <= 1;            //write ok assign
                    if(hs_cmd == 8'h02) begin   //frf mode
                        if(HS1_FRF_FUN_EN) begin
                            $display(".....start to sample frf data, enable 20kHz timer.....");
                        end
                    end else if(hs_cmd == 8'h03) begin  //scope mode
                        if(HS1_SCOPE_FUN_EN) begin
                            $display(".....start to sample scope data.....");
                            // case (sampling_unit)
                            //     00: scp_period <= sampling_cnt * 100;               //us
                            //     // 01: scp_period <= sampling_cnt * 100 * 1000;          //ms
                            //     // 02: scp_period <= sampling_cnt * 100 * 1000 * 1000;     //s
                            //     default: scp_period <= 5000;                        //default:50us
                            // endcase
                        end
                    end
                end
            end
        end
    end
    // assign checksum_en_r = (current_state == st_read_block && cs_ne && cpld_addr == 8'h54);
    delay_cy #(
        .cycles ( 2 ))
    u_delay_cy_checksum_r_2cy (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n                  ),
        .signal_in               ( current_state == st_read_block && cs_ne && cpld_addr == 8'h54    ),

        .signal_out              ( checksum_en_r   )
    );
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_checksum_w_1cy (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( current_state == st_write_block && cs_pe_1cy && cpld_addr == 8'h54    ),

        .signal_out              ( checksum_en_w   )
    );
    delay_cy #(
        .cycles ( 2 ))
    u_delay_cy_checksum_w_2cy (
        .clk                     ( high_cpld_clk          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( checksum_en_w),

        .signal_out              ( checksum_en_w_2cy   )
    );    
    wire [15:0] checksum_datain;
    // assign checksum_datain = (current_state == st_read_block) ? FPGA_COMM_DATA : data_block[pi-1];
    assign checksum_datain = (current_state == st_read_block) ? FPGA_COMM_DATA : FPGA_COMM_DATA;//used for period write test
    ifc_checksum  u_ifc_checksum (
        .clk                     ( high_cpld_clk            ),
        .rst_n                   ( rst_n          ),
        .en                      ( checksum_en_r || checksum_en_w ),
        .clear                   ( checksum_clear          ),
        .r_or_w                  ( 0         ),
        .datain                  ( checksum_datain         ),

        .checksum                ( checksum_out       )
    );

    sample_timer #(
        .freq ( 100 )
    ) u_sample_timer (
        .clk                     ( pll_100M          ),
        .rst_n                   ( rst_n        ),
        .en1                     ( HS1_FRF_FUN_EN          ),
        .en2                     ( en2          ),
        .en3                     ( en3          ),
        .en4                     ( en4          ),
        .en5                     ( HS1_SCOPE_FUN_EN          ),
        .scp_period              ( scp_period   ),
        .scp_unit                ( scp_unit   ),

        .clk_o1                  ( clk_o1       ),
        .clk_o2                  ( clk_o2       ),
        .clk_o3                  ( clk_o3       ),
        .clk_o4                  ( clk_o4       ),
        .clk_o5                  ( clk_o5       )
    );

    get_signal_edge  u_get_signal_edge_clko1 (
    .clk                     ( high_cpld_clk        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( clk_o1     ),

    .pos_edge                ( clk_o1_pe   ),
    .neg_edge                ( clk_o1_ne   )
    );
    get_signal_edge  u_get_signal_edge_clko5 (
    .clk                     ( high_cpld_clk        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( clk_o5     ),

    .pos_edge                ( clk_o5_pe   ),
    .neg_edge                ( clk_o5_ne   )
    );

    reg [7:0] cnt_frf, cnt_scope;
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt_frf <= 0;
            cnt_scope <= 0;
            frf_data_avl <= 0;
            scope_data_avl <= 0;
        end else begin
            if(clk_o1_ne && HS1_FRF_FUN_EN) begin
                if(cnt_frf == 9) begin
                    frf_data_avl <= 1;
                    cnt_frf <= 0;
                end else begin
                    cnt_frf <= cnt_frf + 1;
                end
            end else if(~HS1_FRF_FUN_EN) begin
                frf_data_avl <= 0;
                cnt_frf <= 0;
            end else if(get_out_read_st && hs_cmd == 8'h02 && frf_data_avl) begin
                frf_data_avl <= 0;
                cnt_frf <= 0;
            end
            if(clk_o5_ne && HS1_SCOPE_FUN_EN) begin
                if(cnt_scope == 9) begin
                    scope_data_avl <= 1;
                    cnt_scope <= 0;
                end else begin
                    cnt_scope <= cnt_scope + 1;
                end
            end else if(~HS1_SCOPE_FUN_EN) begin
                scope_data_avl <= 0;
                cnt_scope <= 0;
            end else if(get_out_read_st && hs_cmd == 8'h03 && scope_data_avl) begin
                scope_data_avl <= 0;
                cnt_scope <= 0;
            end
        end
    end

    /*******************end   protocol end  **********************/

    //捕捉statusled信号的下降沿作为定时发送数据的
    reg [1:0] st_ne;
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n ==0) begin
            st_ne <= 0;
        end
        else begin
            st_ne[0] <= status_led;
            st_ne[1] <= st_ne[0];
        end
    end

    //uart发送数据
    always @(posedge high_cpld_clk or negedge rst_n ) begin
        if(rst_n == 0) begin
            uart_send_flag <= 0;
            dataT <= 0;
        end
        else begin
            if (read_status) begin
            // if (cs_pe) begin
                if(uart_send_flag == 0) begin
                // if(1) begin
                    dataT <= {8'b0101_1010, cpld_addr,regd[15:8], regd[7:0], FPGA_COMM_DATA[15:8], FPGA_COMM_DATA[7:0]};
                    uart_send_flag <= 1;
                end
                else
                    uart_send_flag <= 1;
            end
            else if (write_status_1cy) begin
            // if (cs_pe) begin
                if(uart_send_flag == 0) begin
                // if(1) begin
                    dataT <= {8'b0101_1010, cpld_addr,cpld_data[15:8], cpld_data[7:0], FPGA_COMM_DATA[15:8], FPGA_COMM_DATA[7:0]};
                    uart_send_flag <= 1;
                end
                else
                    uart_send_flag <= 1;
            end
            // else if(st_ne[0] == 0 && st_ne[1] == 1) begin
            //     if(uart_send_flag == 0) begin
            //         dataT <= "AB\r\n";
            //         uart_send_flag <= 1;
            //     end
            //     else
            //         uart_send_flag <= 1;
            // end
            else if(uart_sc_pe) begin //在发送数据完成后复位send flag信号
                uart_send_flag <= 0;
            end
            // else begin
            //     uart_send_flag <= uart_send_flag;
            // end
        end
    end

    assign sys_clk = clk;
    assign rst_n = pwr_hrst_n;

    uart_def #(
                 .BSN       ( BSN         ),
                 .BRN       ( BRN         ),
                 .CLK_FRE   ( CLK_FRE     ),
                 .BAUD_RATE ( BAUD_RATE   ))
             u_uart_def (
                 .sys_clk                 ( sys_clk             ),
                 .rst_n                   ( rst_n               ),
                 .uart_send_flag          ( uart_send_flag      ),
                 .dataT                   ( dataT               ),
                 .uart_rx                 ( uart_rx             ),

                 .uart_tx                 ( uart_tx             ),
                 .uart_send_comlete       ( uart_send_comlete   ),
                 .dataR                   ( dataR               )
             );

    //在发送数据完成后复位send flag信号
    // always @(posedge uart_send_comlete) begin
    //     if(uart_send_comlete) begin
    //         uart_send_flag <= 0;
    //     end
    // end

    // always @(posedge clk or negedge rst_n) begin
    //     if(rst_n == 0)begin
    //         error_en <= 0;
    //     end
    //     else begin
    //     //     if(condition from ifc command) begin
    //     //         error_en <= 1;
    //     //     end
    //     //     else if(condition from ifc command)begin
    //     //         error_en <= 0;
    //     //     end
    //     end
    // end

    //
    led_light  u_led_light (
                   .clk                     ( clk        ),
                   .rst_n                   ( rst_n      ),
                   .error_in                ( error_in   ),
                   .error_en                ( error_en   ),

                   .runLED                  ( status_led ),
                   .errorLED                ( error_led  )
               );

    clk_pll_0 pll (
                  .clkout0(pll_out0),        // output
                  .clkout1(pll_out1),        // output
                  .lock(pll_lock),          // output
                  .clkin1(clk_gtp),         // input
                  .rst(~rst_n)              // input
              );

    circular_buffer #(
        .BUFFER_SIZE ( 10 ),
        .DATA_WIDTH  ( 16 ))
    u_circular_buffer (
        .clk                     ( high_cpld_clk            ),
        .rst_n                   ( rst_n          ),
        .write_enable            ( cb_write_enable   ),
        .read_enable             ( cb_read_enable    ),
        .data_in                 ( cb_data_in        ),

        .data_out                ( cb_data_out       )
    );

endmodule
