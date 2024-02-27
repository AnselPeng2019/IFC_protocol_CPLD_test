module adc_ads8688 (input           clk,
                    input           rst_n,
                    input           spi_miso,
                    input           sync,

                    output          spi_clock,
                    output          spi_mosi,
                    output          spi_cs,
                    output  [127:0] spl_data);
    
    //定义begin-----spi_master参数及接口变量------
    localparam WIDTH = 32;
    reg  [WIDTH-1:0] data_in;
    wire  [WIDTH-1:0] data_out;
    //定义end------------------------------------

    wire isInitialized,isSampledOver;
    reg wr_req;
    wire wr_req_i,wr_req_spl;
    wire [31:0] data_in_i, data_in_spl;
    reg cs_ads8688;

    wire sync_pe;

    get_signal_edge  u_get_signal_edge (
        .clk                     ( clk        ),
        .rst_n                   ( rst_n      ),
        .signal                  ( sync       ),

        .pos_edge                ( sync_pe    ),
        .neg_edge                (            )
    );


    //状态机实现 begin
    localparam IDLE                 = 3'B000;
    localparam INITIAL              = 3'b001;
    localparam SAMPLING             = 3'b010;
    localparam SYNCMODE             = 3'b011;

    reg en_initial, en_sample;

    reg [2:0] cs,ns;
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            cs <= IDLE;
        end else begin
            cs <= ns;
        end
    end
    always @(*) begin
        case (cs)
            IDLE: begin
                ns = INITIAL;
            end
            INITIAL: begin
                if(isInitialized == 1)
                    ns = SAMPLING;
                else
                    ns = INITIAL;
            end
            SAMPLING: begin
                if(isSampledOver == 1)
                    ns = SAMPLING;
                else
                    ns = SAMPLING;
            end
            SYNCMODE: begin
                ns = SYNCMODE;
            end
            default: 
                ns = IDLE;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            en_initial <= 0;
            en_sample  <= 0;
        end
        else begin
            case (ns)
                IDLE: begin
                    en_initial <= 1;
                end
                INITIAL: begin
                    if(isInitialized == 1) begin
                        en_initial <= 0;
                        en_sample  <= 1;
                    end
                    else
                        en_initial <= 1;
                end
                SAMPLING: begin
                    if(isSampledOver == 1) begin
                        en_sample <= 0;
                    end
                    else begin
                        en_sample  <= 1;
                        en_initial <= 0;
                    end
                end
                SYNCMODE: begin
                    
                end
                default: begin
                    
                end
            endcase
        end
    end
    //状态机实现 end

    spi_master_cus #(
    .WIDTH ( WIDTH ))
    u_spi_master_cus (
        .sys_clk                 ( clk                   ),
        .rst                     ( rst_n                 ),
        .MISO                    ( spi_miso              ),
        .CPOL                    ( 1'b0                  ),
        .CPHA                    ( 1'b1                  ),
        .nCS_ctrl                ( cs_ads8688            ),
        .clk_div                 ( 16'd1                 ),
        .wr_req                  ( wr_req                ),
        .data_in                 ( data_in   [WIDTH-1:0] ),

        .nCS                     ( spi_cs                ),
        .DCLK                    ( spi_clock             ),
        .MOSI                    ( spi_mosi              ),
        .wr_ack                  ( wr_ack                ),
        .data_out                ( data_out  [WIDTH-1:0] )
    );

    initial_ads8688  u_initial_ads8688 (
        .clk                     ( clk                   ),
        .rst_n                   ( rst_n                 ),
        .enable                  ( en_initial            ),
        .wr_ack                  ( wr_ack                ),

        .wr_req                  ( wr_req_i              ),
        .data_in                 ( data_in_i        [31:0] ),
        .isInitialized           ( isInitialized         ),
        .cs_ads8688              ( cs_ads8688_i            )
    );

    sample_ads8688  u_sample_ads8688 (
        .clk                     ( clk                   ),
        .rst_n                   ( rst_n                 ),
        .enable                  ( en_sample             ),
        .wr_ack                  ( wr_ack                ),
        .data_out                ( data_out  [WIDTH-1:0] ),
        .sync_pe                 ( sync_pe               ),

        .wr_req                  ( wr_req_spl            ),
        .data_in                 ( data_in_spl        [31:0] ),
        .isSampledOver           ( isSampledOver         ),
        .cs_ads8688              ( cs_ads8688_spl            ),
        .spl_data                ( spl_data         [127:0])
    );

    always @(*) begin
        case (cs)
            INITIAL: begin
                wr_req  = wr_req_i;
                data_in = data_in_i;
                cs_ads8688 = cs_ads8688_i;
            end
            SAMPLING: begin
                wr_req  = wr_req_spl;
                data_in = data_in_spl;
                cs_ads8688 = cs_ads8688_spl;
            end
            default: begin
                wr_req  = 1'b0;
                data_in = 32'h0000_0000;
                cs_ads8688 = 1'b1;
            end
        endcase
    end

endmodule

