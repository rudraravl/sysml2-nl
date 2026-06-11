package BiothesiometrySystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volt :> ISQ::electricPotential;
    attribute def MilliVolt :> Volt;
    attribute def Hertz :> ISQ::frequency;
    attribute def Newton :> ISQ::force;
    attribute def Gram :> ISQ::mass;
    attribute def Second :> ISQ::duration;
    attribute def Millimeter :> ISQ::length;
    attribute def DegreeCelsius :> ISQ::thermodynamicTemperature;
    attribute def Percent;
    attribute def ThresholdScore;

    enum def TestStatus {
        enum idle;
        enum patientReady;
        enum probePositioned;
        enum stimulusActive;
        enum responseCaptured;
        enum completed;
        enum faulted;
    }

    enum def AnatomicalSite {
        enum leftGreatToe;
        enum rightGreatToe;
        enum leftMedialMalleolus;
        enum rightMedialMalleolus;
        enum leftIndexFinger;
        enum rightIndexFinger;
    }

    enum def ResponseValue {
        enum felt;
        enum notFelt;
        enum uncertain;
    }

    item def VibrationCommand {
        attribute targetAmplitude : MilliVolt;
        attribute frequency : Hertz;
        attribute rampRate : MilliVolt;
        attribute duration : Second;
    }

    item def VibrationStimulus {
        attribute actualAmplitude : MilliVolt;
        attribute frequency : Hertz;
        attribute contactForce : Newton;
        attribute elapsedTime : Second;
    }

    item def PatientResponse {
        attribute value : ResponseValue;
        attribute responseTime : Second;
        attribute site : AnatomicalSite;
    }

    item def ThresholdMeasurement {
        attribute site : AnatomicalSite;
        attribute perceptionThreshold : MilliVolt;
        attribute repeatCount : Integer;
        attribute confidence : Percent;
        attribute ambientTemperature : DegreeCelsius;
        attribute timestampSeconds : Second;
    }

    item def PatientRecord {
        attribute patientIdentifier : String;
        attribute ageYears : Integer;
        attribute testOperator : String;
    }

    port def PowerPort {
        out item powerVoltage : Volt;
        out item availableCurrent_mA : Real;
    }

    port def StimulusPort {
        out item command : VibrationCommand;
        in item stimulusFeedback : VibrationStimulus;
    }

    port def ResponsePort {
        in item response : PatientResponse;
    }

    port def DataPort {
        inout item patient : PatientRecord;
        out item measurement : ThresholdMeasurement;
        out item status : TestStatus;
    }

    port def DisplayPort {
        in item status : TestStatus;
        in item measurement : ThresholdMeasurement;
    }

    port def ContactPort {
        out item stimulus : VibrationStimulus;
    }

    action def InitializeDevice {
        out status : TestStatus;
        first start;
        then verifyPower;
        then selfTestActuator;
        then calibrateZeroAmplitude;
        then ready;
        action verifyPower;
        action selfTestActuator;
        action calibrateZeroAmplitude;
        action ready {
            status = TestStatus::idle;
        }
    }

    action def ApplyRampStimulus {
        in site : AnatomicalSite;
        in startAmplitude : MilliVolt;
        in maximumAmplitude : MilliVolt;
        in frequency : Hertz;
        out finalStimulus : VibrationStimulus;
        first positionProbe;
        then rampAmplitude;
        then holdAtResponse;
        then stopStimulus;

        action positionProbe;
        action rampAmplitude;
        action holdAtResponse;
        action stopStimulus;
    }

    action def CalculateThreshold {
        in responses : PatientResponse[3..*];
        in stimuli : VibrationStimulus[3..*];
        out result : ThresholdMeasurement;
        first rejectUncertainResponses;
        then averageReversalAmplitudes;
        then computeConfidence;
        then publishMeasurement;

        action rejectUncertainResponses;
        action averageReversalAmplitudes;
        action computeConfidence;
        action publishMeasurement;
    }

    state def BiothesiometerOperatingState {
        entry action InitializeDevice;

        state Idle;
        state PatientSetup;
        state ProbePlacement;
        state Measuring;
        state AwaitingResponse;
        state ComputingThreshold;
        state Reporting;
        state Fault;

        transition first Idle;
        transition Idle_to_PatientSetup
            first Idle
            accept PatientRecord
            then PatientSetup;

        transition PatientSetup_to_ProbePlacement
            first PatientSetup
            accept AnatomicalSite
            then ProbePlacement;

        transition ProbePlacement_to_Measuring
            first ProbePlacement
            if contactForceWithinRange
            then Measuring;

        transition Measuring_to_AwaitingResponse
            first Measuring
            accept VibrationStimulus
            then AwaitingResponse;

        transition AwaitingResponse_to_ComputingThreshold
            first AwaitingResponse
            accept PatientResponse
            then ComputingThreshold;

        transition ComputingThreshold_to_Reporting
            first ComputingThreshold
            accept ThresholdMeasurement
            then Reporting;

        transition Reporting_to_ProbePlacement
            first Reporting
            if moreSitesRequested
            then ProbePlacement;

        transition Reporting_to_Idle
            first Reporting
            if testSessionComplete
            then Idle;

        transition any_to_Fault
            first Idle
            accept faultDetected
            then Fault;

        attribute contactForceWithinRange : Boolean;
        attribute moreSitesRequested : Boolean;
        attribute testSessionComplete : Boolean;
    }

    part def VibrationActuator {
        attribute minimumAmplitude : MilliVolt = 0.0;
        attribute maximumAmplitude : MilliVolt = 50.0;
        attribute nominalFrequency : Hertz = 100.0;
        attribute amplitudeAccuracy : Percent = 5.0;
        port powerIn : PowerPort;
        port stimulusOut : StimulusPort;
        perform action ApplyRampStimulus;
    }

    part def ProbeAssembly {
        attribute probeTipDiameter : Millimeter = 5.0;
        attribute nominalContactForce : Newton = 1.0;
        attribute contactForceTolerance : Newton = 0.2;
        port actuatorInterface : StimulusPort;
        port patientContact : ContactPort;
    }

    part def PatientResponseButton {
        attribute debounceTime : Second = 0.05;
        port responseOut : ResponsePort;
    }

    part def ControlProcessor {
        attribute samplingPeriod : Second = 0.01;
        attribute thresholdResolution : MilliVolt = 0.1;
        attribute requiredRepeatsPerSite : Integer = 3;
        port actuatorControl : StimulusPort;
        port patientInput : ResponsePort;
        port dataInterface : DataPort;
        perform action InitializeDevice;
        perform action CalculateThreshold;
        exhibit state BiothesiometerOperatingState;
    }

    part def UserInterface {
        attribute displayBrightness : Percent = 80.0;
        port displayIn : DisplayPort;
        port sessionData : DataPort;
    }

    part def PowerSubsystem {
        attribute supplyVoltage : Volt = 12.0;
        attribute batteryCapacity_mAh : Real = 2500.0;
        attribute lowBatteryThreshold : Percent = 15.0;
        port powerOut : PowerPort;
    }

    part def Patient {
        attribute identifier : String;
        port tactileInterface : ContactPort;
        port manualResponse : ResponsePort;
    }

    part def Biothesiometer {
        doc /* Primary function: provide a controlled vibratory stimulus to a patient's skin, capture the patient's perception response, and calculate vibration perception threshold values used to screen or monitor sensory nerve function. */

        part power : PowerSubsystem;
        part actuator : VibrationActuator;
        part probe : ProbeAssembly;
        part responseButton : PatientResponseButton;
        part controller : ControlProcessor;
        part interface : UserInterface;
        part patient : Patient;

        port externalData : DataPort;

        connect power.powerOut to actuator.powerIn;
        connect actuator.stimulusOut to probe.actuatorInterface;
        connect probe.patientContact to patient.tactileInterface;
        connect patient.manualResponse to responseButton.responseOut;
        connect responseButton.responseOut to controller.patientInput;
        connect controller.actuatorControl to actuator.stimulusOut;
        connect controller.dataInterface to interface.sessionData;
        connect interface.sessionData to externalData;

        attribute currentStatus : TestStatus;
        attribute selectedSite : AnatomicalSite;
        attribute sessionMeasurementCount : Integer;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall determine a patient's vibration perception threshold by applying controlled vibratory stimuli and recording patient response at selected anatomical sites. */
        subject system : Biothesiometer;
        require constraint {
            system.controller.requiredRepeatsPerSite >= 3
        }
    }

    requirement def StimulusControlRequirement {
        doc /* The system shall provide a sinusoidal tactile vibration stimulus at a clinically standard frequency with bounded amplitude error. */
        subject actuator : VibrationActuator;
        require constraint {
            actuator.nominalFrequency == 100.0 [Hertz] and
            actuator.maximumAmplitude >= 50.0 [MilliVolt] and
            actuator.amplitudeAccuracy <= 5.0 [Percent]
        }
    }

    requirement def ContactForceRequirement {
        doc /* The probe shall maintain repeatable patient contact force during threshold measurement. */
        subject probe : ProbeAssembly;
        require constraint {
            probe.nominalContactForce >= 0.8 [Newton] and
            probe.nominalContactForce <= 1.2 [Newton] and
            probe.contactForceTolerance <= 0.2 [Newton]
        }
    }

    requirement def MeasurementResolutionRequirement {
        doc /* The system shall resolve vibration perception threshold to one tenth of a volt-scale millivolt command unit or better. */
        subject controller : ControlProcessor;
        require constraint {
            controller.thresholdResolution <= 0.1 [MilliVolt]
        }
    }

    requirement def PatientSafetyRequirement {
        doc /* The system shall stop vibration output when a fault is detected, when maximum amplitude is reached without response, or when the operator cancels the test. */
        subject system : Biothesiometer;
        require constraint {
            system.actuator.maximumAmplitude <= 50.0 [MilliVolt]
        }
    }

    requirement def DataReportingRequirement {
        doc /* The system shall report threshold measurement, anatomical site, repeat count, confidence, and environmental temperature for each completed site. */
        subject measurement : ThresholdMeasurement;
        require constraint {
            measurement.repeatCount >= 3 and
            measurement.confidence >= 80.0 [Percent]
        }
    }

    part biothesiometrySystem : Biothesiometer;

    satisfy PrimaryFunctionRequirement by biothesiometrySystem;
    satisfy StimulusControlRequirement by biothesiometrySystem.actuator;
    satisfy ContactForceRequirement by biothesiometrySystem.probe;
    satisfy MeasurementResolutionRequirement by biothesiometrySystem.controller;
    satisfy PatientSafetyRequirement by biothesiometrySystem;
}