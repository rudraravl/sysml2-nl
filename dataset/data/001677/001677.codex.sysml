package OpenPicusBasedSystemModel {
    doc /* High-level primary function: an OpenPicus-based embedded IoT node senses local environmental conditions, processes measurements, and publishes telemetry to a remote service over Wi-Fi while accepting configuration commands. */

    import ScalarValues::*;
    import SI::*;

    value def Voltage {
        unit : Unit = V;
    }

    value def Current {
        unit : Unit = A;
    }

    value def Power {
        unit : Unit = W;
    }

    value def Temperature {
        unit : Unit = degC;
    }

    value def RelativeHumidity {
        unit : Unit = percent;
    }

    value def Illuminance {
        unit : Unit = lx;
    }

    value def Frequency {
        unit : Unit = Hz;
    }

    value def TimeInterval {
        unit : Unit = s;
    }

    value def DataRate {
        unit : Unit = bit / s;
    }

    item def DcPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def SensorSample {
        attribute temperature : Temperature;
        attribute humidity : RelativeHumidity;
        attribute illuminance : Illuminance;
        attribute sampledAtSeconds : TimeInterval;
    }

    item def TelemetryPacket {
        attribute deviceId : String;
        attribute sequenceNumber : Integer;
        attribute temperature : Temperature;
        attribute humidity : RelativeHumidity;
        attribute illuminance : Illuminance;
        attribute supplyVoltage : Voltage;
        attribute uptime : TimeInterval;
    }

    item def ConfigurationCommand {
        attribute targetDeviceId : String;
        attribute samplingPeriod : TimeInterval;
        attribute telemetryPeriod : TimeInterval;
        attribute lowPowerModeEnabled : Boolean;
    }

    port def DcPowerPort {
        in item power : DcPower;
    }

    port def SensorDataPort {
        out item sample : SensorSample;
    }

    port def LocalSensorInputPort {
        in item sample : SensorSample;
    }

    port def TelemetryOutPort {
        out item packet : TelemetryPacket;
    }

    port def CommandInPort {
        in item command : ConfigurationCommand;
    }

    port def WifiRadioPort {
        out item packet : TelemetryPacket;
        in item command : ConfigurationCommand;
    }

    port def CloudServicePort {
        in item packet : TelemetryPacket;
        out item command : ConfigurationCommand;
    }

    action def AcquireSensorSample {
        in item rawSample : SensorSample;
        out item validatedSample : SensorSample;
    }

    action def BuildTelemetryPacket {
        in item sample : SensorSample;
        in attribute deviceId : String;
        in attribute sequenceNumber : Integer;
        in attribute supplyVoltage : Voltage;
        in attribute uptime : TimeInterval;
        out item packet : TelemetryPacket;
    }

    action def PublishTelemetry {
        in item packet : TelemetryPacket;
        out attribute acknowledged : Boolean;
    }

    action def ApplyConfiguration {
        in item command : ConfigurationCommand;
        out attribute activeSamplingPeriod : TimeInterval;
        out attribute activeTelemetryPeriod : TimeInterval;
        out attribute lowPowerModeEnabled : Boolean;
    }

    state def NodeOperationalStateMachine {
        state Initializing;
        state JoiningNetwork;
        state Sampling;
        state Publishing;
        state ReceivingConfiguration;
        state LowPowerSleep;
        state Fault;

        transition first Initializing;
        transition InitializingToJoining
            first Initializing
            then JoiningNetwork;

        transition JoiningToSampling
            first JoiningNetwork
            then Sampling;

        transition SamplingToPublishing
            first Sampling
            then Publishing;

        transition PublishingToSampling
            first Publishing
            then Sampling;

        transition SamplingToReceivingConfiguration
            first Sampling
            then ReceivingConfiguration;

        transition ReceivingConfigurationToSampling
            first ReceivingConfiguration
            then Sampling;

        transition SamplingToLowPowerSleep
            first Sampling
            then LowPowerSleep;

        transition LowPowerSleepToSampling
            first LowPowerSleep
            then Sampling;

        transition AnyFaultFromSampling
            first Sampling
            then Fault;

        transition AnyFaultFromPublishing
            first Publishing
            then Fault;
    }

    part def PowerSupply {
        port dcOut : DcPowerPort;
        attribute nominalVoltage : Voltage = 5.0 [V];
        attribute maximumCurrent : Current = 1.0 [A];
        attribute maximumPower : Power = 5.0 [W];
    }

    part def OpenPicusFlyportModule {
        port dcIn : DcPowerPort;
        port sensorIn : LocalSensorInputPort;
        port wifi : WifiRadioPort;

        attribute deviceId : String = "openpicus-node-001";
        attribute cpuClock : Frequency = 32.0 [MHz];
        attribute operatingVoltage : Voltage = 3.3 [V];
        attribute activeCurrent : Current = 180.0 [mA];
        attribute sleepCurrent : Current = 3.0 [mA];
        attribute wifiDataRate : DataRate = 54000000.0 [bit / s];
        attribute samplingPeriod : TimeInterval = 10.0 [s];
        attribute telemetryPeriod : TimeInterval = 60.0 [s];
        attribute sequenceNumber : Integer = 0;

        perform action acquire : AcquireSensorSample;
        perform action build : BuildTelemetryPacket;
        perform action publish : PublishTelemetry;
        perform action configure : ApplyConfiguration;

        exhibit state operationalBehavior : NodeOperationalStateMachine;
    }

    part def EnvironmentalSensorBoard {
        port dcIn : DcPowerPort;
        port sensorOut : SensorDataPort;

        attribute temperatureRangeLow : Temperature = -20.0 [degC];
        attribute temperatureRangeHigh : Temperature = 85.0 [degC];
        attribute humidityRangeLow : RelativeHumidity = 0.0 [percent];
        attribute humidityRangeHigh : RelativeHumidity = 100.0 [percent];
        attribute lightRangeHigh : Illuminance = 65000.0 [lx];
        attribute conversionTime : TimeInterval = 0.25 [s];
        attribute supplyVoltage : Voltage = 3.3 [V];
        attribute operatingCurrent : Current = 12.0 [mA];
    }

    part def WifiAccessPoint {
        port radio : WifiRadioPort;
        attribute ssid : String = "PlantFloor-IoT";
        attribute channelFrequency : Frequency = 2.437 [GHz];
        attribute minimumSignalMargin : Real = 15.0;
    }

    part def RemoteTelemetryService {
        port api : CloudServicePort;
        attribute endpoint : String = "mqtts://telemetry.example.local/openpicus";
        attribute retainedCommandEnabled : Boolean = true;
        attribute minimumAcceptedTelemetryPeriod : TimeInterval = 15.0 [s];
    }

    part def OpenPicusEnvironmentalMonitor {
        part supply : PowerSupply;
        part sensorBoard : EnvironmentalSensorBoard;
        part controller : OpenPicusFlyportModule;
        part accessPoint : WifiAccessPoint;
        part cloud : RemoteTelemetryService;

        connect supply.dcOut to controller.dcIn;
        connect supply.dcOut to sensorBoard.dcIn;
        connect sensorBoard.sensorOut to controller.sensorIn;
        connect controller.wifi to accessPoint.radio;
        connect accessPoint.radio to cloud.api;

        attribute primaryFunction : String =
            "Sense environmental conditions and publish telemetry through an OpenPicus Wi-Fi embedded controller.";
        attribute requiredAvailability : Real = 0.995;
        attribute maximumStartupTime : TimeInterval = 30.0 [s];
    }

    requirement def PrimaryFunctionRequirement {
        subject monitoredSystem : OpenPicusEnvironmentalMonitor;
        doc /* The system shall use an OpenPicus-based Wi-Fi embedded controller to collect environmental sensor data and transmit structured telemetry to a remote service. */
    }

    requirement def SamplingRequirement {
        subject controller : OpenPicusFlyportModule;
        require constraint {
            controller.samplingPeriod <= 10.0 [s]
        }
    }

    requirement def TelemetryPeriodRequirement {
        subject controller : OpenPicusFlyportModule;
        require constraint {
            controller.telemetryPeriod <= 60.0 [s]
        }
    }

    requirement def PowerRequirement {
        subject controller : OpenPicusFlyportModule;
        require constraint {
            controller.operatingVoltage == 3.3 [V] and controller.activeCurrent <= 250.0 [mA]
        }
    }

    requirement def SensorCoverageRequirement {
        subject sensorBoard : EnvironmentalSensorBoard;
        require constraint {
            sensorBoard.temperatureRangeLow <= -10.0 [degC] and
            sensorBoard.temperatureRangeHigh >= 60.0 [degC] and
            sensorBoard.humidityRangeHigh >= 95.0 [percent]
        }
    }

    requirement def ConfigurationRequirement {
        subject cloud : RemoteTelemetryService;
        doc /* The remote service shall provide configuration commands that can update sampling period, telemetry period, and low-power operating mode. */
    }

    requirement def StartupRequirement {
        subject monitoredSystem : OpenPicusEnvironmentalMonitor;
        require constraint {
            monitoredSystem.maximumStartupTime <= 30.0 [s]
        }
    }

    part system : OpenPicusEnvironmentalMonitor;

    requirement primaryFunctionReq : PrimaryFunctionRequirement {
        subject monitoredSystem = system;
    }

    requirement samplingReq : SamplingRequirement {
        subject controller = system.controller;
    }

    requirement telemetryReq : TelemetryPeriodRequirement {
        subject controller = system.controller;
    }

    requirement powerReq : PowerRequirement {
        subject controller = system.controller;
    }

    requirement sensorReq : SensorCoverageRequirement {
        subject sensorBoard = system.sensorBoard;
    }

    requirement configReq : ConfigurationRequirement {
        subject cloud = system.cloud;
    }

    requirement startupReq : StartupRequirement {
        subject monitoredSystem = system;
    }
}