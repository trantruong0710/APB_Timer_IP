module thcsr(
	input wire clk,
	input wire rst_n,
	input wire wr_en,
	input wire [11:0] addr,
	input wire [31:0] wdata,
	input wire [3:0] strb,
	input wire halt_ack,
	output reg halt_req,
	output wire [31:0] thcsr
);
wire thcsr_wr_en;
assign thcsr_wr_en = wr_en & strb[0] & (addr == 12'h01C);
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		halt_req <= 1'b0;
	else if(thcsr_wr_en)
		halt_req <= wdata[0];
end
assign thcsr = {30'b0, halt_ack, halt_req};
endmodule
