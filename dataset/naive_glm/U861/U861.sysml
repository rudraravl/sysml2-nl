package SSIES {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def PlasmaDensity :> Real { unit 'm^-3'; }
    value def PlasmaTemperature :> Real { unit 'K'; }
    value def DriftVelocity :> Real { unit 'm/s'; }
    value def ElectronEnergy :> Real { unit 'eV'; }
    value def ScintillationAmplitude :> Real { unit 'dB'; }
    value def ScintillationFrequency :> Real { unit 'Hz'; }
    value def PhaseVariation :> Real { unit 'rad'; }
    value def RetardingPotential :> Real { unit 'V'; }
    value def RegulatedVoltage :> Real { unit 'V'; }
    value def BusVoltage :> Real { unit 'V'; }
    value def PowerDraw :> Real {> Real { unit 'W'; }
    value def Timestamp :> Integer { unit 'ms'; }

    // ===== Item Definitions =====
    item def IonMeasurement {
        attribute density : PlasmaDensity;
        attribute temperature : PlasmaTemperature;
        attribute composition : String;
        attribute driftVelocity : DriftVelocity;
        attribute time : Timestamp;
    }

    item def ElectronMeasurement {
        attribute density : PlasmaDensity;
        attribute temperature : PlasmaTemperature;
        attribute energyLevel : ElectronEnergy;
        attribute retardingPotential : RetardingPotential;
        attribute time : Timestamp;
    }

    item def ScintillationData {
        attribute amplitude : ScintillationAmplitude;
        attribute frequency : ScintillationFrequency;
        attribute phaseVariation : PhaseVariation;
        attribute time : Timestamp;
    }

    item def InstrumentStatus {
        attribute mode : String;
        attribute health : String;
        attribute errorCode : Integer;
    }

    item def TelemetryPacket {
        attribute ionData : IonMeasurement;
        attribute electronData : ElectronMeasurement;
        attribute scintillation : ScintillationData;
        attribute status : InstrumentStatus;
        attribute timestamp : Timestamp;
    }

    item def SpacecraftCommand {
        attribute commandId : Integer;
        attribute targetMode : String;
    }

    item def RegulatedPower {
        attribute voltage : RegulatedVoltage;
        attribute current : Real;
    }

    item def BusPower {
        attribute voltage : BusVoltage;
        attribute current : Real;
    }

    // ===== Port Definitions =====
    port def IonMeasurementPort {
        out item ionData : IonMeasurement;
    }

    port def ElectronMeasurementPort {
        out item electronData : ElectronMeasurement;
    }

    port def ScintillationDataPort {
        out item scintillation : ScintillationData;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryPacket;
    }

    port def CommandPort {
        in item command : SpacecraftCommand;
    }

    port def PowerInputPort {
        in item busPower : BusPower;
    }

    port def PowerOutputPort {
        out item regulatedPower : RegulatedPower;
    }

    port def MeasurementInputPort {
        in item ionData : IonMeasurement;
        in item electronData : ElectronMeasurement;
    }

    // ===== State Machine for DPU Modes =====
    state def DPUStateMachine {
        entry; then Standby;

        state Standby {
            entry { send StandbyEntered; }
            transition standbyToContinuous
                first Standby
                accept command : SpacecraftCommand [command.targetMode == "continuous"]
                then ContinuousMeasurement;
            transition standbyToCalibration
                first Standby
                accept command : SpacecraftCommand [command.targetMode == "calibration"]
                then CalibrationMode;
        }

        state ContinuousMeasurement {
            entry { send ContinuousMeasurementEntered; }
            do { collectSensorData(); }
            transition continuousToStandby
                first ContinuousMeasurement
                accept command : SpacecraftCommand [command.targetMode == "standby"]
                then Standby;
            transition continuousToCalibration
                first ContinuousMeasurement
                accept command : SpacecraftCommand [command.targetMode == "calibration"]
                then CalibrationMode;
            transition continuousToSafe
                first ContinuousMeasurement
                accept fault : Boolean [fault == true]
                then SafeMode;
        }

        state CalibrationMode {
            entry { send CalibrationEntered; }
            do { performCalibration(); }
            transition calibrationToStandby
                first CalibrationMode
                accept command : SpacecraftCommand [command.targetMode == "standby"]
                then Standby;
            transition calibrationToContinuous
                first CalibrationMode
                accept command : SpacecraftCommand [command.targetMode == "continuous"]
                then ContinuousMeasurement;
            transition calibrationToSafe
                first CalibrationMode
                accept fault : Boolean [fault == true]
                then SafeMode;
        }

        state SafeMode {
            entry { send SafeModeEntered; }
            do { protectInstrument(); }
            transition safeToStandby
                first SafeMode
                accept command : SpacecraftCommand [command.targetMode == "standby"]
                then Standby;
        }
    }

    // ===== Part Definitions =====
    part def IonDriftMeter {
        port ionOut : IonMeasurementPort;
        port powerIn : PowerOutputPort;

        attribute measurementInterval : Integer = 1000;

        action def measureIons {
            in plasmaEnvironment : PlasmaDensity;
            out ionData : IonMeasurement;
        }

        perform measureIons;
    }

    part def RetardingPotentialAnalyzer {
        port electronOut : ElectronMeasurementPort;
        port powerIn : PowerOutputPort;

        attribute sweepVoltageRange : RetardingPotential = 0.0;

        action def measureElectrons {
            in retardingPotential : RetardingPotential;
            out electronData : ElectronMeasurement;
        }

        perform measureElectrons;
    }

    part def ScintillationMonitor {
        port measurementIn : MeasurementInputPort;
        port scintillationOut : ScintillationDataPort;
        port powerIn : PowerOutputPort;

        attribute analysisWindow : Integer = 5000;

        action def analyzeScintillation {
            in ionData : IonMeasurement;
            in electronData : ElectronMeasurement;
            out scintillation : ScintillationData;
        }

        perform analyzeScintillation;
    }

    part def DataProcessingUnit {
        port ionIn : IonMeasurementPort;
        port electronIn : ElectronMeasurementPort;
        port scintillationIn : ScintillationDataPort;
        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;
        port powerIn : PowerOutputPort;

        attribute currentMode : String = "standby";
        attribute faultDetected : Boolean = false;

        exhibit state dpuState : DPUStateMachine;

        action def collectSensorData {
            in ionData : IonMeasurement;
            in electronData : ElectronMeasurement;
            out scintillationRequest : MeasurementInputPort;
        }

        action def packageTelemetry {
            in ionData : IonMeasurement;
            in electronData : ElectronMeasurement;
            in scintillation : ScintillationData;
            in status : InstrumentStatus;
            out telemetry : TelemetryPacket;
        }

        action def performCalibration {
            out calibrationResult : Boolean;
        }

        action def protectInstrument {
            out safeStatus : InstrumentStatus;
        }
    }

    part def PowerRegulator {
        port busPowerIn : PowerInputPort;
        port regulatedPowerOut : PowerOutputPort;

        attribute nominalVoltage : RegulatedVoltage = 5.0;
        attribute maxPower : PowerDraw = 50.0;

        action def regulatePower {
            in busPower : BusPower;
            out regulatedPower : RegulatedPower;
        }

        perform regulatePower;
    }

    part def SSIESInstrument {
        port spacecraftPower : PowerInputPort;
        port spacecraftCommand : CommandPort;
        port spacecraftTelemetry : TelemetryPort;

        part ionDriftMeter : IonDriftMeter;
        part rpa : RetardingPotentialAnalyzer;
        part scintillationMonitor : ScintillationMonitor;
        part dpu : DataProcessingUnit;
        part powerRegulator : PowerRegulator;

        connection powerBus connect powerRegulator.regulatedPowerOut to {
            ionDriftMeter.powerIn;
            rpa.powerIn;
            scintillationMonitor.powerIn;
            dpu.powerIn;
        }

        connection ionDataFlow connect ionDriftMeter.ionOut to dpu.ionIn;
        connection electronDataFlow connect rpa.electronOut to dpu.electronIn;
        connection scintillationDataFlow connect scintillationMonitor.scintillationOut to dpu.scintillationIn;

        connection ionToScintillation connect ionDriftMeter.ionOut to scintillationMonitor.measurementIn;
        connection electronToScintillation connect rpa.electronOut to scintillationMonitor.measurementIn;

        connection spacecraftPowerFlow connect spacecraftPower to powerRegulator.busPowerIn;
        connection commandFlow connect spacecraftCommand to dpu.commandIn;
        connection telemetryFlow connect dpu.telemetryOut to spacecraftTelemetry;
    }

    // ===== Requirements =====
    requirement def SSIESFunctionalRequirement {
        subject instrument : SSIESInstrument;
        requirement {
            The instrument shall measure ionospheric plasma properties including ion density, temperature, composition, and drift velocity.
        }
        requirement {
            The instrument shall measure electron properties including density, temperature, and energy levels using a retarding potential analyzer.
        }
        requirement {
            The instrument shall detect and characterize scintillation events by analyzing ion and electron measurement data.
        }
        requirement {
            The instrument shall package all scientific measurements, timestamp, and instrument status into a single telemetry packet for transmission to the spacecraft bus.
        }
        requirement {
            The instrument shall be powered by a dedicated power regulator that draws power from the main spacecraft bus and distributes regulated power to all subsystems.
        }
    }

    requirement def DPUOperationalRequirement {
        subject dpu : DataProcessingUnit;
        requirement {
            The DPU shall support standby, continuous measurement, and calibration operational modes.
        }
        requirement {
            The DPU shall accept mode transition commands from the spacecraft via the command interface.
        }
        requirement {
            The DPU shall automatically enter safe mode upon detection of an internal fault.
        }
        requirement {
            The DPU shall continuously gather data from the Ion Drift Meter and RPA during continuous measurement mode.
        }
        requirement {
            The DPU shall pass ion and electron measurement data to the Scintillation Monitor for analysis.
        }
    }

    requirement def ScintillationMonitorRequirement {
        subject monitor : ScintillationMonitor;
        requirement {
            The Scintillation Monitor shall measure the amplitude of plasma fluctuations in decibels.
        }
        requirement {
            The Scintillation Monitor shall measure the frequency of scintillation events in hertz.
        }
        requirement {
            The Scintillation Monitor shall measure phase variations of plasma disturbances in radians.
        }
    }

    requirement def PowerRegulatorRequirement {
        subject regulator : PowerRegulator;
        requirement {
            The Power Regulator shall provide a nominal regulated voltage of 5.0 V to all sensors and the DPU.
        }
        requirement {
            The Power Regulator shall not exceed a maximum power draw of 50.0 W from the spacecraft bus.
        }
    }

    requirement def SpacecraftInterfaceRequirement {
        subject instrument : SSIESInstrument;
        requirement {
            The instrument shall transmit telemetry packets to the spacecraft bus through a dedicated data interface.
        }
        requirement {
            The instrument shall receive operational commands from the spacecraft bus through a dedicated command interface.
        }
        requirement {
            The instrument shall draw electrical power from the spacecraft bus through a dedicated power interface.
        }
    }

    // ===== Satisfaction =====
    satisfaction satisfySSIESFunctional by instrument : SSIESInstrument {
        subject instrument satisfies SSIESFunctionalRequirement;
    }

    satisfaction satisfyDPUOperational by dpu : DataProcessingUnit {
        subject dpu satisfies DPUOperationalRequirement;
    }

    satisfaction satisfyScintillationMonitor by monitor : ScintillationMonitor {
        subject monitor satisfies ScintillationMonitorRequirement;
    }

    satisfaction satisfyPowerRegulator by regulator : PowerRegulator {
        subject regulator satisfies PowerRegulatorRequirement;
    }

    satisfaction satisfySpacecraftInterface by instrument : SSIESInstrument {
        subject instrument satisfies SpacecraftInterfaceRequirement;
    }
}
