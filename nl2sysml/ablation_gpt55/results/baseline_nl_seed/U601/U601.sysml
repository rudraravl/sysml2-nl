package AtomicGravitationalWaveInterferometricSensingUnitModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    enum def MeasuredQuantityKind {
        enum gravitationalWaveStrain;
        enum differentialAtomicPhase;
        enum platformAcceleration;
        enum diagnosticTemperature;
    }

    enum def SensorMethodKind {
        enum atomicGravitationalWaveInterferometry;
        enum opticalInterferometry;
        enum inertialSeismometry;
    }

    attribute def GravitationalWaveStrain :> ScalarValues::Real;
    attribute def PhaseAngle :> ScalarValues::Real;
    attribute def SignalToNoiseRatio :> ScalarValues::Real;
    attribute def DataRate :> ScalarValues::Real;
    attribute def CountRate :> ScalarValues::Real;
    attribute def WaveNumber :> ScalarValues::Real;
    attribute def Fraction :> ScalarValues::Real;

    item def ElectricalPower {
        attribute voltage :> ISQ::electricPotential = 28.0 [SI::V];
        attribute power :> ISQ::power = 450.0 [SI::W];
        attribute rippleFraction : Fraction = 0.002;
    }

    item def TimeReference {
        attribute epochTime :> ISQ::time;
        attribute clockFrequency :> ISQ::frequency = 10000000.0 [SI::Hz];
        attribute timingJitter :> ISQ::time = 2.0e-9 [SI::s];
    }

    item def MeasurementCommand {
        attribute requestedQuantity : MeasuredQuantityKind = MeasuredQuantityKind::gravitationalWaveStrain;
        attribute requestedIntegrationTime :> ISQ::time = 10.0 [SI::s];
        attribute requestedSampleRate :> ISQ::frequency = 1.0 [SI::Hz];
        attribute calibrationEnabled : ScalarValues::Boolean = true;
    }

    item def MaintenanceCommand {
        attribute enableVacuumPumpDown : ScalarValues::Boolean = true;
        attribute enableLaserAlignment : ScalarValues::Boolean = true;
        attribute enableMagneticNulling : ScalarValues::Boolean = true;
    }

    item def ColdAtomCloud {
        attribute isotopeMassNumber : ScalarValues::Integer = 87;
        attribute atomCount : ScalarValues::Integer = 10000000;
        attribute cloudTemperature :> ISQ::temperature = 2.0e-6 [SI::K];
        attribute launchVelocity :> ISQ::speed = 4.0 [SI::m / SI::s];
        attribute transverseRadius :> ISQ::length = 0.004 [SI::m];
    }

    item def LaserPulseTrain {
        attribute wavelength :> ISQ::length = 780.241e-9 [SI::m];
        attribute pulseSeparationTime :> ISQ::time = 1.0 [SI::s];
        attribute piOverTwoPulseDuration :> ISQ::time = 10.0e-6 [SI::s];
        attribute opticalPower :> ISQ::power = 1.5 [SI::W];
        attribute effectiveWaveNumber : WaveNumber = 1.611e7;
    }

    item def AtomicPopulationReadout {
        attribute atomsInStateF1 : ScalarValues::Integer;
        attribute atomsInStateF2 : ScalarValues::Integer;
        attribute contrast : Fraction = 0.62;
        attribute detectionNoise : Fraction = 0.003;
    }

    item def DifferentialPhaseSample {
        attribute phaseA : PhaseAngle;
        attribute phaseB : PhaseAngle;
        attribute differentialPhase : PhaseAngle;
        attribute phaseNoise : PhaseAngle = 1.0e-4;
        attribute sampleTime :> ISQ::time;
    }

    item def EnvironmentalSample {
        attribute benchTemperature :> ISQ::temperature = 293.15 [SI::K];
        attribute magneticFieldMagnitude :> ISQ::magneticFluxDensity = 5.0e-9 [SI::T];
        attribute platformAcceleration :> ISQ::acceleration = 2.0e-8 [SI::m / SI::s^2];
        attribute vacuumPressure :> ISQ::pressure = 1.0e-9 [SI::Pa];
    }

    item def StrainMeasurementFrame {
        attribute measuredQuantity : MeasuredQuantityKind = MeasuredQuantityKind::gravitationalWaveStrain;
        attribute strain : GravitationalWaveStrain;
        attribute oneSigmaUncertainty : GravitationalWaveStrain = 1.0e-21;
        attribute integrationTime :> ISQ::time = 10.0 [SI::s];
        attribute sampleTime :> ISQ::time;
        attribute signalToNoiseRatio : SignalToNoiseRatio;
        attribute dataValidity : ScalarValues::Boolean = true;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : MeasurementCommand;
    }

    port def MaintenanceInputPort {
        in item command : MaintenanceCommand;
    }

    port def CommandOutputPort {
        out item command : MeasurementCommand;
    }

    port def TimeInputPort {
        in item reference : TimeReference;
    }

    port def TimeOutputPort {
        out item reference : TimeReference;
    }

    port def AtomOutputPort {
        out item atoms : ColdAtomCloud;
    }

    port def AtomInputPort {
        in item atoms : ColdAtomCloud;
    }

    port def LaserPulseOutputPort {
        out item pulses : LaserPulseTrain;
    }

    port def LaserPulseInputPort {
        in item pulses : LaserPulseTrain;
    }

    port def PopulationReadoutOutputPort {
        out item readout : AtomicPopulationReadout;
    }

    port def PopulationReadoutInputPort {
        in item readout : AtomicPopulationReadout;
    }

    port def PhaseOutputPort {
        out item phase : DifferentialPhaseSample;
    }

    port def PhaseInputPort {
        in item phase : DifferentialPhaseSample;
    }

    port def EnvironmentalOutputPort {
        out item environment : EnvironmentalSample;
    }

    port def EnvironmentalInputPort {
        in item environment : EnvironmentalSample;
    }

    port def MeasurementOutputPort {
        out item frame : StrainMeasurementFrame;
    }

    port def MeasurementInputPort {
        in item frame : StrainMeasurementFrame;
    }

    action def PrepareVacuum {
        in item command : MaintenanceCommand;
        out item environment : EnvironmentalSample;
    }

    action def CoolAndLaunchAtoms {
        in item command : MeasurementCommand;
        out item atoms : ColdAtomCloud;
    }

    action def GenerateRamanPulseSequence {
        in item command : MeasurementCommand;
        in item reference : TimeReference;
        out item pulses : LaserPulseTrain;
    }

    action def ApplyInterferometerPulseSequence {
        in item atoms : ColdAtomCloud;
        in item pulses : LaserPulseTrain;
        out item readout : AtomicPopulationReadout;
    }

    action def EstimateDifferentialPhase {
        in item readout : AtomicPopulationReadout;
        out item phase : DifferentialPhaseSample;
    }

    action def CompensateEnvironmentalNoise {
        in item phase : DifferentialPhaseSample;
        in item environment : EnvironmentalSample;
        out item compensatedPhase : DifferentialPhaseSample;
    }

    action def ConvertPhaseToStrain {
        in item compensatedPhase : DifferentialPhaseSample;
        out item frame : StrainMeasurementFrame;
    }

    action def PublishMeasurement {
        in item frame : StrainMeasurementFrame;
        out item publishedFrame : StrainMeasurementFrame;
    }

    action def GravitationalWaveMeasurementCycle {
        in item command : MeasurementCommand;
        in item maintenance : MaintenanceCommand;
        in item reference : TimeReference;
        out item measurement : StrainMeasurementFrame;

        action prepareVacuum : PrepareVacuum;
        action coolLaunchAtoms : CoolAndLaunchAtoms;
        action generatePulses : GenerateRamanPulseSequence;
        action applyPulses : ApplyInterferometerPulseSequence;
        action estimatePhase : EstimateDifferentialPhase;
        action compensateNoise : CompensateEnvironmentalNoise;
        action convertStrain : ConvertPhaseToStrain;
        action publish : PublishMeasurement;

        first prepareVacuum;
        then coolLaunchAtoms;
        then generatePulses;
        then applyPulses;
        then estimatePhase;
        then compensateNoise;
        then convertStrain;
        then publish;
    }

    event def PowerOn;
    event def PowerOff;
    event def SelfTestPassed;
    event def SelfTestFailed;
    event def LockAcquired;
    event def LockLost;
    event def CalibrationRequested;
    event def CalibrationComplete;
    event def FaultDetected;
    event def FaultCleared;

    state def SensingUnitOperatingState {
        entry; then unpowered;

        state unpowered;
        state selfTest;
        state standby;
        state acquireInterferometerLock;
        state measuring;
        state calibrating;
        state faultSafe;

        transition powerOnTransition
            first unpowered
            accept PowerOn
            then selfTest;

        transition selfTestPassTransition
            first selfTest
            accept SelfTestPassed
            then standby;

        transition selfTestFailTransition
            first selfTest
            accept SelfTestFailed
            then faultSafe;

        transition beginLockTransition
            first standby
            accept MeasurementCommand
            then acquireInterferometerLock;

        transition lockAcquiredTransition
            first acquireInterferometerLock
            accept LockAcquired
            then measuring;

        transition lockLostTransition
            first measuring
            accept LockLost
            then acquireInterferometerLock;

        transition calibrationRequestTransition
            first measuring
            accept CalibrationRequested
            then calibrating;

        transition calibrationCompleteTransition
            first calibrating
            accept CalibrationComplete
            then measuring;

        transition faultFromMeasuringTransition
            first measuring
            accept FaultDetected
            then faultSafe;

        transition faultClearedTransition
            first faultSafe
            accept FaultCleared
            then standby;

        transition powerOffTransition
            first standby
            accept PowerOff
            then unpowered;
    }

    constraint def PhaseToStrainConversion {
        in differentialPhase : PhaseAngle;
        in effectiveWaveNumber : WaveNumber;
        in baselineLength :> ISQ::length;
        in interrogationTime :> ISQ::time;
        out strain : GravitationalWaveStrain;
        constraint { strain == differentialPhase / (effectiveWaveNumber * baselineLength) }
    }

    constraint def SensitivityLimit {
        in resolution : GravitationalWaveStrain;
        in requiredResolution : GravitationalWaveStrain;
        constraint { resolution <= requiredResolution }
    }

    constraint def VacuumPressureLimit {
        in pressure :> ISQ::pressure;
        in maximumPressure :> ISQ::pressure;
        constraint { pressure <= maximumPressure }
    }

    part def PowerConditioner {
        attribute inputVoltage :> ISQ::electricPotential = 28.0 [SI::V];
        attribute outputVoltage :> ISQ::electricPotential = 24.0 [SI::V];
        attribute maximumOutputPower :> ISQ::power = 600.0 [SI::W];
        attribute conversionEfficiency : Fraction = 0.91;

        port powerIn : PowerInputPort;
        port controllerPower : PowerOutputPort;
        port laserPower : PowerOutputPort;
        port atomSourcePower : PowerOutputPort;
        port vacuumPower : PowerOutputPort;
        port thermalPower : PowerOutputPort;
        port processorPower : PowerOutputPort;
    }

    part def PrecisionTimebase {
        attribute oscillatorFrequency :> ISQ::frequency = 10000000.0 [SI::Hz];
        attribute allanDeviationAtOneSecond : Fraction = 2.0e-12;
        attribute timingJitter :> ISQ::time = 2.0e-9 [SI::s];

        port powerIn : PowerInputPort;
        port timeOut : TimeOutputPort;
    }

    part def VacuumSubsystem {
        attribute chamberPressure :> ISQ::pressure = 1.0e-9 [SI::Pa];
        attribute chamberLength :> ISQ::length = 12.0 [SI::m];
        attribute chamberInnerDiameter :> ISQ::length = 0.30 [SI::m];
        attribute pumpSpeed :> ISQ::volume / ISQ::time = 0.15 [SI::m^3 / SI::s];

        port powerIn : PowerInputPort;
        port environmentOut : EnvironmentalOutputPort;

        perform action pumpDown : PrepareVacuum;
    }

    part def LaserCooledAtomSource {
        attribute isotopeMassNumber : ScalarValues::Integer = 87;
        attribute nominalAtomFlux : CountRate = 1.0e8;
        attribute molassesTemperature :> ISQ::temperature = 2.0e-6 [SI::K];
        attribute launchVelocity :> ISQ::speed = 4.0 [SI::m / SI::s];

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port timeIn : TimeInputPort;
        port atomOut : AtomOutputPort;

        perform action coolAndLaunch : CoolAndLaunchAtoms;
    }

    part def RamanLaserSystem {
        attribute wavelength :> ISQ::length = 780.241e-9 [SI::m];
        attribute linewidth :> ISQ::frequency = 1.0 [SI::Hz];
        attribute outputPower :> ISQ::power = 1.5 [SI::W];
        attribute pulseSeparationTime :> ISQ::time = 1.0 [SI::s];
        attribute effectiveWaveNumber : WaveNumber = 1.611e7;

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port timeIn : TimeInputPort;
        port laserOut : LaserPulseOutputPort;

        perform action generateSequence : GenerateRamanPulseSequence;
    }

    part def MagneticShieldAndBiasCoils {
        attribute residualMagneticField :> ISQ::magneticFluxDensity = 5.0e-9 [SI::T];
        attribute fieldGradient : ScalarValues::Real = 2.0e-10;
        attribute coilPower :> ISQ::power = 25.0 [SI::W];

        port powerIn : PowerInputPort;
        port environmentOut : EnvironmentalOutputPort;
    }

    part def VibrationIsolationPlatform {
        attribute isolationCornerFrequency :> ISQ::frequency = 0.05 [SI::Hz];
        attribute residualAcceleration :> ISQ::acceleration = 2.0e-8 [SI::m / SI::s^2];
        attribute payloadCapacity :> ISQ::mass = 250.0 [SI::kg];

        port powerIn : PowerInputPort;
        port environmentOut : EnvironmentalOutputPort;
    }

    part def ThermalControlSubsystem {
        attribute setPointTemperature :> ISQ::temperature = 293.15 [SI::K];
        attribute temperatureStability :> ISQ::temperature = 0.005 [SI::K];
        attribute maximumThermalPower :> ISQ::power = 80.0 [SI::W];

        port powerIn : PowerInputPort;
        port environmentOut : EnvironmentalOutputPort;
    }

    part def AtomicInterferometerCore {
        attribute method : SensorMethodKind = SensorMethodKind::atomicGravitationalWaveInterferometry;
        attribute measuredQuantity : MeasuredQuantityKind = MeasuredQuantityKind::gravitationalWaveStrain;
        attribute baselineLength :> ISQ::length = 10.0 [SI::m];
        attribute interrogationTime :> ISQ::time = 2.0 [SI::s];
        attribute effectiveWaveNumber : WaveNumber = 1.611e7;
        attribute nominalPhaseNoise : PhaseAngle = 1.0e-4;
        attribute strainResolution : GravitationalWaveStrain = 1.0e-21;

        port commandIn : CommandInputPort;
        port atomIn : AtomInputPort;
        port laserIn : LaserPulseInputPort;
        port timeIn : TimeInputPort;
        port environmentIn : EnvironmentalInputPort;
        port readoutOut : PopulationReadoutOutputPort;
        port phaseOut : PhaseOutputPort;

        perform action applyPulseSequence : ApplyInterferometerPulseSequence;
        perform action estimatePhase : EstimateDifferentialPhase;
    }

    part def EnvironmentalCompensator {
        attribute accelerationRejection : Fraction = 0.999999;
        attribute magneticRejection : Fraction = 0.999;
        attribute thermalRejection : Fraction = 0.995;

        port phaseIn : PhaseInputPort;
        port environmentIn : EnvironmentalInputPort;
        port compensatedPhaseOut : PhaseOutputPort;

        perform action compensate : CompensateEnvironmentalNoise;
    }

    part def StrainEstimator {
        attribute conversionMethod : SensorMethodKind = SensorMethodKind::atomicGravitationalWaveInterferometry;
        attribute baselineLength :> ISQ::length = 10.0 [SI::m];
        attribute effectiveWaveNumber : WaveNumber = 1.611e7;
        attribute outputSampleRate :> ISQ::frequency = 1.0 [SI::Hz];
        attribute minimumIntegrationTime :> ISQ::time = 1.0 [SI::s];
        attribute maximumIntegrationTime :> ISQ::time = 1000.0 [SI::s];

        port phaseIn : PhaseInputPort;
        port commandIn : CommandInputPort;
        port measurementOut : MeasurementOutputPort;

        perform action convert : ConvertPhaseToStrain;
    }

    part def ControlComputer {
        attribute processorClock :> ISQ::frequency = 1.2e9 [SI::Hz];
        attribute commandLatency :> ISQ::time = 0.005 [SI::s];
        attribute telemetryDataRate : DataRate = 1000000.0;

        port powerIn : PowerInputPort;
        port externalCommandIn : CommandInputPort;
        port maintenanceCommandIn : MaintenanceInputPort;
        port timeIn : TimeInputPort;
        port atomSourceCommandOut : CommandOutputPort;
        port laserCommandOut : CommandOutputPort;
        port coreCommandOut : CommandOutputPort;
        port estimatorCommandOut : CommandOutputPort;
    }

    part def DataRecorderAndTelemetry {
        attribute storageCapacity : ScalarValues::Real = 2.0e12;
        attribute downlinkDataRate : DataRate = 1000000.0;
        attribute frameRetentionTime :> ISQ::time = 2592000.0 [SI::s];

        port powerIn : PowerInputPort;
        port measurementIn : MeasurementInputPort;
        port measurementOut : MeasurementOutputPort;
    }

    part def AtomicGravitationalWaveInterferometricSensingUnit {
        attribute method : SensorMethodKind = SensorMethodKind::atomicGravitationalWaveInterferometry;
        attribute measuredQuantity : MeasuredQuantityKind = MeasuredQuantityKind::gravitationalWaveStrain;
        attribute totalMass :> ISQ::mass = 520.0 [SI::kg];
        attribute envelopeLength :> ISQ::length = 13.5 [SI::m];
        attribute envelopeWidth :> ISQ::length = 1.2 [SI::m];
        attribute envelopeHeight :> ISQ::length = 1.8 [SI::m];
        attribute nominalPower :> ISQ::power = 450.0 [SI::W];
        attribute baselineLength :> ISQ::length = 10.0 [SI::m];
        attribute integrationTime :> ISQ::time = 10.0 [SI::s];
        attribute sampleRate :> ISQ::frequency = 1.0 [SI::Hz];
        attribute strainResolution : GravitationalWaveStrain = 1.0e-21;
        attribute measurementBandwidth :> ISQ::frequency = 1.0 [SI::Hz];
        attribute availability : Fraction = 0.995;

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port maintenanceIn : MaintenanceInputPort;
        port timeIn : TimeInputPort;
        port measurementOut : MeasurementOutputPort;

        part powerConditioner : PowerConditioner;
        part timebase : PrecisionTimebase;
        part vacuumSubsystem : VacuumSubsystem;
        part atomSource : LaserCooledAtomSource;
        part ramanLaserSystem : RamanLaserSystem;
        part magneticShield : MagneticShieldAndBiasCoils;
        part vibrationIsolation : VibrationIsolationPlatform;
        part thermalControl : ThermalControlSubsystem;
        part interferometerCore : AtomicInterferometerCore;
        part environmentalCompensator : EnvironmentalCompensator;
        part strainEstimator : StrainEstimator;
        part controller : ControlComputer;
        part recorder : DataRecorderAndTelemetry;

        connect powerIn to powerConditioner.powerIn;
        connect powerConditioner.controllerPower to controller.powerIn;
        connect powerConditioner.processorPower to recorder.powerIn;
        connect powerConditioner.laserPower to ramanLaserSystem.powerIn;
        connect powerConditioner.atomSourcePower to atomSource.powerIn;
        connect powerConditioner.vacuumPower to vacuumSubsystem.powerIn;
        connect powerConditioner.thermalPower to thermalControl.powerIn;
        connect powerConditioner.thermalPower to magneticShield.powerIn;
        connect powerConditioner.thermalPower to vibrationIsolation.powerIn;
        connect powerConditioner.controllerPower to timebase.powerIn;

        connect commandIn to controller.externalCommandIn;
        connect maintenanceIn to controller.maintenanceCommandIn;
        connect timeIn to controller.timeIn;
        connect timeIn to timebase.timeOut;
        connect timebase.timeOut to atomSource.timeIn;
        connect timebase.timeOut to ramanLaserSystem.timeIn;
        connect timebase.timeOut to interferometerCore.timeIn;

        connect controller.atomSourceCommandOut to atomSource.commandIn;
        connect controller.laserCommandOut to ramanLaserSystem.commandIn;
        connect controller.coreCommandOut to interferometerCore.commandIn;
        connect controller.estimatorCommandOut to strainEstimator.commandIn;

        connect atomSource.atomOut to interferometerCore.atomIn;
        connect ramanLaserSystem.laserOut to interferometerCore.laserIn;

        connect vacuumSubsystem.environmentOut to interferometerCore.environmentIn;
        connect thermalControl.environmentOut to environmentalCompensator.environmentIn;
        connect magneticShield.environmentOut to environmentalCompensator.environmentIn;
        connect vibrationIsolation.environmentOut to environmentalCompensator.environmentIn;

        connect interferometerCore.phaseOut to environmentalCompensator.phaseIn;
        connect environmentalCompensator.compensatedPhaseOut to strainEstimator.phaseIn;
        connect strainEstimator.measurementOut to recorder.measurementIn;
        connect recorder.measurementOut to measurementOut;

        perform action measurementCycle : GravitationalWaveMeasurementCycle;
        exhibit state operatingState : SensingUnitOperatingState;
    }

    requirement def MeasureRelevantQuantityUsingAtomicInterferometry {
        subject unit : AtomicGravitationalWaveInterferometricSensingUnit;

        attribute requiredQuantity : MeasuredQuantityKind = MeasuredQuantityKind::gravitationalWaveStrain;
        attribute requiredMethod : SensorMethodKind = SensorMethodKind::atomicGravitationalWaveInterferometry;

        require constraint {
            unit.measuredQuantity == requiredQuantity
        }

        require constraint {
            unit.method == requiredMethod
        }
    }

    requirement def StrainSensitivityRequirement {
        subject unit : AtomicGravitationalWaveInterferometricSensingUnit;

        attribute requiredResolution : GravitationalWaveStrain = 1.0e-21;
        attribute requiredBandwidth :> ISQ::frequency = 1.0 [SI::Hz];

        require constraint {
            unit.strainResolution <= requiredResolution
        }

        require constraint {
            unit.measurementBandwidth >= requiredBandwidth
        }
    }

    requirement def AtomicBaselineRequirement {
        subject unit : AtomicGravitationalWaveInterferometricSensingUnit;

        attribute minimumBaselineLength :> ISQ::length = 10.0 [SI::m];
        attribute maximumNominalPower :> ISQ::power = 600.0 [SI::W];

        require constraint {
            unit.baselineLength >= minimumBaselineLength
        }

        require constraint {
            unit.nominalPower <= maximumNominalPower
        }
    }

    requirement def TimingAndSamplingRequirement {
        subject unit : AtomicGravitationalWaveInterferometricSensingUnit;

        attribute minimumSampleRate :> ISQ::frequency = 1.0 [SI::Hz];
        attribute nominalIntegrationTime :> ISQ::time = 10.0 [SI::s];

        require constraint {
            unit.sampleRate >= minimumSampleRate
        }

        require constraint {
            unit.integrationTime == nominalIntegrationTime
        }
    }

    part sensingUnit : AtomicGravitationalWaveInterferometricSensingUnit;

    requirement measureRequirement : MeasureRelevantQuantityUsingAtomicInterferometry {
        subject unit = sensingUnit;
    }

    requirement sensitivityRequirement : StrainSensitivityRequirement {
        subject unit = sensingUnit;
    }

    requirement baselineRequirement : AtomicBaselineRequirement {
        subject unit = sensingUnit;
    }

    requirement timingRequirement : TimingAndSamplingRequirement {
        subject unit = sensingUnit;
    }

    satisfy measureRequirement by sensingUnit;
    satisfy sensitivityRequirement by sensingUnit;
    satisfy baselineRequirement by sensingUnit;
    satisfy timingRequirement by sensingUnit;
}
