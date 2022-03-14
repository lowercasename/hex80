#include "rom.h"

#include <PS2Keyboard.h>

PS2Keyboard keyboard;

#define AB0 A0
#define AB1 A1
#define AB2 A2
#define AB3 A3
#define AB4 A4
#define AB5 A5
#define AB6 A6
#define AB7 A7
#define AB8 44
#define AB9 45
#define AB10 42
#define AB11 43
#define AB12 40

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
#define IOREQ 47
#define CLOCK 46
#define INT 22

#define SR_RCK 23
#define SR_SCK 24
#define SR_SER 25

#define BYTE_TO_BINARY_PATTERN_READ "%c%c%c%c %c%c%c%c [ADDR %04X -> %02X]"
#define BYTE_TO_BINARY_PATTERN_WRITE "%c%c%c%c %c%c%c%c [DATA %02X -> ADDR %02X]"
#define BYTE_TO_BINARY_PATTERN_BASIC "%c%c%c%c %c%c%c%c [%02X]"
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
byte IOREQ_val = 0;
unsigned short addressBus = 0;
unsigned char dataBus = 0;

short ROM_LENGTH = 4096;

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
 IOREQ_val = digitalRead(IOREQ)==LOW?1:0; 
}

int cycles = 0;
int MAX_CYCLES = 128;

int debug = 0;
int stopOnHalt = 0;

int currentInterrupt = 0;

char c = 0;

volatile int interrupted = 0;

int ioDebounce = 0;

void setup() {
  Serial.begin(115200);

  keyboard.begin(20, 21);

  pinMode(AB0, INPUT);   
  pinMode(AB1, INPUT);
  pinMode(AB2, INPUT); 
  pinMode(AB3, INPUT); 
  pinMode(AB4, INPUT); 
  pinMode(AB5, INPUT); 
  pinMode(AB6, INPUT); 
  pinMode(AB7, INPUT);
  pinMode(AB8, INPUT); 
  pinMode(AB9, INPUT); 
  pinMode(AB10, INPUT); 
  pinMode(AB11, INPUT); 
  pinMode(AB12, INPUT);

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
  pinMode(IOREQ, INPUT);
  pinMode(RFSH, INPUT);
  pinMode(M1, INPUT);

  pinMode(INT, OUTPUT);
  pinMode(RESET, OUTPUT);
  pinMode(CLOCK, OUTPUT);

  pinMode(SR_RCK, OUTPUT);
  pinMode(SR_SCK, OUTPUT);
  pinMode(SR_SER, OUTPUT);

  digitalWrite(RESET, LOW);
  digitalWrite(CLOCK, HIGH);
  digitalWrite(INT, HIGH);

  pinMode(19, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(19), doInterrupt, FALLING);

  Serial.println("==========================");
  Serial.println("| Z80 interface starting |");
  Serial.println("='=========================");

  performZ80Reset();
}

void loop() {
  
  if (interrupted) {
    Serial.println("Interrupt run!");
    interrupted = 0;
    readDataBus();
    char printBuffer[40];
    sprintf(printBuffer,
      BYTE_TO_BINARY_PATTERN_READ,
      BYTE_TO_BINARY(dataBus),
      dataBus,
      dataBus
    );
    Serial.print("DATA: ");
    Serial.println(printBuffer);
//    dataBus = c;
//    writeDataBus();
  }
  
  if (keyboard.available()) {
    
    // Read the next key
    c = keyboard.read();

//    Serial.print("Received key: ");
//    Serial.println(c);

    // Shift the key out to the shift register
//    digitalWrite(SR_RCK, LOW);
//    shiftOut(SR_SER, SR_SCK, LSBFIRST, c);
//    digitalWrite(SR_RCK, HIGH);

    // Trigger the interrupt pin on the Z80 to receive the octal
    digitalWrite(INT, LOW);
    currentInterrupt = 1;
  }

  digitalWrite(CLOCK, HIGH);
  
  updateZ80Control();
  
  // Skip cycles that are just refreshing RAM
  if (RFSH_val == 1) {
    digitalWrite(CLOCK, LOW);
    return;
  }

  if (currentInterrupt > 0) {
    
    if (IOREQ_val && M1_val) // interrupt ack
    {
      digitalWrite(INT, HIGH);
      currentInterrupt = 0;
    }
  }

  readAddressBus();

  if (MEMREQ_val) {
    if (RD_val) {
      // Debug
      if (debug) {
        char printBuffer[40];
        sprintf(printBuffer,
          BYTE_TO_BINARY_PATTERN_READ,
          BYTE_TO_BINARY(addressBus),
          addressBus,
          ROM[addressBus]
        );
        Serial.print("ROM RD: ");
        Serial.println(printBuffer);
      }
        
      if (addressBus < ROM_LENGTH) {
          dataBus = ROM[addressBus];
      } else {
          dataBus = 0x0;
      }
      writeDataBus();

      if (addressBus == 0x800) {
        Serial.println("Z80 error!");

        printRAM();
      }

      if (stopOnHalt) {
        // Have we HALTed?
        if (ROM[addressBus] == 0x76) {
          Serial.println("Z80 halted.");
  
          printRAM();
          while(1);
        }
      }
    } else if (WR_val) {
      readDataBus();

      // Debug
      if (debug) {
        char printBuffer[40];
        sprintf(printBuffer,
          BYTE_TO_BINARY_PATTERN_WRITE,
          BYTE_TO_BINARY(dataBus),
          dataBus,
          addressBus
        );
        Serial.print("ROM WR: ");
        Serial.println(printBuffer);
      }
      
      if (addressBus < ROM_LENGTH) {
        ROM[addressBus] = dataBus;
      }
    }
  }
  else if (IOREQ_val && (ioDebounce == 0) && !M1_val) {
    ioDebounce = 1;
    unsigned short portAddress = addressBus & 0x00FF;
    if (WR_val) {
      readDataBus();
      // Debug
      if (debug) {
        char printBuffer[40];
        sprintf(printBuffer,
          BYTE_TO_BINARY_PATTERN_WRITE,
          BYTE_TO_BINARY(dataBus),
          dataBus,
          portAddress
        );
        Serial.print("IO  WR: ");
        Serial.println(printBuffer);
      }
    }
//    else if (RD_val) {
//      readDataBus();
//      // Debug
//      if (debug) {
//        char printBuffer[40];
//        sprintf(printBuffer,
//          BYTE_TO_BINARY_PATTERN_READ,
//          BYTE_TO_BINARY(portAddress),
//          portAddress,
//          dataBus
//        );
//        Serial.print("IO  RD: ");
//        Serial.println(printBuffer);
//      }
//    }
  } else
  {
    // to deal with cycle timings (figure 7, timing, z80 manual)
    if (ioDebounce > 0)
    {
      ioDebounce++;
      if (ioDebounce >= 3)
      {
        // IO data _might_ be here?
        readDataBus();
        char printBuffer[40];
        sprintf(printBuffer,
          BYTE_TO_BINARY_PATTERN_BASIC,
          BYTE_TO_BINARY(dataBus),
          dataBus
        );
        Serial.print("IO  RD: ");
        Serial.println(printBuffer);
        ioDebounce = 0;
      }
    }
  }
//  delay(100);
  digitalWrite(CLOCK, LOW);
  
  cycles++;

//  if (cycles % 100000 == 0) {
//    printRAM();
//  }
}

void readAddressBus() {
  addressBus = 0;
  addressBus |= ((digitalRead(AB0)==HIGH)?1:0)<<0;
  addressBus |= ((digitalRead(AB1)==HIGH)?1:0)<<1;
  addressBus |= ((digitalRead(AB2)==HIGH)?1:0)<<2;
  addressBus |= ((digitalRead(AB3)==HIGH)?1:0)<<3;
  addressBus |= ((digitalRead(AB4)==HIGH)?1:0)<<4;
  addressBus |= ((digitalRead(AB5)==HIGH)?1:0)<<5;
  addressBus |= ((digitalRead(AB6)==HIGH)?1:0)<<6;
  addressBus |= ((digitalRead(AB7)==HIGH)?1:0)<<7;
  addressBus |= ((digitalRead(AB8)==HIGH)?1:0)<<8;
  addressBus |= ((digitalRead(AB9)==HIGH)?1:0)<<9;
  addressBus |= ((digitalRead(AB10)==HIGH)?1:0)<<10;
  addressBus |= ((digitalRead(AB11)==HIGH)?1:0)<<11;
  addressBus |= ((digitalRead(AB12)==HIGH)?1:0)<<12;
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
        "[%04X] ",
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

void doInterrupt() {
  interrupted = 1;
}
