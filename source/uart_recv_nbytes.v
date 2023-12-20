
`timescale  1ns / 100ps

module uart_recv_nbytes#(
        parameter BN = 4,
        parameter CLK_FRE = 50,
        parameter BAUD_RATE = 115200)

    (
        input  			sys_clk,
        input  			rst_n,
        input  			uart_rx,
        output	reg		uart_recv_flag,			//接收完成标记
        output	reg		[BN*8-1:0]dataR
    );


    localparam          IDLE    =  0;
    localparam          RECV    =  1;
    localparam          RECVCMP =  2;           //recv complete
    localparam          WAIT    =  3;   		//wait 1 second and send uart received data
    localparam          CYCLE = CLK_FRE * 1000000 / BAUD_RATE;

    wire[7:0]           rx_data;
    reg[BN*8-1:0]       rx_str;
    reg[3:0]            rx_cnt;
    wire                rx_data_valid;
    reg                 rx_data_ready;
    reg[3:0]            cs,ns;

    reg[8:0]            timer = 0;
    reg                 timerON = 0;


    // always @(uart_recv_flag or rst_n) begin
    //     if(rst_n == 0) begin
    //         timerON <= 0;
    //         // rx_data_ready <= 0;
    //         dataR <= 0;
    //     end
    //     else if(uart_recv_flag == 1) begin
    //         dataR <= rx_str;
    //         timerON <= 1;
    //     end
    //     else if(timer == CYCLE) begin
    //         timerON <= 0;
    //         // rx_data_ready <= 1;
    //     end
    // end

    always @(posedge sys_clk or negedge rst_n ) begin
        if(rst_n == 0) begin
            timer <= 0;
        end
        else begin
            if(timerON == 1 && timer < CYCLE) begin
                timer <= timer + 1;
            end
            else if(timer == CYCLE) begin
                timer <= 0;
            end
            else
                timer <= timer;
        end
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            timerON <= 0;
            dataR <= 0;
        end
        else begin
            if(timer == CYCLE) begin
                timerON <= 0;
            end
            else if(uart_recv_flag == 1) begin
                dataR <= rx_str;
                timerON <= 1;
            end
        end
    end


    // assign rx_data_ready = 1'b1;//always can receive data,


    always @(posedge sys_clk or negedge rst_n ) begin
        if(~rst_n) begin
            cs <= IDLE;
        end
        else
            cs <= ns;
    end

    //组合逻辑状态切换
    always@(posedge sys_clk or negedge rst_n) begin
        if(rst_n == 0) begin
            ns = IDLE;
        end
        else begin
            case(cs)
                IDLE: begin             //state 0
                    ns = WAIT;
                end
                RECV: begin             //state 1
                    if(uart_recv_flag == 1)
                        ns = RECVCMP;
                end
                RECVCMP: begin          //state 2
                    ns = IDLE;
                end
                WAIT: begin             //state 3
                    ns = RECV;
                end
                default:
                    ns = IDLE;
            endcase
        end
    end

    //时序逻辑动作执行
    always @(posedge sys_clk or negedge rst_n ) begin
        if(rst_n == 0) begin
            rx_cnt <= 0;
            // rx_str  <= 0;
            uart_recv_flag <= 0;
            rx_data_ready  <= 0;
            //dataR <= 0;
        end
        else begin
            case (cs)
                IDLE: begin
                    rx_cnt <= 0;
                    // rx_str  <= 0;
                    uart_recv_flag <= 0;
                    rx_data_ready  <= timerON ? 0 : 1;
                    // dataR <= 0;
                end
                RECV: begin
                    if(rx_data_valid == 1 && rx_cnt < BN-1)
                        rx_cnt <= rx_cnt+1;
                    if(rx_data_valid == 1 && rx_cnt == BN-1) begin
                        uart_recv_flag <= 1;
                        rx_data_ready <= 0;
                    end
                end
                RECVCMP: begin
                end
                WAIT: begin
                end
                default: begin
                    uart_recv_flag <= 0;
                    rx_data_ready  <= 0;
                end
            endcase

            if(timer == CYCLE) begin
                rx_data_ready <= 1;
            end
        end
    end


    always@( * ) begin
        if(rst_n == 0)
            rx_str <= 0;
        else  begin
            if(rx_data_valid == 1)
                rx_str[BN*8-1-rx_cnt*8 -: 8] <= rx_data;
            if(timer == CYCLE)
                rx_str <= 0;
        end
    end

    uart_rx #(
                .CLK_FRE   ( CLK_FRE   ),
                .BAUD_RATE ( BAUD_RATE ))
            u_uart_rx (
                .clk                            ( sys_clk                         ),
                .rst_n                          ( rst_n                           ),
                .rx_data_ready                  ( rx_data_ready                   ),
                .rx_pin                         ( uart_rx                         ),

                .rx_data                        ( rx_data                         ),
                .rx_data_valid                  ( rx_data_valid                   ),
                .rx_negedge                     ( rx_negedge                      )
            );

endmodule
