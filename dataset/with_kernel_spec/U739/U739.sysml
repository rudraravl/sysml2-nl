package LIDARPerceptionSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import Time::TimeInstantValue;

	item def LaserPulse {
		attribute timestamp : TimeInstantValue;
		attribute horizontalAngleDeg : Real;
		attribute verticalAngleDeg : Real;
		attribute wavelengthNm : Real;
	}

	item def ReflectedPulse {
		attribute sendTime : TimeInstantValue;
		attribute returnTime : TimeInstantValue;
		attribute intensity : Real;
		attribute horizontalAngleDeg : Real;
		attribute verticalAngleDeg : Real;
	}

	item def Point3D {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
		attribute reflectivity : Real;
	}

	item def PointCloud {
		item points : Point3D [0..*];
		attribute timestamp : TimeInstantValue;
		attribute frameNumber : Integer;
	}

	attribute def PowerOn;
	attribute def StartScan;
	attribute def StopScan;
	attribute def SingleFrameScan;
	attribute def Reset;
	attribute def FaultDetected;
	attribute def CalibrationComplete;

	port def LaserEmissionPort {
		out laserPulse : LaserPulse;
	}

	port def LaserInputPort {
		in laserPulse : LaserPulse;
	}

	port def ReflectedLightPort {
		in reflectedPulse : ReflectedPulse;
	}

	port def ReflectedDataPort {
		out reflectedPulse : ReflectedPulse;
	}

	port def MotorDrivePort {
		in speed : Real;
		in direction : Real;
	}

	port def PointCloudOutputPort {
		out pointCloud : PointCloud;
	}

	action def EmitLaserPulse {
		out pulse : LaserPulse;
	}

	action def DirectPulse {
		in pulse : LaserPulse;
		in horizontalAngleDeg : Real;
		in verticalAngleDeg : Real;
		out directedPulse : LaserPulse;
	}

	action def DriveMotor {
		in speed : Real;
		in direction : Real;
	}

	action def CaptureReflection {
		in reflected : ReflectedPulse;
		out captured : ReflectedPulse;
	}

	action def CalculateTimeOfFlight {
		in sendTime : TimeInstantValue;
		in returnTime : TimeInstantValue;
		out timeOfFlightUs : Real;
	}

	action def CalculateDistance {
		in timeOfFlightUs : Real;
		out distanceM : Real;
	}

	action def Calculate3DPosition {
		in distanceM : Real;
		in horizontalAngleDeg : Real;
		in verticalAngleDeg : Real;
		out point : Point3D;
	}

	action def AssemblePointCloud {
		in points : Point3D [0..*];
		out cloud : PointCloud;
	}

	action def ProcessScan {
		in reflectedPulses : ReflectedPulse [0..*];
		out pointCloud : PointCloud;
	}

	action def SelfCalibration {
		out success : Boolean;
	}

	action def EnvironmentalScan {
		out pointCloud : PointCloud;
	}

	state def LIDARStates {
		entry; then standby;

		state standby;
		accept PowerOn
			then initializing;

		state initializing {
			do action selfCalibration : SelfCalibration;
		}
		accept CalibrationComplete
			then ready;
		accept FaultDetected
			then fault;

		state ready;
		accept StartScan
			then activeScanning;
		accept SingleFrameScan
			then activeScanning;
		accept FaultDetected
			then fault;

		state activeScanning {
			do action environmentalScan : EnvironmentalScan;
		}
		accept StopScan
			then ready;
		accept FaultDetected
			then fault;

		state fault;
		accept Reset
			then standby;
	}

	part def LaserEmitter {
		attribute wavelengthNm : Real = 905;
		attribute pulseRateHz : Integer = 200000;
		port emissionPort : LaserEmissionPort;
		perform action emitPulse : EmitLaserPulse;
	}

	part def ScanningMirror {
		attribute horizontalFOVDeg : Real = 360;
		attribute verticalFOVDeg : Real = 40;
		attribute currentHorizontalAngleDeg : Real;
		attribute currentVerticalAngleDeg : Real;
		port inputPort : LaserInputPort;
		port motorPort : MotorDrivePort;
		perform action directPulse : DirectPulse;
	}

	part def MirrorMotor {
		attribute rotationSpeedRpm : Real;
		attribute torqueRating : Real;
		port drivePort : MotorDrivePort;
		perform action driveMotor : DriveMotor;
	}

	part def OpticalReceiver {
		attribute sensitivity : Real;
		attribute fieldOfViewDeg : Real;
		port receiverPort : ReflectedLightPort;
		port outputPort : ReflectedDataPort;
		perform action captureReflection : CaptureReflection;
	}

	part def SignalProcessingUnit {
		attribute maxRangeM : Real = 150;
		attribute scanRateHz : Real = 20;
		ref item currentPointCloud : PointCloud;
		attribute frameCount : Integer = 0;
		port inputPort : ReflectedDataPort;
		port pointCloudPort : PointCloudOutputPort;
		perform action calculateTimeOfFlight : CalculateTimeOfFlight;
		perform action calculateDistance : CalculateDistance;
		perform action calculate3DPosition : Calculate3DPosition;
		perform action assemblePointCloud : AssemblePointCloud;
		perform action processScan : ProcessScan;
	}

	part def LIDAR {
		attribute maxRangeM : Real = 150;
		attribute scanRateHz : Real = 20;
		attribute horizontalFOVDeg : Real = 360;
		attribute verticalFOVDeg : Real = 40;
		attribute pulseRateHz : Integer = 200000;

		part laserEmitter : LaserEmitter;
		part scanningMirror : ScanningMirror;
		part mirrorMotor : MirrorMotor;
		part opticalReceiver : OpticalReceiver;
		part signalProcessingUnit : SignalProcessingUnit;

		port outputPort : PointCloudOutputPort;

		perform action environmentalScan : EnvironmentalScan;
		perform action selfCalibration : SelfCalibration;
		exhibit state lidarStates : LIDARStates;

		connection laserToMirror connect laserEmitter.emissionPort to scanningMirror.inputPort;
		connection motorToMirror connect mirrorMotor.drivePort to scanningMirror.motorPort;
		connection receiverToProcessor connect opticalReceiver.outputPort to signalProcessingUnit.inputPort;
		connection processorToOutput connect signalProcessingUnit.pointCloudPort to outputPort;
	}

	requirement def MaxRangeRequirement {
		doc /* The LIDAR shall have a maximum effective range of at least 150 meters. */
		subject lidar : LIDAR;
		assert constraint { lidar.maxRangeM >= 150 }
	}

	requirement def ScanRateRequirement {
		doc /* The LIDAR shall support a scan rate of at least 20 frames per second. */
		subject lidar : LIDAR;
		assert constraint { lidar.scanRateHz >= 20 }
	}

	requirement def FieldOfViewRequirement {
		doc /* The LIDAR shall provide a 360-degree horizontal and 40-degree vertical field of view. */
		subject lidar : LIDAR;
		assert constraint { lidar.horizontalFOVDeg == 360 and lidar.verticalFOVDeg == 40 }
	}

	requirement def PulseRateRequirement {
		doc /* The LIDAR laser emitter shall generate at least 200000 pulses per second. */
		subject lidar : LIDAR;
		assert constraint { lidar.pulseRateHz >= 200000 }
	}

	part lidarInstance : LIDAR {
		satisfy MaxRangeRequirement;
		satisfy ScanRateRequirement;
		satisfy FieldOfViewRequirement;
		satisfy PulseRateRequirement;
	}
}
