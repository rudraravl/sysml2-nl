package 'RadarSensingUnit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def Frequency :> ISQ::frequency;
	attribute def Velocity :> ISQ::velocity;
	attribute def Distance :> ISQ::length;
	attribute def Angle :> ISQ::angle;
	attribute def Power :> ISQ::power;

	item def RadarWaveform {
		attribute carrierFrequency : Frequency;
		attribute transmitPower : Power;
		attribute pulseWidth : Real;
		attribute timestamp : Real;
	}

	item def EchoSignal {
		attribute receivedPower : Power;
		attribute timeDelay : Real;
		attribute dopplerShift : Frequency;
		attribute phaseShift : Angle;
	}

	item def TargetMeasurement {
		attribute range : Distance;
		attribute radialVelocity : Velocity;
		attribute azimuthAngle : Angle;
		attribute elevationAngle : Angle;
		attribute signalStrength : Power;
		attribute measurementTime : Real;
		attribute confidence : Real;
	}

	enum def OperatingMode {
		enum standby;
		enum active;
		enum tracking;
		enum calibration;
	}

	port def TransmitPort {
		out item waveform : RadarWaveform;
	}

	port def ReceivePort {
		in item echo : EchoSignal;
	}

	port def MeasurementPort {
		out item measurement : TargetMeasurement;
	}

	port def ControlPort {
		in item mode : OperatingMode;
	}

	part def TransmitterModule {
		attribute peakPower : Power;
		attribute operatingFrequency : Frequency;
		attribute pulseRepetitionRate : Frequency;
		port txOut : TransmitPort;

		action generateWaveform {
			in mode : OperatingMode;
			out waveform : RadarWaveform;
		}
	}

	part def ReceiverModule {
		attribute sensitivity : Power;
		attribute noiseFigure : Real;
		attribute bandwidth : Frequency;
		port rxIn : ReceivePort;

		action amplifyEcho {
			in echo : EchoSignal;
			out amplifiedEcho : EchoSignal;
		}
	}

	part def AntennaAssembly {
		attribute gain : Real;
		attribute beamwidth : Angle;
		attribute efficiency : Real;
		port txPort : TransmitPort;
		port rxPort : ReceivePort;
	}

	part def SignalProcessingUnit {
		attribute processingGain : Real;
		attribute detectionThreshold : Real;

		action calculateRange {
			in timeDelay : Real;
			out range : Distance;
		}

		action calculateVelocity {
			in dopplerShift : Frequency;
			in carrierFrequency : Frequency;
			out velocity : Velocity;
		}

		action determineAngles {
			in phaseShift : Angle;
			out azimuth : Angle;
			out elevation : Angle;
		}

		action processEcho {
			in echo : EchoSignal;
			in referenceWaveform : RadarWaveform;
			out measurement : TargetMeasurement;
		}
	}

	action def TransmitRadarPulse {
		in mode : OperatingMode;
		out waveform : RadarWaveform;
	}

	action def ReceiveEcho {
		in waveform : RadarWaveform;
		out echo : EchoSignal;
	}

	action def ProcessSignal {
		in echo : EchoSignal;
		in reference : RadarWaveform;
		out measurement : TargetMeasurement;
	}

	action def PerformRadarMeasurement {
		in operatingMode : OperatingMode;
		out targetMeasurement : TargetMeasurement;

		bind transmit.mode = operatingMode;

		action transmit : TransmitRadarPulse {
			in mode;
			out waveform;
		}

		flow from transmit.waveform to receive.waveform;

		action receive : ReceiveEcho {
			in waveform;
			out echo;
		}

		flow from receive.echo to process.echo;
		flow from transmit.waveform to process.reference;

		action process : ProcessSignal {
			in echo;
			in reference;
			out measurement;
		}

		bind process.measurement = targetMeasurement;
	}

	state def RadarOperatingStates {
		entry; then idle;

		state idle {
			entry action initializeSystem;
		}

		transition idle_to_active
			first idle
			accept mode : OperatingMode
			if mode == OperatingMode::active
			then active;

		state active {
			entry; then searching;

			state searching {
				entry action startScan;
			}

			state tracking {
				entry action lockTarget;
			}

			state calibrating {
				entry action performCalibration;
			}

			transition search_to_track
				first searching
				accept at when targetDetected
				then tracking;

			transition track_to_search
				first tracking
				accept at when targetLost
				then searching;

			transition to_calibration
				first searching, tracking
				accept mode : OperatingMode
				if mode == OperatingMode::calibration
				then calibrating;

			transition from_calibration
				first calibrating
				accept at when calibrationComplete
				then searching;
		}

		transition active_to_idle
			first active
			accept mode : OperatingMode
			if mode == OperatingMode::standby
			then idle;
	}

	part def RadarSensor {
		attribute operatingFrequency : Frequency;
		attribute maximumRange : Distance;
		attribute rangeResolution : Distance;
		attribute velocityResolution : Velocity;
		attribute angularResolution : Angle;
		attribute updateRate : Frequency;

		part transmitter : TransmitterModule[1];
		part receiver : ReceiverModule[1];
		part antenna : AntennaAssembly[1];
		part processor : SignalProcessingUnit[1];

		port controlInput : ControlPort;
		port measurementOutput : MeasurementPort;

		connection txPath connect transmitter.txOut to antenna.txPort;
		connection rxPath connect antenna.rxPort to receiver.rxIn;

		perform action measurementCycle : PerformRadarMeasurement;

		exhibit state operatingState : RadarOperatingStates;
	}

	part def SensingUnit {
		attribute unitIdentifier : String;
		attribute installationLocation : String;

		part radarSensor : RadarSensor[1];

		port controlInterface : ControlPort;
		port dataInterface : MeasurementPort;

		connection controlLink connect controlInterface to radarSensor.controlInput;
		connection dataLink connect radarSensor.measurementOutput to dataInterface;

		perform action sensingOperation : PerformRadarMeasurement;
	}

	part radarSensingUnit : SensingUnit {
		attribute :>> unitIdentifier = "RSU-001";
		attribute :>> installationLocation = "Front Bumper";

		part :>> radarSensor {
			attribute :>> operatingFrequency = 77.0[GHz];
			attribute :>> maximumRange = 250.0[m];
			attribute :>> rangeResolution = 0.4[m];
			attribute :>> velocityResolution = 0.1[m/s];
			attribute :>> angularResolution = 1.0[deg];
			attribute :>> updateRate = 20.0[Hz];

			part :>> transmitter {
				attribute :>> peakPower = 12.0[W];
				attribute :>> operatingFrequency = 77.0[GHz];
				attribute :>> pulseRepetitionRate = 10000.0[Hz];
			}

			part :>> receiver {
				attribute :>> sensitivity = -95.0[dBm];
				attribute :>> noiseFigure = 2.5;
				attribute :>> bandwidth = 150.0[MHz];
			}

			part :>> antenna {
				attribute :>> gain = 32.0;
				attribute :>> beamwidth = 2.5[deg];
				attribute :>> efficiency = 0.85;
			}

			part :>> processor {
				attribute :>> processingGain = 25.0;
				attribute :>> detectionThreshold = 12.0;
			}
		}
	}

	requirement def RadarSensingCapability {
		doc /* The radar sensing unit shall measure range, velocity, and angular position of targets. */

		require rangeDetection {
			doc /* The system shall detect targets within the specified maximum range. */
		}

		require velocityMeasurement {
			doc /* The system shall measure target radial velocity using Doppler effect. */
		}

		require angularResolution {
			doc /* The system shall determine target angular position within specified resolution. */
		}

		require updateRate {
			doc /* The system shall provide measurements at the specified update rate. */
		}

		require operationalModes {
			doc /* The system shall support standby, active, tracking, and calibration modes. */
		}
	}

	requirement radarSensingRequirement : RadarSensingCapability {
		subject radarSensingUnit;

		assume environmentalConditions {
			doc /* The radar operates in automotive environment with temperature range -40°C to +85°C. */
		}

		require :>> rangeDetection {
			doc /* Detect targets from 1 meter to 250 meters with 0.4 meter resolution. */
		}

		require :>> velocityMeasurement {
			doc /* Measure radial velocities from -150 m/s to +150 m/s with 0.1 m/s resolution. */
		}

		require :>> angularResolution {
			doc /* Determine azimuth and elevation angles within 1 degree resolution. */
		}

		require :>> updateRate {
			doc /* Provide target measurements at minimum 20 Hz update rate. */
		}

		require :>> operationalModes {
			doc /* Support all defined operational modes with transitions as specified. */
		}
	}
}
