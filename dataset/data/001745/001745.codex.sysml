package AquariumFilterSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def VolumeRate :> Real {
    unit = "L/h";
  }

  attribute def Volume :> Real {
    unit = "L";
  }

  attribute def Pressure :> Real {
    unit = "kPa";
  }

  attribute def Power :> Real {
    unit = "W";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def Concentration :> Real {
    unit = "mg/L";
  }

  attribute def Turbidity :> Real {
    unit = "NTU";
  }

  attribute def Percent :> Real {
    unit = "%";
  }

  item def AquariumWater {
    attribute volume : Volume;
    attribute dissolvedOxygen : Concentration;
    attribute ammonia : Concentration;
    attribute nitrite : Concentration;
    attribute nitrate : Concentration;
    attribute turbidity : Turbidity;
    attribute temperature : Real;
  }

  item def Debris {
    attribute particleDiameter : Real;
    attribute organicFraction : Percent;
  }

  item def Biofilm {
    attribute activeBacteriaCoverage : Percent;
    attribute nitrificationEfficiency : Percent;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage;
    attribute power : Power;
  }

  item def FilterStatusSignal {
    attribute flowRate : VolumeRate;
    attribute cloggingLevel : Percent;
    attribute pumpRunning : Boolean;
    attribute maintenanceRequired : Boolean;
  }

  port def WaterInletPort {
    in item dirtyWater : AquariumWater;
  }

  port def WaterOutletPort {
    out item cleanWater : AquariumWater;
  }

  port def WasteCollectionPort {
    out item capturedDebris : Debris;
  }

  port def ElectricalPowerPort {
    in item supply : ElectricalEnergy;
  }

  port def StatusPort {
    out item status : FilterStatusSignal;
  }

  port def InternalWaterPort {
    inout item water : AquariumWater;
  }

  action def DrawWater {
    in item sourceWater : AquariumWater;
    out item pressurizedWater : AquariumWater;
    attribute targetFlowRate : VolumeRate;
  }

  action def RemoveSuspendedParticles {
    in item incomingWater : AquariumWater;
    out item mechanicallyFilteredWater : AquariumWater;
    out item removedDebris : Debris;
    attribute meshRating : Real;
  }

  action def ConvertToxicNitrogenCompounds {
    in item mechanicallyFilteredWater : AquariumWater;
    in item nitrifyingBiofilm : Biofilm;
    out item biologicallyFilteredWater : AquariumWater;
    attribute ammoniaConversionRate : Concentration;
    attribute nitriteConversionRate : Concentration;
  }

  action def AdsorbDissolvedImpurities {
    in item biologicallyFilteredWater : AquariumWater;
    out item polishedWater : AquariumWater;
    attribute mediaRemainingCapacity : Percent;
  }

  action def ReturnCleanWater {
    in item polishedWater : AquariumWater;
    out item aquariumWater : AquariumWater;
    attribute dischargeFlowRate : VolumeRate;
  }

  action def MonitorFilterHealth {
    in item filteredWater : AquariumWater;
    out item status : FilterStatusSignal;
    attribute measuredPressureDrop : Pressure;
    attribute measuredFlowRate : VolumeRate;
  }

  action def PerformFiltrationCycle {
    in item dirtyWater : AquariumWater;
    in item powerInput : ElectricalEnergy;
    in item biofilm : Biofilm;
    out item cleanWater : AquariumWater;
    out item collectedDebris : Debris;
    out item filterStatus : FilterStatusSignal;

    action draw : DrawWater {
      in sourceWater = dirtyWater;
      attribute targetFlowRate = 450.0;
    }

    action mechanicalFiltration : RemoveSuspendedParticles {
      in incomingWater = draw.pressurizedWater;
      attribute meshRating = 200.0;
    }

    action biologicalFiltration : ConvertToxicNitrogenCompounds {
      in mechanicallyFilteredWater = mechanicalFiltration.mechanicallyFilteredWater;
      in nitrifyingBiofilm = biofilm;
      attribute ammoniaConversionRate = 0.20;
      attribute nitriteConversionRate = 0.15;
    }

    action chemicalFiltration : AdsorbDissolvedImpurities {
      in biologicallyFilteredWater = biologicalFiltration.biologicallyFilteredWater;
      attribute mediaRemainingCapacity = 80.0;
    }

    action discharge : ReturnCleanWater {
      in polishedWater = chemicalFiltration.polishedWater;
      attribute dischargeFlowRate = 430.0;
    }

    action monitor : MonitorFilterHealth {
      in filteredWater = discharge.aquariumWater;
      attribute measuredPressureDrop = 8.0;
      attribute measuredFlowRate = 430.0;
    }

    bind cleanWater = discharge.aquariumWater;
    bind collectedDebris = mechanicalFiltration.removedDebris;
    bind filterStatus = monitor.status;
  }

  state def FilterOperatingStateMachine {
    entry action initializeFilter;

    state Off;
    state Priming;
    state Filtering;
    state ReducedFlow;
    state MaintenanceRequired;
    state Fault;

    transition first Off;

    transition Off_to_Priming
      first Off
      then Priming
      accept powerAvailable;

    transition Priming_to_Filtering
      first Priming
      then Filtering
      accept waterDetected
      if inletSubmerged;

    transition Priming_to_Fault
      first Priming
      then Fault
      accept primingTimeout
      if not inletSubmerged;

    transition Filtering_to_ReducedFlow
      first Filtering
      then ReducedFlow
      accept flowDropDetected
      if cloggingLevel > 60.0;

    transition ReducedFlow_to_MaintenanceRequired
      first ReducedFlow
      then MaintenanceRequired
      accept sustainedLowFlow
      if cloggingLevel > 80.0;

    transition ReducedFlow_to_Filtering
      first ReducedFlow
      then Filtering
      accept flowRecovered
      if cloggingLevel <= 60.0;

    transition MaintenanceRequired_to_Priming
      first MaintenanceRequired
      then Priming
      accept mediaCleaned;

    transition Filtering_to_Off
      first Filtering
      then Off
      accept powerRemoved;

    transition Fault_to_Off
      first Fault
      then Off
      accept resetCommand;
  }

  part def Pump {
    port powerPort : ElectricalPowerPort;
    port waterIn : WaterInletPort;
    port waterOut : InternalWaterPort;

    attribute ratedFlowRate : VolumeRate = 500.0;
    attribute nominalPower : Power = 12.0;
    attribute nominalVoltage : Voltage = 120.0;
    attribute maximumHeadPressure : Pressure = 35.0;
    attribute running : Boolean;

    perform action pumpWater : DrawWater;
  }

  part def IntakeStrainer {
    port inlet : WaterInletPort;
    port outlet : InternalWaterPort;

    attribute slotWidth : Real = 1.5;
    attribute preventsFishIngress : Boolean = true;
  }

  part def MechanicalMediaCartridge {
    port inlet : InternalWaterPort;
    port outlet : InternalWaterPort;
    port wasteOutlet : WasteCollectionPort;

    attribute poreSize : Real = 200.0;
    attribute debrisHoldingCapacity : Volume = 0.35;
    attribute cloggingLevel : Percent = 0.0;

    perform action removeParticles : RemoveSuspendedParticles;
  }

  part def BiologicalMediaBed {
    port inlet : InternalWaterPort;
    port outlet : InternalWaterPort;

    attribute mediaSurfaceArea : Real = 3.5;
    attribute biofilmCoverage : Percent = 75.0;
    attribute ammoniaRemovalEfficiency : Percent = 85.0;
    attribute nitriteRemovalEfficiency : Percent = 80.0;

    item biofilm : Biofilm {
      attribute activeBacteriaCoverage = 75.0;
      attribute nitrificationEfficiency = 82.0;
    }

    perform action nitrify : ConvertToxicNitrogenCompounds;
  }

  part def ActivatedCarbonChamber {
    port inlet : InternalWaterPort;
    port outlet : InternalWaterPort;

    attribute carbonMass : Real = 0.12;
    attribute adsorptionCapacityRemaining : Percent = 80.0;
    attribute replacementInterval : TimeDuration = 2592000.0;

    perform action polishWater : AdsorbDissolvedImpurities;
  }

  part def ReturnSpout {
    port inlet : InternalWaterPort;
    port outlet : WaterOutletPort;

    attribute aerationEnabled : Boolean = true;
    attribute dischargeVelocity : Real = 0.35;

    perform action returnWater : ReturnCleanWater;
  }

  part def WasteReservoir {
    port debrisIn : WasteCollectionPort;

    attribute retainedDebrisVolume : Volume = 0.0;
    attribute maximumDebrisVolume : Volume = 0.35;
  }

  part def FlowSensor {
    port sensedWater : InternalWaterPort;
    port statusOut : StatusPort;

    attribute measuredFlowRate : VolumeRate = 430.0;
    attribute lowFlowThreshold : VolumeRate = 250.0;
  }

  part def FilterController {
    port statusOut : StatusPort;

    attribute pumpEnabled : Boolean = true;
    attribute maintenanceRequired : Boolean = false;
    attribute cloggingLevel : Percent = 0.0;

    perform state machine : FilterOperatingStateMachine;
    perform action healthMonitoring : MonitorFilterHealth;
  }

  part def AquariumFilter {
    port aquariumInlet : WaterInletPort;
    port aquariumOutlet : WaterOutletPort;
    port powerInput : ElectricalPowerPort;
    port statusOutput : StatusPort;

    attribute designTankVolume : Volume = 120.0;
    attribute nominalSystemFlowRate : VolumeRate = 430.0;
    attribute minimumEffectiveFlowRate : VolumeRate = 250.0;
    attribute totalPowerConsumption : Power = 12.0;
    attribute intendedFunction : String = "Continuously draw aquarium water through mechanical, biological, and chemical filtration stages, capture debris, reduce toxic nitrogen compounds, adsorb dissolved impurities, and return cleaner oxygenated water to the tank.";

    part intake : IntakeStrainer;
    part pump : Pump;
    part mechanicalMedia : MechanicalMediaCartridge;
    part biologicalMedia : BiologicalMediaBed;
    part carbonChamber : ActivatedCarbonChamber;
    part returnSpout : ReturnSpout;
    part debrisReservoir : WasteReservoir;
    part flowSensor : FlowSensor;
    part controller : FilterController;

    connect aquariumInlet to intake.inlet;
    connect intake.outlet to pump.waterIn;
    connect powerInput to pump.powerPort;
    connect pump.waterOut to mechanicalMedia.inlet;
    connect mechanicalMedia.outlet to biologicalMedia.inlet;
    connect mechanicalMedia.wasteOutlet to debrisReservoir.debrisIn;
    connect biologicalMedia.outlet to carbonChamber.inlet;
    connect carbonChamber.outlet to returnSpout.inlet;
    connect carbonChamber.outlet to flowSensor.sensedWater;
    connect returnSpout.outlet to aquariumOutlet;
    connect flowSensor.statusOut to controller.statusOut;
    connect controller.statusOut to statusOutput;

    perform action filtrationCycle : PerformFiltrationCycle;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The aquarium filter shall continuously circulate aquarium water through staged filtration and return cleaner water to sustain aquatic life. */
    subject filter : AquariumFilter;
    require constraint {
      filter.nominalSystemFlowRate >= filter.minimumEffectiveFlowRate
    }
  }

  requirement def MechanicalFiltrationRequirement {
    doc /* The filter shall remove suspended particulate debris before water reaches biological and chemical media. */
    subject cartridge : MechanicalMediaCartridge;
    require constraint {
      cartridge.poreSize <= 250.0
    }
  }

  requirement def BiologicalFiltrationRequirement {
    doc /* The biological media shall support nitrifying bacteria that reduce ammonia and nitrite concentrations in normal operation. */
    subject bed : BiologicalMediaBed;
    require constraint {
      bed.ammoniaRemovalEfficiency >= 75.0 and bed.nitriteRemovalEfficiency >= 70.0
    }
  }

  requirement def ChemicalFiltrationRequirement {
    doc /* The activated carbon chamber shall adsorb dissolved impurities while usable adsorption capacity remains. */
    subject chamber : ActivatedCarbonChamber;
    require constraint {
      chamber.adsorptionCapacityRemaining > 10.0
    }
  }

  requirement def FlowMonitoringRequirement {
    doc /* The filter shall identify low-flow or clogged conditions and report maintenance status. */
    subject controller : FilterController;
    require constraint {
      controller.maintenanceRequired == true implies controller.cloggingLevel >= 80.0
    }
  }

  requirement def ElectricalPowerRequirement {
    doc /* The filter shall operate from a household electrical supply while consuming no more than the rated pump power. */
    subject filter : AquariumFilter;
    require constraint {
      filter.totalPowerConsumption <= 15.0
    }
  }

  part aquariumFiltrationSystem : AquariumFilter {
    attribute designTankVolume = 120.0;
    attribute nominalSystemFlowRate = 430.0;
    attribute minimumEffectiveFlowRate = 250.0;
    attribute totalPowerConsumption = 12.0;
  }

  satisfy PrimaryFunctionRequirement by aquariumFiltrationSystem;
  satisfy ElectricalPowerRequirement by aquariumFiltrationSystem;
  satisfy MechanicalFiltrationRequirement by aquariumFiltrationSystem.mechanicalMedia;
  satisfy BiologicalFiltrationRequirement by aquariumFiltrationSystem.biologicalMedia;
  satisfy ChemicalFiltrationRequirement by aquariumFiltrationSystem.carbonChamber;
  satisfy FlowMonitoringRequirement by aquariumFiltrationSystem.controller;
}