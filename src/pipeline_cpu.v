module pipeline_cpu (input clk, input rst);

    // ---- Cache stall signals ----
    wire        icache_hit, dcache_hit;
    wire        icache_mem_req, dcache_mem_req;
    wire [31:0] icache_data_out, dcache_data_out;
    wire [31:0] imem_data_out, dmem_data_out;
    wire        imem_ready, dmem_ready;
    wire        cache_stall;

    assign cache_stall = (!icache_hit) || (exmem_mem_read && !dcache_hit);

    // ---- IF stage wires ----
    reg  [31:0] pc;

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

    // ---- Performance counters ----
    reg [31:0] cycle_count;
    reg [31:0] icache_miss_count;
    reg [31:0] dcache_miss_count;
    reg        icache_req_prev;   // tracks previous cycle's mem_req to detect rising edge
    reg        exmem_jal_prev;    // tracks previous cycle's jal to suppress wrong-path fetch

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_count       <= 0;
            icache_miss_count <= 0;
            icache_req_prev   <= 0;
            exmem_jal_prev    <= 0;
            dcache_miss_count <= 0;
        end else begin
            cycle_count     <= cycle_count + 1;
            icache_req_prev <= icache_mem_req;
            exmem_jal_prev  <= exmem_jal;
            if (icache_mem_req && !icache_req_prev && !exmem_jal && !exmem_jal_prev && !(exmem_branch && exmem_zero) && cycle_count > 4)
                icache_miss_count <= icache_miss_count + 1;
            if (dcache_mem_req)
                dcache_miss_count <= dcache_miss_count + 1;
        end
    end

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

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc         <= 32'b0;
            ifid_instr <= 32'b0;
            ifid_pc    <= 32'b0;
        end else if (exmem_branch && exmem_zero) begin
            pc         <= exmem_pc;
            ifid_instr <= 32'h00000013;
            ifid_pc    <= 32'b0;
        end else if (exmem_jal) begin
            pc         <= exmem_pc;
            ifid_instr <= 32'h00000013;
            ifid_pc    <= 32'b0;
        end else if (stall) begin
            pc         <= pc;
            ifid_instr <= ifid_instr;
            ifid_pc    <= ifid_pc;
        end else if (!cache_stall) begin
            pc         <= pc + 4;
            ifid_instr <= icache_data_out;
            ifid_pc    <= pc;
        end
        // cache miss (icache or dcache): pc and ifid hold
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
        if (rst) begin
            idex_pc <= 0; idex_rd1 <= 0; idex_rd2 <= 0; idex_imm <= 0;
            idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0;
            idex_reg_write <= 0; idex_alu_src <= 0; idex_mem_write <= 0;
            idex_mem_read <= 0; idex_mem_to_reg <= 0;
            idex_branch <= 0; idex_jal <= 0; idex_alu_op <= 0;
        end else if (cache_stall) begin
            idex_pc <= idex_pc; idex_rd1 <= idex_rd1; idex_rd2 <= idex_rd2;
            idex_imm <= idex_imm; idex_rs1 <= idex_rs1; idex_rs2 <= idex_rs2;
            idex_rd <= idex_rd; idex_reg_write <= idex_reg_write;
            idex_alu_src <= idex_alu_src; idex_mem_write <= idex_mem_write;
            idex_mem_read <= idex_mem_read; idex_mem_to_reg <= idex_mem_to_reg;
            idex_branch <= idex_branch; idex_jal <= idex_jal;
            idex_alu_op <= idex_alu_op;
        end else if (stall || (exmem_branch && exmem_zero) || exmem_jal) begin
            idex_pc <= 0; idex_rd1 <= 0; idex_rd2 <= 0; idex_imm <= 0;
            idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0;
            idex_reg_write <= 0; idex_alu_src <= 0; idex_mem_write <= 0;
            idex_mem_read <= 0; idex_mem_to_reg <= 0;
            idex_branch <= 0; idex_jal <= 0; idex_alu_op <= 0;
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
        end else if (cache_stall) begin
            exmem_alu_result <= exmem_alu_result; exmem_rd2 <= exmem_rd2;
            exmem_pc <= exmem_pc; exmem_rd <= exmem_rd;
            exmem_reg_write <= exmem_reg_write;
            exmem_mem_write <= exmem_mem_write;
            exmem_mem_read <= exmem_mem_read;
            exmem_mem_to_reg <= exmem_mem_to_reg;
            exmem_branch <= exmem_branch; exmem_jal <= exmem_jal;
            exmem_zero <= exmem_zero;
        end else begin
            exmem_alu_result <= alu_result_ex;
            exmem_rd2        <= alu_b_pre;
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

    data_mem DMEM (
        .clk(clk), .rst(rst),
        .addr(exmem_alu_result),
        .data_in(exmem_rd2),
        .we(exmem_mem_write),
        .req(dcache_mem_req),
        .data_out(dmem_data_out),
        .ready(dmem_ready)
    );

    assign mem_out_mem = dcache_data_out;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memwb_alu_result <= 0; memwb_mem_out <= 0; memwb_pc <= 0;
            memwb_rd <= 0; memwb_reg_write <= 0;
            memwb_mem_to_reg <= 0; memwb_jal <= 0;
        end else if (cache_stall) begin
            memwb_alu_result <= memwb_alu_result;
            memwb_mem_out <= memwb_mem_out;
            memwb_pc <= memwb_pc; memwb_rd <= memwb_rd;
            memwb_reg_write <= memwb_reg_write;
            memwb_mem_to_reg <= memwb_mem_to_reg;
            memwb_jal <= memwb_jal;
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