package ConductivePolymerSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  doc
  /*
   * High-level primary function:
   * The conductive polymer system provides a flexible, lightweight material platform
   * that transports electrical charge through a polymer matrix while adapting its
   * conductivity in response to controlled electrochemical doping.
   */

  attribute def ConductivityValue :> Real {
    doc /* Electrical conductivity in siemens per meter. */
    unit = "S/m";
  }

  attribute def SheetResistanceValue :> Real {
    doc /* Sheet resistance in ohms per square. */
    unit = "ohm/sq";
  }

  attribute def ThicknessValue :> Real {
    unit = "um";
  }

  attribute def DopingRatioValue :> Real {
    doc /* Fraction of oxidized or reduced conductive sites. */
    unit = "1";
  }

  attribute def VoltageValue :> Real {
    unit = "V";
  }

  attribute def CurrentValue :> Real {
    unit = "mA";
  }

  attribute def TemperatureValue :> Real {
    unit = "degC";
  }

  attribute def HumidityValue :> Real {
    unit = "%RH";
  }

  attribute def StrainValue :> Real {
    unit = "%";
  }

  attribute def ResponseTimeValue :> Real {
    unit = "ms";
  }

  item def ElectronFlow {
    attribute current : CurrentValue;
    attribute voltage : VoltageValue;
  }

  item def IonFlow {
    attribute ionConcentration : Real;
    attribute migrationRate : Real;
  }

  item def ThermalCondition {
    attribute temperature : TemperatureValue;
  }

  item def HumidityCondition {
    attribute relativeHumidity : HumidityValue;
  }

  item def MechanicalDeformation {
    attribute tensileStrain : StrainValue;
  }

  item def ConductivityReport {
    attribute measuredConductivity : ConductivityValue;
    attribute sheetResistance : SheetResistanceValue;
    attribute dopingRatio : DopingRatioValue;
  }

  port def ElectricalTerminal {
    in item suppliedPower : ElectronFlow;
    out item conductedCharge : ElectronFlow;
  }

  port def ElectrolyteInterface {
    in item ionicInput : IonFlow;
    out item ionicOutput : IonFlow;
  }

  port def EnvironmentInterface {
    in item heat : ThermalCondition;
    in item moisture : HumidityCondition;
  }

  port def MechanicalInterface {
    in item deformation : MechanicalDeformation;
  }

  port def DiagnosticInterface {
    out item status : ConductivityReport;
  }

  action def AcceptElectricalStimulus {
    in item inputPower : ElectronFlow;
    out item appliedPotential : ElectronFlow;
  }

  action def AdjustPolymerDoping {
    in item appliedPotential : ElectronFlow;
    in item ionExchange : IonFlow;
    out attribute resultingDopingRatio : DopingRatioValue;
  }

  action def TransportCharge {
    in attribute dopingRatio : DopingRatioValue;
    in item appliedPotential : ElectronFlow;
    out item outputCharge : ElectronFlow;
    out attribute effectiveConductivity : ConductivityValue;
  }

  action def MeasureConductivity {
    in attribute effectiveConductivity : ConductivityValue;
    in attribute dopingRatio : DopingRatioValue;
    out item report : ConductivityReport;
  }

  state def ConductivePolymerOperatingStates {
    state off;
    state initializing;
    state insulating;
    state doping;
    state conducting;
    state protectiveShutdown;

    transition first off;

    transition powerApplied
      first off
      then initializing;

    transition initialized
      first initializing
      then insulating;

    transition voltageCommanded
      first insulating
      then doping;

    transition targetDopingReached
      first doping
      then conducting;

    transition commandRemoved
      first conducting
      then insulating;

    transition overTemperature
      first conducting
      then protectiveShutdown;

    transition reset
      first protectiveShutdown
      then initializing;
  }

  part def ConductivePolymerFilm {
    attribute polymerName : String = "PEDOT:PSS";
    attribute thickness : ThicknessValue = 25.0;
    attribute conductivity : ConductivityValue = 850.0;
    attribute sheetResistance : SheetResistanceValue = 47.0;
    attribute dopingRatio : DopingRatioValue = 0.68;
    attribute maxElasticStrain : StrainValue = 12.0;

    port leftElectrode : ElectricalTerminal;
    port rightElectrode : ElectricalTerminal;
    port electrolyteSurface : ElectrolyteInterface;
    port ambientExposure : EnvironmentInterface;
    port flexSurface : MechanicalInterface;
  }

  part def ElectrodeLayer {
    attribute material : String;
    attribute contactResistance : Real;
    port terminal : ElectricalTerminal;
  }

  part def IonReservoir {
    attribute electrolyteName : String = "aqueous sodium polystyrene sulfonate";
    attribute nominalIonConcentration : Real = 0.25;
    port ionPort : ElectrolyteInterface;
  }

  part def FlexibleSubstrate {
    attribute material : String = "polyimide";
    attribute thickness : ThicknessValue = 50.0;
    attribute allowableStrain : StrainValue = 15.0;
    port mechanicalMount : MechanicalInterface;
  }

  part def ControlElectronics {
    attribute driveVoltage : VoltageValue = 1.8;
    attribute currentLimit : CurrentValue = 20.0;
    attribute samplingPeriod : ResponseTimeValue = 10.0;

    port powerOutput : ElectricalTerminal;
    port senseInput : ElectricalTerminal;
    port diagnostics : DiagnosticInterface;
  }

  part def EnvironmentalBarrier {
    attribute waterVaporTransmissionRate : Real = 0.15;
    attribute maxOperatingTemperature : TemperatureValue = 85.0;
    port outside : EnvironmentInterface;
    port protectedSide : EnvironmentInterface;
  }

  part def ConductivePolymerModule {
    attribute nominalConductivity : ConductivityValue = 850.0;
    attribute minimumConductivity : ConductivityValue = 10.0;
    attribute maximumConductivity : ConductivityValue = 1200.0;
    attribute nominalResponseTime : ResponseTimeValue = 75.0;
    attribute operatingTemperatureMin : TemperatureValue = -20.0;
    attribute operatingTemperatureMax : TemperatureValue = 85.0;

    port electricalInput : ElectricalTerminal;
    port electricalOutput : ElectricalTerminal;
    port environment : EnvironmentInterface;
    port mechanicalLoad : MechanicalInterface;
    port diagnosticOutput : DiagnosticInterface;

    part polymerFilm : ConductivePolymerFilm;
    part inputElectrode : ElectrodeLayer {
      attribute material = "gold-coated carbon";
      attribute contactResistance = 0.8;
    }
    part outputElectrode : ElectrodeLayer {
      attribute material = "gold-coated carbon";
      attribute contactResistance = 0.8;
    }
    part ionReservoir : IonReservoir;
    part substrate : FlexibleSubstrate;
    part controller : ControlElectronics;
    part barrier : EnvironmentalBarrier;

    connect electricalInput to controller.powerOutput;
    connect controller.powerOutput to inputElectrode.terminal;
    connect inputElectrode.terminal to polymerFilm.leftElectrode;
    connect polymerFilm.rightElectrode to outputElectrode.terminal;
    connect outputElectrode.terminal to electricalOutput;

    connect ionReservoir.ionPort to polymerFilm.electrolyteSurface;

    connect environment to barrier.outside;
    connect barrier.protectedSide to polymerFilm.ambientExposure;

    connect mechanicalLoad to substrate.mechanicalMount;
    connect substrate.mechanicalMount to polymerFilm.flexSurface;

    connect controller.senseInput to polymerFilm.rightElectrode;
    connect controller.diagnostics to diagnosticOutput;

    perform action acceptStimulus : AcceptElectricalStimulus;
    perform action adjustDoping : AdjustPolymerDoping;
    perform action conductCharge : TransportCharge;
    perform action reportStatus : MeasureConductivity;

    exhibit state operatingMode : ConductivePolymerOperatingStates;
  }

  requirement def PrimaryFunctionRequirement {
    subject module : ConductivePolymerModule;

    doc
    /*
     * The module shall provide controlled electrical conduction through a flexible
     * conductive polymer film by regulating polymer doping under an applied voltage.
     */

    require constraint {
      module.minimumConductivity <= module.nominalConductivity and
      module.nominalConductivity <= module.maximumConductivity
    }
  }

  requirement def FlexibilityRequirement {
    subject film : ConductivePolymerFilm;

    doc
    /*
     * The conductive polymer film shall remain electrically continuous while
     * subjected to ordinary bending or stretching loads.
     */

    require constraint {
      film.maxElasticStrain >= 10.0
    }
  }

  requirement def LowVoltageOperationRequirement {
    subject controller : ControlElectronics;

    doc
    /*
     * The controller shall regulate doping using a low-voltage electrical stimulus
     * suitable for embedded flexible electronic systems.
     */

    require constraint {
      controller.driveVoltage <= 3.3 and
      controller.currentLimit <= 25.0
    }
  }

  requirement def ResponseTimeRequirement {
    subject module : ConductivePolymerModule;

    doc
    /*
     * The module shall reach its commanded conductive state within a sub-100 ms
     * response time for high-level switching and sensing functions.
     */

    require constraint {
      module.nominalResponseTime <= 100.0
    }
  }

  requirement def EnvironmentalProtectionRequirement {
    subject barrier : EnvironmentalBarrier;

    doc
    /*
     * The barrier shall protect the conductive polymer from humidity-driven drift
     * while preserving operation across the specified temperature range.
     */

    require constraint {
      barrier.maxOperatingTemperature >= 85.0 and
      barrier.waterVaporTransmissionRate <= 0.20
    }
  }

  part conductivePolymerSystem : ConductivePolymerModule;

}