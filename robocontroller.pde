import procontroll.*;
import java.io.*;
import processing.serial.*;

// Motor stuff
Serial motorLeft;
Serial motorRight;
Serial motorChair;

// Controller stuff
ControllIO controll;
ControllDevice device;
ControllStick stickLeft;
ControllStick stickRight;
ControllButton buttonL1;
ControllButton buttonR1;
ControllButton buttonStart;
ControllButton buttonR2;
ControllButton buttonL2;
ControllButton buttonUp;
ControllButton buttonDown;
ControllButton buttonTri;
ControllButton buttonX;

void setup(){
  size(640,480);
  textSize(32);
  //println(Serial.list());
  
  //motorChair = new Serial(this,"/dev/tty.usbmodemfd1211");
  //motorLeft = new Serial(this,"/dev/tty.usbmodemRTQ0011");
  //motorRight = new Serial(this,"/dev/tty.usbmodem9");
  
  controll = ControllIO.getInstance(this);
  //controll.printDevices();
  device = controll.getDevice("PLAYSTATION(R)3 Controller");
  //device.printSliders();
  //device.printButtons();
  //device.printSticks();
  
  // Set tolerance
  device.setTolerance(0.1f);
  
  ControllSlider sliderX = device.getSlider(0);
  ControllSlider sliderY = device.getSlider(1);
  ControllSlider sliderZ = device.getSlider(2);
  ControllSlider sliderRZ = device.getSlider(3);
  
  stickLeft = new ControllStick(sliderX,sliderY);
  stickRight = new ControllStick(sliderZ,sliderRZ); 
  
  /*button # : button name
  0   : select
  1   : left stick
  2   : right stick
  3   : start
  4   : dpad up
  5   : dpad right
  6   : dpad down
  7   : dpad left
  8   : L2
  9   : R2
  10  : L1
  11  : R1
  12  : Triangle
  13  : Circle
  14  : X
  15  : Square
  16  : PS
  17  :
  18  :
  */
  
  buttonL1 = device.getButton(10);
  buttonR1 = device.getButton(11);
  buttonL2 = device.getButton(8);
  buttonR2 = device.getButton(9);
  buttonUp = device.getButton(4);
  buttonDown = device.getButton(6);
  buttonTri = device.getButton(12);
  buttonX = device.getButton(14);
  buttonStart = device.getButton(3);
}

int clock = millis();
int lastCmd = 0;
int lastCmdL = 0;
int lastCmdR = 0;
int lastCmdC = 0;
int cmdLeft = 100, cmdRight = 100, cmdChair = 31;
int gainLeft = 5, gainRight = 5, gainChair = 5;
int LEFT_MAX = 750;
int RIGHT_MAX = 750;
int CHAIR_MAX = 150;
float DECEL = 0.95;

void draw(){  

  if(buttonStart.pressed()){
    println("-1 -1");
    exit();
  }
  else if(buttonL2.pressed()){
    cmdChair = constrain(cmdChair - gainChair,0,CHAIR_MAX);
  }
  else if(buttonR2.pressed()){
    cmdChair = constrain(cmdChair + gainChair,0,CHAIR_MAX);
  }
  else if(buttonUp.pressed()){
    cmdLeft = constrain(cmdLeft + gainLeft,0,LEFT_MAX);
  }
  else if(buttonDown.pressed()){
    cmdLeft = constrain(cmdLeft - gainLeft,0,LEFT_MAX);
  }
  else if(buttonTri.pressed()){
    cmdRight = constrain(cmdRight + gainRight,0,RIGHT_MAX);
  }
  else if(buttonX.pressed()){
    cmdRight = constrain(cmdRight - gainRight,0,RIGHT_MAX);
  }
  
  // Draw configs to window.
  // left motor on left side
  background(0,0,0);
  int radiusLeft = round(map(cmdLeft,0,1000,0,100));
  stroke(255,0,0);
  fill(255,0,0);
  ellipse(100,240,radiusLeft,radiusLeft);
  
  //chair at center
  int radiusChair = round(map(cmdChair,0,1000,0,100));
  stroke(0,255,0);
  fill(0,255,0);
  ellipse(300,240,radiusChair,radiusChair);
  
  //right motor on right size
  int radiusRight = round(map(cmdRight,0,1000,0,100));
  stroke(0,0,255);
  fill(0,0,255);
  ellipse(600,240,radiusRight,radiusRight);
  
  int now = millis();
  if(now < clock+lastCmd){
    return;
  }
  else{
    clock = now;
  }
  
  // Send chair command
  if(buttonL1.pressed()){
    int val = -cmdChair;
    while(val < 0){
      println("3 " + val);
      val = sign(val) * floor(val*DECEL);
      lastCmdC = -cmdChair;
    }
  }
  else if(buttonR1.pressed()){
    println("3 " + cmdChair);
    lastCmdC = cmdChair;
  }
  else if(abs(lastCmdC) > abs(lastCmdC)){
    lastCmdC = floor(lastCmdC*DECEL);
    println("3 " + lastCmdC);
  }
  
  // Send left motor command
  float leftY = stickLeft.getY();
  int val = round(leftY*cmdLeft);
  if(abs(val) > abs(lastCmdL)){
    if(abs(val)>75){
      println("1 " + -val);
      lastCmdL = -val;
    }
  }
  else if(abs(lastCmdL) > 75){
    lastCmdL = floor(lastCmdL*DECEL);
    println("1 " + lastCmdL);
  }
  
  // Send right motor command
  float rightY = stickRight.getY();
  val = round(rightY*cmdRight);
  if(abs(val) > 75){
    println(2 + " " + -val);
    lastCmdR = val;
  }
  else if(abs(lastCmdR) > 75){
    lastCmdR = floor(lastCmdR*DECEL);
    println("2 " + lastCmdR);
  }
  lastCmd = floor(max(max(abs(lastCmdL),abs(lastCmdR)),abs(lastCmdC))/2);
}


/* Returns the sign of an int */
public static int sign(int n){
  int ret = n/abs(n);
  assert ret == 1 || ret == -1;
  return ret;
}

/* Sends commands to the specified motor starting at start argument
    and ending at the end argument. */
int DELTA = 10;
public static int sendCommand(int motor, int start, int end){
  int diff = end-start;
  int delta = DELTA * sign(diff);
  while(start<end){
    println(motor + " " + start);
    start += delta;
  }
}
