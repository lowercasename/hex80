#include "rom.h"

#define A0 A0
#define A1 A1
#define A2 A2
#define A3 A3
#define A4 A4
#define A5 A5
#define A6 A6
#define A7 A7

#define D0 A8
#define D1 A9
#define D2 A10
#define D3 A11
#define D4 A12
#define D5 A13
#define D6 A14
#define D7 A15

#define RD 53
#define WR 52
#define M1 51
#define MREQ 50
#define RESET 49
#define RFSH 48
#define CLOCK 46

#define BYTE_TO_BINARY_PATTERN_READ "%c%c%c%c %c%c%c%c [ADDR %02X -> %02X]"
#define BYTE_TO_BINARY_PATTERN_WRITE "%c%c%c%c %c%c%c%c [DATA %02X -> ADDR %02X]"
#define BYTE_TO_BINARY(byte)  \
  (byte & 0x80 ? '1' : '0'), \
  (byte & 0x40 ? '1' : '0'), \
  (byte & 0x20 ? '1' : '0'), \
  (byte & 0x10 ? '1' : '0'), \
  (byte & 0x08 ? '1' : '0'), \
  (byte & 0x04 ? '1' : '0'), \
  (byte & 0x02 ? '1' : '0'), \
  (byte & 0x01 ? '1' : '0')

byte M1_val = 0;
byte RFSH_val = 0;
byte RD_val = 0;
byte WR_val = 0;
byte MEMREQ_val = 0;
unsigned short addressBus = 0;
unsigned char dataBus = 0;

short ROM_LENGTH = 256;

void performZ80Reset()
{
  //Perform a reset for 4 cycles (manual says 3 should be enough).
  digitalWrite(RESET, LOW);  
  for (int i = 0; i<8; i++)
  {  
    digitalWrite(CLOCK, HIGH);  
    delay(1);
    digitalWrite(CLOCK, LOW);  
    delay(1);
  }
  //bring CPU out of reset state
  digitalWrite(RESET, HIGH); 
}


void updateZ80Control()
{
 M1_val = digitalRead(M1)==LOW?1:0; 
 RFSH_val = digitalRead(RFSH)==LOW?1:0; 
 RD_val = digitalRead(RD)==LOW?1:0; 
 WR_val = digitalRead(WR)==LOW?1:0; 
 MEMREQ_val = digitalRead(MREQ)==LOW?1:0; 
}

int cycles = 0;
int MAX_CYCLES = 128;

void setup() {
  Serial.begin(9600);

  pinMode(A0, INPUT);   
  pinMode(A1, INPUT); 
  pinMode(A2, INPUT); 
  pinMode(A3, INPUT); 
  pinMode(A4, INPUT); 
  pinMode(A5, INPUT); 
  pinMode(A6, INPUT); 
  pinMode(A7, INPUT);

  pinMode(D0, OUTPUT);   
  pinMode(D1, OUTPUT); 
  pinMode(D2, OUTPUT); 
  pinMode(D3, OUTPUT); 
  pinMode(D4, OUTPUT); 
  pinMode(D5, OUTPUT); 
  pinMode(D6, OUTPUT); 
  pinMode(D7, OUTPUT);
  
  pinMode(WR, INPUT); 
  pinMode(RD, INPUT);
  pinMode(MREQ, INPUT); 
  pinMode(RFSH, INPUT);
  pinMode(M1, INPUT);

  pinMode(RESET, OUTPUT);
  pinMode(CLOCK, OUTPUT);

  digitalWrite(RESET, LOW);
  digitalWrite(CLOCK, HIGH);

  Serial.println("==========================");
  Serial.println("| Z80 interface starting |");
  Serial.println("==========================");

  performZ80Reset();
}

void loop() {
  cycles++;

  digitalWrite(CLOCK, HIGH);
  
  updateZ80Control();
  
  // Skip cycles that are just refreshing RAM
  if (RFSH_val == 1) {
    digitalWrite(CLOCK, LOW);
    return;
  }

  readAddressBus();

  if (MEMREQ_val) {
    if (RD_val) {

      // Debug
      char printBuffer[40];
      sprintf(printBuffer,
        BYTE_TO_BINARY_PATTERN_READ,
        BYTE_TO_BINARY(addressBus),
        addressBus,
        ROM[addressBus]
      );
      Serial.print("RD: ");
      Serial.println(printBuffer);
      
      if (addressBus < ROM_LENGTH) {
          dataBus = ROM[addressBus];
      } else {
          dataBus = 0x0;
      }
      writeDataBus();

      // Have we HALTed?
      if (ROM[addressBus] == 0x76) {
        Serial.println("Z80 halted.");
        Serial.print(cycles);
        Serial.println(" cycles run.");

        printRAM();
        while(1);
      }
    } else if (WR_val) {
      readDataBus();

      // Debug
      char printBuffer[40];
      sprintf(printBuffer,
        BYTE_TO_BINARY_PATTERN_WRITE,
        BYTE_TO_BINARY(dataBus),
        dataBus,
        addressBus
      );
      Serial.print("WR: ");
      Serial.println(printBuffer);
      
      if (addressBus < ROM_LENGTH) {
        ROM[addressBus] = dataBus;
      }
    }
  }
  delay(10);
  digitalWrite(CLOCK, LOW);
}

void readAddressBus() {
  addressBus = 0;
  addressBus |= ((digitalRead(A0)==HIGH)?1:0)<<0;
  addressBus |= ((digitalRead(A1)==HIGH)?1:0)<<1;
  addressBus |= ((digitalRead(A2)==HIGH)?1:0)<<2;
  addressBus |= ((digitalRead(A3)==HIGH)?1:0)<<3;
  addressBus |= ((digitalRead(A4)==HIGH)?1:0)<<4;
  addressBus |= ((digitalRead(A5)==HIGH)?1:0)<<5;
  addressBus |= ((digitalRead(A6)==HIGH)?1:0)<<6;
  addressBus |= ((digitalRead(A7)==HIGH)?1:0)<<7;
}

void readDataBus() {
  pinMode(D0, INPUT);
  pinMode(D1, INPUT);
  pinMode(D2, INPUT);
  pinMode(D3, INPUT);
  pinMode(D4, INPUT);
  pinMode(D5, INPUT);
  pinMode(D6, INPUT);
  pinMode(D7, INPUT);
  
  dataBus = 0;
  dataBus |= ((digitalRead(D0)==HIGH)?1:0)<<0;
  dataBus |= ((digitalRead(D1)==HIGH)?1:0)<<1;
  dataBus |= ((digitalRead(D2)==HIGH)?1:0)<<2;
  dataBus |= ((digitalRead(D3)==HIGH)?1:0)<<3;
  dataBus |= ((digitalRead(D4)==HIGH)?1:0)<<4;
  dataBus |= ((digitalRead(D5)==HIGH)?1:0)<<5;
  dataBus |= ((digitalRead(D6)==HIGH)?1:0)<<6;
  dataBus |= ((digitalRead(D7)==HIGH)?1:0)<<7;
}

void writeDataBus() {
  pinMode(D0, OUTPUT);
  pinMode(D1, OUTPUT);
  pinMode(D2, OUTPUT);
  pinMode(D3, OUTPUT);
  pinMode(D4, OUTPUT);
  pinMode(D5, OUTPUT);
  pinMode(D6, OUTPUT);
  pinMode(D7, OUTPUT);

  digitalWrite(D0, (dataBus&(1<<0))?HIGH:LOW);
  digitalWrite(D1, (dataBus&(1<<1))?HIGH:LOW);
  digitalWrite(D2, (dataBus&(1<<2))?HIGH:LOW);
  digitalWrite(D3, (dataBus&(1<<3))?HIGH:LOW);
  digitalWrite(D4, (dataBus&(1<<4))?HIGH:LOW);
  digitalWrite(D5, (dataBus&(1<<5))?HIGH:LOW);
  digitalWrite(D6, (dataBus&(1<<6))?HIGH:LOW);
  digitalWrite(D7, (dataBus&(1<<7))?HIGH:LOW);
}

void printRAM() {
  Serial.println();
  Serial.println("ROM dump");
  for (int i=0; i < ROM_LENGTH; i++) {
    char printBuffer[3];
    if (i % 16 == 0) {
      char lineStartBuffer[3];
      sprintf(lineStartBuffer,
        "[%02X] ",
        i
      );
      Serial.print(lineStartBuffer);
    }
    sprintf(printBuffer,
      "%02X ",
      ROM[i]
    );
    Serial.print(printBuffer);
    if (i % 16 == 15) {
      Serial.print("    ");
      for (int j=15; j >= 0; j--) {
        int v = ROM[i-j];
        if (v >= 0x20 && v <= 0x7E) {
          char asciiValue = ROM[i-j];
          Serial.print(asciiValue);
        } else {
          Serial.print('.');
        }
      }
      Serial.println();
    }
  }
}
