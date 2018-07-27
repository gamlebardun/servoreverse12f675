# servoreverse12f675
Single RC Servo reverse appliance

In some instances, TX and FC reverse settings cannot achieve the required functionality in software.
I got stuck on a Graupner HOTT, MATEK F405-Wing and Opterra 2m foam delta flyer with pre-installed servos. 
It seems the FC servo reverse is not reversing the output - or perhaps the output before the delta mixer.
Either way, a couple of nights with the PIC 12F675, the PICkit2 and PIC assembler was enjoyable.

On my scope right now, with input and output, the total input+output pulse length is constant at about 3000us.
Overshooting 3000us is because of the calculation between input and output. Consider calibrating your 675 if center is critical.
My servotest12f675 is inputting about 900-2100 auto varying pulse width - yellow/brown input, blue output.
As the input end wanders left and right, the output start follows close behind. No visible change on output end.

The operation is quite simple. Clock is running av 4MHz, which gives instruction clock and timer clock 1MHz - 1us per tick.
Input length is measured with timer1, and a "negative" number is added to this measured value.
The output and timer is then set to run until overflow occurs. Repeat.
As usual, a theoretical center value for servos is 1500us. Any deviation from this is a signed value (typical +/- 600us)
The new output value is the same as the input, just with inverted sign (0 minus measured). 
Both pulses have a 1500us center, so we only need to subtract 3000 (us) from the measured pulse to calculate the overflow preload.
Even the 675 can do that :)

On the hardware side, I soldered a dead-bug mockup in on a cut servo extension cable. The FC provides 5v and servo signal, exactly like a receiver.
I routed black, negative, ground to pin 1 on the 675 (VSS), red, positive, +5v to pin 5 (Vdd) and a 100nF capacitor between the two for ripple suppression.
The power leads pass through the device to supply power for the servo, after feeding the 675 - these are just de-isolated for 1mm.
My input is pin 4, and output pin 3, but of course, these can be set in code for your own preference.
On my lead, these were white, but sometimes they are yellow. Signal is not passing through, so this cable is cut.
Some shrink tube around the 675 - and it looks really professional!

Things I might have messed up:
* There will be no output until an input pulse with acceptable length is received. This is intentional
* Calculation of new value is done after input end and before output start. 
This delay will be a handful of micros. I see no way to avoid this whilst requiring a valid input.
* Most of the time, the 675 does nothing. I should have seized this opportunity to delve into SLEEP

Happy flying!

Ketil

Licensing:
There is no licensing on my work. There is also no warranty on my work. Use it, modify it or reject it as you will.