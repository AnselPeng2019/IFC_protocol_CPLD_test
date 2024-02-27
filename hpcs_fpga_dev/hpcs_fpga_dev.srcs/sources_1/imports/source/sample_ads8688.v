module sample_ads8688(  input                clk,
                        input                rst_n,
                        input                enable,
                        input                wr_ack,
                        input      [31:0]    data_out,
                        input                sync_pe,

                        output reg           wr_req,
                        output reg [31:0]    data_in,
                        output reg           isSampledOver,
                        output               cs_ads8688,
                        output reg [127:0]   spl_data);

    // statemachine state parameters
    localparam	[2:0]IDLE                 = 3'b000;					//
    localparam	[2:0]SAMPLING             = 3'b001;		    		//
    localparam	[2:0]SEND_DELAY           = 3'b010;		    		//
    localparam	[2:0]SPL_COMP             = 3'b011;	        		//

    reg [2:0] cs,ns;
    reg isSendCMD,isSampled,isDelayed;
    reg nCS_ctrl;

    //初始化ads8688寄存器的数据
    reg [31:0] data_init [8:0];
    //
    reg [15:0] data [7:0];

    // assign spl_data = {data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]};
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            spl_data <= 0;
        end else if(isSampledOver) begin
            spl_data <= {data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]};
        end
    end

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
            SAMPLING: begin
                if(isSendCMD == 1)
                    ns = SEND_DELAY;
                else
                    ns = SAMPLING;
            end
            SEND_DELAY: begin
                if (isSampledOver == 1)
                    ns = SPL_COMP;
                else if(isDelayed == 1)
                    ns = SAMPLING;
                else
                    ns = SEND_DELAY;             
            end
            SPL_COMP: begin
                if(sync_pe == 1)
                    ns = SEND_DELAY;
                else
                    ns = SPL_COMP;
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
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            isDelayed <= 0;
            ticks <= 0;
        end
        else begin
            if(cs == SEND_DELAY) begin
                ticks <= ticks + 1;
                if(ticks == 10) begin  //100ns = 10*10ns @ 100MHz clock
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
            {isSampled,isSendCMD} <= 2'b00;
            isSampledOver <= 0;
            data_in <= 0;
            wr_req <= 0;
            nCS_ctrl <= 1;
            i <= 0;
        end
        else if(enable == 1) begin
            case (ns)
                SAMPLING: begin
                    data_in <= data_init[i];
                    if(wr_ack_pe == 1) begin
                        wr_req <= 0;
                        nCS_ctrl <= 1;
                        i <= i + 1;
                        isSendCMD <= 1;
                        // data[i] <= data_out[31:16];
                    end else if(isSendCMD == 0) begin
                        wr_req <= 1;
                        nCS_ctrl <= 0;
                    end
                end
                SEND_DELAY: begin
                    isSendCMD <= 0;
                    // i <= (i+1>10) ? 0 : (i+1);
                    if(i == 8 && ticks == 10) begin
                        isSampledOver <= 1;
                        i <= 0;
                    end
                end
                SPL_COMP: begin
                    {isSampled,isSendCMD} <= 2'b00;
                    isSampledOver <= 0;
                    data_in <= 0;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                end
                default: begin
                    {isSampled,isSendCMD} <= 2'b00;
                    data_in <= 0;
                    wr_req <= 0;
                    nCS_ctrl <= 1;
                end
            endcase
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            // data_init[ 0] = 32'hc000_0000;    //get channle 0 sample data in mannual mode
            // data_init[ 1] = 32'h0000_0000;    //get channle 1 sample data in mannual mode
            // data_init[ 2] = 32'hc400_0000;    //get channle 2 sample data in mannual mode
            // data_init[ 3] = 32'h0000_0000;    //get channle 3 sample data in mannual mode
            // data_init[ 4] = 32'hc800_0000;    //get channle 4 sample data in mannual mode
            // data_init[ 5] = 32'h0000_0000;    //get channle 5 sample data in mannual mode
            // data_init[ 6] = 32'hcc00_0000;    //get channle 6 sample data in mannual mode
            // data_init[ 7] = 32'h0000_0000;    //get channle 7 sample data in mannual mode
            // data_init[ 8] = 32'h0000_0000;    //get channle 0 sample data in mannual mode
            data_init[ 0] <= 32'h0000_0000;    //get channle 0 sample data in auto sample mode
            data_init[ 1] <= 32'h0000_0000;    //get channle 1 sample data in auto sample mode
            data_init[ 2] <= 32'h0000_0000;    //get channle 2 sample data in auto sample mode
            data_init[ 3] <= 32'h0000_0000;    //get channle 3 sample data in auto sample mode
            data_init[ 4] <= 32'h0000_0000;    //get channle 4 sample data in auto sample mode
            data_init[ 5] <= 32'h0000_0000;    //get channle 5 sample data in auto sample mode
            data_init[ 6] <= 32'h0000_0000;    //get channle 6 sample data in auto sample mode
            data_init[ 7] <= 32'h0000_0000;    //get channle 7 sample data in auto sample mode
            data_init[ 8] <= 32'h0000_0000;    //get channle 0 sample data in auto sample mode
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 0) begin
            data[ 0] <= 16'h0000;    //get channle 0 sample data
            data[ 1] <= 16'h0000;    //get channle 1 sample data
            data[ 2] <= 16'h0000;    //get channle 2 sample data
            data[ 3] <= 16'h0000;    //get channle 3 sample data
            data[ 4] <= 16'h0000;    //get channle 4 sample data
            data[ 5] <= 16'h0000;    //get channle 5 sample data
            data[ 6] <= 16'h0000;    //get channle 6 sample data
            data[ 7] <= 16'h0000;    //get channle 7 sample data
        end else begin
            if(ns == SAMPLING && wr_ack_pe == 1)
                data[i] <= data_out[15:0];
        end
    end


endmodule