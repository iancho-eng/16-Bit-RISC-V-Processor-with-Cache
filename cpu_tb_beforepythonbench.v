module cpu_tb;
    reg clk, rst;
    pipeline_cpu DUT (.clk(clk), .rst(rst));

    initial clk = 0;
    always #5 clk = ~clk;   // 10ns clock period

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);
        rst = 1; #15; rst = 0;
        #500;                // run for 50 cycles
        $finish;
    end
endmodule