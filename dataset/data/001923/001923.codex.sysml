package RTG_PowerSystem {

  import ScalarValues::*;
  import SI::*;

  item def ThermalEnergy;
  item def ElectricalEnergy;
  item def WasteHeat;
  item def TelemetryData;
  item def ControlCommand;

  attribute def Temperature :> Real;
  attribute def Power :> Real;
  attribute def Voltage :> Real;
  attribute def Current :> Real;
  attribute def Efficiency :> Real;
  attribute def Mass :> Real;
  attribute def Time :> Real;

  port def ThermalPort {
    out item heat: ThermalEnergy;
  }

  port def ElectricalPort {
    out item electricity: ElectricalEnergy;
    attribute voltage: Voltage;
    attribute current: Current;
    attribute power: Power;
  }

  port def HeatRejectionPort {
    out item rejectedHeat: WasteHeat;
  }

  port def DataPort {
    out item telemetry: TelemetryData;
    in item command: ControlCommand;
  }

  part def RadioisotopeThermoelectricGenerator {
    doc /* Primary function: convert decay heat from a radioisotope heat source into continuous electrical power for a remote system without moving parts. */

    attribute nominalElectricalPower: Power = 125.0;
    attribute beginningOfLifeThermalPower: Power = 2000.0;
    attribute conversionEfficiency: Efficiency = 0.0625;
    attribute designLife: Time = 14.0;
    attribute totalMass: Mass = 45.0;

    port electricalOutput: ElectricalPort;
    port wasteHeatOutput: HeatRejectionPort;
    port telemetryPort: DataPort;

    part heatSource: RadioisotopeHeatSource;
    part thermoelectricConverter: ThermoelectricConverter;
    part thermalInsulation: ThermalInsulation;
    part radiator: RadiatorAssembly;
    part powerConditioner: PowerConditioningUnit;
    part controller: RTGController;
    part housing: ProtectiveHousing;

    connection heatSourceToConverter
      connect heatSource.thermalOutput to thermoelectricConverter.hotSideInput;

    connection converterWasteHeatToRadiator
      connect thermoelectricConverter.coldSideOutput to radiator.thermalInput;

    connection converterPowerToConditioner
      connect thermoelectricConverter.rawElectricalOutput to powerConditioner.rawPowerInput;

    connection conditionerToSystemOutput
      connect powerConditioner.regulatedPowerOutput to electricalOutput;

    connection radiatorToWasteHeatOutput
      connect radiator.heatRejectionOutput to wasteHeatOutput;

    connection controllerToTelemetry
      connect controller.dataPort to telemetryPort;

    perform action generateContinuousPower: GenerateContinuousElectricalPower;

    state rtgOperatingState: RTGOperatingState;
  }

  part def RadioisotopeHeatSource {
    attribute isotope: String = "Plutonium-238 dioxide";
    attribute thermalPowerBeginningOfLife: Power = 2000.0;
    attribute fuelTemperature: Temperature = 1273.0;
    attribute containmentTemperatureLimit: Temperature = 1473.0;
    attribute halfLife: Time = 87.7;
    attribute fuelMass: Mass = 4.8;

    port thermalOutput: ThermalPort;

    perform action releaseDecayHeat: ReleaseDecayHeat;
  }

  part def ThermoelectricConverter {
    attribute hotJunctionTemperature: Temperature = 873.0;
    attribute coldJunctionTemperature: Temperature = 473.0;
    attribute temperatureDifference: Temperature = 400.0;
    attribute thermoelectricEfficiency: Efficiency = 0.065;
    attribute rawOutputVoltage: Voltage = 30.0;
    attribute rawOutputPower: Power = 130.0;

    port hotSideInput: ThermalPort;
    port coldSideOutput: HeatRejectionPort;
    port rawElectricalOutput: ElectricalPort;

    part thermocoupleArray: ThermocoupleArray;

    perform action convertHeatToElectricity: ConvertHeatToElectricity;
  }

  part def ThermocoupleArray {
    attribute coupleCount: Integer = 768;
    attribute averageCoupleVoltage: Voltage = 0.039;
    attribute maximumHotSideTemperature: Temperature = 923.0;
    attribute minimumColdSideTemperature: Temperature = 423.0;
  }

  part def ThermalInsulation {
    attribute effectiveConductivity: Real = 0.03;
    attribute maximumOuterSurfaceTemperature: Temperature = 373.0;
    attribute retainedHeatFraction: Efficiency = 0.82;
  }

  part def RadiatorAssembly {
    attribute radiatorArea: Real = 2.4;
    attribute nominalRadiatedPower: Power = 1875.0;
    attribute outerSurfaceTemperature: Temperature = 425.0;

    port thermalInput: HeatRejectionPort;
    port heatRejectionOutput: HeatRejectionPort;

    perform action rejectWasteHeat: RejectWasteHeat;
  }

  part def PowerConditioningUnit {
    attribute inputVoltage: Voltage = 30.0;
    attribute regulatedVoltage: Voltage = 28.0;
    attribute maximumOutputCurrent: Current = 5.0;
    attribute conditioningEfficiency: Efficiency = 0.96;
    attribute outputRippleVoltage: Voltage = 0.05;

    port rawPowerInput: ElectricalPort;
    port regulatedPowerOutput: ElectricalPort;

    perform action regulateElectricalPower: RegulateElectricalPower;
  }

  part def RTGController {
    attribute healthStatus: String = "Nominal";
    attribute telemetryUpdatePeriod: Time = 1.0;
    attribute measuredOutputPower: Power;
    attribute measuredHotJunctionTemperature: Temperature;
    attribute measuredColdJunctionTemperature: Temperature;

    port dataPort: DataPort;

    perform action monitorHealth: MonitorRTGHealth;
  }

  part def ProtectiveHousing {
    attribute impactSurvivalAcceleration: Real = 500.0;
    attribute externalDoseRateLimit: Real = 0.25;
    attribute shellMass: Mass = 12.0;
    attribute sealed: Boolean = true;
  }

  action def GenerateContinuousElectricalPower {
    in item decayHeat: ThermalEnergy;
    out item regulatedElectricity: ElectricalEnergy;
    out item rejectedHeat: WasteHeat;

    first startHeatRelease;
    then convertThermalPower;
    then regulatePower;
    then rejectResidualHeat;

    action startHeatRelease: ReleaseDecayHeat;
    action convertThermalPower: ConvertHeatToElectricity;
    action regulatePower: RegulateElectricalPower;
    action rejectResidualHeat: RejectWasteHeat;
  }

  action def ReleaseDecayHeat {
    out item thermalEnergy: ThermalEnergy;
  }

  action def ConvertHeatToElectricity {
    in item inputHeat: ThermalEnergy;
    out item electricalEnergy: ElectricalEnergy;
    out item wasteHeat: WasteHeat;
  }

  action def RegulateElectricalPower {
    in item rawElectricity: ElectricalEnergy;
    out item regulatedElectricity: ElectricalEnergy;
  }

  action def RejectWasteHeat {
    in item wasteHeat: WasteHeat;
    out item rejectedHeat: WasteHeat;
  }

  action def MonitorRTGHealth {
    in item command: ControlCommand;
    out item telemetry: TelemetryData;
  }

  state def RTGOperatingState {
    entry action initializeMonitoring;
    exit action recordShutdownState;

    state Dormant;
    state Startup;
    state NominalPowerGeneration;
    state DegradedPowerGeneration;
    state FaultProtection;
    state EndOfLife;

    transition initial then Dormant;

    transition DormantToStartup
      first Dormant
      accept ControlCommand
      then Startup;

    transition StartupToNominal
      first Startup
      if startupChecksComplete == true
      then NominalPowerGeneration;

    transition NominalToDegraded
      first NominalPowerGeneration
      if electricalPowerMargin < 0.10
      then DegradedPowerGeneration;

    transition DegradedToFault
      first DegradedPowerGeneration
      if hotJunctionTemperatureExceedsLimit == true
      then FaultProtection;

    transition NominalToFault
      first NominalPowerGeneration
      if containmentTemperatureExceedsLimit == true
      then FaultProtection;

    transition DegradedToEndOfLife
      first DegradedPowerGeneration
      if availableElectricalPower < 80.0
      then EndOfLife;
  }

  requirement def PrimaryFunctionRequirement {
    subject rtg: RadioisotopeThermoelectricGenerator;

    doc /* The RTG shall provide continuous electrical power by converting radioisotope decay heat through thermoelectric conversion. */

    require constraint {
      rtg.nominalElectricalPower >= 100.0
    }
  }

  requirement def ContinuousOperationRequirement {
    subject rtg: RadioisotopeThermoelectricGenerator;

    require constraint {
      rtg.designLife >= 14.0
    }
  }

  requirement def NoMovingPartsRequirement {
    subject rtg: RadioisotopeThermoelectricGenerator;

    doc /* The power conversion path shall use solid-state thermoelectric elements and require no mechanical moving parts for primary power generation. */
  }

  requirement def RegulatedOutputRequirement {
    subject pcu: PowerConditioningUnit;

    require constraint {
      pcu.regulatedVoltage >= 27.5 and pcu.regulatedVoltage <= 28.5
    }
  }

  requirement def ThermalSafetyRequirement {
    subject source: RadioisotopeHeatSource;

    require constraint {
      source.fuelTemperature < source.containmentTemperatureLimit
    }
  }

  requirement def WasteHeatRejectionRequirement {
    subject radiator: RadiatorAssembly;

    require constraint {
      radiator.nominalRadiatedPower >= 1800.0
    }
  }

  requirement def TelemetryRequirement {
    subject controller: RTGController;

    require constraint {
      controller.telemetryUpdatePeriod <= 1.0
    }
  }

  part rtgPowerSystem: RadioisotopeThermoelectricGenerator {
    attribute nominalElectricalPower = 125.0;
    attribute beginningOfLifeThermalPower = 2000.0;
    attribute conversionEfficiency = 0.0625;
    attribute designLife = 14.0;
    attribute totalMass = 45.0;
  }

}