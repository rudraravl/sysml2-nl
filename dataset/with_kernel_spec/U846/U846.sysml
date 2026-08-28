package AutomotiveRadarSensingUnit {
	private import SI::*;
	private import ISQ::*;
	private import ScalarValues::Boolean;

	attribute def PowerValue :> Real;

	item def RadioWave {
		attribute frequency : FrequencyValue = 77 [GHz];
		attribute power : PowerValue;
	}

	item def Echo {
		attribute amplitude : PowerValue;
		attribute timeDelay : TimeValue;
		attribute dopplerShift : FrequencyValue;
		attribute phaseShift : AngleValue;
	}

	item def TargetMeasurement {
		attribute range : LengthValue;
		attribute relativeSpeed : SpeedValue;
		attribute angularPosition : AngleValue;
	}

	item def StartScan;
	item def TargetAcquired;
	item def TargetLost;
	item def CalibrateRequest;
	item def CalibrationDone;

	part def Transmitter {
		port waveOut {
			out wave : RadioWave;
		}
	}

	part def AntennaAssembly {
		port txPort {
			in wave : RadioWave;
		}
		port rxPort {
			out echo : Echo;
		}
		port envPort {
			out transmittedWave : RadioWave;
			in receivedEcho : Echo;
		}
	}

	part def Receiver {
		port echoIn {
			in echo : Echo;
		}
		port echoOut {
			out amplifiedEcho : Echo;
		}
	}

	part def SignalProcessingUnit {
		port echoPort {
			in echo : Echo;
		}
		port wavePort {
			in wave : RadioWave;
		}
		port dataPort {
			out targetData : TargetMeasurement;
		}
	}

	constraint def RadarPhysicsEquations {
		in echoSig : Echo;
		in refWaveSig : RadioWave;
		in meas : TargetMeasurement;

		meas.range == (echoSig.timeDelay * 299792458 [m/s]) / 2 and
		meas.angularPosition == echoSig.phaseShift
	}

	action def ProcessEcho {
		in echo : Echo;
		in refWave : RadioWave;
		out target : TargetMeasurement;

		assert constraint calc : RadarPhysicsEquations {
			in echoSig = echo;
			in refWaveSig = refWave;
			in meas = target;
		}
	}

	action def EmitPulse {
		out wave : RadioWave;
	}

	action def TrackTarget {
		in echo : Echo;
		out target : TargetMeasurement;
	}

	action def SelfTest {
		out status : Boolean;
	}

	action def LowPowerMode {
		out status : Boolean;
	}

	part def RadarUnit {
		port envPort {
			out transmittedWave : RadioWave;
			in receivedEcho : Echo;
		}
		port vehiclePort {
			out targetData : TargetMeasurement;
		}

		part transmitter : Transmitter;
		part antenna : AntennaAssembly;
		part receiver : Receiver;
		part processor : SignalProcessingUnit;

		flow waveFlow of RadioWave
			from transmitter.waveOut.wave to antenna.txPort.wave;
		flow envTxFlow of RadioWave
			from antenna.envPort.transmittedWave to envPort.transmittedWave;
		flow envRxFlow of Echo
			from envPort.receivedEcho to antenna.envPort.receivedEcho;
		flow echoFlow of Echo
			from antenna.rxPort.echo to receiver.echoIn.echo;
		flow ampEchoFlow of Echo
			from receiver.echoOut.amplifiedEcho to processor.echoPort.echo;
		flow refWaveFlow of RadioWave
			from transmitter.waveOut.wave to processor.wavePort.wave;
		flow dataFlow of TargetMeasurement
			from processor.dataPort.targetData to vehiclePort.targetData;

		state def RadarStates {
			entry; then standby;

			state standby {
				do action LowPowerMode;
			}
			transition first standby accept StartScan then scanning;

			state scanning {
				do action EmitPulse;
			}
			transition first scanning accept TargetAcquired then tracking;
			transition first scanning accept CalibrateRequest then calibration;

			state tracking {
				do action TrackTarget;
			}
			transition first tracking accept TargetLost then scanning;
			transition first tracking accept CalibrateRequest then calibration;

			state calibration {
				do action SelfTest;
			}
			transition first calibration accept CalibrationDone then standby;
		}

		exhibit state behavior : RadarStates;
	}

	requirement def RadarRequirements {
		subject radar : RadarUnit;

		requirement MeasureRange {
			subject :>> radar;
			doc /* The radar shall measure the range of detected targets. */
		}

		requirement MeasureRelativeSpeed {
			subject :>> radar;
			doc /* The radar shall measure the relative speed of detected targets. */
		}

		requirement MeasureAngularPosition {
			subject :>> radar;
			doc /* The radar shall measure the angular position of detected targets. */
		}

		requirement UpdateRate {
			subject :>> radar;
			doc /* The radar shall provide target measurements at an update rate of 20 Hz. */
			attribute requiredRate : FrequencyValue = 20 [Hz];
		}

		requirement OperatingFrequency {
			subject :>> radar;
			doc /* The transmitter shall generate radio waves at 77 GHz. */
			attribute frequency : FrequencyValue = 77 [GHz];
		}

		requirement OperatingModes {
			subject :>> radar;
			doc /* The radar shall support standby, scanning, tracking, and calibration modes. */
		}
	}

	requirement radarReqs : RadarRequirements;

	part frontRadar : RadarUnit {
		satisfy radarReqs;
	}
}
