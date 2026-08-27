`timescale 1ns/1ps

module cache_sram_tdp #(
    parameter integer DATA_WIDTH = 32,
    parameter integer DEPTH      = 256,
    parameter integer ADDR_WIDTH = $clog2(DEPTH)
) (
    input  wire                      clk,

    input  wire                      en_a,
    input  wire                      we_a,
    input  wire [DATA_WIDTH/8-1:0]   be_a,
    input  wire [ADDR_WIDTH-1:0]     addr_a,
    input  wire [DATA_WIDTH-1:0]     wdata_a,
    output reg  [DATA_WIDTH-1:0]     rdata_a,

    input  wire                      en_b,
    input  wire                      we_b,
    input  wire [DATA_WIDTH/8-1:0]   be_b,
    input  wire [ADDR_WIDTH-1:0]     addr_b,
    input  wire [DATA_WIDTH-1:0]     wdata_b,
    output reg  [DATA_WIDTH-1:0]     rdata_b
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer byte_idx;

    always @(posedge clk) begin
        if (en_a) begin
            rdata_a <= mem[addr_a];
            if (we_a) begin
                for (byte_idx = 0; byte_idx < DATA_WIDTH/8; byte_idx = byte_idx + 1) begin
                    if (be_a[byte_idx])
                        mem[addr_a][byte_idx*8 +: 8] <= wdata_a[byte_idx*8 +: 8];
                end
            end
        end
    end

    always @(posedge clk) begin
        if (en_b) begin
            rdata_b <= mem[addr_b];
            if (we_b) begin
                for (byte_idx = 0; byte_idx < DATA_WIDTH/8; byte_idx = byte_idx + 1) begin
                    if (be_b[byte_idx])
                        mem[addr_b][byte_idx*8 +: 8] <= wdata_b[byte_idx*8 +: 8];
                end
            end
        end
    end

endmodule
