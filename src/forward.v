module forward (
    input  [4:0] idex_rs1, idex_rs2,      // registers needed in EX
    input  [4:0] exmem_rd, memwb_rd,      // destinations in MEM and WB
    input        exmem_reg_write,          // is MEM stage writing?
    input        memwb_reg_write,          // is WB stage writing?
    output reg [1:0] fwd_a, fwd_b         // forwarding selectors
);
    // 00 = use register file output (no forwarding)
    // 01 = forward from MEM/WB
    // 10 = forward from EX/MEM (higher priority — more recent)

    always @(*) begin
        // Forward A (rs1)
        if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs1)
            fwd_a = 2'b10;  // forward from EX/MEM
        else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs1)
            fwd_a = 2'b01;  // forward from MEM/WB
        else
            fwd_a = 2'b00;  // no forwarding needed

        // Forward B (rs2)
        if (exmem_reg_write && exmem_rd != 0 && exmem_rd == idex_rs2)
            fwd_b = 2'b10;
        else if (memwb_reg_write && memwb_rd != 0 && memwb_rd == idex_rs2)
            fwd_b = 2'b01;
        else
            fwd_b = 2'b00;
    end
endmodule
