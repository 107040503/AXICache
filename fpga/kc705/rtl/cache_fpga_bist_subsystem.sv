`timescale 1ns/1ps

module cache_fpga_bist_subsystem (
    input  wire         clk,
    input  wire         rst_n,
    output wire         bist_done,
    output wire         bist_pass,
    output wire         bist_fail,
    output wire [7:0]   bist_state,
    output wire [7:0]   error_code,
    output wire         maint_busy,
    output wire [31:0]  stat_hit_count,
    output wire [31:0]  stat_miss_count,
    output wire [31:0]  stat_writeback_count,
    output wire [31:0]  memory_read_bursts,
    output wire [31:0]  memory_write_bursts
);

    localparam integer ID_WIDTH = 4;

    wire cache_en;
    wire rd_alct_en;
    wire wr_alct_en;
    wire wr_mode;
    wire replace_mode;
    wire [21:0] adr_start;
    wire [21:0] adr_end;
    wire cache_clr;
    wire [21:0] clr_adr_start;
    wire [21:0] clr_adr_end;
    wire cache_flush;
    wire [21:0] flush_adr_start;
    wire [21:0] flush_adr_end;
    wire maint_done;
    wire maint_error;
    wire [31:0] stat_bypass_count;

    wire p0_cmd_valid;
    wire p0_cmd_ready;
    wire p0_cmd_write;
    wire [31:0] p0_cmd_addr;
    wire [31:0] p0_cmd_wdata;
    wire [3:0] p0_cmd_wstrb;
    wire p0_done;
    wire [31:0] p0_read_data;
    wire p0_error;

    wire p1_cmd_valid;
    wire p1_cmd_ready;
    wire p1_cmd_write;
    wire [31:0] p1_cmd_addr;
    wire [31:0] p1_cmd_wdata;
    wire [3:0] p1_cmd_wstrb;
    wire p1_done;
    wire [31:0] p1_read_data;
    wire p1_error;

    wire [31:0] s0_awaddr;
    wire [7:0] s0_awlen;
    wire [2:0] s0_awsize;
    wire [1:0] s0_awburst;
    wire s0_awvalid;
    wire s0_awready;
    wire [31:0] s0_wdata;
    wire [3:0] s0_wstrb;
    wire s0_wlast;
    wire s0_wvalid;
    wire s0_wready;
    wire [ID_WIDTH-1:0] s0_bid;
    wire [1:0] s0_bresp;
    wire s0_bvalid;
    wire s0_bready;
    wire [31:0] s0_araddr;
    wire [7:0] s0_arlen;
    wire [2:0] s0_arsize;
    wire [1:0] s0_arburst;
    wire s0_arvalid;
    wire s0_arready;
    wire [ID_WIDTH-1:0] s0_rid;
    wire [31:0] s0_rdata;
    wire [1:0] s0_rresp;
    wire s0_rlast;
    wire s0_rvalid;
    wire s0_rready;

    wire [31:0] s1_awaddr;
    wire [7:0] s1_awlen;
    wire [2:0] s1_awsize;
    wire [1:0] s1_awburst;
    wire s1_awvalid;
    wire s1_awready;
    wire [31:0] s1_wdata;
    wire [3:0] s1_wstrb;
    wire s1_wlast;
    wire s1_wvalid;
    wire s1_wready;
    wire [ID_WIDTH-1:0] s1_bid;
    wire [1:0] s1_bresp;
    wire s1_bvalid;
    wire s1_bready;
    wire [31:0] s1_araddr;
    wire [7:0] s1_arlen;
    wire [2:0] s1_arsize;
    wire [1:0] s1_arburst;
    wire s1_arvalid;
    wire s1_arready;
    wire [ID_WIDTH-1:0] s1_rid;
    wire [31:0] s1_rdata;
    wire [1:0] s1_rresp;
    wire s1_rlast;
    wire s1_rvalid;
    wire s1_rready;

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

    cache_bist_controller u_bist_controller (
        .clk(clk), .rst_n(rst_n),
        .p0_cmd_valid(p0_cmd_valid), .p0_cmd_ready(p0_cmd_ready),
        .p0_cmd_write(p0_cmd_write), .p0_cmd_addr(p0_cmd_addr),
        .p0_cmd_wdata(p0_cmd_wdata), .p0_cmd_wstrb(p0_cmd_wstrb),
        .p0_done(p0_done), .p0_read_data(p0_read_data), .p0_error(p0_error),
        .p1_cmd_valid(p1_cmd_valid), .p1_cmd_ready(p1_cmd_ready),
        .p1_cmd_write(p1_cmd_write), .p1_cmd_addr(p1_cmd_addr),
        .p1_cmd_wdata(p1_cmd_wdata), .p1_cmd_wstrb(p1_cmd_wstrb),
        .p1_done(p1_done), .p1_read_data(p1_read_data), .p1_error(p1_error),
        .maint_busy(maint_busy), .maint_done(maint_done), .maint_error(maint_error),
        .stat_hit_count(stat_hit_count), .stat_miss_count(stat_miss_count),
        .stat_writeback_count(stat_writeback_count),
        .cache_en(cache_en), .rd_alct_en(rd_alct_en), .wr_alct_en(wr_alct_en),
        .wr_mode(wr_mode), .replace_mode(replace_mode),
        .adr_start(adr_start), .adr_end(adr_end),
        .cache_clr(cache_clr), .clr_adr_start(clr_adr_start),
        .clr_adr_end(clr_adr_end), .cache_flush(cache_flush),
        .flush_adr_start(flush_adr_start), .flush_adr_end(flush_adr_end),
        .bist_done(bist_done), .bist_pass(bist_pass), .bist_fail(bist_fail),
        .bist_state(bist_state), .error_code(error_code)
    );

    axi_bist_master u_bist_master0 (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(p0_cmd_valid), .cmd_ready(p0_cmd_ready),
        .cmd_write(p0_cmd_write), .cmd_addr(p0_cmd_addr),
        .cmd_wdata(p0_cmd_wdata), .cmd_wstrb(p0_cmd_wstrb),
        .done(p0_done), .read_data(p0_read_data), .error(p0_error),
        .m_axi_awaddr(s0_awaddr), .m_axi_awlen(s0_awlen),
        .m_axi_awsize(s0_awsize), .m_axi_awburst(s0_awburst),
        .m_axi_awvalid(s0_awvalid), .m_axi_awready(s0_awready),
        .m_axi_wdata(s0_wdata), .m_axi_wstrb(s0_wstrb),
        .m_axi_wlast(s0_wlast), .m_axi_wvalid(s0_wvalid),
        .m_axi_wready(s0_wready), .m_axi_bresp(s0_bresp),
        .m_axi_bvalid(s0_bvalid), .m_axi_bready(s0_bready),
        .m_axi_araddr(s0_araddr), .m_axi_arlen(s0_arlen),
        .m_axi_arsize(s0_arsize), .m_axi_arburst(s0_arburst),
        .m_axi_arvalid(s0_arvalid), .m_axi_arready(s0_arready),
        .m_axi_rdata(s0_rdata), .m_axi_rresp(s0_rresp),
        .m_axi_rlast(s0_rlast), .m_axi_rvalid(s0_rvalid),
        .m_axi_rready(s0_rready)
    );

    axi_bist_master u_bist_master1 (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(p1_cmd_valid), .cmd_ready(p1_cmd_ready),
        .cmd_write(p1_cmd_write), .cmd_addr(p1_cmd_addr),
        .cmd_wdata(p1_cmd_wdata), .cmd_wstrb(p1_cmd_wstrb),
        .done(p1_done), .read_data(p1_read_data), .error(p1_error),
        .m_axi_awaddr(s1_awaddr), .m_axi_awlen(s1_awlen),
        .m_axi_awsize(s1_awsize), .m_axi_awburst(s1_awburst),
        .m_axi_awvalid(s1_awvalid), .m_axi_awready(s1_awready),
        .m_axi_wdata(s1_wdata), .m_axi_wstrb(s1_wstrb),
        .m_axi_wlast(s1_wlast), .m_axi_wvalid(s1_wvalid),
        .m_axi_wready(s1_wready), .m_axi_bresp(s1_bresp),
        .m_axi_bvalid(s1_bvalid), .m_axi_bready(s1_bready),
        .m_axi_araddr(s1_araddr), .m_axi_arlen(s1_arlen),
        .m_axi_arsize(s1_arsize), .m_axi_arburst(s1_arburst),
        .m_axi_arvalid(s1_arvalid), .m_axi_arready(s1_arready),
        .m_axi_rdata(s1_rdata), .m_axi_rresp(s1_rresp),
        .m_axi_rlast(s1_rlast), .m_axi_rvalid(s1_rvalid),
        .m_axi_rready(s1_rready)
    );

    axi_l2_cache #(.ID_WIDTH(ID_WIDTH)) u_cache (
        .Clk(clk), .Rst_n(rst_n),
        .Cache_en(cache_en), .Rd_alct_en(rd_alct_en),
        .Wr_alct_en(wr_alct_en), .Wr_mode(wr_mode),
        .replace_mode(replace_mode), .adr_start(adr_start), .adr_end(adr_end),
        .Cache_clr(cache_clr), .clr_adr_start(clr_adr_start),
        .clr_adr_end(clr_adr_end), .Cache_flush(cache_flush),
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

    axi_bram_memory #(.ID_WIDTH(ID_WIDTH), .MEM_WORDS(16384)) u_memory (
        .clk(clk), .rst_n(rst_n),
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
        .read_burst_count(memory_read_bursts),
        .write_burst_count(memory_write_bursts)
    );

endmodule

