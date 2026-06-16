package WaterAerationSystemModel {
  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  item def RawWater {
    attribute volume : Real;
    attribute dissolvedOxygen_mgPerL : Real;
    attribute temperature_degC : Real;
  }

  item def AeratedWater :> RawWater {
    attribute targetDissolvedOxygen_mgPerL : Real = 6.0;
  }

  item def Air {
    attribute oxygenFraction : Real = 0.2095;
    attribute pressure_kPa : Real;
    attribute flowRate_m3PerHour : Real;
  }

  item def ElectricalPower {
    attribute voltage_V : Real;
    attribute current_A : Real;
    attribute frequency_Hz : Real;
  }

  port def WaterInletPort {
    in item water : RawWater;
  }

  port def WaterOutletPort {
    out item water : AeratedWater;
  }

  port def AirPort {
    inout item air : Air;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def SignalPort {
    inout item signal : Real;
  }

  part def AirBlower {
    port powerIn : PowerPort;
    port airOut : AirPort;

    attribute ratedAirFlow_m3PerHour : Real = 180.0;
    attribute dischargePressure_kPa : Real = 65.0;
    attribute ratedPower_kW : Real = 5.5;
    attribute running : Boolean = false;
  }

  part def DiffuserGrid {
    port airIn : AirPort;
    port waterContact : WaterInletPort;

    attribute diffuserCount : Integer = 24;
    attribute bubbleDiameter_mm : Real = 2.0;
    attribute oxygenTransferEfficiency_percent : Real = 18.0;
  }

  part def AerationTank {
    port untreatedWaterIn : WaterInletPort;
    port treatedWaterOut : WaterOutletPort;
    port mixedWaterSignal : SignalPort;

    attribute workingVolume_m3 : Real = 120.0;
    attribute waterDepth_m : Real = 4.5;
    attribute hydraulicRetentionTime_min : Real = 30.0;

    part diffuserGrid : DiffuserGrid;
  }

  part def DissolvedOxygenSensor {
    port measurementOut : SignalPort;

    attribute measuredDO_mgPerL : Real;
    attribute accuracy_mgPerL : Real = 0.1;
    attribute sampleInterval_s : Real = 2.0;
  }

  part def TemperatureSensor {
    port measurementOut : SignalPort;

    attribute measuredTemperature_degC : Real;
    attribute accuracy_degC : Real = 0.2;
  }

  part def AerationController {
    port dissolvedOxygenIn : SignalPort;
    port temperatureIn : SignalPort;
    port blowerCommandOut : SignalPort;

    attribute targetDO_mgPerL : Real = 6.0;
    attribute lowDOThreshold_mgPerL : Real = 5.5;
    attribute highDOThreshold_mgPerL : Real = 7.0;
    attribute commandedBlowerSpeed_percent : Real;
  }

  part def PowerSupply {
    port powerOut : PowerPort;

    attribute nominalVoltage_V : Real = 480.0;
    attribute phaseCount : Integer = 3;
    attribute frequency_Hz : Real = 60.0;
    attribute availablePower_kW : Real = 15.0;
  }

  action def MeasureWaterQuality {
    in water : RawWater;
    out dissolvedOxygen_mgPerL : Real;
    out temperature_degC : Real;
  }

  action def SupplyCompressedAir {
    in power : ElectricalPower;
    out air : Air;

    attribute blowerSpeed_percent : Real;
  }

  action def TransferOxygenToWater {
    in untreatedWater : RawWater;
    in air : Air;
    out treatedWater : AeratedWater;

    attribute oxygenTransferRate_kgPerHour : Real;
    attribute mixingIntensity_WPerM3 : Real;
  }

  action def ControlAeration {
    in measuredDO_mgPerL : Real;
    in measuredTemperature_degC : Real;
    out blowerSpeedCommand_percent : Real;
  }

  state def AerationOperatingStates {
    state Off;
    state Startup;
    state Aerating;
    state Standby;
    state AlarmShutdown;

    transition initial then Off;
    transition Off then Startup
      accept StartCommand;

    transition Startup then Aerating
      if startupChecksPassed;

    transition Aerating then Standby
      if dissolvedOxygenAboveHighThreshold;

    transition Standby then Aerating
      if dissolvedOxygenBelowLowThreshold;

    transition Aerating then AlarmShutdown
      if sensorFault or blowerFault or lowWaterLevel;

    transition Standby then AlarmShutdown
      if sensorFault or blowerFault or lowWaterLevel;

    transition AlarmShutdown then Off
      accept ResetCommand;
  }

  part def WaterAerationSystem {
    port rawWaterIn : WaterInletPort;
    port aeratedWaterOut : WaterOutletPort;
    port electricalPowerIn : PowerPort;

    attribute primaryFunction : String = "Increase dissolved oxygen in incoming water by transferring oxygen from supplied air into the water volume through controlled fine-bubble diffusion.";
    attribute designFlowRate_m3PerHour : Real = 240.0;
    attribute inletDO_mgPerL : Real = 2.0;
    attribute outletDOTarget_mgPerL : Real = 6.0;
    attribute nominalOxygenTransferRate_kgPerHour : Real = 3.2;
    attribute maximumEnergyUse_kWhPer1000m3 : Real = 35.0;
    attribute minimumAvailability_percent : Real = 98.0;

    part powerSupply : PowerSupply;
    part blower : AirBlower;
    part tank : AerationTank;
    part dissolvedOxygenSensor : DissolvedOxygenSensor;
    part temperatureSensor : TemperatureSensor;
    part controller : AerationController;

    connect electricalPowerIn to powerSupply.powerOut;
    connect powerSupply.powerOut to blower.powerIn;
    connect blower.airOut to tank.diffuserGrid.airIn;
    connect rawWaterIn to tank.untreatedWaterIn;
    connect tank.treatedWaterOut to aeratedWaterOut;
    connect dissolvedOxygenSensor.measurementOut to controller.dissolvedOxygenIn;
    connect temperatureSensor.measurementOut to controller.temperatureIn;
    connect controller.blowerCommandOut to blower.airOut;

    perform action MeasureWaterQuality;
    perform action ControlAeration;
    perform action SupplyCompressedAir;
    perform action TransferOxygenToWater;

    exhibit state AerationOperatingStates;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : WaterAerationSystem;

    require constraint {
      system.outletDOTarget_mgPerL >= 6.0
    }

    doc /* The water aeration system shall raise dissolved oxygen concentration in water to support downstream water quality needs. */
  }

  requirement def FlowCapacityRequirement {
    subject system : WaterAerationSystem;

    require constraint {
      system.designFlowRate_m3PerHour >= 240.0
    }
  }

  requirement def OxygenTransferRequirement {
    subject system : WaterAerationSystem;

    require constraint {
      system.nominalOxygenTransferRate_kgPerHour >= 3.0
    }
  }

  requirement def EnergyEfficiencyRequirement {
    subject system : WaterAerationSystem;

    require constraint {
      system.maximumEnergyUse_kWhPer1000m3 <= 35.0
    }
  }

  requirement def AvailabilityRequirement {
    subject system : WaterAerationSystem;

    require constraint {
      system.minimumAvailability_percent >= 98.0
    }
  }

  part waterAerationSystem : WaterAerationSystem;

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject system = waterAerationSystem;
  }

  requirement flowCapacityRequirement : FlowCapacityRequirement {
    subject system = waterAerationSystem;
  }

  requirement oxygenTransferRequirement : OxygenTransferRequirement {
    subject system = waterAerationSystem;
  }

  requirement energyEfficiencyRequirement : EnergyEfficiencyRequirement {
    subject system = waterAerationSystem;
  }

  requirement availabilityRequirement : AvailabilityRequirement {
    subject system = waterAerationSystem;
  }
}