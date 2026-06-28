# FPGA Framebuffer for MCU
*FPGA based framebuffer for extending the video capabilities of MCUs such as the ESP32-S3*

This project turns a cheap FPGA (Tang Nano 9K) into a framebuffer, allowing it to be used as a display controller for a screen over a HDMI cable. An ESP32 can be used as the master, sending video data through its LCD peripheral bus into a double frame buffer on the FPGA's PSRAM. 

## System Capabilities
https://github.com/user-attachments/assets/bbdf33b4-7069-42c7-9aa4-5b9c3d5a4326

*Working animations on the display, being scanned out by the ESP32 at approx 25fps. Each LED flash (on the board) is a switch of the currently displayed buffer.*

![IMG_4221](https://github.com/user-attachments/assets/da7df3cd-a6b5-472f-9198-e3d7cb7e2252)
*Colour bar test.*

![IMG_4235](https://github.com/user-attachments/assets/1b0e6f54-39c4-4599-8d8f-aee572a96f89)
*Slanted line test.*

## System Connection
![IMG_4238](https://github.com/user-attachments/assets/0d8a817e-1cc9-40ed-b466-017862199f6b)
*The ESP32 and Tang Nano 9K (FPGA) connected together, via a 16 bit pixel colour data bus and two control signals (vsync and wr/cs)*

