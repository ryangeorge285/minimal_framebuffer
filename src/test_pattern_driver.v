module test_pattern_driver (
    input clk,
    input rst_n,
    input enable,

    output reg [15:0] uc_data,
    output reg uc_wr,
    output reg uc_cs,
    output reg uc_dc
);

localparam H_RES = 640;
localparam V_RES = 480;
localparam TOTAL_PIXELS = H_RES * V_RES;

// wr pulse timing: hold high/low long enough for 3-stage sync + edge detect
localparam WR_HIGH_CYCLES = 4;
localparam WR_LOW_CYCLES = 4;

localparam GAP_CYCLES = 200;

reg [18:0] pixel_count;
reg [3:0] wr_timer;
reg [7:0] gap_timer;
reg sending;

reg [9:0] col;
reg [8:0] row;

// Confirmation pattern: 4 colored quadrants + 1px white border + center cross.
// - quadrants check the horizontal (col 320) and vertical (row 240) centers
// - the white border checks all four edges
// - distinct colors check pixel order / no channel swap
wire left = (col < H_RES/2);
wire top  = (row < V_RES/2);
wire at_border = (row == 0) || (row == V_RES-1) || (col == 0) || (col == H_RES-1);
wire at_cross  = (col == H_RES/2) || (row == V_RES/2);
wire [15:0] quad = top ? (left ? 16'hF800 : 16'h07E0)    // TL red, TR green
                       : (left ? 16'h001F : 16'hFFE0);   // BL blue, BR yellow
wire [15:0] color = (at_border || at_cross) ? 16'hFFFF : quad;

always @(posedge clk) begin
    if (~rst_n) begin
        pixel_count <= 0;
        wr_timer <= 0;
        uc_wr <= 1'b0;
        uc_cs <= 1'b0;
        uc_dc <= 1'b1;
        uc_data <= 16'h0;
        sending <= 1'b0;
        col <= 0;
        row <= 0;
        gap_timer <= 0;
    end else if (enable) begin
        if (~sending) begin
            uc_cs <= 1'b1;
            uc_dc <= 1'b1;
            uc_data <= color;
            uc_wr <= 1'b0;
            wr_timer <= 0;
            sending <= 1'b1;
        end else if (pixel_count < TOTAL_PIXELS) begin
            uc_data <= color;
            if (~uc_wr) begin
                // wr low phase
                if (wr_timer == WR_LOW_CYCLES - 1) begin
                    uc_wr <= 1'b1;
                    wr_timer <= 0;
                end else begin
                    wr_timer <= wr_timer + 1;
                end
            end else begin
                // wr high phase
                if (wr_timer == WR_HIGH_CYCLES - 1) begin
                    uc_wr <= 1'b0;
                    wr_timer <= 0;
                    pixel_count <= pixel_count + 1;
                    if (col == H_RES - 1) begin
                        col <= 0;
                        row <= row + 1;
                    end else begin
                        col <= col + 1;
                    end
                end else begin
                    wr_timer <= wr_timer + 1;
                end
            end
        end else begin
            uc_cs <= 1'b0;
            uc_wr <= 1'b0;
            if (gap_timer == GAP_CYCLES - 1) begin
                gap_timer <= 0;
                sending <= 1'b0;     // triggers restart (pixel 0) next cycle
                pixel_count <= 0;
                col <= 0;
                row <= 0;
            end else begin
                gap_timer <= gap_timer + 1;
            end
        end
    end
end

endmodule
