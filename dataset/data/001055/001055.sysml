package 'Flow Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def VolumetricFlowRateValue :> ISQ::VolumetricFlowRateValue;
	
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	
	attribute def PressureValue :> ISQ::PressureValue;
	
	item def ProcessFluid {
		attribute temperature: TemperatureValue;
		attribute pressure: PressureValue;
		attribute flowRate: VolumetricFlowRateValue;
	}
	
	enum def SensorStatusKind {
		enum operational;
		enum calibrating;
		enum fault;
		enum standby;
	}
	
	port def FluidInletPort {
		in item fluid: ProcessFluid;
	}
	
	port def FluidOutletPort {
		out item fluid: ProcessFluid;
	}
	
	port def MeasurementOutputPort {
		out attribute flowRate: VolumetricFlowRateValue;
		out attribute temperature: TemperatureValue;
		out attribute pressure: PressureValue;
		out attribute timestamp: TimeInstantValue;
		out attribute status: SensorStatusKind;
	}
	
	requirement def FlowSensorRequirements {
		doc /* The flow sensor shall measure volumetric flow rate accurately and reliably. */
		
		requirement measurementAccuracy {
			doc /* The sensor shall measure flow rate with accuracy within +/- 1.5% of full scale. */
			attribute requiredAccuracy: Real = 0.015;
		}
		
		requirement measurementRange {
			doc /* The sensor shall measure flow rates from 0 to 500 liters per minute. */
			attribute minFlowRate: VolumetricFlowRateValue;
			attribute maxFlowRate: VolumetricFlowRateValue;
		}
		
		requirement responseTime {
			doc /* The sensor shall respond to flow changes within 200 milliseconds. */
			attribute maxResponseTime: DurationValue;
		}
	}
	
	part def FlowSensor {
		attribute serialNumber: String;
		attribute calibrationDate: TimeInstantValue;
		attribute measurementAccuracy: Real default 0.015;
		attribute minMeasurableFlow: VolumetricFlowRateValue;
		attribute maxMeasurableFlow: VolumetricFlowRateValue;
		attribute currentStatus: SensorStatusKind default SensorStatusKind::standby;
		
		port inlet: FluidInletPort;
		port outlet: FluidOutletPort;
		port measurementOut: MeasurementOutputPort;
		port powerInput: PowerInputPort;
		
		part sensingElement: SensingElement {
			attribute sensitivity: Real;
			attribute zeroOffset: Real default 0.0;
		}
		
		part signalConditioner: SignalConditioner {
			attribute gain: Real default 1.0;
			attribute filterFrequency: Real;
		}
		
		part calibrationData: CalibrationData {
			attribute zeroPointCorrection: Real default 0.0;
			attribute spanCorrection: Real default 1.0;
			attribute lastCalibrationTimestamp: TimeInstantValue;
		}
	}
	
	part def SensingElement {
		attribute sensitivity: Real;
		attribute zeroOffset: Real;
		
		port fluidContact: FluidInletPort;
		port rawSignalOut: RawSignalPort;
	}
	
	port def RawSignalPort {
		out attribute voltage: Real;
		out attribute frequency: Real;
	}
	
	part def SignalConditioner {
		attribute gain: Real;
		attribute filterFrequency: Real;
		
		port rawSignalIn: RawSignalPort;
		port conditionedSignalOut: ConditionedSignalPort;
	}
	
	port def ConditionedSignalPort {
		out attribute conditionedValue: Real;
		out attribute signalQuality: Real;
	}
	
	part def CalibrationData {
		attribute zeroPointCorrection: Real;
		attribute spanCorrection: Real;
		attribute lastCalibrationTimestamp: TimeInstantValue;
	}
	
	action def AcquireSignal {
		in item fluid: ProcessFluid;
		out attribute rawSignal: Real;
	}
	
	action def ConditionSignal {
		in attribute signal: Real;
		out attribute conditionedSignal: Real;
	}
	
	action def CalibrateValue {
		in attribute rawValue: Real;
		out attribute calibratedFlowRate: VolumetricFlowRateValue;
	}
	
	action def OutputMeasurement {
		in attribute flowRate: VolumetricFlowRateValue;
		in item fluid: ProcessFluid;
		out attribute finalFlowRate: VolumetricFlowRateValue;
		out attribute finalTemperature: TemperatureValue;
		out attribute finalPressure: PressureValue;
	}
	
	action def MeasureFlowRate {
		in item inputFluid: ProcessFluid;
		out attribute measuredFlowRate: VolumetricFlowRateValue;
		out attribute measuredTemperature: TemperatureValue;
		out attribute measuredPressure: PressureValue;
		out attribute measurementTimestamp: TimeInstantValue;
		
		action acquireSignal: AcquireSignal {
			in item fluid = inputFluid;
			out attribute rawSignal: Real;
		}
		
		then action conditionSignal: ConditionSignal {
			in attribute signal = acquireSignal.rawSignal;
			out attribute conditionedSignal: Real;
		}
		
		then action calibrateValue: CalibrateValue {
			in attribute rawValue = conditionSignal.conditionedSignal;
			out attribute calibratedFlowRate: VolumetricFlowRateValue;
		}
		
		then action outputMeasurement: OutputMeasurement {
			in attribute flowRate = calibrateValue.calibratedFlowRate;
			in item fluid = inputFluid;
			out attribute finalFlowRate: VolumetricFlowRateValue;
			out attribute finalTemperature: TemperatureValue;
			out attribute finalPressure: PressureValue;
		}
		
		bind measuredFlowRate = outputMeasurement.finalFlowRate;
		bind measuredTemperature = outputMeasurement.finalTemperature;
		bind measuredPressure = outputMeasurement.finalPressure;
	}
	
	action def MeasureReferenceFlow {
		in attribute reference: VolumetricFlowRateValue;
		out attribute measuredValue: VolumetricFlowRateValue;
	}
	
	action def CalculateCorrections {
		in attribute reference: VolumetricFlowRateValue;
		in attribute measured: VolumetricFlowRateValue;
		out attribute zeroCorrection: Real;
		out attribute spanCorrection: Real;
	}
	
	action def StoreCalibration {
		in attribute zeroCorr: Real;
		in attribute spanCorr: Real;
		out attribute success: Boolean;
	}
	
	action def PerformCalibration {
		in attribute referenceFlowRate: VolumetricFlowRateValue;
		out attribute newZeroCorrection: Real;
		out attribute newSpanCorrection: Real;
		out attribute calibrationSuccess: Boolean;
		
		action measureReferenceFlow: MeasureReferenceFlow {
			in attribute reference = referenceFlowRate;
			out attribute measuredValue: VolumetricFlowRateValue;
		}
		
		then action calculateCorrections: CalculateCorrections {
			in attribute reference = referenceFlowRate;
			in attribute measured = measureReferenceFlow.measuredValue;
			out attribute zeroCorrection: Real;
			out attribute spanCorrection: Real;
		}
		
		then action storeCalibration: StoreCalibration {
			in attribute zeroCorr = calculateCorrections.zeroCorrection;
			in attribute spanCorr = calculateCorrections.spanCorrection;
			out attribute success: Boolean;
		}
		
		bind newZeroCorrection = calculateCorrections.zeroCorrection;
		bind newSpanCorrection = calculateCorrections.spanCorrection;
		bind calibrationSuccess = storeCalibration.success;
	}
	
	state def FlowSensorStateMachine {
		entry; then standby;
		
		state standby {
			entry assign currentStatus = SensorStatusKind::standby;
		}
		
		transition standby_to_calibrating
			first standby
			accept calibrationRequest
			then calibrating;
		
		transition standby_to_operational
			first standby
			accept startMeasurement
			then operational;
		
		state calibrating {
			entry assign currentStatus = SensorStatusKind::calibrating;
			do action calibrationAction: PerformCalibration;
		}
		
		transition calibrating_to_operational
			first calibrating
			accept calibrationComplete
			then operational;
		
		state operational {
			entry assign currentStatus = SensorStatusKind::operational;
			do action measurementAction: MeasureFlowRate;
		}
		
		transition operational_to_standby
			first operational
			accept stopMeasurement
			then standby;
		
		transition operational_to_fault
			first operational
			accept errorDetected
			then fault;
		
		state fault {
			entry assign currentStatus = SensorStatusKind::fault;
		}
		
		transition fault_to_standby
			first fault
			accept resetSensor
			then standby;
	}
	
	part def DataProcessor {
		attribute processingRate: Real;
		port sensorDataInput: MeasurementOutputPort;
		port processedDataOutput: ProcessedDataPort;
	}
	
	port def ProcessedDataPort {
		out attribute processedFlowRate: VolumetricFlowRateValue;
		out attribute dataQuality: Real;
	}
	
	part def PowerModule {
		attribute inputVoltage: Real;
		attribute outputVoltage: Real;
		port powerOutput: PowerOutputPort;
	}
	
	port def PowerOutputPort {
		out attribute voltage: Real;
		out attribute current: Real;
	}
	
	port def PowerInputPort {
		in attribute voltage: Real;
		in attribute current: Real;
	}
	
	part def CommunicationModule {
		attribute protocolType: String;
		attribute dataRate: Real;
		port dataInterface: DataInterfacePort;
	}
	
	port def DataInterfacePort {
		inout attribute dataPacket: String;
	}
	
	connection def FluidFlowConnection {
		end source: FluidOutletPort[1];
		end target: FluidInletPort[1];
	}
	
	connection def MeasurementDataConnection {
		end source: MeasurementOutputPort[1];
		end target: MeasurementOutputPort[1];
	}
	
	connection def PowerConnection {
		end source: PowerOutputPort[1];
		end target: PowerInputPort[1];
	}
	
	part def SensingUnit {
		attribute unitIdentifier: String;
		attribute installationDate: TimeInstantValue;
		
		part flowSensor: FlowSensor {
			attribute :>> serialNumber = "FS-2025-001";
			attribute :>> measurementAccuracy = 0.015;
		}
		
		part dataProcessor: DataProcessor {
			attribute processingRate: Real;
		}
		
		part powerModule: PowerModule {
			attribute inputVoltage: Real;
			attribute outputVoltage: Real;
		}
		
		part communicationModule: CommunicationModule {
			attribute protocolType: String;
			attribute dataRate: Real;
		}
		
		port fluidInput: FluidInletPort;
		port fluidOutput: FluidOutletPort;
		port measurementOutput: MeasurementOutputPort;
		
		connection fluidFlowPath: FluidFlowConnection
			connect fluidInput to flowSensor.inlet
			connect flowSensor.outlet to fluidOutput;
		
		connection measurementDataPath: MeasurementDataConnection
			connect flowSensor.measurementOut to dataProcessor.sensorDataInput;
		
		connection powerConnection: PowerConnection
			connect powerModule.powerOutput to flowSensor.powerInput;
		
		flow of ProcessFluid from fluidInput to flowSensor.inlet;
		flow of ProcessFluid from flowSensor.outlet to fluidOutput;
		
		perform action measurementCycle: MeasureFlowRate;
		
		exhibit state sensorBehavior: FlowSensorStateMachine;
		
		satisfy flowSensorReqs: FlowSensorRequirements by flowSensor;
	}
	
	part def ProcessPipeline {
		attribute pipelineDiameter: LengthValue;
		attribute pipelineMaterial: String;
	}
	
	part def DataLogger {
		attribute storageCapacity: Real;
		attribute loggingInterval: DurationValue;
		port dataInput: MeasurementOutputPort;
		port dataStorage: DataStoragePort;
	}
	
	port def DataStoragePort {
		in attribute storedMeasurements: String;
	}
	
	part def FlowMeasurementSystem;
	
	part flowMeasurementSystem: FlowMeasurementSystem {
		part processPipeline: ProcessPipeline {
			attribute pipelineDiameter: LengthValue;
			attribute pipelineMaterial: String;
			port pipelineInlet: FluidInletPort;
			port pipelineOutlet: FluidOutletPort;
			port sensorMountPoint: FluidInletPort;
			port sensorExitPoint: FluidOutletPort;
		}
		
		part measurementUnit: SensingUnit {
			attribute :>> unitIdentifier = "SMU-2025-001";
		}
		
		part dataLogger: DataLogger {
			attribute storageCapacity: Real;
			attribute loggingInterval: DurationValue;
		}
		
		flow of ProcessFluid
			from processPipeline.sensorMountPoint
			to measurementUnit.fluidInput;
		
		flow of ProcessFluid
			from measurementUnit.fluidOutput
			to processPipeline.sensorExitPoint;
		
		connect measurementUnit.measurementOutput to dataLogger.dataInput;
	}
}
