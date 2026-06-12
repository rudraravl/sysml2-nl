package CapacitiveSensingSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Capacitance :> ScalarValues::Real {
        unit = "pF";
    }

    attribute def Voltage :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Current :> ScalarValues::Real {
        unit = "uA";
    }

    attribute def Frequency :> ScalarValues::Real {
        unit = "kHz";
    }

    attribute def TimeDuration :> ScalarValues::Real {
        unit = "ms";
    }

    attribute def Distance :> ScalarValues::Real {
        unit = "mm";
    }

    attribute def Temperature :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def DigitalCount :> ScalarValues::Integer;

    attribute def TouchConfidence :> ScalarValues::Real {
        unit = "%";
    }

    enum def TouchStateKind {
        enum noTouch;
        enum proximity;
        enum contact;
        enum fault;
    }

    enum def ElectrodeHealthKind {
        enum normal;
        enum openCircuit;
        enum shortCircuit;
        enum excessiveNoise;
        enum saturated;
    }

    item def ExcitationWaveform {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute dutyCycle : ScalarValues::Real;
    }

    item def RawCapacitanceSample {
        attribute measuredCapacitance : Capacitance;
        attribute acquisitionTime : TimeDuration;
        attribute rawCount : DigitalCount;
        attribute electrodeId : ScalarValues::String;
    }

    item def FilteredCapacitanceSample {
        attribute baselineCapacitance : Capacitance;
        attribute deltaCapacitance : Capacitance;
        attribute noiseEstimate : Capacitance;
        attribute filteredCount : DigitalCount;
        attribute electrodeId : ScalarValues::String;
    }

    item def TouchDecision {
        attribute state : TouchStateKind;
        attribute confidence : TouchConfidence;
        attribute estimatedDistance : Distance;
        attribute electrodeId : ScalarValues::String;
    }

    item def DiagnosticReport {
        attribute electrodeHealth : ElectrodeHealthKind;
        attribute supplyVoltage : Voltage;
        attribute sensorTemperature : Temperature;
        attribute noiseLevel : Capacitance;
        attribute faultCode : ScalarValues::String;
    }

    port def PowerInputPort {
        in item supplyVoltage : Voltage;
        in item supplyCurrent : Current;
    }

    port def ExcitationPort {
        out item excitation : ExcitationWaveform;
    }

    port def SenseInputPort {
        in item sample : RawCapacitanceSample;
    }

    port def SampleOutputPort {
        out item sample : RawCapacitanceSample;
    }

    port def FilteredSamplePort {
        inout item filteredSample : FilteredCapacitanceSample;
    }

    port def TouchDecisionPort {
        out item decision : TouchDecision;
    }

    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }

    port def HostCommandPort {
        in item enableCommand : ScalarValues::Boolean;
        in item recalibrateCommand : ScalarValues::Boolean;
        in item sensitivitySetting : ScalarValues::Real;
    }

    port def HostStatusPort {
        out item touchDecision : TouchDecision;
        out item diagnosticReport : DiagnosticReport;
    }

    part def CapacitiveElectrode {
        attribute electrodeId : ScalarValues::String;
        attribute nominalCapacitance : Capacitance = 12.0;
        attribute parasiticCapacitance : Capacitance = 4.5;
        attribute activeArea : ScalarValues::Real {
            unit = "mm^2";
        }
        attribute overlayThickness : Distance = 1.2;
        attribute health : ElectrodeHealthKind = ElectrodeHealthKind::normal;

        port excitationIn : ExcitationPort;
        port senseOut : SampleOutputPort;

        action senseCapacitance {
            in item excitation : ExcitationWaveform;
            out item sample : RawCapacitanceSample;

            first start;
            then chargeElectrode;
            then measureChargeTransfer;
            then emitRawSample;
            then done;

            action chargeElectrode {
                in item excitation : ExcitationWaveform;
            }

            action measureChargeTransfer {
                out item sample : RawCapacitanceSample;
            }

            action emitRawSample {
                in item sample : RawCapacitanceSample;
            }
        }
    }

    part def ExcitationDriver {
        attribute excitationAmplitude : Voltage = 3.3;
        attribute excitationFrequency : Frequency = 250.0;
        attribute dutyCycle : ScalarValues::Real = 0.5;
        attribute maxDriveCurrent : Current = 800.0;

        port power : PowerInputPort;
        port excitationOut : ExcitationPort;

        action generateExcitation {
            out item waveform : ExcitationWaveform;

            first start;
            then setAmplitude;
            then setFrequency;
            then driveElectrode;
            then done;
        }
    }

    part def CapacitanceToDigitalConverter {
        attribute resolutionBits : ScalarValues::Integer = 16;
        attribute samplePeriod : TimeDuration = 2.0;
        attribute measurableMinimum : Capacitance = 0.5;
        attribute measurableMaximum : Capacitance = 80.0;
        attribute conversionNoise : Capacitance = 0.03;

        port senseIn : SenseInputPort;
        port rawSampleOut : SampleOutputPort;

        action convertCapacitance {
            in item analogSample : RawCapacitanceSample;
            out item digitalSample : RawCapacitanceSample;

            first start;
            then integrateCharge;
            then quantizeMeasurement;
            then compensateOffset;
            then publishRawCount;
            then done;
        }
    }

    part def DigitalSignalProcessor {
        attribute movingAverageWindow : ScalarValues::Integer = 8;
        attribute baselineAdaptationRate : ScalarValues::Real = 0.002;
        attribute proximityThreshold : Capacitance = 0.18;
        attribute contactThreshold : Capacitance = 0.75;
        attribute releaseThreshold : Capacitance = 0.35;
        attribute maxAllowedNoise : Capacitance = 0.25;

        port rawSampleIn : SenseInputPort;
        port filteredSampleOut : FilteredSamplePort;

        action filterAndTrackBaseline {
            in item rawSample : RawCapacitanceSample;
            out item filteredSample : FilteredCapacitanceSample;

            first start;
            then removeOutliers;
            then applyMovingAverage;
            then updateBaseline;
            then calculateDelta;
            then estimateNoise;
            then done;
        }
    }

    part def TouchClassifier {
        attribute proximityThreshold : Capacitance = 0.18;
        attribute contactThreshold : Capacitance = 0.75;
        attribute faultNoiseThreshold : Capacitance = 0.25;
        attribute minimumConfidence : TouchConfidence = 70.0;

        port filteredSampleIn : FilteredSamplePort;
        port decisionOut : TouchDecisionPort;

        state def ClassificationStateMachine {
            state idle;
            state noTouch;
            state proximityDetected;
            state contactDetected;
            state faultDetected;

            entry action initializeClassifier;
            transition first idle then noTouch;

            transition noTouch then proximityDetected
                accept when filteredSample.deltaCapacitance >= proximityThreshold
                    and filteredSample.deltaCapacitance < contactThreshold;

            transition proximityDetected then contactDetected
                accept when filteredSample.deltaCapacitance >= contactThreshold;

            transition contactDetected then proximityDetected
                accept when filteredSample.deltaCapacitance < releaseThreshold
                    and filteredSample.deltaCapacitance >= proximityThreshold;

            transition proximityDetected then noTouch
                accept when filteredSample.deltaCapacitance < proximityThreshold;

            transition noTouch then faultDetected
                accept when filteredSample.noiseEstimate > faultNoiseThreshold;

            transition proximityDetected then faultDetected
                accept when filteredSample.noiseEstimate > faultNoiseThreshold;

            transition contactDetected then faultDetected
                accept when filteredSample.noiseEstimate > faultNoiseThreshold;

            transition faultDetected then noTouch
                accept when filteredSample.noiseEstimate <= faultNoiseThreshold;
        }

        action classifyTouch {
            in item filteredSample : FilteredCapacitanceSample;
            out item decision : TouchDecision;

            first start;
            then compareAgainstThresholds;
            then estimateTouchDistance;
            then computeConfidence;
            then publishDecision;
            then done;
        }
    }

    part def DiagnosticMonitor {
        attribute minimumSupplyVoltage : Voltage = 2.7;
        attribute maximumSupplyVoltage : Voltage = 3.6;
        attribute maximumTemperature : Temperature = 85.0;
        attribute minimumTemperature : Temperature = -40.0;
        attribute maximumNoise : Capacitance = 0.25;

        port power : PowerInputPort;
        port filteredSampleIn : FilteredSamplePort;
        port diagnosticOut : DiagnosticPort;

        action evaluateHealth {
            in item supplyVoltage : Voltage;
            in item filteredSample : FilteredCapacitanceSample;
            out item report : DiagnosticReport;

            first start;
            then checkSupplyRange;
            then checkNoiseLevel;
            then checkSignalSaturation;
            then checkElectrodeContinuity;
            then publishDiagnosticReport;
            then done;
        }
    }

    part def HostInterface {
        attribute reportPeriod : TimeDuration = 10.0;

        port commandIn : HostCommandPort;
        port statusOut : HostStatusPort;
        port touchDecisionIn : TouchDecisionPort;
        port diagnosticIn : DiagnosticPort;

        action publishStatus {
            in item decision : TouchDecision;
            in item report : DiagnosticReport;

            first start;
            then packageStatusFrame;
            then transmitStatusFrame;
            then done;
        }
    }

    part def CapacitiveSensingController {
        attribute supplyVoltage : Voltage = 3.3;
        attribute operatingCurrent : Current = 1200.0;
        attribute scanRate : Frequency = 100.0;
        attribute responseTime : TimeDuration = 20.0;

        port powerIn : PowerInputPort;
        port hostCommand : HostCommandPort;
        port hostStatus : HostStatusPort;

        part driver : ExcitationDriver;
        part electrode : CapacitiveElectrode {
            attribute electrodeId = "BTN_1";
            attribute activeArea = 144.0;
        }
        part converter : CapacitanceToDigitalConverter;
        part processor : DigitalSignalProcessor;
        part classifier : TouchClassifier;
        part diagnostics : DiagnosticMonitor;
        part host : HostInterface;

        connect powerIn to driver.power;
        connect powerIn to diagnostics.power;
        connect hostCommand to host.commandIn;

        connect driver.excitationOut to electrode.excitationIn;
        connect electrode.senseOut to converter.senseIn;
        connect converter.rawSampleOut to processor.rawSampleIn;
        connect processor.filteredSampleOut to classifier.filteredSampleIn;
        connect processor.filteredSampleOut to diagnostics.filteredSampleIn;
        connect classifier.decisionOut to host.touchDecisionIn;
        connect diagnostics.diagnosticOut to host.diagnosticIn;
        connect host.statusOut to hostStatus;

        action scanAndReportTouch {
            first start;
            then driveElectrode;
            then acquireCapacitance;
            then convertMeasurement;
            then filterMeasurement;
            then classifyTouchState;
            then evaluateDiagnostics;
            then reportToHost;
            then done;

            action driveElectrode : driver.generateExcitation;
            action acquireCapacitance : electrode.senseCapacitance;
            action convertMeasurement : converter.convertCapacitance;
            action filterMeasurement : processor.filterAndTrackBaseline;
            action classifyTouchState : classifier.classifyTouch;
            action evaluateDiagnostics : diagnostics.evaluateHealth;
            action reportToHost : host.publishStatus;
        }

        state def ControllerOperatingStateMachine {
            state poweredOff;
            state initializing;
            state calibratingBaseline;
            state scanning;
            state reportingTouch;
            state diagnosticFault;
            state lowPower;

            transition first poweredOff;

            transition poweredOff then initializing
                accept when powerIn.supplyVoltage >= 2.7;

            transition initializing then calibratingBaseline
                accept after 5.0 [ms];

            transition calibratingBaseline then scanning
                accept after 50.0 [ms];

            transition scanning then reportingTouch
                accept when classifier.decisionOut.decision.state == TouchStateKind::proximity
                    or classifier.decisionOut.decision.state == TouchStateKind::contact;

            transition reportingTouch then scanning
                accept after 10.0 [ms];

            transition scanning then diagnosticFault
                accept when diagnostics.diagnosticOut.report.electrodeHealth != ElectrodeHealthKind::normal;

            transition diagnosticFault then calibratingBaseline
                accept when hostCommand.recalibrateCommand == true;

            transition scanning then lowPower
                accept when hostCommand.enableCommand == false;

            transition lowPower then calibratingBaseline
                accept when hostCommand.enableCommand == true;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The capacitive sensing system shall detect the presence or touch of a conductive object by measuring changes in electrode capacitance, classifying the interaction state, and reporting a reliable touch decision to a host controller. */
    }

    requirement def CapacitanceMeasurementRequirement {
        doc /* The system shall measure electrode capacitance over a range of 0.5 pF to 80 pF with a digital resolution of at least 16 bits. */
        require constraint {
            converter.resolutionBits >= 16;
            converter.measurableMinimum <= 0.5;
            converter.measurableMaximum >= 80.0;
        }
    }

    requirement def TouchDetectionRequirement {
        doc /* The system shall identify contact when the filtered capacitance delta is at least 0.75 pF and shall identify proximity when the filtered capacitance delta is at least 0.18 pF. */
        require constraint {
            processor.contactThreshold == 0.75;
            processor.proximityThreshold == 0.18;
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall report a touch decision to the host interface within 20 ms of a qualifying capacitance change. */
        require constraint {
            controller.responseTime <= 20.0;
        }
    }

    requirement def NoiseRobustnessRequirement {
        doc /* The system shall reject measurements as faulty when filtered noise exceeds 0.25 pF. */
        require constraint {
            processor.maxAllowedNoise <= 0.25;
            diagnostics.maximumNoise <= 0.25;
        }
    }

    requirement def SupplyRequirement {
        doc /* The system shall operate from a 3.3 V nominal supply and shall detect undervoltage below 2.7 V. */
        require constraint {
            controller.supplyVoltage == 3.3;
            diagnostics.minimumSupplyVoltage == 2.7;
        }
    }

    part controller : CapacitiveSensingController;

    satisfy PrimaryFunctionRequirement by controller;
    satisfy CapacitanceMeasurementRequirement by controller.converter;
    satisfy TouchDetectionRequirement by controller.processor;
    satisfy ResponseTimeRequirement by controller;
    satisfy NoiseRobustnessRequirement by controller.diagnostics;
    satisfy SupplyRequirement by controller;

    view def HighLevelFunctionalView {
        expose controller;
        expose controller.electrode;
        expose controller.driver;
        expose controller.converter;
        expose controller.processor;
        expose controller.classifier;
        expose controller.host;
    }

    view highLevelFunction : HighLevelFunctionalView;
}