package AutonomousHexapodRobotSystem {
    private import ScalarValues::*;

    enum def BatteryStatusKind {
        nominal;
        low;
        critical;
    }

    enum def GaitKind {
        tripod;
        wave;
    }

    enum def MissionStateKind {
        idle;
        navigatingToObject;
        graspingObject;
        transportingObject;
        releasingObject;
        returningToBase;
    }

    attribute def SigStartMission;
    attribute def SigObjectReached;
    attribute def SigObjectGrasped;
    attribute def SigObjectTransported;
    attribute def SigObjectReleased;
    attribute def SigReturnLocationReached;
    attribute def SigMissionComplete;
    attribute def SigRoughTerrain;
    attribute def SigFlatTerrain;
    attribute def SigLowBattery;

    port def PowerOutPort {
        out attribute voltage : Real;
        out attribute current : Real;
    }

    port def PowerInPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }

    port def BatteryStatusOutPort {
        out attribute status : BatteryStatusKind;
    }

    port def BatteryStatusInPort {
        in attribute status : BatteryStatusKind;
    }

    port def ProximityDataOutPort {
        out attribute detectedDistance : Real;
    }

    port def ProximityDataInPort {
        in attribute detectedDistance : Real;
    }

    port def LiDarDataOutPort {
        out attribute pointCloud : String;
    }

    port def LiDarDataInPort {
        in attribute pointCloud : String;
    }

    port def CameraDataOutPort {
        out attribute imageData : String;
    }

    port def CameraDataInPort {
        in attribute imageData : String;
    }

    port def ImuDataOutPort {
        out attribute orientation : String;
        out attribute angularVelocity : String;
    }

    port def ImuDataInPort {
        in attribute orientation : String;
        in attribute angularVelocity : String;
    }

    port def LegCommandOutPort {
        out attribute targetAngle : Real;
    }

    port def LegCommandInPort {
        in attribute targetAngle : Real;
    }

    port def LegFeedbackOutPort {
        out attribute currentAngle : Real;
        out attribute loadForce : Real;
    }

    port def LegFeedbackInPort {
        in attribute currentAngle : Real;
        in attribute loadForce : Real;
    }

    port def ArmCommandOutPort {
        out attribute jointTargets : String;
        out attribute gripForceTarget : Real;
    }

    port def ArmCommandInPort {
        in attribute jointTargets : String;
        in attribute gripForceTarget : Real;
    }

    port def ArmFeedbackOutPort {
        out attribute jointPositions : String;
        out attribute measuredGripForce : Real;
    }

    port def ArmFeedbackInPort {
        in attribute jointPositions : String;
        in attribute measuredGripForce : Real;
    }

    port def LocomotionCommandOutPort {
        out attribute gaitCommand : GaitKind;
        out attribute travelSpeed : Real;
    }

    port def LocomotionCommandInPort {
        in attribute gaitCommand : GaitKind;
        in attribute travelSpeed : Real;
    }

    port def MissionCommandOutPort {
        out attribute missionPlan : String;
    }

    port def MissionCommandInPort {
        in attribute missionPlan : String;
    }

    port def TelemetryOutPort {
        out attribute status : String;
    }

    port def TelemetryInPort {
        in attribute status : String;
    }

    part def RobotBody {
        attribute mass : Real;
    }

    part def LegSegment {
        attribute length : Real;
    }

    part def JointActuator {
        attribute commandedAngle : Real;
        attribute currentAngle : Real;
        port controlPort : LegCommandInPort;
        port feedbackPort : LegFeedbackOutPort;
        port powerIn : PowerInPort;
    }

    part def LegAssembly {
        part coxa : LegSegment;
        part femur : LegSegment;
        part tibia : LegSegment;
        part coxaActuator : JointActuator;
        part femurActuator : JointActuator;
        part tibiaActuator : JointActuator;
        port powerIn : PowerInPort;
        port commandIn : LegCommandInPort;
        port feedbackOut : LegFeedbackOutPort;

        connect coxaActuator to coxa;
        connect femurActuator to femur;
        connect tibiaActuator to tibia;
        connect commandIn to coxaActuator.controlPort;
        connect commandIn to femurActuator.controlPort;
        connect commandIn to tibiaActuator.controlPort;
        connect coxaActuator.feedbackPort to feedbackOut;
        connect femurActuator.feedbackPort to feedbackOut;
        connect tibiaActuator.feedbackPort to feedbackOut;
    }

    part def ProximitySensor {
        attribute maxRange : Real;
        port dataOut : ProximityDataOutPort;
        port powerIn : PowerInPort;
    }

    part def LiDarSensor {
        attribute scanRate : Real;
        port dataOut : LiDarDataOutPort;
        port powerIn : PowerInPort;
    }

    part def HighResolutionCamera {
        port dataOut : CameraDataOutPort;
        port powerIn : PowerInPort;
    }

    part def InertialMeasurementUnit {
        port dataOut : ImuDataOutPort;
        port powerIn : PowerInPort;
    }

    part def ForceSensor {
        port forceOut {
            out attribute measuredForce : Real;
        }
    }

    part def Gripper {
        part forceSensors[2] : ForceSensor;
        port gripCommandIn {
            in attribute commandedGripForce : Real;
        }
        port forceFeedbackOut {
            out attribute measuredGripForce : Real;
        }
    }

    part def ArmJoint {
        part actuator : JointActuator;
    }

    part def ManipulatorArm {
        part joints[3] : ArmJoint;
        part gripper : Gripper;
        port commandIn : ArmCommandInPort;
        port feedbackOut : ArmFeedbackOutPort;
        port powerIn : PowerInPort;
    }

    part def Battery {
        attribute capacity : Real;
        attribute stateOfCharge : Real;
        port powerOut : PowerOutPort;
        port statusOut : BatteryStatusOutPort;

        perform action reportStatus {
            out attribute status : BatteryStatusKind;
            first start;
            then action readStateOfCharge;
            then action classifyStatus;
            then done;
        }
    }

    part def PowerDistributionUnit {
        port powerIn : PowerInPort;
        port powerOutLegs[6] : PowerOutPort;
        port powerOutSensors : PowerOutPort;
        port powerOutManipulator : PowerOutPort;
        port powerOutControl : PowerOutPort;
        port batteryStatusIn : BatteryStatusInPort;

        perform action managePower {
            first start;
            then action monitorBattery;
            then action allocatePower;
            then done;
        }
    }

    part def LocomotionController {
        port locomotionCommandIn : LocomotionCommandInPort;
        port legCommandOut[6] : LegCommandOutPort;
        port legFeedbackIn[6] : LegFeedbackInPort;
        port powerIn : PowerInPort;

        state gaitState {
            entry; then tripodGait;
            state tripodGait;
            transition tripodToWave
                first tripodGait
                accept SigRoughTerrain
                then waveGait;
            state waveGait;
            transition waveToTripod
                first waveGait
                accept SigFlatTerrain
                then tripodGait;
        }

        perform action generateLegMotion {
            in attribute requestedGait : GaitKind;
            out attribute legAngles : String;
            first start;
            then action readRequestedGait;
            then action computeLegTrajectories;
            then action outputLegCommands;
            then done;
        }
    }

    part def MissionControlComputer {
        port powerIn : PowerInPort;
        port batteryStatusIn : BatteryStatusInPort;
        port frontProximityIn[2] : ProximityDataInPort;
        port sideProximityIn[2] : ProximityDataInPort;
        port lidarIn : LiDarDataInPort;
        port cameraIn : CameraDataInPort;
        port imuIn : ImuDataInPort;
        port armCommandOut : ArmCommandOutPort;
        port armFeedbackIn : ArmFeedbackInPort;
        port locomotionCommandOut : LocomotionCommandOutPort;
        port missionCommandIn : MissionCommandInPort;
        port telemetryOut : TelemetryOutPort;

        perform action sensePlanAct {
            first start;
            then action senseEnvironment;
            then action planTrajectory;
            then action executeMotion;
            then done;
        }

        perform action graspObject {
            first start;
            then action positionArm;
            then action closeGripper;
            then action verifyGripForce;
            then done;
        }

        perform action releaseObject {
            first start;
            then action openGripper;
            then action retractArm;
            then done;
        }

        state missionState {
            entry; then idle;
            state idle;
            accept SigStartMission then navigatingToObject;
            state navigatingToObject;
            accept SigObjectReached then graspingObject;
            state graspingObject;
            accept SigObjectGrasped then transportingObject;
            state transportingObject;
            accept SigObjectTransported then releasingObject;
            state releasingObject;
            accept SigObjectReleased then returningToBase;
            state returningToBase;
            accept SigReturnLocationReached then idle;
        }
    }

    part def HexapodRobot {
        attribute mass : Real;
        attribute operatingTime : Real;

        part body : RobotBody;
        part legs[6] : LegAssembly;
        part frontProximitySensors[2] : ProximitySensor;
        part sideProximitySensors[2] : ProximitySensor;
        part lidar : LiDarSensor;
        part camera : HighResolutionCamera;
        part imu : InertialMeasurementUnit;
        part manipulatorArm : ManipulatorArm;
        part battery : Battery;
        part powerDistributionUnit : PowerDistributionUnit;
        part controlComputer : MissionControlComputer;
        part locomotionController : LocomotionController;

        connect battery.powerOut to powerDistributionUnit.powerIn;
        connect battery.statusOut to powerDistributionUnit.batteryStatusIn;
        connect battery.statusOut to controlComputer.batteryStatusIn;

        connect powerDistributionUnit.powerOutLegs to legs.powerIn;

        connect powerDistributionUnit.powerOutSensors to frontProximitySensors.powerIn;
        connect powerDistributionUnit.powerOutSensors to sideProximitySensors.powerIn;
        connect powerDistributionUnit.powerOutSensors to lidar.powerIn;
        connect powerDistributionUnit.powerOutSensors to camera.powerIn;
        connect powerDistributionUnit.powerOutSensors to imu.powerIn;

        connect powerDistributionUnit.powerOutManipulator to manipulatorArm.powerIn;
        connect powerDistributionUnit.powerOutControl to controlComputer.powerIn;
        connect powerDistributionUnit.powerOutControl to locomotionController.powerIn;

        connect frontProximitySensors.dataOut to controlComputer.frontProximityIn;
        connect sideProximitySensors.dataOut to controlComputer.sideProximityIn;
        connect lidar.dataOut to controlComputer.lidarIn;
        connect camera.dataOut to controlComputer.cameraIn;
        connect imu.dataOut to controlComputer.imuIn;

        connect controlComputer.armCommandOut to manipulatorArm.commandIn;
        connect manipulatorArm.feedbackOut to controlComputer.armFeedbackIn;
        connect controlComputer.locomotionCommandOut to locomotionController.locomotionCommandIn;

        connect locomotionController.legCommandOut to legs.commandIn;
        connect legs.feedbackOut to locomotionController.legFeedbackIn;
    }

    part def MissionPlanner {
        port missionPlanOut : MissionCommandOutPort;
        port telemetryIn : TelemetryInPort;

        perform action planMission {
            out attribute missionPlan : String;
            first start;
            then action defineWaypoints;
            then action definePickupLocation;
            then action defineReturnLocation;
            then action uploadPlan;
            then done;
        }
    }

    part def RemoteControlStation {
        part missionPlanner : MissionPlanner;
    }

    requirement def HexapodLocomotionRequirement {
        doc /* The robot shall use six legs, each with three actuated segments, to provide stable locomotion across challenging terrain. */
        subject robot : HexapodRobot;
    }

    requirement def GaitAdaptationRequirement {
        doc /* The locomotion controller shall select tripod gait for flat terrain and wave gait for rough or inclined terrain. */
        subject controller : LocomotionController;
    }

    requirement def AutonomousNavigationRequirement {
        doc /* The robot shall autonomously navigate to a specified object location while continuously scanning for and avoiding obstacles. */
        subject robot : HexapodRobot;
    }

    requirement def GraspForceControlRequirement {
        doc /* The gripper shall apply a controlled grasp force using feedback from force sensors. */
        subject gripper : Gripper;
    }

    requirement def EnduranceRequirement {
        doc /* The system shall provide at least two hours of operational time on a single battery charge. */
        attribute minOperationalTime : Real = 2.0;
        subject robot : HexapodRobot;
    }

    requirement def MissionExecutionRequirement {
        doc /* The robot shall grasp a specified object, transport it to a designated return location, and release it. */
        subject robot : HexapodRobot;
    }

    requirement hexapodLocomotionRequirement : HexapodLocomotionRequirement;
    requirement autonomousNavigationRequirement : AutonomousNavigationRequirement;
    requirement enduranceRequirement : EnduranceRequirement;
    requirement missionExecutionRequirement : MissionExecutionRequirement;

    part hexapodRobotSystem {
        part robot : HexapodRobot {
            satisfy hexapodLocomotionRequirement;
            satisfy autonomousNavigationRequirement;
            satisfy enduranceRequirement;
            satisfy missionExecutionRequirement;
        }
        part station : RemoteControlStation;
        connect robot.controlComputer.missionCommandIn to station.missionPlanner.missionPlanOut;
        connect robot.controlComputer.telemetryOut to station.missionPlanner.telemetryIn;
    }
}
