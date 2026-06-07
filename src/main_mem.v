module main_mem (
    input         clk, rst,
    input  [31:0] addr,
    input  [31:0] data_in,
    input         we,
    input         req,
    output reg [31:0] data_out,
    output reg    ready
);
    reg [31:0] mem [0:255];
    reg [1:0]  delay_count;

    initial $readmemh("programs/test.hex", mem);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ready       <= 0;
            delay_count <= 0;
            data_out    <= 0;
        end else if (we) begin
            mem[addr[31:2]] <= data_in;
            ready           <= 0;
        end else if (req && !ready) begin
            // start or continue counting toward ready
            if (delay_count == 2) begin
                data_out    <= mem[addr[31:2]];
                ready       <= 1;
                delay_count <= 0;
            end else begin
                delay_count <= delay_count + 1;
                ready       <= 0;
            end
        end else if (!req) begin
            // request dropped — reset
            ready       <= 0;
            delay_count <= 0;
        end
        // if req && ready: hold ready high until req drops
    end
endmodule