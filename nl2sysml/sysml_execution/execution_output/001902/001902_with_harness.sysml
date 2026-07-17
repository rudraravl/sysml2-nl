package ValkyrieHumanoidRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    
    enum def OperationalMode {
        standby;
        autonomous;
        teleoperated;
        emergency;
    }
    
    enum def TaskStatus {
        idle;
        planning;
        executing;
        completed;
        failed;
    }
    
    enum def GraspState {
        open;
        closing;
        holding;
        releasing;
    }
    
    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def Orientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def Pose {
        attribute position : Position3D;
        attribute orientation : Orientation;
    }
    
    item def SensorData {
        attribute timestamp : Real;
        attribute pose : Pose;
    }
    
    item def MotionCommand {
        attribute targetPose : Pose;
        attribute velocity : Real;
        attribute duration : Real;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute powerDraw : Real;
    }
    
    port def DataBusPort {
        in item commands : MotionCommand;
        out item telemetry : SensorData;
    }
    
    port def MechanicalPort {
        attribute torque : Real;
        attribute position : Real;
        attribute velocity : Real;
    }
    
    port def SensorPort {
        out item data : SensorData;
    }
    
    part def ActuatorJoint {
        attribute maxTorque : Real;
        attribute currentPosition : Real;
        attribute targetPosition : Real;
        attribute mass : MassValue;
        
        port power : PowerPort;
        port control : DataBusPort;
        port mechanical : MechanicalPort;
    }
    
    part def Manipulator {
        attribute mass : MassValue;
        attribute reachRadius : LengthValue;
        attribute graspForce : Real;
        attribute graspState : GraspState;
        
        part shoulder : ActuatorJoint {
            attribute :>> maxTorque = 190.0;
            attribute :>> mass = 3.2[kg];
        }
        part elbow : ActuatorJoint {
            attribute :>> maxTorque = 125.0;
            attribute :>> mass = 2.8[kg];
        }
        part wrist : ActuatorJoint {
            attribute :>> maxTorque = 60.0;
            attribute :>> mass = 1.5[kg];
        }
        part gripper {
            attribute mass : MassValue = 1.8[kg];
            attribute maxGraspForce : Real = 150.0;
        }
        
        port power : PowerPort;
        port control : DataBusPort;
    }
    
    part def LegAssembly {
        attribute mass : MassValue;
        attribute stepHeight : LengthValue;
        attribute maxStepLength : LengthValue;
        
        part hip : ActuatorJoint {
            attribute :>> maxTorque = 220.0;
            attribute :>> mass = 4.5[kg];
        }
        part knee : ActuatorJoint {
            attribute :>> maxTorque = 180.0;
            attribute :>> mass = 3.8[kg];
        }
        part ankle : ActuatorJoint {
            attribute :>> maxTorque = 140.0;
            attribute :>> mass = 2.9[kg];
        }
        
        port power : PowerPort;
        port control : DataBusPort;
    }
    
    part def VisionSystem {
        attribute resolution : Integer;
        attribute fieldOfView : Real;
        attribute frameRate : Real;
        attribute mass : MassValue;
        
        port power : PowerPort;
        port data : SensorPort;
    }
    
    part def LidarSensor {
        attribute range : LengthValue;
        attribute scanRate : Real;
        attribute angularResolution : Real;
        attribute mass : MassValue;
        
        port power : PowerPort;
        port data : SensorPort;
    }
    
    part def IMU {
        attribute mass : MassValue;
        attribute sampleRate : Real;
        
        port power : PowerPort;
        port data : SensorPort;
    }
    
    part def BatteryPack {
        attribute capacity : Real;
        attribute voltage : Real;
        attribute currentCharge : Real;
        attribute mass : MassValue;
        attribute maxDischargeRate : Real;
        
        port output : PowerPort;
    }
    
    part def ComputeUnit {
        attribute processingPower : Real;
        attribute memoryCapacity : Real;
        attribute mass : MassValue;
        attribute powerConsumption : Real;
        
        port power : PowerPort;
        port dataBus : DataBusPort;
    }
    
    part def TorsoStructure {
        attribute mass : MassValue;
        
        part mainComputer : ComputeUnit {
            attribute :>> processingPower = 2.4;
            attribute :>> memoryCapacity = 32.0;
            attribute :>> mass = 2.5[kg];
            attribute :>> powerConsumption = 85.0;
        }
        part imu : IMU {
            attribute :>> mass = 0.3[kg];
            attribute :>> sampleRate = 1000.0;
        }
        
        port power : PowerPort;
        port dataBus : DataBusPort;
    }
    
    part def HeadAssembly {
        attribute mass : MassValue;
        
        part cameras : VisionSystem {
            attribute :>> resolution = 1920;
            attribute :>> fieldOfView = 120.0;
            attribute :>> frameRate = 60.0;
            attribute :>> mass = 0.8[kg];
        }
        part lidar : LidarSensor {
            attribute :>> range = 30.0[m];
            attribute :>> scanRate = 20.0;
            attribute :>> angularResolution = 0.25;
            attribute :>> mass = 1.2[kg];
        }
        part neckJoint : ActuatorJoint {
            attribute :>> maxTorque = 45.0;
            attribute :>> mass = 1.5[kg];
        }
        
        port power : PowerPort;
        port dataBus : DataBusPort;
    }
    
    action def PerceiveEnvironment {
        out visualData : SensorData;
        out rangeData : SensorData;
        out inertialData : SensorData;
    }
    
    action def PlanTrajectory {
        in currentPose : Pose;
        in targetPose : Pose;
        in environmentData : SensorData;
        out trajectoryPlan : MotionCommand;
    }
    
    action def ExecuteMotion {
        in trajectoryPlan : MotionCommand;
        out executionStatus : TaskStatus;
    }
    
    action def MaintainBalance {
        in imuData : SensorData;
        out balanceCorrection : MotionCommand;
    }
    
    action def ManipulateObject {
        in objectPose : Pose;
        in graspType : GraspState;
        out manipulationStatus : TaskStatus;
    }
    
    action def NavigateToLocation {
        in targetLocation : Position3D;
        out navigationStatus : TaskStatus;
    }
    
    action def PerformHumanoidMission {
        doc /* Execute autonomous humanoid robot mission including perception,
             * navigation, manipulation, and balance control for disaster response
             * or space exploration tasks. */
        
        first start;
        then merge operationLoop;
        
        then action perceive : PerceiveEnvironment {
            out environmentState : SensorData;
        }
        
        then action balance : MaintainBalance {
            in imuData = perceive.inertialData;
        }
        
        then decide missionPhase;
            if perceive.visualData.timestamp > 0 then planNextAction;
        
        action planNextAction : PlanTrajectory {
            in currentPose : Pose;
            in targetPose : Pose;
            in environmentData = perceive.visualData;
        }
        
        then decide actionType;
            if planNextAction.trajectoryPlan.velocity < 0.5 then manipulate;
            if planNextAction.trajectoryPlan.velocity >= 0.5 then navigate;
        
        action manipulate : ManipulateObject {
            in objectPose : Pose;
            in graspType = GraspState::holding;
        }
        then operationLoop;
        
        action navigate : NavigateToLocation {
            in targetLocation : Position3D;
        }
        then operationLoop;
    }
    
    state def ValkyrieOperationalStateMachine {
        entry; then initialization;
        
        state initialization {
            entry assign mode = OperationalMode::standby;
        }
        accept at when batteryCharge > 15.0 then ready;
        accept at when batteryCharge <= 15.0 then shutdown;
        
        state ready {
            entry assign mode = OperationalMode::autonomous;
        }
        accept at when missionCommandReceived then active;
        
        state active {
            do action mission : PerformHumanoidMission;
            
            state balancing {
                do action maintainBalance : MaintainBalance;
            }
            
            state moving {
                do action navigate : NavigateToLocation;
            }
            
            state manipulating {
                do action manipulate : ManipulateObject;
            }
        }
        accept at when missionComplete then ready;
        accept at when emergencyDetected then emergency;
        accept at when batteryCharge <= 10.0 then shutdown;
        
        state emergency {
            entry assign mode = OperationalMode::emergency;
        }
        accept at when emergencyCleared then ready;
        
        state shutdown {
            entry assign mode = OperationalMode::standby;
        }
        
        attribute mode : OperationalMode;
        attribute batteryCharge : Real;
        attribute missionCommandReceived : Boolean;
        attribute missionComplete : Boolean;
        attribute emergencyDetected : Boolean;
        attribute emergencyCleared : Boolean;
    }
    
    part def ValkyrieHumanoidRobot {
        doc /* NASA Valkyrie (R5) is an advanced humanoid robot designed for disaster
             * response operations and potential space exploration missions. The robot
             * features human-like mobility and dexterity to perform complex tasks in
             * hazardous or remote environments. */
        
        attribute totalMass : MassValue;
        attribute height : LengthValue;
        attribute operatingVoltage : Real;
        attribute totalPowerConsumption : Real;
        attribute operationalDuration : Real;
        
        part battery : BatteryPack {
            attribute :>> capacity = 3600.0;
            attribute :>> voltage = 48.0;
            attribute :>> currentCharge = 3400.0;
            attribute :>> mass = 12.0[kg];
            attribute :>> maxDischargeRate = 150.0;
        }
        
        part torso : TorsoStructure {
            attribute :>> mass = 18.5[kg];
        }
        
        part head : HeadAssembly {
            attribute :>> mass = 4.8[kg];
        }
        
        part leftArm : Manipulator {
            attribute :>> mass = 9.3[kg];
            attribute :>> reachRadius = 0.95[m];
            attribute :>> graspForce = 150.0;
        }
        
        part rightArm : Manipulator {
            attribute :>> mass = 9.3[kg];
            attribute :>> reachRadius = 0.95[m];
            attribute :>> graspForce = 150.0;
        }
        
        part leftLeg : LegAssembly {
            attribute :>> mass = 14.2[kg];
            attribute :>> stepHeight = 0.30[m];
            attribute :>> maxStepLength = 0.60[m];
        }
        
        part rightLeg : LegAssembly {
            attribute :>> mass = 14.2[kg];
            attribute :>> stepHeight = 0.30[m];
            attribute :>> maxStepLength = 0.60[m];
        }
        
        connect battery.output to torso.power;
        connect battery.output to head.power;
        connect battery.output to leftArm.power;
        connect battery.output to rightArm.power;
        connect battery.output to leftLeg.power;
        connect battery.output to rightLeg.power;
        
        connect torso.dataBus to head.dataBus;
        connect torso.dataBus to leftArm.control;
        connect torso.dataBus to rightArm.control;
        connect torso.dataBus to leftLeg.control;
        connect torso.dataBus to rightLeg.control;
        
        assert constraint massBalance {
            totalMass == battery.mass + torso.mass + head.mass + 
                        leftArm.mass + rightArm.mass + 
                        leftLeg.mass + rightLeg.mass
        }
        
        assert constraint powerBudget {
            totalPowerConsumption <= battery.maxDischargeRate
        }
        
        perform action primaryMission : PerformHumanoidMission;
        
        exhibit state operationalBehavior : ValkyrieOperationalStateMachine;
    }
    
    requirement <'REQ-VAL-SYS-001'> primaryMissionCapability {
        doc /* The Valkyrie humanoid robot system shall autonomously perform disaster
             * response and space exploration tasks including navigation through complex
             * environments, manipulation of tools and objects, and environmental
             * assessment with human-like dexterity and mobility. */
        subject valkyrie : ValkyrieHumanoidRobot;
    }
    
    requirement <'REQ-VAL-SYS-010'> mobilityRequirement {
        doc /* The system shall navigate bipedally across uneven terrain with step
             * height capability of at least 0.25 meters and step length of at least
             * 0.50 meters. */
        subject valkyrie : ValkyrieHumanoidRobot;
        assert constraint {
            valkyrie.leftLeg.stepHeight >= 0.25[m] and
            valkyrie.rightLeg.stepHeight >= 0.25[m] and
            valkyrie.leftLeg.maxStepLength >= 0.50[m] and
            valkyrie.rightLeg.maxStepLength >= 0.50[m]
        }
    }
    
    requirement <'REQ-VAL-SYS-020'> manipulationRequirement {
        doc /* The system shall manipulate objects using dual-arm coordination with
             * reach radius of at least 0.90 meters per arm and grasp force of at
             * least 100 Newtons. */
        subject valkyrie : ValkyrieHumanoidRobot;
        assert constraint {
            valkyrie.leftArm.reachRadius >= 0.90[m] and
            valkyrie.rightArm.reachRadius >= 0.90[m] and
            valkyrie.leftArm.graspForce >= 100.0 and
            valkyrie.rightArm.graspForce >= 100.0
        }
    }
    
    requirement <'REQ-VAL-SYS-030'> perceptionRequirement {
        doc /* The system shall perceive the environment using vision sensors with
             * minimum 30 Hz frame rate and lidar with minimum 15 meter range for
             * obstacle detection and object recognition. */
        subject head : ValkyrieHumanoidRobot::head;
        assert constraint {
            head.cameras.frameRate >= 30.0 and
            head.lidar.range >= 15.0[m]
        }
    }
    
    requirement <'REQ-VAL-SYS-040'> massConstraint {
        doc /* The total system mass shall not exceed 130 kilograms to enable
             * practical deployment and transportation. */
        subject valkyrie : ValkyrieHumanoidRobot;
        assert constraint {
            valkyrie.totalMass <= 130.0[kg]
        }
    }
    
    requirement <'REQ-VAL-SYS-050'> autonomyRequirement {
        doc /* The system shall operate autonomously for at least 1 hour on battery
             * power during typical mission operations. */
        subject valkyrie : ValkyrieHumanoidRobot;
        assert constraint {
            valkyrie.operationalDuration >= 3600.0
        }
    }
    
    requirement <'REQ-VAL-SYS-060'> balanceRequirement {
        doc /* The system shall maintain dynamic balance during locomotion and
             * manipulation tasks using real-time inertial feedback. */
        subject torso : ValkyrieHumanoidRobot::torso;
        assert constraint {
            torso.imu.sampleRate >= 500.0
        }
    }
    
    part valkyrieR5 : ValkyrieHumanoidRobot {
        attribute :>> totalMass = 125.0[kg];
        attribute :>> height = 1.88[m];
        attribute :>> operatingVoltage = 48.0;
        attribute :>> totalPowerConsumption = 145.0;
        attribute :>> operationalDuration = 3900.0;
    }
    
    satisfy primaryMissionCapability by valkyrieR5;
    satisfy mobilityRequirement by valkyrieR5;
    satisfy manipulationRequirement by valkyrieR5;
    satisfy perceptionRequirement by valkyrieR5.head;
    satisfy massConstraint by valkyrieR5;
    satisfy autonomyRequirement by valkyrieR5;
    satisfy balanceRequirement by valkyrieR5.torso;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    private import ValkyrieHumanoidRobotSystem::*;

    part testSubject : ValkyrieHumanoidRobot {
        exhibit state operationalBehavior : ValkyrieOperationalStateMachine;
    }

    action orchestrator {
        attribute testCurrentPose : Pose {
            attribute position : Position3D {
                attribute x : LengthValue;
                attribute y : LengthValue;
                attribute z : LengthValue;
            }
            attribute orientation : Orientation {
                attribute roll = 0.0;
                attribute pitch = 0.0;
                attribute yaw = 0.0;
            }
        }
        attribute testTargetPose : Pose {
            attribute position : Position3D {
                attribute x : LengthValue;
                attribute y : LengthValue;
                attribute z : LengthValue;
            }
            attribute orientation : Orientation {
                attribute roll = 0.0;
                attribute pitch = 0.0;
                attribute yaw = 0.0;
            }
        }
        item testEnvironmentData : SensorData {
            attribute timestamp = 0.0;
            attribute pose : Pose {
                attribute position : Position3D {
                    attribute x : LengthValue;
                    attribute y : LengthValue;
                    attribute z : LengthValue;
                }
                attribute orientation : Orientation {
                    attribute roll = 0.0;
                    attribute pitch = 0.0;
                    attribute yaw = 0.0;
                }
            }
        }
        action planNextActionProbe : PlanTrajectory {
            in currentPose = testCurrentPose;
            in targetPose = testTargetPose;
            in environmentData = testEnvironmentData;
        }
        first planNextActionProbe;
    }
}
