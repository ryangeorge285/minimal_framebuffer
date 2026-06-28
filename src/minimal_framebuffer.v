/*
 * FPGA PSRAM to HDMI Output Test
 * Ryan George, 2026
 */

module minimal_framebuffer (
    input sys_clk,
    input sys_resetn,

    input wire wr,
    input wire [15:0] uc_data,

    output wire vsync_out,

    output [5:0] led,

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

wire [15:0] input_data;
wire input_valid;
wire [15:0] pixel;

reg read_pixel;
wire [31:0] pixel_write;

reg fifo_write_reset;
reg draining;
reg [3:0] flush_state;

reg fifo_read_reset;
reg [5:0] read_flush_state;
reg vsync_clk_prev;
wire vsync_clk;
wire read_flushing = (read_flush_state != 6'd0);

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

/* ****************************TEST PATTERN DRIVER****************
wire [15:0] uc_data;
wire uc_wr;
wire uc_cs;

test_pattern_driver test_driver(
    .clk(clk),
    .rst_n(sys_resetn),
    .enable(buffer_init),
    .uc_data(uc_data),
    .uc_wr(uc_wr),
    .uc_dc()
);
*/

//*****************************PERIPH HANDLER******************************************
input_handler input_handler0(
    .fast_clk(clk),
    .wr(wr),
    .rst_n(sys_resetn),
    .uc_data(uc_data),

    .input_data(input_data),
    .input_valid(input_valid),
    .input_end(input_end)
);


//*****************************FIFO******************************************
wire [31:0] fifo_wr_data = read_buffer ? rd_data[1] : rd_data[0];
wire fifo_wr_en = (read_buffer ? rd_data_valid[1] : rd_data_valid[0]) & ~read_flushing;

FIFO_HS_Read fifo_read(
		.Data(fifo_wr_data), //input [31:0] Data
		.Reset(fifo_read_reset), //input Reset
		.WrClk(clk), //input WrClk
		.RdClk(pix_clk), //input RdClk
		.WrEn(fifo_wr_en), //input WrEn
		.RdEn(~fifo_read_empty & pixel_read  & frame_aligned), //input RdEn
		.Almost_Empty(videoclk_fifo_read_almost_empty), //output Almost_Empty
		.Q(pixel), //output [15:0] Q
		.Empty(fifo_read_empty) //output Empty
	);

FIFO_HS_WRITE fifo_write(
		.Data(input_data), //input [15:0] Data
        .Reset(fifo_write_reset),
		.WrClk(clk), //input WrClk
		.RdClk(clk), //input RdClk
		.WrEn(input_valid), //input WrEn
		.RdEn(read_pixel), //input RdEn
		.Q(pixel_write), //output [31:0] Q
        .Almost_Empty(fifo_write_burst_empty), //output Almost_Full
		.Empty(fifo_write_empty) //output Empty
	);


//*****************************CDC******************************************

cdc video_pl_almost_empty(
        .clk_dest(clk),
        .rst_n(sys_resetn),

        .src_data(videoclk_fifo_read_almost_empty),
        .out_data(plclk_fifo_read_almost_empty)
    );

cdc vsync_to_clk(
        .clk_dest(clk),
        .rst_n(sys_resetn),

        .src_data(vsync),
        .out_data(vsync_clk)
    );


//*****************************LOGIC******************************************

wire write_buffer;
reg read_buffer;
assign write_buffer = ~read_buffer;

reg swap_pending;
reg swap_ready;

always @(posedge pix_clk) begin
    if(~sys_resetn)
        frame_aligned <= 0;
    else begin
        if(~frame_aligned & vsync & buffer_init)
            frame_aligned <= 1;
    end
end

reg [15:0] fb_read_burst_index;
reg [15:0] fb_write_burst_index;

reg [31:0] read_cycle;    
reg [31:0] write_cycle; 

reg [5:0] read_count;

wire [20:0] row;
wire [20:0] col;

assign c = read_cycle < 32;

assign row = ((fb_read_burst_index<<5)+(c?read_cycle:0))/(320); 
assign col = ((fb_read_burst_index<<5)+(c?read_cycle:0))%(320); 

reg buffer_init;

assign led[5] = read_buffer;
assign led[4] = write_buffer;

assign vsync_out = vsync;   


//wr_data[0] <= ((row == 0 && col%10==0) || (row == 479 && col%10==0)) ? 32'hffffffff : 32'h00000000;

always @(posedge clk) begin
    if (!sys_resetn) begin
        read_cycle <= 8'b0;
        write_cycle <= 8'b0;
        cmd_en <= 2'b00;
        fb_read_burst_index <= 0;
        fb_write_burst_index <= 0;
        read_buffer <= 0;
        buffer_init <= 1'b0;
        fifo_write_reset <= 1'b0;
        draining <= 1'b0;
        flush_state <= 4'd0;
        swap_pending <= 1'b0;
        swap_ready <= 1'b0;
        fifo_read_reset <= 1'b0;
        read_flush_state <= 6'd0;
        vsync_clk_prev <= 1'b0;
    end else if (~buffer_init) begin
        if (&init_calib) begin
            if(fb_write_burst_index < FB_BURST_COUNT) begin
                wr_data[0] <= 32'hf800f800;   // init buffer 0 = RED
                wr_data[1] <= 32'h001f001f;   // init buffer 1 = BLUE

                if (write_cycle == 0) begin
                    addr[0] <= fb_write_burst_index << 6;
                    data_mask[0] <= 8'h00;
                    cmd[0] <= 1'b1;
                    cmd_en[0] <= 1'b1;

                    addr[1] <= fb_write_burst_index << 6;
                    data_mask[1] <= 8'h00;
                    cmd[1] <= 1'b1;
                    cmd_en[1] <= 1'b1;
                end else begin
                    cmd_en[0] <= 1'b0;
                    cmd_en[1] <= 1'b0;
                end

                if (write_cycle == 50) begin
                    write_cycle <= 0;
                    fb_write_burst_index <= fb_write_burst_index + 1;
                end else begin
                    write_cycle <= write_cycle + 1;
                end
            end else begin
                buffer_init <= 1'b1;
                write_cycle <= 0;
            end
        end
    end else begin
        if(fb_read_burst_index < FB_BURST_COUNT) begin
            if(read_cycle > 100) begin
                if(plclk_fifo_read_almost_empty)
                begin 
                    read_cycle <= 0;
                    fb_read_burst_index <= fb_read_burst_index + 1;
                end
            end else   
                read_cycle <= read_cycle + 1;
       

            if (read_cycle == 0 && ~read_flushing) begin
                addr[read_buffer] <= fb_read_burst_index << 6;
                cmd[read_buffer] <= 1'b0;
                cmd_en[read_buffer] <= 1'b1;
                data_mask[read_buffer] <= 8'h00;
            end else begin
                cmd_en[read_buffer] <= 1'b0;
            end
        end else begin
            cmd_en[read_buffer] <= 1'b0;
        end
    end

    if(buffer_init) begin
        if(fb_write_burst_index < FB_BURST_COUNT) begin
            if (write_cycle == 0) begin
                if ((draining ? ~fifo_write_empty : ~fifo_write_burst_empty) && flush_state == 4'd0) begin
                    addr[write_buffer] <= fb_write_burst_index << 6;
                    data_mask[write_buffer] <= 8'h00;
                    read_pixel <= 1'b1;
                    write_cycle <= 1;
                end
            end else begin
                wr_data[write_buffer] <= {pixel_write[15:0], pixel_write[31:16]};
                if (write_cycle == 1) begin
                    cmd[write_buffer] <= 1'b1;
                    cmd_en[write_buffer] <= 1'b1;
                end else
                    cmd_en[write_buffer] <= 1'b0;

                if (write_cycle == 32)
                    read_pixel <= 1'b0;

                if (write_cycle == 50) begin
                    write_cycle <= 0;
                    fb_write_burst_index <= fb_write_burst_index + 1;
                end else begin
                    write_cycle <= write_cycle + 1;
                end
            end
        end else begin
            write_cycle <= 0;
            fb_write_burst_index <= 0;
            draining <= 1'b0;
            flush_state <= 4'd10;
            if (swap_pending) begin
                swap_ready   <= 1'b1;  
                swap_pending <= 1'b0;
            end
        end
    end

    if (flush_state != 4'd0)
        flush_state <= flush_state - 4'd1;

    if (input_end) begin
        draining <= 1'b1;
        swap_pending <= 1'b1;  
    end

    fifo_write_reset <= ~buffer_init | (flush_state > 4'd4);

    vsync_clk_prev <= vsync_clk;
    if (vsync_clk & ~vsync_clk_prev) begin
        read_flush_state <= 6'd40;
        fb_read_burst_index <= 0;
        read_cycle <= 0;
        if (swap_ready) begin           
            read_buffer <= ~read_buffer;
            swap_ready  <= 1'b0;
        end
    end else if (read_flush_state != 6'd0) begin
        read_flush_state <= read_flush_state - 6'd1;
        fb_read_burst_index <= 0;
        read_cycle <= 0;
    end

    fifo_read_reset <= (read_flush_state > 6'd8);
end



endmodule