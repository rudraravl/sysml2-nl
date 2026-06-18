package BelkinWemoBasedSmartOutletSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Voltage :> ISQ::electricPotential;
  attribute def Current :> ISQ::electricCurrent;
  attribute def ActivePower :> ISQ::power;
  attribute def Energy :> ISQ::energy;
  attribute def Frequency :> ISQ::frequency;
  attribute def Temperature :> ISQ::thermodynamicTemperature;
  attribute def TimeDuration :> ISQ::time;
  attribute def Percent :> Real;
  attribute def Count :> Integer;

  enum def RelayState {
    enum open;
    enum closed;
  }

  enum def ConnectionState {
    enum notConfigured;
    enum provisioning;
    enum connecting;
    enum connected;
    enum cloudReachable;
    enum offline;
  }

  enum def CommandKind {
    enum turnOn;
    enum turnOff;
    enum toggle;
    enum requestStatus;
    enum setSchedule;
    enum factoryReset;
  }

  enum def CommandSource {
    enum mobileApplication;
    enum voiceAssistant;
    enum localButton;
    enum schedule;
    enum cloudAutomation;
  }

  enum def FaultKind {
    enum none;
    enum overCurrent;
    enum overTemperature;
    enum relayWelded;
    enum wifiUnavailable;
    enum internalSupplyFault;
    enum invalidCommand;
  }

  enum def IndicatorColor {
    enum off;
    enum white;
    enum amber;
    enum green;
    enum red;
  }

  item def ACPower {
    attribute rmsVoltage : Voltage;
    attribute rmsCurrent : Current;
    attribute frequency : Frequency;
    attribute activePower : ActivePower;
    attribute accumulatedEnergy : Energy;
  }

  item def DCControlPower {
    attribute voltage : Voltage;
    attribute availableCurrent : Current;
    attribute ripplePercent : Percent;
  }

  item def WiFiFrame {
    attribute ssid : String;
    attribute rssiPercent : Percent;
    attribute payloadBytes : Count;
  }

  item def CloudMessage {
    attribute messageId : String;
    attribute commandKind : CommandKind;
    attribute source : CommandSource;
    attribute requestedRelayState : RelayState;
    attribute scheduleTimeFromNow : TimeDuration;
  }

  item def LocalButtonEvent {
    attribute pressDuration : TimeDuration;
    attribute pressCount : Count;
  }

  item def RelayDriveSignal {
    attribute targetState : RelayState;
    attribute coilVoltage : Voltage;
    attribute pulseDuration : TimeDuration;
  }

  item def ElectricalMeasurement {
    attribute measuredVoltage : Voltage;
    attribute measuredCurrent : Current;
    attribute measuredPower : ActivePower;
    attribute measuredEnergy : Energy;
    attribute boardTemperature : Temperature;
  }

  item def StatusMessage {
    attribute relayState : RelayState;
    attribute connectionState : ConnectionState;
    attribute presentPower : ActivePower;
    attribute totalEnergy : Energy;
    attribute lastFault : FaultKind;
    attribute firmwareVersion : String;
  }

  item def LedCommand {
    attribute color : IndicatorColor;
    attribute blinkPeriod : TimeDuration;
  }

  port def MainsInputPort {
    in item suppliedPower : ACPower;
  }

  port def SwitchedLoadPort {
    out item deliveredPower : ACPower;
  }

  port def ACInternalPort {
    inout item acPower : ACPower;
  }

  port def DCInternalPort {
    inout item dcPower : DCControlPower;
  }

  port def WiFiRadioPort {
    in item receivedFrame : WiFiFrame;
    out item transmittedFrame : WiFiFrame;
  }

  port def CloudServicePort {
    in item inboundMessage : CloudMessage;
    out item outboundStatus : StatusMessage;
  }

  port def ButtonPort {
    out item buttonEvent : LocalButtonEvent;
  }

  port def RelayCoilPort {
    in item relayDrive : RelayDriveSignal;
  }

  port def SensorPort {
    out item measurement : ElectricalMeasurement;
  }

  port def LedPort {
    in item ledCommand : LedCommand;
  }

  port def LogicCommandPort {
    in item cloudCommand : CloudMessage;
    in item buttonCommand : LocalButtonEvent;
    in item sensorInput : ElectricalMeasurement;
    out item relayOutput : RelayDriveSignal;
    out item ledOutput : LedCommand;
    out item statusOutput : StatusMessage;
  }

  part def SurgeAndEMIProtection {
    port lineSide : ACInternalPort;
    port protectedSide : ACInternalPort;

    attribute maximumContinuousVoltage : Voltage = 132 [SI::V];
    attribute surgeClampVoltage : Voltage = 775 [SI::V];
    attribute emiAttenuationAt100MHz : Percent = 85.0;
  }

  part def IsolatedLowVoltagePowerSupply {
    port acInput : ACInternalPort;
    port dcOutput : DCInternalPort;

    attribute nominalInputVoltage : Voltage = 120 [SI::V];
    attribute nominalOutputVoltage : Voltage = 3.3 [SI::V];
    attribute maximumOutputCurrent : Current = 0.7 [SI::A];
    attribute conversionEfficiency : Percent = 78.0;
  }

  part def LatchingRelay {
    port lineSide : ACInternalPort;
    port loadSide : ACInternalPort;
    port coilControl : RelayCoilPort;

    attribute contactState : RelayState = RelayState::open;
    attribute maximumLoadCurrent : Current = 15 [SI::A];
    attribute maximumLoadPower : ActivePower = 1800 [SI::W];
    attribute coilNominalVoltage : Voltage = 5 [SI::V];
    attribute mechanicalLife : Count = 100000;

    state relayPhysicalBehavior {
      state openContact;
      state closedContact;

      transition initialToOpen first openContact;

      transition closeContact
        first openContact
        accept coilControl.relayDrive
        if coilControl.relayDrive.targetState == RelayState::closed
        then closedContact;

      transition openContactAgain
        first closedContact
        accept coilControl.relayDrive
        if coilControl.relayDrive.targetState == RelayState::open
        then openContact;
    }
  }

  part def PowerMeasurementCircuit {
    port sensedAC : ACInternalPort;
    port measurementOut : SensorPort;
    port dcPower : DCInternalPort;

    attribute voltageAccuracy : Percent = 2.0;
    attribute currentAccuracy : Percent = 2.5;
    attribute minimumDetectablePower : ActivePower = 0.5 [SI::W];
    attribute samplePeriod : TimeDuration = 1 [SI::s];
  }

  part def WiFiModule {
    port radio : WiFiRadioPort;
    port cloud : CloudServicePort;
    port dcPower : DCInternalPort;

    attribute supportedBand : String = "2.4 GHz IEEE 802.11 b/g/n";
    attribute minimumRssiForReliableControl : Percent = 25.0;
    attribute connectionState : ConnectionState = ConnectionState::notConfigured;
    attribute averageTransmitPower : ActivePower = 0.08 [SI::W];

    action connectToHomeNetwork {
      in item networkFrame : WiFiFrame;
      out item connectedFrame : WiFiFrame;

      attribute maximumAssociationTime : TimeDuration = 30 [SI::s];
      attribute retryLimit : Count = 5;
    }

    action publishStatusToCloud {
      in item status : StatusMessage;
      out item statusFrame : WiFiFrame;

      attribute maximumStatusLatency : TimeDuration = 2 [SI::s];
    }
  }

  part def EmbeddedController {
    port logic : LogicCommandPort;
    port dcPower : DCInternalPort;

    attribute firmwareVersion : String = "Wemo-compatible high-level controller 1.0";
    attribute commandProcessingPeriod : TimeDuration = 100 [SI::ms];
    attribute watchdogTimeout : TimeDuration = 5 [SI::s];
    attribute lastAcceptedCommand : CommandKind = CommandKind::requestStatus;
    attribute commandedRelayState : RelayState = RelayState::open;
    attribute lastFault : FaultKind = FaultKind::none;

    action interpretCommand {
      in item command : CloudMessage;
      in item localButton : LocalButtonEvent;
      out item relaySignal : RelayDriveSignal;
      out item ledSignal : LedCommand;
      out item status : StatusMessage;
    }

    action evaluateProtection {
      in item measurement : ElectricalMeasurement;
      out item safeRelaySignal : RelayDriveSignal;
      out item reportedFault : StatusMessage;

      attribute overCurrentTrip : Current = 15 [SI::A];
      attribute overTemperatureTrip : Temperature = 358.15 [SI::K];
      attribute faultResponseTime : TimeDuration = 500 [SI::ms];
    }

    state controllerOperatingBehavior {
      state booting;
      state provisioning;
      state connectedRelayOpen;
      state connectedRelayClosed;
      state executingSchedule;
      state faultedSafeOff;
      state factoryResetting;

      transition startUp first booting;

      transition bootToProvisioning
        first booting
        if logic.statusOutput.connectionState == ConnectionState::notConfigured
        then provisioning;

      transition bootToConnectedOff
        first booting
        if logic.statusOutput.connectionState == ConnectionState::connected
        then connectedRelayOpen;

      transition provisioningComplete
        first provisioning
        accept logic.cloudCommand
        if logic.cloudCommand.commandKind == CommandKind::requestStatus
        then connectedRelayOpen;

      transition remoteTurnOn
        first connectedRelayOpen
        accept logic.cloudCommand
        if logic.cloudCommand.commandKind == CommandKind::turnOn
        then connectedRelayClosed;

      transition remoteTurnOff
        first connectedRelayClosed
        accept logic.cloudCommand
        if logic.cloudCommand.commandKind == CommandKind::turnOff
        then connectedRelayOpen;

      transition buttonToggleOn
        first connectedRelayOpen
        accept logic.buttonCommand
        if logic.buttonCommand.pressCount == 1
        then connectedRelayClosed;

      transition buttonToggleOff
        first connectedRelayClosed
        accept logic.buttonCommand
        if logic.buttonCommand.pressCount == 1
        then connectedRelayOpen;

      transition scheduledOn
        first executingSchedule
        if commandedRelayState == RelayState::closed
        then connectedRelayClosed;

      transition scheduledOff
        first executingSchedule
        if commandedRelayState == RelayState::open
        then connectedRelayOpen;

      transition overCurrentFromOn
        first connectedRelayClosed
        accept logic.sensorInput
        if logic.sensorInput.measuredCurrent > 15 [SI::A]
        then faultedSafeOff;

      transition overTemperature
        first connectedRelayClosed
        accept logic.sensorInput
        if logic.sensorInput.boardTemperature > 358.15 [SI::K]
        then faultedSafeOff;

      transition resetRequested
        first connectedRelayOpen
        accept logic.buttonCommand
        if logic.buttonCommand.pressDuration > 10 [SI::s]
        then factoryResetting;

      transition resetComplete
        first factoryResetting
        then provisioning;
    }
  }

  part def ManualButton {
    port buttonOut : ButtonPort;

    attribute debounceTime : TimeDuration = 30 [SI::ms];
    attribute longPressResetThreshold : TimeDuration = 10 [SI::s];
  }

  part def StatusIndicatorLed {
    port ledIn : LedPort;

    attribute maximumIndicatorPower : ActivePower = 0.05 [SI::W];
    attribute normalOnColor : IndicatorColor = IndicatorColor::white;
    attribute setupColor : IndicatorColor = IndicatorColor::amber;
    attribute faultColor : IndicatorColor = IndicatorColor::red;
  }

  part def FlameRetardantEnclosure {
    attribute material : String = "UL94 V-0 polycarbonate";
    attribute maximumSurfaceTemperature : Temperature = 333.15 [SI::K];
    attribute ingressProtectionDescription : String = "Indoor dry-location enclosure";
    attribute plugFormFactor : String = "North American grounded smart plug";
  }

  part def BelkinWemoSmartPlug {
    port wallMainsInput : MainsInputPort;
    port applianceOutput : SwitchedLoadPort;
    port homeWiFi : WiFiRadioPort;
    port cloudInterface : CloudServicePort;

    part enclosure : FlameRetardantEnclosure;
    part inputProtection : SurgeAndEMIProtection;
    part lowVoltageSupply : IsolatedLowVoltagePowerSupply;
    part relay : LatchingRelay;
    part metering : PowerMeasurementCircuit;
    part wifiModule : WiFiModule;
    part controller : EmbeddedController;
    part manualButton : ManualButton;
    part indicator : StatusIndicatorLed;

    attribute productFamily : String = "Belkin Wemo smart outlet";
    attribute primaryFunction : String = "Provide Wi-Fi connected remote, scheduled, and local on/off control of AC mains power delivered to a plugged-in appliance while reporting outlet status and basic electrical measurements.";
    attribute nominalMainsVoltage : Voltage = 120 [SI::V];
    attribute nominalMainsFrequency : Frequency = 60 [SI::Hz];
    attribute maximumContinuousLoadCurrent : Current = 15 [SI::A];
    attribute maximumContinuousLoadPower : ActivePower = 1800 [SI::W];
    attribute standbyPower : ActivePower = 1.5 [SI::W];
    attribute commandToRelayLatency : TimeDuration = 1 [SI::s];
    attribute statusReportPeriod : TimeDuration = 60 [SI::s];

    connect wallMainsInput to inputProtection.lineSide;
    connect inputProtection.protectedSide to relay.lineSide;
    connect relay.loadSide to applianceOutput;
    connect inputProtection.protectedSide to lowVoltageSupply.acInput;
    connect inputProtection.protectedSide to metering.sensedAC;
    connect lowVoltageSupply.dcOutput to controller.dcPower;
    connect lowVoltageSupply.dcOutput to wifiModule.dcPower;
    connect lowVoltageSupply.dcOutput to metering.dcPower;
    connect homeWiFi to wifiModule.radio;
    connect cloudInterface to wifiModule.cloud;
    connect wifiModule.cloud to controller.logic;
    connect metering.measurementOut to controller.logic;
    connect manualButton.buttonOut to controller.logic;
    connect controller.logic to relay.coilControl;
    connect controller.logic to indicator.ledIn;
    connect controller.logic to cloudInterface;

    action highLevelPrimaryFunction {
      in item userCommand : CloudMessage;
      in item mainsPower : ACPower;
      out item switchedPower : ACPower;
      out item outletStatus : StatusMessage;

      action receiveRemoteOrScheduledCommand;
      action validateCommandAndSafetyLimits;
      action setRelayContactState;
      action deliverOrInterruptLoadPower;
      action measureOutletState;
      action reportStateToUser;

      succession receiveRemoteOrScheduledCommand then validateCommandAndSafetyLimits;
      succession validateCommandAndSafetyLimits then setRelayContactState;
      succession setRelayContactState then deliverOrInterruptLoadPower;
      succession deliverOrInterruptLoadPower then measureOutletState;
      succession measureOutletState then reportStateToUser;
    }

    state wemoSystemBehavior {
      state unpowered;
      state booting;
      state setupMode;
      state onlineOff;
      state onlineOn;
      state offlineOff;
      state offlineOn;
      state protectiveShutdown;

      transition powerApplied
        first unpowered
        accept wallMainsInput.suppliedPower
        then booting;

      transition needsSetup
        first booting
        if wifiModule.connectionState == ConnectionState::notConfigured
        then setupMode;

      transition setupFinished
        first setupMode
        accept cloudInterface.inboundMessage
        if cloudInterface.inboundMessage.commandKind == CommandKind::requestStatus
        then onlineOff;

      transition onlineReadyOff
        first booting
        if wifiModule.connectionState == ConnectionState::cloudReachable and relay.contactState == RelayState::open
        then onlineOff;

      transition onlineReadyOn
        first booting
        if wifiModule.connectionState == ConnectionState::cloudReachable and relay.contactState == RelayState::closed
        then onlineOn;

      transition turnLoadOn
        first onlineOff
        accept cloudInterface.inboundMessage
        if cloudInterface.inboundMessage.commandKind == CommandKind::turnOn
        then onlineOn;

      transition turnLoadOff
        first onlineOn
        accept cloudInterface.inboundMessage
        if cloudInterface.inboundMessage.commandKind == CommandKind::turnOff
        then onlineOff;

      transition localOn
        first offlineOff
        accept manualButton.buttonOut.buttonEvent
        if manualButton.buttonOut.buttonEvent.pressCount == 1
        then offlineOn;

      transition localOff
        first offlineOn
        accept manualButton.buttonOut.buttonEvent
        if manualButton.buttonOut.buttonEvent.pressCount == 1
        then offlineOff;

      transition cloudLostWhileOn
        first onlineOn
        if wifiModule.connectionState == ConnectionState::offline
        then offlineOn;

      transition cloudLostWhileOff
        first onlineOff
        if wifiModule.connectionState == ConnectionState::offline
        then offlineOff;

      transition cloudRecoveredOn
        first offlineOn
        if wifiModule.connectionState == ConnectionState::cloudReachable
        then onlineOn;

      transition cloudRecoveredOff
        first offlineOff
        if wifiModule.connectionState == ConnectionState::cloudReachable
        then onlineOff;

      transition tripFromOnlineOn
        first onlineOn
        accept metering.measurementOut.measurement
        if metering.measurementOut.measurement.measuredCurrent > maximumContinuousLoadCurrent
        then protectiveShutdown;

      transition tripFromOfflineOn
        first offlineOn
        accept metering.measurementOut.measurement
        if metering.measurementOut.measurement.measuredCurrent > maximumContinuousLoadCurrent
        then protectiveShutdown;

      transition userClearsFault
        first protectiveShutdown
        accept manualButton.buttonOut.buttonEvent
        if manualButton.buttonOut.buttonEvent.pressDuration > 3 [SI::s]
        then offlineOff;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : BelkinWemoSmartPlug;

    doc /*
      The Belkin Wemo based system shall function primarily as a Wi-Fi connected smart outlet that switches AC mains power to a plugged-in appliance on command from a mobile application, cloud automation, voice assistant, schedule, or local button, and shall report its present on/off state to the user.
    */
  }

  requirement def SafeLoadSwitchingRequirement {
    subject system : BelkinWemoSmartPlug;

    doc /*
      The system shall switch a resistive AC load up to 15 A at 120 V RMS and shall open the relay when measured current exceeds the rated continuous load current.
    */
  }

  requirement def StatusReportingRequirement {
    subject system : BelkinWemoSmartPlug;

    doc /*
      The system shall report relay state, cloud connectivity state, measured load power, accumulated energy, firmware version, and last fault at least once every 60 seconds while connected to the home Wi-Fi network.
    */
  }

  requirement def LocalOverrideRequirement {
    subject system : BelkinWemoSmartPlug;

    doc /*
      The system shall provide a local pushbutton that toggles the load output without requiring cloud connectivity.
    */
  }

  requirement def SetupRequirement {
    subject system : BelkinWemoSmartPlug;

    doc /*
      The system shall enter provisioning mode when no home Wi-Fi credentials are configured and shall indicate provisioning mode using the status indicator.
    */
  }

  part wemoSmartOutlet : BelkinWemoSmartPlug {
    attribute productFamily = "Belkin Wemo based smart plug";
    attribute primaryFunction = "Remote and local control of electrical power to a connected appliance through a Wi-Fi enabled switched outlet.";
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject system = wemoSmartOutlet;
  }

  requirement safeLoadSwitching : SafeLoadSwitchingRequirement {
    subject system = wemoSmartOutlet;
  }

  requirement statusReporting : StatusReportingRequirement {
    subject system = wemoSmartOutlet;
  }

  requirement localOverride : LocalOverrideRequirement {
    subject system = wemoSmartOutlet;
  }

  requirement setupBehavior : SetupRequirement {
    subject system = wemoSmartOutlet;
  }

  satisfy primaryFunction by wemoSmartOutlet;
  satisfy safeLoadSwitching by wemoSmartOutlet.relay;
  satisfy safeLoadSwitching by wemoSmartOutlet.metering;
  satisfy statusReporting by wemoSmartOutlet.wifiModule;
  satisfy statusReporting by wemoSmartOutlet.controller;
  satisfy localOverride by wemoSmartOutlet.manualButton;
  satisfy setupBehavior by wemoSmartOutlet.indicator;
  satisfy setupBehavior by wemoSmartOutlet.wifiModule;
}
