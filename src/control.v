module control (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg reg_write, alu_src, mem_write, mem_read,
    output reg mem_to_reg, branch, jal,
    output reg [3:0] alu_op
);
    always @(*) begin
        // defaults
        {reg_write, alu_src, mem_write, mem_read,
         mem_to_reg, branch, jal} = 7'b0;
        alu_op = 4'b0000;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1;
                case ({funct7[5], funct3})
                    4'b0000: alu_op = 4'b0000; // ADD
                    4'b1000: alu_op = 4'b0001; // SUB
                    4'b0111: alu_op = 4'b0010; // AND
                    4'b0110: alu_op = 4'b0011; // OR
                    4'b0100: alu_op = 4'b0100; // XOR
                    4'b0001: alu_op = 4'b0101; // SLL
                    4'b0101: alu_op = 4'b0110; // SRL
                    4'b1101: alu_op = 4'b0111; // SRA
                    4'b0010: alu_op = 4'b1000; // SLT
                endcase
            end
            7'b0010011: begin // I-type ALU (addi, andi, etc.)
                reg_write = 1; alu_src = 1;
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b111: alu_op = 4'b0010; // ANDI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b010: alu_op = 4'b1000; // SLTI
                endcase
            end
            7'b0000011: begin // load (lw)
                reg_write = 1; alu_src = 1;
                mem_read = 1; mem_to_reg = 1;
                alu_op = 4'b0000; // address = base + offset
            end
            7'b0100011: begin // store (sw)
                alu_src = 1; mem_write = 1;
                alu_op = 4'b0000;
            end
            7'b1100011: begin // branch (beq)
                branch = 1;
                alu_op = 4'b0001; // SUB to compare
            end
            7'b1101111: begin // JAL
                reg_write = 1; jal = 1;
            end
        endcase
    end
endmodule