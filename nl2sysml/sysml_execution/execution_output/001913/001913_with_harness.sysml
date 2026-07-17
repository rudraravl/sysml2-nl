package 'Degrees of Freedom System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def DOFCount :> Integer;

    item def SpatialPosition {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def SpatialOrientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    item def FullPose {
        attribute position : SpatialPosition;
        attribute orientation : SpatialOrientation;
    }

    item def JointConfiguration {
        attribute jointAngle : Real;
        attribute jointVelocity : Real;
        attribute jointAcceleration : Real;
        attribute appliedTorque : TorqueValue;
    }

    item def MotionCommand {
        attribute targetPose : FullPose;
        attribute movementDuration : TimeValue;
        attribute priority : Integer;
    }

    item def SystemStatus {
        attribute operationalState : String;
        attribute errorCode : Integer;
        attribute positionAccuracy : LengthValue;
    }

    port def CommandPort {
        in item motionCmd : MotionCommand;
        out item statusReport : SystemStatus;
    }

    port def SensorFeedbackPort {
        out item jointConfigs : JointConfiguration[6];
        out item endPose : FullPose;
    }

    port def ActuationPort {
        in item torqueCommands : TorqueValue[6];
        out item actualTorques : TorqueValue[6];
    }

    port def PowerPort {
        in item voltage : ElectricPotentialValue;
        in item current : ElectricCurrentValue;
    }

    part def RevoluteJoint {
        attribute jointID : Integer;
        attribute config : JointConfiguration;
        attribute minAngle : Real;
        attribute maxAngle : Real;
        attribute maxTorque : TorqueValue;
        attribute maxVelocity : Real;

        port actuator : ActuationPort;

        action applyTorque {
            in commandedTorque : TorqueValue;
            out resultingAcceleration : Real;
        }
    }

    part def StructuralLink {
        attribute linkID : Integer;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute inertia : Real;
        attribute centerOfMass : SpatialPosition;
    }

    part def PositionSensor {
        attribute sensorID : Integer;
        attribute resolution : Real;
        attribute samplingRate : FrequencyValue;

        port output : SensorFeedbackPort;

        action measureJointAngles {
            in joints : RevoluteJoint[6];
            out measurements : JointConfiguration[6];
        }
    }

    part def MotionPlanner {
        action planTrajectory {
            in startPose : FullPose;
            in targetPose : FullPose;
            in duration : TimeValue;
            out waypoints : FullPose[*];
        }

        action computeInverseKinematics {
            in desiredPose : FullPose;
            in currentConfigs : JointConfiguration[6];
            out targetAngles : Real[6];
        }
    }

    part def MotionController {
        attribute controlGain : Real;
        attribute dampingFactor : Real;

        port commandInterface : CommandPort;

        action computeControlTorques {
            in desiredAngles : Real[6];
            in currentConfigs : JointConfiguration[6];
            out torqueCommands : TorqueValue[6];
        }

        action monitorLimits {
            in configs : JointConfiguration[6];
            in joints : RevoluteJoint[6];
            out withinLimits : Boolean;
        }
    }

    part def EndEffector {
        attribute toolMass : MassValue;
        attribute currentPose : FullPose;
        attribute graspingForce : ForceValue;
        attribute toolOffset : SpatialPosition;
    }

    part def PowerSupply {
        attribute ratedVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute efficiency : Real;

        port powerOutput : PowerPort;
    }

    part def SixDOFManipulator {
        doc /* A six degree of freedom robotic manipulator system that provides 
               complete spatial positioning and orientation control of its end 
               effector through coordinated motion of six revolute joints. */

        attribute totalDOF : DOFCount = 6;
        attribute workspaceRadius : LengthValue = 1.5 [m];
        attribute maxPayload : MassValue = 15.0 [kg];

        part baseJoint : RevoluteJoint {
            :>> jointID = 1;
            :>> minAngle = -180.0;
            :>> maxAngle = 180.0;
            :>> maxTorque = 150.0 [N*m];
            :>> maxVelocity = 90.0;
        }

        part shoulderJoint : RevoluteJoint {
            :>> jointID = 2;
            :>> minAngle = -90.0;
            :>> maxAngle = 90.0;
            :>> maxTorque = 120.0 [N*m];
            :>> maxVelocity = 100.0;
        }

        part elbowJoint : RevoluteJoint {
            :>> jointID = 3;
            :>> minAngle = -150.0;
            :>> maxAngle = 150.0;
            :>> maxTorque = 100.0 [N*m];
            :>> maxVelocity = 120.0;
        }

        part wristRollJoint : RevoluteJoint {
            :>> jointID = 4;
            :>> minAngle = -180.0;
            :>> maxAngle = 180.0;
            :>> maxTorque = 60.0 [N*m];
            :>> maxVelocity = 150.0;
        }

        part wristPitchJoint : RevoluteJoint {
            :>> jointID = 5;
            :>> minAngle = -90.0;
            :>> maxAngle = 90.0;
            :>> maxTorque = 50.0 [N*m];
            :>> maxVelocity = 150.0;
        }

        part wristYawJoint : RevoluteJoint {
            :>> jointID = 6;
            :>> minAngle = -180.0;
            :>> maxAngle = 180.0;
            :>> maxTorque = 40.0 [N*m];
            :>> maxVelocity = 180.0;
        }

        part baseLink : StructuralLink {
            :>> linkID = 1;
            :>> mass = 8.0 [kg];
            :>> length = 0.3 [m];
        }

        part upperArmLink : StructuralLink {
            :>> linkID = 2;
            :>> mass = 6.0 [kg];
            :>> length = 0.6 [m];
        }

        part forearmLink : StructuralLink {
            :>> linkID = 3;
            :>> mass = 4.0 [kg];
            :>> length = 0.5 [m];
        }

        part wristLink : StructuralLink {
            :>> linkID = 4;
            :>> mass = 2.0 [kg];
            :>> length = 0.2 [m];
        }

        part endEffector : EndEffector {
            :>> toolMass = 1.5 [kg];
            :>> graspingForce = 100.0 [N];
        }

        part jointSensors : PositionSensor {
            :>> samplingRate = 200.0 [Hz];
            :>> resolution = 0.01;
        }

        part planner : MotionPlanner;

        part controller : MotionController {
            :>> controlGain = 50.0;
            :>> dampingFactor = 0.7;
        }

        part powerSupply : PowerSupply {
            :>> ratedVoltage = 48.0 [V];
            :>> maxCurrent = 40.0 [A];
            :>> efficiency = 0.92;
        }

        connection baseToPower connect powerSupply.powerOutput to baseJoint.actuator;
        connection shoulderToPower connect powerSupply.powerOutput to shoulderJoint.actuator;
        connection elbowToPower connect powerSupply.powerOutput to elbowJoint.actuator;
        connection wristRollToPower connect powerSupply.powerOutput to wristRollJoint.actuator;
        connection wristPitchToPower connect powerSupply.powerOutput to wristPitchJoint.actuator;
        connection wristYawToPower connect powerSupply.powerOutput to wristYawJoint.actuator;

        connection sensorFeedback connect jointSensors.output to controller.commandInterface;

        connection baseToUpperArm connect baseJoint to upperArmLink;
        connection shoulderToForearm connect shoulderJoint to forearmLink;
        connection elbowToWrist connect elbowJoint to wristLink;
        connection wristToEndEffector connect wristYawJoint to endEffector;
    }

    action def SenseJointStates {
        in joints : RevoluteJoint[6];
        out configurations : JointConfiguration[6];
    }

    action def ValidateMotionCommand {
        in command : MotionCommand;
        in currentPose : FullPose;
        in workspaceLimit : LengthValue;
        out isValid : Boolean;
        out errorMessage : String;
    }

    action def ExecutePositioning {
        in manipulator : SixDOFManipulator;
        in targetPose : FullPose;
        out success : Boolean;

        first start;
        then merge controlLoop;

        then action sense : SenseJointStates {
            in joints = (manipulator.baseJoint, manipulator.shoulderJoint, 
                        manipulator.elbowJoint, manipulator.wristRollJoint,
                        manipulator.wristPitchJoint, manipulator.wristYawJoint);
            out currentConfigs : JointConfiguration[6];
        }

        then action validate : ValidateMotionCommand {
            in command.targetPose = targetPose;
            in currentPose = manipulator.endEffector.currentPose;
            in workspaceLimit = manipulator.workspaceRadius;
            out isValid;
            out errorMessage;
        }

        then decide;
            if validate.isValid then planMotion;
            if not validate.isValid then abortMotion;

        action planMotion : SixDOFManipulator::MotionPlanner::planTrajectory {
            in startPose = manipulator.endEffector.currentPose;
            in targetPose = targetPose;
            in duration = 2.0 [s];
            out waypoints;
        }

        then action computeIK : SixDOFManipulator::MotionPlanner::computeInverseKinematics {
            in desiredPose = targetPose;
            in currentConfigs = sense.currentConfigs;
            out targetAngles;
        }

        then action computeControl : SixDOFManipulator::MotionController::computeControlTorques {
            in desiredAngles = computeIK.targetAngles;
            in currentConfigs = sense.currentConfigs;
            out torqueCommands;
        }

        then action checkLimits : SixDOFManipulator::MotionController::monitorLimits {
            in configs = sense.currentConfigs;
            in joints = (manipulator.baseJoint, manipulator.shoulderJoint,
                        manipulator.elbowJoint, manipulator.wristRollJoint,
                        manipulator.wristPitchJoint, manipulator.wristYawJoint);
            out withinLimits;
        }

        then decide;
            if checkLimits.withinLimits and not poseReached then controlLoop;
            if poseReached then completeMotion;
            if not checkLimits.withinLimits then emergencyStop;

        action abortMotion {
            out success = false;
        }
        then done;

        action emergencyStop {
            out success = false;
        }
        then done;

        action completeMotion {
            out success = true;
        }
        then done;
    }

    state def ManipulatorOperationalState {
        entry; then idle;

        state idle {
            doc /* System is powered and ready to receive commands. */
        }
        accept commandReceived;
        then validating;

        state validating {
            entry action validateCommand : ValidateMotionCommand;
        }
        if validateCommand.isValid then planning;
        if not validateCommand.isValid then error;

        state planning {
            entry action planPath : SixDOFManipulator::MotionPlanner::planTrajectory;
        }
        then executing;

        state executing {
            doc /* Actively moving joints to achieve target pose. */
            do action executeMotion : ExecutePositioning;
        }
        if executeMotion.success then idle;
        if not executeMotion.success then error;

        state error {
            doc /* System has encountered an error and requires intervention. */
        }
        accept resetCommand;
        then idle;
    }

    part manipulatorSystem : SixDOFManipulator {
        perform action operateManipulator[*] ordered {
            in targetPose : FullPose;

            first start;
            then action positioning : ExecutePositioning {
                in manipulator = manipulatorSystem;
                in targetPose = targetPose;
                out success;
            }
            then done;
        }

        exhibit state operationalBehavior : ManipulatorOperationalState;
    }

    requirement def DOFRequirement {
        doc /* The manipulator shall provide six independent degrees of freedom 
               for complete spatial positioning and orientation control. */

        subject system : SixDOFManipulator;

        require constraint {
            system.totalDOF == 6
        }
    }

    requirement def WorkspaceRequirement {
        doc /* The manipulator shall reach any point within its defined 
               spherical workspace radius. */

        attribute minReach : LengthValue = 0.5 [m];
        attribute maxReach : LengthValue = 1.5 [m];

        subject system : SixDOFManipulator;

        require constraint {
            system.workspaceRadius >= minReach and
            system.workspaceRadius <= maxReach
        }
    }

    requirement def PositioningAccuracyRequirement {
        doc /* The end effector shall achieve positioning accuracy within 
               specified tolerance. */

        attribute maxPositionError : LengthValue = 0.5 [mm];
        attribute maxOrientationError : Real = 0.1;

        subject system : SixDOFManipulator;
    }

    requirement def PayloadCapacityRequirement {
        doc /* The manipulator shall handle payloads up to the specified 
               maximum mass. */

        attribute requiredPayload : MassValue = 15.0 [kg];

        subject system : SixDOFManipulator;

        require constraint {
            system.maxPayload >= requiredPayload
        }
    }

    requirement def SafetyRequirement {
        doc /* All joint motions shall remain within defined mechanical limits 
               to prevent damage and ensure safe operation. */

        subject system : SixDOFManipulator;

        require constraint {
            system.baseJoint.config.jointAngle >= system.baseJoint.minAngle and
            system.baseJoint.config.jointAngle <= system.baseJoint.maxAngle and
            system.shoulderJoint.config.jointAngle >= system.shoulderJoint.minAngle and
            system.shoulderJoint.config.jointAngle <= system.shoulderJoint.maxAngle and
            system.elbowJoint.config.jointAngle >= system.elbowJoint.minAngle and
            system.elbowJoint.config.jointAngle <= system.elbowJoint.maxAngle
        }
    }

    requirement <'DOF-SYS-001'> systemRequirements {
        doc /* The six degree of freedom manipulator system shall provide precise, 
               safe, and reliable positioning and orientation control of its end 
               effector throughout its operational workspace. */

        subject system : SixDOFManipulator;

        assume constraint powerAvailable {
            system.powerSupply.ratedVoltage >= 48.0 [V] and
            system.powerSupply.maxCurrent >= 30.0 [A]
        }

        require dofReq : DOFRequirement {
            :>> system = system;
        }

        require workspaceReq : WorkspaceRequirement {
            :>> system = system;
        }

        require accuracyReq : PositioningAccuracyRequirement {
            :>> system = system;
        }

        require payloadReq : PayloadCapacityRequirement {
            :>> system = system;
        }

        require safetyReq : SafetyRequirement {
            :>> system = system;
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Degrees of Freedom System'::*;

    part manipulatorSystem : RevoluteJoint {
        exhibit state sm : ManipulatorOperationalState;
    }

    action orchestrator {
        action planMotionProbe : SixDOFManipulator {
            // TODO(human): unsupported input type for startPose: unknown (missing declared type)
            // TODO(human): unsupported input type for targetPose: unknown (missing declared type)
            // TODO(human): unsupported input type for duration: unknown (missing declared type)
        }
        first planMotionProbe;
    }
}
