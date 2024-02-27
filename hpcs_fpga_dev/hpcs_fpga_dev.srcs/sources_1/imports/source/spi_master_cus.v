//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//                                                                              //
//  Author: meisq                                                               //
//          msq@qq.com                                                          //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////
// 关于spimaster模块的spi clock频率和clk_div的关系//
// clk_div      clk/MHz	        freq/MHz        //
// 0	        100	            25              //
// 1	        100	            16.66666667     //
// 2	        100	            12.5            //
// 3	        100	            10              //
// 4	        100	            8.333333333     //
// 5	        100	            7.142857143     //
// 6	        100	            6.25            //
// 7	        100	            5.555555556     //
// 8	        100	            5               //
// 9	        100	            4.545454545     //
// 10	        100	            4.166666667     //
// 11	        100	            3.846153846     //
// 12	        100	            3.571428571     //
// 13	        100	            3.333333333     //
// 14	        100	            3.125           //
// 15	        100	            2.941176471     //
// 18	        100	            2.5             //
// 23	        100	            2               //
// 30	        100	            1.5625          //
// 38	        100	            1.25            //
// 48	        100	            1               //
//////////////////////////////////////////////////

//==========================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------
//  2017/6/19     meisq         1.0         Original
//*************************************************************************/
module spi_master_cus #(
	parameter WIDTH = 32)
(
	input                       sys_clk,
	input                       rst,
	output                      nCS,       //chip select (SPI mode)
	output                      DCLK,      //spi clock
	output                      MOSI,      //spi data output
	input                       MISO,      //spi input
	input                       CPOL,
	input                       CPHA,
	input                       nCS_ctrl,
	input[15:0]                 clk_div,
	input                       wr_req,
	output                      wr_ack,
	input [WIDTH-1:0]           data_in,
	output[WIDTH-1:0]           data_out
);
localparam                   IDLE            = 0;
localparam                   DCLK_EDGE       = 1;
localparam                   DCLK_IDLE       = 2;
localparam                   ACK             = 3;
localparam                   LAST_HALF_CYCLE = 4;
localparam                   ACK_WAIT        = 5;
reg                          DCLK_reg;
reg[WIDTH-1:0]               MOSI_shift;
reg[WIDTH-1:0]               MISO_shift;
reg[2:0]                     state;
reg[2:0]                     next_state;
reg [15:0]                   clk_cnt;
reg[7:0]                     clk_edge_cnt;
assign MOSI = MOSI_shift[WIDTH-1];
assign DCLK = DCLK_reg;
assign data_out = MISO_shift;
assign wr_ack = (state == ACK);
assign nCS = nCS_ctrl;
always@(posedge sys_clk or posedge rst)
begin
	if(rst == 0)
		state <= IDLE;
	else
		state <= next_state;
end

always@(*)
begin
	case(state)
		IDLE:
			if(wr_req == 1'b1)
				next_state <= DCLK_IDLE;
			else
				next_state <= IDLE;
		DCLK_IDLE:
			//half a SPI clock cycle produces a clock edge
			if(clk_cnt == clk_div)
				next_state <= DCLK_EDGE;
			else
				next_state <= DCLK_IDLE;
		DCLK_EDGE:
			//a SPI byte with a total of 64 clock edges
			if(clk_edge_cnt == WIDTH*2-1)
				next_state <= LAST_HALF_CYCLE;
			else
				next_state <= DCLK_IDLE;
		//this is the last data edge
		LAST_HALF_CYCLE:
			if(clk_cnt == clk_div)
				next_state <= ACK;
			else
				next_state <= LAST_HALF_CYCLE;
		//send one byte complete
		ACK:
			next_state <= ACK_WAIT;
		//wait for one clock cycle, to ensure that the cancel request signal
		ACK_WAIT:
			next_state <= IDLE;
		default:
			next_state <= IDLE;
	endcase
end

always@(posedge sys_clk or posedge rst)
begin
	if(rst == 0)
		DCLK_reg <= 1'b0;
	else if(state == IDLE)
		DCLK_reg <= CPOL;
	else if(state == DCLK_EDGE)
		DCLK_reg <= ~DCLK_reg;//SPI clock edge
end
//SPI clock wait counter
always@(posedge sys_clk or posedge rst)
begin
	if(rst == 0)
		clk_cnt <= 16'd0;
	else if(state == DCLK_IDLE || state == LAST_HALF_CYCLE)
		clk_cnt <= clk_cnt + 16'd1;
	else
		clk_cnt <= 16'd0;
end
//SPI clock edge counter
always@(posedge sys_clk or posedge rst)
begin
	if(rst == 0)
		clk_edge_cnt <= 7'd0;
	else if(state == DCLK_EDGE)
		clk_edge_cnt <= clk_edge_cnt + 7'd1;
	else if(state == IDLE)
		clk_edge_cnt <= 7'd0;
end
//SPI data output
always@(posedge sys_clk or posedge rst)
begin
	if(rst == 0)
		MOSI_shift <= 8'd0;
	else if(state == IDLE && wr_req)
		MOSI_shift <= data_in;
	else if(state == DCLK_EDGE)
		if(CPHA == 1'b0 && clk_edge_cnt[0] == 1'b1)
			MOSI_shift <= {MOSI_shift[WIDTH-2:0],MOSI_shift[WIDTH-1]};
		else if(CPHA == 1'b1 && (clk_edge_cnt != 5'd0 && clk_edge_cnt[0] == 1'b0))
			MOSI_shift <= {MOSI_shift[WIDTH-2:0],MOSI_shift[WIDTH-1]};
end
//SPI data input
always@(posedge sys_clk or posedge rst)
begin
	if(rst == 0)
		MISO_shift <= 8'd0;
	else if(state == IDLE && wr_req)
		MISO_shift <= 8'h00;
	else if(state == DCLK_EDGE)
		if(CPHA == 1'b0 && clk_edge_cnt[0] == 1'b0)
			MISO_shift <= {MISO_shift[WIDTH-1:0],MISO};
		else if(CPHA == 1'b1 && (clk_edge_cnt[0] == 1'b1))
			MISO_shift <= {MISO_shift[WIDTH-2:0],MISO};
end
endmodule