// No cache implementation:
// module dmem (
//     input         clk,
//     input         we,
//     input  [31:0] addr, wd,
//     output [31:0] rd
// );
//     reg [31:0] mem [0:255];
//     assign rd = mem[addr[31:2]];
//     always @(posedge clk)
//         if (we) mem[addr[31:2]] <= wd;
// endmodule

// with cache implementation:
// Data cache + main memory
    dcache DCACHE (
        .clk(clk), .rst(rst),
        .addr(exmem_alu_result),
        .data_in(exmem_rd2),
        .mem_read(exmem_mem_read),
        .mem_write(exmem_mem_write),
        .data_out(dcache_data_out),
        .hit(dcache_hit),
        .mem_data(dmem_data_out),
        .mem_ready(dmem_ready),
        .mem_req(dcache_mem_req)
    );

    main_mem DMEM (
        .clk(clk), .rst(rst),
        .addr(exmem_alu_result),
        .data_in(exmem_rd2),
        .we(exmem_mem_write && dcache_hit),
        .req(dcache_mem_req),
        .data_out(dmem_data_out),
        .ready(dmem_ready)
    );

    // Use dcache output for MEM stage
    assign mem_out_mem = dcache_data_out;