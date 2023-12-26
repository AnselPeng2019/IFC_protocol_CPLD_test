module uart_def #(
        parameter BSN = 6,                  //发送的数据位数
        parameter BRN = 4,                  //接收的数据位数
        parameter CLK_FRE = 50,             //输入时钟，MHz
        parameter BAUD_RATE = 115200        //波特率
    ) (
        input   sys_clk,
        input   rst_n,
        input   uart_send_flag,             //发送数据使能标志
        input   [BSN*8-1:0]  dataT,         //发送数据数组
        output  uart_tx,                    //发送端信号
        output  uart_send_comlete,          //发送数据完成标志
        input   uart_rx,                    //接收端信号
        output  [BRN*8-1:0]  dataR          //接收存储数组
    );

    wire  uart_recv_flag;                   //接收完成标志

    wire send_flag_ptc;
    wire [BSN*8-1:0]  dataT_ptc;
    wire send_flag;
    wire [BSN*8-1:0]  dataTrans;

    assign send_flag = send_flag_ptc ? 1 : uart_send_flag;
    assign dataTrans = send_flag_ptc ? dataT_ptc : dataT;

    uart_send_nbytes #(
                         .BN        ( BSN         ),
                         .CLK_FRE   ( CLK_FRE     ),
                         .BAUD_RATE ( BAUD_RATE   ))
                     u_uart_send_nbytes (
                         .sys_clk                 ( sys_clk             ),
                         .rst_n                   ( rst_n               ),
                         .uart_send_flag          ( send_flag           ),
                         .dataT                   ( dataTrans           ),

                         .uart_tx                 ( uart_tx             ),
                         .uart_send_comlete       ( uart_send_comlete   )
                     );


    uart_recv_nbytes #(
                         .BN        ( BRN        ),
                         .CLK_FRE   ( CLK_FRE    ),
                         .BAUD_RATE ( BAUD_RATE  ))
                     u_uart_recv_nbytes (
                         .sys_clk                 ( sys_clk          ),
                         .rst_n                   ( rst_n            ),
                         .uart_rx                 ( uart_rx          ),

                         .uart_recv_flag          ( uart_recv_flag   ),
                         .dataR                   ( dataR            )
                     );

    uart_protocol #(
                      .BSN ( BSN ),
                      .BRN ( BRN ))
                  u_uart_protocol (
                      .sys_clk                 ( sys_clk             ),
                      .rst_n                   ( rst_n               ),
                      .uart_recv_flag          ( uart_recv_flag      ),
                      .uart_send_comlete       ( uart_send_comlete   ),
                      .dataR                   ( dataR               ),

                      .uart_send_flag          ( send_flag_ptc      ),
                      .dataT                   ( dataT_ptc               )
                  );




endmodule
