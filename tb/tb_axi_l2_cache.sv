`timescale 1ns/1ps

module tb_axi_l2_cache;

    localparam integer ID_WIDTH = 4;

    reg Clk;
    reg Rst_n;
    reg Cache_en;
    reg Rd_alct_en;
    reg Wr_alct_en;
    reg Wr_mode;
    reg replace_mode;
    reg [21:0] adr_start;
    reg [21:0] adr_end;
    reg Cache_clr;
    reg [21:0] clr_adr_start;
    reg [21:0] clr_adr_end;
    reg Cache_flush;
    reg [21:0] flush_adr_start;
    reg [21:0] flush_adr_end;
    wire maint_busy;
    wire maint_done;
    wire maint_error;

    reg [31:0] s0_awaddr;
    reg [7:0] s0_awlen;
    reg [2:0] s0_awsize;
    reg [1:0] s0_awburst;
    reg s0_awvalid;
    wire s0_awready;
    reg [31:0] s0_wdata;
    reg [3:0] s0_wstrb;
    reg s0_wlast;
    reg s0_wvalid;
    wire s0_wready;
    wire [ID_WIDTH-1:0] s0_bid;
    wire [1:0] s0_bresp;
    wire s0_bvalid;
    reg s0_bready;
    reg [31:0] s0_araddr;
    reg [7:0] s0_arlen;
    reg [2:0] s0_arsize;
    reg [1:0] s0_arburst;
    reg s0_arvalid;
    wire s0_arready;
    wire [ID_WIDTH-1:0] s0_rid;
    wire [31:0] s0_rdata;
    wire [1:0] s0_rresp;
    wire s0_rlast;
    wire s0_rvalid;
    reg s0_rready;

    reg [31:0] s1_awaddr;
    reg [7:0] s1_awlen;
    reg [2:0] s1_awsize;
    reg [1:0] s1_awburst;
    reg s1_awvalid;
    wire s1_awready;
    reg [31:0] s1_wdata;
    reg [3:0] s1_wstrb;
    reg s1_wlast;
    reg s1_wvalid;
    wire s1_wready;
    wire [ID_WIDTH-1:0] s1_bid;
    wire [1:0] s1_bresp;
    wire s1_bvalid;
    reg s1_bready;
    reg [31:0] s1_araddr;
    reg [7:0] s1_arlen;
    reg [2:0] s1_arsize;
    reg [1:0] s1_arburst;
    reg s1_arvalid;
    wire s1_arready;
    wire [ID_WIDTH-1:0] s1_rid;
    wire [31:0] s1_rdata;
    wire [1:0] s1_rresp;
    wire s1_rlast;
    wire s1_rvalid;
    reg s1_rready;

    wire [ID_WIDTH-1:0] m_awid;
    wire [31:0] m_awaddr;
    wire [7:0] m_awlen;
    wire [2:0] m_awsize;
    wire [1:0] m_awburst;
    wire m_awvalid;
    wire m_awready;
    wire [31:0] m_wdata;
    wire [3:0] m_wstrb;
    wire m_wlast;
    wire m_wvalid;
    wire m_wready;
    wire [ID_WIDTH-1:0] m_bid;
    wire [1:0] m_bresp;
    wire m_bvalid;
    wire m_bready;
    wire [ID_WIDTH-1:0] m_arid;
    wire [31:0] m_araddr;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize;
    wire [1:0] m_arburst;
    wire m_arvalid;
    wire m_arready;
    wire [ID_WIDTH-1:0] m_rid;
    wire [31:0] m_rdata;
    wire [1:0] m_rresp;
    wire m_rlast;
    wire m_rvalid;
    wire m_rready;

    wire [31:0] stat_hit_count;
    wire [31:0] stat_miss_count;
    wire [31:0] stat_bypass_count;
    wire [31:0] stat_writeback_count;
    wire [31:0] read_burst_count;
    wire [31:0] write_burst_count;

    integer errors;
    integer cycle_count;
    integer before_count;
    integer after_count;
    reg [31:0] rd_data;
    reg [1:0] rd_resp;
    reg [1:0] wr_resp;
    reg [31:0] old_mem_word;

    always #5 Clk = ~Clk;
    always @(posedge Clk) cycle_count <= cycle_count + 1;

    axi_l2_cache #(.ID_WIDTH(ID_WIDTH)) dut (
        .Clk(Clk), .Rst_n(Rst_n),
        .Cache_en(Cache_en), .Rd_alct_en(Rd_alct_en),
        .Wr_alct_en(Wr_alct_en), .Wr_mode(Wr_mode),
        .replace_mode(replace_mode), .adr_start(adr_start), .adr_end(adr_end),
        .Cache_clr(Cache_clr), .clr_adr_start(clr_adr_start),
        .clr_adr_end(clr_adr_end), .Cache_flush(Cache_flush),
        .flush_adr_start(flush_adr_start), .flush_adr_end(flush_adr_end),
        .maint_busy(maint_busy), .maint_done(maint_done), .maint_error(maint_error),

        .AXI_mem_s0_awid(4'd0), .AXI_mem_s0_awaddr(s0_awaddr),
        .AXI_mem_s0_awlen(s0_awlen), .AXI_mem_s0_awsize(s0_awsize),
        .AXI_mem_s0_awburst(s0_awburst), .AXI_mem_s0_awlock(1'b0),
        .AXI_mem_s0_awcache(4'b0011), .AXI_mem_s0_awprot(3'b000),
        .AXI_mem_s0_awqos(4'b0000), .AXI_mem_s0_awvalid(s0_awvalid),
        .AXI_mem_s0_awready(s0_awready),
        .AXI_mem_s0_wdata(s0_wdata), .AXI_mem_s0_wstrb(s0_wstrb),
        .AXI_mem_s0_wlast(s0_wlast), .AXI_mem_s0_wvalid(s0_wvalid),
        .AXI_mem_s0_wready(s0_wready), .AXI_mem_s0_bid(s0_bid),
        .AXI_mem_s0_bresp(s0_bresp), .AXI_mem_s0_bvalid(s0_bvalid),
        .AXI_mem_s0_bready(s0_bready),
        .AXI_mem_s0_arid(4'd0), .AXI_mem_s0_araddr(s0_araddr),
        .AXI_mem_s0_arlen(s0_arlen), .AXI_mem_s0_arsize(s0_arsize),
        .AXI_mem_s0_arburst(s0_arburst), .AXI_mem_s0_arlock(1'b0),
        .AXI_mem_s0_arcache(4'b0011), .AXI_mem_s0_arprot(3'b000),
        .AXI_mem_s0_arqos(4'b0000), .AXI_mem_s0_arvalid(s0_arvalid),
        .AXI_mem_s0_arready(s0_arready), .AXI_mem_s0_rid(s0_rid),
        .AXI_mem_s0_rdata(s0_rdata), .AXI_mem_s0_rresp(s0_rresp),
        .AXI_mem_s0_rlast(s0_rlast), .AXI_mem_s0_rvalid(s0_rvalid),
        .AXI_mem_s0_rready(s0_rready),

        .AXI_mem_s1_awid(4'd1), .AXI_mem_s1_awaddr(s1_awaddr),
        .AXI_mem_s1_awlen(s1_awlen), .AXI_mem_s1_awsize(s1_awsize),
        .AXI_mem_s1_awburst(s1_awburst), .AXI_mem_s1_awlock(1'b0),
        .AXI_mem_s1_awcache(4'b0011), .AXI_mem_s1_awprot(3'b000),
        .AXI_mem_s1_awqos(4'b0000), .AXI_mem_s1_awvalid(s1_awvalid),
        .AXI_mem_s1_awready(s1_awready),
        .AXI_mem_s1_wdata(s1_wdata), .AXI_mem_s1_wstrb(s1_wstrb),
        .AXI_mem_s1_wlast(s1_wlast), .AXI_mem_s1_wvalid(s1_wvalid),
        .AXI_mem_s1_wready(s1_wready), .AXI_mem_s1_bid(s1_bid),
        .AXI_mem_s1_bresp(s1_bresp), .AXI_mem_s1_bvalid(s1_bvalid),
        .AXI_mem_s1_bready(s1_bready),
        .AXI_mem_s1_arid(4'd1), .AXI_mem_s1_araddr(s1_araddr),
        .AXI_mem_s1_arlen(s1_arlen), .AXI_mem_s1_arsize(s1_arsize),
        .AXI_mem_s1_arburst(s1_arburst), .AXI_mem_s1_arlock(1'b0),
        .AXI_mem_s1_arcache(4'b0011), .AXI_mem_s1_arprot(3'b000),
        .AXI_mem_s1_arqos(4'b0000), .AXI_mem_s1_arvalid(s1_arvalid),
        .AXI_mem_s1_arready(s1_arready), .AXI_mem_s1_rid(s1_rid),
        .AXI_mem_s1_rdata(s1_rdata), .AXI_mem_s1_rresp(s1_rresp),
        .AXI_mem_s1_rlast(s1_rlast), .AXI_mem_s1_rvalid(s1_rvalid),
        .AXI_mem_s1_rready(s1_rready),

        .AXI_mem_m_awid(m_awid), .AXI_mem_m_awaddr(m_awaddr),
        .AXI_mem_m_awlen(m_awlen), .AXI_mem_m_awsize(m_awsize),
        .AXI_mem_m_awburst(m_awburst), .AXI_mem_m_awvalid(m_awvalid),
        .AXI_mem_m_awready(m_awready), .AXI_mem_m_wdata(m_wdata),
        .AXI_mem_m_wstrb(m_wstrb), .AXI_mem_m_wlast(m_wlast),
        .AXI_mem_m_wvalid(m_wvalid), .AXI_mem_m_wready(m_wready),
        .AXI_mem_m_bid(m_bid), .AXI_mem_m_bresp(m_bresp),
        .AXI_mem_m_bvalid(m_bvalid), .AXI_mem_m_bready(m_bready),
        .AXI_mem_m_arid(m_arid), .AXI_mem_m_araddr(m_araddr),
        .AXI_mem_m_arlen(m_arlen), .AXI_mem_m_arsize(m_arsize),
        .AXI_mem_m_arburst(m_arburst), .AXI_mem_m_arvalid(m_arvalid),
        .AXI_mem_m_arready(m_arready), .AXI_mem_m_rid(m_rid),
        .AXI_mem_m_rdata(m_rdata), .AXI_mem_m_rresp(m_rresp),
        .AXI_mem_m_rlast(m_rlast), .AXI_mem_m_rvalid(m_rvalid),
        .AXI_mem_m_rready(m_rready),
        .stat_hit_count(stat_hit_count), .stat_miss_count(stat_miss_count),
        .stat_bypass_count(stat_bypass_count),
        .stat_writeback_count(stat_writeback_count)
    );

    axi_memory_model #(.ID_WIDTH(ID_WIDTH), .MEM_BYTES(256*1024)) u_mem (
        .clk(Clk), .rst_n(Rst_n),
        .s_axi_awid(m_awid), .s_axi_awaddr(m_awaddr), .s_axi_awlen(m_awlen),
        .s_axi_awsize(m_awsize), .s_axi_awburst(m_awburst),
        .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_wdata(m_wdata), .s_axi_wstrb(m_wstrb), .s_axi_wlast(m_wlast),
        .s_axi_wvalid(m_wvalid), .s_axi_wready(m_wready),
        .s_axi_bid(m_bid), .s_axi_bresp(m_bresp), .s_axi_bvalid(m_bvalid),
        .s_axi_bready(m_bready),
        .s_axi_arid(m_arid), .s_axi_araddr(m_araddr), .s_axi_arlen(m_arlen),
        .s_axi_arsize(m_arsize), .s_axi_arburst(m_arburst),
        .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_rid(m_rid), .s_axi_rdata(m_rdata), .s_axi_rresp(m_rresp),
        .s_axi_rlast(m_rlast), .s_axi_rvalid(m_rvalid), .s_axi_rready(m_rready),
        .read_burst_count(read_burst_count), .write_burst_count(write_burst_count)
    );

    task automatic check;
        input condition;
        input [8*120-1:0] message;
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("[FAIL] %0s", message);
            end else begin
                $display("[PASS] %0s", message);
            end
        end
    endtask

    task automatic wait_maintenance;
        integer guard;
        begin
            guard = 0;
            while (!maint_busy && guard < 50) begin
                @(negedge Clk);
                guard = guard + 1;
            end
            guard = 0;
            while (maint_busy && guard < 3000) begin
                @(negedge Clk);
                guard = guard + 1;
            end
            if (guard >= 3000)
                $fatal(1, "Maintenance timeout");
        end
    endtask

    task automatic pulse_clear;
        input [21:0] first_kb;
        input [21:0] last_kb;
        begin
            @(negedge Clk);
            clr_adr_start = first_kb;
            clr_adr_end = last_kb;
            Cache_clr = 1'b1;
            @(negedge Clk);
            Cache_clr = 1'b0;
            wait_maintenance();
        end
    endtask

    task automatic pulse_flush;
        input [21:0] first_kb;
        input [21:0] last_kb;
        begin
            @(negedge Clk);
            flush_adr_start = first_kb;
            flush_adr_end = last_kb;
            Cache_flush = 1'b1;
            @(negedge Clk);
            Cache_flush = 1'b0;
            wait_maintenance();
        end
    endtask

    task automatic s0_read_word;
        input [31:0] address;
        output [31:0] data;
        output [1:0] response;
        integer guard;
        begin
            @(negedge Clk);
            s0_araddr = address;
            s0_arlen = 8'd0;
            s0_arsize = 3'd2;
            s0_arburst = 2'b01;
            s0_arvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!s0_arready && guard < 2000) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 2000) $fatal(1, "s0 AR timeout");
            @(negedge Clk);
            s0_arvalid = 1'b0;
            guard = 0;
            while (!s0_rvalid && guard < 4000) begin
                @(negedge Clk);
                guard = guard + 1;
            end
            if (guard >= 4000) $fatal(1, "s0 R timeout at %h", address);
            data = s0_rdata;
            response = s0_rresp;
            @(negedge Clk);
        end
    endtask

    task automatic s1_read_word;
        input [31:0] address;
        output [31:0] data;
        output [1:0] response;
        integer guard;
        begin
            @(negedge Clk);
            s1_araddr = address;
            s1_arlen = 8'd0;
            s1_arsize = 3'd2;
            s1_arburst = 2'b01;
            s1_arvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!s1_arready && guard < 2000) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 2000) $fatal(1, "s1 AR timeout");
            @(negedge Clk);
            s1_arvalid = 1'b0;
            guard = 0;
            while (!s1_rvalid && guard < 4000) begin
                @(negedge Clk);
                guard = guard + 1;
            end
            if (guard >= 4000) $fatal(1, "s1 R timeout at %h", address);
            data = s1_rdata;
            response = s1_rresp;
            @(negedge Clk);
        end
    endtask

    task automatic s0_write_word;
        input [31:0] address;
        input [31:0] data;
        input [3:0] strobes;
        output [1:0] response;
        integer guard;
        begin
            @(negedge Clk);
            s0_awaddr = address;
            s0_awlen = 8'd0;
            s0_awsize = 3'd2;
            s0_awburst = 2'b01;
            s0_awvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!s0_awready && guard < 2000) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 2000) $fatal(1, "s0 AW timeout");
            @(negedge Clk);
            s0_awvalid = 1'b0;
            s0_wdata = data;
            s0_wstrb = strobes;
            s0_wlast = 1'b1;
            s0_wvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!s0_wready && guard < 4000) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 4000) begin
                $display("DBG slave_state=%0d req_valid=%b req_ready=%b hit=%b fast=%b cacheable=%b rsp_valid=%b op_state=%0d",
                         dut.u_slave0.state, dut.p0_req_valid, dut.p0_req_ready,
                         dut.u_cache_core.p0_hit, dut.u_cache_core.p0_fast,
                         dut.u_cache_core.p0_cacheable, dut.p0_rsp_valid,
                         dut.u_cache_core.op_state);
                $fatal(1, "s0 W timeout");
            end
            @(negedge Clk);
            s0_wvalid = 1'b0;
            s0_wlast = 1'b0;
            guard = 0;
            while (!s0_bvalid && guard < 4000) begin
                @(negedge Clk);
                guard = guard + 1;
            end
            if (guard >= 4000) $fatal(1, "s0 B timeout at %h", address);
            response = s0_bresp;
            @(negedge Clk);
        end
    endtask

    task automatic dual_hit_read;
        input [31:0] address0;
        input [31:0] address1;
        output [31:0] data0;
        output [31:0] data1;
        integer guard;
        integer cycle0;
        integer cycle1;
        begin
            s0_rready = 1'b0;
            s1_rready = 1'b0;
            @(negedge Clk);
            s0_araddr = address0;
            s1_araddr = address1;
            s0_arlen = 8'd0;
            s1_arlen = 8'd0;
            s0_arsize = 3'd2;
            s1_arsize = 3'd2;
            s0_arburst = 2'b01;
            s1_arburst = 2'b01;
            s0_arvalid = 1'b1;
            s1_arvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!(s0_arready && s1_arready) && guard < 100) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 100) $fatal(1, "dual AR timeout");
            @(negedge Clk);
            s0_arvalid = 1'b0;
            s1_arvalid = 1'b0;
            cycle0 = -1;
            cycle1 = -1;
            guard = 0;
            while (((cycle0 < 0) || (cycle1 < 0)) && guard < 100) begin
                if ((cycle0 < 0) && s0_rvalid) cycle0 = cycle_count;
                if ((cycle1 < 0) && s1_rvalid) cycle1 = cycle_count;
                @(negedge Clk);
                guard = guard + 1;
            end
            if (guard >= 100) $fatal(1, "dual R timeout");
            data0 = s0_rdata;
            data1 = s1_rdata;
            check(cycle0 == cycle1, "two slave hit responses complete in the same cycle");
            s0_rready = 1'b1;
            s1_rready = 1'b1;
            @(negedge Clk);
        end
    endtask

    task automatic s0_write_burst_pattern;
        input [31:0] address;
        input integer beats;
        integer guard;
        integer beat;
        begin
            @(negedge Clk);
            s0_awaddr = address;
            s0_awlen = beats - 1;
            s0_awsize = 3'd2;
            s0_awburst = 2'b01;
            s0_awvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!s0_awready && guard < 200) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 200) $fatal(1, "write burst AW timeout");
            @(negedge Clk);
            s0_awvalid = 1'b0;

            for (beat = 0; beat < beats; beat = beat + 1) begin
                s0_wdata = 32'hc000_0000 + beat;
                s0_wstrb = 4'hf;
                s0_wlast = (beat == beats-1);
                s0_wvalid = 1'b1;
                guard = 0;
                @(posedge Clk);
                while (!s0_wready && guard < 4000) begin
                    @(posedge Clk);
                    guard = guard + 1;
                end
                if (guard >= 4000) $fatal(1, "write burst W timeout beat %0d", beat);
                @(negedge Clk);
                s0_wvalid = 1'b0;
                s0_wlast = 1'b0;
            end

            guard = 0;
            while (!s0_bvalid && guard < 4000) begin
                @(negedge Clk);
                guard = guard + 1;
            end
            if (guard >= 4000) $fatal(1, "write burst B timeout");
            check(s0_bresp == 2'b00, "AXI write burst returns OKAY");
            @(negedge Clk);
        end
    endtask

    task automatic s0_read_burst_check;
        input [31:0] address;
        input integer beats;
        integer guard;
        integer beat;
        reg [31:0] expected;
        begin
            @(negedge Clk);
            s0_araddr = address;
            s0_arlen = beats - 1;
            s0_arsize = 3'd2;
            s0_arburst = 2'b01;
            s0_arvalid = 1'b1;
            guard = 0;
            @(posedge Clk);
            while (!s0_arready && guard < 100) begin
                @(posedge Clk);
                guard = guard + 1;
            end
            if (guard >= 100) $fatal(1, "burst AR timeout");
            @(negedge Clk);
            s0_arvalid = 1'b0;
            for (beat = 0; beat < beats; beat = beat + 1) begin
                guard = 0;
                while (!s0_rvalid && guard < 4000) begin
                    @(negedge Clk);
                    guard = guard + 1;
                end
                if (guard >= 4000) $fatal(1, "burst R timeout beat %0d", beat);
                expected = u_mem.get_word(address + beat*4);
                check((s0_rresp == 2'b00) && (s0_rdata == expected),
                      "AXI read burst beat data matches memory");
                check(s0_rlast == (beat == beats-1), "AXI RLAST position is correct");
                @(negedge Clk);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/tb_axi_l2_cache.vcd");
        $dumpvars(1, tb_axi_l2_cache);

        Clk = 1'b0;
        Rst_n = 1'b0;
        Cache_en = 1'b1;
        Rd_alct_en = 1'b1;
        Wr_alct_en = 1'b1;
        Wr_mode = 1'b1;
        replace_mode = 1'b1;
        adr_start = 22'd0;
        adr_end = 22'd255;
        Cache_clr = 1'b0;
        clr_adr_start = 22'd0;
        clr_adr_end = 22'd255;
        Cache_flush = 1'b0;
        flush_adr_start = 22'd0;
        flush_adr_end = 22'd255;
        s0_awaddr = 32'd0; s0_awlen = 8'd0; s0_awsize = 3'd2;
        s0_awburst = 2'b01; s0_awvalid = 1'b0;
        s0_wdata = 32'd0; s0_wstrb = 4'hf; s0_wlast = 1'b0; s0_wvalid = 1'b0;
        s0_bready = 1'b1;
        s0_araddr = 32'd0; s0_arlen = 8'd0; s0_arsize = 3'd2;
        s0_arburst = 2'b01; s0_arvalid = 1'b0; s0_rready = 1'b1;
        s1_awaddr = 32'd0; s1_awlen = 8'd0; s1_awsize = 3'd2;
        s1_awburst = 2'b01; s1_awvalid = 1'b0;
        s1_wdata = 32'd0; s1_wstrb = 4'hf; s1_wlast = 1'b0; s1_wvalid = 1'b0;
        s1_bready = 1'b1;
        s1_araddr = 32'd0; s1_arlen = 8'd0; s1_arsize = 3'd2;
        s1_arburst = 2'b01; s1_arvalid = 1'b0; s1_rready = 1'b1;
        errors = 0;
        cycle_count = 0;

        repeat (8) @(negedge Clk);
        Rst_n = 1'b1;
        $display("[INFO] reset released, waiting for directory initialization");
        wait_maintenance();
        check(!maint_busy, "reset directory initialization completes");

        before_count = read_burst_count;
        s0_read_word(32'h0000_0100, rd_data, rd_resp);
        check((rd_resp == 2'b00) && (rd_data == u_mem.get_word(32'h100)),
              "read-allocate miss returns backing memory data");
        check(read_burst_count == before_count + 1, "read miss issues one line refill burst");
        before_count = read_burst_count;
        s0_read_word(32'h0000_0100, rd_data, rd_resp);
        check(read_burst_count == before_count, "second read is a cache hit");

        old_mem_word = u_mem.get_word(32'h104);
        s0_write_word(32'h0000_0104, 32'hdead_beef, 4'hf, wr_resp);
        check(wr_resp == 2'b00, "write-back hit completes with OKAY");
        check(u_mem.get_word(32'h104) == old_mem_word,
              "write-back hit does not update memory before flush");
        s0_read_word(32'h0000_0104, rd_data, rd_resp);
        check(rd_data == 32'hdead_beef, "write-back data is visible through cache");
        pulse_flush(22'd0, 22'd255);
        check(!maint_error, "flush finishes without AXI error");
        check(u_mem.get_word(32'h104) == 32'hdead_beef,
              "flush writes dirty line back to memory");

        Wr_mode = 1'b0;
        s0_write_word(32'h0000_0220, 32'h1234_5678, 4'hf, wr_resp);
        check((wr_resp == 2'b00) && (u_mem.get_word(32'h220) == 32'h1234_5678),
              "write-through allocation updates cache and memory");
        s0_write_word(32'h0000_0220, 32'habcd_0000, 4'b1100, wr_resp);
        check(u_mem.get_word(32'h220) == 32'habcd_5678,
              "write-through honors byte write strobes");

        Wr_mode = 1'b1;
        old_mem_word = u_mem.get_word(32'h340);
        s0_write_word(32'h0000_0340, 32'ha5a5_5a5a, 4'hf, wr_resp);
        pulse_clear(22'd0, 22'd255);
        check(u_mem.get_word(32'h340) == old_mem_word,
              "clear invalidates dirty data without writeback");
        s0_read_word(32'h0000_0340, rd_data, rd_resp);
        check(rd_data == old_mem_word, "read after clear refills original memory data");

        pulse_clear(22'd0, 22'd255);
        Rd_alct_en = 1'b0;
        before_count = read_burst_count;
        s0_read_word(32'h0000_0440, rd_data, rd_resp);
        s0_read_word(32'h0000_0440, rd_data, rd_resp);
        check(read_burst_count == before_count + 2,
              "read no-allocate performs a memory access on every miss");
        Rd_alct_en = 1'b1;

        Wr_alct_en = 1'b0;
        s0_write_word(32'h0000_0540, 32'hface_cafe, 4'hf, wr_resp);
        check(u_mem.get_word(32'h540) == 32'hface_cafe,
              "write no-allocate forwards data directly to memory");
        Wr_alct_en = 1'b1;

        Cache_en = 1'b0;
        before_count = read_burst_count;
        s1_read_word(32'h0000_0640, rd_data, rd_resp);
        s1_read_word(32'h0000_0640, rd_data, rd_resp);
        check(read_burst_count == before_count + 2, "cache disable bypasses both reads");
        Cache_en = 1'b1;

        pulse_clear(22'd0, 22'd255);
        replace_mode = 1'b1;
        s0_read_word(32'h0000_0000, rd_data, rd_resp);
        s0_read_word(32'h0000_2000, rd_data, rd_resp);
        s0_read_word(32'h0000_4000, rd_data, rd_resp);
        s0_read_word(32'h0000_6000, rd_data, rd_resp);
        s0_read_word(32'h0000_0000, rd_data, rd_resp);
        s0_read_word(32'h0000_8000, rd_data, rd_resp);
        before_count = read_burst_count;
        s0_read_word(32'h0000_0000, rd_data, rd_resp);
        check(read_burst_count == before_count, "LRU keeps the recently touched way");
        s0_read_word(32'h0000_2000, rd_data, rd_resp);
        check(read_burst_count == before_count + 1, "LRU evicts the least recently used way");

        pulse_clear(22'd0, 22'd255);
        replace_mode = 1'b0;
        s0_read_word(32'h0000_0000, rd_data, rd_resp);
        s0_read_word(32'h0000_2000, rd_data, rd_resp);
        s0_read_word(32'h0000_4000, rd_data, rd_resp);
        s0_read_word(32'h0000_6000, rd_data, rd_resp);
        repeat (3) s0_read_word(32'h0000_0000, rd_data, rd_resp);
        repeat (2) s0_read_word(32'h0000_2000, rd_data, rd_resp);
        repeat (1) s0_read_word(32'h0000_4000, rd_data, rd_resp);
        s0_read_word(32'h0000_8000, rd_data, rd_resp);
        before_count = read_burst_count;
        s0_read_word(32'h0000_0000, rd_data, rd_resp);
        check(read_burst_count == before_count, "LFU keeps the most frequently used way");
        s0_read_word(32'h0000_6000, rd_data, rd_resp);
        check(read_burst_count == before_count + 1, "LFU evicts the least frequently used way");

        pulse_clear(22'd0, 22'd255);
        replace_mode = 1'b1;
        s0_read_word(32'h0000_1200, rd_data, rd_resp);
        s1_read_word(32'h0000_12a0, rd_data, rd_resp);
        dual_hit_read(32'h0000_1200, 32'h0000_12a0, rd_data, old_mem_word);
        check((rd_data == u_mem.get_word(32'h1200)) &&
              (old_mem_word == u_mem.get_word(32'h12a0)),
              "two slave ports return correct data concurrently");

        pulse_clear(22'd0, 22'd255);
        s0_read_word(32'h0000_1400, rd_data, rd_resp);
        s1_read_word(32'h0000_3400, rd_data, rd_resp);
        dual_hit_read(32'h0000_1400, 32'h0000_3400, rd_data, old_mem_word);
        check((rd_data == u_mem.get_word(32'h1400)) &&
              (old_mem_word == u_mem.get_word(32'h3400)),
              "two slave ports concurrently access different lines in the same set");

        pulse_clear(22'd0, 22'd255);
        Wr_mode = 1'b1;
        s0_write_burst_pattern(32'h0001_5ff8, 4);
        s0_read_word(32'h0001_5ff8, rd_data, rd_resp);
        check(rd_data == 32'hc000_0000, "write burst first beat is cached");
        s0_read_word(32'h0001_6004, rd_data, rd_resp);
        check(rd_data == 32'hc000_0003, "write burst crosses a cache-line boundary");

        pulse_clear(22'd0, 22'd255);
        s0_read_burst_check(32'h0001_7ff0, 8);

        $display("STAT hit=%0d miss=%0d bypass=%0d writeback=%0d",
                 stat_hit_count, stat_miss_count,
                 stat_bypass_count, stat_writeback_count);
        if (errors == 0)
            $display("ALL_TESTS_PASS");
        else
            $display("TESTS_FAILED count=%0d", errors);
        #20;
        $finish;
    end

endmodule
