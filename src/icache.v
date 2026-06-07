module icache (
    input         clk, rst,
    input  [31:0] addr,
    output [31:0] data_out,
    output        hit,

    input  [31:0] mem_data,
    input         mem_ready,
    output        mem_req
);
    reg [31:0] cache_data  [0:15];
    reg [25:0] cache_tag   [0:15];
    reg        cache_valid [0:15];

    wire [3:0]  index = addr[5:2];
    wire [25:0] tag   = addr[31:6];

    // Combinational hit detection and data output
    assign hit      = cache_valid[index] && (cache_tag[index] == tag);
    assign data_out = cache_data[index];
    assign mem_req  = !hit;

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                cache_valid[i] <= 0;
                cache_tag[i]   <= 0;
                cache_data[i]  <= 0;
            end
        end else if (!hit && mem_ready) begin
            cache_data[index]  <= mem_data;
            cache_tag[index]   <= tag;
            cache_valid[index] <= 1;
        end
    end
endmodule