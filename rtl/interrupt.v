module interrupt(
	input wire clk,
	input wire rst_n,
	input wire[63:0] cnt,
	input wire[63:0] tcmp,
	input wire wr_en,
	input wire [11:0] addr,
	input wire [31:0] wdata,
	input wire [3:0] strb,
	output wire [31:0] tier,
	output wire [31:0] tisr,
	output wire tim_int
);

wire wr_en_tier;
wire wr_en_tisr;
wire int_set;
wire int_clr;
reg int_en;
reg int_st;

assign wr_en_tier = wr_en & (addr == 12'h014);
assign wr_en_tisr = wr_en & (addr == 12'h018);
assign int_set = (cnt == tcmp);
assign int_clr = int_st & wr_en_tisr & strb[0] & wdata[0];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		int_en <= 1'b0;
	end else if(wr_en_tier && strb[0]) begin
		int_en <= wdata[0];
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		int_st <= 1'b0;
	end else if(int_clr) begin
		 int_st <= 1'b0;
	 end else if(int_set) begin
		 int_st <= 1'b1;
	 end
 end
 assign tier = {31'b0, int_en};
 assign tisr = {31'b0, int_st};
 assign tim_int = int_en & int_st;
 endmodule
