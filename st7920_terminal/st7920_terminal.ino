//#include <stdlib.h>
//#include <stdio.h>
//#include <string.h>
//#include <math.h>

#define BUFFER_WIDTH 256
#define BUFFER_HEIGHT 32
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define FONT_WIDTH 3 
#define FONT_HEIGHT 6
#define LINE_HEIGHT 8
#define CHARACTER_WIDTH 4

#define RS 12
#define EN 13
#define D0 2

unsigned char buffer[1024];

const unsigned char font[] = {
    0x00, 0x00, 0x00,// [ space]
    0x00, 0x3A, 0x00,// !
    0x30, 0x00, 0x30,// "
    0x3E, 0x14, 0x3E,// #
    0x0A, 0x3F, 0x14,// $
    0x26, 0x08, 0x32,// %
    0x14, 0x2A, 0x16,// &
    0x00, 0x30, 0x00,// '
    0x00, 0x1C, 0x22,// (
    0x22, 0x1C, 0x00,// )
    0x28, 0x10, 0x28,// *
    0x08, 0x1C, 0x08,// +
    0x02, 0x04, 0x00,// ,
    0x08, 0x08, 0x08,// -
    0x00, 0x02, 0x00,// .
    0x06, 0x08, 0x30,// /
    0x1E, 0x22, 0x3C,// 0
    0x10, 0x3E, 0x00,// 1
    0x26, 0x2A, 0x12,// 2
    0x22, 0x2A, 0x14,// 3
    0x38, 0x08, 0x3E,// 4
    0x3A, 0x2A, 0x24,// 5
    0x1C, 0x2A, 0x2E,// 6
    0x26, 0x28, 0x30,// 7
    0x3E, 0x2A, 0x3E,// 8
    0x3A, 0x2A, 0x3C,// 9
    0x00, 0x14, 0x00,// :
    0x02, 0x14, 0x00,// ;
    0x08, 0x14, 0x22,// <
    0x14, 0x14, 0x14,// =
    0x22, 0x14, 0x08,// >
    0x20, 0x2A, 0x30,// ?
    0x1C, 0x22, 0x1A,// @
    0x1E, 0x28, 0x1E,// A
    0x3E, 0x2A, 0x14,// B
    0x1C, 0x22, 0x22,// C
    0x3E, 0x22, 0x1C,// D
    0x3E, 0x2A, 0x2A,// E
    0x3E, 0x28, 0x28,// F
    0x1C, 0x2A, 0x2E,// G
    0x3E, 0x08, 0x3E,// H
    0x22, 0x3E, 0x22,// I
    0x04, 0x22, 0x3C,// J
    0x3E, 0x08, 0x36,// K
    0x3E, 0x02, 0x02,// L
    0x3E, 0x10, 0x3E,// M
    0x3E, 0x20, 0x1E,// N
    0x1C, 0x22, 0x1C,// O
    0x3E, 0x28, 0x10,// P
    0x1C, 0x22, 0x1E,// Q
    0x3E, 0x28, 0x16,// R
    0x12, 0x2A, 0x24,// S
    0x20, 0x3E, 0x20,// T
    0x3C, 0x02, 0x3E,// U
    0x3C, 0x02, 0x3C,// V
    0x3E, 0x04, 0x3E,// W
    0x36, 0x08, 0x36,// X
    0x30, 0x0E, 0x30,// Y
    0x26, 0x2A, 0x32,// Z
    0x00, 0x3E, 0x22,// [
    0x30, 0x08, 0x06,// "\"
    0x22, 0x3E, 0x00,// ]
    0x10, 0x20, 0x10,// ^
    0x02, 0x02, 0x02,// _
    0x20, 0x10, 0x00,// `
    0x0C, 0x12, 0x1E,// a
    0x3E, 0x12, 0x0C,// b
    0x0C, 0x12, 0x12,// c
    0x0C, 0x12, 0x3E,// d
    0x0C, 0x16, 0x1A,// e
    0x08, 0x1E, 0x28,// f
    0x0C, 0x15, 0x1E,// g
    0x3E, 0x08, 0x06,// h
    0x00, 0x2C, 0x02,// i
    0x01, 0x2E, 0x00,// j
    0x3E, 0x08, 0x16,// k
    0x00, 0x3C, 0x02,// l
    0x1E, 0x08, 0x1E,// m
    0x1E, 0x10, 0x0E,// n
    0x0C, 0x12, 0x0C,// o
    0x1F, 0x12, 0x0C,// p
    0x0C, 0x12, 0x1F,// q
    0x1E, 0x08, 0x10,// r
    0x0A, 0x1A, 0x14,// s
    0x10, 0x3C, 0x12,// t
    0x1C, 0x02, 0x1E,// u
    0x1C, 0x02, 0x1C,// v
    0x1E, 0x04, 0x1E,// w
    0x12, 0x0C, 0x12,// x
    0x18, 0x05, 0x1E,// y
    0x12, 0x16, 0x1A,// z
    0x08, 0x36, 0x22,// {
    0x00, 0x3E, 0x00,// |
    0x22, 0x36, 0x08,// }
    0x08, 0x0C, 0x04,// ~
};

void setBit(char* buffer, int x, int y, char c) {
  int index;
    if (y < 32) {
      index = BUFFER_WIDTH*y + x;
    } else {
      index = (BUFFER_WIDTH*(y-32)) + BUFFER_WIDTH/2 + x;
    }
    buffer[index/8] |= (0b10000000 >> (index%8));
}

void printChar(char c, int position) {
    int positionsPerRow = floor(SCREEN_WIDTH / CHARACTER_WIDTH);
    int pageRow = floor(position / positionsPerRow);
    int maxRows = (SCREEN_HEIGHT / LINE_HEIGHT);
    if (pageRow >= maxRows) {
        return;
    }
    // Loop along the font's columns
    for (int i = 0; i < FONT_WIDTH; i++) {
        // Subtract 0x20 (the font starts at space, 0x20) and multiply by columns per character,
        // add the current column
        char col = font[((c - 0x20) * FONT_WIDTH) + i];
        // Loop along the rows in the current column
        for (int j = FONT_HEIGHT; j > 0; j--) {
            // Is this bit in the column set? Print it.
            if (((col << j) & 0b1000000)) {
                setBit(buffer, 1 + i + ((position - (positionsPerRow * pageRow)) * CHARACTER_WIDTH), (pageRow * LINE_HEIGHT) + j, c);
            }
        }
    }
}

byte flipByte(byte c){
  char r=0;
  for(byte i = 0; i < 8; i++){
    r <<= 1;
    r |= c & 1;
    c >>= 1;
  }
  return r;
}

void sendPage(char* page) {
    int pointer;
    for (int row = 0; row < BUFFER_HEIGHT; row++) {
        // Set row and column location (after this the controller auto increments the column)
        lcd_send(0, 0x80 | row);
        lcd_send(0, 0x80);
        for (int col = 0; col < BUFFER_WIDTH/16; col++) {
            lcd_send(1, 0b11111111 & page[pointer]);
            pointer++;
            lcd_send(1, 0b11111111 & page[pointer]);
            pointer++;
        } 
    }
}

void lcd_init() {
  lcd_send(0, 0x30);
  delayMicroseconds(100);
  lcd_send(0, 0x0C);
  delayMicroseconds(100);
  lcd_send(0, 0x01);
  delay(2);
  lcd_send(0, 0x34); // Extended function set
  delayMicroseconds(100);
  lcd_send(0, 0x36); // Extended function set
  delayMicroseconds(100);
  lcd_clear();
  Serial.println("Done init");
}

void lcd_clear() {
  for (byte y = 0; y < BUFFER_HEIGHT; y++) {
    lcd_send(0, 0x80 | y);  
    lcd_send(0, 0x80);
    for (byte x = 0; x < BUFFER_WIDTH/8; x++)
      lcd_send(1, 0x00);
      lcd_send(1, 0x00);
    }
}

void lcd_send(int lcd_mode, byte data) {
  digitalWrite(RS, lcd_mode);

  for (int pin = D0; pin < D0 + 8; pin +=1) {
    digitalWrite(pin, data & 1);
    data = data >> 1;
  }

  digitalWrite(EN, HIGH);
  digitalWrite(EN, LOW);

  digitalWrite(RS, LOW);
}

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);

  Serial.println("Restarting!");
  
  // Prepare pins for output
  pinMode(RS, OUTPUT);
  pinMode(EN, OUTPUT);
  for (int pin = D0; pin < D0 + 8; pin +=1) {
    pinMode(pin, OUTPUT);
  }
  digitalWrite(EN, LOW);
  
  lcd_init();
//
  for (int i = 0x20; i <= 0x7E; i++) {
    printChar(i, i-0x20);
  }
  sendPage(buffer);
}

int incomingByte = 0;
int scrollbackPointer = 0;

char scrollback[1];

void append(char* s, char c) {
  int len = strlen(s);
  s[len] = c;
  s[len+1] = '\0';
}

void loop() {
//  if (Serial.available() > 0) {
//    // read the incoming byte:
//    incomingByte = Serial.read();
//
//    if (incomingByte > 127) { return; }
//
//    if (incomingByte == 127) {
//      scrollback[strlen(scrollback)-1] = '\0';
//    } else {
//      append(scrollback, incomingByte);
//    }
//    
//    for (int i = 0; i < strlen(scrollback); i++) {
//        printChar(scrollback[i], i);
//    }
//    
//    sendPage(buffer);
//  }

}
