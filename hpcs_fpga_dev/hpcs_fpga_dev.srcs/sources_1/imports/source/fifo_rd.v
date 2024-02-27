module fifo_rd
#(
    parameter WIDTH = 16,
    parameter RLEN  = 120
)(
    input                   clk          ,   // 时钟信号
    input                   rst_n        ,   // 复位信号
    input                   en           ,   
    input [15:0]            rlen         ,   

    input [WIDTH-1:0]         fifo_dout  ,   // 从FIFO读出的数据
    input                   almost_full  ,   // FIFO将满信号
    input                   almost_empty ,   // FIFO将空信号
    output reg              fifo_rd_en   ,   // FIFO读使能
    output reg [WIDTH-1:0]    rd_data        // 从FIFO读出的数据
);

    localparam st_wait_triger      = 2'b00;
    localparam st_delay_cycles     = 2'b01;
    localparam st_read_opt         = 2'b10;

    //reg define
    reg [1:0]   state               ;  //动作状态
    reg         almost_full_d0      ;  //almost_full延迟一拍
    reg         almost_full_syn     ;  //almost_full延迟两拍
    reg [3:0]   dly_cnt             ;  //延迟计数器
    reg [7:0]   cnt                 ;

    //*****************************************************
    //**                    main code
    //*****************************************************

    //因为 fifo_full 信号是属于FIFO写时钟域的
    //所以要将其同步到读时钟域中
    always@( posedge clk ) begin
    if( !rst_n ) begin
        almost_full_d0  <= 1'b0 ;
        almost_full_syn <= 1'b0 ;
    end
    else begin
        almost_full_d0  <= almost_full ;
        almost_full_syn <= almost_full_d0 ;
    end
    end

    //读出FIFO的数据
    always @(posedge clk ) begin
        if(!rst_n) begin
            fifo_rd_en <= 1'b0;
            state      <= st_wait_triger;
            dly_cnt    <= 4'd0;
            cnt        <= 0;
            rd_data    <= 0;
        end
        else begin
            case(state)
                st_wait_triger: begin
                    if(en) begin   //等待触发
                        state           <= st_read_opt;     //进入延时状态
                        fifo_rd_en      <= 1'b1;
                    end else begin
                        state           <= st_wait_triger;
                    end
                end 
                // st_delay_cycles: begin
                //     if(dly_cnt == 4'd5) begin   //延时5拍
                //                                 //原因是FIFO IP核内部状态信号的更新存在延时
                //                                 //延迟10拍以等待状态信号更新完毕                   
                //         dly_cnt             <= 4'd0; 
                //         if(almost_empty) begin
                //             state           <= st_wait_triger;
                //         end else begin
                //             fifo_rd_en      <= 1'b1;     //打开写使能
                //             state           <= st_read_opt;     //开始读操作
                //         end
                //     end
                //     else
                //         dly_cnt <= dly_cnt + 4'd1;
                // end 
                st_read_opt: begin
                    if(cnt == RLEN/2 || almost_empty) begin
                        fifo_rd_en      <= 1'b0;     
                        state           <= st_wait_triger;
                    end else begin
                        cnt             <= cnt + 1;    
                        rd_data         <= fifo_dout;
                    end
                end 
            default : state <= st_wait_triger;
            endcase
        end
    end

endmodule