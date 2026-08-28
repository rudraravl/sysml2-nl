package TEOM_System {
    import SI::*;
    import ScalarValues::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    package MeasurementTypes {
        value type FrequencyValue :> Real { unit "Hz"; }
        value type MassValue :> Real { unit "ug"; }
        value type ConcentrationValue :> Real { unit "ug/m3"; }
        value type TemperatureValue :> Real { unit "degC"; }
        value type FlowRateValue :> Real { unit "L/min"; }
        value type DurationValue :> Real { unit "s"; }
        value type VoltageValue :> Real { unit "V"; }
        value type MassSensitivityValue :> Real { unit "ug/Hz"; }
    }

    // ============================================================
    // Items
    // ============================================================
    package AirItems {
        item Air;
        item ParticulateMatter;
        item Moisture;

        item def AirSample {
            attribute temperature: MeasurementTypes::TemperatureValue;
            attribute volume: MeasurementTypes::MassValue;  // placeholder—should be volume
            ref item particles: ParticulateMatter[0..*];
            ref item moisture: Moisture[0..*];
        }

        item def FilteredAir {
            attribute particleLoading: MeasurementTypes::MassValue;
            ref item remaining: Air;
        }
    }

    // ============================================================
    // Signals
    // ============================================================
    package InstrumentSignals {
        signal DriveSignal {
            attribute amplitude: MeasurementTypes::VoltageValue;
            attribute frequency: MeasurementTypes::FrequencyValue;
        }
        signal FrequencyReading {
            attribute frequency: MeasurementTypes::FrequencyValue;
            attribute timestamp: MeasurementTypes::DurationValue;
        }
        signal TemperatureReading {
            attribute temperature: MeasurementTypes::TemperatureValue;
            attribute timestamp: MeasurementTypes::DurationValue;
        }
        signal HeaterCommand {
            attribute powerLevel: Real;  // fraction 0..1
        }
        signal ConcentrationReport {
            attribute concentration: MeasurementTypes::ConcentrationValue;
            attribute timestamp: MeasurementTypes::DurationValue;
            attribute status: String;
        }
        signal StartCommand;
        signal StopCommand;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    package PortDefinitions {
        port def AirInlet {
            in item air: AirItems::Air;
        }
        port def AirOutlet {
            out item air: AirItems::Air;
        }
        port def DriveOutPort {
            out signal drive: InstrumentSignals::DriveSignal;
        }
        port def DriveInPort {
            in signal drive: InstrumentSignals::DriveSignal;
        }
        port def FrequencyOutPort {
            out signal reading: InstrumentSignals::FrequencyReading;
        }
        port def FrequencyInPort {
            in signal reading: InstrumentSignals::FrequencyReading;
        }
        port def TemperatureOutPort {
            out signal reading: InstrumentSignals::TemperatureReading;
        }
        port def TemperatureInPort {
            in signal reading: InstrumentSignals::TemperatureReading;
        }
        port def HeaterCommandOutPort {
            out signal command: InstrumentSignals::HeaterCommand;
        }
        port def HeaterCommandInPort {
            in signal command: InstrumentSignals::HeaterCommand;
        }
        port def DataOutPort {
            out signal report: InstrumentSignals::ConcentrationReport;
        }
        port def ControlInPort {
            in signal start: InstrumentSignals::StartCommand;
            in signal stop: InstrumentSignals::StopCommand;
        }
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================
    package Components {

        // ---- Tapered Element ----
        part def TaperedElement {
            attribute material: String = "hollow glass";
            attribute length_mm: Real = 150.0;
            attribute baseFrequency: MeasurementTypes::FrequencyValue = 500.0;
            attribute currentFrequency: MeasurementTypes::FrequencyValue = 500.0;
            attribute currentMass: MeasurementTypes::MassValue = 0.0;
            attribute massSensitivity: MeasurementTypes::MassSensitivityValue = 2.0;
            attribute operatingTemperature: MeasurementTypes::TemperatureValue = 50.0;

            port airIn: PortDefinitions::AirInlet;
            port airOut: PortDefinitions::AirOutlet;
            port driveIn: PortDefinitions::DriveInPort;
            port freqOut: PortDefinitions::FrequencyOutPort;

            action def Vibrate {
                in signal drive: InstrumentSignals::DriveSignal;
                out signal reading: InstrumentSignals::FrequencyReading;
            }

            action def UpdateResonance {
                in attribute addedMass: MeasurementTypes::MassValue;
                out attribute newFrequency: MeasurementTypes::FrequencyValue;
            }

            action vibrateAction : Vibrate {
                in signal drive = driveIn.drive;
                out signal reading = freqOut.reading;
            }
        }

        // ---- Piezoelectric Driver ----
        part def PiezoelectricDriver {
            attribute driveAmplitude: MeasurementTypes::VoltageValue = 5.0;
            attribute nominalDriveFrequency: MeasurementTypes::FrequencyValue = 500.0;

            port driveOut: PortDefinitions::DriveOutPort;

            action def GenerateDrive {
                out signal drive: InstrumentSignals::DriveSignal;
            }

            action generateDriveAction : GenerateDrive {
                out signal drive = driveOut.drive;
            }
        }

        // ---- Filter ----
        part def Filter {
            attribute filterType: String = "PTFE membrane";
            attribute poreSize_um: Real = 2.0;
            attribute collectedMass: MeasurementTypes::MassValue = 0.0;
            attribute maxLoadingMass: MeasurementTypes::MassValue = 2000.0;

            port airIn: PortDefinitions::AirInlet;
            port airOut: PortDefinitions::AirOutlet;

            action def CollectParticles {
                in item incomingAir: AirItems::Air;
                out item outgoingAir: AirItems::Air;
                out attribute addedMass: MeasurementTypes::MassValue;
            }

            action collectAction : CollectParticles {
                in item incomingAir = airIn.air;
                out item outgoingAir = airOut.air;
            }
        }

        // ---- Vacuum Pump ----
        part def VacuumPump {
            attribute nominalFlowRate: MeasurementTypes::FlowRateValue = 16.7;
            attribute actualFlowRate: MeasurementTypes::FlowRateValue = 16.7;
            attribute flowTolerance: MeasurementTypes::FlowRateValue = 0.5;
            attribute isRunning: Boolean = false;

            port airIn: PortDefinitions::AirInlet;
            port airOut: PortDefinitions::AirOutlet;

            action def DrawAir {
                in item inletAir: AirItems::Air;
                out item exhaustAir: AirItems::Air;
                attribute rate: MeasurementTypes::FlowRateValue;
            }

            action drawAirAction : DrawAir {
                in item inletAir = airIn.air;
                out item exhaustAir = airOut.air;
                attribute rate = actualFlowRate;
            }
        }

        // ---- Frequency Detector ----
        part def FrequencyDetector {
            attribute resolution: MeasurementTypes::FrequencyValue = 0.001;
            attribute measurementRange: MeasurementTypes::FrequencyValue = 1000.0;
            attribute lastReading: MeasurementTypes::FrequencyValue = 0.0;

            port senseIn: PortDefinitions::FrequencyInPort;
            port dataOut: PortDefinitions::FrequencyOutPort;

            action def MeasureFrequency {
                in signal input: InstrumentSignals::FrequencyReading;
                out signal output: InstrumentSignals::FrequencyReading;
            }

            action measureAction : MeasureFrequency {
                in signal input = senseIn.reading;
                out signal output = dataOut.reading;
            }
        }

        // ---- Temperature Controller ----
        part def TemperatureController {
            attribute setpoint: MeasurementTypes::TemperatureValue = 50.0;
            attribute tolerance: MeasurementTypes::TemperatureValue = 0.5;
            attribute currentTemperature: MeasurementTypes::TemperatureValue = 25.0;
            attribute heaterPower: Real = 0.0;
            attribute isStable: Boolean = false;

            port tempIn: PortDefinitions::TemperatureInPort;
            port heaterOut: PortDefinitions::HeaterCommandOutPort;

            action def RegulateTemperature {
                in signal reading: InstrumentSignals::TemperatureReading;
                out signal command: InstrumentSignals::HeaterCommand;
            }

            action regulateAction : RegulateTemperature {
                in signal reading = tempIn.reading;
                out signal command = heaterOut.command;
            }
        }

        // ---- Temperature Sensor ----
        part def TemperatureSensor {
            attribute accuracy: MeasurementTypes::TemperatureValue = 0.1;
            port tempOut: PortDefinitions::TemperatureOutPort;

            action def SenseTemperature {
                out signal reading: InstrumentSignals::TemperatureReading;
            }

            action senseAction : SenseTemperature {
                out signal reading = tempOut.reading;
            }
        }

        // ---- Heater ----
        part def Heater {
            attribute maxPower_W: Real = 10.0;
            attribute currentPower: Real = 0.0;
            port commandIn: PortDefinitions::HeaterCommandInPort;

            action def ApplyHeat {
                in signal command: InstrumentSignals::HeaterCommand;
            }

            action applyHeatAction : ApplyHeat {
                in signal command = commandIn.command;
            }
        }

        // ---- Data Processor ----
        part def DataProcessor {
            attribute baselineFrequency: MeasurementTypes::FrequencyValue = 0.0;
            attribute currentFrequency: MeasurementTypes::FrequencyValue = 0.0;
            attribute currentConcentration: MeasurementTypes::ConcentrationValue = 0.0;
            attribute flowRate: MeasurementTypes::FlowRateValue = 16.7;
            attribute massSensitivity: MeasurementTypes::MassSensitivityValue = 2.0;
            attribute sampleInterval: MeasurementTypes::DurationValue = 10.0;
            attribute elapsedTime: MeasurementTypes::DurationValue = 0.0;
            attribute isInitialized: Boolean = false;

            port freqIn: PortDefinitions::FrequencyInPort;
            port dataOut: PortDefinitions::DataOutPort;
            port controlIn: PortDefinitions::ControlInPort;

            action def EstablishBaseline {
                in signal reading: InstrumentSignals::FrequencyReading;
                out attribute baseline: MeasurementTypes::FrequencyValue;
            }

            action def ComputeConcentration {
                in signal reading: InstrumentSignals::FrequencyReading;
                in attribute baseline: MeasurementTypes::FrequencyValue;
                in attribute flow: MeasurementTypes::FlowRateValue;
                in attribute sensitivity: MeasurementTypes::MassSensitivityValue;
                out signal report: InstrumentSignals::ConcentrationReport;
            }

            action establishBaselineAction : EstablishBaseline {
                in signal reading = freqIn.reading;
                out attribute baseline = baselineFrequency;
            }

            action computeConcentrationAction : ComputeConcentration {
                in signal reading = freqIn.reading;
                in attribute baseline = baselineFrequency;
                in attribute flow = flowRate;
                in attribute sensitivity = massSensitivity;
                out signal report = dataOut.report;
            }

            state machine OperatingCycle {
                entry { send InstrumentSignals::StartCommand(); }

                state initializing {
                    entry { attribute isInitialized = false; }
                    do { perform initialize; }
                    exit { attribute isInitialized = true; }
                }

                state baselineMeasuring {
                    entry { perform establishBaselineAction; }
                    do { wait for baselineFrequency > 0.0; }
                }

                state sampling {
                    do { send InstrumentSignals::StartCommand(); }
                    entry { attribute elapsedTime = 0.0; }
                }

                state computing {
                    entry { perform computeConcentrationAction; }
                }

                state reporting {
                    entry { send InstrumentSignals::ConcentrationReport(); }
                }

                state shutdown {
                    entry { send InstrumentSignals::StopCommand(); }
                }

                transition t_init_to_baseline
                    from initializing to baselineMeasuring
                    when { isInitialized == true };

                transition t_baseline_to_sampling
                    from baselineMeasuring to sampling
                    when { baselineFrequency > 0.0 };

                transition t_sampling_to_computing
                    from sampling to computing
                    when { elapsedTime >= sampleInterval };

                transition t_computing_to_reporting
                    from computing to reporting
                    when { currentConcentration >= 0.0 };

                transition t_reporting_to_sampling
                    from reporting to sampling
                    when { true };

                transition t_any_to_shutdown
                    from sampling to shutdown
                    when { false }  // triggered by stop command;
            }
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    package InstrumentRequirements {

        requirement def MeasurementRangeRequirement {
            attribute maxConcentration: MeasurementTypes::ConcentrationValue = 1000.0;
            attribute minConcentration: MeasurementTypes::ConcentrationValue = 0.0;
            attribute resolution: MeasurementTypes::ConcentrationValue = 0.1;
            doc /* The TEOM shall measure particulate matter concentration
                  from 0 to 1000 ug/m3 with a resolution of 0.1 ug/m3. */
        }

        requirement def TemperatureStabilityRequirement {
            attribute setpoint: MeasurementTypes::TemperatureValue = 50.0;
            attribute tolerance: MeasurementTypes::TemperatureValue = 0.5;
            doc /* The temperature controller shall maintain the tapered element
                  at 50 +/- 0.5 degC to prevent moisture condensation. */
        }

        requirement def FlowRateRequirement {
            attribute nominalFlow: MeasurementTypes::FlowRateValue = 16.7;
            attribute tolerance: MeasurementTypes::FlowRateValue = 0.5;
            doc /* The vacuum pump shall maintain a volumetric flow rate
                  of 16.7 +/- 0.5 L/min through the filter. */
        }

        requirement def FrequencyResolutionRequirement {
            attribute minDetectableShift: MeasurementTypes::FrequencyValue = 0.001;
            doc /* The frequency detector shall resolve frequency changes
                  as small as 0.001 Hz. */
        }

        requirement def RealTimeReportingRequirement {
            attribute maxLatency: MeasurementTypes::DurationValue = 60.0;
            doc /* The data processor shall output a concentration report
                  at least every 60 seconds during continuous operation. */
        }

        requirement def BaselineEstablishmentRequirement {
            doc /* The data processor shall establish a baseline frequency
                  with a clean filter before beginning particulate sampling. */
        }

        requirement def MoisturePreventionRequirement {
            attribute operatingTemp: MeasurementTypes::TemperatureValue = 50.0;
            doc /* The system shall maintain the filter and tapered element
                  above ambient dew point to prevent moisture condensation
                  from affecting mass measurements. */
        }
    }

    // ============================================================
    // Top-Level Instrument Assembly
    // ============================================================
    part def TEOMInstrument {
        part taperedElement : Components::TaperedElement;
        part driver : Components::PiezoelectricDriver;
        part filter : Components::Filter;
        part pump : Components::VacuumPump;
        part detector : Components::FrequencyDetector;
        part tempController : Components::TemperatureController;
        part tempSensor : Components::TemperatureSensor;
        part heater : Components::Heater;
        part processor : Components::DataProcessor;

        port ambientAirIn : PortDefinitions::AirInlet;
        port exhaustAirOut : PortDefinitions::AirOutlet;
        port dataOutput : PortDefinitions::DataOutPort;
        port controlInput : PortDefinitions::ControlInPort;

        // Requirement satisfaction
        satisfy InstrumentRequirements::MeasurementRangeRequirement {
            subject processor;
        }
        satisfy InstrumentRequirements::TemperatureStabilityRequirement {
            subject tempController;
        }
        satisfy InstrumentRequirements::FlowRateRequirement {
            subject pump;
        }
        satisfy InstrumentRequirements::FrequencyResolutionRequirement {
            subject detector;
        }
        satisfy InstrumentRequirements::RealTimeReportingRequirement {
            subject processor;
        }
        satisfy InstrumentRequirements::BaselineEstablishmentRequirement {
            subject processor;
        }
        satisfy InstrumentRequirements::MoisturePreventionRequirement {
            subject tempController;
        }

        // Air flow path: ambient -> filter -> tapered element (hollow) -> pump -> exhaust
        connection ambientToFilter connect ambientAirIn to filter.airIn;
        connection filterToElement connect filter.airOut to taperedElement.airIn;
        connection elementToPump connect taperedElement.airOut to pump.airIn;
        connection pumpToExhaust connect pump.airOut to exhaustAirOut;

        // Drive signal: driver -> tapered element
        connection driverToElement connect driver.driveOut to taperedElement.driveIn;

        // Frequency signal: tapered element -> detector -> processor
        connection elementToDetector connect taperedElement.freqOut to detector.senseIn;
        connection detectorToProcessor connect detector.dataOut to processor.freqIn;

        // Temperature control loop: sensor -> controller -> heater
        connection sensorToController connect tempSensor.tempOut to tempController.tempIn;
        connection controllerToHeater connect tempController.heaterOut to heater.commandIn;

        // Data output: processor -> external
        connection processorToOutput connect processor.dataOut to dataOutput;

        // Control input: external -> processor
        connection controlToProcessor connect controlInput to processor.controlIn;

        // Item flows on air connections
        flow ambientToFilter of AirItems::Air;
        flow filterToElement of AirItems::Air;
        flow elementToPump of AirItems::Air;
        flow pumpToExhaust of AirItems::Air;

        // Item flow of particulate matter captured on filter
        flow filterToElement of AirItems::ParticulateMatter {
            attribute capturedMass: MeasurementTypes::MassValue;
        }
    }

    // ============================================================
    // Operational Context
    // ============================================================
    part def MonitoringStation {
        attribute stationId: String;
        attribute location: String;
        attribute deploymentDate: String;

        part instrument : TEOMInstrument;

        port ambientAirIntake : PortDefinitions::AirInlet;
        port dataBroadcast : PortDefinitions::DataOutPort;

        connection ambientToInstrument connect ambientAirIntake to instrument.ambientAirIn;
        connection instrumentDataOut connect instrument.dataOutput to dataBroadcast;
    }

    // ============================================================
    // Verification Actions
    // ============================================================
    package Verification {
        action def VerifyMeasurementRange {
            in instrument: TEOMInstrument;
            attribute testConcentration: MeasurementTypes::ConcentrationValue;
            attribute pass: Boolean;
        }

        action def VerifyTemperatureStability {
            in controller: Components::TemperatureController;
            attribute measuredTemp: MeasurementTypes::TemperatureValue;
            attribute pass: Boolean;
        }

        action def VerifyFlowRate {
            in pump: Components::VacuumPump;
            attribute measuredFlow: MeasurementTypes::FlowRateValue;
            attribute pass: Boolean;
        }

        action def VerifyFrequencyResolution {
            in detector: Components::FrequencyDetector;
            attribute appliedShift: MeasurementTypes::FrequencyValue;
            attribute detectedShift: MeasurementTypes::FrequencyValue;
            attribute pass: Boolean;
        }
    }
}
