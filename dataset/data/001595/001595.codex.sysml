package TechnologicalParadigmSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value type Power :> ISQ::power {
    :>> unit = SI::watt;
  }

  value type Energy :> ISQ::energy {
    :>> unit = SI::kilowattHour;
  }

  value type Voltage :> ISQ::electricPotential {
    :>> unit = SI::volt;
  }

  value type Current :> ISQ::electricCurrent {
    :>> unit = SI::ampere;
  }

  value type Frequency :> ISQ::frequency {
    :>> unit = SI::hertz;
  }

  value type Time :> ISQ::time {
    :>> unit = SI::second;
  }

  value type Temperature :> ISQ::thermodynamicTemperature {
    :>> unit = SI::degreeCelsius;
  }

  value type Percentage {
    unit = "%";
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute realPower : Power;
    attribute frequency : Frequency;
  }

  item def ControlCommand {
    attribute targetPower : Power;
    attribute targetVoltage : Voltage;
    attribute priority : Integer;
  }

  item def TelemetryFrame {
    attribute measuredPower : Power;
    attribute storedEnergy : Energy;
    attribute stateOfCharge : Percentage;
    attribute internalTemperature : Temperature;
  }

  port def ElectricalPort {
    inout item power : ElectricalPower;
  }

  port def ControlPort {
    in item command : ControlCommand;
    out item telemetry : TelemetryFrame;
  }

  port def DataPort {
    inout item telemetry : TelemetryFrame;
  }

  part def PhotovoltaicArray {
    attribute ratedPower : Power = 120.0 [SI::kilowatt];
    attribute dcVoltage : Voltage = 760.0 [SI::volt];

    port dcOutput : ElectricalPort;
    port monitoring : DataPort;

    action generateElectricalPower {
      in solarIrradiance : Real;
      out generatedPower : Power;

      first start;
      then computeAvailablePower;
      then deliverDcPower;
      then done;

      action computeAvailablePower;
      action deliverDcPower;
    }
  }

  part def BatteryEnergyStorage {
    attribute usableCapacity : Energy = 420.0 [SI::kilowattHour];
    attribute maximumChargePower : Power = 90.0 [SI::kilowatt];
    attribute maximumDischargePower : Power = 110.0 [SI::kilowatt];
    attribute stateOfCharge : Percentage;

    port dcPort : ElectricalPort;
    port control : ControlPort;

    state machine storageStateMachine {
      state Idle;
      state Charging;
      state Discharging;
      state Protected;

      initial then Idle;

      transition Idle_to_Charging
        first Idle
        accept command
        if command.targetPower < 0.0 [SI::kilowatt]
        then Charging;

      transition Idle_to_Discharging
        first Idle
        accept command
        if command.targetPower > 0.0 [SI::kilowatt]
        then Discharging;

      transition Charging_to_Idle
        first Charging
        if stateOfCharge >= 95.0 [%]
        then Idle;

      transition Discharging_to_Protected
        first Discharging
        if stateOfCharge <= 15.0 [%]
        then Protected;

      transition Protected_to_Idle
        first Protected
        if stateOfCharge >= 25.0 [%]
        then Idle;
    }

    action regulateStoredEnergy {
      in requestedPower : Power;
      out deliveredPower : Power;
    }
  }

  part def GridFormingInverter {
    attribute ratedAcPower : Power = 150.0 [SI::kilowatt];
    attribute nominalAcVoltage : Voltage = 480.0 [SI::volt];
    attribute nominalFrequency : Frequency = 60.0 [SI::hertz];

    port dcSide : ElectricalPort;
    port acSide : ElectricalPort;
    port control : ControlPort;

    action convertAndStabilizePower {
      in dcPower : ElectricalPower;
      out acPower : ElectricalPower;

      first measureDcInput;
      then synthesizeAcWaveform;
      then regulateVoltageAndFrequency;
      then publishTelemetry;
      then done;

      action measureDcInput;
      action synthesizeAcWaveform;
      action regulateVoltageAndFrequency;
      action publishTelemetry;
    }
  }

  part def CriticalLoadPanel {
    attribute peakDemand : Power = 85.0 [SI::kilowatt];
    attribute minimumSupportedPower : Power = 25.0 [SI::kilowatt];

    port acInput : ElectricalPort;
    port telemetry : DataPort;
  }

  part def UtilityGridInterface {
    attribute importLimit : Power = 100.0 [SI::kilowatt];
    attribute exportLimit : Power = 60.0 [SI::kilowatt];

    port gridAcPort : ElectricalPort;
    port protectionControl : ControlPort;

    state machine gridConnectionStateMachine {
      state Connected;
      state Islanded;
      state Reconnecting;

      initial then Connected;

      transition Connected_to_Islanded
        first Connected
        accept gridFaultDetected
        then Islanded;

      transition Islanded_to_Reconnecting
        first Islanded
        accept gridStableFor300s
        then Reconnecting;

      transition Reconnecting_to_Connected
        first Reconnecting
        accept synchronizationConfirmed
        then Connected;
    }
  }

  part def EnergyManagementController {
    attribute dispatchInterval : Time = 1.0 [SI::second];
    attribute reserveEnergyTarget : Energy = 90.0 [SI::kilowattHour];
    attribute maximumLoadShedDuration : Time = 10.0 [SI::second];

    port solarData : DataPort;
    port storageControl : ControlPort;
    port inverterControl : ControlPort;
    port gridControl : ControlPort;
    port loadData : DataPort;

    action optimizeEnergyDispatch {
      in photovoltaicTelemetry : TelemetryFrame;
      in storageTelemetry : TelemetryFrame;
      in loadTelemetry : TelemetryFrame;
      out storageCommand : ControlCommand;
      out inverterCommand : ControlCommand;

      first collectTelemetry;
      then estimateGenerationAndDemand;
      then selectOperatingMode;
      then issuePowerCommands;
      then done;

      action collectTelemetry;
      action estimateGenerationAndDemand;
      action selectOperatingMode;
      action issuePowerCommands;
    }

    state machine controlModeStateMachine {
      state GridFollowing;
      state RenewableMaximizing;
      state IslandedSupply;
      state EmergencyLoadPreservation;

      initial then GridFollowing;

      transition GridFollowing_to_RenewableMaximizing
        first GridFollowing
        if photovoltaicTelemetry.measuredPower > loadTelemetry.measuredPower
        then RenewableMaximizing;

      transition GridFollowing_to_IslandedSupply
        first GridFollowing
        accept gridFaultDetected
        then IslandedSupply;

      transition IslandedSupply_to_EmergencyLoadPreservation
        first IslandedSupply
        if storageTelemetry.stateOfCharge < 20.0 [%]
        then EmergencyLoadPreservation;

      transition IslandedSupply_to_GridFollowing
        first IslandedSupply
        accept gridConnectionRestored
        then GridFollowing;
    }
  }

  part def AutonomousRenewableMicrogrid {
    doc /* A cyber-physical technological system whose primary high-level function is to sense energy availability and demand, convert renewable electrical power, store surplus energy, and autonomously dispatch stable AC power to critical loads with or without utility grid support. */

    attribute continuousSupplyRating : Power = 120.0 [SI::kilowatt];
    attribute nominalDistributionVoltage : Voltage = 480.0 [SI::volt];
    attribute nominalDistributionFrequency : Frequency = 60.0 [SI::hertz];
    attribute requiredAutonomyDuration : Time = 14400.0 [SI::second];

    part photovoltaicArray : PhotovoltaicArray;
    part batteryStorage : BatteryEnergyStorage;
    part inverter : GridFormingInverter;
    part loadPanel : CriticalLoadPanel;
    part gridInterface : UtilityGridInterface;
    part controller : EnergyManagementController;

    port renewableDcPort : ElectricalPort;
    port facilityAcPort : ElectricalPort;
    port utilityAcPort : ElectricalPort;
    port supervisoryDataPort : DataPort;

    connect photovoltaicArray.dcOutput to inverter.dcSide;
    connect batteryStorage.dcPort to inverter.dcSide;
    connect inverter.acSide to loadPanel.acInput;
    connect inverter.acSide to gridInterface.gridAcPort;

    connect photovoltaicArray.monitoring to controller.solarData;
    connect batteryStorage.control to controller.storageControl;
    connect inverter.control to controller.inverterControl;
    connect gridInterface.protectionControl to controller.gridControl;
    connect loadPanel.telemetry to controller.loadData;

    connect renewableDcPort to photovoltaicArray.dcOutput;
    connect facilityAcPort to loadPanel.acInput;
    connect utilityAcPort to gridInterface.gridAcPort;
    connect supervisoryDataPort to controller.loadData;

    action provideResilientElectricalService {
      in sunlightAvailable : Boolean;
      in utilityGridAvailable : Boolean;
      out criticalLoadsPowered : Boolean;

      first senseSystemState;
      then forecastNearTermBalance;
      then dispatchGenerationStorageAndGrid;
      then maintainVoltageAndFrequency;
      then reportOperationalStatus;
      then done;

      action senseSystemState;
      action forecastNearTermBalance;
      action dispatchGenerationStorageAndGrid;
      action maintainVoltageAndFrequency;
      action reportOperationalStatus;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject microgrid : AutonomousRenewableMicrogrid;

    doc /* The system shall autonomously provide stable electrical power to critical loads by coordinating renewable generation, battery storage, inverter control, and grid interconnection. */

    require constraint {
      microgrid.continuousSupplyRating >= 100.0 [SI::kilowatt]
    }
  }

  requirement def VoltageFrequencyQualityRequirement {
    subject inverter : GridFormingInverter;

    require constraint {
      inverter.nominalAcVoltage == 480.0 [SI::volt] and
      inverter.nominalFrequency == 60.0 [SI::hertz]
    }
  }

  requirement def StorageAutonomyRequirement {
    subject storage : BatteryEnergyStorage;

    require constraint {
      storage.usableCapacity >= 400.0 [SI::kilowattHour]
    }
  }

  requirement def RenewableCapacityRequirement {
    subject array : PhotovoltaicArray;

    require constraint {
      array.ratedPower >= 100.0 [SI::kilowatt]
    }
  }

  requirement def IslandedOperationRequirement {
    subject microgrid : AutonomousRenewableMicrogrid;

    require constraint {
      microgrid.requiredAutonomyDuration >= 14400.0 [SI::second]
    }
  }

  satisfy PrimaryFunctionRequirement by AutonomousRenewableMicrogrid;
  satisfy VoltageFrequencyQualityRequirement by GridFormingInverter;
  satisfy StorageAutonomyRequirement by BatteryEnergyStorage;
  satisfy RenewableCapacityRequirement by PhotovoltaicArray;
  satisfy IslandedOperationRequirement by AutonomousRenewableMicrogrid;
}