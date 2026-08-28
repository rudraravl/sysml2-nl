package AcousticRadiometerSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		alias ForceValue for ISQ::ForceValue;
		alias PowerValue for ISQ::PowerValue;
		alias VoltageValue for ISQ::ElectricPotentialValue;
		alias DensityValue for ISQ::MassDensityValue;
		alias SpeedValue for ISQ::SpeedValue;

		item def SoundWave;
		item def RawSignal {
			attribute voltage : VoltageValue;
		}
		item def ConditionedSignal {
			attribute voltage : VoltageValue;
		}
		item def PowerMeasurement {
			attribute power : PowerValue;
		}

		port def SoundPort {
			in sound : SoundWave;
		}
		port def ForceOutPort {
			out force : ForceValue;
		}
		port def ForceInPort {
			in force : ForceValue;
		}
		port def RawSignalOutPort {
			out signal : RawSignal;
		}
		port def RawSignalInPort {
			in signal : RawSignal;
		}
		port def ConditionedSignalOutPort {
			out signal : ConditionedSignal;
		}
		port def ConditionedSignalInPort {
			in signal : ConditionedSignal;
		}
		port def PowerOutPort {
			out power : PowerMeasurement;
		}
		port def PowerInPort {
			in power : PowerMeasurement;
		}

		action def MeasureForce {
			in sound : SoundWave;
			out force : ForceValue;
		}
		action def SenseForce {
			in force : ForceValue;
			out signal : RawSignal;
		}
		action def ConditionSignal {
			in raw : RawSignal;
			out conditioned : ConditionedSignal;
		}
		action def ComputePower {
			in conditioned : ConditionedSignal;
			in density : DensityValue;
			in soundSpeed : SpeedValue;
			in calib : Real;
			out power : PowerMeasurement;
		}
		action def DisplayPower {
			in power : PowerMeasurement;
		}

		state def RadiometerOperation {
			state measuring;
			state processing;
			state displaying;
			transition from measuring to processing;
			transition from processing to displaying;
			transition from displaying to measuring;
		}

		requirement def AccuracyRequirement {
			doc /* The acoustic radiometer shall measure total sound power with an accuracy of at least ±3%. */
			attribute maxError : Real = 0.03;
			constraint { maxError <= 0.03 }
		}

		requirement def ContinuousOperationRequirement {
			doc /* The system shall operate continuously by cycling through measuring, processing, and displaying states. */
		}
	}

	package Usages {
		part def AbsorbentTarget {
			port soundIn : SoundPort;
			port forceOut : ForceOutPort;
			action measureForce : MeasureForce {
				in sound = soundIn.sound;
				out force = forceOut.force;
			}
		}

		part def ForceSensor {
			port forceIn : ForceInPort;
			port signalOut : RawSignalOutPort;
			attribute sensitivity : Real = 0.001 [V/N];
			action senseForce : SenseForce {
				in force = forceIn.force;
				out signal = signalOut.signal;
			}
		}

		part def SignalConditioner {
			port signalIn : RawSignalInPort;
			port signalOut : ConditionedSignalOutPort;
			attribute gain : Real = 100.0;
			attribute filterCutoff : Real = 1000 [Hz];
			action condition : ConditionSignal {
				in raw = signalIn.signal;
				out conditioned = signalOut.signal;
			}
		}

		part def ComputationUnit {
			port signalIn : ConditionedSignalInPort;
			port powerOut : PowerOutPort;
			attribute mediumDensity : DensityValue = 1.225 [kg/m^3];
			attribute speedOfSound : SpeedValue = 343 [m/s];
			attribute calibrationFactor : Real = 1.0;
			action compute : ComputePower {
				in conditioned = signalIn.signal;
				in density = mediumDensity;
				in soundSpeed = speedOfSound;
				in calib = calibrationFactor;
				out power = powerOut.power;
			}
		}

		part def DisplayUnit {
			port powerIn : PowerInPort;
			action display : DisplayPower {
				in power = powerIn.power;
			}
		}

		part def AcousticRadiometer {
			port soundInput : SoundPort;

			part target : AbsorbentTarget;
			part sensor : ForceSensor;
			part conditioner : SignalConditioner;
			part processor : ComputationUnit;
			part display : DisplayUnit;

			bind soundInput = target.soundIn;

			flow forceFlow of ForceValue
				from target.forceOut.force to sensor.forceIn.force;
			flow rawSignalFlow of RawSignal
				from sensor.signalOut.signal to conditioner.signalIn.signal;
			flow conditionedSignalFlow of ConditionedSignal
				from conditioner.signalOut.signal to processor.signalIn.signal;
			flow powerFlow of PowerMeasurement
				from processor.powerOut.power to display.powerIn.power;

			state operation : RadiometerOperation;

			satisfy accReq : AccuracyRequirement;
			satisfy contReq : ContinuousOperationRequirement;
		}

		part acousticRadiometer : AcousticRadiometer;
	}
}
