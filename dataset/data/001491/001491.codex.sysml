package ManumationSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        doc /* Ratio expressed from 0.0 to 100.0 percent. */
    }

    attribute def Confidence :> Real {
        doc /* Probability-like confidence from 0.0 to 1.0. */
    }

    attribute def Identifier :> String;
    attribute def StatusText :> String;

    enum def OperatingMode {
        enum idle;
        enum manualGuidance;
        enum sharedControl;
        enum automatedExecution;
        enum hold;
        enum faultRecovery;
        enum shutdown;
    }

    enum def SafetyState {
        enum safe;
        enum warning;
        enum protectiveStop;
        enum emergencyStop;
    }

    enum def WorkpieceState {
        enum absent;
        enum loaded;
        enum aligned;
        enum processed;
        enum verified;
        enum rejected;
        enum unloaded;
    }

    enum def CommandIntent {
        enum startCycle;
        enum stopCycle;
        enum pauseCycle;
        enum resumeCycle;
        enum adjustTarget;
        enum acceptRecommendation;
        enum rejectRecommendation;
        enum requestManualOverride;
        enum acknowledgeFault;
    }

    enum def QualityDisposition {
        enum pass;
        enum rework;
        enum fail;
        enum unknown;
    }

    item def Workpiece {
        attribute serialNumber : Identifier;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute state : WorkpieceState;
        attribute qualityDisposition : QualityDisposition;
    }

    item def OperatorCommand {
        attribute commandId : Identifier;
        attribute intent : CommandIntent;
        attribute targetStation : Identifier;
        attribute priority : Integer;
        attribute issuedTime : TimeValue;
    }

    item def MotionPlan {
        attribute planId : Identifier;
        attribute targetPoseX : LengthValue;
        attribute targetPoseY : LengthValue;
        attribute targetPoseZ : LengthValue;
        attribute targetYaw : PlaneAngleValue;
        attribute nominalSpeed : SpeedValue;
        attribute maximumForce : ForceValue;
        attribute confidence : Confidence;
    }

    item def SensorObservation {
        attribute observationId : Identifier;
        attribute sourceId : Identifier;
        attribute measuredTime : TimeValue;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute appliedForce : ForceValue;
        attribute temperature : TemperatureValue;
        attribute presenceConfidence : Confidence;
    }

    item def SafetySignal {
        attribute safetyState : SafetyState;
        attribute stopRequested : Boolean;
        attribute safeSpeedLimit : SpeedValue;
        attribute safeForceLimit : ForceValue;
        attribute message : StatusText;
    }

    item def ProcessResult {
        attribute workpieceSerialNumber : Identifier;
        attribute cycleTime : TimeValue;
        attribute peakForce : ForceValue;
        attribute finalDisposition : QualityDisposition;
        attribute measuredError : LengthValue;
        attribute operatorInterventionRequired : Boolean;
    }

    port def HumanInterfacePort {
        in item command : OperatorCommand;
        out item recommendation : MotionPlan;
        out item status : SafetySignal;
        out item result : ProcessResult;
    }

    port def WorkpieceFlowPort {
        inout item workpiece : Workpiece;
    }

    port def ObservationPort {
        out item observation : SensorObservation;
    }

    port def PlanPort {
        out item plan : MotionPlan;
        in item command : OperatorCommand;
    }

    port def SafetyPort {
        inout item safety : SafetySignal;
    }

    port def ActuationPort {
        in item plan : MotionPlan;
        in item safety : SafetySignal;
        out item observation : SensorObservation;
    }

    port def DataPort {
        inout item command : OperatorCommand;
        inout item observation : SensorObservation;
        inout item plan : MotionPlan;
        inout item result : ProcessResult;
    }

    action def InterpretOperatorIntent {
        in item command : OperatorCommand;
        in item currentObservation : SensorObservation;
        out item interpretedPlan : MotionPlan;
    }

    action def GenerateAssistedMotionPlan {
        in item workpiece : Workpiece;
        in item observation : SensorObservation;
        in attribute targetThroughput : Real;
        out item plan : MotionPlan;
    }

    action def BlendHumanAndAutomatedControl {
        in item operatorCommand : OperatorCommand;
        in item automatedPlan : MotionPlan;
        in attribute assistanceLevel : Percent;
        out item sharedPlan : MotionPlan;
    }

    action def ExecuteConstrainedMotion {
        in item plan : MotionPlan;
        in item safety : SafetySignal;
        out item observation : SensorObservation;
    }

    action def VerifyWorkpieceQuality {
        in item workpiece : Workpiece;
        in item observation : SensorObservation;
        out item result : ProcessResult;
    }

    action def EnterProtectiveStop {
        in item triggeringSignal : SafetySignal;
        out item safeSignal : SafetySignal;
    }

    action def RecoverFromFault {
        in item command : OperatorCommand;
        in item safety : SafetySignal;
        out item recoveredSignal : SafetySignal;
    }

    state def ManumationOperatingStateMachine {
        in item command : OperatorCommand;
        in item safety : SafetySignal;
        in item workpiece : Workpiece;

        state idle;
        state manualGuidance;
        state sharedControl;
        state automatedExecution;
        state hold;
        state protectiveStop;
        state faultRecovery;
        state shutdown;

        transition first idle;

        transition idle_to_manual
            first idle
            then manualGuidance
            if command.intent == CommandIntent::requestManualOverride;

        transition idle_to_shared
            first idle
            then sharedControl
            if command.intent == CommandIntent::startCycle and workpiece.state == WorkpieceState::loaded;

        transition shared_to_auto
            first sharedControl
            then automatedExecution
            if command.intent == CommandIntent::acceptRecommendation and safety.safetyState == SafetyState::safe;

        transition auto_to_shared
            first automatedExecution
            then sharedControl
            if command.intent == CommandIntent::adjustTarget;

        transition running_to_hold_from_shared
            first sharedControl
            then hold
            if command.intent == CommandIntent::pauseCycle;

        transition running_to_hold_from_auto
            first automatedExecution
            then hold
            if command.intent == CommandIntent::pauseCycle;

        transition hold_to_shared
            first hold
            then sharedControl
            if command.intent == CommandIntent::resumeCycle;

        transition any_to_protective_stop_from_manual
            first manualGuidance
            then protectiveStop
            if safety.stopRequested == true;

        transition any_to_protective_stop_from_shared
            first sharedControl
            then protectiveStop
            if safety.stopRequested == true;

        transition any_to_protective_stop_from_auto
            first automatedExecution
            then protectiveStop
            if safety.stopRequested == true;

        transition protective_stop_to_recovery
            first protectiveStop
            then faultRecovery
            if command.intent == CommandIntent::acknowledgeFault;

        transition recovery_to_idle
            first faultRecovery
            then idle
            if safety.safetyState == SafetyState::safe;

        transition stop_to_shutdown_from_idle
            first idle
            then shutdown
            if command.intent == CommandIntent::stopCycle;

        transition stop_to_shutdown_from_hold
            first hold
            then shutdown
            if command.intent == CommandIntent::stopCycle;
    }

    part def Operator {
        attribute operatorId : Identifier;
        attribute certifiedForManualOverride : Boolean;
        attribute maximumSustainedCommandRate : Real;
        port interface : HumanInterfacePort;
    }

    part def HumanMachineInterface {
        attribute displayLatency : TimeValue;
        attribute hapticFeedbackEnabled : Boolean;
        attribute alarmVolume : Real;
        port operatorSide : HumanInterfacePort;
        port controllerSide : DataPort;
    }

    part def PerceptionSubsystem {
        attribute cameraFrameRate : Real;
        attribute forceSampleRate : Real;
        attribute poseAccuracy : LengthValue;
        port workcellObservation : ObservationPort;
        port data : DataPort;
    }

    part def AssistanceController {
        attribute currentMode : OperatingMode;
        attribute assistanceLevel : Percent;
        attribute targetThroughput : Real;
        attribute minimumPlanConfidence : Confidence;
        port humanData : DataPort;
        port sensorData : DataPort;
        port actuatorData : ActuationPort;
        port safetyData : SafetyPort;

        action interpretIntent : InterpretOperatorIntent;
        action generatePlan : GenerateAssistedMotionPlan;
        action blendControl : BlendHumanAndAutomatedControl;
        action executeMotion : ExecuteConstrainedMotion;

        behavior operatingBehavior : ManumationOperatingStateMachine;
    }

    part def CollaborativeManipulator {
        attribute payloadCapacity : MassValue;
        attribute maximumReach : LengthValue;
        attribute maximumSpeed : SpeedValue;
        attribute forceLimit : ForceValue;
        attribute positionRepeatability : LengthValue;
        port actuator : ActuationPort;
        port safety : SafetyPort;
        port toolPort : WorkpieceFlowPort;
    }

    part def EndEffector {
        attribute gripForce : ForceValue;
        attribute openingWidth : LengthValue;
        attribute toolMass : MassValue;
        port manipulatorSide : WorkpieceFlowPort;
        port workpieceSide : WorkpieceFlowPort;
    }

    part def WorkholdingFixture {
        attribute fixtureId : Identifier;
        attribute clampForce : ForceValue;
        attribute alignmentTolerance : LengthValue;
        port input : WorkpieceFlowPort;
        port output : WorkpieceFlowPort;
        port safety : SafetyPort;
    }

    part def SafetySupervisor {
        attribute emergencyStopResponseTime : TimeValue;
        attribute protectiveStopResponseTime : TimeValue;
        attribute allowedHumanRobotSeparation : LengthValue;
        attribute currentSafetyState : SafetyState;
        port controllerSafety : SafetyPort;
        port manipulatorSafety : SafetyPort;
        port fixtureSafety : SafetyPort;
        port hmiSafety : HumanInterfacePort;

        action stopAction : EnterProtectiveStop;
        action recoveryAction : RecoverFromFault;
    }

    part def QualityStation {
        attribute measurementResolution : LengthValue;
        attribute acceptedErrorLimit : LengthValue;
        attribute inspectionTime : TimeValue;
        port input : WorkpieceFlowPort;
        port observation : ObservationPort;
        port resultData : DataPort;

        action verifyQuality : VerifyWorkpieceQuality;
    }

    part def ProductionDataLogger {
        attribute retentionPeriod : TimeValue;
        attribute sampleCompressionRatio : Real;
        port processData : DataPort;
    }

    part def ManumationCell {
        doc /* A manumation cell combines human skill and automated assistance so an operator can guide, approve, and override work while the system plans, constrains, executes, verifies, and records repeatable production actions. */

        attribute systemId : Identifier = "MANUMATION-CELL-01";
        attribute primaryFunction : StatusText = "Assist a human operator in performing precision workpiece handling and processing by blending manual intent with automated motion planning, safety supervision, and quality verification.";
        attribute ratedThroughputPerHour : Real = 48.0;
        attribute nominalCycleTime : TimeValue;
        attribute nominalAssistanceLevel : Percent = 65.0;
        attribute maximumWorkpieceMass : MassValue;
        attribute requiredPoseAccuracy : LengthValue;
        attribute currentMode : OperatingMode;
        attribute currentSafetyState : SafetyState;

        port operatorInterface : HumanInterfacePort;
        port materialInput : WorkpieceFlowPort;
        port materialOutput : WorkpieceFlowPort;
        port enterpriseData : DataPort;

        part operator : Operator {
            attribute certifiedForManualOverride = true;
        }

        part hmi : HumanMachineInterface {
            attribute hapticFeedbackEnabled = true;
        }

        part perception : PerceptionSubsystem;

        part controller : AssistanceController {
            attribute assistanceLevel = 65.0;
            attribute minimumPlanConfidence = 0.92;
            attribute targetThroughput = 48.0;
        }

        part manipulator : CollaborativeManipulator;

        part endEffector : EndEffector;

        part fixture : WorkholdingFixture;

        part safetySupervisor : SafetySupervisor;

        part qualityStation : QualityStation;

        part logger : ProductionDataLogger;

        connect operator.interface to hmi.operatorSide;
        connect hmi.controllerSide to controller.humanData;
        connect perception.data to controller.sensorData;
        connect controller.actuatorData to manipulator.actuator;
        connect controller.safetyData to safetySupervisor.controllerSafety;
        connect safetySupervisor.manipulatorSafety to manipulator.safety;
        connect safetySupervisor.fixtureSafety to fixture.safety;
        connect safetySupervisor.hmiSafety to hmi.operatorSide;
        connect materialInput to fixture.input;
        connect fixture.output to endEffector.workpieceSide;
        connect endEffector.manipulatorSide to manipulator.toolPort;
        connect manipulator.toolPort to qualityStation.input;
        connect qualityStation.resultData to logger.processData;
        connect qualityStation.resultData to enterpriseData;
        connect qualityStation.input to materialOutput;
        connect perception.workcellObservation to qualityStation.observation;

        perform action nominalCycle {
            in item incomingWorkpiece : Workpiece;
            out item completedResult : ProcessResult;

            action receiveWorkpiece;
            action observeWorkcell : GenerateAssistedMotionPlan;
            action interpretCommand : InterpretOperatorIntent;
            action blendMotion : BlendHumanAndAutomatedControl;
            action executeAssistedMotion : ExecuteConstrainedMotion;
            action inspectResult : VerifyWorkpieceQuality;

            first start;
            then receiveWorkpiece;
            then observeWorkcell;
            then interpretCommand;
            then blendMotion;
            then executeAssistedMotion;
            then inspectResult;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject cell : ManumationCell;
        doc /* The system shall provide manumation by combining operator judgment with automated planning and constrained motion execution to process workpieces safely and repeatably. */
        require constraint {
            cell.nominalAssistanceLevel >= 30.0 and
            cell.nominalAssistanceLevel <= 90.0
        }
    }

    requirement def HumanAuthorityRequirement {
        subject cell : ManumationCell;
        doc /* The operator shall be able to pause, stop, or manually override assisted operation whenever the cell is not in emergency stop. */
        require constraint {
            cell.currentSafetyState != SafetyState::emergencyStop
        }
    }

    requirement def SafetyResponseRequirement {
        subject supervisor : SafetySupervisor;
        doc /* The safety supervisor shall command a protective stop within 250 milliseconds when a stop request or unsafe separation condition is detected. */
        require constraint {
            supervisor.protectiveStopResponseTime <= 0.250 [s]
        }
    }

    requirement def AssistedMotionAccuracyRequirement {
        subject manipulator : CollaborativeManipulator;
        doc /* The collaborative manipulator shall maintain end-effector repeatability sufficient for precision assisted work. */
        require constraint {
            manipulator.positionRepeatability <= 0.0005 [m]
        }
    }

    requirement def ForceLimitingRequirement {
        subject manipulator : CollaborativeManipulator;
        doc /* The manipulator shall limit contact force during shared-control and manual-guidance operation. */
        require constraint {
            manipulator.forceLimit <= 150 [N]
        }
    }

    requirement def QualityVerificationRequirement {
        subject station : QualityStation;
        doc /* The quality station shall classify each processed workpiece against the accepted dimensional error limit before unload. */
        require constraint {
            station.acceptedErrorLimit <= 0.001 [m]
        }
    }

    requirement def TraceabilityRequirement {
        subject logger : ProductionDataLogger;
        doc /* The production data logger shall retain operator commands, sensor observations, plans, and process results for traceability. */
        require constraint {
            logger.retentionPeriod >= 15552000 [s]
        }
    }

    requirement def ThroughputRequirement {
        subject cell : ManumationCell;
        doc /* The manumation cell shall support at least forty completed workpieces per hour during nominal assisted operation. */
        require constraint {
            cell.ratedThroughputPerHour >= 40.0
        }
    }

    satisfy PrimaryFunctionRequirement by ManumationCell;
    satisfy HumanAuthorityRequirement by ManumationCell;
    satisfy SafetyResponseRequirement by SafetySupervisor;
    satisfy AssistedMotionAccuracyRequirement by CollaborativeManipulator;
    satisfy ForceLimitingRequirement by CollaborativeManipulator;
    satisfy QualityVerificationRequirement by QualityStation;
    satisfy TraceabilityRequirement by ProductionDataLogger;
    satisfy ThroughputRequirement by ManumationCell;

    part manumationProductionCell : ManumationCell {
        attribute nominalCycleTime = 75 [s];
        attribute maximumWorkpieceMass = 12 [kg];
        attribute requiredPoseAccuracy = 0.001 [m];
        attribute currentMode = OperatingMode::idle;
        attribute currentSafetyState = SafetyState::safe;

        part manipulator {
            attribute payloadCapacity = 15 [kg];
            attribute maximumReach = 1.35 [m];
            attribute maximumSpeed = 1.2 [m/s];
            attribute forceLimit = 120 [N];
            attribute positionRepeatability = 0.0003 [m];
        }

        part endEffector {
            attribute gripForce = 85 [N];
            attribute openingWidth = 0.16 [m];
            attribute toolMass = 3.2 [kg];
        }

        part fixture {
            attribute fixtureId = "FIXTURE-A";
            attribute clampForce = 450 [N];
            attribute alignmentTolerance = 0.0008 [m];
        }

        part safetySupervisor {
            attribute emergencyStopResponseTime = 0.080 [s];
            attribute protectiveStopResponseTime = 0.180 [s];
            attribute allowedHumanRobotSeparation = 0.45 [m];
            attribute currentSafetyState = SafetyState::safe;
        }

        part qualityStation {
            attribute measurementResolution = 0.0001 [m];
            attribute acceptedErrorLimit = 0.0008 [m];
            attribute inspectionTime = 6 [s];
        }

        part logger {
            attribute retentionPeriod = 31536000 [s];
            attribute sampleCompressionRatio = 4.0;
        }

        part perception {
            attribute cameraFrameRate = 60.0;
            attribute forceSampleRate = 1000.0;
            attribute poseAccuracy = 0.0006 [m];
        }

        part hmi {
            attribute displayLatency = 0.050 [s];
            attribute alarmVolume = 72.0;
        }
    }
}