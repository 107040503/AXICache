`timescale 1ns/1ps

module axi_bist_master #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     cmd_valid,
    output wire                     cmd_ready,
    input  wire                     cmd_write,
    input  wire [ADDR_WIDTH-1:0]    cmd_addr,
    input  wire [DATA_WIDTH-1:0]    cmd_wdata,
    input  wire [DATA_WIDTH/8-1:0]  cmd_wstrb,
    output reg                      done,
    output reg  [DATA_WIDTH-1:0]    read_data,
    output reg                      error,

    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,

    output wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
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

    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] address_reg;
    reg [DATA_WIDTH-1:0] write_data_reg;
    reg [DATA_WIDTH/8-1:0] write_strobe_reg;

    assign cmd_ready = (state == ST_IDLE);

    assign m_axi_awaddr  = address_reg;
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awvalid = (state == ST_AW);
    assign m_axi_wdata   = write_data_reg;
    assign m_axi_wstrb   = write_strobe_reg;
    assign m_axi_wlast   = 1'b1;
    assign m_axi_wvalid  = (state == ST_W);
    assign m_axi_bready  = (state == ST_B);

    assign m_axi_araddr  = address_reg;
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'd2;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arvalid = (state == ST_AR);
    assign m_axi_rready  = (state == ST_R);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            address_reg      <= {ADDR_WIDTH{1'b0}};
            write_data_reg   <= {DATA_WIDTH{1'b0}};
            write_strobe_reg <= {DATA_WIDTH/8{1'b0}};
            done             <= 1'b0;
            read_data        <= {DATA_WIDTH{1'b0}};
            error            <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (cmd_valid) begin
                        address_reg      <= cmd_addr;
                        write_data_reg   <= cmd_wdata;
                        write_strobe_reg <= cmd_wstrb;
                        error            <= 1'b0;
                        state            <= cmd_write ? ST_AW : ST_AR;
                    end
                end

                ST_AW: begin
                    if (m_axi_awvalid && m_axi_awready)
                        state <= ST_W;
                end

                ST_W: begin
                    if (m_axi_wvalid && m_axi_wready)
                        state <= ST_B;
                end

                ST_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        error <= (m_axi_bresp != 2'b00);
                        done  <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_AR: begin
                    if (m_axi_arvalid && m_axi_arready)
                        state <= ST_R;
                end

                ST_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        read_data <= m_axi_rdata;
                        error     <= (m_axi_rresp != 2'b00) || !m_axi_rlast;
                        done      <= 1'b1;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

