module initial_ads8688(input                clk,
                       input                rst_n,
                       input                enable,
                       input                wr_ack,
                       output reg           wr_req,
                       output reg [31:0]    data_in,
                       output reg           isInitialized,
                       output               cs_ads8688);

    // statemachine state parameters
    localparam	[2:0]IDLE                 = 3'b000;					//
    localparam	[2:0]SEND_CMD             = 3'b001;		    		//
    localparam	[2:0]SEND_DELAY           = 3'b010;		    		//
    localparam	[2:0]SEND_COMP            = 3'b011;	        		//

    reg [2:0] cs,ns;
    reg isSendCMD,isDelayed,isSendAll;
    reg nCS_ctrl;

    //初始化ads8688寄存器的数据
    reg [31:0] data_init [15:0];
    //
    assign cs_ads8688 = nCS_ctrl;

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0)
            cs <= IDLE;
        else if(enable == 1)
            cs <= ns;
    end
    always @(*) begin
        case (cs)
            IDLE: begin
                ns = SEND_DELAY;
            end
            SEND_CMD: begin
                if(isSendCMD == 1)
                    ns = SEND_DELAY;
                else
                    ns = SEND_CMD;
            end
            SEND_DELAY: begin
                if (isSendAll == 1)
                    ns = SEND_COMP;
                else if(isDelayed == 1)
                    ns = SEND_CMD;
                else
                    ns = SEND_DELAY; 
            end
            SEND_COMP: begin
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

    reg [7:0] i;
    reg [23:0] ticks;
    reg [23:0] tck_delay [15:0];
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            isDelayed <= 0;
            ticks <= 0;
        end
        else begin
            if(cs == SEND_DELAY) begin
                ticks <= ticks + 1;
                if(ticks == tck_delay[i]) begin  //1ms = 100*1000 10ns
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

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            {isInitialized,isSendCMD,isSendAll} <= 3'b000;
            data_in <= 0;
            wr_req <= 0;
            nCS_ctrl <= 1;
            i <= 0;
        end
        else if(enable == 1) begin
            case (ns)
                SEND_CMD: begin
                    data_in <= data_init[i];
                    if(wr_ack_pe == 1) begin
                        wr_req <= 0;
                        nCS_ctrl <= 1;
                        i <= i + 1;
                        isSendCMD <= 1;
                    end else if(isSendCMD == 0) begin
                        wr_req <= 1;
                        nCS_ctrl <= 0;
                    end
                end
                SEND_DELAY: begin
                    isSendCMD <= 0;
                    // i <= (i+1>10) ? 0 : (i+1);
                    if(i == 14 && ticks == tck_delay[i]) begin
                        isSendAll <= 1;
                        i <= 0;
                    end
                end
                SEND_COMP: begin
                    {isInitialized,isSendCMD,isSendAll} <= 3'b100;
                    data_in <= 0;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                end
                default: begin
                    {isInitialized,isSendCMD,isSendAll} <= 3'b000;
                    data_in <= 0;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                end
            endcase
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            data_init[ 0] <= 32'h8300_0000;    //power down
            data_init[ 1] <= 32'h8200_0000;    //standby mode
            data_init[ 2] <= 32'h8500_0000;    //reset registers
            // data_init[ 3] <= 32'h0000_0000;    //auto scan sequence enable
            // data_init[ 4] <= 32'h0000_0000;    //no op:Continued Operation in the Selected Mode
            // data_init[ 5] <= 32'ha000_0000;    //Auto Channel Enable with Reset
            // data_init[ 6] <= 32'h0000_0000;    //no op:Continued Operation in the Selected Mode
            data_init[ 3] <= 32'h0b01_0000;    //change ch0 to +/-5.12 scale
            data_init[ 4] <= 32'h0d01_0000;    //change ch1 to +/-5.12 scale
            data_init[ 5] <= 32'h0f01_0000;    //change ch2 to +/-5.12 scale
            data_init[ 6] <= 32'h1101_0000;    //change ch3 to +/-5.12 scale
            data_init[ 7] <= 32'h1301_0000;    //change ch4 to +/-5.12 scale
            data_init[ 8] <= 32'h1501_0000;    //change ch5 to +/-5.12 scale
            data_init[ 9] <= 32'h1701_0000;    //change ch6 to +/-5.12 scale
            data_init[10] <= 32'h1901_0000;    //change ch7 to +/-5.12 scale
            data_init[11] <= 32'h03ff_0000;    //Auto-Scan Sequence Enable Register h0301_0000
            data_init[12] <= 32'h0000_0000;    //no op:Continued Operation in the Selected Mode
            data_init[13] <= 32'ha000_0000;    //auto scan sequence enable ha000_0000
            data_init[14] <= 32'h0000_0000;    //no op:Continued Operation in the Selected Mode
            data_init[15] <= 32'h0000_0000;    //no op:Continued Operation in the Selected Mode
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            tck_delay[ 0] <= 100000;
            tck_delay[ 1] <= 100000;
            tck_delay[ 2] <= 100000;
            tck_delay[ 3] <= 500000;
            tck_delay[ 4] <= 100000;
            tck_delay[ 5] <= 100000;
            tck_delay[ 6] <= 100000;
            tck_delay[ 7] <= 100000;
            tck_delay[ 8] <= 100000;
            tck_delay[ 9] <= 100000;
            tck_delay[10] <= 100000;
            tck_delay[11] <= 100000;
            tck_delay[12] <= 100000;
            tck_delay[13] <= 100000;
            tck_delay[14] <= 100000;
            tck_delay[15] <= 100000;
        end
        
    end


endmodule