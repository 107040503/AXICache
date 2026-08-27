`timescale 1ns/1ps

module axi_l2_cache #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer ID_WIDTH   = 4
) (
    input  wire                     Clk,
    input  wire                     Rst_n,

    input  wire                     Cache_en,
    input  wire                     Rd_alct_en,
    input  wire                     Wr_alct_en,
    input  wire                     Wr_mode,
    input  wire                     replace_mode,
    input  wire [21:0]              adr_start,
    input  wire [21:0]              adr_end,
    input  wire                     Cache_clr,
    input  wire [21:0]              clr_adr_start,
    input  wire [21:0]              clr_adr_end,
    input  wire                     Cache_flush,
    input  wire [21:0]              flush_adr_start,
    input  wire [21:0]              flush_adr_end,
    output wire                     maint_busy,
    output wire                     maint_done,
    output wire                     maint_error,

    input  wire [ID_WIDTH-1:0]      AXI_mem_s0_awid,
    input  wire [ADDR_WIDTH-1:0]    AXI_mem_s0_awaddr,
    input  wire [7:0]               AXI_mem_s0_awlen,
    input  wire [2:0]               AXI_mem_s0_awsize,
    input  wire [1:0]               AXI_mem_s0_awburst,
    input  wire                     AXI_mem_s0_awlock,
    input  wire [3:0]               AXI_mem_s0_awcache,
    input  wire [2:0]               AXI_mem_s0_awprot,
    input  wire [3:0]               AXI_mem_s0_awqos,
    input  wire                     AXI_mem_s0_awvalid,
    output wire                     AXI_mem_s0_awready,
    input  wire [DATA_WIDTH-1:0]    AXI_mem_s0_wdata,
    input  wire [DATA_WIDTH/8-1:0]  AXI_mem_s0_wstrb,
    input  wire                     AXI_mem_s0_wlast,
    input  wire                     AXI_mem_s0_wvalid,
    output wire                     AXI_mem_s0_wready,
    output wire [ID_WIDTH-1:0]      AXI_mem_s0_bid,
    output wire [1:0]               AXI_mem_s0_bresp,
    output wire                     AXI_mem_s0_bvalid,
    input  wire                     AXI_mem_s0_bready,
    input  wire [ID_WIDTH-1:0]      AXI_mem_s0_arid,
    input  wire [ADDR_WIDTH-1:0]    AXI_mem_s0_araddr,
    input  wire [7:0]               AXI_mem_s0_arlen,
    input  wire [2:0]               AXI_mem_s0_arsize,
    input  wire [1:0]               AXI_mem_s0_arburst,
    input  wire                     AXI_mem_s0_arlock,
    input  wire [3:0]               AXI_mem_s0_arcache,
    input  wire [2:0]               AXI_mem_s0_arprot,
    input  wire [3:0]               AXI_mem_s0_arqos,
    input  wire                     AXI_mem_s0_arvalid,
    output wire                     AXI_mem_s0_arready,
    output wire [ID_WIDTH-1:0]      AXI_mem_s0_rid,
    output wire [DATA_WIDTH-1:0]    AXI_mem_s0_rdata,
    output wire [1:0]               AXI_mem_s0_rresp,
    output wire                     AXI_mem_s0_rlast,
    output wire                     AXI_mem_s0_rvalid,
    input  wire                     AXI_mem_s0_rready,

    input  wire [ID_WIDTH-1:0]      AXI_mem_s1_awid,
    input  wire [ADDR_WIDTH-1:0]    AXI_mem_s1_awaddr,
    input  wire [7:0]               AXI_mem_s1_awlen,
    input  wire [2:0]               AXI_mem_s1_awsize,
    input  wire [1:0]               AXI_mem_s1_awburst,
    input  wire                     AXI_mem_s1_awlock,
    input  wire [3:0]               AXI_mem_s1_awcache,
    input  wire [2:0]               AXI_mem_s1_awprot,
    input  wire [3:0]               AXI_mem_s1_awqos,
    input  wire                     AXI_mem_s1_awvalid,
    output wire                     AXI_mem_s1_awready,
    input  wire [DATA_WIDTH-1:0]    AXI_mem_s1_wdata,
    input  wire [DATA_WIDTH/8-1:0]  AXI_mem_s1_wstrb,
    input  wire                     AXI_mem_s1_wlast,
    input  wire                     AXI_mem_s1_wvalid,
    output wire                     AXI_mem_s1_wready,
    output wire [ID_WIDTH-1:0]      AXI_mem_s1_bid,
    output wire [1:0]               AXI_mem_s1_bresp,
    output wire                     AXI_mem_s1_bvalid,
    input  wire                     AXI_mem_s1_bready,
    input  wire [ID_WIDTH-1:0]      AXI_mem_s1_arid,
    input  wire [ADDR_WIDTH-1:0]    AXI_mem_s1_araddr,
    input  wire [7:0]               AXI_mem_s1_arlen,
    input  wire [2:0]               AXI_mem_s1_arsize,
    input  wire [1:0]               AXI_mem_s1_arburst,
    input  wire                     AXI_mem_s1_arlock,
    input  wire [3:0]               AXI_mem_s1_arcache,
    input  wire [2:0]               AXI_mem_s1_arprot,
    input  wire [3:0]               AXI_mem_s1_arqos,
    input  wire                     AXI_mem_s1_arvalid,
    output wire                     AXI_mem_s1_arready,
    output wire [ID_WIDTH-1:0]      AXI_mem_s1_rid,
    output wire [DATA_WIDTH-1:0]    AXI_mem_s1_rdata,
    output wire [1:0]               AXI_mem_s1_rresp,
    output wire                     AXI_mem_s1_rlast,
    output wire                     AXI_mem_s1_rvalid,
    input  wire                     AXI_mem_s1_rready,

    output wire [ID_WIDTH-1:0]      AXI_mem_m_awid,
    output wire [ADDR_WIDTH-1:0]    AXI_mem_m_awaddr,
    output wire [7:0]               AXI_mem_m_awlen,
    output wire [2:0]               AXI_mem_m_awsize,
    output wire [1:0]               AXI_mem_m_awburst,
    output wire                     AXI_mem_m_awlock,
    output wire [3:0]               AXI_mem_m_awcache,
    output wire [2:0]               AXI_mem_m_awprot,
    output wire [3:0]               AXI_mem_m_awqos,
    output wire                     AXI_mem_m_awvalid,
    input  wire                     AXI_mem_m_awready,
    output wire [DATA_WIDTH-1:0]    AXI_mem_m_wdata,
    output wire [DATA_WIDTH/8-1:0]  AXI_mem_m_wstrb,
    output wire                     AXI_mem_m_wlast,
    output wire                     AXI_mem_m_wvalid,
    input  wire                     AXI_mem_m_wready,
    input  wire [ID_WIDTH-1:0]      AXI_mem_m_bid,
    input  wire [1:0]               AXI_mem_m_bresp,
    input  wire                     AXI_mem_m_bvalid,
    output wire                     AXI_mem_m_bready,
    output wire [ID_WIDTH-1:0]      AXI_mem_m_arid,
    output wire [ADDR_WIDTH-1:0]    AXI_mem_m_araddr,
    output wire [7:0]               AXI_mem_m_arlen,
    output wire [2:0]               AXI_mem_m_arsize,
    output wire [1:0]               AXI_mem_m_arburst,
    output wire                     AXI_mem_m_arlock,
    output wire [3:0]               AXI_mem_m_arcache,
    output wire [2:0]               AXI_mem_m_arprot,
    output wire [3:0]               AXI_mem_m_arqos,
    output wire                     AXI_mem_m_arvalid,
    input  wire                     AXI_mem_m_arready,
    input  wire [ID_WIDTH-1:0]      AXI_mem_m_rid,
    input  wire [DATA_WIDTH-1:0]    AXI_mem_m_rdata,
    input  wire [1:0]               AXI_mem_m_rresp,
    input  wire                     AXI_mem_m_rlast,
    input  wire                     AXI_mem_m_rvalid,
    output wire                     AXI_mem_m_rready,

    output wire [31:0]              stat_hit_count,
    output wire [31:0]              stat_miss_count,
    output wire [31:0]              stat_bypass_count,
    output wire [31:0]              stat_writeback_count
);

    wire p0_req_valid;
    wire p0_req_ready;
    wire p0_req_write;
    wire [ADDR_WIDTH-1:0] p0_req_addr;
    wire [DATA_WIDTH-1:0] p0_req_wdata;
    wire [DATA_WIDTH/8-1:0] p0_req_wstrb;
    wire p0_rsp_valid;
    wire p0_rsp_ready;
    wire [DATA_WIDTH-1:0] p0_rsp_rdata;
    wire [1:0] p0_rsp_resp;
    wire p0_idle;

    wire p1_req_valid;
    wire p1_req_ready;
    wire p1_req_write;
    wire [ADDR_WIDTH-1:0] p1_req_addr;
    wire [DATA_WIDTH-1:0] p1_req_wdata;
    wire [DATA_WIDTH/8-1:0] p1_req_wstrb;
    wire p1_rsp_valid;
    wire p1_rsp_ready;
    wire [DATA_WIDTH-1:0] p1_rsp_rdata;
    wire [1:0] p1_rsp_resp;
    wire p1_idle;

    wire mem_cmd_valid;
    wire mem_cmd_ready;
    wire mem_cmd_write;
    wire mem_cmd_line;
    wire [ADDR_WIDTH-1:0] mem_cmd_addr;
    wire [DATA_WIDTH-1:0] mem_cmd_wdata;
    wire [DATA_WIDTH/8-1:0] mem_cmd_wstrb;
    wire [255:0] mem_cmd_wline;
    wire mem_rsp_valid;
    wire mem_rsp_ready;
    wire mem_rsp_error;
    wire [DATA_WIDTH-1:0] mem_rsp_rdata;
    wire [255:0] mem_rsp_rline;

    axi_cache_slave_port #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_slave0 (
        .clk(Clk), .rst_n(Rst_n),
        .s_axi_awid(AXI_mem_s0_awid), .s_axi_awaddr(AXI_mem_s0_awaddr),
        .s_axi_awlen(AXI_mem_s0_awlen), .s_axi_awsize(AXI_mem_s0_awsize),
        .s_axi_awburst(AXI_mem_s0_awburst), .s_axi_awlock(AXI_mem_s0_awlock),
        .s_axi_awcache(AXI_mem_s0_awcache), .s_axi_awprot(AXI_mem_s0_awprot),
        .s_axi_awqos(AXI_mem_s0_awqos), .s_axi_awvalid(AXI_mem_s0_awvalid),
        .s_axi_awready(AXI_mem_s0_awready),
        .s_axi_wdata(AXI_mem_s0_wdata), .s_axi_wstrb(AXI_mem_s0_wstrb),
        .s_axi_wlast(AXI_mem_s0_wlast), .s_axi_wvalid(AXI_mem_s0_wvalid),
        .s_axi_wready(AXI_mem_s0_wready),
        .s_axi_bid(AXI_mem_s0_bid), .s_axi_bresp(AXI_mem_s0_bresp),
        .s_axi_bvalid(AXI_mem_s0_bvalid), .s_axi_bready(AXI_mem_s0_bready),
        .s_axi_arid(AXI_mem_s0_arid), .s_axi_araddr(AXI_mem_s0_araddr),
        .s_axi_arlen(AXI_mem_s0_arlen), .s_axi_arsize(AXI_mem_s0_arsize),
        .s_axi_arburst(AXI_mem_s0_arburst), .s_axi_arlock(AXI_mem_s0_arlock),
        .s_axi_arcache(AXI_mem_s0_arcache), .s_axi_arprot(AXI_mem_s0_arprot),
        .s_axi_arqos(AXI_mem_s0_arqos), .s_axi_arvalid(AXI_mem_s0_arvalid),
        .s_axi_arready(AXI_mem_s0_arready),
        .s_axi_rid(AXI_mem_s0_rid), .s_axi_rdata(AXI_mem_s0_rdata),
        .s_axi_rresp(AXI_mem_s0_rresp), .s_axi_rlast(AXI_mem_s0_rlast),
        .s_axi_rvalid(AXI_mem_s0_rvalid), .s_axi_rready(AXI_mem_s0_rready),
        .req_valid(p0_req_valid), .req_ready(p0_req_ready),
        .req_write(p0_req_write), .req_addr(p0_req_addr),
        .req_wdata(p0_req_wdata), .req_wstrb(p0_req_wstrb),
        .rsp_valid(p0_rsp_valid), .rsp_ready(p0_rsp_ready),
        .rsp_rdata(p0_rsp_rdata), .rsp_resp(p0_rsp_resp), .port_idle(p0_idle)
    );

    axi_cache_slave_port #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_slave1 (
        .clk(Clk), .rst_n(Rst_n),
        .s_axi_awid(AXI_mem_s1_awid), .s_axi_awaddr(AXI_mem_s1_awaddr),
        .s_axi_awlen(AXI_mem_s1_awlen), .s_axi_awsize(AXI_mem_s1_awsize),
        .s_axi_awburst(AXI_mem_s1_awburst), .s_axi_awlock(AXI_mem_s1_awlock),
        .s_axi_awcache(AXI_mem_s1_awcache), .s_axi_awprot(AXI_mem_s1_awprot),
        .s_axi_awqos(AXI_mem_s1_awqos), .s_axi_awvalid(AXI_mem_s1_awvalid),
        .s_axi_awready(AXI_mem_s1_awready),
        .s_axi_wdata(AXI_mem_s1_wdata), .s_axi_wstrb(AXI_mem_s1_wstrb),
        .s_axi_wlast(AXI_mem_s1_wlast), .s_axi_wvalid(AXI_mem_s1_wvalid),
        .s_axi_wready(AXI_mem_s1_wready),
        .s_axi_bid(AXI_mem_s1_bid), .s_axi_bresp(AXI_mem_s1_bresp),
        .s_axi_bvalid(AXI_mem_s1_bvalid), .s_axi_bready(AXI_mem_s1_bready),
        .s_axi_arid(AXI_mem_s1_arid), .s_axi_araddr(AXI_mem_s1_araddr),
        .s_axi_arlen(AXI_mem_s1_arlen), .s_axi_arsize(AXI_mem_s1_arsize),
        .s_axi_arburst(AXI_mem_s1_arburst), .s_axi_arlock(AXI_mem_s1_arlock),
        .s_axi_arcache(AXI_mem_s1_arcache), .s_axi_arprot(AXI_mem_s1_arprot),
        .s_axi_arqos(AXI_mem_s1_arqos), .s_axi_arvalid(AXI_mem_s1_arvalid),
        .s_axi_arready(AXI_mem_s1_arready),
        .s_axi_rid(AXI_mem_s1_rid), .s_axi_rdata(AXI_mem_s1_rdata),
        .s_axi_rresp(AXI_mem_s1_rresp), .s_axi_rlast(AXI_mem_s1_rlast),
        .s_axi_rvalid(AXI_mem_s1_rvalid), .s_axi_rready(AXI_mem_s1_rready),
        .req_valid(p1_req_valid), .req_ready(p1_req_ready),
        .req_write(p1_req_write), .req_addr(p1_req_addr),
        .req_wdata(p1_req_wdata), .req_wstrb(p1_req_wstrb),
        .rsp_valid(p1_rsp_valid), .rsp_ready(p1_rsp_ready),
        .rsp_rdata(p1_rsp_rdata), .rsp_resp(p1_rsp_resp), .port_idle(p1_idle)
    );

    cache_core #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) u_cache_core (
        .clk(Clk), .rst_n(Rst_n),
        .cache_en(Cache_en), .rd_alct_en(Rd_alct_en), .wr_alct_en(Wr_alct_en),
        .wr_mode(Wr_mode), .replace_mode(replace_mode),
        .adr_start(adr_start), .adr_end(adr_end),
        .cache_clr(Cache_clr), .clr_adr_start(clr_adr_start),
        .clr_adr_end(clr_adr_end), .cache_flush(Cache_flush),
        .flush_adr_start(flush_adr_start), .flush_adr_end(flush_adr_end),
        .maint_busy(maint_busy), .maint_done(maint_done), .maint_error(maint_error),
        .p0_req_valid(p0_req_valid), .p0_req_ready(p0_req_ready),
        .p0_req_write(p0_req_write), .p0_req_addr(p0_req_addr),
        .p0_req_wdata(p0_req_wdata), .p0_req_wstrb(p0_req_wstrb),
        .p0_rsp_valid(p0_rsp_valid), .p0_rsp_ready(p0_rsp_ready),
        .p0_rsp_rdata(p0_rsp_rdata), .p0_rsp_resp(p0_rsp_resp), .p0_idle(p0_idle),
        .p1_req_valid(p1_req_valid), .p1_req_ready(p1_req_ready),
        .p1_req_write(p1_req_write), .p1_req_addr(p1_req_addr),
        .p1_req_wdata(p1_req_wdata), .p1_req_wstrb(p1_req_wstrb),
        .p1_rsp_valid(p1_rsp_valid), .p1_rsp_ready(p1_rsp_ready),
        .p1_rsp_rdata(p1_rsp_rdata), .p1_rsp_resp(p1_rsp_resp), .p1_idle(p1_idle),
        .mem_cmd_valid(mem_cmd_valid), .mem_cmd_ready(mem_cmd_ready),
        .mem_cmd_write(mem_cmd_write), .mem_cmd_line(mem_cmd_line),
        .mem_cmd_addr(mem_cmd_addr), .mem_cmd_wdata(mem_cmd_wdata),
        .mem_cmd_wstrb(mem_cmd_wstrb), .mem_cmd_wline(mem_cmd_wline),
        .mem_rsp_valid(mem_rsp_valid), .mem_rsp_ready(mem_rsp_ready),
        .mem_rsp_error(mem_rsp_error), .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_rline(mem_rsp_rline),
        .stat_hit_count(stat_hit_count), .stat_miss_count(stat_miss_count),
        .stat_bypass_count(stat_bypass_count),
        .stat_writeback_count(stat_writeback_count)
    );

    axi_master_engine #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_master_engine (
        .clk(Clk), .rst_n(Rst_n),
        .cmd_valid(mem_cmd_valid), .cmd_ready(mem_cmd_ready),
        .cmd_write(mem_cmd_write), .cmd_line(mem_cmd_line),
        .cmd_addr(mem_cmd_addr), .cmd_wdata(mem_cmd_wdata),
        .cmd_wstrb(mem_cmd_wstrb), .cmd_wline(mem_cmd_wline),
        .rsp_valid(mem_rsp_valid), .rsp_ready(mem_rsp_ready),
        .rsp_error(mem_rsp_error), .rsp_rdata(mem_rsp_rdata),
        .rsp_rline(mem_rsp_rline),
        .m_axi_awid(AXI_mem_m_awid), .m_axi_awaddr(AXI_mem_m_awaddr),
        .m_axi_awlen(AXI_mem_m_awlen), .m_axi_awsize(AXI_mem_m_awsize),
        .m_axi_awburst(AXI_mem_m_awburst), .m_axi_awlock(AXI_mem_m_awlock),
        .m_axi_awcache(AXI_mem_m_awcache), .m_axi_awprot(AXI_mem_m_awprot),
        .m_axi_awqos(AXI_mem_m_awqos), .m_axi_awvalid(AXI_mem_m_awvalid),
        .m_axi_awready(AXI_mem_m_awready),
        .m_axi_wdata(AXI_mem_m_wdata), .m_axi_wstrb(AXI_mem_m_wstrb),
        .m_axi_wlast(AXI_mem_m_wlast), .m_axi_wvalid(AXI_mem_m_wvalid),
        .m_axi_wready(AXI_mem_m_wready),
        .m_axi_bid(AXI_mem_m_bid), .m_axi_bresp(AXI_mem_m_bresp),
        .m_axi_bvalid(AXI_mem_m_bvalid), .m_axi_bready(AXI_mem_m_bready),
        .m_axi_arid(AXI_mem_m_arid), .m_axi_araddr(AXI_mem_m_araddr),
        .m_axi_arlen(AXI_mem_m_arlen), .m_axi_arsize(AXI_mem_m_arsize),
        .m_axi_arburst(AXI_mem_m_arburst), .m_axi_arlock(AXI_mem_m_arlock),
        .m_axi_arcache(AXI_mem_m_arcache), .m_axi_arprot(AXI_mem_m_arprot),
        .m_axi_arqos(AXI_mem_m_arqos), .m_axi_arvalid(AXI_mem_m_arvalid),
        .m_axi_arready(AXI_mem_m_arready),
        .m_axi_rid(AXI_mem_m_rid), .m_axi_rdata(AXI_mem_m_rdata),
        .m_axi_rresp(AXI_mem_m_rresp), .m_axi_rlast(AXI_mem_m_rlast),
        .m_axi_rvalid(AXI_mem_m_rvalid), .m_axi_rready(AXI_mem_m_rready)
    );

endmodule

