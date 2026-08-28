package 'Digital Tachometer System' {
	private import ScalarValues::*;

	package Definitions {
		attribute def RPMValue :> Real;
		attribute def TimeWindow :> Real;
		attribute def PulseCount :> Integer;
		attribute def PulsesPerRevolution :> Real;
		attribute def OperatingHours :> Real;

		item def PulseSignal;
		item def RPMData {
			attribute rpm : RPMValue;
		}
		item def ElectricalPower;

		attribute def PowerOnSignal;
		attribute def PowerOffSignal;
		attribute def RPMUpdateSignal;

		port def PulseOutPort {
			out pulse : PulseSignal;
		}
		port def PulseInPort {
			in pulse : PulseSignal;
		}
		port def RPMOutPort {
			out rpmData : RPMData;
		}
		port def RPMInPort {
			in rpmData : RPMData;
		}
		port def PowerOutPort {
			out power : ElectricalPower;
		}
		port def PowerInPort {
			in power : ElectricalPower;
		}

		part def RotatingShaft {
			attribute currentRPM : RPMValue;
			port rotationPort {
				out shaftRotation : RPMValue;
			}
		}

		part def MagneticSensor {
			attribute pulsesPerRevolution : PulsesPerRevolution = 60;
			port shaftPort {
				in shaftRotation : RPMValue;
			}
			port powerIn : PowerInPort;
			port pulseOut : PulseOutPort;
		}

		part def SignalProcessor {
			attribute timeWindow : TimeWindow = 0.1;
			attribute calibrationFactor : PulsesPerRevolution = 60;
			port powerIn : PowerInPort;
			port pulseIn : PulseInPort;
			port rpmOut : RPMOutPort;

			action computeRPM {
				in pulseCount : PulseCount;
				in timeWindow : TimeWindow;
				in calibration : PulsesPerRevolution;
				out rpm : RPMValue;
			}
		}

		part def DigitalDisplay {
			attribute maxSafeRPM : RPMValue = 7000;
			port powerIn : PowerInPort;
			port rpmIn : RPMInPort;
		}

		part def PowerSource {
			port powerOut : PowerOutPort;
		}

		part def TachometerSystem {
			part powerSource : PowerSource;
			part shaft : RotatingShaft;
			part magneticSensor : MagneticSensor;
			part signalProcessor : SignalProcessor;
			part digitalDisplay : DigitalDisplay;
		}

		state def DisplayStates;
		state displayStates : DisplayStates {
			in display : DigitalDisplay;
			in rpmInput : RPMData;
			entry; then off;
			state off;
			accept PowerOnSignal then idle;
			state idle;
			accept RPMUpdateSignal
				if rpmInput.rpm > 0
				then active;
			state active;
			accept RPMUpdateSignal
				if rpmInput.rpm > display.maxSafeRPM
				then warning;
			state warning;
			accept RPMUpdateSignal
				if rpmInput.rpm <= display.maxSafeRPM
				then active;
			accept PowerOffSignal then off;
		}

		requirement def AccuracyRequirement {
			doc /* The displayed RPM shall be within +/- 1% of the actual shaft RPM. */
			subject : displayedRPM : RPMValue;
			objective {
				constraint { displayedRPM >= (actualRPM * 0.99) and displayedRPM <= (actualRPM * 1.01) }
			}
			in actualRPM : RPMValue;
		}

		requirement def ResponsivenessRequirement {
			doc /* The display shall update within 100 milliseconds of a shaft speed change. */
			subject : updateLatency : TimeWindow;
			objective {
				constraint { updateLatency <= 0.1 }
			}
		}

		requirement def ReliabilityRequirement {
			doc /* The tachometer system shall operate continuously for at least 10,000 hours without failure. */
			subject : operatingHours : OperatingHours;
			objective {
				constraint { operatingHours >= 10000 }
			}
		}

		requirement def RedlineWarningRequirement {
			doc /* The display shall enter a warning state when RPM exceeds the maximum safe limit. */
		}
	}

	package Usages {
		private import Definitions::*;

		part tachometerSystem : TachometerSystem {
			connect shaft.rotationPort to magneticSensor.shaftPort;
			connect magneticSensor.pulseOut to signalProcessor.pulseIn;
			connect signalProcessor.rpmOut to digitalDisplay.rpmIn;

			connect powerSource.powerOut to magneticSensor.powerIn;
			connect powerSource.powerOut to signalProcessor.powerIn;
			connect powerSource.powerOut to digitalDisplay.powerIn;

			flow pulseFlow of PulseSignal
				from magneticSensor.pulseOut.pulse to signalProcessor.pulseIn.pulse;
			flow rpmFlow of RPMData
				from signalProcessor.rpmOut.rpmData to digitalDisplay.rpmIn.rpmData;
			flow powerFlow1 of ElectricalPower
				from powerSource.powerOut.power to magneticSensor.powerIn.power;
			flow powerFlow2 of ElectricalPower
				from powerSource.powerOut.power to signalProcessor.powerIn.power;
			flow powerFlow3 of ElectricalPower
				from powerSource.powerOut.power to digitalDisplay.powerIn.power;

			exhibit displayStates {
				in display = digitalDisplay;
				in rpmInput = rpmFlow;
			}

			requirement accuracy : AccuracyRequirement {
				in actualRPM = shaft.rotationPort.shaftRotation;
				subject :>> displayedRPM = rpmFlow.rpm;
			}
			requirement responsiveness : ResponsivenessRequirement {
				subject :>> updateLatency = 0.05;
			}
			requirement reliability : ReliabilityRequirement {
				subject :>> operatingHours = 12000;
			}
			satisfy RedlineWarningRequirement by digitalDisplay;
		}
	}
}
