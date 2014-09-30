import procontroll.*;
import java.io.*;
import processing.serial.*;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.Scanner;

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

// Named pipes
String pnli = "/tmp/pipeli", pnri = "/tmp/piperi", pnci = "/tmp/pipeci";
ReaderThread inL, inR, inC;
String pnlo = "/tmp/pipelo", pnro = "/tmp/pipero", pnco = "/tmp/pipeco";
WriterThread outL, outR, outC;


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
  
  // Set up analog sticks
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

  // Open pipes.
  System.err.println("Opening pipes");
  try{
    inL = new ReaderThread(pnli);
    System.err.println("Opened input left");
    inR = new ReaderThread(pnri);
    System.err.println("Opened input right");
    inC = new ReaderThread(pnci);
    System.err.println("Opened input chair");
    outL = new WriterThread(pnlo);
    System.err.println("Opened output left");
    outR = new WriterThread(pnro);
    System.err.println("Opened output right");
    outC = new WriterThread(pnco);
    System.err.println("Opened output chair");
  }
  catch(FileNotFoundException e){
    System.err.println(e);
    return;
  }
  catch(SecurityException e){
    System.err.println(e);
    return;
  }
}

int clock = millis();

// Motor stuff
Motor L, R, C;
Serial motorLeft;
Serial motorRight;
Serial motorChair;
static final int MOTOR_LEFT = 1, MOTOR_RIGHT = 2, MOTOR_CHAIR = 3;
static final int Q_CAP = 10;
int lastCmd = 0;
int lastCmdL = 0;
int lastCmdR = 0;
int lastCmdC = 0;
int cmdLeft = 100, cmdRight = 100, cmdChair = 31;
int gainLeft = 5, gainRight = 5, gainChair = 5;
static int LEFT_MAX = 750;
static int RIGHT_MAX = 750;
static int CHAIR_MAX = 250;
static float DECEL = 0.5;
static final int DELTA_THRESHOLD_L = 40, DELTA_THRESHOLD_R = 40, DELTA_THRESHOLD_C = 30;
void draw(){  
  /* Pressing start exits. */
  if(buttonStart.pressed()){
    println("-1 -1");
    exit();
  }
  
  /* Check button presses to alter the commands sent to each chair. */
  if(buttonL2.pressed()){
    cmdChair = constrain(cmdChair - gainChair,0,CHAIR_MAX);
  }
  if(buttonR2.pressed()){
    cmdChair = constrain(cmdChair + gainChair,0,CHAIR_MAX);
  }
  if(buttonUp.pressed()){
    cmdLeft = constrain(cmdLeft + gainLeft,0,LEFT_MAX);
  }
  if(buttonDown.pressed()){
    cmdLeft = constrain(cmdLeft - gainLeft,0,LEFT_MAX);
  }
  if(buttonTri.pressed()){
    cmdRight = constrain(cmdRight + gainRight,0,RIGHT_MAX);
  }
  if(buttonX.pressed()){
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
  
  /* Delay so we don't que up too many commands to the motors. */
  int now = millis();
  if(now < clock+(lastCmd*2)){
    return;
  }
  else{
    clock = now;
  }
  
  /* Check L1 and R1 buttons.  R1 rotates chair clockwise and L1 rotates counter-clockwise.
      If both buttons are pressed, prefers L1. 
      I am not going to allow both button presses to send conflicting commands to the chair motor. */
  if(buttonL1.pressed()){
    // If the change between current command and last command is larger than some threshold,
    // Send last command plus threshold.
    int cmd = -cmdChair;
    int delta = cmd - lastCmdC;
    if(abs(delta) > DELTA_THRESHOLD_C){
      cmd = lastCmdC + sign(delta)*DELTA_THRESHOLD_C;
    }
    lastCmdC = sendCommand(MOTOR_CHAIR,cmd);
  }
  else if(buttonR1.pressed()){
    int cmd = cmdChair;
    int delta = cmd - lastCmdC;
    if(abs(delta) > DELTA_THRESHOLD_C){
      cmd = lastCmdC + sign(delta)*DELTA_THRESHOLD_C;
    }
    lastCmdC = sendCommand(3,cmd);
  }
  // If last command was higher than some arbitrary threshold, send deceleration command.
  else if(abs(lastCmdC)>0){
    int ncmd = floor(lastCmdC*DECEL);
    if(ncmd<30) ncmd = 0;
    lastCmdC = sendCommand(MOTOR_CHAIR,ncmd);
  }
  
  // Send left motor command
  float leftY = -stickLeft.getY();
  if(abs(leftY)>0.01){
    int cmd = floor(leftY*cmdLeft);
    cmd = round((cmd+lastCmdL)/2);
    lastCmdL = sendCommand(MOTOR_LEFT,cmd);
  }
  // Send decleration if motor is still spinning and no new input
  else if(abs(lastCmdL)>0){
    int ncmd = floor(lastCmdL*DECEL);
    if(ncmd<30) ncmd = 0;
    lastCmdL = sendCommand(MOTOR_LEFT,ncmd);
  }
  
  // Send right motor command
  float rightY = -stickRight.getY();
  if(abs(rightY)>0.01){
    int cmd = floor(rightY*cmdRight);
    cmd = round((cmd+lastCmdR)/2);
    lastCmdR = sendCommand(MOTOR_RIGHT,cmd);
  }
  // Send deceleration command if motor still spinning and no new input
  else if(abs(lastCmdR)>0){
    int ncmd = floor(lastCmdR*DECEL);
    if(ncmd<30) ncmd = 0;
    lastCmdR = sendCommand(MOTOR_RIGHT,ncmd);
  }
  int[] times = {abs(lastCmdL), abs(lastCmdR), abs(lastCmdC), 60};
  lastCmd = max(times);
  //lastCmd = floor(max(max(abs(lastCmdL),abs(lastCmdR)),abs(lastCmdC)));
}


/* Returns the sign of an int */
public static int sign(int n){
  if(n==0) return 0;
  return n/abs(n);
}

/* Sends commands to the specified motor. */
public static int sendCommand(int motor, int cmd){
  println(motor + " " + cmd);
  return cmd;
}

class Motor{
  int id;         // id of the motor
  int lastCmd;    // last command sent to the motor
  int power;      // current po 
  int gain;
  int max;
  int capacity;
  int threshold;
  float decel = 0.8;
  ReaderThread input;
  WriterThread output;
  
  public Motor(String in, String out, int val, int m, int g, int cap, int thresh){
    try{
      input = new ReaderThread(in,cap);
      input.start();
      output = new WriterThread(out,cap);
      output.start();
    }
    catch(FileNotFoundException e){
      throw new RuntimeException("Could not open motor " + id);
    }
    power = val;
    gain = g;
    max = m;
    lastCmd = 0;
    capacity = cap;
    threshold = thresh;
  }
  
  /* Waits for next int from input and returns it. 
      If thread is interrupted, return the lastCmd. */
  public int read() {
    try{
      return input.take();
    }
    catch(InterruptedException e){
      return lastCmd;
    }
  }
  
  /* Tries to add the value to the queue.
      Returns true if the value was added, false otherwise. */
  public boolean queue(int val){
    return output.puts(val);
  }
}

class ReaderThread extends Thread {
  volatile ArrayBlockingQueue<Integer> q;
  Scanner in;
  
  /* Call base constructor with Q_CAP as capacity. */
  ReaderThread(String fn) throws FileNotFoundException {
    this(fn,Q_CAP);
  }
  
  /* Initializes ReaderThread by opening the given filename and a new queue
      with given capacity. */
  ReaderThread(String fn, int capacity) throws FileNotFoundException{
    q = new ArrayBlockingQueue<Integer>(capacity);
    in = new Scanner(new FileInputStream(fn));
  }
  
  public void run() {
    while(in.hasNextInt()){
      int next = in.nextInt();
      q.offer(next);    // Note that this will drop this command if the queue is full.
    }
  }
  
  /* Returns next item from queue, waiting if necessary. */
  public int take() throws InterruptedException {
    return q.take();
  }
  
  /* Returns number of available items in the queue. */
  public int available(){
    return q.size();
  }
  
  /* Returns true if queue has available items, false otherwise. */
  public boolean hasAvailable(){
    return q.size() > 0;
  }
  
  public int get() throws RuntimeException{
    if(q.size()==0){
      throw new RuntimeException();
    }
    return q.poll();
  }
}

class WriterThread extends Thread{
  volatile ArrayBlockingQueue<Integer> q;
  PrintWriter out;
  
  WriterThread(String fn) throws FileNotFoundException {
    this(fn,Q_CAP);
  }
  
  /* Base constructor. Initializes a queue with given capacity
      and initializes a PrintWriter to the given file using a 
      FileOutputStream. */
  WriterThread(String fn, int capacity) throws FileNotFoundException {
    out = new PrintWriter(new FileOutputStream(fn),true);
    q = new ArrayBlockingQueue<Integer>(capacity);
  }
  
  public void run(){
    if(q.size()>0){
      out.println(q.poll());
    }
    if(isInterrupted()){
      return;
    }
  }
  
  /* Add a command to the queue. */
  public boolean puts(int n){
    return q.offer(n);
  }
}
