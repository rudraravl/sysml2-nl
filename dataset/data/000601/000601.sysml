package EsthesiometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def StimulusIntensity :> Real;
    attribute def SensoryThreshold :> ForceValue;
    attribute def SpatialResolution :> LengthValue;
    
    attribute def TestParameters {
        attribute initialForce : ForceValue;
        attribute forceIncrement : ForceValue;
        attribute maxForce : ForceValue;
        attribute probeSpacing : LengthValue;
        attribute testSite : String;
    }
    
    attribute def TestResults {
        attribute detectedThreshold : ForceValue;
        attribute twoPointDiscrimination : LengthValue;
        attribute testTimestamp : String;
        attribute testLocation : String;
    }

    attribute def StartupComplete;
    attribute def BeginTest;
    attribute def AcknowledgeResults;
    attribute def ResetSystem;
    attribute def ClearError;

    port def StimulusApplicationPort {
        out appliedForce : ForceValue;
        out probePosition : LengthValue;
    }
    
    port def ResponseInputPort {
        in patientResponse : Boolean;
        in responseTime : TimeValue;
    }
    
    port def DataOutputPort {
        out testData : TestResults;
    }
    
    port def ControlInputPort {
        in testCommand : String;
        in parameters : TestParameters;
    }

    part def ProbeHead {
        doc /* Mechanical probe assembly that applies controlled tactile stimuli to skin surface */
        
        attribute numberOfProbes : Integer;
        attribute probeSpacing : LengthValue;
        attribute currentForce : ForceValue;
        
        port stimulusOut : StimulusApplicationPort;
        
        part probe1 : TactileProbe {
            attribute tipDiameter : LengthValue = 0.5 [mm];
            attribute material : String = "stainless steel";
        }
        
        part probe2 : TactileProbe {
            attribute tipDiameter : LengthValue = 0.5 [mm];
            attribute material : String = "stainless steel";
        }
        
        part spacingAdjuster : SpacingMechanism {
            in targetSpacing : LengthValue;
            out actualSpacing : LengthValue;
            attribute minSpacing : LengthValue = 1.0 [mm];
            attribute maxSpacing : LengthValue = 50.0 [mm];
            attribute adjustmentResolution : LengthValue = 0.1 [mm];
        }
        
        part forceApplicator : ForceRegulator {
            in targetForce : ForceValue;
            out measuredForce : ForceValue;
            attribute minForce : ForceValue = 0.01 [N];
            attribute maxForce : ForceValue = 5.0 [N];
            attribute forceAccuracy : Real = 0.02;
        }
    }
    
    part def TactileProbe {
        attribute tipDiameter : LengthValue;
        attribute material : String;
        attribute position : LengthValue;
    }
    
    part def SpacingMechanism {
        in targetSpacing : LengthValue;
        out actualSpacing : LengthValue;
        attribute minSpacing : LengthValue;
        attribute maxSpacing : LengthValue;
        attribute adjustmentResolution : LengthValue;
    }
    
    part def ForceRegulator {
        in targetForce : ForceValue;
        out measuredForce : ForceValue;
        attribute minForce : ForceValue;
        attribute maxForce : ForceValue;
        attribute forceAccuracy : Real;
    }

    part def PatientInterface {
        doc /* Interface for capturing patient sensory responses during testing */
        
        port responseOut : ResponseInputPort;
        
        part responseButton : InputButton {
            out buttonState : Boolean;
        }
        
        part audioIndicator : AudioFeedback {
            in signalTone : Boolean;
            out toneActive : Boolean;
        }
        
        part visualCue : VisualIndicator {
            in displayState : String;
        }
    }
    
    part def InputButton {
        out buttonState : Boolean;
    }
    
    part def AudioFeedback {
        in signalTone : Boolean;
        out toneActive : Boolean;
    }
    
    part def VisualIndicator {
        in displayState : String;
    }

    part def DataProcessor {
        doc /* Processes test responses and calculates sensory thresholds */
        
        in responseData : Boolean;
        in stimulusLevel : ForceValue;
        in spacingValue : LengthValue;
        out results : TestResults;
        
        attribute testProtocol : String;
        attribute thresholdAlgorithm : String;
        
        part calculator : ThresholdCalculator {
            in responses : Boolean[*];
            in stimuli : ForceValue[*];
            out threshold : ForceValue;
        }
        
        part dataLogger : DataRecorder {
            in testData : TestResults;
            out logStatus : Boolean;
        }
    }
    
    part def ThresholdCalculator {
        in responses : Boolean[*];
        in stimuli : ForceValue[*];
        out threshold : ForceValue;
    }
    
    part def DataRecorder {
        in testData : TestResults;
        out logStatus : Boolean;
    }

    part def DisplayModule {
        doc /* Displays test progress, results, and system status */
        
        port dataIn : DataOutputPort;
        
        attribute displayType : String = "LCD";
        attribute resolution : String = "1024x768";
        
        part screen : DisplayScreen {
            in content : String;
        }
        
        part statusIndicator : StatusLight {
            in systemState : String;
        }
    }
    
    part def DisplayScreen {
        in content : String;
    }
    
    part def StatusLight {
        in systemState : String;
    }

    part def ControlModule {
        doc /* Manages test sequences and coordinates system components */
        
        port controlOut : ControlInputPort;
        
        attribute operatingMode : String;
        attribute testSequenceType : String;
        
        part sequencer : TestSequencer {
            in protocol : String;
            out nextStimulus : ForceValue;
        }
        
        part coordinator : SystemCoordinator {
            in systemStatus : String;
            out controlSignal : String;
        }
    }
    
    part def TestSequencer {
        in protocol : String;
        out nextStimulus : ForceValue;
    }
    
    part def SystemCoordinator {
        in systemStatus : String;
        out controlSignal : String;
    }

    action def PerformSensoryAssessment {
        doc /* Conducts tactile sensitivity assessment by applying incremental stimuli */
        
        in testSite : String;
        in startForce : ForceValue;
        in incrementForce : ForceValue;
        in maximumForce : ForceValue;
        out assessmentResult : TestResults;
        
        private attribute currentForce : ForceValue;
        private attribute thresholdDetected : Boolean := false;
        private attribute detectedLevel : ForceValue := 0.0 [N];
        
        first start;
        then action initializeSystem : InitializeSystem {
            in site = testSite;
            out systemReady : Boolean;
        }
        then action calibrateProbes : CalibrateProbes {
            in calibrationForce : ForceValue = 1.0 [N];
            out calibrationComplete : Boolean;
        }
        then assign currentForce := startForce;
        then merge testLoop;
        
        action testLoop {
            action applyStimulus : ApplyStimulus {
                in force = currentForce;
                in duration : TimeValue = 2.0 [s];
                out stimulusApplied : Boolean;
            }
            then action waitForResponse : WaitForResponse {
                in timeout : TimeValue = 5.0 [s];
                out responseReceived : Boolean;
                out responseTime : TimeValue;
            }
            then action recordData : RecordData {
                in stimulusForce = currentForce;
                in response = waitForResponse.responseReceived;
                out dataRecorded : Boolean;
            }
            then decide;
                if waitForResponse.responseReceived and !thresholdDetected then markThreshold;
                else checkContinue;
            
            action markThreshold {
                assign detectedLevel := currentForce;
                assign thresholdDetected := true;
            }
            then checkContinue;
            
            action checkContinue {
                decide;
                    if currentForce < maximumForce then incrementStimulus;
                    else finalizeTest;
            }
            
            action incrementStimulus {
                assign currentForce := currentForce + incrementForce;
            }
            then testLoop;
        }
        
        action finalizeTest : FinalizeTest {
            in detectedThreshold = detectedLevel;
            in testLocation = testSite;
            out finalResults : TestResults;
        }
        then assign assessmentResult := finalizeTest.finalResults;
        then done;
    }
    
    action def InitializeSystem {
        in site : String;
        out systemReady : Boolean;
    }
    
    action def CalibrateProbes {
        in calibrationForce : ForceValue;
        out calibrationComplete : Boolean;
    }
    
    action def ApplyStimulus {
        in force : ForceValue;
        in duration : TimeValue;
        out stimulusApplied : Boolean;
    }
    
    action def WaitForResponse {
        in timeout : TimeValue;
        out responseReceived : Boolean;
        out responseTime : TimeValue;
    }
    
    action def RecordData {
        in stimulusForce : ForceValue;
        in response : Boolean;
        out dataRecorded : Boolean;
    }
    
    action def FinalizeTest {
        in detectedThreshold : ForceValue;
        in testLocation : String;
        out finalResults : TestResults;
    }

    state def SystemOperationalStates {
        doc /* State machine governing esthesiometer operational modes */
        
        entry; then powerOn;
        
        state powerOn {
            entry action initializePower;
        }
        transition powerOn_to_selfTest
            first powerOn
            accept StartupComplete
            then selfTest;
        
        state selfTest {
            do action performSelfTest;
            attribute selfTestPassed : Boolean;
        }
        transition selfTest_to_calibration
            first selfTest
            if selfTest.selfTestPassed
            then calibration;
        transition selfTest_to_error
            first selfTest
            if !selfTest.selfTestPassed
            then error;
        
        state calibration {
            do action calibrateSystem;
            attribute calibrationSuccessful : Boolean;
        }
        transition calibration_to_ready
            first calibration
            if calibration.calibrationSuccessful
            then ready;
        
        state ready {
            entry action displayReadyStatus;
        }
        transition ready_to_testing
            first ready
            accept BeginTest
            then testing;
        
        state testing {
            do action executeTest : PerformSensoryAssessment;
            attribute testCompleted : Boolean;
        }
        transition testing_to_analyzing
            first testing
            if testing.testCompleted
            then analyzing;
        
        state analyzing {
            do action analyzeTestData;
            attribute analysisComplete : Boolean;
        }
        transition analyzing_to_displaying
            first analyzing
            if analyzing.analysisComplete
            then displaying;
        
        state displaying {
            entry action presentResults;
        }
        transition displaying_to_ready
            first displaying
            accept AcknowledgeResults
            then ready;
        transition displaying_to_powerOn
            first displaying
            accept ResetSystem
            then powerOn;
        
        state error {
            entry action displayError;
        }
        transition error_to_powerOn
            first error
            accept ClearError
            then powerOn;
    }

    part esthesiometerDevice : EsthesiometerDevice {
        doc /* Complete esthesiometer system for quantitative assessment of tactile sensitivity and spatial discrimination */
        
        attribute deviceIdentifier : String = "ESTH-2024-001";
        attribute firmwareVersion : String = "2.1.0";
        attribute calibrationDate : String;
        
        part probeAssembly : ProbeHead {
            attribute numberOfProbes = 2;
            attribute probeSpacing = 5.0 [mm];
            attribute currentForce = 0.0 [N];
        }
        
        part patientInput : PatientInterface;
        
        part processor : DataProcessor {
            attribute testProtocol = "ascending-method-of-limits";
            attribute thresholdAlgorithm = "staircase";
        }
        
        part display : DisplayModule {
            attribute displayType = "LCD";
            attribute resolution = "1024x768";
        }
        
        part controller : ControlModule {
            attribute operatingMode = "manual";
            attribute testSequenceType = "threshold-detection";
        }
        
        connection probeToProcessor : StimulusDataFlow
            connect probeAssembly.stimulusOut to processor;
        
        connection patientToProcessor : ResponseDataFlow
            connect patientInput.responseOut to processor;
        
        connection processorToDisplay : ResultDataFlow
            connect processor to display.dataIn;
        
        connection controllerToProbe : ControlSignalFlow
            connect controller.controlOut to probeAssembly;
        
        perform action conductAssessment : PerformSensoryAssessment {
            in testSite = "index fingertip";
            in startForce = 0.05 [N];
            in incrementForce = 0.05 [N];
            in maximumForce = 3.0 [N];
            out assessmentResult;
        }
        
        exhibit state systemStateMachine : SystemOperationalStates;
    }
    
    part def EsthesiometerDevice;
    
    connection def StimulusDataFlow;
    connection def ResponseDataFlow;
    connection def ResultDataFlow;
    connection def ControlSignalFlow;

    requirement def ThresholdAccuracyRequirement {
        doc /* System shall measure tactile sensitivity thresholds with high accuracy */
        
        subject device : EsthesiometerDevice;
        
        require constraint accuracyConstraint {
            device.probeAssembly.forceApplicator.forceAccuracy <= 0.05
        }
    }
    
    requirement def SpatialResolutionRequirement {
        doc /* System shall provide fine spatial resolution for two-point discrimination testing */
        
        subject device : EsthesiometerDevice;
        
        require constraint resolutionConstraint {
            device.probeAssembly.spacingAdjuster.adjustmentResolution <= 0.2 [mm]
        }
    }
    
    requirement def ForceRangeRequirement {
        doc /* System shall operate across physiologically relevant force range */
        
        subject device : EsthesiometerDevice;
        
        require constraint forceRangeConstraint {
            device.probeAssembly.forceApplicator.minForce >= 0.01 [N] and
            device.probeAssembly.forceApplicator.maxForce <= 5.0 [N]
        }
    }
    
    requirement def SafetyRequirement {
        doc /* System shall not apply excessive force that could cause tissue damage */
        
        subject device : EsthesiometerDevice;
        
        require constraint safetyConstraint {
            device.probeAssembly.currentForce <= 5.0 [N]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for esthesiometer system functionality and safety */
        
        require thresholdAccuracyReq : ThresholdAccuracyRequirement;
        require spatialResolutionReq : SpatialResolutionRequirement;
        require forceRangeReq : ForceRangeRequirement;
        require safetyReq : SafetyRequirement;
    }
}
