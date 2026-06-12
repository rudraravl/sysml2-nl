package HomeAutomation {

  item def CelsiusTemperature {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  item def Percent {
    attribute value : Real;
    attribute unit : String = "%";
  }

  item def WattPower {
    attribute value : Real;
    attribute unit : String = "W";
  }

  item def KilowattHourEnergy {
    attribute value : Real;
    attribute unit : String = "kWh";
  }

  item def LuxIlluminance {
    attribute value : Real;
    attribute unit : String = "lx";
  }

  item def PpmConcentration {
    attribute value : Real;
    attribute unit : String = "ppm";
  }

  item def BooleanStatus {
    attribute value : Boolean;
  }

  item def AutomationCommand {
    attribute targetId : String;
    attribute commandKind : String;
    attribute priority : Integer;
    attribute issuedAt : String;
  }

  item def SensorReading {
    attribute sourceId : String;
    attribute readingKind : String;
    attribute numericValue : Real;
    attribute unit : String;
    attribute measuredAt : String;
  }

  item def SecurityEvent {
    attribute sourceId : String;
    attribute eventKind : String;
    attribute severity : Integer;
    attribute detectedAt : String;
  }

  port def SensorDataPort {
    out item reading : SensorReading;
  }

  port def CommandPort {
    in item command : AutomationCommand;
  }

  port def EventPort {
    out item event : SecurityEvent;
  }

  port def NetworkPort {
    in item inboundCommand : AutomationCommand;
    out item outboundReading : SensorReading;
    out item outboundEvent : SecurityEvent;
  }

  port def PowerPort {
    in item suppliedPower : WattPower;
  }

  part def TemperatureSensor {
    attribute sensorId : String;
    attribute measuredTemperature : CelsiusTemperature;
    attribute samplePeriod_s : Real;
    port dataOut : SensorDataPort;
    port powerIn : PowerPort;

    action senseTemperature {
      out item temperatureReading : SensorReading;
    }
  }

  part def OccupancySensor {
    attribute sensorId : String;
    attribute occupied : BooleanStatus;
    attribute detectionConfidence : Percent;
    port dataOut : SensorDataPort;
    port powerIn : PowerPort;

    action detectOccupancy {
      out item occupancyReading : SensorReading;
    }
  }

  part def LightSensor {
    attribute sensorId : String;
    attribute illuminance : LuxIlluminance;
    port dataOut : SensorDataPort;
    port powerIn : PowerPort;

    action measureIlluminance {
      out item lightReading : SensorReading;
    }
  }

  part def AirQualitySensor {
    attribute sensorId : String;
    attribute carbonDioxide : PpmConcentration;
    attribute humidity : Percent;
    port dataOut : SensorDataPort;
    port powerIn : PowerPort;

    action measureAirQuality {
      out item airReading : SensorReading;
    }
  }

  part def DoorWindowSensor {
    attribute sensorId : String;
    attribute open : BooleanStatus;
    port dataOut : SensorDataPort;
    port eventOut : EventPort;
    port powerIn : PowerPort;

    action detectOpening {
      out item openingReading : SensorReading;
      out item intrusionEvent : SecurityEvent;
    }
  }

  part def SmartThermostat {
    attribute deviceId : String;
    attribute targetTemperature : CelsiusTemperature;
    attribute currentTemperature : CelsiusTemperature;
    attribute mode : String;
    port commandIn : CommandPort;
    port dataOut : SensorDataPort;
    port powerIn : PowerPort;

    action regulateTemperature {
      in item command : AutomationCommand;
      out item hvacCommand : AutomationCommand;
    }
  }

  part def SmartLight {
    attribute deviceId : String;
    attribute brightness : Percent;
    attribute colorTemperature_K : Real;
    attribute energized : BooleanStatus;
    port commandIn : CommandPort;
    port powerIn : PowerPort;

    action setLighting {
      in item command : AutomationCommand;
    }
  }

  part def SmartLock {
    attribute deviceId : String;
    attribute locked : BooleanStatus;
    port commandIn : CommandPort;
    port eventOut : EventPort;
    port powerIn : PowerPort;

    action lockOrUnlock {
      in item command : AutomationCommand;
      out item lockEvent : SecurityEvent;
    }
  }

  part def MotorizedBlind {
    attribute deviceId : String;
    attribute openPercent : Percent;
    port commandIn : CommandPort;
    port powerIn : PowerPort;

    action positionBlind {
      in item command : AutomationCommand;
    }
  }

  part def AlarmSiren {
    attribute deviceId : String;
    attribute active : BooleanStatus;
    attribute soundLevel_dBA : Real;
    port commandIn : CommandPort;
    port powerIn : PowerPort;

    action activateAlarm {
      in item command : AutomationCommand;
    }
  }

  part def EnergyMeter {
    attribute deviceId : String;
    attribute instantaneousPower : WattPower;
    attribute dailyEnergy : KilowattHourEnergy;
    port dataOut : SensorDataPort;
    port powerIn : PowerPort;

    action measureEnergy {
      out item energyReading : SensorReading;
    }
  }

  part def HomeGateway {
    attribute gatewayId : String;
    attribute online : BooleanStatus;
    attribute firmwareVersion : String;
    port sensorIn : SensorDataPort;
    port eventIn : EventPort;
    port deviceCommandOut : CommandPort;
    port cloudNetwork : NetworkPort;
    port powerIn : PowerPort;

    action routeMessages {
      in item reading : SensorReading;
      in item event : SecurityEvent;
      out item command : AutomationCommand;
    }
  }

  part def AutomationController {
    attribute controllerId : String;
    attribute activeScenario : String;
    attribute occupiedMode : BooleanStatus;
    attribute nightMode : BooleanStatus;
    attribute targetHeatingTemperature : CelsiusTemperature;
    attribute targetCoolingTemperature : CelsiusTemperature;
    attribute maximumLightingPower : WattPower;
    attribute dailyEnergyBudget : KilowattHourEnergy;

    port sensorIn : SensorDataPort;
    port eventIn : EventPort;
    port commandOut : CommandPort;
    port network : NetworkPort;
    port powerIn : PowerPort;

    action monitorHome {
      in item reading : SensorReading;
      out item command : AutomationCommand;
    }

    action optimizeEnergyUse {
      in item energyReading : SensorReading;
      out item thermostatCommand : AutomationCommand;
      out item lightingCommand : AutomationCommand;
      out item blindCommand : AutomationCommand;
    }

    action protectHome {
      in item securityEvent : SecurityEvent;
      out item lockCommand : AutomationCommand;
      out item alarmCommand : AutomationCommand;
    }

    state automationState {
      state initializing;
      state normalMonitoring;
      state energySaving;
      state awaySecured;
      state alarmActive;
      state manualOverride;

      transition first initializing then normalMonitoring;
      transition normalMonitoring then energySaving if dailyEnergyBudget.value < 8.0;
      transition normalMonitoring then awaySecured if occupiedMode.value == false;
      transition awaySecured then alarmActive if true;
      transition normalMonitoring then manualOverride if true;
      transition manualOverride then normalMonitoring if true;
      transition alarmActive then awaySecured if true;
    }
  }

  part def MobileApplication {
    attribute userAccountId : String;
    attribute authenticated : BooleanStatus;
    port network : NetworkPort;

    action requestAutomationChange {
      out item userCommand : AutomationCommand;
    }

    action displayHomeStatus {
      in item reading : SensorReading;
      in item event : SecurityEvent;
    }
  }

  part def HomeAutomationSystem {
    attribute systemId : String;
    attribute primaryFunction : String = "Automatically monitor and control home comfort, lighting, energy use, and security according to occupant presence, environmental conditions, schedules, and user commands.";
    attribute totalInstalledPower : WattPower;
    attribute monthlyEnergyConsumption : KilowattHourEnergy;
    attribute availabilityTarget : Percent;

    part controller : AutomationController;
    part gateway : HomeGateway;
    part mobileApp : MobileApplication;

    part livingRoomTemperatureSensor : TemperatureSensor;
    part bedroomTemperatureSensor : TemperatureSensor;
    part hallwayOccupancySensor : OccupancySensor;
    part livingRoomOccupancySensor : OccupancySensor;
    part outdoorLightSensor : LightSensor;
    part indoorAirQualitySensor : AirQualitySensor;
    part frontDoorSensor : DoorWindowSensor;
    part rearWindowSensor : DoorWindowSensor;

    part thermostat : SmartThermostat;
    part livingRoomLight : SmartLight;
    part hallwayLight : SmartLight;
    part frontDoorLock : SmartLock;
    part rearDoorLock : SmartLock;
    part bedroomBlind : MotorizedBlind;
    part alarmSiren : AlarmSiren;
    part wholeHomeEnergyMeter : EnergyMeter;

    connect livingRoomTemperatureSensor.dataOut to controller.sensorIn;
    connect bedroomTemperatureSensor.dataOut to controller.sensorIn;
    connect hallwayOccupancySensor.dataOut to controller.sensorIn;
    connect livingRoomOccupancySensor.dataOut to controller.sensorIn;
    connect outdoorLightSensor.dataOut to controller.sensorIn;
    connect indoorAirQualitySensor.dataOut to controller.sensorIn;
    connect frontDoorSensor.dataOut to controller.sensorIn;
    connect rearWindowSensor.dataOut to controller.sensorIn;
    connect wholeHomeEnergyMeter.dataOut to controller.sensorIn;

    connect frontDoorSensor.eventOut to controller.eventIn;
    connect rearWindowSensor.eventOut to controller.eventIn;
    connect frontDoorLock.eventOut to controller.eventIn;

    connect controller.commandOut to thermostat.commandIn;
    connect controller.commandOut to livingRoomLight.commandIn;
    connect controller.commandOut to hallwayLight.commandIn;
    connect controller.commandOut to frontDoorLock.commandIn;
    connect controller.commandOut to rearDoorLock.commandIn;
    connect controller.commandOut to bedroomBlind.commandIn;
    connect controller.commandOut to alarmSiren.commandIn;

    connect controller.network to gateway.cloudNetwork;
    connect gateway.cloudNetwork to mobileApp.network;

    action performPrimaryAutomationFunction {
      first collectEnvironmentalAndSecurityData;
      then determineComfortEnergyAndSecurityIntent;
      then issueDeviceCommands;
      then reportStatusToUser;
    }

    action collectEnvironmentalAndSecurityData {
      out item readings : SensorReading;
      out item events : SecurityEvent;
    }

    action determineComfortEnergyAndSecurityIntent {
      in item readings : SensorReading;
      in item events : SecurityEvent;
      out item commands : AutomationCommand;
    }

    action issueDeviceCommands {
      in item commands : AutomationCommand;
    }

    action reportStatusToUser {
      in item readings : SensorReading;
      in item events : SecurityEvent;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : HomeAutomationSystem;
    require constraint {
      system.primaryFunction == "Automatically monitor and control home comfort, lighting, energy use, and security according to occupant presence, environmental conditions, schedules, and user commands."
    }
  }

  requirement def ComfortControlRequirement {
    subject system : HomeAutomationSystem;
    require constraint {
      system.controller.targetHeatingTemperature.value >= 16.0 and
      system.controller.targetHeatingTemperature.value <= 24.0 and
      system.controller.targetCoolingTemperature.value >= 20.0 and
      system.controller.targetCoolingTemperature.value <= 28.0
    }
  }

  requirement def LightingAutomationRequirement {
    subject system : HomeAutomationSystem;
    require constraint {
      system.controller.maximumLightingPower.value <= 500.0
    }
  }

  requirement def EnergyManagementRequirement {
    subject system : HomeAutomationSystem;
    require constraint {
      system.controller.dailyEnergyBudget.value <= 30.0
    }
  }

  requirement def SecurityResponseRequirement {
    subject system : HomeAutomationSystem;
    require constraint {
      system.alarmSiren.soundLevel_dBA >= 85.0
    }
  }

  requirement def AvailabilityRequirement {
    subject system : HomeAutomationSystem;
    require constraint {
      system.availabilityTarget.value >= 99.0
    }
  }

  part homeAutomationSystem : HomeAutomationSystem {
    attribute systemId = "HOME-AUTO-001";
    attribute totalInstalledPower : WattPower {
      attribute value = 1800.0;
      attribute unit = "W";
    }
    attribute monthlyEnergyConsumption : KilowattHourEnergy {
      attribute value = 420.0;
      attribute unit = "kWh";
    }
    attribute availabilityTarget : Percent {
      attribute value = 99.5;
      attribute unit = "%";
    }
  }

}