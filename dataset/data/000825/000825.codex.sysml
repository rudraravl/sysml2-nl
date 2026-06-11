package VonFreyHairSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Millimeter :> LengthUnit {
        :>> symbol = "mm";
    }

    attribute def GramForce :> ForceUnit {
        :>> symbol = "gf";
    }

    attribute def Newton :> ForceUnit {
        :>> symbol = "N";
    }

    attribute def Second :> TimeUnit {
        :>> symbol = "s";
    }

    attribute def Degree :> PlaneAngleUnit {
        :>> symbol = "deg";
    }

    value type ForceValue :> ISQ::force {
        unit = Newton;
    }

    value type GramForceValue :> ISQ::force {
        unit = GramForce;
    }

    value type LengthValue :> ISQ::length {
        unit = Millimeter;
    }

    value type TimeValue :> ISQ::time {
        unit = Second;
    }

    value type AngleValue :> ISQ::planeAngle {
        unit = Degree;
    }

    value type BooleanResponse :> ScalarValues::Boolean;

    item def MechanicalStimulus {
        attribute appliedForce : ForceValue;
        attribute nominalForce : GramForceValue;
        attribute contactDuration : TimeValue;
        attribute filamentDeflection : LengthValue;
        attribute contactAngle : AngleValue;
        attribute stimulusValid : BooleanResponse;
    }

    item def SkinContactEvent {
        attribute contactDetected : BooleanResponse;
        attribute contactForce : ForceValue;
        attribute locationLabel : String;
    }

    item def PatientResponse {
        attribute responseDetected : BooleanResponse;
        attribute responseLatency : TimeValue;
        attribute responseMode : String;
    }

    item def TestResult {
        attribute thresholdForce : GramForceValue;
        attribute trialCount : Integer;
        attribute validTrialCount : Integer;
        attribute responsePattern : String;
        attribute assessmentComplete : BooleanResponse;
    }

    port def MechanicalStimulusPort {
        out item stimulus : MechanicalStimulus;
    }

    port def SkinInterfacePort {
        in item contact : SkinContactEvent;
        out item response : PatientResponse;
    }

    port def ResultPort {
        out item result : TestResult;
    }

    port def OperatorCommandPort {
        in item command : String;
    }

    action def ApplyVonFreyStimulus {
        in attribute targetForce : GramForceValue;
        in attribute targetDuration : TimeValue;
        in attribute targetAngle : AngleValue;
        out item generatedStimulus : MechanicalStimulus;

        first start;
        then positionFilament;
        then increaseContactForce;
        then holdAtBucklePoint;
        then releaseFilament;
        then done;

        action positionFilament {
            out attribute positionedAngle : AngleValue = targetAngle;
        }

        action increaseContactForce {
            out attribute deflection : LengthValue;
        }

        action holdAtBucklePoint {
            out item stimulus : MechanicalStimulus;
            bind stimulus.nominalForce = targetForce;
            bind stimulus.contactDuration = targetDuration;
            bind stimulus.contactAngle = targetAngle;
            bind stimulus.stimulusValid = true;
        }

        action releaseFilament;

        bind generatedStimulus = holdAtBucklePoint.stimulus;
    }

    action def RecordPatientResponse {
        in item stimulus : MechanicalStimulus;
        in item observedResponse : PatientResponse;
        out item trialResult : TestResult;

        first start;
        then evaluateResponse;
        then updateThresholdEstimate;
        then done;

        action evaluateResponse {
            out attribute validResponse : BooleanResponse;
        }

        action updateThresholdEstimate {
            out item result : TestResult;
        }

        bind trialResult = updateThresholdEstimate.result;
    }

    state def TestSessionStateMachine {
        entry action initializeSession;

        state Idle;
        state SelectFilament;
        state AlignFilament;
        state ApplyStimulus;
        state ObserveResponse;
        state RecordTrial;
        state EstimateThreshold;
        state Complete;
        state Fault;

        transition first Idle;

        transition Idle_to_SelectFilament
            first Idle
            then SelectFilament
            accept command
            if command == "start";

        transition SelectFilament_to_AlignFilament
            first SelectFilament
            then AlignFilament;

        transition AlignFilament_to_ApplyStimulus
            first AlignFilament
            then ApplyStimulus
            if alignmentAngle <= 15 [Degree];

        transition AlignFilament_to_Fault
            first AlignFilament
            then Fault
            if alignmentAngle > 15 [Degree];

        transition ApplyStimulus_to_ObserveResponse
            first ApplyStimulus
            then ObserveResponse
            if stimulusValid == true;

        transition ApplyStimulus_to_Fault
            first ApplyStimulus
            then Fault
            if stimulusValid == false;

        transition ObserveResponse_to_RecordTrial
            first ObserveResponse
            then RecordTrial;

        transition RecordTrial_to_EstimateThreshold
            first RecordTrial
            then EstimateThreshold;

        transition EstimateThreshold_to_SelectFilament
            first EstimateThreshold
            then SelectFilament
            if assessmentComplete == false;

        transition EstimateThreshold_to_Complete
            first EstimateThreshold
            then Complete
            if assessmentComplete == true;

        transition Fault_to_Idle
            first Fault
            then Idle
            accept command
            if command == "reset";

        attribute alignmentAngle : AngleValue;
        attribute stimulusValid : BooleanResponse;
        attribute assessmentComplete : BooleanResponse;
    }

    part def VonFreyHairSystem {
        doc /* Primary function: apply a calibrated, repeatable, localized mechanical stimulus to skin using a flexible monofilament that buckles at a known force, enabling high-level tactile sensitivity or mechanical threshold assessment. */

        port operatorCommandPort : OperatorCommandPort;
        port stimulusOutputPort : MechanicalStimulusPort;
        port skinInterfacePort : SkinInterfacePort;
        port resultOutputPort : ResultPort;

        attribute systemMass : MassValue;
        attribute nominalOperatingTemperature : TemperatureValue;
        attribute maximumPermittedContactAngle : AngleValue = 15 [Degree];

        part handle : ErgonomicHandle {
            attribute length = 120 [Millimeter];
            attribute diameter = 12 [Millimeter];
        }

        part calibratedFilamentSet : CalibratedFilamentSet;

        part activeFilament : VonFreyFilament;

        part forceCalibrationIndex : ForceCalibrationIndex;

        part alignmentGuide : AlignmentGuide {
            attribute preferredContactAngle = 90 [Degree];
            attribute maximumAngularError = 15 [Degree];
        }

        part skinContactTip : RoundedContactTip {
            attribute tipDiameter = 0.5 [Millimeter];
        }

        part responseRecorder : ResponseRecorder;

        part thresholdEstimator : ThresholdEstimator;

        part sessionController : TestSessionController;

        connection filamentMechanicalPath
            connect activeFilament.tipPort to skinContactTip.filamentPort;

        connection stimulusDeliveryPath
            connect skinContactTip.stimulusPort to stimulusOutputPort;

        connection patientResponsePath
            connect skinInterfacePort to responseRecorder.responseInputPort;

        connection resultPath
            connect thresholdEstimator.resultPort to resultOutputPort;

        connection commandPath
            connect operatorCommandPort to sessionController.commandPort;

        perform action applyStimulus : ApplyVonFreyStimulus {
            in targetForce = activeFilament.nominalBucklingForce;
            in targetDuration = sessionController.targetContactDuration;
            in targetAngle = alignmentGuide.preferredContactAngle;
            out generatedStimulus = stimulusOutputPort.stimulus;
        }

        perform action recordResponse : RecordPatientResponse {
            in stimulus = stimulusOutputPort.stimulus;
            in observedResponse = responseRecorder.currentResponse;
            out trialResult = resultOutputPort.result;
        }

        exhibit state sessionState : TestSessionStateMachine;
    }

    part def ErgonomicHandle {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute gripMaterial : String = "matte medical-grade polymer";
        attribute reusable : BooleanResponse = true;
    }

    part def VonFreyFilament {
        port basePort : MechanicalStimulusPort;
        port tipPort : MechanicalStimulusPort;

        attribute filamentIdentifier : String;
        attribute material : String = "nylon monofilament";
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute nominalBucklingForce : GramForceValue;
        attribute calibratedBucklingForce : ForceValue;
        attribute elasticRecoveryRequired : BooleanResponse = true;
        attribute maximumAllowedPermanentSet : LengthValue = 0.1 [Millimeter];

        constraint bucklingForceConsistency {
            calibratedBucklingForce >= 0.009 [N] and calibratedBucklingForce <= 5.000 [N];
        }
    }

    part def CalibratedFilamentSet {
        part filament008 : VonFreyFilament {
            attribute filamentIdentifier = "VF-008";
            attribute length = 38 [Millimeter];
            attribute diameter = 0.064 [Millimeter];
            attribute nominalBucklingForce = 0.008 [GramForce];
        }

        part filament02 : VonFreyFilament {
            attribute filamentIdentifier = "VF-020";
            attribute length = 38 [Millimeter];
            attribute diameter = 0.076 [Millimeter];
            attribute nominalBucklingForce = 0.02 [GramForce];
        }

        part filament04 : VonFreyFilament {
            attribute filamentIdentifier = "VF-040";
            attribute length = 38 [Millimeter];
            attribute diameter = 0.089 [Millimeter];
            attribute nominalBucklingForce = 0.04 [GramForce];
        }

        part filament16 : VonFreyFilament {
            attribute filamentIdentifier = "VF-160";
            attribute length = 38 [Millimeter];
            attribute diameter = 0.203 [Millimeter];
            attribute nominalBucklingForce = 1.6 [GramForce];
        }

        part filament40 : VonFreyFilament {
            attribute filamentIdentifier = "VF-400";
            attribute length = 38 [Millimeter];
            attribute diameter = 0.305 [Millimeter];
            attribute nominalBucklingForce = 4.0 [GramForce];
        }

        part filament1500 : VonFreyFilament {
            attribute filamentIdentifier = "VF-1500";
            attribute length = 38 [Millimeter];
            attribute diameter = 0.559 [Millimeter];
            attribute nominalBucklingForce = 15.0 [GramForce];
        }
    }

    part def ForceCalibrationIndex {
        attribute calibrationDate : String;
        attribute calibrationIntervalDays : Integer = 365;
        attribute allowedForceTolerancePercent : Real = 10.0;
        attribute traceableStandard : String = "calibrated force gauge";

        port calibrationDataPort : ResultPort;
    }

    part def AlignmentGuide {
        attribute preferredContactAngle : AngleValue;
        attribute maximumAngularError : AngleValue;
        attribute visualCueColor : String = "white";
        attribute contactPerpendicularityRequired : BooleanResponse = true;
    }

    part def RoundedContactTip {
        port filamentPort : MechanicalStimulusPort;
        port stimulusPort : MechanicalStimulusPort;

        attribute tipDiameter : LengthValue;
        attribute edgeRadius : LengthValue = 0.25 [Millimeter];
        attribute cleanableSurface : BooleanResponse = true;
    }

    part def ResponseRecorder {
        port responseInputPort : SkinInterfacePort;
        port trialResultPort : ResultPort;

        attribute currentResponse : PatientResponse;
        attribute minimumObservableLatency : TimeValue = 0.1 [Second];
        attribute maximumResponseWindow : TimeValue = 2.0 [Second];
        attribute responseCaptureMode : String = "operator observed patient report or withdrawal";

        action captureResponse {
            in item contact : SkinContactEvent;
            out item response : PatientResponse;
        }
    }

    part def ThresholdEstimator {
        port trialInputPort : ResultPort;
        port resultPort : ResultPort;

        attribute method : String = "ascending descending staircase";
        attribute requiredReversals : Integer = 3;
        attribute maximumTrials : Integer = 20;
        attribute thresholdForce : GramForceValue;
        attribute assessmentComplete : BooleanResponse;

        action estimateThreshold {
            in item trial : TestResult;
            out item result : TestResult;
        }
    }

    part def TestSessionController {
        port commandPort : OperatorCommandPort;

        attribute targetContactDuration : TimeValue = 1.5 [Second];
        attribute interStimulusInterval : TimeValue = 5.0 [Second];
        attribute currentTrialNumber : Integer;
        attribute selectedBodySite : String = "plantar skin test site";
        attribute operatorInstructions : String = "apply filament perpendicular to skin until first visible buckle, hold, release, and record response";
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide a calibrated localized tactile stimulus by bending a selected Von Frey filament against the skin until buckling occurs at its nominal force. */

        subject system : VonFreyHairSystem;

        require constraint {
            system.activeFilament.nominalBucklingForce > 0 [GramForce]
        }
    }

    requirement def RepeatableStimulusRequirement {
        doc /* The system shall deliver each valid stimulus within the calibrated force tolerance of the selected filament. */

        subject system : VonFreyHairSystem;

        require constraint {
            system.forceCalibrationIndex.allowedForceTolerancePercent <= 10.0
        }
    }

    requirement def ContactDurationRequirement {
        doc /* The system shall support a controlled contact duration suitable for sensory threshold testing. */

        subject system : VonFreyHairSystem;

        require constraint {
            system.sessionController.targetContactDuration >= 1.0 [Second] and
            system.sessionController.targetContactDuration <= 2.0 [Second]
        }
    }

    requirement def AlignmentRequirement {
        doc /* The system shall guide the operator to apply the filament approximately perpendicular to the skin surface. */

        subject system : VonFreyHairSystem;

        require constraint {
            system.alignmentGuide.maximumAngularError <= 15 [Degree]
        }
    }

    requirement def ThresholdAssessmentRequirement {
        doc /* The system shall convert a sequence of stimulus-response observations into an estimated mechanical detection threshold. */

        subject system : VonFreyHairSystem;

        require constraint {
            system.thresholdEstimator.maximumTrials <= 20 and
            system.thresholdEstimator.requiredReversals >= 3
        }
    }

    requirement def PatientInterfaceRequirement {
        doc /* The system shall contact the skin through a smooth rounded tip to reduce scratching and concentrate the stimulus location. */

        subject system : VonFreyHairSystem;

        require constraint {
            system.skinContactTip.tipDiameter >= 0.3 [Millimeter] and
            system.skinContactTip.tipDiameter <= 0.7 [Millimeter]
        }
    }

    satisfy PrimaryFunctionRequirement by VonFreyHairSystem;
    satisfy RepeatableStimulusRequirement by ForceCalibrationIndex;
    satisfy ContactDurationRequirement by TestSessionController;
    satisfy AlignmentRequirement by AlignmentGuide;
    satisfy ThresholdAssessmentRequirement by ThresholdEstimator;
    satisfy PatientInterfaceRequirement by RoundedContactTip;

    part vonFreyHairAssessmentDevice : VonFreyHairSystem {
        attribute systemMass = 0.05 [kg];
        attribute nominalOperatingTemperature = 293.15 [K];
    }
}