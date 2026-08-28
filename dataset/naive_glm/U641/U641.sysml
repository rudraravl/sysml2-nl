package CryogenicParticleDetector {
    import ScalarValues::*;

    // ===== Value Types =====

    value type TemperatureK :> Real {
        unit "K";
    }

    value type ResistanceOhm :> Real {
        unit "ohm";
    }

    value type VoltageV :> Real {
        unit "V";
    }

    value type EnergyJ :> Real {
        unit "J";
    }

    value type EnergyEV :> Real {
        unit "eV";
    }

    value type HeatFlowW :> Real {
        unit "W";
    }

    value type PressurePa :> Real {
        unit "Pa";
    }

    value type TimeS :> Real {
        unit "s";
    }

    value type MassKg :> Real {
        unit "kg";
    }

    value type LengthM :> Real {
        unit "m";
    }

    // ===== Item Definitions =====

    item def Particle {
        attribute energy : EnergyEV;
        attribute particleType : String;
        attribute incidentAngle : Real;
    }

    item def HeatPulse {
        attribute energy : EnergyJ;
        attribute temperatureRise : TemperatureK;
        attribute duration : TimeS;
        attribute decayTime : TimeS;
    }

    item def ElectricalSignal {
        attribute voltage : VoltageV;
        attribute duration : TimeS;
        attribute snr : Real;
        attribute pulseHeight : VoltageV;
    }

    item def DigitalData {
        attribute samples : Real[0..*];
        attribute timestamp : TimeS;
        attribute energyEstimate : EnergyEV;
        attribute eventId : Integer;
        attribute pulseShape : String;
    }

    item def Coolant {
        attribute coolantType : String;
        attribute temperature : TemperatureK;
        attribute flowRate : Real;
    }

    // ===== Event Definitions for State Machine =====

    item def PowerOn;
    item def OperationalTempReached;
    item def CalibrationComplete;
    item def ParticleEvent;
    item def AcquisitionComplete;
    item def ShutdownCommand;
    item def RoomTempReached;
    item def FaultDetected;
    item def FaultCleared;

    // ===== Port Definitions =====

    port def ParticlePort {
        in particle : Particle;
    }

    port def ThermalFlowPort {
        flow heat : HeatPulse;
        flow coolant : Coolant;
    }

    port def SignalPort {
        out outputSignal : ElectricalSignal;
        in inputSignal : ElectricalSignal;
    }

    port def DataPort {
        out data : DigitalData;
    }

    port def CommandPort {
        out command : String;
        in status : String;
    }

    // ===== Calculation Definitions =====

    calc def EnergyEstimateCalc {
        in pulseHeight : VoltageV;
        in calibrationFactor : Real;
        in amplifierGain : Real;
        return energy : EnergyEV;
    }

    calc def TemperatureRiseCalc {
        in particleEnergy : EnergyJ;
        in heatCapacity : Real;
        return temperatureRise : TemperatureK;
    }

    // ===== Part Definitions =====

    part def CryogenicAbsorber {
        attribute operationalTemperature : TemperatureK = 0.01;
        attribute heatCapacity : Real = 1.0e-9;
        attribute material : String = "Germanium";
        attribute mass : MassKg = 0.5;
        attribute dimensions : LengthM = 0.05;

        port particleIn : ParticlePort;
        port thermalOut : ThermalFlowPort;
        port thermalCooling : ThermalFlowPort;

        action def absorbParticle {
            in particle : Particle;
            out heatPulse : HeatPulse;
        }

        action def thermalize {
            in heatPulse : HeatPulse;
            out thermalSignal : HeatPulse;
        }
    }

    part def DilutionRefrigerator {
        attribute baseTemperature : TemperatureK = 0.008;
        attribute coolingPower : HeatFlowW = 1.0e-3;
        attribute mixTemperature : TemperatureK;
        attribute stillTemperature : TemperatureK;
        attribute circulationRate : Real;

        port coolantOut : ThermalFlowPort;
        port commandIn : CommandPort;

        action def coolDown {
            attribute duration : TimeS = 259200;
            attribute phase : String;
        }

        action def circulateHe3 {
            in coolant : Coolant;
            out cooledCoolant : Coolant;
        }
    }

    part def ThermalLink {
        attribute thermalConductance : Real = 1.0e-6;
        attribute thermalResistance : Real = 1.0e6;
        attribute material : String = "Silver";
        attribute length : LengthM = 0.02;
        attribute crossSection : Real;

        port hotSide : ThermalFlowPort;
        port coldSide : ThermalFlowPort;
    }

    part def ThermistorSensor {
        attribute nominalResistance : ResistanceOhm = 1.0e6;
        attribute temperatureCoefficient : Real = -0.1;
        attribute currentResistance : ResistanceOhm;
        attribute biasCurrent : Real = 1.0e-9;
        attribute sensitivity : TemperatureK = 1.0e-6;

        port thermalIn : ThermalFlowPort;
        port signalOut : SignalPort;

        action def measureTemperature {
            in heatPulse : HeatPulse;
            out signal : ElectricalSignal;
        }

        action def calibrate {
            in referenceTemp : TemperatureK;
            out calibratedResistance : ResistanceOhm;
        }
    }

    part def VacuumChamber {
        attribute pressure : PressurePa = 1.0e-5;
        attribute wallThickness : LengthM = 0.01;
        attribute material : String = "Stainless Steel";
        attribute innerDiameter : LengthM = 0.5;
        attribute leakRate : Real;

        action def evacuate {
            attribute targetPressure : PressurePa = 1.0e-5;
        }
    }

    part def RadiationShield {
        attribute material : String = "Lead";
        attribute thickness : LengthM = 0.1;
        attribute layers : Integer = 5;
        attribute attenuationFactor : Real = 1000;
        attribute innerLayerMaterial : String = "Copper";

        port particleIn : ParticlePort;
        port particleOut : ParticlePort;

        action def attenuateBackground {
            in incoming : Particle;
            out attenuated : Particle;
        }
    }

    part def LowNoiseAmplifier {
        attribute gain : Real = 1000;
        attribute noiseFloor : VoltageV = 1.0e-9;
        attribute bandwidth : Real = 1.0e4;
        attribute inputImpedance : ResistanceOhm = 1.0e9;
        attribute powerConsumption : Real;

        port signalIn : SignalPort;
        port signalOut : SignalPort;

        action def amplify {
            in inputSignal : ElectricalSignal;
            out outputSignal : ElectricalSignal;
        }
    }

    part def DigitalAcquisitionSystem {
        attribute samplingRate : Real = 1.0e6;
        attribute resolutionBits : Integer = 16;
        attribute bufferSize : Integer = 4096;
        attribute triggerLevel : VoltageV = 5.0e-6;
        attribute dynamicRange : Real;

        port signalIn : SignalPort;
        port dataOut : DataPort;
        port commandIn : CommandPort;

        action def digitize {
            in analogSignal : ElectricalSignal;
            out digitalData : DigitalData;
        }

        action def trigger {
            in signal : ElectricalSignal;
            out triggered : Boolean;
        }

        action def reconstructPulse {
            in samples : Real[0..*];
            out pulseShape : String;
            out energyEstimate : EnergyEV;
        }
    }

    part def ControlElectronics {
        attribute systemState : String;
        attribute clockFrequency : Real = 1.0e8;
        attribute watchdogTimeout : TimeS = 60;
        attribute logCapacity : Integer = 10000;

        port commandOut : CommandPort;
        port dataIn : DataPort;

        action def manageSystem {
            in command : String;
            out status : String;
        }

        action def logEvent {
            in data : DigitalData;
            out logged : Boolean;
        }

        action def performDiagnostics {
            out healthStatus : String;
        }
    }

    // ===== State Machine Definition =====

    state def DetectorLifecycle {
        entry; then offline;

        state offline {
            entry { /* System at room temperature, powered off */ }
            do { /* All subsystems de-energized */ }
        }

        state cooldown {
            entry { /* Begin cooling process via dilution refrigerator */ }
            do { /* Active cooling; may take several days */ }
            exit { /* Verify temperature approaching operational point */ }
        }

        state stabilized {
            entry { /* Temperature stabilizes at operational point */ }
            do { /* Fine-tune temperature control and thermistor bias */ }
            exit { /* Calibration sequence initiated */ }
        }

        state ready {
            entry { /* Awaiting particle events */ }
            do { /* Monitor thermistor output for signal above trigger threshold */ }
        }

        state acquiring {
            entry { /* Particle event detected; begin data acquisition */ }
            do { /* Digitize pulse, reconstruct energy, log event */ }
            exit { /* Data acquisition complete; reset trigger */ }
        }

        state warmup {
            entry { /* Controlled warm-up procedure initiated */ }
            do { /* Gradually increase temperature to avoid thermal shock */ }
            exit { /* Verify safe state for maintenance */ }
        }

        state fault {
            entry { /* Fault condition detected; engage safety protocols */ }
            do { /* Run diagnostics; isolate fault; protect detector */ }
            exit { /* Fault cleared; return to safe state */ }
        }

        transition t_off_to_cool
            from offline to cooldown
            accept PowerOn;

        transition t_cool_to_stable
            from cooldown to stabilized
            accept OperationalTempReached;

        transition t_stable_to_ready
            from stabilized to ready
            accept CalibrationComplete;

        transition t_ready_to_acquire
            from ready to acquiring
            accept ParticleEvent;

        transition t_acquire_to_ready
            from acquiring to ready
            accept AcquisitionComplete;

        transition t_ready_to_warmup
            from ready to warmup
            accept ShutdownCommand;

        transition t_warmup_to_offline
            from warmup to offline
            accept RoomTempReached;

        transition t_offline_to_fault
            from offline to fault
            accept FaultDetected;

        transition t_cooldown_to_fault
            from cooldown to fault
            accept FaultDetected;

        transition t_stabilized_to_fault
            from stabilized to fault
            accept FaultDetected;

        transition t_ready_to_fault
            from ready to fault
            accept FaultDetected;

        transition t_acquiring_to_fault
            from acquiring to fault
            accept FaultDetected;

        transition t_warmup_to_fault
            from warmup to fault
            accept FaultDetected;

        transition t_fault_to_offline
            from fault to offline
            accept FaultCleared;
    }

    // ===== Requirements =====

    requirement def OperationalTemperatureRequirement {
        doc /* The absorber must be cooled to a few millikelvin for operation. */;
        subject absorber : CryogenicAbsorber;
        objective {
            assert absorber.operationalTemperature <= 0.02
        }
    }

    requirement def DetectionSensitivityRequirement {
        doc /* The thermistor must detect temperature changes at the microkelvin scale. */;
        subject sensor : ThermistorSensor;
        objective {
            assert sensor.sensitivity <= 1.0e-5
        }
    }

    requirement def BackgroundRadiationRequirement {
        doc /* The radiation shield must reduce background radiation by at least a factor of 1000. */;
        subject shield : RadiationShield;
        objective {
            assert shield.attenuationFactor >= 1000
        }
    }

    requirement def VacuumInsulationRequirement {
        doc /* The vacuum chamber must maintain high vacuum for thermal insulation. */;
        subject chamber : VacuumChamber;
        objective {
            assert chamber.pressure <= 1.0e-4
        }
    }

    requirement def AmplifierNoiseRequirement {
        doc /* The amplifier must boost signal without adding significant electronic noise. */;
        subject amp : LowNoiseAmplifier;
        objective {
            assert amp.noiseFloor <= 1.0e-8
            assert amp.gain >= 100
        }
    }

    requirement def DAQResolutionRequirement {
        doc /* The DAQ must capture pulse shape with sufficient resolution. */;
        subject daq : DigitalAcquisitionSystem;
        objective {
            assert daq.resolutionBits >= 16
            assert daq.samplingRate >= 1.0e5
        }
    }

    requirement def CooldownTimeRequirement {
        doc /* The system must complete cooldown within a reasonable timeframe. */;
        subject fridge : DilutionRefrigerator;
        objective {
            assert fridge.baseTemperature <= 0.01
        }
    }

    requirement def ThermalIsolationRequirement {
        doc /* The thermal link must provide sufficient isolation for temperature spikes to be visible. */;
        subject link : ThermalLink;
        objective {
            assert link.thermalResistance >= 1.0e5
        }
    }

    // ===== System Assembly =====

    part def CryogenicParticleDetectorSystem {
        attribute systemName : String = "CryoDetector-Alpha";
        attribute serialNumber : String;
        attribute firmwareVersion : String = "2.1.0";

        part radiationShield : RadiationShield;
        part vacuumChamber : VacuumChamber;
        part absorber : CryogenicAbsorber;
        part thermalLink : ThermalLink;
        part refrigerator : DilutionRefrigerator;
        part thermistor : ThermistorSensor;
        part amplifier : LowNoiseAmplifier;
        part daq : DigitalAcquisitionSystem;
        part controller : ControlElectronics;

        // Connections: particle path
        connection particlePath
            from radiationShield.particleOut to absorber.particleIn;

        // Connections: cooling path
        connection coolingPath
            from refrigerator.coolantOut to thermalLink.coldSide;

        connection thermalLinkPath
            from thermalLink.hotSide to absorber.thermalCooling;

        // Connections: sensing path
        connection sensingPath
            from absorber.thermalOut to thermistor.thermalIn;

        // Connections: signal chain
        connection signalPath1
            from thermistor.signalOut to amplifier.signalIn;

        connection signalPath2
            from amplifier.signalOut to daq.signalIn;

        // Connections: data path
        connection dataPath
            from daq.dataOut to controller.dataIn;

        // Connections: command paths
        connection commandPath1
            from controller.commandOut to refrigerator.commandIn;

        connection commandPath2
            from controller.commandOut to daq.commandIn;

        // Lifecycle behavior
        exhibit DetectorLifecycle;

        // Requirement satisfaction
        satisfy OperationalTemperatureRequirement by absorber;
        satisfy DetectionSensitivityRequirement by thermistor;
        satisfy BackgroundRadiationRequirement by radiationShield;
        satisfy VacuumInsulationRequirement by vacuumChamber;
        satisfy AmplifierNoiseRequirement by amplifier;
        satisfy DAQResolutionRequirement by daq;
        satisfy CooldownTimeRequirement by refrigerator;
        satisfy ThermalIsolationRequirement by thermalLink;
    }
}
