package BiomimeticPassiveCoolingSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Temperature {
    :> scalarValues::Real;
    unit = "degC";
  }

  attribute def RelativeHumidity {
    :> scalarValues::Real;
    unit = "%";
  }

  attribute def Pressure {
    :> scalarValues::Real;
    unit = "Pa";
  }

  attribute def VolumetricFlowRate {
    :> scalarValues::Real;
    unit = "m^3/s";
  }

  attribute def HeatPower {
    :> scalarValues::Real;
    unit = "W";
  }

  attribute def AirSpeed {
    :> scalarValues::Real;
    unit = "m/s";
  }

  attribute def SolarIrradiance {
    :> scalarValues::Real;
    unit = "W/m^2";
  }

  attribute def CarbonDioxideConcentration {
    :> scalarValues::Real;
    unit = "ppm";
  }

  attribute def Energy {
    :> scalarValues::Real;
    unit = "kWh";
  }

  attribute def Fraction {
    :> scalarValues::Real;
    unit = "1";
  }

  item def Air {
    attribute temperature : Temperature;
    attribute humidity : RelativeHumidity;
    attribute pressure : Pressure;
    attribute carbonDioxide : CarbonDioxideConcentration;
    attribute flowRate : VolumetricFlowRate;
  }

  item def Heat {
    attribute heatRate : HeatPower;
    attribute sourceTemperature : Temperature;
  }

  item def ControlSignal {
    attribute openingCommand : Fraction;
    attribute fanAssistCommand : Fraction;
    attribute bypassCommand : Fraction;
  }

  port def AirPort {
    inout air : Air;
  }

  port def HeatPort {
    inout heat : Heat;
  }

  port def SignalPort {
    inout command : ControlSignal;
  }

  part def TermiteMoundInspiredClimateSystem {
    doc
    /*
     Biomimicry basis: the system imitates the self-regulating ventilation of termite mounds.
     Its primary high-level function is to maintain habitable indoor temperature and air quality
     by using stack effect, thermal mass, branching air channels, and adaptive vents instead of
     conventional compressor-based cooling.
    */

    attribute indoorTemperature : Temperature;
    attribute outdoorTemperature : Temperature;
    attribute indoorHumidity : RelativeHumidity;
    attribute outdoorHumidity : RelativeHumidity;
    attribute indoorCO2 : CarbonDioxideConcentration;
    attribute solarLoad : SolarIrradiance;
    attribute dailyElectricalEnergy : Energy;
    attribute comfortError : Temperature;

    port outdoorAirIn : AirPort;
    port exhaustAirOut : AirPort;
    port occupiedZoneAir : AirPort;
    port heatExchange : HeatPort;
    port controllerBus : SignalPort;

    part inletChimney : GroundAirInlet;
    part branchingDuctNetwork : BranchingVentilationLattice;
    part thermalMassCore : PorousThermalMassCore;
    part solarChimney : SolarHeatedExhaustChimney;
    part adaptiveSkin : AdaptiveVentSkin;
    part occupiedZone : OccupiedHabitatZone;
    part sensorArray : EnvironmentalSensorArray;
    part controller : BiomimeticVentilationController;
    part lowPowerFan : AssistFan;

    connect outdoorAirIn to inletChimney.externalAir;
    connect inletChimney.conditionedAir to branchingDuctNetwork.mainInlet;
    connect branchingDuctNetwork.distributedOutlet to occupiedZone.supplyAir;
    connect occupiedZone.returnAir to solarChimney.exhaustInlet;
    connect solarChimney.exhaustOutlet to exhaustAirOut;

    connect occupiedZone.zoneHeat to thermalMassCore.heatInterface;
    connect thermalMassCore.airInterface to branchingDuctNetwork.coreExchange;
    connect adaptiveSkin.skinAir to branchingDuctNetwork.skinExchange;
    connect adaptiveSkin.commandPort to controller.ventCommand;
    connect sensorArray.measurementCommand to controller.sensorInput;
    connect controller.fanCommand to lowPowerFan.commandPort;
    connect lowPowerFan.airBoost to branchingDuctNetwork.assistInlet;
    connect heatExchange to thermalMassCore.heatInterface;

    perform maintainComfort : MaintainThermalComfort;
    exhibit operatingModes : PassiveCoolingStateMachine;

    constraint comfortBalance {
      indoorTemperature >= 21.0;
      indoorTemperature <= 27.0;
      indoorCO2 <= 900.0;
      dailyElectricalEnergy <= 2.5;
    }
  }

  part def GroundAirInlet {
    attribute inletDepth : Length = 2.5 [m];
    attribute groundTemperature : Temperature = 18.0;
    attribute pressureDrop : Pressure;
    attribute intakeFlow : VolumetricFlowRate;

    port externalAir : AirPort;
    port conditionedAir : AirPort;

    action conditionIncomingAir {
      in ambientAir : Air;
      out temperedAir : Air;
      attribute groundCouplingHeatRate : HeatPower;
    }
  }

  part def BranchingVentilationLattice {
    attribute numberOfPrimaryBranches : Integer = 6;
    attribute numberOfTerminalBranches : Integer = 48;
    attribute averageAirSpeed : AirSpeed;
    attribute pressureRecovery : Pressure;
    attribute totalFlowRate : VolumetricFlowRate;

    port mainInlet : AirPort;
    port assistInlet : AirPort;
    port coreExchange : AirPort;
    port skinExchange : AirPort;
    port distributedOutlet : AirPort;

    action distributeAir {
      in supplyAir : Air;
      out zoneAir : Air;
      attribute flowUniformity : Fraction;
    }
  }

  part def PorousThermalMassCore {
    attribute coreMaterialDensity : Real = 1800.0;
    attribute effectiveHeatCapacity : Real = 920.0;
    attribute storedHeat : HeatPower;
    attribute coreTemperature : Temperature;
    attribute porosity : Fraction = 0.32;

    port heatInterface : HeatPort;
    port airInterface : AirPort;

    action absorbDaytimeHeat {
      in zoneHeat : Heat;
      out coolerAir : Air;
    }

    action releaseNightHeat {
      in nightAir : Air;
      out warmedExhaustAir : Air;
    }
  }

  part def SolarHeatedExhaustChimney {
    attribute chimneyHeight : Length = 12.0 [m];
    attribute absorberTemperature : Temperature;
    attribute stackPressure : Pressure;
    attribute exhaustFlow : VolumetricFlowRate;

    port exhaustInlet : AirPort;
    port exhaustOutlet : AirPort;

    action createStackDraft {
      in warmReturnAir : Air;
      out exhaustedAir : Air;
      attribute buoyancyPressure : Pressure;
    }
  }

  part def AdaptiveVentSkin {
    attribute ventOpenFraction : Fraction;
    attribute apertureArea : Area = 18.0 [m^2];
    attribute skinTemperature : Temperature;
    attribute rainShieldPosition : Fraction;

    port skinAir : AirPort;
    port commandPort : SignalPort;

    action adjustApertures {
      in command : ControlSignal;
      out exchangedAir : Air;
    }
  }

  part def OccupiedHabitatZone {
    attribute occupancyCount : Integer;
    attribute sensibleHeatLoad : HeatPower;
    attribute latentHeatLoad : HeatPower;
    attribute zoneTemperature : Temperature;
    attribute zoneHumidity : RelativeHumidity;
    attribute zoneCO2 : CarbonDioxideConcentration;

    port supplyAir : AirPort;
    port returnAir : AirPort;
    port zoneHeat : HeatPort;

    action mixAndConditionZone {
      in suppliedAir : Air;
      out returnAirFlow : Air;
      out generatedHeat : Heat;
    }
  }

  part def EnvironmentalSensorArray {
    attribute measuredIndoorTemperature : Temperature;
    attribute measuredOutdoorTemperature : Temperature;
    attribute measuredIndoorHumidity : RelativeHumidity;
    attribute measuredCO2 : CarbonDioxideConcentration;
    attribute measuredSolarLoad : SolarIrradiance;
    attribute sensorUpdatePeriod : Real = 5.0;

    port measurementCommand : SignalPort;

    action sampleEnvironment {
      out signal : ControlSignal;
    }
  }

  part def BiomimeticVentilationController {
    attribute coolingSetpoint : Temperature = 25.0;
    attribute heatingSetpoint : Temperature = 21.0;
    attribute maximumCO2 : CarbonDioxideConcentration = 900.0;
    attribute minimumVentOpening : Fraction = 0.10;
    attribute maximumVentOpening : Fraction = 1.00;
    attribute fanAssistThreshold : Fraction = 0.75;

    port sensorInput : SignalPort;
    port ventCommand : SignalPort;
    port fanCommand : SignalPort;

    action computeVentilationCommand {
      in sensedState : ControlSignal;
      out ventSignal : ControlSignal;
      out fanSignal : ControlSignal;
    }
  }

  part def AssistFan {
    attribute ratedPower : HeatPower = 180.0;
    attribute commandedSpeed : Fraction;
    attribute boostFlowRate : VolumetricFlowRate;

    port commandPort : SignalPort;
    port airBoost : AirPort;

    action provideLowPowerAssist {
      in command : ControlSignal;
      out boostedAir : Air;
    }
  }

  action def MaintainThermalComfort {
    in outdoorAir : Air;
    in internalHeat : Heat;
    out exhaustAir : Air;

    first start;
    then sampleEnvironment;
    then computeVentilationMode;
    then conditionAirThroughGround;
    then distributeThroughBranchingLattice;
    then exchangeHeatWithPorousCore;
    then regulateAdaptiveSkin;
    then exhaustBySolarChimney;
    then verifyComfort;
    then done;

    action sampleEnvironment;
    action computeVentilationMode;
    action conditionAirThroughGround;
    action distributeThroughBranchingLattice;
    action exchangeHeatWithPorousCore;
    action regulateAdaptiveSkin;
    action exhaustBySolarChimney;
    action verifyComfort;
  }

  state def PassiveCoolingStateMachine {
    entry action initializeController;

    state PassiveDayCooling;
    state NightPurge;
    state HeatRetention;
    state FanAssistedVentilation;
    state StormProtection;
    state FaultTolerantVentilation;

    transition initial then PassiveDayCooling;

    transition PassiveDayCooling_to_NightPurge
      first PassiveDayCooling
      accept when outdoorTemperature < indoorTemperature - 2.0
      then NightPurge;

    transition NightPurge_to_PassiveDayCooling
      first NightPurge
      accept when solarLoad > 250.0
      then PassiveDayCooling;

    transition PassiveDayCooling_to_FanAssistedVentilation
      first PassiveDayCooling
      accept when indoorCO2 > 900.0 or indoorTemperature > 27.0
      then FanAssistedVentilation;

    transition FanAssistedVentilation_to_PassiveDayCooling
      first FanAssistedVentilation
      accept when indoorCO2 < 750.0 and indoorTemperature <= 26.0
      then PassiveDayCooling;

    transition PassiveDayCooling_to_HeatRetention
      first PassiveDayCooling
      accept when outdoorTemperature < 12.0 and indoorTemperature < 21.0
      then HeatRetention;

    transition HeatRetention_to_PassiveDayCooling
      first HeatRetention
      accept when indoorTemperature >= 22.0
      then PassiveDayCooling;

    transition Any_to_StormProtection
      first PassiveDayCooling
      accept when outdoorAir.pressure > 102500.0 and outdoorHumidity > 95.0
      then StormProtection;

    transition StormProtection_to_PassiveDayCooling
      first StormProtection
      accept when outdoorHumidity < 85.0
      then PassiveDayCooling;

    transition Any_to_FaultTolerantVentilation
      first FanAssistedVentilation
      accept when dailyElectricalEnergy > 2.5
      then FaultTolerantVentilation;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     The system shall provide habitable indoor thermal comfort and air quality by passively
     exchanging heat and air using termite-mound-inspired geometry and control behavior.
    */

    subject system : TermiteMoundInspiredClimateSystem;

    require constraint {
      system.indoorTemperature >= 21.0 and
      system.indoorTemperature <= 27.0 and
      system.indoorCO2 <= 900.0
    }
  }

  requirement def BiomimeticArchitectureRequirement {
    subject system : TermiteMoundInspiredClimateSystem;

    require constraint {
      system.branchingDuctNetwork.numberOfPrimaryBranches >= 4 and
      system.branchingDuctNetwork.numberOfTerminalBranches >= 24 and
      system.thermalMassCore.porosity >= 0.20 and
      system.adaptiveSkin.apertureArea >= 10.0
    }
  }

  requirement def LowEnergyRequirement {
    subject system : TermiteMoundInspiredClimateSystem;

    require constraint {
      system.dailyElectricalEnergy <= 2.5
    }
  }

  requirement def VentilationCapacityRequirement {
    subject system : TermiteMoundInspiredClimateSystem;

    require constraint {
      system.branchingDuctNetwork.totalFlowRate >= 1.2 and
      system.solarChimney.stackPressure >= 8.0
    }
  }

  requirement def ResilienceRequirement {
    subject system : TermiteMoundInspiredClimateSystem;

    require constraint {
      system.adaptiveSkin.ventOpenFraction >= 0.0 and
      system.adaptiveSkin.ventOpenFraction <= 1.0 and
      system.lowPowerFan.commandedSpeed >= 0.0 and
      system.lowPowerFan.commandedSpeed <= 1.0
    }
  }

  satisfy PrimaryFunctionRequirement by TermiteMoundInspiredClimateSystem;
  satisfy BiomimeticArchitectureRequirement by BranchingVentilationLattice;
  satisfy BiomimeticArchitectureRequirement by PorousThermalMassCore;
  satisfy LowEnergyRequirement by AssistFan;
  satisfy VentilationCapacityRequirement by SolarHeatedExhaustChimney;
  satisfy ResilienceRequirement by AdaptiveVentSkin;

  part termiteInspiredBuildingClimateSystem : TermiteMoundInspiredClimateSystem {
    attribute indoorTemperature = 24.0;
    attribute outdoorTemperature = 34.0;
    attribute indoorHumidity = 48.0;
    attribute outdoorHumidity = 62.0;
    attribute indoorCO2 = 650.0;
    attribute solarLoad = 720.0;
    attribute dailyElectricalEnergy = 1.1;
  }
}