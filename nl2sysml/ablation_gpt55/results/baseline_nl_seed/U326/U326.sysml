package NebulizerSystemModel {
  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Volume :> ISQ::volume;
  attribute def VolumetricFlowRate :> ISQ::volumeFlowRate;
  attribute def Pressure :> ISQ::pressure;
  attribute def Time :> ISQ::time;
  attribute def Length :> ISQ::length;
  attribute def Power :> ISQ::power;
  attribute def ElectricPotential :> ISQ::electricPotential;
  attribute def ElectricCurrent :> ISQ::electricCurrent;
  attribute def MassDensity :> ISQ::density;
  attribute def DynamicViscosity :> ISQ::dynamicViscosity;
  attribute def Efficiency :> ScalarValues::Real;

  item def ElectricalEnergy {
    attribute voltage : ElectricPotential = 12 [V];
    attribute current : ElectricCurrent;
    attribute availablePower : Power;
  }

  item def AmbientAir {
    attribute pressure : Pressure = 101325 [Pa];
    attribute flowRate : VolumetricFlowRate;
  }

  item def CompressedAir {
    attribute pressure : Pressure;
    attribute flowRate : VolumetricFlowRate;
  }

  item def MedicineSolution {
    attribute volume : Volume;
    attribute medicationConcentration : MassDensity;
    attribute viscosity : DynamicViscosity = 0.001 [Pa*s];
  }

  item def AerosolMist {
    attribute aerosolFlowRate : VolumetricFlowRate;
    attribute particleDiameter : Length;
    attribute medicationVolume : Volume;
  }

  item def NebulizerCommand {
    attribute startRequested : Boolean;
    attribute stopRequested : Boolean;
    attribute treatmentTimeRequested : Time;
  }

  item def CompressorCommand {
    attribute enableCompressor : Boolean;
    attribute targetAirFlowRate : VolumetricFlowRate;
    attribute targetPressure : Pressure;
  }

  item def NebulizerStatus {
    attribute powered : Boolean;
    attribute ready : Boolean;
    attribute nebulizing : Boolean;
    attribute medicationLow : Boolean;
    attribute faultDetected : Boolean;
    attribute deliveredVolumeEstimate : Volume;
  }

  item def MedicationLevelStatus {
    attribute remainingVolume : Volume;
    attribute lowLevelDetected : Boolean;
  }

  item def AerosolFlowStatus {
    attribute measuredFlowRate : VolumetricFlowRate;
    attribute obstructionDetected : Boolean;
  }

  port def PowerInputPort {
    in item power : ElectricalEnergy;
  }

  port def PowerOutputPort {
    out item power : ElectricalEnergy;
  }

  port def AmbientAirInputPort {
    in item air : AmbientAir;
  }

  port def CompressedAirOutputPort {
    out item air : CompressedAir;
  }

  port def CompressedAirInputPort {
    in item air : CompressedAir;
  }

  port def MedicationInputPort {
    in item medication : MedicineSolution;
  }

  port def MedicationOutputPort {
    out item medication : MedicineSolution;
  }

  port def AerosolInputPort {
    in item mist : AerosolMist;
  }

  port def AerosolOutputPort {
    out item mist : AerosolMist;
  }

  port def CommandInputPort {
    in item command : NebulizerCommand;
  }

  port def CompressorCommandOutputPort {
    out item command : CompressorCommand;
  }

  port def CompressorCommandInputPort {
    in item command : CompressorCommand;
  }

  port def StatusOutputPort {
    out item status : NebulizerStatus;
  }

  port def MedicationLevelOutputPort {
    out item status : MedicationLevelStatus;
  }

  port def MedicationLevelInputPort {
    in item status : MedicationLevelStatus;
  }

  port def AerosolFlowStatusOutputPort {
    out item status : AerosolFlowStatus;
  }

  port def AerosolFlowStatusInputPort {
    in item status : AerosolFlowStatus;
  }

  constraint def RespirableParticleDiameter {
    in diameter : Length;
    constraint {
      diameter >= 1.0e-6 [m] and diameter <= 5.0e-6 [m]
    }
  }

  constraint def SafeCompressorPressure {
    in pressure : Pressure;
    constraint {
      pressure >= 50000 [Pa] and pressure <= 250000 [Pa]
    }
  }

  constraint def MinimumAerosolOutput {
    in outputRate : VolumetricFlowRate;
    constraint {
      outputRate >= 1.0e-8 [m^3/s]
    }
  }

  action def RegulateElectricalPower {
    in rawPower : ElectricalEnergy;
    out regulatedPower : ElectricalEnergy;
  }

  action def PressurizeAir {
    in ambientAir : AmbientAir;
    in electricalPower : ElectricalEnergy;
    out compressedAir : CompressedAir;
  }

  action def MeterMedication {
    in storedMedication : MedicineSolution;
    out meteredMedication : MedicineSolution;
  }

  action def AtomizeLiquidMedication {
    in meteredMedication : MedicineSolution;
    in compressedAir : CompressedAir;
    out respirableAerosol : AerosolMist;
  }

  action def DeliverAerosolToPatientInterface {
    in respirableAerosol : AerosolMist;
    out deliveredAerosol : AerosolMist;
  }

  action def ConvertMedicationToRespirableAerosol {
    in liquidMedication : MedicineSolution;
    in ambientAir : AmbientAir;
    in electricalPower : ElectricalEnergy;
    out patientReadyAerosol : AerosolMist;

    attribute targetParticleDiameter : Length = 3.0e-6 [m];
    attribute nominalTreatmentDuration : Time = 600 [s];

    action regulatePower : RegulateElectricalPower;
    action pressurizeAir : PressurizeAir;
    action meterMedication : MeterMedication;
    action atomizeMedication : AtomizeLiquidMedication;
    action deliverAerosol : DeliverAerosolToPatientInterface;

    succession regulatePower then pressurizeAir;
    succession pressurizeAir then meterMedication;
    succession meterMedication then atomizeMedication;
    succession atomizeMedication then deliverAerosol;
  }

  action def PrepareNebulizer {
    in medicationLevel : MedicationLevelStatus;
    out readyStatus : NebulizerStatus;
  }

  action def MonitorTreatment {
    in medicationLevel : MedicationLevelStatus;
    in aerosolFlow : AerosolFlowStatus;
    out treatmentStatus : NebulizerStatus;
  }

  action def StopNebulization {
    out stoppedStatus : NebulizerStatus;
  }

  state def NebulizerLifecycle {
    entry; then Off;

    state Off;
    state Ready;
    state Nebulizing;
    state TreatmentComplete;
    state Fault;

    transition powerOn
      first Off
      accept NebulizerCommand
      do PrepareNebulizer
      then Ready;

    transition startTreatment
      first Ready
      accept NebulizerCommand
      then Nebulizing;

    transition completeTreatment
      first Nebulizing
      accept MedicationLevelStatus
      do StopNebulization
      then TreatmentComplete;

    transition stopRequested
      first Nebulizing
      accept NebulizerCommand
      do StopNebulization
      then Ready;

    transition faultDetected
      first Nebulizing
      accept AerosolFlowStatus
      do StopNebulization
      then Fault;

    transition resetFromComplete
      first TreatmentComplete
      accept NebulizerCommand
      then Ready;

    transition powerOffFromReady
      first Ready
      accept NebulizerCommand
      then Off;

    transition powerOffFromFault
      first Fault
      accept NebulizerCommand
      then Off;
  }

  part def PowerSupply {
    port powerIn : PowerInputPort;
    port powerOut : PowerOutputPort;

    attribute inputVoltage : ElectricPotential = 12 [V];
    attribute regulatedVoltage : ElectricPotential = 12 [V];
    attribute maximumOutputPower : Power = 36 [W];
    attribute conversionEfficiency : Efficiency = 0.88;

    perform action regulatePower : RegulateElectricalPower;
  }

  part def InletFilter {
    port airIn : AmbientAirInputPort;
    port airOut : AmbientAirInputPort;

    attribute retainedParticleDiameter : Length = 5.0e-6 [m];
    attribute cleanPressureDrop : Pressure = 250 [Pa];
  }

  part def Compressor {
    port powerIn : PowerInputPort;
    port ambientAirIn : AmbientAirInputPort;
    port compressedAirOut : CompressedAirOutputPort;
    port controlIn : CompressorCommandInputPort;

    attribute nominalPressure : Pressure = 150000 [Pa];
    attribute maximumPressure : Pressure = 250000 [Pa];
    attribute nominalAirFlowRate : VolumetricFlowRate = 1.0e-4 [m^3/s];
    attribute ratedPower : Power = 30 [W];

    perform action pressurizeAir : PressurizeAir;

    constraint pressureLimit : SafeCompressorPressure {
      in pressure = maximumPressure;
    }
  }

  part def MedicationCup {
    port fillPort : MedicationInputPort;
    port liquidOut : MedicationOutputPort;
    port levelStatusOut : MedicationLevelOutputPort;

    attribute maximumFillVolume : Volume = 8.0e-6 [m^3];
    attribute nominalDoseVolume : Volume = 4.0e-6 [m^3];
    attribute residualVolume : Volume = 5.0e-7 [m^3];
    attribute lowLevelThreshold : Volume = 6.0e-7 [m^3];
  }

  part def Atomizer {
    port airIn : CompressedAirInputPort;
    port liquidIn : MedicationInputPort;
    port mistOut : AerosolOutputPort;

    attribute nominalParticleDiameter : Length = 3.0e-6 [m];
    attribute aerosolGenerationRate : VolumetricFlowRate = 1.5e-8 [m^3/s];
    attribute atomizationEfficiency : Efficiency = 0.65;

    perform action atomizeMedication : AtomizeLiquidMedication;

    constraint particleSize : RespirableParticleDiameter {
      in diameter = nominalParticleDiameter;
    }

    constraint minimumOutput : MinimumAerosolOutput {
      in outputRate = aerosolGenerationRate;
    }
  }

  part def Mouthpiece {
    port aerosolIn : AerosolInputPort;
    port aerosolOut : AerosolOutputPort;

    attribute internalDeadVolume : Volume = 1.5e-5 [m^3];
    attribute outletDiameter : Length = 1.5e-2 [m];

    perform action deliverAerosol : DeliverAerosolToPatientInterface;
  }

  part def FlowSensor {
    port aerosolIn : AerosolInputPort;
    port aerosolOut : AerosolOutputPort;
    port flowStatusOut : AerosolFlowStatusOutputPort;

    attribute minimumDetectableFlow : VolumetricFlowRate = 5.0e-9 [m^3/s];
    attribute obstructionFlowThreshold : VolumetricFlowRate = 2.0e-9 [m^3/s];
  }

  part def Controller {
    port powerIn : PowerInputPort;
    port commandIn : CommandInputPort;
    port compressorCommandOut : CompressorCommandOutputPort;
    port levelStatusIn : MedicationLevelInputPort;
    port flowStatusIn : AerosolFlowStatusInputPort;
    port systemStatusOut : StatusOutputPort;

    attribute treatmentTimeSetpoint : Time = 600 [s];
    attribute commandedPressure : Pressure = 150000 [Pa];
    attribute commandedFlowRate : VolumetricFlowRate = 1.0e-4 [m^3/s];

    perform action prepare : PrepareNebulizer;
    perform action monitor : MonitorTreatment;
    perform action stop : StopNebulization;
  }

  part def Nebulizer {
    doc /* The primary high-level function of the nebulizer is to convert a liquid medication solution into a respirable aerosol mist and deliver it through a patient interface for inhalation. */

    port powerIn : PowerInputPort;
    port medicationFill : MedicationInputPort;
    port ambientAirIn : AmbientAirInputPort;
    port userCommandIn : CommandInputPort;
    port aerosolOut : AerosolOutputPort;
    port statusOut : StatusOutputPort;

    attribute primaryFunctionEnabled : Boolean = true;
    attribute nominalDoseVolume : Volume = 4.0e-6 [m^3];
    attribute nominalTreatmentDuration : Time = 600 [s];
    attribute nominalParticleDiameter : Length = 3.0e-6 [m];
    attribute nominalAerosolOutputRate : VolumetricFlowRate = 1.5e-8 [m^3/s];
    attribute nominalOperatingPressure : Pressure = 150000 [Pa];

    part powerSupply : PowerSupply;
    part inletFilter : InletFilter;
    part compressor : Compressor;
    part medicationCup : MedicationCup;
    part atomizer : Atomizer;
    part flowSensor : FlowSensor;
    part mouthpiece : Mouthpiece;
    part controller : Controller;

    perform action primaryFunction : ConvertMedicationToRespirableAerosol;
    exhibit state lifecycle : NebulizerLifecycle;

    connect powerIn to powerSupply.powerIn;
    connect powerSupply.powerOut to controller.powerIn;
    connect powerSupply.powerOut to compressor.powerIn;

    connect ambientAirIn to inletFilter.airIn;
    connect inletFilter.airOut to compressor.ambientAirIn;
    connect compressor.compressedAirOut to atomizer.airIn;

    connect medicationFill to medicationCup.fillPort;
    connect medicationCup.liquidOut to atomizer.liquidIn;

    connect atomizer.mistOut to flowSensor.aerosolIn;
    connect flowSensor.aerosolOut to mouthpiece.aerosolIn;
    connect mouthpiece.aerosolOut to aerosolOut;

    connect userCommandIn to controller.commandIn;
    connect controller.compressorCommandOut to compressor.controlIn;
    connect medicationCup.levelStatusOut to controller.levelStatusIn;
    connect flowSensor.flowStatusOut to controller.flowStatusIn;
    connect controller.systemStatusOut to statusOut;

    constraint systemParticleSize : RespirableParticleDiameter {
      in diameter = nominalParticleDiameter;
    }

    constraint systemAerosolOutput : MinimumAerosolOutput {
      in outputRate = nominalAerosolOutputRate;
    }

    constraint systemPressureLimit : SafeCompressorPressure {
      in pressure = nominalOperatingPressure;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The nebulizer shall accept liquid medication, air, and electrical power; generate a respirable aerosol with a nominal particle diameter in the respirable range; and deliver the aerosol through the patient interface. */

    subject nebulizer : Nebulizer;

    require constraint {
      nebulizer.primaryFunctionEnabled == true and
      nebulizer.nominalParticleDiameter >= 1.0e-6 [m] and
      nebulizer.nominalParticleDiameter <= 5.0e-6 [m] and
      nebulizer.nominalAerosolOutputRate >= 1.0e-8 [m^3/s]
    }
  }

  requirement def DoseCapacityRequirement {
    doc /* The nebulizer medication cup shall hold at least one nominal treatment dose. */

    subject nebulizer : Nebulizer;

    require constraint {
      nebulizer.medicationCup.maximumFillVolume >= nebulizer.nominalDoseVolume
    }
  }

  requirement def OperatingPressureRequirement {
    doc /* The nebulizer shall operate the compressor within the safe pressure range used by the atomizer. */

    subject nebulizer : Nebulizer;

    require constraint {
      nebulizer.nominalOperatingPressure >= 50000 [Pa] and
      nebulizer.nominalOperatingPressure <= 250000 [Pa]
    }
  }

  part systemNebulizer : Nebulizer;

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject nebulizer = systemNebulizer;
  }

  requirement doseCapacity : DoseCapacityRequirement {
    subject nebulizer = systemNebulizer;
  }

  requirement operatingPressure : OperatingPressureRequirement {
    subject nebulizer = systemNebulizer;
  }

  satisfy primaryFunction by systemNebulizer;
  satisfy doseCapacity by systemNebulizer.medicationCup;
  satisfy operatingPressure by systemNebulizer.compressor;
}
