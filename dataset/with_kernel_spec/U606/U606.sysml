package 'Auxanometer System' {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ScalarValues::*;
		private import SI::*;

		alias Length for ISQ::LengthValue;
		alias Angle for ISQ::PlaneAngleValue;
		alias Time for ISQ::TimeValue;
		alias Speed for ISQ::SpeedValue;

		/* Operator command signals for state transitions. */
		attribute def StartSignal;
		attribute def StopSignal;
		attribute def PauseSignal;
		attribute def ResumeSignal;
		attribute def CalibrationCompleteSignal;

		/* Composite data types for sensor readings and stored records. */
		attribute def EncoderReading {
			attribute angle : Angle;
			attribute timestamp : Time;
		}

		attribute def MeasurementRecord {
			attribute timestamp : Time;
			attribute displacement : Length;
			attribute growthRate : Speed;
		}

		/* Port definitions for mechanical and data interfaces. */
		port def LinearMotionPort {
			attribute displacement : Length;
		}

		port def RotaryMotionPort {
			attribute angle : Angle;
		}

		port def EncoderDataPort {
			attribute reading : EncoderReading;
		}

		port def MeasurementDataPort {
			attribute timestamp : Time;
			attribute displacement : Length;
			attribute growthRate : Speed;
		}

		/* Action definitions. */
		action def Calibrate {
			out baseline : Length;
		}

		action def AcquireSample {
			in encoderAngle : Angle;
			in sampleTime : Time;
			in baseline : Length;
			in previousDisplacement : Length;
			in deltaTime : Time;
			out displacement : Length;
			out growthRate : Speed;
		}

		action def RecordMeasurement {
			in timestamp : Time;
			in displacement : Length;
			in growthRate : Speed;
		}

		/* Component part definitions. */
		part def PlantSpecimen {
			port contactPoint : LinearMotionPort;
			attribute apexDisplacement : Length;
		}

		part def AttachmentPoint {
			port contactPoint : LinearMotionPort;
			port leverLink : LinearMotionPort;
		}

		part def LeverArm {
			attribute magnification : Real;
			port inputDisplacement : LinearMotionPort;
			port outputDisplacement : LinearMotionPort;
		}

		part def Pulley {
			attribute radius : Length;
			port linearInput : LinearMotionPort;
			port rotaryOutput : RotaryMotionPort;
		}

		part def RotaryEncoder {
			attribute resolution : Real;
			port rotaryInput : RotaryMotionPort;
			port dataOutput : EncoderDataPort;
		}

		part def DataAcquisitionUnit {
			attribute samplingInterval : Time;
			attribute baselineDisplacement : Length;
			attribute lastDisplacement : Length;
			port encoderInput : EncoderDataPort;
			port recordOutput : MeasurementDataPort;

			action calibrate : Calibrate {
				out baseline;
			}

			action acquire : AcquireSample {
				in encoderAngle = encoderInput.reading.angle;
				in sampleTime = encoderInput.reading.timestamp;
				in baseline = baselineDisplacement;
				in previousDisplacement = lastDisplacement;
				in deltaTime = samplingInterval;
				out displacement;
				out growthRate;
			}

			flow acquire.displacement to recordOutput.displacement;
			flow acquire.growthRate to recordOutput.growthRate;
			flow encoderInput.reading.timestamp to recordOutput.timestamp;
		}

		part def RecordingDevice {
			port dataInput : MeasurementDataPort;
			attribute records : MeasurementRecord[*] := ();

			action record : RecordMeasurement {
				in timestamp = dataInput.timestamp;
				in displacement = dataInput.displacement;
				in growthRate = dataInput.growthRate;
			}
		}

		part def Pointer {
			port rotaryInput : RotaryMotionPort;
			port scaleOutput : LinearMotionPort;
		}

		part def GraduatedScale {
			attribute totalRange : Length;
			port readingPosition : LinearMotionPort;
		}

		/* State machine for operational control. */
		state def AuxanometerState {
			entry;
			then idle;
			state idle;
			transition idleToCalibrating
				first idle
				accept StartSignal
				then calibrating;
			state calibrating;
			transition calibratingToMeasuring
				first calibrating
				accept CalibrationCompleteSignal
				then measuring;
			state measuring;
			transition measuringToPaused
				first measuring
				accept PauseSignal
				then paused;
			transition measuringToIdle
				first measuring
				accept StopSignal
				then idle;
			state paused;
			transition pausedToMeasuring
				first paused
				accept ResumeSignal
				then measuring;
			transition pausedToIdle
				first paused
				accept StopSignal
				then idle;
		}

		/* System assembly definition. */
		part def Auxanometer {
			attribute leverMagnification : Real := 10;
			attribute pulleyRadius : Length := 50[mm];
			attribute samplingInterval : Time := 60[s];

			part specimen : PlantSpecimen;
			part attachment : AttachmentPoint;
			part lever : LeverArm {
				:>> magnification = 10;
			}
			part pulley : Pulley {
				:>> radius = 50[mm];
			}
			part encoder : RotaryEncoder;
			part dau : DataAcquisitionUnit {
				:>> samplingInterval = 60[s];
				:>> baselineDisplacement = 0[mm];
				:>> lastDisplacement = 0[mm];
			}
			part recorder : RecordingDevice;
			part pointer : Pointer;
			part scale : GraduatedScale {
				:>> totalRange = 200[mm];
			}

			/* Mechanical chain: plant apex to lever to pulley. */
			connect specimen.contactPoint to attachment.contactPoint;
			connect attachment.leverLink to lever.inputDisplacement;
			connect lever.outputDisplacement to pulley.linearInput;

			/* Rotary encoder senses pulley rotation for digital recording. */
			connect pulley.rotaryOutput to encoder.rotaryInput;
			connect encoder.dataOutput to dau.encoderInput;
			connect dau.recordOutput to recorder.dataInput;

			/* Visual readout: pointer driven by pulley rotation moves along scale. */
			connect pulley.rotaryOutput to pointer.rotaryInput;
			connect pointer.scaleOutput to scale.readingPosition;

			state operationState : AuxanometerState;
		}

		/* Requirements. */
		requirement def AuxanometerRequirement {
			subject theAuxanometer : Auxanometer;
			requirement monitorGrowth {
				doc /* The auxanometer shall continuously monitor minute vertical plant growth. */
			}
			requirement recordMeasurements {
				doc /* The auxanometer shall record timestamped displacement and growth rate data. */
			}
			requirement provideVisualReading {
				doc /* The auxanometer shall provide a direct visual reading via a graduated scale. */
			}
			requirement operatorControl {
				doc /* The auxanometer shall support start, stop, pause, and resume commands. */
			}
		}
	}

	package Usages {
		private import Definitions::*;
		private import SI::*;

		part auxanometer : Auxanometer {
			:>> leverMagnification = 10;
			:>> pulleyRadius = 50[mm];
			:>> samplingInterval = 60[s];

			part specimen : PlantSpecimen {
				:>> apexDisplacement = 0[mm];
			}
			part encoder : RotaryEncoder {
				:>> resolution = 1000;
			}
			part scale : GraduatedScale {
				:>> totalRange = 200[mm];
			}
		}

		requirement growthMeasurementRequirement : AuxanometerRequirement {
			subject theAuxanometer :> auxanometer;
		}
	}
}
