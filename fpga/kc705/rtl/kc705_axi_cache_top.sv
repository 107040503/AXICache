`timescale 1ns/1ps

module kc705_axi_cache_top (
    input  wire       clk_p,
    input  wire       clk_n,
    input  wire       reset,
    output wire [7:0] leds
);

    wire clk_200mhz;
    wire clk_100mhz_mmcm;
    wire clk_100mhz;
    wire clk_feedback;
    wire clk_feedback_buf;
    wire mmcm_locked;

    reg [2:0] reset_pipe;
    wire rst_n = reset_pipe[2];
    wire reset_async = reset || !mmcm_locked;
    reg [28:0] bist_start_counter;
    wire bist_rst_n = rst_n && (&bist_start_counter);

    (* mark_debug = "true" *) wire bist_done;
    (* mark_debug = "true" *) wire bist_pass;
    (* mark_debug = "true" *) wire bist_fail;
    (* mark_debug = "true" *) wire [7:0] bist_state;
    (* mark_debug = "true" *) wire [7:0] error_code;
    (* mark_debug = "true" *) wire maint_busy;
    (* mark_debug = "true" *) wire [31:0] stat_hit_count;
    (* mark_debug = "true" *) wire [31:0] stat_miss_count;
    (* mark_debug = "true" *) wire [31:0] stat_writeback_count;
    (* mark_debug = "true" *) wire [31:0] memory_read_bursts;
    (* mark_debug = "true" *) wire [31:0] memory_write_bursts;

    reg [26:0] heartbeat_counter;
    wire [7:0] status_vector = {
        heartbeat_counter[26], bist_fail, bist_pass, bist_done,
        (bist_rst_n && !bist_done), maint_busy, bist_rst_n, mmcm_locked
    };

    IBUFDS #(
        .DIFF_TERM("TRUE"),
        .IBUF_LOW_PWR("FALSE"),
        .IOSTANDARD("DIFF_SSTL15")
    ) u_sysclk_ibufds (
        .I(clk_p),
        .IB(clk_n),
        .O(clk_200mhz)
    );

    BUFG u_clkfb_bufg (
        .I(clk_feedback),
        .O(clk_feedback_buf)
    );

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(5.000),
        .CLKIN1_PERIOD(5.000),
        .CLKOUT0_DIVIDE_F(10.000),
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKIN1(clk_200mhz),
        .CLKFBIN(clk_feedback_buf),
        .RST(reset),
        .PWRDWN(1'b0),
        .CLKFBOUT(clk_feedback),
        .CLKOUT0(clk_100mhz_mmcm),
        .LOCKED(mmcm_locked)
    );

    BUFG u_clk100_bufg (
        .I(clk_100mhz_mmcm),
        .O(clk_100mhz)
    );

    always @(posedge clk_100mhz or posedge reset_async) begin
        if (reset_async)
            reset_pipe <= 3'b000;
        else
            reset_pipe <= {reset_pipe[1:0], 1'b1};
    end

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n)
            heartbeat_counter <= 27'd0;
        else
            heartbeat_counter <= heartbeat_counter + 1'b1;
    end

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n)
            bist_start_counter <= 29'd0;
        else if (!(&bist_start_counter))
            bist_start_counter <= bist_start_counter + 1'b1;
    end

    cache_fpga_bist_subsystem u_bist_subsystem (
        .clk(clk_100mhz),
        .rst_n(bist_rst_n),
        .bist_done(bist_done),
        .bist_pass(bist_pass),
        .bist_fail(bist_fail),
        .bist_state(bist_state),
        .error_code(error_code),
        .maint_busy(maint_busy),
        .stat_hit_count(stat_hit_count),
        .stat_miss_count(stat_miss_count),
        .stat_writeback_count(stat_writeback_count),
        .memory_read_bursts(memory_read_bursts),
        .memory_write_bursts(memory_write_bursts)
    );

    assign leds = status_vector;

`ifdef XILINX_ILA
    ila_cache_kc705 u_ila (
        .clk(clk_100mhz),
        .probe0(bist_state),
        .probe1(error_code),
        .probe2(status_vector),
        .probe3(stat_hit_count),
        .probe4(stat_miss_count),
        .probe5(stat_writeback_count),
        .probe6(memory_read_bursts),
        .probe7(memory_write_bursts)
    );
`endif

endmodule
