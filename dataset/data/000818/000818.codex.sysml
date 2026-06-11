package VaginalDilatorSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Millimeter :> Real;
    attribute def MillimeterPerSecond :> Real;
    attribute def Newton :> Real;
    attribute def DegreeCelsius :> Real;
    attribute def ShoreA :> Real;
    attribute def Percent :> Real;
    attribute def Minute :> Real;

    enum def DilatorSize {
        enum small;
        enum medium;
        enum large;
        enum extraLarge;
    }

    enum def MaterialState {
        enum intact;
        enum degraded;
        enum damaged;
    }

    enum def UseMode {
        enum stored;
        enum prepared;
        enum inserted;
        enum heldInPlace;
        enum removed;
        enum cleaned;
    }

    item def WaterBasedLubricant {
        attribute volume : ml;
        attribute hypoallergenic : Boolean;
        attribute compatibleWithSilicone : Boolean;
    }

    item def CleaningAgent {
        attribute pH : Real;
        attribute nonAbrasive : Boolean;
        attribute residueFree : Boolean;
    }

    item def UserAppliedForce {
        attribute axialForce : Newton;
        attribute lateralForce : Newton;
        attribute insertionSpeed : MillimeterPerSecond;
    }

    item def UserComfortFeedback {
        attribute discomfortScore : Integer;
        attribute painReported : Boolean;
        attribute stopRequested : Boolean;
    }

    item def DilatorStatus {
        attribute mode : UseMode;
        attribute surfaceClean : Boolean;
        attribute integrity : MaterialState;
        attribute currentTemperature : DegreeCelsius;
    }

    port def HandInterfacePort {
        in force : UserAppliedForce;
        out tactileFeedback : UserComfortFeedback;
    }

    port def BodyInterfacePort {
        in lubricant : WaterBasedLubricant;
        in force : UserAppliedForce;
        out comfortFeedback : UserComfortFeedback;
    }

    port def CleaningPort {
        in cleaningAgent : CleaningAgent;
        out status : DilatorStatus;
    }

    port def StoragePort {
        out storedStatus : DilatorStatus;
    }

    part def DilatorBody {
        attribute totalLength : Millimeter;
        attribute maximumDiameter : Millimeter;
        attribute tipRadius : Millimeter;
        attribute shaftTaperAngle : Real;
        attribute surfaceRoughnessRa : Millimeter;
        attribute hardness : ShoreA;
        attribute biocompatible : Boolean;
        attribute nonPorousSurface : Boolean;
        attribute integrity : MaterialState;

        port bodyInterface : BodyInterfacePort;

        constraint smoothSurface {
            surfaceRoughnessRa <= 0.002;
        }

        constraint atraumaticTip {
            tipRadius >= 3.0;
        }

        constraint moderateCompliance {
            hardness >= 20.0 and hardness <= 70.0;
        }
    }

    part def Handle {
        attribute gripLength : Millimeter;
        attribute gripDiameter : Millimeter;
        attribute slipResistantTexture : Boolean;
        attribute flangeDiameter : Millimeter;

        port handInterface : HandInterfacePort;

        constraint retentionGeometry {
            flangeDiameter > gripDiameter;
        }
    }

    part def SizeMarking {
        attribute size : DilatorSize;
        attribute visibleWhenHeld : Boolean;
        attribute permanentMarking : Boolean;
        attribute nominalDiameter : Millimeter;
        attribute nominalLength : Millimeter;
    }

    part def ProtectiveCase {
        attribute internalLength : Millimeter;
        attribute internalDiameter : Millimeter;
        attribute vented : Boolean;
        attribute cleanable : Boolean;

        port storagePort : StoragePort;
    }

    part def HygieneSurface {
        attribute surfaceClean : Boolean;
        attribute compatibleWithSoapAndWater : Boolean;
        attribute compatibleWithWaterBasedLubricant : Boolean;
        attribute maximumCleaningTemperature : DegreeCelsius;

        port cleaningPort : CleaningPort;
    }

    part def VaginalDilatorSystem {
        attribute intendedFunction : String = "Provide a smooth, controllable, graduated intravaginal form used under clinical guidance or prescribed self-care to gently support progressive accommodation of vaginal tissue.";
        attribute selectedSize : DilatorSize;
        attribute currentMode : UseMode;
        attribute allowedAxialForce : Newton = 10.0;
        attribute allowedInsertionSpeed : MillimeterPerSecond = 5.0;
        attribute maximumUseDuration : Minute = 20.0;

        part body : DilatorBody {
            attribute totalLength = 150.0;
            attribute maximumDiameter = 28.0;
            attribute tipRadius = 6.0;
            attribute shaftTaperAngle = 3.5;
            attribute surfaceRoughnessRa = 0.001;
            attribute hardness = 45.0;
            attribute biocompatible = true;
            attribute nonPorousSurface = true;
            attribute integrity = MaterialState::intact;
        }

        part handle : Handle {
            attribute gripLength = 55.0;
            attribute gripDiameter = 24.0;
            attribute slipResistantTexture = true;
            attribute flangeDiameter = 42.0;
        }

        part marking : SizeMarking {
            attribute size = DilatorSize::medium;
            attribute visibleWhenHeld = true;
            attribute permanentMarking = true;
            attribute nominalDiameter = 28.0;
            attribute nominalLength = 150.0;
        }

        part case : ProtectiveCase {
            attribute internalLength = 180.0;
            attribute internalDiameter = 50.0;
            attribute vented = true;
            attribute cleanable = true;
        }

        part hygieneSurface : HygieneSurface {
            attribute surfaceClean = true;
            attribute compatibleWithSoapAndWater = true;
            attribute compatibleWithWaterBasedLubricant = true;
            attribute maximumCleaningTemperature = 45.0;
        }

        port handPort : HandInterfacePort;
        port bodyPort : BodyInterfacePort;
        port cleaningPort : CleaningPort;
        port storagePort : StoragePort;

        connect handPort to handle.handInterface;
        connect bodyPort to body.bodyInterface;
        connect cleaningPort to hygieneSurface.cleaningPort;
        connect storagePort to case.storagePort;

        constraint forceLimit {
            handPort.force.axialForce <= allowedAxialForce;
        }

        constraint speedLimit {
            handPort.force.insertionSpeed <= allowedInsertionSpeed;
        }

        constraint lubricantCompatibility {
            bodyPort.lubricant.compatibleWithSilicone == true;
        }
    }

    action def PrepareDilator {
        in cleaningAgent : CleaningAgent;
        in lubricant : WaterBasedLubricant;
        inout status : DilatorStatus;
        out prepared : Boolean;

        first start;
        then verifyIntegrity;
        then cleanSurface;
        then applyLubricant;
        then setPrepared;

        action verifyIntegrity {
            inout status : DilatorStatus;
        }

        action cleanSurface {
            in cleaningAgent : CleaningAgent;
            inout status : DilatorStatus;
        }

        action applyLubricant {
            in lubricant : WaterBasedLubricant;
            inout status : DilatorStatus;
        }

        action setPrepared {
            out prepared : Boolean;
        }
    }

    action def PerformGraduatedDilation {
        in selectedSize : DilatorSize;
        in appliedForce : UserAppliedForce;
        in lubricant : WaterBasedLubricant;
        in comfortFeedback : UserComfortFeedback;
        out completed : Boolean;
        out stopRequired : Boolean;

        first confirmPrepared;
        then beginGentleInsertion;
        then monitorComfort;
        then holdPosition;
        then removeDilator;
        then completeUse;

        action confirmPrepared;
        action beginGentleInsertion {
            in appliedForce : UserAppliedForce;
            in lubricant : WaterBasedLubricant;
        }
        action monitorComfort {
            in comfortFeedback : UserComfortFeedback;
            out stopRequired : Boolean;
        }
        action holdPosition;
        action removeDilator;
        action completeUse {
            out completed : Boolean;
        }

        constraint userControl {
            appliedForce.axialForce <= 10.0 and appliedForce.insertionSpeed <= 5.0;
        }

        constraint stopOnPain {
            comfortFeedback.stopRequested == false and comfortFeedback.painReported == false;
        }
    }

    action def CleanAndStoreDilator {
        in cleaningAgent : CleaningAgent;
        inout status : DilatorStatus;
        out stored : Boolean;

        first rinse;
        then wash;
        then inspect;
        then dry;
        then placeInCase;

        action rinse;
        action wash {
            in cleaningAgent : CleaningAgent;
        }
        action inspect {
            inout status : DilatorStatus;
        }
        action dry;
        action placeInCase {
            out stored : Boolean;
        }
    }

    state def DilatorUseStateMachine {
        entry action initialize {
            out initialStatus : DilatorStatus;
        }

        state Stored;
        state Prepared;
        state InUse;
        state HeldInPosition;
        state Removed;
        state Cleaning;
        state ReadyForStorage;
        state OutOfService;

        initial then Stored;

        transition prepare
            first Stored
            accept prepareCommand
            then Prepared;

        transition insert
            first Prepared
            accept gentleInsertionStarted
            then InUse;

        transition hold
            first InUse
            accept targetPositionReached
            then HeldInPosition;

        transition stopForComfort
            first InUse
            accept discomfortLimitReached
            then Removed;

        transition removeAfterUse
            first HeldInPosition
            accept useDurationComplete
            then Removed;

        transition clean
            first Removed
            accept cleaningStarted
            then Cleaning;

        transition dryAndInspect
            first Cleaning
            accept cleaningComplete
            then ReadyForStorage;

        transition store
            first ReadyForStorage
            accept placedInCase
            then Stored;

        transition rejectDamagedDevice
            first Cleaning
            accept damageDetected
            then OutOfService;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide a smooth, body-safe, manually controlled vaginal dilator that supports gradual accommodation of vaginal tissue at a high level by enabling prepared insertion, controlled positioning, removal, cleaning, and storage. */
    }

    requirement def BiocompatibilityRequirement {
        doc /* All patient-contacting surfaces shall be non-porous, biocompatible, and compatible with water-based lubricant. */
    }

    requirement def SmoothGeometryRequirement {
        doc /* The patient-contacting body shall have a rounded atraumatic tip and a smooth continuous surface to reduce localized pressure. */
    }

    requirement def ManualControlRequirement {
        doc /* The system shall allow the user or clinician to manually control insertion direction, insertion speed, axial force, and removal. */
    }

    requirement def GraduatedSizingRequirement {
        doc /* The system shall identify size by permanent marking and provide dimensions suitable for progressive use. */
    }

    requirement def HygieneRequirement {
        doc /* The system shall support cleaning before and after use with non-abrasive soap-and-water cleaning agents and protected storage in a cleanable case. */
    }

    requirement def ComfortStopRequirement {
        doc /* The dilation behavior shall allow use to stop immediately when pain, excessive discomfort, or user stop request is reported. */
    }

    requirement def StorageRequirement {
        doc /* The system shall include a protective storage case that limits contamination after cleaning and drying. */
    }

    satisfy PrimaryFunctionRequirement by VaginalDilatorSystem;
    satisfy BiocompatibilityRequirement by VaginalDilatorSystem::body;
    satisfy SmoothGeometryRequirement by VaginalDilatorSystem::body;
    satisfy ManualControlRequirement by VaginalDilatorSystem::handle;
    satisfy GraduatedSizingRequirement by VaginalDilatorSystem::marking;
    satisfy HygieneRequirement by VaginalDilatorSystem::hygieneSurface;
    satisfy StorageRequirement by VaginalDilatorSystem::case;
    satisfy ComfortStopRequirement by PerformGraduatedDilation;
}