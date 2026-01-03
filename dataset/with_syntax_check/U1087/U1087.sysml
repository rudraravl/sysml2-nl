package 'Horizon Scanning System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def ScanAngle :> Real;
	attribute def ConfidenceScore :> Real;
	attribute def ThreatLevel;
	attribute def ScanCommand;
	attribute def AlertSignal;
	attribute def TargetClassification;
	
	attribute def ScanSector {
		attribute azimuthStart : ScanAngle;
		attribute azimuthEnd : ScanAngle;
		attribute elevationStart : ScanAngle;
		attribute elevationEnd : ScanAngle;
	}
	
	attribute def DetectedTarget {
		attribute classification : TargetClassification;
		attribute range : LengthValue;
		attribute azimuth : ScanAngle;
		attribute elevation : ScanAngle;
		attribute velocity : SpeedValue;
		attribute confidence : ConfidenceScore;
		attribute threatLevel : ThreatLevel;
		attribute detectionTime : TimeValue;
	}
	
	item def SensorReading {
		attribute timestamp : TimeValue;
		attribute sectorScanned : ScanSector;
		attribute rawSignalStrength : Real;
		attribute detectedTargets : DetectedTarget[0..*];
	}
	
	port def SensorDataPort {
		out sensorReading : SensorReading;
	}
	
	port def ControlCommandPort {
		in command : ScanCommand;
		out status : Real;
	}
	
	port def AlertOutputPort {
		out alert : AlertSignal;
		out targets : DetectedTarget[0..*];
	}
	
	port def DisplayDataPort {
		in targets : DetectedTarget[0..*];
		in sectorStatus : ScanSector;
	}
	
	part def RadarUnit {
		attribute scanRate :> ISQ::frequency;
		attribute maxDetectionRange :> ISQ::length;
		attribute angularResolution : ScanAngle;
		attribute transmitPower :> ISQ::power;
		port dataOut : SensorDataPort;
		port controlIn : ControlCommandPort;
	}
	
	part def ElectroOpticalSensor {
		attribute fieldOfView : ScanSector;
		attribute imagingResolution : LengthValue;
		attribute sensitivity : Real;
		port dataOut : SensorDataPort;
		port controlIn : ControlCommandPort;
	}
	
	part def InfraredSensor {
		attribute thermalSensitivity : TemperatureValue;
		attribute detectionRange : LengthValue;
		port dataOut : SensorDataPort;
		port controlIn : ControlCommandPort;
	}
	
	part def FusionProcessor {
		attribute processingLatency :> ISQ::time;
		attribute fusionAlgorithmVersion : String;
		attribute minimumConfidence : ConfidenceScore;
		port radarIn : ~SensorDataPort;
		port eoIn : ~SensorDataPort;
		port irIn : ~SensorDataPort;
		port fusedDataOut : AlertOutputPort;
	}
	
	part def ScanCoordinator {
		attribute activeSector : ScanSector;
		attribute sectorDwellTime : TimeValue;
		attribute priorityTargetZones : ScanSector[0..*];
		port radarControl : ~ControlCommandPort;
		port eoControl : ~ControlCommandPort;
		port irControl : ~ControlCommandPort;
	}
	
	part def OperatorConsole {
		attribute displayRefreshRate :> ISQ::frequency;
		attribute maxDisplayedTargets : Integer;
		port alertIn : ~AlertOutputPort;
		port displayData : DisplayDataPort;
	}
	
	part def ThreatDatabase {
		attribute knownSignatures : TargetClassification[0..*];
		attribute updateFrequency : FrequencyValue;
	}
	
	action def InitializeScanSequence {
		in initialSector : ScanSector;
		in scanParameters : Real;
		out sequenceReady : Boolean;
	}
	
	action def ExecuteRadarScan {
		in sector : ScanSector;
		in transmitPower : PowerValue;
		out radarReading : SensorReading;
	}
	
	action def ExecuteEOScan {
		in sector : ScanSector;
		out eoReading : SensorReading;
	}
	
	action def ExecuteIRScan {
		in sector : ScanSector;
		out irReading : SensorReading;
	}
	
	action def PerformDataFusion {
		in radarData : SensorReading;
		in eoData : SensorReading;
		in irData : SensorReading;
		out fusedTargets : DetectedTarget[0..*];
	}
	
	action def ClassifyTargets {
		in detectedTargets : DetectedTarget[0..*];
		in signatureDatabase : TargetClassification[0..*];
		out classifiedTargets : DetectedTarget[0..*];
	}
	
	action def EvaluateThreatLevel {
		in classifiedTargets : DetectedTarget[0..*];
		out highThreatTargets : DetectedTarget[0..*];
		out mediumThreatTargets : DetectedTarget[0..*];
		out lowThreatTargets : DetectedTarget[0..*];
	}
	
	action def IssueAlert {
		in threateningTargets : DetectedTarget[0..*];
		out alertSignal : AlertSignal;
	}
	
	action def DetermineNextSector {
		in currentSector : ScanSector;
		in recentDetections : DetectedTarget[0..*];
		in priorityZones : ScanSector[0..*];
		out nextSector : ScanSector;
	}
	
	action def UpdateDisplay {
		in allTargets : DetectedTarget[0..*];
		in currentSector : ScanSector;
	}
	
	action def HorizonScanCycle {
		in inputSector : ScanSector;
		in powerLevel : PowerValue;
		in threatDB : TargetClassification[0..*];
		out detectedThreats : DetectedTarget[0..*];
		
		action initialize : InitializeScanSequence {
			in initialSector = inputSector;
			in scanParameters = 1.0;
			out sequenceReady : Boolean;
		}
		
		then decide;
			if initialize.sequenceReady then performScans;
			if not initialize.sequenceReady then done;
		
		action performScans {
			action radarScan : ExecuteRadarScan {
				in sector = inputSector;
				in transmitPower = powerLevel;
				out radarReading : SensorReading;
			}
			
			then action eoScan : ExecuteEOScan {
				in sector = inputSector;
				out eoReading : SensorReading;
			}
			
			then action irScan : ExecuteIRScan {
				in sector = inputSector;
				out irReading : SensorReading;
			}
			
			then action fusionStep : PerformDataFusion {
				in radarData = radarScan.radarReading;
				in eoData = eoScan.eoReading;
				in irData = irScan.irReading;
				out fusedTargets : DetectedTarget[0..*];
			}
			
			then action classifyStep : ClassifyTargets {
				in detectedTargets = fusionStep.fusedTargets;
				in signatureDatabase = threatDB;
				out classifiedTargets : DetectedTarget[0..*];
			}
			
			then action evaluateStep : EvaluateThreatLevel {
				in classifiedTargets = classifyStep.classifiedTargets;
				out highThreatTargets : DetectedTarget[0..*];
				out mediumThreatTargets : DetectedTarget[0..*];
				out lowThreatTargets : DetectedTarget[0..*];
			}
			
			then decide;
				if evaluateStep.highThreatTargets->size() > 0 then issueAlert;
				else updateDisplayOnly;
			
			action issueAlert : IssueAlert {
				in threateningTargets = evaluateStep.highThreatTargets;
				out alertSignal : AlertSignal;
			}
			then updateDisplayOnly;
			
			action updateDisplayOnly : UpdateDisplay {
				in allTargets = classifyStep.classifiedTargets;
				in currentSector = inputSector;
			}
		}
		
		then assign detectedThreats := performScans.classifyStep.classifiedTargets;
		then done;
	}
	
	action def ContinuousHorizonScanning {
		in coverageSectors : ScanSector[*];
		in systemPower : PowerValue;
		in database : TargetClassification[0..*];
		out allDetections : DetectedTarget[0..*] := ( );
		
		loop {
			for sector in coverageSectors {
				perform action scanCycle : HorizonScanCycle {
					in inputSector = sector;
					in powerLevel = systemPower;
					in threatDB = database;
					out detectedThreats : DetectedTarget[0..*];
				}
				then assign allDetections := allDetections->including(scanCycle.detectedThreats);
			}
		}
	}
	
	state def HorizonScanningStateMachine {
		entry; then standby;
		
		state standby {
			doc /* System is powered but not actively scanning */
		}
		
		transition standby_to_initializing
			first standby
			accept cmd : ScanCommand
			then initializing;
		
		state initializing {
			entry; then calibrating;
			
			state calibrating;
			transition calibrating_to_ready
				first calibrating
				then ready;
			
			state ready;
		}
		
		transition initializing_to_scanning
			first initializing
			then scanning;
		
		state scanning {
			entry; then activeScan;
			
			state activeScan {
				entry; then radarActive;
				
				state radarActive;
				transition radarActive_to_eoActive
					first radarActive
					then eoActive;
				
				state eoActive;
				transition eoActive_to_irActive
					first eoActive
					then irActive;
				
				state irActive;
				transition irActive_to_processing
					first irActive
					then processing;
				
				state processing;
				transition processing_to_radarActive
					first processing
					then radarActive;
			}
			
			state alertMode {
				doc /* High-priority threat detected, alert issued */
			}
			
			transition activeScan_to_alertMode
				first activeScan
				then alertMode;
			
			transition alertMode_to_activeScan
				first alertMode
				then activeScan;
		}
		
		transition scanning_to_standby
			first scanning
			then standby;
	}
	
	part def HorizonScanningSystem;
	
	part horizonScanner : HorizonScanningSystem {
		doc /* 
		The Horizon Scanning System continuously monitors a wide area of the surrounding 
		environment to detect, track, and classify objects of interest across the horizon. 
		Its primary function is to provide comprehensive situational awareness by systematically 
		scanning designated sectors using multiple complementary sensor modalities (radar, 
		electro-optical, and infrared), fusing the collected data to improve detection accuracy, 
		classifying detected targets against known threat signatures, evaluating threat levels, 
		and alerting operators to significant detections that require immediate attention or 
		tactical response. The system operates in a continuous cycle, adaptively prioritizing 
		scan sectors based on recent detections and predefined areas of interest.
		*/
		
		attribute coverageRange :> ISQ::length = 75000[SI::m];
		attribute azimuthCoverage : ScanAngle = 360.0;
		attribute elevationCoverage : ScanAngle = 60.0;
		attribute scanCycleTime :> ISQ::time = 5.0[SI::s];
		attribute systemRefreshRate :> ISQ::frequency = 0.2[SI::Hz];
		
		part radar : RadarUnit {
			attribute :>> scanRate = 12.0[SI::Hz];
			attribute :>> maxDetectionRange = 75000[SI::m];
			attribute :>> angularResolution = 0.5;
			attribute :>> transmitPower = 5000[SI::W];
		}
		
		part eoSensor : ElectroOpticalSensor {
			attribute :>> fieldOfView : ScanSector {
				attribute azimuthStart = -45.0;
				attribute azimuthEnd = 45.0;
				attribute elevationStart = -15.0;
				attribute elevationEnd = 45.0;
			}
			attribute :>> imagingResolution = 0.1[SI::m];
			attribute :>> sensitivity = 0.98;
		}
		
		part irSensor : InfraredSensor {
			attribute :>> thermalSensitivity = 0.05[SI::K];
			attribute :>> detectionRange = 25000[SI::m];
		}
		
		part fusionProcessor : FusionProcessor {
			attribute :>> processingLatency = 0.15[SI::s];
			attribute :>> fusionAlgorithmVersion = "v3.2.1";
			attribute :>> minimumConfidence = 0.70;
		}
		
		part coordinator : ScanCoordinator {
			attribute :>> activeSector : ScanSector {
				attribute azimuthStart = 0.0;
				attribute azimuthEnd = 30.0;
				attribute elevationStart = 0.0;
				attribute elevationEnd = 30.0;
			}
			attribute :>> sectorDwellTime = 2.0[SI::s];
		}
		
		part console : OperatorConsole {
			attribute :>> displayRefreshRate = 1.0[SI::Hz];
			attribute :>> maxDisplayedTargets = 100;
		}
		
		part threatDB : ThreatDatabase {
			attribute :>> updateFrequency = 0.001[SI::Hz];
		}
		
		connection radarToFusion connect radar.dataOut to fusionProcessor.radarIn;
		connection eoToFusion connect eoSensor.dataOut to fusionProcessor.eoIn;
		connection irToFusion connect irSensor.dataOut to fusionProcessor.irIn;
		connection fusionToConsole connect fusionProcessor.fusedDataOut to console.alertIn;
		connection coordinatorToRadar connect coordinator.radarControl to radar.controlIn;
		connection coordinatorToEO connect coordinator.eoControl to eoSensor.controlIn;
		connection coordinatorToIR connect coordinator.irControl to irSensor.controlIn;
		
		perform action continuousScanning : ContinuousHorizonScanning;
		exhibit state scanningBehavior : HorizonScanningStateMachine;
	}
	
	requirement <'HSS-REQ-001'> continuousCoverageRequirement {
		doc /* 
		The system shall provide continuous 360-degree azimuthal coverage of the horizon 
		with a complete scan cycle time not exceeding 10 seconds to ensure timely detection 
		of emerging threats and objects of interest.
		*/
		
		subject horizonScanner;
		require constraint { horizonScanner.scanCycleTime <= 10.0[SI::s] }
		require constraint { horizonScanner.azimuthCoverage >= 360.0 }
	}
	
	requirement <'HSS-REQ-002'> detectionRangeRequirement {
		doc /* 
		The system shall detect targets at ranges up to 75 kilometers to provide 
		sufficient early warning time for threat assessment and response planning.
		*/
		
		subject horizonScanner;
		require constraint { horizonScanner.coverageRange >= 75000[SI::m] }
	}
	
	requirement <'HSS-REQ-003'> multiSensorFusionRequirement {
		doc /* 
		The system shall fuse data from at least three independent sensor modalities 
		(radar, electro-optical, infrared) to enhance detection confidence, reduce 
		false alarm rates, and improve target classification accuracy.
		*/
		
		subject horizonScanner;
		require constraint { horizonScanner.fusionProcessor.minimumConfidence >= 0.65 }
	}
	
	requirement <'HSS-REQ-004'> processingLatencyRequirement {
		doc /* 
		The system shall complete sensor data fusion and threat evaluation within 
		500 milliseconds of sensor data acquisition to enable rapid alert generation 
		and operator response.
		*/
		
		subject horizonScanner;
		require constraint { horizonScanner.fusionProcessor.processingLatency <= 0.5[SI::s] }
	}
	
	requirement <'HSS-REQ-005'> elevationCoverageRequirement {
		doc /* 
		The system shall provide elevation coverage from -15 degrees to +60 degrees 
		to detect both surface-level and elevated threats including aerial targets.
		*/
		
		subject horizonScanner;
		require constraint { horizonScanner.elevationCoverage >= 60.0 }
	}
	
	requirement systemLevelRequirements {
		doc /* 
		Top-level requirements for the Horizon Scanning System encompassing operational 
		performance, detection capability, sensor fusion, processing latency, and coverage.
		*/
		
		require continuousCoverageRequirement;
		require detectionRangeRequirement;
		require multiSensorFusionRequirement;
		require processingLatencyRequirement;
		require elevationCoverageRequirement;
	}
}
