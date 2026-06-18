package OpenPicusBasedIoTSystem {

    import ScalarValues::*;

    attribute def Voltage_V :> Real {
        doc /* Electric potential in volts. */
    }

    attribute def Current_mA :> Real {
        doc /* Electric current in milliamperes. */
    }

    attribute def Power_W :> Real {
        doc /* Electrical power in watts. */
    }

    attribute def Temperature_degC :> Real {
        doc /* Temperature in degrees Celsius. */
    }

    attribute def RelativeHumidity_pct :> Real {
        doc /* Relative humidity in percent. */
    }

    attribute def Illuminance_lux :> Real {
        doc /* Illuminance in lux. */
    }

    attribute def Time_s :> Real {
        doc /* Time duration in seconds. */
    }

    attribute def Frequency_Hz :> Real {
        doc /* Frequency in hertz. */
    }

    attribute def DataRate_kbps :> Real {
        doc /* Data rate in kilobits per second. */
    }

    attribute def Memory_KiB :> Real {
        doc /* Memory capacity in kibibytes. */
    }

    attribute def DigitalLevel :> Boolean {
        doc /* Logical level for digital input or output. */
    }

    enum def OperatingMode {
        enum off;
        enum booting;
        enum joiningNetwork;
        enum sensing;
        enum publishing;
        enum commandHandling;
        enum faultRecovery;
        enum maintenance;
    }

    enum def NetworkTechnology {
        enum wifi;
        enum ethernet;
        enum cellular;
    }

    enum def ConnectionState {
        enum disconnected;
        enum associating;
        enum dhcpResolving;
        enum connected;
        enum degraded;
        enum failed;
    }

    enum def ActuatorState {
        enum inactive;
        enum active;
        enum pulsed;
        enum inhibited;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage_V;
        attribute current : Current_mA;
        attribute power : Power_W;
    }

    item def PowerStatus {
        attribute inputVoltage : Voltage_V;
        attribute regulatedVoltage : Voltage_V;
        attribute currentDraw : Current_mA;
        attribute powerGood : Boolean;
    }

    item def EnvironmentSample {
        attribute sampleTime : Time_s;
        attribute temperature : Temperature_degC;
        attribute humidity : RelativeHumidity_pct;
        attribute lightLevel : Illuminance_lux;
        attribute valid : Boolean;
    }

    item def TelemetryMessage {
        attribute sequenceNumber : Integer;
        attribute sourceId : String;
        attribute encodedPayloadBytes : Integer;
        attribute publishPeriod : Time_s;
        attribute temperature : Temperature_degC;
        attribute humidity : RelativeHumidity_pct;
        attribute lightLevel : Illuminance_lux;
    }

    item def ControlCommand {
        attribute commandId : Integer;
        attribute requestedRelayState : Boolean;
        attribute requestedLedState : Boolean;
        attribute validUntil : Time_s;
    }

    item def ActuatorDrive {
        attribute relayLevel : DigitalLevel;
        attribute ledLevel : DigitalLevel;
        attribute pulseWidth : Time_s;
    }

    item def NetworkFrame {
        attribute frameBytes : Integer;
        attribute dataRate : DataRate_kbps;
        attribute authenticated : Boolean;
    }

    item def DiagnosticRecord {
        attribute uptime : Time_s;
        attribute freeMemory : Memory_KiB;
        attribute networkState : ConnectionState;
        attribute lastErrorCode : Integer;
        attribute resetCount : Integer;
    }

    port def DCInputPort {
        in item dcPower : ElectricalEnergy;
        out item status : PowerStatus;
    }

    port def RegulatedPowerPort {
        out item regulatedPower : ElectricalEnergy;
        in item loadStatus : PowerStatus;
    }

    port def SensorPort {
        out item sample : EnvironmentSample;
        in item excitationPower : ElectricalEnergy;
    }

    port def SensorBusPort {
        in item sensorSample : EnvironmentSample;
        out item sensorPower : ElectricalEnergy;
    }

    port def NetworkPort {
        out item txFrame : NetworkFrame;
        in item rxFrame : NetworkFrame;
    }

    port def CloudApplicationPort {
        in item telemetry : TelemetryMessage;
        out item command : ControlCommand;
        in item diagnostic : DiagnosticRecord;
    }

    port def DigitalActuatorPort {
        in item drive : ActuatorDrive;
        out item stateFeedback : ActuatorState;
    }

    port def UserStatusPort {
        out item diagnostic : DiagnosticRecord;
        out item modeIndication : OperatingMode;
    }

    constraint def VoltageWithinRange {
        in value : Voltage_V;
        in minimum : Voltage_V;
        in maximum : Voltage_V;
        value >= minimum and value <= maximum
    }

    constraint def SamplingPeriodLimit {
        in period : Time_s;
        period >= 1.0 and period <= 3600.0
    }

    constraint def HumidityPhysicalRange {
        in humidity : RelativeHumidity_pct;
        humidity >= 0.0 and humidity <= 100.0
    }

    part def ExternalDCPowerSupply {
        doc /* Provides regulated DC input power to the OpenPicus-based controller. */
        attribute nominalVoltage : Voltage_V = 5.0;
        attribute maximumCurrent : Current_mA = 1000.0;
        attribute availablePower : Power_W = 5.0;
        port dcOut : DCInputPort;
    }

    part def VoltageRegulator {
        doc /* Converts external 5 V input into the 3.3 V rail used by the OpenPicus Flyport module and sensors. */
        attribute inputVoltageMinimum : Voltage_V = 4.5;
        attribute inputVoltageMaximum : Voltage_V = 5.5;
        attribute outputVoltage : Voltage_V = 3.3;
        attribute outputCurrentLimit : Current_mA = 500.0;
        port input : DCInputPort;
        port output : RegulatedPowerPort;

        constraint inputRange : VoltageWithinRange {
            in value = input.dcPower.voltage;
            in minimum = inputVoltageMinimum;
            in maximum = inputVoltageMaximum;
        }
    }

    part def TemperatureHumiditySensor {
        doc /* Digital environmental sensor measuring air temperature and relative humidity. */
        attribute temperatureAccuracy : Temperature_degC = 0.5;
        attribute humidityAccuracy : RelativeHumidity_pct = 3.0;
        attribute conversionTime : Time_s = 0.05;
        port sensorIf : SensorPort;
    }

    part def LightSensor {
        doc /* Analog or digital light sensor providing ambient illuminance. */
        attribute minimumIlluminance : Illuminance_lux = 0.0;
        attribute maximumIlluminance : Illuminance_lux = 100000.0;
        attribute conversionTime : Time_s = 0.02;
        port sensorIf : SensorPort;
    }

    part def RelayDriver {
        doc /* Low-side driver for switching an external load under OpenPicus digital output control. */
        attribute coilVoltage : Voltage_V = 5.0;
        attribute maximumSwitchedCurrent : Current_mA = 2000.0;
        attribute state : ActuatorState = ActuatorState::inactive;
        port control : DigitalActuatorPort;
    }

    part def StatusLed {
        doc /* Visual indicator driven by a GPIO pin to show network and application status. */
        attribute forwardVoltage : Voltage_V = 2.0;
        attribute forwardCurrent : Current_mA = 10.0;
        attribute state : ActuatorState = ActuatorState::inactive;
        port control : DigitalActuatorPort;
    }

    part def PICMicrocontroller {
        doc /* Embedded PIC microcontroller executing the OpenPicus application firmware. */
        attribute clockFrequency : Frequency_Hz = 32000000.0;
        attribute flashMemory : Memory_KiB = 256.0;
        attribute ramMemory : Memory_KiB = 16.0;
        attribute watchdogTimeout : Time_s = 2.0;
        port sensorBus : SensorBusPort;
        port actuatorOut : DigitalActuatorPort;
        port statusOut : UserStatusPort;
        port moduleNetwork : NetworkPort;
    }

    part def NetworkTransceiver {
        doc /* OpenPicus network interface providing IP connectivity, modeled as Wi-Fi-capable with optional Ethernet variant. */
        attribute technology : NetworkTechnology = NetworkTechnology::wifi;
        attribute nominalDataRate : DataRate_kbps = 54000.0;
        attribute connectionState : ConnectionState = ConnectionState::disconnected;
        attribute reconnectInterval : Time_s = 10.0;
        port controllerSide : NetworkPort;
        port infrastructureSide : NetworkPort;
    }

    part def EmbeddedWebAndMqttApplication {
        doc /* Firmware service exposing a small web interface and publishing sensor telemetry to a remote service. */
        attribute httpEnabled : Boolean = true;
        attribute mqttEnabled : Boolean = true;
        attribute telemetryPeriod : Time_s = 60.0;
        attribute retainedLastSample : Boolean = true;
        port localNetwork : NetworkPort;
        port cloudApi : CloudApplicationPort;

        constraint periodLimit : SamplingPeriodLimit {
            in period = telemetryPeriod;
        }
    }

    part def OpenPicusFlyportModule {
        doc /* OpenPicus Flyport-style module combining a PIC microcontroller, network transceiver, memory resources, GPIO, and application firmware. */
        attribute supplyVoltage : Voltage_V = 3.3;
        attribute typicalCurrent : Current_mA = 180.0;
        attribute bootTime : Time_s = 3.0;
        attribute mode : OperatingMode = OperatingMode::off;

        port powerIn : RegulatedPowerPort;
        port sensorExpansion : SensorBusPort;
        port actuatorExpansion : DigitalActuatorPort;
        port network : NetworkPort;
        port userStatus : UserStatusPort;

        part mcu : PICMicrocontroller;
        part transceiver : NetworkTransceiver;
        part application : EmbeddedWebAndMqttApplication;

        connection internalNetworkA connect mcu.moduleNetwork to transceiver.controllerSide;
        connection internalNetworkB connect transceiver.infrastructureSide to application.localNetwork;
        connection sensorRouting connect sensorExpansion to mcu.sensorBus;
        connection actuatorRouting connect mcu.actuatorOut to actuatorExpansion;
        connection statusRouting connect mcu.statusOut to userStatus;
        connection applicationCloudRouting connect application.cloudApi to network;
    }

    part def CloudIoTService {
        doc /* Remote service receiving telemetry, storing diagnostic records, and issuing control commands. */
        attribute endpointName : String = "openpicus-node.telemetry.example";
        attribute acceptsMqtt : Boolean = true;
        attribute acceptsHttpPost : Boolean = true;
        attribute maximumPayloadBytes : Integer = 2048;
        port serviceApi : CloudApplicationPort;
    }

    part def LocalUserClient {
        doc /* Browser or mobile client interacting with the embedded OpenPicus web interface on the local network. */
        attribute supportsHttp : Boolean = true;
        attribute supportsStatusView : Boolean = true;
        port networkAccess : NetworkPort;
    }

    part def MonitoredEnvironment {
        doc /* Physical environment observed by the OpenPicus-based node. */
        attribute ambientTemperature : Temperature_degC = 22.0;
        attribute ambientHumidity : RelativeHumidity_pct = 45.0;
        attribute ambientLight : Illuminance_lux = 350.0;

        constraint humidityRange : HumidityPhysicalRange {
            in humidity = ambientHumidity;
        }
    }

    action def InitializeHardware {
        doc /* Configure clocks, GPIO directions, ADC channels, sensor buses, watchdog, and network stack. */
        out initialized : Boolean;
    }

    action def JoinIpNetwork {
        doc /* Associate to configured network, obtain IP configuration, and open application sockets. */
        in technology : NetworkTechnology;
        out connectionState : ConnectionState;
    }

    action def ReadEnvironmentSensors {
        doc /* Acquire temperature, humidity, and light measurements through OpenPicus expansion interfaces. */
        in samplePeriod : Time_s;
        out sample : EnvironmentSample;
    }

    action def ValidateSample {
        doc /* Reject physically impossible or stale sensor readings before publication. */
        in rawSample : EnvironmentSample;
        out checkedSample : EnvironmentSample;
        out accepted : Boolean;
    }

    action def EncodeTelemetry {
        doc /* Convert a validated sample into a compact telemetry message for HTTP or MQTT transport. */
        in checkedSample : EnvironmentSample;
        in sourceId : String;
        out telemetry : TelemetryMessage;
    }

    action def PublishTelemetry {
        doc /* Send telemetry from the OpenPicus application to the configured cloud endpoint. */
        in telemetry : TelemetryMessage;
        out frame : NetworkFrame;
        out delivered : Boolean;
    }

    action def ReceiveControlCommand {
        doc /* Receive a cloud or local user command and check it before actuator execution. */
        in frame : NetworkFrame;
        out command : ControlCommand;
        out commandAccepted : Boolean;
    }

    action def DriveActuators {
        doc /* Translate a valid command into GPIO levels for relay and status LED outputs. */
        in command : ControlCommand;
        out drive : ActuatorDrive;
    }

    action def ReportDiagnostics {
        doc /* Emit uptime, memory, network, and reset-count diagnostics. */
        in mode : OperatingMode;
        in networkState : ConnectionState;
        out diagnostic : DiagnosticRecord;
    }

    action def OpenPicusSenseProcessPublishLoop {
        doc /* Primary behavior: periodically sense the environment, process the sample, publish telemetry, receive commands, and drive actuators. */
        in samplePeriod : Time_s;
        in sourceId : String;
        out latestTelemetry : TelemetryMessage;
        out latestDiagnostic : DiagnosticRecord;

        action initialize : InitializeHardware;
        action joinNetwork : JoinIpNetwork;
        action readSensors : ReadEnvironmentSensors;
        action validate : ValidateSample;
        action encode : EncodeTelemetry;
        action publish : PublishTelemetry;
        action receiveCommand : ReceiveControlCommand;
        action drive : DriveActuators;
        action report : ReportDiagnostics;

        flow initialize.initialized to joinNetwork.connectionState;
        flow readSensors.sample to validate.rawSample;
        flow validate.checkedSample to encode.checkedSample;
        flow encode.telemetry to publish.telemetry;
        flow publish.frame to receiveCommand.frame;
        flow receiveCommand.command to drive.command;
        flow encode.telemetry to latestTelemetry;
        flow report.diagnostic to latestDiagnostic;
    }

    state def OpenPicusControllerLifecycle {
        doc /* Operational state machine for the OpenPicus-based controller. */

        state Off;
        state Booting;
        state JoiningNetwork;
        state Running {
            state Sensing;
            state Publishing;
            state CommandHandling;
            state Diagnostics;

            transition first Sensing then Publishing;
            transition publishComplete first Publishing then CommandHandling;
            transition commandHandled first CommandHandling then Diagnostics;
            transition diagnosticReported first Diagnostics then Sensing;
        }
        state FaultRecovery;
        state Maintenance;

        transition initial then Off;
        transition powerApplied first Off then Booting;
        transition hardwareInitialized first Booting then JoiningNetwork;
        transition networkConnected first JoiningNetwork then Running;
        transition networkFailed first JoiningNetwork then FaultRecovery;
        transition watchdogExpired first Running then FaultRecovery;
        transition faultCleared first FaultRecovery then Booting;
        transition serviceRequested first Running then Maintenance;
        transition serviceComplete first Maintenance then Booting;
        transition powerRemoved first Booting then Off;
        transition powerRemoved first JoiningNetwork then Off;
        transition powerRemoved first Running then Off;
        transition powerRemoved first FaultRecovery then Off;
        transition powerRemoved first Maintenance then Off;
    }

    part def OpenPicusBasedIoTController {
        doc /* High-level system based on an OpenPicus Flyport-style module. Its primary function is to act as a compact networked embedded controller that senses local environmental conditions, processes the measurements, publishes telemetry to a cloud or local client, and applies received commands to simple actuators. */
        attribute nodeId : String = "OPC-FLYPORT-ENV-CTRL-001";
        attribute nominalInputVoltage : Voltage_V = 5.0;
        attribute regulatedLogicVoltage : Voltage_V = 3.3;
        attribute nominalSamplePeriod : Time_s = 60.0;
        attribute expectedAveragePower : Power_W = 1.2;
        attribute currentMode : OperatingMode = OperatingMode::off;

        port dcInput : DCInputPort;
        port cloudConnection : CloudApplicationPort;
        port localUserConnection : NetworkPort;
        port status : UserStatusPort;

        part regulator : VoltageRegulator;
        part openPicus : OpenPicusFlyportModule;
        part temperatureHumiditySensor : TemperatureHumiditySensor;
        part lightSensor : LightSensor;
        part relayDriver : RelayDriver;
        part statusLed : StatusLed;

        perform behavior : OpenPicusSenseProcessPublishLoop;
        exhibit lifecycle : OpenPicusControllerLifecycle;

        connection inputPowerTrace connect dcInput to regulator.input;
        connection regulatedPowerTrace connect regulator.output to openPicus.powerIn;
        connection tempHumiditySensorBus connect temperatureHumiditySensor.sensorIf to openPicus.sensorExpansion;
        connection lightSensorBus connect lightSensor.sensorIf to openPicus.sensorExpansion;
        connection relayControlTrace connect openPicus.actuatorExpansion to relayDriver.control;
        connection ledControlTrace connect openPicus.actuatorExpansion to statusLed.control;
        connection cloudTrace connect openPicus.network to cloudConnection;
        connection localUserTrace connect openPicus.network to localUserConnection;
        connection statusTrace connect openPicus.userStatus to status;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The OpenPicus-based system shall provide networked embedded monitoring and control by collecting environmental measurements, processing them locally, publishing telemetry, and responding to valid remote or local commands. */
        subject controller : OpenPicusBasedIoTController;
        require constraint {
            controller.nominalSamplePeriod >= 1.0 and
            controller.nominalSamplePeriod <= 3600.0
        }
    }

    requirement def OpenPicusBasisRequirement {
        doc /* The controller shall include an OpenPicus Flyport-style module containing a PIC microcontroller, network transceiver, GPIO expansion, and embedded web or messaging application. */
        subject controller : OpenPicusBasedIoTController;
    }

    requirement def PowerRequirement {
        doc /* The controller shall operate from a nominal 5 V DC input and regulate logic power to 3.3 V for the OpenPicus module and attached sensors. */
        subject controller : OpenPicusBasedIoTController;
        require constraint {
            controller.nominalInputVoltage == 5.0 and
            controller.regulatedLogicVoltage == 3.3
        }
    }

    requirement def TelemetryRequirement {
        doc /* The controller shall publish temperature, humidity, light level, node identifier, and diagnostic status at the configured sampling period. */
        subject controller : OpenPicusBasedIoTController;
        require constraint {
            controller.nominalSamplePeriod <= 60.0
        }
    }

    requirement def CommandRequirement {
        doc /* The controller shall accept authenticated network commands and translate valid requests into relay and LED actuator drive signals. */
        subject controller : OpenPicusBasedIoTController;
    }

    requirement def FaultRecoveryRequirement {
        doc /* The controller shall enter fault recovery on network failure or watchdog timeout and shall attempt automatic restart without unsafe actuator activation. */
        subject controller : OpenPicusBasedIoTController;
    }

    part openPicusSystemContext {
        doc /* System context for an OpenPicus-based IoT monitoring and control node. */
        part powerSupply : ExternalDCPowerSupply;
        part controller : OpenPicusBasedIoTController;
        part environment : MonitoredEnvironment;
        part cloudService : CloudIoTService;
        part userClient : LocalUserClient;

        connection systemPower connect powerSupply.dcOut to controller.dcInput;
        connection telemetryAndCommandPath connect controller.cloudConnection to cloudService.serviceApi;
        connection localWebAccess connect controller.localUserConnection to userClient.networkAccess;

        requirement primaryFunction : PrimaryFunctionRequirement {
            subject controller = controller;
        }

        requirement openPicusBasis : OpenPicusBasisRequirement {
            subject controller = controller;
        }

        requirement powerOperation : PowerRequirement {
            subject controller = controller;
        }

        requirement telemetryPublication : TelemetryRequirement {
            subject controller = controller;
        }

        requirement commandHandling : CommandRequirement {
            subject controller = controller;
        }

        requirement automaticFaultRecovery : FaultRecoveryRequirement {
            subject controller = controller;
        }

        satisfy primaryFunction by controller;
        satisfy openPicusBasis by controller.openPicus;
        satisfy powerOperation by controller.regulator;
        satisfy telemetryPublication by controller.behavior;
        satisfy commandHandling by controller.openPicus.mcu;
        satisfy automaticFaultRecovery by controller.lifecycle;
    }
}
