// Bjorklund implementation by Kristopher Reese
// from http://kreese.net/blog/2010/03/27/generating-musical-rhythms/

import java.util.*;
 
public class Bjorklund
{
    private ArrayList<Boolean> rhythm = new ArrayList<Boolean>();
    int pauses, per_pulse, remainder, steps, pulses, noskip, skipXTime;
    boolean switcher;
 
    public Bjorklund(int pulses, int steps) {
	this.steps = steps;
	this.pulses = pulses;
	this.pauses = steps - pulses;
	this.switcher = false;
        if (this.pulses > this.pauses) {
	    this.switcher = true;
	    // XOR swap pauses and pulses
	    this.pauses ^= this.pulses;
	    this.pulses ^= this.pauses;
	    this.pauses ^= this.pulses;
	}
	this.per_pulse = (int) Math.floor(this.pauses / this.pulses);
	this.remainder = this.pauses % this.pulses;
	this.noskip = (this.remainder == 0) ? 0 : (int) Math.floor(this.pulses / this.remainder);
        this.skipXTime = (this.noskip == 0) ? 0 : (int)Math.floor((this.pulses - this.remainder)/this.noskip);
 
	this.buildRhythm();
 
        if(this.switcher) {
            // XOR swap pauses and pulses
            this.pauses ^= this.pulses;
            this.pulses ^= this.pauses;
            this.pauses ^= this.pulses;
        }
    }
 
    public Bjorklund(int pulses, int steps, String expected) {
        this(pulses, steps);
        autorotate(expected);
    }
 
    private void buildRhythm() {
        int count = 0;
        int skipper = 0;
	for (int i = 1; i <= this.steps; i++) {
	    if (count == 0) {
                this.rhythm.add(!this.switcher);
                count = this.per_pulse;
 
                if (this.remainder > 0 && skipper == 0) {
	            count++;
	            this.remainder--;
                    skipper = (this.skipXTime > 0) ? this.noskip : 0;
                    this.skipXTime--;
                } else {
                    skipper--;
                }
	    } else {
		this.rhythm.add(this.switcher);
		count--;
	    }
	}
    }
 
    public ArrayList<Boolean> getRhythm() {
	return this.rhythm;
    }
 
    public int getRhythmSize() {
        return this.rhythm.size();
    }
 
    public void autorotate(String expected) {
        boolean verified = false;
        int size = this.rhythm.size();
        int rotate = 1;
        this.rotateRightByPulses(0);
        String found = this.getRhythmString();
        while(!found.equals(expected) || rotate < this.pulses) {
            this.rotateRightByPulses(1);
            found = this.getRhythmString();
            if(found.equals(expected)){
                verified = true;
                break;
            }
        }
 
        if(!verified) {
            System.err.println("Rhythmic string passed cannot be generated from E("+this.pulses+","+this.steps+")");
        }
 
    }
 
    public void rotateRightByBits(int numBits) {
	Collections.rotate(this.rhythm, numBits);
    }
 
    public void rotateRightByPulses(int numPulses) {
	for (int i = 0; i < numPulses; i++) {
	    int rotater = this.rhythm.size() - 1;
	    int count = 1;
	    while (this.rhythm.get(rotater) == false) {
		rotater--;
		count++;
	    }
	    this.rotateRightByBits(count);
	}
    }
 
    private String getRhythmString(){
    	Iterator<Boolean> iterator = this.rhythm.iterator();
    	StringBuffer buffer = new StringBuffer();
    	while(iterator.hasNext()){
    		buffer.append(iterator.next() ? "x" : ".");
    		if(iterator.hasNext()){
    			buffer.append(" ");
    		}
    	}
    	return buffer.toString();
    }
 
    private void print() {
    	System.out.println(this.pulses + ":" + this.steps +" -> ");
    	System.out.print(this.getRhythmString());
    	System.out.println();
    }
 
    public void autoverify(String expected) {
        boolean verified = false;
        int size = this.rhythm.size();
        int rotate = 1;
        this.rotateRightByBits(0);
        String found = this.getRhythmString();
        while(!found.equals(expected) || rotate < size) {
            this.rotateRightByBits(1);
            found = this.getRhythmString();
            if(found.equals(expected)){
                System.out.println("E("+this.pulses+","+this.steps+") verified for <<" + found + ">> by rotating bits right "+rotate+" times");
                verified = true;
                break;
            }
            rotate++;
        }
 
        if(verified == false)
        {
            System.err.println("missed E("+this.pulses+","+this.steps+") expected: <<"+ expected + ">> but found: <<"+found+">>");
        }
    }
 
}
