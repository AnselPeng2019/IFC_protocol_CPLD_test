module dac_ad5676 (input            clk,
                   input            rst_n,
                   input            sync,
                   input [127:0]    dac_data,
                   output           isInitialized,
                   output           cs_ad5676_o,
                   output           spi_clk,
                   output           spi_mosi);


    // reg [3:0]       cmd;
    // reg [3:0]       addr;
    // reg [15:0]      v_data;//0~65535
    // wire [23:0]     cmdData;
    // assign cmdData = {cmd, addr, v_data};

    reg  wr_req, cs_ad5676;
    wire sync_pe;

    get_signal_edge  u_get_signal_edge (
        .clk                     ( clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( sync       ),

        .pos_edge                ( sync_pe    ),
        .neg_edge                (            )
    );

    // statemachine state parameters
    localparam	[2:0]IDLE               = 3'b000;					//IDLE
    localparam	[2:0]SYSTEM_ON          = 3'b001;	        		//系统工作状态
    localparam	[2:0]INITIAL            = 3'b010;		        	//ad5676初始化
    localparam	[2:0]GENWAVE            = 3'b011;	        		//波形输出

    reg	    [2:0]cs;
    reg	    [2:0]ns;
    // wire    isInitialized;

    //statemachine---------begin------------
    always@(rst_n or cs or isInitialized or sync_pe)	//posedge cpld_clk
    begin
        case (cs)
            IDLE: begin
                ns = SYSTEM_ON;
            end
            SYSTEM_ON:begin
                if(isInitialized == 0)
                    ns = INITIAL;
                else if(sync_pe == 1)
                    ns = INITIAL;
                else
                    ns = SYSTEM_ON; 
            end
            INITIAL: begin
                if(isInitialized == 1)
                    ns = SYSTEM_ON;
                else
                    ns = INITIAL;
            end
            GENWAVE: begin
                ns = GENWAVE;
            end
            default:
                ns = IDLE;
        endcase
    end

    always@(posedge clk or negedge rst_n)	//negedge cpld_clk
    begin
        if(rst_n == 0) begin
            cs <= IDLE;
        end else begin
            cs <= ns;
        end
    end

    //output per each state
    always@(posedge clk)	//ns
    begin
        case (ns)
            IDLE: begin
            end
            INITIAL: begin
            end
            GENWAVE: begin
            end
            SYSTEM_ON: begin
            end
            default: begin
            end
        endcase
    end
    //state machine-----------end------------------

    //初始化变量
    // always @(posedge clk or negedge rst_n) begin
    //     if(rst_n == 0) begin
    //         cmd <= 4'b0011;
    //         addr <= 4'b0111;
    //         v_data <= 16'd14562;
    //     end
    // end
    wire [23:0] data_in_i, data_in_gen;
    reg  [23:0] data_in;
    wire wr_req_i;
    wire cs0,cs1;
    wire wr_ack;
    initial_ad5676  u_initial_ad5676 (
        .clk                     ( clk              ),
        .rst_n                   ( rst_n            ),
        .sync_pe                 ( sync_pe          ),
        .wr_ack                  ( wr_ack           ),
        .dac_data                ( dac_data         ),

        .isInitialized           ( isInitialized    ),
        .cs_ad5676               ( cs_ad5676_i      ),
        .data_in                 ( data_in_i [23:0] ),
        .wr_req                  ( wr_req_i         )
    );
    wire wr_req_gen;
    genwave_ad5676  u_genwave_ad5676 (
        .clk                     ( clk                ),
        .rst_n                   ( rst_n              ),
        .wr_ack                  ( wr_ack             ),
  
        .wr_req                  ( wr_req_gen         ),
        .data_in                 ( data_in_gen [23:0] ),
        .cs_ad5676               ( cs_ad5676_gen      )
    );
    // assign wr_req = wr_req_i | wr_req_gen;
    // assign cs_ad5676 = cs0 & cs1;
    // assign data_in = (cs == GENWAVE) ? data_in1 : data_in0;

    always @(*) begin
        case (ns)
            INITIAL: begin
                wr_req  = wr_req_i;
                data_in = data_in_i;
                cs_ad5676 = cs_ad5676_i;
            end
            GENWAVE: begin
                wr_req  = wr_req_gen;
                data_in = data_in_gen;
                cs_ad5676 = cs_ad5676_gen;
            end
            default: begin
                wr_req  = 1'b0;
                data_in = 32'h0000_0000;
                cs_ad5676 = 1'b1;
            end
        endcase
    end

    // spi_master  u_spi_master (
    //     .sys_clk                 ( clk              ),
    //     .rst                     ( rst_n            ),
    //     .MISO                    (                  ),
    //     .CPOL                    ( 1'b1             ),
    //     .CPHA                    ( 1'b0             ),
    //     .nCS_ctrl                ( cs_ad5676        ),
    //     .clk_div                 ( 16'd0            ),//spi clk freq = clk / (div+2) / 2
    //     .wr_req                  ( wr_req           ),
    //     .data_in                 ( data_in   [7:0]  ),

    //     .nCS                     ( cs_ad5676_o      ),
    //     .DCLK                    ( spi_clk          ),
    //     .MOSI                    ( spi_mosi         ),
    //     .wr_ack                  ( wr_ack           ),
    //     .data_out                (                  )
    // );

    spi_master_cus #(
        .WIDTH ( 24 ))
    u_spi_master_cus (
        .sys_clk                 ( clk              ),
        .rst                     ( rst_n            ),
        .MISO                    (                  ),
        .CPOL                    ( 1'b1             ),
        .CPHA                    ( 1'b0             ),
        .nCS_ctrl                ( cs_ad5676        ),
        .clk_div                 ( 16'd0            ),//spi clk freq = clk / (div+2) / 2
        .wr_req                  ( wr_req           ),
        .data_in                 ( data_in   [23:0] ),

        .nCS                     ( cs_ad5676_o      ),
        .DCLK                    ( spi_clk          ),
        .MOSI                    ( spi_mosi         ),
        .wr_ack                  ( wr_ack           ),
        .data_out                (                  )
    );

endmodule