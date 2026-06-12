package OffshoreOilPlatformSystem {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Pressure :> ISQ::pressure;
  attribute def Temperature :> ISQ::thermodynamicTemperature;
  attribute def MassFlowRate :> ISQ::massFlowRate;
  attribute def VolumeFlowRate :> ISQ::volumeFlowRate;
  attribute def Power :> ISQ::power;
  attribute def Length :> ISQ::length;
  attribute def Time :> ISQ::time;

  item def CrudeOil {
    attribute apiGravity : Real;
    attribute waterCut : Real;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
  }

  item def NaturalGas {
    attribute methaneFraction : Real;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
  }

  item def ProducedWater {
    attribute salinity : Real;
    attribute oilContent : Real;
    attribute flowRate : VolumeFlowRate;
  }

  item def ElectricalEnergy {
    attribute voltage : Real;
    attribute frequency : Real;
    attribute power : Power;
  }

  item def ControlSignal {
    attribute commandId : String;
    attribute priority : Integer;
    attribute issuedAt : Time;
  }

  item def AlarmSignal {
    attribute severity : Integer;
    attribute message : String;
    attribute detectedAt : Time;
  }

  port def FluidInletPort {
    in item producedFluid : CrudeOil;
  }

  port def OilOutletPort {
    out item stabilizedOil : CrudeOil;
  }

  port def GasOutletPort {
    out item exportGas : NaturalGas;
  }

  port def WaterOutletPort {
    out item treatedWater : ProducedWater;
  }

  port def PowerPort {
    inout item energy : ElectricalEnergy;
  }

  port def ControlPort {
    in item command : ControlSignal;
    out item alarm : AlarmSignal;
  }

  part def OilPlatform {
    attribute topsideWeight : Real;
    attribute waterDepth : Length;
    attribute maxOilProductionRate : VolumeFlowRate;
    attribute maxGasProductionRate : VolumeFlowRate;
    attribute designLife : Time;

    port reservoirInlet : FluidInletPort;
    port oilExport : OilOutletPort;
    port gasExport : GasOutletPort;
    port waterDischarge : WaterOutletPort;
    port gridInterface : PowerPort;
    port operationsInterface : ControlPort;

    part wellbay : Wellbay;
    part separationTrain : SeparationTrain;
    part gasCompression : GasCompressionSystem;
    part waterTreatment : ProducedWaterTreatmentSystem;
    part oilExportSystem : OilExportSystem;
    part powerGeneration : PowerGenerationSystem;
    part controlAndSafety : ControlAndSafetySystem;
    part livingQuarters : LivingQuarters;
    part flareSystem : FlareSystem;
    part structure : JacketStructure;

    connect reservoirInlet to wellbay.productionInlet;
    connect wellbay.productionOutlet to separationTrain.mixedFluidInlet;
    connect separationTrain.oilOutlet to oilExportSystem.oilInlet;
    connect separationTrain.gasOutlet to gasCompression.gasInlet;
    connect separationTrain.waterOutlet to waterTreatment.waterInlet;
    connect oilExportSystem.exportOutlet to oilExport;
    connect gasCompression.exportOutlet to gasExport;
    connect waterTreatment.dischargeOutlet to waterDischarge;
    connect powerGeneration.powerBus to gridInterface;
    connect controlAndSafety.platformControl to operationsInterface;
    connect controlAndSafety.flareCommand to flareSystem.controlInput;
    connect separationTrain.reliefGasOutlet to flareSystem.reliefGasInlet;
    connect gasCompression.reliefGasOutlet to flareSystem.reliefGasInlet;

    perform action ProduceHydrocarbons;
    exhibit state PlatformOperationalState;
  }

  part def Wellbay {
    attribute wellCount : Integer;
    attribute nominalManifoldPressure : Pressure;

    port productionInlet : FluidInletPort;
    port productionOutlet : FluidInletPort;
    port controlInput : ControlPort;

    part productionManifold : ProductionManifold;
    part subseaRiser : SubseaRiser;

    connect productionInlet to subseaRiser.riserInlet;
    connect subseaRiser.riserOutlet to productionManifold.manifoldInlet;
    connect productionManifold.manifoldOutlet to productionOutlet;
  }

  part def ProductionManifold {
    attribute maximumPressure : Pressure;
    attribute chokePosition : Real;

    port manifoldInlet : FluidInletPort;
    port manifoldOutlet : FluidInletPort;
    port controlInput : ControlPort;
  }

  part def SubseaRiser {
    attribute riserLength : Length;
    attribute designPressure : Pressure;

    port riserInlet : FluidInletPort;
    port riserOutlet : FluidInletPort;
  }

  part def SeparationTrain {
    attribute separatorPressure : Pressure;
    attribute separatorTemperature : Temperature;
    attribute oilCapacity : VolumeFlowRate;
    attribute gasCapacity : VolumeFlowRate;
    attribute waterCapacity : VolumeFlowRate;

    port mixedFluidInlet : FluidInletPort;
    port oilOutlet : OilOutletPort;
    port gasOutlet : GasOutletPort;
    port waterOutlet : WaterOutletPort;
    port reliefGasOutlet : GasOutletPort;
    port controlInput : ControlPort;

    part firstStageSeparator : ThreePhaseSeparator;
    part secondStageSeparator : ThreePhaseSeparator;
    part oilHeaterTreater : OilHeaterTreater;

    connect mixedFluidInlet to firstStageSeparator.inlet;
    connect firstStageSeparator.oilOutlet to oilHeaterTreater.oilInlet;
    connect oilHeaterTreater.oilOutlet to secondStageSeparator.inlet;
    connect secondStageSeparator.oilOutlet to oilOutlet;
    connect firstStageSeparator.gasOutlet to gasOutlet;
    connect secondStageSeparator.gasOutlet to gasOutlet;
    connect firstStageSeparator.waterOutlet to waterOutlet;
    connect secondStageSeparator.waterOutlet to waterOutlet;
    connect firstStageSeparator.reliefOutlet to reliefGasOutlet;
    connect secondStageSeparator.reliefOutlet to reliefGasOutlet;
  }

  part def ThreePhaseSeparator {
    attribute operatingPressure : Pressure;
    attribute operatingTemperature : Temperature;
    attribute residenceTime : Time;

    port inlet : FluidInletPort;
    port oilOutlet : OilOutletPort;
    port gasOutlet : GasOutletPort;
    port waterOutlet : WaterOutletPort;
    port reliefOutlet : GasOutletPort;
  }

  part def OilHeaterTreater {
    attribute duty : Power;
    attribute targetTemperature : Temperature;

    port oilInlet : OilOutletPort;
    port oilOutlet : OilOutletPort;
    port powerInput : PowerPort;
  }

  part def GasCompressionSystem {
    attribute suctionPressure : Pressure;
    attribute dischargePressure : Pressure;
    attribute compressionPower : Power;

    port gasInlet : GasOutletPort;
    port exportOutlet : GasOutletPort;
    port reliefGasOutlet : GasOutletPort;
    port powerInput : PowerPort;
    port controlInput : ControlPort;

    part scrubber : GasScrubber;
    part compressor : GasCompressor;
    part cooler : GasCooler;

    connect gasInlet to scrubber.gasInlet;
    connect scrubber.gasOutlet to compressor.gasInlet;
    connect compressor.gasOutlet to cooler.gasInlet;
    connect cooler.gasOutlet to exportOutlet;
    connect compressor.reliefOutlet to reliefGasOutlet;
  }

  part def GasScrubber {
    port gasInlet : GasOutletPort;
    port gasOutlet : GasOutletPort;
    port liquidDrain : WaterOutletPort;
  }

  part def GasCompressor {
    attribute pressureRatio : Real;
    attribute driverPower : Power;

    port gasInlet : GasOutletPort;
    port gasOutlet : GasOutletPort;
    port reliefOutlet : GasOutletPort;
    port powerInput : PowerPort;
  }

  part def GasCooler {
    attribute outletTemperature : Temperature;

    port gasInlet : GasOutletPort;
    port gasOutlet : GasOutletPort;
  }

  part def ProducedWaterTreatmentSystem {
    attribute maxOilInWater : Real;
    attribute treatmentCapacity : VolumeFlowRate;

    port waterInlet : WaterOutletPort;
    port dischargeOutlet : WaterOutletPort;
    port controlInput : ControlPort;

    part hydrocyclone : Hydrocyclone;
    part degasser : Degasser;
    part dischargeMonitor : WaterQualityMonitor;

    connect waterInlet to hydrocyclone.waterInlet;
    connect hydrocyclone.waterOutlet to degasser.waterInlet;
    connect degasser.waterOutlet to dischargeMonitor.waterInlet;
    connect dischargeMonitor.waterOutlet to dischargeOutlet;
  }

  part def Hydrocyclone {
    attribute oilRemovalEfficiency : Real;

    port waterInlet : WaterOutletPort;
    port waterOutlet : WaterOutletPort;
  }

  part def Degasser {
    attribute gasRemovalEfficiency : Real;

    port waterInlet : WaterOutletPort;
    port waterOutlet : WaterOutletPort;
    port gasVent : GasOutletPort;
  }

  part def WaterQualityMonitor {
    attribute measuredOilInWater : Real;

    port waterInlet : WaterOutletPort;
    port waterOutlet : WaterOutletPort;
    port alarmOutput : ControlPort;
  }

  part def OilExportSystem {
    attribute exportPressure : Pressure;
    attribute storageVolume : Real;

    port oilInlet : OilOutletPort;
    port exportOutlet : OilOutletPort;
    port powerInput : PowerPort;

    part exportPump : OilExportPump;
    part meteringSkid : CustodyTransferMeter;

    connect oilInlet to exportPump.oilInlet;
    connect exportPump.oilOutlet to meteringSkid.oilInlet;
    connect meteringSkid.oilOutlet to exportOutlet;
  }

  part def OilExportPump {
    attribute ratedFlow : VolumeFlowRate;
    attribute dischargePressure : Pressure;

    port oilInlet : OilOutletPort;
    port oilOutlet : OilOutletPort;
    port powerInput : PowerPort;
  }

  part def CustodyTransferMeter {
    attribute measurementUncertainty : Real;

    port oilInlet : OilOutletPort;
    port oilOutlet : OilOutletPort;
  }

  part def PowerGenerationSystem {
    attribute installedPower : Power;
    attribute spinningReserve : Power;

    port powerBus : PowerPort;
    port controlInput : ControlPort;

    part gasTurbineGenerator1 : GasTurbineGenerator;
    part gasTurbineGenerator2 : GasTurbineGenerator;
    part emergencyDieselGenerator : EmergencyDieselGenerator;
  }

  part def GasTurbineGenerator {
    attribute ratedPower : Power;
    attribute fuelGasConsumption : VolumeFlowRate;

    port electricalOutput : PowerPort;
    port fuelGasInlet : GasOutletPort;
    port controlInput : ControlPort;
  }

  part def EmergencyDieselGenerator {
    attribute ratedPower : Power;
    attribute startTime : Time;

    port electricalOutput : PowerPort;
    port controlInput : ControlPort;
  }

  part def ControlAndSafetySystem {
    attribute safetyIntegrityLevel : Integer;
    attribute alarmResponseTime : Time;

    port platformControl : ControlPort;
    port flareCommand : ControlPort;

    part processControl : ProcessControlSystem;
    part emergencyShutdown : EmergencyShutdownSystem;
    part fireAndGasDetection : FireAndGasDetectionSystem;

    connect processControl.operatorInterface to platformControl;
    connect emergencyShutdown.shutdownCommand to platformControl;
    connect fireAndGasDetection.alarmOutput to platformControl;
  }

  part def ProcessControlSystem {
    port operatorInterface : ControlPort;
  }

  part def EmergencyShutdownSystem {
    attribute shutdownClosureTime : Time;

    port shutdownCommand : ControlPort;
  }

  part def FireAndGasDetectionSystem {
    attribute detectorCount : Integer;

    port alarmOutput : ControlPort;
  }

  part def FlareSystem {
    attribute flareCapacity : MassFlowRate;
    attribute ignitionAvailability : Real;

    port reliefGasInlet : GasOutletPort;
    port controlInput : ControlPort;
  }

  part def LivingQuarters {
    attribute personnelCapacity : Integer;
    attribute potableWaterCapacity : Real;
    attribute HVACPowerDemand : Power;
  }

  part def JacketStructure {
    attribute deckElevation : Length;
    attribute waterDepthRating : Length;
    attribute fatigueLife : Time;
  }

  action def ProduceHydrocarbons {
    in item reservoirFluid : CrudeOil;
    out item exportOil : CrudeOil;
    out item exportGas : NaturalGas;
    out item treatedProducedWater : ProducedWater;

    first startProduction;
    then regulateWellFlow;
    then separateOilGasWater;
    then stabilizeOil;
    then compressGas;
    then treatProducedWater;
    then exportHydrocarbons;

    action startProduction;
    action regulateWellFlow;
    action separateOilGasWater;
    action stabilizeOil;
    action compressGas;
    action treatProducedWater;
    action exportHydrocarbons;
  }

  state def PlatformOperationalState {
    entry action initializeControlSystems;

    state Offline;
    state Startup;
    state Producing;
    state Turndown;
    state EmergencyShutdown;
    state Maintenance;
    state AbandonPlatform;

    transition initial then Offline;
    transition Offline_to_Startup
      first Offline
      accept ControlSignal
      if command.commandId == "START_PLATFORM"
      then Startup;

    transition Startup_to_Producing
      first Startup
      if startupChecksComplete
      then Producing;

    transition Producing_to_Turndown
      first Producing
      accept ControlSignal
      if command.commandId == "REDUCE_PRODUCTION"
      then Turndown;

    transition Turndown_to_Producing
      first Turndown
      accept ControlSignal
      if command.commandId == "RESTORE_PRODUCTION"
      then Producing;

    transition Any_to_EmergencyShutdown
      first Producing
      accept AlarmSignal
      if alarm.severity >= 4
      then EmergencyShutdown;

    transition EmergencyShutdown_to_Maintenance
      first EmergencyShutdown
      accept ControlSignal
      if command.commandId == "MAKE_SAFE_FOR_MAINTENANCE"
      then Maintenance;

    transition Maintenance_to_Offline
      first Maintenance
      accept ControlSignal
      if command.commandId == "RETURN_TO_SERVICE"
      then Offline;

    transition Producing_to_AbandonPlatform
      first Producing
      accept AlarmSignal
      if alarm.message == "UNCONTROLLED_FIRE_OR_MAJOR_LEAK"
      then AbandonPlatform;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The oil platform shall receive multiphase reservoir production from offshore wells, separate crude oil, natural gas, and produced water, condition hydrocarbons for export, treat produced water for compliant discharge, and maintain safe operation of personnel, equipment, and environment. */
  }

  requirement def ProductionCapacityRequirement {
    attribute requiredOilRate : VolumeFlowRate;
    attribute requiredGasRate : VolumeFlowRate;

    require constraint {
      requiredOilRate <= 120000;
      requiredGasRate <= 15000000;
    }
  }

  requirement def SafetyShutdownRequirement {
    attribute maxShutdownTime : Time;

    require constraint {
      maxShutdownTime <= 30;
    }
  }

  requirement def ProducedWaterQualityRequirement {
    attribute maxOilInWaterDischarge : Real;

    require constraint {
      maxOilInWaterDischarge <= 30.0;
    }
  }

  requirement def PowerAvailabilityRequirement {
    attribute minimumAvailability : Real;

    require constraint {
      minimumAvailability >= 0.995;
    }
  }

  requirement def StructuralIntegrityRequirement {
    attribute minimumFatigueLife : Time;
    attribute ratedWaterDepth : Length;

    require constraint {
      minimumFatigueLife >= 25;
      ratedWaterDepth >= 150;
    }
  }

  part offshoreOilPlatform : OilPlatform {
    attribute topsideWeight = 42000;
    attribute waterDepth = 120;
    attribute maxOilProductionRate = 120000;
    attribute maxGasProductionRate = 15000000;
    attribute designLife = 25;

    satisfy PrimaryFunctionRequirement;
    satisfy ProductionCapacityRequirement;
    satisfy SafetyShutdownRequirement;
    satisfy ProducedWaterQualityRequirement;
    satisfy PowerAvailabilityRequirement;
    satisfy StructuralIntegrityRequirement;
  }

}