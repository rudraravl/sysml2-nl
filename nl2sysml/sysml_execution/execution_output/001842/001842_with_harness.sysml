package QuartzClockSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def CurrentValue :> ISQ::ElectricCurrentValue;
	attribute def AngleValue :> ISQ::PlaneAngleValue;
	
	item def ElectricalPower {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	item def OscillationSignal {
		attribute frequency : FrequencyValue;
		attribute amplitude : VoltageValue;
	}
	
	item def PulseSignal {
		attribute rate : FrequencyValue;
	}
	
	item def MotorCommand {
		attribute stepAngle : AngleValue;
	}
	
	item def TimeValue {
		attribute hours : Integer;
		attribute minutes : Integer;
		attribute seconds : Integer;
	}
	
	port def PowerPort {
		out item power : ElectricalPower;
	}
	
	port def OscillationPort {
		out item signal : OscillationSignal;
	}
	
	port def PulsePort {
		out item pulse : PulseSignal;
	}
	
	port def MotorPort {
		in item command : MotorCommand;
	}
	
	port def TimePort {
		out item time : TimeValue;
	}
	
	part def Battery {
		attribute nominalVoltage : VoltageValue;
		attribute capacity : Real;
		port powerOutput : PowerPort;
	}
	
	part def QuartzCrystal {
		attribute resonantFrequency : FrequencyValue;
		port oscillationOutput : OscillationPort;
		
		state crystalOperation {
			entry; then oscillating;
			state oscillating {
				do action generateOscillation {
					out signal : OscillationSignal;
					assign signal.frequency := resonantFrequency;
				}
			}
		}
	}
	
	part def OscillatorCircuit {
		attribute targetFrequency : FrequencyValue;
		port powerInput : PowerPort;
		port signalOutput : OscillationPort;
		
		part crystal : QuartzCrystal {
			attribute :>> resonantFrequency = targetFrequency;
		}
		
		action sustainOscillation {
			in power : ElectricalPower;
			out oscillation : OscillationSignal;
			
			first start;
			then action amplify {
				in crystalSignal : OscillationSignal;
			}
			then action feedback {
				out sustainedSignal : OscillationSignal;
			}
			then assign oscillation := feedback.sustainedSignal;
		}
	}
	
	part def FrequencyDividerIC {
		attribute inputFrequency : FrequencyValue;
		attribute divisionFactor : Integer;
		port signalInput : OscillationPort;
		port pulseOutput : PulsePort;
		
		action divideFrequency {
			in inputSignal : OscillationSignal;
			out outputPulse : PulseSignal;
			
			private attribute cycleCount : Integer := 0;
			
			first start;
			then merge countCycles;
			then action incrementCounter {
				assign cycleCount := cycleCount + 1;
			}
			then decide;
				if cycleCount >= divisionFactor then emitPulse;
				if cycleCount < divisionFactor then countCycles;
			action emitPulse {
				assign cycleCount := 0;
				assign outputPulse.rate := inputSignal.frequency / divisionFactor;
			}
			then countCycles;
		}
	}
	
	part def StepperMotor {
		attribute stepAngle : AngleValue;
		port commandInput : MotorPort;
		
		action executeStep {
			in cmd : MotorCommand;
		}
	}
	
	part def GearTrain {
		attribute secondsGearRatio : Real;
		attribute minutesGearRatio : Real;
		attribute hoursGearRatio : Real;
		
		action transmitMotion {
			in motorRotation : AngleValue;
			out secondsRotation : AngleValue;
			out minutesRotation : AngleValue;
			out hoursRotation : AngleValue;
			
			assign secondsRotation := motorRotation * secondsGearRatio;
			assign minutesRotation := motorRotation * minutesGearRatio;
			assign hoursRotation := motorRotation * hoursGearRatio;
		}
	}
	
	part def TimeCounter {
		port pulseInput : PulsePort;
		port timeOutput : TimePort;
		
		private attribute secondsCount : Integer := 0;
		private attribute minutesCount : Integer := 0;
		private attribute hoursCount : Integer := 0;
		
		action updateTime {
			assign secondsCount := (secondsCount + 1) % 60;
			if secondsCount == 0 then incrementMinutes;
			
			action incrementMinutes {
				assign minutesCount := (minutesCount + 1) % 60;
				if minutesCount == 0 then incrementHours;
				
				action incrementHours {
					assign hoursCount := (hoursCount + 1) % 12;
				}
			}
		}
		
		action outputTime {
			out currentTime : TimeValue;
			assign currentTime.hours := hoursCount;
			assign currentTime.minutes := minutesCount;
			assign currentTime.seconds := secondsCount;
		}
	}
	
	part def AnalogDisplay {
		port timeInput : TimePort;
		
		action displayTime {
			in time : TimeValue;
			
			action positionHourHand {
				in hours : Integer = time.hours;
			}
			then action positionMinuteHand {
				in minutes : Integer = time.minutes;
			}
			then action positionSecondHand {
				in seconds : Integer = time.seconds;
			}
		}
	}
	
	part def QuartzClock {
		attribute operatingVoltage : VoltageValue;
		attribute crystalFrequency : FrequencyValue;
		attribute divisionRatio : Integer;
		
		part powerSource : Battery {
			attribute :>> nominalVoltage = operatingVoltage;
			attribute :>> capacity = 2000.0;
		}
		
		part oscillator : OscillatorCircuit {
			attribute :>> targetFrequency = crystalFrequency;
		}
		
		part divider : FrequencyDividerIC {
			attribute :>> inputFrequency = crystalFrequency;
			attribute :>> divisionFactor = divisionRatio;
		}
		
		part counter : TimeCounter;
		
		part motor : StepperMotor {
			attribute :>> stepAngle = 6.0 [deg];
		}
		
		part gears : GearTrain {
			attribute :>> secondsGearRatio = 1.0;
			attribute :>> minutesGearRatio = 1.0 / 60.0;
			attribute :>> hoursGearRatio = 1.0 / 720.0;
		}
		
		part display : AnalogDisplay;
		
		connect powerSource.powerOutput to oscillator.powerInput;
		connect oscillator.signalOutput to divider.signalInput;
		connect divider.pulseOutput to counter.pulseInput;
		connect divider.pulseOutput to motor.commandInput;
		connect counter.timeOutput to display.timeInput;
		
		perform action operateClock {
			doc /* 
			 * The primary function of the quartz clock is to accurately measure and display time.
			 * It generates a stable high-frequency oscillation using a quartz crystal, divides this
			 * frequency down to one pulse per second, and uses these pulses to drive a stepper motor
			 * that moves the clock hands through a gear train while maintaining an internal time count.
			 */
			
			first start;
			then merge maintainTime;
			then action generateStableOscillation references oscillator.sustainOscillation;
			then action convertToPulses references divider.divideFrequency;
			then action updateTimeCount references counter.updateTime;
			then action outputCurrentTime references counter.outputTime;
			then action driveMotor references motor.executeStep;
			then action showTime references display.displayTime;
			then maintainTime;
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The clock shall maintain accurate timekeeping within specified tolerance. */
		attribute maxDriftPerMonth : ISQ::TimeValue;
	}
	
	requirement def PowerEfficiencyRequirement {
		doc /* The clock shall operate efficiently on battery power. */
		attribute minBatteryLife : ISQ::TimeValue;
	}
	
	requirement def ReliabilityRequirement {
		doc /* The clock shall operate reliably under normal conditions. */
		attribute minOperatingTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute maxOperatingTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	requirement <'CLK-REQ-001'> quartzClockSystemRequirements {
		doc /* 
		 * The quartz clock system shall provide accurate, reliable timekeeping
		 * by leveraging the stable oscillation of a quartz crystal.
		 */
		
		subject clockSystem : QuartzClock;
		
		require accuracyReq : AccuracyRequirement {
			attribute :>> maxDriftPerMonth = 15.0 [s];
		}
		
		require powerReq : PowerEfficiencyRequirement {
			attribute :>> minBatteryLife = 31536000.0 [s];
		}
		
		require reliabilityReq : ReliabilityRequirement {
			attribute :>> minOperatingTemperature = 263.15 [K];
			attribute :>> maxOperatingTemperature = 313.15 [K];
		}
		
		assume constraint crystalStability {
			doc /* The quartz crystal maintains stable resonant frequency at 32768 Hz. */
		}
		
		assume constraint powerSupplyStability {
			doc /* The battery provides stable voltage throughout its operational life. */
		}
	}
	
	part quartzClockInstance : QuartzClock {
		attribute :>> operatingVoltage = 1.5 [V];
		attribute :>> crystalFrequency = 32768.0 [Hz];
		attribute :>> divisionRatio = 32768;
		
		satisfy quartzClockSystemRequirements by quartzClockInstance;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import QuartzClockSystem::*;
    part testSubject : Battery;
    // TODO(human): define boundary input values for: voltage, current, frequency, amplitude, rate, stepAngle, hours, minutes
}
