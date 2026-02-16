package 'Visual Sensing Unit System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	comment about VisualSensorNetwork
	/* This model describes a visual sensing unit that measures illuminance
	 * and spatial characteristics using a network of optical sensors.
	 * The system coordinates multiple visual sensors to provide comprehensive
	 * environmental monitoring with data fusion and processing capabilities. */
	
	attribute def DimensionOneValue :> ScalarQuantityValue {
		attribute :>> num : Integer;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def IlluminanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def FrameRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def ResolutionValue :> ScalarQuantityValue {
		attribute :>> num : Integer;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def FieldOfViewValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def LatencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	attribute def AreaValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	item def RawImageFrame {
		attribute timestamp : TimeValue;
		attribute sensorId : String;
		attribute pixelData : Integer[*];
		attribute resolution : ResolutionValue;
		attribute illuminance : IlluminanceValue;
	}
	
	item def ProcessedImageData {
		attribute frameId : String;
		attribute enhancedData : Integer[*];
		attribute qualityMetric : Real;
		attribute detectedFeatures : Integer;
	}
	
	item def FusedSensorData {
		attribute aggregatedIlluminance : IlluminanceValue;
		attribute coverageArea : AreaValue;
		attribute activeSensorCount : Integer;
		attribute fusionTimestamp : TimeValue;
		attribute dataQuality : Real;
	}
	
	item def MeasurementReport {
		attribute reportId : String;
		attribute averageIlluminance : IlluminanceValue;
		attribute spatialCoverage : AreaValue;
		attribute measurementAccuracy : Real;
		attribute sensorStatus : String[*];
	}
	
	port def SensorOutputPort {
		out item rawFrame : RawImageFrame;
	}
	
	port def ProcessingInputPort {
		in item rawFrame : RawImageFrame;
	}
	
	port def ProcessingOutputPort {
		out item processedData : ProcessedImageData;
	}
	
	port def FusionInputPort {
		in item processedData : ProcessedImageData;
	}
	
	port def FusionOutputPort {
		out item fusedData : FusedSensorData;
	}
	
	port def ReportOutputPort {
		out item report : MeasurementReport;
	}
	
	port def ControlPort {
		in item command : String;
		out item status : String;
	}
	
	port def PowerPort {
		in item voltage : VoltageValue;
	}
	
	connection def SensorDataConnection {
		end source : SensorOutputPort[1];
		end sink : ProcessingInputPort[1];
	}
	
	connection def ProcessedDataConnection {
		end source : ProcessingOutputPort[1];
		end sink : FusionInputPort[1];
	}
	
	connection def FusionDataConnection {
		end source : FusionOutputPort[1];
		end sink : ReportOutputPort[1];
	}
	
	connection def ControlBusConnection {
		end controller : ControlPort[1];
		end controlled : ControlPort[1..*];
	}
	
	enum def SensorState {
		enum Initializing;
		enum Active;
		enum Standby;
		enum Calibrating;
		enum Fault;
	}
	
	enum def SystemMode {
		enum Startup;
		enum NormalOperation;
		enum HighPrecision;
		enum LowPower;
		enum Maintenance;
	}
	
	action def CaptureImage {
		in sceneIlluminance : IlluminanceValue;
		in exposureTime : TimeValue;
		out rawFrame : RawImageFrame;
	}
	
	action def ProcessImage {
		in rawFrame : RawImageFrame;
		out processedData : ProcessedImageData;
	}
	
	action def FuseData {
		in processedFrames : ProcessedImageData[1..*];
		out fusedData : FusedSensorData;
	}
	
	action def GenerateReport {
		in fusedData : FusedSensorData;
		out report : MeasurementReport;
	}
	
	action def CalibrateSensor {
		in calibrationTarget : IlluminanceValue;
		out calibrationStatus : String;
	}
	
	action def MeasurementSequence {
		in item operatingMode : String;
		out item finalReport : MeasurementReport;
		
		action initialize {
			out initStatus : String;
		}
		
		then fork;
		
		action captureSensor1 : CaptureImage {
			in sceneIlluminance;
			in exposureTime;
			out frame1 : RawImageFrame;
		}
		
		then joinNode;
		
		action captureSensor2 : CaptureImage {
			in sceneIlluminance;
			in exposureTime;
			out frame2 : RawImageFrame;
		}
		
		then joinNode;
		
		action captureSensor3 : CaptureImage {
			in sceneIlluminance;
			in exposureTime;
			out frame3 : RawImageFrame;
		}
		
		then joinNode;
		
		action captureSensor4 : CaptureImage {
			in sceneIlluminance;
			in exposureTime;
			out frame4 : RawImageFrame;
		}
		
		then joinNode;
		
		join joinNode;
		
		then fork;
		
		action processSensor1 : ProcessImage {
			in rawFrame;
			out data1 : ProcessedImageData;
		}
		
		then joinNode2;
		
		action processSensor2 : ProcessImage {
			in rawFrame;
			out data2 : ProcessedImageData;
		}
		
		then joinNode2;
		
		action processSensor3 : ProcessImage {
			in rawFrame;
			out data3 : ProcessedImageData;
		}
		
		then joinNode2;
		
		action processSensor4 : ProcessImage {
			in rawFrame;
			out data4 : ProcessedImageData;
		}
		
		then joinNode2;
		
		flow from captureSensor1.frame1 to processSensor1.rawFrame;
		flow from captureSensor2.frame2 to processSensor2.rawFrame;
		flow from captureSensor3.frame3 to processSensor3.rawFrame;
		flow from captureSensor4.frame4 to processSensor4.rawFrame;
		
		join joinNode2;
		
		then fuseAllData : FuseData {
			in processedFrames;
			out fusedData;
		}
		
		flow from processSensor1.data1 to fuseAllData.processedFrames;
		flow from processSensor2.data2 to fuseAllData.processedFrames;
		flow from processSensor3.data3 to fuseAllData.processedFrames;
		flow from processSensor4.data4 to fuseAllData.processedFrames;
		
		then generateFinalReport : GenerateReport {
			in fusedData;
			out report;
		}
		
		flow from fuseAllData.fusedData to generateFinalReport.fusedData;
		
		bind generateFinalReport.report = finalReport;
		
		then done;
	}
	
	state def SensorOperationStateMachine {
		entry; then initializing;
		
		state initializing {
			entry; do CalibrateSensor;
		}
		transition init_to_standby
			first initializing
			accept InitializationComplete
			then standby;
		
		state standby;
		transition standby_to_active
			first standby
			accept ActivationCommand
			then active;
		
		state active {
			entry; then capturing;
			
			state capturing {
				do CaptureImage;
			}
			transition capturing_to_processing
				first capturing
				accept FrameCaptured
				then processing;
			
			state processing {
				do ProcessImage;
			}
			transition processing_to_capturing
				first processing
				accept ProcessingComplete
				then capturing;
		}
		
		transition active_to_standby
			first active
			accept DeactivationCommand
			then standby;
		
		transition active_to_calibrating
			first active
			accept CalibrationRequest
			then calibrating;
		
		state calibrating {
			do CalibrateSensor;
		}
		transition calibrating_to_standby
			first calibrating
			accept CalibrationComplete
			then standby;
		
		transition any_to_fault
			first standby
			accept FaultDetected
			then fault;
		
		state fault;
		transition fault_to_initializing
			first fault
			accept FaultCleared
			then initializing;
	}
	
	state def SystemOperationStateMachine {
		entry; then startup;
		
		state startup;
		transition startup_to_normal
			first startup
			accept SystemReady
			then normalOperation;
		
		state normalOperation {
			do MeasurementSequence;
		}
		
		transition normal_to_highPrecision
			first normalOperation
			accept HighPrecisionRequest
			then highPrecision;
		
		state highPrecision {
			do MeasurementSequence;
		}
		
		transition highPrecision_to_normal
			first highPrecision
			accept NormalModeRequest
			then normalOperation;
		
		transition normal_to_lowPower
			first normalOperation
			accept LowPowerRequest
			then lowPower;
		
		state lowPower;
		
		transition lowPower_to_normal
			first lowPower
			accept WakeupRequest
			then normalOperation;
		
		transition any_to_maintenance
			first normalOperation
			accept MaintenanceRequest
			then maintenance;
		
		state maintenance;
		
		transition maintenance_to_startup
			first maintenance
			accept MaintenanceComplete
			then startup;
	}
	
	part def OpticalAssembly {
		attribute focalLength : LengthValue;
		attribute apertureDiameter : LengthValue;
		attribute transmittance : Real;
		
		part lens : Lens {
			attribute focalLength : LengthValue;
			attribute refractiveIndex : Real;
		}
		
		part filter : OpticalFilter {
			attribute wavelengthRange : LengthValue[2];
			attribute filterType : String;
		}
	}
	
	part def Lens {
		attribute focalLength : LengthValue;
		attribute refractiveIndex : Real;
		attribute coatingType : String;
	}
	
	part def OpticalFilter {
		attribute wavelengthRange : LengthValue[2];
		attribute filterType : String;
		attribute transmissionEfficiency : Real;
	}
	
	part def ImageSensorArray {
		attribute pixelCount : ResolutionValue;
		attribute sensitivity : IlluminanceValue;
		attribute quantumEfficiency : Real;
		attribute dynamicRange : Real;
	}
	
	part def SignalProcessor {
		attribute processingRate : FrameRateValue;
		attribute bufferCapacity : Integer;
		attribute algorithmVersion : String;
	}
	
	part def VisualSensor {
		attribute sensorId : String;
		attribute fieldOfView : FieldOfViewValue;
		attribute resolution : ResolutionValue;
		attribute frameRate : FrameRateValue;
		attribute currentState : SensorState;
		attribute measuredIlluminance : IlluminanceValue;
		
		port dataOutput : SensorOutputPort;
		port control : ControlPort;
		port power : PowerPort;
		
		part optics : OpticalAssembly;
		part imageSensor : ImageSensorArray;
		part processor : SignalProcessor;
		
		perform action sensorBehavior : MeasurementSequence;
		exhibit state sensorStateMachine : SensorOperationStateMachine;
	}
	
	part def DataProcessor {
		attribute processorId : String;
		attribute processingLatency : LatencyValue;
		attribute throughput : FrameRateValue;
		
		port input : ProcessingInputPort;
		port output : ProcessingOutputPort;
		port control : ControlPort;
		port power : PowerPort;
		
		part computeUnit : ComputeEngine {
			attribute coreCount : Integer;
			attribute clockSpeed : FrequencyValue;
		}
		
		part memory : DataBuffer {
			attribute capacity : Integer;
			attribute accessSpeed : FrequencyValue;
		}
	}
	
	part def ComputeEngine {
		attribute coreCount : Integer;
		attribute clockSpeed : FrequencyValue;
		attribute architecture : String;
	}
	
	part def DataBuffer {
		attribute capacity : Integer;
		attribute accessSpeed : FrequencyValue;
		attribute currentLoad : Integer;
	}
	
	part def DataFusionUnit {
		attribute fusionAlgorithm : String;
		attribute fusionLatency : LatencyValue;
		attribute dataQualityThreshold : Real;
		
		port input : FusionInputPort;
		port output : FusionOutputPort;
		port control : ControlPort;
		port power : PowerPort;
		
		part fusionEngine : FusionProcessor {
			attribute algorithmType : String;
			attribute weightingScheme : String;
		}
		
		part qualityAnalyzer : QualityAssessment {
			attribute assessmentMetric : String;
			attribute confidenceLevel : Real;
		}
	}
	
	part def FusionProcessor {
		attribute algorithmType : String;
		attribute weightingScheme : String;
		attribute convergenceRate : Real;
	}
	
	part def QualityAssessment {
		attribute assessmentMetric : String;
		attribute confidenceLevel : Real;
		attribute validationThreshold : Real;
	}
	
	part def NetworkController {
		attribute controllerId : String;
		attribute controlStrategy : String;
		
		port masterControl : ControlPort;
		port power : PowerPort;
		
		part synchronizer : TimeSynchronizer {
			attribute clockAccuracy : TimeValue;
			attribute syncProtocol : String;
		}
		
		part coordinator : TaskCoordinator {
			attribute schedulingPolicy : String;
			attribute priorityLevels : Integer;
		}
	}
	
	part def TimeSynchronizer {
		attribute clockAccuracy : TimeValue;
		attribute syncProtocol : String;
		attribute driftCompensation : Boolean;
	}
	
	part def TaskCoordinator {
		attribute schedulingPolicy : String;
		attribute priorityLevels : Integer;
		attribute loadBalancing : Boolean;
	}
	
	part def PowerSupply {
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
		attribute efficiency : Real;
		
		port powerOut : PowerPort;
	}
	
	part def VisualSensorNetwork {
		attribute networkId : String;
		attribute totalCoverage : AreaValue;
		attribute measurementAccuracy : Real;
		attribute operationalMode : SystemMode;
		
		part sensors : VisualSensor[4];
		part processors : DataProcessor[4];
		part fusionUnit : DataFusionUnit;
		part controller : NetworkController;
		part powerSupply : PowerSupply;
		
		connection sensorToProcessor1 : SensorDataConnection
			connect source => sensors[1].dataOutput
			to sink => processors[1].input;
		
		connection sensorToProcessor2 : SensorDataConnection
			connect source => sensors[2].dataOutput
			to sink => processors[2].input;
		
		connection sensorToProcessor3 : SensorDataConnection
			connect source => sensors[3].dataOutput
			to sink => processors[3].input;
		
		connection sensorToProcessor4 : SensorDataConnection
			connect source => sensors[4].dataOutput
			to sink => processors[4].input;
		
		connection processorToFusion1 : ProcessedDataConnection
			connect source => processors[1].output
			to sink => fusionUnit.input;
		
		connection processorToFusion2 : ProcessedDataConnection
			connect source => processors[2].output
			to sink => fusionUnit.input;
		
		connection processorToFusion3 : ProcessedDataConnection
			connect source => processors[3].output
			to sink => fusionUnit.input;
		
		connection processorToFusion4 : ProcessedDataConnection
			connect source => processors[4].output
			to sink => fusionUnit.input;
		
		connection controlBus : ControlBusConnection
			connect controller => controller.masterControl
			to controlled => sensors.control;
		
		connect controlBus to processors.control;
		connect controlBus to fusionUnit.control;
		
		connect powerSupply.powerOut to sensors.power;
		connect powerSupply.powerOut to processors.power;
		connect powerSupply.powerOut to fusionUnit.power;
		connect powerSupply.powerOut to controller.power;
		
		exhibit state systemStateMachine : SystemOperationStateMachine;
	}
	
	part def VisualSensingUnit {
		attribute unitId : String;
		attribute totalMeasurementLatency : LatencyValue;
		attribute systemAvailability : Real;
		
		port reportOutput : ReportOutputPort;
		port externalControl : ControlPort;
		port externalPower : PowerPort;
		
		part network : VisualSensorNetwork;
		
		connection fusionToReport : FusionDataConnection
			connect source => network.fusionUnit.output
			to sink => reportOutput;
		
		connect externalControl to network.controller.masterControl;
		connect externalPower to network.powerSupply.powerOut;
		
		perform action measurementOperation : MeasurementSequence;
	}
	
	requirement def IlluminanceMeasurementRequirement {
		doc /* The visual sensing unit shall measure illuminance with 
		     * accuracy better than 5% across the monitored coverage area. */
		
		subject sensingUnit : VisualSensingUnit;
		
		require constraint {
			sensingUnit.network.measurementAccuracy >= 0.95
		}
	}
	
	requirement def SpatialCoverageRequirement {
		doc /* The visual sensor network shall provide continuous spatial 
		     * coverage of at least 150 square meters with overlapping 
		     * fields of view for redundancy. */
		
		subject sensingUnit : VisualSensingUnit;
		
		require constraint {
			sensingUnit.network.totalCoverage.num >= 150.0
		}
	}
	
	requirement def ResponseLatencyRequirement {
		doc /* The visual sensing unit shall complete measurement acquisition,
		     * processing, fusion, and reporting within 100 milliseconds 
		     * end-to-end latency. */
		
		subject sensingUnit : VisualSensingUnit;
		
		require constraint {
			sensingUnit.totalMeasurementLatency.num <= 100.0
		}
	}
	
	requirement def RedundancyRequirement {
		doc /* The visual sensor network shall maintain operational capability
		     * with at least 3 active sensors to ensure measurement reliability
		     * and fault tolerance. */
		
		subject network : VisualSensorNetwork;
	}
	
	requirement def DataQualityRequirement {
		doc /* The data fusion unit shall ensure fused sensor data quality
		     * exceeds 85% confidence threshold before generating measurement
		     * reports. */
		
		subject fusionUnit : DataFusionUnit;
		
		require constraint {
			fusionUnit.dataQualityThreshold >= 0.85
		}
	}
	
	requirement def AvailabilityRequirement {
		doc /* The visual sensing unit shall maintain system availability
		     * of at least 99% during operational periods. */
		
		subject sensingUnit : VisualSensingUnit;
		
		require constraint {
			sensingUnit.systemAvailability >= 0.99
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the visual sensing unit system. */
		
		requirement illuminanceMeasurement : IlluminanceMeasurementRequirement;
		requirement spatialCoverage : SpatialCoverageRequirement;
		requirement responseLatency : ResponseLatencyRequirement;
		requirement redundancy : RedundancyRequirement;
		requirement dataQuality : DataQualityRequirement;
		requirement availability : AvailabilityRequirement;
	}
	
	part visualSensingUnitInstance : VisualSensingUnit {
		attribute :>> unitId = "VSU-MAIN-001";
		attribute :>> systemAvailability = 0.995;
	}
	
	satisfy systemRequirements.illuminanceMeasurement by visualSensingUnitInstance;
	satisfy systemRequirements.spatialCoverage by visualSensingUnitInstance;
	satisfy systemRequirements.responseLatency by visualSensingUnitInstance;
	satisfy systemRequirements.redundancy by visualSensingUnitInstance.network;
	satisfy systemRequirements.dataQuality by visualSensingUnitInstance.network.fusionUnit;
	satisfy systemRequirements.availability by visualSensingUnitInstance;
}
