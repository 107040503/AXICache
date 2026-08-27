`timescale 1ns/1ps

module axi_master_engine #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer ID_WIDTH   = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     cmd_valid,
    output wire                     cmd_ready,
    input  wire                     cmd_write,
    input  wire                     cmd_line,
    input  wire [ADDR_WIDTH-1:0]    cmd_addr,
    input  wire [DATA_WIDTH-1:0]    cmd_wdata,
    input  wire [DATA_WIDTH/8-1:0]  cmd_wstrb,
    input  wire [255:0]             cmd_wline,

    output reg                      rsp_valid,
    input  wire                     rsp_ready,
    output reg                      rsp_error,
    output reg  [DATA_WIDTH-1:0]    rsp_rdata,
    output reg  [255:0]             rsp_rline,

    output wire [ID_WIDTH-1:0]      m_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awlock,
    output wire [3:0]               m_axi_awcache,
    output wire [2:0]               m_axi_awprot,
    output wire [3:0]               m_axi_awqos,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,

    output wire [DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,

    input  wire [ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,

    output wire [ID_WIDTH-1:0]      m_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arlock,
    output wire [3:0]               m_axi_arcache,
    output wire [2:0]               m_axi_arprot,
    output wire [3:0]               m_axi_arqos,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,

    input  wire [ID_WIDTH-1:0]      m_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready
);

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_AW   = 3'd1;
    localparam [2:0] ST_W    = 3'd2;
    localparam [2:0] ST_B    = 3'd3;
    localparam [2:0] ST_AR   = 3'd4;
    localparam [2:0] ST_R    = 3'd5;
    localparam [2:0] ST_RESP = 3'd6;

    localparam [1:0] AXI_OKAY = 2'b00;

    reg [2:0] state;
    reg txn_line;
    reg [ADDR_WIDTH-1:0] txn_addr;
    reg [DATA_WIDTH-1:0] txn_wdata;
    reg [DATA_WIDTH/8-1:0] txn_wstrb;
    reg [255:0] txn_wline;
    reg [2:0] beat_index;
    reg txn_error;
    reg [255:0] read_line_buffer;

    wire unused_ids;
    assign unused_ids = ^m_axi_bid ^ ^m_axi_rid;

    function automatic [255:0] put_line_word;
        input [255:0] line;
        input [2:0] index;
        input [31:0] word;
        reg [255:0] updated;
        begin
            updated = line;
            case (index)
                3'd0: updated[31:0]    = word;
                3'd1: updated[63:32]   = word;
                3'd2: updated[95:64]   = word;
                3'd3: updated[127:96]  = word;
                3'd4: updated[159:128] = word;
                3'd5: updated[191:160] = word;
                3'd6: updated[223:192] = word;
                default: updated[255:224] = word;
            endcase
            put_line_word = updated;
        end
    endfunction

    function automatic [31:0] get_line_word;
        input [255:0] line;
        input [2:0] index;
        begin
            case (index)
                3'd0: get_line_word = line[31:0];
                3'd1: get_line_word = line[63:32];
                3'd2: get_line_word = line[95:64];
                3'd3: get_line_word = line[127:96];
                3'd4: get_line_word = line[159:128];
                3'd5: get_line_word = line[191:160];
                3'd6: get_line_word = line[223:192];
                default: get_line_word = line[255:224];
            endcase
        end
    endfunction

    assign cmd_ready = (state == ST_IDLE);

    assign m_axi_awid    = {ID_WIDTH{1'b0}};
    assign m_axi_awaddr  = txn_addr;
    assign m_axi_awlen   = txn_line ? 8'd7 : 8'd0;
    assign m_axi_awsize  = 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_awvalid = (state == ST_AW);

    assign m_axi_wdata  = txn_line ? get_line_word(txn_wline, beat_index) : txn_wdata;
    assign m_axi_wstrb  = txn_line ? {DATA_WIDTH/8{1'b1}} : txn_wstrb;
    assign m_axi_wlast  = txn_line ? (beat_index == 3'd7) : 1'b1;
    assign m_axi_wvalid = (state == ST_W);
    assign m_axi_bready = (state == ST_B);

    assign m_axi_arid    = {ID_WIDTH{1'b0}};
    assign m_axi_araddr  = txn_addr;
    assign m_axi_arlen   = txn_line ? 8'd7 : 8'd0;
    assign m_axi_arsize  = 3'd2;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arvalid = (state == ST_AR);
    assign m_axi_rready  = (state == ST_R);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            txn_line         <= 1'b0;
            txn_addr         <= {ADDR_WIDTH{1'b0}};
            txn_wdata        <= {DATA_WIDTH{1'b0}};
            txn_wstrb        <= {DATA_WIDTH/8{1'b0}};
            txn_wline        <= 256'd0;
            beat_index       <= 3'd0;
            txn_error        <= 1'b0;
            read_line_buffer <= 256'd0;
            rsp_valid        <= 1'b0;
            rsp_error        <= 1'b0;
            rsp_rdata        <= {DATA_WIDTH{1'b0}};
            rsp_rline        <= 256'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (cmd_valid && cmd_ready) begin
                        txn_line         <= cmd_line;
                        txn_addr         <= cmd_addr;
                        txn_wdata        <= cmd_wdata;
                        txn_wstrb        <= cmd_wstrb;
                        txn_wline        <= cmd_wline;
                        beat_index       <= 3'd0;
                        txn_error        <= 1'b0;
                        read_line_buffer <= 256'd0;
                        rsp_error        <= 1'b0;
                        if (cmd_write)
                            state <= ST_AW;
                        else
                            state <= ST_AR;
                    end
                end

                ST_AW: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        beat_index <= 3'd0;
                        state      <= ST_W;
                    end
                end

                ST_W: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        if (m_axi_wlast)
                            state <= ST_B;
                        else
                            beat_index <= beat_index + 1'b1;
                    end
                end

                ST_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        rsp_error <= (m_axi_bresp != AXI_OKAY);
                        rsp_valid <= 1'b1;
                        state     <= ST_RESP;
                    end
                end

                ST_AR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        beat_index <= 3'd0;
                        state      <= ST_R;
                    end
                end

                ST_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        read_line_buffer <= put_line_word(read_line_buffer,
                                                          beat_index,
                                                          m_axi_rdata);
                        txn_error <= txn_error || (m_axi_rresp != AXI_OKAY) ||
                                     (m_axi_rlast != (txn_line ?
                                                      (beat_index == 3'd7) : 1'b1));
                        if (m_axi_rlast || (txn_line ?
                                            (beat_index == 3'd7) : 1'b1)) begin
                            rsp_rdata <= m_axi_rdata;
                            rsp_rline <= put_line_word(read_line_buffer,
                                                       beat_index,
                                                       m_axi_rdata);
                            rsp_error <= txn_error || (m_axi_rresp != AXI_OKAY) ||
                                         (m_axi_rlast != (txn_line ?
                                                          (beat_index == 3'd7) : 1'b1));
                            rsp_valid <= 1'b1;
                            state     <= ST_RESP;
                        end else begin
                            beat_index <= beat_index + 1'b1;
                        end
                    end
                end

                ST_RESP: begin
                    if (rsp_valid && rsp_ready) begin
                        rsp_valid <= 1'b0;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

