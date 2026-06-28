// ESP32-S3 -> Tang Nano 9K : procedural demo, line-buffered, vsync-synced.
#include "esp_lcd_panel_io.h"
#include <math.h>

#define H_RES 640
#define V_RES 480

#define PIN_WR  42      // -> FPGA 30
#define PIN_DC  47      // unconnected
#define PIN_VS  1       // <- FPGA 53 (vsync)
static const int DATA_PINS[16] = {4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,41};

static esp_lcd_panel_io_handle_t io = nullptr;
static uint16_t lineBuf[2][H_RES];
static uint8_t  sinLUT[256];
static uint16_t pal[256];

static inline uint16_t rgb565(int r,int g,int b){
  return ((r&0xF8)<<8) | ((g&0xFC)<<3) | (b>>3);
}

void setup() {
  pinMode(PIN_VS, INPUT);
  for (int i=0;i<256;i++)
    sinLUT[i] = (uint8_t)(127.5f + 127.5f*sinf(i*2*PI/256.0f));
  for (int i=0;i<256;i++)                       // smooth rainbow palette
    pal[i] = rgb565(sinLUT[i], sinLUT[(i+85)&255], sinLUT[(i+170)&255]);

  esp_lcd_i80_bus_handle_t bus = nullptr;
  esp_lcd_i80_bus_config_t b = {};
  b.dc_gpio_num=PIN_DC; b.wr_gpio_num=PIN_WR; b.clk_src=LCD_CLK_SRC_DEFAULT;
  b.bus_width=16; b.max_transfer_bytes=H_RES*2;
  for (int i=0;i<16;i++) b.data_gpio_nums[i]=DATA_PINS[i];
  ESP_ERROR_CHECK(esp_lcd_new_i80_bus(&b,&bus));

  esp_lcd_panel_io_i80_config_t c = {};
  c.cs_gpio_num=-1; c.pclk_hz=8*1000*1000; c.trans_queue_depth=1;
  c.dc_levels.dc_data_level=1; c.lcd_cmd_bits=0; c.lcd_param_bits=0;
  ESP_ERROR_CHECK(esp_lcd_new_panel_io_i80(bus,&c,&io));
}

static inline void waitVsync(){
  while ( digitalRead(PIN_VS)) {}
  while (!digitalRead(PIN_VS)) {}
}

#define BLACK 0x0000
#define WHITE 0xFFFF

static void renderLine(uint16_t *lb, int y, int t, int p) {
  switch (p) {
    case 0:  // plasma
      for (int x=0;x<H_RES;x++){
        uint8_t a=sinLUT[((x>>1)+t)&255], b=sinLUT[((y>>1)-t)&255];
        uint8_t c=sinLUT[(((x+y)>>2)+t)&255];
        lb[x]=pal[(a+b+c)&255];
      } break;

    case 1: { // centered ripples
      int dy=y-240;
      for (int x=0;x<H_RES;x++){ int dx=x-320;
        lb[x]=pal[(((dx*dx+dy*dy)>>7)-t)&255]; }
      } break;

    case 2:  // rainbow scroll
      for (int x=0;x<H_RES;x++) lb[x]=pal[(x+y+(t<<1))&255];
      break;

    case 3: { // two-source interference
      int dy1=y-150, dy2=y-330;
      for (int x=0;x<H_RES;x++){ int dx1=x-200, dx2=x-440;
        uint8_t s1=sinLUT[(((dx1*dx1+dy1*dy1)>>7))+t&255];
        uint8_t s2=sinLUT[(((dx2*dx2+dy2*dy2)>>7))-t&255];
        lb[x]=pal[(s1+s2)&255]; }
      } break;

    case 4: { // swirl (rotozoom-ish)
      for (int x=0;x<H_RES;x++){
        uint8_t a=sinLUT[((x>>2)+sinLUT[(y+t)&255])&255];
        uint8_t b=sinLUT[((y>>2)+sinLUT[(x-t)&255])&255];
        lb[x]=pal[(a+b)&255]; }
      } break;

    // ---------- standard test patterns ----------
    case 5: { // alignment grid: border + lines every 64px
      bool row = (y==0)||(y==V_RES-1)||((y&63)==0);
      for (int x=0;x<H_RES;x++){
        bool g = row || (x==0)||(x==H_RES-1)||((x&63)==0);
        lb[x]= g?WHITE:BLACK; }
      } break;

    case 6: { // 8 vertical color bars (SMPTE-ish)
      static const uint16_t bc[8]=
        {0xFFFF,0xFFE0,0x07FF,0x07E0,0xF81F,0xF800,0x001F,0x0000};
      for (int x=0;x<H_RES;x++) lb[x]=bc[(x*8)/H_RES];
      } break;

    case 7: { // gradient: red across X, green down Y
      int g=(y*546)>>10;                         // y/480*256
      for (int x=0;x<H_RES;x++){ int r=(x*410)>>10; // x/640*256
        lb[x]=rgb565(r,g,64); }
      } break;

    case 8: { // diagonal crosshatch
      for (int x=0;x<H_RES;x++){
        bool d=(((x+y)&31)==0)||(((x-y)&31)==0);
        lb[x]= d?WHITE:0x0008; }
      } break;

    default: { // sweeping cross (moving H + V line)
      int hy=t%V_RES, vx=t%H_RES;
      for (int x=0;x<H_RES;x++)
        lb[x]=(y==hy||x==vx)?WHITE:(((x^y)&8)?0x0002:BLACK);
      } break;
  }
}

void loop() {
  static int t=0; t++;
  int p=(t>>8)%10;            // 10 patterns, ~10s each
  waitVsync();
  for (int y=0;y<V_RES;y++){
    uint16_t *lb=lineBuf[y&1];
    renderLine(lb,y,t,p);
    esp_lcd_panel_io_tx_color(io,-1,lb,H_RES*2);
  }
}

