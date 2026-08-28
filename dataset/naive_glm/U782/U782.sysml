package OpticalNanosensorSystem {
    import ISQ::*;
    import ScalarValues::*;

    value type Concentration :> Real {
        unit mol_per_L;
    }

    value type Wavelength :> Real {
        unit nm;
    }

    value type LightIntensity :> Real {
        unit W_per_m2;
    }

    value type SignalVoltage :> Real {
        unit mV;
    }

    value type AmplifiedVoltage :> Real {
        unit V;
    }

    value type ResponseTime :> Real {
        unit s;
    }

    value type OperatingTemperature :> Real {
        unit K;
    }

    value type PowerConsumption :> Real {
        unit mW;
    }

    value type SampleVolume :> Real {
        unit uL;
    }

    value type ConfidenceLevel :> Real;

    value type BindingAffinity :> Real {
        unit nM;
    }

    value type MolecularWeight :> Real {
        unit g_per_mol;
    }

    value type GainFactor :> Real;

    value type OperationalDuration :> Real {
        unit s;
    }

    value type SurfaceArea :> Real {
        unit m2;
    }

    value type Frequency :> Real {
        unit Hz;
    }

    item def TargetMolecule {
        attribute identifier : String;
        attribute molecularWeight : MolecularWeight;
        attribute bindingAffinity : BindingAffinity;
        attribute isCaptured : Boolean = false;
    }

    item def BiologicalSample {
        attribute sampleId : String;
        attribute volume : SampleVolume;
        attribute temperature : OperatingTemperature;
        attribute timestamp : DateTime;
        item targetMolecules : TargetMolecule[0..*];
    }

    item def CalibrationStandard {
        attribute standardId : String;
        attribute knownConcentration : Concentration;
        attribute batchNumber : String;
        attribute expirationDate : Date;
    }

    item def CalibrationData {
        attribute slope : Real;
        attribute offset : Real;
        attribute correlationCoefficient : Real;
        attribute calibrationTime : DateTime;
        attribute validDuration : OperationalDuration;
    }

    item def MeasurementResult {
        attribute measurementId : Integer;
        attribute targetIdentifier : String;
        attribute measuredConcentration : Concentration;
        attribute timestamp : DateTime;
        attribute confidence : ConfidenceLevel;
        attribute signalStrength : AmplifiedVoltage;
    }

    enum CommandType {
        start;
        stop;
        calibrate;
        reset;
        query;
        setThreshold;
    }

    enum PowerState {
        on;
        low;
        off;
    }

    item def ControlCommand {
        attribute commandType : CommandType;
        attribute parameters : String;
        attribute source : String;
        attribute timestamp : DateTime;
    }

    item def SystemStatus {
        attribute systemState : String;
        attribute powerLevel : PowerConsumption;
        attribute temperature : OperatingTemperature;
        attribute uptime : OperationalDuration;
        attribute lastMaintenance : DateTime;
    }

    port def SamplePort {
        in sample : BiologicalSample;
    }

    port def OpticalExcitationPort {
        attribute excitationWavelength : Wavelength;
        out excitationLight : LightIntensity;
    }

    port def OpticalEmissionPort {
        attribute emissionWavelength : Wavelength;
        in emissionLight : LightIntensity;
    }

    port def ElectricalSignalPort {
        out signal : SignalVoltage;
    }

    port def AmplifiedSignalPort {
        out amplifiedSignal : AmplifiedVoltage;
    }

    port def DigitalDataPort {
        out data : MeasurementResult;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : SystemStatus;
    }

    port def CalibrationPort {
        in standard : CalibrationStandard;
        out calibrationData : CalibrationData;
    }

    port def ReportingPort {
        out measurement : MeasurementResult;
    }

    part def FunctionalCoating {
        attribute coatingType : String;
        attribute activeBindingSites : Integer;
        attribute bindingEfficiency : Real;
        attribute surfaceCharge : Real;
        attribute crossReactivity : Real;

        action bindMolecules {
            in targetMolecules : TargetMolecule[0..*];
            in sample : BiologicalSample;
            out capturedMolecules : TargetMolecule[0..*];
            out remainingSites : Integer;
        }
    }

    part def NanoparticleSurface {
        attribute material : String;
        attribute diameter : Wavelength;
        attribute surfaceAreaVal : SurfaceArea;
        attribute totalBindingSites : Integer;
        attribute occupiedSites : Integer = 0;

        part coating : FunctionalCoating;

        port sampleInput : SamplePort;

        action captureMolecules {
            in sample : BiologicalSample;
            in availableSites : Integer;
            out capturedMolecules : TargetMolecule[0..*];
            out remainingSites : Integer;
        }
    }

    part def ExcitationSource {
        attribute lightSourceType : String;
        attribute excitationWavelength : Wavelength;
        attribute outputPower : LightIntensity;
        attribute stability : Real;

        port excitationOutput : OpticalExcitationPort;

        action emitExcitationLight {
            in power : LightIntensity;
            out emittedLight : LightIntensity;
        }
    }

    part def EmissionDetector {
        attribute detectorType : String;
        attribute emissionWavelength : Wavelength;
        attribute detectionRange : Wavelength;
        attribute quantumEfficiency : Real;
        attribute noiseFloor : LightIntensity;

        port emissionInput : OpticalEmissionPort;
        port signalOutput : ElectricalSignalPort;

        action detectEmission {
            in incomingLight : LightIntensity;
            out signal : SignalVoltage;
        }
    }

    part def OpticalTransducer {
        attribute transducerType : String;
        attribute excitationWavelength : Wavelength;
        attribute emissionWavelength : Wavelength;
        attribute quantumYield : Real;

        part excitationSource : ExcitationSource;
        part emissionDetector : EmissionDetector;

        port sampleChamber : SamplePort;
        port excitationOutput : OpticalExcitationPort;
        port emissionInput : OpticalEmissionPort;
        port signalOutput : ElectricalSignalPort;

        action transduceBindingEvent {
            in bindingEvents : Integer;
            out emittedSignal : SignalVoltage;
        }
    }

    part def SignalAmplifier {
        attribute amplificationGain : GainFactor;
        attribute bandwidth : Frequency;
        attribute inputImpedance : Real;
        attribute noiseFigure : Real;
        attribute linearity : Real;

        port signalInput : ElectricalSignalPort;
        port amplifiedOutput : AmplifiedSignalPort;

        action amplifySignal {
            in inputSignal : SignalVoltage;
            out amplifiedSignal : AmplifiedVoltage;
        }
    }

    part def DataProcessor {
        attribute processingSpeed : Frequency;
        attribute memory : Real;
        attribute calibrationData : CalibrationData;
        attribute analysisAlgorithms : String[0..*];
        attribute signalThreshold : AmplifiedVoltage;

        port dataInput : AmplifiedSignalPort;
        port dataOutput : DigitalDataPort;
        port calibrationInput : CalibrationPort;

        action applyCalibration {
            in rawSignal : AmplifiedVoltage;
            in calibration : CalibrationData;
            out concentration : Concentration;
        }

        action analyzeSignal {
            in signal : AmplifiedVoltage;
            in calibration : CalibrationData;
            out result : MeasurementResult;
        }

        action updateCalibrationData {
            in newCalibration : CalibrationData;
            out updatedCalibration : CalibrationData;
        }
    }

    part def ControlInterface {
        attribute interfaceType : String;
        attribute supportedCommands : CommandType[0..*];

        port controlInput : ControlPort;
        port statusOutput : ControlPort;

        action processCommand {
            in command : ControlCommand;
            out action : CommandType;
        }

        action getStatus {
            out status : SystemStatus;
        }
    }

    part def PowerManager {
        attribute powerMode : PowerState;
        attribute powerCapacity : PowerConsumption;
        attribute currentDraw : PowerConsumption;
        attribute standbyTimer : OperationalDuration;

        action setPowerMode {
            in mode : PowerState;
            out appliedMode : PowerState;
        }

        action enterLowPower {
            in duration : OperationalDuration;
        }
    }

    part def ReportingModule {
        attribute reportingInterval : OperationalDuration;
        attribute reportingFormat : String;

        port reportingOutput : ReportingPort;

        action generateReport {
            in measurements : MeasurementResult[0..*];
            out report : MeasurementResult;
        }
    }

    state def SensorState {
        state idle {
            entry {
                // Set power manager to normal operating mode
            }
            do {
                // Monitor for incoming commands and sample presence
            }
        }

        state calibration {
            entry {
                // Initialize calibration procedure
            }
            do {
                // Run calibration cycle with known standards
            }
            exit {
                // Store calibration data in data processor
            }
        }

        state active {
            state sensing {
                entry {
                    // Begin sample introduction and capture
                }
                do {
                    // Capture target molecules on nanoparticle surface
                }
            }

            state analyzing {
                do {
                    // Process amplified signal and apply calibration
                }
            }

            state reporting {
                do {
                    // Output measurement result to reporting port
                }
            }

            transition sensing_to_analyzing {
                from sensing;
                to analyzing;
                when signalReceived;
            }

            transition analyzing_to_reporting {
                from analyzing;
                to reporting;
                when analysisComplete;
            }

            transition reporting_to_sensing {
                from reporting;
                to sensing;
                when continuousMode;
            }
        }

        state standby {
            entry {
                // Enter low-power mode
            }
            do {
                // Maintain minimal monitoring for wake-up trigger
            }
        }

        transition init {
            to idle;
        }

        transition idle_to_calibration {
            from idle;
            to calibration;
            when calibrateCommandReceived;
        }

        transition idle_to_active {
            from idle;
            to active.sensing;
            when startCommandReceived;
        }

        transition idle_to_standby {
            from idle;
            to standby;
            when inactivityTimeout;
        }

        transition calibration_to_idle {
            from calibration;
            to idle;
            when calibrationComplete;
        }

        transition active_to_idle {
            from active;
            to idle;
            when stopCommandReceived;
        }

        transition standby_to_idle {
            from standby;
            to idle;
            when wakeupCommandReceived;
        }
    }

    part def OpticalNanosensorSystem {
        attribute systemId : String;
        attribute manufacturer : String;
        attribute serialNumber : String;
        attribute firmwareVersion : String;
        attribute maxSampleVolume : SampleVolume;
        attribute detectionRangeMin : Concentration;
        attribute detectionRangeMax : Concentration;
        attribute operatingTemperatureMin : OperatingTemperature;
        attribute operatingTemperatureMax : OperatingTemperature;
        attribute detectionSensitivity : Concentration;
        attribute responseTime : ResponseTime;
        attribute operationalDuration : OperationalDuration;

        part nanoparticleSurface : NanoparticleSurface;
        part opticalTransducer : OpticalTransducer;
        part signalAmplifier : SignalAmplifier;
        part dataProcessor : DataProcessor;
        part controlInterface : ControlInterface;
        part powerManager : PowerManager;
        part reportingModule : ReportingModule;

        port samplePort : SamplePort;
        port commandPort : ControlPort;
        port calibrationPort : CalibrationPort;
        port reportingPort : ReportingPort;

        connection sampleToSurface connect samplePort to nanoparticleSurface.sampleInput;
        connection sampleToTransducer connect samplePort to opticalTransducer.sampleChamber;
        connection excitationToEmission connect opticalTransducer.excitationOutput to opticalTransducer.emissionInput;
        connection signalToAmplifier connect opticalTransducer.signalOutput to signalAmplifier.signalInput;
        connection amplifierToProcessor connect signalAmplifier.amplifiedOutput to dataProcessor.dataInput;
        connection processorToReporter connect dataProcessor.dataOutput to reportingModule.reportingOutput;
        connection commandToInterface connect commandPort to controlInterface.controlInput;
        connection statusFromInterface connect controlInterface.statusOutput to commandPort;
        connection calibrationToProcessor connect calibrationPort to dataProcessor.calibrationInput;

        state sensorState : SensorState;
    }

    requirement def DetectionSensitivityRequirement {
        doc "The system shall detect target molecule concentrations as low as 1 picomolar.";
        attribute minimumDetection : Concentration = 1e-12 [mol_per_L];
    }

    requirement def ResponseTimeRequirement {
        doc "The system shall report a measurement within 30 seconds of sample introduction.";
        attribute maxResponseTime : ResponseTime = 30 [s];
    }

    requirement def ConcentrationRangeRequirement {
        doc "The system shall measure concentrations from 1 picomolar to 100 micromolar.";
        attribute minRange : Concentration = 1e-12 [mol_per_L];
        attribute maxRange : Concentration = 1e-4 [mol_per_L];
    }

    requirement def SelectivityRequirement {
        doc "The functional coating shall exhibit minimum cross-reactivity (<5 percent) with non-target molecules.";
        attribute maxCrossReactivity : Real = 0.05;
    }

    requirement def ContinuousOperationRequirement {
        doc "The system shall operate continuously for at least 24 hours without intervention.";
        attribute minOperationDuration : OperationalDuration = 86400 [s];
    }

    requirement def StandbyPowerRequirement {
        doc "In standby mode, power consumption shall not exceed 10 milliwatts.";
        attribute maxStandbyPower : PowerConsumption = 10 [mW];
    }

    requirement def CalibrationRequirement {
        doc "The system shall support external calibration with known standards.";
    }

    requirement def ReportingRequirement {
        doc "The system shall report measurements with timestamp, concentration value, and confidence level.";
    }

    requirement def InterfaceRequirement {
        doc "The external interface shall support start, stop, calibrate, and query commands.";
    }

    requirement def OpticalTransductionRequirement {
        doc "The optical transducer shall excite the surface at one wavelength and measure emission at a different wavelength.";
        attribute excitationWavelength : Wavelength;
        attribute emissionWavelength : Wavelength;
    }

    requirement def AmplificationRequirement {
        doc "The signal amplifier shall amplify the faint optical signal to a measurable level with minimal noise.";
        attribute minGain : GainFactor = 100.0;
        attribute maxNoiseFigure : Real = 3.0;
    }

    requirement def StateMachineRequirement {
        doc "The system shall operate through idle, calibration, active sensing/analyzing, and standby states.";
    }

    satisfy DetectionSensitivityRequirement by OpticalNanosensorSystem;
    satisfy ResponseTimeRequirement by OpticalNanosensorSystem;
    satisfy ConcentrationRangeRequirement by OpticalNanosensorSystem;
    satisfy SelectivityRequirement by NanoparticleSurface;
    satisfy ContinuousOperationRequirement by OpticalNanosensorSystem;
    satisfy StandbyPowerRequirement by PowerManager;
    satisfy CalibrationRequirement by DataProcessor;
    satisfy ReportingRequirement by ReportingModule;
    satisfy InterfaceRequirement by ControlInterface;
    satisfy OpticalTransductionRequirement by OpticalTransducer;
    satisfy AmplificationRequirement by SignalAmplifier;
    satisfy StateMachineRequirement by SensorState;
}
