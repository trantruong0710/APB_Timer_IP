module tcr(
	input wire clk,
	input wire rst_n,
	input wire [31:0] wdata,
	input wire wr_en,
	input wire tcr_err,
	input wire [11:0] addr,
	input wire [3:0] strb,
	output reg timer_en,
	output reg div_en,
	output reg [3:0] div_val,
	output wire [31:0] tcr,
	output wire falling_edge
);

wire tcr_wr_sel;
reg timer_en_d;
assign tcr_wr_sel = wr_en & (addr == 12'h000) & (~tcr_err);
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		timer_en <= 1'b0;
		div_en <= 1'b0;
		div_val <= 3'b001;
		timer_en_d <= 1'b0;
	end else begin
		timer_en_d <= timer_en;
		if(tcr_wr_sel && strb[0]) begin
			timer_en <= wdata[0];
			div_en <= wdata[1];
		end
		if(tcr_wr_sel && strb[1]) begin
			div_val <= wdata[11:8];
		end
	end
end
assign falling_edge = timer_en_d & (~timer_en);
assign tcr = {20'b0, div_val, 6'b0, div_en, timer_en};
endmodule	
