module pipeline_cpu (input clk, input rst);

    // ---- IF stage wires ----
    reg  [31:0] pc;
    wire [31:0] instr_if;

    // ---- IF/ID pipeline register ----
    reg [31:0] ifid_instr;
    reg [31:0] ifid_pc;

    // ---- ID stage wires ----
    wire [31:0] rd1_id, rd2_id, imm_id;
    wire        reg_write_id, alu_src_id, mem_write_id;
    wire        mem_read_id, mem_to_reg_id, branch_id, jal_id;
    wire [3:0]  alu_op_id;

    // ---- ID/EX pipeline register ----
    reg [31:0] idex_pc, idex_rd1, idex_rd2, idex_imm;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg        idex_reg_write, idex_alu_src, idex_mem_write;
    reg        idex_mem_read, idex_mem_to_reg, idex_branch, idex_jal;
    reg [3:0]  idex_alu_op;

    // ---- EX stage wires ----
    wire [31:0] alu_result_ex;
    wire        zero_ex;
    wire [31:0] branch_target_ex;

    // ---- EX/MEM pipeline register ----
    reg [31:0] exmem_alu_result, exmem_rd2, exmem_pc;
    reg [4:0]  exmem_rd;
    reg        exmem_reg_write, exmem_mem_write;
    reg        exmem_mem_read, exmem_mem_to_reg, exmem_branch, exmem_jal;
    reg        exmem_zero;

    // ---- MEM stage wires ----
    wire [31:0] mem_out_mem;

    // ---- MEM/WB pipeline register ----
    reg [31:0] memwb_alu_result, memwb_mem_out, memwb_pc;
    reg [4:0]  memwb_rd;
    reg        memwb_reg_write, memwb_mem_to_reg, memwb_jal;

    // ---- Hazard detection unit ----
    wire stall;

    hazard HDU (
        .ifid_rs1(ifid_instr[19:15]),
        .ifid_rs2(ifid_instr[24:20]),
        .idex_rd(idex_rd),
        .idex_mem_read(idex_mem_read),
        .stall(stall)
    );

    // ---- IF stage ----
    imem IMEM (.addr(pc), .instr(instr_if));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc         <= 32'b0;
            ifid_instr <= 32'b0;
            ifid_pc    <= 32'b0;
        end else begin
            if (exmem_branch && exmem_zero)
                pc <= exmem_pc;
            else if (exmem_jal)
                pc <= exmem_pc;
            else if (!stall)
                pc <= pc + 4;

            if (!stall) begin
                ifid_instr <= instr_if;
                ifid_pc    <= pc;
            end
        end
    end

    // ---- ID stage ----
    wire [31:0] write_data_wb;

    control CTRL (
        .opcode(ifid_instr[6:0]), .funct3(ifid_instr[14:12]),
        .funct7(ifid_instr[31:25]),
        .reg_write(reg_write_id), .alu_src(alu_src_id),
        .mem_write(mem_write_id), .mem_read(mem_read_id),
        .mem_to_reg(mem_to_reg_id), .branch(branch_id),
        .jal(jal_id), .alu_op(alu_op_id)
    );

    regfile RF (
        .clk(clk),
        .we(memwb_reg_write),
        .rs1(ifid_instr[19:15]),
        .rs2(ifid_instr[24:20]),
        .rd(memwb_rd),
        .wd(write_data_wb),
        .rd1(rd1_id), .rd2(rd2_id)
    );

    imm_decode IMM (.instr(ifid_instr), .imm(imm_id));

    always @(posedge clk or posedge rst) begin
        if (rst || stall) begin
            idex_pc         <= 0;
            idex_rd1        <= 0;
            idex_rd2        <= 0;
            idex_imm        <= 0;
            idex_rs1        <= 0;
            idex_rs2        <= 0;
            idex_rd         <= 0;
            idex_reg_write  <= 0;
            idex_alu_src    <= 0;
            idex_mem_write  <= 0;
            idex_mem_read   <= 0;
            idex_mem_to_reg <= 0;
            idex_branch     <= 0;
            idex_jal        <= 0;
            idex_alu_op     <= 0;
        end else begin
            idex_pc         <= ifid_pc;
            idex_rd1        <= rd1_id;
            idex_rd2        <= rd2_id;
            idex_imm        <= imm_id;
            idex_rs1        <= ifid_instr[19:15];
            idex_rs2        <= ifid_instr[24:20];
            idex_rd         <= ifid_instr[11:7];
            idex_reg_write  <= reg_write_id;
            idex_alu_src    <= alu_src_id;
            idex_mem_write  <= mem_write_id;
            idex_mem_read   <= mem_read_id;
            idex_mem_to_reg <= mem_to_reg_id;
            idex_branch     <= branch_id;
            idex_jal        <= jal_id;
            idex_alu_op     <= alu_op_id;
        end
    end

    // ---- EX stage ----
    wire [1:0] fwd_a, fwd_b;

    forward FWD (
        .idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
        .exmem_rd(exmem_rd), .memwb_rd(memwb_rd),
        .exmem_reg_write(exmem_reg_write),
        .memwb_reg_write(memwb_reg_write),
        .fwd_a(fwd_a), .fwd_b(fwd_b)
    );

    wire [31:0] alu_a_ex, alu_b_pre, alu_b_ex;

    assign alu_a_ex = (fwd_a == 2'b10) ? exmem_alu_result :
                      (fwd_a == 2'b01) ? write_data_wb    :
                                         idex_rd1;

    assign alu_b_pre = (fwd_b == 2'b10) ? exmem_alu_result :
                       (fwd_b == 2'b01) ? write_data_wb    :
                                          idex_rd2;

    assign alu_b_ex = idex_alu_src ? idex_imm : alu_b_pre;

    assign branch_target_ex = idex_pc + idex_imm;

    alu ALU (
        .a(alu_a_ex), .b(alu_b_ex),
        .op(idex_alu_op),
        .result(alu_result_ex), .zero(zero_ex)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exmem_alu_result <= 0; exmem_rd2 <= 0; exmem_pc <= 0;
            exmem_rd <= 0; exmem_reg_write <= 0; exmem_mem_write <= 0;
            exmem_mem_read <= 0; exmem_mem_to_reg <= 0;
            exmem_branch <= 0; exmem_jal <= 0; exmem_zero <= 0;
        end else begin
            exmem_alu_result <= alu_result_ex;
            exmem_rd2        <= idex_rd2;
            exmem_pc         <= branch_target_ex;
            exmem_rd         <= idex_rd;
            exmem_reg_write  <= idex_reg_write;
            exmem_mem_write  <= idex_mem_write;
            exmem_mem_read   <= idex_mem_read;
            exmem_mem_to_reg <= idex_mem_to_reg;
            exmem_branch     <= idex_branch;
            exmem_jal        <= idex_jal;
            exmem_zero       <= zero_ex;
        end
    end

    // ---- MEM stage ----
    dmem DMEM (
        .clk(clk),
        .we(exmem_mem_write),
        .addr(exmem_alu_result),
        .wd(exmem_rd2),
        .rd(mem_out_mem)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memwb_alu_result <= 0; memwb_mem_out <= 0; memwb_pc <= 0;
            memwb_rd <= 0; memwb_reg_write <= 0;
            memwb_mem_to_reg <= 0; memwb_jal <= 0;
        end else begin
            memwb_alu_result <= exmem_alu_result;
            memwb_mem_out    <= mem_out_mem;
            memwb_pc         <= exmem_pc + 4;
            memwb_rd         <= exmem_rd;
            memwb_reg_write  <= exmem_reg_write;
            memwb_mem_to_reg <= exmem_mem_to_reg;
            memwb_jal        <= exmem_jal;
        end
    end

    // ---- WB stage ----
    assign write_data_wb = memwb_jal        ? memwb_pc :
                           memwb_mem_to_reg ? memwb_mem_out :
                                              memwb_alu_result;

endmodule