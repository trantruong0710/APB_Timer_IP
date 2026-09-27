module timer_top(
	input wire sys_clk,
	input wire sys_rst_n,
	input wire tim_psel,
	input wire tim_pwrite,
	input wire tim_penable,
	input wire [11:0] tim_paddr,
	input wire [31:0] tim_pwdata,
	input wire [3:0] tim_pstrb,
	input wire dbg_mode,
	output wire [31:0] tim_prdata,
	output wire tim_pready,
	output wire tim_pslverr,
	output wire tim_int
);
wire wr_en;
wire rd_en;
wire [11:0] addr;
wire [31:0] wdata;
wire [3:0] strb;
wire tcr_err;
wire timer_en;
wire div_en;
wire [3:0] div_val;
wire [31:0] tcr;
wire falling_edge;
wire cnt_en;
wire halt_req;
wire halt_ack;
wire tdr0_wr_en;
wire tdr1_wr_en;
wire [31:0] tdr0;
wire [31:0] tdr1;
wire [63:0] cnt;
wire [31:0] tcmp0;
wire [31:0] tcmp1;
wire [63:0] tcmp;
wire [31:0] tier;
wire [31:0] tisr;
wire [31:0] thcsr;
reg [31:0] rdata_dec;
wire [31:0] rdata;

assign tdr0_wr_en = wr_en & (addr == 12'h004);
assign tdr1_wr_en = wr_en & (addr == 12'h008);

always @(*) begin
	case(addr) 
		12'h000: rdata_dec = tcr;
		12'h004: rdata_dec = tdr0;
		12'h008: rdata_dec = tdr1;
		12'h00C: rdata_dec = tcmp0;
		12'h010: rdata_dec = tcmp1;
		12'h014: rdata_dec = tier;
		12'h018: rdata_dec = tisr;
		12'h01C: rdata_dec = thcsr;
		default: rdata_dec = 32'h0000_0000;
	endcase
end

assign rdata = rd_en ? rdata_dec : 32'h0000_0000;

apb_slave u_apb_slave(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.tim_psel(tim_psel),
	.tim_penable(tim_penable),
	.tim_pwrite(tim_pwrite),
	.tim_paddr(tim_paddr),
	.tim_pwdata(tim_pwdata),
	.tim_pstrb(tim_pstrb),
	.tcr(tcr),
	.rdata(rdata),
	.wr_en(wr_en),
	.rd_en(rd_en),
	.addr(addr),
	.wdata(wdata),
	.strb(strb),
	.tim_prdata(tim_prdata),
	.tim_pready(tim_pready),
	.tim_pslverr(tim_pslverr),
	.tcr_err(tcr_err)
);

tcr u_tcr(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.wdata(wdata),
	.wr_en(wr_en),
	.tcr_err(tcr_err),
	.addr(addr),
	.strb(strb),
	.timer_en(timer_en),
	.div_en(div_en),
	.div_val(div_val),
	.tcr(tcr),
	.falling_edge(falling_edge)
);

counter_control u_counter_control(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.timer_en(timer_en),
	.div_en(div_en),
	.div_val(div_val),
	.dbg_mode(dbg_mode),
	.halt_req(halt_req),
	.cnt_en(cnt_en),
	.halt_ack(halt_ack)
);

counter_64b u_counter_64b(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.cnt_en(cnt_en),
	.falling_edge(falling_edge),
	.tdr0_wr_en(tdr0_wr_en),
	.tdr1_wr_en(tdr1_wr_en),
	.tdr_wdata(wdata),
	.tim_pstrb(strb),
	.tdr0(tdr0),
	.tdr1(tdr1),
	.cnt(cnt)
);

tcmp u_tcmp(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.wr_en(wr_en),
	.addr(addr),
	.wdata(wdata),
	.strb(strb),
	.tcmp0(tcmp0),
	.tcmp1(tcmp1),
	.tcmp(tcmp)
);

interrupt u_interrupt(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.cnt(cnt),
	.tcmp(tcmp),
	.wr_en(wr_en),
	.addr(addr),
	.wdata(wdata),
	.strb(strb),
	.tier(tier),
	.tisr(tisr),
	.tim_int(tim_int)
);

thcsr u_thcsr(
	.clk(sys_clk),
	.rst_n(sys_rst_n),
	.wr_en(wr_en),
	.addr(addr),
	.wdata(wdata),
	.strb(strb),
	.halt_ack(halt_ack),
	.halt_req(halt_req),
	.thcsr(thcsr)
);
endmodule
