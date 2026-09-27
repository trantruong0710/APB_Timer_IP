module counter_control(
	input wire clk,
	input wire rst_n,
	input wire timer_en,
	input wire div_en,
	input wire[3:0] div_val,
	input wire dbg_mode,
	input wire halt_req,
	output wire cnt_en,
	output wire halt_ack
);
reg[7:0] div_limit;
wire div_tick;
wire halt_active;
wire base_cnt_en;
wire div_cnt_en;
wire div_cnt_clr;
reg [7:0] div_cnt;

always @(*) begin
	case(div_val)
		4'd0: div_limit = 8'h00;
		4'd1: div_limit = 8'h01;
		4'd2: div_limit = 8'h03;
		4'd3: div_limit = 8'h07;
		4'd4: div_limit = 8'h0F;
		4'd5: div_limit = 8'h1F;
		4'd6: div_limit = 8'h3F;
		4'd7: div_limit = 8'h7F;
		4'd8: div_limit = 8'hFF;
		default: div_limit = 8'h00;
	endcase
end

assign halt_active = dbg_mode & halt_req;
assign halt_ack = halt_active;
assign div_tick = (div_cnt == div_limit);
assign base_cnt_en = div_en ? div_tick : 1'b1;
assign cnt_en = timer_en & base_cnt_en & (~halt_active);
assign div_cnt_en = timer_en & div_en & (~halt_active);
assign div_cnt_clr = (~timer_en) | (div_cnt_en & div_tick);
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		div_cnt <= 8'h00;
	end else if(div_cnt_clr) begin
		div_cnt <= 8'h00;
	end else if(div_cnt_en) begin
		div_cnt <= div_cnt + 8'h01;
	end else begin
		div_cnt <= div_cnt;
	end
end
endmodule

module counter_64b(
	input wire clk,
	input wire rst_n,
	input wire cnt_en,
	input wire falling_edge,
	input wire tdr0_wr_en,
	input wire tdr1_wr_en,
	input wire [31:0] tdr_wdata,
	input wire [3:0] tim_pstrb,
	output reg [31:0] tdr0,
	output reg [31:0] tdr1,
	output wire [63:0] cnt
);
wire [63:0] cnt_plus1;
wire [31:0] tdr0_cnt_sel;
wire [31:0] tdr1_cnt_sel;
wire [31:0] tdr0_clr_sel;
wire [31:0] tdr1_clr_sel;
wire [31:0] tdr0_next;
wire [31:0] tdr1_next;
assign cnt = {tdr1, tdr0};
assign cnt_plus1 = cnt + 64'd1;
assign tdr0_cnt_sel = cnt_en ? cnt_plus1[31:0] : tdr0;
assign tdr1_cnt_sel = cnt_en ? cnt_plus1[63:32] : tdr1;
assign tdr0_clr_sel = falling_edge ? 32'h0000_0000 : tdr0_cnt_sel;
assign tdr1_clr_sel = falling_edge ? 32'h0000_0000 : tdr1_cnt_sel;
assign tdr0_next[7:0] = (tdr0_wr_en && tim_pstrb[0]) ? tdr_wdata[7:0] : tdr0_clr_sel[7:0];
assign tdr0_next[15:8] = (tdr0_wr_en && tim_pstrb[1]) ? tdr_wdata[15:8] : tdr0_clr_sel[15:8];
assign tdr0_next[23:16] = (tdr0_wr_en && tim_pstrb[2]) ? tdr_wdata[23:16] : tdr0_clr_sel[23:16];
assign tdr0_next[31:24] = (tdr0_wr_en && tim_pstrb[3]) ? tdr_wdata[31:24] : tdr0_clr_sel[31:24];
assign tdr1_next[7:0] = (tdr1_wr_en && tim_pstrb[0]) ? tdr_wdata[7:0] : tdr1_clr_sel[7:0];
assign tdr1_next[15:8] = (tdr1_wr_en && tim_pstrb[1]) ? tdr_wdata[15:8] : tdr1_clr_sel[15:8];
assign tdr1_next[23:16] = (tdr1_wr_en && tim_pstrb[2]) ? tdr_wdata[23:16] : tdr1_clr_sel[23:16];
assign tdr1_next[31:24] = (tdr1_wr_en && tim_pstrb[3]) ? tdr_wdata[31:24] : tdr1_clr_sel[31:24];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		tdr0 <= 32'h0000_0000;
		tdr1 <= 32'h0000_0000;
	end else begin
		tdr0 <= tdr0_next;
		tdr1 <= tdr1_next;
	end
end
endmodule
