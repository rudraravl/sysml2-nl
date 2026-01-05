package 'Atomic Gravitational Wave Interferometric Sensor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;

    comment about SensingUnit
    /* This model describes an atomic gravitational wave interferometric sensor
     * that uses ultra-cold atoms in a matter-wave interferometer to detect
     * gravitational wave strain through differential phase measurements.
     * The sensor exploits quantum interference of atomic wave packets to
     * measure spacetime distortions with exceptional sensitivity. */

    attribute def StrainUnit :> SimpleUnit {
        attribute :>> name = "dimensionless";
    }

    attribute def StrainValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : StrainUnit;
    }

    attribute def PhaseAngleValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::AngleUnit;
    }

    attribute def TemperatureValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::TemperatureUnit;
    }

    attribute def PressureValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::PressureUnit;
    }

    attribute def PowerValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::PowerUnit;
    }

    attribute def VelocityValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::SpeedUnit;
    }

    attribute def VolumeValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::VolumeUnit;
    }

    attribute def EnergyValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::EnergyUnit;
    }

    item def AtomCloud {
        attribute atomCount : Integer;
        attribute temperature : TemperatureValue;
        attribute species : String;
        attribute velocity : VelocityValue;
    }

    item def LaserPulse {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute duration : TimeValue;
        attribute frequency : FrequencyValue;
    }

    item def InterferenceSignal {
        attribute phaseDifference : PhaseAngleValue;
        attribute contrast : Real;
        attribute timestamp : TimeValue;
    }

    item def GravitationalWaveData {
        attribute strain : StrainValue;
        attribute frequency : FrequencyValue;
        attribute amplitude : Real;
        attribute signalToNoiseRatio : Real;
    }

    port def LaserPort {
        in item laserPulse : LaserPulse;
    }

    port def AtomPort {
        out item atomCloud : AtomCloud;
    }

    port def VacuumPort {
        attribute pressure : PressureValue;
    }

    port def DetectionPort {
        out item interferenceSignal : InterferenceSignal;
    }

    port def DataOutputPort {
        out item gravitationalWaveData : GravitationalWaveData;
    }

    action def CoolAndTrapAtoms {
        in item initialAtoms : AtomCloud;
        in item coolingLasers : LaserPulse[6];
        out item ultracoldAtoms : AtomCloud;
    }

    action def LaunchAtomCloud {
        in item ultracoldAtoms : AtomCloud;
        in item launchPulse : LaserPulse;
        out item launchedAtoms : AtomCloud;
    }

    action def ApplyBeamSplitterPulse {
        in item launchedAtoms : AtomCloud;
        in item splitterPulse : LaserPulse;
        out item atomWavePacket1 : AtomCloud;
        out item atomWavePacket2 : AtomCloud;
    }

    action def FreeEvolution {
        in item atomWavePacket1 : AtomCloud;
        in item atomWavePacket2 : AtomCloud;
        in attribute evolutionTime : TimeValue;
        out item evolvedPacket1 : AtomCloud;
        out item evolvedPacket2 : AtomCloud;
    }

    action def ApplyMirrorPulse {
        in item evolvedPacket1 : AtomCloud;
        in item evolvedPacket2 : AtomCloud;
        in item mirrorPulse : LaserPulse;
        out item reflectedPacket1 : AtomCloud;
        out item reflectedPacket2 : AtomCloud;
    }

    action def ApplyRecombinerPulse {
        in item reflectedPacket1 : AtomCloud;
        in item reflectedPacket2 : AtomCloud;
        in item recombinerPulse : LaserPulse;
        out item interferenceSignal : InterferenceSignal;
    }

    action def MeasurePopulation {
        in item interferenceSignal : InterferenceSignal;
        out attribute phaseMeasurement : PhaseAngleValue;
    }

    action def ComputeStrain {
        in attribute phaseMeasurement : PhaseAngleValue;
        in attribute calibrationFactor : Real;
        out item gravitationalWaveData : GravitationalWaveData;
    }

    action def PerformInterferometricMeasurement {
        in item initialAtoms : AtomCloud;
        in item laserPulses : LaserPulse[10];
        out item measuredData : GravitationalWaveData;

        action coolTrap : CoolAndTrapAtoms {
            in item initialAtoms;
            in item coolingLasers[6];
            out item ultracoldAtoms;
        }
        then launch;

        action launch : LaunchAtomCloud {
            in item ultracoldAtoms;
            in item launchPulse;
            out item launchedAtoms;
        }
        then beamSplit;

        action beamSplit : ApplyBeamSplitterPulse {
            in item launchedAtoms;
            in item splitterPulse;
            out item atomWavePacket1;
            out item atomWavePacket2;
        }
        then evolve1;

        action evolve1 : FreeEvolution {
            in item atomWavePacket1;
            in item atomWavePacket2;
            in attribute evolutionTime;
            out item evolvedPacket1;
            out item evolvedPacket2;
        }
        then mirror;

        action mirror : ApplyMirrorPulse {
            in item evolvedPacket1;
            in item evolvedPacket2;
            in item mirrorPulse;
            out item reflectedPacket1;
            out item reflectedPacket2;
        }
        then evolve2;

        action evolve2 : FreeEvolution {
            in item reflectedPacket1;
            in item reflectedPacket2;
            in attribute evolutionTime;
            out item evolvedPacket1;
            out item evolvedPacket2;
        }
        then recombine;

        action recombine : ApplyRecombinerPulse {
            in item evolvedPacket1;
            in item evolvedPacket2;
            in item recombinerPulse;
            out item interferenceSignal;
        }
        then measure;

        action measure : MeasurePopulation {
            in item interferenceSignal;
            out attribute phaseMeasurement;
        }
        then compute;

        action compute : ComputeStrain {
            in attribute phaseMeasurement;
            in attribute calibrationFactor;
            out item gravitationalWaveData;
        }

        flow from coolTrap.ultracoldAtoms to launch.ultracoldAtoms;
        flow from launch.launchedAtoms to beamSplit.launchedAtoms;
        flow from beamSplit.atomWavePacket1 to evolve1.atomWavePacket1;
        flow from beamSplit.atomWavePacket2 to evolve1.atomWavePacket2;
        flow from evolve1.evolvedPacket1 to mirror.evolvedPacket1;
        flow from evolve1.evolvedPacket2 to mirror.evolvedPacket2;
        flow from mirror.reflectedPacket1 to evolve2.reflectedPacket1;
        flow from mirror.reflectedPacket2 to evolve2.reflectedPacket2;
        flow from evolve2.evolvedPacket1 to recombine.evolvedPacket1;
        flow from evolve2.evolvedPacket2 to recombine.evolvedPacket2;
        flow from recombine.interferenceSignal to measure.interferenceSignal;
        flow from measure.phaseMeasurement to compute.phaseMeasurement;

        bind compute.gravitationalWaveData = measuredData;
    }

    state def SensorOperationalState {
        entry; then initialization;

        state initialization;
        then vacuumCheck;

        state vacuumCheck;
        accept at vacuumCheck then atomLoading;

        state atomLoading;
        accept at atomLoading then cooling;

        state cooling;
        accept at cooling then ready;

        state ready;
        accept at ready then measuring;

        state measuring {
            do action performMeasurement : PerformInterferometricMeasurement;
        }
        accept at measuring then dataProcessing;

        state dataProcessing;
        accept at dataProcessing then outputData;

        state outputData;
        accept at outputData then ready;
    }

    part def VacuumChamber {
        attribute volume : VolumeValue;
        attribute operatingPressure : PressureValue;
        attribute material : String;
        port vacuumPort : VacuumPort;
    }

    part def LaserSystem {
        attribute totalLasers : Integer;
        part coolingLasers : LaserSource[6];
        part launchLaser : LaserSource[1];
        part splitterLaser : LaserSource[1];
        part mirrorLaser : LaserSource[1];
        part recombinerLaser : LaserSource[1];
        port laserOutputs : LaserPort[10];
    }

    part def LaserSource {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute linewidth : FrequencyValue;
        attribute stability : Real;
        attribute pulseWidth : TimeValue;
    }

    part def AtomicSource {
        attribute atomicSpecies : String;
        attribute loadingRate : Real;
        attribute sourceTemperature : TemperatureValue;
        part reservoir;
        part dispenser;
        port atomOutput : AtomPort;
    }

    part def MagnetoOpticalTrap {
        attribute trapDepth : EnergyValue;
        attribute trapFrequency : FrequencyValue;
        attribute captureVolume : VolumeValue;
        part magneticCoils[6];
        part opticalBeams[6];
        port coolingPort : LaserPort;
        port atomPort : AtomPort;
    }

    part def StateDetector {
        attribute quantumEfficiency : Real;
        attribute spatialResolution : LengthValue;
        attribute detectionBandwidth : FrequencyValue;
        part fluorescenceImager;
        part absorptionImager;
        part signalAmplifier;
        port detectionPort : DetectionPort;
    }

    part def SignalProcessingUnit {
        attribute samplingRate : FrequencyValue;
        attribute processingBandwidth : FrequencyValue;
        attribute dynamicRange : Real;
        part analogToDigitalConverter;
        part digitalSignalProcessor;
        part phaseExtractor;
        part noiseFilter;
        part strainCalculator;
        port dataInput : DetectionPort;
        port dataOutput : DataOutputPort;
    }

    part def ControlSystem {
        attribute controlLoopRate : FrequencyValue;
        part laserController;
        part magneticFieldController;
        part timingSequencer;
        part feedbackController;
    }

    part def AtomicGravitationalWaveInterferometricSensor {
        attribute sensorIdentifier : String;
        attribute targetSensitivity : StrainValue;
        attribute operatingFrequencyBand : FrequencyValue[2];
        attribute interferometerTime : TimeValue;
        attribute baselineLength : LengthValue;

        part vacuumChamber : VacuumChamber[1] {
            attribute :>> volume = 0.216[SI::m^3];
            attribute :>> operatingPressure = 5.0e-12[SI::Pa];
            attribute :>> material = "Stainless Steel 316L";
        }

        part laserSystem : LaserSystem[1] {
            attribute :>> totalLasers = 10;
            part :>> coolingLasers {
                attribute :>> wavelength = 780.241e-9[SI::m];
                attribute :>> power = 0.025[SI::W];
                attribute :>> linewidth = 5.0e5[SI::Hz];
                attribute :>> stability = 1.0e-7;
                attribute :>> pulseWidth = 1.0e-3[SI::s];
            }
            part :>> launchLaser {
                attribute :>> wavelength = 780.241e-9[SI::m];
                attribute :>> power = 0.100[SI::W];
                attribute :>> pulseWidth = 5.0e-6[SI::s];
            }
            part :>> splitterLaser {
                attribute :>> wavelength = 780.241e-9[SI::m];
                attribute :>> power = 0.200[SI::W];
                attribute :>> pulseWidth = 1.0e-5[SI::s];
            }
            part :>> mirrorLaser {
                attribute :>> wavelength = 780.241e-9[SI::m];
                attribute :>> power = 0.200[SI::W];
                attribute :>> pulseWidth = 2.0e-5[SI::s];
            }
            part :>> recombinerLaser {
                attribute :>> wavelength = 780.241e-9[SI::m];
                attribute :>> power = 0.200[SI::W];
                attribute :>> pulseWidth = 1.0e-5[SI::s];
            }
        }

        part atomicSource : AtomicSource[1] {
            attribute :>> atomicSpecies = "Rubidium-87";
            attribute :>> loadingRate = 1.0e9;
            attribute :>> sourceTemperature = 373.15[SI::K];
        }

        part magnetoOpticalTrap : MagnetoOpticalTrap[1] {
            attribute :>> trapDepth = 1.38e-26[SI::J];
            attribute :>> trapFrequency = 150.0[SI::Hz];
            attribute :>> captureVolume = 1.0e-6[SI::m^3];
        }

        part stateDetector : StateDetector[1] {
            attribute :>> quantumEfficiency = 0.90;
            attribute :>> spatialResolution = 5.0e-6[SI::m];
            attribute :>> detectionBandwidth = 100.0e3[SI::Hz];
        }

        part signalProcessor : SignalProcessingUnit[1] {
            attribute :>> samplingRate = 50.0e3[SI::Hz];
            attribute :>> processingBandwidth = 10.0e3[SI::Hz];
            attribute :>> dynamicRange = 120.0;
        }

        part controlSystem : ControlSystem[1] {
            attribute :>> controlLoopRate = 1.0e3[SI::Hz];
        }

        part operationalStateMachine : SensorOperationalState[1];

        port dataOutput : DataOutputPort;

        connect laserSystem.laserOutputs[1] to magnetoOpticalTrap.coolingPort;
        connect atomicSource.atomOutput to magnetoOpticalTrap.atomPort;
        connect stateDetector.detectionPort to signalProcessor.dataInput;
        connect signalProcessor.dataOutput to dataOutput;

        perform action interferometry : PerformInterferometricMeasurement;
    }

    requirement def StrainSensitivityRequirement {
        doc /* The sensor shall achieve a strain sensitivity better than 1e-19 per square root Hz
         * in the frequency range of 0.1 Hz to 10 Hz to detect gravitational waves
         * from astrophysical sources. */

        subject sensor : AtomicGravitationalWaveInterferometricSensor;

        require constraint {
            sensor.targetSensitivity.num <= 1.0e-19
        }
    }

    requirement def FrequencyBandRequirement {
        doc /* The sensor shall operate in the low-frequency gravitational wave band
         * from 0.1 Hz to 10 Hz to complement existing ground-based detectors. */

        subject sensor : AtomicGravitationalWaveInterferometricSensor;

        require constraint {
            sensor.operatingFrequencyBand[1].num >= 0.1 and
            sensor.operatingFrequencyBand[2].num <= 10.0
        }
    }

    requirement def UltraHighVacuumRequirement {
        doc /* The vacuum chamber shall maintain ultra-high vacuum at pressure
         * below 1e-11 Pa to minimize atomic collisions and decoherence. */

        subject chamber : VacuumChamber;

        require constraint {
            chamber.operatingPressure.num <= 1.0e-11
        }
    }

    requirement def AtomTemperatureRequirement {
        doc /* The magneto-optical trap shall cool atoms to temperatures
         * below 1 microkelvin to achieve quantum degeneracy and minimize
         * thermal noise in the interferometer. */

        subject trap : MagnetoOpticalTrap;

        require constraint {
            trap.trapDepth.num >= 1.0e-27
        }
    }

    requirement def LaserStabilityRequirement {
        doc /* All laser sources shall have frequency stability better than 1e-6
         * to ensure coherent atom manipulation and accurate phase measurements. */

        subject laser : LaserSource;

        require constraint {
            laser.stability <= 1.0e-6
        }
    }

    requirement def DetectionEfficiencyRequirement {
        doc /* The state detector shall have quantum efficiency greater than 85%
         * to maximize signal-to-noise ratio in population measurements. */

        subject detector : StateDetector;

        require constraint {
            detector.quantumEfficiency >= 0.85
        }
    }

    requirement def InterferometerTimeRequirement {
        doc /* The interferometer shall support interrogation times up to 10 seconds
         * to maximize phase accumulation and strain sensitivity. */

        subject sensor : AtomicGravitationalWaveInterferometricSensor;

        require constraint {
            sensor.interferometerTime.num >= 10.0
        }
    }

    part sensingUnit : AtomicGravitationalWaveInterferometricSensor {
        attribute :>> sensorIdentifier = "AGWIS-PROTO-001";
        attribute :>> targetSensitivity = 5.0e-20[StrainUnit::dimensionless];
        attribute :>> operatingFrequencyBand = (0.1[SI::Hz], 10.0[SI::Hz]);
        attribute :>> interferometerTime = 10.0[SI::s];
        attribute :>> baselineLength = 100.0[SI::m];

        satisfy StrainSensitivityRequirement by sensingUnit;
        satisfy FrequencyBandRequirement by sensingUnit;
        satisfy UltraHighVacuumRequirement by sensingUnit.vacuumChamber;
        satisfy AtomTemperatureRequirement by sensingUnit.magnetoOpticalTrap;
        satisfy LaserStabilityRequirement by sensingUnit.laserSystem.coolingLasers;
        satisfy DetectionEfficiencyRequirement by sensingUnit.stateDetector;
        satisfy InterferometerTimeRequirement by sensingUnit;
    }
}
