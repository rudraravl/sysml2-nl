package StardrawBasedPresentationSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def DataRate {
        :>> baseType = Real;
        unit = "Gb/s";
    }

    attribute def Power {
        :>> baseType = Real;
        unit = "W";
    }

    attribute def Voltage {
        :>> baseType = Real;
        unit = "V";
    }

    attribute def Current {
        :>> baseType = Real;
        unit = "A";
    }

    attribute def Length {
        :>> baseType = Real;
        unit = "m";
    }

    attribute def Time {
        :>> baseType = Real;
        unit = "ms";
    }

    attribute def AudioLevel {
        :>> baseType = Real;
        unit = "dBFS";
    }

    attribute def Temperature {
        :>> baseType = Real;
        unit = "degC";
    }

    enum def SignalHealth {
        enum ok;
        enum degraded;
        enum failed;
        enum unknown;
    }

    enum def SystemMode {
        enum standby;
        enum localPresentation;
        enum videoConference;
        enum maintenance;
        enum fault;
    }

    enum def CableType {
        enum hdmi2_0;
        enum cat6a;
        enum balancedAudio;
        enum speakerCable;
        enum ethernet;
        enum mainsPower;
    }

    item def DigitalVideoStream {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : Real;
        attribute colorDepth : Integer;
        attribute encrypted : Boolean;
        attribute bandwidth : DataRate;
    }

    item def DigitalAudioStream {
        attribute channels : Integer;
        attribute sampleRate : Real;
        attribute bitDepth : Integer;
        attribute level : AudioLevel;
        attribute bandwidth : DataRate;
    }

    item def AvStream {
        item video : DigitalVideoStream;
        item audio : DigitalAudioStream;
        attribute latency : Time;
        attribute health : SignalHealth;
    }

    item def ControlMessage {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute commandName : String;
        attribute acknowledged : Boolean;
        attribute timeout : Time;
    }

    item def PowerFeed {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
        attribute protected : Boolean;
    }

    item def StardrawCableRecord {
        attribute cableId : String;
        attribute cableType : CableType;
        attribute fromEquipmentTag : String;
        attribute fromConnector : String;
        attribute toEquipmentTag : String;
        attribute toConnector : String;
        attribute plannedLength : Length;
        attribute installedLength : Length;
        attribute tested : Boolean;
    }

    item def StardrawEquipmentSymbol {
        attribute equipmentTag : String;
        attribute manufacturer : String;
        attribute model : String;
        attribute rackUnits : Integer;
        attribute drawingSheet : String;
        attribute symbolReference : String;
    }

    port def HdmiSourcePort {
        out item av : AvStream;
        attribute maxBandwidth : DataRate = 18.0;
    }

    port def HdmiSinkPort {
        in item av : AvStream;
        attribute requiredBandwidth : DataRate;
    }

    port def NetworkControlPort {
        in item commandIn : ControlMessage;
        out item commandOut : ControlMessage;
        attribute linkSpeed : DataRate = 1.0;
    }

    port def AudioInputPort {
        in item audio : DigitalAudioStream;
    }

    port def AudioOutputPort {
        out item audio : DigitalAudioStream;
    }

    port def SpeakerDrivePort {
        out item audio : DigitalAudioStream;
        attribute ratedPower : Power;
    }

    port def PowerInputPort {
        in item feed : PowerFeed;
        attribute maximumConsumption : Power;
    }

    port def PowerOutputPort {
        out item feed : PowerFeed;
        attribute breakerRating : Current;
    }

    part def StardrawProject {
        attribute projectName : String;
        attribute revision : String;
        attribute primaryFunction : String =
            "Coordinate the audiovisual, control, network, and power connectivity defined in a Stardraw system drawing so room users can select a presentation source and reliably route it to displays and loudspeakers.";

        item equipmentSymbols : StardrawEquipmentSymbol[1..*];
        item cableSchedule : StardrawCableRecord[1..*];
    }

    part def PresentationSource {
        attribute equipmentTag : String;
        attribute nativeResolutionWidth : Integer;
        attribute nativeResolutionHeight : Integer;
        attribute maxFrameRate : Real;
        attribute nominalPower : Power;

        port hdmiOut : HdmiSourcePort;
        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def LaptopInputPlate :> PresentationSource {
        attribute equipmentTag = "PLT-101";
        attribute nativeResolutionWidth = 3840;
        attribute nativeResolutionHeight = 2160;
        attribute maxFrameRate = 60.0;
        attribute nominalPower = 15.0;
    }

    part def WirelessPresentationGateway :> PresentationSource {
        attribute equipmentTag = "WPG-101";
        attribute nativeResolutionWidth = 3840;
        attribute nativeResolutionHeight = 2160;
        attribute maxFrameRate = 30.0;
        attribute nominalPower = 22.0;
    }

    part def RoomCamera {
        attribute equipmentTag : String = "CAM-101";
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : Real = 30.0;
        attribute nominalPower : Power = 12.0;

        port videoOut : HdmiSourcePort;
        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def AvSwitcher {
        attribute equipmentTag : String = "SW-101";
        attribute inputCount : Integer = 4;
        attribute outputCount : Integer = 2;
        attribute switchingLatency : Time = 45.0;
        attribute nominalPower : Power = 55.0;
        attribute selectedInput : Integer = 1;
        attribute health : SignalHealth = SignalHealth::unknown;

        port input1 : HdmiSinkPort;
        port input2 : HdmiSinkPort;
        port input3 : HdmiSinkPort;
        port input4 : HdmiSinkPort;
        port programOut : HdmiSourcePort;
        port confidenceOut : HdmiSourcePort;
        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def Display {
        attribute equipmentTag : String;
        attribute diagonalSize : Length;
        attribute widthPixels : Integer = 3840;
        attribute heightPixels : Integer = 2160;
        attribute nominalPower : Power;
        attribute currentInputActive : Boolean = false;

        port hdmiIn : HdmiSinkPort;
        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def ProgramDisplay :> Display {
        attribute equipmentTag = "DSP-101";
        attribute diagonalSize = 2.16;
        attribute nominalPower = 180.0;
    }

    part def ConfidenceDisplay :> Display {
        attribute equipmentTag = "DSP-102";
        attribute diagonalSize = 1.40;
        attribute nominalPower = 95.0;
    }

    part def AudioProcessor {
        attribute equipmentTag : String = "DSP-A101";
        attribute inputChannels : Integer = 8;
        attribute outputChannels : Integer = 8;
        attribute nominalPower : Power = 35.0;
        attribute echoCancellationEnabled : Boolean = true;
        attribute muteActive : Boolean = false;

        port programAudioIn : AudioInputPort;
        port farEndAudioIn : AudioInputPort;
        port roomMixOut : AudioOutputPort;
        port conferenceMixOut : AudioOutputPort;
        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def Amplifier {
        attribute equipmentTag : String = "AMP-101";
        attribute channels : Integer = 2;
        attribute outputPowerPerChannel : Power = 120.0;
        attribute nominalPower : Power = 90.0;
        attribute thermalLimit : Temperature = 70.0;
        attribute currentTemperature : Temperature = 32.0;

        port audioIn : AudioInputPort;
        port speakerOutLeft : SpeakerDrivePort;
        port speakerOutRight : SpeakerDrivePort;
        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def Loudspeaker {
        attribute equipmentTag : String;
        attribute impedance : Real;
        attribute continuousPower : Power;
        attribute installedHeight : Length;

        port driveIn : AudioInputPort;
    }

    part def CeilingSpeakerLeft :> Loudspeaker {
        attribute equipmentTag = "SPK-101";
        attribute impedance = 8.0;
        attribute continuousPower = 80.0;
        attribute installedHeight = 2.75;
    }

    part def CeilingSpeakerRight :> Loudspeaker {
        attribute equipmentTag = "SPK-102";
        attribute impedance = 8.0;
        attribute continuousPower = 80.0;
        attribute installedHeight = 2.75;
    }

    part def TouchPanel {
        attribute equipmentTag : String = "TP-101";
        attribute diagonalSize : Length = 0.254;
        attribute nominalPower : Power = 10.0;
        attribute selectedMode : SystemMode = SystemMode::standby;

        port control : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def ControlProcessor {
        attribute equipmentTag : String = "CP-101";
        attribute nominalPower : Power = 18.0;
        attribute lastCommandAccepted : Boolean = false;
        attribute activeMode : SystemMode = SystemMode::standby;

        port panelControl : NetworkControlPort;
        port switcherControl : NetworkControlPort;
        port displayControl : NetworkControlPort;
        port audioControl : NetworkControlPort;
        port cameraControl : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def NetworkSwitch {
        attribute equipmentTag : String = "NET-101";
        attribute portCount : Integer = 16;
        attribute poeBudget : Power = 120.0;
        attribute nominalPower : Power = 40.0;

        port uplink : NetworkControlPort;
        port port1 : NetworkControlPort;
        port port2 : NetworkControlPort;
        port port3 : NetworkControlPort;
        port port4 : NetworkControlPort;
        port port5 : NetworkControlPort;
        port powerIn : PowerInputPort;
    }

    part def PowerDistributionUnit {
        attribute equipmentTag : String = "PDU-101";
        attribute inputVoltage : Voltage = 120.0;
        attribute breakerRating : Current = 20.0;
        attribute maximumPower : Power = 1920.0;

        port mainsIn : PowerInputPort;
        port outlet1 : PowerOutputPort;
        port outlet2 : PowerOutputPort;
        port outlet3 : PowerOutputPort;
        port outlet4 : PowerOutputPort;
        port outlet5 : PowerOutputPort;
        port outlet6 : PowerOutputPort;
        port outlet7 : PowerOutputPort;
        port outlet8 : PowerOutputPort;
    }

    part def EquipmentRack {
        attribute rackTag : String = "RCK-101";
        attribute rackUnitsAvailable : Integer = 18;
        attribute rackUnitsUsed : Integer = 11;
        attribute ambientTemperature : Temperature = 24.0;

        part switcher : AvSwitcher;
        part audioProcessor : AudioProcessor;
        part amplifier : Amplifier;
        part controlProcessor : ControlProcessor;
        part networkSwitch : NetworkSwitch;
        part pdu : PowerDistributionUnit;
    }

    action def SelectPresentationSource {
        in sourceNumber : Integer;
        inout switcher : AvSwitcher;
        out accepted : Boolean;

        first start;
        then validateSource;
        then routeSource;
        then reportStatus;

        action validateSource {
            out valid : Boolean;
        }

        action routeSource {
            in valid : Boolean;
            out routed : Boolean;
        }

        action reportStatus {
            in routed : Boolean;
            out accepted : Boolean;
        }
    }

    action def StartVideoConference {
        inout controlProcessor : ControlProcessor;
        inout audioProcessor : AudioProcessor;
        inout camera : RoomCamera;
        inout switcher : AvSwitcher;
        out ready : Boolean;

        first wakeDisplays;
        then selectCameraAndProgram;
        then enableEchoCancellation;
        then publishReady;

        action wakeDisplays;
        action selectCameraAndProgram;
        action enableEchoCancellation;
        action publishReady;
    }

    action def EnterStandby {
        inout controlProcessor : ControlProcessor;
        inout displays : Display[2];
        inout audioProcessor : AudioProcessor;
        out completed : Boolean;

        first muteAudio;
        then blankDisplays;
        then setLowPowerMode;

        action muteAudio;
        action blankDisplays;
        action setLowPowerMode;
    }

    state def RoomAvOperatingState {
        entry action initializeStatus;

        state Standby {
            entry action setModeStandby;
        }

        state LocalPresentation {
            entry action selectDefaultLocalSource;
            do action monitorProgramSignal;
        }

        state VideoConference {
            entry action configureConferenceRouting;
            do action monitorCameraAndAudio;
        }

        state Maintenance {
            entry action exposeDiagnostics;
        }

        state Fault {
            entry action notifyOperator;
            do action isolateFailedSignalPath;
        }

        transition initial then Standby;
        transition Standby_to_LocalPresentation
            first Standby
            accept ControlMessage
            if commandName == "startLocalPresentation"
            then LocalPresentation;

        transition Standby_to_VideoConference
            first Standby
            accept ControlMessage
            if commandName == "startVideoConference"
            then VideoConference;

        transition LocalPresentation_to_Standby
            first LocalPresentation
            accept ControlMessage
            if commandName == "standby"
            then Standby;

        transition VideoConference_to_Standby
            first VideoConference
            accept ControlMessage
            if commandName == "standby"
            then Standby;

        transition Any_to_Fault
            first Standby
            accept ControlMessage
            if commandName == "faultDetected"
            then Fault;

        transition Fault_to_Maintenance
            first Fault
            accept ControlMessage
            if commandName == "maintenance"
            then Maintenance;

        transition Maintenance_to_Standby
            first Maintenance
            accept ControlMessage
            if commandName == "restoreService"
            then Standby;
    }

    part def StardrawBasedRoomAvSystem {
        attribute systemName : String = "Stardraw Conference Room AV System";
        attribute primaryFunction : String =
            "Provide high-level coordinated presentation and conferencing by routing user-selected audio/video sources from a Stardraw-defined equipment and cable schedule to displays, loudspeakers, and controllable room devices.";
        attribute maximumEndToEndLatency : Time = 120.0;
        attribute installedPowerBudget : Power = 760.0;
        attribute operatingMode : SystemMode = SystemMode::standby;

        part stardrawProject : StardrawProject {
            attribute projectName = "Conference Room 214 Stardraw AV Drawing";
            attribute revision = "R3";
        }

        part rack : EquipmentRack;
        part laptopPlate : LaptopInputPlate;
        part wirelessGateway : WirelessPresentationGateway;
        part camera : RoomCamera;
        part programDisplay : ProgramDisplay;
        part confidenceDisplay : ConfidenceDisplay;
        part touchPanel : TouchPanel;
        part leftSpeaker : CeilingSpeakerLeft;
        part rightSpeaker : CeilingSpeakerRight;

        item cable101 : StardrawCableRecord {
            attribute cableId = "C-101";
            attribute cableType = CableType::hdmi2_0;
            attribute fromEquipmentTag = "PLT-101";
            attribute fromConnector = "HDMI OUT";
            attribute toEquipmentTag = "SW-101";
            attribute toConnector = "INPUT 1";
            attribute plannedLength = 8.0;
            attribute installedLength = 7.6;
            attribute tested = true;
        }

        item cable102 : StardrawCableRecord {
            attribute cableId = "C-102";
            attribute cableType = CableType::hdmi2_0;
            attribute fromEquipmentTag = "WPG-101";
            attribute fromConnector = "HDMI OUT";
            attribute toEquipmentTag = "SW-101";
            attribute toConnector = "INPUT 2";
            attribute plannedLength = 2.0;
            attribute installedLength = 1.8;
            attribute tested = true;
        }

        item cable103 : StardrawCableRecord {
            attribute cableId = "C-103";
            attribute cableType = CableType::hdmi2_0;
            attribute fromEquipmentTag = "SW-101";
            attribute fromConnector = "PROGRAM OUT";
            attribute toEquipmentTag = "DSP-101";
            attribute toConnector = "HDMI IN";
            attribute plannedLength = 14.0;
            attribute installedLength = 13.5;
            attribute tested = true;
        }

        item cable104 : StardrawCableRecord {
            attribute cableId = "C-104";
            attribute cableType = CableType::balancedAudio;
            attribute fromEquipmentTag = "DSP-A101";
            attribute fromConnector = "ROOM MIX OUT";
            attribute toEquipmentTag = "AMP-101";
            attribute toConnector = "INPUT";
            attribute plannedLength = 1.0;
            attribute installedLength = 0.8;
            attribute tested = true;
        }

        connection laptopToSwitcher
            connect laptopPlate.hdmiOut to rack.switcher.input1;

        connection wirelessToSwitcher
            connect wirelessGateway.hdmiOut to rack.switcher.input2;

        connection cameraToSwitcher
            connect camera.videoOut to rack.switcher.input3;

        connection switcherToProgramDisplay
            connect rack.switcher.programOut to programDisplay.hdmiIn;

        connection switcherToConfidenceDisplay
            connect rack.switcher.confidenceOut to confidenceDisplay.hdmiIn;

        connection audioProcessorToAmplifier
            connect rack.audioProcessor.roomMixOut to rack.amplifier.audioIn;

        connection amplifierToLeftSpeaker
            connect rack.amplifier.speakerOutLeft to leftSpeaker.driveIn;

        connection amplifierToRightSpeaker
            connect rack.amplifier.speakerOutRight to rightSpeaker.driveIn;

        connection touchPanelToNetwork
            connect touchPanel.control to rack.networkSwitch.port1;

        connection controlProcessorToNetwork
            connect rack.controlProcessor.panelControl to rack.networkSwitch.port2;

        connection switcherControlToNetwork
            connect rack.switcher.control to rack.networkSwitch.port3;

        connection audioControlToNetwork
            connect rack.audioProcessor.control to rack.networkSwitch.port4;

        connection cameraControlToNetwork
            connect camera.control to rack.networkSwitch.port5;

        connection pduToSwitcher
            connect rack.pdu.outlet1 to rack.switcher.powerIn;

        connection pduToAudioProcessor
            connect rack.pdu.outlet2 to rack.audioProcessor.powerIn;

        connection pduToAmplifier
            connect rack.pdu.outlet3 to rack.amplifier.powerIn;

        connection pduToControlProcessor
            connect rack.pdu.outlet4 to rack.controlProcessor.powerIn;

        connection pduToNetworkSwitch
            connect rack.pdu.outlet5 to rack.networkSwitch.powerIn;

        connection pduToProgramDisplay
            connect rack.pdu.outlet6 to programDisplay.powerIn;

        connection pduToConfidenceDisplay
            connect rack.pdu.outlet7 to confidenceDisplay.powerIn;

        perform behavior operatingState : RoomAvOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : StardrawBasedRoomAvSystem;

        doc
        /* The system shall use the Stardraw-defined equipment symbols and cable schedule to coordinate AV source selection, signal routing, control, audio playback, display activation, and standby behavior for a conference room. */

        require constraint {
            system.primaryFunction != ""
        }
    }

    requirement def SourceRoutingRequirement {
        subject system : StardrawBasedRoomAvSystem;

        doc
        /* The system shall route at least one user-selected presentation source to the program display and room loudspeakers. */

        require constraint {
            system.rack.switcher.inputCount >= 3 and
            system.rack.switcher.outputCount >= 2
        }
    }

    requirement def LatencyRequirement {
        subject system : StardrawBasedRoomAvSystem;

        doc
        /* End-to-end AV latency from selected source input to program display output shall not exceed 120 ms. */

        require constraint {
            system.maximumEndToEndLatency <= 120.0
        }
    }

    requirement def PowerBudgetRequirement {
        subject system : StardrawBasedRoomAvSystem;

        doc
        /* Total installed steady-state AV equipment load shall remain within the protected PDU power rating. */

        require constraint {
            system.installedPowerBudget < system.rack.pdu.maximumPower
        }
    }

    requirement def CableTraceabilityRequirement {
        subject system : StardrawBasedRoomAvSystem;

        doc
        /* Each installed cable represented from the Stardraw drawing shall identify source equipment, destination equipment, connector names, cable type, length, and test status. */

        require constraint {
            system.cable101.tested and
            system.cable102.tested and
            system.cable103.tested and
            system.cable104.tested
        }
    }

    requirement def ConferenceModeRequirement {
        subject system : StardrawBasedRoomAvSystem;

        doc
        /* In video conference mode, the system shall enable camera video routing, echo-cancelled audio processing, and room loudspeaker output. */

        require constraint {
            system.rack.audioProcessor.echoCancellationEnabled == true and
            system.camera.resolutionWidth >= 1920 and
            system.camera.resolutionHeight >= 1080
        }
    }

    satisfy PrimaryFunctionRequirement by StardrawBasedRoomAvSystem;
    satisfy SourceRoutingRequirement by AvSwitcher;
    satisfy LatencyRequirement by AvSwitcher;
    satisfy PowerBudgetRequirement by PowerDistributionUnit;
    satisfy CableTraceabilityRequirement by StardrawProject;
    satisfy ConferenceModeRequirement by AudioProcessor, RoomCamera;

}