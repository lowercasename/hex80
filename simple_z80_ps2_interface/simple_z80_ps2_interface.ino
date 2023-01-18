#include <PS2Keyboard.h>

PS2Keyboard keyboard;

#define SR_RCK 23
#define SR_SCK 24
#define SR_SER 25

#define PS2_DAT 20
#define PS2_CLK 21

#define Z80_INT 22

void setup() {
  Serial.begin(9600);
  
  keyboard.begin(/* DataPin */ PS2_DAT, /* ClockPin */ PS2_CLK);

  
  pinMode(Z80_INT, OUTPUT);
  pinMode(SR_RCK, OUTPUT);
  pinMode(SR_SCK, OUTPUT);
  pinMode(SR_SER, OUTPUT);

  digitalWrite(SR_RCK, HIGH);
  digitalWrite(Z80_INT, HIGH);
}

void loop() {
  if (keyboard.available()) {
    char c = keyboard.read();

    Serial.print("Received key: ");
    Serial.println(c);

    // Shift the key out to the shift register
    digitalWrite(SR_RCK, LOW);
    shiftOut(SR_SER, SR_SCK, MSBFIRST, c);
    digitalWrite(SR_RCK, HIGH);

    // Trigger the interrupt pin on the Z80 to receive the octal
   digitalWrite(Z80_INT, LOW);
   digitalWrite(Z80_INT, HIGH); 
  }

}
