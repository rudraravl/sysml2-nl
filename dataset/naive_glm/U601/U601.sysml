package AGWIS {
    public import ISQ::*;

    // ---- Value Types ----
    value type Temperature specializes Real { unit 'K'; }
    value type Pressure specializes Real { unit 'Pa'; }
    value type Frequency specializes Real { unit 'Hz'; }
    value type Strain specializes Real { unit '1'; }
    value type Length specializes Real { unit 'm'; }
    value type Duration specializes Real { unit 's'; }
    value type Phase specializes Real { unit 'rad'; }
    value type MagneticFluxDensity specializes Real { unit 'T'; }
    value type OpticalPower specializes Real { unit 'W'; }
    value type Velocity specializes Real { unit 'm/s'; }
    value type Amplitude specializes Real { unit 'm'; }
    value type Mass specializes Real { unit 'kg'; }

    // ---- Enumerations ----
    enum LaserPulseKind { launch; beamSplitter; mirror; recombine; }
    enum AtomState { hot; cooled; launched; split; recombined; detected; }
    enum OperationalMode { standby; initialization; loadingCooling; measurement; processing; ready; }

    // ---- Item Definitions ----
    item def Rubidium87Atom {
        attribute mass : Mass = 1.443e-25;
        attribute isotope : String = "Rb-87";
    }

    item def AtomCloud {
        attribute temperature : Temperature;
        attribute atomCount : Integer;
        attribute state : AtomState;
        attribute position : Length;
        attribute velocity : Velocity;
        attribute phaseShift : Phase;
    }

    item def LaserPulse {
        attribute kind : LaserPulseKind;
        attribute duration : Duration;
        attribute frequency : Frequency;
        attribute power : OpticalPower;
        attribute timing : Duration;
    }

    item def GravitationalWave {
        attribute strain : Strain;
        attribute frequency : Frequency;
        attribute amplitude : Amplitude;
    }

    item def InterferencePattern {
        attribute phaseShift : Phase;
        attribute visibility : Real;
    }

    item def RawSignal {
        attribute phaseShift : Phase;
        attribute noiseLevel : Real;
        attribute timestamp : Duration;
    }

    item def ProcessedData {
        attribute strain : Strain;
        attribute frequency : Frequency;
        attribute amplitude : Amplitude;
        attribute confidence : Real;
        attribute timestamp : Duration;
    }

    item def ControlCommand {
        attribute target : String;
        attribute action : String;
        attribute timestamp : Duration;
    }

    item def TimingSignal {
        attribute timestamp : Duration;
        attribute precision : Duration;
    }

    // ---- Port Definitions ----
    port def AtomFlowPort {
        out item atomCloud : AtomCloud;
    }

    port def OpticalFlowPort {
        out item laserPulse : LaserPulse;
    }

    port def SignalFlowPort {
        out item rawSignal : RawSignal;
    }

    port def DataFlowPort {
        out item processedData : ProcessedData;
    }

    port def ControlFlowPort {
        out item command : ControlCommand;
        in item timing : TimingSignal;
    }

    port def MagneticFieldFlowPort {
        out item fieldStrength : MagneticFluxDensity;
    }

    port def VacuumFlowPort {
        out item pressure : Pressure;
    }

    // ---- Part Definitions ----
    part def VacuumChamber {
        attribute material : String = "Stainless Steel";
        attribute height : Length = 3.0;
        attribute diameter : Length = 0.5;
        attribute targetPressure : Pressure = 1.0e-9;
        attribute currentPressure : Pressure;

        port vacuumOut : VacuumFlowPort;
        port atomRegion : AtomFlowPort;

        action def MaintainVacuum {
            in item currentPressure : Pressure;
            out item maintainedPressure : Pressure;
        }

        perform MaintainVacuum;
    }

    part def AtomicSource {
        attribute isotope : String = "Rubidium-87";
        attribute releaseTemperature : Temperature = 300.0;
        attribute reservoirCapacity : Integer = 1000000;

        port atomOut : AtomFlowPort;

        action def ReleaseAtoms {
            out item releasedCloud : AtomCloud;
        }

        perform ReleaseAtoms;
    }

    part def MagnetoOpticalTrap {
        attribute targetTemperature : Temperature = 1.0e-6;
        attribute magneticFieldGradient : MagneticFluxDensity = 0.1;
        attribute coolingLaserPower : OpticalPower = 0.5;
        attribute coolingLaserWavelength : Length = 780e-9;

        port atomIn : AtomFlowPort;
        port atomOut : AtomFlowPort;
        port magneticOut : MagneticFieldFlowPort;
        port opticalIn : OpticalFlowPort;

        action def CaptureAndCool {
            in item hotCloud : AtomCloud;
            in item coolingPulse : LaserPulse;
            out item cooledCloud : AtomCloud;
        }

        perform CaptureAndCool;
    }

    part def LaserSystem {
        attribute wavelength : Length = 780e-9;
        attribute pulsePrecision : Duration = 1.0e-9;
        attribute maxPower : OpticalPower = 5.0;

        port opticalOut : OpticalFlowPort;
        port controlIn : ControlFlowPort;

        action def EmitPulse {
            in item command : ControlCommand;
            out item pulse : LaserPulse;
        }

        action def LaunchSequence {
            out item launchPulse : LaserPulse;
        }

        action def BeamSplitterSequence {
            out item splitPulse : LaserPulse;
        }

        action def MirrorSequence {
            out item mirrorPulse : LaserPulse;
        }

        action def RecombineSequence {
            out item recombinePulse : LaserPulse;
        }

        perform EmitPulse;
    }

    part def StateDetector {
        attribute resolution : Length = 1.0e-6;
        attribute integrationTime : Duration = 0.01;
        attribute cameraType : String = "High-Resolution CCD";

        port atomIn : AtomFlowPort;
        port signalOut : SignalFlowPort;

        action def DetectState {
            in item atomCloud : AtomCloud;
            out item pattern : InterferencePattern;
        }

        action def GenerateRawSignal {
            in item pattern : InterferencePattern;
            out item signal : RawSignal;
        }

        perform DetectState;
        perform GenerateRawSignal;
    }

    part def SignalProcessingUnit {
        attribute filterCutoff : Frequency = 100.0;
        attribute samplingRate : Frequency = 1000.0;
        attribute signalToNoiseThreshold : Real = 3.0;

        port signalIn : SignalFlowPort;
        port dataOut : DataFlowPort;

        action def FilterNoise {
            in item rawSignal : RawSignal;
            out item filteredSignal : RawSignal;
        }

        action def ExtractPhaseShift {
            in item filteredSignal : RawSignal;
            out item phaseShift : Phase;
        }

        action def CalculateStrain {
            in item phaseShift : Phase;
            out item strain : Strain;
        }

        action def CalculateWaveParameters {
            in item strain : Strain;
            out item data : ProcessedData;
        }

        perform FilterNoise;
        perform ExtractPhaseShift;
        perform CalculateStrain;
        perform CalculateWaveParameters;
    }

    part def ControlSystem {
        attribute cycleTime : Duration = 2.0;
        attribute timingPrecision : Duration = 1.0e-12;
        attribute mode : OperationalMode = OperationalMode::standby;

        port controlOut : ControlFlowPort;

        action def OrchestrateSequence {
            out item commands : ControlCommand[*];
        }

        action def ManageTiming {
            out item timing : TimingSignal;
        }

        action def TransitionMode {
            in item currentMode : OperationalMode;
            out item nextMode : OperationalMode;
        }

        perform OrchestrateSequence;
        perform ManageTiming;
    }

    // ---- Main System ----
    part def AtomicGravitationalWaveInterferometricSensor {
        attribute targetFrequencyRange : Frequency[2] = (0.1, 10.0);
        attribute sensitivityStrain : Strain = 1.0e-15;
        attribute systemName : String = "AGWIS";

        part vacuumChamber : VacuumChamber {
            attribute currentPressure : Pressure = 1.0e-9;
        }
        part atomicSource : AtomicSource;
        part magnetoOpticalTrap : MagnetoOpticalTrap;
        part laserSystem : LaserSystem;
        part stateDetector : StateDetector;
        part signalProcessingUnit : SignalProcessingUnit;
        part controlSystem : ControlSystem;

        connection atomSourceToTrap connect atomicSource.atomOut to magnetoOpticalTrap.atomIn;
        connection trapToDetector connect magnetoOpticalTrap.atomOut to stateDetector.atomIn;
        connection laserToTrap connect laserSystem.opticalOut to magnetoOpticalTrap.opticalIn;
        connection detectorToProcessor connect stateDetector.signalOut to signalProcessingUnit.signalIn;
        connection controlToLaser connect controlSystem.controlOut to laserSystem.controlIn;

        // ---- State Machine ----
        state machine SensorStateMachine {
            state standby;
            state initialization;
            state loadingCooling;
            state measurement;
            state processing;
            state ready;

            transition standby to initialization
                when controlSystem.mode == OperationalMode::standby;

            transition initialization to loadingCooling
                when vacuumChamber.currentPressure < 1.0e-8;

            transition loadingCooling to measurement
                when magnetoOpticalTrap.targetTemperature < 1.0e-5;

            transition measurement to processing
                when stateDetector.signalOut.rawSignal.phaseShift != 0.0;

            transition processing to ready
                when signalProcessingUnit.dataOut.processedData.confidence > 0.5;

            transition ready to loadingCooling
                when controlSystem.cycleTime > 0.0;
        }

        // ---- Composite Action ----
        action def DetectionCycle {
            action initialize {
                out item vacuumReady : Pressure;
            }

            action loadAndCool {
                in item vacuumReady : Pressure;
                out item cooledCloud : AtomCloud;
            }

            action launchAtoms {
                in item cooledCloud : AtomCloud;
                in item launchPulse : LaserPulse;
                out item launchedCloud : AtomCloud;
            }

            action splitWavePackets {
                in item launchedCloud : AtomCloud;
                in item splitPulse : LaserPulse;
                out item splitCloud : AtomCloud;
            }

            action mirrorWavePackets {
                in item splitCloud : AtomCloud;
                in item mirrorPulse : LaserPulse;
                out item mirroredCloud : AtomCloud;
            }

            action recombineWavePackets {
                in item mirroredCloud : AtomCloud;
                in item recombinePulse : LaserPulse;
                out item recombinedCloud : AtomCloud;
            }

            action detectInterference {
                in item recombinedCloud : AtomCloud;
                out item pattern : InterferencePattern;
            }

            action processData {
                in item pattern : InterferencePattern;
                out item data : ProcessedData;
            }

            flow initialize.vacuumReady to loadAndCool.vacuumReady;
            flow loadAndCool.cooledCloud to launchAtoms.cooledCloud;
            flow launchAtoms.launchedCloud to splitWavePackets.launchedCloud;
            flow splitWavePackets.splitCloud to mirrorWavePackets.splitCloud;
            flow mirrorWavePackets.mirroredCloud to recombineWavePackets.mirroredCloud;
            flow recombineWavePackets.recombinedCloud to detectInterference.recombinedCloud;
            flow detectInterference.pattern to processData.pattern;
        }

        perform DetectionCycle;
    }

    // ---- Requirements ----
    requirement def VacuumRequirement {
        subject chamber : VacuumChamber;
        objective {
            doc "The vacuum chamber shall maintain ultra-high vacuum below 1.0e-8 Pa to ensure a pristine environment free from interfering particles.";
            chamber.targetPressure < 1.0e-8
        }
    }

    requirement def CoolingRequirement {
        subject trap : MagnetoOpticalTrap;
        objective {
            doc "The magneto-optical trap shall cool Rubidium-87 atoms to temperatures below 1.0e-5 K, just fractions of a degree above absolute zero.";
            trap.targetTemperature < 1.0e-5
        }
    }

    requirement def TimingPrecisionRequirement {
        subject controller : ControlSystem;
        objective {
            doc "The control system shall manage the timing of lasers and magnetic fields with precision better than 1.0e-12 s.";
            controller.timingPrecision < 1.0e-12
        }
    }

    requirement def SensitivityRequirement {
        subject sensor : AtomicGravitationalWaveInterferometricSensor;
        objective {
            doc "The sensor shall detect gravitational wave strains down to 1.0e-15 by measuring phase shifts in the atomic matter-wave interference pattern.";
            sensor.sensitivityStrain <= 1.0e-15
        }
    }

    requirement def FrequencyRangeRequirement {
        subject sensor : AtomicGravitationalWaveInterferometricSensor;
        objective {
            doc "The sensor shall target the low-frequency gravitational wave spectrum from 0.1 Hz to 10 Hz, which is difficult to observe with ground-based light interferometers.";
            sensor.targetFrequencyRange(1) >= 0.1 and sensor.targetFrequencyRange(2) <= 10.0
        }
    }

    requirement def CycleTimeRequirement {
        subject sensor : AtomicGravitationalWaveInterferometricSensor;
        objective {
            doc "The sensor shall complete a full detection cycle, from initialization through data processing, within 2 seconds.";
            sensor.controlSystem.cycleTime <= 2.0
        }
    }

    requirement def InterferometerSequenceRequirement {
        subject laser : LaserSystem;
        objective {
            doc "The laser system shall project a series of precisely timed laser pulses including launch, beam-splitter, mirror, and recombine pulses to create and measure the matter-wave interferometer.";
            laser.pulsePrecision < 1.0e-9
        }
    }

    requirement def StateDetectionRequirement {
        subject detector : StateDetector;
        objective {
            doc "The state detector shall measure the final quantum state of the atoms using high-resolution imaging to read the interference pattern.";
            detector.resolution < 1.0e-5
        }
    }

    requirement def SignalProcessingRequirement {
        subject processor : SignalProcessingUnit;
        objective {
            doc "The signal processing unit shall filter noise, extract phase shift information, and calculate the strain, frequency, and amplitude of the detected gravitational wave.";
            processor.signalToNoiseThreshold >= 3.0
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction VacuumRequirement by vacuumChamber;
    satisfaction CoolingRequirement by magnetoOpticalTrap;
    satisfaction TimingPrecisionRequirement by controlSystem;
    satisfaction SensitivityRequirement by AtomicGravitationalWaveInterferometricSensor;
    satisfaction FrequencyRangeRequirement by AtomicGravitationalWaveInterferometricSensor;
    satisfaction CycleTimeRequirement by AtomicGravitationalWaveInterferometricSensor;
    satisfaction InterferometerSequenceRequirement by laserSystem;
    satisfaction StateDetectionRequirement by stateDetector;
    satisfaction SignalProcessingRequirement by signalProcessingUnit;
}
