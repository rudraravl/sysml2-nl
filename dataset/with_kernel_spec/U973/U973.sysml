package AnybotTelepresenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def BatteryLevel :> ScalarValues::Real;
    attribute def DistanceValue :> ISQ::LengthValue;
    attribute def AngleMeasure :> ISQ::AngleValue;
    attribute def VideoQualityLevel :> ScalarValues::Real;
    attribute def AudioSignal;
    attribute def VideoSignal;

    attribute def NavigationCommand {
        attribute linearVelocity : ISQ::SpeedValue;
        attribute angularVelocity : ISQ::AngularSpeedValue;
    }
    attribute def CameraCommand {
        attribute pan : AngleMeasure;
        attribute tilt : AngleMeasure;
        attribute zoom : ScalarValues::Real;
    }
    attribute def TelemetryData {
        attribute position : ScalarValues::String;
        attribute batteryLevel : BatteryLevel;
        attribute sensorReadings : ScalarValues::String;
        attribute videoQuality : VideoQualityLevel;
    }
    attribute def AudioVideoStream {
        attribute video : VideoSignal;
        attribute audio : AudioSignal;
    }
    attribute def ProximityAlert {
        attribute sensorId : ScalarValues::String;
        attribute distance : DistanceValue;
    }

    attribute def SigPowerOn;
    attribute def SigActivate;
    attribute def SigDeactivate;
    attribute def SigShutdown;
    attribute def SigMoveCommand;
    attribute def SigStopCommand;
    attribute def SigObstacleClose;
    attribute def SigObstacleClear;
    attribute def SigBatteryLow;
    attribute def SigBatteryCritical;
    attribute def SigReachedCharger;
    attribute def SigChargeComplete;
    attribute def SigBatteryDepleted;

    state def RobotActiveStates;

    port def NetworkPort {
        in navCmd : NavigationCommand;
        in camCmd : CameraCommand;
        in operatorAudio : AudioSignal;
        out telemetry : TelemetryData;
        out avStream : AudioVideoStream;
    }

    port def SensorPort {
        out distance : DistanceValue;
    }

    port def PowerPort {
        out level : BatteryLevel;
    }

    port def DriveCmdPort {
        in cmd : NavigationCommand;
    }

    port def CameraCmdPort {
        in cmd : CameraCommand;
    }

    port def AudioModulePort {
        in remoteAudio : AudioSignal;
        out localAudio : AudioSignal;
    }

    action def ProcessCommands {
        in navCmd : NavigationCommand;
        in camCmd : CameraCommand;
        first start;
        then action receiveCommands;
        then action coordinateActions;
        then done;
    }

    action def ReduceVideoQuality {
        out quality : VideoQualityLevel;
    }

    action def AlertOperator {
        out alert : ScalarValues::String;
    }

    action def NavigateToCharger {
        out target : ScalarValues::String;
    }

    action def ReadSensors {
        out dist : DistanceValue;
    }

    action def ProcessAudio {
        in audioIn : AudioSignal;
        out audioOut : AudioSignal;
    }

    action def PanTiltZoom {
        in cmd : CameraCommand;
    }

    action def DriveMotors {
        in cmd : NavigationCommand;
    }

    part def MobilityBase {
        port driveCmdPort : DriveCmdPort;
        perform action driveMotors : DriveMotors;
        state mobilityStates {
            entry; then idle;
            state idle;
            accept SigMoveCommand then moving;
            state moving;
            accept SigStopCommand then idle;
        }
    }

    part def CameraModule {
        port cameraCmdPort : CameraCmdPort;
        port videoOutPort { out video : VideoSignal; }
        attribute pan : AngleMeasure;
        attribute tilt : AngleMeasure;
        attribute zoom : ScalarValues::Real;
        perform action panTiltZoom : PanTiltZoom;
    }

    part def AudioModule {
        port audioPort : AudioModulePort;
        part microphone;
        part speaker;
        perform action processAudio : ProcessAudio;
    }

    part def ProximitySensor {
        port sensorPort : SensorPort;
        attribute position : ScalarValues::String;
        perform action readSensors : ReadSensors;
    }

    part def BatterySystem {
        port powerPort : PowerPort;
        attribute level : BatteryLevel = 100.0;
        state batteryStates {
            entry; then normal;
            state normal;
            accept SigBatteryLow then low;
            state low;
            accept SigBatteryCritical then critical;
            state critical;
        }
    }

    part def ControlProcessor {
        port navCmdInPort { in navCmd : NavigationCommand; }
        port camCmdInPort { in camCmd : CameraCommand; }
        port frontSensorPort { in distance : DistanceValue; }
        port leftSensorPort { in distance : DistanceValue; }
        port rightSensorPort { in distance : DistanceValue; }
        port powerInPort { in battLevel : BatteryLevel; }
        port navCmdOutPort { out navCmd : NavigationCommand; }
        port camCmdOutPort { out camCmd : CameraCommand; }
        port telemetryOutPort { out telemetry : TelemetryData; }
        port powerPolicyOutPort { out policy : VideoQualityLevel; }
        perform action processCommands : ProcessCommands;
        perform action reduceVideoQuality : ReduceVideoQuality;
        perform action alertOperator : AlertOperator;
        perform action navigateToCharger : NavigateToCharger;
        state robotStates {
            entry; then off;
            state off;
            accept SigPowerOn then standby;
            state standby;
            accept SigActivate then active;
            state active : RobotActiveStates parallel {
                state navigationStates {
                    entry; then moving;
                    state moving;
                    accept SigStopCommand then stopped;
                    state stopped;
                    accept SigMoveCommand then moving;
                }
                state safetyStates {
                    entry; then clear;
                    state clear;
                    accept SigObstacleClose then autoStop;
                    state autoStop;
                    accept SigObstacleClear then clear;
                }
                state powerStates {
                    entry; then normal;
                    state normal;
                    accept SigBatteryLow then lowPower;
                    state lowPower {
                        entry reduceVideoQuality;
                        do alertOperator;
                    }
                    accept SigBatteryCritical then criticalPower;
                    state criticalPower {
                        do navigateToCharger;
                    }
                    accept SigReachedCharger then charging;
                    accept SigBatteryDepleted then shutdown;
                    state charging;
                    accept SigChargeComplete then normal;
                    state shutdown;
                }
            }
            accept SigDeactivate then standby;
            accept SigShutdown then off;
        }
    }

    part def NetworkController {
        port commPort : ~NetworkPort;
        port navCmdOutPort { out navCmd : NavigationCommand; }
        port camCmdOutPort { out camCmd : CameraCommand; }
        port audioIOPort {
            out operatorAudio : AudioSignal;
            in robotAudio : AudioSignal;
        }
        port telemetryInPort { in telemetry : TelemetryData; }
        port videoInPort { in video : VideoSignal; }
        port powerPolicyInPort { in policy : VideoQualityLevel; }
    }

    part def AnybotRobot {
        port networkPort : NetworkPort;

        part mobilityBase : MobilityBase;
        part camera : CameraModule;
        part audioModule : AudioModule;
        part frontSensor : ProximitySensor {
            :>> position = "front";
        }
        part leftSensor : ProximitySensor {
            :>> position = "left";
        }
        part rightSensor : ProximitySensor {
            :>> position = "right";
        }
        part batterySystem : BatterySystem;
        part controlProcessor : ControlProcessor;
        part networkController : NetworkController;

        connect networkPort to networkController.commPort;
        connect networkController.navCmdOutPort to controlProcessor.navCmdInPort;
        connect networkController.camCmdOutPort to controlProcessor.camCmdInPort;
        connect networkController.audioIOPort to audioModule.audioPort;
        connect controlProcessor.navCmdOutPort to mobilityBase.driveCmdPort;
        connect controlProcessor.camCmdOutPort to camera.cameraCmdPort;
        connect frontSensor.sensorPort to controlProcessor.frontSensorPort;
        connect leftSensor.sensorPort to controlProcessor.leftSensorPort;
        connect rightSensor.sensorPort to controlProcessor.rightSensorPort;
        connect batterySystem.powerPort to controlProcessor.powerInPort;
        connect controlProcessor.telemetryOutPort to networkController.telemetryInPort;
        connect controlProcessor.powerPolicyOutPort to networkController.powerPolicyInPort;
        connect camera.videoOutPort to networkController.videoInPort;
    }

    part def OperatorStation {
        port networkPort : ~NetworkPort;
        part display;
        part speakers;
        part microphone;
        part controls;
    }

    part def AnybotSystem {
        part robot : AnybotRobot;
        part operatorStation : OperatorStation;
        connect robot.networkPort to operatorStation.networkPort;
    }

    part anybotSystem : AnybotSystem;

    requirement def TelepresenceRequirement {
        subject robot : AnybotRobot;
        objective 'Provide real-time, two-way audiovisual communication for remote physical presence';
    }

    requirement def SafeNavigationRequirement {
        subject robot : AnybotRobot;
        objective 'Automatically stop to prevent collisions when proximity sensors detect obstacle too close';
    }

    requirement def PowerManagementRequirement {
        subject robot : AnybotRobot;
        objective 'Reduce video quality and alert operator on low battery; navigate to charging station on critical battery before shutdown';
    }

    requirement def CameraControlRequirement {
        subject robot : AnybotRobot;
        subject station : OperatorStation;
        objective 'Operator shall control camera pan, tilt, and zoom from Operator Station';
    }

    requirement def RemoteMobilityRequirement {
        subject robot : AnybotRobot;
        subject station : OperatorStation;
        objective 'Operator shall remotely navigate robot through environment using Operator Station';
    }
}
