package AutonomousMobileServiceRobot {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::m;
    private import SI::kg;
    private import SI::s;
    private import SI::V;

    attribute def TaskCommand;
    attribute def TaskComplete;
    attribute def BatteryLow;
    attribute def BatterySufficient;
    attribute def PathBlocked;
    attribute def TaskFailed;
    attribute def ErrorCleared;

    item def Power {
        attribute voltage : ElectricPotentialValue;
    }

    part def Battery {
        attribute voltage : ElectricPotentialValue = 48 [V];
        attribute chargeLevel : Real = 100;
        port powerOut {
            out item p : Power;
        }
        port statusOut {
            out attribute chargeLevel : Real;
        }
    }

    part def DriveWheel;
    part def SteeringSystem;
    part def Motor;

    part def MobilePlatform {
        attribute maxSpeed : SpeedValue = 2 [m/s];
        part driveWheel[2] : DriveWheel;
        part steering : SteeringSystem;
        part driveMotor[2] : Motor;
        port powerIn {
            in item p : Power;
        }
    }

    part def Gripper {
        attribute maxGripForce : ForceValue;
        port controlIn {
            in attribute gripCommand : Real;
        }
    }

    part def Joint;

    part def ManipulatorArm {
        attribute reach : LengthValue = 0.8 [m];
        attribute payloadCapacity : MassValue = 15 [kg];
        part joint[6] : Joint;
        part gripper : Gripper;
        port powerIn {
            in item p : Power;
        }
    }

    part def LidarScanner {
        attribute range : LengthValue = 30 [m];
        attribute fieldOfView : PlaneAngleValue = 360;
        port dataOut {
            out attribute scanData : Real;
        }
        port powerIn {
            in item p : Power;
        }
    }

    part def Camera {
        attribute resolution : Real;
        port imageOut {
            out attribute imageData : Real;
        }
        port powerIn {
            in item p : Power;
        }
    }

    part def ProximitySensor {
        port dataOut {
            out attribute proximityData : Real;
        }
        port powerIn {
            in item p : Power;
        }
    }

    part def Controller {
        port sensorIn {
            in attribute sensorData : Real;
        }
        port commandOut {
            out attribute command : Real;
        }
        port powerIn {
            in item p : Power;
        }
        port batteryStatusIn {
            in attribute chargeLevel : Real;
        }
    }

    part def DockingStation {
        port chargeOut {
            out item p : Power;
        }
    }

    part def Robot {
        attribute height : LengthValue = 1.2 [m];
        attribute mass : MassValue = 85 [kg];

        part battery : Battery;
        part platform : MobilePlatform;
        part arm : ManipulatorArm;
        part lidar : LidarScanner;
        part frontCamera : Camera;
        part gripperCamera : Camera;
        part proximitySensor[4] : ProximitySensor;
        part controller : Controller;
        part dockingStation : DockingStation;

        connect battery.powerOut to platform.powerIn;
        connect battery.powerOut to arm.powerIn;
        connect battery.powerOut to lidar.powerIn;
        connect battery.powerOut to frontCamera.powerIn;
        connect battery.powerOut to gripperCamera.powerIn;
        connect battery.powerOut to proximitySensor.powerIn;
        connect battery.powerOut to controller.powerIn;
        connect battery.statusOut to controller.batteryStatusIn;

        connect lidar.dataOut to controller.sensorIn;
        connect frontCamera.imageOut to controller.sensorIn;
        connect gripperCamera.imageOut to controller.sensorIn;
        connect proximitySensor.dataOut to controller.sensorIn;

        connect controller.commandOut to platform.steering;
        connect controller.commandOut to arm.gripper.controlIn;

        connect dockingStation.chargeOut to battery.powerOut;

        state robotStates {
            entry; then idle;
            state idle;
            accept TaskCommand then navigating;
            state navigating;
            accept TaskComplete then executing;
            accept PathBlocked then error;
            accept BatteryLow then charging;
            state executing;
            accept TaskComplete then idle;
            accept TaskFailed then error;
            accept BatteryLow then charging;
            state charging;
            accept BatterySufficient then idle;
            state error;
            accept ErrorCleared then idle;
        }
    }

    requirement def RobotRequirements {
        subject r : Robot;
        requirement heightRequirement {
            doc /* The robot shall stand about 1.2 meters tall. */
            constraint { r.height == 1.2 [m] }
        }
        requirement massRequirement {
            doc /* The robot shall weigh 85 kg. */
            constraint { r.mass == 85 [kg] }
        }
        requirement speedRequirement {
            doc /* The robot shall move at speeds up to 2 m/s. */
            constraint { r.platform.maxSpeed <= 2 [m/s] }
        }
        requirement armReachRequirement {
            doc /* The arm shall reach up to 0.8 meters. */
            constraint { r.arm.reach <= 0.8 [m] }
        }
        requirement armPayloadRequirement {
            doc /* The arm shall lift objects up to 15 kg. */
            constraint { r.arm.payloadCapacity <= 15 [kg] }
        }
        requirement lidarRangeRequirement {
            doc /* The LIDAR shall detect obstacles up to 30 meters. */
            constraint { r.lidar.range >= 30 [m] }
        }
        requirement batteryRequirement {
            doc /* The robot shall use a 48-volt battery. */
            constraint { r.battery.voltage == 48 [V] }
        }
    }

    part robot : Robot;

    requirement robotSpec : RobotRequirements {
        subject = robot;
    }

}
