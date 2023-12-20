/*
原本设计是为了形成协议，通过串口修改IFC对应的寄存器，可是还未设计寄存器专用接口，所以该串口协议不能使用
*/


module uart_protocol #(
        parameter BSN = 4,
        parameter BRN = 4
    ) (
        input       sys_clk,
        input       rst_n,
        input       uart_recv_flag,
        input       uart_send_comlete,
        output reg  uart_send_flag,
        input       [BRN*8-1:0]dataR,
        output reg  [BSN*8-1:0]dataT
    );

    always @(posedge uart_recv_flag or posedge uart_send_comlete or negedge rst_n) begin
        if(rst_n == 0) begin
            uart_send_flag <= 0;
        end
        else begin
            uart_send_flag <= 0;
            // if(uart_recv_flag == 1)
            //     uart_send_flag <= 1;
            // else if(uart_send_comlete == 1)
            //     uart_send_flag <= 0;
            // else
            //     uart_send_flag<=1;
        end
    end

    always @(posedge sys_clk or negedge rst_n or posedge uart_recv_flag) begin
        if(rst_n == 0) begin
            // uart_send_flag <= 0;
            dataT <= 'bz;
        end
        else if(uart_recv_flag == 1) begin
            // case (dataR)
            //     "RD00"
            //     : begin
            //         dataT <= "DEFG";
            //     end
            //     "1234"
            //     : begin
            //         dataT <= "4567";
            //     end
            //     default:
            //         dataT <= 0;
            // endcase
        end
    end


endmodule
