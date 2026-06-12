package ExtronBasedAVDistributionSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def dB;
    attribute def dBm;
    attribute def percent;

    enum def SignalFormat {
        enum HDMI;
        enum DisplayPort;
        enum USB_C_DPAltMode;
        enum DanteAudio;
        enum BalancedAnalogAudio;
        enum EthernetControl;
        enum RS232Control;
        enum ContactClosure;
    }

    enum def PowerState {
        enum Off;
        enum Standby;
        enum Booting;
        enum Operational;
        enum Faulted;
    }

    enum def VideoResolution {
        enum R1920x1080p60;
        enum R2560x1440p60;
        enum R3840x2160p30;
        enum R3840x2160p60;
    }

    enum def RoomMode {
        enum LocalPresentation;
        enum VideoConference;
        enum LectureCapture;
        enum Maintenance;
    }

    enum def FaultSeverity {
        enum Advisory;
        enum Degraded;
        enum Critical;
    }

    item def DigitalVideo {
        attribute format : SignalFormat;
        attribute resolution : VideoResolution;
        attribute frameRate : FrequencyValue;
        attribute colorDepth : Integer;
        attribute encrypted : Boolean;
    }

    item def DigitalAudio {
        attribute format : SignalFormat;
        attribute channelCount : Integer;
        attribute sampleRate : FrequencyValue;
        attribute level : dB;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetId : String;
        attribute issuedAt : TimeValue;
        attribute authenticated : Boolean;
    }

    item def DeviceStatus {
        attribute deviceId : String;
        attribute powerState : PowerState;
        attribute temperature : TemperatureValue;
        attribute faultCount : Integer;
    }

    item def NetworkPacket {
        attribute protocolName : String;
        attribute payloadBytes : Integer;
        attribute priority : Integer;
    }

    item def FaultReport {
        attribute sourceId : String;
        attribute severity : FaultSeverity;
        attribute message : String;
        attribute detectedAt : TimeValue;
    }

    port def VideoInPort {
        in item video : DigitalVideo;
    }

    port def VideoOutPort {
        out item video : DigitalVideo;
    }

    port def AudioInPort {
        in item audio : DigitalAudio;
    }

    port def AudioOutPort {
        out item audio : DigitalAudio;
    }

    port def ControlInPort {
        in item command : ControlCommand;
    }

    port def ControlOutPort {
        out item command : ControlCommand;
    }

    port def StatusOutPort {
        out item status : DeviceStatus;
        out item fault : FaultReport;
    }

    port def NetworkPort {
        inout item packet : NetworkPacket;
    }

    port def PowerPort {
        in item supplyVoltage : VoltageValue;
        out item loadCurrent : CurrentValue;
    }

    part def ExtronInspiredAVSystem {
        attribute primaryFunction : String = "Route, scale, control, and monitor audiovisual sources for a presentation room using an Extron-style AV switching and control architecture.";
        attribute activeMode : RoomMode;
        attribute systemState : PowerState;
        attribute availability : percent;
        attribute maxSupportedResolution : VideoResolution = VideoResolution::R3840x2160p60;

        port acPower : PowerPort;
        port campusLan : NetworkPort;
        port userControl : ControlInPort;
        port facilityStatus : StatusOutPort;

        part matrixSwitcher : DigitalMatrixSwitcher;
        part scalerProcessor : VideoScalerProcessor;
        part audioDsp : AudioDSP;
        part controlProcessor : AVControlProcessor;
        part touchPanel : TouchPanelInterface;
        part sourceLaptop : UserLaptopSource;
        part sourceWireless : WirelessPresentationGateway;
        part roomCamera : PTZCamera;
        part displayProjector : LaserProjector;
        part confidenceDisplay : FlatPanelDisplay;
        part amplifier : AudioAmplifier;
        part loudspeakers[4] : CeilingLoudspeaker;
        part occupancySensor : OccupancySensor;
        part relayScreen : ProjectionScreenController;

        connect sourceLaptop.videoOut to matrixSwitcher.inputA;
        connect sourceWireless.videoOut to matrixSwitcher.inputB;
        connect roomCamera.videoOut to matrixSwitcher.inputC;

        connect matrixSwitcher.programOut to scalerProcessor.videoIn;
        connect scalerProcessor.projectorOut to displayProjector.videoIn;
        connect scalerProcessor.confidenceOut to confidenceDisplay.videoIn;

        connect sourceLaptop.audioOut to audioDsp.programAudioIn;
        connect sourceWireless.audioOut to audioDsp.wirelessAudioIn;
        connect roomCamera.audioOut to audioDsp.cameraAudioIn;
        connect audioDsp.mixedAudioOut to amplifier.audioIn;
        connect amplifier.speakerOut to loudspeakers.audioIn;

        connect touchPanel.controlOut to controlProcessor.panelControlIn;
        connect userControl to controlProcessor.externalControlIn;
        connect controlProcessor.switcherControlOut to matrixSwitcher.controlIn;
        connect controlProcessor.scalerControlOut to scalerProcessor.controlIn;
        connect controlProcessor.displayControlOut to displayProjector.controlIn;
        connect controlProcessor.screenControlOut to relayScreen.controlIn;
        connect controlProcessor.audioControlOut to audioDsp.controlIn;
        connect occupancySensor.statusOut to controlProcessor.sensorStatusIn;

        connect campusLan to controlProcessor.network;
        connect controlProcessor.statusOut to facilityStatus;
        connect matrixSwitcher.statusOut to controlProcessor.deviceStatusIn;
        connect scalerProcessor.statusOut to controlProcessor.deviceStatusIn;
        connect audioDsp.statusOut to controlProcessor.deviceStatusIn;
        connect displayProjector.statusOut to controlProcessor.deviceStatusIn;
    }

    part def DigitalMatrixSwitcher {
        attribute inputCount : Integer = 4;
        attribute outputCount : Integer = 2;
        attribute switchingLatency : TimeValue = 50 [ms];
        attribute hdcpCompliant : Boolean = true;
        attribute maxDataRate : DataRateValue = 18 [Gb/s];

        port inputA : VideoInPort;
        port inputB : VideoInPort;
        port inputC : VideoInPort;
        port inputD : VideoInPort;
        port programOut : VideoOutPort;
        port previewOut : VideoOutPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;
        port network : NetworkPort;

        action routeSelectedSource {
            in item selectedVideo : DigitalVideo;
            out item routedVideo : DigitalVideo;
            assert routedVideo.resolution == selectedVideo.resolution;
            assert routedVideo.format == selectedVideo.format;
        }
    }

    part def VideoScalerProcessor {
        attribute outputResolution : VideoResolution = VideoResolution::R3840x2160p60;
        attribute scalingLatency : TimeValue = 33 [ms];
        attribute aspectRatioPreserved : Boolean = true;

        port videoIn : VideoInPort;
        port projectorOut : VideoOutPort;
        port confidenceOut : VideoOutPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;

        action scaleVideo {
            in item incoming : DigitalVideo;
            out item scaled : DigitalVideo;
            assert scaled.resolution == outputResolution;
            assert scaled.frameRate == incoming.frameRate;
        }
    }

    part def AudioDSP {
        attribute nominalOutputLevel : dBu = 4;
        attribute noiseFloor : dB = -90;
        attribute echoCancellationEnabled : Boolean = true;
        attribute automixEnabled : Boolean = true;

        port programAudioIn : AudioInPort;
        port wirelessAudioIn : AudioInPort;
        port cameraAudioIn : AudioInPort;
        port mixedAudioOut : AudioOutPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;

        action mixAndProcessAudio {
            in item program : DigitalAudio;
            in item wireless : DigitalAudio;
            in item camera : DigitalAudio;
            out item mix : DigitalAudio;
            assert mix.channelCount <= 2;
            assert mix.sampleRate == 48 [kHz];
        }
    }

    part def AVControlProcessor {
        attribute controllerId : String = "EXTRON-STYLE-CP-01";
        attribute bootTime : TimeValue = 45 [s];
        attribute commandTimeout : TimeValue = 2 [s];
        attribute authenticatedSessions : Integer;

        port panelControlIn : ControlInPort;
        port externalControlIn : ControlInPort;
        port sensorStatusIn : ControlInPort;
        port deviceStatusIn : StatusOutPort;
        port switcherControlOut : ControlOutPort;
        port scalerControlOut : ControlOutPort;
        port displayControlOut : ControlOutPort;
        port screenControlOut : ControlOutPort;
        port audioControlOut : ControlOutPort;
        port network : NetworkPort;
        port statusOut : StatusOutPort;

        state def ControlProcessorLifecycle {
            state off;
            state booting;
            state ready;
            state presenting;
            state conferencing;
            state faultHandling;

            initial then off;

            transition off_to_booting
                first off
                accept ControlCommand
                if command.commandId == "POWER_ON"
                then booting;

            transition booting_to_ready
                first booting
                after 45 [s]
                then ready;

            transition ready_to_presenting
                first ready
                accept ControlCommand
                if command.commandId == "START_PRESENTATION"
                then presenting;

            transition presenting_to_conferencing
                first presenting
                accept ControlCommand
                if command.commandId == "START_CONFERENCE"
                then conferencing;

            transition any_to_fault
                first ready
                accept FaultReport
                if fault.severity == FaultSeverity::Critical
                then faultHandling;

            transition fault_to_ready
                first faultHandling
                accept ControlCommand
                if command.commandId == "CLEAR_FAULTS"
                then ready;

            transition ready_to_off
                first ready
                accept ControlCommand
                if command.commandId == "POWER_OFF"
                then off;
        }

        action executeRoomPreset {
            in item request : ControlCommand;
            out item switchCommand : ControlCommand;
            out item displayCommand : ControlCommand;
            out item audioCommand : ControlCommand;
            assert request.authenticated == true;
        }
    }

    part def TouchPanelInterface {
        attribute diagonalSize : LengthValue = 10.1 [in];
        attribute brightness : IlluminanceValue = 350 [cd/m^2];
        attribute supportsPinAccess : Boolean = true;

        port controlOut : ControlOutPort;
        port statusIn : StatusOutPort;
    }

    part def UserLaptopSource {
        attribute connectorFormat : SignalFormat = SignalFormat::USB_C_DPAltMode;
        attribute maxResolution : VideoResolution = VideoResolution::R3840x2160p60;
        attribute powerDeliveryAvailable : Boolean = true;

        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
    }

    part def WirelessPresentationGateway {
        attribute supportedClients : Integer = 16;
        attribute networkBandwidthRequired : DataRateValue = 25 [Mb/s];
        attribute maxResolution : VideoResolution = VideoResolution::R1920x1080p60;

        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port network : NetworkPort;
    }

    part def PTZCamera {
        attribute panRange : AngleValue = 340 [deg];
        attribute tiltRange : AngleValue = 120 [deg];
        attribute opticalZoom : Real = 12.0;
        attribute outputFormat : SignalFormat = SignalFormat::HDMI;

        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;
    }

    part def LaserProjector {
        attribute brightness : IlluminanceValue = 6000 [lm];
        attribute nativeResolution : VideoResolution = VideoResolution::R3840x2160p60;
        attribute laserLife : TimeValue = 20000 [h];
        attribute warmupTime : TimeValue = 20 [s];

        port videoIn : VideoInPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;
        port power : PowerPort;
    }

    part def FlatPanelDisplay {
        attribute diagonalSize : LengthValue = 65 [in];
        attribute nativeResolution : VideoResolution = VideoResolution::R3840x2160p60;
        attribute maxBrightness : IlluminanceValue = 500 [cd/m^2];

        port videoIn : VideoInPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;
    }

    part def AudioAmplifier {
        attribute channels : Integer = 4;
        attribute powerPerChannel : PowerValue = 60 [W];
        attribute impedance : ResistanceValue = 8 [ohm];

        port audioIn : AudioInPort;
        port speakerOut : AudioOutPort;
        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;
    }

    part def CeilingLoudspeaker {
        attribute ratedPower : PowerValue = 30 [W];
        attribute nominalImpedance : ResistanceValue = 8 [ohm];
        attribute sensitivity : dB = 88;

        port audioIn : AudioInPort;
    }

    part def OccupancySensor {
        attribute detectionRange : LengthValue = 9 [m];
        attribute vacancyTimeout : TimeValue = 15 [min];

        port statusOut : ControlOutPort;
    }

    part def ProjectionScreenController {
        attribute travelTime : TimeValue = 18 [s];
        attribute hasLimitSwitches : Boolean = true;

        port controlIn : ControlInPort;
        port statusOut : StatusOutPort;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide centralized audiovisual switching, scaling, audio processing, device control, and operational monitoring for a presentation and conferencing room. */
    }

    requirement def VideoRoutingRequirement {
        doc /* The system shall route at least three digital video sources to a projector and confidence display. */
        require constraint { ExtronInspiredAVSystem::matrixSwitcher.inputCount >= 3 }
        require constraint { ExtronInspiredAVSystem::maxSupportedResolution == VideoResolution::R3840x2160p60 }
    }

    requirement def ControlRequirement {
        doc /* The system shall execute authenticated user commands from a touch panel or external control interface within two seconds. */
        require constraint { ExtronInspiredAVSystem::controlProcessor.commandTimeout <= 2 [s] }
    }

    requirement def AudioRequirement {
        doc /* The system shall mix program, wireless, and camera audio into a stereo room feed with echo cancellation enabled. */
        require constraint { ExtronInspiredAVSystem::audioDsp.echoCancellationEnabled == true }
        require constraint { ExtronInspiredAVSystem::audioDsp.automixEnabled == true }
    }

    requirement def AvailabilityRequirement {
        doc /* The system shall maintain monitored operational availability suitable for scheduled classroom and meeting-room use. */
        require constraint { ExtronInspiredAVSystem::availability >= 99.0 }
    }

    requirement def FaultMonitoringRequirement {
        doc /* The system shall report critical device faults to the facility monitoring interface. */
    }

    satisfy PrimaryFunctionRequirement by ExtronInspiredAVSystem;
    satisfy VideoRoutingRequirement by DigitalMatrixSwitcher;
    satisfy ControlRequirement by AVControlProcessor;
    satisfy AudioRequirement by AudioDSP;
    satisfy AvailabilityRequirement by ExtronInspiredAVSystem;
    satisfy FaultMonitoringRequirement by AVControlProcessor;
}