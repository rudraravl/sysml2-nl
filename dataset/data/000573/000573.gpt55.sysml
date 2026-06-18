package CoolingVestHighLevelModel {

  import ScalarValues::*;

  attribute def Temperature :> Real {
    doc /* Thermodynamic temperature expressed in degree Celsius. */
    attribute unit : String = "degC";
  }

  attribute def HeatFlowRate :> Real {
    doc /* Rate of thermal energy transfer. */
    attribute unit : String = "W";
  }

  attribute def ThermalEnergy :> Real {
    doc /* Quantity of stored or transferred thermal energy. */
    attribute unit : String = "J";
  }

  attribute def FlowRate :> Real {
    doc /* Volumetric coolant flow rate. */
    attribute unit : String = "L/min";
  }

  attribute def Pressure :> Real {
    doc /* Gauge pressure. */
    attribute unit : String = "kPa";
  }

  attribute def ElectricVoltage :> Real {
    doc /* Electric potential difference. */
    attribute unit : String = "V";
  }

  attribute def ElectricCurrent :> Real {
    doc /* Electric current. */
    attribute unit : String = "A";
  }

  attribute def ElectricPower :> Real {
    doc /* Electric power. */
    attribute unit : String = "W";
  }

  attribute def StateOfCharge :> Real {
    doc /* Battery available charge as percentage of rated capacity. */
    attribute unit : String = "%";
  }

  attribute def TimeDuration :> Real {
    doc /* Elapsed time. */
    attribute unit : String = "min";
  }

  attribute def Mass :> Real {
    doc /* Mass. */
    attribute unit : String = "kg";
  }

  attribute def Area :> Real {
    doc /* Surface area. */
    attribute unit : String = "m^2";
  }

  attribute def Fraction :> Real {
    doc /* Dimensionless fraction from 0 to 1. */
    attribute unit : String = "1";
  }

  item def Coolant {
    doc /* Water-glycol coolant transported through vest tubing to absorb heat from the wearer. */
    attribute temperature : Temperature;
    attribute flowRate : FlowRate;
    attribute pressure : Pressure;
    attribute heatCapacity : Real = 3.8 {
      attribute unit : String = "kJ/(kg*K)";
    }
  }

  item def Air {
    doc /* Ambient air surrounding the vest. */
    attribute temperature : Temperature;
    attribute relativeHumidity : Fraction;
  }

  item def BodyHeat {
    doc /* Metabolic heat load from the wearer torso entering the vest thermal interface. */
    attribute heatRate : HeatFlowRate;
    attribute sourceTemperature : Temperature;
  }

  item def StoredThermalEnergy {
    doc /* Thermal energy absorbed and temporarily stored by phase change material. */
    attribute energy : ThermalEnergy;
    attribute storageTemperature : Temperature;
  }

  item def ElectricalEnergy {
    doc /* Electrical energy supplied by the removable battery pack. */
    attribute voltage : ElectricVoltage;
    attribute current : ElectricCurrent;
    attribute power : ElectricPower;
  }

  item def TemperatureSample {
    doc /* Measured temperature signal from a thermistor or digital sensor. */
    attribute measuredTemperature : Temperature;
    attribute sampleAge : TimeDuration;
    attribute valid : Boolean;
  }

  item def ControlCommand {
    doc /* Controller command sent to pump and user interface. */
    attribute pumpDutyCycle : Fraction;
    attribute alarmEnabled : Boolean;
    attribute requestedMode : CoolingMode;
  }

  enum def CoolingMode {
    enum idle;
    enum standby;
    enum activeCooling;
    enum economyCooling;
    enum faultSafe;
    enum shutdown;
  }

  enum def FaultCode {
    enum noFault;
    enum lowBattery;
    enum overTemperature;
    enum pumpStall;
    enum reservoirEmpty;
    enum sensorInvalid;
    enum leakDetected;
  }

  port def ThermalPort {
    in item incomingHeat : BodyHeat;
    out item removedHeat : BodyHeat;
    attribute interfaceTemperature : Temperature;
    attribute allowableHeatRate : HeatFlowRate;
  }

  port def CoolantSupplyPort {
    out item coolantOut : Coolant;
    attribute supplyPressure : Pressure;
    attribute supplyTemperature : Temperature;
  }

  port def CoolantReturnPort {
    in item coolantIn : Coolant;
    attribute returnPressure : Pressure;
    attribute returnTemperature : Temperature;
  }

  port def ElectricalPowerPort {
    out item electricalEnergy : ElectricalEnergy;
    attribute voltage : ElectricVoltage;
    attribute currentLimit : ElectricCurrent;
  }

  port def ElectricalLoadPort {
    in item electricalEnergy : ElectricalEnergy;
    attribute requiredVoltage : ElectricVoltage;
    attribute consumedPower : ElectricPower;
  }

  port def TemperatureSensorPort {
    out item sample : TemperatureSample;
    attribute sensorLocation : String;
  }

  port def TemperatureMeasurementPort {
    in item sample : TemperatureSample;
    attribute accepted : Boolean;
  }

  port def ControlOutputPort {
    out item command : ControlCommand;
  }

  port def ControlInputPort {
    in item command : ControlCommand;
  }

  port def AmbientAirPort {
    in item ambientAir : Air;
    out item rejectedHeat : BodyHeat;
    attribute convectionArea : Area;
  }

  part def Wearer {
    doc /* Human user wearing the cooling vest. The wearer produces metabolic heat that is transferred through the torso interface. */
    attribute torsoSkinTemperature : Temperature = 36.8;
    attribute maximumComfortableSkinTemperature : Temperature = 38.0;
    attribute metabolicHeatLoad : HeatFlowRate = 180.0;
    port torsoThermalPort : ThermalPort {
      :>> incomingHeat.heatRate = 180.0;
      :>> incomingHeat.sourceTemperature = 36.8;
      :>> interfaceTemperature = 36.8;
      :>> allowableHeatRate = 250.0;
    }
  }

  part def VestGarmentShell {
    doc /* Wearable textile shell that positions the cooling channels against the torso and distributes contact pressure. */
    attribute garmentMass : Mass = 1.2;
    attribute torsoCoverageArea : Area = 0.55;
    attribute insulationResistance : Real = 0.08 {
      attribute unit : String = "m^2*K/W";
    }
    attribute contactEfficiency : Fraction = 0.82;
    port wearerSide : ThermalPort;
    port coolingSide : ThermalPort;
  }

  part def CoolantChannelNetwork {
    doc /* Flexible tubing network embedded in the vest to circulate coolant across high-heat torso regions. */
    attribute totalTubeLength : Real = 12.0 {
      attribute unit : String = "m";
    }
    attribute internalVolume : Real = 0.42 {
      attribute unit : String = "L";
    }
    attribute nominalFlowRate : FlowRate = 1.4;
    attribute heatPickupCapacity : HeatFlowRate = 220.0;
    port coolantInlet : CoolantReturnPort;
    port coolantOutlet : CoolantSupplyPort;
    port torsoHeatInput : ThermalPort;
  }

  part def PhaseChangeThermalStore {
    doc /* Removable phase-change material pack that absorbs heat from the coolant while melting near the target comfort temperature. */
    attribute pcmMass : Mass = 1.8;
    attribute phaseChangeTemperature : Temperature = 23.0;
    attribute latentHeatCapacity : ThermalEnergy = 360000.0;
    attribute currentStoredHeat : ThermalEnergy = 40000.0;
    attribute meltFraction : Fraction = 0.11;
    port coolantInlet : CoolantReturnPort;
    port coolantOutlet : CoolantSupplyPort;
    port storedEnergyPort : ThermalPort;
  }

  part def HeatExchanger {
    doc /* Air-coupled heat exchanger that rejects a portion of absorbed body heat to the ambient environment. */
    attribute finArea : Area = 0.35;
    attribute nominalHeatRejection : HeatFlowRate = 90.0;
    attribute fanAssisted : Boolean = true;
    port coolantInlet : CoolantReturnPort;
    port coolantOutlet : CoolantSupplyPort;
    port ambientPort : AmbientAirPort;
  }

  part def MicroPump {
    doc /* Electrically powered pump that drives coolant through the closed loop. */
    attribute ratedFlowRate : FlowRate = 1.6;
    attribute minimumStableFlowRate : FlowRate = 0.4;
    attribute ratedPressureRise : Pressure = 45.0;
    attribute ratedPower : ElectricPower = 8.0;
    attribute commandedDutyCycle : Fraction = 0.0;
    attribute measuredFlowRate : FlowRate = 0.0;
    port coolantInlet : CoolantReturnPort;
    port coolantOutlet : CoolantSupplyPort;
    port powerInput : ElectricalLoadPort {
      :>> requiredVoltage = 14.4;
      :>> consumedPower = 8.0;
    }
    port commandInput : ControlInputPort;
  }

  part def BatteryPack {
    doc /* Removable rechargeable battery supplying low-voltage electrical power to pump, controller, sensors, and fan. */
    attribute nominalVoltage : ElectricVoltage = 14.4;
    attribute capacity : Real = 5.0 {
      attribute unit : String = "Ah";
    }
    attribute stateOfCharge : StateOfCharge = 100.0;
    attribute maximumContinuousPower : ElectricPower = 40.0;
    attribute lowChargeThreshold : StateOfCharge = 15.0;
    port powerOutput : ElectricalPowerPort {
      :>> voltage = 14.4;
      :>> currentLimit = 2.8;
    }

    state batteryState {
      entry;
      state charged;
      state normalDischarge;
      state lowCharge;
      state depleted;

      transition initial then charged;
      transition charged then normalDischarge
        accept event PowerDrawn
        if stateOfCharge < 95.0;
      transition normalDischarge then lowCharge
        accept event ChargeUpdated
        if stateOfCharge <= lowChargeThreshold;
      transition lowCharge then depleted
        accept event ChargeUpdated
        if stateOfCharge <= 3.0;
      transition lowCharge then normalDischarge
        accept event BatteryReplaced
        if stateOfCharge > lowChargeThreshold;
    }
  }

  part def TemperatureSensor {
    doc /* Temperature sensor used to measure skin-side or coolant-side temperature for closed-loop cooling control. */
    attribute accuracy : Temperature = 0.5;
    attribute updatePeriod : TimeDuration = 0.05;
    attribute validMeasurement : Boolean = true;
    port measuredThermalPort : ThermalPort;
    port sampleOutput : TemperatureSensorPort;
  }

  part def FlowSensor {
    doc /* Inline flow sensor that detects loss of circulation or reservoir blockage. */
    attribute measuredFlowRate : FlowRate = 0.0;
    attribute minimumExpectedFlowRate : FlowRate = 0.35;
    attribute validMeasurement : Boolean = true;
    port coolantInlet : CoolantReturnPort;
    port coolantOutlet : CoolantSupplyPort;
    port sampleOutput : TemperatureSensorPort;
  }

  part def UserInterface {
    doc /* Simple wearer interface providing mode selection and visible/audible alarm notification. */
    attribute selectedMode : CoolingMode = CoolingMode::standby;
    attribute indicatedFault : FaultCode = FaultCode::noFault;
    attribute alarmActive : Boolean = false;
    port commandOutput : ControlOutputPort;
    port commandInput : ControlInputPort;
  }

  part def CoolingController {
    doc /* Closed-loop controller that regulates pump duty cycle to keep the wearer torso within a safe and comfortable temperature range. */
    attribute targetSkinTemperature : Temperature = 34.0;
    attribute maximumSkinTemperature : Temperature = 38.0;
    attribute minimumCoolantTemperature : Temperature = 10.0;
    attribute currentMode : CoolingMode = CoolingMode::standby;
    attribute activeFault : FaultCode = FaultCode::noFault;
    attribute computedPumpDutyCycle : Fraction = 0.0;
    attribute lastSkinTemperature : Temperature = 36.8;
    attribute lastCoolantReturnTemperature : Temperature = 24.0;
    attribute lastBatteryStateOfCharge : StateOfCharge = 100.0;
    port skinTemperatureInput : TemperatureMeasurementPort;
    port coolantTemperatureInput : TemperatureMeasurementPort;
    port uiCommandInput : ControlInputPort;
    port pumpCommandOutput : ControlOutputPort;
    port uiStatusOutput : ControlOutputPort;
    port powerInput : ElectricalLoadPort {
      :>> requiredVoltage = 14.4;
      :>> consumedPower = 1.5;
    }

    action computeCoolingCommand {
      in skinTemperature : Temperature;
      in coolantReturnTemperature : Temperature;
      in batteryStateOfCharge : StateOfCharge;
      out pumpDutyCycle : Fraction;
      out requestedMode : CoolingMode;
      out fault : FaultCode;

      constraint safeTemperatureLimit {
        skinTemperature <= maximumSkinTemperature
      }

      constraint pumpCommandRange {
        pumpDutyCycle >= 0.0 and pumpDutyCycle <= 1.0
      }
    }

    state controllerOperatingState {
      entry;
      state off;
      state standby;
      state monitoring;
      state activeCooling;
      state economyCooling;
      state faultSafe;
      state shutdown;

      transition initial then off;

      transition off then standby
        accept event PowerButtonPressed
        if lastBatteryStateOfCharge > 15.0;

      transition standby then monitoring
        accept event VestWorn
        if activeFault == FaultCode::noFault;

      transition monitoring then activeCooling
        accept event TemperatureUpdated
        if lastSkinTemperature > targetSkinTemperature + 0.5;

      transition activeCooling then monitoring
        accept event TemperatureUpdated
        if lastSkinTemperature <= targetSkinTemperature;

      transition activeCooling then economyCooling
        accept event ChargeUpdated
        if lastBatteryStateOfCharge <= 25.0 and lastBatteryStateOfCharge > 15.0;

      transition economyCooling then activeCooling
        accept event ChargeUpdated
        if lastBatteryStateOfCharge > 35.0;

      transition monitoring then faultSafe
        accept event FaultDetected
        if activeFault != FaultCode::noFault;

      transition activeCooling then faultSafe
        accept event FaultDetected
        if activeFault != FaultCode::noFault;

      transition economyCooling then faultSafe
        accept event FaultDetected
        if activeFault != FaultCode::noFault;

      transition faultSafe then shutdown
        accept event CriticalFaultConfirmed
        if activeFault == FaultCode::pumpStall or activeFault == FaultCode::leakDetected or activeFault == FaultCode::overTemperature;

      transition standby then shutdown
        accept event PowerButtonHeld;

      transition monitoring then shutdown
        accept event PowerButtonHeld;

      transition activeCooling then shutdown
        accept event PowerButtonHeld;

      transition economyCooling then shutdown
        accept event PowerButtonHeld;
    }
  }

  part def CoolingVestSystem {
    doc /* Primary function: a wearable cooling vest removes heat from the wearer's torso by circulating coolant through garment channels, absorbing and storing or rejecting that heat, and automatically regulating cooling intensity to maintain a safe and comfortable skin temperature. */

    attribute systemMassCharged : Mass = 4.5;
    attribute nominalOperatingDuration : TimeDuration = 180.0;
    attribute maximumContinuousHeatRemoval : HeatFlowRate = 220.0;
    attribute targetSkinTemperature : Temperature = 34.0;
    attribute safeSkinTemperatureLimit : Temperature = 38.0;
    attribute nominalAmbientTemperature : Temperature = 30.0;

    port wearerThermalInterface : ThermalPort;
    port ambientInterface : AmbientAirPort;

    part garmentShell : VestGarmentShell;
    part channels : CoolantChannelNetwork;
    part pump : MicroPump;
    part thermalStore : PhaseChangeThermalStore;
    part heatExchanger : HeatExchanger;
    part battery : BatteryPack;
    part controller : CoolingController;
    part skinSensor : TemperatureSensor {
      :>> sampleOutput.sensorLocation = "inner vest chest panel";
    }
    part coolantSensor : TemperatureSensor {
      :>> sampleOutput.sensorLocation = "coolant return manifold";
    }
    part flowSensor : FlowSensor;
    part ui : UserInterface;

    connect wearerThermalInterface to garmentShell.wearerSide;
    connect garmentShell.coolingSide to channels.torsoHeatInput;

    connect channels.coolantOutlet to thermalStore.coolantInlet;
    connect thermalStore.coolantOutlet to heatExchanger.coolantInlet;
    connect heatExchanger.coolantOutlet to pump.coolantInlet;
    connect pump.coolantOutlet to flowSensor.coolantInlet;
    connect flowSensor.coolantOutlet to channels.coolantInlet;

    connect heatExchanger.ambientPort to ambientInterface;

    connect skinSensor.measuredThermalPort to garmentShell.wearerSide;
    connect coolantSensor.measuredThermalPort to channels.torsoHeatInput;

    connect skinSensor.sampleOutput to controller.skinTemperatureInput;
    connect coolantSensor.sampleOutput to controller.coolantTemperatureInput;

    connect battery.powerOutput to pump.powerInput;
    connect battery.powerOutput to controller.powerInput;

    connect ui.commandOutput to controller.uiCommandInput;
    connect controller.pumpCommandOutput to pump.commandInput;
    connect controller.uiStatusOutput to ui.commandInput;

    constraint closedLoopCoolingPerformance {
      maximumContinuousHeatRemoval >= 180.0
    }

    constraint safeSkinTemperature {
      targetSkinTemperature < safeSkinTemperatureLimit
    }

    constraint portableMass {
      systemMassCharged <= 5.0
    }

    action absorbWearerHeat {
      in metabolicHeat : BodyHeat;
      out heatTransferredToCoolant : BodyHeat;
      constraint heatTransferLimit {
        heatTransferredToCoolant.heatRate <= maximumContinuousHeatRemoval
      }
    }

    action circulateCoolant {
      in pumpDutyCycle : Fraction;
      out deliveredFlowRate : FlowRate;
      constraint commandedRange {
        pumpDutyCycle >= 0.0 and pumpDutyCycle <= 1.0
      }
      constraint minimumActiveFlow {
        if pumpDutyCycle > 0.25 then deliveredFlowRate >= 0.4
      }
    }

    action storeAndRejectHeat {
      in heatFromCoolant : BodyHeat;
      in ambientAir : Air;
      out storedHeat : StoredThermalEnergy;
      out heatRejectedToAir : BodyHeat;
      constraint energyBalance {
        heatFromCoolant.heatRate >= heatRejectedToAir.heatRate
      }
    }

    action regulateCooling {
      in measuredSkinTemperature : Temperature;
      in measuredCoolantTemperature : Temperature;
      in availableCharge : StateOfCharge;
      out command : ControlCommand;
      constraint increaseCoolingWhenWarm {
        if measuredSkinTemperature > targetSkinTemperature + 1.0 then command.pumpDutyCycle >= 0.60
      }
      constraint reduceCoolingWhenCool {
        if measuredSkinTemperature <= targetSkinTemperature then command.pumpDutyCycle <= 0.30
      }
      constraint batteryConservation {
        if availableCharge <= 25.0 then command.requestedMode == CoolingMode::economyCooling
      }
    }
  }

  part wearer : Wearer;

  part vest : CoolingVestSystem {
    :>> nominalAmbientTemperature = 32.0;
    :>> targetSkinTemperature = 34.0;
    :>> safeSkinTemperatureLimit = 38.0;
  }

  connect wearer.torsoThermalPort to vest.wearerThermalInterface;

  requirement def PrimaryCoolingFunctionRequirement {
    doc /* The cooling vest shall provide a wearable means to remove heat from the user's torso at a high level by circulating coolant through the garment and transferring heat to a thermal store and ambient air. */
    subject vestSystem : CoolingVestSystem;

    require constraint primaryHeatRemoval {
      vestSystem.maximumContinuousHeatRemoval >= 180.0
    }

    require constraint highLevelFunctionMaintainsComfort {
      vestSystem.targetSkinTemperature <= 34.0 and vestSystem.safeSkinTemperatureLimit <= 38.0
    }
  }

  requirement def WearabilityRequirement {
    doc /* The complete charged cooling vest shall remain light enough for sustained wearable operation. */
    subject vestSystem : CoolingVestSystem;

    require constraint massLimit {
      vestSystem.systemMassCharged <= 5.0
    }

    require constraint durationLimit {
      vestSystem.nominalOperatingDuration >= 120.0
    }
  }

  requirement def ThermalSafetyRequirement {
    doc /* The controller shall command active cooling or fault response before the wearer torso skin temperature exceeds the safe limit. */
    subject vestSystem : CoolingVestSystem;

    require constraint safeTemperatureLimit {
      vestSystem.safeSkinTemperatureLimit <= 38.0
    }

    require constraint targetBelowLimit {
      vestSystem.targetSkinTemperature < vestSystem.safeSkinTemperatureLimit
    }
  }

  requirement def ClosedLoopControlRequirement {
    doc /* The system shall measure skin-side temperature and use that measurement to regulate pump duty cycle. */
    subject vestSystem : CoolingVestSystem;

    require constraint pumpCommandValidRange {
      vestSystem.controller.computedPumpDutyCycle >= 0.0 and vestSystem.controller.computedPumpDutyCycle <= 1.0
    }

    require constraint activeCoolingThreshold {
      if vestSystem.controller.lastSkinTemperature > vestSystem.controller.targetSkinTemperature + 0.5 then vestSystem.controller.currentMode == CoolingMode::activeCooling
    }
  }

  requirement primaryCoolingFunction : PrimaryCoolingFunctionRequirement {
    subject vestSystem = vest;
  }

  requirement wearability : WearabilityRequirement {
    subject vestSystem = vest;
  }

  requirement thermalSafety : ThermalSafetyRequirement {
    subject vestSystem = vest;
  }

  requirement closedLoopControl : ClosedLoopControlRequirement {
    subject vestSystem = vest;
  }

  satisfy primaryCoolingFunction by vest;
  satisfy wearability by vest;
  satisfy thermalSafety by vest.controller;
  satisfy closedLoopControl by vest.controller;

}
