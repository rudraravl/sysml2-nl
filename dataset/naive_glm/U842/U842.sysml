package NVCenterMagnetometerSystem {
    import ScalarValues::*;
    import SI::*;

    // ================================================================
    // Enumerations
    // ================================================================

    enum MeasurementProtocol {
        ODMR;
        Rabi;
        Ramsey;
        HahnEcho;
        CPMG;
    }

    enum SystemMode {
        standby;
        continuous;
        pulsed;
        diagnostic;
    }

    // ================================================================
    // Value Types
    // ================================================================

    value type MagneticFluxDensity :> Real {
        doc "Magnetic field strength in tesla";
        :>> unit = T;
    }

    value type Temperature :> Real {
        doc "Temperature in kelvin";
        :>> unit = K;
    }

    value type OpticalPower :> Real {
        doc "Optical power in watts";
        :>> unit = W;
    }

    value type MicrowaveFrequency :> Real {
        doc "Frequency in hertz";
        :>> unit = Hz;
    }

    value type TimeDuration :> Real {
        doc "Duration in seconds";
        :>> unit = s;
    }

    value type Length :> Real {
        doc "Length in meters";
        :>> unit = m;
    }

    value type ElectricPotential :> Real {
        doc "Electric potential in volts";
        :>> unit = V;
    }

    value type ElectricCurrent :> Real {
        doc "Electric current in amperes";
        :>> unit = A;
    }

    value type ElectricPower :> Real {
        doc "Electric power in watts";
        :>> unit = W;
    }

    value type GyromagneticRatio :> Real {
        doc "Gyromagnetic ratio in GHz/T";
        :>> unit = Hz;
    }

    value type ConfidenceScore :> Real {
        doc "Statistical confidence score, dimensionless in range 0 to 1";
        :>> min = 0;
        :>> max = 1;
    }

    value type PhotonCountRate :> Real {
        doc "Photon detection count rate in counts per second";
        :>> unit = Hz;
    }

    value type DecoherenceTime :> Real {
        doc "Quantum decoherence time constant in seconds";
        :>> unit = s;
    }

    // ================================================================
    // Item Definitions
    // ================================================================

    item def OpticalPulse {
        doc "Laser pulse used to initialize or read out NV center spin states";
        attribute wavelength : Length;
        attribute power : OpticalPower;
        attribute duration : TimeDuration;
        attribute kind : String;
    }

    item def MicrowavePulse {
        doc "Microwave pulse to manipulate NV center spin states";
        attribute frequency : MicrowaveFrequency;
        attribute power : ElectricPower;
        attribute duration : TimeDuration;
        attribute phase : Real;
        attribute protocol : MeasurementProtocol;
    }

    item def FluorescenceEmission {
        doc "Photons emitted by NV centers during optical readout";
        attribute photonCount : Integer;
        attribute wavelength : Length;
        attribute emissionDuration : TimeDuration;
        attribute countRate : PhotonCountRate;
    }

    item def RawElectronicSignal {
        doc "Raw digitized voltage signal from photon detector";
        attribute voltage : ElectricPotential;
        attribute timestamp : TimeDuration;
        attribute sampleCount : Integer;
        attribute noiseLevel : ElectricPotential;
    }

    item def MeasurementResult {
        doc "Final processed magnetic field measurement with metadata";
        attribute magneticField : MagneticFluxDensity;
        attribute timestamp : TimeDuration;
        attribute confidence : ConfidenceScore;
        attribute measurementId : String;
        attribute protocol : MeasurementProtocol;
        attribute sequenceNumber : Integer;
    }

    item def OperationalParameters {
        doc "Configuration parameters for a measurement cycle";
        attribute laserPower : OpticalPower;
        attribute laserWavelength : Length;
        attribute microwaveFrequency : MicrowaveFrequency;
        attribute microwavePower : ElectricPower;
        attribute microwaveDuration : TimeDuration;
        attribute measurementDuration : TimeDuration;
        attribute operatingTemperature : Temperature;
        attribute protocol : MeasurementProtocol;
        attribute averagingCycles : Integer;
    }

    item def CommandMessage {
        doc "Operational command received from external controller";
        attribute command : String;
        attribute parameters : OperationalParameters;
        attribute priority : Integer;
    }

    item def PowerSupplyInput {
        doc "External electrical power supply specification";
        attribute voltage : ElectricPotential;
        attribute maxPower : ElectricPower;
        attribute current : ElectricCurrent;
    }

    item def ThermalStatus {
        doc "Thermal control loop status report";
        attribute currentTemperature : Temperature;
        attribute targetTemperature : Temperature;
        attribute heaterActive : Boolean;
        attribute coolerActive : Boolean;
    }

    // ================================================================
    // Port Definitions
    // ================================================================

    port def OpticalOutput {
        out item : OpticalPulse;
    }

    port def OpticalInput {
        in item : OpticalPulse;
    }

    port def MicrowaveOutput {
        out item : MicrowavePulse;
    }

    port def MicrowaveInput {
        in item : MicrowavePulse;
    }

    port def FluorescenceOutput {
        out item : FluorescenceEmission;
    }

    port def FluorescenceInput {
        in item : FluorescenceEmission;
    }

    port def RawSignalOutput {
        out item : RawElectronicSignal;
    }

    port def RawSignalInput {
        in item : RawElectronicSignal;
    }

    port def ResultOutput {
        out item : MeasurementResult;
    }

    port def CommandInput {
        in item : CommandMessage;
    }

    port def ElectricalPowerInput {
        in item : PowerSupplyInput;
    }

    port def TemperatureSignal {
        in attribute setpoint : Temperature;
        out attribute actual : Temperature;
        out attribute status : ThermalStatus;
    }

    // ================================================================
    // Component Part Definitions
    // ================================================================

    part def LaserSystem {
        doc "532 nm green laser system for NV center initialization and readout";

        port opticalOut : OpticalOutput;
        port powerIn : ElectricalPowerInput;

        attribute currentPower : OpticalPower;
        attribute wavelength : Length = 532.0e-9;
        attribute maxPower : OpticalPower = 1.0;
        attribute pulseDuration : TimeDuration = 1.0e-6;
        attribute dutyCycleLimit : Real = 0.1;
        attribute temperature : Temperature;

        state machine laserController {
            initial laserOff;
            state idle;
            state preparing;
            state reading;
            state cooldown;

            transition laserOff to idle when powerApplied;
            transition idle to preparing when prepareCommand;
            transition preparing to reading when prepareComplete;
            transition reading to cooldown when readoutComplete;
            transition cooldown to idle when cooldownTimerExpired;
        }

        action emitPreparePulse {
            doc "Emit a 532 nm pulse to optically pump NV centers into ms=0 spin state";
            in attribute power : OpticalPower;
            in attribute duration : TimeDuration;
            out item pulse : OpticalPulse;
        }

        action emitReadoutPulse {
            doc "Emit a 532 nm pulse to read out NV center spin state via fluorescence contrast";
            in attribute power : OpticalPower;
            in attribute duration : TimeDuration;
            out item pulse : OpticalPulse;
        }

        action stabilizeLaser {
            doc "Stabilize laser output power and wavelength through thermal and current feedback";
        }
    }

    part def MicrowaveGenerator {
        doc "Microwave synthesizer for NV center spin manipulation near 2.87 GHz";

        port mwOut : MicrowaveOutput;
        port powerIn : ElectricalPowerInput;

        attribute currentFrequency : MicrowaveFrequency;
        attribute currentPower : ElectricPower;
        attribute maxPower : ElectricPower = 10.0;
        attribute pulseDuration : TimeDuration = 5.0e-7;
        attribute frequencyResolution : MicrowaveFrequency = 1.0;
        attribute phaseNoise : Real;

        state machine mwController {
            initial mwOff;
            state idle;
            state transmitting;
            state tuning;

            transition mwOff to idle when powerApplied;
            transition idle to tuning when frequencyCommand;
            transition tuning to transmitting when tuneComplete;
            transition transmitting to idle when pulseComplete;
        }

        action emitMicrowavePulse {
            doc "Emit a calibrated microwave pulse at the NV zero-field splitting frequency";
            in attribute frequency : MicrowaveFrequency;
            in attribute power : ElectricPower;
            in attribute duration : TimeDuration;
            in attribute protocol : MeasurementProtocol;
            out item pulse : MicrowavePulse;
        }

        action calibrateFrequency {
            doc "Fine-tune microwave frequency to NV center resonance using ODMR sweep";
        }
    }

    part def DiamondSensor {
        doc "Engineered diamond with NV centers serving as the primary quantum sensing element";

        port opticalIn : OpticalInput;
        port mwIn : MicrowaveInput;
        port fluorescenceOut : FluorescenceOutput;
        port tempControl : TemperatureSignal;

        attribute operatingTemperature : Temperature = 293.15;
        attribute nvCenterDensity : Real = 3.0e18;
        attribute crystalDimension : Length = 1.0e-4;
        attribute fluorescenceEfficiency : Real = 0.7;
        attribute nvTransitionFrequency : MicrowaveFrequency = 2.87e9;
        attribute gyromagneticRatio : GyromagneticRatio = 28.024e9;
        attribute coherenceTimeT2 : DecoherenceTime = 1.0e-3;
        attribute relaxationTimeT1 : DecoherenceTime = 5.0e-3;
        attribute currentNvState : String = "ms_0";
        attribute accumulatedPhase : Real;

        state machine nvQuantumState {
            initial uninitialized;
            state ms0;
            state msSuperposition;
            state phaseAccumulated;
            state readoutEmitting;
            state reset;

            transition uninitialized to ms0 when preparePulseAbsorbed;
            transition ms0 to msSuperposition when microwavePulseAbsorbed;
            transition msSuperposition to phaseAccumulated when evolutionTimeElapsed;
            transition phaseAccumulated to readoutEmitting when readoutPulseAbsorbed;
            transition readoutEmitting to reset when fluorescenceEmitted;
            transition reset to ms0 when resetComplete;
        }

        action absorbLaserPulse {
            doc "Absorb incoming laser pulse and polarize NV centers into ms=0 ground state";
            in item pulse : OpticalPulse;
        }

        action absorbMicrowavePulse {
            doc "Absorb microwave pulse to drive spin transition into quantum superposition";
            in item pulse : MicrowavePulse;
        }

        action evolveUnderField {
            doc "Allow NV center spin superposition to accumulate Larmor phase under external magnetic field";
            in attribute evolutionTime : TimeDuration;
        }

        action emitFluorescence {
            doc "Emit fluorescence photons proportional to the ms=0 population after state projection";
            in attribute readoutPulse : OpticalPulse;
            out item emission : FluorescenceEmission;
        }
    }

    part def PhotonDetector {
        doc "Single-photon counting module with avalanche photodiode for fluorescence detection";

        port fluorescenceIn : FluorescenceInput;
        port signalOut : RawSignalOutput;
        port powerIn : ElectricalPowerInput;

        attribute sensitivity : Real = 0.9;
        attribute darkCountRate : Real = 50.0;
        attribute quantumEfficiency : Real = 0.85;
        attribute integrationTime : TimeDuration = 1.0e-3;
        attribute gain : Real = 1.0e6;
        attribute bandwidth : MicrowaveFrequency = 10.0e6;
        attribute deadTime : TimeDuration = 1.0e-8;

        state machine detectorController {
            initial detectorOff;
            state idle;
            state integrating;
            state converting;
            state transmitting;

            transition detectorOff to idle when powerApplied;
            transition idle to integrating when fluorescenceReceived;
            transition integrating to converting when integrationComplete;
            transition converting to transmitting when conversionComplete;
            transition transmitting to idle when signalTransmitted;
        }

        action detectFluorescence {
            doc "Integrate fluorescence photons over integration window and produce analog voltage";
            in item emission : FluorescenceEmission;
            out item signal : RawElectronicSignal;
        }

        action applyDarkCountCorrection {
            doc "Subtract dark count baseline from measured photon signal";
            in attribute rawCount : Integer;
            out attribute correctedCount : Integer;
        }
    }

    part def SignalProcessor {
        doc "Digital signal processor for calibration, field computation, and confidence estimation";

        port signalIn : RawSignalInput;
        port resultOut : ResultOutput;
        port powerIn : ElectricalPowerInput;

        attribute calibrationCoefficients : Real[0..*];
        attribute noiseFloor : MagneticFluxDensity = 1.0e-15;
        attribute samplingRate : Real = 1000.0;
        attribute baselineReference : ElectricPotential;
        attribute linearCalibrationSlope : Real;
        attribute linearCalibrationOffset : MagneticFluxDensity;
        attribute averagingWindow : Integer = 100;

        state machine processorController {
            initial procOff;
            state idle;
            state receiving;
            state computing;
            state validating;
            state transmitting;

            transition procOff to idle when powerApplied;
            transition idle to receiving when rawSignalReceived;
            transition receiving to computing when signalAcquired;
            transition computing to validating when fieldComputed;
            transition validating to transmitting when confidenceVerified;
            transition transmitting to idle when resultSent;
        }

        action processRawSignal {
            doc "Calibrate raw signal and compute magnetic flux density from NV center fluorescence contrast";
            in item raw : RawElectronicSignal;
            out item result : MeasurementResult;
        }

        action applyCalibration {
            doc "Apply linear calibration model to convert detector voltage to magnetic field";
            in attribute voltage : ElectricPotential;
            out attribute field : MagneticFluxDensity;
        }

        action computeConfidence {
            doc "Compute statistical confidence from signal-to-noise ratio and averaging count";
            in attribute signalAmplitude : ElectricPotential;
            in attribute noiseAmplitude : ElectricPotential;
            in attribute averagingCycles : Integer;
            out attribute confidence : ConfidenceScore;
        }

        action generateTimestamp {
            doc "Generate precise timestamp for measurement result";
            out attribute timestamp : TimeDuration;
        }
    }

    part def TemperatureStabilizer {
        doc "Thermoelectric temperature controller maintaining diamond at constant operating temperature";

        port tempPort : TemperatureSignal;
        port powerIn : ElectricalPowerInput;

        attribute setpoint : Temperature = 293.15;
        attribute actual : Temperature = 293.15;
        attribute tolerance : Temperature = 0.01;
        attribute maxHeatingPower : ElectricPower = 5.0;
        attribute maxCoolingPower : ElectricPower = 5.0;
        attribute proportionalGain : Real = 2.0;
        attribute integralGain : Real = 0.1;
        attribute derivativeGain : Real = 0.05;
        attribute currentError : Real;
        attribute integralTerm : Real;
        attribute derivativeTerm : Real;
        attribute heaterOutput : ElectricPower;
        attribute coolerOutput : ElectricPower;

        state machine thermalControl {
            initial thermalOff;
            state idle;
            state heating;
            state cooling;
            state monitoring;

            transition thermalOff to idle when powerApplied;
            transition idle to heating when actual < (setpoint - tolerance);
            transition idle to cooling when actual > (setpoint + tolerance);
            transition idle to monitoring when (actual >= (setpoint - tolerance)) and (actual <= (setpoint + tolerance));
            transition heating to monitoring when actual >= (setpoint - tolerance);
            transition cooling to monitoring when actual <= (setpoint + tolerance);
            transition monitoring to heating when actual < (setpoint - tolerance);
            transition monitoring to cooling when actual > (setpoint + tolerance);
        }

        action regulateTemperature {
            doc "PID control loop to maintain diamond crystal at precise setpoint temperature";
            in attribute setpointTemp : Temperature;
            in attribute measuredTemp : Temperature;
            out attribute heaterPower : ElectricPower;
            out attribute coolerPower : ElectricPower;
            out attribute actualTemp : Temperature;
        }

        action computePID {
            doc "Compute proportional, integral, and derivative terms of thermal control loop";
            in attribute error : Real;
            out attribute pTerm : Real;
            out attribute iTerm : Real;
            out attribute dTerm : Real;
        }

        action reportThermalStatus {
            doc "Report current thermal status including temperature and actuator states";
            out item status : ThermalStatus;
        }
    }

    // ================================================================
    // Main System Definition
    // ================================================================

    part def NVCenterMagnetometer {
        doc "Quantum NV-center diamond magnetometer system for high-precision weak magnetic field measurement";

        port commandIn : CommandInput;
        port resultOut : ResultOutput;
        port powerIn : ElectricalPowerInput;

        part laser : LaserSystem;
        part microwave : MicrowaveGenerator;
        part diamond : DiamondSensor;
        part detector : PhotonDetector;
        part processor : SignalProcessor;
        part thermalStabilizer : TemperatureStabilizer;

        attribute systemId : String = "NVMAG-001";
        attribute lastMeasurementTime : TimeDuration;
        attribute totalMeasurements : Integer = 0;
        attribute supplyVoltage : ElectricPotential = 24.0;
        attribute cycleDuration : TimeDuration;
        attribute currentMode : SystemMode = standby;
        attribute currentParameters : OperationalParameters;
        attribute firmwareVersion : String = "2.1.0";

        // ---- Internal connections ----

        connect laser.opticalOut to diamond.opticalIn;
        connect microwave.mwOut to diamond.mwIn;
        connect diamond.fluorescenceOut to detector.fluorescenceIn;
        connect detector.signalOut to processor.signalIn;
        connect thermalStabilizer.tempPort to diamond.tempControl;

        connect powerIn to laser.powerIn;
        connect powerIn to microwave.powerIn;
        connect powerIn to detector.powerIn;
        connect powerIn to processor.powerIn;
        connect powerIn to thermalStabilizer.powerIn;

        connect processor.resultOut to resultOut;

        // ---- System lifecycle state machine ----

        state machine lifecycle {
            initial startState;
            state poweredOff {
                doc "System is unpowered and non-operational";
            }
            state initializing {
                doc "Power-up sequence: calibrate laser, tune microwave, stabilize temperature";
            }
            state ready {
                doc "System is idle and awaiting measurement commands";
            }
            state preparing {
                doc "Laser pulse initializing NV centers to ms=0 state";
            }
            state interrogating {
                doc "Microwave pulse applied, NV centers evolving under external field";
            }
            state reading {
                doc "Readout laser pulse applied, fluorescence being detected";
            }
            state processing {
                doc "Signal processor computing magnetic field from detector output";
            }
            state fault {
                doc "Fault condition detected, system requires reset";
            }

            transition startState to poweredOff;
            transition poweredOff to initializing when powerApplied;
            transition initializing to ready when initComplete;
            transition ready to preparing when commandReceived;
            transition preparing to interrogating when laserPulseComplete;
            transition interrogating to reading when evolutionComplete;
            transition reading to processing when fluorescenceDetected;
            transition processing to ready when resultTransmitted;
            transition ready to fault when faultDetected;
            transition preparing to fault when faultDetected;
            transition interrogating to fault when faultDetected;
            transition reading to fault when faultDetected;
            transition processing to fault when faultDetected;
            transition fault to poweredOff when resetCommand;
        }

        // ---- Orchestrated measurement action ----

        action executeMeasurement {
            doc "Full single-shot measurement cycle: prepare, interrogate, evolve, readout, process";
            in item command : CommandMessage;
            out item result : MeasurementResult;

            perform thermalStabilizer.regulateTemperature;
            perform laser.emitPreparePulse;
            perform diamond.absorbLaserPulse;
            perform microwave.emitMicrowavePulse;
            perform diamond.absorbMicrowavePulse;
            perform diamond.evolveUnderField;
            perform laser.emitReadoutPulse;
            perform diamond.emitFluorescence;
            perform detector.detectFluorescence;
            perform detector.applyDarkCountCorrection;
            perform processor.applyCalibration;
            perform processor.computeConfidence;
            perform processor.generateTimestamp;
            perform processor.processRawSignal;
        }

        action initialize {
            doc "Power-up initialization: calibrate subsystems, set defaults, enter ready state";
        }

        action diagnoseFault {
            doc "Run diagnostic checks on all subsystems to identify fault source";
        }

        action configureParameters {
            doc "Apply operational parameters from command to all subsystems";
            in item parameters : OperationalParameters;
        }

        action logResult {
            doc "Log measurement result with metadata for quality tracking";
            in item result : MeasurementResult;
        }
    }

    // ================================================================
    // Requirements
    // ================================================================

    requirement def MagneticFieldSensitivity {
        doc "The system shall measure magnetic fields with sensitivity better than 10 nT per sqrt(Hz) at 1 Hz";
        subject magnetometer : NVCenterMagnetometer;
        constraint {
            magnetometer.processor.noiseFloor <= 10.0e-9
        }
    }

    requirement def TemperatureStability {
        doc "The temperature stabilizer shall maintain the diamond crystal within 0.01 K of the configured setpoint at all times during operation";
        subject stabilizer : TemperatureStabilizer;
        constraint {
            (stabilizer.actual <= stabilizer.setpoint + 0.01) and
            (stabilizer.actual >= stabilizer.setpoint - 0.01)
        }
    }

    requirement def MeasurementCycleTime {
        doc "Each complete measurement cycle shall execute within 10 milliseconds from command to result output";
        subject magnetometer : NVCenterMagnetometer;
        constraint {
            magnetometer.cycleDuration <= 0.010
        }
    }

    requirement def PowerSupplySpec {
        doc "The system shall operate from a nominal 24V DC external power supply with maximum power draw of 50 W";
        subject magnetometer : NVCenterMagnetometer;
        constraint {
            magnetometer.supplyVoltage == 24.0
        }
    }

    requirement def MeasurementOutputFormat {
        doc "Each measurement result shall include a magnetic field value, a timestamp, and a confidence score above 0.5 for valid measurements";
        subject result : MeasurementResult;
        constraint {
            result.confidence >= 0.5
        }
    }

    requirement def NVCoherenceRequirement {
        doc "The diamond sensor shall maintain a T2 coherence time of at least 1 ms at the operating temperature to enable high-precision measurements";
        subject diamond : DiamondSensor;
        constraint {
            diamond.coherenceTimeT2 >= 1.0e-3
        }
    }

    requirement def LaserWavelengthSpec {
        doc "The laser system shall emit at 532 nm wavelength with tolerance of 0.1 nm for NV center optical pumping";
        subject laser : LaserSystem;
        constraint {
            (laser.wavelength >= 531.9e-9) and
            (laser.wavelength <= 532.1e-9)
        }
    }

    // ================================================================
    // Satisfaction Relationships
    // ================================================================

    part nvMagnetometer : NVCenterMagnetometer;

    satisfy MagneticFieldSensitivity by nvMagnetometer;
    satisfy TemperatureStability by nvMagnetometer.thermalStabilizer;
    satisfy MeasurementCycleTime by nvMagnetometer;
    satisfy PowerSupplySpec by nvMagnetometer;
    satisfy MeasurementOutputFormat by nvMagnetometer;
    satisfy NVCoherenceRequirement by nvMagnetometer.diamond;
    satisfy LaserWavelengthSpec by nvMagnetometer.laser;
}
