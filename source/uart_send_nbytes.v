
/*
发送BN个字节数据
*/


`timescale  1ns / 100ps

module uart_send_nbytes #(
        parameter BN = 4,
        parameter CLK_FRE = 50,
        parameter BAUD_RATE = 115200)
    (
        input  				sys_clk,
        input  				rst_n,
        output 				uart_tx,
        input 				uart_send_flag,			//flag=1, send;flag=0,recv
        output reg			uart_send_comlete,		//发送完成标记
        input				[BN*8-1:0]dataT
    );

    localparam          IDLE =  0;
    localparam          SEND =  1;   			    //send data
    localparam          WAIT =  2;   			    //wait data
    localparam			PRESEND = 3;

    reg[7:0]            tx_data;
    reg[7:0]            tx_str;					    //synthesis syn_keep=1
    reg                 tx_data_valid;
    wire                tx_data_ready;
    reg[7:0]            tx_cnt = 0;
    reg[3:0]            cs,ns;                      //current state,next state


    always @(posedge sys_clk or negedge rst_n ) begin
        if(~rst_n) begin
            cs <= IDLE;
        end
        else
            cs <= ns;
    end

    //组合逻辑
    always@(*) begin
        case(cs)
            IDLE: begin
                ns = WAIT;
            end
            PRESEND: begin
                ns = SEND;
            end
            SEND: begin
                if(tx_data_valid && tx_data_ready &&tx_cnt == (BN-1))
                    ns = WAIT;
                else if(tx_data_valid ==0 && tx_cnt == 0 && uart_send_comlete == (BN-1))
                    ns = IDLE;
                else if(uart_send_comlete == 0 && tx_data_valid)
                    ns = SEND;
                else
                    ns = WAIT;
            end
            WAIT: begin
                if ( uart_send_flag )
                    ns = PRESEND;
            end
            default:
                ns = IDLE;
        endcase
    end

    reg i;

    always @(posedge sys_clk or negedge rst_n ) begin
        if(rst_n == 0) begin
            tx_data <= 8'd0;
            tx_cnt  <= 8'd0;
            tx_data_valid     <= 1'b0;
            uart_send_comlete <= 0;
        end
        else begin
            case (cs)
                IDLE: begin
                    // tx_str <= 0;
                end
                PRESEND: begin
                    // tx_data <= tx_str;
                end
                SEND: begin
                    tx_data <= tx_str;

                    if(tx_data_valid && tx_data_ready && tx_cnt < (BN-1))//Send 12 bytes data
                    begin
                        tx_cnt <= tx_cnt + 8'd1; //Send data counter
                    end
                    else if(tx_data_valid && tx_data_ready &&tx_cnt == (BN-1))//last byte sent is complete
                    begin
                        tx_cnt <= 8'd0;
                        tx_data_valid <= 1'b0;
                        uart_send_comlete <= 1;
                    end
                end
                WAIT:
                    if ( uart_send_flag ) begin
                        uart_send_comlete <= 0;
                        tx_data_valid <= 1;
                    end
            endcase
        end
    end


    always@(posedge sys_clk or negedge rst_n) begin
        if(rst_n == 0 || cs == IDLE) begin
            tx_str <= 0;
        end
        else begin
            tx_str <= dataT[BN*8-1-tx_cnt*8 -: 8];//依次取出8位数据
        end
    end


    uart_tx#
        (
            .CLK_FRE(CLK_FRE),
            .BAUD_RATE(BAUD_RATE)
        ) uart_tx_inst
        (
            .clk               (sys_clk        ),
            .rst_n             (rst_n          ),
            .tx_data           (tx_data        ),
            .tx_data_valid     (tx_data_valid  ),
            .tx_data_ready     (tx_data_ready  ),
            .tx_pin            (uart_tx        )
        );
endmodule
