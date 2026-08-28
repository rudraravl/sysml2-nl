package AutonomousMobileManipulationRobot {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def Pose {
        attribute x : ISQ::Length;
        attribute y : ISQ::Length;
        attribute z : ISQ::Length;
        attribute roll : ISQ::PlaneAngle;
        attribute pitch : ISQ::PlaneAngle;
        attribute yaw : ISQ::PlaneAngle;
    }

    part def WheelEncoder {
        port encoderPort {
            out attribute distanceTraveled : ISQ::Length;
        }
    }

    part def Wheel {
        attribute radius : ISQ::Length = 0.1 [SI::m];
        part encoder : WheelEncoder;
        port drivePort {
            in attribute angularVelocity : ScalarValues::Real;
        }
    }

    part def MobileBase {
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        port navPort {
            in attribute targetLocation : Pose;
            out attribute currentLocation : Pose;
        }
    }

    part def ManipulatorJoint {
        port jointPort {
            in attribute targetAngle : ISQ::PlaneAngle;
            out attribute currentAngle : ISQ::PlaneAngle;
        }
    }

    part def ParallelGripper {
        attribute maxPayload : ISQ::Mass = 5 [SI::kg];
        attribute gripForce : ISQ::Force;
        port gripPort {
            in attribute gripCommand : Boolean;
            in attribute targetForce : ISQ::Force;
            out attribute objectGrasped : Boolean;
        }
    }

    part def ManipulatorArm {
        part joints : ManipulatorJoint[7];
        part gripper : ParallelGripper;
        port armCtrlPort {
            in attribute targetJointAngles : ISQ::PlaneAngle[7];
            out attribute currentJointAngles : ISQ::PlaneAngle[7];
        }
        port gripCtrlPort {
            in attribute gripCommand : Boolean;
            in attribute targetForce : ISQ::Force;
            out attribute objectGrasped : Boolean;
        }
        connect gripCtrlPort to gripper.gripPort;
    }

    part def LiDAR {
        port lidarPort {
            out attribute obstacleMap : Boolean[*];
            out attribute pointCloud : ISQ::Length[*];
        }
    }

    part def RGBDCamera {
        port cameraPort {
            out attribute objectLocation : Pose;
            out attribute colorImage : String;
            out attribute depthImage : String;
        }
    }

    state def ControllerBehavior {
        state Idle;
        state Scanning;
        state NavigatingToObject;
        state Manipulating;
        state Transporting;
        state Placing;
        state Returning;
        transition Idle to Scanning;
        transition Scanning to NavigatingToObject;
        transition NavigatingToObject to Manipulating;
        transition Manipulating to Transporting;
        transition Transporting to Placing;
        transition Placing to Returning;
        transition Returning to Idle;
    }

    part def CentralController {
        port sensorInputPort {
            in attribute obstacleMap : Boolean[*];
            in attribute pointCloud : ISQ::Length[*];
            in attribute objectLocation : Pose;
            in attribute currentLocation : Pose;
        }
        port controlOutputPort {
            out attribute targetLocation : Pose;
            out attribute targetJointAngles : ISQ::PlaneAngle[7];
            out attribute gripCommand : Boolean;
            out attribute targetForce : ISQ::Force;
        }
        state controllerBehavior : ControllerBehavior;
    }

    part def AutonomousRobot {
        part mobileBase : MobileBase;
        part manipulatorArm : ManipulatorArm;
        part lidar : LiDAR;
        part rgbCamera : RGBDCamera;
        part controller : CentralController;

        connect lidar.lidarPort to controller.sensorInputPort;
        connect rgbCamera.cameraPort to controller.sensorInputPort;
        connect mobileBase.navPort to controller.sensorInputPort;
        
        connect controller.controlOutputPort to mobileBase.navPort;
        connect controller.controlOutputPort to manipulatorArm.armCtrlPort;
        connect controller.controlOutputPort to manipulatorArm.gripCtrlPort;

        perform action pickAndPlaceMission {
            first start;
            then action scanArea : ScanArea;
            then action navigateToObject : NavigateToObject;
            then action approachObject : ApproachObject;
            then action graspObject : GraspObject;
            then action liftObject : LiftObject;
            then action transportObject : TransportObject;
            then action placeObject : PlaceObject;
            then action returnHome : ReturnHome;
            then done;
        }
    }

    action def ScanArea {
        out attribute objectFound : Boolean;
        out attribute objectLocation : Pose;
    }
    action def NavigateToObject {
        in attribute targetLocation : Pose;
        out attribute arrivalStatus : Boolean;
    }
    action def ApproachObject {
        in attribute targetLocation : Pose;
        out attribute approachStatus : Boolean;
    }
    action def GraspObject {
        in attribute gripForce : ISQ::Force;
        out attribute graspStatus : Boolean;
    }
    action def LiftObject {
        out attribute liftStatus : Boolean;
    }
    action def TransportObject {
        in attribute dropOffLocation : Pose;
        out attribute transportStatus : Boolean;
    }
    action def PlaceObject {
        out attribute placeStatus : Boolean;
    }
    action def ReturnHome {
        out attribute homeStatus : Boolean;
    }

    requirement def AccurateNavigation {
        doc /* The robot shall navigate to the target location with an error margin of less than 0.05 meters. */
        subject robot : AutonomousRobot;
        attribute errorMargin : ISQ::Length = 0.05 [SI::m];
    }
    
    requirement def ObstacleAvoidance {
        doc /* The robot shall maintain a safe margin of at least 0.2 meters from any detected obstacle. */
        subject robot : AutonomousRobot;
        attribute safeMargin : ISQ::Length = 0.2 [SI::m];
    }
    
    requirement def CycleTime {
        doc /* The robot shall complete a full pick-and-place cycle in under 60 seconds. */
        subject robot : AutonomousRobot;
        attribute maxCycleTime : ISQ::Time = 60 [SI::s];
    }
}
