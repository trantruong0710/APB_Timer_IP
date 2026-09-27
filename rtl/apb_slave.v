module apb_slave(
	input wire clk,
	input wire rst_n,
	input wire tim_psel,
	input wire tim_penable,
	input wire tim_pwrite,
	input wire [11:0] tim_paddr,
	input wire [31:0] tim_pwdata,
	input wire [3:0] tim_pstrb,
	input wire [31:0] tcr,
	input wire [31:0] rdata,
	output reg wr_en,
	output reg rd_en,
	output wire [11:0] addr,
	output wire [31:0] wdata,
	output wire [3:0] strb,
	output wire [31:0] tim_prdata,
	output wire tim_pready,
	output wire tim_pslverr,
	output wire tcr_err
);
wire wr_req;
wire rd_req;
wire is_tcr_write;
wire div_en_change;
wire div_val_change;
wire illegal_div_val;
wire running_change;

assign wr_req = tim_psel & tim_penable & tim_pwrite & (~wr_en);
assign rd_req = tim_psel & tim_penable & (~tim_pwrite) & (~rd_en);

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		wr_en <= 1'b0;
		rd_en <= 1'b0;
	end else begin
		wr_en <= wr_req;
		rd_en <= rd_req;
	end
end

assign tim_pready = wr_en | rd_en;
assign addr = tim_paddr;
assign wdata = tim_pwdata;
assign strb = tim_pstrb;
assign tim_prdata = rdata;
assign is_tcr_write = wr_en & (tim_paddr == 12'h000);
assign div_en_change = tim_pstrb[0] & (tcr[1] != tim_pwdata[1]);
assign div_val_change = tim_pstrb[1] & (tcr[11:8] != tim_pwdata[11:8]);
assign illegal_div_val = tim_pstrb[1] & (tim_pwdata[11:8] > 4'd8);
assign running_change = tcr[0] & (div_en_change | div_val_change);
assign tcr_err = is_tcr_write & (illegal_div_val | running_change);
assign tim_pslverr = tcr_err;
endmodule
