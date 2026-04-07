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

localparam FB_BURST_COUNT = 2400;

wire memory_clock;
wire memory_pll_lock;

//*****************************MEMORY******************************************

//PLL for memory 
Gowin_rPLL_memory pll_memory(
        .clkout(clkout), //output clkout
        .lock(memory_pll_lock), //output lock
        .clkin(sys_clk) //input clkin
    );

//Memory controller
PSRAM_Memory_Interface_HS_Top memory(
        //Clocks
		.clk(sys_clk), //input clk
		.rst_n(sys_rst_n), //input rst_n
		.memory_clk(memory_clk), //input memory_clk
		.pll_lock(memory_pll_lock), //input pll_lock
        .clk_out(clk_out), //output clk_out

        //Interface to memory chip
		.O_psram_ck(O_psram_ck), //output [1:0] O_psram_ck
		.O_psram_ck_n(O_psram_ck_n), //output [1:0] O_psram_ck_n
		.IO_psram_rwds(IO_psram_rwds), //inout [1:0] IO_psram_rwds
		.O_psram_reset_n(O_psram_reset_n), //output [1:0] O_psram_reset_n
		.IO_psram_dq(IO_psram_dq), //inout [15:0] IO_psram_dq
		.O_psram_cs_n(O_psram_cs_n), //output [1:0] O_psram_cs_n

        //Buffer 0
		.init_calib0(init_calib0), //output init_calib0
        .cmd0(cmd0), //input cmd0
        .cmd_en0(cmd_en0), //input cmd_en0
        .addr0(addr0), //input [20:0] addr0
        .wr_data0(wr_data0), //input [31:0] wr_data0
        .rd_data0(rd_data0), //output [31:0] rd_data0
        .rd_data_valid0(rd_data_valid0), //output rd_data_valid0
        .data_mask0(data_mask0), //input [3:0] data_mask0

        //Buffer 1
		.init_calib1(init_calib1), //output init_calib1
		.cmd1(cmd1), //input cmd1	
		.cmd_en1(cmd_en1), //input cmd_en1	
		.addr1(addr1), //input [20:0] addr1
		.wr_data1(wr_data1), //input [31:0] wr_data1
		.rd_data1(rd_data1), //output [31:0] rd_data1
		.rd_data_valid1(rd_data_valid1), //output rd_data_valid1
		.data_mask1(data_mask1) //input [3:0] data_mask1
	);

//*****************************VIDEO******************************************

endmodule