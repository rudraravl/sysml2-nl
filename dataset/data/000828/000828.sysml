package WatsonCapsuleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ConcentrationValue :> Real;
	
	attribute def pHValue :> Real;
	
	item def BiologicalSample {
		attribute volume : VolumeValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute pH : pHValue;
	}
	
	item def DiagnosticData {
		attribute biomarkerConcentration : ConcentrationValue;
		attribute sampleTemperature : ThermodynamicTemperatureValue;
		attribute samplePH : pHValue;
		attribute timestamp : String;
	}
	
	item def AnalysisResult {
		attribute diagnosis : String;
		attribute confidence : Real;
		attribute recommendations : String;
	}
	
	item def PowerStatus {
		attribute batteryLevel : Real;
		attribute voltage : ElectricPotentialValue;
	}
	
	port def SampleInputPort {
		in item sample : BiologicalSample;
	}
	
	port def DataOutputPort {
		out item data : DiagnosticData;
	}
	
	port def ResultOutputPort {
		out item result : AnalysisResult;
	}
	
	port def PowerMonitorPort {
		out item status : PowerStatus;
	}
	
	part def SensorArray {
		attribute sensitivity : Real;
		attribute calibrationDate : String;
		
		port sampleIn : SampleInputPort;
		port dataOut : DataOutputPort;
		
		action def MeasureBiomarkers {
			in sample : BiologicalSample;
			out data : DiagnosticData;
		}
		
		perform action measure : MeasureBiomarkers;
	}
	
	part def AnalyticsEngine {
		attribute modelVersion : String;
		attribute processingCapacity : Real;
		
		port diagnosticDataIn {
			in item inputData : DiagnosticData;
		}
		
		port analysisOut : ResultOutputPort;
		
		action def AnalyzeData {
			in diagnosticData : DiagnosticData;
			out analysisResult : AnalysisResult;
		}
		
		perform action analyze : AnalyzeData;
	}
	
	part def CommunicationModule {
		attribute transmissionProtocol : String;
		attribute signalStrength : Real;
		
		port resultIn {
			in item result : AnalysisResult;
		}
		
		port externalOut {
			out item transmittedResult : AnalysisResult;
		}
		
		action def TransmitResults {
			in result : AnalysisResult;
			out transmitted : AnalysisResult;
		}
		
		perform action transmit : TransmitResults;
	}
	
	part def PowerManagement {
		attribute batteryCapacity : EnergyValue;
		attribute currentCharge : Real;
		
		port powerStatus : PowerMonitorPort;
		
		action def MonitorPower {
			out status : PowerStatus;
		}
		
		perform action monitor : MonitorPower;
	}
	
	part def CapsuleHousing {
		attribute dimensions : LengthValue[3];
		attribute material : String;
		attribute biocompatible : Boolean;
	}
	
	action def WatsonCapsuleOperation {
		in biologicalSample : BiologicalSample;
		out finalResult : AnalysisResult;
		
		first start;
		then action sensing : SensorArray::MeasureBiomarkers {
			in sample = biologicalSample;
			out data;
		}
		then action analysis : AnalyticsEngine::AnalyzeData {
			in diagnosticData = sensing.data;
			out analysisResult;
		}
		then action transmission : CommunicationModule::TransmitResults {
			in result = analysis.analysisResult;
			out transmitted;
		}
		then assign finalResult := transmission.transmitted;
		then done;
	}
	
	part def WatsonCapsule {
		attribute capsuleID : String;
		attribute deploymentDate : String;
		attribute operatingTemperatureRange : ThermodynamicTemperatureValue[2];
		
		part housing : CapsuleHousing {
			attribute :>> dimensions = (15.0, 8.0, 8.0) [SI::mm];
			attribute :>> material = "Medical-grade polymer";
			attribute :>> biocompatible = true;
		}
		
		part sensors : SensorArray {
			attribute :>> sensitivity = 0.95;
			attribute :>> calibrationDate = "2024-01-15";
		}
		
		part analytics : AnalyticsEngine {
			attribute :>> modelVersion = "Watson-AI-v3.2";
			attribute :>> processingCapacity = 1000.0;
		}
		
		part comms : CommunicationModule {
			attribute :>> transmissionProtocol = "BLE-5.2";
			attribute :>> signalStrength = 0.85;
		}
		
		part powerMgmt : PowerManagement {
			attribute :>> batteryCapacity = 500.0 [SI::mJ];
			attribute :>> currentCharge = 100.0;
		}
		
		connection sensorToAnalytics
			connect sensors.dataOut to analytics.diagnosticDataIn;
		
		connection analyticsToComms
			connect analytics.analysisOut to comms.resultIn;
		
		perform action operate : WatsonCapsuleOperation;
	}
	
	part externalSystem {
		port resultReceiver {
			in item receivedResult : AnalysisResult;
		}
	}
	
	part capsule : WatsonCapsule {
		attribute :>> capsuleID = "WC-2024-001";
		attribute :>> deploymentDate = "2024-03-01";
		attribute :>> operatingTemperatureRange = (36.0, 38.0) [SI::'°C'];
		
		perform action operate[*] ordered;
	}
	
	connection capsuleToExternal
		connect capsule.comms.externalOut to externalSystem.resultReceiver;
	
	requirement def <'REQ-WC-001'> PrimaryDiagnosticFunction {
		doc /* The Watson capsule shall autonomously collect biological samples from the 
		       gastrointestinal tract, perform real-time diagnostic analysis using embedded 
		       AI analytics, and wirelessly transmit results to external monitoring systems. */
		
		subject capsule : WatsonCapsule;
		
		require constraint sampleCollection {
			doc /* The capsule must collect and analyze biological samples during transit. */
			capsule.sensors.measure.sample.volume > 0.0 [SI::mL]
		}
		
		require constraint aiAnalysis {
			doc /* The analytics engine must process diagnostic data with minimum 90% confidence. */
			capsule.analytics.analyze.analysisResult.confidence >= 0.90
		}
		
		require constraint wirelessTransmission {
			doc /* Results must be transmitted wirelessly to external systems. */
			capsule.comms.transmit.transmitted == capsule.analytics.analyze.analysisResult
		}
	}
	
	requirement def <'REQ-WC-002'> BiocompatibilityRequirement {
		doc /* The Watson capsule housing shall be constructed from biocompatible materials 
		       suitable for safe passage through the human digestive system. */
		
		subject capsule : WatsonCapsule;
		
		require constraint materialSafety {
			doc /* Housing material must be biocompatible. */
			capsule.housing.biocompatible == true
		}
	}
	
	requirement def <'REQ-WC-003'> PowerEfficiency {
		doc /* The Watson capsule shall operate for the duration of gastrointestinal transit 
		       (typically 24-72 hours) on internal battery power. */
		
		subject capsule : WatsonCapsule;
		
		require constraint batteryLife {
			doc /* Battery must maintain sufficient charge throughout operation. */
			capsule.powerMgmt.currentCharge > 0.0
		}
	}
	
	requirement def <'REQ-WC-004'> DiagnosticAccuracy {
		doc /* The Watson capsule analytics engine shall achieve minimum 95% sensitivity 
		       in detecting target biomarkers for specified gastrointestinal conditions. */
		
		subject capsule : WatsonCapsule;
		
		require constraint sensorSensitivity {
			doc /* Sensor array must maintain calibrated sensitivity above 90%. */
			capsule.sensors.sensitivity >= 0.90
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for Watson capsule diagnostic system. */
		
		require PrimaryDiagnosticFunction;
		require BiocompatibilityRequirement;
		require PowerEfficiency;
		require DiagnosticAccuracy;
	}
}
