`timescale 1ns/1ps

module cache_bist_controller (
    input  wire         clk,
    input  wire         rst_n,

    output reg          p0_cmd_valid,
    input  wire         p0_cmd_ready,
    output reg          p0_cmd_write,
    output reg  [31:0]  p0_cmd_addr,
    output reg  [31:0]  p0_cmd_wdata,
    output reg  [3:0]   p0_cmd_wstrb,
    input  wire         p0_done,
    input  wire [31:0]  p0_read_data,
    input  wire         p0_error,

    output reg          p1_cmd_valid,
    input  wire         p1_cmd_ready,
    output reg          p1_cmd_write,
    output reg  [31:0]  p1_cmd_addr,
    output reg  [31:0]  p1_cmd_wdata,
    output reg  [3:0]   p1_cmd_wstrb,
    input  wire         p1_done,
    input  wire [31:0]  p1_read_data,
    input  wire         p1_error,

    input  wire         maint_busy,
    input  wire         maint_done,
    input  wire         maint_error,
    input  wire [31:0]  stat_hit_count,
    input  wire [31:0]  stat_miss_count,
    input  wire [31:0]  stat_writeback_count,

    output wire         cache_en,
    output wire         rd_alct_en,
    output wire         wr_alct_en,
    output reg          wr_mode,
    output wire         replace_mode,
    output wire [21:0]  adr_start,
    output wire [21:0]  adr_end,
    output wire         cache_clr,
    output wire [21:0]  clr_adr_start,
    output wire [21:0]  clr_adr_end,
    output reg          cache_flush,
    output wire [21:0]  flush_adr_start,
    output wire [21:0]  flush_adr_end,

    output reg          bist_done,
    output reg          bist_pass,
    output reg          bist_fail,
    output reg  [7:0]   bist_state,
    output reg  [7:0]   error_code
);

    localparam [7:0] S_WAIT_INIT       = 8'd0;
    localparam [7:0] S_READ1_CMD       = 8'd1;
    localparam [7:0] S_READ1_WAIT      = 8'd2;
    localparam [7:0] S_READ2_CMD       = 8'd3;
    localparam [7:0] S_READ2_WAIT      = 8'd4;
    localparam [7:0] S_WB_WRITE_CMD    = 8'd5;
    localparam [7:0] S_WB_WRITE_WAIT   = 8'd6;
    localparam [7:0] S_WB_READ_CMD     = 8'd7;
    localparam [7:0] S_WB_READ_WAIT    = 8'd8;
    localparam [7:0] S_FLUSH_PULSE     = 8'd9;
    localparam [7:0] S_FLUSH_START     = 8'd10;
    localparam [7:0] S_FLUSH_WAIT      = 8'd11;
    localparam [7:0] S_POST_READ_CMD   = 8'd12;
    localparam [7:0] S_POST_READ_WAIT  = 8'd13;
    localparam [7:0] S_WT_WRITE_CMD    = 8'd14;
    localparam [7:0] S_WT_WRITE_WAIT   = 8'd15;
    localparam [7:0] S_WT_READ_CMD     = 8'd16;
    localparam [7:0] S_WT_READ_WAIT    = 8'd17;
    localparam [7:0] S_PREFILL0_CMD    = 8'd18;
    localparam [7:0] S_PREFILL0_WAIT   = 8'd19;
    localparam [7:0] S_PREFILL1_CMD    = 8'd20;
    localparam [7:0] S_PREFILL1_WAIT   = 8'd21;
    localparam [7:0] S_DUAL_CMD        = 8'd22;
    localparam [7:0] S_DUAL_WAIT       = 8'd23;
    localparam [7:0] S_DONE            = 8'd24;
    localparam [7:0] S_FAIL            = 8'd25;

    reg saw_init_busy;
    reg [23:0] watchdog;

    assign cache_en       = 1'b1;
    assign rd_alct_en     = 1'b1;
    assign wr_alct_en     = 1'b1;
    assign replace_mode   = 1'b1;
    assign adr_start      = 22'd0;
    assign adr_end        = 22'd63;
    assign cache_clr      = 1'b0;
    assign clr_adr_start  = 22'd0;
    assign clr_adr_end    = 22'd63;
    assign flush_adr_start = 22'd0;
    assign flush_adr_end   = 22'd63;

    function automatic [31:0] expected_word;
        input [31:0] byte_address;
        begin
            expected_word = 32'hcafe_0000 ^ (byte_address >> 2);
        end
    endfunction

    task automatic fail_bist;
        input [7:0] code;
        begin
            bist_done  <= 1'b1;
            bist_pass  <= 1'b0;
            bist_fail  <= 1'b1;
            error_code <= code;
            bist_state <= S_FAIL;
        end
    endtask

    always @* begin
        p0_cmd_valid = 1'b0;
        p0_cmd_write = 1'b0;
        p0_cmd_addr  = 32'd0;
        p0_cmd_wdata = 32'd0;
        p0_cmd_wstrb = 4'hf;
        p1_cmd_valid = 1'b0;
        p1_cmd_write = 1'b0;
        p1_cmd_addr  = 32'd0;
        p1_cmd_wdata = 32'd0;
        p1_cmd_wstrb = 4'hf;

        case (bist_state)
            S_READ1_CMD, S_READ2_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_addr  = 32'h0000_0100;
            end
            S_WB_WRITE_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_write = 1'b1;
                p0_cmd_addr  = 32'h0000_0104;
                p0_cmd_wdata = 32'hdead_beef;
            end
            S_WB_READ_CMD, S_POST_READ_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_addr  = 32'h0000_0104;
            end
            S_WT_WRITE_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_write = 1'b1;
                p0_cmd_addr  = 32'h0000_0220;
                p0_cmd_wdata = 32'h1234_5678;
            end
            S_WT_READ_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_addr  = 32'h0000_0220;
            end
            S_PREFILL0_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_addr  = 32'h0000_1400;
            end
            S_PREFILL1_CMD: begin
                p1_cmd_valid = 1'b1;
                p1_cmd_addr  = 32'h0000_3400;
            end
            S_DUAL_CMD: begin
                p0_cmd_valid = 1'b1;
                p0_cmd_addr  = 32'h0000_1400;
                p1_cmd_valid = 1'b1;
                p1_cmd_addr  = 32'h0000_3400;
            end
            default: begin end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bist_state    <= S_WAIT_INIT;
            bist_done     <= 1'b0;
            bist_pass     <= 1'b0;
            bist_fail     <= 1'b0;
            error_code    <= 8'd0;
            cache_flush   <= 1'b0;
            wr_mode       <= 1'b1;
            saw_init_busy <= 1'b0;
            watchdog      <= 24'd0;
        end else begin
            cache_flush <= 1'b0;
            if (!bist_done)
                watchdog <= watchdog + 1'b1;

            if (&watchdog)
                fail_bist(8'he0);
            else begin
                case (bist_state)
                    S_WAIT_INIT: begin
                        if (maint_busy)
                            saw_init_busy <= 1'b1;
                        if (saw_init_busy && !maint_busy)
                            bist_state <= S_READ1_CMD;
                    end

                    S_READ1_CMD: if (p0_cmd_ready) bist_state <= S_READ1_WAIT;
                    S_READ1_WAIT: if (p0_done) begin
                        if (p0_error || (p0_read_data != expected_word(32'h100)))
                            fail_bist(8'h01);
                        else
                            bist_state <= S_READ2_CMD;
                    end

                    S_READ2_CMD: if (p0_cmd_ready) bist_state <= S_READ2_WAIT;
                    S_READ2_WAIT: if (p0_done) begin
                        if (p0_error || (p0_read_data != expected_word(32'h100)))
                            fail_bist(8'h02);
                        else
                            bist_state <= S_WB_WRITE_CMD;
                    end

                    S_WB_WRITE_CMD: if (p0_cmd_ready) bist_state <= S_WB_WRITE_WAIT;
                    S_WB_WRITE_WAIT: if (p0_done) begin
                        if (p0_error)
                            fail_bist(8'h03);
                        else
                            bist_state <= S_WB_READ_CMD;
                    end

                    S_WB_READ_CMD: if (p0_cmd_ready) bist_state <= S_WB_READ_WAIT;
                    S_WB_READ_WAIT: if (p0_done) begin
                        if (p0_error || (p0_read_data != 32'hdead_beef))
                            fail_bist(8'h04);
                        else
                            bist_state <= S_FLUSH_PULSE;
                    end

                    S_FLUSH_PULSE: begin
                        cache_flush <= 1'b1;
                        bist_state  <= S_FLUSH_START;
                    end
                    S_FLUSH_START: if (maint_busy) bist_state <= S_FLUSH_WAIT;
                    S_FLUSH_WAIT: if (maint_done || !maint_busy) begin
                        if (maint_error)
                            fail_bist(8'h05);
                        else
                            bist_state <= S_POST_READ_CMD;
                    end

                    S_POST_READ_CMD: if (p0_cmd_ready) bist_state <= S_POST_READ_WAIT;
                    S_POST_READ_WAIT: if (p0_done) begin
                        if (p0_error || (p0_read_data != 32'hdead_beef))
                            fail_bist(8'h06);
                        else begin
                            wr_mode    <= 1'b0;
                            bist_state <= S_WT_WRITE_CMD;
                        end
                    end

                    S_WT_WRITE_CMD: if (p0_cmd_ready) bist_state <= S_WT_WRITE_WAIT;
                    S_WT_WRITE_WAIT: if (p0_done) begin
                        if (p0_error)
                            fail_bist(8'h07);
                        else
                            bist_state <= S_WT_READ_CMD;
                    end

                    S_WT_READ_CMD: if (p0_cmd_ready) bist_state <= S_WT_READ_WAIT;
                    S_WT_READ_WAIT: if (p0_done) begin
                        if (p0_error || (p0_read_data != 32'h1234_5678))
                            fail_bist(8'h08);
                        else begin
                            wr_mode    <= 1'b1;
                            bist_state <= S_PREFILL0_CMD;
                        end
                    end

                    S_PREFILL0_CMD: if (p0_cmd_ready) bist_state <= S_PREFILL0_WAIT;
                    S_PREFILL0_WAIT: if (p0_done) begin
                        if (p0_error || (p0_read_data != expected_word(32'h1400)))
                            fail_bist(8'h09);
                        else
                            bist_state <= S_PREFILL1_CMD;
                    end

                    S_PREFILL1_CMD: if (p1_cmd_ready) bist_state <= S_PREFILL1_WAIT;
                    S_PREFILL1_WAIT: if (p1_done) begin
                        if (p1_error || (p1_read_data != expected_word(32'h3400)))
                            fail_bist(8'h0a);
                        else
                            bist_state <= S_DUAL_CMD;
                    end

                    S_DUAL_CMD: if (p0_cmd_ready && p1_cmd_ready) bist_state <= S_DUAL_WAIT;
                    S_DUAL_WAIT: if (p0_done || p1_done) begin
                        if (!(p0_done && p1_done))
                            fail_bist(8'h0b);
                        else if (p0_error || p1_error ||
                                 (p0_read_data != expected_word(32'h1400)) ||
                                 (p1_read_data != expected_word(32'h3400)))
                            fail_bist(8'h0c);
                        else if ((stat_hit_count < 32'd4) ||
                                 (stat_miss_count < 32'd4) ||
                                 (stat_writeback_count < 32'd1))
                            fail_bist(8'h0d);
                        else begin
                            bist_done  <= 1'b1;
                            bist_pass  <= 1'b1;
                            bist_state <= S_DONE;
                        end
                    end

                    S_DONE: begin
                        bist_done <= 1'b1;
                        bist_pass <= 1'b1;
                    end
                    S_FAIL: begin
                        bist_done <= 1'b1;
                        bist_fail <= 1'b1;
                    end
                    default: fail_bist(8'hff);
                endcase
            end
        end
    end

endmodule

