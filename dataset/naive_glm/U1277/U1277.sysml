package IoTEnvironmentalMonitoringSystem {

  import ScalarValues::*;
  import ISQ::*;

  package ValueTypes {
    value def TemperatureValue :> Real { unit 'C'; }
    value def HumidityValue :> Real { unit '%'; }
    value def PressureValue :> Real { unit 'Pa'; }
    value def BatteryLevelValue :> Real { unit '%'; }
    value def SignalStrengthValue :> Real { unit 'dBm'; }
    value def DataRateValue :> Real { unit 'kbps'; }
    value def PowerConsumptionValue :> Real { unit 'mW'; }
    value def LuminosityValue :> Real { unit 'lx'; }
  }

  package Items {

    item def SensorReading {
      attribute sensorId : String;
      attribute timestamp : String;
      attribute temperature : TemperatureValue;
      attribute humidity : HumidityValue;
      attribute pressure : PressureValue;
      attribute batteryLevel : BatteryLevelValue;
      attribute signalStrength : SignalStrengthValue;
    }

    item def ControlCommand {
      attribute commandId : String;
      attribute targetDeviceId : String;
      attribute commandType : CommandType;
      attribute parameterValue : Real;
      attribute priority : Integer;
      attribute issuedTimestamp : String;
    }

    enumeration def CommandType {
      literal turnOnCooling;
      literal turnOffCooling;
      literal turnOnHeating;
      literal turnOffHeating;
      literal setFanSpeed;
      literal setDimLevel;
      literal turnOnLight;
      literal turnOffLight;
    }

    item def StatusReport {
      attribute deviceId : String;
      attribute timestamp : String;
      attribute commandId : String;
      attribute status : CommandStatus;
      attribute currentValue : Real;
      attribute message : String;
    }

    enumeration def CommandStatus {
      literal success;
      literal failure;
      literal inProgress;
    }

    item def SecuredPayload {
      attribute payloadId : String;
      attribute sourceId : String;
      attribute destinationId : String;
      attribute encryptedData : String;
      attribute authenticationTag : String;
      attribute timestamp : String;
      attribute payloadType : PayloadType;
    }

    enumeration def PayloadType {
      literal sensorData;
      literal controlCommand;
      literal statusReport;
    }

    item def AlertEvent {
      attribute alertId : String;
      attribute severity : SeverityLevel;
      attribute message : String;
      attribute sourceDeviceId : String;
      attribute timestamp : String;
    }

    enumeration def SeverityLevel {
      literal info;
      literal warning;
      literal critical;
    }

    item def DeviceRegistration {
      attribute deviceId : String;
      attribute deviceType : String;
      attribute location : String;
      attribute registeredTimestamp : String;
    }
  }

  package Ports {

    port def SensorDataOutPort {
      out item reading : SensorReading;
    }

    port def SensorDataInPort {
      in item reading : SensorReading;
    }

    port def CommandOutPort {
      out item command : ControlCommand;
    }

    port def CommandInPort {
      in item command : ControlCommand;
    }

    port def StatusOutPort {
      out item report : StatusReport;
    }

    port def StatusInPort {
      in item report : StatusReport;
    }

    port def SecuredOutPort {
      out item payload : SecuredPayload;
    }

    port def SecuredInPort {
      in item payload : SecuredPayload;
    }

    port def AlertOutPort {
      out item alert : AlertEvent;
    }

    port def AlertInPort {
      in item alert : AlertEvent;
    }

    port def RegistrationOutPort {
      out item registration : DeviceRegistration;
    }

    port def RegistrationInPort {
      in item registration : DeviceRegistration;
    }
  }

  package Components {

    // ----------------------------------------------------------------
    // IoT Sensor — battery-powered edge device
    // ----------------------------------------------------------------
    part def IoTSensor {
      attribute sensorId : String;
      attribute location : String;
      attribute batteryLevel : BatteryLevelValue := 100;
      attribute lowBatteryThreshold : BatteryLevelValue := 20;
      attribute samplingIntervalSeconds : Integer := 300;
      attribute isLowPower : Boolean := true;
      attribute firmwareVersion : String := "2.1.0";

      port dataOut : SensorDataOutPort;
      port registrationOut : RegistrationOutPort;

      action def TakeMeasurement {
        out temperature : TemperatureValue;
        out humidity : HumidityValue;
        out pressure : PressureValue;
      }

      action def TransmitReading {
        in reading : SensorReading;
      }

      action def CheckBattery {
        in currentLevel : BatteryLevelValue;
        out isLow : Boolean;
      }

      state def SensorStateMachine {
        entry;
        state Sleeping {
          entry { /* Enter low-power sleep mode to conserve battery */ }
        }
        state Measuring {
          entry { /* Wake from sleep and take environmental measurements */ }
          do { TakeMeasurement; }
        }
        state Transmitting {
          entry { /* Transmit sensor reading to network gateway */ }
          do { TransmitReading; }
        }
        state LowBatteryAlert {
          entry { /* Transmit low-battery alert to gateway */ }
        }
        transition from entry to Sleeping;
        transition from Sleeping to Measuring
          after (samplingIntervalSeconds * 1 [s]);
        transition from Measuring to Transmitting;
        transition from Transmitting to Sleeping
          when (batteryLevel >= lowBatteryThreshold);
        transition from Transmitting to LowBatteryAlert
          when (batteryLevel < lowBatteryThreshold);
        transition from LowBatteryAlert to Sleeping;
      }

      exhibit SensorStateMachine;
    }

    // ----------------------------------------------------------------
    // Network Gateway — routes data between edge and cloud
    // ----------------------------------------------------------------
    part def NetworkGateway {
      attribute gatewayId : String;
      attribute maxConnectedDevices : Integer := 100;
      attribute connectedDeviceCount : Integer := 0;
      attribute dataRate : DataRateValue;
      attribute firmwareVersion : String := "3.0.2";

      port sensorDataIn : SensorDataInPort;
      port commandOut : CommandOutPort;
      port statusIn : StatusInPort;
      port securedDataOut : SecuredOutPort;
      port securedCommandIn : SecuredInPort;
      port registrationIn : RegistrationInPort;
      port alertOut : AlertOutPort;

      action def RouteSensorData {
        in reading : SensorReading;
        out payload : SecuredPayload;
      }

      action def RouteCommand {
        in payload : SecuredPayload;
        out command : ControlCommand;
      }

      action def RouteStatus {
        in report : StatusReport;
        out payload : SecuredPayload;
      }

      action def RegisterDevice {
        in registration : DeviceRegistration;
        out accepted : Boolean;
      }

      state def GatewayStateMachine {
        entry;
        state Idle;
        state RoutingSensorData {
          do { RouteSensorData; }
        }
        state RoutingCommand {
          do { RouteCommand; }
        }
        state RoutingStatus {
          do { RouteStatus; }
        }
        state Registering {
          do { RegisterDevice; }
        }
        transition from entry to Idle;
        transition from Idle to RoutingSensorData
          when (sensorDataIn.reading is received);
        transition from RoutingSensorData to Idle;
        transition from Idle to RoutingCommand
          when (securedCommandIn.payload is received);
        transition from RoutingCommand to Idle;
        transition from Idle to RoutingStatus
          when (statusIn.report is received);
        transition from RoutingStatus to Idle;
        transition from Idle to Registering
          when (registrationIn.registration is received);
        transition from Registering to Idle;
      }

      exhibit GatewayStateMachine;
    }

    // ----------------------------------------------------------------
    // Security Module — AES-256 encryption and source authentication
    // ----------------------------------------------------------------
    part def SecurityModule {
      attribute moduleId : String;
      attribute encryptionAlgorithm : String := "AES-256";
      attribute authenticationEnabled : Boolean := true;
      attribute encryptionKey : String;
      attribute authenticationKey : String;
      attribute keyRotationIntervalHours : Integer := 24;

      port plainDataIn : SensorDataInPort;
      port plainCommandOut : CommandOutPort;
      port plainStatusIn : StatusInPort;
      port securedDataOut : SecuredOutPort;
      port securedCommandOut : SecuredOutPort;
      port securedDataIn : SecuredInPort;
      port securedCommandIn : SecuredInPort;

      action def AuthenticateSource {
        in sourceId : String;
        out authenticated : Boolean;
      }

      action def EncryptPayload {
        in data : String;
        in key : String;
        out encryptedData : String;
        out authTag : String;
      }

      action def DecryptPayload {
        in encryptedData : String;
        in key : String;
        out decryptedData : String;
        out verified : Boolean;
      }

      action def ProcessSensorData {
        in reading : SensorReading;
        out payload : SecuredPayload;
      }

      action def ProcessCommand {
        in payload : SecuredPayload;
        out command : ControlCommand;
      }

      action def ProcessStatus {
        in report : StatusReport;
        out payload : SecuredPayload;
      }

      action def RotateKeys {
        out newEncryptionKey : String;
        out newAuthKey : String;
      }

      state def SecurityStateMachine {
        entry;
        state Idle;
        state Authenticating {
          do { AuthenticateSource; }
        }
        state Encrypting {
          do { EncryptPayload; }
        }
        state Decrypting {
          do { DecryptPayload; }
        }
        state KeyRotating {
          do { RotateKeys; }
        }
        transition from entry to Idle;
        transition from Idle to Authenticating
          when (plainDataIn.reading is received
                or plainStatusIn.report is received
                or securedCommandIn.payload is received);
        transition from Authenticating to Encrypting
          when (plainDataIn.reading is received
                or plainStatusIn.report is received);
        transition from Authenticating to Decrypting
          when (securedCommandIn.payload is received);
        transition from Encrypting to Idle;
        transition from Decrypting to Idle;
        transition from Idle to KeyRotating
          after (keyRotationIntervalHours * 3600 [s]);
        transition from KeyRotating to Idle;
      }

      exhibit SecurityStateMachine;
    }

    // ----------------------------------------------------------------
    // Cloud Platform — aggregation, storage, analysis, command generation
    // ----------------------------------------------------------------
    part def CloudPlatform {
      attribute platformId : String;
      attribute temperatureThresholdHigh : TemperatureValue := 26;
      attribute temperatureThresholdLow : TemperatureValue := 18;
      attribute humidityThresholdHigh : HumidityValue := 70;
      attribute humidityThresholdLow : HumidityValue := 30;
      attribute dataStorageCapacityGB : Integer := 1000;
      attribute analysisWindowMinutes : Integer := 15;

      port securedDataIn : SecuredInPort;
      port securedCommandOut : SecuredOutPort;
      port alertIn : AlertInPort;

      action def AggregateData {
        in payload : SecuredPayload;
        out aggregatedData : String;
      }

      action def StoreData {
        in data : String;
      }

      action def AnalyzeData {
        in data : String;
        out anomalyDetected : Boolean;
        out actionNeeded : Boolean;
        out targetDeviceId : String;
        out recommendedCommand : CommandType;
        out parameterValue : Real;
      }

      action def GenerateCommand {
        in actionNeeded : Boolean;
        in targetDeviceId : String;
        in recommendedCommand : CommandType;
        in parameterValue : Real;
        out command : ControlCommand;
      }

      action def HandleAlert {
        in alert : AlertEvent;
      }

      state def CloudStateMachine {
        entry;
        state Idle;
        state Receiving {
          do { AggregateData; }
        }
        state Storing {
          do { StoreData; }
        }
        state Analyzing {
          do { AnalyzeData; }
        }
        state DecisionMaking {
          do { GenerateCommand; }
        }
        state AlertHandling {
          do { HandleAlert; }
        }
        transition from entry to Idle;
        transition from Idle to Receiving
          when (securedDataIn.payload is received);
        transition from Receiving to Storing;
        transition from Storing to Analyzing;
        transition from Analyzing to DecisionMaking
          when (actionNeeded == true);
        transition from Analyzing to Idle
          when (actionNeeded == false);
        transition from DecisionMaking to Idle;
        transition from Idle to AlertHandling
          when (alertIn.alert is received);
        transition from AlertHandling to Idle;
      }

      exhibit CloudStateMachine;
    }

    // ----------------------------------------------------------------
    // Actuator Device — abstract base for physical actuators
    // ----------------------------------------------------------------
    part def ActuatorDevice {
      attribute deviceId : String;
      attribute location : String;
      attribute isOnline : Boolean := true;
      attribute firmwareVersion : String := "1.5.3";

      port commandIn : CommandInPort;
      port statusOut : StatusOutPort;
      port registrationOut : RegistrationOutPort;

      action def ExecuteCommand {
        in command : ControlCommand;
        out report : StatusReport;
      }

      state def ActuatorStateMachine {
        entry;
        state Idle;
        state Executing {
          do { ExecuteCommand; }
        }
        state Reporting {
          entry { /* Send status report back to gateway */ }
        }
        transition from entry to Idle;
        transition from Idle to Executing
          when (commandIn.command is received);
        transition from Executing to Reporting;
        transition from Reporting to Idle;
      }

      exhibit ActuatorStateMachine;
    }

    // ----------------------------------------------------------------
    // HVAC Unit — heating, ventilation, and air conditioning
    // ----------------------------------------------------------------
    part def HVACUnit :> ActuatorDevice {
      attribute currentTemperature : TemperatureValue;
      attribute targetTemperature : TemperatureValue := 22;
      attribute coolingEnabled : Boolean := false;
      attribute heatingEnabled : Boolean := false;
      attribute fanSpeed : Integer := 0;
      attribute maxFanSpeed : Integer := 5;

      action def ActivateCooling {
        in targetTemp : TemperatureValue;
      }

      action def ActivateHeating {
        in targetTemp : TemperatureValue;
      }

      action def SetFanSpeedLevel {
        in speed : Integer;
      }

      action def DeactivateSystem {
      }
    }

    // ----------------------------------------------------------------
    // Smart Lighting — dimmable LED lighting system
    // ----------------------------------------------------------------
    part def SmartLighting :> ActuatorDevice {
      attribute brightnessLevel : Integer := 0;
      attribute maxBrightness : Integer := 100;
      attribute isOn : Boolean := false;
      attribute colorTemperature : Integer := 4000;

      action def SetBrightnessLevel {
        in level : Integer;
      }

      action def TurnOnLight {
      }

      action def TurnOffLight {
      }

      action def SetColorTemperature {
        in kelvin : Integer;
      }
    }
  }

  package System {

    part def EnvironmentalMonitoringSystem {
      attribute systemId : String := "IoT-EMS-001";
      attribute deploymentLocation : String;
      attribute systemVersion : String := "1.0.0";
      attribute operationalStatus : String := "active";

      part sensors : IoTSensor[*] {
        attribute minCount : Integer := 1;
        attribute maxCount : Integer := 100;
      }

      part gateway : NetworkGateway;
      part securityModule : SecurityModule;
      part cloud : CloudPlatform;
      part actuators : ActuatorDevice[*] {
        attribute minCount : Integer := 1;
        attribute maxCount : Integer := 100;
      }

      // Sensor → Gateway (sensor readings)
      flow from sensors.dataOut to gateway.sensorDataIn;

      // Sensor → Gateway (device registrations)
      flow from sensors.registrationOut to gateway.registrationIn;

      // Gateway → Security Module (outbound sensor data for encryption)
      flow from gateway.securedDataOut to securityModule.securedDataIn;

      // Security Module → Cloud (encrypted sensor data)
      flow from securityModule.securedDataOut to cloud.securedDataIn;

      // Cloud → Security Module (encrypted control commands)
      flow from cloud.securedCommandOut to securityModule.securedCommandIn;

      // Security Module → Gateway (decrypted control commands)
      flow from securityModule.securedCommandOut to gateway.securedCommandIn;

      // Gateway → Actuators (control commands)
      flow from gateway.commandOut to actuators.commandIn;

      // Actuators → Gateway (status reports)
      flow from actuators.statusOut to gateway.statusIn;

      // Actuators → Gateway (device registrations)
      flow from actuators.registrationOut to gateway.registrationIn;

      // Gateway → Cloud (alert events)
      flow from gateway.alertOut to cloud.alertIn;
    }
  }

  package Requirements {

    requirement def EnvironmentalMonitoringRequirement {
      doc /* The system shall collect environmental data including temperature, humidity, and pressure from multiple physical locations using battery-powered IoT sensors. */;
      subject : IoTSensor;
    }

    requirement def SecureCommunicationRequirement {
      doc /* The system shall encrypt all communications using AES-256 encryption to ensure confidentiality. */;
      subject : SecurityModule;
    }

    requirement def GatewayCapacityRequirement {
      doc /* The network gateway shall manage communications for up to 100 connected devices including both sensors and actuators. */;
      subject : NetworkGateway;
    }

    requirement def SensorPowerRequirement {
      doc /* IoT sensors shall periodically wake from a low-power sleep state to take readings and return to sleep to conserve battery energy. */;
      subject : IoTSensor;
    }

    requirement def AutomatedControlRequirement {
      doc /* The cloud platform shall generate and send specific control commands when analysis determines that an action is needed, such as temperature exceeding a threshold. */;
      subject : CloudPlatform;
    }

    requirement def ActuatorFeedbackRequirement {
      doc /* Actuator devices shall execute received commands and send back status reports to close the automated control loop. */;
      subject : ActuatorDevice;
    }

    requirement def DataIntegrityRequirement {
      doc /* The security module shall authenticate the source of all incoming data to ensure data integrity before processing. */;
      subject : SecurityModule;
    }

    requirement def CloudAnalysisRequirement {
      doc /* The cloud platform shall aggregate, store, and analyze sensor data to identify patterns or anomalies. */;
      subject : CloudPlatform;
    }

    requirement def DataRoutingRequirement {
      doc /* The network gateway shall direct all incoming sensor data towards the cloud and route control commands to the appropriate actuator devices. */;
      subject : NetworkGateway;
    }

    requirement def HVACControlRequirement {
      doc /* The HVAC unit shall be capable of turning on cooling, turning on heating, and adjusting fan speed upon receiving control commands. */;
      subject : HVACUnit;
    }

    requirement def LightingControlRequirement {
      doc /* The smart lighting system shall be capable of being dimmed, brightened, turned on, and turned off upon receiving control commands. */;
      subject : SmartLighting;
    }

    satisfy EnvironmentalMonitoringRequirement by Components::IoTSensor;
    satisfy SecureCommunicationRequirement by Components::SecurityModule;
    satisfy GatewayCapacityRequirement by Components::NetworkGateway;
    satisfy SensorPowerRequirement by Components::IoTSensor;
    satisfy AutomatedControlRequirement by Components::CloudPlatform;
    satisfy ActuatorFeedbackRequirement by Components::ActuatorDevice;
    satisfy DataIntegrityRequirement by Components::SecurityModule;
    satisfy CloudAnalysisRequirement by Components::CloudPlatform;
    satisfy DataRoutingRequirement by Components::NetworkGateway;
    satisfy HVACControlRequirement by Components::HVACUnit;
    satisfy LightingControlRequirement by Components::SmartLighting;
  }
}
