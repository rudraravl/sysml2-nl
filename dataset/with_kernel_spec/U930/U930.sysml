package UWB_RTLS {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def StartRanging;
	attribute def StopRanging;
	attribute def PulseReceived;
	attribute def MeasurementSent;
	attribute def MeasurementReceived;
	attribute def PositionUpdate;
	attribute def StartCalibration;
	attribute def CalibrationComplete;
	attribute def StartTracking;
	attribute def StopTracking;

	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	item def UWB_Pulse {
		attribute tagId : String;
		attribute timestamp : TimeValue;
	}

	item def ToF_Measurement {
		attribute tagId : String;
		attribute anchorId : String;
		attribute timeOfFlight : TimeValue;
	}

	item def Distance_Measurement {
		attribute tagId : String;
		attribute anchorId : String;
		attribute distance : LengthValue;
	}

	calc def CalculateDistance {
		in tof : TimeValue;
		return : LengthValue = tof * 299792458 [m/s];
	}

	calc def Trilateration {
		in distances : Distance_Measurement[3..*];
		in anchorPositions : Position3D[3..*];
		return : Position3D;
	}

	action def TransmitPulse {
		out pulse : UWB_Pulse;
	}

	action def ReceiveAndMeasure {
		in pulse : UWB_Pulse;
		in anchorId : String;
		out tof : ToF_Measurement;
		out distance : Distance_Measurement;
	}

	action def ProcessDistances {
		in distances : Distance_Measurement[3..*];
		in anchorPositions : Position3D[3..*];
		out position : Position3D = Trilateration(distances, anchorPositions);
	}

	port def UWB_Port {
		out pulse : UWB_Pulse;
		in tof : ToF_Measurement;
	}

	port def Data_Port {
		in distance : Distance_Measurement;
		out position : Position3D;
	}

	state def TagStates {
		entry; then idle;
		state idle;
		state ranging {
			do action transmitPulse : TransmitPulse;
		}
		transition first idle accept StartRanging then ranging;
		transition first ranging accept StopRanging then idle;
	}

	state def AnchorStates {
		entry; then idle;
		state idle;
		state receiving {
			do action receiveAndMeasure : ReceiveAndMeasure;
		}
		transition first idle accept PulseReceived then receiving;
		transition first receiving accept MeasurementSent then idle;
	}

	state def EngineStates {
		entry; then idle;
		state idle;
		state calculating {
			do action processDistances : ProcessDistances;
		}
		transition first idle accept MeasurementReceived then calculating;
		transition first calculating accept PositionUpdate then idle;
	}

	state def SystemStates {
		entry; then Idle;
		state Idle;
		state Calibration;
		state Tracking;
		transition first Idle accept StartCalibration then Calibration;
		transition first Calibration accept CalibrationComplete then Idle;
		transition first Idle accept StartTracking then Tracking;
		transition first Tracking accept StopTracking then Idle;
	}

	part def MobileTag {
		attribute tagId : String;
		port uwbPort : UWB_Port;
		state tagStates : TagStates;
	}

	part def FixedAnchor {
		attribute anchorId : String;
		attribute knownPosition : Position3D;
		port uwbPort : ~UWB_Port;
		port dataPort : ~Data_Port;
		state anchorStates : AnchorStates;
	}

	part def PositioningEngine {
		port dataPort : Data_Port;
		state engineStates : EngineStates;
	}

	part def UWB_System {
		part tags : MobileTag[*];
		part anchors : FixedAnchor[4..*];
		part engine : PositioningEngine[1];

		connection tagToAnchor connect tags.uwbPort to anchors.uwbPort;
		connection anchorToEngine connect anchors.dataPort to engine.dataPort;

		state systemStates : SystemStates;
	}

	requirement def HighPrecisionTracking {
		doc /* The system shall provide centimeter-level 3D tracking. */
		subject system : UWB_System;
		attribute maxError : LengthValue = 0.1 [m];
	}

	requirement def RealTimeUpdates {
		doc /* The system shall provide position updates at a rate of at least 10 Hz. */
		attribute minUpdateRate : FrequencyValue = 10 [Hz];
	}

	requirement def MinimumAnchors {
		doc /* The system shall include at least four fixed anchors for robust 3D positioning. */
		attribute minAnchors : Natural = 4;
	}
}
