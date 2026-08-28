package AnybotTelepresence {
    import ISQ::*; 
    import ScalarValues::*; 

    // ===== Value Types =====
    def LengthUnit = >m;
    def SpeedUnit = >m/s;
    def AngleUnit = >deg;
    def PercentUnit = >%;
    def PowerUnit = >W;
    def EnergyUnit = >J;
    def VoltageUnit = >V;
    def FrequencyUnit = >Hz;
    def DataRateUnit = >bit/s;
    def MassUnit = >kg;

    value type Distance :> Real { unit LengthUnit; }
    value type Speed :> Real { unit SpeedUnit; }
    value type Angle :> Real { unit AngleUnit; }
    value type BatteryLevel :> Real { unit PercentUnit; min 0; max 100; }
    value type Power :> Real { unit PowerUnit; }
    value type Voltage :> Real { unit VoltageUnit; }
    value type DataRate :> Real { unit DataRateUnit; }
    value type Mass :> Real { unit MassUnit; }
    value type Frequency :> Real { unit FrequencyUnit; }

    // ===== Item Types =====
    item def VideoStream {
        attribute resolution : String;
        attribute frameRate : Frequency;
        attribute bitrate : DataRate;
    }
    item def AudioStream {
        attribute sampleRate : Frequency;
        attribute channels : Integer;
    }
    item def TelemetryData {
        attribute positionX : Distance;
        attribute positionY : Distance;
        attribute heading : Angle;
        attribute batteryLevel : BatteryLevel;
        attribute frontObstacleDist : Distance;
        attribute leftObstacleDist : Distance;
        attribute rightObstacleDist : Distance;
    }
    item def NavigationCommand {
        attribute linearVelocity : Speed;
        attribute angularVelocity : Angle unit "deg/s";
    }
    item def CameraCommand {
        attribute pan : Angle;
        attribute tilt : Angle;
        attribute zoom : Real; // magnification factor
    }
    item def AudioCommand {
        attribute volume : Real;
        attribute mute : Boolean;
    }
    item def StatusAlert {
        attribute code : String;
        attribute message : String;
        attribute severity : String;
    }

    // ===== Port Definitions =====
    port def VideoOutPort { out video : VideoStream; }
    port def VideoInPort { in video : VideoStream; }
    port def AudioOutPort { out audio : AudioStream; }
    port def AudioInPort { in audio : AudioStream; }
    port def TelemetryOutPort { out telemetry : TelemetryData; }
    port def TelemetryInPort { in telemetry : TelemetryData; }
    port def NavCmdOutPort { out navCmd : NavigationCommand; }
    port def NavCmdInPort { in navCmd : NavigationCommand; }
    port def CameraCmdOutPort { out camCmd : CameraCommand; }
    port def CameraCmdInPort { in camCmd : CameraCommand; }
    port def AudioCmdOutPort { out audioCmd : AudioCommand; }
    port def AudioCmdInPort { in audioCmd : AudioCommand; }
    port def AlertOutPort { out alert : StatusAlert; }
    port def AlertInPort { in alert : StatusAlert; }
    port def PowerPort { in voltage : Voltage; in power : Power; }

    // ===== Anybot Robot =====
    part def AnybotRobot {
        attribute mass : Mass = 12;
        attribute maxSpeed : Speed = 1.5;

        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port audioIn : AudioInPort;
        port telemetryOut : TelemetryOutPort;
        port navCmdIn : NavCmdInPort;
        port camCmdIn : CameraCmdInPort;
        port audioCmdIn : AudioCmdInPort;

        part battery : BatterySystem {
            port powerOut : PowerPort;
            attribute currentLevel : BatteryLevel = 100;
            attribute nominalVoltage : Voltage = 24;
            attribute capacity : Real = 50; // Ah
        }

        part controlProcessor : ControlProcessor {
            port navCmdIn : NavCmdInPort;
            port camCmdIn : CameraCmdInPort;
            port audioCmdIn : AudioCmdInPort;
            port telemetryOut : TelemetryOutPort;
            port alertOut : AlertOutPort;
            port powerIn : PowerPort;
            port mobilityCmdOut : NavCmdOutPort;
            port cameraCmdOut : CameraCmdOutPort;
            port audioCmdOut : AudioCmdOutPort;
            port sensorDataIn : TelemetryInPort;
            port batteryLevelIn : >> in batteryLevel : BatteryLevel;
        }

        part mobilityBase : MobilityBase {
            port navCmdIn : NavCmdInPort;
            port telemetryOut : TelemetryOutPort;
            port powerIn : PowerPort;
            attribute currentSpeed : Speed;
            attribute currentHeading : Angle;
        }

        part camera : HDCamera {
            port camCmdIn : CameraCmdInPort;
            port videoOut : VideoOutPort;
            port powerIn : PowerPort;
            attribute pan : Angle = 0;
            attribute tilt : Angle = 0;
            attribute zoom : Real = 1;
        }

        part audioModule : AudioModule {
            port audioCmdIn : AudioCmdInPort;
            port audioOut : AudioOutPort;
            port audioIn : AudioInPort;
            port powerIn : PowerPort;
            part microphone : Microphone;
            part speaker : Speaker;
        }

        part sensorSuite : ProximitySensorSuite {
            port telemetryOut : TelemetryOutPort;
            port powerIn : PowerPort;
            part frontSensor : ProximitySensor {
                attribute position : String = "front";
                attribute minRange : Distance = 0.05;
                attribute maxRange : Distance = 2.0;
                attribute currentDistance : Distance;
            }
            part leftSensor : ProximitySensor {
                attribute position : String = "left";
                attribute minRange : Distance = 0.05;
                attribute maxRange : Distance = 2.0;
                attribute currentDistance : Distance;
            }
            part rightSensor : ProximitySensor {
                attribute position : String = "right";
                attribute minRange : Distance = 0.05;
                attribute maxRange : Distance = 2.0;
                attribute currentDistance : Distance;
            }
        }

        part networkController : NetworkController {
            port videoIn : VideoInPort;
            port audioIn : AudioInPort;
            port telemetryIn : TelemetryInPort;
            port navCmdOut : NavCmdOutPort;
            port camCmdOut : CameraCmdOutPort;
            port audioCmdOut : AudioCmdOutPort;
            port alertIn : AlertInPort;
            port videoOut : VideoOutPort;
            port audioOut : AudioOutPort;
            port telemetryOut : TelemetryOutPort;
            port navCmdIn : NavCmdInPort;
            port camCmdIn : CameraCmdInPort;
            port audioCmdIn : AudioCmdInPort;
            port powerIn : PowerPort;
            attribute uplinkRate : DataRate;
            attribute downlinkRate : DataRate;
        }

        // Internal connections
        connection batteryToProcessor : PowerPort connect battery.powerOut to controlProcessor.powerIn;
        connection batteryToMobility : PowerPort connect battery.powerOut to mobilityBase.powerIn;
        connection batteryToCamera : PowerPort connect battery.powerOut to camera.powerIn;
        connection batteryToAudio : PowerPort connect battery.powerOut to audioModule.powerIn;
        connection batteryToSensors : PowerPort connect battery.powerOut to sensorSuite.powerIn;
        connection batteryToNetwork : PowerPort connect battery.powerOut to networkController.powerIn;

        connection navCmdFlow : NavCmdInPort connect networkController.navCmdOut to controlProcessor.navCmdIn;
        connection camCmdFlow : CameraCmdInPort connect networkController.camCmdOut to controlProcessor.camCmdIn;
        connection audioCmdFlow : AudioCmdInPort connect networkController.audioCmdOut to controlProcessor.audioCmdIn;

        connection processorToMobility : NavCmdOutPort connect controlProcessor.mobilityCmdOut to mobilityBase.navCmdIn;
        connection processorToCamera : CameraCmdOutPort connect controlProcessor.cameraCmdOut to camera.camCmdIn;
        connection processorToAudio : AudioCmdOutPort connect controlProcessor.audioCmdOut to audioModule.audioCmdIn;

        connection sensorToProcessor : TelemetryInPort connect sensorSuite.telemetryOut to controlProcessor.sensorDataIn;
        connection mobilityToProcessor : TelemetryInPort connect mobilityBase.telemetryOut to controlProcessor.sensorDataIn;

        connection cameraToNetwork : VideoInPort connect camera.videoOut to networkController.videoIn;
        connection audioToNetwork : AudioInPort connect audioModule.audioOut to networkController.audioIn;
        connection telemetryToNetwork : TelemetryInPort connect controlProcessor.telemetryOut to networkController.telemetryIn;
        connection alertToNetwork : AlertInPort connect controlProcessor.alertOut to networkController.alertIn;

        connection networkVideoOut : VideoOutPort connect networkController.videoOut to ::videoOut;
        connection networkAudioOut : AudioOutPort connect networkController.audioOut to ::audioOut;
        connection networkTelemetryOut : TelemetryOutPort connect networkController.telemetryOut to ::telemetryOut;
        connection networkNavIn : NavCmdInPort connect ::navCmdIn to networkController.navCmdIn;
        connection networkCamIn : CameraCmdInPort connect ::camCmdIn to networkController.camCmdIn;
        connection networkAudioIn : AudioInPort connect ::audioIn to networkController.audioIn;

        // Robot-level safety state machine
        state def SafetyStateMachine {
            attribute stopThreshold : Distance = 0.3;
            attribute slowThreshold : Distance = 0.8;

            state Normal {
                entry action { /* allow full operator control */ }
                do action { /* monitor sensor distances */ }
            }
            state Caution {
                entry action { /* reduce speed, alert operator */ }
            }
            state EmergencyStop {
                entry action { /* halt mobility base immediately */ }
            }

            transition Normal to Caution when (sensorSuite.frontSensor.currentDistance < slowThreshold || sensorSuite.leftSensor.currentDistance < slowThreshold || sensorSuite.rightSensor.currentDistance < slowThreshold);
            transition Caution to EmergencyStop when (sensorSuite.frontSensor.currentDistance < stopThreshold || sensorSuite.leftSensor.currentDistance < stopThreshold || sensorSuite.rightSensor.currentDistance < stopThreshold);
            transition Caution to Normal when (sensorSuite.frontSensor.currentDistance > slowThreshold && sensorSuite.leftSensor.currentDistance > slowThreshold && sensorSuite.rightSensor.currentDistance > slowThreshold);
            transition EmergencyStop to Caution when (sensorSuite.frontSensor.currentDistance > stopThreshold && sensorSuite.leftSensor.currentDistance > stopThreshold && sensorSuite.rightSensor.currentDistance > stopThreshold);
        }

        // Power management state machine
        state def PowerManagementStateMachine {
            attribute lowThreshold : BatteryLevel = 20;
            attribute criticalThreshold : BatteryLevel = 8;

            state FullPower {
                entry action { /* full video quality, normal operation */ }
            }
            state LowPower {
                entry action { /* reduce video quality, alert operator */ }
            }
            state CriticalPower {
                entry action { /* navigate to charging station */ }
            }
            state Shutdown {
                entry action { /* safe shutdown */ }
            }

            transition FullPower to LowPower when (battery.currentLevel < lowThreshold);
            transition LowPower to FullPower when (battery.currentLevel > lowThreshold + 5);
            transition LowPower to CriticalPower when (battery.currentLevel < criticalThreshold);
            transition CriticalPower to Shutdown when (battery.currentLevel < 2);
        }

        exhibit state safetyBehavior : SafetyStateMachine;
        exhibit state powerBehavior : PowerManagementStateMachine;
    }

    // ===== Sub-component definitions =====
    part def BatterySystem {
        port powerOut : PowerPort;
        attribute currentLevel : BatteryLevel;
        attribute nominalVoltage : Voltage;
        attribute capacity : Real;
    }

    part def ControlProcessor {
        port navCmdIn : NavCmdInPort;
        port camCmdIn : CameraCmdInPort;
        port audioCmdIn : AudioCmdInPort;
        port telemetryOut : TelemetryOutPort;
        port alertOut : AlertOutPort;
        port powerIn : PowerPort;
        port mobilityCmdOut : NavCmdOutPort;
        port cameraCmdOut : CameraCmdOutPort;
        port audioCmdOut : AudioCmdOutPort;
        port sensorDataIn : TelemetryInPort;
        port batteryLevelIn : >> in batteryLevel : BatteryLevel;

        action def ProcessCommands {
            in navCmd : NavigationCommand;
            in camCmd : CameraCommand;
            in audioCmd : AudioCommand;
            in sensorData : TelemetryData;
            out mobilityCmd : NavigationCommand;
            out cameraCmd : CameraCommand;
            out audioCmdOut : AudioCommand;
            out telemetry : TelemetryData;
            out alert : StatusAlert;
        }
    }

    part def MobilityBase {
        port navCmdIn : NavCmdInPort;
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerPort;
        attribute currentSpeed : Speed;
        attribute currentHeading : Angle;

        action def Drive {
            in cmd : NavigationCommand;
            out speed : Speed;
            out heading : Angle;
        }
    }

    part def HDCamera {
        port camCmdIn : CameraCmdInPort;
        port videoOut : VideoOutPort;
        port powerIn : PowerPort;
        attribute pan : Angle;
        attribute tilt : Angle;
        attribute zoom : Real;

        action def CaptureVideo {
            in cmd : CameraCommand;
            out stream : VideoStream;
        }
    }

    part def AudioModule {
        port audioCmdIn : AudioCmdInPort;
        port audioOut : AudioOutPort;
        port audioIn : AudioInPort;
        port powerIn : PowerPort;
        part microphone : Microphone;
        part speaker : Speaker;
    }

    part def Microphone {
        attribute sampleRate : Frequency;
    }

    part def Speaker {
        attribute maxVolume : Real;
    }

    part def ProximitySensorSuite {
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerPort;
        part frontSensor : ProximitySensor;
        part leftSensor : ProximitySensor;
        part rightSensor : ProximitySensor;
    }

    part def ProximitySensor {
        attribute position : String;
        attribute minRange : Distance;
        attribute maxRange : Distance;
        attribute currentDistance : Distance;
    }

    part def NetworkController {
        port videoIn : VideoInPort;
        port audioIn : AudioInPort;
        port telemetryIn : TelemetryInPort;
        port navCmdOut : NavCmdOutPort;
        port camCmdOut : CameraCmdOutPort;
        port audioCmdOut : AudioCmdOutPort;
        port alertIn : AlertInPort;
        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port telemetryOut : TelemetryOutPort;
        port navCmdIn : NavCmdInPort;
        port camCmdIn : CameraCmdInPort;
        port audioCmdIn : AudioCmdInPort;
        port powerIn : PowerPort;
        attribute uplinkRate : DataRate;
        attribute downlinkRate : DataRate;
    }

    // ===== Operator Station =====
    part def OperatorStation {
        port videoIn : VideoInPort;
        port audioIn : AudioInPort;
        port telemetryIn : TelemetryInPort;
        port alertIn : AlertInPort;
        port navCmdOut : NavCmdOutPort;
        port camCmdOut : CameraCmdOutPort;
        port audioCmdOut : AudioCmdOutPort;
        port audioOut : AudioOutPort;

        part display : Display {
            port videoIn : VideoInPort;
            port telemetryIn : TelemetryInPort;
            port alertIn : AlertInPort;
        }

        part speaker : StationSpeaker {
            port audioIn : AudioInPort;
        }

        part microphone : StationMicrophone {
            port audioOut : AudioOutPort;
        }

        part controlInterface : ControlInterface {
            port navCmdOut : NavCmdOutPort;
            port camCmdOut : CameraCmdOutPort;
            port audioCmdOut : AudioCmdOutPort;
        }

        part stationProcessor : StationProcessor {
            port videoIn : VideoInPort;
            port audioIn : AudioInPort;
            port telemetryIn : TelemetryInPort;
            port alertIn : AlertInPort;
            port navCmdOut : NavCmdOutPort;
            port camCmdOut : CameraCmdOutPort;
            port audioCmdOut : AudioCmdOutPort;
            port audioOut : AudioOutPort;
            port videoOut : VideoOutPort;
            port audioOutStation : AudioOutPort;
        }

        connection stationVideoToDisplay : VideoInPort connect stationProcessor.videoOut to display.videoIn;
        connection stationTelemetryToDisplay : TelemetryInPort connect stationProcessor.telemetryIn to display.telemetryIn;
        connection stationAlertToDisplay : AlertInPort connect stationProcessor.alertIn to display.alertIn;
        connection stationAudioToSpeaker : AudioInPort connect stationProcessor.audioIn to speaker.audioIn;
        connection micToProcessor : AudioOutPort connect microphone.audioOut to stationProcessor.audioOutStation;
        connection interfaceToProcessorNav : NavCmdOutPort connect controlInterface.navCmdOut to stationProcessor.navCmdOut;
        connection interfaceToProcessorCam : CameraCmdOutPort connect controlInterface.camCmdOut to stationProcessor.camCmdOut;
        connection interfaceToProcessorAudio : AudioCmdOutPort connect controlInterface.audioCmdOut to stationProcessor.audioCmdOut;

        // External port bindings
        connection extVideoIn : VideoInPort connect ::videoIn to stationProcessor.videoIn;
        connection extAudioIn : AudioInPort connect ::audioIn to stationProcessor.audioIn;
        connection extTelemetryIn : TelemetryInPort connect ::telemetryIn to stationProcessor.telemetryIn;
        connection extAlertIn : AlertInPort connect ::alertIn to stationProcessor.alertIn;
        connection extNavCmdOut : NavCmdOutPort connect stationProcessor.navCmdOut to ::navCmdOut;
        connection extCamCmdOut : CameraCmdOutPort connect stationProcessor.camCmdOut to ::camCmdOut;
        connection extAudioCmdOut : AudioCmdOutPort connect stationProcessor.audioCmdOut to ::audioCmdOut;
        connection extAudioOut : AudioOutPort connect stationProcessor.audioOut to ::audioOut;
    }

    part def Display {
        port videoIn : VideoInPort;
        port telemetryIn : TelemetryInPort;
        port alertIn : AlertInPort;
        attribute resolution : String = "1920x1080";
        attribute size : Distance = 0.686; // 27 inch diagonal
    }

    part def StationSpeaker {
        port audioIn : AudioInPort;
        attribute maxPower : Power = 20;
    }

    part def StationMicrophone {
        port audioOut : AudioOutPort;
        attribute sampleRate : Frequency = 48000;
    }

    part def ControlInterface {
        port navCmdOut : NavCmdOutPort;
        port camCmdOut : CameraCmdOutPort;
        port audioCmdOut : AudioCmdOutPort;
        part joystick : Joystick;
        part cameraControls : CameraControls;
    }

    part def Joystick {
        attribute maxLinearSpeed : Speed = 1.5;
        attribute maxAngularSpeed : Angle unit "deg/s" = 180;
    }

    part def CameraControls {
        attribute panRange : Angle = 180;
        attribute tiltRange : Angle = 90;
        attribute maxZoom : Real = 10;
    }

    part def StationProcessor {
        port videoIn : VideoInPort;
        port audioIn : AudioInPort;
        port telemetryIn : TelemetryInPort;
        port alertIn : AlertInPort;
        port navCmdOut : NavCmdOutPort;
        port camCmdOut : CameraCmdOutPort;
        port audioCmdOut : AudioCmdOutPort;
        port audioOut : AudioOutPort;
        port videoOut : VideoOutPort;
        port audioOutStation : AudioOutPort;
    }

    // ===== Top-level System =====
    part def AnybotTelepresenceSystem {
        part robot : AnybotRobot;
        part station : OperatorStation;

        connection robotVideoToStation : VideoOutPort connect robot.videoOut to station.videoIn;
        connection robotAudioToStation : AudioOutPort connect robot.audioOut to station.audioIn;
        connection robotTelemetryToStation : TelemetryOutPort connect robot.telemetryOut to station.telemetryIn;
        connection stationNavToRobot : NavCmdOutPort connect station.navCmdOut to robot.navCmdIn;
        connection stationCamToRobot : CameraCmdOutPort connect station.camCmdOut to robot.camCmdIn;
        connection stationAudioToRobot : AudioOutPort connect station.audioOut to robot.audioIn;
        connection stationAudioCmdToRobot : AudioCmdOutPort connect station.audioCmdOut to robot.audioCmdIn;
    }

    // ===== Requirements =====
    requirement def TelepresenceRequirement {
        subject telepresenceSystem : AnybotTelepresenceSystem;
        objective "Provide remote physical presence via mobile telepresence";
    }

    requirement def TwoWayAudioVisualRequirement :> TelepresenceRequirement {
        subject robot : AnybotRobot;
        objective "Provide real-time two-way audiovisual communication";
        require { robot.camera.videoOut.video.bitrate > 2000000; }
        require { robot.audioModule.audioOut.audio.sampleRate >= 16000; }
    }

    requirement def CameraControlRequirement :> TelepresenceRequirement {
        subject camera : HDCamera;
        objective "Operator can pan, tilt, and zoom the camera";
        require { camera.pan >= -180 && camera.pan <= 180; }
        require { camera.tilt >= -45 && camera.tilt <= 45; }
        require { camera.zoom >= 1 && camera.zoom <= 10; }
    }

    requirement def ObstacleSafetyRequirement :> TelepresenceRequirement {
        subject sensorSuite : ProximitySensorSuite;
        objective "Automatically stop robot to prevent collisions";
        require { sensorSuite.frontSensor.maxRange >= 2.0; }
        require { sensorSuite.leftSensor.maxRange >= 2.0; }
        require { sensorSuite.rightSensor.maxRange >= 2.0; }
    }

    requirement def BatteryLifeRequirement :> TelepresenceRequirement {
        subject battery : BatterySystem;
        objective "Support several hours of continuous operation";
        require { battery.capacity >= 40; }
    }

    requirement def PowerManagementRequirement :> TelepresenceRequirement {
        subject robot : AnybotRobot;
        objective "Intelligently manage power consumption";
        require { robot.battery.currentLevel < 20 implies robot.camera.videoOut.video.bitrate < 2000000; }
    }

    requirement def LowBatteryNavigationRequirement :> TelepresenceRequirement {
        subject robot : AnybotRobot;
        objective "Navigate to charging station when battery critically low";
        require { robot.battery.currentLevel < 8 implies robot.mobilityBase.currentSpeed > 0; }
    }

    requirement def OperatorControlRequirement :> TelepresenceRequirement {
        subject station : OperatorStation;
        objective "Operator can drive robot, control camera, and speak through robot";
        require { station.navCmdOut.navCmd.linearVelocity <= 1.5; }
        require { station.camCmdOut.camCmd.zoom <= 10; }
    }

    requirement def TelemetryRequirement :> TelepresenceRequirement {
        subject robot : AnybotRobot;
        objective "Send telemetry data to operator station";
        require { robot.telemetryOut.telemetry.batteryLevel >= 0; }
    }

    requirement telepresenceReq : TelepresenceRequirement;
    requirement twoWayAVReq : TwoWayAudioVisualRequirement;
    requirement cameraCtrlReq : CameraControlRequirement;
    requirement obstacleSafetyReq : ObstacleSafetyRequirement;
    requirement batteryLifeReq : BatteryLifeRequirement;
    requirement powerMgmtReq : PowerManagementRequirement;
    requirement lowBattNavReq : LowBatteryNavigationRequirement;
    requirement operatorCtrlReq : OperatorControlRequirement;
    requirement telemetryReq : TelemetryRequirement;
}
