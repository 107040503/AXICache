`timescale 1ns/1ps

module tb_cache_fpga_bist;

    reg clk;
    reg rst_n;
    wire bist_done;
    wire bist_pass;
    wire bist_fail;
    wire [7:0] bist_state;
    wire [7:0] error_code;
    wire maint_busy;
    wire [31:0] stat_hit_count;
    wire [31:0] stat_miss_count;
    wire [31:0] stat_writeback_count;
    wire [31:0] memory_read_bursts;
    wire [31:0] memory_write_bursts;

    integer cycles;

    always #5 clk = ~clk;

    cache_fpga_bist_subsystem dut (
        .clk(clk), .rst_n(rst_n),
        .bist_done(bist_done), .bist_pass(bist_pass), .bist_fail(bist_fail),
        .bist_state(bist_state), .error_code(error_code),
        .maint_busy(maint_busy),
        .stat_hit_count(stat_hit_count), .stat_miss_count(stat_miss_count),
        .stat_writeback_count(stat_writeback_count),
        .memory_read_bursts(memory_read_bursts),
        .memory_write_bursts(memory_write_bursts)
    );

    initial begin
        $dumpfile("fpga/kc705/sim/cache_fpga_bist.vcd");
        $dumpvars(1, tb_cache_fpga_bist);

        clk = 1'b0;
        rst_n = 1'b0;
        cycles = 0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;

        while (!bist_done && cycles < 20000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        $display("BIST state=%0d error=0x%02x pass=%b fail=%b", 
                 bist_state, error_code, bist_pass, bist_fail);
        $display("BIST stats hit=%0d miss=%0d writeback=%0d mem_read=%0d mem_write=%0d",
                 stat_hit_count, stat_miss_count, stat_writeback_count,
                 memory_read_bursts, memory_write_bursts);

        if (!bist_done)
            $fatal(1, "KC705 BIST timeout");
        if (!bist_pass || bist_fail || (error_code != 8'd0))
            $fatal(1, "KC705 BIST failed with code 0x%02x", error_code);

        $display("KC705_BIST_SIM_PASS");
        #20;
        $finish;
    end

endmodule

