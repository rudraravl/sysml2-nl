package 'Quartz Analog Clock' {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def ElectricalSignal;
		item def Rotation;
		
		port def SignalOutPort {
			out item signal : ElectricalSignal;
		}
		port def SignalInPort {
			in item signal : ElectricalSignal;
		}
		port def MechanicalOutPort {
			out item rotation : Rotation;
		}
		port def MechanicalInPort {
			in item rotation : Rotation;
		}
		
		part def Battery {
			attribute voltage : ISQ::VoltageValue = 1.5 [V];
			port powerOut : SignalOutPort;
		}
		
		part def QuartzCrystalOscillator {
			attribute nominalFrequency : FrequencyValue = 32768 [Hz];
			port powerIn : SignalInPort;
			port signalOut : SignalOutPort;
			perform action generateSignal {
				out sig : ElectricalSignal;
			}
		}
		
		part def FrequencyDividerIC {
			port signalIn : SignalInPort;
			port pulseOut : SignalOutPort;
			perform action divideFrequency {
				in highFreqSignal : ElectricalSignal;
				out oneHzPulse : ElectricalSignal;
			}
		}
		
		part def StepperMotor {
			port pulseIn : SignalInPort;
			port shaftOut : MechanicalOutPort;
			perform action step {
				in pulse : ElectricalSignal;
				out rotation : Rotation;
			}
		}
		
		part def GearTrain {
			port shaftIn : MechanicalInPort;
			port handsOut : MechanicalOutPort;
			attribute gearRatio : Real;
		}
		
		part def AnalogDisplay {
			port handsIn : MechanicalInPort;
			part secondHand;
			part minuteHand;
			part hourHand;
		}
		
		part def TimeCounter {
			port pulseIn : SignalInPort;
			attribute hours : Integer = 0;
			attribute minutes : Integer = 0;
			attribute seconds : Integer = 0;
			perform action incrementTime {
				in pulse : ElectricalSignal;
			}
		}
		
		requirement def BatteryLifeRequirement {
			subject clock : QuartzAnalogClock;
			require constraint { clock.batteryLife >= 31536000 [s] }
		}
		
		requirement def AccuracyRequirement {
			subject clock : QuartzAnalogClock;
			require constraint { clock.timeDrift <= 15.0 [s] }
		}
		
		requirement def OscillationFrequencyRequirement {
			subject oscillator : QuartzCrystalOscillator;
			require constraint { oscillator.nominalFrequency == 32768.0 [Hz] }
		}
		
		part def QuartzAnalogClock {
			attribute batteryLife : TimeValue;
			attribute timeDrift : TimeValue;
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part clock : QuartzAnalogClock {
			part battery : Battery;
			part oscillator : QuartzCrystalOscillator;
			part divider : FrequencyDividerIC;
			part motor : StepperMotor;
			part gearTrain : GearTrain;
			part display : AnalogDisplay;
			part timeCounter : TimeCounter;
			
			flow of power : ElectricalSignal
				from battery.powerOut.signal to oscillator.powerIn.signal;
				
			flow of highFreqSignal : ElectricalSignal
				from oscillator.signalOut.signal to divider.signalIn.signal;
				
			flow of oneHzPulse : ElectricalSignal
				from divider.pulseOut.signal to motor.pulseIn.signal;
				
			flow of oneHzPulse2 : ElectricalSignal
				from divider.pulseOut.signal to timeCounter.pulseIn.signal;
				
			flow of rotation : Rotation
				from motor.shaftOut.rotation to gearTrain.shaftIn.rotation;
				
			flow of handsRotation : Rotation
				from gearTrain.handsOut.rotation to display.handsIn.rotation;
		}
		
		satisfy BatteryLifeRequirement by clock;
		satisfy AccuracyRequirement by clock;
		satisfy OscillationFrequencyRequirement by clock.oscillator;
	}
}
