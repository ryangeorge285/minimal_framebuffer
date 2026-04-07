module hdmi_sink (
	input resetn,

	input pix_clk,
	input tmds_clk,

    input [15:0] pixel,

	output       tmds_clk_n,
	output       tmds_clk_p,
	output [2:0] tmds_d_n,
	output [2:0] tmds_d_p,
    
    output pixel_read
);

wire [2:0] tmds_dout;
wire [2:0] tmds_d9, tmds_d8, tmds_d7, tmds_d6, tmds_d5, tmds_d4, tmds_d3, tmds_d2, tmds_d1, tmds_d0;

reg [9:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;

assign pixel_read = DrawArea;

always @(posedge pix_clk) DrawArea <= (CounterX<640) && (CounterY<480);
always @(posedge pix_clk) CounterX <= (CounterX==799) ? 0 : CounterX+1;
always @(posedge pix_clk) if(CounterX==799) CounterY <= (CounterY==524) ? 0 : CounterY+1;

always @(posedge pix_clk) hSync <= (CounterX>=656) && (CounterX<752);
always @(posedge pix_clk) vSync <= (CounterY>=490) && (CounterY<492);

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;

assign red   = {pixel[15:11], 3'b0};
assign green = {pixel[10:5], 2'b0};
assign blue  = {pixel[4:0], 3'b0};

hdmi_tmds channel0 (
    .clk(pix_clk),
	.reset(~resetn),
	.de(DrawArea),
	.ctrl({vSync,hSync}),
	.d(green[7:0]),
	.q_out({tmds_d9[0], tmds_d8[0], tmds_d7[0], tmds_d6[0], tmds_d5[0], tmds_d4[0], tmds_d3[0], tmds_d2[0], tmds_d1[0], tmds_d0[0]})
);

hdmi_tmds channel1 (
	.clk(pix_clk),
	.reset(~resetn),
	.de(DrawArea),
	.ctrl(2'b0),
	.d(blue[7:0]),
	.q_out({tmds_d9[1], tmds_d8[1], tmds_d7[1], tmds_d6[1], tmds_d5[1], tmds_d4[1], tmds_d3[1], tmds_d2[1], tmds_d1[1], tmds_d0[1]})
);

hdmi_tmds channel2 (
	.clk(pix_clk),
	.reset(~resetn),
	.de(DrawArea),
	.ctrl(2'b0),
	.d(red[7:0]),
	.q_out({tmds_d9[2], tmds_d8[2], tmds_d7[2], tmds_d6[2], tmds_d5[2], tmds_d4[2], tmds_d3[2], tmds_d2[2], tmds_d1[2], tmds_d0[2]})
);
    
OSER10 serializer [2:0] (
	.Q(tmds_dout),
	.D0(tmds_d0),
	.D1(tmds_d1),
	.D2(tmds_d2),
	.D3(tmds_d3),
	.D4(tmds_d4),
	.D5(tmds_d5),
	.D6(tmds_d6),
	.D7(tmds_d7),
	.D8(tmds_d8),
	.D9(tmds_d9),
	.PCLK(pix_clk),
	.FCLK(tmds_clk),
	.RESET(~resetn)
);
	
ELVDS_OBUF tmds_bufds [3:0] (
	.I({pix_clk, tmds_dout}),
	.O({tmds_clk_p, tmds_d_p}),
	.OB({tmds_clk_n, tmds_d_n})
);

endmodule
