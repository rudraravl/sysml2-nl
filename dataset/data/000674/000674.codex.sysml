package MDDI_HighLevelSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Percentage :> Real {
    range = "0..100";
    unit = "%";
  }

  attribute def DataRate :> Real {
    unit = "Mb/s";
  }

  attribute def Latency :> Real {
    unit = "ms";
  }

  attribute def TemperatureCelsius :> Real {
    unit = "degC";
  }

  attribute def PressureKPa :> Real {
    unit = "kPa";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def TimeSeconds :> Real {
    unit = "s";
  }

  item def DiagnosticCommand {
    attribute commandId : String;
    attribute targetDeviceId : String;
    attribute commandType : String;
    attribute issuedAt : TimeSeconds;
  }

  item def DeviceTelemetry {
    attribute deviceId : String;
    attribute temperature : TemperatureCelsius;
    attribute pressure : PressureKPa;
    attribute supplyVoltage : Voltage;
    attribute healthScore : Percentage;
    attribute sampledAt : TimeSeconds;
  }

  item def DiagnosticResult {
    attribute deviceId : String;
    attribute testId : String;
    attribute passed : Boolean;
    attribute faultCode : String;
    attribute confidence : Percentage;
    attribute completedAt : TimeSeconds;
  }

  item def IntegratedDataRecord {
    attribute recordId : String;
    attribute deviceId : String;
    attribute sourceTimestamp : TimeSeconds;
    attribute qualityScore : Percentage;
    attribute normalizedPayload : String;
  }

  item def MaintenanceAlert {
    attribute alertId : String;
    attribute affectedDeviceId : String;
    attribute severity : String;
    attribute recommendedAction : String;
    attribute generatedAt : TimeSeconds;
  }

  port def CommandPort {
    out item command : DiagnosticCommand;
  }

  port def TelemetryPort {
    in item telemetry : DeviceTelemetry;
  }

  port def ResultPort {
    in item result : DiagnosticResult;
  }

  port def IntegratedDataPort {
    out item record : IntegratedDataRecord;
  }

  port def AlertPort {
    out item alert : MaintenanceAlert;
  }

  port def NetworkPort {
    in item inboundCommand : DiagnosticCommand;
    in item inboundTelemetry : DeviceTelemetry;
    out item outboundResult : DiagnosticResult;
    out item outboundRecord : IntegratedDataRecord;
    out item outboundAlert : MaintenanceAlert;
  }

  part def MedicalDevice {
    attribute deviceId : String;
    attribute operatingTemperature : TemperatureCelsius;
    attribute chamberPressure : PressureKPa;
    attribute supplyVoltage : Voltage;
    attribute availability : Percentage;

    port commands : CommandPort;
    port telemetry : TelemetryPort;
    port results : ResultPort;
  }

  part def DiagnosticInstrument {
    attribute instrumentId : String;
    attribute maximumSampleRate : DataRate = 50.0;
    attribute diagnosticLatency : Latency = 250.0;
    attribute calibrationValid : Boolean;

    port commands : CommandPort;
    port telemetry : TelemetryPort;
    port results : ResultPort;

    action performDiagnostic {
      in item command : DiagnosticCommand;
      in item telemetry : DeviceTelemetry;
      out item result : DiagnosticResult;
    }
  }

  part def DataIntegrationController {
    attribute controllerId : String;
    attribute supportedDeviceCount : Integer = 64;
    attribute integrationLatency : Latency = 500.0;
    attribute minimumQualityScore : Percentage = 95.0;

    port telemetryIn : TelemetryPort;
    port resultIn : ResultPort;
    port integratedOut : IntegratedDataPort;
    port alertOut : AlertPort;

    action normalizeAndFuseData {
      in item telemetry : DeviceTelemetry;
      in item diagnostic : DiagnosticResult;
      out item record : IntegratedDataRecord;
    }

    action evaluateHealth {
      in item record : IntegratedDataRecord;
      out item alert : MaintenanceAlert;
    }
  }

  part def OperatorWorkstation {
    attribute workstationId : String;
    attribute activeSession : Boolean;
    attribute displayRefreshRate : DataRate = 1.0;

    port commands : CommandPort;
    port integratedData : IntegratedDataPort;
    port alerts : AlertPort;

    action reviewSystemStatus {
      in item record : IntegratedDataRecord;
      in item alert : MaintenanceAlert;
    }
  }

  part def SecureNetworkGateway {
    attribute gatewayId : String;
    attribute encrypted : Boolean = true;
    attribute maximumThroughput : DataRate = 1000.0;
    attribute roundTripLatency : Latency = 50.0;

    port fieldNetwork : NetworkPort;
    port enterpriseNetwork : NetworkPort;
  }

  part def MDDISystem {
    doc
    /*
     The primary function of the MD&DI system is to acquire operational data from medical devices,
     execute diagnostic tests, integrate telemetry and diagnostic results into trusted records,
     and generate actionable maintenance alerts that support safe and continuous device operation.
    */

    attribute systemId : String = "MDDI-Integrated-Diagnostic-System";
    attribute targetAvailability : Percentage = 99.5;
    attribute maximumEndToEndLatency : Latency = 2000.0;

    part monitoredDevice : MedicalDevice {
      attribute deviceId = "MD-ICU-VENT-042";
      attribute operatingTemperature = 36.8;
      attribute chamberPressure = 101.3;
      attribute supplyVoltage = 24.0;
      attribute availability = 99.7;
    }

    part diagnosticInstrument : DiagnosticInstrument {
      attribute instrumentId = "DI-AUTO-001";
      attribute calibrationValid = true;
    }

    part integrationController : DataIntegrationController {
      attribute controllerId = "DIC-CORE-001";
    }

    part workstation : OperatorWorkstation {
      attribute workstationId = "OW-CLINICAL-001";
      attribute activeSession = true;
    }

    part gateway : SecureNetworkGateway {
      attribute gatewayId = "SNG-HOSPITAL-001";
    }

    connect workstation.commands to gateway.enterpriseNetwork;
    connect gateway.fieldNetwork to diagnosticInstrument.commands;
    connect monitoredDevice.telemetry to diagnosticInstrument.telemetry;
    connect diagnosticInstrument.results to integrationController.resultIn;
    connect monitoredDevice.telemetry to integrationController.telemetryIn;
    connect integrationController.integratedOut to gateway.fieldNetwork;
    connect integrationController.alertOut to gateway.fieldNetwork;
    connect gateway.enterpriseNetwork to workstation.integratedData;
    connect gateway.enterpriseNetwork to workstation.alerts;

    action provideIntegratedDiagnostics {
      in item command : DiagnosticCommand;
      in item telemetry : DeviceTelemetry;
      out item result : DiagnosticResult;
      out item record : IntegratedDataRecord;
      out item alert : MaintenanceAlert;

      first start;
      then acquireDeviceTelemetry;
      then executeDiagnosticTest;
      then integrateDiagnosticData;
      then assessDeviceHealth;
      then publishClinicalMaintenanceInformation;
      then done;

      action acquireDeviceTelemetry {
        out item telemetry : DeviceTelemetry;
      }

      action executeDiagnosticTest {
        in item command : DiagnosticCommand;
        in item telemetry : DeviceTelemetry;
        out item result : DiagnosticResult;
      }

      action integrateDiagnosticData {
        in item telemetry : DeviceTelemetry;
        in item result : DiagnosticResult;
        out item record : IntegratedDataRecord;
      }

      action assessDeviceHealth {
        in item record : IntegratedDataRecord;
        out item alert : MaintenanceAlert;
      }

      action publishClinicalMaintenanceInformation {
        in item record : IntegratedDataRecord;
        in item alert : MaintenanceAlert;
      }
    }

    state operationalStates {
      entry action initializeSystem;

      state Initializing;
      state Ready;
      state AcquiringTelemetry;
      state RunningDiagnostics;
      state IntegratingData;
      state PublishingResults;
      state Degraded;
      state MaintenanceRequired;
      state Shutdown;

      transition first Initializing;
      transition Initializing then Ready
        accept after 5.0;
      transition Ready then AcquiringTelemetry
        accept DiagnosticCommand;
      transition AcquiringTelemetry then RunningDiagnostics
        accept DeviceTelemetry;
      transition RunningDiagnostics then IntegratingData
        accept DiagnosticResult;
      transition IntegratingData then PublishingResults
        accept IntegratedDataRecord;
      transition PublishingResults then Ready
        accept after 1.0;
      transition Ready then Degraded
        if monitoredDevice.availability < 95.0;
      transition Degraded then MaintenanceRequired
        if monitoredDevice.availability < 90.0;
      transition MaintenanceRequired then Ready
        accept DiagnosticCommand;
      transition Ready then Shutdown
        accept after 86400.0;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     The MD&DI system shall acquire medical device telemetry, perform automated diagnostics,
     integrate validated results, and publish maintenance-relevant information to the operator.
    */

    subject mddi : MDDISystem;

    require constraint {
      mddi.maximumEndToEndLatency <= 2000.0
    }
  }

  requirement def TelemetryQualityRequirement {
    doc
    /*
     Integrated records shall have a quality score of at least 95 percent before they are published.
    */

    subject controller : DataIntegrationController;

    require constraint {
      controller.minimumQualityScore >= 95.0
    }
  }

  requirement def SecureExchangeRequirement {
    doc
    /*
     All operational commands, telemetry, diagnostic results, integrated records, and alerts shall pass through an encrypted network gateway.
    */

    subject gateway : SecureNetworkGateway;

    require constraint {
      gateway.encrypted == true
    }
  }

  requirement def AvailabilityRequirement {
    doc
    /*
     The MD&DI system shall maintain a target operational availability of at least 99.5 percent.
    */

    subject mddi : MDDISystem;

    require constraint {
      mddi.targetAvailability >= 99.5
    }
  }

  requirement def DiagnosticLatencyRequirement {
    doc
    /*
     The diagnostic instrument shall complete an automated diagnostic evaluation within 250 milliseconds after valid telemetry is received.
    */

    subject instrument : DiagnosticInstrument;

    require constraint {
      instrument.diagnosticLatency <= 250.0
    }
  }

  satisfy PrimaryFunctionRequirement by MDDISystem;
  satisfy TelemetryQualityRequirement by DataIntegrationController;
  satisfy SecureExchangeRequirement by SecureNetworkGateway;
  satisfy AvailabilityRequirement by MDDISystem;
  satisfy DiagnosticLatencyRequirement by DiagnosticInstrument;
}