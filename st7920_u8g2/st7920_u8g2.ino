#include <Arduino.h>
#include <SPI.h>
#include <U8g2lib.h>

/* Constructor */
U8G2_ST7920_128X64_F_SW_SPI u8g2(U8G2_R0, /* clock=*/ 13, /* data=*/ 12, /* cs=*/ 11);

#define line_height 7

/* u8g2.begin() is required and will sent the setup/init sequence to the display */
void setup(void) {
  u8g2.begin();
  u8g2.setFont(u8g2_font_pixelle_micro_tr);
  u8g2.drawStr(0,line_height * 1,"Hello World!");
  u8g2.drawStr(0,line_height * 2,"This is me!");
  u8g2.sendBuffer();
}

/* draw something on the display with the `firstPage()`/`nextPage()` loop*/
void loop(void) {

}
