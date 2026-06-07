module cpu_tb;
    reg clk, rst;
    pipeline_cpu DUT (.clk(clk), .rst(rst));

    initial clk = 0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst) begin
            if (DUT.icache_mem_req && !DUT.icache_req_prev && !DUT.exmem_jal && !DUT.exmem_jal_prev && !(DUT.exmem_branch && DUT.exmem_zero) && DUT.cycle_count > 4)
                $display("MISS_COUNT cy=%0d pc=%08h imem_req=%0d exmem_jal=%0d exmem_jal_prev=%0d", DUT.cycle_count, DUT.pc, DUT.icache_mem_req, DUT.exmem_jal, DUT.exmem_jal_prev);
            $display("CY=%0d PC=%08h WBrd=%0d WBdata=%08h WBwe=%0d exmem_memw=%0d exmem_memr=%0d exmem_rd2=%08h dcache_hit=%0d",
                DUT.cycle_count, DUT.pc,
                DUT.memwb_rd, DUT.write_data_wb, DUT.memwb_reg_write,
                DUT.exmem_mem_write, DUT.exmem_mem_read,
                DUT.exmem_rd2, DUT.dcache_hit);
        end
    end

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);
        rst = 1; #15; rst = 0;
        #5000;
        $display("FINAL: cycles=%0d imiss=%0d dmiss=%0d",
                 DUT.cycle_count,
                 DUT.icache_miss_count,
                 DUT.dcache_miss_count);
        $finish;
    end
endmodule