package RoboticAssistanceSystem {
    import ISQ::**;
    import ScalarValues::**;

    enum def TaskType {
        value retrieveObject;
        value deliverMedication;
        value mobilitySupport;
        value smartHomeControl;
    }

    enum def BatteryStatusKind {
        value full;
        value adequate;
        value low;
        value critical;
    }

    attribute def TaskRequest {
        attribute taskType : TaskType;
        attribute targetLocation : String;
        attribute targetObject : String;
    }

    attribute def TaskComplete;
    attribute def BatteryLow;
    attribute def ArrivedAtTarget;
    attribute def ArrivedAtBase;
    attribute def ArrivedAtCharger;
    attribute def ChargingComplete;
    attribute def GraspFailed;

    requirement def AssistIndividualsWithDisabilities {
        subject assistanceRobot;
        text = "The robotic assistance system shall support individuals with disabilities in a home or care environment.";
    }

    requirement def CarryUpTo5kg :> AssistIndividualsWithDisabilities {
        subject gripper;
        text = "The gripper shall securely grasp and carry objects weighing up to 5 kilograms.";
        attribute maxLoad : ISQ::MassValue = 5 [kg];
    }

    requirement def BatteryLifeOver6h :> AssistIndividualsWithDisabilities {
        subject battery;
        text = "The battery shall provide over six hours of continuous operation.";
        attribute minDuration : ISQ::TimeValue = 6 [h];
    }

    requirement def AutoRechargeOnLowBattery :> AssistIndividualsWithDisabilities {
        subject assistanceRobot;
        text = "The robot shall automatically navigate to its charging station when battery power is low.";
    }

    requirement def SixJointManipulator :> AssistIndividualsWithDisabilities {
        subject manipulatorArm;
        text = "The manipulator arm shall have six joints for versatile operation.";
        attribute jointCount : Integer = 6;
    }

    requirement def FourWheelMobility :> AssistIndividualsWithDisabilities {
        subject mobilityBase;
        text = "The mobility base shall have four wheels.";
        attribute wheelCount : Integer = 4;
    }

    requirement def FullPerceptionSuite :> AssistIndividualsWithDisabilities {
        subject assistanceRobot;
        text = "The robot shall be equipped with a 360-degree LiDAR, an IMU, two HD cameras, and a depth sensor.";
    }

    part def Wheel {
        attribute radius : ISQ::LengthValue;
        port wheelDrivePort {
            in attribute commandTorque : Real;
            out attribute wheelOdom : Real;
        }
    }

    part def MobilityBase {
        attribute wheelCount : Integer = 4;
        attribute maxSpeed : ISQ::SpeedValue;
        part wheels[wheelCount] : Wheel;
        port drivePort {
            in attribute velocityCommand : Real;
            in attribute steeringCommand : Real;
        }
        connect drivePort to wheels[1].wheelDrivePort;
        connect drivePort to wheels[2].wheelDrivePort;
        connect drivePort to wheels[3].wheelDrivePort;
        connect drivePort to wheels[4].wheelDrivePort;
    }

    part def Joint {
        attribute jointId : Integer;
        attribute rangeMin : ISQ::AngleValue;
        attribute rangeMax : ISQ::AngleValue;
        port jointPort {
            in attribute targetAngle : ISQ::AngleValue;
            out attribute measuredAngle : ISQ::AngleValue;
        }
    }

    part def Gripper {
        attribute maxLoad : ISQ::MassValue = 5 [kg];
        attribute gripForceMax : Real;
        port gripPort {
            in attribute gripCommand : Boolean;
            in attribute forceSetpoint : Real;
            out attribute gripStatus : String;
            out attribute loadSensed : ISQ::MassValue;
        }
        perform action graspSequence {
            in attribute targetObject : String;
            first start;
            then action closeJaw;
            then action senseLoad;
            then done;
        }
    }

    part def ManipulatorArm {
        attribute jointCount : Integer = 6;
        attribute reach : ISQ::LengthValue;
        part joints[jointCount] : Joint;
        part gripper : Gripper;
        port armControlPort {
            in attribute jointCommand : ISQ::AngleValue[*];
            in attribute gripperCommand : Boolean;
            out attribute endEffectorPose : String;
        }
    }

    part def LiDAR {
        attribute fieldOfView : ISQ::AngleValue = 360 [deg];
        attribute maxRange : ISQ::LengthValue;
        port perceptionPort {
            out attribute pointCloud : String;
            out attribute obstacleMap : String;
        }
    }

    part def IMU {
        port imuPort {
            out attribute orientation : Real[*];
            out attribute angularVelocity : Real[*];
            out attribute linearAcceleration : Real[*];
        }
    }

    part def Camera {
        attribute resolution : String = "HD";
        port cameraPort {
            out attribute imageData : String;
        }
    }

    part def DepthSensor {
        port depthPort {
            out attribute depthImage : String;
        }
    }

    part def VisionSystem {
        attribute cameraCount : Integer = 2;
        attribute hasDepthSensor : Boolean = true;
        part cameras[cameraCount] : Camera;
        part depthSensor : DepthSensor;
        port visionPort {
            out attribute recognizedObjects : String;
            out attribute detectedPeople : String;
            out attribute sceneDescriptor : String;
        }
    }

    part def UserInterface {
        attribute supportedTaskTypes : TaskType[*];
        port requestPort {
            out attribute taskRequest : TaskRequest;
            in attribute statusFeedback : String;
        }
        perform action handleUserInput {
            out attribute taskRequest : TaskRequest;
            first start;
            then action receiveInput;
            then action parseRequest;
            then action validateRequest;
            then done;
        }
    }

    part def Battery {
        attribute chemistry : String = "Lithium-Ion";
        attribute nominalOperatingDuration : ISQ::TimeValue = 6 [h];
        attribute currentChargePercent : Real;
        port batteryPort {
            out attribute status : BatteryStatusKind;
            out attribute chargePercent : Real;
        }
        perform action monitorCharge {
            out attribute status : BatteryStatusKind;
            first start;
            then action measureVoltage;
            then action estimateRemaining;
            then action classifyStatus;
            then done;
        }
    }

    part def ChargingStation {
        attribute location : String;
        port chargerPort {
            in attribute dockRequest : Boolean;
            out attribute chargeComplete : Boolean;
            out attribute chargingPower : Real;
        }
        perform action rechargeSequence {
            first start;
            then action connectDock;
            then action chargeCell;
            then action balanceCells;
            then done;
        }
    }

    part def ControlUnit {
        port requestIn {
            in attribute taskRequest : TaskRequest;
        }
        port perceptionIn {
            in attribute pointCloud : String;
            in attribute obstacleMap : String;
            in attribute imuData : String;
            in attribute visionData : String;
        }
        port batteryIn {
            in attribute status : BatteryStatusKind;
            in attribute chargePercent : Real;
        }
        port navOut {
            out attribute velocityCommand : Real;
            out attribute steeringCommand : Real;
        }
        port armOut {
            out attribute jointCommand : ISQ::AngleValue[*];
            out attribute gripperCommand : Boolean;
        }
        port uiOut {
            out attribute statusFeedback : String;
        }
        port chargerOut {
            out attribute dockRequest : Boolean;
        }
        perform action planTask {
            in attribute taskRequest : TaskRequest;
            out attribute plan : String;
            first start;
            then action decodeRequest;
            then action computePath;
            then done;
        }
    }

    action def PerformGrasp {
        in attribute targetObject : String;
        out attribute graspedObject : Boolean;
        first start;
        then action approachObject;
        then action alignGripper;
        then action closeGripper;
        then action verifyGrasp;
        then done;
    }

    action def NavigateToTarget {
        in attribute targetLocation : String;
        first start;
        then action planPath;
        then action followPath;
        then action checkArrival;
        then done;
    }

    action def ExecuteTask {
        in attribute taskRequest : TaskRequest;
        first start;
        then action performTaskAction;
        then done;
    }

    action def ReturnToBase {
        first start;
        then action navigateHome;
        then action dockAtBase;
        then done;
    }

    part def AssistanceRobot {
        attribute supportsIndependence : Boolean = true;
        attribute returnsToChargerOnLowBattery : Boolean = true;

        part mobilityBase : MobilityBase;
        part manipulatorArm : ManipulatorArm;
        part lidar : LiDAR;
        part imu : IMU;
        part visionSystem : VisionSystem;
        part userInterface : UserInterface;
        part battery : Battery;
        part controlUnit : ControlUnit;
        part chargingStation : ChargingStation;

        connect userInterface.requestPort to controlUnit.requestIn;
        connect lidar.perceptionPort to controlUnit.perceptionIn;
        connect imu.imuPort to controlUnit.perceptionIn;
        connect visionSystem.visionPort to controlUnit.perceptionIn;
        connect battery.batteryPort to controlUnit.batteryIn;
        connect controlUnit.navOut to mobilityBase.drivePort;
        connect controlUnit.armOut to manipulatorArm.armControlPort;
        connect controlUnit.uiOut to userInterface.requestPort;
        connect controlUnit.chargerOut to chargingStation.chargerPort;

        state robotStates {
            entry; then idle;

            state idle;
            transition idle_to_navigating
                first idle
                accept TaskRequest
                then navigating;
            transition idle_to_navigatingToCharger
                first idle
                accept BatteryLow
                then navigatingToCharger;

            state navigating;
            transition navigating_to_executing
                first navigating
                accept ArrivedAtTarget
                then executing;
            transition navigating_to_navigatingToCharger
                first navigating
                accept BatteryLow
                then navigatingToCharger;

            state executing;
            transition executing_to_returning
                first executing
                accept TaskComplete
                then returning;
            transition executing_to_returning_on_fail
                first executing
                accept GraspFailed
                then returning;
            transition executing_to_navigatingToCharger
                first executing
                accept BatteryLow
                then navigatingToCharger;

            state returning;
            transition returning_to_idle
                first returning
                accept ArrivedAtBase
                then idle;
            transition returning_to_navigatingToCharger
                first returning
                accept BatteryLow
                then navigatingToCharger;

            state navigatingToCharger;
            transition navigatingToCharger_to_charging
                first navigatingToCharger
                accept ArrivedAtCharger
                then charging;

            state charging;
            transition charging_to_idle
                first charging
                accept ChargingComplete
                then idle;
        }
    }

    part homeAssistanceRobot : AssistanceRobot {
        :>> mobilityBase {
            :>> maxSpeed = 1.2 [m/s];
        }
        :>> manipulatorArm {
            :>> reach = 0.8 [m];
            :>> gripper {
                :>> maxLoad = 5 [kg];
                :>> gripForceMax = 60.0;
            }
        }
        :>> lidar {
            :>> maxRange = 10 [m];
        }
        :>> battery {
            :>> nominalOperatingDuration = 6.5 [h];
            :>> currentChargePercent = 100.0;
        }
        :>> userInterface {
            :>> supportedTaskTypes = TaskType::retrieveObject;
        }
        :>> chargingStation {
            :>> location = "HomeBaseDock";
        }
    }

    requirement def HomeCareMission {
        subject homeAssistanceRobot;
        text = "The home assistance robot shall support individuals with disabilities with a 5 kg payload capacity, 6+ hour battery life, 6-joint arm, 4-wheel base, 360-degree LiDAR, and dual-camera vision system with depth sensor.";
    }
}
