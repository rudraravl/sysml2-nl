package SpotRobotModel {
    attribute def TorqueValue;
    attribute def AngleValue;
    attribute def AngularVelocityValue;
    attribute def LinearAccelerationValue;
    attribute def VoltageValue;
    attribute def ElectricChargeValue;
    attribute def MassValue;

    item def PerceptionData;
    item def LidarScanData;
    item def CameraImageData;
    item def DepthMapData;
    item def ImuData;
    item def MapData;
    item def ObstacleListData;
    item def TrajectoryData;
    item def GaitPatternData;
    item def ActuatorCommand;
    item def PowerSignal;
    item def BatteryStatusData;
    item def OperatorCommandData;
    item def TelemetryData;

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def InitCompleteSignal;
    attribute def StartMissionSignal;
    attribute def StopMissionSignal;
    attribute def MissionCompleteSignal;
    attribute def ManualControlSignal;
    attribute def AutonomousSignal;
    attribute def CriticalErrorSignal;
    attribute def SafeStopCompleteSignal;

    action def CalibrateSensors;
    action def CheckSystems;
    action def PerceiveEnvironment;
    action def PlanTrajectory;
    action def GenerateGait;
    action def RunBalanceControl;
    action def DetectAndAvoidObstacles;
    action def PerformSafeStop;
    action def ExecuteMission;
    action def EnableManualControl;
    action def DisableManualControl;

    part def Actuator {
        attribute maxTorque : TorqueValue;
        port commandIn {
            in command : ActuatorCommand;
        }
        port feedbackOut {
            out jointAngle : AngleValue;
            out jointVelocity : AngularVelocityValue;
        }
        port powerIn {
            in power : PowerSignal;
        }
    }

    part def Leg {
        part hipActuator : Actuator;
        part shoulderActuator : Actuator;
        part kneeActuator : Actuator;
        port commandIn {
            in hipCmd : ActuatorCommand;
            in shoulderCmd : ActuatorCommand;
            in kneeCmd : ActuatorCommand;
        }
        port feedbackOut {
            out hipAngle : AngleValue;
            out shoulderAngle : AngleValue;
            out kneeAngle : AngleValue;
        }
        port powerIn {
            in power : PowerSignal;
        }
        connect commandIn.hipCmd to hipActuator.commandIn;
        connect commandIn.shoulderCmd to shoulderActuator.commandIn;
        connect commandIn.kneeCmd to kneeActuator.commandIn;
        connect hipActuator.feedbackOut.jointAngle to feedbackOut.hipAngle;
        connect shoulderActuator.feedbackOut.jointAngle to feedbackOut.shoulderAngle;
        connect kneeActuator.feedbackOut.jointAngle to feedbackOut.kneeAngle;
        connect powerIn to hipActuator.powerIn;
        connect powerIn to shoulderActuator.powerIn;
        connect powerIn to kneeActuator.powerIn;
    }

    part def LidarScanner {
        port dataOut {
            out scanData : LidarScanData;
        }
        port powerIn {
            in power : PowerSignal;
        }
    }

    part def StereoCamera {
        port imageDataOut {
            out imageData : CameraImageData;
        }
        port depthDataOut {
            out depthData : DepthMapData;
        }
        port powerIn {
            in power : PowerSignal;
        }
    }

    part def DepthCamera {
        port depthDataOut {
            out depthData : DepthMapData;
        }
        port powerIn {
            in power : PowerSignal;
        }
    }

    part def IMU {
        port dataOut {
            out orientation : AngleValue;
            out angularVelocity : AngularVelocityValue;
            out linearAcceleration : LinearAccelerationValue;
        }
        port powerIn {
            in power : PowerSignal;
        }
    }

    part def BatteryPack {
        attribute capacity : ElectricChargeValue;
        attribute mass : MassValue;
        port powerOut {
            out power : PowerSignal;
            out voltage : VoltageValue;
        }
        port statusOut {
            out status : BatteryStatusData;
        }
    }

    part def OperatorCommUnit {
        port commandOut {
            out command : OperatorCommandData;
        }
        port telemetryIn {
            in telemetry : TelemetryData;
        }
    }

    part def ComputeModule {
        port frontLidarIn {
            in scanData : LidarScanData;
        }
        port rearLidarIn {
            in scanData : LidarScanData;
        }
        port stereoImageIn {
            in imageData : CameraImageData;
        }
        port stereoDepthIn {
            in depthData : DepthMapData;
        }
        port depthCameraIn {
            in depthData : DepthMapData;
        }
        port imuIn {
            in orientation : AngleValue;
            in angularVelocity : AngularVelocityValue;
            in linearAcceleration : LinearAccelerationValue;
        }
        port leg1CmdOut {
            out hipCmd : ActuatorCommand;
            out shoulderCmd : ActuatorCommand;
            out kneeCmd : ActuatorCommand;
        }
        port leg2CmdOut {
            out hipCmd : ActuatorCommand;
            out shoulderCmd : ActuatorCommand;
            out kneeCmd : ActuatorCommand;
        }
        port leg3CmdOut {
            out hipCmd : ActuatorCommand;
            out shoulderCmd : ActuatorCommand;
            out kneeCmd : ActuatorCommand;
        }
        port leg4CmdOut {
            out hipCmd : ActuatorCommand;
            out shoulderCmd : ActuatorCommand;
            out kneeCmd : ActuatorCommand;
        }
        port leg1FeedbackIn {
            in hipAngle : AngleValue;
            in shoulderAngle : AngleValue;
            in kneeAngle : AngleValue;
        }
        port leg2FeedbackIn {
            in hipAngle : AngleValue;
            in shoulderAngle : AngleValue;
            in kneeAngle : AngleValue;
        }
        port leg3FeedbackIn {
            in hipAngle : AngleValue;
            in shoulderAngle : AngleValue;
            in kneeAngle : AngleValue;
        }
        port leg4FeedbackIn {
            in hipAngle : AngleValue;
            in shoulderAngle : AngleValue;
            in kneeAngle : AngleValue;
        }
        port batteryStatusIn {
            in status : BatteryStatusData;
        }
        port powerIn {
            in power : PowerSignal;
        }
        port operatorIn {
            in command : OperatorCommandData;
        }
        port telemetryOut {
            out telemetry : TelemetryData;
        }

        perform action processPerception {
            in perceptionData : PerceptionData;
            out mapData : MapData;
            first start;
            then action fuseSensorData;
            then action buildOccupancyMap;
            then action detectObstacles;
            then done;
        }

        perform action planAndExecuteMotion {
            in mapData : MapData;
            out gaitPattern : GaitPatternData;
            first start;
            then action planTrajectory;
            then action generateGait;
            then action computeActuatorCommands;
            then action sendLegCommands;
            then action runBalanceControl;
            then done;
        }
    }

    part def SpotRobot {
        attribute mass : MassValue;

        part body;
        part battery : BatteryPack;
        part leg1 : Leg;
        part leg2 : Leg;
        part leg3 : Leg;
        part leg4 : Leg;
        part frontLidar : LidarScanner;
        part rearLidar : LidarScanner;
        part stereoCamera : StereoCamera;
        part depthCamera : DepthCamera;
        part imu : IMU;
        part computeModule : ComputeModule;
        part operatorComm : OperatorCommUnit;

        connect battery.powerOut to computeModule.powerIn;
        connect battery.powerOut to leg1.powerIn;
        connect battery.powerOut to leg2.powerIn;
        connect battery.powerOut to leg3.powerIn;
        connect battery.powerOut to leg4.powerIn;
        connect battery.powerOut to frontLidar.powerIn;
        connect battery.powerOut to rearLidar.powerIn;
        connect battery.powerOut to stereoCamera.powerIn;
        connect battery.powerOut to depthCamera.powerIn;
        connect battery.powerOut to imu.powerIn;
        connect battery.statusOut to computeModule.batteryStatusIn;

        connect frontLidar.dataOut to computeModule.frontLidarIn;
        connect rearLidar.dataOut to computeModule.rearLidarIn;
        connect stereoCamera.imageDataOut to computeModule.stereoImageIn;
        connect stereoCamera.depthDataOut to computeModule.stereoDepthIn;
        connect depthCamera.depthDataOut to computeModule.depthCameraIn;
        connect imu.dataOut to computeModule.imuIn;

        connect computeModule.leg1CmdOut to leg1.commandIn;
        connect computeModule.leg2CmdOut to leg2.commandIn;
        connect computeModule.leg3CmdOut to leg3.commandIn;
        connect computeModule.leg4CmdOut to leg4.commandIn;

        connect leg1.feedbackOut to computeModule.leg1FeedbackIn;
        connect leg2.feedbackOut to computeModule.leg2FeedbackIn;
        connect leg3.feedbackOut to computeModule.leg3FeedbackIn;
        connect leg4.feedbackOut to computeModule.leg4FeedbackIn;

        connect operatorComm.commandOut to computeModule.operatorIn;
        connect computeModule.telemetryOut to operatorComm.telemetryIn;

        state spotStates {
            entry; then poweredOff;

            state poweredOff;
            accept PowerOnSignal then initializing;

            state initializing {
                entry action calibrateSensors {
                    /* Calibrate LIDAR, cameras, and IMU */
                }
                do action checkSystems {
                    /* Check battery, actuators, and compute module */
                }
            }
            accept InitCompleteSignal then standby;
            accept CriticalErrorSignal then emergency;

            state standby;
            accept StartMissionSignal then operational;
            accept PowerOffSignal then poweredOff;
            accept CriticalErrorSignal then emergency;

            state operational {
                entry action executeMission {
                    /* Begin autonomous navigation */
                }
                do action runAutonomousNavigation {
                    /* Perceive environment, detect obstacles, plan trajectory, generate gait, run balance control */
                }
            }
            accept MissionCompleteSignal then standby;
            accept StopMissionSignal then standby;
            accept ManualControlSignal then manualControl;
            accept CriticalErrorSignal then emergency;

            state manualControl {
                entry action enableManualControl {
                    /* Enable operator control */
                }
                exit action disableManualControl {
                    /* Disable operator control */
                }
            }
            accept AutonomousSignal then operational;
            accept CriticalErrorSignal then emergency;

            state emergency {
                entry action performSafeStop {
                    /* Lock actuators and cut drive power */
                }
            }
            accept SafeStopCompleteSignal then standby;
        }
    }

    part spotRobot : SpotRobot;

    requirement def MobilityRequirement;
    requirement def PerceptionRequirement;
    requirement def AutonomyRequirement;
    requirement def SafetyRequirement;
    requirement def CommunicationRequirement;

    requirement mobilityReq : MobilityRequirement {
        text = "The robot shall move dynamically and stably across varied terrain.";
        satisfiedBy = spotRobot;
    }

    requirement perceptionReq : PerceptionRequirement {
        text = "The robot shall perceive its environment using LIDAR, cameras, and IMU.";
        satisfiedBy = spotRobot;
    }

    requirement autonomyReq : AutonomyRequirement {
        text = "The robot shall autonomously navigate pre-defined paths while detecting and avoiding obstacles.";
        satisfiedBy = spotRobot;
    }

    requirement safetyReq : SafetyRequirement {
        text = "The robot shall perform a safe stop upon detecting a critical error.";
        satisfiedBy = spotRobot;
    }

    requirement communicationReq : CommunicationRequirement {
        text = "The robot shall support manual operator control and telemetry reporting.";
        satisfiedBy = spotRobot;
    }
}
