module dcache (
    input         clk, rst,
    input  [31:0] addr,
    input  [31:0] data_in,
    input         mem_read,
    input         mem_write,
    output [31:0] data_out,
    output        hit,

    input  [31:0] mem_data,
    input         mem_ready,
    output        mem_req
);
    reg [31:0] cache_data  [0:15];
    reg [25:0] cache_tag   [0:15];
    reg        cache_valid [0:15];

    wire [3:0]  index  = addr[5:2];
    wire [25:0] tag    = addr[31:6];

    wire tag_match = cache_valid[index] && (cache_tag[index] == tag);
    wire read_hit  = mem_read  && tag_match;
    wire write_hit = mem_write && tag_match;

    // stores always proceed, reads need a hit
    assign hit      = mem_write || read_hit;
    assign mem_req  = mem_read && !read_hit;
    assign data_out = mem_write ? data_in : cache_data[index];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                cache_valid[i] <= 0;
                cache_tag[i]   <= 0;
                cache_data[i]  <= 0;
            end
        end else if (mem_write) begin
            cache_data[index]  <= data_in;
            cache_tag[index]   <= tag;
            cache_valid[index] <= 1;
        end else if (mem_read && !read_hit && mem_ready) begin
            cache_data[index]  <= mem_data;
            cache_tag[index]   <= tag;
            cache_valid[index] <= 1;
        end
    end
endmodule