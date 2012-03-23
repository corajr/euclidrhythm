/** euclidrhythm
 * by Chris Johnson-Roberson
 * March 21, 2012
 *
 * Bjorklund implementation by Kristopher Reese
 * this program is designed for use with a TUIO tracker; see http://www.tuio.org/?software
 *
 * alternative mouse controls: 
 * right-click: increase pulses, shift-click: increase steps, double-click: switch instrument, alt/command click: remove
 */

import oscP5.*;
import netP5.*;
import tuioZones.*;
import themidibus.*;

MidiBus myBus;
MidiThread midiThread;
ArrayList<BeatBox> beatboxes;
int beatBoxID = 0;
Hashtable<String, Integer> instruments = new Hashtable<String, Integer>();

ArrayList instrumentNames;
ArrayList instrumentPitches;

ArrayList<Label> labels;

PFont sansFont;

TUIOzoneCollection zones;

float bpm = 120.0;
int sliderBPM = 120;
double interval = 0.0;
boolean audio = true, bpmDragging = false;

int defaultOuterRadius;
float defaultInnerRadiusRatio = 0.33;


int plusWidth = 15, plusXOffset = 20, plusYOffset = 80;

void setup() {
  size(screenWidth, screenHeight);
  // to run under Processing 1.5:
  // size(screen.width, screen.height);

  defaultOuterRadius = width / 8;
  plusWidth = width / 85;
  plusXOffset = width / 64;
  plusYOffset = height / 8;


  smooth();
  background(255);

  //  instruments.put("pitched", 60);
  instruments.put("kick", 35);
  instruments.put("snare", 38);
  instruments.put("hi-hat", 42); //closed
  //  instruments.put("open hi-hat", 46);
  instruments.put("clap", 39);
  instruments.put("claves", 75);

  instrumentNames = new ArrayList();
  instrumentPitches = new ArrayList();


  // split instrument hashtable into two lists for easy access

  Enumeration e = instruments.keys();
  while (e.hasMoreElements ()) {
    String inst = (String) e.nextElement();
    instrumentNames.add(inst);
    instrumentPitches.add(((Integer) instruments.get(inst)).intValue());
  }

  myBus = new MidiBus(this, -1, "Java Sound Synthesizer");

  sansFont = createFont("Verdana", 12);
  textFont(sansFont);

  zones = new TUIOzoneCollection(this);

  // add global function zones

    zones.setZone("add", plusXOffset, height - (plusYOffset + (plusWidth * 2)), plusWidth * 5, plusWidth * 5);
  zones.setZone("bpm", width / 2, height - (plusYOffset + (plusWidth * 2)), plusWidth, plusWidth * 5);
  zones.setZoneParameter("bpm", "XDRAGGABLE", true);
  zones.setZone("help", width - (plusXOffset + plusWidth * 5), height - (plusYOffset + (plusWidth*2)), plusWidth * 5, plusWidth * 5);

  labels = new ArrayList<Label>();

  displayHelp();

  beatboxes = new ArrayList<BeatBox>();
  beatboxes.add(new BeatBox(4, 16, 35));
  beatboxes.add(new BeatBox(3, 8, 38));

  arrangeBeatBoxes();

  midiThread = new MidiThread();
  midiThread.start();

  interval = 15000.0/bpm;  // interval in milliseconds
  frameRate(30);
}

void draw() {
  background(255);
  synchronized(beatboxes) {
    ListIterator itr = beatboxes.listIterator();
    while (itr.hasNext ()) {
      BeatBox b = (BeatBox) itr.next();
      b.update();
      if (b.x < 0 || b.x > width || b.y < 0 || b.y > height) { // moved off-screen; delete
        stopBeatBox(b);
        itr.remove();
      }
      else b.draw();
    }
  }
  stroke(0);
  fill(1);
  arrangeBeatBoxes();

  if (zones.getZoneX("bpm") < plusXOffset + plusWidth * 6 || zones.getZoneX("bpm") > width - (plusXOffset + plusWidth * 7)) 
    zones.setZoneData("bpm", constrain(zones.getZoneX("bpm"), plusXOffset + plusWidth * 6, width - (plusXOffset + plusWidth * 7)), zones.getZoneY("bpm"), zones.getZoneWidth("bpm"), zones.getZoneHeight("bpm"));

  sliderBPM = int(map(zones.getZoneX("bpm"), plusXOffset + plusWidth * 6, width - (plusXOffset + plusWidth * 7), 40, 201)) - 1; 
  if (int(bpm) != sliderBPM) {
    bpm(sliderBPM);
  }

  drawOptions();

  synchronized (labels) {
    ListIterator labelItr = labels.listIterator();
    while (labelItr.hasNext ()) {
      Label l = (Label) labelItr.next();
      l.draw();
      if (l.currentFrame == l.framesToDraw) labelItr.remove();
    }
  }



  int[][] coord=zones.getPoints();
  stroke(100, 100, 100);
  strokeWeight(1);
  fill(1);
  if (coord.length>0) {
    for (int i=0;i<coord.length;i++) {
      ellipse(coord[i][0], coord[i][1], 10, 10);
    }
  }
}

void mousePressed() {
  if (mouseX > plusXOffset && mouseX < plusWidth * 5 && mouseY > height - (plusYOffset + (plusWidth * 2)) && mouseY < height - (plusYOffset - (plusWidth*2))) {
    addNewBeatBox(5, 5);
  }
  if (mouseX > width - (plusXOffset + plusWidth * 5) && mouseX < width - plusXOffset && mouseY > height - (plusYOffset + (plusWidth * 2)) && mouseY < height - (plusYOffset - (plusWidth*3))) {
    displayHelp();
  }
  if (mouseX > zones.getZoneX("bpm") && mouseX < zones.getZoneX("bpm") + zones.getZoneWidth("bpm") && mouseY > zones.getZoneY("bpm") && mouseY < zones.getZoneY("bpm") + zones.getZoneHeight("bpm")) {
    bpmDragging = true;
  }
  else bpmDragging = false;

  boolean startDragging = false;
  ListIterator itr = beatboxes.listIterator();
  while (itr.hasNext ()) {
    BeatBox b = (BeatBox) itr.next();
    if (sqrt(sq(mouseX - b.x) + sq(mouseY - b.y)) < b.innerRadius) {
      b.dragging = true;
      startDragging = true;
      if (keyPressed == true && key == CODED && keyCode == SHIFT) {
        b.changeSteps(b.steps + 1 >= 17 ? b.pulses + 1 : b.steps + 1);
      }
      else if (keyPressed == true && key == CODED && (keyCode == 157 || keyCode == 18)) {
        stopBeatBox(b);
        itr.remove();
      }
      else if (mouseButton == RIGHT) {
        b.changePulses(b.pulses + 1 >= b.steps ? 1 : b.pulses + 1);
      }
      else if (mouseEvent.getClickCount()==2) {
        nextInstrument(b);
      }
    }
    else b.dragging = false;
  }
  if (!startDragging) {
    if (mouseEvent.getClickCount()==2) {
      addNewBeatBox(mouseX, mouseY);
    }
  }
}

void mouseDragged() {
  if (bpmDragging) {
    zones.setZoneData("bpm", constrain(zones.getZoneX("bpm") + mouseX - pmouseX, plusXOffset + plusWidth * 6, width - (plusXOffset + plusWidth * 7)), zones.getZoneY("bpm"), zones.getZoneWidth("bpm"), zones.getZoneHeight("bpm"));
  }
  else {
    synchronized(beatboxes) {
      Iterator itr = beatboxes.iterator();
      while (itr.hasNext ()) {
        BeatBox b = (BeatBox) itr.next();
        if (b.dragging) {
          b.x += (mouseX - pmouseX);
          b.y += (mouseY - pmouseY);
        }
      }
    }
  }
}
void mouseReleased() {
  synchronized(beatboxes) {
    Iterator itr = beatboxes.iterator();
    while (itr.hasNext ()) {
      BeatBox b = (BeatBox) itr.next();
      b.dragging = false;
    }
  }
}

void reset() {
  synchronized(beatboxes) {
    Iterator itr = beatboxes.iterator();
    while (itr.hasNext ()) {
      BeatBox b = (BeatBox) itr.next();
      b.presentAngle = 0.0;
      b.timeStep = 0;
      b.playing = false;
      b.dragging = false;
      b.lastTime = 0.0;
      if (audio) {
        myBus.sendNoteOff(b.channel, b.pitch, b.velocity);
        if (b.pitches.size() > 0) {
          Iterator p = b.pitches.iterator();
          while (p.hasNext ()) {
            myBus.sendNoteOff(b.channel, ((Integer) p.next()), b.velocity);
          }
        }
      }
    }
  }
}

void keyPressed() {
  if (key == 's') {
    PrintWriter output;
    output = createWriter(timestamp()+".txt");
    synchronized(beatboxes) {
      Iterator itr = beatboxes.iterator();
      while (itr.hasNext ()) {
        BeatBox b = (BeatBox) itr.next();
        String out = "";
        out += str(b.pulses) + "\t";
        out += str(b.steps) + "\t";
        out += str(b.channel) + "\t";
        out += str(b.pitch) + "\t";
        out += str(b.velocity) + "\t";
        out += str(b.instrument) + "\t";
        out += str(b.shift);
        println(out);
        output.println(out);
      }
    }
    output.flush();
    output.close();
  }
  if (key == 'r') reset();

  if (key == 'p') {
    synchronized(beatboxes) {

      Iterator itr = beatboxes.iterator();
      while (itr.hasNext ()) {
        BeatBox b = (BeatBox) itr.next();
        b.myBjorklund.print();
      }
    }
  }
  if (key == ' ') audio = !audio;
}

String timestamp() {
  Calendar now = Calendar.getInstance();
  return String.format("%1$ty%1$tm%1$td_%1$tH%1$tM%1$tS", now);
}

void readBeatFile(String fileName) {
  beatboxes.clear();
  String lines[] = loadStrings(fileName);
  for (int i = 0; i < lines.length; i++) {
    String[] list = split(lines[i], "\t");
    if (list.length == 7) {
      BeatBox b = new BeatBox(int(list[0]), int(list[1]));
      b.channel = int(list[2]);
      b.pitch = int(list[3]);
      b.velocity = int(list[4]);
      b.instrument = int(list[5]);
      b.shift = int(list[6]);
      beatboxes.add(b);
    }
  }
}

class MidiThread extends Thread {

  boolean running;
  long previousTime;

  MidiThread () { 
    running = false;
  }

  void start () {
    running = true;
    previousTime = System.nanoTime();
    super.start();
  }

  void run () {
    while (running) {
      double timePassed = (System.nanoTime()-previousTime)*1.0e-6;
      while (timePassed < interval) {
        timePassed=(System.nanoTime()-previousTime)*1.0e-6;
      }
      synchronized(beatboxes) {
        Iterator itr = beatboxes.iterator();
        while (itr.hasNext ()) {
          BeatBox b = (BeatBox) itr.next();

          if (b.playing) {
            if (audio) {
              myBus.sendNoteOff(b.channel, b.pitch, b.velocity);
            }
            b.playing = false;
          }
          if (b.check()) {
            b.playing = true;
            b.presentAngle = (TWO_PI/b.steps)*b.timeStep;
            if (audio) {
              myBus.sendMessage(0xC0, b.channel, b.instrument, 0);
              myBus.sendNoteOn(b.channel, b.pitch, b.velocity);
            }
            b.lastTime = millis();
          }
          //      println("midi out: "+timePassed+"ms");
        }
        long delay=(long)(interval-(System.nanoTime()-previousTime)*1.0e-6);
        previousTime=System.nanoTime();
        drowse(delay);
      }
    }
  }

  void quit() {
    running = false;
    interrupt();
  }
}

void bpm(int val) {
  bpm = val;
  interval = 15000.0/bpm;
}

void drowse(long wait) {
  try {
    Thread.sleep(wait);
  } 
  catch (Exception e) {
  }
}

String newID() {
  beatBoxID += 1;
  return "zone" + str(beatBoxID);
}

void arrangeBeatBoxes() {
  for (int i = 1; i < 10; i++) {
    iterateLayout(i);
  }
}

void drawOptions() {
  stroke(0);
  fill(0);

  // draw addition sign
  rect(plusXOffset, height - plusYOffset, plusWidth * 5, plusWidth);
  rect(plusXOffset + (plusWidth * 2), height - (plusYOffset + (plusWidth*2)), plusWidth, plusWidth * 5);

  // draw BPM slider

  text(str(int(bpm)), zones.getZoneX("bpm"), zones.getZoneY("bpm") - 16);
  zones.drawRect("bpm");
  fill(255);
  text("B\nP\nM", zones.getZoneX("bpm") + 2, zones.getZoneY("bpm") + 16);
  fill(0);

  // draw question mark
  rect(width - (plusXOffset + plusWidth * 5), height - (plusYOffset + (plusWidth*2)), plusWidth * 5, plusWidth);
  rect(width - (plusXOffset + plusWidth), height - (plusYOffset + (plusWidth)), plusWidth, plusWidth);
  rect(width - (plusXOffset + plusWidth * 3), height - (plusYOffset), plusWidth * 3, plusWidth);
  rect(width - (plusXOffset + plusWidth * 3), height - (plusYOffset - (plusWidth)), plusWidth, plusWidth);
  rect(width - (plusXOffset + plusWidth * 3), height - (plusYOffset - (plusWidth*3)), plusWidth, plusWidth);
}

void addNewBeatBox(int x, int y) {
  float rand = random(4);
  BeatBox beat = new BeatBox(4, rand < 3 ? 16 : int(random(4, 32)), 35, x, y);
  synchronized (beatboxes) {
    beatboxes.add(beat);
  }
  reset();
}

void displayHelp() {
  labels.add(new Label("euclidean rhythms\n\n"+
    "press + button to add\n" +
    "drag offscreen to remove\n" + 
    "swipe/double-click to change instrument\n" +
    "rotate/right-click to change pulses\n" +
    "pinch/alt-click to change steps", 10, 20, color(0), 450));
}

void clickEvent(String zName) {
  if (zName.equals("add")) {
    addNewBeatBox(5, 5);
  }
  if (zName.equals("help")) {
    displayHelp();
  }
}

void hSwipeEvent(String zName) {
  //  println(zName);
  Iterator itr = beatboxes.iterator();
  while (itr.hasNext ()) {
    BeatBox b = (BeatBox) itr.next();
    if ((b.name + "inst").equals(zName)) {
      nextInstrument(b);
    }
  }
}

void nextInstrument(BeatBox b) {
  b.instrumentIndex = (b.instrumentIndex + 1) % instrumentNames.size();
  b.setInstrument(b.instrumentIndex);
  synchronized(labels) {
    labels.add(new Label(b.instrumentName, int(b.x), int(b.y)));
  }
}

void stopBeatBox(BeatBox b) {
  if (audio) myBus.sendNoteOff(b.channel, b.pitch, b.velocity);
  zones.killZone(b.name);
  zones.killZone(b.name + "outer");
  zones.killZone(b.name + "inst");
}


class Label {
  String myText;
  int x, y, framesToDraw, currentFrame;
  color myColor;
  float myOpacity;

  Label(String _text, int _x, int _y) {
    this(_text, _x, _y, 30);
  }
  Label(String _text, int _x, int _y, color _myColor) {
    this(_text, _x, _y, _myColor, 30);
  }

  Label(String _text, int _x, int _y, color _myColor, int _framesToDraw) {
    myText = _text;
    myColor = _myColor;
    myOpacity = 255.0;
    x = _x;
    y = _y;
    framesToDraw = _framesToDraw;
    currentFrame = 0;
  }

  void draw() {
    fill(myColor, myOpacity * cos(float(currentFrame) * (PI/2) / framesToDraw));
    textFont(sansFont);
    text(myText, x, y);
    currentFrame++;
  }
}

