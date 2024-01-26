module ifc_top (
    input          clk_200M,
    input          clk_100M,
    input          rst_n,
    inout	[15:0] ifc_ad_bus,     //IFC data and address
    input   [15:0] ifc_addr_lat,   //IFC address latch
    input          ifc_cs,         //IFC chip select
    input          ifc_we_b,       //IFC WE and POR pin
    input          ifc_oe_b,       //IFC OE
    input          ifc_avd,        //IFC AVD
    output         irq             //IRQ input of LS1046A
);
    
/**************************************statemachine parameters******************************************/
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
/**************************************statemachine parameters******************************************/


/***************************************IFC通信处理中间变量定义*******************************************/
    reg	    [15:0] ifc_addr_r;		//CPLD Registers address
    wire	[15:0] ifc_data_r;		//CPLD Registers data
/***************************************IFC通信处理中间变量定义*******************************************/


/***************************************状态机变量相关信号************************************************/
    reg     fpga_poweron;               //创建一个poweron的信号，让开机后，会从idle进入到pow_on状态对寄存器进行初始化
    reg	    pwr_hrst_n;					//CPLD internal hardware reset 
    reg	    sw_rst_n;				    //CPLD internal software reset
    reg	    pmic_pwron;
    reg	    [6:0]delay2;
    reg	    delay_flag2;
    reg	    [3:0]cs;
    reg	    [3:0]ns;
    reg	    [15:0]regd;
/***************************************状态机变量相关信号************************************************/

/*******************************IFC寄存器定义************************************************************/
    /*CPLD Registers uesed for input                 register address*/
    reg	system_rst;	        				       //01, CPLD软复位

    /*used for FPGA test                             reg address*/
    reg [15:0] FPGA_SYS_INFO_SERIALNUMBER;         //0x00, 设备序列号
    reg [15:0] FPGA_SYS_INFO_HWREVISION;           //0x02, 设备硬件版本号
    reg [15:0] FPGA_SYS_INFO_SOFTREVISION;         //0x04, 软件版本号
    reg [15:0] FPGA_SYS_STA_STATUS;                //0x10, FPGA 状态寄存器
    reg [15:0] FPGA_SYS_STA_ERROR;                 //0x12, 运行错误码
    reg [15:0] FPGA_SYS_STA_TIMESINCESTART_UIL;    //0x14, 设备运行时间
    reg [15:0] FPGA_SYS_STA_TIMESINCESTART_UIH;    //0x16, 设备运行时间
    reg [15:0] FPGA_HANDSHAKE_CHANNEL0;            //0x40, FPGA 握手同步寄存器
    reg [15:0] FPGA_HANDSHAKE_CHANNEL1;            //0x42, FPGA 握手同步寄存器
    reg [15:0] FPGA_COMM_CHECKSUM;                 //0x50, 设备通信通讯通道校验码
    reg [15:0] FPGA_COMM_DATALEN;                  //0x52, 设备通信通讯通道传输数据长度
    reg [15:0] FPGA_COMM_DATA;                     //0x54, 设备通信通讯通道传输数据
    reg [15:0] FPGA_APP_SCOPE_SAMPLING;            //0x56, 设备通信通讯通道传输数据长度；在FPGA中使用0x2000
    reg [15:0] FPGA_APP_DEBUG00;                   //0x58, 用于调试，查看中间变量
    reg [15:0] FPGA_APP_DEBUG01;                   //0x5A, 用于调试，查看中间变量
    reg [15:0] FPGA_APP_DEBUG02;                   //0x5C, 用于调试，查看中间变量
/*******************************IFC寄存器定义************************************************************/

/*******************************IFC标志位和计数器定义*****************************************************/
    wire [9:0] scp_period;
    wire [1:0] scp_unit;
    wire [63:0] sampling_cnt;
    wire [1:0] sampling_unit;
    wire hs_lock, hs_read, hs_write, hs_ready, hs_write_ok;
    wire [7:0] hs_cmd;
    wire HS1_SCOPE_FUN_EN, HS1_FRF_FUN_EN;
    reg [15:0] cnt_frf, cnt_scope;
    reg [31:0] sys_timer;
    reg frf_data_avl,scope_data_avl;
    reg [15:0]  pi;
    //checksum 相关变量定义
    reg checksum_clear;
    wire checksum_en_r,checksum_en_w,checksum_en_w_2cy;
    wire [15:0] checksum_out;
    wire check_result;
    wire [15:0] checksum_datain;

    assign hs_lock                   =     FPGA_HANDSHAKE_CHANNEL0[0];
    assign hs_read                   =     FPGA_HANDSHAKE_CHANNEL0[1];
    assign hs_write                  =     FPGA_HANDSHAKE_CHANNEL0[2];
    assign hs_ready                  =     FPGA_HANDSHAKE_CHANNEL0[3];
    assign hs_write_ok               =     FPGA_HANDSHAKE_CHANNEL0[4];
    assign hs_cmd[7:0]               =     FPGA_HANDSHAKE_CHANNEL0[15:8];
    assign HS1_SCOPE_FUN_EN          =     FPGA_HANDSHAKE_CHANNEL1[0];
    assign HS1_FRF_FUN_EN            =     FPGA_HANDSHAKE_CHANNEL1[1];
    assign scp_period[9:0]           =     FPGA_APP_SCOPE_SAMPLING[9:0];
    assign scp_unit[1:0]             =     FPGA_APP_SCOPE_SAMPLING[11:10];
/*******************************IFC标志位和计数器定义*****************************************************/


/*******************************各种信号边沿的定义********************************************************/
    wire cs_ne, cs_pe;
    wire clk_second_ne;
    wire avd_ne, avd_pe, avd_ne_1cy;
    wire get_in_read_st, get_out_read_st;
    wire oe_pe, oe_ne;
    wire get_in_write_st, get_out_write_st;
    wire read_status;
    wire oe_ne_1cy;
    wire we_pe,we_ne;
    wire uart_sc_pe,uart_sc_ne;
    wire write_status;
    wire write_status_1cy;
    wire sw_pe,sw_ne;
/*******************************各种信号边沿的定义********************************************************/


/*******************************周期数据制造，仅用于模拟测试***********************************************/
    reg [15:0] data_period    [0:59];
    task reset_period_data;
        begin
            data_period[ 0] <= 16'h0003;data_period[ 1] <= 16'h1122;data_period[ 2] <= 16'h3344;data_period[ 3] <= 16'h0004;data_period[ 4] <= 16'h1122;data_period[ 5] <= 16'h3344;data_period[ 6] <= 16'h0005; data_period[ 7] <= 16'h1122; data_period[ 8] <= 16'h3344; data_period[ 9] <= 16'h0006;data_period[10] <= 16'h1122;data_period[11] <= 16'h3344;data_period[12] <= 16'h0007; data_period[13] <= 16'h1122; data_period[14] <= 16'h3344;
            data_period[15] <= 16'h1003;data_period[16] <= 16'h1122;data_period[17] <= 16'h3344;data_period[18] <= 16'h1004;data_period[19] <= 16'h1122;data_period[20] <= 16'h3344;data_period[21] <= 16'h0005; data_period[22] <= 16'h1122; data_period[23] <= 16'h3344; data_period[24] <= 16'h0006;data_period[25] <= 16'h1122;data_period[26] <= 16'h3344;data_period[27] <= 16'h0007; data_period[28] <= 16'h1122; data_period[29] <= 16'h3344;
            data_period[30] <= 16'h2003;data_period[31] <= 16'h1122;data_period[32] <= 16'h3344;data_period[33] <= 16'h2004;data_period[34] <= 16'h1122;data_period[35] <= 16'h3344;data_period[36] <= 16'h0005; data_period[37] <= 16'h1122; data_period[38] <= 16'h3344; data_period[39] <= 16'h0006;data_period[40] <= 16'h1122;data_period[41] <= 16'h3344;data_period[42] <= 16'h0007; data_period[43] <= 16'h1122; data_period[44] <= 16'h3344;
            data_period[45] <= 16'h3003;data_period[46] <= 16'h1122;data_period[47] <= 16'h3344;data_period[48] <= 16'h3004;data_period[49] <= 16'h1122;data_period[50] <= 16'h3344;data_period[51] <= 16'h0005; data_period[52] <= 16'h1122; data_period[53] <= 16'h3344; data_period[54] <= 16'h0006;data_period[55] <= 16'h1122;data_period[56] <= 16'h3344;data_period[57] <= 16'h0007; data_period[58] <= 16'h1122; data_period[59] <= 16'h3344;
        end
    endtask
/*******************************周期数据制造，仅用于模拟测试***********************************************/


/*******************************各种信号边沿的提取和延时***************************************************/
    get_signal_edge  u_get_signal_edge_cs (
        .clk                     ( clk_200M        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( ifc_cs     ),

        .pos_edge                ( cs_pe   ),
        .neg_edge                ( cs_ne   )
    );    
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_cs_pe_1 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( cs_pe    ),

        .signal_out              ( cs_pe_1cy   )
    );
    get_signal_edge  u_get_signal_edge_avd (
        .clk                     ( clk_200M        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( ifc_avd     ),

        .pos_edge                ( avd_pe   ),
        .neg_edge                ( avd_ne   )
    );    
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_avd_1 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( avd_ne    ),

        .signal_out              ( avd_ne_1cy   )
    );
    get_signal_edge  u_get_signal_edge_read_st (
        .clk                     ( clk_200M        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( cs == st_read_block     ),

        .pos_edge                ( get_in_read_st   ),
        .neg_edge                ( get_out_read_st   )
        );
    
    get_signal_edge  u_get_signal_edge_write_st (
        .clk                     ( clk_200M        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( cs == st_write_block     ),

        .pos_edge                ( get_in_write_st   ),
        .neg_edge                ( get_out_write_st   )
        );
    get_signal_edge  u_get_signal_edge_oe (
        .clk                     ( clk_200M        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( ifc_oe_b     ),

        .pos_edge                ( oe_pe   ),
        .neg_edge                ( oe_ne   )
    );    
    delay_cy #(
        .cycles ( 5 ))
    u_delay_cy_cs_5 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               (  ifc_cs    ),

        .signal_out              ( cpld_cs_5cy   )
    );

    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_rs_1 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               (  ~cpld_cs_5cy && oe_pe    ),

        .signal_out              ( read_status   )
    );

    delay_cy #(
        .cycles ( 2 ))
    u_delay_cy_oe_ne_1 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( oe_ne    ),

        .signal_out              ( oe_ne_1cy   )
    );
    get_signal_edge  u_get_signal_edge_we (
    .clk                     ( clk_200M        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( ifc_we_b     ),

    .pos_edge                ( we_pe   ),
    .neg_edge                ( we_ne   )
    );
    get_signal_edge  u_get_signal_edge_sw (
    .clk                     ( clk_200M        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( sw_rst_n     ),

    .pos_edge                ( sw_pe   ),
    .neg_edge                ( sw_ne   )
    );
    get_signal_edge  u_get_signal_edge_uart_sc (
    .clk                     ( clk_200M        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( uart_send_comlete     ),

    .pos_edge                ( uart_sc_pe   ),
    .neg_edge                ( uart_sc_ne   )
    );

    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_ws1 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( ~ifc_cs && we_ne    ),

        .signal_out              ( write_status   )
    );

    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_ws2 (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( write_status    ),

        .signal_out              ( write_status_1cy   )
    );
    delay_cy #(
        .cycles ( 2 ))
    u_delay_cy_checksum_r_2cy (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n                  ),
        .signal_in               ( cs == st_read_block && cs_ne && ifc_addr_r == 16'h54    ),

        .signal_out              ( checksum_en_r   )
    );
    delay_cy #(
        .cycles ( 1 ))
    u_delay_cy_checksum_w_1cy (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( cs == st_write_block && cs_pe_1cy && ifc_addr_r == 16'h54    ),

        .signal_out              ( checksum_en_w   )
    );
    delay_cy #(
        .cycles ( 2 ))
    u_delay_cy_checksum_w_2cy (
        .clk                     ( clk_200M          ),
        .rst_n                   ( rst_n        ),
        .signal_in               ( checksum_en_w),

        .signal_out              ( checksum_en_w_2cy   )
    );    
    get_signal_edge  u_get_signal_edge_clko1 (
    .clk                     ( clk_200M        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( clk_o1     ),

    .pos_edge                ( clk_o1_pe   ),
    .neg_edge                ( clk_o1_ne   )
    );
    get_signal_edge  u_get_signal_edge_clko5 (
    .clk                     ( clk_200M        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( clk_o5     ),

    .pos_edge                ( clk_o5_pe   ),
    .neg_edge                ( clk_o5_ne   )
    );
    get_signal_edge  u_get_signal_edge_clk_sencond (
    .clk                     ( clk_200M        ),
    .rst_n                   ( rst_n      ),
    .signal                  ( clk_second     ),

    .pos_edge                ( clk_second_pe   ),
    .neg_edge                ( clk_second_ne   )
    );
/*******************************各种信号边沿的提取和延时***************************************************/

/*******************************IFC总线数据和地址位的移位处理**********************************************/
    assign	ifc_data_r[15:0] = {ifc_ad_bus[0], ifc_ad_bus[1], ifc_ad_bus[2],  ifc_ad_bus[3],  ifc_ad_bus[4],  ifc_ad_bus[5],  ifc_ad_bus[6],  ifc_ad_bus[7],
                               ifc_ad_bus[8], ifc_ad_bus[9], ifc_ad_bus[10], ifc_ad_bus[11], ifc_ad_bus[12], ifc_ad_bus[13], ifc_ad_bus[14], ifc_ad_bus[15]};//
    assign  ifc_ad_bus[15:0] = (ifc_cs==0 && ifc_oe_b==0) ? {regd[0], regd[1], regd[2],  regd[3],  regd[4],  regd[5],  regd[6],  regd[7],
                                                          regd[8], regd[9], regd[10], regd[11], regd[12], regd[13], regd[14], regd[15]} : 16'bzzzz_zzzz_zzzz_zzzz;
    always @(posedge clk_200M or negedge rst_n) begin
        if(rst_n == 0) begin
            ifc_addr_r <= 0;
        end
        else begin
            if (avd_ne) begin
                ifc_addr_r[15:0] <= {ifc_addr_lat[0], ifc_addr_lat[1], ifc_addr_lat[2],  ifc_addr_lat[3],  ifc_addr_lat[4],  ifc_addr_lat[5],  ifc_addr_lat[6],  ifc_addr_lat[7],
                                    ifc_addr_lat[8], ifc_addr_lat[9], ifc_addr_lat[10], ifc_addr_lat[11], ifc_addr_lat[12], ifc_addr_lat[13], ifc_addr_lat[14], ifc_addr_lat[15]};
                // ifc_addr_r[7:0] <= {ifc_addr_lat[0], ifc_addr_lat[1], ifc_addr_lat[2],  ifc_addr_lat[3],  ifc_addr_lat[4],  ifc_addr_lat[5],  ifc_addr_lat[6],  ifc_addr_lat[7]};
            end
        end
    end
/*******************************IFC总线数据和地址位的移位处理**********************************************/


/**********************************************状态机的实现***********************************************/

    //statemachine
    always@(*)	//posedge cpld_clk
    begin
        case (cs)
            st_idle: begin
                ns = st_pwr_on;
            end
            st_pwr_on: begin
                if(fpga_poweron)
                    ns = st_system_up;
                else
                    ns = st_pwr_on;
            end
            st_system_up: begin
                if (system_rst)
                    ns = st_swr_assert;
                else if(hs_lock && hs_read )
                    ns = st_read_block;
                else if(hs_lock && hs_write)
                    ns = st_write_block;
                // else if(hs_lock && hs_read  && hs_cmd == 8'h01)
                //     ns = st_read_block;
                // else if(hs_lock && hs_write && hs_cmd == 8'h01)
                //     ns = st_write_block;
                // else if(hs_lock && hs_write && hs_cmd == 8'h02)
                //     ns = st_w_frf_block;
                // else if(hs_lock && hs_read  && hs_cmd == 8'h02)
                //     ns = st_r_frf_block;
                else
                    ns = st_system_up;
            end
            st_swr_assert: begin
                if (delay_flag2)
                    ns = st_idle;
                else
                    ns = st_swr_assert;
            end
            st_read_block: begin
                if (system_rst)
                    ns = st_swr_assert;
                else if(hs_lock == 0 && hs_read == 0)
                    ns = st_system_up;
                else
                    ns = st_read_block;
            end
            st_write_block: begin
                if (system_rst)
                    ns = st_swr_assert;
                else if(hs_lock == 0 && hs_write == 0)
                    ns = st_system_up;
                else
                    ns = st_write_block;
            end
            st_w_frf_block: begin
                if (system_rst)
                    ns = st_swr_assert;
                else if(hs_lock == 0 && hs_write == 0)
                    ns = st_system_up;
                else
                    ns = st_w_frf_block;
            end
            st_r_frf_block: begin
                if (system_rst)
                    ns = st_swr_assert;
                else if(hs_lock == 0 && hs_read == 0)
                    ns = st_system_up;
                else
                    ns = st_r_frf_block;
            end
            default:
                ns = st_idle;
        endcase
    end


    always@(posedge clk_100M)	//negedge cpld_clk
    begin
        cs <= ns;
    end

    //output per each state
    always@(posedge clk_100M)	//ns
    begin
        case (ns)
            st_idle: begin
                pwr_hrst_n <= 1'b1;
                sw_rst_n <= 1'b1;
                pmic_pwron <= 1'b0;
                fpga_poweron <= 1'b0;
            end
            st_pwr_on: begin
                pwr_hrst_n <= 1'b0;
                sw_rst_n <= 1'b1;
                pmic_pwron <= 1'b1;
                fpga_poweron <= 1'b1;
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
                fpga_poweron <= 1'b0;
            end
        endcase
    end

    //delay 
    always@(posedge clk_200M) begin
        if (cs == st_swr_assert) begin
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
/**********************************************状态机的实现***********************************************/


/**********************************************IFC单读操作的实现******************************************/
    always@(posedge clk_200M or negedge rst_n) begin
        if(rst_n == 0) begin
            regd <= 0;
        end
        else begin
            if (~ifc_cs && oe_ne_1cy) begin
                case (ifc_addr_r[15:0])
                    1:
                        regd[7:0] <= {7'b0,  system_rst};
                    16'h10:
                        regd[15:0] <= {FPGA_SYS_STA_STATUS[15:0]};//0x10
                    16'h14:
                        regd[15:0] <= FPGA_SYS_STA_TIMESINCESTART_UIL;
                    16'h16:
                        regd[15:0] <= FPGA_SYS_STA_TIMESINCESTART_UIH;
                    16'h40:
                        regd[15:0] <= FPGA_HANDSHAKE_CHANNEL0;
                    16'h42:
                        regd[15:0] <= FPGA_HANDSHAKE_CHANNEL1;
                    16'h50:
                        regd[15:0] <= FPGA_COMM_CHECKSUM;
                    16'h52:
                        regd[15:0] <= FPGA_COMM_DATALEN;
                    16'h54:
                        regd[15:0] <= FPGA_COMM_DATA;
                    16'h56:
                        regd[15:0] <= FPGA_APP_SCOPE_SAMPLING;
                    16'h58:
                        regd[15:0] <= FPGA_APP_DEBUG00;
                    16'h5A:
                        regd[15:0] <= FPGA_APP_DEBUG01;
                    16'h5C:
                        regd[15:0] <= FPGA_APP_DEBUG02;
                    default:
                        regd[15:0] <= 0;
                endcase
            end
        end
    end
/**********************************************IFC单读操作的实现******************************************/

/**********************************************IFC单写操作的实现******************************************/
    always@(posedge clk_200M or negedge rst_n) begin
        if(rst_n == 0) begin
            /*CPLD Registers uesed for output                                 寄存器地址*/

        end     
        else begin
            if (sw_ne == 1) begin
                system_rst <= 1'b0;
            end
            else if (~ifc_cs && we_ne) begin
                case (ifc_addr_r[15:0])
                    1:
                        system_rst     <= ifc_data_r[0];
                    default:;
                        
                endcase

            end
            // else if(uart_sc_pe[0] == 1 && uart_sc_pe[1] == 0) begin //在发送数据完成后复位send flag信号
            //     uart_send_flag <= 0;
            // end
        end
    end
/**********************************************IFC单写操作的实现******************************************/

/**********************************************IFC连写连读操作的实现***************************************/
    always @(posedge clk_200M or negedge rst_n) begin
        if(rst_n == 0) begin
            FPGA_SYS_INFO_SERIALNUMBER              <= 16'h0000;
            FPGA_SYS_INFO_HWREVISION                <= 16'h0000;
            FPGA_SYS_INFO_SOFTREVISION              <= 16'h0000;
            FPGA_SYS_STA_STATUS                     <= 16'h0003;        //0000_0000_0000_0011
            FPGA_SYS_STA_ERROR                      <= 16'h0000;
            FPGA_SYS_STA_TIMESINCESTART_UIL         <= 16'h0000;
            FPGA_SYS_STA_TIMESINCESTART_UIH         <= 16'h0000;
            FPGA_HANDSHAKE_CHANNEL0                 <= 16'h0000;        //0x40
            FPGA_HANDSHAKE_CHANNEL1                 <= 16'h0000;        //0x42
            FPGA_COMM_CHECKSUM                      <= 16'h0000;        //0x50
            FPGA_COMM_DATALEN                       <= 16'h0000;        //0x52
            FPGA_COMM_DATA                          <= 16'h0000;        //0x54
            FPGA_APP_SCOPE_SAMPLING                 <= {5'b0_0000, 2'b00, 9'd50}; //0x
            pi                                      <= 0; 
            checksum_clear                          <= 0;
            sys_timer                               <= 0;
            // scp_period                              <= 5000;            //50us
            // reset_data_block;
            reset_period_data;
        end
        else begin
            if (cs_ne) begin//update registers
                FPGA_SYS_STA_STATUS[2]    <= frf_data_avl;
                FPGA_SYS_STA_STATUS[3]    <= scope_data_avl;
                FPGA_APP_DEBUG00          <= cnt_frf;
                FPGA_APP_DEBUG01          <= cnt_scope;
                FPGA_APP_DEBUG02          <= pi;
            end 
            if(clk_second_ne) begin //系统计时，单位为秒
                sys_timer <= sys_timer + 1;
                FPGA_SYS_STA_TIMESINCESTART_UIL <= sys_timer[15: 0];
                FPGA_SYS_STA_TIMESINCESTART_UIH <= sys_timer[31:16];
            end
            if (write_status) begin       //写操作
                case (ifc_addr_r[15:0]) 
                    16'h14:
                        FPGA_SYS_STA_TIMESINCESTART_UIL     <= ifc_data_r[15:0];
                    16'h16:
                        FPGA_SYS_STA_TIMESINCESTART_UIH     <= ifc_data_r[15:0];
                    16'h40:
                        FPGA_HANDSHAKE_CHANNEL0             <= ifc_data_r[15:0];
                    16'h42:
                        FPGA_HANDSHAKE_CHANNEL1             <= ifc_data_r[15:0];
                    16'h50:
                        FPGA_COMM_CHECKSUM                  <= ifc_data_r[15:0];
                    16'h52:
                        FPGA_COMM_DATALEN                   <= ifc_data_r[15:0];
                    16'h54:
                        FPGA_COMM_DATA                      <= ifc_data_r[15:0];
                    16'h56:
                        FPGA_APP_SCOPE_SAMPLING             <= ifc_data_r[15:0];
                    16'h58:
                        FPGA_APP_DEBUG00                    <= ifc_data_r[15:0];
                    16'h5A:
                        FPGA_APP_DEBUG01                    <= ifc_data_r[15:0];
                    default:
                        ;
                endcase
            end 
            if(cs == st_read_block && cs_ne && ifc_addr_r == 16'h54) begin
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
            else if (cs == st_write_block && cs_pe_1cy && ifc_addr_r == 16'h54) begin
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
            else if (cs == st_w_frf_block && cs_pe_1cy && ifc_addr_r == 16'h54) begin
                if(pi <= FPGA_COMM_DATALEN/2 - 1) begin
                    // data_block[pi] <= FPGA_COMM_DATA;
                    pi <= pi + 1;
                end
            end
            if(get_in_read_st) begin
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
                        $display(".....FPGA_COMM_DATALEN was assigned %d in frf mode.....\n", 120);
                    end
                end else if(hs_cmd == 8'h03) begin      //scope mode
                    $display(".....Check if scope data available.....\n");
                    if(scope_data_avl == 1) begin
                        FPGA_HANDSHAKE_CHANNEL0[3] <= 1;//set ready bit
                        FPGA_COMM_DATALEN <= 120;
                        $display(".....FPGA_COMM_DATALEN was assigned %d in scope mode.....\n", 120);
                    end
                end else if(hs_cmd == 8'h04) begin      //para  mode
                    // FPGA_HANDSHAKE_CHANNEL0[3] <= 1;//ready bit
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
/**********************************************IFC连写连读操作的实现***************************************/


/**********************************************Checksum模块实现*******************************************/
    assign checksum_datain = (cs == st_read_block) ? FPGA_COMM_DATA : FPGA_COMM_DATA;//used for period write test
    ifc_checksum  u_ifc_checksum (
        .clk                     ( clk_200M            ),
        .rst_n                   ( rst_n          ),
        .en                      ( checksum_en_r || checksum_en_w ),
        .clear                   ( checksum_clear          ),
        .r_or_w                  ( 0         ),
        .datain                  ( checksum_datain         ),

        .checksum                ( checksum_out       )
    );
/**********************************************Checksum模块实现*******************************************/


/**********************************************定时器模块实现**********************************************/
    //用于实现frf和scope数据采样的定时
    sample_timer #(
        .freq ( 100 )
    ) u_sample_timer1 (
        .clk                     ( clk_100M          ),
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
    //用于实现单板运行时间的定时
    sample_timer #(
        .freq ( 100 )
    ) u_sample_timer2 (
        .clk                     ( clk_100M          ),
        .rst_n                   ( rst_n        ),
        .en1                     (           ),
        .en2                     (           ),
        .en3                     (           ),
        .en4                     (           ),
        .en5                     ( rst_n          ),
        .scp_period              ( 1000   ),
        .scp_unit                ( 1   ),

        .clk_o1                  (        ),
        .clk_o2                  (        ),
        .clk_o3                  (        ),
        .clk_o4                  (        ),
        .clk_o5                  ( clk_second       )
    );
    always @(posedge clk_200M or negedge rst_n) begin
        if(~rst_n) begin
            cnt_frf <= 0;
            cnt_scope <= 0;
            frf_data_avl <= 0;
            scope_data_avl <= 0;
        end else begin
            if(~HS1_FRF_FUN_EN) begin
                frf_data_avl  <= 0;
                cnt_frf       <= 0;
            end else if(get_out_read_st && hs_cmd == 8'h02 && frf_data_avl) begin
                frf_data_avl <= 0;
                if(cnt_frf > 9) begin
                    cnt_frf <= cnt_frf - 10;
                end
                // cnt_frf      <= 0;
            end else if(clk_o1_ne && HS1_FRF_FUN_EN) begin
                if(cnt_frf > 9) begin
                    frf_data_avl <= 1;
                    cnt_frf <= cnt_frf + 1;
                end else begin
                    cnt_frf <= cnt_frf + 1;
                end
            end
            if(~HS1_SCOPE_FUN_EN) begin
                scope_data_avl  <= 0;
                cnt_scope       <= 0;
            end else if(get_out_read_st && hs_cmd == 8'h03 && scope_data_avl) begin
                scope_data_avl <= 0;
                if(cnt_scope > 9) begin
                    cnt_scope <= cnt_scope - 10;
                end
            end else if(clk_o5_ne && HS1_SCOPE_FUN_EN) begin
                if(cnt_scope > 9) begin
                    scope_data_avl <= 1;
                    cnt_scope <= cnt_scope + 1;
                end else begin
                    cnt_scope <= cnt_scope + 1;
                end
            end
        end
    end
/**********************************************定时器模块实现**********************************************/


/**********************************************ILA逻辑分析仪***********************************************/
    wire [15:0] probe0;
    wire [15:0] probe1;
    wire [15:0] probe2;
    wire [15:0] probe3;
    wire [15:0] probe4;
    wire [15:0] probe5;
    wire [15:0] probe6;
    wire [15:0] probe7;
    wire [15:0] probe8;
    wire [15:0] probe9;
    wire  probe10;
    wire  probe11;
    wire  probe12;
    wire  probe13;
    wire  probe14;
    wire  probe15;

    ila_0 u_ila_0 (
        .clk(clk_200M), // input wire clk

        .probe0(probe0), // input wire [15:0]  probe0  
        .probe1(probe1), // input wire [15:0]  probe1 
        .probe2(probe2), // input wire [15:0]  probe2 
        .probe3(probe3), // input wire [15:0]  probe3 
        .probe4(probe4), // input wire [15:0]  probe4 
        .probe5(probe5), // input wire [15:0]  probe5 
        .probe6(probe6), // input wire [15:0]  probe6 
        .probe7(probe7), // input wire [15:0]  probe7 
        .probe8(probe8), // input wire [15:0]  probe8 
        .probe9(probe9), // input wire [15:0]  probe9 
        .probe10(probe10), // input wire [0:0]  probe10 
        .probe11(probe11), // input wire [0:0]  probe11 
        .probe12(probe12), // input wire [0:0]  probe12 
        .probe13(probe13), // input wire [0:0]  probe13 
        .probe14(probe14), // input wire [0:0]  probe14 
        .probe15(probe15) // input wire [0:0]  probe15 cnt_scope
    );
    assign probe0  = ifc_ad_bus;
    assign probe1  = ifc_addr_lat;
    assign probe3  = ifc_data_r;
    assign probe4  = ifc_addr_r;
    assign probe5  = checksum_out;
    assign probe6  = FPGA_HANDSHAKE_CHANNEL0;
    assign probe7  = FPGA_SYS_STA_STATUS;
    assign probe8  = FPGA_HANDSHAKE_CHANNEL1;
    assign probe2  = cnt_scope;
    assign probe10 = ifc_cs;
    assign probe11 = ifc_we_b;
    assign probe12 = ifc_oe_b;
    assign probe13 = ifc_avd;
    assign probe14 = scope_data_avl;
/**********************************************ILA逻辑分析仪***********************************************/

endmodule