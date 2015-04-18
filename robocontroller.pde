import procontroll.*;
import java.io.*;
import processing.serial.*;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.Scanner;

// Controller stuff
ControllIO controll;
ControllDevice device;

//analog sticks
ControllStick stickLeft, stickRight;

//buttons
ControllButton buttonStart;
ControllButton buttonL1, buttonR1, buttonL2, buttonR2;
ControllButton buttonUp, buttonDown, buttonLeft, buttonRight;
ControllButton buttonTri, buttonX, buttonSquare, buttonO;

void setup() {
  size(640, 480);
  textSize(32);

  controll = ControllIO.getInstance(this);
  //controll.printDevices();
  device = controll.getDevice("PLAYSTATION(R)3 Controller");
  //device.printSliders();
  //device.printButtons();
  //device.printSticks();

  // Set tolerance
  device.setTolerance(0.1f);

  // Set up analog sticks
  ControllSlider sliderX = device.getSlider(0);
  ControllSlider sliderY = device.getSlider(1);
  ControllSlider sliderZ = device.getSlider(2);
  ControllSlider sliderRZ = device.getSlider(3);

  stickLeft = new ControllStick(sliderX, sliderY);
  stickRight = new ControllStick(sliderZ, sliderRZ); 

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
  // Initialize buttons.
  buttonL1 = device.getButton(10);
  buttonR1 = device.getButton(11);
  buttonL2 = device.getButton(8);
  buttonR2 = device.getButton(9);
  buttonUp = device.getButton(4);
  buttonDown = device.getButton(6);
  buttonTri = device.getButton(12);
  buttonX = device.getButton(14);
  buttonStart = device.getButton(3);
  buttonLeft = device.getButton(7);
  buttonRight = device.getButton(5);
  buttonSquare = device.getButton(15);
  buttonO = device.getButton(13);
}

int clock = millis();

// Motor stuff
Serial motorLeft;
Serial motorRight;
Serial motorChair;
static final int MOTOR_LEFT = 1, MOTOR_RIGHT = 2, MOTOR_CHAIR = 3;
static final int Q_CAP = 10;
static final int DEFAULT_CMD_DUR = 25;
static int turn_duration = 3600;
static int gain_turn_duration = 10;
int lastCmd = 0;
int lastCmdL = 0;
int lastCmdR = 0;
int lastCmdC = 0;
static int prev_cmd_dur = 0;
int cmdLeft = 100, cmdRight = 100, cmdChair = 65;
int gainLeft = 5, gainRight = 5, gainChair = 5;
static int LEFT_MAX = 1000;
static int RIGHT_MAX = 1000;
static int CHAIR_MAX = 250;
static float DECEL = 0.3;
static final int DELTA_THRESHOLD_L = 20, DELTA_THRESHOLD_R = 20, DELTA_THRESHOLD_C = 30;

// Store times for previous config changes to make it easier to set the correct values for commands.
int last_chair_adjust = millis(), last_left_adjust = millis(), last_right_adjust = millis();
int last_duration_adjust = millis();
// Set the interval between button presses before configs are updated.
static final int ADJUST_INTERVAL = 150;

// Main routine
void draw() {  
  /* Pressing start exits. */
  if (buttonStart.pressed()) {
    println("-1 -1");
    exit();
  }

  /* Check button presses to alter the commands sent to chair. */
  if (millis()-last_chair_adjust > ADJUST_INTERVAL){
    if (buttonL2.pressed()) {
      cmdChair = constrain(cmdChair - gainChair, 0, CHAIR_MAX);
      last_chair_adjust = millis();
    }
    else if (buttonR2.pressed()) {
      cmdChair = constrain(cmdChair + gainChair, 0, CHAIR_MAX);
      last_chair_adjust = millis();
    }
  }
  
  /* Check for config changes to left motor. */
  if (millis()-last_left_adjust > ADJUST_INTERVAL){
    if (buttonUp.pressed()) {
      cmdLeft = constrain(cmdLeft + gainLeft, 0, LEFT_MAX);
      last_left_adjust = millis();
    }
    else if (buttonDown.pressed()) {
      cmdLeft = constrain(cmdLeft - gainLeft, 0, LEFT_MAX);
      last_left_adjust = millis();
    }
  }
  
  /* Check for config changes to right motor. */
  if(millis()-last_right_adjust > ADJUST_INTERVAL){
    if (buttonTri.pressed()) {
      cmdRight = constrain(cmdRight + gainRight, 0, RIGHT_MAX);
      last_right_adjust = millis();
    }
    if (buttonX.pressed()) {
      cmdRight = constrain(cmdRight - gainRight, 0, RIGHT_MAX);
      last_right_adjust = millis();
    }
  }

  
  /* Check for changes to command duration. */
  if(millis()-last_duration_adjust > ADJUST_INTERVAL){
    if (buttonO.pressed()){
      turn_duration += gain_turn_duration;
      last_duration_adjust = millis();
    }
    if (buttonSquare.pressed()){
      turn_duration = max(10,turn_duration-gain_turn_duration);
      last_duration_adjust = millis();
    }
  }

  // Draw configs to window.
  // left motor on left side
  background(0, 0, 0);
  int radiusLeft = round(map(cmdLeft, 0, 1000, 0, 100));
  stroke(255, 0, 0);
  fill(255, 0, 0);
  ellipse(100, 240, radiusLeft, radiusLeft);
  fill(255,255,255);
  text(cmdLeft,75,200);

  //chair at center
  int radiusChair = round(map(cmdChair, 0, 1000, 0, 100));
  stroke(0, 255, 0);
  fill(0, 255, 0);
  ellipse(300, 240, radiusChair, radiusChair);
  fill(255,255,255);
  text(cmdChair,275,200);

  //right motor on right size
  int radiusRight = round(map(cmdRight, 0, 1000, 0, 100));
  stroke(0, 0, 255);
  fill(0, 0, 255);
  ellipse(600, 240, radiusRight, radiusRight);
  fill(255,255,255);
  text(cmdRight,575,200);

  // Draw turn command duration
  fill(0,255,0);
  text(turn_duration,10,100);
  
  /* Delay so we don't que up too many commands to the motors. */
  int now = millis();
  if (now < clock+prev_cmd_dur) {
    return;
  } else {
    clock = now;
  }

  /* Check L1 and R1 buttons.  R1 rotates chair clockwise and L1 rotates counter-clockwise.
   If both buttons are pressed, prefers L1. 
   I am not going to allow both button presses to send conflicting commands to the chair motor. */
  if (buttonL1.pressed()) {
    // If the change between current command and last command is larger than some threshold,
    // Send last command plus threshold.
    int cmd = -cmdChair;
    int delta = cmd - lastCmdC;
    if (abs(delta) > DELTA_THRESHOLD_C) {
      cmd = lastCmdC + sign(delta)*DELTA_THRESHOLD_C;
    }
    lastCmdC = sendCommand(MOTOR_CHAIR, cmd);
  } else if (buttonR1.pressed()) {
    int cmd = cmdChair;
    int delta = cmd - lastCmdC;
    if (abs(delta) > DELTA_THRESHOLD_C) {
      cmd = lastCmdC + sign(delta)*DELTA_THRESHOLD_C;
    }
    lastCmdC = sendCommand(3, cmd);
  } else if (buttonLeft.pressed()){
    // Rotate chair 180 ccw
    lastCmdC = sendCommand(MOTOR_CHAIR, -65, turn_duration);
    delay(500);
    lastCmdC = sendCommand(MOTOR_CHAIR, 0, 25); // brake

  } else if (buttonRight.pressed()){
    // Rotate chair 180 cw
    lastCmdC = sendCommand(MOTOR_CHAIR, 65, turn_duration);
    delay(500);
    lastCmdC = sendCommand(MOTOR_CHAIR, 0, 25); // brake
  }
   
    
  // If last command was higher than some arbitrary threshold, send deceleration command.
  else if (abs(lastCmdC)>0) {
    int ncmd = floor(lastCmdC*DECEL);
    if (ncmd<30) ncmd = 0;
    lastCmdC = sendCommand(MOTOR_CHAIR, ncmd);
  }

  // Send left motor command
  float leftY = -stickLeft.getY();
  if (abs(leftY)>0.01) {
    int cmd = floor(leftY*cmdLeft);
    cmd = round((cmd+lastCmdL)/2);
    lastCmdL = sendCommand(MOTOR_LEFT, cmd);
  }
  // Send decleration if motor is still spinning and no new input
  else if (abs(lastCmdL)>0) {
    int ncmd = floor(lastCmdL*DECEL);
    if (ncmd<30) ncmd = 0;
    lastCmdL = sendCommand(MOTOR_LEFT, ncmd);
  }

  // Send right motor command
  float rightY = -stickRight.getY();
  if (abs(rightY)>0.01) {
    int cmd = floor(rightY*cmdRight);
    cmd = round((cmd+lastCmdR)/2);
    lastCmdR = sendCommand(MOTOR_RIGHT, cmd);
  }
  // Send deceleration command if motor still spinning and no new input
  else if (abs(lastCmdR)>0) {
    int ncmd = floor(lastCmdR*DECEL);
    if (ncmd<30) ncmd = 0;
    lastCmdR = sendCommand(MOTOR_RIGHT, ncmd);
  }
  int[] times = {
    abs(lastCmdL), abs(lastCmdR), abs(lastCmdC), 60
  };
  lastCmd = max(times);
  //lastCmd = floor(max(max(abs(lastCmdL),abs(lastCmdR)),abs(lastCmdC)));
}


/* Returns the sign of an int */
public static int sign(int n) {
  if (n==0) return 0;
  return n/abs(n);
}

/* Sends commands to the specified motor. */
public static int sendCommand(int motor, int cmd, int dur) {
  //System.out.printf("%d %d %d\n",motor,cmd,dur);
  System.out.println(motor + " " + cmd + " " + dur);
  prev_cmd_dur = dur;
  return cmd;
}

/* Sends command and default duration to motor. */
public static int sendCommand(int motor, int cmd){
  return sendCommand(motor, cmd, DEFAULT_CMD_DUR);
}

