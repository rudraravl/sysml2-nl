package 'Wired Glove System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def SensorID;
	attribute def GestureType;
	attribute def CalibrationData;
	attribute def PowerOn;
	attribute def PowerOff;
	attribute def CalibrationComplete;

	value def FlexAngle :> ISQ::planeAngle {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::PlaneAngleUnit;
	}

	value def ForceLevel :> ISQ::force {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::ForceUnit;
	}

	value def Position3D {
		attribute x : ISQ::LengthValue;
		attribute y : ISQ::LengthValue;
		attribute z : ISQ::LengthValue;
	}

	value def Orientation3D {
		attribute roll : ISQ::PlaneAngleValue;
		attribute pitch : ISQ::PlaneAngleValue;
		attribute yaw : ISQ::PlaneAngleValue;
	}

	item def RawSensorData {
		attribute sensorID : SensorID;
		attribute timestamp : ISQ::TimeValue;
		attribute value : Real;
	}

	item def ProcessedGestureData {
		attribute gestureType : GestureType;
		attribute confidence : Real;
		attribute timestamp : ISQ::TimeValue;
		attribute handPosition : Position3D;
		attribute handOrientation : Orientation3D;
	}

	port def SensorDataPort {
		out item sensorData : RawSensorData[*];
	}

	port def GestureOutputPort {
		out item gestureData : ProcessedGestureData[*];
	}

	port def PowerPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}

	port def CommunicationPort {
		out item dataStream : ProcessedGestureData[*];
		in item commands : CalibrationData[*];
	}

	part def FlexSensor {
		attribute sensorID : SensorID;
		attribute minAngle : FlexAngle;
		attribute maxAngle : FlexAngle;
		attribute currentAngle : FlexAngle;

		port sensorOutput : SensorDataPort;

		action measureFlexure {
			out flexAngle : FlexAngle;
			out rawData : RawSensorData;
		}
	}

	part def ForceSensor {
		attribute sensorID : SensorID;
		attribute maxForce : ForceLevel;
		attribute currentForce : ForceLevel;

		port sensorOutput : SensorDataPort;

		action measureForce {
			out force : ForceLevel;
			out rawData : RawSensorData;
		}
	}

	part def InertialMeasurementUnit {
		attribute position : Position3D;
		attribute orientation : Orientation3D;
		attribute acceleration : ISQ::AccelerationValue;

		port sensorOutput : SensorDataPort;

		action trackMotion {
			out positionData : Position3D;
			out orientationData : Orientation3D;
			out rawData : RawSensorData[*];
		}
	}

	part def DataProcessor {
		attribute calibrationData : CalibrationData;

		port dataInput : SensorDataPort;
		port gestureOutput : GestureOutputPort;

		action def FilterData {
			in rawData : RawSensorData[*];
			out filteredData : RawSensorData[*];
		}

		action def RecognizeGesture {
			in filteredData : RawSensorData[*];
			in calibration : CalibrationData;
			out gesture : ProcessedGestureData;
		}

		action processData {
			in sensorInputs : RawSensorData[*];
			out gestureResult : ProcessedGestureData;

			first start;
			then action filter : FilterData {
				in rawData = sensorInputs;
				out filteredData;
			}
			then action recognize : RecognizeGesture {
				in filteredData = filter.filteredData;
				in calibration = calibrationData;
				out gesture;
			}
			then assign gestureResult := recognize.gesture;
			then done;
		}
	}

	part def WirelessTransmitter {
		attribute transmissionPower : ISQ::PowerValue;
		attribute frequency : ISQ::FrequencyValue;

		port dataInput : GestureOutputPort;
		port commOutput : CommunicationPort;

		action transmitData {
			in gestureData : ProcessedGestureData;
			out transmittedData : ProcessedGestureData;
		}
	}

	part def PowerSupply {
		attribute batteryCapacity : ISQ::EnergyValue;
		attribute currentCharge : ISQ::EnergyValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;

		port powerOutput : PowerPort;

		action supplyPower {
			out voltage : ISQ::ElectricPotentialValue;
			out current : ISQ::ElectricCurrentValue;
		}
	}

	part def GloveFabric {
		attribute material : String;
		attribute size : String;

		part fingerCompartments[5] {
			attribute fingerName : String;
		}
	}

	part def WiredGlove {
		attribute gloveSize : String;
		attribute handedness : String;

		part fabric : GloveFabric {
			attribute material = "conductive textile";
			attribute size = gloveSize;
		}

		part thumbFlexSensor : FlexSensor {
			attribute sensorID = "THUMB_FLEX";
		}

		part indexFlexSensor : FlexSensor {
			attribute sensorID = "INDEX_FLEX";
		}

		part middleFlexSensor : FlexSensor {
			attribute sensorID = "MIDDLE_FLEX";
		}

		part ringFlexSensor : FlexSensor {
			attribute sensorID = "RING_FLEX";
		}

		part pinkyFlexSensor : FlexSensor {
			attribute sensorID = "PINKY_FLEX";
		}

		part thumbForceSensor : ForceSensor {
			attribute sensorID = "THUMB_FORCE";
		}

		part indexForceSensor : ForceSensor {
			attribute sensorID = "INDEX_FORCE";
		}

		part imu : InertialMeasurementUnit;

		part processor : DataProcessor;

		part transmitter : WirelessTransmitter;

		part battery : PowerSupply {
			attribute batteryCapacity = 3600.0 [SI::J];
			attribute outputVoltage = 3.7 [SI::V];
		}

		connection thumbFlexConnection connect thumbFlexSensor.sensorOutput to processor.dataInput;
		connection indexFlexConnection connect indexFlexSensor.sensorOutput to processor.dataInput;
		connection middleFlexConnection connect middleFlexSensor.sensorOutput to processor.dataInput;
		connection ringFlexConnection connect ringFlexSensor.sensorOutput to processor.dataInput;
		connection pinkyFlexConnection connect pinkyFlexSensor.sensorOutput to processor.dataInput;
		connection thumbForceConnection connect thumbForceSensor.sensorOutput to processor.dataInput;
		connection indexForceConnection connect indexForceSensor.sensorOutput to processor.dataInput;
		connection imuConnection connect imu.sensorOutput to processor.dataInput;
		connection processorToTransmitter connect processor.gestureOutput to transmitter.dataInput;

		perform action captureHandGesture;
	}

	action def CaptureHandGesture {
		in handPosition : Position3D;
		in fingerFlexAngles : FlexAngle[5];
		in fingerForces : ForceLevel[2];
		out recognizedGesture : ProcessedGestureData;
	}

	action captureHandGesture : CaptureHandGesture {
		doc /* 
			The wired glove system continuously captures hand and finger movements
			by sensing flex angles, contact forces, and spatial orientation,
			then processes this data to recognize gestures for human-computer interaction.
		*/

		first start;
		then merge continuousCapture;

		then action collectSensorData {
			action measureThumbFlex {
				out thumbAngle : FlexAngle;
			}
			action measureIndexFlex {
				out indexAngle : FlexAngle;
			}
			action measureMiddleFlex {
				out middleAngle : FlexAngle;
			}
			action measureRingFlex {
				out ringAngle : FlexAngle;
			}
			action measurePinkyFlex {
				out pinkyAngle : FlexAngle;
			}
			action measureThumbForce {
				out thumbForce : ForceLevel;
			}
			action measureIndexForce {
				out indexForce : ForceLevel;
			}
			action measureHandPosition {
				out position : Position3D;
				out orientation : Orientation3D;
			}
		}

		then action aggregateData {
			in flexData : FlexAngle[5];
			in forceData : ForceLevel[2];
			in motionData : Position3D;
			out aggregatedSensorData : RawSensorData[*];
		}

		then action processAndRecognize {
			in sensorData : RawSensorData[*];
			out gesture : ProcessedGestureData;

			action filterNoise {
				in rawInputs : RawSensorData[*];
				out cleanData : RawSensorData[*];
			}

			action applyCalibration {
				in cleanData : RawSensorData[*];
				out calibratedData : RawSensorData[*];
			}

			action classifyGesture {
				in calibratedData : RawSensorData[*];
				out detectedGesture : ProcessedGestureData;
			}
		}

		then action transmitGesture {
			in gesture : ProcessedGestureData;
			out transmittedGesture : ProcessedGestureData;
		}

		then decide;
			if transmitGesture.transmittedGesture.confidence > 0.8 then continuousCapture;
			if transmitGesture.transmittedGesture.confidence <= 0.8 then recalibrate;

		action recalibrate {
			out newCalibration : CalibrationData;
		}
		then continuousCapture;
	}

	state machine GloveSystemBehavior {
		initial state Off;

		state Off {
			accept PowerOn;
			then Calibrating;
		}

		state Calibrating {
			accept CalibrationComplete;
			then Active;
		}

		state Active {
			entry action {
				perform captureHandGesture;
			}
			accept PowerOff;
			then ShuttingDown;
		}

		state ShuttingDown;
		then Off;
	}

	requirement def AccuracyRequirement {
		doc /* The system shall recognize gestures with minimum 90% accuracy. */

		subject wiredGlove : WiredGlove;

		require constraint {
			wiredGlove.processor.processData.gestureResult.confidence >= 0.90
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall process and transmit gesture data within 50 milliseconds. */

		subject wiredGlove : WiredGlove;

		attribute maxLatency : ISQ::TimeValue = 0.05 [SI::s];
	}

	requirement def BatteryLifeRequirement {
		doc /* The system shall operate continuously for at least 8 hours on a single charge. */

		subject battery : PowerSupply;

		attribute minOperatingTime : ISQ::TimeValue = 28800.0 [SI::s];

		require constraint {
			battery.currentCharge >= battery.batteryCapacity * 0.1
		}
	}

	requirement def SensorRangeRequirement {
		doc /* Flex sensors shall measure finger bend angles from 0 to 180 degrees. */

		subject flexSensor : FlexSensor;

		require constraint {
			flexSensor.minAngle.num == 0.0 and
			flexSensor.maxAngle.num == 180.0
		}
	}

	requirement <'GLOVE-001'> primaryFunctionRequirement {
		doc /* 
			The wired glove system shall capture hand and finger movements in real-time,
			process sensor data to recognize gestures, and transmit gesture information
			wirelessly to enable natural human-computer interaction and virtual reality control.
		*/

		subject gloveSystem : WiredGlove;

		assume constraint {
			gloveSystem.battery.currentCharge > 0.0 [SI::J]
		}

		require accuracyReq : AccuracyRequirement;
		require responseReq : ResponseTimeRequirement;
		require batteryReq : BatteryLifeRequirement;
		require sensorReq : SensorRangeRequirement;
	}
}
