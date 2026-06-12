package BusSCS_Model {

  import ScalarValues::*;
  import SI::*;

  attribute def Voltage : Real {
    unit = "V";
  }

  attribute def Current : Real {
    unit = "A";
  }

  attribute def Power : Real {
    unit = "W";
  }

  attribute def Temperature : Real {
    unit = "degC";
  }

  attribute def Speed : Real {
    unit = "km/h";
  }

  attribute def Pressure : Real {
    unit = "kPa";
  }

  attribute def Percentage : Real {
    unit = "%";
  }

  attribute def TimeDuration : Real {
    unit = "s";
  }

  item def Command {
    attribute commandId : String;
    attribute priority : Integer;
  }

  item def StatusMessage {
    attribute sourceId : String;
    attribute healthState : String;
    attribute timestamp : TimeDuration;
  }

  item def SensorSample {
    attribute name : String;
    attribute value : Real;
    attribute timestamp : TimeDuration;
  }

  item def BrakeCommand specializes Command {
    attribute requestedPressure : Pressure;
  }

  item def PropulsionCommand specializes Command {
    attribute torqueRequest : Real;
    attribute speedLimit : Speed;
  }

  item def DoorCommand specializes Command {
    attribute openRequested : Boolean;
  }

  item def HVACCommand specializes Command {
    attribute targetCabinTemperature : Temperature;
  }

  item def DiagnosticReport {
    attribute faultCode : String;
    attribute severity : Integer;
    attribute description : String;
  }

  port def PowerPort {
    out item electricalPower : Power;
    out item supplyVoltage : Voltage;
    out item supplyCurrent : Current;
  }

  port def ControlCommandPort {
    out item command : Command;
  }

  port def ControlReceivePort {
    in item command : Command;
  }

  port def StatusOutPort {
    out item status : StatusMessage;
    out item diagnostic : DiagnosticReport;
  }

  port def StatusInPort {
    in item status : StatusMessage;
    in item diagnostic : DiagnosticReport;
  }

  port def SensorOutPort {
    out item sample : SensorSample;
  }

  port def SensorInPort {
    in item sample : SensorSample;
  }

  port def DriverInterfacePort {
    in item driverCommand : Command;
    out item driverStatus : StatusMessage;
  }

  action def AcquireVehicleData {
    in item speedSample : SensorSample;
    in item brakeSample : SensorSample;
    in item doorSample : SensorSample;
    in item energySample : SensorSample;
    out item fusedStatus : StatusMessage;
  }

  action def ComputeSupervisoryControl {
    in item vehicleStatus : StatusMessage;
    in item driverCommand : Command;
    out item propulsionCommand : PropulsionCommand;
    out item brakeCommand : BrakeCommand;
    out item doorCommand : DoorCommand;
    out item hvacCommand : HVACCommand;
  }

  action def DistributeCommands {
    in item propulsionCommand : PropulsionCommand;
    in item brakeCommand : BrakeCommand;
    in item doorCommand : DoorCommand;
    in item hvacCommand : HVACCommand;
    out item commandStatus : StatusMessage;
  }

  action def DetectFaults {
    in item vehicleStatus : StatusMessage;
    out item diagnosticReport : DiagnosticReport;
  }

  state def BusSCSOperatingState {
    entry action InitializeSystem;
    exit action StoreOperationalLog;

    state Off;
    state Startup;
    state Standby;
    state NormalOperation;
    state DegradedOperation;
    state EmergencyStop;
    state Shutdown;

    transition first Off;
    transition Off_to_Startup
      first Off
      then Startup;

    transition Startup_to_Standby
      first Startup
      then Standby
      if startChecksPassed;

    transition Standby_to_Normal
      first Standby
      then NormalOperation
      if driverEnableReceived;

    transition Normal_to_Degraded
      first NormalOperation
      then DegradedOperation
      if nonCriticalFaultDetected;

    transition Degraded_to_Normal
      first DegradedOperation
      then NormalOperation
      if faultCleared;

    transition Normal_to_Emergency
      first NormalOperation
      then EmergencyStop
      if emergencyBrakeRequested;

    transition Degraded_to_Emergency
      first DegradedOperation
      then EmergencyStop
      if emergencyBrakeRequested;

    transition Emergency_to_Shutdown
      first EmergencyStop
      then Shutdown
      if vehicleStopped;

    transition Standby_to_Shutdown
      first Standby
      then Shutdown
      if shutdownRequested;
  }

  part def EnergyStorageSubsystem {
    port powerOut : PowerPort;
    port statusOut : StatusOutPort;

    attribute stateOfCharge : Percentage;
    attribute batteryVoltage : Voltage;
    attribute batteryCurrent : Current;
    attribute batteryTemperature : Temperature;
    attribute maximumDischargePower : Power;

    constraint validBatteryState {
      stateOfCharge >= 0.0 and stateOfCharge <= 100.0;
    }

    constraint thermalLimit {
      batteryTemperature <= 60.0;
    }
  }

  part def PropulsionSubsystem {
    port powerIn : PowerPort;
    port commandIn : ControlReceivePort;
    port statusOut : StatusOutPort;

    attribute tractionMotorSpeed : Speed;
    attribute motorTemperature : Temperature;
    attribute deliveredPower : Power;
    attribute availableTorque : Real;

    perform action ExecutePropulsionCommand {
      in item command : PropulsionCommand;
    }
  }

  part def BrakeSubsystem {
    port commandIn : ControlReceivePort;
    port statusOut : StatusOutPort;
    port brakeSensorOut : SensorOutPort;

    attribute brakePressure : Pressure;
    attribute emergencyBrakeAvailable : Boolean;
    attribute stoppingRequestActive : Boolean;

    perform action ApplyBrakePressure {
      in item command : BrakeCommand;
    }
  }

  part def DoorSubsystem {
    port commandIn : ControlReceivePort;
    port statusOut : StatusOutPort;
    port doorSensorOut : SensorOutPort;

    attribute frontDoorOpen : Boolean;
    attribute rearDoorOpen : Boolean;
    attribute obstacleDetected : Boolean;

    perform action ControlDoorState {
      in item command : DoorCommand;
    }
  }

  part def HVACSubsystem {
    port powerIn : PowerPort;
    port commandIn : ControlReceivePort;
    port statusOut : StatusOutPort;

    attribute cabinTemperature : Temperature;
    attribute targetTemperature : Temperature;
    attribute blowerPower : Percentage;

    perform action RegulateCabinTemperature {
      in item command : HVACCommand;
    }
  }

  part def VehicleSensorSuite {
    port speedOut : SensorOutPort;
    port brakeOut : SensorOutPort;
    port doorOut : SensorOutPort;
    port energyOut : SensorOutPort;

    attribute measuredSpeed : Speed;
    attribute measuredBrakePressure : Pressure;
    attribute measuredCabinTemperature : Temperature;
    attribute measuredBatterySoc : Percentage;
  }

  part def DriverConsole {
    port interfacePort : DriverInterfacePort;

    attribute enableSwitch : Boolean;
    attribute emergencyStopButtonPressed : Boolean;
    attribute selectedMode : String;
  }

  part def SupervisoryController {
    port driverPort : DriverInterfacePort;
    port sensorIn : SensorInPort;
    port propulsionCommandOut : ControlCommandPort;
    port brakeCommandOut : ControlCommandPort;
    port doorCommandOut : ControlCommandPort;
    port hvacCommandOut : ControlCommandPort;
    port subsystemStatusIn : StatusInPort;
    port diagnosticOut : StatusOutPort;

    attribute controllerVoltage : Voltage;
    attribute controlCyclePeriod : TimeDuration;
    attribute currentMode : String;
    attribute primaryFunction : String =
      "Coordinate vehicle-level monitoring, command arbitration, safety supervision, and subsystem control for a passenger bus.";

    exhibit state BusSCSOperatingState;

    perform action AcquireVehicleData;
    perform action ComputeSupervisoryControl;
    perform action DistributeCommands;
    perform action DetectFaults;

    constraint controlCycleTiming {
      controlCyclePeriod <= 0.05;
    }
  }

  part def BusSCS {
    part energyStorage : EnergyStorageSubsystem;
    part propulsion : PropulsionSubsystem;
    part brakes : BrakeSubsystem;
    part doors : DoorSubsystem;
    part hvac : HVACSubsystem;
    part sensors : VehicleSensorSuite;
    part driverConsole : DriverConsole;
    part controller : SupervisoryController;

    attribute vehicleSpeed : Speed;
    attribute grossVehicleMass : Real {
      unit = "kg";
    }
    attribute passengerCapacity : Integer;
    attribute nominalBusVoltage : Voltage;
    attribute operationalAvailability : Percentage;

    connect energyStorage.powerOut to propulsion.powerIn;
    connect energyStorage.powerOut to hvac.powerIn;

    connect sensors.speedOut to controller.sensorIn;
    connect sensors.brakeOut to controller.sensorIn;
    connect sensors.doorOut to controller.sensorIn;
    connect sensors.energyOut to controller.sensorIn;

    connect driverConsole.interfacePort to controller.driverPort;

    connect controller.propulsionCommandOut to propulsion.commandIn;
    connect controller.brakeCommandOut to brakes.commandIn;
    connect controller.doorCommandOut to doors.commandIn;
    connect controller.hvacCommandOut to hvac.commandIn;

    connect propulsion.statusOut to controller.subsystemStatusIn;
    connect brakes.statusOut to controller.subsystemStatusIn;
    connect doors.statusOut to controller.subsystemStatusIn;
    connect hvac.statusOut to controller.subsystemStatusIn;
    connect energyStorage.statusOut to controller.subsystemStatusIn;

    constraint busSpeedLimit {
      vehicleSpeed <= 120.0;
    }

    constraint passengerCapacityLimit {
      passengerCapacity >= 1 and passengerCapacity <= 120;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject scs : BusSCS;

    doc /* The Bus SCS shall provide high-level supervisory control for a passenger bus by acquiring vehicle and driver inputs, determining safe operating commands, distributing commands to major subsystems, and reporting system health. */

    require constraint {
      scs.controller.primaryFunction ==
      "Coordinate vehicle-level monitoring, command arbitration, safety supervision, and subsystem control for a passenger bus."
    }
  }

  requirement def ControlCycleRequirement {
    subject controller : SupervisoryController;

    doc /* The supervisory controller shall complete each control cycle within 50 ms during normal operation. */

    require constraint {
      controller.controlCyclePeriod <= 0.05;
    }
  }

  requirement def SafeBrakeRequirement {
    subject brakes : BrakeSubsystem;

    doc /* The brake subsystem shall remain capable of emergency braking whenever the Bus SCS is in NormalOperation or DegradedOperation. */

    require constraint {
      brakes.emergencyBrakeAvailable == true;
    }
  }

  requirement def BatteryOperatingRequirement {
    subject energyStorage : EnergyStorageSubsystem;

    doc /* The energy storage subsystem shall maintain state of charge within valid physical bounds and keep battery temperature at or below 60 degC. */

    require constraint {
      energyStorage.stateOfCharge >= 0.0 and
      energyStorage.stateOfCharge <= 100.0 and
      energyStorage.batteryTemperature <= 60.0;
    }
  }

  requirement def DoorSafetyRequirement {
    subject doors : DoorSubsystem;
    subject bus : BusSCS;

    doc /* Passenger doors shall not be commanded open while the bus speed is greater than 3 km/h. */

    require constraint {
      bus.vehicleSpeed <= 3.0 or
      doors.frontDoorOpen == false and doors.rearDoorOpen == false;
    }
  }

  requirement def DiagnosticReportingRequirement {
    subject controller : SupervisoryController;

    doc /* The Bus SCS shall issue a diagnostic report when a monitored subsystem reports a degraded or failed health state. */

    require constraint {
      controller.currentMode != "NormalOperation" implies controller.diagnosticOut.diagnostic.severity >= 1;
    }
  }

  satisfy PrimaryFunctionRequirement by BusSCS;
  satisfy ControlCycleRequirement by SupervisoryController;
  satisfy SafeBrakeRequirement by BrakeSubsystem;
  satisfy BatteryOperatingRequirement by EnergyStorageSubsystem;
  satisfy DoorSafetyRequirement by DoorSubsystem;
  satisfy DiagnosticReportingRequirement by SupervisoryController;

  part operationalBusSCS : BusSCS {
    attribute vehicleSpeed = 0.0;
    attribute grossVehicleMass = 18000.0;
    attribute passengerCapacity = 78;
    attribute nominalBusVoltage = 650.0;
    attribute operationalAvailability = 99.0;

    part controller {
      attribute controllerVoltage = 24.0;
      attribute controlCyclePeriod = 0.02;
      attribute currentMode = "Standby";
    }

    part energyStorage {
      attribute stateOfCharge = 85.0;
      attribute batteryVoltage = 650.0;
      attribute batteryCurrent = 0.0;
      attribute batteryTemperature = 28.0;
      attribute maximumDischargePower = 250000.0;
    }

    part propulsion {
      attribute tractionMotorSpeed = 0.0;
      attribute motorTemperature = 35.0;
      attribute deliveredPower = 0.0;
      attribute availableTorque = 2200.0;
    }

    part brakes {
      attribute brakePressure = 0.0;
      attribute emergencyBrakeAvailable = true;
      attribute stoppingRequestActive = false;
    }

    part doors {
      attribute frontDoorOpen = false;
      attribute rearDoorOpen = false;
      attribute obstacleDetected = false;
    }

    part hvac {
      attribute cabinTemperature = 22.0;
      attribute targetTemperature = 21.0;
      attribute blowerPower = 40.0;
    }

    part sensors {
      attribute measuredSpeed = 0.0;
      attribute measuredBrakePressure = 0.0;
      attribute measuredCabinTemperature = 22.0;
      attribute measuredBatterySoc = 85.0;
    }

    part driverConsole {
      attribute enableSwitch = false;
      attribute emergencyStopButtonPressed = false;
      attribute selectedMode = "Standby";
    }
  }
}