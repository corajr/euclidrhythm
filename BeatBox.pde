class BeatBox {
  int pulses, steps, channel, pitch, velocity, instrument, duration, timeStep, shift, thisPitch;
  int instrumentIndex;
  String instrumentName;
  Bjorklund myBjorklund;
  ArrayList<Boolean> rhythm;
  float lastTime;
  boolean playing, dragging, tuioDragging, arranged, perc;
  String name;
  float x, y, dx, dy, innerRadius, outerRadius;
  float presentAngle = 0.0, outerGestureRotation = 0.0, gestureScale = 1.0;
  ArrayList pitches;
  int innerZoneData[];

  BeatBox() {
    this(1, 4);
  }

  BeatBox(int _pulses, int _steps) {
    this(_pulses, _steps, 9, 35, 64, 0, 100);
  }
  BeatBox(int _pulses, int _steps, int _pitch) {
    this(_pulses, _steps, 9, _pitch, 64, 0, 100);
    x = random(width);
    y = random(height);
  }
  BeatBox(int _pulses, int _steps, int _pitch, int _x, int _y) {
    this(_pulses, _steps, 9, _pitch, 64, 0, 100);
    x = _x;
    y = _y;
  }


  BeatBox(int _pulses, int _steps, int _channel, int _pitch, int _velocity, int _instrument, int _duration) {
    pulses = _pulses;
    steps = _steps;
    channel = _channel;
    pitch = _pitch;
    velocity = _velocity;
    instrument = _instrument;
    duration = _duration;
    lastTime = 0.0;
    timeStep = 0;
    shift = 0;
    playing = false;
    dragging = false;
    tuioDragging = false;
    arranged = false; // has the object been automatically moved?
    perc = true;
    pitches = new ArrayList();
    thisPitch = 0;
    outerRadius = defaultOuterRadius;
    innerRadius = defaultInnerRadiusRatio * outerRadius;

    if (pulses == steps) {
      myBjorklund = null;
      rhythm = new ArrayList<Boolean>(steps);
      for (int i = 0; i < steps; i++) {
        rhythm.add(true);
      }
    }
    else {
      myBjorklund = new Bjorklund(pulses, steps);
      //    myBjorklund.rotateRightByPulses(1);
      myBjorklund.rotateRightByBits(shift);
      rhythm = myBjorklund.getRhythm();
    }
    name = newID();

    zones.setZone(name + "outer", int(x), int(y), int(outerRadius));
    zones.setZoneParameter(name + "outer", "SCALABLE", true);
    zones.setZoneScaleSensitivity(name + "outer", 0.25);

    zones.setZone(name, int(x), int(y), int(innerRadius));
    zones.setZoneParameter(name, "DRAGGABLE", true);
    zones.setZoneParameter(name, "THROWABLE", true);

    zones.setZone(name + "inst", int(x - 5), int(y - innerRadius), 10, int(innerRadius*2));
    zones.setZoneParameter(name + "inst", "HSWIPEABLE", true);
    zones.pullZoneToTop(name + "inst");
  }

  boolean check() {
    if (timeStep >= rhythm.size()) {
      timeStep = 0;
      return false;
    }
    Boolean thisStep = (Boolean) rhythm.get(timeStep);
    if (thisStep.booleanValue() && pitches.size() > 0 && perc == false) {
      thisPitch = (thisPitch) % pitches.size();
      pitch = ((Integer) pitches.get(thisPitch)).intValue();
      thisPitch = (thisPitch + 1) % pitches.size();
    }
    timeStep = (timeStep + 1) % steps;
    return thisStep.booleanValue();
  }

  void pitchesFromString(String input) {
    ArrayList newPitches = new ArrayList();
    String[] nums = split(input, ",");
    for (int i = 0; i < nums.length; i++) {
      newPitches.add(int(nums[i]));
    }
    pitches = newPitches;
    perc = false;
  }

  void draw() {
    pushMatrix();
    translate(x, y);
    if (dragging || tuioDragging) fill (255, 0, 0);
    else fill (255);
    ellipse(0, 0, innerRadius*2, innerRadius*2);
    pushMatrix();
    if (playing) stroke(255, 0, 0);
    else stroke(0);
    rotate(presentAngle);
    line(0, innerRadius, 0, outerRadius);
    popMatrix();
    float angle = TWO_PI/steps;
    stroke(0);
    for (int i = 0; i < steps; i++) {
      //      line(0, outerRadius, sin(angle)*outerRadius, cos(angle)*outerRadius);
      line(sin(angle*i)*outerRadius, cos(angle*i)*outerRadius, sin(angle*(i+1))*outerRadius, cos(angle*(i+1))*outerRadius);
    }
    for (int i = 0; i < steps; i++) {

      if (rhythm.get(i)) {
        if (timeStep == i) fill(255, 0, 0);
        else fill(0);
        ellipse(sin(angle*(steps-i))*outerRadius, cos(angle*(steps-i))*outerRadius, 16, 16);
      }
      else {
        fill(255);
        ellipse(sin(angle*(steps-i))*outerRadius, cos(angle*(steps-i))*outerRadius, 8, 8);
      }
    }

    popMatrix();
  }

  void update() {
    presentAngle += (TWO_PI/steps)/(interval * (1.0/frameRate));  // 30 fps = 33.33 ms
    if (presentAngle >= TWO_PI) presentAngle -= TWO_PI;
    try {
      innerZoneData = zones.getZoneData(name);
    }
    catch (Exception e) { 
      innerZoneData = new int[] {
        int(x), int(y), int(innerRadius)
      };
    }
    tuioDragging = zones.isZonePressed(name);
    outerGestureRotation = zones.getGestureRotation(name + "outer");

    gestureScale = zones.getGestureScale(name + "outer");

    if (tuioDragging) {
      x = innerZoneData[4];
      y = innerZoneData[5];
      zones.setZoneData(name + "outer", int(x), int(y), int(outerRadius));
      zones.setZoneData(name + "inst", int(x - 5), int(y - innerRadius), 10, int(innerRadius*2));
    }
    else {
      zones.setZoneData(name, int(x), int(y), int(innerRadius));
      zones.setZoneData(name + "outer", int(x), int(y), int(outerRadius));
      zones.setZoneData(name + "inst", int(x - 5), int(y - innerRadius), 10, int(innerRadius*2));
    }
    if (gestureScale != 1.0) {
//      changeSteps(int(constrain(gestureScale * steps, 4, 32)));

      changeSteps(int(8 * constrain(sq(gestureScale), 0.25, 2)));
      outerRadius = constrain(outerRadius * gestureScale, defaultOuterRadius * 0.9, defaultOuterRadius * 1.75);
//      outerRadius = defaultOuterRadius * constrain(gestureScale, 0.9, 2);
      innerRadius = outerRadius * defaultInnerRadiusRatio;
      
      velocity = int(constrain((outerRadius/defaultOuterRadius) * 64, 32, 96));
    }
    if (outerGestureRotation != 0.0) {
      int newPulses = int(outerGestureRotation / 2 * steps);
      if (newPulses < 0) newPulses += steps;
      changePulses(newPulses);
    }
  }

  void setInstrument(int index) {
    instrumentName = (String) instrumentNames.get(index);
    pitch = ((Integer) instrumentPitches.get(index)).intValue();
  }

  void changePulses(int val) {
    if (val <= 0) return;
    if (val >= steps) return;
    pulses = val;
    myBjorklund = new Bjorklund(pulses, steps);
    myBjorklund.rotateRightByPulses(1);
    rhythm = myBjorklund.getRhythm();
    synchronized(labels) {
      labels.clear();
      labels.add(new Label(pulses + "\n" + steps, zones.getZoneX(name), zones.getZoneY(name), color(0)));
    }
  }
  void changeSteps(int val) {
    if (pulses >= val) return;
    if (val <= 0) return;
    steps = val;
    myBjorklund = new Bjorklund(pulses, steps);
    myBjorklund.rotateRightByPulses(1);
    rhythm = myBjorklund.getRhythm();
    synchronized(labels) {
      labels.clear();
      labels.add(new Label(pulses + "\n" + steps, zones.getZoneX(name), zones.getZoneY(name), color(0)));
    }
  }

  void changeShift(int _shift) {
    shift = _shift;
    myBjorklund = new Bjorklund(pulses, steps);
    //    myBjorklund.rotateRightByPulses(1);
    myBjorklund.rotateRightByBits(shift);
    rhythm = myBjorklund.getRhythm();
  }
  void changeVelocity(int _velocity) {
    velocity = _velocity;
  }

  void pitchesEntry(String theText) {
    if (theText.length() > 0) {
      try {
        pitchesFromString(theText);
      }
      catch (Exception e) {
      }
    }
  }

  float distanceToCenter() {
    return sqrt(sq(x - width/2) + sq(y - height/2));
  }
}


// the following is circle packing code from Sean McCullough; see http://www.cricketschirping.com/processing/CirclePacking1/
// which was based in turn off an algorithm found at http://en.wiki.mcneel.com/default.aspx/McNeel/2DCirclePacking

Comparator comp = new Comparator() {
  public int compare(Object p1, Object p2) {
    BeatBox a = (BeatBox)p1;
    BeatBox b = (BeatBox)p2;
    if (a.distanceToCenter() < b.distanceToCenter()) 
      return 1;
    else if (a.distanceToCenter() > b.distanceToCenter())
      return -1;
    else
      return 0;
  }
};

void iterateLayout(int iterationCounter) {

  Object boxes[] = beatboxes.toArray();
  Arrays.sort(boxes, comp);
  float buffer = 20;

  //fix overlaps
  BeatBox ci, cj;
  PVector v = new PVector();

  for (int i=0; i<boxes.length; i++) {
    ci = (BeatBox)boxes[i];
    for (int j=i+1; j<boxes.length; j++) {
      if (i != j) {
        cj = (BeatBox)boxes[j];
        float dx = cj.x - ci.x;
        float dy = cj.y - ci.y;
        float r = ci.outerRadius + cj.outerRadius + buffer*2;
        float d = (dx*dx) + (dy*dy);
        if (d < (r * r) - 0.01 ) {

          v.x = dx;
          v.y = dy;

          v.normalize();
          v.mult((r-sqrt(d))*0.5);

          if (!cj.dragging && !cj.tuioDragging) {
            cj.x += v.x;
            cj.y += v.y;
          }

          if (!ci.dragging && !ci.tuioDragging) {     
            ci.x -= v.x;
            ci.y -= v.y;
          }
        }
      }
    }
  }
  //Contract
  float damping = 0.1/(float)(iterationCounter);
  for (int i=0; i<boxes.length; i++) {
    BeatBox c = (BeatBox)boxes[i];
    if (!c.dragging && !c.tuioDragging) {
      v.x = c.x - width/2;
      v.y = c.y - (height - plusYOffset) /2;
      v.mult(damping);
      c.x -= v.x;
      c.y -= v.y;
    }
  }
}

