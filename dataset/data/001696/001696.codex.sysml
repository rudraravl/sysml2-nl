package DaikinBasedClimateControlModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def RelativeHumidity :> Real {
    unit = "%";
  }

  attribute def AirFlowRate :> Real {
    unit = "m^3/min";
  }

  attribute def ElectricPower :> Real {
    unit = "W";
  }

  attribute def RefrigerantPressure :> Real {
    unit = "kPa";
  }

  attribute def FanSpeed :> Real {
    unit = "rpm";
  }

  attribute def SoundLevel :> Real {
    unit = "dBA";
  }

  item def ConditionedAir {
    attribute temperature : Temperature;
    attribute humidity : RelativeHumidity;
    attribute flowRate : AirFlowRate;
  }

  item def ReturnAir {
    attribute temperature : Temperature;
    attribute humidity : RelativeHumidity;
    attribute flowRate : AirFlowRate;
  }

  item def OutdoorAir {
    attribute temperature : Temperature;
    attribute humidity : RelativeHumidity;
  }

  item def Refrigerant {
    attribute pressure : RefrigerantPressure;
    attribute temperature : Temperature;
  }

  item def ElectricalEnergy {
    attribute power : ElectricPower;
  }

  item def UserCommand {
    attribute targetTemperature : Temperature;
    attribute operatingMode : ClimateMode;
    attribute requestedFanLevel : FanLevel;
  }

  enum def ClimateMode {
    enum idle;
    enum cool;
    enum heat;
    enum dry;
    enum fanOnly;
    enum auto;
  }

  enum def FanLevel {
    enum low;
    enum medium;
    enum high;
    enum auto;
  }

  enum def FaultCode {
    enum none;
    enum sensorFault;
    enum compressorFault;
    enum refrigerantFault;
    enum airflowFault;
    enum communicationFault;
  }

  port def AirInPort {
    in item air : ReturnAir;
  }

  port def AirOutPort {
    out item air : ConditionedAir;
  }

  port def OutdoorAirPort {
    in item air : OutdoorAir;
  }

  port def RefrigerantSupplyPort {
    out item refrigerant : Refrigerant;
  }

  port def RefrigerantReturnPort {
    in item refrigerant : Refrigerant;
  }

  port def PowerPort {
    in item energy : ElectricalEnergy;
  }

  port def CommandPort {
    in item command : UserCommand;
  }

  port def StatusPort {
    out attribute currentTemperature : Temperature;
    out attribute currentHumidity : RelativeHumidity;
    out attribute activeMode : ClimateMode;
    out attribute fault : FaultCode;
  }

  part def IndoorUnit {
    port returnAirIn : AirInPort;
    port conditionedAirOut : AirOutPort;
    port refrigerantIn : RefrigerantReturnPort;
    port refrigerantOut : RefrigerantSupplyPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    attribute coilTemperature : Temperature;
    attribute fanSpeed : FanSpeed;
    attribute supplyAirTemperature : Temperature;
    attribute measuredRoomTemperature : Temperature;
    attribute measuredRoomHumidity : RelativeHumidity;

    part evaporatorCoil;
    part indoorFan;
    part temperatureSensor;
    part humiditySensor;
    part airFilter;

    action conditionIndoorAir {
      in item incomingAir : ReturnAir;
      in item refrigerantLoopInput : Refrigerant;
      out item deliveredAir : ConditionedAir;

      first start;
      then measureRoomAir;
      then adjustFanSpeed;
      then exchangeHeatAtCoil;
      then deliverConditionedAir;
      then done;
    }
  }

  part def OutdoorUnit {
    port outdoorAirIn : OutdoorAirPort;
    port refrigerantIn : RefrigerantReturnPort;
    port refrigerantOut : RefrigerantSupplyPort;
    port powerIn : PowerPort;

    attribute compressorPower : ElectricPower;
    attribute condenserFanSpeed : FanSpeed;
    attribute refrigerantDischargePressure : RefrigerantPressure;
    attribute outdoorSoundLevel : SoundLevel;

    part inverterCompressor;
    part outdoorHeatExchanger;
    part expansionValve;
    part condenserFan;

    action manageRefrigerantCycle {
      in item returnedRefrigerant : Refrigerant;
      in item ambientAir : OutdoorAir;
      out item suppliedRefrigerant : Refrigerant;

      first start;
      then compressRefrigerant;
      then rejectOrAbsorbHeat;
      then meterRefrigerantFlow;
      then provideRefrigerantToIndoorUnit;
      then done;
    }
  }

  part def DaikinBasedClimateControlSystem {
    doc /* Primary function: provide controlled indoor comfort by moving heat between an indoor zone and outdoor air using a Daikin-style inverter heat-pump architecture, while regulating temperature, humidity, airflow, energy use, and equipment protection. */

    port powerInput : PowerPort;
    port userCommandInput : CommandPort;
    port roomAirInput : AirInPort;
    port supplyAirOutput : AirOutPort;
    port ambientAirInput : OutdoorAirPort;
    port systemStatusOutput : StatusPort;

    attribute targetTemperature : Temperature = 22.0;
    attribute roomTemperature : Temperature;
    attribute roomHumidity : RelativeHumidity;
    attribute operatingMode : ClimateMode = ClimateMode::auto;
    attribute fanLevel : FanLevel = FanLevel::auto;
    attribute totalPowerDemand : ElectricPower;
    attribute activeFault : FaultCode = FaultCode::none;

    part indoorUnit : IndoorUnit;
    part outdoorUnit : OutdoorUnit;
    part controller;
    part remoteInterface;
    part protectionManager;
    part diagnostics;

    connect powerInput to outdoorUnit.powerIn;
    connect userCommandInput to indoorUnit.commandIn;
    connect roomAirInput to indoorUnit.returnAirIn;
    connect indoorUnit.conditionedAirOut to supplyAirOutput;
    connect ambientAirInput to outdoorUnit.outdoorAirIn;
    connect indoorUnit.statusOut to systemStatusOutput;

    connect outdoorUnit.refrigerantOut to indoorUnit.refrigerantIn;
    connect indoorUnit.refrigerantOut to outdoorUnit.refrigerantIn;

    action regulateIndoorClimate {
      in item command : UserCommand;
      in item returnAir : ReturnAir;
      in item outdoorAir : OutdoorAir;
      out item conditionedAir : ConditionedAir;

      first receiveCommand;
      then evaluateComfortError;
      then selectOperatingMode;
      then computeCompressorSpeed;
      then computeIndoorFanSpeed;
      then operateRefrigerantCycle;
      then conditionAir;
      then publishStatus;
      then done;
    }

    state def OperatingStates {
      entry action initializeSystem;

      state Off;
      state Standby;
      state Cooling;
      state Heating;
      state Drying;
      state FanOnly;
      state Faulted;

      transition first Off;

      transition Off_to_Standby
        first Off
        then Standby
        accept UserCommand
        if command.operatingMode != ClimateMode::idle;

      transition Standby_to_Cooling
        first Standby
        then Cooling
        if operatingMode == ClimateMode::cool or
           (operatingMode == ClimateMode::auto and roomTemperature > targetTemperature + 0.5);

      transition Standby_to_Heating
        first Standby
        then Heating
        if operatingMode == ClimateMode::heat or
           (operatingMode == ClimateMode::auto and roomTemperature < targetTemperature - 0.5);

      transition Standby_to_Drying
        first Standby
        then Drying
        if operatingMode == ClimateMode::dry and roomHumidity > 55.0;

      transition Standby_to_FanOnly
        first Standby
        then FanOnly
        if operatingMode == ClimateMode::fanOnly;

      transition Cooling_to_Standby
        first Cooling
        then Standby
        if roomTemperature <= targetTemperature;

      transition Heating_to_Standby
        first Heating
        then Standby
        if roomTemperature >= targetTemperature;

      transition Drying_to_Standby
        first Drying
        then Standby
        if roomHumidity <= 50.0;

      transition Any_to_Faulted
        first Off, Standby, Cooling, Heating, Drying, FanOnly
        then Faulted
        if activeFault != FaultCode::none;

      transition Faulted_to_Standby
        first Faulted
        then Standby
        accept UserCommand
        if activeFault == FaultCode::none;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall regulate an occupied indoor space by delivering conditioned air using a Daikin-style inverter heat-pump configuration. */
    subject climateSystem : DaikinBasedClimateControlSystem;

    require constraint {
      climateSystem.supplyAirOutput.air.flowRate > 0.0
    }
  }

  requirement def TemperatureControlRequirement {
    doc /* The system shall maintain indoor temperature near the commanded setpoint during normal operation. */
    subject climateSystem : DaikinBasedClimateControlSystem;

    require constraint {
      abs(climateSystem.roomTemperature - climateSystem.targetTemperature) <= 1.0
    }
  }

  requirement def HumidityControlRequirement {
    doc /* In dry mode, the system shall reduce room humidity while continuing to provide airflow. */
    subject climateSystem : DaikinBasedClimateControlSystem;

    require constraint {
      climateSystem.operatingMode == ClimateMode::dry implies
      climateSystem.roomHumidity <= 60.0
    }
  }

  requirement def EnergyEfficiencyRequirement {
    doc /* The inverter compressor shall modulate power demand instead of operating only at fixed maximum output. */
    subject climateSystem : DaikinBasedClimateControlSystem;

    require constraint {
      climateSystem.totalPowerDemand >= 0.0 and
      climateSystem.totalPowerDemand <= 3500.0
    }
  }

  requirement def ProtectionRequirement {
    doc /* The system shall enter a faulted state when detected faults could damage equipment or reduce safe operation. */
    subject climateSystem : DaikinBasedClimateControlSystem;

    require constraint {
      climateSystem.activeFault != FaultCode::none implies
      climateSystem.operatingMode == ClimateMode::idle
    }
  }

  satisfy PrimaryFunctionRequirement by DaikinBasedClimateControlSystem;
  satisfy TemperatureControlRequirement by DaikinBasedClimateControlSystem;
  satisfy HumidityControlRequirement by DaikinBasedClimateControlSystem;
  satisfy EnergyEfficiencyRequirement by DaikinBasedClimateControlSystem;
  satisfy ProtectionRequirement by DaikinBasedClimateControlSystem;
}