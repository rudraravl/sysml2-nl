package SewageTreatmentSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def FlowRate {
    :> ScalarValues::Real;
    unit = "m^3/h";
  }

  attribute def Volume {
    :> ScalarValues::Real;
    unit = "m^3";
  }

  attribute def Concentration {
    :> ScalarValues::Real;
    unit = "mg/L";
  }

  attribute def RemovalEfficiency {
    :> ScalarValues::Real;
    unit = "%";
  }

  attribute def Power {
    :> ScalarValues::Real;
    unit = "kW";
  }

  attribute def TimeDuration {
    :> ScalarValues::Real;
    unit = "h";
  }

  attribute def Temperature {
    :> ScalarValues::Real;
    unit = "degC";
  }

  attribute def Pressure {
    :> ScalarValues::Real;
    unit = "kPa";
  }

  attribute def pHValue {
    :> ScalarValues::Real;
    unit = "pH";
  }

  item def RawSewage {
    attribute flowRate : FlowRate;
    attribute biochemicalOxygenDemand : Concentration;
    attribute chemicalOxygenDemand : Concentration;
    attribute totalSuspendedSolids : Concentration;
    attribute ammoniaNitrogen : Concentration;
    attribute phosphorus : Concentration;
    attribute temperature : Temperature;
    attribute acidity : pHValue;
  }

  item def ScreenedSewage specializes RawSewage;

  item def PrimaryEffluent specializes RawSewage {
    attribute settledSolidsRemoval : RemovalEfficiency;
  }

  item def MixedLiquor {
    attribute flowRate : FlowRate;
    attribute dissolvedOxygen : Concentration;
    attribute mixedLiquorSuspendedSolids : Concentration;
    attribute sludgeAge : TimeDuration;
  }

  item def TreatedEffluent {
    attribute flowRate : FlowRate;
    attribute biochemicalOxygenDemand : Concentration;
    attribute totalSuspendedSolids : Concentration;
    attribute ammoniaNitrogen : Concentration;
    attribute phosphorus : Concentration;
    attribute pathogenReduction : RemovalEfficiency;
  }

  item def PrimarySludge {
    attribute flowRate : FlowRate;
    attribute solidsConcentration : Concentration;
  }

  item def WasteActivatedSludge {
    attribute flowRate : FlowRate;
    attribute solidsConcentration : Concentration;
  }

  item def StabilizedBiosolids {
    attribute volume : Volume;
    attribute solidsContent : Concentration;
    attribute pathogenReduction : RemovalEfficiency;
  }

  item def Biogas {
    attribute productionRate : FlowRate;
    attribute methaneFraction : RemovalEfficiency;
    attribute energyContent : Power;
  }

  item def Disinfectant {
    attribute dose : Concentration;
  }

  item def ElectricalPower {
    attribute demand : Power;
  }

  port def SewageInletPort {
    in item sewage : RawSewage;
  }

  port def EffluentOutletPort {
    out item effluent : TreatedEffluent;
  }

  port def SludgeOutletPort {
    out item sludge : StabilizedBiosolids;
  }

  port def BiogasOutletPort {
    out item gas : Biogas;
  }

  port def PowerPort {
    in item electricity : ElectricalPower;
  }

  port def ChemicalPort {
    in item chemical : Disinfectant;
  }

  port def LiquidTransferPort {
    inout item liquid : RawSewage;
  }

  port def SludgeTransferPort {
    inout item sludge : PrimarySludge;
  }

  action def ReceiveSewage {
    in item influent : RawSewage;
    out item acceptedSewage : RawSewage;
  }

  action def RemoveCoarseSolids {
    in item influent : RawSewage;
    out item screened : ScreenedSewage;
  }

  action def SettlePrimarySolids {
    in item screened : ScreenedSewage;
    out item primaryEffluent : PrimaryEffluent;
    out item primarySludge : PrimarySludge;
  }

  action def BiologicallyTreat {
    in item primaryEffluent : PrimaryEffluent;
    out item mixedLiquor : MixedLiquor;
    attribute targetDissolvedOxygen : Concentration = 2.0;
  }

  action def ClarifyBiomass {
    in item mixedLiquor : MixedLiquor;
    out item clarifiedEffluent : TreatedEffluent;
    out item wasteSludge : WasteActivatedSludge;
  }

  action def DisinfectEffluent {
    in item clarifiedEffluent : TreatedEffluent;
    in item disinfectant : Disinfectant;
    out item finalEffluent : TreatedEffluent;
  }

  action def StabilizeSludge {
    in item primarySludge : PrimarySludge;
    in item wasteSludge : WasteActivatedSludge;
    out item biosolids : StabilizedBiosolids;
    out item gas : Biogas;
  }

  action def TreatSewageProcess {
    in item rawInfluent : RawSewage;
    in item disinfectant : Disinfectant;
    out item compliantEffluent : TreatedEffluent;
    out item reusableBiosolids : StabilizedBiosolids;
    out item recoverableBiogas : Biogas;

    action receive : ReceiveSewage {
      in item influent = rawInfluent;
    }

    action screen : RemoveCoarseSolids {
      in item influent = receive.acceptedSewage;
    }

    action primaryTreatment : SettlePrimarySolids {
      in item screened = screen.screened;
    }

    action biologicalTreatment : BiologicallyTreat {
      in item primaryEffluent = primaryTreatment.primaryEffluent;
    }

    action secondaryClarification : ClarifyBiomass {
      in item mixedLiquor = biologicalTreatment.mixedLiquor;
    }

    action disinfection : DisinfectEffluent {
      in item clarifiedEffluent = secondaryClarification.clarifiedEffluent;
      in item disinfectant = disinfectant;
      out item finalEffluent = compliantEffluent;
    }

    action sludgeTreatment : StabilizeSludge {
      in item primarySludge = primaryTreatment.primarySludge;
      in item wasteSludge = secondaryClarification.wasteSludge;
      out item biosolids = reusableBiosolids;
      out item gas = recoverableBiogas;
    }
  }

  part def PumpStation {
    port inlet : SewageInletPort;
    port outlet : LiquidTransferPort;
    port power : PowerPort;

    attribute maximumFlow : FlowRate = 2500.0;
    attribute wetWellVolume : Volume = 150.0;
    attribute pumpPower : Power = 75.0;
    attribute dischargePressure : Pressure = 280.0;
  }

  part def ScreeningUnit {
    port inlet : LiquidTransferPort;
    port outlet : LiquidTransferPort;

    attribute barSpacing : ScalarValues::Real = 6.0;
    attribute coarseSolidsRemoval : RemovalEfficiency = 95.0;
  }

  part def GritRemovalUnit {
    port inlet : LiquidTransferPort;
    port outlet : LiquidTransferPort;

    attribute gritRemovalEfficiency : RemovalEfficiency = 90.0;
    attribute hydraulicRetentionTime : TimeDuration = 0.25;
  }

  part def PrimaryClarifier {
    port inlet : LiquidTransferPort;
    port liquidOutlet : LiquidTransferPort;
    port sludgeOutlet : SludgeTransferPort;

    attribute tankVolume : Volume = 1200.0;
    attribute suspendedSolidsRemoval : RemovalEfficiency = 60.0;
    attribute biochemicalOxygenDemandRemoval : RemovalEfficiency = 35.0;
    attribute retentionTime : TimeDuration = 2.0;
  }

  part def AerationBasin {
    port inlet : LiquidTransferPort;
    port outlet : LiquidTransferPort;
    port power : PowerPort;

    attribute basinVolume : Volume = 4500.0;
    attribute targetDissolvedOxygen : Concentration = 2.0;
    attribute biochemicalOxygenDemandRemoval : RemovalEfficiency = 90.0;
    attribute ammoniaRemoval : RemovalEfficiency = 85.0;
    attribute aerationPower : Power = 420.0;
  }

  part def SecondaryClarifier {
    port inlet : LiquidTransferPort;
    port effluentOutlet : LiquidTransferPort;
    port sludgeOutlet : SludgeTransferPort;

    attribute biomassSeparationEfficiency : RemovalEfficiency = 98.0;
    attribute returnActivatedSludgeRate : FlowRate = 900.0;
    attribute wasteActivatedSludgeRate : FlowRate = 120.0;
  }

  part def DisinfectionUnit {
    port inlet : LiquidTransferPort;
    port chemicalInlet : ChemicalPort;
    port outlet : EffluentOutletPort;

    attribute contactTime : TimeDuration = 0.75;
    attribute pathogenReduction : RemovalEfficiency = 99.9;
    attribute residualDisinfectant : Concentration = 1.0;
  }

  part def AnaerobicDigester {
    port primarySludgeInlet : SludgeTransferPort;
    port wasteSludgeInlet : SludgeTransferPort;
    port biosolidsOutlet : SludgeOutletPort;
    port gasOutlet : BiogasOutletPort;
    port power : PowerPort;

    attribute digesterVolume : Volume = 1800.0;
    attribute solidsReduction : RemovalEfficiency = 50.0;
    attribute digestionTime : TimeDuration = 360.0;
    attribute operatingTemperature : Temperature = 35.0;
    attribute mixingPower : Power = 55.0;
  }

  part def SewageTreatmentPlant {
    port influentInlet : SewageInletPort;
    port effluentOutlet : EffluentOutletPort;
    port biosolidsOutlet : SludgeOutletPort;
    port biogasOutlet : BiogasOutletPort;
    port powerSupply : PowerPort;
    port disinfectantSupply : ChemicalPort;

    attribute designAverageFlow : FlowRate = 1800.0;
    attribute peakFlowCapacity : FlowRate = 3600.0;
    attribute totalInstalledPower : Power = 650.0;
    attribute effluentBODLimit : Concentration = 25.0;
    attribute effluentTSSLimit : Concentration = 30.0;
    attribute effluentAmmoniaLimit : Concentration = 10.0;
    attribute operatingPHMinimum : pHValue = 6.5;
    attribute operatingPHMaximum : pHValue = 8.5;

    part pumpStation : PumpStation;
    part screeningUnit : ScreeningUnit;
    part gritRemovalUnit : GritRemovalUnit;
    part primaryClarifier : PrimaryClarifier;
    part aerationBasin : AerationBasin;
    part secondaryClarifier : SecondaryClarifier;
    part disinfectionUnit : DisinfectionUnit;
    part anaerobicDigester : AnaerobicDigester;

    connect influentInlet to pumpStation.inlet;
    connect pumpStation.outlet to screeningUnit.inlet;
    connect screeningUnit.outlet to gritRemovalUnit.inlet;
    connect gritRemovalUnit.outlet to primaryClarifier.inlet;
    connect primaryClarifier.liquidOutlet to aerationBasin.inlet;
    connect aerationBasin.outlet to secondaryClarifier.inlet;
    connect secondaryClarifier.effluentOutlet to disinfectionUnit.inlet;
    connect disinfectionUnit.outlet to effluentOutlet;

    connect primaryClarifier.sludgeOutlet to anaerobicDigester.primarySludgeInlet;
    connect secondaryClarifier.sludgeOutlet to anaerobicDigester.wasteSludgeInlet;
    connect anaerobicDigester.biosolidsOutlet to biosolidsOutlet;
    connect anaerobicDigester.gasOutlet to biogasOutlet;

    connect powerSupply to pumpStation.power;
    connect powerSupply to aerationBasin.power;
    connect powerSupply to anaerobicDigester.power;
    connect disinfectantSupply to disinfectionUnit.chemicalInlet;

    perform action treatment : TreatSewageProcess;
  }

  state def SewageTreatmentOperatingStateMachine {
    entry action initializePlant;
    exit action securePlant;

    state offline;
    state startup;
    state normalTreatment;
    state peakFlowTreatment;
    state maintenanceBypass;
    state emergencyShutdown;

    transition first offline;

    transition offline_to_startup
      first offline
      then startup;

    transition startup_to_normal
      first startup
      then normalTreatment
      guard startupChecksComplete;

    transition normal_to_peak
      first normalTreatment
      then peakFlowTreatment
      guard influentFlowExceedsAverage;

    transition peak_to_normal
      first peakFlowTreatment
      then normalTreatment
      guard influentFlowReturnsToDesignRange;

    transition normal_to_maintenance
      first normalTreatment
      then maintenanceBypass
      guard unitIsolationRequested;

    transition maintenance_to_normal
      first maintenanceBypass
      then normalTreatment
      guard maintenanceCompleted;

    transition any_to_emergency
      first normalTreatment
      then emergencyShutdown
      guard toxicInfluentDetected;

    transition emergency_to_offline
      first emergencyShutdown
      then offline
      guard plantSecured;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The sewage treatment system shall receive raw sewage, remove coarse solids, settleable solids, dissolved organic load, nutrients, and pathogens, and discharge treated effluent that is suitable for permitted release while converting separated solids into stabilized biosolids and recoverable biogas. */
  }

  requirement def HydraulicCapacityRequirement {
    subject plant : SewageTreatmentPlant;
    require constraint { plant.peakFlowCapacity >= 2.0 * plant.designAverageFlow }
  }

  requirement def EffluentQualityRequirement {
    subject plant : SewageTreatmentPlant;
    require constraint {
      plant.effluentBODLimit <= 25.0 and
      plant.effluentTSSLimit <= 30.0 and
      plant.effluentAmmoniaLimit <= 10.0
    }
  }

  requirement def BiologicalTreatmentRequirement {
    subject basin : AerationBasin;
    require constraint {
      basin.targetDissolvedOxygen >= 1.5 and
      basin.targetDissolvedOxygen <= 3.0 and
      basin.biochemicalOxygenDemandRemoval >= 85.0
    }
  }

  requirement def SludgeStabilizationRequirement {
    subject digester : AnaerobicDigester;
    require constraint {
      digester.solidsReduction >= 45.0 and
      digester.operatingTemperature >= 33.0 and
      digester.operatingTemperature <= 38.0
    }
  }

  requirement def DisinfectionRequirement {
    subject unit : DisinfectionUnit;
    require constraint {
      unit.pathogenReduction >= 99.9 and
      unit.contactTime >= 0.5
    }
  }

  requirement def PowerAvailabilityRequirement {
    subject plant : SewageTreatmentPlant;
    require constraint {
      plant.totalInstalledPower >=
        plant.pumpStation.pumpPower +
        plant.aerationBasin.aerationPower +
        plant.anaerobicDigester.mixingPower
    }
  }

  satisfy PrimaryFunctionRequirement by SewageTreatmentPlant;
  satisfy HydraulicCapacityRequirement by SewageTreatmentPlant;
  satisfy EffluentQualityRequirement by SewageTreatmentPlant;
  satisfy BiologicalTreatmentRequirement by AerationBasin;
  satisfy SludgeStabilizationRequirement by AnaerobicDigester;
  satisfy DisinfectionRequirement by DisinfectionUnit;
  satisfy PowerAvailabilityRequirement by SewageTreatmentPlant;
}