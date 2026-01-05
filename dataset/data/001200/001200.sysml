package 'Position Sensing Unit Design' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQSpaceTime::*;
	private import SI::*;
	private import MeasurementReferences::*;
	private import Quantities::*;
	
	comment about PositionSensingUnitDef
	/* This model describes a position sensing unit that measures three-dimensional
	 * spatial position using a position sensor. The system includes sensor hardware,
	 * signal conditioning, data processing, and calibration capabilities to provide
	 * accurate position measurements in a defined coordinate frame. */
	
	attribute def PositionVector :> VectorQuantityValue {
		attribute :>> num : Real[3] ordered;
		attribute :>> mRef : PositionCoordinateFrame;
	}
	
	attribute def PositionCoordinateFrame :> CoordinateFrame {
		attribute origin : PositionVector[1];
		attribute xAxis : VectorQuantityValue[1];
		attribute yAxis : VectorQuantityValue[1];
		attribute zAxis : VectorQuantityValue[1];
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> SimpleUnit;
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def FrequencyUnit :> DerivedUnit;
	
	item def PositionMeasurement {
		attribute timestamp : Real;
		attribute position : PositionVector;
		attribute quality : Real;
		attribute valid : Boolean;
	}
	
	item def CalibrationParameters {
		attribute xOffset : LengthValue;
		attribute yOffset : LengthValue;
		attribute zOffset : LengthValue;
		attribute scaleFactor : Real;
		attribute rotationMatrix : Real[9] ordered;
	}
	
	item def RawSensorData {
		attribute xVoltage : VoltageValue;
		attribute yVoltage : VoltageValue;
		attribute zVoltage : VoltageValue;
		attribute timestamp : Real;
	}
	
	port def SensorOutputPort {
		out item measurement : PositionMeasurement;
	}
	
	port def PowerInputPort {
		in attribute voltage : VoltageValue;
		in attribute current : Real;
	}
	
	port def CalibrationPort {
		in item parameters : CalibrationParameters;
		out item status : Boolean;
	}
	
	port def RawDataPort {
		out item rawData : RawSensorData;
	}
	
	port def ProcessedDataPort {
		in item rawData : RawSensorData;
		out item measurement : PositionMeasurement;
	}
	
	connection def DataConnection {
		end source : RawDataPort;
		end sink : ProcessedDataPort;
	}
	
	action def AcquireRawPosition {
		out item rawData : RawSensorData;
		
		action sampleXChannel {
			out xVolt : VoltageValue;
		}
		
		action sampleYChannel {
			out yVolt : VoltageValue;
		}
		
		action sampleZChannel {
			out zVolt : VoltageValue;
		}
		
		action assembleData {
			in xV : VoltageValue;
			in yV : VoltageValue;
			in zV : VoltageValue;
			out item assembled : RawSensorData;
		}
		
		first sampleXChannel;
		then fork;
		then sampleYChannel;
		then sampleZChannel;
		join;
		then assembleData;
		
		flow from sampleXChannel.xVolt to assembleData.xV;
		flow from sampleYChannel.yVolt to assembleData.yV;
		flow from sampleZChannel.zVolt to assembleData.zV;
		bind assembleData.assembled = rawData;
	}
	
	action def ProcessSensorData {
		in item rawInput : RawSensorData;
		in item calibration : CalibrationParameters;
		out item measurement : PositionMeasurement;
		
		action convertToLength {
			in item raw : RawSensorData;
			out xLength : LengthValue;
			out yLength : LengthValue;
			out zLength : LengthValue;
		}
		
		action applyCal {
			in xRaw : LengthValue;
			in yRaw : LengthValue;
			in zRaw : LengthValue;
			in item cal : CalibrationParameters;
			out xCal : LengthValue;
			out yCal : LengthValue;
			out zCal : LengthValue;
		}
		
		action filterNoise {
			in xIn : LengthValue;
			in yIn : LengthValue;
			in zIn : LengthValue;
			out xFiltered : LengthValue;
			out yFiltered : LengthValue;
			out zFiltered : LengthValue;
		}
		
		action constructMeas {
			in xPos : LengthValue;
			in yPos : LengthValue;
			in zPos : LengthValue;
			out item result : PositionMeasurement;
		}
		
		first convertToLength;
		then applyCal;
		then filterNoise;
		then constructMeas;
		
		flow from convertToLength.xLength to applyCal.xRaw;
		flow from convertToLength.yLength to applyCal.yRaw;
		flow from convertToLength.zLength to applyCal.zRaw;
		flow from applyCal.xCal to filterNoise.xIn;
		flow from applyCal.yCal to filterNoise.yIn;
		flow from applyCal.zCal to filterNoise.zIn;
		flow from filterNoise.xFiltered to constructMeas.xPos;
		flow from filterNoise.yFiltered to constructMeas.yPos;
		flow from filterNoise.zFiltered to constructMeas.zPos;
		bind constructMeas.result = measurement;
	}
	
	action def PerformCalibration {
		in item referencePosition : PositionVector;
		in item measuredPosition : PositionMeasurement;
		out item calibrationParams : CalibrationParameters;
		
		action computeOffsets {
			in item reference : PositionVector;
			in item measured : PositionMeasurement;
			out xOff : LengthValue;
			out yOff : LengthValue;
			out zOff : LengthValue;
		}
		
		action computeScale {
			in xOffset : LengthValue;
			in yOffset : LengthValue;
			in zOffset : LengthValue;
			out scale : Real;
		}
		
		action computeRotation {
			in item ref : PositionVector;
			in item meas : PositionMeasurement;
			out rotation : Real[9];
		}
		
		action assembleParameters {
			in xOff : LengthValue;
			in yOff : LengthValue;
			in zOff : LengthValue;
			in scale : Real;
			in rotation : Real[9];
			out item params : CalibrationParameters;
		}
		
		first computeOffsets;
		then fork;
		then computeScale;
		then computeRotation;
		join;
		then assembleParameters;
		
		flow from computeOffsets.xOff to computeScale.xOffset;
		flow from computeOffsets.yOff to computeScale.yOffset;
		flow from computeOffsets.zOff to computeScale.zOffset;
		flow from computeOffsets.xOff to assembleParameters.xOff;
		flow from computeOffsets.yOff to assembleParameters.yOff;
		flow from computeOffsets.zOff to assembleParameters.zOff;
		flow from computeScale.scale to assembleParameters.scale;
		flow from computeRotation.rotation to assembleParameters.rotation;
		bind assembleParameters.params = calibrationParams;
	}
	
	part def SensingElement {
		attribute sensitivity : Real;
		attribute operatingRange : LengthValue;
		attribute noiseLevel : VoltageValue;
		
		port rawOutput : RawDataPort;
		port power : PowerInputPort;
		
		perform action sense : AcquireRawPosition {
			out item rawData;
		}
		
		bind rawOutput.rawData = sense.rawData;
	}
	
	part def SignalProcessor {
		attribute processingLatency : Real;
		attribute filterCutoffFrequency : FrequencyValue;
		
		port rawInput : ProcessedDataPort;
		port processedOutput : SensorOutputPort;
		port calibrationInput : CalibrationPort;
		
		attribute currentCalibration : CalibrationParameters;
		
		perform action process : ProcessSensorData {
			in item rawInput;
			in item calibration :>> currentCalibration;
			out item measurement;
		}
		
		bind processedOutput.measurement = process.measurement;
	}
	
	part def CalibrationModule {
		attribute calibrationInterval : Real;
		attribute isCalibrated : Boolean;
		attribute lastCalibrationTime : Real;
		
		port calibrationOutput : CalibrationPort;
		
		perform action calibrate : PerformCalibration {
			in item referencePosition;
			in item measuredPosition;
			out item calibrationParams;
		}
		
		bind calibrationOutput.parameters = calibrate.calibrationParams;
	}
	
	state def SensorOperationalStates {
		entry; then powerOn;
		
		state powerOn {
			entry assign systemReady = false;
		}
		
		transition powerOn_to_initialization
			first powerOn
			then initialization;
		
		state initialization {
			do action initializeHardware;
		}
		
		transition initialization_to_calibration
			first initialization
			then calibration;
		
		state calibration {
			do action runCalibration : PerformCalibration;
			entry assign isCalibrated = false;
		}
		
		transition calibration_to_ready
			first calibration
			if isCalibrated
			then ready;
		
		state ready {
			entry assign systemReady = true;
		}
		
		transition ready_to_measuring
			first ready
			accept StartMeasurement
			then measuring;
		
		state measuring {
			do action continuousMeasure {
				loop action acquire : AcquireRawPosition;
				then process : ProcessSensorData;
			}
		}
		
		transition measuring_to_ready
			first measuring
			accept StopMeasurement
			then ready;
		
		transition ready_to_recalibration
			first ready
			accept RecalibrationRequest
			then calibration;
		
		transition measuring_to_fault
			first measuring
			accept FaultDetected
			then fault;
		
		state fault {
			entry assign systemReady = false;
		}
		
		transition fault_to_powerOn
			first fault
			accept SystemReset
			then powerOn;
	}
	
	part def PositionSensor {
		attribute sensorId : String;
		attribute measurementAccuracy : LengthValue;
		attribute samplingRate : FrequencyValue;
		attribute maxRange : LengthValue;
		
		port dataOutput : SensorOutputPort;
		port powerInput : PowerInputPort;
		port calibrationInterface : CalibrationPort;
		
		part sensingElement : SensingElement[1] {
			attribute :>> sensitivity = 1.0;
			attribute :>> operatingRange = 10.0[m];
			attribute :>> noiseLevel {
				attribute :>> num = 0.001;
			}
		}
		
		part signalProcessor : SignalProcessor[1] {
			attribute :>> processingLatency = 0.001;
			attribute :>> filterCutoffFrequency {
				attribute :>> num = 50.0;
			}
		}
		
		part calibrationModule : CalibrationModule[1] {
			attribute :>> calibrationInterval = 3600.0;
			attribute :>> isCalibrated = false;
			attribute :>> lastCalibrationTime = 0.0;
		}
		
		connection sensorToProcessor : DataConnection
			connect source references sensingElement.rawOutput
			to sink references signalProcessor.rawInput;
		
		connection calibrationToProcessor
			connect calibrationModule.calibrationOutput to signalProcessor.calibrationInput;
		
		bind dataOutput = signalProcessor.processedOutput;
		
		exhibit state operationalState : SensorOperationalStates;
	}
	
	part def PowerSupply {
		attribute nominalVoltage : VoltageValue;
		attribute maxCurrent : Real;
		attribute efficiency : Real;
		
		port powerOutput : PowerInputPort;
	}
	
	part def DataAcquisitionInterface {
		attribute dataRate : FrequencyValue;
		attribute bufferSize : Integer;
		attribute protocol : String;
		
		port sensorInput : SensorOutputPort;
		port systemOutput : SensorOutputPort;
		
		bind systemOutput.measurement = sensorInput.measurement;
	}
	
	part def PositionSensingUnitDef {
		attribute unitId : String;
		attribute installationFrame : PositionCoordinateFrame;
		attribute operationalStatus : Boolean;
		
		port measurementOutput : SensorOutputPort;
		port externalPower : PowerInputPort;
		
		part sensor : PositionSensor[1] {
			attribute :>> sensorId = "POS-001";
			attribute :>> measurementAccuracy = 0.001[m];
			attribute :>> samplingRate {
				attribute :>> num = 100.0;
			}
			attribute :>> maxRange = 10.0[m];
		}
		
		part powerSupply : PowerSupply[1] {
			attribute :>> nominalVoltage {
				attribute :>> num = 24.0;
			}
			attribute :>> maxCurrent = 2.0;
			attribute :>> efficiency = 0.85;
		}
		
		part dataInterface : DataAcquisitionInterface[1] {
			attribute :>> dataRate {
				attribute :>> num = 100.0;
			}
			attribute :>> bufferSize = 1024;
			attribute :>> protocol = "RS485";
		}
		
		connect powerSupply.powerOutput to sensor.powerInput;
		connect sensor.dataOutput to dataInterface.sensorInput;
		connect dataInterface.systemOutput to measurementOutput;
		connect externalPower to powerSupply.powerOutput;
	}
	
	requirement def AccuracyRequirement {
		doc /* The position sensor shall measure position with an accuracy
		     * of 1 millimeter or better within the specified operating range. */
		
		subject sensor : PositionSensor;
		
		require constraint {
			sensor.measurementAccuracy.num <= 0.001
		}
	}
	
	requirement def SamplingRateRequirement {
		doc /* The position sensor shall provide measurements at a minimum
		     * sampling rate of 100 Hz for real-time position tracking. */
		
		subject sensor : PositionSensor;
		
		require constraint {
			sensor.samplingRate.num >= 100.0
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The position sensor shall operate over a range of at least
		     * 10 meters in each spatial dimension. */
		
		subject sensor : PositionSensor;
		
		require constraint {
			sensor.maxRange.num >= 10.0
		}
	}
	
	requirement def CalibrationRequirement {
		doc /* The sensing unit shall support calibration to compensate for
		     * installation offsets and environmental variations. */
		
		subject unit : PositionSensingUnitDef;
		
		require constraint {
			unit.sensor.calibrationModule.isCalibrated == true
		}
	}
	
	requirement def PowerRequirement {
		doc /* The sensing unit shall operate from a 24V DC power supply
		     * with current consumption not exceeding 2 amperes. */
		
		subject unit : PositionSensingUnitDef;
		
		require constraint {
			unit.powerSupply.nominalVoltage.num == 24.0 and
			unit.powerSupply.maxCurrent <= 2.0
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the position sensing unit system. */
		
		requirement accuracyReq : AccuracyRequirement;
		requirement samplingReq : SamplingRateRequirement;
		requirement rangeReq : OperatingRangeRequirement;
		requirement calibrationReq : CalibrationRequirement;
		requirement powerReq : PowerRequirement;
	}
	
	part sensingUnitInstance : PositionSensingUnitDef {
		attribute :>> unitId = "PSU-MAIN-001";
		attribute :>> operationalStatus = false;
	}
	
	satisfy systemRequirements by sensingUnitInstance;
}
