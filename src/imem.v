// no cache implementation
// module imem (
//     input  [31:0] addr,
//     output [31:0] instr
// );
//     reg [31:0] mem [0:255];
//     initial $readmemh("programs/test.hex", mem);
//     assign instr = mem[addr[31:2]];
// endmodule

// With Cache:
// Instruction cache + main memory
    icache ICACHE (
        .clk(clk), .rst(rst),
        .addr(pc),
        .data_out(icache_data_out),
        .hit(icache_hit),
        .mem_data(imem_data_out),
        .mem_ready(imem_ready),
        .mem_req(icache_mem_req)
    );

    main_mem IMEM (
        .clk(clk), .rst(rst),
        .addr(pc),
        .data_in(32'b0),
        .we(1'b0),
        .req(icache_mem_req),
        .data_out(imem_data_out),
        .ready(imem_ready)
    );

    // Use icache output instead of direct imem
    assign instr_if = icache_hit ? icache_data_out : 32'h00000013; // NOP on miss