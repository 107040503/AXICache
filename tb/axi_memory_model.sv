`timescale 1ns/1ps

module axi_memory_model #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer ID_WIDTH   = 4,
    parameter integer MEM_BYTES  = 1024*1024
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
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
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output reg  [ID_WIDTH-1:0]      s_axi_rid,
    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rlast,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,

    output reg  [31:0]              read_burst_count,
    output reg  [31:0]              write_burst_count
);

    localparam [1:0] AXI_OKAY   = 2'b00;
    localparam [1:0] AXI_SLVERR = 2'b10;

    reg [7:0] mem [0:MEM_BYTES-1];
    reg write_active;
    reg [ID_WIDTH-1:0] write_id;
    reg [ADDR_WIDTH-1:0] write_addr;
    reg [7:0] write_len;
    reg [7:0] write_beat;
    reg [2:0] write_size;
    reg [1:0] write_burst;

    reg read_active;
    reg [ID_WIDTH-1:0] read_id;
    reg [ADDR_WIDTH-1:0] read_addr;
    reg [7:0] read_len;
    reg [7:0] read_beat;
    reg [2:0] read_size;
    reg [1:0] read_burst;

    integer init_i;
    integer byte_i;

    assign s_axi_awready = !write_active && !s_axi_bvalid;
    assign s_axi_wready  = write_active && !s_axi_bvalid;
    assign s_axi_arready = !read_active && !s_axi_rvalid;

    function automatic [ADDR_WIDTH-1:0] next_addr;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0] size;
        input [1:0] burst;
        begin
            if (burst == 2'b00)
                next_addr = addr;
            else
                next_addr = addr + ({{(ADDR_WIDTH-1){1'b0}}, 1'b1} << size);
        end
    endfunction

    function automatic [31:0] get_word;
        input integer address;
        begin
            get_word = {mem[address+3], mem[address+2], mem[address+1], mem[address]};
        end
    endfunction

    task automatic set_word;
        input integer address;
        input [31:0] value;
        begin
            mem[address]   = value[7:0];
            mem[address+1] = value[15:8];
            mem[address+2] = value[23:16];
            mem[address+3] = value[31:24];
        end
    endtask

    initial begin
        for (init_i = 0; init_i < MEM_BYTES; init_i = init_i + 1)
            mem[init_i] = init_i[7:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_active     <= 1'b0;
            write_id         <= {ID_WIDTH{1'b0}};
            write_addr       <= {ADDR_WIDTH{1'b0}};
            write_len        <= 8'd0;
            write_beat       <= 8'd0;
            write_size       <= 3'd0;
            write_burst      <= 2'd0;
            s_axi_bid        <= {ID_WIDTH{1'b0}};
            s_axi_bresp      <= AXI_OKAY;
            s_axi_bvalid     <= 1'b0;
            read_active      <= 1'b0;
            read_id          <= {ID_WIDTH{1'b0}};
            read_addr        <= {ADDR_WIDTH{1'b0}};
            read_len         <= 8'd0;
            read_beat        <= 8'd0;
            read_size        <= 3'd0;
            read_burst       <= 2'd0;
            s_axi_rid        <= {ID_WIDTH{1'b0}};
            s_axi_rdata      <= {DATA_WIDTH{1'b0}};
            s_axi_rresp      <= AXI_OKAY;
            s_axi_rlast      <= 1'b0;
            s_axi_rvalid     <= 1'b0;
            read_burst_count <= 32'd0;
            write_burst_count <= 32'd0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                write_active <= 1'b1;
                write_id     <= s_axi_awid;
                write_addr   <= s_axi_awaddr;
                write_len    <= s_axi_awlen;
                write_beat   <= 8'd0;
                write_size   <= s_axi_awsize;
                write_burst  <= s_axi_awburst;
                write_burst_count <= write_burst_count + 1'b1;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                if ((write_addr + DATA_WIDTH/8) <= MEM_BYTES) begin
                    for (byte_i = 0; byte_i < DATA_WIDTH/8; byte_i = byte_i + 1) begin
                        if (s_axi_wstrb[byte_i])
                            mem[write_addr + byte_i] <= s_axi_wdata[byte_i*8 +: 8];
                    end
                end

                if (s_axi_wlast || (write_beat == write_len)) begin
                    write_active <= 1'b0;
                    s_axi_bid    <= write_id;
                    s_axi_bresp  <= (s_axi_wlast == (write_beat == write_len)) ?
                                    AXI_OKAY : AXI_SLVERR;
                    s_axi_bvalid <= 1'b1;
                end else begin
                    write_beat <= write_beat + 1'b1;
                    write_addr <= next_addr(write_addr, write_size, write_burst);
                end
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                s_axi_bresp  <= AXI_OKAY;
            end

            if (s_axi_arvalid && s_axi_arready) begin
                read_active <= 1'b1;
                read_id     <= s_axi_arid;
                read_addr   <= s_axi_araddr;
                read_len    <= s_axi_arlen;
                read_beat   <= 8'd0;
                read_size   <= s_axi_arsize;
                read_burst  <= s_axi_arburst;
                read_burst_count <= read_burst_count + 1'b1;
            end

            if (read_active && !s_axi_rvalid) begin
                s_axi_rid    <= read_id;
                s_axi_rdata  <= (read_addr + DATA_WIDTH/8 <= MEM_BYTES) ?
                                get_word(read_addr) : {DATA_WIDTH{1'b0}};
                s_axi_rresp  <= (read_addr + DATA_WIDTH/8 <= MEM_BYTES) ?
                                AXI_OKAY : AXI_SLVERR;
                s_axi_rlast  <= (read_beat == read_len);
                s_axi_rvalid <= 1'b1;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                if (s_axi_rlast) begin
                    read_active <= 1'b0;
                    s_axi_rlast <= 1'b0;
                end else begin
                    read_beat <= read_beat + 1'b1;
                    read_addr <= next_addr(read_addr, read_size, read_burst);
                end
            end
        end
    end

endmodule

