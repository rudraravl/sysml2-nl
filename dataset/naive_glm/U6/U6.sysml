package BushRobotSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Position {
        attribute x: Length;
        attribute y: Length;
        attribute z: Length;
    }

    value type Orientation {
        attribute roll: PlaneAngle;
        attribute pitch: PlaneAngle;
        attribute yaw: PlaneAngle;
    }

    value type JointAngleValue :> PlaneAngle {
        attribute minLimit: PlaneAngle = -180 [deg];
        attribute maxLimit: PlaneAngle = 180 [deg];
    }

    value type JointVelocityValue :> AngularVelocity;
    value type JointTorqueValue :> Torque;
    value type GripperForceValue :> Force;
    value type PowerValue :> Real { attribute unit: String = "W"; }
    value type VoltageValue :> Real { attribute unit: String = "V"; }
    value type CurrentValue :> Real { attribute unit: String = "A"; }

    // ===== Item Types =====
    item def TargetCommand {
        attribute targetPosition: Position;
        attribute targetOrientation: Orientation;
        attribute gripperCommand: String;
        attribute gripperForceSetpoint: GripperForceValue;
    }

    item def Trajectory {
        attribute waypoints: Position[0..*];
        attribute orientations: Orientation[0..*];
        attribute duration: Time;
    }

    item def JointState {
        attribute angle: JointAngleValue;
        attribute velocity: JointVelocityValue;
        attribute torque: JointTorqueValue;
    }

    item def RobotState {
        attribute endEffectorPosition: Position;
        attribute endEffectorOrientation: Orientation;
        attribute jointStates: JointState[6];
        attribute gripperForce: GripperForceValue;
    }

    item def EmergencyStopSignal {
        attribute reason: String;
    }

    item def JointCommand {
        attribute targetAngle: JointAngleValue;
    }

    item def GripperCommand {
        attribute grasp: Boolean;
        attribute forceSetpoint: GripperForceValue;
    }

    // ===== Port Definitions =====
    port def CommandPort {
        out item : TargetCommand;
    }

    port def FeedbackPort {
        out item : RobotState;
    }

    port def TrajectoryPort {
        out item : Trajectory;
    }

    port def JointCommandPort {
        out item : JointCommand;
    }

    port def GripperCommandPort {
        out item : GripperCommand;
    }

    port def PowerPort {
        out attribute voltage: VoltageValue;
        out attribute current: CurrentValue;
    }

    port def EmergencyPort {
        out item : EmergencyStopSignal;
    }

    // ===== Part Definitions =====
    part def Link {
        attribute mass: Mass;
        attribute length: Length;
        attribute material: String;
    }

    part def Joint {
        port jointCmd: JointCommandPort;
        attribute currentAngle: JointAngleValue;
        attribute currentVelocity: JointVelocityValue;
        attribute currentTorque: JointTorqueValue;
        attribute maxTorque: JointTorqueValue = 150 [N*m];

        action def Actuate {
            in targetAngle: JointAngleValue;
            then done;
            action done;
        }
    }

    part def Gripper {
        port gripperCmd: GripperCommandPort;
        attribute appliedForce: GripperForceValue;
        attribute maxForce: GripperForceValue = 50 [N];
        attribute isGrasping: Boolean = false;

        action def Grasp {
            in force: GripperForceValue;
            then engaged;
            action engaged;
        }

        action def Release {
            then disengaged;
            action disengaged;
        }
    }

    part def RoboticArm {
        part links: Link[6] {
            attribute mass: Mass = 5 [kg];
            attribute length: Length = 0.4 [m];
            attribute material: String = "aluminum";
        }
        part joints: Joint[6] {
            redefines port jointCmd;
        }
        part endEffector: Gripper;

        attribute degreesOfFreedom: Integer = 6;

        action def ExecuteTrajectory {
            in trajectory: Trajectory;
            then moving;
            action moving {
                out jointCommands: JointCommand[6];
            }
            then done;
            action done;
        }
    }

    part def ControlModule {
        port cmdInput: CommandPort;
        port feedbackInput: FeedbackPort;
        port trajectoryOutput: TrajectoryPort;
        port jointControlOutputs: JointCommandPort[6];
        port gripperControlOutput: GripperCommandPort;
        port emergencyOutput: EmergencyPort;

        attribute isTrajectoryValid: Boolean;

        action def PlanTrajectory {
            in target: TargetCommand;
            in currentState: RobotState;
            out trajectory: Trajectory;
            then validate;
            action validate {
                out valid: Boolean;
            }
        }

        action def ExecuteMotion {
            in trajectory: Trajectory;
        }

        action def MonitorSafety {
            in state: RobotState;
            out emergency: EmergencyStopSignal;
        }
    }

    part def SensorModule {
        port feedbackOutput: FeedbackPort;
        attribute samplingRate: Frequency = 1000 [Hz];

        action def SampleState {
            out state: RobotState;
            then transmit;
            action transmit;
        }
    }

    part def PowerSupply {
        port powerOutput: PowerPort;
        attribute outputVoltage: VoltageValue = 48 [V];
        attribute maxCurrent: CurrentValue = 20 [A];
        attribute maxPower: PowerValue = 1000 [W];
        attribute isActive: Boolean = true;
    }

    // ===== System =====
    part def BushRobot {
        part arm: RoboticArm;
        part controller: ControlModule;
        part sensors: SensorModule;
        part power: PowerSupply;

        // Power distribution
        connection powerToController connect power.powerOutput to controller;
        connection powerToSensors connect power.powerOutput to sensors;
        connection powerToArm connect power.powerOutput to arm;

        // Command flow
        connection cmdToController connect controller.cmdInput to controller;

        // Trajectory from controller to arm
        connection trajectoryFlow connect controller.trajectoryOutput to arm;

        // Joint commands from controller to each joint
        connection jointCmd1 connect controller.jointControlOutputs[1] to arm.joints[1].jointCmd;
        connection jointCmd2 connect controller.jointControlOutputs[2] to arm.joints[2].jointCmd;
        connection jointCmd3 connect controller.jointControlOutputs[3] to arm.joints[3].jointCmd;
        connection jointCmd4 connect controller.jointControlOutputs[4] to arm.joints[4].jointCmd;
        connection jointCmd5 connect controller.jointControlOutputs[5] to arm.joints[5].jointCmd;
        connection jointCmd6 connect controller.jointControlOutputs[6] to arm.joints[6].jointCmd;

        // Gripper command
        connection gripperCmdFlow connect controller.gripperControlOutput to arm.endEffector.gripperCmd;

        // Feedback from sensors to controller
        connection feedbackFlow connect sensors.feedbackOutput to controller.feedbackInput;

        // Emergency stop
        connection emergencyFlow connect controller.emergencyOutput to controller;

        attribute systemState: String = "standby";
    }

    // ===== State Machine =====
    state def RobotLifecycle {
        entry; then standby;

        state standby {
            entry {
                attribute systemState = "standby";
            }
        }

        state operational {
            entry; then initializing;
            state initializing {
                entry {
                    attribute systemState = "initializing";
                }
            }
            transition from initializing to executing when initialized;
            state executing {
                entry {
                    attribute systemState = "executing";
                }
            }
            transition from executing to completing when motionComplete;
            state completing {
                entry {
                    attribute systemState = "completing";
                }
            }
        }

        transition from standby to operational when taskInitiated;
        transition from operational.standby to operational when taskInitiated;
        transition from operational.completing to standby when taskComplete;

        state fault {
            entry {
                attribute systemState = "fault";
            }
        }

        transition from operational to fault when errorDetected;
        transition from standby to fault when errorDetected;
        transition from operational to fault when emergencyStopTriggered;

        state maintenance {
            entry {
                attribute systemState = "maintenance";
            }
        }

        transition from fault to maintenance when serviceRequested;
        transition from maintenance to standby when serviceComplete;
    }

    // ===== Requirements =====
    requirement def ManipulationRequirement {
        doc "The robot shall perform precise physical manipulation tasks autonomously."
        subject robot: BushRobot;
    }

    requirement def SixAxisFlexibilityRequirement {
        doc "The robotic arm shall be constructed from six interconnected links and six motorized joints, providing six degrees of freedom for positioning and orientation in three-dimensional space."
        subject arm: RoboticArm;
    }

    requirement def GripperControlRequirement {
        doc "The end-effector gripper shall be commandable to grasp and release objects with a controlled force not exceeding 50 N."
        subject gripper: Gripper;
    }

    requirement def ControlModuleRequirement {
        doc "The onboard control module shall receive high-level target commands, plan a valid trajectory, and execute the motion."
        subject controller: ControlModule;
    }

    requirement def SensorFeedbackRequirement {
        doc "The sensor module shall continuously feed back data about the robot's current position, orientation, and the precise state of each of its six joints for closed-loop control and safety monitoring."
        subject sensors: SensorModule;
    }

    requirement def PowerSupplyRequirement {
        doc "The robotic system shall be powered by a dedicated external power supply unit providing 48 V DC."
        subject power: PowerSupply;
    }

    requirement def LifecycleRequirement {
        doc "The robot shall operate through a well-defined lifecycle with modes: standby, operational, fault, and maintenance."
        subject robot: BushRobot;
    }

    requirement def TaskExecutionRequirement {
        doc "When a task is initiated, the robot shall transition from standby to operational, first initializing, then executing the motion, and finally completing the task before returning to standby."
        subject robot: BushRobot;
    }

    requirement def SafetyMonitoringRequirement {
        doc "The system shall continuously monitor its state during operation and shall trigger an emergency stop if an issue is detected."
        subject robot: BushRobot;
    }

    // ===== Requirement Satisfaction =====
    requirement manipulationReq : ManipulationRequirement;
    requirement sixAxisReq : SixAxisFlexibilityRequirement;
    requirement gripperReq : GripperControlRequirement;
    requirement controlReq : ControlModuleRequirement;
    requirement sensorReq : SensorFeedbackRequirement;
    requirement powerReq : PowerSupplyRequirement;
    requirement lifecycleReq : LifecycleRequirement;
    requirement taskExecReq : TaskExecutionRequirement;
    requirement safetyReq : SafetyMonitoringRequirement;
}
