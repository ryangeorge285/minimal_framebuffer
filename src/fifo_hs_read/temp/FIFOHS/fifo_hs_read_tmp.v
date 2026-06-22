//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW1NR-LV9QN88PC6/I5
//Device: GW1NR-9
//Device Version: C
//Created Time: Sun Jun 21 14:27:08 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	FIFO_HS_Read your_instance_name(
		.Data(Data), //input [31:0] Data
		.Reset(Reset), //input Reset
		.WrClk(WrClk), //input WrClk
		.RdClk(RdClk), //input RdClk
		.WrEn(WrEn), //input WrEn
		.RdEn(RdEn), //input RdEn
		.Almost_Empty(Almost_Empty), //output Almost_Empty
		.Q(Q), //output [15:0] Q
		.Empty(Empty), //output Empty
		.Full(Full) //output Full
	);

//--------Copy end-------------------
