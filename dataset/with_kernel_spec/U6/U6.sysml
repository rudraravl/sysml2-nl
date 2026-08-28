package BushRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def TargetPose {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
            attribute roll : AngleValue;
            attribute pitch : AngleValue;
            attribute yaw : AngleValue;
        }
        item def GripperCommand {
            attribute doGrasp : Boolean;
            attribute force : ForceValue;
        }
        item def TaskCommand {
            attribute taskId : String;
            attribute targetPose : TargetPose;
            attribute gripperCommand : GripperCommand;
        }
        item def JointState {
            attribute angle : AngleValue;
            attribute velocity : AngularVelocityValue;
            attribute torque : TorqueValue;
        }
        item def SensorData {
            attribute currentPose : TargetPose;
            attribute jointStates : JointState[6];
            attribute gripperForce : ForceValue;
        }
        item def PowerStatus {
            attribute online : Boolean;
            attribute outputVoltage : ElectricPotentialValue;
        }
        item def InitializationComplete;
        item def MotionComplete;
        item def TaskComplete;
        item def FaultDetected;
        item def EmergencyStop;
        item def ClearFault;
        item def MaintenanceMode;
        item def MaintenanceDone;

        port def TaskCommandPort {
            in attribute command : TaskCommand;
        }
        port def ArmControlInPort {
            in attribute targetPose : TargetPose;
            in attribute gripperCommand : GripperCommand;
        }
        port def ArmControlOutPort {
            out attribute targetPose : TargetPose;
            out attribute gripperCommand : GripperCommand;
        }
        port def ArmFeedbackOutPort {
            out attribute currentPose : TargetPose;
            out attribute jointStates : JointState[6];
            out attribute gripperForce : ForceValue;
        }
        port def ArmFeedbackInPort {
            in attribute currentPose : TargetPose;
            in attribute jointStates : JointState[6];
            in attribute gripperForce : ForceValue;
        }
        port def SensorFeedbackOutPort {
            out attribute data : SensorData;
        }
        port def SensorFeedbackInPort {
            in attribute data : SensorData;
        }
        port def PowerOutputPort {
            out attribute status : PowerStatus;
        }
        port def PowerInputPort {
            in attribute status : PowerStatus;
        }

        action def InitializeMotion;
        action def PlanTrajectory {
            in attribute targetPose : TargetPose;
            in attribute currentJointStates : JointState[6];
            out attribute plannedTrajectory : JointState[6];
        }
        action def ExecuteMotion {
            in attribute plannedTrajectory : JointState[6];
        }
        action def CompleteTask;
        action def MonitorSystem {
            out attribute faultDetected : Boolean;
        }
        action def EmergencyStopAction;
        action def GraspObject {
            in attribute force : ForceValue;
        }
        action def ReleaseObject;
        action def RotateJoint {
            in attribute targetAngle : AngleValue;
            out attribute currentAngle : AngleValue;
        }
        action def SensePosition {
            out attribute currentPose : TargetPose;
        }
        action def SenseJointStates {
            out attribute jointStates : JointState[6];
        }
        action def SenseGripperForce {
            out attribute gripperForce : ForceValue;
        }

        part def Link {
            attribute length : LengthValue;
            attribute mass : MassValue;
        }
        part def Joint {
            attribute angle : AngleValue;
            perform action rotate : RotateJoint;
        }
        part def Gripper {
            attribute appliedForce : ForceValue;
            perform action graspObject : GraspObject;
            perform action releaseObject : ReleaseObject;
        }
        part def SixAxisArm {
            part links[6] : Link;
            part joints[6] : Joint;
            part gripper : Gripper;
            port controlPort : ArmControlInPort;
            port feedbackPort : ArmFeedbackOutPort;
            port powerInputPort : PowerInputPort;
            perform action executeMotion : ExecuteMotion;
        }
        part def ControlModule {
            port commandPort : TaskCommandPort;
            port armControlPort : ArmControlOutPort;
            port armFeedbackPort : ArmFeedbackInPort;
            port sensorFeedbackPort : SensorFeedbackInPort;
            port powerInputPort : PowerInputPort;
            perform action planTrajectory : PlanTrajectory;
            perform action executeMotion : ExecuteMotion;
            perform action monitorSystem : MonitorSystem;
            perform action emergencyStop : EmergencyStopAction;
        }
        part def SensorModule {
            port powerInputPort : PowerInputPort;
            port feedbackPort : SensorFeedbackOutPort;
            perform action sensePosition : SensePosition;
            perform action senseJointStates : SenseJointStates;
            perform action senseGripperForce : SenseGripperForce;
        }
        part def PowerSupplyUnit {
            port outputPort : PowerOutputPort;
            attribute ratedVoltage : ElectricPotentialValue;
            attribute maxPower : PowerValue;
        }

        part def BushRobot {
            part arm : SixAxisArm;
            part controller : ControlModule;
            part sensors : SensorModule;
            part powerSupply : PowerSupplyUnit;
            port taskCommandPort : TaskCommandPort;
            perform action initializeMotion : InitializeMotion;
            perform action executeMotion : ExecuteMotion;
            perform action completeTask : CompleteTask;
            perform action monitorSystem : MonitorSystem;
            perform action emergencyStop : EmergencyStopAction;

            connector powerToArm {
                end feature source references powerSupply.outputPort;
                end feature target references arm.powerInputPort;
            }
            connector powerToController {
                end feature source references powerSupply.outputPort;
                end feature target references controller.powerInputPort;
            }
            connector powerToSensors {
                end feature source references powerSupply.outputPort;
                end feature target references sensors.powerInputPort;
            }
            connector taskToController {
                end feature source references taskCommandPort;
                end feature target references controller.commandPort;
            }
            connector controllerToArm {
                end feature source references controller.armControlPort;
                end feature target references arm.controlPort;
            }
            connector armFeedbackToController {
                end feature source references arm.feedbackPort;
                end feature target references controller.armFeedbackPort;
            }
            connector sensorFeedbackToController {
                end feature source references sensors.feedbackPort;
                end feature target references controller.sensorFeedbackPort;
            }

            state robotLifecycle {
                entry; then standby;
                state standby;
                accept taskCommand : TaskCommand via taskCommandPort
                    then operational;
                accept MaintenanceMode
                    then maintenance;
                state operational {
                    entry; then initializing;
                    state initializing {
                        entry do initializeMotion;
                    }
                    accept InitializationComplete
                        then executing;
                    state executing {
                        do executeMotion;
                        do monitorSystem;
                    }
                    accept MotionComplete
                        then completing;
                    accept FaultDetected
                        then fault;
                    accept EmergencyStop
                        then fault;
                    state completing {
                        entry do completeTask;
                    }
                    accept TaskComplete
                        then standby;
                }
                state fault {
                    entry do emergencyStop;
                }
                accept ClearFault
                    then standby;
                state maintenance;
                accept MaintenanceDone
                    then standby;
            }
        }

        requirement def SixAxisStructure {
            subject arm : SixAxisArm;
            doc /* The robotic arm shall consist of exactly six interconnected links and six motorized joints. */
        }
        requirement def GripperForceControl {
            subject gripper : Gripper;
            doc /* The gripper shall grasp and release objects with controlled force. */
        }
        requirement def ClosedLoopControl {
            subject robot : BushRobot;
            doc /* The system shall utilize continuous sensor feedback for closed-loop control. */
        }
        requirement def SafetyMonitoring {
            subject robot : BushRobot;
            doc /* The system shall continuously monitor its state during operation and trigger emergency stop on fault. */
        }
        requirement def PowerSupplyAdequacy {
            subject powerSupply : PowerSupplyUnit;
            doc /* The power supply shall provide adequate power to all subsystems. */
        }

        requirement bushRobotSystemRequirements {
            doc /* Top-level Bush Robot system requirements group */
            subject robot : BushRobot;
            requirement sixAxisStructure : SixAxisStructure {
                subject = robot.arm;
            }
            requirement gripperForceControl : GripperForceControl {
                subject = robot.arm.gripper;
            }
            requirement closedLoopControl : ClosedLoopControl {
                subject = robot;
            }
            requirement safetyMonitoring : SafetyMonitoring {
                subject = robot;
            }
            requirement powerSupplyAdequacy : PowerSupplyAdequacy {
                subject = robot.powerSupply;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part bushRobotInstance : BushRobot;

        action initializeMotion : InitializeMotion;
        action executeMotion : ExecuteMotion;
        action completeTask : CompleteTask;
        action monitorSystem : MonitorSystem;
        action emergencyStop : EmergencyStopAction;
        action planTrajectory : PlanTrajectory;
        action sensePosition : SensePosition;
        action senseJointStates : SenseJointStates;
        action senseGripperForce : SenseGripperForce;
        action graspObject : GraspObject;
        action releaseObject : ReleaseObject;
        action rotateJoint : RotateJoint;

        requirement robotSpec : bushRobotSystemRequirements {
            subject robot = bushRobotInstance;
        }
    }
}
