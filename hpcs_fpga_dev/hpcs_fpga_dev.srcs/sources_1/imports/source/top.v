`timescale 1ns/10ps

module top (
        inout	[15:0] ifc_ad_bus,      //IFC data and address
        input   [15:0] ifc_addr_lat,    //IFC address latch
        input          ifc_cs,          //IFC chip select
        input          ifc_we_b,        //IFC WE and POR pin
        input          ifc_oe_b,        //IFC OE
        input          ifc_avd,         //IFC AVD
        output         irq,             //IRQ input of LS1046A
        input          sys_clk_p,       // Differentia system clock 200Mhz input on board
        input          sys_clk_n,       // Differentia system clock 200Mhz input on board
        output         spi1_cs,         //adc port, spi1
        output         spi1_clk,        //adc port, spi1
        input          spi1_miso,       //adc port, spi1
        output         spi1_mosi,       //adc port, spi1
        output         spi2_cs,         //dac port, spi2
        output         spi2_clk,        //dac port, spi2
        output         spi2_mosi,       //dac port, spi2
        input          spi2_miso        //adc port, spi2
    );

    //statemachine parameters
    localparam    [2:0]    IDLE               = 3'b000;					//IDLE
    localparam    [2:0]    GENRST             = 3'b001;		    		//生成reset信号
    localparam    [2:0]    INITIAL            = 3'b010;	        		//外设初始化：ADC+DAC
    localparam    [2:0]    SYSTEM_ON          = 3'b011;		        	//系统工作状态

/***************************************时钟实现*******************************************/
    wire	pll_lock;
    wire	clk_100M, clk_200M;
    wire    rst_n;
    reg	    [2:0] cs, ns;
    reg     sm_rstn;
    //  Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
    //   Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
    //----------------------------------------------------------------------------
    // clk_out1___200.000______0.000______50.0_______98.146_____89.971
    // clk_out2___100.000______0.000______50.0______112.316_____89.971
    clk_wiz_0 clk_mmcm_0
    (
    // Clock out ports
    .clk_out1(clk_200M),       // output clk_out1
    .clk_out2(clk_100M),       // output clk_out2
    // Status and control signals
    .locked(pll_lock),        // output locked
    // Clock in ports
    .clk_in1_p(sys_clk_p),    // input clk_in1_p
    .clk_in1_n(sys_clk_n));   // input clk_in1_n
/***************************************时钟实现*******************************************/

    assign rst_n = pll_lock & sm_rstn;//上电复位信号生成


/***************************************变量定义*******************************************/
    //fifo相关变量
    wire [1: 0] fifo_en;
    wire [15:0] fifo_rdata,fifo_wdata;
    wire [15:0] fifo_din,fifo_dout;
    wire [ 7:0] rd_data_count,wr_data_count;

    //adc, dac相关变量
    wire [127:0] dac_data;
    reg [15:0] dac_val [7:0];
    reg enable_sync;
    reg [15:0] sine_data [63:0];
    wire [127:0] spl_data;
    wire [15:0] adc_val [7:0];
    wire sync_out;
    assign dac_data = {dac_val[0],dac_val[1],dac_val[2],dac_val[3],dac_val[4],dac_val[5],dac_val[6],dac_val[7]};
    assign {adc_val[0],adc_val[1],adc_val[2],adc_val[3],adc_val[4],adc_val[5],adc_val[6],adc_val[7]} = spl_data;
/***************************************变量定义*******************************************/


/***************************************状态机实现*******************************************/
    always@(rst_n or cs)	//posedge cpld_clk
    begin
        case (cs)
            IDLE: begin
                ns = GENRST;
            end
            GENRST: begin
                ns = INITIAL;
            end
            INITIAL: begin
                ns = SYSTEM_ON;
            end
            SYSTEM_ON:begin
                ns = SYSTEM_ON; 
            end
            default:
                ns = IDLE;
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
            IDLE: begin
                sm_rstn <= 1;
            end
            GENRST: begin
                sm_rstn <= 0;
            end
            INITIAL: begin
            end
            SYSTEM_ON: begin
                sm_rstn <= 1;
            end
            default: begin
                sm_rstn <= 1;
            end
        endcase
    end
/***************************************状态机实现*******************************************/


/***************************************IFC通信模块实例化*************************************/
    ifc_top u_ifc_top (
        .clk_200M                ( clk_200M       ),
        .clk_100M                ( clk_100M       ),
        .rst_n                   ( rst_n          ),
        .ifc_addr_lat            ( ifc_addr_lat   ),
        .ifc_cs                  ( ifc_cs         ),
        .ifc_we_b                ( ifc_we_b       ),
        .ifc_oe_b                ( ifc_oe_b       ),
        .ifc_avd                 ( ifc_avd        ),

        .irq                     ( irq            ),
        .clk_20k                 ( clk_20k        ),

        .ifc_ad_bus              ( ifc_ad_bus     ),

        .fifo_en                 ( fifo_en        ),
        .fifo_rdata              ( fifo_dout   ),
        .fifo_wdata              ( fifo_wdata   )    
    );
/***************************************IFC通信模块实例化*************************************/


/***************************************FIFO模块实例化*****************************************/
    //周期数据fifo
    afifo_16i_16o_256 period_wr_fifo (
        .wr_clk(clk_200M),                // input wire wr_clk
        .rd_clk(clk_200M),                // input wire rd_clk
        .din(fifo_din),                      // input wire [15 : 0] din
        .wr_en(fifo_wr_en),                  // input wire wr_en
        .rd_en(fifo_rd_en),                  // input wire rd_en
        .dout(fifo_dout),                    // output wire [15 : 0] dout
        .full(full),                    // output wire full
        .almost_full(almost_full),      // output wire almost_full
        .empty(empty),                  // output wire empty
        .almost_empty(almost_empty),    // output wire almost_empty
        .rd_data_count(rd_data_count),  // output wire [7 : 0] rd_data_count
        .wr_data_count(wr_data_count)   // output wire [7 : 0] wr_data_count
    );
    fifo_wr #(
        .WIDTH ( 16 ))
    u_fifo_wr (
        .clk                     ( clk_200M            ),
        .rst_n                   ( rst_n          ),
        .en                      ( fifo_en[0]             ),//from ifc_top
        .wr_data                 ( fifo_wdata        ),//from ifc_top
        .almost_empty            ( almost_empty   ),
        .almost_full             ( almost_full    ),

        .fifo_wr_en              ( fifo_wr_en     ),
        .fifo_wr_data            ( fifo_din   )
    );
    fifo_rd #(
        .WIDTH ( 16 ))
    u_fifo_rd (
        .clk                     ( clk_200M            ),
        .rst_n                   ( rst_n          ),
        .en                      ( fifo_en[1]             ),//from ifc_top
        .fifo_dout               ( fifo_dout      ),//from fifo
        .almost_full             ( almost_full    ),
        .almost_empty            ( almost_empty   ),

        .fifo_rd_en              ( fifo_rd_en     ),
        .rd_data                 ( fifo_rdata        )//to ifc_top
    );
/***************************************FIFO模块实例化*****************************************/


/***************************************DDR模块实例化*****************************************/
/***************************************DDR模块实例化*****************************************/


/***************************************编码器解析模块*****************************************/
/***************************************编码器解析模块*****************************************/


/***************************************AD/DA模块实例化***************************************/
analog_top  u_analog_top (
    //inputs
    .clk_100M                ( clk_100M    ),
    .rst_n                   ( rst_n       ),
    .clk_20k                 ( clk_20k     ),
    .spi1_miso               ( spi1_miso   ),
    .spi2_miso               ( spi2_miso   ),
    //outputs
    .spi1_cs                 ( spi1_cs     ),
    .spi1_clk                ( spi1_clk    ),
    .spi1_mosi               ( spi1_mosi   ),
    .spi2_cs                 ( spi2_cs     ),
    .spi2_clk                ( spi2_clk    ),
    .spi2_mosi               ( spi2_mosi   )
);
/***************************************AD/DA模块实例化***************************************/


/***************************************算法模块实例化*****************************************/
//模拟算法模块

/***************************************算法模块实例化*****************************************/


endmodule