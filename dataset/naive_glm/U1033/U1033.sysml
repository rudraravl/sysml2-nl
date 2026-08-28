package RoboticAssistanceSystem {
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Mass :> Real { unit 'kg'; }
    value type Distance :> Real { unit 'm'; }
    value type Angle :> Real { unit 'rad'; }
    value type Power :> Real { unit 'W'; }
    value type Energy :> Real { unit 'J'; }
    value type Duration :> Real { unit 'h'; }
    value type Percentage :> Real { unit '%'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type LinearVelocity :> Real { unit 'm/s'; }
    value type AngularVelocity :> Real { unit 'rad/s'; }

    // ===== Item Types =====
    item def WaterBottle {
        attribute weight : Mass = 0.5 [kg];
    }
    item def MedicationContainer {
        attribute weight : Mass = 0.2 [kg];
    }
    item def GraspableObject {
        attribute weight : Mass;
        attribute identifier : String;
    }
    item def TaskRequest {
        attribute requestType : TaskType;
        attribute targetObject : String;
        attribute targetLocation : String;
    }
    item def NavigationMap {
        attribute resolution : Distance;
    }
    item def SensorData;
    item def ImageData;
    item def DepthData;
    item def PowerStatus {
        attribute chargeLevel : Percentage;
        attribute voltage : Voltage;
    }

    // ===== Enumerations =====
    enum def TaskType {
        RETRIEVE_OBJECT;
        DELIVER_MEDICATION;
        MOBILITY_SUPPORT;
        SMART_HOME_CONTROL;
    }
    enum def ArmJointType {
        SHOULDER_PITCH;
        SHOULDER_ROLL;
        SHOULDER_YAW;
        ELBOW_PITCH;
        WRIST_PITCH;
        WRIST_ROLL;
    }
    enum def RobotState {
        IDLE;
        NAVIGATING;
        EXECUTING;
        RETURNING;
        CHARGING;
    }
    enum def ChargeLevel {
        FULL;
        ADEQUATE;
        LOW;
        CRITICAL;
    }

    // ===== Requirements =====
    package Requirements {
        requirement def RoboticAssistanceRequirement {
            doc "The robotic assistance system shall support individuals with disabilities in a home or care environment.";
        }
        requirement def PayloadCapacityRequirement {
            doc "The gripper shall securely grasp and carry objects weighing up to 5 kilograms.";
            attribute maxPayload : Mass = 5.0 [kg];
            constraint { payload <= maxPayload }
        }
        requirement def BatteryLifeRequirement {
            doc "The lithium-ion battery shall support over six hours of continuous use.";
            attribute minDuration : Duration = 6.0 [h];
            constraint { operatingDuration >= minDuration }
        }
        requirement def NavigationRequirement {
            doc "The robot shall navigate autonomously using LiDAR and IMU for obstacle detection and mapping.";
        }
        requirement def VisionRequirement {
            doc "The vision system shall recognize objects and people using two HD cameras and a depth sensor.";
        }
        requirement def AutoRechargeRequirement {
            doc "The robot shall automatically navigate to its charging station when power runs low.";
        }
        requirement def TaskHandlingRequirement {
            doc "The robot shall handle retrieve object, deliver medication, mobility support, and smart home control tasks.";
        }
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out powerStatus : PowerStatus;
        in chargeCommand : Boolean;
    }
    port def DataPort {
        out sensorData : SensorData;
    }
    port def CommandPort {
        in taskRequest : TaskRequest;
        out taskStatus : String;
    }
    port def NavigationPort {
        out mapData : NavigationMap;
        out poseData : SensorData;
    }
    port def ArmCommandPort {
        in jointAngles : List{Angle, 6};
        in gripperCommand : Boolean;
    }
    port def SmartHomePort {
        out deviceCommand : String;
        in deviceStatus : String;
    }

    // ===== Interfaces =====
    interface def PowerInterface {
        end supplier : PowerPort;
        end consumer : PowerPort;
    }
    interface def DataInterface {
        end source : DataPort;
        end sink : DataPort;
    }
    interface def CommandInterface {
        end requester : CommandPort;
        end receiver : CommandPort;
    }

    // ===== Part Definitions =====
    part def Wheel {
        attribute radius : Distance = 0.15 [m];
        attribute maxSpeed : LinearVelocity = 1.2 [m/s];
        port wheelPower : PowerPort;
    }
    part def MobilityBase {
        doc "Four-wheeled mobility base for the assistance robot.";
        attribute wheelCount : Integer = 4;
        attribute maxLinearSpeed : LinearVelocity = 1.0 [m/s];
        attribute maxAngularSpeed : AngularVelocity = 1.5 [rad/s];
        part wheels : Wheel[4];
        port basePower : PowerPort;
        port baseCommand : CommandPort;
        port baseNavigation : NavigationPort;
        connection def WheelPowerConnection {
            end source : PowerPort;
            end target : PowerPort;
        }
        connection wheelPowerConn : WheelPowerConnection connect basePower to wheels.wheelPower;
    }
    part def ArmJoint {
        attribute jointType : ArmJointType;
        attribute currentAngle : Angle = 0 [rad];
        attribute maxTorque : Real = 50;
        port jointCommand : ArmCommandPort;
    }
    part def Gripper {
        doc "End-effector gripper capable of grasping objects up to 5 kg.";
        attribute maxPayload : Mass = 5.0 [kg];
        attribute gripForce : Real = 30;
        attribute isOpen : Boolean = true;
        port gripperCommand : ArmCommandPort;
        action grasp {
            in object : GraspableObject;
            doc "Perform grasp action on target object.";
        }
        action release {
            doc "Release currently grasped object.";
        }
    }
    part def ManipulatorArm {
        doc "Six-jointed manipulator arm with gripper end-effector.";
        attribute jointCount : Integer = 6;
        attribute reach : Distance = 0.8 [m];
        part joints : ArmJoint[6] {
            item joints[0].jointType = ArmJointType::SHOULDER_PITCH;
            item joints[1].jointType = ArmJointType::SHOULDER_ROLL;
            item joints[2].jointType = ArmJointType::SHOULDER_YAW;
            item joints[3].jointType = ArmJointType::ELBOW_PITCH;
            item joints[4].jointType = ArmJointType::WRIST_PITCH;
            item joints[5].jointType = ArmJointType::WRIST_ROLL;
        }
        part gripper : Gripper;
        port armCommand : ArmCommandPort;
        action def PerformGrasp {
            in targetObject : GraspableObject;
            doc "Coordinate joints and gripper to grasp an object.";
        }
        action def PerformPlace {
            in targetLocation : String;
            doc "Place grasped object at target location.";
        }
    }
    part def LiDARUnit {
        doc "360-degree LiDAR for obstacle detection and mapping.";
        attribute range : Distance = 10.0 [m];
        attribute angularResolution : Angle = 0.02 [rad];
        attribute scanRate : Real = 10;
        port lidarData : DataPort;
        flow scanData : SensorData out lidarData;
    }
    part def IMU {
        doc "Inertial measurement unit for balance and orientation.";
        attribute updateRate : Real = 100;
        port imuData : DataPort;
        flow orientationData : SensorData out imuData;
    }
    part def HDCamera {
        doc "High-definition camera for object and people recognition.";
        attribute resolution : String = "1920x1080";
        attribute frameRate : Real = 30;
        port cameraData : DataPort;
        flow imageData : ImageData out cameraData;
    }
    part def DepthSensor {
        doc "Depth sensor for 3D environmental perception.";
        attribute range : Distance = 5.0 [m];
        port depthData : DataPort;
        flow depthInfo : DepthData out depthData;
    }
    part def VisionSystem {
        doc "Vision system consisting of two HD cameras and a depth sensor.";
        part leftCamera : HDCamera;
        part rightCamera : HDCamera;
        part depthSensor : DepthSensor;
        port visionData : DataPort;
        action def RecognizeObjects {
            out recognizedObjects : List{String};
            doc "Identify objects in the environment using camera and depth data.";
        }
        action def RecognizePeople {
            out recognizedPeople : List{String};
            doc "Identify people in the environment.";
        }
    }
    part def SensorSuite {
        doc "Advanced sensor suite for navigation and environmental awareness.";
        part lidar : LiDARUnit;
        part imu : IMU;
        part vision : VisionSystem;
        port suiteData : DataPort;
        connection lidarConn : DataInterface connect lidar.lidarData to suiteData;
        connection imuConn : DataInterface connect imu.imuData to suiteData;
        connection visionConn : DataInterface connect vision.visionData to suiteData;
    }
    part def Battery {
        doc "Long-lasting lithium-ion battery for over 6 hours of continuous use.";
        attribute chemistry : String = "Lithium-Ion";
        attribute capacity : Energy = 100000 [J];
        attribute nominalVoltage : Voltage = 24 [V];
        attribute maxCurrent : Current = 10 [A];
        attribute chargeLevel : Percentage = 100 [%];
        attribute minOperatingDuration : Duration = 6.0 [h];
        attribute chargeThreshold : Percentage = 20 [%];
        port batteryPower : PowerPort;
        flow powerStatus : PowerStatus out batteryPower;
        action def Discharge {
            in rate : Power;
            out remainingCharge : Percentage;
        }
        action def Recharge {
            doc "Recharge battery from charging station.";
            out chargeLevel : Percentage;
        }
        satisfy Requirements::BatteryLifeRequirement by minOperatingDuration;
    }
    part def ChargingStation {
        doc "Base station for robot recharging.";
        attribute outputVoltage : Voltage = 24 [V];
        attribute outputCurrent : Current = 5 [A];
        port stationPower : PowerPort;
        flow chargingPower : PowerStatus out stationPower;
    }
    part def UserInterface {
        doc "Dedicated interface for users to request assistance.";
        attribute inputMethods : String = "Voice, Touchscreen, Mobile App";
        port userCommand : CommandPort;
        action def ReceiveTaskRequest {
            out request : TaskRequest;
            doc "Receive and parse user task request.";
        }
        action def ProvideFeedback {
            in status : String;
            doc "Provide feedback to user on task progress.";
        }
    }
    part def NavigationController {
        doc "Controller for autonomous navigation using sensor data.";
        port navInput : DataPort;
        port navOutput : NavigationPort;
        action def PlanPath {
            in destination : String;
            in map : NavigationMap;
            out path : List{String};
            doc "Plan a path to the destination using the navigation map.";
        }
        action def AvoidObstacles {
            in sensorInput : SensorData;
            out adjustedPath : List{String};
            doc "Adjust path to avoid detected obstacles.";
        }
    }
    part def TaskController {
        doc "Controller for managing task execution.";
        port taskInput : CommandPort;
        port taskOutput : CommandPort;
        port armPort : ArmCommandPort;
        port smartHomePort : SmartHomePort;
        action def ExecuteRetrieveObject {
            in target : String;
            doc "Retrieve a specific object using the manipulator arm.";
        }
        action def ExecuteDeliverMedication {
            in medication : String;
            in recipient : String;
            doc "Deliver medication to a specified recipient.";
        }
        action def ExecuteMobilitySupport {
            in user : String;
            doc "Provide basic mobility support to the user.";
        }
        action def ExecuteSmartHomeControl {
            in device : String;
            in command : String;
            doc "Control a smart home device.";
        }
    }
    part def CentralProcessor {
        doc "Central processing unit coordinating all subsystems.";
        part navigationController : NavigationController;
        part taskController : TaskController;
        port processorData : DataPort;
        port processorCommand : CommandPort;
        port processorArm : ArmCommandPort;
        port processorSmartHome : SmartHomePort;
    }
    part def AssistanceRobot {
        doc "Sophisticated autonomous mobile robot for assisting individuals with disabilities.";
        attribute robotId : String;
        attribute currentState : RobotState = RobotState::IDLE;
        part mobilityBase : MobilityBase;
        part manipulatorArm : ManipulatorArm;
        part sensorSuite : SensorSuite;
        part processor : CentralProcessor;
        part battery : Battery;
        port robotCommand : CommandPort;
        port robotPower : PowerPort;
        port robotSmartHome : SmartHomePort;
        connection powerConn : PowerInterface connect battery.batteryPower to mobilityBase.basePower;
        connection sensorConn : DataInterface connect sensorSuite.suiteData to processor.processorData;
        connection commandConn : CommandInterface connect robotCommand to processor.processorCommand;
        connection armConn connect processor.processorArm to manipulatorArm.armCommand;
        connection navConn connect processor.navigationController.navOutput to mobilityBase.baseNavigation;
        connection smartHomeConn connect processor.processorSmartHome to robotSmartHome;
        satisfy Requirements::RoboticAssistanceRequirement;
        satisfy Requirements::PayloadCapacityRequirement by manipulatorArm.gripper.maxPayload;
        satisfy Requirements::NavigationRequirement by sensorSuite;
        satisfy Requirements::VisionRequirement by sensorSuite.vision;
        satisfy Requirements::TaskHandlingRequirement by processor.taskController;
        satisfy Requirements::AutoRechargeRequirement by battery.chargeThreshold;

        state def RobotStateMachine {
            doc "Robot operational state machine.";
            entry action { /* initialize robot systems */ }
            state idle {
                doc "Robot is idle and waiting for a task request.";
                entry action { AssistanceRobot.currentState = RobotState::IDLE; }
            }
            state navigating {
                doc "Robot is navigating to the target location.";
                entry action { AssistanceRobot.currentState = RobotState::NAVIGATING; }
                do action { processor.navigationController.PlanPath(); }
            }
            state executing {
                doc "Robot is executing the requested task.";
                entry action { AssistanceRobot.currentState = RobotState::EXECUTING; }
                do action { processor.taskController.ExecuteRetrieveObject(); }
            }
            state returning {
                doc "Robot is returning to its base station.";
                entry action { AssistanceRobot.currentState = RobotState::RETURNING; }
                do action { processor.navigationController.PlanPath(); }
            }
            state charging {
                doc "Robot is charging at the charging station.";
                entry action { AssistanceRobot.currentState = RobotState::CHARGING; }
                do action { battery.Recharge(); }
            }
            transition idle_to_navigating
                transition from idle to navigating
                when robotCommand.taskRequest.requestType != null
                accept robotCommand.taskRequest;
            transition navigating_to_executing
                transition from navigating to executing
                when processor.navigationController.navOutput.poseData == "ARRIVED";
            transition executing_to_returning
                transition from executing to returning
                when processor.taskController.taskOutput.taskStatus == "COMPLETED";
            transition returning_to_idle
                transition from returning to idle
                when processor.navigationController.navOutput.poseData == "AT_BASE";
            transition any_to_charging_low
                transition from idle to charging
                when battery.batteryPower.powerStatus.chargeLevel <= battery.chargeThreshold;
            transition any_to_charging_navigating
                transition from navigating to charging
                when battery.batteryPower.powerStatus.chargeLevel <= battery.chargeThreshold;
            transition any_to_charging_executing
                transition from executing to charging
                when battery.batteryPower.powerStatus.chargeLevel <= battery.chargeThreshold;
            transition any_to_charging_returning
                transition from returning to charging
                when battery.batteryPower.powerStatus.chargeLevel <= battery.chargeThreshold;
            transition charging_to_idle
                transition from charging to idle
                when battery.batteryPower.powerStatus.chargeLevel >= 95 [%];
        }
        action def PerformGrasp {
            in targetObject : GraspableObject;
            doc "Coordinate the manipulator arm to grasp a target object.";
            perform manipulatorArm.PerformGrasp(targetObject);
        }
        action def PerformTask {
            in request : TaskRequest;
            doc "Execute a complete task cycle from request to completion.";
            if request.requestType == TaskType::RETRIEVE_OBJECT {
                PerformGrasp();
            } else if request.requestType == TaskType::DELIVER_MEDICATION {
                processor.taskController.ExecuteDeliverMedication();
            } else if request.requestType == TaskType::MOBILITY_SUPPORT {
                processor.taskController.ExecuteMobilitySupport();
            } else if request.requestType == TaskType::SMART_HOME_CONTROL {
                processor.taskController.ExecuteSmartHomeControl();
            }
        }
    }
    part def RoboticAssistanceSystem {
        doc "Complete robotic assistance system for home or care environment.";
        part robot : AssistanceRobot;
        part chargingStation : ChargingStation;
        part userInterface : UserInterface;
        connection userToRobot : CommandInterface connect userInterface.userCommand to robot.robotCommand;
        connection stationToRobot : PowerInterface connect chargingStation.stationPower to robot.robotPower;
        exhibit state robotBehavior : AssistanceRobot::RobotStateMachine;
    }
}
