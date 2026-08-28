package AutonomousPickPlaceRobot {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ============================================================
    // Enumerations
    // ============================================================
    enum def OperationalMode {
        Idle;
        Scanning;
        Navigating;
        Positioning;
        Grasping;
        Transporting;
        Releasing;
    }

    enum def PowerState {
        Nominal;
        Warning;
        Critical;
    }

    // ============================================================
    // Value Definitions
    // ============================================================
    value def Position3D {
        x : Length;
        y : Length;
        z : Length;
    }

    value def Pose6D {
        position : Position3D;
        roll : PlaneAngle;
        pitch : PlaneAngle;
        yaw : PlaneAngle;
    }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def TargetObject {
        attribute identifier : String;
        attribute mass : Mass;
        attribute detected : Boolean = false;
        attribute location : Position3D;
    }

    item def Destination {
        attribute identifier : String;
        attribute position : Position3D;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def VisionDataPort {
        out detectedObjects : TargetObject[*];
        out targetRange : Length;
        out targetLocation : Position3D;
    }

    port def ProximityDataPort {
        out distance : Length;
        out obstacleDetected : Boolean;
    }

    port def MotionCommandPort {
        in linearVelocity : Speed;
        in angularVelocity : AngularVelocity;
    }

    port def ArmCommandPort {
        in jointAngles : PlaneAngle[6];
        in gripperForce : Force;
    }

    port def GripperFeedbackPort {
        out contactForce : Force;
        out isGrasping : Boolean;
        out loadMass : Mass;
    }

    port def PowerStatusPort {
        out batteryLevel : Real;
        out voltage : ElectricPotential;
        out state : PowerState;
    }

    port def CommandPort {
        in taskCommand : String;
        out taskStatus : OperationalMode;
    }

    // ============================================================
    // Sub-Component Definitions
    // ============================================================
    part def Wheel {
        attribute diameter : Length = 0.2 [m];
        attribute maxTorque : Torque = 5 [N*m];
        attribute currentSpeed : Speed = 0 [m/s];
        port motionIn : MotionCommandPort;
    }

    part def FourWheelDrive {
        attribute wheelCount : Integer = 4;
        port motionCmd : MotionCommandPort;
        part frontLeft : Wheel;
        part frontRight : Wheel;
        part rearLeft : Wheel;
        part rearRight : Wheel;
        connect motionCmd to frontLeft.motionIn;
        connect motionCmd to frontRight.motionIn;
        connect motionCmd to rearLeft.motionIn;
        connect motionCmd to rearRight.motionIn;
    }

    part def MobilePlatform {
        attribute platformWidth : Length = 0.6 [m];
        attribute platformLength : Length = 0.8 [m];
        attribute maxSpeed : Speed = 1.5 [m/s];
        attribute safeMaxSpeed : Speed = 1.0 [m/s];
        attribute platformMass : Mass = 15 [kg];

        port motionCmdIn : MotionCommandPort;
        part drivetrain : FourWheelDrive;
        connect motionCmdIn to drivetrain.motionCmd;

        action navigateTo(targetLocation : Position3D) {
            in maxAllowedSpeed : Speed = safeMaxSpeed;
        }
    }

    part def Joint {
        attribute index : Integer;
        attribute minAngle : PlaneAngle = -180 [deg];
        attribute maxAngle : PlaneAngle = 180 [deg];
        attribute currentAngle : PlaneAngle = 0 [deg];
        attribute maxTorque : Torque = 20 [N*m];
    }

    part def Gripper {
        attribute maxLoad : Mass = 8 [kg];
        attribute minGripForce : Force = 5 [N];
        attribute maxGripForce : Force = 40 [N];
        attribute safeGripForce : Force = 30 [N];
        attribute currentForce : Force = 0 [N];
        attribute isClosed : Boolean = false;

        port cmdIn : ArmCommandPort;
        port feedbackOut : GripperFeedbackPort;

        action grasp(target : TargetObject) {
            in appliedForce : Force = safeGripForce;
        }

        action release {
        }
    }

    part def SixJointArm {
        attribute jointCount : Integer = 6;
        attribute maxReach : Length = 0.95 [m];
        attribute payloadCapacity : Mass = 8 [kg];

        port armCmdIn : ArmCommandPort;
        port gripperFeedbackIn : ~GripperFeedbackPort;

        part joints : Joint[6];
        part endEffector : Gripper;

        connect armCmdIn to endEffector.cmdIn;
        connect endEffector.feedbackOut to gripperFeedbackIn;

        action moveToPose(targetPose : Pose6D) {
        }
    }

    part def VisionSensor {
        attribute detectionRange : Length = 5 [m];
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : Integer = 30;
        attribute currentTargetRange : Length = 0 [m];

        port dataOut : VisionDataPort;

        action scan {
            out detectedObjects : TargetObject[*];
            out targetRange : Length;
        }
    }

    part def ProximitySensor {
        attribute sensorId : Integer;
        attribute detectionRange : Length = 0.5 [m];
        attribute currentDistance : Length = 0 [m];

        port dataOut : ProximityDataPort;

        action sense {
            out distance : Length;
            out obstacleDetected : Boolean;
        }
    }

    part def Battery {
        attribute capacity : Energy = 100 [Wh];
        attribute nominalVoltage : ElectricPotential = 24 [V];
        attribute currentLevel : Real = 100;
        attribute minThreshold : Real = 20;
        attribute criticalThreshold : Real = 10;

        port powerOut : PowerStatusPort;

        action discharge(amount : Energy) {
        }

        action charge(amount : Energy) {
        }
    }

    part def PowerModule {
        attribute monitoringInterval : Time = 1 [s];
        attribute state : PowerState = PowerState::Nominal;

        port batteryIn : ~PowerStatusPort;
        port statusOut : PowerStatusPort;

        state machine powerMonitoring {
            state nominal;
            state warning;
            state critical;

            transition initial to nominal;
            transition from nominal to warning when batteryIn.batteryLevel < 30;
            transition from warning to nominal when batteryIn.batteryLevel >= 30;
            transition from warning to critical when batteryIn.batteryLevel < 10;
            transition from critical to warning when batteryIn.batteryLevel >= 15;
        }

        action monitorBatteryLevel {
            out level : Real;
            out state : PowerState;
        }
    }

    part def ControlModule {
        attribute mode : OperationalMode = OperationalMode::Idle;
        attribute atTargetLocation : Boolean = false;
        attribute armReady : Boolean = false;
        attribute atDestination : Boolean = false;
        attribute objectReleased : Boolean = false;
        attribute commandReceived : Boolean = false;

        port visionIn : ~VisionDataPort;
        port proximityIn : ~ProximityDataPort[4];
        port motionOut : ~MotionCommandPort;
        port armOut : ~ArmCommandPort;
        port gripperFeedbackIn : ~GripperFeedbackPort;
        port powerStatusIn : ~PowerStatusPort;
        port commandIn : CommandPort;

        state machine taskController {
            state idle;
            state scanning;
            state navigating;
            state positioning;
            state grasping;
            state transporting;
            state releasing;

            transition initial to idle;
            transition from idle to scanning when commandReceived;
            transition from scanning to navigating when visionIn.targetRange > 0 [m];
            transition from scanning to idle when commandIn.taskCommand == "cancel";
            transition from navigating to positioning when atTargetLocation;
            transition from positioning to grasping when armReady;
            transition from grasping to transporting when gripperFeedbackIn.isGrasping;
            transition from transporting to releasing when atDestination;
            transition from releasing to idle when objectReleased;
            transition from scanning to idle when powerStatusIn.batteryLevel < 20;
            transition from navigating to idle when powerStatusIn.batteryLevel < 20;
            transition from positioning to idle when powerStatusIn.batteryLevel < 20;
        }

        action planPath(target : Position3D) {
        }

        action executePickAndPlace(target : TargetObject, destination : Destination) {
        }
    }

    // ============================================================
    // Main Robot Assembly
    // ============================================================
    part def MobileRobot {
        attribute systemName : String = "AutonomousPickPlaceRobot";
        attribute operationalAreaRadius : Length = 5 [m];

        part platform : MobilePlatform;
        part manipulator : SixJointArm;
        part vision : VisionSensor;
        part proximitySensors : ProximitySensor[4];
        part controller : ControlModule;
        part battery : Battery;
        part power : PowerModule;

        connect vision.dataOut to controller.visionIn;
        connect proximitySensors.dataOut to controller.proximityIn;
        connect controller.motionOut to platform.motionCmdIn;
        connect controller.armOut to manipulator.armCmdIn;
        connect manipulator.gripperFeedbackIn to controller.gripperFeedbackIn;
        connect battery.powerOut to power.batteryIn;
        connect power.statusOut to controller.powerStatusIn;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def AutonomousPickPlaceRequirement {
        doc "The robot shall autonomously locate, grasp, transport, and release objects within its operational area.";
        subject robot : MobileRobot;
        constraint { robot.operationalAreaRadius >= 5 [m] }
    }

    requirement def FourWheelDriveRequirement {
        doc "The mobile platform shall be equipped with a four-wheel drive system for navigation.";
        subject platform : MobilePlatform;
        constraint { platform.drivetrain.wheelCount == 4 }
    }

    requirement def SixJointArmRequirement {
        doc "The robot shall feature a six-jointed robotic arm with a reach of nearly one meter.";
        subject arm : SixJointArm;
        constraint { arm.jointCount == 6 }
        constraint { arm.maxReach >= 0.9 [m] }
    }

    requirement def GripperLoadRequirement {
        doc "The gripper shall hold objects up to 8 kg without crushing them by applying a controlled amount of force.";
        subject gripper : Gripper;
        constraint { gripper.maxLoad >= 8 [kg] }
        constraint { gripper.maxGripForce <= 50 [N] }
        constraint { gripper.currentForce <= gripper.maxGripForce }
    }

    requirement def CentralControlRequirement {
        doc "A central control module shall coordinate the operation of the robot, including scanning, navigation, grasping, transport, and release.";
        subject controller : ControlModule;
    }

    requirement def VisionRangeRequirement {
        doc "The vision sensor shall detect and identify target objects up to 5 meters away.";
        subject sensor : VisionSensor;
        constraint { sensor.detectionRange >= 5 [m] }
    }

    requirement def ProximitySensorRequirement {
        doc "The robot shall have four proximity sensors for close-range awareness and obstacle avoidance.";
        subject robot : MobileRobot;
        constraint { robot.proximitySensors.size == 4 }
    }

    requirement def SafeSpeedRequirement {
        doc "The robot shall navigate while adhering to a safe maximum speed during object approach.";
        subject platform : MobilePlatform;
        constraint { platform.safeMaxSpeed <= platform.maxSpeed }
    }

    requirement def BatteryPowerRequirement {
        doc "The system shall be powered by an internal battery with sufficient charge remaining above a minimum threshold.";
        subject battery : Battery;
        constraint { battery.minThreshold == 20 }
        constraint { battery.currentLevel > battery.minThreshold }
    }

    requirement def PowerModuleRequirement {
        doc "A dedicated power module shall continuously monitor the battery level to ensure the robot has sufficient charge.";
        subject power : PowerModule;
        constraint { power.monitoringInterval <= 1 [s] }
    }

    requirement def TaskSequenceRequirement {
        doc "A typical task sequence shall begin with scanning for an object, followed by navigation to the object, grasping, transporting to a destination, and releasing.";
        subject controller : ControlModule;
    }

    // ============================================================
    // Robot Instance & Requirement Satisfaction
    // ============================================================
    part robotInstance : MobileRobot;

    satisfy AutonomousPickPlaceRequirement by robotInstance;
    satisfy FourWheelDriveRequirement by robotInstance.platform;
    satisfy SixJointArmRequirement by robotInstance.manipulator;
    satisfy GripperLoadRequirement by robotInstance.manipulator.endEffector;
    satisfy CentralControlRequirement by robotInstance.controller;
    satisfy VisionRangeRequirement by robotInstance.vision;
    satisfy ProximitySensorRequirement by robotInstance;
    satisfy SafeSpeedRequirement by robotInstance.platform;
    satisfy BatteryPowerRequirement by robotInstance.battery;
    satisfy PowerModuleRequirement by robotInstance.power;
    satisfy TaskSequenceRequirement by robotInstance.controller;
}
