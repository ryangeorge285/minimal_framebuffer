/*
 * FPGA PSRAM to HDMI Output Test
 * Ryan George, 2026
 */

module minimal_framebuffer (
    input sys_clk,  
    input sys_resetn,
    input button,   

    output reg [5:0] led,

    output [CS_WIDTH-1:0] O_psram_ck,      
    output [CS_WIDTH-1:0] O_psram_ck_n,
    inout [CS_WIDTH-1:0] IO_psram_rwds,
    inout [DQ_WIDTH-1:0] IO_psram_dq,
    output [CS_WIDTH-1:0] O_psram_reset_n,
    output [CS_WIDTH-1:0] O_psram_cs_n,

    output       tmds_clk_n,
    output       tmds_clk_p,
    output [2:0] tmds_d_n,
    output [2:0] tmds_d_p
);

localparam  DQ_WIDTH = 16;
localparam  CS_WIDTH = 2;

localparam FB_BURST_COUNT = 4800;

wire memory_clock;
wire memory_pll_lock;

wire clk;   

wire [1:0] init_calib;
reg [32:0] wr_data [0:1];
wire [32:0] rd_data [0:1];
wire rd_data_valid [0:1];
reg [20:0] addr [0:1];
reg [1:0] cmd;
reg [1:0] cmd_en;
reg [7:0] data_mask [0:1];

wire pix_clk;
wire tmds_clk;
wire video_pll_lock;

wire [15:0] pixel;

reg frame_aligned;
       
wire videoclk_fifo_read_almost_empty;
wire plclk_fifo_read_almost_empty;

//*****************************MEMORY******************************************

//PLL for memory 
Gowin_rPLL_memory pll_memory(
        .clkout(memory_clk), //output clkout
        .lock(memory_pll_lock), //output lock
        .clkin(sys_clk) //input clkin
    );

//Memory controller
PSRAM_Memory_Interface_HS_Top memory(
        //Clocks
		.clk(sys_clk), //input clk
		.rst_n(sys_resetn), //input rst_n
		.memory_clk(memory_clk), //input memory_clk
		.pll_lock(memory_pll_lock), //input pll_lock
        .clk_out(clk), //output clk_out

        //Interface to memory chip
		.O_psram_ck(O_psram_ck), //output [1:0] O_psram_ck
		.O_psram_ck_n(O_psram_ck_n), //output [1:0] O_psram_ck_n
		.IO_psram_rwds(IO_psram_rwds), //inout [1:0] IO_psram_rwds
		.O_psram_reset_n(O_psram_reset_n), //output [1:0] O_psram_reset_n
		.IO_psram_dq(IO_psram_dq), //inout [15:0] IO_psram_dq
		.O_psram_cs_n(O_psram_cs_n), //output [1:0] O_psram_cs_n

        //Buffer 0
		.init_calib0(init_calib[0]), //output init_calib0
        .cmd0(cmd[0]), //input cmd0
        .cmd_en0(cmd_en[0]), //input cmd_en0
        .addr0(addr[0]), //input [20:0] addr0
        .wr_data0(wr_data[0]), //input [31:0] wr_data0
        .rd_data0(rd_data[0]), //output [31:0] rd_data0
        .rd_data_valid0(rd_data_valid[0]), //output rd_data_valid0
        .data_mask0(data_mask[0]), //input [3:0] data_mask0

        //Buffer 1
		.init_calib1(init_calib[1]), //output init_calib1
		.cmd1(cmd[1]), //input cmd1	
		.cmd_en1(cmd_en[1]), //input cmd_en1	
		.addr1(addr[1]), //input [20:0] addr1
		.wr_data1(wr_data[1]), //input [31:0] wr_data1
		.rd_data1(rd_data[1]), //output [31:0] rd_data1
		.rd_data_valid1(rd_data_valid[1]), //output rd_data_valid1
		.data_mask1(data_mask[1]) //input [3:0] data_mask1
	);


Gowin_rPLL_480p clk_pll(
    .clkout(tmds_clk),
    .clkin(sys_clk),
    .lock(video_pll_lock)
);

Gowin_CLKDIV clk_div(
    .clkout(pix_clk),
    .hclkin(tmds_clk),
    .resetn(video_pll_lock) 
);


hdmi_sink top_u_hdmi (
	.resetn(sys_resetn),

	// video clocks
	.pix_clk(pix_clk),
	.tmds_clk(tmds_clk),
    
    .pixel(pixel),

	// output signals
	.tmds_clk_n(tmds_clk_n),
	.tmds_clk_p(tmds_clk_p),
	.tmds_d_n(tmds_d_n),
	.tmds_d_p(tmds_d_p),

    .pixel_read(pixel_read),
    .vsync(vsync)
);

//*****************************FIFO******************************************
wire [31:0] fifo_wr_data = read_buffer ? rd_data[1] : rd_data[0];
wire fifo_wr_en = read_buffer ? rd_data_valid[1] : rd_data_valid[0];

FIFO_HS_Top_Read fifo_read(
		.Data(fifo_wr_data), //input [31:0] Data
		.WrClk(clk), //input WrClk
		.RdClk(pix_clk), //input RdClk
		.WrEn(fifo_wr_en), //input WrEn
		.RdEn(~fifo_read_empty & pixel_read  & frame_aligned), //input RdEn
		.Almost_Empty(videoclk_fifo_read_almost_empty), //output Almost_Empty
		.Q(pixel), //output [15:0] Q
		.Empty(fifo_read_empty), //output Empty
		.Full(Full) //output Full
	);

//*****************************CDC******************************************

cdc video_pl_almost_empty(
        .clk_dest(clk),
        .rst_n(sys_resetn),
        
        .src_data(videoclk_fifo_read_almost_empty),
        .out_data(plclk_fifo_read_almost_empty)
    );


//*****************************LOGIC******************************************

wire write_buffer;
reg read_buffer;
assign write_buffer = ~read_buffer;

debouncer button_handler(
    .clk(clk),
    .rst_n(sys_resetn),
    .button_in(~button),
    .button_out(switch_buffer)
);



always @(posedge pix_clk) begin
    if(~sys_resetn)
        frame_aligned <= 0;
    else begin
        if(~frame_aligned & vsync & buffer_init)
            frame_aligned <= 1;
    end
end

// Inside your write state block:

reg [15:0] fb_burst_index;

reg [31:0] cycle;     // 14 cycles between write and read
reg [5:0] read_count;

wire [20:0] row;
wire [20:0] col;

assign c = cycle < 32;

assign row = ((fb_burst_index<<5)+(c?cycle:0))/(320); 
assign col = ((fb_burst_index<<5)+(c?cycle:0))%(320); 

reg buffer_init;

//wr_data[0] <= ((row == 0 && col%10==0) || (row == 479 && col%10==0)) ? 32'hffffffff : 32'h00000000;

always @(posedge clk) begin
    if (!sys_resetn) begin
        cycle <= 8'b0;
        cmd_en <= 2'b00;
        fb_burst_index <= 0;
        read_buffer <= 0;
        buffer_init <= 1'b0;
    end else if (!buffer_init) begin
        if (&init_calib) begin
            if(fb_burst_index < FB_BURST_COUNT) begin
                wr_data[0] <= 32'h00000000;
                wr_data[1] <= 32'h00000000;

                if (cycle == 0) begin
                    addr[0] <= fb_burst_index << 6;
                    data_mask[0] <= 8'h00;
                    cmd[0] <= 1'b1;
                    cmd_en[0] <= 1'b1;

                    addr[1] <= fb_burst_index << 6;
                    data_mask[1] <= 8'h00;
                    cmd[1] <= 1'b1;
                    cmd_en[1] <= 1'b1;
                end else begin
                    cmd_en[0] <= 1'b0;
                    cmd_en[1] <= 1'b0;
                end

                if (cycle == 50) begin
                    cycle <= 0;
                    fb_burst_index <= fb_burst_index + 1;
                end else begin
                    cycle <= cycle + 1;
                end
            end else begin
                buffer_init <= 1'b1;
                cycle <= 0;
            end
        end
    end else begin
        if(fb_burst_index < FB_BURST_COUNT) begin
            if(cycle > 100) begin
                if(plclk_fifo_read_almost_empty)
                begin 
                    cycle <= 0;
                    fb_burst_index <= fb_burst_index + 1;
                end
            end else   
                cycle <= cycle + 1;
       

            if (cycle == 0) begin
                addr[read_buffer] <= fb_burst_index << 6;
                cmd[read_buffer] <= 1'b0;
                cmd_en[read_buffer] <= 1'b1;
                data_mask[read_buffer] <= 8'h00;
            end else begin
                cmd_en[read_buffer] <= 1'b0;
            end
        end else begin
            if(switch_buffer)
                read_buffer <= ~read_buffer;
            fb_burst_index <= 0;
            cycle <= 0;
        end
    end
end

endmodule