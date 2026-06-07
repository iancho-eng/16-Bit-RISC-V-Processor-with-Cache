module alu (
    input  [31:0] a, b,
    input  [3:0]  op,
    output reg [31:0] result,
    output zero
);
    assign zero = (result == 0);

    always @(*) begin
        case (op)
            4'b0000: result = a + b;           // ADD
            4'b0001: result = a - b;           // SUB
            4'b0010: result = a & b;           // AND
            4'b0011: result = a | b;           // OR
            4'b0100: result = a ^ b;           // XOR
            4'b0101: result = a << b[4:0];     // SLL (shift left logical)
            4'b0110: result = a >> b[4:0];     // SRL (shift right logical)
            4'b0111: result = $signed(a) >>> b[4:0]; // SRA (shift right arithmetic)
            4'b1000: result = ($signed(a) < $signed(b)) ? 1 : 0; // SLT (set less than)
            default: result = 32'b0;
        endcase
    end
endmodule