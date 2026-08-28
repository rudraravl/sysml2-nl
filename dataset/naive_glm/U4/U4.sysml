package AutonomousGroundRobot {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ===== Custom Value Types =====
    value type Percent :> Real;
    value type ChargeCapacity :> Real;
    value type TorqueValue :> Real;
    value type AngularSpeed :> Real;
    value type FrequencyVal :> Real;
    value type DataSize :> Real;

    // ===== Enumerations =====
    enum def TaskTypeEnum {
        INSPECTION;
        DELIVERY;
        CLEANING;
        PATROL;
        TRANSPORT;
    }

    enum def WheelPositionEnum {
        FRONT_LEFT;
        FRONT_RIGHT;
        REAR_LEFT;
        REAR_RIGHT;
    }

    enum def AlertSeverity {
        LOW;
        MEDIUM;
        HIGH;
        CRITICAL;
    }

    // ===== Item Definitions =====
    item def Position {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    item def TaskCommand {
        attribute taskType : TaskTypeEnum;
        attribute targetLocation : Position;
    }

    item def ObstacleData {
        attribute detected : Boolean;
        attribute distance : Length;
        attribute position : Position;
    }

    item def LidarScan {
        attribute pointCloud : Position[0..*];
        attribute obstacles : ObstacleData[0..*];
        attribute timestamp : Time;
    }

    item def CameraImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute data : String;
        attribute timestamp : Time;
    }

    item def PathPlan {
        attribute waypoints : Position[0..*];
        attribute estimatedDistance : Length;
        attribute safe : Boolean;
    }

    item def MotorCommand {
        attribute targetSpeed : AngularSpeed;
        attribute direction : Real;
    }

    item def BatteryStatus {
        attribute chargeLevel : Percent;
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute charging : Boolean;
    }

    item def EmergencyAlert {
        attribute code : Integer;
        attribute description : String;
        attribute severity : AlertSeverity;
    }

    item def SensorFusionData {
        attribute lidarScan : LidarScan;
        attribute cameraImage : CameraImage;
        attribute fusedObstacles : ObstacleData[0..*];
    }

    item def ChargingStationInfo {
        attribute location : Position;
        attribute available : Boolean;
        attribute docked : Boolean;
    }

    // ===== Port Definitions =====
    port def TaskCommandPort {
        in taskCommand : TaskCommand;
    }

    port def LidarDataPort {
        out scan : LidarScan;
    }

    port def CameraDataPort {
        out image : CameraImage;
    }

    port def MotorControlPort {
        in command : MotorCommand;
    }

    port def BatteryMonitorPort {
        out status : BatteryStatus;
    }

    port def EmergencyPort {
        out alert : EmergencyAlert;
    }

    port def SensorFusionPort {
        out fusionData : SensorFusionData;
    }

    // ===== Action Definitions =====
    action def PerformLidarScan {
        out scan : LidarScan;
    }

    action def CaptureImage {
        out image : CameraImage;
    }

    action def FuseSensorData {
        in lidarScan : LidarScan;
        in cameraImage : CameraImage;
        out fusionData : SensorFusionData;
    }

    action def PlanPathAction {
        in sensorData : SensorFusionData;
        in target : Position;
        out plan : PathPlan;
    }

    action def NavigateAction {
        in plan : PathPlan;
        in sensorData : SensorFusionData;
        out motorCommands : MotorCommand[4];
    }

    action def ExecuteTaskAction {
        in task : TaskCommand;
    }

    action def MonitorBatteryAction {
        in status : BatteryStatus;
        out lowBattery : Boolean;
    }

    action def ChargeBatteryAction {
        in stationInfo : ChargingStationInfo;
        out chargeLevel : Percent;
    }

    action def HandleEmergencyAction {
        in alert : EmergencyAlert;
    }

    action def SafeShutdownAction {
    }

    // ===== Part Definitions =====
    part def Chassis {
        doc "Sturdy chassis structure for the autonomous ground robot.";
        attribute length : Length = 0.80 [m];
        attribute width : Length = 0.50 [m];
        attribute height : Length = 0.30 [m];
        attribute mass : Mass = 45 [kg];
        attribute material : String = "aluminum";
    }

    part def LidarSensor {
        doc "Lidar sensor for 3D environmental mapping and obstacle detection.";
        attribute maxRange : Length = 10 [m];
        attribute scanRate : FrequencyVal = 10;
        attribute angularResolution : Real = 0.5;
        attribute verticalFieldOfView : Real = 30;
        port lidarOut : LidarDataPort;
        action performScan : PerformLidarScan;
    }

    part def CameraSensor {
        doc "Camera sensor for visual data capture.";
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : FrequencyVal = 30;
        attribute horizontalFieldOfView : Real = 90;
        port cameraOut : CameraDataPort;
        action captureImage : CaptureImage;
    }

    part def MotorController {
        doc "Individual motor controller for each wheel assembly.";
        attribute maxTorque : TorqueValue = 5;
        attribute maxSpeed : AngularSpeed = 20;
        attribute efficiency : Percent = 85;
        port motorCmd : MotorControlPort;
    }

    part def WheelAssembly {
        doc "Individual wheel assembly with integrated motor controller.";
        attribute diameter : Length = 0.20 [m];
        attribute width : Length = 0.05 [m];
        attribute position : WheelPositionEnum;
        part motorController : MotorController;
    }

    part def BatteryPack {
        doc "High-capacity rechargeable battery pack powering the entire system.";
        attribute capacity : ChargeCapacity = 20;
        attribute nominalVoltage : ElectricPotential = 24 [V];
        attribute chargeLevel : Percent = 100;
        attribute maxDischargeRate : ElectricCurrent = 10 [A];
        attribute cycleCount : Integer = 0;
        port monitor : BatteryMonitorPort;
        action charge : ChargeBatteryAction;
    }

    part def CentralProcessor {
        doc "Central processing unit acting as the robot's brain.";
        attribute clockSpeed : FrequencyVal = 2000000000;
        attribute memory : DataSize = 8;
        attribute taskQueueCapacity : Integer = 10;
        port taskIn : TaskCommandPort;
        port lidarIn : ~LidarDataPort;
        port cameraIn : ~CameraDataPort;
        port motorOut : ~MotorControlPort[4];
        port batteryIn : ~BatteryMonitorPort;
        port emergencyOut : EmergencyPort;
        port fusionOut : SensorFusionPort;
        action fuseSensors : FuseSensorData;
        action planPath : PlanPathAction;
        action navigate : NavigateAction;
        action executeTask : ExecuteTaskAction;
        action monitorBattery : MonitorBatteryAction;
        action handleEmergency : HandleEmergencyAction;
    }

    // ===== State Machine Definition =====
    state def RobotStateMachine {
        doc "State machine governing the autonomous robot's operation.";

        attribute batteryThreshold : Percent = 20;
        attribute taskCommandReceived : Boolean = false;
        attribute batteryLevel : Percent = 100;
        attribute pathPlanReady : Boolean = false;
        attribute arrivedAtTarget : Boolean = false;
        attribute obstacleDetected : Boolean = false;
        attribute taskComplete : Boolean = false;
        attribute chargeComplete : Boolean = false;
        attribute criticalFailureDetected : Boolean = false;
        attribute failureResolved : Boolean = false;
        attribute atChargingStation : Boolean = false;
        attribute missionPaused : Boolean = false;

        transition initial -> standby;

        state standby {
            doc "Standby mode: waiting for instructions in low-power state.";
            entry {
                // Enter low-power standby mode
                // All subsystems in idle state
                // Ready to receive task commands
            }
            exit {
                // Wake up subsystems
            }
        }

        state active {
            doc "Active mode: executing a received task.";
            entry {
                // Activate all subsystems
                // Initialize sensor fusion
            }

            state planning {
                doc "Planning a safe path to the target location using sensor data.";
                entry {
                    // Use sensor data to identify and avoid obstacles
                    // Plan safe path to target location
                }
            }

            state navigating {
                doc "Navigating to the destination by controlling the four-wheel drive system.";
                entry {
                    // Control four-wheel drive system
                    // Navigate to destination along planned path
                }
            }

            state executingTask {
                doc "Executing the assigned task at the target location.";
                entry {
                    // Execute assigned task at target location
                }
            }

            transition planning -> navigating
                when pathPlanReady;

            transition navigating -> executingTask
                when arrivedAtTarget;

            transition navigating -> planning
                when obstacleDetected;
        }

        state charging {
            doc "Charging mode: mission paused, navigating to charging station.";
            entry {
                // Pause current mission
                // Save mission state for resumption
            }

            state travelingToCharger {
                doc "Traveling to the charging station location.";
                entry {
                    // Navigate to charging station location
                }
            }

            state chargingBattery {
                doc "Charging the battery at the charging station.";
                entry {
                    // Charge battery until complete
                }
            }

            transition travelingToCharger -> chargingBattery
                when atChargingStation;

            transition chargingBattery -> travelingToCharger
                when chargeComplete;
        }

        state emergency {
            doc "Emergency state: handling critical failures safely.";
            entry {
                // Stop all motors immediately
                // Alert operators via emergency port
                // Execute safe shutdown procedures
            }
            exit {
                // Reset failure flags
                // Reinitialize subsystems
            }
        }

        transition standby -> active
            accept TaskCommand;

        transition active -> charging
            when batteryLevel < batteryThreshold;

        transition active -> standby
            when taskComplete;

        transition charging -> standby
            when chargeComplete;

        transition standby -> emergency
            when criticalFailureDetected;

        transition active -> emergency
            when criticalFailureDetected;

        transition charging -> emergency
            when criticalFailureDetected;

        transition emergency -> standby
            when failureResolved;
    }

    // ===== Requirements =====
    requirement def ChassisRequirement {
        doc "The chassis shall be 80cm long and weigh 45kg.";
        subject chassis : Chassis;
        require chassis.length == 0.80 [m];
        require chassis.mass == 45 [kg];
    }

    requirement def SensorSuiteRequirement {
        doc "The robot shall have a Lidar for 3D environmental mapping and obstacle detection, and a camera for visual data.";
        subject robot : AutonomousRobot;
        require robot.lidar.maxRange >= 10 [m];
        require robot.lidar.scanRate >= 10;
        require robot.camera.resolutionWidth >= 1920;
        require robot.camera.resolutionHeight >= 1080;
    }

    requirement def PropulsionRequirement {
        doc "The robot shall have four individual wheel assemblies, each powered by its own motor controller.";
        subject robot : AutonomousRobot;
        require robot.wheelAssembly->size == 4;
    }

    requirement def PowerRequirement {
        doc "The entire system shall be powered by a high-capacity rechargeable battery pack.";
        subject robot : AutonomousRobot;
        require robot.batteryPack.capacity >= 20;
        require robot.batteryPack.nominalVoltage >= 24 [V];
    }

    requirement def ProcessingRequirement {
        doc "A central processing unit shall act as the robot's brain, receiving task commands that specify a task type and target location.";
        subject robot : AutonomousRobot;
        require robot.processor.taskIn <> null;
    }

    requirement def StateOperationRequirement {
        doc "The robot shall operate through standby, active, charging, and emergency states. It starts in standby, enters active upon receiving a task, plans a safe path, navigates, and executes the task.";
        subject robot : AutonomousRobot;
        require robot.robotStateMachine.standby <> null;
        require robot.robotStateMachine.active <> null;
        require robot.robotStateMachine.charging <> null;
        require robot.robotStateMachine.emergency <> null;
    }

    requirement def PowerManagementRequirement {
        doc "The robot shall constantly monitor its battery level. If charge drops below 20 percent, it shall automatically pause its current mission and navigate to a charging station. After charging, it returns to standby.";
        subject robot : AutonomousRobot;
        require robot.robotStateMachine.batteryThreshold == 20;
    }

    requirement def TaskCompletionRequirement {
        doc "Upon completing a task, the robot shall return to a standby state, ready for its next command.";
        subject robot : AutonomousRobot;
        require robot.robotStateMachine.taskComplete == true;
    }

    requirement def EmergencyRequirement {
        doc "The system shall include an emergency state to handle critical failures safely.";
        subject robot : AutonomousRobot;
        require robot.robotStateMachine.emergency <> null;
        require robot.processor.emergencyOut <> null;
    }

    // ===== Requirement Instances =====
    requirement chassisReq : ChassisRequirement;
    requirement sensorSuiteReq : SensorSuiteRequirement;
    requirement propulsionReq : PropulsionRequirement;
    requirement powerReq : PowerRequirement;
    requirement processingReq : ProcessingRequirement;
    requirement stateOperationReq : StateOperationRequirement;
    requirement powerManagementReq : PowerManagementRequirement;
    requirement taskCompletionReq : TaskCompletionRequirement;
    requirement emergencyReq : EmergencyRequirement;

    // ===== Main Robot Part =====
    part def AutonomousRobot {
        doc "A versatile, autonomous, four-wheeled ground robot designed to perform tasks at specific locations. Self-contained system with intelligent power management and emergency handling.";
        attribute name : String = "VersatileAutonomousGroundRobot";
        attribute version : String = "1.0";
        attribute manufacturer : String = "RoboticsDivision";

        part chassis : Chassis;

        part lidar : LidarSensor;

        part camera : CameraSensor;

        part wheelAssembly : WheelAssembly[4] {
            attribute position = WheelPositionEnum::FRONT_LEFT;
        }

        part batteryPack : BatteryPack;

        part processor : CentralProcessor;

        port taskReceiver : TaskCommandPort;
        port emergencyReceiver : ~EmergencyPort;

        // Connections: sensor data to processor
        connect lidar.lidarOut to processor.lidarIn;
        connect camera.cameraOut to processor.cameraIn;

        // Connection: battery monitoring to processor
        connect batteryPack.monitor to processor.batteryIn;

        // Connection: processor motor commands to wheel assemblies
        connect processor.motorOut to wheelAssembly.motorController.motorCmd;

        // Connection: task command delegation
        connect taskReceiver to processor.taskIn;

        // Connection: emergency alert to robot external port
        connect processor.emergencyOut to emergencyReceiver;

        // State machine behavior
        state robotStateMachine : RobotStateMachine;

        // Requirement satisfaction
        satisfy chassisReq by chassis;
        satisfy sensorSuiteReq by self;
        satisfy propulsionReq by self;
        satisfy powerReq by self;
        satisfy processingReq by self;
        satisfy stateOperationReq by self;
        satisfy powerManagementReq by self;
        satisfy taskCompletionReq by self;
        satisfy emergencyReq by self;
    }
}
