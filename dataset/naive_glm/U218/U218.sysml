package EsthesiometerSystem {
    import ScalarValues::*;
    
    package Units {
        unit newton;
        unit millimeter;
        unit second;
        unit millisecond;
    }
    
    value type ForceValue :> Real {
        :>> unit = Units::newton;
        attribute : lowerBound : ForceValue = 0.01;
        attribute : upperBound : ForceValue = 5.0;
    }
    
    value type SpacingValue :> Real {
        :>> unit = Units::millimeter;
        attribute : lowerBound : SpacingValue = 1;
        attribute : upperBound : SpacingValue = 50;
    }
    
    value type TimeStampValue :> Real {
        :>> unit = Units::second;
    }
    
    value type DurationValue :> Real {
        :>> unit = Units::second;
    }
    
    enumeration def ResponseKind {
        value felt;
        value notFelt;
    }
    
    enumeration def BodyLocation {
        value fingertip;
        value palm;
        value forearm;
        value forehead;
        value cheek;
        value foot;
    }
    
    enumeration def TestProtocol {
        value ascendingMethodOfLimits;
        value descendingMethodOfLimits;
        value staircaseMethod;
    }
    
    enumeration def SystemStatus {
        value off;
        value selfTest;
        value calibration;
        value ready;
        value testing;
        value analysis;
        value resultsDisplay;
        value error;
    }
    
    enumeration def IndicatorColor {
        value green;
        value amber;
        value red;
    }
    
    item def Stimulus {
        attribute : appliedForce : ForceValue;
        attribute : probeSpacing : SpacingValue;
        attribute : timestamp : TimeStampValue;
    }
    
    item def PatientResponse {
        attribute : felt : ResponseKind;
        attribute : timestamp : TimeStampValue;
    }
    
    item def StimulusResponsePair {
        attribute : stimulus : Stimulus;
        attribute : response : PatientResponse;
    }
    
    item def TestParameters {
        attribute : protocol : TestProtocol;
        attribute : location : BodyLocation;
        attribute : startForce : ForceValue;
        attribute : maxForce : ForceValue;
        attribute : stepSize : ForceValue;
        attribute : initialSpacing : SpacingValue;
    }
    
    item def TestResults {
        attribute : sensoryThreshold : ForceValue;
        attribute : twoPointDiscriminationThreshold : SpacingValue;
        attribute : location : BodyLocation;
        attribute : timestamp : TimeStampValue;
        attribute : protocol : TestProtocol;
        attribute : trials : StimulusResponsePair[*];
    }
    
    item def DisplayUpdate {
        attribute : status : SystemStatus;
        attribute : message : String;
        attribute : currentForce : ForceValue;
        attribute : currentSpacing : SpacingValue;
        attribute : indicator : IndicatorColor;
    }
    
    item def ControlCommand {
        attribute : command : String;
        attribute : parameters : TestParameters;
    }
    
    port def MechanicalPort {
        attribute : appliedForce : ForceValue;
        attribute : probeSpacing : SpacingValue;
    }
    
    port def ControlPort {
        attribute : command : ControlCommand;
        attribute : status : SystemStatus;
    }
    
    port def StimulusDataPort {
        attribute : stimulus : Stimulus;
    }
    
    port def ResponseDataPort {
        attribute : response : PatientResponse;
    }
    
    port def PatientIOPort {
        out attribute : audioCue : Boolean;
        out attribute : visualCue : Boolean;
        in attribute : buttonPress : Boolean;
    }
    
    port def ResultsPort {
        attribute : results : TestResults;
    }
    
    port def DisplayPort {
        attribute : update : DisplayUpdate;
        attribute : acknowledged : Boolean;
    }
    
    part def TactileProbe {
        attribute : material : String = "stainless steel";
        attribute : tipDiameter : SpacingValue = 1;
        port : mechanicalPort : MechanicalPort;
    }
    
    part def ForceRegulator {
        attribute : currentForce : ForceValue;
        attribute : targetForce : ForceValue;
        attribute : accuracy : ForceValue = 0.005;
        port : controlIn : ControlPort;
        port : mechanicalOut : MechanicalPort;
        
        action def applyForce(in target : ForceValue) {
            assign targetForce = target;
        }
        action def rampForce(in fromForce : ForceValue, in toForce : ForceValue, in duration : DurationValue) {
        }
        action def zeroForce() {
            assign currentForce = 0;
        }
    }
    
    part def SpacingMechanism {
        attribute : currentSpacing : SpacingValue;
        attribute : targetSpacing : SpacingValue;
        port : controlIn : ControlPort;
        port : mechanicalOut : MechanicalPort;
        
        action def setSpacing(in target : SpacingValue) {
            assign targetSpacing = target;
        }
        action def home() {
            assign currentSpacing = 1;
        }
    }
    
    part def ProbeHead {
        part : probeA : TactileProbe;
        part : probeB : TactileProbe;
        part : forceRegulator : ForceRegulator;
        part : spacingMechanism : SpacingMechanism;
        
        port : controlIn : ControlPort;
        port : stimulusOut : StimulusDataPort;
        
        connection : probeAForceCoupling connect forceRegulator.mechanicalOut to probeA.mechanicalPort;
        connection : probeBForceCoupling connect forceRegulator.mechanicalOut to probeB.mechanicalPort;
        connection : probeASpacingCoupling connect spacingMechanism.mechanicalOut to probeA.mechanicalPort;
        connection : probeBSpacingCoupling connect spacingMechanism.mechanicalOut to probeB.mechanicalPort;
    }
    
    part def ResponseButton {
        attribute : pressed : Boolean;
        port : io : PatientIOPort;
        action def detectPress() : Boolean {
        }
    }
    
    part def AudioCueGenerator {
        attribute : enabled : Boolean;
        attribute : volume : Real;
        port : io : PatientIOPort;
        action def playTone() {
        }
        action def stopTone() {
        }
    }
    
    part def VisualCueIndicator {
        attribute : enabled : Boolean;
        port : io : PatientIOPort;
        action def showLight() {
        }
        action def clearLight() {
        }
    }
    
    part def PatientInterface {
        part : responseButton : ResponseButton;
        part : audioCue : AudioCueGenerator;
        part : visualCue : VisualCueIndicator;
        
        port : controlIn : ControlPort;
        port : patientIO : PatientIOPort;
        port : responseOut : ResponseDataPort;
        
        action def emitCues(in audio : Boolean, in visual : Boolean) {
            assign audioCue.enabled = audio;
            assign visualCue.enabled = visual;
        }
        action def captureResponse() : PatientResponse {
        }
    }
    
    part def DataProcessor {
        attribute : trials : StimulusResponsePair[*];
        attribute : currentThreshold : ForceValue;
        
        port : stimulusIn : StimulusDataPort;
        port : responseIn : ResponseDataPort;
        port : resultsOut : ResultsPort;
        port : controlIn : ControlPort;
        
        action def calculateThreshold(in trialData : StimulusResponsePair[*]) : ForceValue {
        }
        action def calculateTwoPointThreshold(in trialData : StimulusResponsePair[*]) : SpacingValue {
        }
        action def logResults(in results : TestResults) {
        }
        action def generateReport(in trialData : StimulusResponsePair[*], in params : TestParameters) : TestResults {
        }
        action def clearData() {
            assign trials = ();
        }
    }
    
    part def LCDScreen {
        attribute : text : String;
        attribute : backlight : Boolean = true;
        port : displayPort : DisplayPort;
        action def render(in update : DisplayUpdate) {
        }
    }
    
    part def StatusIndicator {
        attribute : color : IndicatorColor;
        port : displayPort : DisplayPort;
        action def setColor(in c : IndicatorColor) {
        }
    }
    
    part def DisplayModule {
        part : lcd : LCDScreen;
        part : statusLight : StatusIndicator;
        port : displayIn : DisplayPort;
        
        action def showStatus(in status : SystemStatus) {
        }
        action def showResults(in results : TestResults) {
        }
        action def showInstructions(in text : String) {
        }
        action def acknowledge() {
        }
    }
    
    part def ControlModule {
        attribute : currentProtocol : TestProtocol;
        attribute : currentParams : TestParameters;
        attribute : stimulusCounter : Integer = 0;
        
        port : operatorIn : ControlPort;
        port : probeControl : ControlPort;
        port : patientControl : ControlPort;
        port : processorControl : ControlPort;
        
        action def startTest(in params : TestParameters) {
            assign currentParams = params;
            assign currentProtocol = params.protocol;
            assign stimulusCounter = 0;
        }
        action def abortTest() {
        }
        action def nextStimulus() : Stimulus {
            assign stimulusCounter = stimulusCounter + 1;
        }
        action def endTest() {
        }
    }
    
    part def Esthesiometer {
        attribute : serialNumber : String;
        attribute : poweredOn : Boolean;
        attribute : operatorAcknowledged : Boolean;
        attribute : selfTestPassed : Boolean;
        attribute : calibrationPassed : Boolean;
        attribute : lastResults : TestResults;
        
        part : probeHead : ProbeHead;
        part : controlModule : ControlModule;
        part : patientInterface : PatientInterface;
        part : dataProcessor : DataProcessor;
        part : displayModule : DisplayModule;
        
        connection : ctrlToProbe connect controlModule.probeControl to probeHead.controlIn;
        connection : ctrlToPatient connect controlModule.patientControl to patientInterface.controlIn;
        connection : ctrlToProcessor connect controlModule.processorControl to dataProcessor.controlIn;
        connection : ctrlToDisplay connect controlModule.operatorIn to displayModule.displayIn;
        connection : stimulusToProcessor connect probeHead.stimulusOut to dataProcessor.stimulusIn;
        connection : responseToProcessor connect patientInterface.responseOut to dataProcessor.responseIn;
        connection : resultsToDisplay connect dataProcessor.resultsOut to displayModule.displayIn;
        
        action def performSelfTest() : Boolean {
            assign probeHead.forceRegulator.zeroForce();
            assign probeHead.spacingMechanism.home();
        }
        action def performCalibration() : Boolean {
            assign probeHead.forceRegulator.applyForce(0.01);
            assign probeHead.spacingMechanism.setSpacing(1);
        }
        action def runTestSequence(in params : TestParameters) {
            assign controlModule.currentParams = params;
        }
        action def analyzeData() : TestResults {
            assign lastResults = dataProcessor.generateReport(dataProcessor.trials, controlModule.currentParams);
        }
        action def displayResults(in results : TestResults) {
            assign displayModule.lcd.text = "Sensory Threshold: " + results.sensoryThreshold;
        }
        action def handleError(in error : String) {
            assign displayModule.lcd.text = error;
        }
        
        state machine : lifecycle {
            state off;
            state selfTest {
                entry : performSelfTest();
            }
            state calibration {
                entry : performCalibration();
            }
            state ready;
            state testing {
                entry : runTestSequence(controlModule.currentParams);
            }
            state analysis {
                entry : analyzeData();
            }
            state resultsDisplay {
                entry : displayResults(lastResults);
            }
            state error {
                entry : handleError("System error detected");
            }
            
            transition init initial to off;
            transition off_to_selfTest off to selfTest when poweredOn;
            transition selfTest_to_calibration selfTest to calibration when selfTestPassed;
            transition selfTest_to_error selfTest to error when !selfTestPassed;
            transition calibration_to_ready calibration to ready when calibrationPassed;
            transition calibration_to_error calibration to error when !calibrationPassed;
            transition ready_to_testing ready to testing;
            transition testing_to_analysis testing to analysis;
            transition testing_to_error testing to error;
            transition analysis_to_resultsDisplay analysis to resultsDisplay;
            transition analysis_to_error analysis to error;
            transition resultsDisplay_to_ready resultsDisplay to ready when operatorAcknowledged;
            transition error_to_off error to off;
        }
    }
    
    requirement def ForceRangeRequirement {
        doc /* The system shall apply controlled forces from 0.01 N to 5 N. */;
        subject : esthesiometer : Esthesiometer;
        constraint { esthesiometer.probeHead.forceRegulator.currentForce >= 0.01
            and esthesiometer.probeHead.forceRegulator.currentForce <= 5.0 }
    }
    
    requirement def SpacingRangeRequirement {
        doc /* The system shall adjust probe spacing from 1 mm to 50 mm. */;
        subject : esthesiometer : Esthesiometer;
        constraint { esthesiometer.probeHead.spacingMechanism.currentSpacing >= 1
            and esthesiometer.probeHead.spacingMechanism.currentSpacing <= 50 }
    }
    
    requirement def ForceAccuracyRequirement {
        doc /* The force regulator shall maintain accuracy of 0.005 N or better. */;
        subject : regulator : ForceRegulator;
        constraint { regulator.accuracy <= 0.005 }
    }
    
    requirement def ThresholdCalculationRequirement {
        doc /* The data processor shall calculate sensory threshold using a staircase algorithm. */;
        subject : processor : DataProcessor;
        constraint { processor.trials.size > 0 }
    }
    
    requirement def LifecycleRequirement {
        doc /* The system shall perform self-test and calibration on power-on before entering ready. */;
        subject : esthesiometer : Esthesiometer;
        constraint { esthesiometer.selfTestPassed = true
            and esthesiometer.calibrationPassed = true }
    }
    
    requirement def PatientResponseRequirement {
        doc /* The patient interface shall provide audio and visual cues and capture button responses. */;
        subject : interface : PatientInterface;
        constraint { interface.audioCue.enabled.isDefined
            and interface.visualCue.enabled.isDefined }
    }
    
    requirement def ProbeMaterialRequirement {
        doc /* The tactile probes shall be made of stainless steel. */;
        subject : probe : TactileProbe;
        constraint { probe.material = "stainless steel" }
    }
    
    requirement def TwoPointDiscriminationRequirement {
        doc /* The system shall support two-point discrimination with two probes. */;
        subject : esthesiometer : Esthesiometer;
        constraint { esthesiometer.probeHead.probeA.isDefined
            and esthesiometer.probeHead.probeB.isDefined }
    }
    
    requirement def ErrorHandlingRequirement {
        doc /* The system shall enter an error state on malfunction and return to off when safe. */;
        subject : esthesiometer : Esthesiometer;
        constraint { esthesiometer.lifecycle.states.exists(s | s = SystemStatus::error) }
    }
}
