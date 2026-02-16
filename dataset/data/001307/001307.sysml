package 'Vibrating Structure Gyroscope System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def AngularRateValue :> ISQ::AngularVelocityValue;
	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def CurrentValue :> ISQ::ElectricCurrentValue;
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def DisplacementValue :> ISQ::LengthValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def CapacitanceValue :> ISQ::CapacitanceValue;

	attribute def DriveSignal {
		attribute voltage : VoltageValue;
		attribute frequency : FrequencyValue;
		attribute phase : Real;
	}

	attribute def SenseSignal {
		attribute voltage : VoltageValue;
		attribute amplitude : Real;
	}

	port def DrivePort {
		out signal : DriveSignal;
	}

	port def SensePort {
		in signal : SenseSignal;
	}

	port def AngularRateOutputPort {
		out rate : AngularRateValue;
		out temperature : TemperatureValue;
	}

	port def PowerPort {
		in voltage : VoltageValue;
		in current : CurrentValue;
	}

	part def ResonantMass {
		attribute mass : ISQ::MassValue;
		attribute resonantFrequency : FrequencyValue;
		attribute qualityFactor : Real;
		attribute driveAmplitude : DisplacementValue;
		attribute senseAmplitude : DisplacementValue;
		attribute stiffness : Real;
		attribute damping : Real;
	}

	part def DriveElectrode {
		port drivePort : DrivePort;
		attribute capacitance : CapacitanceValue;
		attribute area : ISQ::AreaValue;

		action applyElectrostaticForce {
			in driveVoltage : VoltageValue;
			in driveFrequency : FrequencyValue;
			out force : ForceValue;
		}
	}

	part def SenseElectrode {
		port sensePort : SensePort;
		attribute capacitance : CapacitanceValue;
		attribute area : ISQ::AreaValue;

		action detectDisplacement {
			in displacement : DisplacementValue;
			out signal : SenseSignal;
		}
	}

	part def DriveLoopElectronics {
		port driveOutput : DrivePort;
		port feedbackInput : SensePort;
		port power : PowerPort;

		attribute targetAmplitude : DisplacementValue;
		attribute lockFrequency : FrequencyValue;
		attribute loopGain : Real;

		action maintainResonance {
			in feedbackSignal : SenseSignal;
			in targetAmp : DisplacementValue;
			out driveSignal : DriveSignal;
		}

		action phaseLockedLoop {
			in feedbackPhase : Real;
			out lockedFrequency : FrequencyValue;
		}
	}

	part def SenseElectronics {
		port senseInput : SensePort;
		port power : PowerPort;

		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
		attribute noiseFloor : VoltageValue;

		action amplifySignal {
			in inputSignal : SenseSignal;
			out amplifiedVoltage : VoltageValue;
		}

		action demodulate {
			in amplifiedSignal : VoltageValue;
			in referencePhase : Real;
			out demodulatedVoltage : VoltageValue;
		}

		action filterSignal {
			in rawSignal : VoltageValue;
			out filteredSignal : VoltageValue;
		}
	}

	part def DigitalSignalProcessor {
		port analogInput : ~SensePort;
		port rateOutput : AngularRateOutputPort;
		port power : PowerPort;

		attribute scaleFactor : Real;
		attribute biasOffset : AngularRateValue;
		attribute temperatureCoefficient : Real;
		attribute nonlinearity : Real;

		action convertToRate {
			in senseVoltage : VoltageValue;
			in temperature : TemperatureValue;
			out angularRate : AngularRateValue;
		}

		action compensateTemperature {
			in rawRate : AngularRateValue;
			in temperature : TemperatureValue;
			out compensatedRate : AngularRateValue;
		}

		action applyCalibration {
			in measuredRate : AngularRateValue;
			in calibrationData : Real;
			out calibratedRate : AngularRateValue;
		}
	}

	part def TemperatureSensor {
		attribute currentTemperature : TemperatureValue;
		attribute accuracy : TemperatureValue;

		action measureTemperature {
			out temperature : TemperatureValue;
		}
	}

	part def VacuumPackage {
		attribute pressure : ISQ::PressureValue;
		attribute sealIntegrity : Real;
	}

	action def GenerateCoriolisForce {
		in driveVelocity : ISQ::SpeedValue;
		in angularRate : AngularRateValue;
		in mass : ISQ::MassValue;
		out coriolisForce : ForceValue;
	}

	action def InitializeSensors;
	action def SelfTest;
	action def StartDriveLoop;
	action def StabilizeTemperature;
	action def ContinuousMeasurement;
	action def EnterCalMode;
	action def CollectCalibrationData;
	action def ApplyCalibrationCoefficients;
	action def LogFault;
	action def AttemptRecovery;

	state def GyroscopeOperationalStates {
		entry; then PowerOff;
		
		state PowerOff;
		
		state Initialization {
			entry action initSensors : InitializeSensors;
			do action selfTest : SelfTest;
		}
		
		state WarmUp {
			entry action startLoop : StartDriveLoop;
			do action stabilize : StabilizeTemperature;
		}
		
		state NormalOperation {
			do action measure : ContinuousMeasurement;
		}
		
		state Calibration {
			entry action enterCal : EnterCalMode;
			do action collectCal : CollectCalibrationData;
			exit action applyCal : ApplyCalibrationCoefficients;
		}
		
		state Fault {
			entry action logError : LogFault;
			do action recover : AttemptRecovery;
		}

		transition powerOn first PowerOff then Initialization;
		transition initComplete first Initialization then WarmUp;
		transition warmUpComplete first WarmUp then NormalOperation;
		transition calibrationRequest first NormalOperation then Calibration;
		transition calibrationComplete first Calibration then NormalOperation;
		transition faultDetected first NormalOperation then Fault;
		transition faultDetected2 first WarmUp then Fault;
		transition recoverySuccess first Fault then Initialization;
		transition powerDown first NormalOperation then PowerOff;
		transition emergencyShutdown first Fault then PowerOff;
	}

	part def VibratingStructureGyroscope {
		doc /*
		A vibrating structure gyroscope measures angular rotation rate by exploiting 
		the Coriolis effect. A resonant mass is driven into continuous oscillation 
		along a primary axis. When the gyroscope rotates about a sensitive axis 
		perpendicular to the drive motion, Coriolis forces induce a secondary 
		oscillation proportional to the angular rate. This secondary motion is 
		detected capacitively, demodulated, and converted into a calibrated 
		angular rate output.
		*/

		part resonantMass : ResonantMass {
			attribute mass = 5.0e-6 [kg];
			attribute resonantFrequency = 15000.0 [Hz];
			attribute qualityFactor = 50000.0;
			attribute stiffness = 4500.0;
			attribute damping = 0.02;
		}

		part driveElectrodes : DriveElectrode[4] {
			attribute capacitance = 2.0e-12 [F];
			attribute area = 1.0e-6 [m^2];
		}

		part senseElectrodes : SenseElectrode[4] {
			attribute capacitance = 2.0e-12 [F];
			attribute area = 1.0e-6 [m^2];
		}

		part driveLoop : DriveLoopElectronics {
			attribute targetAmplitude = 5.0e-6 [m];
			attribute lockFrequency = resonantMass.resonantFrequency;
			attribute loopGain = 100.0;
		}

		part senseChain : SenseElectronics {
			attribute gain = 10000.0;
			attribute bandwidth = 200.0 [Hz];
			attribute noiseFloor = 1.0e-9 [V];
		}

		part processor : DigitalSignalProcessor {
			attribute scaleFactor = 0.0015;
			attribute biasOffset = 0.001 [rad/s];
			attribute temperatureCoefficient = 0.0002;
			attribute nonlinearity = 0.001;
		}

		part tempSensor : TemperatureSensor {
			attribute currentTemperature = 298.15 [K];
			attribute accuracy = 0.1 [K];
		}

		part vacuumPackage : VacuumPackage {
			attribute pressure = 0.001 [Pa];
			attribute sealIntegrity = 0.999;
		}

		port powerSupply : PowerPort;
		port gyroOutput : AngularRateOutputPort;

		connection driveFeedback connect driveElectrodes[1].drivePort to driveLoop.driveOutput;
		connection driveMonitor connect senseElectrodes[1].sensePort to driveLoop.feedbackInput;
		connection senseInput connect senseElectrodes[2].sensePort to senseChain.senseInput;
		connection processorInput connect senseChain.senseInput to processor.analogInput;
		connection rateOutput connect processor.rateOutput to gyroOutput;

		action measureAngularRate {
			doc /*
			Primary operational function: Continuously measure angular rotation rate 
			by maintaining resonant drive oscillation, detecting Coriolis-induced 
			sense motion, and processing the resulting signals into calibrated 
			angular rate data.
			*/

			first start;

			then action initializeDrive {
				action generateInitialDrive : driveLoop.maintainResonance {
					in feedbackSignal;
					in targetAmp = driveLoop.targetAmplitude;
					out driveSignal;
				}
				then action lockPhase : driveLoop.phaseLockedLoop {
					in feedbackPhase = 0.0;
					out lockedFrequency;
				}
			}

			then merge continuousOperation;

			then action exciteResonantMass {
				action applyDriveForce : driveElectrodes[1].applyElectrostaticForce {
					in driveVoltage = 10.0 [V];
					in driveFrequency = resonantMass.resonantFrequency;
					out force;
				}
				then assign resonantMass.driveAmplitude := 5.0e-6 [m];
			}

			then action detectRotation {
				action generateCoriolis : GenerateCoriolisForce {
					in driveVelocity = 0.047 [m/s];
					in angularRate;
					in mass = resonantMass.mass;
					out coriolisForce;
				}
				then assign resonantMass.senseAmplitude := 5.0e-10 [m];
			}

			then action captureSenseMotion {
				action detectSense : senseElectrodes[2].detectDisplacement {
					in displacement = resonantMass.senseAmplitude;
					out signal;
				}
			}

			then action processSignal {
				action amplify : senseChain.amplifySignal {
					in inputSignal;
					out amplifiedVoltage;
				}
				then action demod : senseChain.demodulate {
					in amplifiedSignal = amplify.amplifiedVoltage;
					in referencePhase = 0.0;
					out demodulatedVoltage;
				}
				then action filter : senseChain.filterSignal {
					in rawSignal = demod.demodulatedVoltage;
					out filteredSignal;
				}
			}

			then action computeAngularRate {
				action measureTemp : tempSensor.measureTemperature {
					out temperature;
				}
				then action convert : processor.convertToRate {
					in senseVoltage = processSignal.filter.filteredSignal;
					in temperature = measureTemp.temperature;
					out angularRate;
				}
				then action compensate : processor.compensateTemperature {
					in rawRate = convert.angularRate;
					in temperature = measureTemp.temperature;
					out compensatedRate;
				}
				then action calibrate : processor.applyCalibration {
					in measuredRate = compensate.compensatedRate;
					in calibrationData = 1.0;
					out calibratedRate;
				}
			}

			then continuousOperation;
		}

		exhibit state lifecycle : GyroscopeOperationalStates;
	}

	requirement def PerformanceRequirement {
		doc /* Performance specifications for the vibrating structure gyroscope. */

		subject gyro : VibratingStructureGyroscope;

		require constraint measurementRange {
			doc /* The gyroscope shall measure angular rates from -1000 to +1000 deg/s. */
		}

		require constraint biasStability {
			doc /* The gyroscope bias stability shall be less than 0.5 deg/hr over 100 seconds. */
		}

		require constraint angularRandomWalk {
			doc /* The angular random walk shall be less than 0.05 deg/sqrt(hr). */
		}

		require constraint bandwidth {
			doc /* The measurement bandwidth shall be at least 100 Hz. */
		}

		require constraint sensitivity {
			doc /* The minimum detectable rate shall be less than 0.01 deg/s. */
		}

		require constraint temperatureRange {
			doc /* The gyroscope shall operate over -40 to +85 degrees Celsius. */
		}
	}

	requirement def SystemRequirement {
		doc /* Top-level functional requirement for the vibrating structure gyroscope system. */

		subject system : VibratingStructureGyroscope;

		requirement <'VSG-SYS-001'> primaryFunction {
			doc /*
			The vibrating structure gyroscope shall measure angular rotation rate 
			by maintaining a resonant mass in continuous oscillation along a drive 
			axis and detecting Coriolis-induced motion along an orthogonal sense 
			axis when the system rotates. The detected motion shall be converted 
			into a calibrated, temperature-compensated angular rate output with 
			specified accuracy and stability.
			*/

			assume constraint resonantDriveOperation {
				doc /* The resonant mass operates at its natural frequency with stable amplitude. */
			}

			assume constraint vacuumEnvironment {
				doc /* The resonant structure is maintained in a vacuum to achieve high quality factor. */
			}

			require constraint coriolisDetection {
				doc /* Coriolis forces are detected through capacitive sensing with sufficient sensitivity. */
			}

			require performanceReq : PerformanceRequirement {
				subject gyro = system;
			}
		}
	}

	part gyroscopeSystem : VibratingStructureGyroscope {
		satisfy primaryFunction by measureAngularRate;
	}
}
