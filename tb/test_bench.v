`timescale 1ns/1ps

module test_bench;
parameter CLK_PERIOD = 10;
parameter APB_TIMEOUT = 20;
parameter [11:0] ADDR_TCR = 12'h000;
parameter [11:0] ADDR_TDR0 = 12'h004;
parameter [11:0] ADDR_TDR1 = 12'h008;
parameter [11:0] ADDR_TCMP0 = 12'h00C;
parameter [11:0] ADDR_TCMP1 = 12'h010;
parameter [11:0] ADDR_TIER = 12'h014;
parameter [11:0] ADDR_TISR = 12'h018;
parameter [11:0] ADDR_THCSR = 12'h01C;

reg sys_clk;
reg sys_rst_n;
reg tim_psel;
reg tim_pwrite;
reg tim_penable;
reg [11:0] tim_paddr;
reg [31:0] tim_pwdata;
reg [3:0] tim_pstrb;
wire [31:0] tim_prdata;
wire tim_pready;
wire tim_pslverr;
wire tim_int;
reg dbg_mode;
reg [31:0] read_data;
reg last_slverr;

integer last_wait_cycles;
integer pass_count;
integer fail_count;

timer_top dut(
	.sys_clk(sys_clk),
	.sys_rst_n(sys_rst_n),
	.tim_psel(tim_psel),
	.tim_pwrite(tim_pwrite),
	.tim_penable(tim_penable),
	.tim_paddr(tim_paddr),
	.tim_pwdata(tim_pwdata),
	.tim_pstrb(tim_pstrb),
	.tim_prdata(tim_prdata),
	.tim_pready(tim_pready),
	.tim_pslverr(tim_pslverr),
	.tim_int(tim_int),
	.dbg_mode(dbg_mode)
);

always #(CLK_PERIOD/2) sys_clk = ~sys_clk;

task bus_idle;
	begin
		tim_psel = 1'b0;
		tim_pwrite = 1'b0;
		tim_penable = 1'b0;
		tim_paddr = 12'h000;
		tim_pwdata = 32'h0000_0000;
		tim_pstrb = 4'b0000;
	end
endtask

task reset_dut;
	begin
		@(negedge sys_clk);
		sys_rst_n =1'b0;
		bus_idle;
		repeat(2) @(posedge sys_clk);
		@(negedge sys_clk);
		sys_rst_n = 1'b1;
		@(posedge sys_clk);
	end 
endtask

task apb_write;
	input [11:0] address;
	input [31:0] data;
	input [3:0] byte_strobe;
	integer timeout;
	begin
		last_slverr = 1'b0;
		last_wait_cycles = 0;
		timeout = 0;
		@(negedge sys_clk);
		tim_psel = 1'b1;
		tim_penable = 1'b0;
		tim_pwrite = 1'b1;
		tim_paddr = address;
		tim_pwdata = data;
		tim_pstrb = byte_strobe;
		@(negedge sys_clk);
		tim_penable = 1'b1;
		while(tim_pready !== 1'b1) begin
			@(negedge sys_clk);
			last_wait_cycles = last_wait_cycles + 1;
			timeout = timeout + 1;
			if(timeout > APB_TIMEOUT) begin
				$display("FAIL APB WRITE TIMEOUT addr=%h", address);
				fail_count = fail_count + 1;
				$finish;
			end
		end
		last_slverr = tim_pslverr;
		@(posedge sys_clk);
		@(negedge sys_clk);
		bus_idle;
	end
endtask

task apb_read;
	input [11:0] address;
	integer timeout;
	begin
		last_slverr = 1'b0;
		last_wait_cycles = 0;
		timeout = 0;
		@(negedge sys_clk);
		tim_psel = 1'b1;
		tim_penable = 1'b0;
		tim_pwrite = 1'b0;
		tim_paddr = address;
		tim_pwdata = 32'h0000_0000;
		tim_pstrb = 4'b0000;
		@(negedge sys_clk);
		tim_penable = 1'b1;
		while(tim_pready !== 1'b1) begin
			@(negedge sys_clk);
			last_wait_cycles = last_wait_cycles + 1;
			timeout = timeout + 1;
			if(timeout > APB_TIMEOUT) begin
				$display("FAIL APB READ TIMEOUT addr=%h", address);
				fail_count = fail_count + 1;
				$finish;
			end
		end
		read_data = tim_prdata;
		last_slverr = tim_pslverr;
		@(posedge sys_clk);
		@(negedge sys_clk);
		bus_idle;
	end
endtask

task check32;
	input [8*64-1:0] check_name;
	input [31:0] actual;
	input [31:0] expected;
	begin
		if(actual !== expected) begin
			$display("FAIL %0s: expected=%h, actual=%h", check_name, expected, actual);
			fail_count = fail_count + 1;
		end else begin
			$display("PASS %0s: expected=%h, actual=%h", check_name, expected, actual);
			pass_count = pass_count + 1;
		end
	end
endtask

task check1;
	input [8*64-1:0] check_name;
	input actual;
	input expected;
	begin
		if(actual !== expected) begin
			$display("FAIL %0s: expected=%h, actual=%h", check_name, expected, actual);
			fail_count = fail_count + 1;
		end else begin
			$display("PASS %0s: expected=%h, actual=%h", check_name, expected, actual);
			pass_count = pass_count + 1;
		end
	end
endtask

task ID1;
	begin
		$display("-----ID1-----");
		dbg_mode = 1'b0;
		reset_dut;
		apb_read(ADDR_TCR);
		check32("TCR reset value", read_data, 32'h0000_0100);
		apb_read(ADDR_TDR0);
		check32("TDR0 reset value", read_data, 32'h0000_0000);
		apb_read(ADDR_TDR1);
		check32("TDR1 reset value", read_data, 32'h0000_0000);
		apb_read(ADDR_TCMP0);
		check32("TCMP0 reset value", read_data, 32'hFFFF_FFFF);
		apb_read(ADDR_TCMP1);
		check32("TCMP1 reset value", read_data, 32'hFFFF_FFFF);
		apb_read(ADDR_TIER);
		check32("TIER reset value", read_data, 32'h0000_0000);
		apb_read(ADDR_TISR);
		check32("TISR reset value", read_data, 32'h0000_0000);
		apb_read(ADDR_THCSR);
		check32("THCSR reset value", read_data, 32'h0000_0000);
		check1("TIM_INT after reset", tim_int, 1'b0);
	end
endtask

task ID2;
	begin
		$display("-----ID2-----");
		reset_dut;
		apb_write(ADDR_TCMP0, 32'h1234_5678, 4'b1111);
		check1("APB write PSLVERR", last_slverr, 1'b0);
		if(last_wait_cycles ==1) begin
			$display("PASS APB write wait state: 1 cycle");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL APB write wait state: expected=1, actual=%0d", last_wait_cycles);
			fail_count = fail_count + 1;
		end
		apb_read(ADDR_TCMP0);
		check1("APB read PSLVERR", last_slverr, 1'b0);
		if(last_wait_cycles ==1) begin
			$display("PASS APB read wait state: 1 cycle");
			pass_count = pass_count + 1;
			end else begin
				$display("FAIL APB read wait state: expected=1, actual=%0d", last_wait_cycles);
				fail_count = fail_count + 1;
			end
			check32("APBreadback TCMP0", read_data, 32'h1234_5678);
		end
endtask

task ID3;
	reg [31:0] rdata0;
	reg [31:0] rdata1;
	reg w_err0;
	reg w_err1;
	reg r_err0;
	reg r_err1;
	integer w_wait0;
	integer w_wait1;
	integer r_wait0;
	integer r_wait1;
	integer timeout;
	begin
		$display("-----ID3-----");
		reset_dut;

		w_wait0 = 0;
		timeout = 0;
		@(negedge sys_clk);
		tim_psel = 1'b1;
		tim_penable = 1'b0;
		tim_pwrite = 1'b1;
		tim_paddr = ADDR_TCMP0;
		tim_pwdata = 32'hAAAA_5555;
		tim_pstrb = 4'b1111;
		@(negedge sys_clk);
		tim_penable = 1'b1;
		while(tim_pready !== 1'b1) begin
			@(negedge sys_clk);
			w_wait0 = w_wait0 + 1;
			timeout = timeout + 1;
			if(timeout > APB_TIMEOUT) begin
				$display("FAIL ID3 WRITE TCMP0 TIMEOUT");
				fail_count = fail_count + 1;
				$finish;
			end
		end
		w_err0 = tim_pslverr;
		@(posedge sys_clk);

		@(negedge sys_clk);
		tim_psel = 1'b1;
		tim_penable = 1'b0;
		tim_pwrite = 1'b1;
		tim_paddr = ADDR_TCMP1;
		tim_pwdata = 32'h1234_5678;
		tim_pstrb = 4'b1111;
		w_wait1 = 0;
		timeout = 0;
		@(negedge sys_clk);
		tim_penable = 1'b1;
		while(tim_pready !== 1'b1) begin
			@(negedge sys_clk);
			w_wait1 = w_wait1 + 1;
			timeout = timeout + 1;
			if(timeout > APB_TIMEOUT) begin
				$display("FAIL ID3 WRITE TCMP1 TIMEOUT");
				fail_count = fail_count + 1;
				$finish;
			end
		end
		w_err1 = tim_pslverr;
		@(posedge sys_clk);
		@(negedge sys_clk);
		bus_idle;

		if((w_wait0 == 1) && (w_wait1 == 1)) begin
			$display("PASS Back-to-back write wait states: 1 cycle each");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Back-to-back write wait states: first=%0d, second=%0d", w_wait0, w_wait1);
			fail_count = fail_count + 1;
		end
		if((w_err0 == 1'b0) && (w_err1 == 1'b0)) begin
			$display("PASS Back-to-back write PSLVERR: 0");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Back-to-back write PSLVERR: first=%0d, second=%0d", w_err0, w_err1);
			fail_count = fail_count + 1;
		end
		r_wait0 = 0;
		timeout = 0;
		@(negedge sys_clk);
		tim_psel = 1'b1;
		tim_penable = 1'b0;
		tim_pwrite = 1'b0;
		tim_paddr = ADDR_TCMP0;
		tim_pwdata = 32'h0000_0000;
		tim_pstrb = 4'b0000;
		@(negedge sys_clk);
		tim_penable = 1'b1;
		while(tim_pready !== 1'b1) begin
			@(negedge sys_clk);
			r_wait0 = r_wait0 + 1;
			timeout = timeout + 1;
			if(timeout > APB_TIMEOUT) begin
				$display("FAIL ID3 READ TCMP0 TIMEOUT");
				fail_count = fail_count + 1;
				$finish;
			end
		end
		rdata0 = tim_prdata;
		r_err0 = tim_pslverr;
		@(posedge sys_clk);
		@(negedge sys_clk);
		tim_psel = 1'b1;
		tim_penable = 1'b0;
		tim_pwrite = 1'b0;
		tim_paddr = ADDR_TCMP1;
		tim_pwdata = 32'h0000_0000;
		tim_pstrb = 4'b0000;
		r_wait1 = 0;
		timeout = 0;
		@(negedge sys_clk);
		tim_penable = 1'b1;
		while(tim_pready !== 1'b1) begin
			@(negedge sys_clk);
			r_wait1 = r_wait1 + 1;
			timeout = timeout + 1;
			if(timeout > APB_TIMEOUT) begin
				$display("FAIL ID3 READ TCMP1 TIMEOUT");
				fail_count = fail_count + 1;
				$finish;
			end
		end
		$display("DBG addr=%h dut_addr=%h rd_en=%b pready=%b rdata_dec=%h prdata=%h",tim_paddr,dut.addr,dut.rd_en,tim_pready,dut.rdata_dec,tim_prdata);
		rdata1 = tim_prdata;
		r_err1 = tim_pslverr;
		@(posedge sys_clk);
		@(negedge sys_clk);
		bus_idle;
		if((r_wait0 == 1) && (r_wait1 == 1)) begin
			$display("PASS Back-to-back read wait states: 1 cycle each");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Back-to-back read wait states: first=%0d, second=%0d", r_wait0, r_wait1);
			fail_count = fail_count + 1;
		end
		if((r_err0 == 1'b0) && (r_err1 == 1'b0)) begin
			$display("PASS Back-to-back read PSLVERR: 0");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Back-to-back read PSLVERR: first=%0d, second=%0d", r_err0, r_err1);
			fail_count = fail_count + 1;
		end

		check32("Back-to-back read TCMP0", rdata0, 32'hAAAA_5555);
		check32("Back-to-back read TCMP1", rdata1, 32'h1234_5678);
	end
endtask

task ID4;
	begin
		$display("-----ID4-----");
		reset_dut;
		dbg_mode = 1'b0;
		apb_write(ADDR_TCR, 32'h0000_0802,4'b1111);
		apb_write(ADDR_TDR0, 32'h1111_1111,4'b1111);
		apb_write(ADDR_TDR1, 32'h2222_2222,4'b1111);
		apb_write(ADDR_TCMP0, 32'h3333_3333,4'b1111);
		apb_write(ADDR_TCMP1, 32'h4444_4444,4'b1111);
		apb_write(ADDR_TIER, 32'h0000_0001,4'b1111);
		apb_write(ADDR_THCSR, 32'h0000_0001,4'b1111);
		apb_read(ADDR_TCR);
		check32("TCR R/W", read_data, 32'h0000_0802);
		apb_read(ADDR_TDR0);
		check32("TDR0 R/W", read_data, 32'h1111_1111);
		apb_read(ADDR_TDR1);
		check32("TDR1 R/W", read_data, 32'h2222_2222);
		apb_read(ADDR_TCMP0);
		check32("TCMP0 R/W", read_data, 32'h3333_3333);
		apb_read(ADDR_TCMP1);
		check32("TCMP1 R/W", read_data, 32'h4444_4444);
		apb_read(ADDR_TIER);
		check32("TIER R/W", read_data, 32'h0000_0001);
		apb_read(ADDR_THCSR);
		check32("THCSR halt_req R/W", read_data, 32'h0000_0001);
	end
endtask

task ID5;
	integer i;
	reg [3:0] test_strb;
	reg [31:0] expected;
	begin
		$display("-----ID5-----");
		reset_dut;
		dbg_mode = 1'b0;
		//TCR
		apb_write(ADDR_TCR, 32'h0000_0002, 4'b0001);
		apb_read(ADDR_TCR);
		check32("TCR byte0 access", read_data, 32'h0000_0102);
		apb_write(ADDR_TCR, 32'h0000_0800, 4'b0010);
		apb_read(ADDR_TCR);
		check32("TCR byte1 access", read_data, 32'h0000_0802);
		//TDR0
		expected = 32'h0000_0000;
		for(i = 0; i< 4;i = i + 1) begin
			case(i)
				0: begin
					test_strb = 4'b0001;
					expected[7:0] = 8'h11;
				end
				1: begin
					test_strb = 4'b0010;
					expected[15:8] = 8'h22;
				end
				2: begin
					test_strb = 4'b0100;
					expected[23:16] = 8'h33;
				end
				3: begin
					test_strb = 4'b1000;
					expected[31:24] = 8'h44;
				end
			endcase
			apb_write(ADDR_TDR0,32'h4433_2211,test_strb);
			apb_read(ADDR_TDR0);
			$display("Checking TDR0 %0d", i);
			check32("TDR0 byte access",read_data,expected);
		end
		//TDR1
		expected = 32'h0000_0000;
		for(i = 0; i< 4;i = i + 1) begin
			case(i)
				0: begin
					test_strb = 4'b0001;
					expected[7:0] = 8'h55;
				end
				1: begin
					test_strb = 4'b0010;
					expected[15:8] = 8'h66;
				end
				2: begin
					test_strb = 4'b0100;
					expected[23:16] = 8'h77;
				end
				3: begin
					test_strb = 4'b1000;
					expected[31:24] = 8'h88;
				end
			endcase
			apb_write(ADDR_TDR1,32'h8877_6655,test_strb);
			apb_read(ADDR_TDR1);
			$display("Checking TDR1 %0d", i);
			check32("TDR1 byte access",read_data,expected);
		end
		//TCMP0
		apb_write(ADDR_TCMP0, 32'h0000_0000,4'b1111);
		expected = 32'h0000_0000;
		for(i = 0; i< 4;i = i + 1) begin
			case(i)
				0: begin
					test_strb = 4'b0001;
					expected[7:0] = 8'h11;
				end
				1: begin
					test_strb = 4'b0010;
					expected[15:8] = 8'h22;
				end
				2: begin
					test_strb = 4'b0100;
					expected[23:16] = 8'h33;
				end
				3: begin
					test_strb = 4'b1000;
					expected[31:24] = 8'h44;
				end
			endcase
			apb_write(ADDR_TCMP0,32'h4433_2211,test_strb);
			apb_read(ADDR_TCMP0);
			$display("Checking TCMP0 byte %0d",i);
			check32("TCMP0 byte access", read_data, expected);
		end
		//TCMP1
		apb_write(ADDR_TCMP1, 32'h0000_0000,4'b1111);
		expected = 32'h0000_0000;
		for(i = 0; i< 4;i = i + 1) begin
			case(i)
				0: begin
					test_strb = 4'b0001;
					expected[7:0] = 8'h55;
				end
				1: begin
					test_strb = 4'b0010;
					expected[15:8] = 8'h66;
				end
				2: begin
					test_strb = 4'b0100;
					expected[23:16] = 8'h77;
				end
				3: begin
					test_strb = 4'b1000;
					expected[31:24] = 8'h88;
				end
			endcase
			apb_write(ADDR_TCMP1,32'h8877_6655,test_strb);
			apb_read(ADDR_TCMP1);
			$display("Checking TCMP1 byte %0d",i);
			check32("TCMP1 byte access", read_data, expected);
		end
		//TIER
		apb_write(ADDR_TIER, 32'h0000_0001, 4'b0001);
		apb_read(ADDR_TIER);
		check32("TIER byte0 access", read_data, 32'h0000_0001);
		apb_write(ADDR_TIER, 32'h0000_FF00, 4'b0010);
		apb_read(ADDR_TIER);
		check32("TIER other byte ignored", read_data, 32'h0000_0001);
		//THCSR
		apb_write(ADDR_THCSR, 32'h0000_0001, 4'b0001);
		apb_read(ADDR_THCSR);
		check32("THCSR byte0 access", read_data, 32'h0000_0001);
		apb_write(ADDR_THCSR, 32'h0000_FF00, 4'b0010);
		apb_read(ADDR_THCSR);
		check32("THCSR other byte ignored", read_data, 32'h0000_0001);
	end
endtask

task ID6;
	integer i;
	reg [11:0] reserved_addr;
	reg [31:0] write_pattern;
	begin
		$display("-----ID6-----");
		reset_dut;
		dbg_mode = 1'b0;
		apb_write(ADDR_TCR, 32'h0000_0802, 4'b1111);
		apb_write(ADDR_TDR0, 32'h1111_1111, 4'b1111);
		apb_write(ADDR_TDR1, 32'h2222_2222, 4'b1111);
		apb_write(ADDR_TCMP0, 32'h3333_3333, 4'b1111);
		apb_write(ADDR_TCMP1, 32'h4444_4444, 4'b1111);
		apb_write(ADDR_TIER, 32'h0000_0001, 4'b1111);
		apb_write(ADDR_THCSR, 32'h0000_0001, 4'b1111);

		for(i = 0; i < 3; i = i + 1) begin
			case(i)
				0: begin
					reserved_addr = 12'h020;
					write_pattern = 32'hAAAA_AAAA;
				end
				1: begin
					reserved_addr = 12'h100;
					write_pattern = 32'h5555_5555;
				end
				2: begin
					reserved_addr = 12'hFFC;
					write_pattern = 32'hDEAD_BEEF;
				end
			endcase
			apb_write(reserved_addr, write_pattern, 4'b1111);
			check1("Reserved write PSLVERR", last_slverr, 1'b0);
			apb_read(reserved_addr);
			check32("Reserved read returns zero", read_data, 32'h0000_0000);
			check1("Reserved read PSLVERR", last_slverr, 1'b0);
		end
		for(i = 1; i <=3; i = i+1) begin
			apb_write(ADDR_TDR0 + i, 32'h4444_4444, 4'b1111);
			check1("Unaligned write PSLVERR", last_slverr, 1'b0);
			apb_read(ADDR_TDR0 + i);
			check32("Unaligned read return zero", read_data, 32'h0000_0000);
			check1("Unaligned read PSLVERR", last_slverr, 1'b0);
			apb_read(ADDR_TDR0);
			check32("Unaligned write ignored", read_data, 32'h1111_1111);
		end
		apb_read(ADDR_TCR);
		check32("Reserved write keep TCR", read_data, 32'h0000_0802);
		apb_read(ADDR_TDR0);
		check32("Reserved write keep TDR0", read_data, 32'h1111_1111);
		apb_read(ADDR_TDR1);
		check32("Reserved write keep TDR1", read_data, 32'h2222_2222);
		apb_read(ADDR_TCMP0);
		check32("Reserved write keep TCMP0", read_data, 32'h3333_3333);
		apb_read(ADDR_TCMP1);
		check32("Reserved write keep TCMP1", read_data, 32'h4444_4444);
		apb_read(ADDR_TIER);
		check32("Reserved write keep TIER", read_data, 32'h0000_0001);
		apb_read(ADDR_THCSR);
		check32("Reserved write keep THCSR", read_data, 32'h0000_0001);
	end
endtask

task ID7;
	integer i;
	reg[31:0] illegal_data;
	begin
		$display("-----ID7-----");
		reset_dut;
		for(i = 9; i <= 15; i = i + 1) begin
			illegal_data = (i << 8) | 32'h0000_0003;
			apb_write(ADDR_TCR, illegal_data, 4'b0011);
			check1("Illegal div_val PSLVERR", last_slverr, 1'b1);
		end
		apb_read(ADDR_TCR);
		check32("TCR unchanged after illegal div_val", read_data, 32'h0000_0100);
		reset_dut;
		apb_write(ADDR_TCR,32'h0000_0F00,4'b0001);
		check1("Illegal div_val byte not selected PSLVERR", last_slverr, 1'b0);
		apb_read(ADDR_TCR);
		check32("TCR unchanged when div_val byte not selected", read_data, 32'h0000_0100);
	end
endtask

task ID8;
	begin
		$display("----ID8----");
		reset_dut;
		dbg_mode = 1'b0;
		apb_write(ADDR_TCR, 32'h0000_0200, 4'b0010);
		apb_write(ADDR_TCR, 32'h0000_0001, 4'b0001);
		apb_write(ADDR_TCR, 32'h0000_0003, 4'b0001);
		check1("Change div_en while run PSLVERR", last_slverr, 1'b1);
		apb_read(ADDR_TCR);
		check32("TCR unchanged after div_en error", read_data, 32'h0000_0201);
		//case2
		apb_write(ADDR_TCR, 32'h0000_0300, 4'b0010);
		check1("Change div_val while run PSLVERR", last_slverr, 1'b1);
		apb_read(ADDR_TCR);
		check32("TCR unchanged after div_val error", read_data, 32'h0000_0201);
		//case3
		apb_write(ADDR_TCR, 32'h0000_0303, 4'b0011);
		check1("Change div_en and div_val while run PSLVERR", last_slverr, 1'b1);
		apb_read(ADDR_TCR);
		check32("TCR unchanged after combined error", read_data, 32'h0000_0201);
		//case4
		apb_write(ADDR_TCR, 32'h0000_0201, 4'b0011);
		check1("Same div setting while run PSLVERR", last_slverr, 1'b0);
		apb_read(ADDR_TCR);
		check32("TCR after same setting write", read_data, 32'h0000_0201);
	end
endtask

task ID9;
	reg[63:0] cnt_before;
	reg[63:0] cnt_after;
	begin
		$display("-----ID9-----");
		reset_dut;
		dbg_mode = 1'b0;
		//case1 timer_en=0
		//counter hold value
		apb_write(ADDR_TDR0,32'h0000_0005,4'b1111);
		repeat(5) @(posedge sys_clk);
		apb_read(ADDR_TDR0);
		check32("Counter holds when timer_en = 0", read_data, 32'h0000_0005);
		//case2 counting mode default
		apb_write(ADDR_TDR0,32'h0000_0000,4'b1111);
		apb_write(ADDR_TDR1,32'h0000_0000,4'b1111);
		apb_write(ADDR_TCR,32'h0000_0001,4'b1111);
		cnt_before = dut.cnt;
		repeat(8) @(posedge sys_clk);
		@(negedge sys_clk);
		cnt_after = dut.cnt;
		if(cnt_after == (cnt_before + 64'd8)) begin
			$display("PASS Default mode count: before=%0d, after=%0d", cnt_before, cnt_after);
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Default mode count: expected=%0d, actual=%0d", cnt_before + 64'd8, cnt_after);
			fail_count = fail_count + 1;
		end
	end
endtask

task ID10;
	integer i;
	integer period;
	reg [63:0] cnt_before;
	reg [63:0] cnt_after;
	begin
		$display("-----ID10-----");
		for (i = 0; i <= 8; i = i + 1) begin
			reset_dut;
			dbg_mode = 1'b0;
			apb_write(ADDR_TCR, (i << 8), 4'b0010);
			apb_write(ADDR_TCR,32'h0000_0003,4'b0001);
			period = (1 << i);
			cnt_before = dut.cnt;
			repeat(period * 3)@(posedge sys_clk);
			@(negedge sys_clk);
			cnt_after = dut.cnt;
			if(cnt_after == (cnt_before + 64'd3)) begin
				$display("PASS div_val=%0d period=%0d clocks: before=%0d, after=%0d",i,period,cnt_before,cnt_after);
				pass_count = pass_count + 1;
			end else begin
				$display("FAIL div_val=%0d period=%0d clocks: expected=%0d, actual=%0d",i,period,cnt_before + 64'd3,cnt_after);
				fail_count = fail_count + 1;
			end
		end
	end
endtask

task ID11;
	reg[63:0] cnt_value;
	begin
		$display("-----ID11-----");
		dbg_mode = 1'b0;
		reset_dut;
		//case1
		apb_write(ADDR_TDR1, 32'h1234_5678,4'b1111);
		apb_write(ADDR_TDR0, 32'hFFFF_FFFF,4'b1111);
		apb_write(ADDR_TCR, 32'h0000_0001,4'b0001);
		@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_value = dut.cnt;
		if(cnt_value === 64'h1234_5679_0000_0000) begin
			$display("PASS 32-bit carry: value=%h", cnt_value);
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL 32-bit carry: expected=1234567900000000,actual=%h", cnt_value);
			fail_count = fail_count + 1;
		end
		//case2
		apb_write(ADDR_TCR, 32'h0000_0000,4'b0001);
		@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_value = dut.cnt;
		if(cnt_value === 64'h0000_0000_0000_0000) begin
			$display("PASS timer_en H->L clear counter");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL timer_en H->L clear: actual=%h", cnt_value);
			fail_count = fail_count + 1;
		end
		//case3
		reset_dut;
		apb_write(ADDR_TDR0, 32'hFFFF_FFFF,4'b1111);
		apb_write(ADDR_TDR1, 32'hFFFF_FFFF,4'b1111);
		apb_write(ADDR_TCR, 32'h0000_0001,4'b0001);
		@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_value = dut.cnt;
		if(cnt_value === 64'h0000_0000_0000_0000) begin
			$display("PASS 64bit counter overflow wraps to zero");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL 64bit counter overflow: expected=0, actual=%h", cnt_value);
			fail_count = fail_count + 1;
		end
		@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_value = dut.cnt;
		if(cnt_value === 64'h0000_0000_0000_0001) begin
			$display("PASS counter continue after overflow");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL counter after overflow: expected=1, actual=%h", cnt_value);
			fail_count = fail_count + 1;
		end
		//subcase
		reset_dut;
		apb_write(ADDR_TDR1, 32'hFFFF_FFFF,4'b1111);
		apb_write(ADDR_TDR0, 32'hFFFF_FFFE,4'b1111);
		apb_write(ADDR_TDR0, 32'hFFFF_FFFF,4'b1111);
		apb_write(ADDR_TDR0, 32'hFFFF_FFFE,4'b1111);
		apb_read(ADDR_TDR0);
		check32("Counter toggle coverage", read_data, 32'hFFFF_FFFE);
	end
endtask

task ID12;
	reg[63:0] cnt_before;
	reg[63:0] cnt_after;
	reg[7:0] phase_before;
	reg[7:0] phase_after;
	integer remain;
	begin
		$display("-----ID12-----");
		//case1
		reset_dut;
		dbg_mode = 1'b0;
		apb_write(ADDR_TCR, 32'h0000_0001,4'b0001);
		apb_write(ADDR_THCSR, 32'h0000_0001,4'b0001);
		apb_read(ADDR_THCSR);
		check32("Halt rejected outside debug", read_data, 32'h0000_0001);
		cnt_before = dut.cnt;
		repeat(4)@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_after = dut.cnt;
		if(cnt_after == (cnt_before + 64'd4)) begin
			$display("PASS Counter continue when debug mode = 0");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Counter stopped when debug mode = 0: before=%0d, after=%0d",cnt_before,cnt_after);
			fail_count = fail_count + 1;
		end
		//case2
		reset_dut;
		dbg_mode = 1'b1;
		apb_write(ADDR_TCR, 32'h0000_0800,4'b0010);
		apb_write(ADDR_TCR, 32'h0000_0003,4'b0001);
		repeat(3)@(posedge sys_clk);
		@(negedge sys_clk);
		apb_write(ADDR_THCSR, 32'h0000_0001,4'b0001);
		apb_read(ADDR_THCSR);
		check32("THCSR while halted", read_data, 32'h0000_0003);
		cnt_before = dut.cnt;
		phase_before = dut.u_counter_control.div_cnt;
		repeat(6)@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_after = dut.cnt;
		phase_after = dut.u_counter_control.div_cnt;
		if(cnt_after == cnt_before) begin
			$display("PASS Counter holds during halt");
				pass_count = pass_count + 1;
		end else begin
			$display("FAIL Counter change during halt: before=%0d, after=%0d", cnt_before, cnt_after);
			fail_count = fail_count + 1;
		end
		if(phase_after == phase_before) begin
			$display("PASS Divider phase holds during halt: phase=%0d", phase_before);
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Divider phase change during halt: before=%0d, after=%0d", phase_before, phase_after);
			fail_count = fail_count + 1;
		end
		//resume
		apb_write(ADDR_THCSR, 32'h0000_0000,4'b0001);
		check1("halt_ack clear after resume", dut.halt_ack,1'b0);
		cnt_before = dut.cnt;
		phase_before = dut.u_counter_control.div_cnt;
		remain = 256 - phase_before;
		repeat(remain)@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_after = dut.cnt;
		if(cnt_after == (cnt_before + 64'd1)) begin
			$display("PASS Counter resume from saved divider phase");
			pass_count = pass_count + 1;
		end else begin
			$display("FAILL Resume phase: expected=%0d, actual=%0d, phase=%0d",cnt_before + 64'd1,cnt_after,phase_before);
			fail_count = fail_count + 1;
		end
		reset_dut;
		dbg_mode = 1'b1;
		apb_write(ADDR_TCR, 32'h0000_0001,4'b0001);
		apb_write(ADDR_THCSR, 32'h0000_0001,4'b0001);
		check1("cnt_en blocked by halt_active", dut.cnt_en, 1'b0);
	end
endtask

task ID13;
	integer timeout;
	reg[63:0] cnt_before;
	reg[63:0] cnt_after;
	begin
		$display("-----ID13-----");
		reset_dut;
		dbg_mode = 1'b0;
		apb_write(ADDR_TDR0, 32'h0000_0000,4'b1111);
		apb_write(ADDR_TDR1, 32'h0000_0001,4'b1111);
		apb_write(ADDR_TCMP0, 32'h0000_0010,4'b1111);
		apb_write(ADDR_TCMP1, 32'h0000_0001,4'b1111);
		apb_write(ADDR_TIER, 32'h0000_0001,4'b0001);
		apb_write(ADDR_TCR, 32'h0000_0001,4'b0001);
		//wait for interrupt
		timeout = 0;
		while ((tim_int !== 1'b1) && (timeout < 100)) begin
			@(negedge sys_clk);
			timeout = timeout + 1;
		end
		check1("Interrupt asserted on compare match", tim_int, 1'b1);
		//check interrupt pending
		apb_read(ADDR_TISR);
		check32("TISR int_st set", read_data, 32'h0000_0001);
		//
		cnt_before = dut.cnt;
		repeat(4)@(posedge sys_clk);
		@(negedge sys_clk);
		cnt_after = dut.cnt;
		if(cnt_after == (cnt_before + 64'd4)) begin
			$display("PASS Counter continue after interrupt");
			pass_count = pass_count + 1;
		end else begin
			$display("FAIL Counter after interrupt: expected=%h, actual=%h", cnt_before + 64'd4,cnt_after);
			fail_count = fail_count + 1;
		end
		check1("Interrupt remain asserted after compare", tim_int, 1'b1);
		apb_write(ADDR_TIER, 32'h0000_0000,4'b0001);
		check1("Interrupt mask when int_en=0", tim_int, 1'b0);
		apb_read(ADDR_TISR);
		check32("TISR remain set after masking", read_data, 32'h0000_0001);
		//
		apb_write(ADDR_TIER, 32'h0000_0001,4'b0001);
		check1("Interrupt return after re_enable", tim_int, 1'b1);
	end
endtask

task ID14;
	integer timeout;
	begin
		$display("-----ID14-----");
		dbg_mode = 1'b0;
		//case1
		reset_dut;
		apb_write(ADDR_TCMP0, 32'h0000_0008,4'b1111);
		apb_write(ADDR_TCMP1, 32'h0000_0000,4'b1111);
		apb_write(ADDR_TCR, 32'h0000_0001,4'b0001);
		timeout = 0;
		while((dut.u_interrupt.int_st !== 1'b1) && (timeout < 100)) begin
			@(negedge sys_clk);
			timeout = timeout + 1;
		end
		check1("TISR pending generated", dut.u_interrupt.int_st, 1'b1);
		repeat(2)@(posedge sys_clk);
		@(negedge sys_clk);
		//case2
		apb_write(ADDR_TISR, 32'h0000_0000,4'b0001);
		apb_read(ADDR_TISR);
		check32("TISR write 0 has no effect", read_data, 32'h0000_0001);
		//case3
		apb_write(ADDR_TISR, 32'h0000_0001,4'b0010);
		apb_read(ADDR_TISR);
		check32("TISR write 1 with wrong STRB ignored", read_data, 32'h0000_0001);
		//case4
		apb_write(ADDR_TISR, 32'h0000_0001,4'b0001);
		apb_read(ADDR_TISR);
		check32("TISR W1C clears pending", read_data, 32'h0000_0000);
		//case5
		reset_dut;
		apb_write(ADDR_TCMP0, 32'h0000_0000,4'b1111);
		apb_write(ADDR_TCMP1, 32'h0000_0000,4'b1111);
		repeat(2)@(posedge sys_clk);
		@(negedge sys_clk);
		check1("Pending before clear priority test", dut.u_interrupt.int_st,1'b1);
		apb_write(ADDR_TISR, 32'h0000_0001,4'b0001);
		check1("TISR clear has priority over set", dut.u_interrupt.int_st,1'b0);
	end
endtask

task report_result;
	begin
		$display("-----TEST SUMMARY-----");
		$display("PASS = %0d", pass_count);
		$display("FAIL = %0d", fail_count);
		if( fail_count == 0)
			$display("ALL TESTS PASSED");
	end
endtask

initial begin
	sys_clk = 1'b0;
	sys_rst_n = 1'b0;
	dbg_mode = 1'b0;
	pass_count = 0;
	fail_count = 0;
	read_data = 32'h0000_0000;
	last_slverr = 1'b0;
	last_wait_cycles = 0;
	bus_idle;
	ID1;
	ID2;
	ID3;
	ID4;
	ID5;
	ID6;
	ID7;
	ID8;
	ID9;
	ID10;
	ID11;
	ID12;
	ID13;
	ID14;
	report_result;
	#100;
	$finish;
end
endmodule
