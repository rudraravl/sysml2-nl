package EsthesiometerSystem {
    private import SI::N;
    private import SI::mm;
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Natural;
    private import Time::DateTime;

    attribute def Force :> Real {
        unit N;
    }
    attribute def Distance :> Real {
        unit mm;
    }

    item def TestParameters {
        attribute bodyLocation : String;
        attribute timestamp : DateTime;
    }

    item def Stimulus {
        attribute force : Force;
        attribute spacing : Distance;
    }

    item def PatientResponse {
        attribute felt : Boolean;
        attribute responseTime : Real;
    }

    item def TestResult {
        attribute sensoryThreshold : Force;
        attribute spatialResolution : Distance;
        attribute params : TestParameters;
    }

    item def TestCommand {
        attribute testType : String;
        attribute bodyLocation : String;
    }

    item def TestCompleteReport;

    item def AudioVisualCue {
        attribute cueType : String;
        attribute active : Boolean;
    }

    attribute def PowerOnSignal;
    attribute def SelfTestCompleteSignal;
    attribute def CalibrationCompleteSignal;
    attribute def StartTestSignal;
    attribute def TestCompleteSignal;
    attribute def AnalysisCompleteSignal;
    attribute def AcknowledgeSignal;
    attribute def ErrorSignal;
    attribute def ResetSignal;

    action def AscendingMethodOfLimits {
        in item testCommand : TestCommand;
        in item patientResponse : PatientResponse;
        out item stimulus : Stimulus;

        attribute currentForce : Force = 0.01 [N];
        attribute forceIncrement : Force = 0.01 [N];
        attribute maxForce : Force = 5.0 [N];
        attribute currentSpacing : Distance = if testCommand.testType == "TwoPoint" ? 30.0 [mm] else 0.0 [mm];

        first start;
        then action initialize;
        then action deliverStimulus;
        then decide;
            if patientResponse.felt then done;
            else increaseForce;
        action increaseForce;
        then decide;
            if currentForce >= maxForce then done;
            else deliverStimulus;
    }

    action def StaircaseAlgorithm {
        in item response : PatientResponse;
        in item stimulus : Stimulus;
        out item result : TestResult;

        attribute reversalCount : Natural = 0;
        attribute currentForce : Force = 0.1 [N];
        attribute stepSize : Force = 0.02 [N];

        first start;
        then action evaluate;
        then decide;
            if response.felt then decrease;
            else increase;
        action decrease;
        then decide;
            if reversalCount >= 6 then computeResult;
            else evaluate;
        action increase;
        then decide;
            if reversalCount >= 6 then computeResult;
            else evaluate;
        action computeResult;
        then done;
    }

    state def EsthesiometerStates {
        entry; then off;
        state off;
        accept PowerOnSignal then selfTest;
        state selfTest;
        accept SelfTestCompleteSignal then calibration;
        accept ErrorSignal then error;
        state calibration;
        accept CalibrationCompleteSignal then ready;
        accept ErrorSignal then error;
        state ready;
        accept StartTestSignal then testing;
        state testing;
        accept TestCompleteSignal then analyzing;
        accept ErrorSignal then error;
        state analyzing;
        accept AnalysisCompleteSignal then displaying;
        accept ErrorSignal then error;
        state displaying;
        accept AcknowledgeSignal then ready;
        accept ErrorSignal then error;
        state error;
        accept ResetSignal then selfTest;
    }

    part def ForceRegulator {
        attribute minForce : Force = 0.01 [N];
        attribute maxForce : Force = 5.0 [N];
        attribute appliedForce : Force;
        constraint forceRangeConstraint {
            appliedForce >= minForce and appliedForce <= maxForce
        }
    }

    part def SpacingMechanism {
        attribute minSpacing : Distance = 1.0 [mm];
        attribute maxSpacing : Distance = 50.0 [mm];
        attribute probeSpacing : Distance;
        constraint spacingRangeConstraint {
            probeSpacing >= minSpacing and probeSpacing <= maxSpacing
        }
    }

    part def TactileProbe {
        attribute material : String = "Stainless Steel";
    }

    part def ProbeHead {
        in item command : TestCommand;
        out item stimulus : Stimulus;
        in item response : PatientResponse;
        out item responseOut : PatientResponse;
        bind responseOut = response;

        part probe1 : TactileProbe;
        part probe2 : TactileProbe;
        part forceRegulator : ForceRegulator;
        part spacingMechanism : SpacingMechanism;
    }

    part def ControlModule {
        out item command : TestCommand;
        in item completeReport : TestCompleteReport;
        out item status : String;
    }

    part def ResponseButton {
        attribute isPressed : Boolean;
    }

    part def AudioDevice {
        attribute volume : Real;
    }

    part def VisualDevice {
        attribute brightness : Real;
    }

    part def PatientInterface {
        in item stimulus : Stimulus;
        out item response : PatientResponse;

        part responseButton : ResponseButton;
        part audioOutput : AudioDevice;
        part visualOutput : VisualDevice;
    }

    part def DataProcessor {
        in item response : PatientResponse;
        in item stimulus : Stimulus;
        out item result : TestResult;
    }

    part def LCDDisplay {
        in item statusText : String;
        in item resultText : TestResult;
    }

    part def IndicatorLights {
        in item status : String;
    }

    part def DisplayModule {
        in item result : TestResult;
        in item status : String;
        out item acknowledge : TestCompleteReport;

        part lcdScreen : LCDDisplay;
        part statusLights : IndicatorLights;
    }

    requirement def SensoryThresholdRequirement {
        doc /* The system shall measure the minimum force a person can feel using a staircase algorithm with at least 6 reversals. */
        attribute minForce : Force = 0.01 [N];
        attribute maxForce : Force = 5.0 [N];
    }

    requirement def TwoPointDiscriminationRequirement {
        doc /* The system shall measure the ability to distinguish between two distinct points of contact by adjusting probe spacing from 1 mm to 50 mm. */
        attribute minSpacing : Distance = 1.0 [mm];
        attribute maxSpacing : Distance = 50.0 [mm];
    }

    requirement def ForceAccuracyRequirement {
        doc /* The Force Regulator shall apply computer-controlled forces with an accuracy of +/- 0.005 N. */
        attribute accuracy : Force = 0.005 [N];
    }

    requirement def SelfTestRequirement {
        doc /* The system shall perform a self-test upon power-on and transition to an error state if any test fails. */
    }

    requirement def CalibrationRequirement {
        doc /* The system shall perform calibration after a successful self-test and before entering the ready state. */
    }

    requirement def DataLoggingRequirement {
        doc /* The system shall log test results including sensory threshold, spatial resolution, body location, and timestamp. */
    }

    requirement def PatientSafetyRequirement {
        doc /* The maximum applied force shall not exceed 5 N to ensure patient safety. */
        attribute maxForce : Force = 5.0 [N];
    }

    part def Esthesiometer {
        satisfy SensoryThresholdRequirement;
        satisfy TwoPointDiscriminationRequirement;
        satisfy SelfTestRequirement;
        satisfy CalibrationRequirement;
        satisfy DataLoggingRequirement;
        satisfy PatientSafetyRequirement;

        part probeHead : ProbeHead;
        part controlModule : ControlModule;
        part patientInterface : PatientInterface;
        part dataProcessor : DataProcessor;
        part displayModule : DisplayModule;

        flow controlModule.command to probeHead.command;
        flow probeHead.stimulus to patientInterface.stimulus;
        flow patientInterface.response to probeHead.response;
        flow probeHead.responseOut to dataProcessor.response;
        flow probeHead.stimulus to dataProcessor.stimulus;
        flow dataProcessor.result to displayModule.result;
        flow displayModule.acknowledge to controlModule.completeReport;
        flow controlModule.status to displayModule.status;

        state machine :>> EsthesiometerStates;
    }
}
