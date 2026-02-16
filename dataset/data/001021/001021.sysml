package 'Defect Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DefectSeverity :> Real;
	attribute def ConfidenceScore :> Real;
	
	item def InspectionImage {
		attribute captureTime : TimeValue;
		attribute resolution : Integer[2];
		attribute exposureLevel : Real;
	}
	
	item def DefectData {
		attribute defectType : String;
		attribute severity : DefectSeverity;
		attribute position : LengthValue[2];
		attribute confidence : ConfidenceScore;
		attribute timestamp : TimeValue;
	}
	
	item def InspectionReport {
		attribute inspectionId : String;
		attribute detectedDefects : DefectData[*];
		attribute totalDefects : Integer;
		attribute passFailStatus : Boolean;
		attribute completionTime : TimeValue;
	}
	
	port def ImageInputPort {
		in item image : InspectionImage;
	}
	
	port def DataOutputPort {
		out item defects : DefectData[*];
	}
	
	port def ReportOutputPort {
		out item report : InspectionReport;
	}
	
	port def ControlPort {
		in attribute startInspection : Boolean;
		out attribute systemReady : Boolean;
	}
	
	part def ImagingSubsystem {
		port imageOut : DataOutputPort;
		port control : ControlPort;
		
		attribute captureResolution : Integer[2];
		attribute frameRate : FrequencyValue;
		
		action def CaptureImage {
			out capturedImage : InspectionImage;
		}
		
		action def AdjustLighting {
			in currentExposure : Real;
			out optimalExposure : Real;
		}
		
		perform action imagingSequence {
			first start;
			then action adjustLight : AdjustLighting;
			then action capture : CaptureImage;
			then done;
		}
	}
	
	part def ProcessingSubsystem {
		port imageIn : ImageInputPort;
		port defectOut : DataOutputPort;
		
		attribute processingPower : PowerValue;
		attribute algorithmVersion : String;
		
		action def PreprocessImage {
			in rawImage : InspectionImage;
			out processedImage : InspectionImage;
		}
		
		action def DetectDefects {
			in image : InspectionImage;
			out detectedDefects : DefectData[*];
		}
		
		action def ClassifyDefect {
			in defect : DefectData;
			out classifiedDefect : DefectData;
		}
		
		perform action defectDetectionPipeline {
			first start;
			then action preprocess : PreprocessImage;
			then action detect : DetectDefects {
				in image = preprocess.processedImage;
			}
			then action classify : ClassifyDefect[*];
			then done;
		}
	}
	
	part def ReportingSubsystem {
		port defectIn : DataOutputPort;
		port reportOut : ReportOutputPort;
		
		attribute reportFormat : String;
		attribute storageCapacity : Integer;
		
		action def AggregateDefects {
			in defects : DefectData[*];
			out summary : InspectionReport;
		}
		
		action def DeterminePassFail {
			in defectCount : Integer;
			in maxAllowedDefects : Integer;
			out status : Boolean;
		}
		
		action def GenerateReport {
			in defects : DefectData[*];
			out report : InspectionReport;
		}
		
		perform action reportGeneration {
			first start;
			then action aggregate : AggregateDefects;
			then action evaluate : DeterminePassFail;
			then action generate : GenerateReport;
			then done;
		}
	}
	
	part def AlertSubsystem {
		port reportIn : ReportOutputPort;
		
		attribute alertThreshold : DefectSeverity;
		attribute notificationEnabled : Boolean;
		
		action def EvaluateAlert {
			in report : InspectionReport;
			out alertRequired : Boolean;
		}
		
		action def IssueAlert {
			in report : InspectionReport;
		}
		
		perform action alertManagement {
			first start;
			then merge monitoring;
			then action evaluate : EvaluateAlert;
			then decide;
				if evaluate.alertRequired then issue;
				if not evaluate.alertRequired then monitoring;
			action issue : IssueAlert;
			then monitoring;
		}
	}
	
	part defectDetectorSystem : DefectDetectorSystem {
		doc /* 
		The defect detector system is an automated quality inspection system that identifies 
		and classifies defects in manufactured products or materials. Its primary function is 
		to capture high-resolution images of items under inspection, process those images using 
		advanced detection algorithms to identify defects, classify the severity and type of 
		each defect, generate comprehensive inspection reports, and issue alerts when critical 
		defects are detected. This enables real-time quality control, reduces manual inspection 
		effort, and ensures consistent product quality standards.
		*/
		
		part imaging : ImagingSubsystem {
			perform action imageCapture[*] ordered references imagingSequence;
		}
		
		part processing : ProcessingSubsystem {
			perform action defectAnalysis[*] ordered references defectDetectionPipeline;
		}
		
		part reporting : ReportingSubsystem {
			perform action reportCreation[*] ordered references reportGeneration;
		}
		
		part alerting : AlertSubsystem {
			perform action alertProcessing[*] ordered references alertManagement;
		}
		
		connection imagingToProcessing connect imaging.imageOut to processing.imageIn;
		connection processingToReporting connect processing.defectOut to reporting.defectIn;
		connection reportingToAlerting connect reporting.reportOut to alerting.reportIn;
	}
	
	action def InspectProduct {
		in productId : String;
		in qualityThreshold : DefectSeverity;
		out inspectionReport : InspectionReport;
		
		first start;
		then merge inspectionCycle;
		
		then action captureProductImage {
			out productImage : InspectionImage;
		}
		
		then action preprocessImage {
			in rawImage : InspectionImage = captureProductImage.productImage;
			out cleanedImage : InspectionImage;
		}
		
		then action analyzeForDefects {
			in image : InspectionImage = preprocessImage.cleanedImage;
			out foundDefects : DefectData[*];
		}
		
		then decide;
			if analyzeForDefects.foundDefects->size() > 0 then classifyAndReport;
			if analyzeForDefects.foundDefects->size() == 0 then generateCleanReport;
		
		action classifyAndReport {
			in defects : DefectData[*] = analyzeForDefects.foundDefects;
			out report : InspectionReport;
		}
		then evaluateForAlert;
		
		action generateCleanReport {
			out report : InspectionReport;
		}
		then inspectionCycle;
		
		action evaluateForAlert {
			in report : InspectionReport = classifyAndReport.report;
		}
		then inspectionCycle;
	}
	
	requirement def DetectionAccuracyRequirement {
		doc /* The defect detector shall achieve minimum detection accuracy for specified defect types and sizes. */
		
		attribute minimumAccuracy : Real;
		attribute minimumDefectSize : LengthValue;
		
		require constraint accuracyConstraint {
			minimumAccuracy >= 0.98
		}
	}
	
	requirement def ProcessingSpeedRequirement {
		doc /* The system shall complete inspection and report generation within specified time limit. */
		
		attribute maxProcessingTime : TimeValue;
		
		require constraint speedConstraint {
			maxProcessingTime <= 1.5 [SI::s]
		}
	}
	
	requirement def FalseAlarmRequirement {
		doc /* The false positive detection rate shall not exceed specified threshold. */
		
		attribute maxFalsePositiveRate : Real;
		
		require constraint falseAlarmConstraint {
			maxFalsePositiveRate <= 0.03
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The system shall maintain operational availability during production hours. */
		
		attribute minimumUptime : Real;
		
		require constraint reliabilityConstraint {
			minimumUptime >= 0.995
		}
	}
	
	requirement <'SYS-REQ-001'> primarySystemRequirements {
		doc /* The defect detector system shall automatically inspect products, detect and classify defects with high accuracy, generate detailed reports, and alert operators to critical quality issues in real-time. */
		
		subject defectDetectorSystem;
		
		require detectionAccuracy : DetectionAccuracyRequirement {
			attribute :>> minimumAccuracy = 0.98;
			attribute :>> minimumDefectSize = 0.3 [SI::mm];
		}
		
		require processingSpeed : ProcessingSpeedRequirement {
			attribute :>> maxProcessingTime = 1.5 [SI::s];
		}
		
		require falseAlarmRate : FalseAlarmRequirement {
			attribute :>> maxFalsePositiveRate = 0.03;
		}
		
		require systemReliability : ReliabilityRequirement {
			attribute :>> minimumUptime = 0.995;
		}
	}
	
	part def DefectDetectorSystem {
		satisfy primarySystemRequirements;
	}
}
