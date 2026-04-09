module cdc(
    input wire clk_dest,
    input wire rst_n,

    input wire src_data,
    output wire out_data
);

reg sync1, sync2;

always @(posedge clk_dest or negedge rst_n) begin
    if(~rst_n) begin
        sync1 <= 1'b0;
        sync2 <= 1'b0;
    end else begin
        sync1 <= src_data;
        sync2 <= sync1;
    end
end

assign out_data=sync2;

endmodule