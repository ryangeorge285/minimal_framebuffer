module input_handler(
    input fast_clk,
    input wire wr,
    input wire rst_n,


    input wire [15:0] uc_data,
    
    output reg [15:0] input_data,
    output reg input_valid,
    output reg input_end
);

reg [2:0] wr_sync;
wire wr_rising = (wr_sync[2:1] == 2'b01);
wire wr_end  = (wr_sync[2:1] == 2'b10);

reg [20:0] count;

always @(posedge fast_clk) begin
    input_valid <= 1'b0;
    input_end   <= 1'b0;
    wr_sync <= {wr_sync[1:0], wr};
    if(~rst_n) begin
        input_data <= 16'b0;
        wr_sync <= 3'b0;
        count <= 0;
    end
    else if(wr_rising) begin
        input_data <= uc_data;
        input_valid <= 1'b1;
        if(count == 307199) begin
            count <= 0;
            input_end <= 1'b1;
        end else begin
            count <= count + 1;
        end
    end
end

endmodule