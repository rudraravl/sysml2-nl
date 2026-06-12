package ProgrammableCommunicatingThermostatSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def TemperatureC :> Real {
    unit = "degC";
  }

  attribute def RelativeHumidityPercent :> Real {
    unit = "%";
  }

  attribute def TimeMinutes :> Real {
    unit = "min";
  }

  attribute def PowerWatt :> Real {
    unit = "W";
  }

  attribute def VoltageDC :> Real {
    unit = "V";
  }

  attribute def DataRateKbps :> Real {
    unit = "kbps";
  }

  item def TemperatureReading {
    attribute value: TemperatureC;
    attribute sampleAge: TimeMinutes;
  }

  item def HumidityReading {
    attribute value: RelativeHumidityPercent;
    attribute sampleAge: TimeMinutes;
  }

  item def SetpointCommand {
    attribute heatingSetpoint: TemperatureC;
    attribute coolingSetpoint: TemperatureC;
    attribute holdDuration: TimeMinutes;
  }

  item def HVACCommand {
    attribute callForHeat: Boolean;
    attribute callForCool: Boolean;
    attribute fanOn: Boolean;
    attribute emergencyShutdown: Boolean;
  }

  item def ScheduleProfile {
    attribute weekdayWakeHeat: TemperatureC;
    attribute weekdayWakeCool: TemperatureC;
    attribute weekdayAwayHeat: TemperatureC;
    attribute weekdayAwayCool: TemperatureC;
    attribute weekdaySleepHeat: TemperatureC;
    attribute weekdaySleepCool: TemperatureC;
    attribute weekendWakeHeat: TemperatureC;
    attribute weekendWakeCool: TemperatureC;
    attribute weekendSleepHeat: TemperatureC;
    attribute weekendSleepCool: TemperatureC;
  }

  item def NetworkMessage {
    attribute sourceAddress: String;
    attribute destinationAddress: String;
    attribute payloadType: String;
    attribute encrypted: Boolean;
  }

  port def TemperatureSensorPort {
    out item reading: TemperatureReading;
  }

  port def HumiditySensorPort {
    out item reading: HumidityReading;
  }

  port def UserInterfacePort {
    in item userSetpoint: SetpointCommand;
    out item displayedTemperature: TemperatureReading;
    out item displayedHumidity: HumidityReading;
  }

  port def HVACControlPort {
    out item command: HVACCommand;
  }

  port def CommunicationPort {
    in item inbound: NetworkMessage;
    out item outbound: NetworkMessage;
  }

  port def PowerPort {
    in attribute supplyVoltage: VoltageDC;
    in attribute availablePower: PowerWatt;
  }

  part def TemperatureSensor {
    port sensedAir: TemperatureSensorPort;
    attribute accuracy: TemperatureC = 0.3;
    attribute samplePeriod: TimeMinutes = 1.0;
  }

  part def HumiditySensor {
    port sensedAir: HumiditySensorPort;
    attribute accuracy: RelativeHumidityPercent = 3.0;
    attribute samplePeriod: TimeMinutes = 2.0;
  }

  part def TouchDisplay {
    port ui: UserInterfacePort;
    attribute diagonalSizeInches: Real = 4.0;
    attribute backlightPower: PowerWatt = 1.5;
  }

  part def WirelessCommunicator {
    port network: CommunicationPort;
    attribute supportedProtocol: String = "WiFi";
    attribute nominalDataRate: DataRateKbps = 54000.0;
    attribute encryptedTransportRequired: Boolean = true;
  }

  part def ScheduleManager {
    attribute activeSchedule: ScheduleProfile;
    attribute vacationModeEnabled: Boolean = false;
    attribute manualHoldActive: Boolean = false;
    attribute manualHoldRemaining: TimeMinutes = 0.0;
  }

  part def HVACController {
    port hvac: HVACControlPort;
    attribute minimumCompressorOffTime: TimeMinutes = 5.0;
    attribute heatDifferential: TemperatureC = 0.5;
    attribute coolDifferential: TemperatureC = 0.5;
    attribute fanCirculationPeriod: TimeMinutes = 20.0;
  }

  part def PowerSupply {
    port powerIn: PowerPort;
    attribute nominalVoltage: VoltageDC = 24.0;
    attribute maximumPowerDraw: PowerWatt = 6.0;
    attribute backupRuntime: TimeMinutes = 30.0;
  }

  action def MeasureIndoorConditions {
    out item temperature: TemperatureReading;
    out item humidity: HumidityReading;
  }

  action def SelectActiveSetpoints {
    in item schedule: ScheduleProfile;
    in item optionalUserOverride: SetpointCommand;
    out item activeSetpoint: SetpointCommand;
  }

  action def RegulateHVAC {
    in item temperature: TemperatureReading;
    in item humidity: HumidityReading;
    in item activeSetpoint: SetpointCommand;
    out item hvacCommand: HVACCommand;
  }

  action def CommunicateStatus {
    in item temperature: TemperatureReading;
    in item humidity: HumidityReading;
    in item hvacCommand: HVACCommand;
    out item networkStatus: NetworkMessage;
  }

  state def ThermostatOperatingState {
    state Off;
    state Booting;
    state Idle;
    state Heating;
    state Cooling;
    state FanOnly;
    state NetworkSync;
    state Fault;

    transition first Booting;
    transition Booting then Idle;
    transition Idle then Heating if roomTemperature < heatingSetpoint;
    transition Idle then Cooling if roomTemperature > coolingSetpoint;
    transition Heating then Idle if roomTemperature >= heatingSetpoint;
    transition Cooling then Idle if roomTemperature <= coolingSetpoint;
    transition Idle then NetworkSync if inboundMessageAvailable;
    transition NetworkSync then Idle;
    transition Idle then FanOnly if circulationFanRequested;
    transition FanOnly then Idle if circulationPeriodComplete;
    transition Booting then Fault if selfTestFailed;
    transition Idle then Fault if sensorFaultDetected;
    transition Heating then Fault if unsafeHVACCondition;
    transition Cooling then Fault if unsafeHVACCondition;
    transition Fault then Off if emergencyShutdownRequested;
  }

  part def ProgrammableCommunicatingThermostat {
    port power: PowerPort;
    port userInterface: UserInterfacePort;
    port hvacControl: HVACControlPort;
    port communication: CommunicationPort;

    part temperatureSensor: TemperatureSensor;
    part humiditySensor: HumiditySensor;
    part display: TouchDisplay;
    part communicator: WirelessCommunicator;
    part scheduler: ScheduleManager;
    part controller: HVACController;
    part supply: PowerSupply;

    attribute roomTemperature: TemperatureC;
    attribute roomHumidity: RelativeHumidityPercent;
    attribute heatingSetpoint: TemperatureC = 20.0;
    attribute coolingSetpoint: TemperatureC = 24.0;
    attribute operatingMode: String = "Auto";
    attribute networkConnected: Boolean = false;
    attribute occupiedMode: Boolean = true;

    connection tempSenseLink connect temperatureSensor.sensedAir to userInterface;
    connection humiditySenseLink connect humiditySensor.sensedAir to userInterface;
    connection displayLink connect display.ui to userInterface;
    connection networkLink connect communicator.network to communication;
    connection hvacCommandLink connect controller.hvac to hvacControl;
    connection powerDistribution connect supply.powerIn to power;

    perform action measure: MeasureIndoorConditions;
    perform action chooseSetpoints: SelectActiveSetpoints;
    perform action regulate: RegulateHVAC;
    perform action report: CommunicateStatus;

    exhibit state behavior: ThermostatOperatingState;
  }

  part def ResidentialHVACPlant {
    port control: HVACControlPort;
    attribute heatCapacity: PowerWatt = 9500.0;
    attribute coolCapacity: PowerWatt = 10500.0;
    attribute fanPower: PowerWatt = 450.0;
  }

  part def HomeAutomationCloud {
    port remoteAccess: CommunicationPort;
    attribute supportsRemoteScheduling: Boolean = true;
    attribute supportsEnergyReports: Boolean = true;
  }

  part thermostatSystem {
    part thermostat: ProgrammableCommunicatingThermostat;
    part hvacPlant: ResidentialHVACPlant;
    part cloudService: HomeAutomationCloud;

    connection thermostatToHVAC connect thermostat.hvacControl to hvacPlant.control;
    connection thermostatToCloud connect thermostat.communication to cloudService.remoteAccess;
  }

  requirement def PrimaryFunctionRequirement {
    subject thermostat: ProgrammableCommunicatingThermostat;
    require constraint {
      thermostat shall maintain indoor air temperature near programmed or remotely commanded heating and cooling setpoints by measuring indoor conditions, selecting active setpoints, commanding HVAC equipment, and communicating status and commands over a network.
    }
  }

  requirement def TemperatureControlAccuracyRequirement {
    subject thermostat: ProgrammableCommunicatingThermostat;
    require constraint {
      abs(thermostat.roomTemperature - thermostat.heatingSetpoint) <= 0.5 or
      abs(thermostat.roomTemperature - thermostat.coolingSetpoint) <= 0.5
    }
  }

  requirement def CommunicationRequirement {
    subject thermostat: ProgrammableCommunicatingThermostat;
    require constraint {
      thermostat.networkConnected == true implies thermostat.communication.outbound.encrypted == true
    }
  }

  requirement def HVACProtectionRequirement {
    subject thermostat: ProgrammableCommunicatingThermostat;
    require constraint {
      thermostat.controller.minimumCompressorOffTime >= 5.0
    }
  }

  requirement def PowerRequirement {
    subject thermostat: ProgrammableCommunicatingThermostat;
    require constraint {
      thermostat.supply.nominalVoltage == 24.0 and
      thermostat.supply.maximumPowerDraw <= 6.0
    }
  }

}