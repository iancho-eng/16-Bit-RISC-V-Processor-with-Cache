module hazard (
    input  [4:0] ifid_rs1, ifid_rs2,   // registers being read in ID
    input  [4:0] idex_rd,              // destination of instruction in EX
    input        idex_mem_read,        // is EX stage a load?
    output reg   stall                 // freeze PC and IF/ID, inject bubble
);
    always @(*) begin
        // Only stall for load-use: instruction in EX is a load AND
        // its destination matches either source of the instruction in ID
        if (idex_mem_read &&
            (idex_rd == ifid_rs1 || idex_rd == ifid_rs2))
            stall = 1;
        else
            stall = 0;
    end
endmodule
