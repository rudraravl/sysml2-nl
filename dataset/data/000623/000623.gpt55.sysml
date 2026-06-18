package HighEmissivityAluminiferousLuminescentSubstrateModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Emissivity :> Real {
    doc "Dimensionless hemispherical emissivity."
  }

  attribute def Reflectance :> Real {
    doc "Dimensionless optical reflectance."
  }

  attribute def Transmittance :> Real {
    doc "Dimensionless optical transmittance."
  }

  attribute def QuantumYield :> Real {
    doc "Dimensionless ratio of emitted photons to absorbed photons."
  }

  attribute def AluminumMassFraction :> Real {
    doc "Dimensionless mass fraction of aluminum-bearing phase in the substrate."
  }

  attribute def DegradationIndex :> Real {
    doc "Dimensionless health metric; 0.0 is pristine and 1.0 is end of useful life."
  }

  attribute def SurfaceRoughness {
    attribute value : Real;
    attribute unit : String = "um";
  }

  attribute def Wavelength {
    attribute value : Real;
    attribute unit : String = "nm";
  }

  attribute def Irradiance {
    attribute value : Real;
    attribute unit : String = "W/m^2";
  }

  attribute def Radiance {
    attribute value : Real;
    attribute unit : String = "W/(m^2*sr)";
  }

  attribute def RadiantFlux {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def HeatFlux {
    attribute value : Real;
    attribute unit : String = "W/m^2";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "K";
  }

  attribute def Area {
    attribute value : Real;
    attribute unit : String = "m^2";
  }

  attribute def Thickness {
    attribute value : Real;
    attribute unit : String = "um";
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Current {
    attribute value : Real;
    attribute unit : String = "A";
  }

  attribute def Power {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "s";
  }

  item def IncidentRadiation {
    attribute irradiance : Irradiance;
    attribute meanWavelength : Wavelength;
    attribute spectralBandLow : Wavelength;
    attribute spectralBandHigh : Wavelength;
    attribute incidenceAngle : Real;
  }

  item def AbsorbedEnergy {
    attribute absorbedFlux : RadiantFlux;
    attribute absorbedHeatFlux : HeatFlux;
  }

  item def ThermalEnergy {
    attribute heatFlow : Power;
    attribute temperature : Temperature;
  }

  item def LuminescentRadiation {
    attribute radiantFlux : RadiantFlux;
    attribute peakWavelength : Wavelength;
    attribute spectralBandLow : Wavelength;
    attribute spectralBandHigh : Wavelength;
    attribute radiance : Radiance;
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  item def ControlCommand {
    attribute enableEmission : Boolean;
    attribute requestedRadiantFlux : RadiantFlux;
    attribute requestedSurfaceTemperature : Temperature;
  }

  item def HealthTelemetry {
    attribute measuredTemperature : Temperature;
    attribute measuredEmissivity : Emissivity;
    attribute measuredRadiantFlux : RadiantFlux;
    attribute degradation : DegradationIndex;
    attribute faultPresent : Boolean;
  }

  port def OpticalInputPort {
    in item incident : IncidentRadiation;
  }

  port def OpticalEmissionPort {
    out item emitted : LuminescentRadiation;
  }

  port def ThermalPort {
    inout item thermalFlow : ThermalEnergy;
  }

  port def ElectricalInputPort {
    in item supply : ElectricalPower;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def TelemetryPort {
    out item telemetry : HealthTelemetry;
  }

  part def AluminumEnrichedCarrierMatrix {
    attribute aluminumMassFraction : AluminumMassFraction = 0.72;
    attribute matrixThickness : Thickness = (value = 750.0; unit = "um");
    attribute surfaceRoughnessRa : SurfaceRoughness = (value = 1.6; unit = "um");
    attribute thermalConductivity : Real = 165.0;
    attribute oxidationStabilized : Boolean = true;

    port frontThermal : ThermalPort;
    port rearThermal : ThermalPort;
  }

  part def HighEmissivityOxideCeramicLayer {
    attribute effectiveHemisphericalEmissivity : Emissivity = 0.94;
    attribute solarReflectance : Reflectance = 0.18;
    attribute coatingThickness : Thickness = (value = 85.0; unit = "um");
    attribute operatingTemperatureLimit : Temperature = (value = 673.0; unit = "K");
    attribute aluminaSpinelContent : AluminumMassFraction = 0.61;

    port incidentOptical : OpticalInputPort;
    port thermalInterface : ThermalPort;
  }

  part def LuminescentDopantLattice {
    attribute quantumYield : QuantumYield = 0.43;
    attribute excitationBandLow : Wavelength = (value = 360.0; unit = "nm");
    attribute excitationBandHigh : Wavelength = (value = 470.0; unit = "nm");
    attribute emissionPeak : Wavelength = (value = 625.0; unit = "nm");
    attribute emissionBandLow : Wavelength = (value = 560.0; unit = "nm");
    attribute emissionBandHigh : Wavelength = (value = 720.0; unit = "nm");
    attribute dopantLockedInAluminiferousSites : Boolean = true;

    port absorbedEnergyIn : ThermalPort;
    port luminescenceOut : OpticalEmissionPort;
  }

  part def TransparentProtectiveOvercoat {
    attribute visibleTransmittance : Transmittance = 0.89;
    attribute infraredEmissivityContribution : Emissivity = 0.05;
    attribute overcoatThickness : Thickness = (value = 22.0; unit = "um");
    attribute abrasionResistant : Boolean = true;
    attribute chemicallySealed : Boolean = true;

    port externalOpticalIn : OpticalInputPort;
    port externalOpticalOut : OpticalEmissionPort;
    port internalOpticalIn : OpticalInputPort;
    port internalOpticalOut : OpticalEmissionPort;
  }

  part def BackingHeatSpreader {
    attribute spreaderArea : Area = (value = 0.25; unit = "m^2");
    attribute rearSurfaceEmissivity : Emissivity = 0.81;
    attribute thermalStorageCapacity : Real = 920.0;

    port laminateThermal : ThermalPort;
    port mountingThermal : ThermalPort;
  }

  part def EdgeSeal {
    attribute moistureIngressRate : Real = 0.002;
    attribute sealContinuityVerified : Boolean = true;
    attribute sealWidth : Thickness = (value = 2500.0; unit = "um");

    port sealThermal : ThermalPort;
  }

  part def TemperatureSensorArray {
    attribute sensorCount : Integer = 16;
    attribute samplePeriod : TimeDuration = (value = 0.25; unit = "s");
    attribute measurementUncertainty : Temperature = (value = 1.5; unit = "K");

    port sensedThermal : ThermalPort;
    port telemetryOut : TelemetryPort;
  }

  part def OpticalEmissionSensor {
    attribute measurementBandLow : Wavelength = (value = 540.0; unit = "nm");
    attribute measurementBandHigh : Wavelength = (value = 760.0; unit = "nm");
    attribute fluxResolution : RadiantFlux = (value = 0.05; unit = "W");

    port sampledEmissionIn : OpticalInputPort;
    port telemetryOut : TelemetryPort;
  }

  part def ExcitationController {
    attribute maximumElectricalPower : Power = (value = 18.0; unit = "W");
    attribute nominalDriveVoltage : Voltage = (value = 24.0; unit = "V");
    attribute enabled : Boolean = false;

    port electricalIn : ElectricalInputPort;
    port commandIn : CommandPort;
    port telemetryIn : TelemetryPort;
    port controllerTelemetryOut : TelemetryPort;
    port controlledThermalOut : ThermalPort;
  }

  part def HighEmissivityAluminiferousLuminescentSubstrate {
    doc "A layered aluminiferous substrate that combines an aluminum-enriched heat-spreading carrier, a high-emissivity oxide ceramic surface, and a luminescent dopant lattice to absorb incident energy and emit controlled thermal and visible/near-visible radiation."

    attribute activeArea : Area = (value = 0.25; unit = "m^2");
    attribute effectiveHemisphericalEmissivity : Emissivity = 0.93;
    attribute nominalOperatingTemperature : Temperature = (value = 333.0; unit = "K");
    attribute maximumSafeSurfaceTemperature : Temperature = (value = 393.0; unit = "K");
    attribute minimumUsefulRadiantFlux : RadiantFlux = (value = 7.5; unit = "W");
    attribute primaryFunctionStatement : String = "Convert absorbed optical, thermal, or low electrical excitation energy into stable high-emissivity thermal radiation and aluminiferous luminescent emission for passive/active surface signaling and radiative thermal management.";

    port opticalIn : OpticalInputPort;
    port opticalOut : OpticalEmissionPort;
    port thermalInterface : ThermalPort;
    port electricalIn : ElectricalInputPort;
    port commandIn : CommandPort;
    port telemetryOut : TelemetryPort;

    part overcoat : TransparentProtectiveOvercoat;
    part emissiveLayer : HighEmissivityOxideCeramicLayer;
    part dopantLattice : LuminescentDopantLattice;
    part carrierMatrix : AluminumEnrichedCarrierMatrix;
    part heatSpreader : BackingHeatSpreader;
    part edgeSeal : EdgeSeal;
    part temperatureSensors : TemperatureSensorArray;
    part opticalSensor : OpticalEmissionSensor;
    part controller : ExcitationController;

    connection opticalIncidentPath connect opticalIn to overcoat.externalOpticalIn;
    connection overcoatToEmissiveLayer connect overcoat.internalOpticalOut to emissiveLayer.incidentOptical;
    connection emissionToOvercoat connect dopantLattice.luminescenceOut to overcoat.internalOpticalIn;
    connection emittedOutputPath connect overcoat.externalOpticalOut to opticalOut;

    connection emissiveLayerThermalToCarrier connect emissiveLayer.thermalInterface to carrierMatrix.frontThermal;
    connection carrierToHeatSpreader connect carrierMatrix.rearThermal to heatSpreader.laminateThermal;
    connection heatSpreaderToExternalThermal connect heatSpreader.mountingThermal to thermalInterface;
    connection edgeSealThermalTie connect edgeSeal.sealThermal to carrierMatrix.frontThermal;

    connection sensorThermalPickup connect temperatureSensors.sensedThermal to carrierMatrix.frontThermal;
    connection opticalFeedbackPath connect opticalIn to opticalSensor.sampledEmissionIn;
    connection electricalSupplyPath connect electricalIn to controller.electricalIn;
    connection commandPath connect commandIn to controller.commandIn;
    connection controlledExcitationPath connect controller.controlledThermalOut to dopantLattice.absorbedEnergyIn;
    connection thermalSensorFeedback connect temperatureSensors.telemetryOut to controller.telemetryIn;
    connection opticalSensorFeedback connect opticalSensor.telemetryOut to controller.telemetryIn;
    connection controllerTelemetryPath connect controller.controllerTelemetryOut to telemetryOut;

    perform action primaryFunction : ConvertAbsorbedEnergyToEmissiveOutput;
    exhibit state operatingState : SubstrateOperationalStates;
  }

  action def AbsorbIncidentEnergy {
    in item incidentRadiation : IncidentRadiation;
    in item substrateTemperature : ThermalEnergy;
    out item absorbedEnergy : AbsorbedEnergy;

    attribute absorptionEfficiency : Real = 0.82;
  }

  action def ConvertToLuminescentEmission {
    in item absorbedEnergy : AbsorbedEnergy;
    in item electricalBias : ElectricalPower;
    out item luminescentOutput : LuminescentRadiation;

    attribute conversionQuantumYield : QuantumYield = 0.43;
    attribute peakEmission : Wavelength = (value = 625.0; unit = "nm");
  }

  action def EmitThermalRadiation {
    in item substrateHeat : ThermalEnergy;
    out item thermalEmission : LuminescentRadiation;

    attribute effectiveEmissivity : Emissivity = 0.93;
    attribute radiativeBandLow : Wavelength = (value = 3000.0; unit = "nm");
    attribute radiativeBandHigh : Wavelength = (value = 25000.0; unit = "nm");
  }

  action def MonitorSubstrateHealth {
    in item temperatureTelemetry : HealthTelemetry;
    in item opticalTelemetry : HealthTelemetry;
    out item healthTelemetry : HealthTelemetry;

    attribute temperatureAlarmLimit : Temperature = (value = 393.0; unit = "K");
    attribute degradationAlarmLimit : DegradationIndex = 0.35;
  }

  action def RegulateExcitation {
    in item command : ControlCommand;
    in item health : HealthTelemetry;
    in item supply : ElectricalPower;
    out item controlledEnergy : ThermalEnergy;

    attribute closedLoopControlEnabled : Boolean = true;
    attribute maximumCommandedPower : Power = (value = 18.0; unit = "W");
  }

  action def ConvertAbsorbedEnergyToEmissiveOutput {
    in item incidentRadiation : IncidentRadiation;
    in item electricalSupply : ElectricalPower;
    in item command : ControlCommand;
    out item emittedRadiation : LuminescentRadiation;
    out item telemetry : HealthTelemetry;

    action absorb : AbsorbIncidentEnergy;
    action regulate : RegulateExcitation;
    action convert : ConvertToLuminescentEmission;
    action thermalRadiate : EmitThermalRadiation;
    action monitor : MonitorSubstrateHealth;

    succession first absorb then regulate;
    succession regulate then convert;
    succession convert then thermalRadiate;
    succession thermalRadiate then monitor;

    flow incidentRadiation to absorb.incidentRadiation;
    flow electricalSupply to regulate.supply;
    flow command to regulate.command;
    flow absorb.absorbedEnergy to convert.absorbedEnergy;
    flow regulate.controlledEnergy to thermalRadiate.substrateHeat;
    flow convert.luminescentOutput to emittedRadiation;
    flow monitor.healthTelemetry to telemetry;
  }

  state def SubstrateOperationalStates {
    entry action initializeTelemetry {
      out item telemetry : HealthTelemetry;
    }

    state Off;
    state Standby;
    state PassiveRadiating;
    state ActiveLuminescing;
    state ThermalProtection;
    state DegradedService;
    state SafeShutdown;

    transition initial_to_off first start then Off;

    transition power_available
      first Off
      accept ControlCommand
      if command.enableEmission == false
      then Standby;

    transition passive_energy_absorption
      first Standby
      accept IncidentRadiation
      if incident.irradiance.value > 50.0
      then PassiveRadiating;

    transition active_command
      first Standby
      accept ControlCommand
      if command.enableEmission == true
      then ActiveLuminescing;

    transition passive_to_active
      first PassiveRadiating
      accept ControlCommand
      if command.enableEmission == true
      then ActiveLuminescing;

    transition active_to_passive
      first ActiveLuminescing
      accept ControlCommand
      if command.enableEmission == false
      then PassiveRadiating;

    transition overtemperature
      first ActiveLuminescing
      accept HealthTelemetry
      if telemetry.measuredTemperature.value >= 393.0
      then ThermalProtection;

    transition cool_recovery
      first ThermalProtection
      accept HealthTelemetry
      if telemetry.measuredTemperature.value < 373.0 and telemetry.faultPresent == false
      then PassiveRadiating;

    transition degradation_detected
      first PassiveRadiating
      accept HealthTelemetry
      if telemetry.degradation >= 0.35
      then DegradedService;

    transition degraded_active_limited
      first DegradedService
      accept ControlCommand
      if command.enableEmission == true
      then ActiveLuminescing;

    transition unrecoverable_fault
      first ThermalProtection
      accept HealthTelemetry
      if telemetry.faultPresent == true
      then SafeShutdown;

    transition commanded_shutdown
      first Standby
      accept ControlCommand
      if command.enableEmission == false and command.requestedRadiantFlux.value == 0.0
      then Off;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall provide a high-level function of converting absorbed incident energy and optional low electrical excitation into high-emissivity thermal radiation and aluminiferous luminescent optical output."

    subject substrate : HighEmissivityAluminiferousLuminescentSubstrate;

    require constraint {
      substrate.effectiveHemisphericalEmissivity >= 0.90
    }

    require constraint {
      substrate.minimumUsefulRadiantFlux.value >= 5.0
    }
  }

  requirement def AluminiferousCompositionRequirement {
    doc "The carrier and emissive phases shall contain substantial aluminum-bearing material to provide aluminiferous structure, oxidation stability, and heat spreading."

    subject substrate : HighEmissivityAluminiferousLuminescentSubstrate;

    require constraint {
      substrate.carrierMatrix.aluminumMassFraction >= 0.60
    }

    require constraint {
      substrate.emissiveLayer.aluminaSpinelContent >= 0.50
    }
  }

  requirement def HighEmissivityRequirement {
    doc "The exposed functional surface shall maintain high hemispherical emissivity during normal operation."

    subject substrate : HighEmissivityAluminiferousLuminescentSubstrate;

    require constraint {
      substrate.emissiveLayer.effectiveHemisphericalEmissivity >= 0.92
    }

    require constraint {
      substrate.maximumSafeSurfaceTemperature.value <= substrate.emissiveLayer.operatingTemperatureLimit.value
    }
  }

  requirement def LuminescentOutputRequirement {
    doc "The luminescent lattice shall emit visible to near-visible radiation in a stable band when excited by absorbed incident radiation or controlled electrical energy."

    subject substrate : HighEmissivityAluminiferousLuminescentSubstrate;

    require constraint {
      substrate.dopantLattice.emissionPeak.value >= 560.0 and substrate.dopantLattice.emissionPeak.value <= 720.0
    }

    require constraint {
      substrate.dopantLattice.quantumYield >= 0.35
    }
  }

  requirement def ThermalSafetyRequirement {
    doc "The controller shall limit active luminescent excitation when the substrate approaches the maximum safe surface temperature."

    subject substrate : HighEmissivityAluminiferousLuminescentSubstrate;

    require constraint {
      substrate.maximumSafeSurfaceTemperature.value <= 393.0
    }

    require constraint {
      substrate.controller.maximumElectricalPower.value <= 18.0
    }
  }

  requirement def EnvironmentalDurabilityRequirement {
    doc "The protective overcoat and edge seal shall preserve the emissive and luminescent layers against abrasion and moisture ingress."

    subject substrate : HighEmissivityAluminiferousLuminescentSubstrate;

    require constraint {
      substrate.overcoat.visibleTransmittance >= 0.85
    }

    require constraint {
      substrate.edgeSeal.moistureIngressRate <= 0.005
    }

    require constraint {
      substrate.overcoat.abrasionResistant == true
    }
  }

  part def IncidentEnergyEnvironment {
    attribute ambientTemperature : Temperature = (value = 298.0; unit = "K");
    attribute nominalSolarIrradiance : Irradiance = (value = 800.0; unit = "W/m^2");

    port radiationOut : OpticalInputPort;
    port radiationIn : OpticalEmissionPort;
    port thermalSink : ThermalPort;
  }

  part def PowerAndCommandUnit {
    attribute supplyVoltage : Voltage = (value = 24.0; unit = "V");
    attribute availablePower : Power = (value = 24.0; unit = "W");

    port powerOut : ElectricalInputPort;
    port commandOut : CommandPort;
    port telemetryIn : TelemetryPort;
  }

  part def HELSOperationalAssembly {
    doc "Operational assembly containing the High Emissivity Aluminiferous Luminescent Substrate, its environmental interfaces, and command/power support."

    part substrate : HighEmissivityAluminiferousLuminescentSubstrate;
    part environment : IncidentEnergyEnvironment;
    part powerCommandUnit : PowerAndCommandUnit;

    connection incidentRadiationInterface connect environment.radiationOut to substrate.opticalIn;
    connection emittedRadiationInterface connect substrate.opticalOut to environment.radiationIn;
    connection thermalRejectionInterface connect substrate.thermalInterface to environment.thermalSink;
    connection electricalInterface connect powerCommandUnit.powerOut to substrate.electricalIn;
    connection commandInterface connect powerCommandUnit.commandOut to substrate.commandIn;
    connection telemetryInterface connect substrate.telemetryOut to powerCommandUnit.telemetryIn;

    satisfy PrimaryFunctionRequirement by substrate;
    satisfy AluminiferousCompositionRequirement by substrate;
    satisfy HighEmissivityRequirement by substrate;
    satisfy LuminescentOutputRequirement by substrate;
    satisfy ThermalSafetyRequirement by substrate;
    satisfy EnvironmentalDurabilityRequirement by substrate;
  }

}
