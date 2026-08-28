package 'Sensor Fusion Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;

	value type AccelValue :> Real;
	value type GyroValue :> Real;
	value type MagValue :> Real;
	value type LengthValue :> Real;
	value type VelocityValue :> Real;
	value type AngleValue :> Real;
	value type ConfidenceValue :> Real;
	value type FrequencyValue :> Real;

	attribute def PowerOn;
	attribute def PowerOff;
	attribute def CalibrationComplete;
	attribute def SensorFailure;
	attribute def RecoverySuccess;
	attribute def RecoveryFailed;

	attribute def AccelData {
		attribute x : AccelValue;
		attribute y : AccelValue;
		attribute z : AccelValue;
		attribute gravity : AccelValue;
		attribute timestamp : Real;
		attribute valid : Boolean;
	}
	attribute def GyroData {
		attribute x : GyroValue;
		attribute y : GyroValue;
		attribute z : GyroValue;
		attribute timestamp : Real;
		attribute valid : Boolean;
	}
	attribute def MagData {
		attribute x : MagValue;
		attribute y : MagValue;
		attribute z : MagValue;
		attribute timestamp : Real;
		attribute valid : Boolean;
	}
	attribute def SyncData {
		attribute accel : AccelData;
		attribute gyro : GyroData;
		attribute mag : MagData;
		attribute syncTimestamp : Real;
	}
	attribute def FusionOutput {
		attribute posX : LengthValue;
		attribute posY : LengthValue;
		attribute posZ : LengthValue;
		attribute velX : VelocityValue;
		attribute velY : VelocityValue;
		attribute velZ : VelocityValue;
		attribute roll : AngleValue;
		attribute pitch : AngleValue;
		attribute yaw : AngleValue;
		attribute confidence : ConfidenceValue;
		attribute timestamp : Real;
		attribute isDegraded : Boolean;
	}

	port def AccelOutPort {
		out data : AccelData;
	}
	port def GyroOutPort {
		out data : GyroData;
	}
	port def MagOutPort {
		out data : MagData;
	}
	port def AccelInPort {
		in data : AccelData;
	}
	port def GyroInPort {
		in data : GyroData;
	}
	port def MagInPort {
		in data : MagData;
	}
	port def OutputPort {
		out output : FusionOutput;
	}

	action def ReadAccel {
		out data : AccelData;
	}
	action def ReadGyro {
		out data : GyroData;
	}
	action def ReadMag {
		out data : MagData;
	}
	action def AcquireSensorData {
		action readAccel : ReadAccel;
		action readGyro : ReadGyro;
		action readMag : ReadMag;
	}
	action def ValidateIntegrity {
		in accelData : AccelData;
		in gyroData : GyroData;
		in magData : MagData;
		out allValid : Boolean;
	}
	action def TimeSynchronize {
		in accelData : AccelData;
		in gyroData : GyroData;
		in magData : MagData;
		out syncData : SyncData;
	}
	action def RunExtendedKalmanFilter {
		in syncData : SyncData;
		out estimate : FusionOutput;
	}
	action def RunComplementaryFilter {
		in syncData : SyncData;
		out orientation : FusionOutput;
	}
	action def MergeResults {
		in ekfResult : FusionOutput;
		in compResult : FusionOutput;
		out merged : FusionOutput;
	}
	action def CalibrateSensors;
	action def AttemptRecovery;
	action def ComputeDegradedEstimate {
		in syncData : SyncData;
		out estimate : FusionOutput;
	}

	part def Accelerometer {
		port outPort : AccelOutPort;
		perform action read : ReadAccel;
		attribute biasX : AccelValue;
		attribute biasY : AccelValue;
		attribute biasZ : AccelValue;
		attribute operational : Boolean;
	}
	part def Gyroscope {
		port outPort : GyroOutPort;
		perform action read : ReadGyro;
		attribute biasX : GyroValue;
		attribute biasY : GyroValue;
		attribute biasZ : GyroValue;
		attribute operational : Boolean;
	}
	part def Magnetometer {
		port outPort : MagOutPort;
		perform action read : ReadMag;
		attribute biasX : MagValue;
		attribute biasY : MagValue;
		attribute biasZ : MagValue;
		attribute operational : Boolean;
	}
	part def FusionProcessor {
		port accelIn : AccelInPort;
		port gyroIn : GyroInPort;
		port magIn : MagInPort;
		port output : OutputPort;
		perform action validate : ValidateIntegrity;
		perform action sync : TimeSynchronize;
		perform action runEKF : RunExtendedKalmanFilter;
		perform action runComp : RunComplementaryFilter;
		perform action mergeEstimates : MergeResults;
		perform action recover : AttemptRecovery;
		perform action degraded : ComputeDegradedEstimate;
	}

	state def OperationalStates;

	part def SensorFusionUnit {
		part accelerometer : Accelerometer;
		part gyroscope : Gyroscope;
		part magnetometer : Magnetometer;
		part processor : FusionProcessor;
		port systemOutput : OutputPort;
		exhibit state operatingStates : OperationalStates;
	}

	part fusionUnit : SensorFusionUnit {
		connect accelerometer.outPort to processor.accelIn;
		connect gyroscope.outPort to processor.gyroIn;
		connect magnetometer.outPort to processor.magIn;
		connect processor.output to systemOutput;

		action acquireSensorData : AcquireSensorData;
		action validateData : ValidateIntegrity;
		action syncData : TimeSynchronize;
		action runKalman : RunExtendedKalmanFilter;
		action runCompFilter : RunComplementaryFilter;
		action mergeResults : MergeResults;
		action calibrate : CalibrateSensors;
		action attemptRecovery : AttemptRecovery;
		action degradedEst : ComputeDegradedEstimate;

		state operatingStates : OperationalStates {
			entry; then off;

			state off;
			accept PowerOn then initializing;

			state initializing;
			transition first initializing then calibrating;

			state calibrating {
				do calibrate;
			}
			accept CalibrationComplete then operational;

			state operational {
				entry; then acquiring;
				state acquiring {
					do acquireSensorData;
				}
				transition first acquiring then validating;
				state validating {
					do validateData;
				}
				transition first validating then synchronizing;
				state synchronizing {
					do syncData;
				}
				transition first synchronizing then fusing;
				state fusing {
					entry; then dualFilter;
					state dualFilter parallel {
						state ekf {
							do runKalman;
						}
						state comp {
							do runCompFilter;
						}
					}
				}
				transition first fusing then merging;
				state merging {
					do mergeResults;
				}
				transition first merging then acquiring;
			}

			transition
				first operational
				accept SensorFailure
				then errorHandling;

			transition
				first operational
				accept PowerOff
				then off;

			state errorHandling {
				entry; then recovering;
				state recovering {
					do attemptRecovery;
				}
			}
			transition
				first errorHandling.recovering
				accept RecoverySuccess
				then operational;
			transition
				first errorHandling.recovering
				accept RecoveryFailed
				then degraded;

			state degraded {
				do degradedEst;
			}
			transition
				first degraded
				accept RecoverySuccess
				then operational;
			transition
				first degraded
				accept PowerOff
				then off;
		}
	}

	requirement def AccuracyRequirement {
		doc
		/* The sensor fusion unit shall provide position estimates
		   accurate to within 0.1 m and orientation estimates
		   accurate to within 0.0175 rad (1 degree). */
		attribute maxPositionError : LengthValue = 0.1;
		attribute maxOrientationError : AngleValue = 0.0175;
	}

	requirement def FrequencyRequirement {
		doc
		/* The sensor fusion unit shall execute the complete
		   sense-process-fuse cycle at a minimum frequency of 100 Hz. */
		attribute minCycleFrequency : FrequencyValue = 100.0;
	}

	requirement def DualAlgorithmRequirement {
		doc
		/* The sensor fusion unit shall simultaneously process
		   synchronized sensor data through both an Extended Kalman
		   Filter and a Complementary Filter, then merge the results
		   to produce a single refined output. */
	}

	requirement def RobustnessRequirement {
		doc
		/* The sensor fusion unit shall detect sensor failures,
		   attempt recovery, and provide a degraded estimate using
		   remaining operational sensors when recovery fails. */
	}

	requirement def CalibrationRequirement {
		doc
		/* The sensor fusion unit shall enter a mandatory calibration
		   phase on power-up to tune each sensor and correct for
		   biases and drift before entering operational mode. */
	}

	requirement accuracyReq : AccuracyRequirement;
	requirement frequencyReq : FrequencyRequirement;
	requirement dualAlgorithmReq : DualAlgorithmRequirement;
	requirement robustnessReq : RobustnessRequirement;
	requirement calibrationReq : CalibrationRequirement;
}
