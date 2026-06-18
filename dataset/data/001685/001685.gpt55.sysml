package StardrawBasedPresentationSystem {

    import ScalarValues::*;

    attribute def Watt {
        :>> Real;
        doc /* Unit: W, electrical or acoustic power. */
    }

    attribute def Volt {
        :>> Real;
        doc /* Unit: V, electrical potential. */
    }

    attribute def Ampere {
        :>> Real;
        doc /* Unit: A, electrical current. */
    }

    attribute def Hertz {
        :>> Real;
        doc /* Unit: Hz, frequency. */
    }

    attribute def DecibelSPL {
        :>> Real;
        doc /* Unit: dB SPL, acoustic sound pressure level. */
    }

    attribute def DecibelFS {
        :>> Real;
        doc /* Unit: dBFS, digital audio level. */
    }

    attribute def PixelCount {
        :>> Integer;
        doc /* Unit: px. */
    }

    attribute def BitRate {
        :>> Real;
        doc /* Unit: Mb/s. */
    }

    attribute def Latency {
        :>> Real;
        doc /* Unit: ms. */
    }

    attribute def TemperatureCelsius {
        :>> Real;
        doc /* Unit: degC. */
    }

    attribute def Percent {
        :>> Real;
        doc /* Unit: %. */
    }

    enum def PowerState {
        enum off;
        enum standby;
        enum booting;
        enum on;
        enum fault;
    }

    enum def SignalHealth {
        enum absent;
        enum present;
        enum degraded;
        enum invalid;
    }

    enum def RouteMode {
        enum localPresentation;
        enum videoConference;
        enum wirelessShare;
        enum standby;
        enum maintenance;
    }

    enum def DisplayInput {
        enum hdmi1;
        enum hdmi2;
        enum hdbaseT;
        enum networkStream;
    }

    item def VideoSignal {
        attribute horizontalPixels : PixelCount;
        attribute verticalPixels : PixelCount;
        attribute frameRate : Hertz;
        attribute colorDepthBits : Integer;
        attribute compressedBitRate : BitRate;
        attribute health : SignalHealth;
    }

    item def AudioSignal {
        attribute channelCount : Integer;
        attribute sampleRate : Hertz;
        attribute bitDepth : Integer;
        attribute nominalLevel : DecibelFS;
        attribute health : SignalHealth;
    }

    item def ControlMessage {
        attribute commandId : String;
        attribute targetAddress : String;
        attribute priority : Integer;
        attribute acknowledged : Boolean;
    }

    item def EthernetFrame {
        attribute vlanId : Integer;
        attribute payloadSizeBytes : Integer;
        attribute priorityCodePoint : Integer;
    }

    item def PowerFeed {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute availablePower : Watt;
        attribute grounded : Boolean;
    }

    item def ThermalAirflow {
        attribute inletTemperature : TemperatureCelsius;
        attribute outletTemperature : TemperatureCelsius;
        attribute fanDutyCycle : Percent;
    }

    item def OccupancyEvent {
        attribute occupied : Boolean;
        attribute confidence : Percent;
    }

    item def UserIntent {
        attribute selectedMode : RouteMode;
        attribute requestedSourceName : String;
        attribute requestedVolume : Percent;
    }

    port def HdmiSourcePort {
        out video : VideoSignal;
        out audio : AudioSignal;
        in control : ControlMessage;
    }

    port def HdmiSinkPort {
        in video : VideoSignal;
        in audio : AudioSignal;
        out control : ControlMessage;
    }

    port def BalancedAudioOutPort {
        out audio : AudioSignal;
    }

    port def BalancedAudioInPort {
        in audio : AudioSignal;
    }

    port def SpeakerLevelPort {
        out audioPower : AudioSignal;
        out amplifierPower : PowerFeed;
    }

    port def LoudspeakerInputPort {
        in audioPower : AudioSignal;
        in amplifierPower : PowerFeed;
    }

    port def EthernetPort {
        inout frame : EthernetFrame;
        inout control : ControlMessage;
    }

    port def PowerInletPort {
        in feed : PowerFeed;
    }

    port def PowerOutletPort {
        out feed : PowerFeed;
    }

    port def UserInterfacePort {
        in intent : UserIntent;
        out status : ControlMessage;
    }

    port def OccupancyPort {
        out event : OccupancyEvent;
    }

    port def ThermalPort {
        inout airflow : ThermalAirflow;
    }

    action def ValidateSignal {
        in video : VideoSignal;
        in audio : AudioSignal;
        out valid : Boolean;
        out reason : String;
    }

    action def SelectRoute {
        in mode : RouteMode;
        in sourceName : String;
        out selectedVideo : VideoSignal;
        out selectedAudio : AudioSignal;
    }

    action def ScaleVideo {
        in sourceVideo : VideoSignal;
        in targetHorizontalPixels : PixelCount;
        in targetVerticalPixels : PixelCount;
        out scaledVideo : VideoSignal;
    }

    action def MixAudio {
        in programAudio : AudioSignal;
        in microphoneAudio : AudioSignal;
        out mixedAudio : AudioSignal;
    }

    action def AmplifyAudio {
        in lineAudio : AudioSignal;
        in gain : DecibelFS;
        out poweredAudio : AudioSignal;
    }

    action def SendDeviceCommand {
        in command : ControlMessage;
        out accepted : Boolean;
    }

    action def ReportSystemStatus {
        in state : PowerState;
        in mode : RouteMode;
        in videoHealth : SignalHealth;
        in audioHealth : SignalHealth;
        out status : ControlMessage;
    }

    state def PresentationSystemStateMachine {
        state initial Off;
        state Standby;
        state Booting;
        state Ready;
        state RoutingLocalPresentation;
        state RoutingVideoConference;
        state RoutingWirelessShare;
        state Faulted;
        state ShuttingDown;

        transition first Off to Standby;

        transition wake Standby to Booting
            accept OccupancyEvent
            guard event.occupied == true;

        transition bootComplete Booting to Ready;

        transition chooseLocal Ready to RoutingLocalPresentation
            accept UserIntent
            guard intent.selectedMode == RouteMode::localPresentation;

        transition chooseConference Ready to RoutingVideoConference
            accept UserIntent
            guard intent.selectedMode == RouteMode::videoConference;

        transition chooseWireless Ready to RoutingWirelessShare
            accept UserIntent
            guard intent.selectedMode == RouteMode::wirelessShare;

        transition localToReady RoutingLocalPresentation to Ready
            accept UserIntent
            guard intent.selectedMode == RouteMode::standby;

        transition conferenceToReady RoutingVideoConference to Ready
            accept UserIntent
            guard intent.selectedMode == RouteMode::standby;

        transition wirelessToReady RoutingWirelessShare to Ready
            accept UserIntent
            guard intent.selectedMode == RouteMode::standby;

        transition anyFault Ready to Faulted
            accept ControlMessage
            guard control.commandId == "FAULT_DETECTED";

        transition localFault RoutingLocalPresentation to Faulted
            accept ControlMessage
            guard control.commandId == "FAULT_DETECTED";

        transition conferenceFault RoutingVideoConference to Faulted
            accept ControlMessage
            guard control.commandId == "FAULT_DETECTED";

        transition wirelessFault RoutingWirelessShare to Faulted
            accept ControlMessage
            guard control.commandId == "FAULT_DETECTED";

        transition resetFault Faulted to Standby
            accept ControlMessage
            guard control.commandId == "RESET";

        transition sleep Ready to ShuttingDown
            accept UserIntent
            guard intent.selectedMode == RouteMode::standby;

        transition shutdownComplete ShuttingDown to Standby;
    }

    part def AcPowerDistributionUnit {
        attribute ratedInputVoltage : Volt = 120.0;
        attribute ratedOutputPower : Watt = 1800.0;
        attribute outletCount : Integer = 12;
        attribute surgeProtected : Boolean = true;

        port mainsIn : PowerInletPort;
        port switchedOut[12] : PowerOutletPort;
        port network : EthernetPort;
    }

    part def ControlProcessor {
        attribute powerState : PowerState = PowerState::standby;
        attribute ipAddress : String = "10.20.30.10";
        attribute programVersion : String = "6.2.4";
        attribute commandLatency : Latency = 25.0;

        port power : PowerInletPort;
        port lan : EthernetPort;
        port ui : UserInterfacePort;
        port occupancyIn : OccupancyPort;
        port thermal : ThermalPort;

        perform action sendCommand : SendDeviceCommand;
        perform action reportStatus : ReportSystemStatus;

        exhibit stateMachine : PresentationSystemStateMachine;
    }

    part def TouchPanel {
        attribute diagonalSize : PixelCount = 10;
        attribute horizontalPixels : PixelCount = 1920;
        attribute verticalPixels : PixelCount = 1200;
        attribute poweredByPoE : Boolean = true;

        port user : UserInterfacePort;
        port lan : EthernetPort;
    }

    part def OccupancySensor {
        attribute detectionRangeMeters : Real = 8.0;
        attribute timeoutSeconds : Real = 900.0;

        port eventOut : OccupancyPort;
        port lan : EthernetPort;
        port power : PowerInletPort;
    }

    part def NetworkSwitch {
        attribute portCount : Integer = 24;
        attribute poeBudget : Watt = 370.0;
        attribute switchingCapacity : BitRate = 56000.0;
        attribute managementIpAddress : String = "10.20.30.2";

        port uplink : EthernetPort;
        port endpoint[24] : EthernetPort;
        port power : PowerInletPort;
    }

    part def LaptopInputPlate {
        attribute locationName : String = "conference_table";
        attribute supportsHdmi : Boolean = true;
        attribute supportsUsbC : Boolean = true;
        attribute maximumHorizontalPixels : PixelCount = 3840;
        attribute maximumVerticalPixels : PixelCount = 2160;
        attribute maximumFrameRate : Hertz = 60.0;

        port hdmiOut : HdmiSourcePort;
        port network : EthernetPort;
    }

    part def WirelessPresentationGateway {
        attribute ssid : String = "StardrawRoomShare";
        attribute maximumUsers : Integer = 4;
        attribute maximumHorizontalPixels : PixelCount = 1920;
        attribute maximumVerticalPixels : PixelCount = 1080;
        attribute maximumFrameRate : Hertz = 30.0;

        port mediaOut : HdmiSourcePort;
        port lan : EthernetPort;
        port power : PowerInletPort;
    }

    part def VideoConferenceCodec {
        attribute codecName : String = "RoomCodec-Pro";
        attribute cameraCountSupported : Integer = 2;
        attribute farEndMaximumHorizontalPixels : PixelCount = 1920;
        attribute farEndMaximumVerticalPixels : PixelCount = 1080;
        attribute farEndFrameRate : Hertz = 60.0;

        port presentationIn : HdmiSinkPort;
        port programOut : HdmiSourcePort;
        port lan : EthernetPort;
        port power : PowerInletPort;
        port micIn : BalancedAudioInPort;
        port speakerOut : BalancedAudioOutPort;
    }

    part def AvMatrixSwitcher {
        attribute hdmiInputCount : Integer = 6;
        attribute hdmiOutputCount : Integer = 4;
        attribute maximumHorizontalPixels : PixelCount = 3840;
        attribute maximumVerticalPixels : PixelCount = 2160;
        attribute maximumFrameRate : Hertz = 60.0;
        attribute switchingLatency : Latency = 40.0;

        port input[6] : HdmiSinkPort;
        port output[4] : HdmiSourcePort;
        port lan : EthernetPort;
        port power : PowerInletPort;

        perform action validateLaptop : ValidateSignal;
        perform action validateWireless : ValidateSignal;
        perform action selectRoute : SelectRoute;
    }

    part def VideoScaler {
        attribute outputHorizontalPixels : PixelCount = 3840;
        attribute outputVerticalPixels : PixelCount = 2160;
        attribute outputFrameRate : Hertz = 60.0;
        attribute scalingLatency : Latency = 16.7;

        port input : HdmiSinkPort;
        port output : HdmiSourcePort;
        port lan : EthernetPort;
        port power : PowerInletPort;

        perform action scale : ScaleVideo;
    }

    part def MainDisplay {
        attribute diagonalInches : Real = 98.0;
        attribute nativeHorizontalPixels : PixelCount = 3840;
        attribute nativeVerticalPixels : PixelCount = 2160;
        attribute nominalPower : Watt = 420.0;
        attribute selectedInput : DisplayInput = DisplayInput::hdbaseT;

        port input : HdmiSinkPort;
        port lan : EthernetPort;
        port power : PowerInletPort;
        port thermal : ThermalPort;
    }

    part def ConfidenceMonitor {
        attribute diagonalInches : Real = 27.0;
        attribute nativeHorizontalPixels : PixelCount = 1920;
        attribute nativeVerticalPixels : PixelCount = 1080;
        attribute nominalPower : Watt = 45.0;

        port input : HdmiSinkPort;
        port lan : EthernetPort;
        port power : PowerInletPort;
    }

    part def BeamformingMicrophoneArray {
        attribute microphoneElements : Integer = 16;
        attribute pickupRadiusMeters : Real = 6.0;
        attribute sampleRate : Hertz = 48000.0;
        attribute noiseReductionEnabled : Boolean = true;

        port audioOut : BalancedAudioOutPort;
        port lan : EthernetPort;
        port power : PowerInletPort;
    }

    part def DigitalSignalProcessor {
        attribute inputChannelCount : Integer = 12;
        attribute outputChannelCount : Integer = 8;
        attribute sampleRate : Hertz = 48000.0;
        attribute processingLatency : Latency = 3.2;
        attribute echoCancellationEnabled : Boolean = true;
        attribute automaticGainControlEnabled : Boolean = true;

        port micInput : BalancedAudioInPort;
        port programInput : BalancedAudioInPort;
        port codecInput : BalancedAudioInPort;
        port programOutput : BalancedAudioOutPort;
        port codecOutput : BalancedAudioOutPort;
        port assistiveListeningOutput : BalancedAudioOutPort;
        port lan : EthernetPort;
        port power : PowerInletPort;

        perform action mixRoomAudio : MixAudio;
    }

    part def PowerAmplifier {
        attribute channelCount : Integer = 4;
        attribute ratedPowerPerChannel : Watt = 250.0;
        attribute loadImpedanceOhms : Real = 8.0;
        attribute amplifierLatency : Latency = 0.7;

        port lineInput : BalancedAudioInPort;
        port speakerOut[4] : SpeakerLevelPort;
        port lan : EthernetPort;
        port power : PowerInletPort;

        perform action amplify : AmplifyAudio;
    }

    part def CeilingLoudspeaker {
        attribute nominalImpedanceOhms : Real = 8.0;
        attribute sensitivity : DecibelSPL = 89.0;
        attribute maximumSpl : DecibelSPL = 105.0;
        attribute coverageAngleDegrees : Real = 110.0;

        port input : LoudspeakerInputPort;
    }

    part def AssistedListeningTransmitter {
        attribute carrierFrequency : Hertz = 72000000.0;
        attribute coverageAreaSquareMeters : Real = 250.0;
        attribute outputPower : Watt = 0.25;

        port audioInput : BalancedAudioInPort;
        port lan : EthernetPort;
        port power : PowerInletPort;
    }

    part def EquipmentRack {
        attribute rackUnits : Integer = 27;
        attribute inletTemperatureLimit : TemperatureCelsius = 30.0;
        attribute calculatedHeatLoad : Watt = 980.0;
        attribute ventilationRequired : Boolean = true;

        port powerIn : PowerInletPort;
        port thermal : ThermalPort;

        part pdu : AcPowerDistributionUnit;
        part controller : ControlProcessor;
        part networkSwitch : NetworkSwitch;
        part matrix : AvMatrixSwitcher;
        part scaler : VideoScaler;
        part dsp : DigitalSignalProcessor;
        part amplifier : PowerAmplifier;
        part codec : VideoConferenceCodec;
        part assistedListening : AssistedListeningTransmitter;

        connect powerIn.feed to pdu.mainsIn.feed;
        connect pdu.switchedOut[1].feed to controller.power.feed;
        connect pdu.switchedOut[2].feed to networkSwitch.power.feed;
        connect pdu.switchedOut[3].feed to matrix.power.feed;
        connect pdu.switchedOut[4].feed to scaler.power.feed;
        connect pdu.switchedOut[5].feed to dsp.power.feed;
        connect pdu.switchedOut[6].feed to amplifier.power.feed;
        connect pdu.switchedOut[7].feed to codec.power.feed;
        connect pdu.switchedOut[8].feed to assistedListening.power.feed;

        connect controller.lan.frame to networkSwitch.endpoint[1].frame;
        connect matrix.lan.frame to networkSwitch.endpoint[2].frame;
        connect scaler.lan.frame to networkSwitch.endpoint[3].frame;
        connect dsp.lan.frame to networkSwitch.endpoint[4].frame;
        connect amplifier.lan.frame to networkSwitch.endpoint[5].frame;
        connect codec.lan.frame to networkSwitch.endpoint[6].frame;
        connect assistedListening.lan.frame to networkSwitch.endpoint[7].frame;

        connect controller.lan.control to networkSwitch.endpoint[1].control;
        connect matrix.lan.control to networkSwitch.endpoint[2].control;
        connect scaler.lan.control to networkSwitch.endpoint[3].control;
        connect dsp.lan.control to networkSwitch.endpoint[4].control;
        connect amplifier.lan.control to networkSwitch.endpoint[5].control;
        connect codec.lan.control to networkSwitch.endpoint[6].control;
        connect assistedListening.lan.control to networkSwitch.endpoint[7].control;

        connect matrix.output[1].video to scaler.input.video;
        connect matrix.output[1].audio to scaler.input.audio;

        connect dsp.programOutput.audio to amplifier.lineInput.audio;
        connect dsp.assistiveListeningOutput.audio to assistedListening.audioInput.audio;

        connect codec.speakerOut.audio to dsp.codecInput.audio;
        connect dsp.codecOutput.audio to codec.micIn.audio;
    }

    part def StardrawConferenceRoomAvSystem {
        attribute systemName : String = "Stardraw Integrated Conference Presentation System";
        attribute primaryFunction : String = "Route, process, present, and monitor audiovisual content from local, wireless, and conferencing sources to room displays and loudspeakers under coordinated network control.";
        attribute designBasis : String = "Stardraw-derived AV signal-flow drawing for a medium conference room.";
        attribute nominalMainsVoltage : Volt = 120.0;
        attribute totalEstimatedLoad : Watt = 1450.0;
        attribute maximumEndToEndVideoLatency : Latency = 100.0;
        attribute maximumEndToEndAudioLatency : Latency = 25.0;
        attribute normalMode : RouteMode = RouteMode::localPresentation;

        port buildingPower : PowerInletPort;
        port buildingNetwork : EthernetPort;
        port roomUserInterface : UserInterfacePort;
        port roomOccupancy : OccupancyPort;
        port rackThermalAir : ThermalPort;

        part rack : EquipmentRack;
        part touchPanel : TouchPanel;
        part occupancySensor : OccupancySensor;
        part laptopPlate : LaptopInputPlate;
        part wirelessGateway : WirelessPresentationGateway;
        part mainDisplay : MainDisplay;
        part confidenceMonitor : ConfidenceMonitor;
        part microphoneArray : BeamformingMicrophoneArray;
        part ceilingSpeaker[4] : CeilingLoudspeaker;

        connect buildingPower.feed to rack.powerIn.feed;
        connect buildingNetwork.frame to rack.networkSwitch.uplink.frame;
        connect buildingNetwork.control to rack.networkSwitch.uplink.control;

        connect rack.pdu.switchedOut[9].feed to mainDisplay.power.feed;
        connect rack.pdu.switchedOut[10].feed to confidenceMonitor.power.feed;
        connect rack.pdu.switchedOut[11].feed to wirelessGateway.power.feed;
        connect rack.pdu.switchedOut[12].feed to occupancySensor.power.feed;

        connect touchPanel.lan.frame to rack.networkSwitch.endpoint[8].frame;
        connect occupancySensor.lan.frame to rack.networkSwitch.endpoint[9].frame;
        connect laptopPlate.network.frame to rack.networkSwitch.endpoint[10].frame;
        connect wirelessGateway.lan.frame to rack.networkSwitch.endpoint[11].frame;
        connect mainDisplay.lan.frame to rack.networkSwitch.endpoint[12].frame;
        connect confidenceMonitor.lan.frame to rack.networkSwitch.endpoint[13].frame;
        connect microphoneArray.lan.frame to rack.networkSwitch.endpoint[14].frame;

        connect touchPanel.lan.control to rack.networkSwitch.endpoint[8].control;
        connect occupancySensor.lan.control to rack.networkSwitch.endpoint[9].control;
        connect laptopPlate.network.control to rack.networkSwitch.endpoint[10].control;
        connect wirelessGateway.lan.control to rack.networkSwitch.endpoint[11].control;
        connect mainDisplay.lan.control to rack.networkSwitch.endpoint[12].control;
        connect confidenceMonitor.lan.control to rack.networkSwitch.endpoint[13].control;
        connect microphoneArray.lan.control to rack.networkSwitch.endpoint[14].control;

        connect roomUserInterface.intent to touchPanel.user.intent;
        connect touchPanel.user.status to roomUserInterface.status;
        connect touchPanel.user.intent to rack.controller.ui.intent;
        connect rack.controller.ui.status to touchPanel.user.status;

        connect occupancySensor.eventOut.event to rack.controller.occupancyIn.event;
        connect roomOccupancy.event to occupancySensor.eventOut.event;

        connect rackThermalAir.airflow to rack.thermal.airflow;
        connect rack.thermal.airflow to mainDisplay.thermal.airflow;

        connect laptopPlate.hdmiOut.video to rack.matrix.input[1].video;
        connect laptopPlate.hdmiOut.audio to rack.matrix.input[1].audio;

        connect wirelessGateway.mediaOut.video to rack.matrix.input[2].video;
        connect wirelessGateway.mediaOut.audio to rack.matrix.input[2].audio;

        connect rack.codec.programOut.video to rack.matrix.input[3].video;
        connect rack.codec.programOut.audio to rack.matrix.input[3].audio;

        connect rack.scaler.output.video to mainDisplay.input.video;
        connect rack.scaler.output.audio to mainDisplay.input.audio;

        connect rack.matrix.output[2].video to confidenceMonitor.input.video;
        connect rack.matrix.output[2].audio to confidenceMonitor.input.audio;

        connect rack.matrix.output[3].video to rack.codec.presentationIn.video;
        connect rack.matrix.output[3].audio to rack.codec.presentationIn.audio;

        connect microphoneArray.audioOut.audio to rack.dsp.micInput.audio;
        connect rack.matrix.output[4].audio to rack.dsp.programInput.audio;

        connect rack.amplifier.speakerOut[1].audioPower to ceilingSpeaker[1].input.audioPower;
        connect rack.amplifier.speakerOut[1].amplifierPower to ceilingSpeaker[1].input.amplifierPower;
        connect rack.amplifier.speakerOut[2].audioPower to ceilingSpeaker[2].input.audioPower;
        connect rack.amplifier.speakerOut[2].amplifierPower to ceilingSpeaker[2].input.amplifierPower;
        connect rack.amplifier.speakerOut[3].audioPower to ceilingSpeaker[3].input.audioPower;
        connect rack.amplifier.speakerOut[3].amplifierPower to ceilingSpeaker[3].input.amplifierPower;
        connect rack.amplifier.speakerOut[4].audioPower to ceilingSpeaker[4].input.audioPower;
        connect rack.amplifier.speakerOut[4].amplifierPower to ceilingSpeaker[4].input.amplifierPower;

        perform action validateActiveSource : ValidateSignal;
        perform action selectActiveRoute : SelectRoute;
        perform action scaleMainImage : ScaleVideo;
        perform action mixProgramAndMicrophones : MixAudio;
        perform action amplifyRoomAudio : AmplifyAudio;
        perform action commandDevices : SendDeviceCommand;
        perform action publishStatus : ReportSystemStatus;
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        id = "SDAV-REQ-001";
        text = "The system shall provide the primary function of presenting audiovisual content from local laptop, wireless sharing, and video conference sources to room displays and loudspeakers using coordinated switching, processing, amplification, and control.";
    }

    requirement def SourceRoutingRequirement {
        id = "SDAV-REQ-002";
        text = "The system shall route at least three presentation source classes: table laptop input, wireless presentation gateway, and video conference codec program output.";
    }

    requirement def MainDisplayRequirement {
        id = "SDAV-REQ-003";
        text = "The system shall deliver a scaled 3840 by 2160 pixel video signal at up to 60 Hz to the main display.";
    }

    requirement def ConfidenceMonitorRequirement {
        id = "SDAV-REQ-004";
        text = "The system shall provide a secondary confidence monitor feed for presenter preview or conference monitoring.";
    }

    requirement def AudioReinforcementRequirement {
        id = "SDAV-REQ-005";
        text = "The system shall mix microphone, program, and conference audio and reproduce the resulting room audio through four ceiling loudspeakers.";
    }

    requirement def ConferencingRequirement {
        id = "SDAV-REQ-006";
        text = "The system shall exchange microphone audio, loudspeaker reference audio, and presentation video with the video conference codec.";
    }

    requirement def ControlRequirement {
        id = "SDAV-REQ-007";
        text = "The system shall provide touch-panel operation for selecting local presentation, wireless share, video conference, standby, and maintenance modes.";
    }

    requirement def OccupancyWakeRequirement {
        id = "SDAV-REQ-008";
        text = "The control processor shall wake the system from standby when occupancy is detected with positive confidence.";
    }

    requirement def NetworkManagementRequirement {
        id = "SDAV-REQ-009";
        text = "The control processor shall communicate device commands and status over the managed Ethernet network.";
    }

    requirement def PowerDistributionRequirement {
        id = "SDAV-REQ-010";
        text = "The rack power distribution unit shall provide switched, surge-protected power to rack-mounted AV devices and selected room endpoints.";
    }

    requirement def LatencyRequirement {
        id = "SDAV-REQ-011";
        text = "The system shall maintain end-to-end video latency below 100 ms and end-to-end audio latency below 25 ms during normal presentation modes.";
    }

    requirement def ThermalRequirement {
        id = "SDAV-REQ-012";
        text = "The equipment rack inlet temperature shall remain at or below 30 degC while operating at the calculated heat load.";
    }

    requirement def AccessibilityRequirement {
        id = "SDAV-REQ-013";
        text = "The system shall provide an assisted-listening audio output derived from the processed program mix.";
    }

    requirement def FaultReportingRequirement {
        id = "SDAV-REQ-014";
        text = "The system shall report degraded, invalid, or absent audio/video signal health to the touch panel and transition to a faulted state when required for user action.";
    }

    satisfy HighLevelPrimaryFunctionRequirement by StardrawConferenceRoomAvSystem;
    satisfy SourceRoutingRequirement by StardrawConferenceRoomAvSystem::rack::matrix;
    satisfy MainDisplayRequirement by StardrawConferenceRoomAvSystem::rack::scaler;
    satisfy MainDisplayRequirement by StardrawConferenceRoomAvSystem::mainDisplay;
    satisfy ConfidenceMonitorRequirement by StardrawConferenceRoomAvSystem::confidenceMonitor;
    satisfy AudioReinforcementRequirement by StardrawConferenceRoomAvSystem::rack::dsp;
    satisfy AudioReinforcementRequirement by StardrawConferenceRoomAvSystem::rack::amplifier;
    satisfy AudioReinforcementRequirement by StardrawConferenceRoomAvSystem::ceilingSpeaker;
    satisfy ConferencingRequirement by StardrawConferenceRoomAvSystem::rack::codec;
    satisfy ControlRequirement by StardrawConferenceRoomAvSystem::touchPanel;
    satisfy ControlRequirement by StardrawConferenceRoomAvSystem::rack::controller;
    satisfy OccupancyWakeRequirement by StardrawConferenceRoomAvSystem::occupancySensor;
    satisfy OccupancyWakeRequirement by StardrawConferenceRoomAvSystem::rack::controller;
    satisfy NetworkManagementRequirement by StardrawConferenceRoomAvSystem::rack::networkSwitch;
    satisfy NetworkManagementRequirement by StardrawConferenceRoomAvSystem::rack::controller;
    satisfy PowerDistributionRequirement by StardrawConferenceRoomAvSystem::rack::pdu;
    satisfy LatencyRequirement by StardrawConferenceRoomAvSystem;
    satisfy ThermalRequirement by StardrawConferenceRoomAvSystem::rack;
    satisfy AccessibilityRequirement by StardrawConferenceRoomAvSystem::rack::assistedListening;
    satisfy FaultReportingRequirement by StardrawConferenceRoomAvSystem::rack::controller;

    assert constraint MainDisplayResolutionConstraint {
        StardrawConferenceRoomAvSystem::rack::scaler::outputHorizontalPixels >= 3840 and
        StardrawConferenceRoomAvSystem::rack::scaler::outputVerticalPixels >= 2160;
    }

    assert constraint LatencyConstraint {
        StardrawConferenceRoomAvSystem::maximumEndToEndVideoLatency <= 100.0 and
        StardrawConferenceRoomAvSystem::maximumEndToEndAudioLatency <= 25.0;
    }

    assert constraint PowerBudgetConstraint {
        StardrawConferenceRoomAvSystem::totalEstimatedLoad <=
        StardrawConferenceRoomAvSystem::rack::pdu::ratedOutputPower;
    }

    assert constraint ThermalConstraint {
        StardrawConferenceRoomAvSystem::rack::inletTemperatureLimit <= 30.0;
    }
}
