module initial_ad5676 (input                clk,
                       input                rst_n,
                    //    input [23:0]         cmdData,
                       input                sync_pe,
                       input                wr_ack,
                       input [16*8-1:0]     dac_data,
                       output reg           wr_req,
                       output reg [23:0]    data_in,
                       output reg           isInitialized,
                       output               cs_ad5676);

    // statemachine state parameters
    localparam	[2:0]IDLE                 = 3'b000;					//
    localparam	[2:0]SEND_CMD            = 3'b001;		    		//send data
    localparam	[2:0]SEND_DELAY            = 3'b010;	        		//delay 
    // localparam	[2:0]SEND_CMD2            = 3'b011;		        	//to be deleted
    localparam	[2:0]SEND_COMP            = 3'b011;	        		//complete

    reg [2:0] cs,ns;
    reg isSendCMD;
    //  isSendCMD1,isSendCMD2;
    // reg wr_req;
    reg nCS_ctrl;
    // reg [7:0] data_in;
    // reg [3:0] cmd;
    // reg [3:0] addr;
    // reg [15:0] v_data;//0~65535
    reg [23:0] initial_data [7:0];

    // wire wr_ack;

    assign cs_ad5676 = nCS_ctrl;

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0)
            cs <= IDLE;
        else
            cs <= ns;
    end
    reg [7:0] i;
    reg [7:0] ticks;
    reg isDelayed;
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            isDelayed <= 0;
            ticks <= 0;
        end
        else begin
            if(cs == SEND_DELAY) begin
                ticks <= ticks + 1;
                if(ticks == 95) begin  //50ns = 5*10ns @ 100MHz clock
                    ticks <= 0;
                    isDelayed <= 1;
                end
            end
            else begin
                ticks <= 0;
                isDelayed <= 0;
            end
        end
    end
    always @(*) begin
        case (cs)
            IDLE: begin
                ns = SEND_DELAY;
            end
            SEND_CMD: begin        //发送数据
                if(isSendCMD == 1)
                    ns = SEND_DELAY;
                else
                    ns = SEND_CMD;
            end
            SEND_DELAY: begin        //delay
                if(isInitialized == 1)
                    ns = SEND_COMP;
                else if(isDelayed == 1)
                    ns = SEND_CMD;
                else
                    ns = SEND_DELAY;
            end
            SEND_COMP: begin        //complete
                if(sync_pe == 1)
                    ns = SEND_DELAY;
                else
                    ns = SEND_COMP;
            end
            default: begin
                ns = IDLE;
            end
        endcase
    end

    //获取wr_ack的上升沿  begin
    reg [1:0] wr_ack_edge;
    wire wr_ack_pe;
    always @ (posedge clk) begin
        wr_ack_edge[0] <= wr_ack;
        wr_ack_edge[1] <= wr_ack_edge[0];
    end
    assign wr_ack_pe = wr_ack_edge[0] == 1 && wr_ack_edge[1] == 0;
    //获取wr_ack的上升沿  end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            {isInitialized,isSendCMD} <= 2'b00;
            data_in <= 24'h000000;
            wr_req <= 0;
            nCS_ctrl <= 1;
            i <= 0;
        end
        else begin
            case (ns)
                SEND_CMD: begin                    //send data
                    data_in <= initial_data[i];
                    if(wr_ack_pe == 1) begin
                        wr_req <= 0;
                        nCS_ctrl <= 1;
                        isSendCMD <= 1;
                        i <= i + 1;
                    end else if(isSendCMD == 0) begin
                        wr_req <= 1;
                        nCS_ctrl <= 0;
                    end
                end
                SEND_DELAY: begin                    //delay
                    // data_in <= v_data[15:8];
                    isSendCMD <= 0;
                    if(i == 8 && ticks == 5) begin
                        i <= 0;
                        // nCS_ctrl <= 1;
                        isInitialized <= 1;
                    end
                end
                SEND_COMP: begin
                    isInitialized <= 0;
                    isSendCMD <= 1'b0;
                    data_in <= 24'h000000;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                end
                default: begin
                    {isInitialized,isSendCMD} <= 2'b00;
                    data_in <= 24'h000000;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                end
            endcase
        end
    end

    always @(posedge clk  or negedge rst_n) begin
        if(rst_n == 0) begin
            initial_data[0] <= {8'b0011_0000, 16'h0000};     //初始化0通道数据
            initial_data[1] <= {8'b0011_0001, 16'h0001};     //初始化1通道数据
            initial_data[2] <= {8'b0011_0010, 16'h0002};     //初始化2通道数据
            initial_data[3] <= {8'b0011_0011, 16'h0003};     //初始化3通道数据
            initial_data[4] <= {8'b0011_0100, 16'h0004};     //初始化4通道数据
            initial_data[5] <= {8'b0011_0101, 16'h0005};     //初始化5通道数据
            initial_data[6] <= {8'b0011_0110, 16'h0006};     //初始化6通道数据
            initial_data[7] <= {8'b0011_0111, 16'h0007};     //初始化7通道数据
        end else if(sync_pe) begin
            initial_data[0] <= {8'b0011_0000, dac_data[127:112]};
            initial_data[1] <= {8'b0011_0001, dac_data[111: 96]};
            initial_data[2] <= {8'b0011_0010, dac_data[ 95: 80]};
            initial_data[3] <= {8'b0011_0011, dac_data[ 79: 64]};
            initial_data[4] <= {8'b0011_0100, dac_data[ 63: 48]};
            initial_data[5] <= {8'b0011_0101, dac_data[ 47: 32]};
            initial_data[6] <= {8'b0011_0110, dac_data[ 31: 16]};
            initial_data[7] <= {8'b0011_0111, dac_data[ 15:  0]};
            // initial_data[0] <= {8'b0011_0000, 16'h0000};
            // initial_data[1] <= {8'b0011_0001, 16'h0000};
            // initial_data[2] <= {8'b0011_0010, 16'h0000};
            // initial_data[3] <= {8'b0011_0011, 16'h0000};
            // initial_data[4] <= {8'b0011_0100, 16'h0000};
            // initial_data[5] <= {8'b0011_0101, 16'h0000};
            // initial_data[6] <= {8'b0011_0110, 16'h0000};
            // initial_data[7] <= {8'b0011_0111, 16'h0000};
            // initial_data[0] <= {8'b0011_0000, 16'h7fff};
            // initial_data[1] <= {8'b0011_0001, 16'h7fff};
            // initial_data[2] <= {8'b0011_0010, 16'h7fff};
            // initial_data[3] <= {8'b0011_0011, 16'h7fff};
            // initial_data[4] <= {8'b0011_0100, 16'h7fff};
            // initial_data[5] <= {8'b0011_0101, 16'h7fff};
            // initial_data[6] <= {8'b0011_0110, 16'h7fff};
            // initial_data[7] <= {8'b0011_0111, 16'h7fff};
        end
    end

endmodule