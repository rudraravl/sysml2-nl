package InternationalSpaceStationModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def MassValue {
    :>> num : Real;
    unit = "kg";
  }

  value def LengthValue {
    :>> num : Real;
    unit = "m";
  }

  value def PowerValue {
    :>> num : Real;
    unit = "W";
  }

  value def EnergyValue {
    :>> num : Real;
    unit = "J";
  }

  value def VoltageValue {
    :>> num : Real;
    unit = "V";
  }

  value def TemperatureValue {
    :>> num : Real;
    unit = "degC";
  }

  value def PressureValue {
    :>> num : Real;
    unit = "kPa";
  }

  value def FlowRateValue {
    :>> num : Real;
    unit = "kg/h";
  }

  value def DataRateValue {
    :>> num : Real;
    unit = "Mb/s";
  }

  value def VolumeValue {
    :>> num : Real;
    unit = "m^3";
  }

  value def TimeValue {
    :>> num : Real;
    unit = "s";
  }

  item def ElectricalPower {
    attribute voltage : VoltageValue;
    attribute availablePower : PowerValue;
  }

  item def ThermalFluid {
    attribute temperature : TemperatureValue;
    attribute flowRate : FlowRateValue;
  }

  item def BreathingAtmosphere {
    attribute oxygenPartialPressure : PressureValue;
    attribute cabinPressure : PressureValue;
    attribute carbonDioxideLevel : Real;
    attribute humidity : Real;
  }

  item def CrewMember {
    attribute identifier : String;
    attribute metabolicOxygenDemand : FlowRateValue;
    attribute potableWaterDemand : FlowRateValue;
  }

  item def PayloadData {
    attribute scienceDataRate : DataRateValue;
    attribute telemetryDataRate : DataRateValue;
  }

  item def CommandData {
    attribute commandRate : DataRateValue;
    attribute authenticated : Boolean;
  }

  item def VisitingVehicle {
    attribute vehicleName : String;
    attribute pressurizedCargoMass : MassValue;
    attribute propellantTransferMass : MassValue;
  }

  item def OrbitState {
    attribute altitude : LengthValue;
    attribute inclinationDeg : Real;
    attribute velocity : Real;
  }

  port def PowerPort {
    out item power : ElectricalPower;
  }

  port def PowerLoadPort {
    in item power : ElectricalPower;
  }

  port def AtmosphereSupplyPort {
    out item atmosphere : BreathingAtmosphere;
  }

  port def AtmosphereReturnPort {
    in item atmosphere : BreathingAtmosphere;
  }

  port def ThermalSupplyPort {
    out item coolant : ThermalFluid;
  }

  port def ThermalReturnPort {
    in item coolant : ThermalFluid;
  }

  port def DataDownlinkPort {
    out item data : PayloadData;
  }

  port def DataUplinkPort {
    in item command : CommandData;
  }

  port def DockingPort {
    inout item vehicle : VisitingVehicle;
  }

  port def CrewTransferPort {
    inout item crew : CrewMember;
  }

  part def SolarArrayWing {
    attribute deployedArea : Real;
    attribute generatedPower : PowerValue;
    attribute sunTrackingEnabled : Boolean;

    port generatedPowerOut : PowerPort;

    action def TrackSun {
      in item orbit : OrbitState;
      out item power : ElectricalPower;
    }

    state def SolarArrayState {
      state Stowed;
      state Deploying;
      state SunTracking;
      state SafeHold;

      transition first Stowed;
      transition Stowed to Deploying accept deployCommand;
      transition Deploying to SunTracking accept deploymentComplete;
      transition SunTracking to SafeHold accept faultDetected;
      transition SafeHold to SunTracking accept faultCleared;
    }
  }

  part def BatteryAssembly {
    attribute storedEnergy : EnergyValue;
    attribute maximumEnergy : EnergyValue;
    attribute chargePowerLimit : PowerValue;
    attribute dischargePowerLimit : PowerValue;

    port chargeInput : PowerLoadPort;
    port dischargeOutput : PowerPort;

    action def BalanceCharge {
      in item solarPower : ElectricalPower;
      out item conditionedPower : ElectricalPower;
    }
  }

  part def PowerManagementAndDistribution {
    attribute busVoltage : VoltageValue;
    attribute continuousLoadCapacity : PowerValue;
    attribute essentialLoadReserve : PowerValue;

    port solarInput : PowerLoadPort;
    port batteryInput : PowerLoadPort;
    port regulatedPowerOut : PowerPort;

    action def AllocatePower {
      in item generated : ElectricalPower;
      in item stored : ElectricalPower;
      out item distributed : ElectricalPower;
    }
  }

  part def PressurizedModule {
    attribute moduleName : String;
    attribute habitableVolume : VolumeValue;
    attribute structuralMass : MassValue;
    attribute nominalPressure : PressureValue;
    attribute nominalTemperature : TemperatureValue;

    port powerIn : PowerLoadPort;
    port atmosphereIn : AtmosphereSupplyPort;
    port atmosphereOut : AtmosphereReturnPort;
    port thermalIn : ThermalSupplyPort;
    port thermalOut : ThermalReturnPort;
    port crewHatch : CrewTransferPort;
    port dataOut : DataDownlinkPort;
    port commandIn : DataUplinkPort;
  }

  part def EnvironmentalControlAndLifeSupport {
    attribute oxygenGenerationRate : FlowRateValue;
    attribute carbonDioxideRemovalRate : FlowRateValue;
    attribute potableWaterRecoveryRate : FlowRateValue;
    attribute cabinPressureSetpoint : PressureValue;
    attribute cabinTemperatureSetpoint : TemperatureValue;

    port powerIn : PowerLoadPort;
    port atmosphereSupply : AtmosphereSupplyPort;
    port atmosphereReturn : AtmosphereReturnPort;

    action def MaintainAtmosphere {
      in item returnedAtmosphere : BreathingAtmosphere;
      out item conditionedAtmosphere : BreathingAtmosphere;
    }

    action def RecycleWater {
      in item humidityCondensate : ThermalFluid;
      out item potableWater : ThermalFluid;
    }

    state def LifeSupportState {
      state Nominal;
      state ElevatedCO2;
      state LowPressure;
      state EmergencyMode;

      transition first Nominal;
      transition Nominal to ElevatedCO2 accept co2AboveLimit;
      transition ElevatedCO2 to Nominal accept co2Recovered;
      transition Nominal to LowPressure accept pressureBelowLimit;
      transition LowPressure to EmergencyMode accept leakRateCritical;
      transition LowPressure to Nominal accept pressureRecovered;
      transition EmergencyMode to Nominal accept emergencyResolved;
    }
  }

  part def ThermalControlSystem {
    attribute internalLoopTemperature : TemperatureValue;
    attribute externalRadiatorTemperature : TemperatureValue;
    attribute heatRejectionCapacity : PowerValue;

    port powerIn : PowerLoadPort;
    port coolantSupply : ThermalSupplyPort;
    port coolantReturn : ThermalReturnPort;

    action def RejectHeat {
      in item warmCoolant : ThermalFluid;
      out item cooledCoolant : ThermalFluid;
    }
  }

  part def CommandAndDataHandling {
    attribute onboardStorageCapacity : Real;
    attribute internalNetworkRate : DataRateValue;
    attribute faultManagementEnabled : Boolean;

    port powerIn : PowerLoadPort;
    port payloadDataIn : DataDownlinkPort;
    port commandIn : DataUplinkPort;
    port telemetryOut : DataDownlinkPort;

    action def RouteTelemetry {
      in item payloadData : PayloadData;
      in item subsystemStatus : PayloadData;
      out item downlinkData : PayloadData;
    }

    action def ExecuteCommand {
      in item command : CommandData;
      out item acceptedCommand : CommandData;
    }
  }

  part def CommunicationSystem {
    attribute sBandRate : DataRateValue;
    attribute kuBandRate : DataRateValue;
    attribute groundLinkAvailable : Boolean;

    port powerIn : PowerLoadPort;
    port commandUplink : DataUplinkPort;
    port telemetryDownlink : DataDownlinkPort;

    action def CommunicateWithGround {
      in item command : CommandData;
      in item telemetry : PayloadData;
      out item acknowledgedCommand : CommandData;
      out item transmittedData : PayloadData;
    }
  }

  part def GuidanceNavigationAndControl {
    attribute attitudeKnowledgeAccuracyDeg : Real;
    attribute orbitAltitudeSetpoint : LengthValue;
    attribute momentumStorageCapacity : Real;

    port powerIn : PowerLoadPort;
    port commandIn : DataUplinkPort;

    action def MaintainAttitude {
      in item orbit : OrbitState;
      out item correctedOrbit : OrbitState;
    }

    state def AttitudeControlState {
      state LocalVerticalLocalHorizontal;
      state MicrogravityMode;
      state ReboostPreparation;
      state ContingencyFreeDrift;

      transition first LocalVerticalLocalHorizontal;
      transition LocalVerticalLocalHorizontal to MicrogravityMode accept scienceQuietPeriod;
      transition MicrogravityMode to LocalVerticalLocalHorizontal accept sciencePeriodComplete;
      transition LocalVerticalLocalHorizontal to ReboostPreparation accept reboostCommand;
      transition ReboostPreparation to LocalVerticalLocalHorizontal accept reboostComplete;
      transition LocalVerticalLocalHorizontal to ContingencyFreeDrift accept controlFault;
      transition ContingencyFreeDrift to LocalVerticalLocalHorizontal accept controlRestored;
    }
  }

  part def DockingNode {
    attribute nodeName : String;
    attribute availableBerthingPorts : Integer;
    attribute hatchPressureEqualized : Boolean;

    port powerIn : PowerLoadPort;
    port crewTransfer : CrewTransferPort;
    port visitingVehiclePort : DockingPort;
    port commandIn : DataUplinkPort;

    action def SupportDocking {
      inout item vehicle : VisitingVehicle;
      out item dockedVehicle : VisitingVehicle;
    }
  }

  part def PayloadRack {
    attribute rackName : String;
    attribute experimentPowerDemand : PowerValue;
    attribute experimentDataRate : DataRateValue;
    attribute microgravitySensitive : Boolean;

    port powerIn : PowerLoadPort;
    port thermalIn : ThermalSupplyPort;
    port thermalOut : ThermalReturnPort;
    port dataOut : DataDownlinkPort;
    port commandIn : DataUplinkPort;

    action def ConductExperiment {
      in item command : CommandData;
      out item scienceData : PayloadData;
    }
  }

  part def CrewHabitationSystem {
    attribute maximumCrewCapacity : Integer;
    attribute nominalCrewCapacity : Integer;
    attribute sleepStations : Integer;
    attribute exerciseDevices : Integer;

    port powerIn : PowerLoadPort;
    port atmosphereIn : AtmosphereSupplyPort;
    port atmosphereOut : AtmosphereReturnPort;
    port crewAccess : CrewTransferPort;

    action def SupportCrewDailyOperations {
      inout item crew : CrewMember;
      out item crewSupported : CrewMember;
    }
  }

  part def InternationalSpaceStation {
    attribute totalMass : MassValue = 420000;
    attribute pressurizedVolume : VolumeValue = 915;
    attribute nominalCrew : Integer = 7;
    attribute nominalAltitude : LengthValue = 420000;
    attribute primaryFunction : String =
      "Provide a permanently crewed orbital laboratory and habitation platform for microgravity research, Earth and space observation, technology demonstration, international operations, and spacecraft servicing in low Earth orbit.";

    port groundCommandIn : DataUplinkPort;
    port groundTelemetryOut : DataDownlinkPort;
    port crewAccessPort : CrewTransferPort;
    port visitingVehicleInterface : DockingPort;

    part portTrussSolarAlpha : SolarArrayWing {
      attribute generatedPower = 30000;
      attribute deployedArea = 850;
      attribute sunTrackingEnabled = true;
    }

    part starboardTrussSolarBeta : SolarArrayWing {
      attribute generatedPower = 30000;
      attribute deployedArea = 850;
      attribute sunTrackingEnabled = true;
    }

    part batteryAssembly : BatteryAssembly {
      attribute maximumEnergy = 400000000;
      attribute storedEnergy = 320000000;
      attribute chargePowerLimit = 45000;
      attribute dischargePowerLimit = 45000;
    }

    part powerDistribution : PowerManagementAndDistribution {
      attribute busVoltage = 120;
      attribute continuousLoadCapacity = 90000;
      attribute essentialLoadReserve = 25000;
    }

    part usLaboratory : PressurizedModule {
      attribute moduleName = "Destiny Laboratory";
      attribute habitableVolume = 106;
      attribute structuralMass = 14500;
      attribute nominalPressure = 101.3;
      attribute nominalTemperature = 22;
    }

    part europeanLaboratory : PressurizedModule {
      attribute moduleName = "Columbus Laboratory";
      attribute habitableVolume = 75;
      attribute structuralMass = 12800;
      attribute nominalPressure = 101.3;
      attribute nominalTemperature = 22;
    }

    part japaneseExperimentModule : PressurizedModule {
      attribute moduleName = "Kibo Pressurized Module";
      attribute habitableVolume = 140;
      attribute structuralMass = 15000;
      attribute nominalPressure = 101.3;
      attribute nominalTemperature = 22;
    }

    part russianServiceModule : PressurizedModule {
      attribute moduleName = "Zvezda Service Module";
      attribute habitableVolume = 89;
      attribute structuralMass = 19000;
      attribute nominalPressure = 101.3;
      attribute nominalTemperature = 22;
    }

    part lifeSupport : EnvironmentalControlAndLifeSupport {
      attribute oxygenGenerationRate = 0.84;
      attribute carbonDioxideRemovalRate = 1.10;
      attribute potableWaterRecoveryRate = 6.0;
      attribute cabinPressureSetpoint = 101.3;
      attribute cabinTemperatureSetpoint = 22;
    }

    part thermalControl : ThermalControlSystem {
      attribute internalLoopTemperature = 4;
      attribute externalRadiatorTemperature = -20;
      attribute heatRejectionCapacity = 70000;
    }

    part commandDataHandling : CommandAndDataHandling {
      attribute onboardStorageCapacity = 12000;
      attribute internalNetworkRate = 1000;
      attribute faultManagementEnabled = true;
    }

    part communications : CommunicationSystem {
      attribute sBandRate = 2;
      attribute kuBandRate = 300;
      attribute groundLinkAvailable = true;
    }

    part navigationControl : GuidanceNavigationAndControl {
      attribute attitudeKnowledgeAccuracyDeg = 0.1;
      attribute orbitAltitudeSetpoint = 420000;
      attribute momentumStorageCapacity = 3500;
    }

    part nodeForward : DockingNode {
      attribute nodeName = "Harmony Forward Node";
      attribute availableBerthingPorts = 4;
      attribute hatchPressureEqualized = true;
    }

    part nodeAft : DockingNode {
      attribute nodeName = "Unity Aft Node";
      attribute availableBerthingPorts = 3;
      attribute hatchPressureEqualized = true;
    }

    part humanResearchRack : PayloadRack {
      attribute rackName = "Human Research Facility";
      attribute experimentPowerDemand = 2500;
      attribute experimentDataRate = 20;
      attribute microgravitySensitive = true;
    }

    part materialsScienceRack : PayloadRack {
      attribute rackName = "Materials Science Research Rack";
      attribute experimentPowerDemand = 3000;
      attribute experimentDataRate = 40;
      attribute microgravitySensitive = true;
    }

    part earthObservationRack : PayloadRack {
      attribute rackName = "Earth Observation Payload Rack";
      attribute experimentPowerDemand = 1800;
      attribute experimentDataRate = 120;
      attribute microgravitySensitive = false;
    }

    part habitation : CrewHabitationSystem {
      attribute maximumCrewCapacity = 10;
      attribute nominalCrewCapacity = 7;
      attribute sleepStations = 7;
      attribute exerciseDevices = 2;
    }

    connect portTrussSolarAlpha.generatedPowerOut to powerDistribution.solarInput;
    connect starboardTrussSolarBeta.generatedPowerOut to powerDistribution.solarInput;
    connect powerDistribution.regulatedPowerOut to batteryAssembly.chargeInput;
    connect batteryAssembly.dischargeOutput to powerDistribution.batteryInput;

    connect powerDistribution.regulatedPowerOut to usLaboratory.powerIn;
    connect powerDistribution.regulatedPowerOut to europeanLaboratory.powerIn;
    connect powerDistribution.regulatedPowerOut to japaneseExperimentModule.powerIn;
    connect powerDistribution.regulatedPowerOut to russianServiceModule.powerIn;
    connect powerDistribution.regulatedPowerOut to lifeSupport.powerIn;
    connect powerDistribution.regulatedPowerOut to thermalControl.powerIn;
    connect powerDistribution.regulatedPowerOut to commandDataHandling.powerIn;
    connect powerDistribution.regulatedPowerOut to communications.powerIn;
    connect powerDistribution.regulatedPowerOut to navigationControl.powerIn;
    connect powerDistribution.regulatedPowerOut to nodeForward.powerIn;
    connect powerDistribution.regulatedPowerOut to nodeAft.powerIn;
    connect powerDistribution.regulatedPowerOut to habitation.powerIn;
    connect powerDistribution.regulatedPowerOut to humanResearchRack.powerIn;
    connect powerDistribution.regulatedPowerOut to materialsScienceRack.powerIn;
    connect powerDistribution.regulatedPowerOut to earthObservationRack.powerIn;

    connect lifeSupport.atmosphereSupply to usLaboratory.atmosphereIn;
    connect lifeSupport.atmosphereSupply to europeanLaboratory.atmosphereIn;
    connect lifeSupport.atmosphereSupply to japaneseExperimentModule.atmosphereIn;
    connect lifeSupport.atmosphereSupply to russianServiceModule.atmosphereIn;
    connect lifeSupport.atmosphereSupply to habitation.atmosphereIn;

    connect usLaboratory.atmosphereOut to lifeSupport.atmosphereReturn;
    connect europeanLaboratory.atmosphereOut to lifeSupport.atmosphereReturn;
    connect japaneseExperimentModule.atmosphereOut to lifeSupport.atmosphereReturn;
    connect russianServiceModule.atmosphereOut to lifeSupport.atmosphereReturn;
    connect habitation.atmosphereOut to lifeSupport.atmosphereReturn;

    connect thermalControl.coolantSupply to usLaboratory.thermalIn;
    connect thermalControl.coolantSupply to europeanLaboratory.thermalIn;
    connect thermalControl.coolantSupply to japaneseExperimentModule.thermalIn;
    connect thermalControl.coolantSupply to russianServiceModule.thermalIn;
    connect thermalControl.coolantSupply to humanResearchRack.thermalIn;
    connect thermalControl.coolantSupply to materialsScienceRack.thermalIn;
    connect thermalControl.coolantSupply to earthObservationRack.thermalIn;

    connect usLaboratory.thermalOut to thermalControl.coolantReturn;
    connect europeanLaboratory.thermalOut to thermalControl.coolantReturn;
    connect japaneseExperimentModule.thermalOut to thermalControl.coolantReturn;
    connect russianServiceModule.thermalOut to thermalControl.coolantReturn;
    connect humanResearchRack.thermalOut to thermalControl.coolantReturn;
    connect materialsScienceRack.thermalOut to thermalControl.coolantReturn;
    connect earthObservationRack.thermalOut to thermalControl.coolantReturn;

    connect humanResearchRack.dataOut to commandDataHandling.payloadDataIn;
    connect materialsScienceRack.dataOut to commandDataHandling.payloadDataIn;
    connect earthObservationRack.dataOut to commandDataHandling.payloadDataIn;
    connect commandDataHandling.telemetryOut to communications.telemetryDownlink;
    connect communications.telemetryDownlink to groundTelemetryOut;
    connect groundCommandIn to communications.commandUplink;
    connect communications.commandUplink to commandDataHandling.commandIn;
    connect commandDataHandling.commandIn to humanResearchRack.commandIn;
    connect commandDataHandling.commandIn to materialsScienceRack.commandIn;
    connect commandDataHandling.commandIn to earthObservationRack.commandIn;
    connect commandDataHandling.commandIn to navigationControl.commandIn;
    connect commandDataHandling.commandIn to nodeForward.commandIn;
    connect commandDataHandling.commandIn to nodeAft.commandIn;

    connect crewAccessPort to nodeForward.crewTransfer;
    connect nodeForward.crewTransfer to habitation.crewAccess;
    connect nodeForward.crewTransfer to usLaboratory.crewHatch;
    connect nodeForward.crewTransfer to europeanLaboratory.crewHatch;
    connect nodeForward.crewTransfer to japaneseExperimentModule.crewHatch;
    connect nodeAft.crewTransfer to russianServiceModule.crewHatch;

    connect visitingVehicleInterface to nodeForward.visitingVehiclePort;
    connect visitingVehicleInterface to nodeAft.visitingVehiclePort;

    action def OperateOrbitalLaboratory {
      in item crew : CrewMember;
      in item groundCommand : CommandData;
      in item visitingVehicle : VisitingVehicle;
      out item scienceTelemetry : PayloadData;
      out item maintainedOrbit : OrbitState;

      first start;
      then maintainPower;
      then sustainCrew;
      then conductResearch;
      then transmitResults;
      then manageOrbit;
      then done;

      action maintainPower : PowerManagementAndDistribution::AllocatePower;
      action sustainCrew : EnvironmentalControlAndLifeSupport::MaintainAtmosphere;
      action conductResearch : PayloadRack::ConductExperiment;
      action transmitResults : CommunicationSystem::CommunicateWithGround;
      action manageOrbit : GuidanceNavigationAndControl::MaintainAttitude;
    }

    state def StationOperationalState {
      state AssemblyComplete;
      state CrewOccupiedNominal;
      state ScienceOperations;
      state VisitingVehicleOperations;
      state ReboostOperations;
      state ContingencySafeHaven;
      state UncrewedSurvival;

      transition first CrewOccupiedNominal;
      transition CrewOccupiedNominal to ScienceOperations accept experimentTimelineActive;
      transition ScienceOperations to CrewOccupiedNominal accept experimentTimelineComplete;
      transition CrewOccupiedNominal to VisitingVehicleOperations accept dockingSequenceStarted;
      transition VisitingVehicleOperations to CrewOccupiedNominal accept vehicleDepartureComplete;
      transition CrewOccupiedNominal to ReboostOperations accept reboostPlanned;
      transition ReboostOperations to CrewOccupiedNominal accept orbitRestored;
      transition CrewOccupiedNominal to ContingencySafeHaven accept criticalAlarm;
      transition ContingencySafeHaven to CrewOccupiedNominal accept contingencyResolved;
      transition CrewOccupiedNominal to UncrewedSurvival accept crewDeparture;
      transition UncrewedSurvival to CrewOccupiedNominal accept crewArrival;
    }
  }

  requirement def OrbitalLaboratoryFunction {
    subject station : InternationalSpaceStation;
    doc /* The station shall provide an integrated, continuously operated low Earth orbit platform for crew habitation, microgravity research, Earth observation, technology demonstration, and spacecraft logistics. */
    require constraint {
      station.nominalCrew >= 7 and
      station.pressurizedVolume >= 900 and
      station.nominalAltitude >= 350000
    }
  }

  requirement def CrewLifeSupportRequirement {
    subject station : InternationalSpaceStation;
    doc /* The station shall maintain a habitable pressurized environment for the nominal crew during orbital operations. */
    require constraint {
      station.lifeSupport.cabinPressureSetpoint >= 95 and
      station.lifeSupport.cabinPressureSetpoint <= 103 and
      station.lifeSupport.cabinTemperatureSetpoint >= 18 and
      station.lifeSupport.cabinTemperatureSetpoint <= 27 and
      station.lifeSupport.oxygenGenerationRate >= 0.70
    }
  }

  requirement def PowerRequirement {
    subject station : InternationalSpaceStation;
    doc /* The station electrical power system shall generate, store, and distribute sufficient regulated power for crew systems, payloads, thermal control, communication, and guidance functions. */
    require constraint {
      station.powerDistribution.continuousLoadCapacity >= 75000 and
      station.batteryAssembly.maximumEnergy >= 300000000
    }
  }

  requirement def ResearchRequirement {
    subject station : InternationalSpaceStation;
    doc /* The station shall support simultaneous scientific payload operations with power, cooling, command, and telemetry interfaces. */
    require constraint {
      station.humanResearchRack.experimentPowerDemand +
      station.materialsScienceRack.experimentPowerDemand +
      station.earthObservationRack.experimentPowerDemand <=
      station.powerDistribution.continuousLoadCapacity
    }
  }

  requirement def CommunicationsRequirement {
    subject station : InternationalSpaceStation;
    doc /* The station shall provide bidirectional communications for ground command, health telemetry, crew operations, and payload data return. */
    require constraint {
      station.communications.kuBandRate >= 100 and
      station.communications.sBandRate >= 1
    }
  }

  requirement def VisitingVehicleSupportRequirement {
    subject station : InternationalSpaceStation;
    doc /* The station shall provide docking or berthing interfaces for crew transport, cargo delivery, cargo disposal, and orbital logistics. */
    require constraint {
      station.nodeForward.availableBerthingPorts + station.nodeAft.availableBerthingPorts >= 4
    }
  }

  requirement def ThermalControlRequirement {
    subject station : InternationalSpaceStation;
    doc /* The station shall collect internal heat loads and reject heat to space while maintaining crew and payload thermal environments. */
    require constraint {
      station.thermalControl.heatRejectionCapacity >= 60000 and
      station.thermalControl.internalLoopTemperature >= 0 and
      station.thermalControl.internalLoopTemperature <= 10
    }
  }

  satisfy OrbitalLaboratoryFunction by InternationalSpaceStation;
  satisfy CrewLifeSupportRequirement by InternationalSpaceStation::lifeSupport;
  satisfy PowerRequirement by InternationalSpaceStation::powerDistribution;
  satisfy ResearchRequirement by InternationalSpaceStation::humanResearchRack;
  satisfy CommunicationsRequirement by InternationalSpaceStation::communications;
  satisfy VisitingVehicleSupportRequirement by InternationalSpaceStation::nodeForward;
  satisfy ThermalControlRequirement by InternationalSpaceStation::thermalControl;
}