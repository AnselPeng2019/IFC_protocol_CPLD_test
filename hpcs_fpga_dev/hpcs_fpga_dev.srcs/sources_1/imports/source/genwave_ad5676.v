module genwave_ad5676 (input                clk,
                       input                rst_n,
                       input                wr_ack,
                       output reg           wr_req,
                       output reg [23:0]    data_in,
                       output               cs_ad5676);


    // statemachine state parameters
    localparam	[2:0]IDLE                 = 3'b000;					//
    localparam	[2:0]SEND_CMD0            = 3'b001;		    		//
    localparam	[2:0]SEND_CMD1            = 3'b010;	        		//send command 
    localparam	[2:0]SEND_CMD2            = 3'b011;		        	//send data high 8 bits
    localparam	[2:0]SEND_COMP            = 3'b100;	        		//send data low 8 bits

    reg [2:0] cs,ns;
    reg isSendCMD0, isSendCMD1,isSendCMD2;
    // reg isgenerated;
    reg nCS_ctrl;
    reg [3:0] cmd;
    reg [3:0] addr;
    reg [15:0] v_data;//0~65535

    //正弦波数组
    reg [15:0] sine_data[63:0];

    assign cs_ad5676 = nCS_ctrl;


    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0)
            cs <= IDLE;
        else
            cs <= ns;
    end
    always @(*) begin
        case (cs)
            IDLE: begin
                ns = SEND_CMD0;
            end
            SEND_CMD0: begin
                if(isSendCMD0 == 1)
                    ns = SEND_CMD1;
                else
                    ns = SEND_CMD0;
            end
            SEND_CMD1: begin
                if(isSendCMD1 == 1)
                    ns = SEND_CMD2;
                else
                    ns = SEND_CMD1;
            end
            SEND_CMD2: begin
                if(isSendCMD2 == 1)
                    ns = SEND_COMP;
                else
                    ns = SEND_CMD2;
            end
            SEND_COMP: begin
                ns = SEND_CMD0;
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

    //状态机输出
    reg [7:0] i;
    reg [3:0] j;
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            {isSendCMD0,isSendCMD1,isSendCMD2} <= 3'b000;
            // isgenerated         <= 0;
            data_in             <= 8'b0000_0000;
            wr_req              <= 0;
            nCS_ctrl            <= 1;
            cmd                 <= 4'b0011;
            addr                <= 4'b0000;
            v_data              <= sine_data[0];
            i                   <= 1;
            j                   <= 0;
        end
        else begin
            case (cs)
                SEND_CMD0: begin
                    data_in <= {cmd, addr};
                    if(wr_ack_pe == 1) begin
                        wr_req <= 0;
                        // nCS_ctrl <= 1;
                        isSendCMD0 <= 1;
                    end else if(isSendCMD0 == 0) begin
                        wr_req <= 1;
                        nCS_ctrl <= 0;
                    end
                end
                SEND_CMD1: begin
                    data_in <= v_data[15:8];
                    if(wr_ack_pe == 1) begin
                        wr_req <= 0;
                        // nCS_ctrl <= 1;
                        isSendCMD1 <= 1;
                    end else if(isSendCMD1 == 0) begin
                        wr_req <= 1;
                        nCS_ctrl <= 0;
                    end
                end
                SEND_CMD2: begin
                    data_in <= v_data[7:0];
                    if(wr_ack_pe == 1) begin
                        wr_req <= 0;
                        isSendCMD2 <= 1;
                        nCS_ctrl <= 1;
                        // isgenerated <= 1;
                    end else if(isSendCMD2 == 0) begin
                        wr_req <= 1;
                        nCS_ctrl <= 0;
                    end
                end
                SEND_COMP: begin
                    // isgenerated <= 0;
                    {isSendCMD0,isSendCMD1,isSendCMD2} <= 3'b000;
                    data_in <= 8'b0000_0000;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                    j <= (j+1) > 3 ? 0 : (j+1);
                    addr <= j;
                    if(j == 3) begin
                        i <= (i+1) > 63 ? 0 : (i+1);
                    end
                    v_data <= sine_data[i];
                end
                default: begin
                    {isSendCMD0,isSendCMD1,isSendCMD2} <= 3'b000;
                    data_in <= 8'b0000_0000;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                    i <= 0;
                    j <= 0;
                    v_data <= sine_data[0];
                    addr <= 0;
                end
            endcase                
        end
    end

    //初始化正弦波值
    always @(negedge clk or negedge rst_n) begin
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