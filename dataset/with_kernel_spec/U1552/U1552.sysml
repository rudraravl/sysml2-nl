package '6-DOF Robotic Arm' {
    private import ScalarValues::*;

    package Definitions {
        attribute def AngleValue :> Real { unit = "deg"; }
        attribute def TorqueValue :> Real { unit = "N*m"; }
        attribute def ForceValue :> Real { unit = "N"; }
        attribute def VoltageValue :> Real { unit = "V"; }
        attribute def AngularVelocityValue :> Real { unit = "deg/s"; }
        attribute def AngularAccelerationValue :> Real { unit = "deg/s^2"; }
        attribute def MassValue :> Real { unit = "kg"; }
        attribute def LengthValue :> Real { unit = "m"; }

        item def TargetPose {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
            attribute roll : AngleValue;
            attribute pitch : AngleValue;
            attribute yaw : AngleValue;
        }
        item def Waypoint :> TargetPose;
        item def JointState {
            attribute angle : AngleValue;
            attribute velocity : AngularVelocityValue;
            attribute acceleration : AngularAccelerationValue;
        }
        item def JointTorque {
            attribute torque : TorqueValue;
        }
        item def MotionCommand {
            attribute targetPose : TargetPose;
        }
        item def GraspCommand {
            attribute graspForce : ForceValue;
        }
        item def SafetyStatus {
            attribute isSafe : Boolean;
            attribute statusMessage : String;
        }

        port def MotionCommandPort {
            in cmd : MotionCommand;
        }
        port def WaypointsPort {
            out waypoints : Waypoint[*];
            in waypoints : Waypoint[*];
        }
        port def TorquePort {
            out torque : JointTorque;
            in torque : JointTorque;
        }
        port def JointStatePort {
            out jointState : JointState;
            in jointState : JointState;
        }
        port def PowerPort {
            out voltage : VoltageValue;
            in voltage : VoltageValue;
        }
        port def GraspPort {
            out graspCmd : GraspCommand;
            in graspCmd : GraspCommand;
        }
        port def SafetyPort {
            out safetyStatus : SafetyStatus;
        }

        part def Actuator {
            port torqueIn : TorquePort;
            port powerIn : PowerPort;
            attribute maxTorque : TorqueValue;
            perform action applyTorque {
                in cmd : JointTorque;
                out applied : TorqueValue;
            }
        }
        part def PositionSensor {
            port stateOut : JointStatePort;
            attribute resolution : AngleValue;
            perform action readState {
                out angle : AngleValue;
                out velocity : AngularVelocityValue;
                out acceleration : AngularAccelerationValue;
            }
        }
        part def Joint {
            attribute name : String;
            attribute minAngle : AngleValue;
            attribute maxAngle : AngleValue;
            attribute maxTorque : TorqueValue;
            part actuator : Actuator;
            part sensor : PositionSensor;
            port torqueIn : TorquePort;
            port stateOut : JointStatePort;
            port powerIn : PowerPort;
        }
        part def Link {
            attribute mass : MassValue;
            attribute length : LengthValue;
        }
        part def EndEffector {
            attribute maxGraspForce : ForceValue;
            port graspCmdIn : GraspPort;
            perform action grasp {
                in cmd : GraspCommand;
                out status : Boolean;
            }
        }

        action def ValidateTarget {
            in target : TargetPose;
            out isValid : Boolean;
        }
        action def SolveInverseKinematics {
            in target : TargetPose;
            out jointAngles : AngleValue[6];
        }
        action def GenerateWaypoints {
            in jointAngles : AngleValue[6];
            out waypoints : Waypoint[*];
        }
        action def PlanMotion {
            in cmd : MotionCommand;
            out waypoints : Waypoint[*];
            perform action validateTarget : ValidateTarget;
            perform action solveIK : SolveInverseKinematics;
            perform action generateWaypoints : GenerateWaypoints;
            first validateTarget;
            then solveIK;
            then generateWaypoints;
        }
        action def ComputeError {
            in target : Waypoint;
            in current : JointState[6];
            out error : JointState[6];
        }
        action def ApplyControlLaw {
            in error : JointState[6];
            out torques : JointTorque[6];
        }
        action def ControlMotion {
            in waypoints : Waypoint[*];
            in states : JointState[6];
            out torques : JointTorque[6];
            perform action computeError : ComputeError;
            perform action applyControlLaw : ApplyControlLaw;
            first computeError;
            then applyControlLaw;
        }
        action def MonitorSafety {
            in states : JointState[6];
            in limits : AngleValue[6];
            in maxTorques : TorqueValue[6];
            out status : SafetyStatus;
        }

        part def MotionPlanner {
            port motionCmdIn : MotionCommandPort;
            port waypointsOut : WaypointsPort;
            attribute maxPayload : MassValue = 15;
            attribute workspaceRadius : LengthValue = 1.5;
            perform action planMotion : PlanMotion {
                in cmd = motionCmdIn.cmd;
                out waypoints = waypointsOut.waypoints;
            }
        }
        part def MotionController {
            port waypointsIn : WaypointsPort;
            port torqueOutBase : TorquePort;
            port torqueOutShoulder : TorquePort;
            port torqueOutElbow : TorquePort;
            port torqueOutWristRoll : TorquePort;
            port torqueOutWristPitch : TorquePort;
            port torqueOutWristYaw : TorquePort;
            port stateInBase : JointStatePort;
            port stateInShoulder : JointStatePort;
            port stateInElbow : JointStatePort;
            port stateInWristRoll : JointStatePort;
            port stateInWristPitch : JointStatePort;
            port stateInWristYaw : JointStatePort;
            port graspCmdOut : GraspPort;
            port safetyOut : SafetyPort;
            port powerIn : PowerPort;
            perform action controlMotion : ControlMotion {
                in waypoints = waypointsIn.waypoints;
            }
            perform action monitorSafety : MonitorSafety;
        }
        part def PowerSupply {
            attribute nominalVoltage : VoltageValue = 48;
            port powerOut : PowerPort;
        }

        attribute def MotionComplete;
        attribute def SafetyViolation;
        attribute def ResetCommand;
        attribute def PlanComplete;

        part def RoboticArm {
            attribute maxPayload : MassValue = 15;
            attribute workspaceRadius : LengthValue = 1.5;

            part baseJoint : Joint {
                :>> name = "Base";
                :>> minAngle = -180;
                :>> maxAngle = 180;
                :>> maxTorque = 200;
            }
            part shoulderJoint : Joint {
                :>> name = "Shoulder";
                :>> minAngle = -90;
                :>> maxAngle = 90;
                :>> maxTorque = 250;
            }
            part elbowJoint : Joint {
                :>> name = "Elbow";
                :>> minAngle = -135;
                :>> maxAngle = 0;
                :>> maxTorque = 150;
            }
            part wristRollJoint : Joint {
                :>> name = "WristRoll";
                :>> minAngle = -180;
                :>> maxAngle = 180;
                :>> maxTorque = 50;
            }
            part wristPitchJoint : Joint {
                :>> name = "WristPitch";
                :>> minAngle = -90;
                :>> maxAngle = 90;
                :>> maxTorque = 50;
            }
            part wristYawJoint : Joint {
                :>> name = "WristYaw";
                :>> minAngle = -180;
                :>> maxAngle = 180;
                :>> maxTorque = 50;
            }

            part upperArm : Link {
                :>> mass = 8.0;
                :>> length = 0.6;
            }
            part forearm : Link {
                :>> mass = 5.0;
                :>> length = 0.5;
            }
            part wristLink : Link {
                :>> mass = 1.5;
                :>> length = 0.2;
            }

            part endEffector : EndEffector {
                :>> maxGraspForce = 100;
            }

            part motionPlanner : MotionPlanner;
            part motionController : MotionController;
            part powerSupply : PowerSupply;

            exhibit state armStates {
                entry; then idle;
                state idle;
                accept cmd : MotionCommand
                    if cmd.targetPose.x*cmd.targetPose.x + cmd.targetPose.y*cmd.targetPose.y + cmd.targetPose.z*cmd.targetPose.z <= 1.5 * 1.5
                    then planning;
                state planning {
                    do motionPlanner.planMotion;
                }
                transition planning_to_executing
                    first planning
                    accept PlanComplete
                    then executing;
                state executing {
                    do motionController.controlMotion;
                }
                accept MotionComplete then idle;
                accept SafetyViolation then error;
                state error;
                accept ResetCommand then idle;
            }
        }

        requirement def PayloadRequirement {
            doc /* The system shall handle a maximum payload of 15 kilograms. */
            attribute maxPayload : MassValue = 15;
        }
        requirement def WorkspaceRequirement {
            doc /* The system shall operate within a workspace radius of 1.5 meters. */
            attribute workspaceRadius : LengthValue = 1.5;
        }
        requirement def DOFRequirement {
            doc /* The arm shall provide six degrees of freedom for independent control of position and orientation. */
            attribute degreesOfFreedom : Integer = 6;
        }
        requirement def PowerSupplyRequirement {
            doc /* The system shall be powered by a dedicated 48-volt power supply. */
            attribute supplyVoltage : VoltageValue = 48;
        }
        requirement def SafetyMonitoringRequirement {
            doc /* The controller shall continuously monitor joint limits and halt on safety violations. */
        }
    }

    package Usages {
        private import Definitions::*;

        part roboticArm : RoboticArm {
            flow waypointsFlow of Waypoint
                from motionPlanner.waypointsOut.waypoints
                to motionController.waypointsIn.waypoints;

            flow torqueFlowBase of JointTorque
                from motionController.torqueOutBase.torque
                to baseJoint.torqueIn.torque;
            flow torqueFlowShoulder of JointTorque
                from motionController.torqueOutShoulder.torque
                to shoulderJoint.torqueIn.torque;
            flow torqueFlowElbow of JointTorque
                from motionController.torqueOutElbow.torque
                to elbowJoint.torqueIn.torque;
            flow torqueFlowWristRoll of JointTorque
                from motionController.torqueOutWristRoll.torque
                to wristRollJoint.torqueIn.torque;
            flow torqueFlowWristPitch of JointTorque
                from motionController.torqueOutWristPitch.torque
                to wristPitchJoint.torqueIn.torque;
            flow torqueFlowWristYaw of JointTorque
                from motionController.torqueOutWristYaw.torque
                to wristYawJoint.torqueIn.torque;

            flow stateFlowBase of JointState
                from baseJoint.stateOut.jointState
                to motionController.stateInBase.jointState;
            flow stateFlowShoulder of JointState
                from shoulderJoint.stateOut.jointState
                to motionController.stateInShoulder.jointState;
            flow stateFlowElbow of JointState
                from elbowJoint.stateOut.jointState
                to motionController.stateInElbow.jointState;
            flow stateFlowWristRoll of JointState
                from wristRollJoint.stateOut.jointState
                to motionController.stateInWristRoll.jointState;
            flow stateFlowWristPitch of JointState
                from wristPitchJoint.stateOut.jointState
                to motionController.stateInWristPitch.jointState;
            flow stateFlowWristYaw of JointState
                from wristYawJoint.stateOut.jointState
                to motionController.stateInWristYaw.jointState;

            flow powerFlowBase of VoltageValue
                from powerSupply.powerOut.voltage
                to baseJoint.powerIn.voltage;
            flow powerFlowShoulder of VoltageValue
                from powerSupply.powerOut.voltage
                to shoulderJoint.powerIn.voltage;
            flow powerFlowElbow of VoltageValue
                from powerSupply.powerOut.voltage
                to elbowJoint.powerIn.voltage;
            flow powerFlowWristRoll of VoltageValue
                from powerSupply.powerOut.voltage
                to wristRollJoint.powerIn.voltage;
            flow powerFlowWristPitch of VoltageValue
                from powerSupply.powerOut.voltage
                to wristPitchJoint.powerIn.voltage;
            flow powerFlowWristYaw of VoltageValue
                from powerSupply.powerOut.voltage
                to wristYawJoint.powerIn.voltage;
            flow powerFlowController of VoltageValue
                from powerSupply.powerOut.voltage
                to motionController.powerIn.voltage;

            flow graspFlow of GraspCommand
                from motionController.graspCmdOut.graspCmd
                to endEffector.graspCmdIn.graspCmd;
        }

        satisfy PayloadRequirement by roboticArm;
        satisfy WorkspaceRequirement by roboticArm;
        satisfy DOFRequirement by roboticArm;
        satisfy PowerSupplyRequirement by roboticArm.powerSupply;
        satisfy SafetyMonitoringRequirement by roboticArm.motionController;
    }
}
