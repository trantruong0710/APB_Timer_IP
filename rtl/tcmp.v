module tcmp(
	input wire clk,
	input wire rst_n,
	input wire wr_en,
	input wire [11:0] addr,
	input wire [31:0] wdata,
	input wire [3:0] strb,
	output reg [31:0] tcmp0,
	output reg [31:0] tcmp1,
	output wire [63:0] tcmp
);

wire tcmp0_wr_en;
wire tcmp1_wr_en;
assign tcmp0_wr_en = wr_en & (addr == 12'h00C);
assign tcmp1_wr_en = wr_en & (addr == 12'h010);

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		tcmp0 <= 32'hFFFF_FFFF;
	end else if(tcmp0_wr_en) begin
		if(strb[0])
			tcmp0[7:0] <= wdata[7:0];
		if(strb[1])
			tcmp0[15:8] <= wdata[15:8];
		if(strb[2])
			tcmp0[23:16] <= wdata[23:16];
		if(strb[3])
			tcmp0[31:24] <= wdata[31:24];
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		tcmp1 <= 32'hFFFF_FFFF;
	end else if(tcmp1_wr_en) begin
		if(strb[0])
			tcmp1[7:0] <= wdata[7:0];
		if(strb[1])
			tcmp1[15:8] <= wdata[15:8];
		if(strb[2])
			tcmp1[23:16] <= wdata[23:16];
		if(strb[3])
			tcmp1[31:24] <= wdata[31:24];
	end
end
assign tcmp = {tcmp1, tcmp0};
endmodule
