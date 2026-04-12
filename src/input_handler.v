module input_handler(
    input fast_clk,
    input wire wr,
    input wire rst_n,

    input wire dc,
    input wire cs,

    input wire [15:0] uc_data,
    
    output reg input_type,
    output reg [15:0] input_data,
    output reg input_valid
);

reg [2:0] wr_sync;
always @(posedge fast_clk) wr_sync <= {wr_sync[1:0], wr};
wire wr_rising = (wr_sync[2:1] == 2'b01); 

always @(posedge fast_clk) begin
    input_valid <= 1'b0;
    if(~rst_n) begin
        input_type <= 1'b0;
        input_data <= 16'b0;
        wr_sync <= 3'b0;
    end
    if(wr_rising) begin
        if(cs) begin
            input_type <= 1'b1;
            input_data <= uc_data;
            input_valid <= 1'b1;
        end
    end
end

endmodule