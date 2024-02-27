
/***写fifo：
****每次只写入一个数据，写入完成后就结束操作，disable 写使能
***/
module fifo_wr
#(
    parameter WIDTH = 16
)
(
    input                        clk    ,          // 时钟信号
    input                        rst_n  ,          // 复位信号
    input                        en,
    input      [WIDTH-1:0]       wr_data,       
             
    input                        almost_empty,     // FIFO将空信号
    input                        almost_full ,     // FIFO将满信号
    output reg                   fifo_wr_en ,      // FIFO写使能
    output reg [WIDTH-1:0]       fifo_wr_data      // 写入FIFO的数据
);

    localparam st_wait_triger      = 2'b00;
    localparam st_delay_cycles     = 2'b01;
    localparam st_write_opt        = 2'b10;

    //reg define
    reg [1:0]   state            ;  //动作状态
    reg         almost_empty_d0  ;  //almost_empty 延迟一拍
    reg         almost_empty_syn ;  //almost_empty 延迟两拍
    reg [3:0]   dly_cnt          ;  //延迟计数器


    //*****************************************************
    //**                    main code
    //*****************************************************

    //因为 almost_empty 信号是属于FIFO读时钟域的
    //所以要将其同步到写时钟域中
    always@( posedge clk ) begin
        if( !rst_n ) begin
            almost_empty_d0  <= 1'b0 ;
            almost_empty_syn <= 1'b0 ;
        end
        else begin
            almost_empty_d0  <= almost_empty ;
            almost_empty_syn <= almost_empty_d0 ;
        end
    end

    //向FIFO中写入数据
    always @(posedge clk ) begin
        if(!rst_n) begin
            fifo_wr_en   <= 1'b0;
            fifo_wr_data <= {WIDTH{1'd0}};
            state        <= 2'd0;
            dly_cnt      <= 4'd0;
        end
        else begin
            case(state)
                st_wait_triger: begin
                    if(en) begin   //等待触发
                        state       <= st_delay_cycles;     //进入延时状态
                    end
                    else
                        state       <= st_wait_triger;
                end 
                st_delay_cycles: begin
                    if(dly_cnt == 4'd5) begin   //延时5拍
                                                //原因是FIFO IP核内部状态信号的更新存在延时
                                                //延迟10拍以等待状态信号更新完毕                   
                        dly_cnt             <= 4'd0; 
                        fifo_wr_en          <= 1'b1;     //打开写使能
                        if(almost_full)
                            state           <= st_wait_triger;
                        else begin
                            fifo_wr_en      <= 1'b1;     //打开写使能
                            state           <= st_write_opt;     //开始写操作
                            fifo_wr_data    <= wr_data;
                        end
                    end
                    else
                        dly_cnt <= dly_cnt + 4'd1;
                end 
                st_write_opt: begin
                    state           <= st_wait_triger;
                    fifo_wr_data    <= 0;
                    fifo_wr_en      <= 1'b0;
                end 
                default : state <= st_wait_triger;
            endcase
        end
    end

endmodule
