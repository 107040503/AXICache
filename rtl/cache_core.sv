`timescale 1ns/1ps

module cache_core #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     cache_en,
    input  wire                     rd_alct_en,
    input  wire                     wr_alct_en,
    input  wire                     wr_mode,
    input  wire                     replace_mode,
    input  wire [21:0]              adr_start,
    input  wire [21:0]              adr_end,

    input  wire                     cache_clr,
    input  wire [21:0]              clr_adr_start,
    input  wire [21:0]              clr_adr_end,
    input  wire                     cache_flush,
    input  wire [21:0]              flush_adr_start,
    input  wire [21:0]              flush_adr_end,
    output reg                      maint_busy,
    output reg                      maint_done,
    output reg                      maint_error,

    input  wire                     p0_req_valid,
    output reg                      p0_req_ready,
    input  wire                     p0_req_write,
    input  wire [ADDR_WIDTH-1:0]    p0_req_addr,
    input  wire [DATA_WIDTH-1:0]    p0_req_wdata,
    input  wire [DATA_WIDTH/8-1:0]  p0_req_wstrb,
    output reg                      p0_rsp_valid,
    input  wire                     p0_rsp_ready,
    output reg  [DATA_WIDTH-1:0]    p0_rsp_rdata,
    output reg  [1:0]               p0_rsp_resp,
    input  wire                     p0_idle,

    input  wire                     p1_req_valid,
    output reg                      p1_req_ready,
    input  wire                     p1_req_write,
    input  wire [ADDR_WIDTH-1:0]    p1_req_addr,
    input  wire [DATA_WIDTH-1:0]    p1_req_wdata,
    input  wire [DATA_WIDTH/8-1:0]  p1_req_wstrb,
    output reg                      p1_rsp_valid,
    input  wire                     p1_rsp_ready,
    output reg  [DATA_WIDTH-1:0]    p1_rsp_rdata,
    output reg  [1:0]               p1_rsp_resp,
    input  wire                     p1_idle,

    output reg                      mem_cmd_valid,
    input  wire                     mem_cmd_ready,
    output reg                      mem_cmd_write,
    output reg                      mem_cmd_line,
    output reg  [ADDR_WIDTH-1:0]    mem_cmd_addr,
    output reg  [DATA_WIDTH-1:0]    mem_cmd_wdata,
    output reg  [DATA_WIDTH/8-1:0]  mem_cmd_wstrb,
    output reg  [255:0]             mem_cmd_wline,
    input  wire                     mem_rsp_valid,
    output reg                      mem_rsp_ready,
    input  wire                     mem_rsp_error,
    input  wire [DATA_WIDTH-1:0]    mem_rsp_rdata,
    input  wire [255:0]             mem_rsp_rline,

    output reg  [31:0]              stat_hit_count,
    output reg  [31:0]              stat_miss_count,
    output reg  [31:0]              stat_bypass_count,
    output reg  [31:0]              stat_writeback_count
);

    localparam integer WAYS        = 4;
    localparam integer SETS        = 256;
    localparam integer LINE_WORDS  = 8;
    localparam integer INDEX_WIDTH = 8;
    localparam integer TAG_WIDTH   = ADDR_WIDTH - INDEX_WIDTH - 5;
    localparam [21:0] MAX_MAP_KB   = 22'd262144;

    localparam [1:0] AXI_OKAY   = 2'b00;
    localparam [1:0] AXI_SLVERR = 2'b10;

    localparam [3:0] OP_IDLE          = 4'd0;
    localparam [3:0] OP_WB_REQ        = 4'd1;
    localparam [3:0] OP_WB_WAIT       = 4'd2;
    localparam [3:0] OP_REFILL_REQ    = 4'd3;
    localparam [3:0] OP_REFILL_WAIT   = 4'd4;
    localparam [3:0] OP_DIRECT_REQ    = 4'd5;
    localparam [3:0] OP_DIRECT_WAIT   = 4'd6;
    localparam [3:0] OP_WT_REQ        = 4'd7;
    localparam [3:0] OP_WT_WAIT       = 4'd8;
    localparam [3:0] OP_MAINT_SCAN    = 4'd9;
    localparam [3:0] OP_MAINT_WB_REQ  = 4'd10;
    localparam [3:0] OP_MAINT_WB_WAIT = 4'd11;
    localparam [3:0] OP_DATA_WAIT     = 4'd12;

    reg [3:0] op_state;

    reg [WAYS-1:0]                 valid_mem [0:SETS-1];
    reg [WAYS-1:0]                 dirty_mem [0:SETS-1];
    reg [WAYS-1:0][TAG_WIDTH-1:0]  tag_mem   [0:SETS-1];
    reg [WAYS-1:0][7:0]            lfu_count [0:SETS-1];
    reg [WAYS-1:0][15:0]           lru_stamp [0:SETS-1];
    reg [15:0]             lru_clock [0:SETS-1];

    wire [31:0] data_rdata_a [0:WAYS-1][0:LINE_WORDS-1];
    wire [31:0] data_rdata_b [0:WAYS-1][0:LINE_WORDS-1];
    reg         data_we_a    [0:WAYS-1][0:LINE_WORDS-1];
    reg         data_we_b    [0:WAYS-1][0:LINE_WORDS-1];
    reg [3:0]   data_be_a    [0:WAYS-1][0:LINE_WORDS-1];
    reg [3:0]   data_be_b    [0:WAYS-1][0:LINE_WORDS-1];
    reg [31:0]  data_wdata_a [0:WAYS-1][0:LINE_WORDS-1];
    reg [31:0]  data_wdata_b [0:WAYS-1][0:LINE_WORDS-1];
    reg [INDEX_WIDTH-1:0] sram_addr_a;
    reg [INDEX_WIDTH-1:0] sram_addr_b;

    reg p0_read_pending;
    reg p1_read_pending;
    reg [1:0] p0_read_way;
    reg [1:0] p1_read_way;
    reg [2:0] p0_read_word;
    reg [2:0] p1_read_word;

    reg ctx_owner;
    reg ctx_write;
    reg ctx_cacheable;
    reg ctx_wr_mode;
    reg ctx_wb_for_wt_hit;
    reg [ADDR_WIDTH-1:0] ctx_addr;
    reg [DATA_WIDTH-1:0] ctx_wdata;
    reg [DATA_WIDTH/8-1:0] ctx_wstrb;
    reg [INDEX_WIDTH-1:0] ctx_set;
    reg [2:0] ctx_word;
    reg [1:0] ctx_way;
    reg [TAG_WIDTH-1:0] ctx_tag;
    reg [TAG_WIDTH-1:0] ctx_victim_tag;
    reg [255:0] ctx_victim_line;

    reg maint_pending_clear;
    reg maint_pending_flush;
    reg maint_is_flush;
    reg maint_is_init;
    reg [21:0] maint_range_start;
    reg [21:0] maint_range_end;
    reg [INDEX_WIDTH-1:0] scan_set;
    reg [1:0] scan_way;

    wire [INDEX_WIDTH-1:0] p0_set = p0_req_addr[12:5];
    wire [INDEX_WIDTH-1:0] p1_set = p1_req_addr[12:5];
    wire [2:0] p0_word = p0_req_addr[4:2];
    wire [2:0] p1_word = p1_req_addr[4:2];
    wire [TAG_WIDTH-1:0] p0_tag = p0_req_addr[ADDR_WIDTH-1:13];
    wire [TAG_WIDTH-1:0] p1_tag = p1_req_addr[ADDR_WIDTH-1:13];

    reg p0_hit;
    reg p1_hit;
    reg [1:0] p0_hit_way;
    reg [1:0] p1_hit_way;
    reg [1:0] p0_victim_way;
    reg [1:0] p1_victim_way;
    reg p0_cacheable;
    reg p1_cacheable;
    reg p0_fast;
    reg p1_fast;

    wire p0_fire = p0_req_valid && p0_req_ready;
    wire p1_fire = p1_req_valid && p1_req_ready;
    wire p0_slow = p0_req_valid && !p0_fast;
    wire p1_slow = p1_req_valid && !p1_fast;
    wire same_line_request = p0_req_valid && p1_req_valid &&
                             (p0_req_addr[ADDR_WIDTH-1:5] ==
                              p1_req_addr[ADDR_WIDTH-1:5]);
    wire p0_hit_event = p0_fire && p0_cacheable && p0_hit;
    wire p1_hit_event = p1_fire && p1_cacheable && p1_hit;
    wire p0_miss_event = p0_fire && p0_cacheable && !p0_hit;
    wire p1_miss_event = p1_fire && p1_cacheable && !p1_hit;
    wire p0_bypass_event = p0_fire && !p0_cacheable;
    wire p1_bypass_event = p1_fire && !p1_cacheable;

    integer wi;
    integer si;
    integer way0_i;
    integer way1_i;
    integer word_i;
    reg invalid_found0;
    reg invalid_found1;
    reg [15:0] min_lru0;
    reg [15:0] min_lru1;
    reg [7:0] min_lfu0;
    reg [7:0] min_lfu1;
    reg [31:0] scan_line_addr;
    reg [255:0] scan_line_data;

    function automatic [31:0] merge_bytes;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0] strobes;
        integer bi;
        reg [31:0] merged;
        begin
            merged = old_word;
            for (bi = 0; bi < 4; bi = bi + 1) begin
                if (strobes[bi])
                    merged[bi*8 +: 8] = new_word[bi*8 +: 8];
            end
            merge_bytes = merged;
        end
    endfunction

    function automatic [31:0] line_word;
        input [255:0] line;
        input [2:0] index;
        begin
            case (index)
                3'd0: line_word = line[31:0];
                3'd1: line_word = line[63:32];
                3'd2: line_word = line[95:64];
                3'd3: line_word = line[127:96];
                3'd4: line_word = line[159:128];
                3'd5: line_word = line[191:160];
                3'd6: line_word = line[223:192];
                default: line_word = line[255:224];
            endcase
        end
    endfunction

    function automatic [255:0] merge_line_word;
        input [255:0] line;
        input [2:0] index;
        input [31:0] new_word;
        input [3:0] strobes;
        reg [255:0] result_line;
        begin
            result_line = line;
            case (index)
                3'd0: result_line[31:0]    = merge_bytes(line[31:0], new_word, strobes);
                3'd1: result_line[63:32]   = merge_bytes(line[63:32], new_word, strobes);
                3'd2: result_line[95:64]   = merge_bytes(line[95:64], new_word, strobes);
                3'd3: result_line[127:96]  = merge_bytes(line[127:96], new_word, strobes);
                3'd4: result_line[159:128] = merge_bytes(line[159:128], new_word, strobes);
                3'd5: result_line[191:160] = merge_bytes(line[191:160], new_word, strobes);
                3'd6: result_line[223:192] = merge_bytes(line[223:192], new_word, strobes);
                default: result_line[255:224] = merge_bytes(line[255:224], new_word, strobes);
            endcase
            merge_line_word = result_line;
        end
    endfunction

    function automatic address_is_cacheable;
        input [ADDR_WIDTH-1:0] address;
        reg [21:0] block_kb;
        reg [21:0] offset_kb;
        begin
            block_kb = address[31:10];
            offset_kb = block_kb - adr_start;
            address_is_cacheable = cache_en && (adr_end >= adr_start) &&
                                   (block_kb >= adr_start) &&
                                   (block_kb <= adr_end) &&
                                   (offset_kb < MAX_MAP_KB);
        end
    endfunction

    function automatic [255:0] port_a_line;
        input [1:0] selected_way;
        integer k;
        begin
            port_a_line = 256'd0;
            for (k = 0; k < LINE_WORDS; k = k + 1)
                port_a_line[k*32 +: 32] = data_rdata_a[selected_way][k];
        end
    endfunction

    function automatic [255:0] port_b_line;
        input [1:0] selected_way;
        integer k;
        begin
            port_b_line = 256'd0;
            for (k = 0; k < LINE_WORDS; k = k + 1)
                port_b_line[k*32 +: 32] = data_rdata_b[selected_way][k];
        end
    endfunction

    genvar gw;
    genvar gb;
    generate
        for (gw = 0; gw < WAYS; gw = gw + 1) begin : gen_way
            for (gb = 0; gb < LINE_WORDS; gb = gb + 1) begin : gen_bank
                cache_sram_tdp #(
                    .DATA_WIDTH(32),
                    .DEPTH(SETS),
                    .ADDR_WIDTH(INDEX_WIDTH)
                ) u_data_sram (
                    .clk(clk),
                    .en_a(1'b1),
                    .we_a(data_we_a[gw][gb]),
                    .be_a(data_be_a[gw][gb]),
                    .addr_a(sram_addr_a),
                    .wdata_a(data_wdata_a[gw][gb]),
                    .rdata_a(data_rdata_a[gw][gb]),
                    .en_b(1'b1),
                    .we_b(data_we_b[gw][gb]),
                    .be_b(data_be_b[gw][gb]),
                    .addr_b(sram_addr_b),
                    .wdata_b(data_wdata_b[gw][gb]),
                    .rdata_b(data_rdata_b[gw][gb])
                );
            end
        end
    endgenerate

    always @* begin
        p0_cacheable = address_is_cacheable(p0_req_addr);
        p1_cacheable = address_is_cacheable(p1_req_addr);

        p0_hit = 1'b0;
        p1_hit = 1'b0;
        p0_hit_way = 2'd0;
        p1_hit_way = 2'd0;
        for (wi = 0; wi < WAYS; wi = wi + 1) begin
            if (valid_mem[p0_set][wi] && (tag_mem[p0_set][wi] == p0_tag)) begin
                p0_hit = 1'b1;
                p0_hit_way = wi[1:0];
            end
            if (valid_mem[p1_set][wi] && (tag_mem[p1_set][wi] == p1_tag)) begin
                p1_hit = 1'b1;
                p1_hit_way = wi[1:0];
            end
        end

        p0_fast = p0_cacheable && p0_hit &&
                  (!p0_req_write || wr_mode);
        p1_fast = p1_cacheable && p1_hit &&
                  (!p1_req_write || wr_mode);
    end

    always @* begin
        p0_victim_way = 2'd0;
        invalid_found0 = 1'b0;
        min_lru0 = 16'd0;
        min_lfu0 = 8'd0;
        for (way0_i = 0; way0_i < WAYS; way0_i = way0_i + 1) begin
            if (!valid_mem[p0_set][way0_i] && !invalid_found0) begin
                p0_victim_way = way0_i[1:0];
                invalid_found0 = 1'b1;
            end
        end
        if (!invalid_found0) begin
            if (replace_mode) begin
                min_lru0 = lru_stamp[p0_set][0];
                p0_victim_way = 2'd0;
                for (way0_i = 1; way0_i < WAYS; way0_i = way0_i + 1) begin
                    if (lru_stamp[p0_set][way0_i] < min_lru0) begin
                        min_lru0 = lru_stamp[p0_set][way0_i];
                        p0_victim_way = way0_i[1:0];
                    end
                end
            end else begin
                min_lfu0 = lfu_count[p0_set][0];
                p0_victim_way = 2'd0;
                for (way0_i = 1; way0_i < WAYS; way0_i = way0_i + 1) begin
                    if (lfu_count[p0_set][way0_i] < min_lfu0) begin
                        min_lfu0 = lfu_count[p0_set][way0_i];
                        p0_victim_way = way0_i[1:0];
                    end
                end
            end
        end
    end

    always @* begin
        p1_victim_way = 2'd0;
        invalid_found1 = 1'b0;
        min_lru1 = 16'd0;
        min_lfu1 = 8'd0;
        for (way1_i = 0; way1_i < WAYS; way1_i = way1_i + 1) begin
            if (!valid_mem[p1_set][way1_i] && !invalid_found1) begin
                p1_victim_way = way1_i[1:0];
                invalid_found1 = 1'b1;
            end
        end
        if (!invalid_found1) begin
            if (replace_mode) begin
                min_lru1 = lru_stamp[p1_set][0];
                p1_victim_way = 2'd0;
                for (way1_i = 1; way1_i < WAYS; way1_i = way1_i + 1) begin
                    if (lru_stamp[p1_set][way1_i] < min_lru1) begin
                        min_lru1 = lru_stamp[p1_set][way1_i];
                        p1_victim_way = way1_i[1:0];
                    end
                end
            end else begin
                min_lfu1 = lfu_count[p1_set][0];
                p1_victim_way = 2'd0;
                for (way1_i = 1; way1_i < WAYS; way1_i = way1_i + 1) begin
                    if (lfu_count[p1_set][way1_i] < min_lfu1) begin
                        min_lfu1 = lfu_count[p1_set][way1_i];
                        p1_victim_way = way1_i[1:0];
                    end
                end
            end
        end
    end

    always @* begin
        p0_req_ready = 1'b0;
        p1_req_ready = 1'b0;

        if (!maint_busy) begin
            if (p0_req_valid) begin
                if (p0_fast) begin
                    if (!p0_read_pending && (!p0_rsp_valid || p0_rsp_ready) &&
                        !(((op_state == OP_WB_REQ) || (op_state == OP_WB_WAIT) ||
                           (op_state == OP_REFILL_REQ) || (op_state == OP_REFILL_WAIT) ||
                           (op_state == OP_WT_REQ) || (op_state == OP_WT_WAIT)) &&
                          (p0_set == ctx_set)))
                        p0_req_ready = 1'b1;
                end else if ((op_state == OP_IDLE) && (!p0_rsp_valid || p0_rsp_ready)) begin
                    p0_req_ready = 1'b1;
                end
            end

            if (p1_req_valid && !same_line_request) begin
                if (p1_fast) begin
                    if (!p1_read_pending && (!p1_rsp_valid || p1_rsp_ready) &&
                        !(((op_state == OP_WB_REQ) || (op_state == OP_WB_WAIT) ||
                           (op_state == OP_REFILL_REQ) || (op_state == OP_REFILL_WAIT) ||
                           (op_state == OP_WT_REQ) || (op_state == OP_WT_WAIT)) &&
                          (p1_set == ctx_set)) &&
                        !(p0_fire && p0_slow && (p0_set == p1_set)))
                        p1_req_ready = 1'b1;
                end else if ((op_state == OP_IDLE) && (!p1_rsp_valid || p1_rsp_ready) &&
                             !(p0_fire && p0_slow) &&
                             !(p0_fire && (p0_set == p1_set))) begin
                    p1_req_ready = 1'b1;
                end
            end
        end
    end

    always @* begin
        if (maint_busy) begin
            sram_addr_a = scan_set;
            sram_addr_b = scan_set;
        end else begin
            if ((op_state != OP_IDLE) && ctx_owner == 1'b0)
                sram_addr_a = ctx_set;
            else
                sram_addr_a = p0_set;

            if ((op_state != OP_IDLE) && ctx_owner == 1'b1)
                sram_addr_b = ctx_set;
            else
                sram_addr_b = p1_set;
        end
    end

    always @* begin
        for (si = 0; si < WAYS; si = si + 1) begin
            for (word_i = 0; word_i < LINE_WORDS; word_i = word_i + 1) begin
                data_we_a[si][word_i] = 1'b0;
                data_we_b[si][word_i] = 1'b0;
                data_be_a[si][word_i] = 4'b0000;
                data_be_b[si][word_i] = 4'b0000;
                data_wdata_a[si][word_i] = 32'd0;
                data_wdata_b[si][word_i] = 32'd0;
            end
        end

        if (p0_fire && p0_cacheable && p0_hit && p0_req_write) begin
            data_we_a[p0_hit_way][p0_word] = 1'b1;
            data_be_a[p0_hit_way][p0_word] = p0_req_wstrb;
            data_wdata_a[p0_hit_way][p0_word] = p0_req_wdata;
        end

        if (p1_fire && p1_cacheable && p1_hit && p1_req_write) begin
            data_we_b[p1_hit_way][p1_word] = 1'b1;
            data_be_b[p1_hit_way][p1_word] = p1_req_wstrb;
            data_wdata_b[p1_hit_way][p1_word] = p1_req_wdata;
        end

        if ((op_state == OP_REFILL_WAIT) && mem_rsp_valid && !mem_rsp_error) begin
            for (word_i = 0; word_i < LINE_WORDS; word_i = word_i + 1) begin
                if (ctx_owner == 1'b0) begin
                    data_we_a[ctx_way][word_i] = 1'b1;
                    data_be_a[ctx_way][word_i] = 4'b1111;
                    if (ctx_write && (ctx_word == word_i[2:0]))
                        data_wdata_a[ctx_way][word_i] =
                            merge_bytes(mem_rsp_rline[word_i*32 +: 32],
                                        ctx_wdata, ctx_wstrb);
                    else
                        data_wdata_a[ctx_way][word_i] =
                            mem_rsp_rline[word_i*32 +: 32];
                end else begin
                    data_we_b[ctx_way][word_i] = 1'b1;
                    data_be_b[ctx_way][word_i] = 4'b1111;
                    if (ctx_write && (ctx_word == word_i[2:0]))
                        data_wdata_b[ctx_way][word_i] =
                            merge_bytes(mem_rsp_rline[word_i*32 +: 32],
                                        ctx_wdata, ctx_wstrb);
                    else
                        data_wdata_b[ctx_way][word_i] =
                            mem_rsp_rline[word_i*32 +: 32];
                end
            end
        end
    end

    always @* begin
        scan_line_addr = {tag_mem[scan_set][scan_way], scan_set, 5'b00000};
        scan_line_data = port_a_line(scan_way);

        mem_cmd_valid = 1'b0;
        mem_cmd_write = 1'b0;
        mem_cmd_line  = 1'b0;
        mem_cmd_addr  = {ADDR_WIDTH{1'b0}};
        mem_cmd_wdata = {DATA_WIDTH{1'b0}};
        mem_cmd_wstrb = {DATA_WIDTH/8{1'b0}};
        mem_cmd_wline = 256'd0;
        mem_rsp_ready = 1'b0;

        case (op_state)
            OP_WB_REQ: begin
                mem_cmd_valid = 1'b1;
                mem_cmd_write = 1'b1;
                mem_cmd_line  = 1'b1;
                mem_cmd_addr  = {ctx_victim_tag, ctx_set, 5'b00000};
                mem_cmd_wline = ctx_victim_line;
            end
            OP_WB_WAIT: mem_rsp_ready = 1'b1;
            OP_REFILL_REQ: begin
                mem_cmd_valid = 1'b1;
                mem_cmd_write = 1'b0;
                mem_cmd_line  = 1'b1;
                mem_cmd_addr  = {ctx_addr[ADDR_WIDTH-1:5], 5'b00000};
            end
            OP_REFILL_WAIT: mem_rsp_ready = 1'b1;
            OP_DIRECT_REQ: begin
                mem_cmd_valid = 1'b1;
                mem_cmd_write = ctx_write;
                mem_cmd_line  = 1'b0;
                mem_cmd_addr  = {ctx_addr[ADDR_WIDTH-1:2], 2'b00};
                mem_cmd_wdata = ctx_wdata;
                mem_cmd_wstrb = ctx_wstrb;
            end
            OP_DIRECT_WAIT: mem_rsp_ready = 1'b1;
            OP_WT_REQ: begin
                mem_cmd_valid = 1'b1;
                mem_cmd_write = 1'b1;
                mem_cmd_line  = 1'b0;
                mem_cmd_addr  = {ctx_addr[ADDR_WIDTH-1:2], 2'b00};
                mem_cmd_wdata = ctx_wdata;
                mem_cmd_wstrb = ctx_wstrb;
            end
            OP_WT_WAIT: mem_rsp_ready = 1'b1;
            OP_MAINT_WB_REQ: begin
                mem_cmd_valid = 1'b1;
                mem_cmd_write = 1'b1;
                mem_cmd_line  = 1'b1;
                mem_cmd_addr  = scan_line_addr;
                mem_cmd_wline = scan_line_data;
            end
            OP_MAINT_WB_WAIT: mem_rsp_ready = 1'b1;
            default: begin end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_state              <= OP_MAINT_SCAN;
            p0_rsp_valid          <= 1'b0;
            p0_rsp_rdata          <= {DATA_WIDTH{1'b0}};
            p0_rsp_resp           <= AXI_OKAY;
            p1_rsp_valid          <= 1'b0;
            p1_rsp_rdata          <= {DATA_WIDTH{1'b0}};
            p1_rsp_resp           <= AXI_OKAY;
            ctx_owner             <= 1'b0;
            ctx_write             <= 1'b0;
            ctx_cacheable         <= 1'b0;
            ctx_wr_mode           <= 1'b0;
            ctx_wb_for_wt_hit     <= 1'b0;
            ctx_addr              <= {ADDR_WIDTH{1'b0}};
            ctx_wdata             <= {DATA_WIDTH{1'b0}};
            ctx_wstrb             <= {DATA_WIDTH/8{1'b0}};
            ctx_set               <= {INDEX_WIDTH{1'b0}};
            ctx_word              <= 3'd0;
            ctx_way               <= 2'd0;
            ctx_tag               <= {TAG_WIDTH{1'b0}};
            ctx_victim_tag        <= {TAG_WIDTH{1'b0}};
            ctx_victim_line       <= 256'd0;
            maint_pending_clear   <= 1'b0;
            maint_pending_flush   <= 1'b0;
            maint_is_flush        <= 1'b0;
            maint_is_init         <= 1'b1;
            maint_range_start     <= 22'd0;
            maint_range_end       <= {22{1'b1}};
            scan_set              <= {INDEX_WIDTH{1'b0}};
            scan_way              <= 2'd0;
            maint_busy            <= 1'b1;
            maint_done            <= 1'b0;
            maint_error           <= 1'b0;
            stat_hit_count        <= 32'd0;
            stat_miss_count       <= 32'd0;
            stat_bypass_count     <= 32'd0;
            stat_writeback_count  <= 32'd0;
            p0_read_pending       <= 1'b0;
            p1_read_pending       <= 1'b0;
            p0_read_way           <= 2'd0;
            p1_read_way           <= 2'd0;
            p0_read_word          <= 3'd0;
            p1_read_word          <= 3'd0;
        end else begin
            maint_done <= 1'b0;

            if (cache_clr)
                maint_pending_clear <= 1'b1;
            if (cache_flush)
                maint_pending_flush <= 1'b1;

            if (p0_rsp_valid && p0_rsp_ready)
                p0_rsp_valid <= 1'b0;
            if (p1_rsp_valid && p1_rsp_ready)
                p1_rsp_valid <= 1'b0;

            case ({p1_hit_event, p0_hit_event})
                2'b01, 2'b10: stat_hit_count <= stat_hit_count + 1'b1;
                2'b11:        stat_hit_count <= stat_hit_count + 2'd2;
                default: begin end
            endcase
            case ({p1_miss_event, p0_miss_event})
                2'b01, 2'b10: stat_miss_count <= stat_miss_count + 1'b1;
                2'b11:        stat_miss_count <= stat_miss_count + 2'd2;
                default: begin end
            endcase
            case ({p1_bypass_event, p0_bypass_event})
                2'b01, 2'b10: stat_bypass_count <= stat_bypass_count + 1'b1;
                2'b11:        stat_bypass_count <= stat_bypass_count + 2'd2;
                default: begin end
            endcase

            if (p0_read_pending) begin
                p0_rsp_valid <= 1'b1;
                p0_rsp_resp  <= AXI_OKAY;
                p0_rsp_rdata <= data_rdata_a[p0_read_way][p0_read_word];
                p0_read_pending <= 1'b0;
            end

            if (p1_read_pending) begin
                p1_rsp_valid <= 1'b1;
                p1_rsp_resp  <= AXI_OKAY;
                p1_rsp_rdata <= data_rdata_b[p1_read_way][p1_read_word];
                p1_read_pending <= 1'b0;
            end

            if (p0_fire && p0_fast) begin
                if (p0_req_write) begin
                    p0_rsp_valid <= 1'b1;
                    p0_rsp_resp  <= AXI_OKAY;
                    p0_rsp_rdata <= {DATA_WIDTH{1'b0}};
                    dirty_mem[p0_set][p0_hit_way] <= 1'b1;
                end else begin
                    p0_read_pending <= 1'b1;
                    p0_read_way     <= p0_hit_way;
                    p0_read_word    <= p0_word;
                end
            end

            if (p1_fire && p1_fast) begin
                if (p1_req_write) begin
                    p1_rsp_valid <= 1'b1;
                    p1_rsp_resp  <= AXI_OKAY;
                    p1_rsp_rdata <= {DATA_WIDTH{1'b0}};
                    dirty_mem[p1_set][p1_hit_way] <= 1'b1;
                end else begin
                    p1_read_pending <= 1'b1;
                    p1_read_way     <= p1_hit_way;
                    p1_read_word    <= p1_word;
                end
            end

            if (p0_fire && p0_cacheable && p0_hit) begin
                if (lfu_count[p0_set][p0_hit_way] != 8'hff)
                    lfu_count[p0_set][p0_hit_way] <= lfu_count[p0_set][p0_hit_way] + 1'b1;
            end
            if (p1_fire && p1_cacheable && p1_hit) begin
                if (lfu_count[p1_set][p1_hit_way] != 8'hff)
                    lfu_count[p1_set][p1_hit_way] <= lfu_count[p1_set][p1_hit_way] + 1'b1;
            end

            if (p0_fire && p0_cacheable && p0_hit &&
                p1_fire && p1_cacheable && p1_hit && (p0_set == p1_set)) begin
                lru_stamp[p0_set][p0_hit_way] <= lru_clock[p0_set] + 1'b1;
                lru_stamp[p1_set][p1_hit_way] <= lru_clock[p0_set] + 2'd2;
                lru_clock[p0_set] <= lru_clock[p0_set] + 2'd2;
            end else begin
                if (p0_fire && p0_cacheable && p0_hit) begin
                    lru_stamp[p0_set][p0_hit_way] <= lru_clock[p0_set] + 1'b1;
                    lru_clock[p0_set] <= lru_clock[p0_set] + 1'b1;
                end
                if (p1_fire && p1_cacheable && p1_hit) begin
                    lru_stamp[p1_set][p1_hit_way] <= lru_clock[p1_set] + 1'b1;
                    lru_clock[p1_set] <= lru_clock[p1_set] + 1'b1;
                end
            end

            case (op_state)
                OP_IDLE: begin
                    if ((maint_pending_flush || maint_pending_clear) &&
                        p0_idle && p1_idle && !p0_rsp_valid && !p1_rsp_valid) begin
                        maint_busy        <= 1'b1;
                        maint_error       <= 1'b0;
                        maint_is_init     <= 1'b0;
                        scan_set          <= {INDEX_WIDTH{1'b0}};
                        scan_way          <= 2'd0;
                        if (maint_pending_flush) begin
                            maint_is_flush      <= 1'b1;
                            maint_range_start   <= flush_adr_start;
                            maint_range_end     <= flush_adr_end;
                            maint_pending_flush <= 1'b0;
                            maint_pending_clear <= 1'b0;
                        end else begin
                            maint_is_flush      <= 1'b0;
                            maint_range_start   <= clr_adr_start;
                            maint_range_end     <= clr_adr_end;
                            maint_pending_clear <= 1'b0;
                        end
                        op_state <= OP_MAINT_SCAN;
                    end else if (p0_fire && !p0_fast) begin
                        ctx_owner         <= 1'b0;
                        ctx_write         <= p0_req_write;
                        ctx_cacheable     <= p0_cacheable;
                        ctx_wr_mode       <= wr_mode;
                        ctx_addr          <= p0_req_addr;
                        ctx_wdata         <= p0_req_wdata;
                        ctx_wstrb         <= p0_req_wstrb;
                        ctx_set           <= p0_set;
                        ctx_word          <= p0_word;
                        ctx_tag           <= p0_tag;
                        ctx_wb_for_wt_hit <= 1'b0;

                        if (!p0_cacheable ||
                            (!p0_hit && ((!p0_req_write && !rd_alct_en) ||
                                        (p0_req_write && !wr_alct_en)))) begin
                            op_state <= OP_DIRECT_REQ;
                        end else if (p0_hit && p0_req_write && !wr_mode) begin
                            ctx_way <= p0_hit_way;
                            ctx_victim_tag <= p0_tag;
                            if (dirty_mem[p0_set][p0_hit_way]) begin
                                ctx_wb_for_wt_hit <= 1'b1;
                                op_state <= OP_DATA_WAIT;
                            end else begin
                                op_state <= OP_WT_REQ;
                            end
                        end else begin
                            ctx_way          <= p0_victim_way;
                            ctx_victim_tag   <= tag_mem[p0_set][p0_victim_way];
                            if (valid_mem[p0_set][p0_victim_way] &&
                                dirty_mem[p0_set][p0_victim_way])
                                op_state <= OP_DATA_WAIT;
                            else
                                op_state <= OP_REFILL_REQ;
                        end
                    end else if (p1_fire && !p1_fast) begin
                        ctx_owner         <= 1'b1;
                        ctx_write         <= p1_req_write;
                        ctx_cacheable     <= p1_cacheable;
                        ctx_wr_mode       <= wr_mode;
                        ctx_addr          <= p1_req_addr;
                        ctx_wdata         <= p1_req_wdata;
                        ctx_wstrb         <= p1_req_wstrb;
                        ctx_set           <= p1_set;
                        ctx_word          <= p1_word;
                        ctx_tag           <= p1_tag;
                        ctx_wb_for_wt_hit <= 1'b0;

                        if (!p1_cacheable ||
                            (!p1_hit && ((!p1_req_write && !rd_alct_en) ||
                                        (p1_req_write && !wr_alct_en)))) begin
                            op_state <= OP_DIRECT_REQ;
                        end else if (p1_hit && p1_req_write && !wr_mode) begin
                            ctx_way <= p1_hit_way;
                            ctx_victim_tag <= p1_tag;
                            if (dirty_mem[p1_set][p1_hit_way]) begin
                                ctx_wb_for_wt_hit <= 1'b1;
                                op_state <= OP_DATA_WAIT;
                            end else begin
                                op_state <= OP_WT_REQ;
                            end
                        end else begin
                            ctx_way          <= p1_victim_way;
                            ctx_victim_tag   <= tag_mem[p1_set][p1_victim_way];
                            if (valid_mem[p1_set][p1_victim_way] &&
                                dirty_mem[p1_set][p1_victim_way])
                                op_state <= OP_DATA_WAIT;
                            else
                                op_state <= OP_REFILL_REQ;
                        end
                    end
                end

                OP_DATA_WAIT: begin
                    if (ctx_owner == 1'b0) begin
                        if (ctx_wb_for_wt_hit)
                            ctx_victim_line <= merge_line_word(port_a_line(ctx_way),
                                                               ctx_word, ctx_wdata,
                                                               ctx_wstrb);
                        else
                            ctx_victim_line <= port_a_line(ctx_way);
                    end else begin
                        if (ctx_wb_for_wt_hit)
                            ctx_victim_line <= merge_line_word(port_b_line(ctx_way),
                                                               ctx_word, ctx_wdata,
                                                               ctx_wstrb);
                        else
                            ctx_victim_line <= port_b_line(ctx_way);
                    end
                    op_state <= OP_WB_REQ;
                end

                OP_WB_REQ: begin
                    if (mem_cmd_valid && mem_cmd_ready) begin
                        stat_writeback_count <= stat_writeback_count + 1'b1;
                        op_state <= OP_WB_WAIT;
                    end
                end

                OP_WB_WAIT: begin
                    if (mem_rsp_valid && mem_rsp_ready) begin
                        if (ctx_wb_for_wt_hit) begin
                            dirty_mem[ctx_set][ctx_way] <= mem_rsp_error;
                            if (ctx_owner == 1'b0) begin
                                p0_rsp_valid <= 1'b1;
                                p0_rsp_rdata <= {DATA_WIDTH{1'b0}};
                                p0_rsp_resp  <= mem_rsp_error ? AXI_SLVERR : AXI_OKAY;
                            end else begin
                                p1_rsp_valid <= 1'b1;
                                p1_rsp_rdata <= {DATA_WIDTH{1'b0}};
                                p1_rsp_resp  <= mem_rsp_error ? AXI_SLVERR : AXI_OKAY;
                            end
                            op_state <= OP_IDLE;
                        end else if (mem_rsp_error) begin
                            if (ctx_owner == 1'b0) begin
                                p0_rsp_valid <= 1'b1;
                                p0_rsp_resp  <= AXI_SLVERR;
                            end else begin
                                p1_rsp_valid <= 1'b1;
                                p1_rsp_resp  <= AXI_SLVERR;
                            end
                            op_state <= OP_IDLE;
                        end else begin
                            op_state <= OP_REFILL_REQ;
                        end
                    end
                end

                OP_REFILL_REQ: begin
                    if (mem_cmd_valid && mem_cmd_ready)
                        op_state <= OP_REFILL_WAIT;
                end

                OP_REFILL_WAIT: begin
                    if (mem_rsp_valid && mem_rsp_ready) begin
                        if (mem_rsp_error) begin
                            if (ctx_owner == 1'b0) begin
                                p0_rsp_valid <= 1'b1;
                                p0_rsp_resp  <= AXI_SLVERR;
                            end else begin
                                p1_rsp_valid <= 1'b1;
                                p1_rsp_resp  <= AXI_SLVERR;
                            end
                        end else begin
                            valid_mem[ctx_set][ctx_way] <= 1'b1;
                            tag_mem[ctx_set][ctx_way]   <= ctx_tag;
                            lfu_count[ctx_set][ctx_way] <= 8'd1;
                            lru_stamp[ctx_set][ctx_way] <= lru_clock[ctx_set] + 1'b1;
                            lru_clock[ctx_set]          <= lru_clock[ctx_set] + 1'b1;
                            if (ctx_write) begin
                                dirty_mem[ctx_set][ctx_way] <= ctx_wr_mode;
                                if (ctx_wr_mode) begin
                                    if (ctx_owner == 1'b0) begin
                                        p0_rsp_valid <= 1'b1;
                                        p0_rsp_rdata <= {DATA_WIDTH{1'b0}};
                                        p0_rsp_resp  <= AXI_OKAY;
                                    end else begin
                                        p1_rsp_valid <= 1'b1;
                                        p1_rsp_rdata <= {DATA_WIDTH{1'b0}};
                                        p1_rsp_resp  <= AXI_OKAY;
                                    end
                                end
                            end else begin
                                dirty_mem[ctx_set][ctx_way] <= 1'b0;
                                if (ctx_owner == 1'b0) begin
                                    p0_rsp_valid <= 1'b1;
                                    p0_rsp_rdata <= line_word(mem_rsp_rline, ctx_word);
                                    p0_rsp_resp  <= AXI_OKAY;
                                end else begin
                                    p1_rsp_valid <= 1'b1;
                                    p1_rsp_rdata <= line_word(mem_rsp_rline, ctx_word);
                                    p1_rsp_resp  <= AXI_OKAY;
                                end
                            end
                        end

                        if (!mem_rsp_error && ctx_write && !ctx_wr_mode)
                            op_state <= OP_WT_REQ;
                        else
                            op_state <= OP_IDLE;
                    end
                end

                OP_DIRECT_REQ: begin
                    if (mem_cmd_valid && mem_cmd_ready)
                        op_state <= OP_DIRECT_WAIT;
                end

                OP_DIRECT_WAIT: begin
                    if (mem_rsp_valid && mem_rsp_ready) begin
                        if (ctx_owner == 1'b0) begin
                            p0_rsp_valid <= 1'b1;
                            p0_rsp_rdata <= mem_rsp_rdata;
                            p0_rsp_resp  <= mem_rsp_error ? AXI_SLVERR : AXI_OKAY;
                        end else begin
                            p1_rsp_valid <= 1'b1;
                            p1_rsp_rdata <= mem_rsp_rdata;
                            p1_rsp_resp  <= mem_rsp_error ? AXI_SLVERR : AXI_OKAY;
                        end
                        op_state <= OP_IDLE;
                    end
                end

                OP_WT_REQ: begin
                    if (mem_cmd_valid && mem_cmd_ready)
                        op_state <= OP_WT_WAIT;
                end

                OP_WT_WAIT: begin
                    if (mem_rsp_valid && mem_rsp_ready) begin
                        dirty_mem[ctx_set][ctx_way] <= mem_rsp_error;
                        if (ctx_owner == 1'b0) begin
                            p0_rsp_valid <= 1'b1;
                            p0_rsp_rdata <= {DATA_WIDTH{1'b0}};
                            p0_rsp_resp  <= mem_rsp_error ? AXI_SLVERR : AXI_OKAY;
                        end else begin
                            p1_rsp_valid <= 1'b1;
                            p1_rsp_rdata <= {DATA_WIDTH{1'b0}};
                            p1_rsp_resp  <= mem_rsp_error ? AXI_SLVERR : AXI_OKAY;
                        end
                        op_state <= OP_IDLE;
                    end
                end

                OP_MAINT_SCAN: begin
                    if (maint_is_init) begin
                        valid_mem[scan_set][scan_way] <= 1'b0;
                        dirty_mem[scan_set][scan_way] <= 1'b0;
                        lfu_count[scan_set][scan_way] <= 8'd0;
                        lru_stamp[scan_set][scan_way] <= 16'd0;
                        if (scan_way == 2'd0)
                            lru_clock[scan_set] <= 16'd0;
                    end else if (valid_mem[scan_set][scan_way] &&
                                 (scan_line_addr[31:10] >= maint_range_start) &&
                                 (scan_line_addr[31:10] <= maint_range_end)) begin
                        if (maint_is_flush && dirty_mem[scan_set][scan_way]) begin
                            op_state <= OP_MAINT_WB_REQ;
                        end else begin
                            valid_mem[scan_set][scan_way] <= 1'b0;
                            dirty_mem[scan_set][scan_way] <= 1'b0;
                        end
                    end

                    if (!(valid_mem[scan_set][scan_way] && !maint_is_init &&
                          maint_is_flush && dirty_mem[scan_set][scan_way] &&
                          (scan_line_addr[31:10] >= maint_range_start) &&
                          (scan_line_addr[31:10] <= maint_range_end))) begin
                        if ((scan_set == SETS-1) && (scan_way == WAYS-1)) begin
                            maint_busy    <= 1'b0;
                            maint_done    <= 1'b1;
                            maint_is_init <= 1'b0;
                            op_state      <= OP_IDLE;
                        end else if (scan_way == WAYS-1) begin
                            scan_way <= 2'd0;
                            scan_set <= scan_set + 1'b1;
                        end else begin
                            scan_way <= scan_way + 1'b1;
                        end
                    end
                end

                OP_MAINT_WB_REQ: begin
                    if (mem_cmd_valid && mem_cmd_ready) begin
                        stat_writeback_count <= stat_writeback_count + 1'b1;
                        op_state <= OP_MAINT_WB_WAIT;
                    end
                end

                OP_MAINT_WB_WAIT: begin
                    if (mem_rsp_valid && mem_rsp_ready) begin
                        if (mem_rsp_error)
                            maint_error <= 1'b1;
                        else begin
                            valid_mem[scan_set][scan_way] <= 1'b0;
                            dirty_mem[scan_set][scan_way] <= 1'b0;
                        end

                        if ((scan_set == SETS-1) && (scan_way == WAYS-1)) begin
                            maint_busy <= 1'b0;
                            maint_done <= 1'b1;
                            op_state   <= OP_IDLE;
                        end else if (scan_way == WAYS-1) begin
                            scan_way <= 2'd0;
                            scan_set <= scan_set + 1'b1;
                            op_state <= OP_MAINT_SCAN;
                        end else begin
                            scan_way <= scan_way + 1'b1;
                            op_state <= OP_MAINT_SCAN;
                        end
                    end
                end

                default: op_state <= OP_IDLE;
            endcase
        end
    end

endmodule
