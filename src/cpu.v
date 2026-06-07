module cpu (input clk, input rst);
    reg  [31:0] pc;
    wire [31:0] instr, rd1, rd2, alu_result, mem_out, imm;
    wire [31:0] write_data, next_pc, branch_target;
    wire        zero, reg_write, alu_src, mem_write, mem_read;
    wire        mem_to_reg, branch, jal;
    wire [3:0]  alu_op;

    assign branch_target = pc + imm;
    assign next_pc = jal                    ? pc + imm :
                     (branch && zero)       ? branch_target :
                                             pc + 4;

    always @(posedge clk or posedge rst)
        pc <= rst ? 32'b0 : next_pc;

    // Instantiate submodules
    imem      IMEM (.addr(pc), .instr(instr));
    regfile   RF   (.clk(clk), .we(reg_write),
                    .rs1(instr[19:15]), .rs2(instr[24:20]), .rd(instr[11:7]),
                    .wd(write_data), .rd1(rd1), .rd2(rd2));
    control   CTRL (.opcode(instr[6:0]), .funct3(instr[14:12]),
                    .funct7(instr[31:25]),
                    .reg_write(reg_write), .alu_src(alu_src),
                    .mem_write(mem_write), .mem_read(mem_read),
                    .mem_to_reg(mem_to_reg), .branch(branch),
                    .jal(jal), .alu_op(alu_op));
    imm_decode IMM (.instr(instr), .imm(imm));
    alu        ALU (.a(rd1), .b(alu_src ? imm : rd2),
                    .op(alu_op), .result(alu_result), .zero(zero));
    dmem       DMEM(.clk(clk), .we(mem_write),
                    .addr(alu_result), .wd(rd2), .rd(mem_out));

    assign write_data = jal        ? pc + 4 :
                        mem_to_reg ? mem_out :
                                     alu_result;
endmodule