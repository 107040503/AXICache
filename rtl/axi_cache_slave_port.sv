`timescale 1ns/1ps

module axi_cache_slave_port #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer ID_WIDTH   = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,

    output reg  [ID_WIDTH-1:0]      s_axi_bid,
    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,

    output reg  [ID_WIDTH-1:0]      s_axi_rid,
    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rlast,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,

    output wire                     req_valid,
    input  wire                     req_ready,
    output wire                     req_write,
    output wire [ADDR_WIDTH-1:0]    req_addr,
    output wire [DATA_WIDTH-1:0]    req_wdata,
    output wire [DATA_WIDTH/8-1:0]  req_wstrb,

    input  wire                     rsp_valid,
    output wire                     rsp_ready,
    input  wire [DATA_WIDTH-1:0]    rsp_rdata,
    input  wire [1:0]               rsp_resp,

    output wire                     port_idle
);

    localparam [3:0] ST_IDLE       = 4'd0;
    localparam [3:0] ST_R_REQ      = 4'd1;
    localparam [3:0] ST_R_WAIT     = 4'd2;
    localparam [3:0] ST_R_SEND     = 4'd3;
    localparam [3:0] ST_R_ERROR    = 4'd4;
    localparam [3:0] ST_W_DATA     = 4'd5;
    localparam [3:0] ST_W_WAIT     = 4'd6;
    localparam [3:0] ST_W_DROP     = 4'd7;
    localparam [3:0] ST_W_RESP     = 4'd8;

    localparam [1:0] AXI_OKAY   = 2'b00;
    localparam [1:0] AXI_SLVERR = 2'b10;

    reg [3:0] state;
    reg [ID_WIDTH-1:0] txn_id;
    reg [ADDR_WIDTH-1:0] cur_addr;
    reg [7:0] txn_len;
    reg [7:0] beat_count;
    reg [2:0] txn_size;
    reg [1:0] txn_burst;
    reg write_error;
    reg beat_terminal;
    reg beat_protocol_error;

    wire unused_inputs;
    assign unused_inputs = s_axi_awlock ^ s_axi_arlock ^ s_axi_awcache[0] ^
                           s_axi_awprot[0] ^ s_axi_awqos[0] ^ s_axi_arcache[0] ^
                           s_axi_arprot[0] ^ s_axi_arqos[0];

    function automatic legal_burst;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] len;
        input [2:0] size;
        input [1:0] burst;
        begin
            legal_burst = (size == 3'd2) && (addr[1:0] == 2'b00) &&
                          (burst != 2'b11) &&
                          ((burst != 2'b10) ||
                           (len == 8'd1) || (len == 8'd3) ||
                           (len == 8'd7) || (len == 8'd15));
        end
    endfunction

    function automatic [ADDR_WIDTH-1:0] next_burst_addr;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] len;
        input [2:0] size;
        input [1:0] burst;
        reg [ADDR_WIDTH-1:0] increment;
        reg [ADDR_WIDTH-1:0] wrap_bytes;
        reg [ADDR_WIDTH-1:0] wrap_base;
        reg [ADDR_WIDTH-1:0] candidate;
        begin
            increment = {{(ADDR_WIDTH-1){1'b0}}, 1'b1} << size;
            candidate = addr + increment;
            case (burst)
                2'b00: next_burst_addr = addr;
                2'b10: begin
                    wrap_bytes = increment * (len + 1'b1);
                    wrap_base = addr & ~(wrap_bytes - 1'b1);
                    if (candidate >= (wrap_base + wrap_bytes))
                        next_burst_addr = wrap_base;
                    else
                        next_burst_addr = candidate;
                end
                default: next_burst_addr = candidate;
            endcase
        end
    endfunction

    assign s_axi_arready = (state == ST_IDLE);
    assign s_axi_awready = (state == ST_IDLE) && !s_axi_arvalid;
    assign s_axi_wready  = ((state == ST_W_DATA) && req_ready) ||
                           (state == ST_W_DROP);

    assign req_valid = ((state == ST_R_REQ) ||
                        ((state == ST_W_DATA) && s_axi_wvalid));
    assign req_write = (state == ST_W_DATA);
    assign req_addr  = cur_addr;
    assign req_wdata = s_axi_wdata;
    assign req_wstrb = s_axi_wstrb;

    assign rsp_ready = ((state == ST_R_WAIT) && !s_axi_rvalid) ||
                       (state == ST_W_WAIT);
    assign port_idle = (state == ST_IDLE) && !s_axi_rvalid && !s_axi_bvalid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= ST_IDLE;
            txn_id              <= {ID_WIDTH{1'b0}};
            cur_addr            <= {ADDR_WIDTH{1'b0}};
            txn_len             <= 8'd0;
            beat_count          <= 8'd0;
            txn_size            <= 3'd0;
            txn_burst           <= 2'd0;
            write_error         <= 1'b0;
            beat_terminal       <= 1'b0;
            beat_protocol_error <= 1'b0;
            s_axi_bid           <= {ID_WIDTH{1'b0}};
            s_axi_bresp         <= AXI_OKAY;
            s_axi_bvalid        <= 1'b0;
            s_axi_rid           <= {ID_WIDTH{1'b0}};
            s_axi_rdata         <= {DATA_WIDTH{1'b0}};
            s_axi_rresp         <= AXI_OKAY;
            s_axi_rlast         <= 1'b0;
            s_axi_rvalid        <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    write_error <= 1'b0;
                    if (s_axi_arvalid && s_axi_arready) begin
                        txn_id     <= s_axi_arid;
                        cur_addr   <= s_axi_araddr;
                        txn_len    <= s_axi_arlen;
                        beat_count <= 8'd0;
                        txn_size   <= s_axi_arsize;
                        txn_burst  <= s_axi_arburst;
                        if (legal_burst(s_axi_araddr, s_axi_arlen,
                                        s_axi_arsize, s_axi_arburst))
                            state <= ST_R_REQ;
                        else
                            state <= ST_R_ERROR;
                    end else if (s_axi_awvalid && s_axi_awready) begin
                        txn_id     <= s_axi_awid;
                        cur_addr   <= s_axi_awaddr;
                        txn_len    <= s_axi_awlen;
                        beat_count <= 8'd0;
                        txn_size   <= s_axi_awsize;
                        txn_burst  <= s_axi_awburst;
                        if (legal_burst(s_axi_awaddr, s_axi_awlen,
                                        s_axi_awsize, s_axi_awburst))
                            state <= ST_W_DATA;
                        else
                            state <= ST_W_DROP;
                    end
                end

                ST_R_REQ: begin
                    if (req_valid && req_ready)
                        state <= ST_R_WAIT;
                end

                ST_R_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        s_axi_rid    <= txn_id;
                        s_axi_rdata  <= rsp_rdata;
                        s_axi_rresp  <= rsp_resp;
                        s_axi_rlast  <= (beat_count == txn_len);
                        s_axi_rvalid <= 1'b1;
                        state        <= ST_R_SEND;
                    end
                end

                ST_R_SEND: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        if (beat_count == txn_len) begin
                            s_axi_rlast <= 1'b0;
                            state       <= ST_IDLE;
                        end else begin
                            beat_count <= beat_count + 1'b1;
                            cur_addr   <= next_burst_addr(cur_addr, txn_len,
                                                          txn_size, txn_burst);
                            state      <= ST_R_REQ;
                        end
                    end
                end

                ST_R_ERROR: begin
                    if (!s_axi_rvalid) begin
                        s_axi_rid    <= txn_id;
                        s_axi_rdata  <= {DATA_WIDTH{1'b0}};
                        s_axi_rresp  <= AXI_SLVERR;
                        s_axi_rlast  <= (beat_count == txn_len);
                        s_axi_rvalid <= 1'b1;
                    end else if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        if (beat_count == txn_len) begin
                            s_axi_rlast <= 1'b0;
                            state       <= ST_IDLE;
                        end else begin
                            beat_count <= beat_count + 1'b1;
                            cur_addr   <= next_burst_addr(cur_addr, txn_len,
                                                          txn_size, txn_burst);
                        end
                    end
                end

                ST_W_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        beat_terminal       <= s_axi_wlast || (beat_count == txn_len);
                        beat_protocol_error <= s_axi_wlast != (beat_count == txn_len);
                        state               <= ST_W_WAIT;
                    end
                end

                ST_W_WAIT: begin
                    if (rsp_valid && rsp_ready) begin
                        write_error <= write_error || beat_protocol_error ||
                                       (rsp_resp != AXI_OKAY);
                        if (beat_terminal) begin
                            s_axi_bid    <= txn_id;
                            s_axi_bresp  <= (write_error || beat_protocol_error ||
                                             (rsp_resp != AXI_OKAY)) ? AXI_SLVERR : AXI_OKAY;
                            s_axi_bvalid <= 1'b1;
                            state        <= ST_W_RESP;
                        end else begin
                            beat_count <= beat_count + 1'b1;
                            cur_addr   <= next_burst_addr(cur_addr, txn_len,
                                                          txn_size, txn_burst);
                            state      <= ST_W_DATA;
                        end
                    end
                end

                ST_W_DROP: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        if (s_axi_wlast || (beat_count == txn_len)) begin
                            s_axi_bid    <= txn_id;
                            s_axi_bresp  <= AXI_SLVERR;
                            s_axi_bvalid <= 1'b1;
                            state        <= ST_W_RESP;
                        end else begin
                            beat_count <= beat_count + 1'b1;
                            cur_addr   <= next_burst_addr(cur_addr, txn_len,
                                                          txn_size, txn_burst);
                        end
                    end
                end

                ST_W_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        s_axi_bresp  <= AXI_OKAY;
                        state        <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

