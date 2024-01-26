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

        .ifc_ad_bus              ( ifc_ad_bus     )
    );
/***************************************IFC通信模块实例化*************************************/


/***************************************DDR模块实例化*****************************************/
/***************************************DDR模块实例化*****************************************/


/***************************************AD/DA模块实例化***************************************/
/***************************************AD/DA模块实例化***************************************/


endmodule
