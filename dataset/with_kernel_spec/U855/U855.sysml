package 'Ring Laser Gyroscope' {
	private import ISQ::AngularVelocityValue;
	private import ISQ::FrequencyValue;
	private import ISQ::LengthValue;
	private import ISQ::AreaValue;
	private import ISQ::DurationValue;
	private import Time::TimeInstantValue;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;
	private import ScalarValues::String;
	private import ScalarValues::Integer;
	private import SI::m;
	private import SI::s;
	private import SI::rad;
	private import SI::Hz;
	private import SI::m2;

	attribute def PowerOnSignal;
	attribute def WarmupComplete;
	attribute def LockComplete;
	attribute def StopSignal;
	attribute def FaultSignal;

	attribute def RotationData {
		angularVelocity : AngularVelocityValue;
		timestamp : TimeInstantValue;
	}

	item def LaserBeam;
	item def ClockwiseBeam :> LaserBeam;
	item def CounterClockwiseBeam :> LaserBeam;

	port def OpticalOutputPort {
		out beam : LaserBeam;
	}
	port def OpticalInputPort {
		in beam : LaserBeam;
	}
	port def ElectricalOutputPort {
		out signal : FrequencyValue;
	}
	port def ElectricalInputPort {
		in signal : FrequencyValue;
	}
	port def RotationDataOutputPort {
		out data : RotationData;
	}

	part def Mirror {
		attribute reflectivity : Real;
		port opticalPort {
			in incomingBeam : LaserBeam;
			out outgoingBeam : LaserBeam;
		}
	}

	part def BeamSplitter {
		port inputPort : OpticalInputPort;
		port outputPortA : OpticalOutputPort;
		port outputPortB : OpticalOutputPort;
	}

	part def RingCavity {
		attribute perimeter : LengthValue;
		attribute area : AreaValue;
		part mirror1 : Mirror;
		part mirror2 : Mirror;
		part mirror3 : Mirror;
		part mirror4 : Mirror;
		part beamSplitter : BeamSplitter;
		port cwInputPort : OpticalInputPort;
		port ccwInputPort : OpticalInputPort;
		port cwOutputPort : OpticalOutputPort;
		port ccwOutputPort : OpticalOutputPort;
	}

	part def LaserGainMedium {
		attribute wavelength : LengthValue;
		attribute outputPower : Real;
		port outputPort : OpticalOutputPort;
	}

	part def Photodetector {
		port cwInputPort : OpticalInputPort;
		port ccwInputPort : OpticalInputPort;
		port outputPort : ElectricalOutputPort;
	}

	part def SignalProcessor {
		attribute cavityPerimeter : LengthValue;
		attribute cavityArea : AreaValue;
		attribute laserWavelength : LengthValue;
		port inputPort : ElectricalInputPort;
		port outputPort : RotationDataOutputPort;
	}

	part def RingLaserGyroscope {
		attribute maxAngularRate : AngularVelocityValue;
		attribute warmupDuration : DurationValue;
		attribute isThermallyStable : Boolean;
		attribute isLocked : Boolean;

		part gainMedium : LaserGainMedium {
			:>> wavelength = 632.8e-9 [m];
			:>> outputPower = 5.0;
		}
		part cavity : RingCavity {
			:>> perimeter = 0.40 [m];
			:>> area = 0.012 [m2];
		}
		part detector : Photodetector;
		part processor : SignalProcessor {
			:>> cavityPerimeter = 0.40 [m];
			:>> cavityArea = 0.012 [m2];
			:>> laserWavelength = 632.8e-9 [m];
		}

		port dataPort : RotationDataOutputPort;

		flow laserBeamFlow of LaserBeam
			from gainMedium.outputPort.beam to cavity.beamSplitter.inputPort.beam;
		flow cwBeamFlow of LaserBeam
			from cavity.beamSplitter.outputPortA.beam to detector.cwInputPort.beam;
		flow ccwBeamFlow of LaserBeam
			from cavity.beamSplitter.outputPortB.beam to detector.ccwInputPort.beam;
		flow beatFrequencyFlow of FrequencyValue
			from detector.outputPort.signal to processor.inputPort.signal;
		flow rotationDataFlow of RotationData
			from processor.outputPort.data to dataPort.data;

		state rlgStates {
			in rlg : RingLaserGyroscope;
			entry; then standby;

			state standby {
				do action initializeSystem { /* Initialize subsystems */ }
			}
			accept PowerOnSignal then warmup;

			state warmup {
				entry assign rlg.isThermallyStable := false;
				do action thermalStabilization { /* Reach thermal equilibrium */ }
				exit assign rlg.isThermallyStable := true;
			}
			accept WarmupComplete then locking;

			state locking {
				entry assign rlg.isLocked := false;
				do action stabilizeLaserFrequency { /* Lock laser to cavity resonance */ }
				exit assign rlg.isLocked := true;
			}
			accept LockComplete if rlg.isThermallyStable then operating;

			state operating {
				do action continuousMeasurement { /* Measure and output rotation data */ }
			}
			accept StopSignal then standby;
			accept FaultSignal then standby;
		}
	}

	requirement def SagnacEffectRequirement {
		subject gyroscope : RingLaserGyroscope;
	}

	requirement def BeatFrequencyRequirement {
		subject gyroscope : RingLaserGyroscope;
	}

	requirement def AngularVelocityCalculationRequirement {
		subject gyroscope : RingLaserGyroscope;
	}

	requirement def ThermalStabilityRequirement {
		subject gyroscope : RingLaserGyroscope;
		constraint { gyroscope.isThermallyStable == true }
	}

	requirement def FrequencyLockingRequirement {
		subject gyroscope : RingLaserGyroscope;
		constraint { gyroscope.isLocked == true }
	}

	requirement def StateSequenceRequirement {
		subject gyroscope : RingLaserGyroscope;
	}

	requirement def ContinuousOutputRequirement {
		subject gyroscope : RingLaserGyroscope;
	}

	part ringLaserGyroscope1 : RingLaserGyroscope {
		:>> maxAngularRate = 500.0 [rad/s];
		:>> warmupDuration = 300.0 [s];
		:>> isThermallyStable = false;
		:>> isLocked = false;
	}

	requirement sagnacEffect : SagnacEffectRequirement {
		subject = ringLaserGyroscope1;
	}
	requirement beatFrequency : BeatFrequencyRequirement {
		subject = ringLaserGyroscope1;
	}
	requirement angularVelocityCalc : AngularVelocityCalculationRequirement {
		subject = ringLaserGyroscope1;
	}
	requirement thermalStability : ThermalStabilityRequirement {
		subject = ringLaserGyroscope1;
	}
	requirement frequencyLocking : FrequencyLockingRequirement {
		subject = ringLaserGyroscope1;
	}
	requirement stateSequence : StateSequenceRequirement {
		subject = ringLaserGyroscope1;
	}
	requirement continuousOutput : ContinuousOutputRequirement {
		subject = ringLaserGyroscope1;
	}
}
