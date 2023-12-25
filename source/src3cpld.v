
`timescale 1ns/100ps

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
    parameter	[2:0]st_idle            = 3'b000;					//Idle
    parameter	[2:0]st_pwr_on          = 3'b001;		    		//Power on
    parameter	[2:0]st_system_up       = 3'b010;		        	//System up
    parameter	[2:0]st_swr_assert      = 3'b100;	        		//CPLD software reset, reserve CPLD Registers value
    parameter	[2:0]st_read_block      = 3'b101;	        		//read block data
    parameter	[2:0]st_write_block     = 3'b110;	        		//write block data

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
    wire	high_cpld_clk;			//100MHz from PLL
    wire    clk;
    reg	    [7:0] cpld_addr;		//CPLD Registers address
    wire	[15:0]cpld_data;		//CPLD Registers data
    wire	cpld_cs;				//CPLD Registers chip select
    wire	reset_req;
    wire	[2:0]qspi_bank;			//QSPI Flash bank select
    wire    clk_gtp;
    wire    pll_out;

    assign  clk  = clk_gtp;
    assign  high_cpld_clk = pll_100M;

    GTP_CLKBUFG CLKBUFG_1  (
                    .CLKOUT(clk_gtp),// OUTPUT
                    .CLKIN(clock_50MHz)  // INPUT
                );

    GTP_CLKBUFG CLKBUFG_2  (
                    .CLKOUT(pll_100M),// OUTPUT
                    .CLKIN(pll_out)  // INPUT
                );


    reg	    pwr_hrst_n;					//CPLD internal hardware reset ##删除赋初值
    reg	    sw_rst_n;				    //CPLD internal software reset
    reg	    pmic_pwron;

    //创建一个poweron的信号，让开机后，会从idle进入到pow_on状态对寄存器进行初始化
    reg     cpld_poweron;//##删除赋初值

    reg	    [1:0]pll_count;// = 2'b00;//##删除赋初值
    reg	    [6:0]delay2;
    reg	    delay_flag2;


    reg	    [2:0]current_state;// = idle; //##删除赋初值
    reg	    [2:0]next_state;
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
    reg [1:0]cmode_sel;						//02, 控制器监控控制柜钥匙档位
    reg [3:0]ems;							//03, 控制器监控安全回路
    reg [1:0]tmp_mon;						//04, 控制器监控控制柜温度
    reg ackm_mon;							//05, 控制器监控接触器吸合
    reg sr_err;								//06, 安全继电器反馈信号
    reg [1:0]pmode_sel;						//07, 控制器监控示教器钥匙档位
    reg en12_pndt;							//08, 控制器监控示教器使能开关
    reg eq_door2_b;							//09, 设备门锁2 状态检测
    reg acpwr_mon;							//10, 控制器监控AC 电源
    reg rio_rdy;							//11, 控制器监控远程IO 板RDY 信号
    reg eq_svon_b;							//12, 安全盒启动按钮状态检测
    reg eq_remote_b;						//13, 安全盒模式切换开关状态检测
    reg [1:0]saf_ems6;						//14, 使能开关状态检测信号
    reg ems12_pndt;							//15, 示教器急停状态信号检测
    reg [1:0]saf_ems3;						//16, 未超限状态检测信号
    reg [7:0]hand_in;						//17, 连接本体端HAND IO 的INPUT信号

    /*CPLD Registers uesed for output      寄存器地址*/
    reg pndt_svon;							//18, 控制器输出SVON 信号
    reg [1:0]crh;							//19, 控制器输出安全回路信号
    reg ovrun_clr;							//20, 控制器输出OVER RUN 解除信号
    reg [4:0]ext_disp;						//21, 控制器输出信号至数码管
    reg rb_rdy;								//22, 控制器输出给上位PLC 的RDY信号
    reg rb_err;								//23, 控制器输出给上位PLC 的ERR信号
    reg svo;								//24, 控制器输出给上位PLC 的SVO信号
    reg self_son;							//25, 控制器输出的远程模式SVON 信号
    reg [7:0]hand_out;						//26, 连接本体端HAND IO 的OUTPUT信号

    /*CPLD Registers uesed for read       寄存器地址*/
    reg error_en;                           //27, 异常状态灯控制开关
    reg vin_fall;                           //28, 输入电压状态
    reg [2:0]cnt_set;                       //29, 计数器模式配置寄存器
    wire [31:0]cnt;                         //30~33，用于读写计数使用
    reg [15:0] test_16bits;                 //34, 测试16bit通信寄存器

    /*used for FPGA test                             reg address*/
    reg [15:0] FPGA_SYS_INFO_SERIALNUMBER;         //0x00, 设备序列号
    reg [15:0] FPGA_SYS_INFO_HWREVISION;           //0x02, 设备硬件版本号
    reg [15:0] FPGA_SYS_INFO_SOFTREVISION;         //0x04, 软件版本号
    reg [15:0] FPGA_SYS_STA_STATUS;                //0x10, FPGA 状态寄存器
    reg [15:0] FPGA_SYS_STA_ERROR;                 //0x12, 运行错误码
    reg [15:0] FPGA_SYS_STA_TIMESINCESTART;        //0x14, 设备运行时间
    reg [15:0] FPGA_HANDSHAKE_CHANNEL0;            //0x40, FPGA 握手寄存器
    reg [15:0] FPGA_COMM_CHECKSUM;                 //0x50, 设备通信通讯通道校验码
    reg [15:0] FPGA_COMM_DATALEN;                  //0x52, 设备通信通讯通道传输数据长度
    reg [15:0] FPGA_COMM_DATA;                     //0x54, 设备通信通讯通道传输数据

    reg [15:0] data_len;


    wire hs_lock;
    wire hs_read;
    wire hs_write;
    wire hs_ready;
    wire hs_write_ok;
    wire hs_fun_en;
    wire [7:0] hs_cmd_code;

    assign hs_lock              = FPGA_HANDSHAKE_CHANNEL0[0];
    assign hs_read              = FPGA_HANDSHAKE_CHANNEL0[1];
    assign hs_write             = FPGA_HANDSHAKE_CHANNEL0[2];
    assign hs_ready             = FPGA_HANDSHAKE_CHANNEL0[3];
    assign hs_write_ok          = FPGA_HANDSHAKE_CHANNEL0[4];
    assign hs_fun_en            = FPGA_HANDSHAKE_CHANNEL0[5];
    assign hs_cmd_code[7:0]     = FPGA_HANDSHAKE_CHANNEL0[15:8];

    // circular_buffer Inputs
    wire   cb_write_enable;
    wire   cb_read_enable;
    reg   [16-1:0]  cb_data_in;
    wire  [16-1:0]  cb_data_out;


    //用于测试读写次数
    reg     [31:0]cnt_r;
    reg     [31:0]cnt_w;

    assign cnt = cnt_set[2] ? cnt_r : cnt_w;

    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            //N.O. I IO board
            cmode_sel[1:0]    <= 0;       //
            ems[3:0] 		  <= 0;       //
            tmp_mon[1:0]	  <= 0;       //
            ackm_mon 		  <= 0;       //
            sr_err 			  <= 0;       //
            pmode_sel[1:0] 	  <= 0;       //
            en12_pndt 		  <= 0;       //
            eq_door2_b 		  <= 0;       //
            acpwr_mon 		  <= 0;       //
            rio_rdy 		  <= 0;       //
            //N.O. II IO board            //
            eq_svon_b 		  <= 0;       //
            eq_remote_b 	  <= 0;       //
            saf_ems6[1:0]	  <= 0;       //
            ems12_pndt 	  	  <= 0;       //
            saf_ems3[1:0] 	  <= 0;       //
            hand_in[7:0] 	  <= 0;       //

            //

        end
        else begin
            //N.O. I IO board cs3
            cmode_sel[1:0]    <= {io_in[0], io_in[2]};//02
            ems[3:0] 		  <= {io_in[7],io_in[5], io_in[3], io_in[1]};
            tmp_mon[1:0]	  <= {io_in[6], io_in[4]};
            ackm_mon 		  <= io_in[8];
            sr_err 			  <= io_in[9];
            pmode_sel[1:0] 	  <= {io_in[12], io_in[10]};
            en12_pndt 		  <= io_in[11];
            eq_door2_b 		  <= io_in[15];
            acpwr_mon 		  <= io_in[13];
            rio_rdy 		  <= io_in[14];//11,0x0b
            //N.O. II IO board cs4
            eq_svon_b 		  <= io_in[0];//12,0x0c
            eq_remote_b 	  <= io_in[1];
            saf_ems6[1:0]	  <= {io_in[4], io_in[2]};
            ems12_pndt 	  	  <= io_in[5];
            saf_ems3[1:0] 	  <= {io_in[6], io_in[4]};
            hand_in[7:0] 	  <= {io_in[14:7]};//17,0x11
        end
    end

    //假设所有寄存器的初始值是1
    /*IO output connector definition      				        pin number   */
    assign io_out[15:0] = {3'b011,
                           ext_disp[0],  						    //p13
                           self_son,							    //p12
                           ext_disp[1],							    //p11
                           svo,									    //p10
                           ext_disp[2],							    //p09
                           rb_err        &  hand_out[7],			//p08
                           ext_disp[3]   &  hand_out[6],			//p07
                           rb_rdy        &  hand_out[5],			//p06
                           ext_disp[4]   &  hand_out[4],			//p05
                           crh[1]        &  hand_out[3],			//p04
                           ovrun_clr     &  hand_out[2],			//p03
                           crh[0] 	     &  hand_out[1],			//p02
                           pndt_svon     &  hand_out[0]};			//p01


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

    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            irq <= 0;
            vin_fall <= 0;
        end
        else begin
            //use the edge to judge voltage drop
            // if (vd_pe) begin
            //     irq <= 1'b1;
            //     vin_fall <= 1'b1;
            // end
            // else if (vd_ne) begin
            //     vin_fall <= 1'b0;
            // end
            // else if (vd_edge == 3'b000) begin
            //     irq <= 1'b0;
            // end
            //use the voltage to judge the drop
            if(voltage_drop == 1'b1) begin
                vin_fall <= 1'b1;
                irq      <= 1'b1;
            end
            else if(voltage_drop == 1'b0) begin
                vin_fall <= 1'b0;
                irq      <= 1'b0;
            end
        end
    end

    //error signals
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            error_source <= 0;
        end
        else begin
            error_source[0] <= voltage_drop ? 1'b1 : 1'b0;
            error_source[1] <= 1'b0;
            error_source[2] <= 1'b0;
            error_source[3] <= 1'b0;
            error_source[4] <= 1'b0;
            error_source[5] <= 1'b0;
            error_source[6] <= 1'b0;
            error_source[7] <= 1'b0;
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
    get_signal_edge  u_get_signal_edge_0 (
    .clk                     ( high_cpld_clk        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( current_state == st_read_block     ),

    .pos_edge                ( get_in_read_st   ),
    .neg_edge                ( get_out_read_st   )
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
                else if(hs_lock && hs_read)
                    next_state = st_read_block;
                else if(hs_lock && hs_write)
                    next_state = st_write_block;
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
            cnt_r <= 0;
        end
        else begin
            if (~cpld_cs && oe_ne_1cy) begin
                case (cpld_addr[7:0])
                    0:
                        regd[15:0] <= {cpld_ver[15:0]};
                    1:
                        regd[7:0] <= {7'b0,  system_rst};
                    2://cs3
                        regd[7:0] <= {6'b0,  cmode_sel[1:0]};
                    3:
                        regd[7:0] <= {4'b0,  ems[3:0]};
                    4:
                        regd[7:0] <= {6'b0,  tmp_mon[1:0]};
                    5:
                        regd[7:0] <= {7'b0,  ackm_mon};
                    6:
                        regd[7:0] <= {7'b0,  sr_err};
                    7:
                        regd[7:0] <= {6'b0,  pmode_sel[1:0]};
                    8:
                        regd[7:0] <= {7'b0,  en12_pndt};
                    9:
                        regd[7:0] <= {7'b0,  eq_door2_b};
                    10:
                        regd[7:0] <= {7'b0,  acpwr_mon};
                    11:
                        regd[7:0] <= {7'b0,  rio_rdy};
                    12://cs4
                        regd[7:0] <= {7'b0,  eq_svon_b};
                    13:
                        regd[7:0] <= {7'b0,  eq_remote_b};
                    14:
                        regd[7:0] <= {6'b0,  saf_ems6[1:0]};
                    15:
                        regd[7:0] <= {7'b0,  ems12_pndt};
                    16:
                        regd[15:0] <= {FPGA_SYS_STA_STATUS[15:0]};//0x10
                    17:
                        regd[7:0] <= {       hand_in[7:0]};
                    18:
                        regd[7:0] <= {7'b0,  pndt_svon};
                    19:
                        regd[7:0] <= {6'b0,  crh[1:0]};
                    20:
                        regd[7:0] <= {7'b0,  ovrun_clr};
                    21:
                        regd[7:0] <= {3'b0,  ext_disp[4:0]};
                    22:
                        regd[7:0] <= {7'b0,  rb_rdy};
                    23:
                        regd[7:0] <= {7'b0,  rb_err};
                    24:
                        regd[7:0] <= {7'b0,  svo};
                    25:
                        regd[7:0] <= {7'b0,  self_son};
                    26:
                        regd[7:0] <=         hand_out[7:0];
                    27:
                        regd[7:0] <= {7'b0,  error_en};
                    28:
                        regd[7:0] <= {7'b0,  vin_fall};
                    29:
                        regd[7:0] <= {5'b0,  cnt_set[2:0]};
                    30:
                        regd[7:0] <= cnt[7:0];
                    31:
                        regd[7:0] <= cnt[15:8];
                    32:
                        regd[7:0] <= cnt[23:16];
                    33:
                        regd[7:0] <= cnt[31:24];
                    34:
                        regd[15:0] <= test_16bits[15:0];
                    8'h40:
                        regd[15:0] <= FPGA_HANDSHAKE_CHANNEL0;
                    8'h50:
                        regd[15:0] <= FPGA_COMM_CHECKSUM;
                    8'h52:
                        regd[15:0] <= FPGA_COMM_DATALEN;
                    8'h54:
                        regd[15:0] <= FPGA_COMM_DATA;
                    default:
                        regd[15:0] <= 0;
                endcase

                if(cnt_set[1])
                    cnt_r <= 0; //clear cnt_r
                else if(cnt_set[0] && cnt_set[2])
                    cnt_r <= cnt_r + 1; //read operation count
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

    always@(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            /*CPLD Registers uesed for output                                 寄存器地址*/
            pndt_svon      <= 1'b1;					                    //18, 控制器输出SVON 信号
            crh[1:0]       <= 2'b11;				                    //19, 控制器输出安全回路信号
            ovrun_clr      <= 1'b1;					                    //20, 控制器输出OVER RUN 解除信号
            ext_disp[4:0]  <= 5'b1_1111;			                    //21, 控制器输出信号至数码管
            rb_rdy         <= 1'b1;					                    //22, 控制器输出给上位PLC 的RDY信号
            rb_err         <= 1'b1;					                    //23, 控制器输出给上位PLC 的ERR信号
            svo            <= 1'b1;					                    //24, 控制器输出给上位PLC 的SVO信号
            self_son       <= 1'b1;					                    //25, 控制器输出的远程模式SVON 信号
            hand_out[7:0]  <= 8'b1111_1111;			                    //26, 连接本体端HAND IO 的OUTPUT信号
            error_en       <= 1'b0;                                     //27, 单板显示状态异常灯开关信号
            cnt_set        <= 0;                                        //29, 计数器模式配置寄存器
            cnt_w          <= 0;                                        //计数器值寄存器
            test_16bits    <= 16'h1234;                                 //34, 测试16bit宽度数据的寄存器

        end     
        else begin
            if (sw_ne == 1) begin
                system_rst <= 1'b0;
            end
            else if (~cpld_cs && we_ne) begin
                case (cpld_addr[7:0])
                    1:
                        system_rst     <= cpld_data[0];
                    18:
                        pndt_svon      <= cpld_data[0];
                    19:
                        crh[1:0]       <= (cpld_data[1:0] == 2'b11) ? (2'b00) : (2'b11);
                    20:
                        ovrun_clr      <= cpld_data[0];
                    21:
                        ext_disp[4:0]  <= cpld_data[4:0];
                    22:
                        rb_rdy         <= cpld_data[0];
                    23:
                        rb_err         <= cpld_data[0];
                    24:
                        svo            <= cpld_data[0];
                    25:
                        self_son       <= cpld_data[0];
                    26:
                        hand_out[7:0]  <= cpld_data[7:0];
                    27:
                        error_en       <= cpld_data[0];
                    29:
                        cnt_set        <= cpld_data[2:0];
                    34:
                        test_16bits    <= cpld_data[15:0];
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
    reg [15:0] data_block[0:4];
    reg [7:0]  pi;
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            FPGA_SYS_INFO_SERIALNUMBER              <= 16'h0000;
            FPGA_SYS_INFO_HWREVISION                <= 16'h0000;
            FPGA_SYS_INFO_SOFTREVISION              <= 16'h0000;
            FPGA_SYS_STA_STATUS                     <= 16'h0001;
            FPGA_SYS_STA_ERROR                      <= 16'h0000;
            FPGA_SYS_STA_TIMESINCESTART             <= 16'h0000;
            FPGA_HANDSHAKE_CHANNEL0                 <= 16'h0000;        //0x40
            FPGA_COMM_CHECKSUM                      <= 16'h0000;        //0x50
            FPGA_COMM_DATALEN                       <= 16'h0000;        //0x52
            FPGA_COMM_DATA                          <= 16'h0000;        //0x54

            data_block[0] <= 16'h1122;
            data_block[1] <= 16'h3344;
            data_block[2] <= 16'h5566;
            data_block[3] <= 16'h7788;
            data_block[4] <= 16'h99aa;
            pi <=0;
        end
        else begin
            if (read_status) begin//读操作

            end
            else if (write_status) begin       //写操作
                case (cpld_addr[7:0]) 
                    8'h40:
                        FPGA_HANDSHAKE_CHANNEL0     <= cpld_data[15:0];
                    8'h50:
                        FPGA_COMM_CHECKSUM          <= cpld_data[15:0];
                    8'h52:
                        FPGA_COMM_DATALEN           <= cpld_data[15:0];
                    8'h54:
                        FPGA_COMM_DATA              <= cpld_data[15:0];
                    8'h56:
                        FPGA_COMM_DATA              <= cpld_data[15:0];
                    8'h58:
                        FPGA_COMM_DATA              <= cpld_data[15:0];
                    8'h5a:
                        FPGA_COMM_DATA              <= cpld_data[15:0];
                    8'h5c:
                        FPGA_COMM_DATA              <= cpld_data[15:0];
                    default:
                        ;
                endcase
            end
            else if(current_state == st_read_block && cs_ne && cpld_addr == 8'h54) begin
                if(pi <= 5) begin
                    FPGA_COMM_DATA <= data_block[pi];
                    pi <= pi + 1;
                end
            end
            else if(get_in_read_st) begin
                FPGA_HANDSHAKE_CHANNEL0[3] <= 1;
                FPGA_COMM_DATALEN <= 10;
                pi <= 0;
            end
            else if(get_out_read_st) begin
                FPGA_HANDSHAKE_CHANNEL0[3] <= 0;
            end
        end
    end

    assign cb_write_enable = (current_state == st_read_block && cs_ne && cpld_addr == 8'h54);
    reg[7:0] wi;
    always @(posedge high_cpld_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            cb_data_in <= 0;
        end else begin
            if(cb_write_enable) begin
                
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
            if (read_status || write_status) begin
            // if (cs_pe) begin
                if(uart_send_flag == 0) begin
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
                  .clkout0(pll_out),        // output
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
