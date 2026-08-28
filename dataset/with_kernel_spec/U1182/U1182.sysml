package MobilePickAndPlaceRobot {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def LengthValue :> Real;
    attribute def MassValue :> Real;
    attribute def ForceValue :> Real;
    attribute def SpeedValue :> Real;
    attribute def BatteryLevelValue :> Real;

    attribute def ObjectInfo {
        attribute id : Integer;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
    }

    attribute def StartMission;
    attribute def TargetDetected;
    attribute def TargetReached;
    attribute def ArmPositioned;
    attribute def ObjectGrasped;
    attribute def DestinationReached;
    attribute def ObjectReleased;
    attribute def BatteryLow;
    attribute def BatteryRecovered;

    part def Wheel;
    part def Joint;

    part def Gripper {
        attribute maxPayload : MassValue = 8;
        attribute maxForce : ForceValue = 50;
        port commandPort {
            in attribute force : ForceValue;
            in attribute open : Boolean;
        }
    }

    part def RoboticArm {
        attribute reach : LengthValue = 1.0;
        part joints[6] : Joint;
        part gripper : Gripper;
        port armCommandPort {
            in attribute jointAngles : Real[6];
        }
        port gripperCommandPort {
            in attribute force : ForceValue;
            in attribute open : Boolean;
        }
    }

    part def MobilePlatform {
        attribute maxSafeSpeed : SpeedValue = 1.5;
        part wheels[4] : Wheel;
        port navCommandPort {
            in attribute target : ObjectInfo;
        }
    }

    part def VisionSensor {
        attribute detectionRange : LengthValue = 5.0;
        port dataPort {
            out attribute objectData : ObjectInfo;
        }
    }

    part def ProximitySensor {
        attribute maxRange : LengthValue = 1.5;
        port dataPort {
            out attribute distance : LengthValue;
        }
    }

    part def Battery {
        attribute capacity : BatteryLevelValue = 100;
        attribute currentLevel : BatteryLevelValue = 100;
        port powerPort {
            out attribute level : BatteryLevelValue;
        }
    }

    part def PowerModule {
        attribute minThreshold : BatteryLevelValue = 20;
        port batteryPort {
            in attribute level : BatteryLevelValue;
        }
        port monitorPort {
            out attribute batteryStatus : BatteryLevelValue;
        }
        perform action monitorBattery : MonitorBattery;
    }

    part def ControlModule {
        port visionIn {
            in attribute objectData : ObjectInfo;
        }
        port proximityIn {
            in attribute distances : LengthValue[4];
        }
        port navOut {
            out attribute navCommand : ObjectInfo;
        }
        port armOut {
            out attribute armCommand : Real[6];
        }
        port gripperOut {
            out attribute gripForce : ForceValue;
            out attribute gripOpen : Boolean;
        }
        port powerIn {
            in attribute batteryStatus : BatteryLevelValue;
        }
    }

    action def ScanForObject {
        out target : ObjectInfo;
    }
    action def NavigateToTarget {
        in target : ObjectInfo;
    }
    action def PositionArm {
        in target : ObjectInfo;
    }
    action def GraspObject {
        in target : ObjectInfo;
    }
    action def TransportObject {
        in destination : ObjectInfo;
    }
    action def ReleaseObject;
    action def MonitorBattery {
        out batteryStatus : BatteryLevelValue;
    }
    action def HaltOperations;

    action def PickAndPlaceMission {
        in destination : ObjectInfo;
        action scan : ScanForObject { out target; }
        first scan;
        then action navigate : NavigateToTarget { in target = scan.target; }
        then action position : PositionArm { in target = scan.target; }
        then action grasp : GraspObject { in target = scan.target; }
        then action transport : TransportObject { in destination; }
        then action release : ReleaseObject;
        then done;
    }

    state def MissionStates {
        entry action initial;
        transition initial then idle;

        state idle;
        transition 'idle-scanning'
            first idle
            accept StartMission
            then scanning;

        state scanning;
        transition 'scanning-navigating'
            first scanning
            accept TargetDetected
            then navigating;

        state navigating;
        transition 'navigating-positioning'
            first navigating
            accept TargetReached
            then positioning;

        state positioning;
        transition 'positioning-grasping'
            first positioning
            accept ArmPositioned
            then grasping;

        state grasping;
        transition 'grasping-transporting'
            first grasping
            accept ObjectGrasped
            then transporting;

        state transporting;
        transition 'transporting-releasing'
            first transporting
            accept DestinationReached
            then releasing;

        state releasing;
        transition 'releasing-idle'
            first releasing
            accept ObjectReleased
            then idle;

        state aborted;
        transition 'abort-from-idle'
            first idle
            accept BatteryLow
            then aborted;
        transition 'abort-from-scanning'
            first scanning
            accept BatteryLow
            then aborted;
        transition 'abort-from-navigating'
            first navigating
            accept BatteryLow
            then aborted;
        transition 'abort-from-positioning'
            first positioning
            accept BatteryLow
            then aborted;
        transition 'abort-from-grasping'
            first grasping
            accept BatteryLow
            then aborted;
        transition 'abort-from-transporting'
            first transporting
            accept BatteryLow
            then aborted;
        transition 'abort-from-releasing'
            first releasing
            accept BatteryLow
            then aborted;
    }

    state def PowerMonitoringStates {
        entry action initial;
        transition initial then normal;

        state normal;
        transition 'normal-lowBattery'
            first normal
            accept BatteryLow
            then lowBattery;

        state lowBattery;
        transition 'lowBattery-normal'
            first lowBattery
            accept BatteryRecovered
            then normal;
    }

    state def RobotStates parallel {
        state mission : MissionStates;
        state power : PowerMonitoringStates;
    }

    part def Robot {
        attribute safeSpeed : SpeedValue = 1.5;

        part mobilePlatform : MobilePlatform;
        part roboticArm : RoboticArm;
        part controlModule : ControlModule;
        part visionSensor : VisionSensor;
        part proximitySensors[4] : ProximitySensor;
        part battery : Battery;
        part powerModule : PowerModule;

        perform action pickAndPlaceMission : PickAndPlaceMission;
        exhibit state robotStates : RobotStates;

        connect visionSensor.dataPort to controlModule.visionIn;
        connect proximitySensors.dataPort to controlModule.proximityIn;
        connect controlModule.navOut to mobilePlatform.navCommandPort;
        connect controlModule.armOut to roboticArm.armCommandPort;
        connect controlModule.gripperOut to roboticArm.gripperCommandPort;
        connect battery.powerPort to powerModule.batteryPort;
        connect powerModule.monitorPort to controlModule.powerIn;
    }

    requirement <'REQ-01'> payloadCapacity {
        doc /* The gripper shall securely hold objects up to 8 kg without crushing them. */
        subject gripper : Gripper;
        assert constraint { gripper.maxPayload >= 8 }
    }

    requirement <'REQ-02'> armReach {
        doc /* The robotic arm shall provide a reach of approximately one meter. */
        subject arm : RoboticArm;
        assert constraint { arm.reach >= 0.9 and arm.reach <= 1.1 }
    }

    requirement <'REQ-03'> visionRange {
        doc /* The vision sensor shall detect and identify target objects up to 5 meters away. */
        subject sensor : VisionSensor;
        assert constraint { sensor.detectionRange >= 5.0 }
    }

    requirement <'REQ-04'> safeSpeed {
        doc /* The navigation system shall adhere to a safe maximum speed of 1.5 m/s. */
        subject platform : MobilePlatform;
        assert constraint { platform.maxSafeSpeed <= 1.5 }
    }

    requirement <'REQ-05'> batteryThreshold {
        doc /* The battery shall remain above a minimum threshold to ensure task completion. */
        subject power : PowerModule;
        assert constraint { power.minThreshold >= 20 }
    }

    requirement <'REQ-06'> autonomousPickAndPlace {
        doc /* The robot shall autonomously locate, grasp, transport, and release objects within its operational area. */
        subject robot : Robot;
    }

    part robot : Robot;

    satisfy payloadCapacity by robot.roboticArm.gripper;
    satisfy armReach by robot.roboticArm;
    satisfy visionRange by robot.visionSensor;
    satisfy safeSpeed by robot.mobilePlatform;
    satisfy batteryThreshold by robot.powerModule;
    satisfy autonomousPickAndPlace by robot;
}
