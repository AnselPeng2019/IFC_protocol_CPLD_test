module analog_top (
    input          clk_100M,
    input          rst_n,
    input          clk_20k,
    output         spi1_cs,         //adc port, spi1
    output         spi1_clk,        //adc port, spi1
    input          spi1_miso,       //adc port, spi1
    output         spi1_mosi,       //adc port, spi1
    output         spi2_cs,         //dac port, spi2
    output         spi2_clk,        //dac port, spi2
    output         spi2_mosi,       //dac port, spi2
    input          spi2_miso        //adc port, spi2
);
    
    wire [127:0] dac_data;
    reg  [15:0]  dac_val [7:0];
    reg          enable_sync;
    reg  [15:0]  sine_data [63:0];
    wire [127:0] spl_data;
    wire [15:0]  adc_val [7:0];
    
    assign dac_data = {dac_val[0],dac_val[1],dac_val[2],dac_val[3],dac_val[4],dac_val[5],dac_val[6],dac_val[7]};
    assign {adc_val[0],adc_val[1],adc_val[2],adc_val[3],adc_val[4],adc_val[5],adc_val[6],adc_val[7]} = spl_data;

    // statemachine state parameters
    localparam	[2:0]IDLE               = 3'b000;					//IDLE
    localparam	[2:0]GENRST             = 3'b001;		    		//生成reset信号
    localparam	[2:0]INITIAL            = 3'b010;	        		//ad5676初始化
    localparam	[2:0]SYSTEM_ON          = 3'b011;		        	//系统工作状态

    reg	    [2:0]cs;
    reg	    [2:0]ns;
    wire    isInitialized, sync_out;


//statemachine---------begin------------
    always@(rst_n or cs)	//posedge cpld_clk
    begin
        case (cs)
            IDLE: begin
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
                enable_sync <= 0;
            end
            INITIAL: begin
            end
            SYSTEM_ON: begin
                enable_sync <= 1;
            end
            default: begin
                enable_sync <= 0;
            end
        endcase
    end
//state machine-----------end------------------

    reg [7:0] i;
    always @(posedge clk_100M or negedge rst_n) begin
        if(rst_n == 0) begin
            dac_val[0] <= 16'h1000;     // 0通道数据
            dac_val[1] <= 16'h1001;     // 1通道数据
            dac_val[2] <= 16'h1002;     // 2通道数据
            dac_val[3] <= 16'h1003;     // 3通道数据
            dac_val[4] <= 16'h1004;     // 4通道数据
            dac_val[5] <= 16'h1005;     // 5通道数据
            dac_val[6] <= 16'h1006;     // 6通道数据
            dac_val[7] <= 16'h1007;     // 7通道数据
            i <= 0;
        end
        else if(isInitialized) begin
            dac_val[0] <= sine_data[i];     // 0通道数据
            dac_val[1] <= sine_data[i];     // 1通道数据
            dac_val[2] <= sine_data[i];     // 2通道数据
            dac_val[3] <= sine_data[i];     // 3通道数据
            dac_val[4] <= sine_data[i];     // 4通道数据
            dac_val[5] <= sine_data[i];     // 5通道数据
            dac_val[6] <= sine_data[i];     // 6通道数据
            dac_val[7] <= sine_data[i];     // 7通道数据
            i <= (i+1 > 63) ? 0 : i+1;
        end
    end

    dac_ad5676  u_dac_ad5676   (
        .clk                     ( clk_100M    ),
        .rst_n                   ( rst_n         ),
        .sync                    ( clk_20k       ),
        .dac_data                ( dac_data     [127:0] ),

        .isInitialized           ( isInitialized ),
        .cs_ad5676_o             ( spi2_cs       ),
        .spi_clk                 ( spi2_clk      ),
        .spi_mosi                ( spi2_mosi     )
    );
    adc_ads8688  u_adc_ads8688 (
        .clk                     ( clk_100M      ),
        .rst_n                   ( rst_n         ),
        .spi_miso                ( spi1_miso     ),
        .sync                    ( isInitialized_o  ),

        .spi_clock               ( spi1_clk      ),
        .spi_mosi                ( spi1_mosi     ),
        .spi_cs                  ( spi1_cs       ),
        .spl_data                ( spl_data     [127:0])
    );

    delay_cy_cnt #(
        .cycles ( 3200 ))
    u_delay_cy_32us (
        .clk                     ( clk_100M          ),
        .rst_n                   ( rst_n             ),
        .signal_in               ( isInitialized     ),

        .signal_out              ( isInitialized_o   )
    );

    //初始化正弦波值，仅用于测试
    always @(negedge clk_100M or negedge rst_n) begin
        if(rst_n == 0) begin
            sine_data[ 0] = 32767;
            sine_data[ 1] = 35336;
            sine_data[ 2] = 37881;
            sine_data[ 3] = 40376;
            sine_data[ 4] = 42798;
            sine_data[ 5] = 45124;
            sine_data[ 6] = 47330;
            sine_data[ 7] = 49397;
            sine_data[ 8] = 51302;
            sine_data[ 9] = 53030;
            sine_data[10] = 54562;
            sine_data[11] = 55885;
            sine_data[12] = 56985;
            sine_data[13] = 57852;
            sine_data[14] = 58477;
            sine_data[15] = 58854;
            sine_data[16] = 58981;
            sine_data[17] = 58854;
            sine_data[18] = 58477;
            sine_data[19] = 57852;
            sine_data[20] = 56985;
            sine_data[21] = 55885;
            sine_data[22] = 54562;
            sine_data[23] = 53030;
            sine_data[24] = 51302;
            sine_data[25] = 49397;
            sine_data[26] = 47330;
            sine_data[27] = 45124;
            sine_data[28] = 42798;
            sine_data[29] = 40376;
            sine_data[30] = 37881;
            sine_data[31] = 35336;
            sine_data[32] = 32767;
            sine_data[33] = 30198;
            sine_data[34] = 27653;
            sine_data[35] = 25158;
            sine_data[36] = 22735;
            sine_data[37] = 20410;
            sine_data[38] = 18203;
            sine_data[39] = 16137;
            sine_data[40] = 14231;
            sine_data[41] = 12503;
            sine_data[42] = 10971;
            sine_data[43] = 9649;
            sine_data[44] = 8549;
            sine_data[45] = 7682;
            sine_data[46] = 7057;
            sine_data[47] = 6679;
            sine_data[48] = 6554;
            sine_data[49] = 6679;
            sine_data[50] = 7057;
            sine_data[51] = 7682;
            sine_data[52] = 8549;
            sine_data[53] = 9649;
            sine_data[54] = 10971;
            sine_data[55] = 12503;
            sine_data[56] = 14231;
            sine_data[57] = 16137;
            sine_data[58] = 18203;
            sine_data[59] = 20410;
            sine_data[60] = 22735;
            sine_data[61] = 25158;
            sine_data[62] = 27653;
            sine_data[63] = 30198;
        end
    end


endmodule