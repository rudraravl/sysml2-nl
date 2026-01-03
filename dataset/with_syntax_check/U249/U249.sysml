package 'Humphrey Visual Field Analyzer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID;
	attribute def TestProtocol;
	attribute def ReliabilityIndex;
	
	attribute def LuminanceValue {
		attribute magnitude : Real;
		attribute unit : LuminanceUnit;
	}
	
	attribute def EccentricityValue {
		attribute magnitude : Real;
		attribute unit : AngleUnit;
	}
	
	attribute def MeridianValue {
		attribute magnitude : Real;
		attribute unit : AngleUnit;
	}
	
	enum def FixationStatus {
		stable;
		unstable;
		lost;
	}
	
	enum def ResponseType {
		detected;
		notDetected;
		falsePositive;
		falseNegative;
	}
	
	item def StimulusLocation {
		attribute eccentricity : EccentricityValue;
		attribute meridian : MeridianValue;
	}
	
	item def StimulusCommand {
		attribute location : StimulusLocation;
		attribute intensity : LuminanceValue;
		attribute duration : ISQ::TimeValue;
	}
	
	item def PatientResponse {
		attribute responseType : ResponseType;
		attribute reactionTime : ISQ::TimeValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def FixationData {
		attribute status : FixationStatus;
		attribute gazeDeviation : EccentricityValue;
	}
	
	item def TestPoint {
		attribute location : StimulusLocation;
		attribute thresholdIntensity : LuminanceValue;
		attribute sensitivity : Real;
		attribute responseHistory : ResponseType[*];
	}
	
	item def VisualFieldMap {
		attribute testPoints : TestPoint[*];
		attribute meanDeviation : Real;
		attribute patternStandardDeviation : Real;
		attribute visualFieldIndex : Real;
		attribute reliabilityIndices : ReliabilityIndex[*];
	}
	
	port def StimulusPort {
		out item stimulusCmd : StimulusCommand;
	}
	
	port def ResponsePort {
		in item patientResp : PatientResponse;
	}
	
	port def FixationPort {
		in item fixationData : FixationData;
	}
	
	port def DataPort {
		out item testResults : VisualFieldMap;
		in item testConfig : TestProtocol;
	}
	
	part def OpticalProjectionSystem {
		port stimulusOutput : StimulusPort;
		attribute currentIntensity : LuminanceValue;
		attribute projectionPosition : StimulusLocation;
		
		action def ProjectLightStimulus {
			in stimCmd : StimulusCommand;
			out projectionComplete : Boolean;
		}
	}
	
	part def FixationMonitoringSystem {
		port fixationOutput : FixationPort;
		attribute fixationLossCount : Integer;
		attribute totalFixationChecks : Integer;
		
		action def TrackGazePosition {
			out gazeData : FixationData;
		}
		
		action def VerifyFixation {
			in gazeData : FixationData;
			out isFixating : Boolean;
		}
	}
	
	part def PatientResponseInterface {
		port responseInput : ResponsePort;
		attribute falsePositiveCount : Integer;
		attribute falseNegativeCount : Integer;
		
		action def CaptureButtonPress {
			out response : PatientResponse;
		}
		
		action def ValidateResponse {
			in response : PatientResponse;
			in expectedStimulus : Boolean;
			out validatedResponse : ResponseType;
		}
	}
	
	part def TestControlProcessor {
		port dataInterface : DataPort;
		port stimulusControl : StimulusPort;
		port responseMonitor : ResponsePort;
		port fixationMonitor : FixationPort;
		
		attribute testSequence : StimulusCommand[*];
		attribute currentTestIndex : Integer;
		attribute accumulatedResults : TestPoint[*];
		
		action def InitializeTestPattern {
			in protocol : TestProtocol;
			out testSequence : StimulusCommand[*];
		}
		
		action def CalculateThreshold {
			in location : StimulusLocation;
			in responseHistory : ResponseType[*];
			out thresholdIntensity : LuminanceValue;
		}
		
		action def ComputeVisualFieldIndices {
			in testPoints : TestPoint[*];
			out fieldMap : VisualFieldMap;
		}
		
		action def AssessReliability {
			in fixationLosses : Integer;
			in falsePositives : Integer;
			in falseNegatives : Integer;
			out reliabilityScore : Real;
		}
	}
	
	part def ResultsDisplaySystem {
		attribute displayedMap : VisualFieldMap;
		
		action def RenderGrayscaleMap {
			in fieldData : VisualFieldMap;
			out grayscaleImage : String;
		}
		
		action def GenerateNumericReport {
			in fieldData : VisualFieldMap;
			out reportDocument : String;
		}
	}
	
	part def HumphreyVisualFieldAnalyzer {
		part opticalSystem : OpticalProjectionSystem;
		part fixationSystem : FixationMonitoringSystem;
		part responseInterface : PatientResponseInterface;
		part controlProcessor : TestControlProcessor;
		part displaySystem : ResultsDisplaySystem;
		
		connection stimulusPath connect 
			controlProcessor.stimulusControl to opticalSystem.stimulusOutput;
		
		connection responsePath connect 
			responseInterface.responseInput to controlProcessor.responseMonitor;
		
		connection fixationPath connect 
			fixationSystem.fixationOutput to controlProcessor.fixationMonitor;
		
		perform action executeVisualFieldAssessment[*] ordered 
			references conductThresholdTest;
	}
	
	action def PresentStimulusAtLocation {
		in stimulusCmd : StimulusCommand;
		out presented : Boolean;
		out presentationTime : ISQ::TimeValue;
	}
	
	action def WaitForPatientResponse {
		in timeout : ISQ::TimeValue;
		out responseReceived : Boolean;
		out response : PatientResponse;
	}
	
	action def UpdateThresholdEstimate {
		in currentEstimate : LuminanceValue;
		in responseDetected : Boolean;
		out newEstimate : LuminanceValue;
	}
	
	action def RecordTestPointData {
		in location : StimulusLocation;
		in finalThreshold : LuminanceValue;
		in responses : ResponseType[*];
		out testPoint : TestPoint;
	}
	
	action def VerifyPatientFixation {
		out fixationValid : Boolean;
		out fixationData : FixationData;
	}
	
	action def AnalyzeFieldData {
		in completedPoints : TestPoint[*];
		out visualFieldMap : VisualFieldMap;
	}
	
	action def DisplayResults {
		in fieldMap : VisualFieldMap;
		out displayComplete : Boolean;
	}
	
	action def InitializeTest {
		in protocol : TestProtocol;
		out testLocations : StimulusLocation[*];
		out initialIntensity : LuminanceValue;
	}
	
	action def ExecuteThresholdTest {
		in patientID : PatientID;
		in testProtocol : TestProtocol;
		out finalVisualFieldMap : VisualFieldMap;
		out testCompleted : Boolean;
	}
	
	action conductThresholdTest : ExecuteThresholdTest {
		in patientID : PatientID;
		in testProtocol : TestProtocol;
		out finalVisualFieldMap : VisualFieldMap;
		out testCompleted : Boolean;
		
		first start;
		
		then action initialize : InitializeTest {
			in protocol = conductThresholdTest::testProtocol;
			out testLocations : StimulusLocation[*];
			out initialIntensity : LuminanceValue;
		}
		
		then merge testLoop;
		
		private attribute locationIndex : Integer := 0;
		private attribute collectedTestPoints : TestPoint[*] := ();
		private attribute currentLocation : StimulusLocation;
		private attribute currentIntensity : LuminanceValue;
		private attribute responseSequence : ResponseType[*] := ();
		private attribute thresholdFound : Boolean := false;
		
		then decide;
			if locationIndex < 54 then processNextLocation;
			if locationIndex >= 54 then finalizeTest;
		
		action processNextLocation {
			action selectLocation {
				assign currentLocation := initialize.testLocations#(locationIndex);
				assign currentIntensity := initialize.initialIntensity;
				assign responseSequence := ();
				assign thresholdFound := false;
			}
			
			then merge thresholdLoop;
			
			then decide;
				if !thresholdFound then continueThresholding;
				if thresholdFound then recordPoint;
			
			action continueThresholding {
				action checkFixation : VerifyPatientFixation {
					out fixationValid;
					out fixationData;
				}
				
				then decide;
					if checkFixation.fixationValid then presentStimulus;
					if !checkFixation.fixationValid then retryFixation;
				
				action presentStimulus {
					action present : PresentStimulusAtLocation {
						in stimulusCmd;
						out presented;
						out presentationTime;
					}
					
					then action waitResponse : WaitForPatientResponse {
						in timeout;
						out responseReceived;
						out response;
					}
					
					then action updateEstimate : UpdateThresholdEstimate {
						in currentEstimate = currentIntensity;
						in responseDetected = waitResponse.responseReceived;
						out newEstimate;
					}
					
					then action recordResponse {
						assign currentIntensity := updateEstimate.newEstimate;
					}
					
					then decide;
						if true then markThresholdFound;
						else thresholdLoop;
					
					action markThresholdFound {
						assign thresholdFound := true;
					}
				}
				
				action retryFixation {
					then thresholdLoop;
				}
			}
			
			action recordPoint {
				action record : RecordTestPointData {
					in location = currentLocation;
					in finalThreshold = currentIntensity;
					in responses = responseSequence;
					out testPoint;
				}
				
				then action updateCollection {
					assign collectedTestPoints := collectedTestPoints->including(record.testPoint);
					assign locationIndex := locationIndex + 1;
				}
			}
			
			then testLoop;
		}
		
		action finalizeTest {
			action analyze : AnalyzeFieldData {
				in completedPoints = collectedTestPoints;
				out visualFieldMap;
			}
			
			then action display : DisplayResults {
				in fieldMap = analyze.visualFieldMap;
				out displayComplete;
			}
			
			then action complete {
				assign finalVisualFieldMap := analyze.visualFieldMap;
				assign testCompleted := true;
			}
		}
		
		then done;
	}
	
	requirement def AccuracyRequirement {
		doc /* The system shall measure visual field sensitivity thresholds 
		       with accuracy within 2 dB across all tested locations. */
	}
	
	requirement def ReliabilityRequirement {
		doc /* The system shall monitor and report test reliability through 
		       fixation loss rate, false positive rate, and false negative rate. */
	}
	
	requirement def TestDurationRequirement {
		doc /* A standard 24-2 threshold test shall complete within 6 minutes 
		       for a cooperative patient with normal visual fields. */
	}
	
	requirement def FixationMonitoringRequirement {
		doc /* The system shall continuously monitor patient fixation throughout 
		       the test with fixation loss detection accuracy greater than 95%. */
	}
	
	requirement <'HVF-SYS-001'> primaryFunctionRequirement {
		doc /* The Humphrey Visual Field Analyzer shall systematically assess 
		       the patient's visual field sensitivity by presenting calibrated 
		       light stimuli at predetermined retinal locations, monitoring patient 
		       fixation stability, recording detection responses, and generating 
		       a comprehensive visual field sensitivity map with statistical indices 
		       for clinical interpretation of visual field defects. */
		
		subject analyzer : HumphreyVisualFieldAnalyzer;
		
		require accuracyReq : AccuracyRequirement;
		require reliabilityReq : ReliabilityRequirement;
		require durationReq : TestDurationRequirement;
		require fixationReq : FixationMonitoringRequirement;
	}
}
