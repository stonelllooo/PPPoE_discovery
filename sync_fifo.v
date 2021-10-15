
// //**********************************************
// //COPYRIGHT(c)2021, Xidian University
// //All rights reserved.
// //
// //File name     : sync_fifo.v
// //Module name   : sync_fifo	
// //Full name     :
// //Author 		: Xu Mingwei
// //Email 		: xumingweiaa@qq.com
// //
// //Version 		:
// //This File is  Created on 2021-06-22 22:30:56
// //------------------Discription-----------------
// //
// //----------------------------------------------
// //-------------Modification history-------------
// //Last Modified by 	: xumingwei
// //Last Modified time: 2021-06-22 22:53:03
// //Discription 	:
// //----------------------------------------------
// //TIMESCALE
// `timescale 1ns/1ns
// //DEFINES
// //`include ".v"
// //----------------------------------------------

module sync_fifo #(
		parameter		WIDTH = 8	,	// data width
		parameter		ADDR  = 8		// address width
	)
	(
	input					  clk	,	// sync clock
	input					  rst_n	,	// async reset(low)

	input		[WIDTH-1:0]	  din	,	// input data
	input					  wr_en	,	// write enable
	output	wire			  full  ,	// write full symbol

	output	reg	[WIDTH-1:0]	  dout	,	// output data
	input					  rd_en ,	// read enable
	output	wire			  empty 	// read empty symbol
);


localparam		DEPTH = 1 << ADDR;


wire	[ADDR-1:0]	wr_addr	  		;	// DPRAM 写地址
wire	[ADDR-1:0]	rd_addr	  		;	// DPRAM 读地址
reg		[ADDR:0]	wr_addr_ptr	  	;	// FIFO 写指针
reg		[ADDR:0]	rd_addr_ptr	  	;	// FIFO 读指针

reg		[WIDTH-1:0]	DPRAM [DEPTH-1:0];	// DPRAM


// DPRAM 写操作
always @(posedge clk) begin
	if ( wr_en && !full ) begin
		DPRAM[wr_addr] <= din;
		$display("================== %h =====================",DPRAM[wr_addr]);
	end
	else begin
		DPRAM[wr_addr] <= DPRAM[wr_addr];
	end
end


// DPRAM 读操作
always @(posedge clk) begin
	if ( rd_en && !empty ) begin
		dout <= DPRAM[rd_addr];
	end
	else begin
		dout <= 'd0;
	end
end


// FIFO 写指针自增
always @(posedge clk or negedge rst_n) begin
	if ( rst_n == 1'b0 ) begin
		wr_addr_ptr <='d0;
	end
	else if( wr_en && !full ) begin
		wr_addr_ptr <= wr_addr_ptr + 1'b1;
	end
	else begin
		wr_addr_ptr <= wr_addr_ptr;
	end
end


// FIFO 读指针自增
always @(posedge clk or negedge rst_n) begin
	if ( rst_n == 1'b0 ) begin
		rd_addr_ptr <='d0;
	end
	else if( rd_en && !empty ) begin
		rd_addr_ptr <= rd_addr_ptr + 1'b1;
	end
	else begin
		rd_addr_ptr <= rd_addr_ptr;
	end
end


assign wr_addr = wr_addr_ptr[ADDR-1:0];
assign rd_addr = rd_addr_ptr[ADDR-1:0];
assign full = { ~wr_addr_ptr[ADDR], wr_addr_ptr[ADDR-1:0] } == rd_addr_ptr;
assign empty = wr_addr_ptr == rd_addr_ptr;

endmodule
