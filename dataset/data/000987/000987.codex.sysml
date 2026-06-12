package BhangmeterSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def RadiantIntensityUnit;
    attribute def IrradianceUnit;
    attribute def CountRateUnit;
    attribute def ConfidenceUnit;

    value type Time_us specializes Real {
        unit = "us";
    }

    value type Time_ms specializes Real {
        unit = "ms";
    }

    value type Irradiance_W_per_m2 specializes Real {
        unit = "W/m^2";
    }

    value type OpticalEnergy_J specializes Real {
        unit = "J";
    }

    value type CountRate_counts_per_s specializes Real {
        unit = "counts/s";
    }

    value type Temperature_C specializes Real {
        unit = "degC";
    }

    value type Voltage_V specializes Real {
        unit = "V";
    }

    value type Current_A specializes Real {
        unit = "A";
    }

    value type Power_W specializes Real {
        unit = "W";
    }

    value type Angle_deg specializes Real {
        unit = "deg";
    }

    value type Probability specializes Real {
        unit = "1";
    }

    value type DataRate_bps specializes Real {
        unit = "bit/s";
    }

    item def IncidentOpticalFlash {
        attribute peakIrradiance : Irradiance_W_per_m2;
        attribute firstPulseDuration : Time_ms;
        attribute secondPulseDuration : Time_ms;
        attribute interPulseInterval : Time_ms;
        attribute totalOpticalEnergy : OpticalEnergy_J;
        attribute arrivalAzimuth : Angle_deg;
        attribute arrivalElevation : Angle_deg;
    }

    item def BackgroundLight {
        attribute irradiance : Irradiance_W_per_m2;
        attribute variability : Irradiance_W_per_m2;
    }

    item def OpticalSample {
        attribute sampleTime : Time_us;
        attribute detectorCurrent : Current_A;
        attribute estimatedIrradiance : Irradiance_W_per_m2;
        attribute saturationFlag : Boolean;
    }

    item def FlashEventEstimate {
        attribute detected : Boolean;
        attribute confidence : Probability;
        attribute peakIrradiance : Irradiance_W_per_m2;
        attribute firstPeakTime : Time_ms;
        attribute secondPeakTime : Time_ms;
        attribute pulseSeparation : Time_ms;
        attribute eventAzimuth : Angle_deg;
        attribute eventElevation : Angle_deg;
    }

    item def HealthStatus {
        attribute opticalPathClear : Boolean;
        attribute detectorHealthy : Boolean;
        attribute processorHealthy : Boolean;
        attribute powerHealthy : Boolean;
        attribute temperature : Temperature_C;
    }

    item def MissionReport {
        attribute eventDetected : Boolean;
        attribute eventConfidence : Probability;
        attribute sensorHealthNominal : Boolean;
        attribute reportLatency : Time_ms;
    }

    port def OpticalInputPort {
        in item flash : IncidentOpticalFlash;
        in item background : BackgroundLight;
    }

    port def SamplePort {
        out item sample : OpticalSample;
    }

    port def EventPort {
        out item estimate : FlashEventEstimate;
    }

    port def HealthPort {
        out item health : HealthStatus;
    }

    port def ReportPort {
        out item report : MissionReport;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : Voltage_V;
        in attribute supplyCurrent : Current_A;
    }

    port def ThermalInterfacePort {
        in attribute ambientTemperature : Temperature_C;
        out attribute dissipatedPower : Power_W;
    }

    part def WideAngleOpticalCollector {
        attribute fieldOfViewAzimuth : Angle_deg = 180;
        attribute fieldOfViewElevation : Angle_deg = 120;
        attribute opticalTransmission : Probability = 0.82;
        attribute contaminationLoss : Probability;

        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalInputPort;

        action collectAndFilterLight {
            in item incomingFlash : IncidentOpticalFlash;
            in item incomingBackground : BackgroundLight;
            out item filteredFlash : IncidentOpticalFlash;
            out item filteredBackground : BackgroundLight;
        }
    }

    part def FastPhotodetector {
        attribute riseTime : Time_us = 1.0;
        attribute responsivity : Real = 0.45;
        attribute darkCurrent : Current_A = 0.000000002;
        attribute saturationCurrent : Current_A = 0.02;
        attribute detectorTemperature : Temperature_C;

        port opticalIn : OpticalInputPort;
        port sampleOut : SamplePort;
        port powerIn : PowerInputPort;

        action convertLightToSamples {
            in item flash : IncidentOpticalFlash;
            in item background : BackgroundLight;
            out item sample : OpticalSample;
        }
    }

    part def TimingReference {
        attribute clockStability : Probability = 0.99999;
        attribute tickPeriod : Time_us = 1.0;

        action provideTimestamp {
            out attribute timestamp : Time_us;
        }
    }

    part def SignalConditioner {
        attribute analogBandwidth : Real = 1000000;
        attribute gain : Real = 1000;
        attribute noiseFloor : Current_A = 0.000000001;

        port rawSampleIn : SamplePort;
        port conditionedSampleOut : SamplePort;
        port powerIn : PowerInputPort;

        action conditionSample {
            in item rawSample : OpticalSample;
            out item conditionedSample : OpticalSample;
        }
    }

    part def FlashPatternProcessor {
        attribute minimumDetectablePeak : Irradiance_W_per_m2 = 0.001;
        attribute maximumReportLatency : Time_ms = 500;
        attribute minimumConfidenceForEvent : Probability = 0.90;

        port sampleIn : SamplePort;
        port eventOut : EventPort;
        port healthOut : HealthPort;
        port powerIn : PowerInputPort;

        action estimateBackground {
            in item sample : OpticalSample;
            out item background : BackgroundLight;
        }

        action detectDoublePulseSignature {
            in item sample : OpticalSample;
            out item estimate : FlashEventEstimate;
        }

        action rejectSinglePulseOrSlowTransient {
            in item sample : OpticalSample;
            out attribute rejected : Boolean;
        }

        action assessHealth {
            out item health : HealthStatus;
        }

        state machine processingStates {
            state initializing;
            state monitoring;
            state candidateFlash;
            state validatingDoublePulse;
            state reportingEvent;
            state degraded;
            state faulted;

            transition first initializing then monitoring;
            transition monitoringToCandidate
                first monitoring
                accept OpticalSample
                if minimumDetectablePeak > 0.0
                then candidateFlash;

            transition candidateToValidation
                first candidateFlash
                then validatingDoublePulse;

            transition validationToReport
                first validatingDoublePulse
                if minimumConfidenceForEvent >= 0.90
                then reportingEvent;

            transition reportToMonitoring
                first reportingEvent
                then monitoring;

            transition monitoringToDegraded
                first monitoring
                if minimumConfidenceForEvent < 0.50
                then degraded;

            transition degradedToMonitoring
                first degraded
                if minimumConfidenceForEvent >= 0.90
                then monitoring;

            transition anyToFaulted
                first monitoring
                if maximumReportLatency > 5000
                then faulted;
        }
    }

    part def EventReporter {
        attribute nominalDataRate : DataRate_bps = 9600;
        attribute reportTimeout : Time_ms = 1000;

        port eventIn : EventPort;
        port healthIn : HealthPort;
        port reportOut : ReportPort;
        port powerIn : PowerInputPort;

        action composeMissionReport {
            in item estimate : FlashEventEstimate;
            in item health : HealthStatus;
            out item report : MissionReport;
        }
    }

    part def PowerRegulator {
        attribute inputVoltage : Voltage_V = 28;
        attribute regulatedDetectorVoltage : Voltage_V = 12;
        attribute regulatedLogicVoltage : Voltage_V = 5;
        attribute maximumPower : Power_W = 25;

        port primaryPowerIn : PowerInputPort;
        port detectorPowerOut : PowerInputPort;
        port electronicsPowerOut : PowerInputPort;
    }

    part def ThermalControl {
        attribute minimumOperatingTemperature : Temperature_C = -40;
        attribute maximumOperatingTemperature : Temperature_C = 70;
        attribute dissipatedPower : Power_W;

        port thermalPort : ThermalInterfacePort;

        action regulateTemperature {
            in attribute ambientTemperature : Temperature_C;
            out attribute controlledTemperature : Temperature_C;
        }
    }

    part def Bhangmeter {
        attribute primaryFunction : String = "Detect and characterize the distinctive rapid double-pulse optical flash associated with a high-energy atmospheric event, while rejecting ordinary background illumination and reporting a time-tagged event estimate.";
        attribute detectionConfidenceThreshold : Probability = 0.90;
        attribute requiredReportLatency : Time_ms = 500;
        attribute operatingTemperatureMin : Temperature_C = -40;
        attribute operatingTemperatureMax : Temperature_C = 70;

        port opticalEnvironment : OpticalInputPort;
        port primaryPower : PowerInputPort;
        port thermalInterface : ThermalInterfacePort;
        port missionReport : ReportPort;

        part collector : WideAngleOpticalCollector;
        part detector : FastPhotodetector;
        part conditioner : SignalConditioner;
        part timing : TimingReference;
        part processor : FlashPatternProcessor;
        part reporter : EventReporter;
        part regulator : PowerRegulator;
        part thermal : ThermalControl;

        connect opticalEnvironment to collector.opticalIn;
        connect collector.opticalOut to detector.opticalIn;
        connect detector.sampleOut to conditioner.rawSampleIn;
        connect conditioner.conditionedSampleOut to processor.sampleIn;
        connect processor.eventOut to reporter.eventIn;
        connect processor.healthOut to reporter.healthIn;
        connect reporter.reportOut to missionReport;

        connect primaryPower to regulator.primaryPowerIn;
        connect regulator.detectorPowerOut to detector.powerIn;
        connect regulator.electronicsPowerOut to conditioner.powerIn;
        connect regulator.electronicsPowerOut to processor.powerIn;
        connect regulator.electronicsPowerOut to reporter.powerIn;

        connect thermalInterface to thermal.thermalPort;

        action performPrimaryFunction {
            in item flash : IncidentOpticalFlash;
            in item background : BackgroundLight;
            out item report : MissionReport;

            action collect : collector.collectAndFilterLight;
            action convert : detector.convertLightToSamples;
            action condition : conditioner.conditionSample;
            action detect : processor.detectDoublePulseSignature;
            action health : processor.assessHealth;
            action compose : reporter.composeMissionReport;

            flow flash to collect.incomingFlash;
            flow background to collect.incomingBackground;
            flow collect.filteredFlash to convert.flash;
            flow collect.filteredBackground to convert.background;
            flow convert.sample to condition.rawSample;
            flow condition.conditionedSample to detect.sample;
            flow detect.estimate to compose.estimate;
            flow health.health to compose.health;
            flow compose.report to report;
        }
    }

    requirement def DetectDoublePulseOpticalSignature {
        doc /* The system shall detect a rapid two-peak optical flash signature when the peak irradiance exceeds the calibrated minimum threshold within the collector field of view. */
        attribute threshold : Irradiance_W_per_m2 = 0.001;
        attribute requiredConfidence : Probability = 0.90;
    }

    requirement def RejectBackgroundIllumination {
        doc /* The system shall reject slowly varying sunlight, cloud reflection, lightning-like single-pulse transients, and detector noise as non-events when they do not satisfy the double-pulse temporal pattern. */
        attribute maximumFalseEventProbability : Probability = 0.01;
    }

    requirement def ReportEventEstimate {
        doc /* The system shall issue a mission report containing event detection status, confidence, timing, and sensor health within the required latency after candidate flash recognition. */
        attribute maximumLatency : Time_ms = 500;
    }

    requirement def MaintainOperationalHealth {
        doc /* The system shall monitor detector, optical path, processor, power, and thermal health during operation. */
        attribute minimumTemperature : Temperature_C = -40;
        attribute maximumTemperature : Temperature_C = 70;
    }

    requirement def ProvideHighLevelBhangmeterFunction {
        doc /* The system shall provide the primary Bhangmeter function: high-speed optical sensing and recognition of a distinctive double-pulse flash pattern, producing a reliable event estimate for external mission systems. */
    }

    satisfy DetectDoublePulseOpticalSignature by Bhangmeter::processor;
    satisfy RejectBackgroundIllumination by Bhangmeter::processor;
    satisfy ReportEventEstimate by Bhangmeter::reporter;
    satisfy MaintainOperationalHealth by Bhangmeter;
    satisfy ProvideHighLevelBhangmeterFunction by Bhangmeter;

    constraint def ConfidenceWithinBounds {
        in attribute confidence : Probability;
        assert confidence >= 0.0 and confidence <= 1.0;
    }

    constraint def ReportLatencyLimit {
        in attribute latency : Time_ms;
        in attribute requiredLatency : Time_ms;
        assert latency <= requiredLatency;
    }

    constraint def ThermalOperatingLimit {
        in attribute temperature : Temperature_C;
        in attribute minimumTemperature : Temperature_C;
        in attribute maximumTemperature : Temperature_C;
        assert temperature >= minimumTemperature and temperature <= maximumTemperature;
    }

    analysis def DetectionPerformanceAnalysis {
        subject sensor : Bhangmeter;

        objective confidenceObjective {
            doc /* Evaluate whether detected flash events meet the required confidence threshold. */
        }

        constraint confidenceBound : ConfidenceWithinBounds {
            confidence = sensor.detectionConfidenceThreshold;
        }

        constraint latencyBound : ReportLatencyLimit {
            latency = sensor.requiredReportLatency;
            requiredLatency = 500;
        }

        constraint thermalBound : ThermalOperatingLimit {
            temperature = 25;
            minimumTemperature = sensor.operatingTemperatureMin;
            maximumTemperature = sensor.operatingTemperatureMax;
        }
    }

    part operationalBhangmeter : Bhangmeter {
        attribute detectionConfidenceThreshold = 0.90;
        attribute requiredReportLatency = 500;
        attribute operatingTemperatureMin = -40;
        attribute operatingTemperatureMax = 70;
    }
}