package OilPlatformHighLevelSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def PressureValue :> Real {
    doc "Pressure measured in bar."
    unit = "bar";
  }

  attribute def TemperatureValue :> Real {
    doc "Temperature measured in degree Celsius."
    unit = "degC";
  }

  attribute def FlowRateValue :> Real {
    doc "Volumetric flow rate measured in cubic meters per hour."
    unit = "m^3/h";
  }

  attribute def MassFlowRateValue :> Real {
    doc "Mass flow rate measured in tonnes per day."
    unit = "t/d";
  }

  attribute def PowerValue :> Real {
    doc "Electrical or mechanical power measured in megawatts."
    unit = "MW";
  }

  attribute def VolumeValue :> Real {
    doc "Volume measured in cubic meters."
    unit = "m^3";
  }

  attribute def LengthValue :> Real {
    doc "Length or water depth measured in meters."
    unit = "m";
  }

  attribute def ConcentrationValue :> Real {
    doc "Concentration measured in milligrams per liter."
    unit = "mg/L";
  }

  attribute def FractionValue :> Real {
    doc "Dimensionless fraction from 0 to 1."
    unit = "1";
  }

  enum def PlatformMode {
    enum idle;
    enum startup;
    enum producing;
    enum processing;
    enum exporting;
    enum emergencyShutdown;
    enum maintenance;
  }

  enum def AlarmSeverity {
    enum advisory;
    enum warning;
    enum critical;
  }

  enum def FluidPhase {
    enum multiphase;
    enum oil;
    enum gas;
    enum producedWater;
    enum seawater;
    enum chemical;
  }

  item def ReservoirFluid {
    doc "Multiphase hydrocarbon stream received from subsea wells."
    attribute phase : FluidPhase = FluidPhase::multiphase;
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute totalFlowRate : FlowRateValue;
    attribute oilFraction : FractionValue;
    attribute gasFraction : FractionValue;
    attribute waterFraction : FractionValue;
    attribute sandConcentration : ConcentrationValue;
  }

  item def StabilizedCrudeOil {
    doc "Export-quality crude oil after bulk separation, stabilization, metering, and pumping."
    attribute phase : FluidPhase = FluidPhase::oil;
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute exportFlowRate : FlowRateValue;
    attribute waterContent : FractionValue;
    attribute vaporPressure : PressureValue;
  }

  item def ExportGas {
    doc "Conditioned produced gas routed to compression, fuel gas, export, or flare systems."
    attribute phase : FluidPhase = FluidPhase::gas;
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute exportFlowRate : FlowRateValue;
    attribute hydrocarbonDewPoint : TemperatureValue;
  }

  item def TreatedProducedWater {
    doc "Produced water treated for reinjection or discharge according to platform limits."
    attribute phase : FluidPhase = FluidPhase::producedWater;
    attribute flowRate : FlowRateValue;
    attribute oilInWater : ConcentrationValue;
    attribute pressure : PressureValue;
  }

  item def ElectricalPower {
    doc "Electrical power distributed from platform generation to topsides consumers."
    attribute availablePower : PowerValue;
    attribute voltage : Real;
    attribute frequency : Real;
  }

  item def ControlCommand {
    doc "Digital command for equipment control."
    attribute commandId : String;
    attribute targetMode : PlatformMode;
    attribute priority : AlarmSeverity;
  }

  item def Telemetry {
    doc "Measured operating information reported to the integrated control and safety system."
    attribute tag : String;
    attribute value : Real;
    attribute severity : AlarmSeverity;
  }

  port def MultiphaseFluidInletPort {
    in item producedFluid : ReservoirFluid;
    attribute designPressure : PressureValue;
    attribute designFlowRate : FlowRateValue;
  }

  port def OilExportPort {
    out item crudeOil : StabilizedCrudeOil;
    attribute designPressure : PressureValue;
    attribute designFlowRate : FlowRateValue;
  }

  port def GasExportPort {
    out item gas : ExportGas;
    attribute designPressure : PressureValue;
    attribute designFlowRate : FlowRateValue;
  }

  port def WaterDischargePort {
    out item treatedWater : TreatedProducedWater;
    attribute maxOilInWater : ConcentrationValue;
  }

  port def PowerPort {
    inout item power : ElectricalPower;
    attribute ratedPower : PowerValue;
  }

  port def ControlPort {
    in item command : ControlCommand;
    out item telemetry : Telemetry;
  }

  port def ChemicalInjectionPort {
    out item chemical : ReservoirFluid;
    attribute injectionFlowRate : FlowRateValue;
  }

  port def FlarePort {
    in item gasToFlare : ExportGas;
    attribute maximumReliefFlow : FlowRateValue;
  }

  part def SubseaWell {
    doc "Subsea well connected to the platform by riser and flowline."
    attribute wellheadPressure : PressureValue;
    attribute wellheadTemperature : TemperatureValue;
    attribute maximumProductionRate : FlowRateValue;
    attribute chokeOpening : FractionValue;
    port producedFluidOut : MultiphaseFluidInletPort;
    port control : ControlPort;
  }

  part def ProductionRiser {
    doc "Vertical conduit transporting multiphase reservoir fluid from subsea facilities to topsides."
    attribute waterDepth : LengthValue;
    attribute innerDiameter : LengthValue;
    attribute designPressure : PressureValue;
    port inlet : MultiphaseFluidInletPort;
    port outlet : MultiphaseFluidInletPort;
  }

  part def WellheadManifold {
    doc "Combines production streams and distributes control or injection services."
    attribute manifoldDesignPressure : PressureValue;
    attribute connectedWellCount : Integer;
    port wellInlet[4] : MultiphaseFluidInletPort;
    port combinedOutlet : MultiphaseFluidInletPort;
    port chemicalInjection : ChemicalInjectionPort;
    port control : ControlPort;
  }

  part def ThreePhaseSeparator {
    doc "Separates multiphase produced fluid into oil, gas, and water streams."
    attribute operatingPressure : PressureValue;
    attribute operatingTemperature : TemperatureValue;
    attribute liquidResidenceVolume : VolumeValue;
    attribute separationEfficiency : FractionValue;
    port feedIn : MultiphaseFluidInletPort;
    port oilOut : OilExportPort;
    port gasOut : GasExportPort;
    port waterOut : WaterDischargePort;
    port control : ControlPort;
  }

  part def OilStabilizationTrain {
    doc "Stabilizes separated oil by pressure reduction, heating, and removal of light ends."
    attribute heaterDuty : PowerValue;
    attribute targetVaporPressure : PressureValue;
    attribute maximumOilThroughput : FlowRateValue;
    port unstabilizedOilIn : OilExportPort;
    port stabilizedOilOut : OilExportPort;
    port offGasOut : GasExportPort;
    port control : ControlPort;
  }

  part def GasCompressionTrain {
    doc "Compresses and conditions produced gas for export, fuel gas, or flare."
    attribute suctionPressure : PressureValue;
    attribute dischargePressure : PressureValue;
    attribute compressionPower : PowerValue;
    attribute maximumGasThroughput : FlowRateValue;
    port gasIn : GasExportPort;
    port compressedGasOut : GasExportPort;
    port flareReliefOut : FlarePort;
    port power : PowerPort;
    port control : ControlPort;
  }

  part def ProducedWaterTreatment {
    doc "Removes oil and solids from produced water prior to reinjection or discharge."
    attribute treatmentCapacity : FlowRateValue;
    attribute targetOilInWater : ConcentrationValue;
    port producedWaterIn : WaterDischargePort;
    port treatedWaterOut : WaterDischargePort;
    port control : ControlPort;
  }

  part def CrudeOilExportPump {
    doc "Pumps stabilized crude oil to pipeline or tanker export system."
    attribute pumpPower : PowerValue;
    attribute dischargePressure : PressureValue;
    attribute ratedFlow : FlowRateValue;
    port suctionIn : OilExportPort;
    port dischargeOut : OilExportPort;
    port power : PowerPort;
    port control : ControlPort;
  }

  part def ExportPipelineInterface {
    doc "Custody transfer and pipeline interface for stabilized crude oil and export gas."
    attribute oilMeterUncertainty : FractionValue;
    attribute gasMeterUncertainty : FractionValue;
    port oilIn : OilExportPort;
    port gasIn : GasExportPort;
    port control : ControlPort;
  }

  part def PowerGenerationSystem {
    doc "Generates and distributes electrical power for drilling, processing, utilities, safety systems, and accommodation."
    attribute installedCapacity : PowerValue;
    attribute spinningReserve : PowerValue;
    attribute fuelGasConsumption : FlowRateValue;
    port fuelGasIn : GasExportPort;
    port powerOut : PowerPort;
    port control : ControlPort;
  }

  part def FlareAndReliefSystem {
    doc "Safely disposes of relieved hydrocarbon gas during upset, shutdown, or maintenance conditions."
    attribute flareTipCapacity : FlowRateValue;
    attribute knockoutDrumVolume : VolumeValue;
    port reliefGasIn : FlarePort;
    port control : ControlPort;
  }

  part def IntegratedControlAndSafetySystem {
    doc "Coordinates production control, process safeguarding, emergency shutdown, fire and gas detection, and telemetry."
    attribute controlAvailability : FractionValue;
    attribute shutdownDemandResponseTime : Real;
    port platformControl : ControlPort;
    port wellControl[4] : ControlPort;
    port processControl : ControlPort;
    port utilityControl : ControlPort;
  }

  part def LivingQuarters {
    doc "Provides accommodation and life-support services for platform personnel."
    attribute personnelCapacity : Integer;
    attribute emergencyMusterCapacity : Integer;
    port power : PowerPort;
    port control : ControlPort;
  }

  action def ReceiveReservoirFluid {
    in item wellStreams[4] : ReservoirFluid;
    out item combinedStream : ReservoirFluid;
  }

  action def SeparateProducedPhases {
    in item multiphaseFeed : ReservoirFluid;
    out item separatedOil : StabilizedCrudeOil;
    out item separatedGas : ExportGas;
    out item separatedWater : TreatedProducedWater;
  }

  action def StabilizeOil {
    in item separatedOil : StabilizedCrudeOil;
    out item exportQualityOil : StabilizedCrudeOil;
  }

  action def CompressAndConditionGas {
    in item separatedGas : ExportGas;
    out item exportQualityGas : ExportGas;
    out item fuelGas : ExportGas;
  }

  action def TreatProducedWater {
    in item separatedWater : TreatedProducedWater;
    out item compliantWater : TreatedProducedWater;
  }

  action def ExportHydrocarbons {
    in item exportQualityOil : StabilizedCrudeOil;
    in item exportQualityGas : ExportGas;
  }

  action def ExecuteEmergencyShutdown {
    in item shutdownCommand : ControlCommand;
    out item shutdownTelemetry : Telemetry;
  }

  action def PrimaryProductionFunction {
    doc "High-level primary function of the oil platform: safely receive reservoir fluids from wells, separate oil, gas, and water, stabilize and condition hydrocarbons, and export saleable oil and gas while managing produced water and process safety."
    in item reservoirFluidFromWells[4] : ReservoirFluid;
    out item exportedOil : StabilizedCrudeOil;
    out item exportedGas : ExportGas;
    out item treatedWater : TreatedProducedWater;

    action receive : ReceiveReservoirFluid;
    action separate : SeparateProducedPhases;
    action stabilize : StabilizeOil;
    action compress : CompressAndConditionGas;
    action waterTreat : TreatProducedWater;
    action export : ExportHydrocarbons;

    flow reservoirFluidFromWells to receive.wellStreams;
    flow receive.combinedStream to separate.multiphaseFeed;
    flow separate.separatedOil to stabilize.separatedOil;
    flow separate.separatedGas to compress.separatedGas;
    flow separate.separatedWater to waterTreat.separatedWater;
    flow stabilize.exportQualityOil to export.exportQualityOil;
    flow compress.exportQualityGas to export.exportQualityGas;
    flow stabilize.exportQualityOil to exportedOil;
    flow compress.exportQualityGas to exportedGas;
    flow waterTreat.compliantWater to treatedWater;
  }

  state def OilPlatformOperatingState {
    doc "Operational state model for the platform production lifecycle."

    state idle;
    state startup;
    state producing;
    state processUpset;
    state maintenance;
    state emergencyShutdown;

    initial then idle;

    transition idle_to_startup
      first idle
      accept ControlCommand
      if command.targetMode == PlatformMode::startup
      then startup;

    transition startup_to_producing
      first startup
      if true
      then producing;

    transition producing_to_processUpset
      first producing
      accept Telemetry
      if telemetry.severity == AlarmSeverity::warning
      then processUpset;

    transition processUpset_to_producing
      first processUpset
      accept Telemetry
      if telemetry.severity == AlarmSeverity::advisory
      then producing;

    transition producing_to_maintenance
      first producing
      accept ControlCommand
      if command.targetMode == PlatformMode::maintenance
      then maintenance;

    transition maintenance_to_idle
      first maintenance
      accept ControlCommand
      if command.targetMode == PlatformMode::idle
      then idle;

    transition any_to_emergencyShutdown
      first idle, startup, producing, processUpset, maintenance
      accept ControlCommand
      if command.targetMode == PlatformMode::emergencyShutdown or command.priority == AlarmSeverity::critical
      then emergencyShutdown;

    transition emergencyShutdown_to_idle
      first emergencyShutdown
      accept ControlCommand
      if command.targetMode == PlatformMode::idle
      then idle;
  }

  part def OffshoreOilProductionPlatform {
    doc "An integrated offshore oil platform whose primary high-level function is safe production of hydrocarbons from subsea wells by receiving reservoir fluids, separating phases, processing oil and gas to export specification, treating produced water, and maintaining process safety."

    attribute designLife : Real = 25;
    attribute topsidesWeight : Real = 42000;
    attribute waterDepth : LengthValue = 1500;
    attribute nominalOilProduction : FlowRateValue = 6200;
    attribute nominalGasProduction : FlowRateValue = 180000;
    attribute producedWaterCapacity : FlowRateValue = 3500;
    attribute currentMode : PlatformMode = PlatformMode::idle;

    port externalOilExport : OilExportPort;
    port externalGasExport : GasExportPort;
    port externalWaterDischarge : WaterDischargePort;
    port remoteOperationsControl : ControlPort;

    part wells[4] : SubseaWell {
      attribute maximumProductionRate = 1800;
      attribute wellheadPressure = 310;
      attribute wellheadTemperature = 88;
      attribute chokeOpening = 0.65;
    }

    part risers[4] : ProductionRiser {
      attribute waterDepth = 1500;
      attribute innerDiameter = 0.25;
      attribute designPressure = 420;
    }

    part manifold : WellheadManifold {
      attribute manifoldDesignPressure = 420;
      attribute connectedWellCount = 4;
    }

    part separator : ThreePhaseSeparator {
      attribute operatingPressure = 35;
      attribute operatingTemperature = 72;
      attribute liquidResidenceVolume = 480;
      attribute separationEfficiency = 0.985;
    }

    part oilTrain : OilStabilizationTrain {
      attribute heaterDuty = 8.5;
      attribute targetVaporPressure = 0.7;
      attribute maximumOilThroughput = 7000;
    }

    part gasTrain : GasCompressionTrain {
      attribute suctionPressure = 28;
      attribute dischargePressure = 145;
      attribute compressionPower = 32;
      attribute maximumGasThroughput = 220000;
    }

    part waterTreatment : ProducedWaterTreatment {
      attribute treatmentCapacity = 4000;
      attribute targetOilInWater = 25;
    }

    part oilExportPump : CrudeOilExportPump {
      attribute pumpPower = 6.2;
      attribute dischargePressure = 95;
      attribute ratedFlow = 7200;
    }

    part exportInterface : ExportPipelineInterface {
      attribute oilMeterUncertainty = 0.0025;
      attribute gasMeterUncertainty = 0.005;
    }

    part powerGeneration : PowerGenerationSystem {
      attribute installedCapacity = 85;
      attribute spinningReserve = 18;
      attribute fuelGasConsumption = 3200;
    }

    part flareSystem : FlareAndReliefSystem {
      attribute flareTipCapacity = 260000;
      attribute knockoutDrumVolume = 620;
    }

    part controlSystem : IntegratedControlAndSafetySystem {
      attribute controlAvailability = 0.9995;
      attribute shutdownDemandResponseTime = 2.0;
    }

    part accommodation : LivingQuarters {
      attribute personnelCapacity = 140;
      attribute emergencyMusterCapacity = 180;
    }

    perform action productionFunction : PrimaryProductionFunction;
    exhibit state operatingState : OilPlatformOperatingState;

    connection c_well1_to_riser1 connect wells[1].producedFluidOut to risers[1].inlet;
    connection c_well2_to_riser2 connect wells[2].producedFluidOut to risers[2].inlet;
    connection c_well3_to_riser3 connect wells[3].producedFluidOut to risers[3].inlet;
    connection c_well4_to_riser4 connect wells[4].producedFluidOut to risers[4].inlet;

    connection c_riser1_to_manifold connect risers[1].outlet to manifold.wellInlet[1];
    connection c_riser2_to_manifold connect risers[2].outlet to manifold.wellInlet[2];
    connection c_riser3_to_manifold connect risers[3].outlet to manifold.wellInlet[3];
    connection c_riser4_to_manifold connect risers[4].outlet to manifold.wellInlet[4];

    connection c_manifold_to_separator connect manifold.combinedOutlet to separator.feedIn;
    connection c_separator_oil_to_stabilization connect separator.oilOut to oilTrain.unstabilizedOilIn;
    connection c_stabilization_to_pump connect oilTrain.stabilizedOilOut to oilExportPump.suctionIn;
    connection c_pump_to_export_interface connect oilExportPump.dischargeOut to exportInterface.oilIn;
    connection c_export_interface_to_external_oil connect exportInterface.oilIn to externalOilExport;

    connection c_separator_gas_to_compression connect separator.gasOut to gasTrain.gasIn;
    connection c_stabilizer_offgas_to_compression connect oilTrain.offGasOut to gasTrain.gasIn;
    connection c_compression_to_export_interface connect gasTrain.compressedGasOut to exportInterface.gasIn;
    connection c_export_interface_to_external_gas connect exportInterface.gasIn to externalGasExport;

    connection c_separator_water_to_treatment connect separator.waterOut to waterTreatment.producedWaterIn;
    connection c_treatment_to_external_water connect waterTreatment.treatedWaterOut to externalWaterDischarge;

    connection c_gas_to_power_generation connect gasTrain.compressedGasOut to powerGeneration.fuelGasIn;
    connection c_power_to_gas_train connect powerGeneration.powerOut to gasTrain.power;
    connection c_power_to_oil_pump connect powerGeneration.powerOut to oilExportPump.power;
    connection c_power_to_accommodation connect powerGeneration.powerOut to accommodation.power;

    connection c_gas_relief_to_flare connect gasTrain.flareReliefOut to flareSystem.reliefGasIn;

    connection c_remote_to_control connect remoteOperationsControl to controlSystem.platformControl;
    connection c_control_to_manifold connect controlSystem.processControl to manifold.control;
    connection c_control_to_separator connect controlSystem.processControl to separator.control;
    connection c_control_to_oil_train connect controlSystem.processControl to oilTrain.control;
    connection c_control_to_gas_train connect controlSystem.processControl to gasTrain.control;
    connection c_control_to_water_treatment connect controlSystem.processControl to waterTreatment.control;
    connection c_control_to_export_pump connect controlSystem.processControl to oilExportPump.control;
    connection c_control_to_power_generation connect controlSystem.utilityControl to powerGeneration.control;
    connection c_control_to_flare connect controlSystem.utilityControl to flareSystem.control;
    connection c_control_to_accommodation connect controlSystem.utilityControl to accommodation.control;

    connection c_control_to_well1 connect controlSystem.wellControl[1] to wells[1].control;
    connection c_control_to_well2 connect controlSystem.wellControl[2] to wells[2].control;
    connection c_control_to_well3 connect controlSystem.wellControl[3] to wells[3].control;
    connection c_control_to_well4 connect controlSystem.wellControl[4] to wells[4].control;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The offshore oil platform shall safely receive multiphase fluids from subsea wells, separate oil, gas, and produced water, process hydrocarbons to export quality, export stabilized crude oil and conditioned gas, and treat produced water while maintaining safe operation."
    subject platform : OffshoreOilProductionPlatform;

    require constraint {
      platform.nominalOilProduction >= 6000 and
      platform.nominalGasProduction >= 150000 and
      platform.producedWaterCapacity >= 3000
    }
  }

  requirement def SafeSeparationRequirement {
    doc "The platform shall separate produced reservoir fluid with at least 98 percent phase separation efficiency during normal production."
    subject separator : ThreePhaseSeparator;

    require constraint {
      separator.separationEfficiency >= 0.98
    }
  }

  requirement def ExportOilQualityRequirement {
    doc "The oil processing system shall deliver stabilized crude oil with water content no greater than 0.5 percent and vapor pressure no greater than 0.7 bar at the export interface."
    subject oil : StabilizedCrudeOil;

    require constraint {
      oil.waterContent <= 0.005 and oil.vaporPressure <= 0.7
    }
  }

  requirement def ProducedWaterEnvironmentalRequirement {
    doc "The produced water treatment system shall provide treated water with oil-in-water concentration no greater than 30 mg/L before discharge or reinjection."
    subject waterTreatmentSystem : ProducedWaterTreatment;

    require constraint {
      waterTreatmentSystem.targetOilInWater <= 30
    }
  }

  requirement def EmergencyShutdownRequirement {
    doc "The integrated control and safety system shall command emergency shutdown within 2 seconds of a critical shutdown demand."
    subject safetySystem : IntegratedControlAndSafetySystem;

    require constraint {
      safetySystem.shutdownDemandResponseTime <= 2.0
    }
  }

  requirement def PowerAvailabilityRequirement {
    doc "The platform power generation system shall provide sufficient installed capacity and reserve to support process trains, export pumps, utilities, controls, and accommodation during normal production."
    subject powerSystem : PowerGenerationSystem;

    require constraint {
      powerSystem.installedCapacity >= 80 and powerSystem.spinningReserve >= 15
    }
  }

  requirement def FlareCapacityRequirement {
    doc "The flare and relief system shall safely handle the maximum credible gas relief flow from compression and stabilization systems."
    subject flare : FlareAndReliefSystem;

    require constraint {
      flare.flareTipCapacity >= 250000
    }
  }

  part oilPlatform : OffshoreOilProductionPlatform;

  satisfy PrimaryFunctionRequirement by oilPlatform;
  satisfy SafeSeparationRequirement by oilPlatform.separator;
  satisfy ProducedWaterEnvironmentalRequirement by oilPlatform.waterTreatment;
  satisfy EmergencyShutdownRequirement by oilPlatform.controlSystem;
  satisfy PowerAvailabilityRequirement by oilPlatform.powerGeneration;
  satisfy FlareCapacityRequirement by oilPlatform.flareSystem;
}
