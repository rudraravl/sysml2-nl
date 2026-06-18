package ShockDetectorModel {

    package ValueTypes {
        attribute def Acceleration {
            attribute value: Real;
            attribute unitSymbol: String = "m/s^2";
        }

        attribute def Velocity {
            attribute value: Real;
            attribute unitSymbol: String = "m/s";
        }

        attribute def TimeDuration {
            attribute value: Real;
            attribute unitSymbol: String = "ms";
        }

        attribute def Frequency {
            attribute value: Real;
            attribute unitSymbol: String = "Hz";
        }

        attribute def Voltage {
            attribute value: Real;
            attribute unitSymbol: String = "V";
        }

        attribute def Current {
            attribute value: Real;
            attribute unitSymbol: String = "mA";
        }

        attribute def ElectricPower {
            attribute value: Real;
            attribute unitSymbol: String = "mW";
        }

        attribute def Temperature {
            attribute value: Real;
            attribute unitSymbol: String = "degC";
        }

        attribute def MemorySize {
            attribute value: Real;
            attribute unitSymbol: String = "kB";
        }

        attribute def Probability {
            attribute value: Real;
            attribute unitSymbol: String = "1";
        }

        attribute def Count {
            attribute value: Integer;
            attribute unitSymbol: String = "count";
        }
    }

    package Items {
        import ValueTypes::*;

        enum def ShockSeverity {
            enum noShock;
            enum minorShock;
            enum moderateShock;
            enum severeShock;
            enum destructiveShock;
        }

        enum def DetectorMode {
            enum poweredOff;
            enum initializing;
            enum selfTest;
            enum standby;
            enum monitoring;
            enum shockConfirmed;
            enum reporting;
            enum fault;
        }

        enum def FaultCode {
            enum none;
            enum sensorSaturation;
            enum sensorDisconnected;
            enum processorWatchdogExpired;
            enum storageUnavailable;
            enum lowSupplyVoltage;
            enum calibrationInvalid;
        }

        item def MechanicalAcceleration {
            attribute ax: Acceleration;
            attribute ay: Acceleration;
            attribute az: Acceleration;
            attribute timestamp: TimeDuration;
        }

        item def AnalogAccelerationSignal {
            attribute xVoltage: Voltage;
            attribute yVoltage: Voltage;
            attribute zVoltage: Voltage;
            attribute bandwidth: Frequency;
        }

        item def DigitalAccelerationSample {
            attribute ax: Acceleration;
            attribute ay: Acceleration;
            attribute az: Acceleration;
            attribute sampleTime: TimeDuration;
            attribute sampleRate: Frequency;
            attribute sensorTemperature: Temperature;
            attribute valid: Boolean;
        }

        item def FilteredAccelerationSample {
            attribute resultantAcceleration: Acceleration;
            attribute highPassAcceleration: Acceleration;
            attribute sampleTime: TimeDuration;
            attribute valid: Boolean;
        }

        item def ShockCandidate {
            attribute peakAcceleration: Acceleration;
            attribute durationAboveThreshold: TimeDuration;
            attribute peakTime: TimeDuration;
            attribute candidateValid: Boolean;
        }

        item def ShockEvent {
            attribute eventId: Count;
            attribute peakAcceleration: Acceleration;
            attribute duration: TimeDuration;
            attribute severity: ShockSeverity;
            attribute detectionLatency: TimeDuration;
            attribute confidence: Probability;
            attribute occurredAt: TimeDuration;
        }

        item def ShockReport {
            attribute reportId: Count;
            attribute eventId: Count;
            attribute severity: ShockSeverity;
            attribute peakAcceleration: Acceleration;
            attribute duration: TimeDuration;
            attribute emittedAt: TimeDuration;
            attribute acknowledged: Boolean;
        }

        item def PowerInput {
            attribute voltage: Voltage;
            attribute currentLimit: Current;
            attribute availablePower: ElectricPower;
        }

        item def RegulatedPower {
            attribute voltage: Voltage;
            attribute current: Current;
            attribute power: ElectricPower;
            attribute withinTolerance: Boolean;
        }

        item def ConfigurationData {
            attribute sampleRate: Frequency;
            attribute minorThreshold: Acceleration;
            attribute moderateThreshold: Acceleration;
            attribute severeThreshold: Acceleration;
            attribute destructiveThreshold: Acceleration;
            attribute minimumPulseDuration: TimeDuration;
            attribute alarmHoldTime: TimeDuration;
            attribute calibrationValid: Boolean;
        }

        item def HealthStatus {
            attribute mode: DetectorMode;
            attribute fault: FaultCode;
            attribute supplyOk: Boolean;
            attribute sensorOk: Boolean;
            attribute storageOk: Boolean;
            attribute temperatureOk: Boolean;
            attribute selfTestPassed: Boolean;
        }

        item def AlarmCommand {
            attribute active: Boolean;
            attribute severity: ShockSeverity;
            attribute holdTime: TimeDuration;
        }

        item def MaintenanceCommand {
            attribute requestSelfTest: Boolean;
            attribute requestCalibration: Boolean;
            attribute clearLoggedEvents: Boolean;
        }
    }

    package Ports {
        import Items::*;

        port def ShockInputPort {
            in item acceleration: MechanicalAcceleration;
        }

        port def AnalogSensorPort {
            out item analogAcceleration: AnalogAccelerationSignal;
        }

        port def DigitalSamplePort {
            out item sample: DigitalAccelerationSample;
        }

        port def FilteredSamplePort {
            out item filteredSample: FilteredAccelerationSample;
        }

        port def CandidatePort {
            out item candidate: ShockCandidate;
        }

        port def EventPort {
            out item shockEvent: ShockEvent;
        }

        port def ReportPort {
            out item report: ShockReport;
        }

        port def PowerInputPort {
            in item power: PowerInput;
        }

        port def RegulatedPowerPort {
            out item regulatedPower: RegulatedPower;
        }

        port def ConfigurationPort {
            in item configuration: ConfigurationData;
        }

        port def HealthPort {
            out item health: HealthStatus;
        }

        port def AlarmPort {
            in item command: AlarmCommand;
        }

        port def MaintenancePort {
            in item command: MaintenanceCommand;
            out item health: HealthStatus;
        }
    }

    package Constraints {
        import ValueTypes::*;
        import Items::*;

        constraint def ThresholdExceeded {
            in item candidate: ShockCandidate;
            in item configuration: ConfigurationData;
            attribute thresholdExceeded: Boolean;
            constraint {
                thresholdExceeded ==
                    candidate.peakAcceleration.value >= configuration.minorThreshold.value and
                    candidate.durationAboveThreshold.value >= configuration.minimumPulseDuration.value
            }
        }

        constraint def SeverityClassification {
            in item candidate: ShockCandidate;
            in item configuration: ConfigurationData;
            attribute severity: ShockSeverity;
            constraint {
                if candidate.peakAcceleration.value >= configuration.destructiveThreshold.value then severity == ShockSeverity::destructiveShock
                else if candidate.peakAcceleration.value >= configuration.severeThreshold.value then severity == ShockSeverity::severeShock
                else if candidate.peakAcceleration.value >= configuration.moderateThreshold.value then severity == ShockSeverity::moderateShock
                else if candidate.peakAcceleration.value >= configuration.minorThreshold.value then severity == ShockSeverity::minorShock
                else severity == ShockSeverity::noShock
            }
        }

        constraint def DetectionLatencyLimit {
            in item event: ShockEvent;
            attribute maximumAllowedLatency: TimeDuration;
            constraint {
                event.detectionLatency.value <= maximumAllowedLatency.value
            }
        }

        constraint def SupplyVoltageRange {
            in item power: PowerInput;
            attribute minimumVoltage: Voltage;
            attribute maximumVoltage: Voltage;
            constraint {
                power.voltage.value >= minimumVoltage.value and power.voltage.value <= maximumVoltage.value
            }
        }
    }

    package Behaviors {
        import ValueTypes::*;
        import Items::*;
        import Constraints::*;

        action def AcquireAcceleration {
            in item analogInput: AnalogAccelerationSignal;
            out item digitalOutput: DigitalAccelerationSample;

            attribute configuredSampleRate: Frequency = (value = 20000.0; unitSymbol = "Hz");
            attribute conversionValid: Boolean;

            constraint {
                digitalOutput.sampleRate.value == configuredSampleRate.value
            }
        }

        action def FilterAcceleration {
            in item rawSample: DigitalAccelerationSample;
            out item filteredSample: FilteredAccelerationSample;

            attribute highPassCutoff: Frequency = (value = 5.0; unitSymbol = "Hz");
            attribute lowPassCutoff: Frequency = (value = 5000.0; unitSymbol = "Hz");

            constraint {
                filteredSample.valid == rawSample.valid
            }
        }

        action def DetectShockCandidate {
            in item filteredSample: FilteredAccelerationSample;
            in item configuration: ConfigurationData;
            out item candidate: ShockCandidate;

            attribute resultantMagnitude: Acceleration;
            attribute thresholdExceeded: Boolean;

            constraint {
                candidate.peakAcceleration.value >= filteredSample.resultantAcceleration.value
            }
        }

        action def ClassifyShock {
            in item candidate: ShockCandidate;
            in item configuration: ConfigurationData;
            out item event: ShockEvent;

            bind candidate.peakAcceleration = event.peakAcceleration;
            bind candidate.durationAboveThreshold = event.duration;

            satisfy SeverityClassification by event;
        }

        action def LogShockEvent {
            in item event: ShockEvent;
            out item storedReport: ShockReport;

            attribute writeComplete: Boolean;

            bind event.eventId = storedReport.eventId;
            bind event.peakAcceleration = storedReport.peakAcceleration;
            bind event.duration = storedReport.duration;
            bind event.severity = storedReport.severity;
        }

        action def AnnunciateShock {
            in item event: ShockEvent;
            out item alarmCommand: AlarmCommand;

            bind event.severity = alarmCommand.severity;

            constraint {
                alarmCommand.active == true
            }
        }

        action def ReportShock {
            in item storedReport: ShockReport;
            out item externalReport: ShockReport;

            bind storedReport.reportId = externalReport.reportId;
            bind storedReport.eventId = externalReport.eventId;
            bind storedReport.severity = externalReport.severity;
            bind storedReport.peakAcceleration = externalReport.peakAcceleration;
            bind storedReport.duration = externalReport.duration;
        }

        action def PerformSelfTest {
            in item configuration: ConfigurationData;
            out item health: HealthStatus;

            constraint {
                health.selfTestPassed == configuration.calibrationValid
            }
        }

        action def DetectAndReportShock {
            in item analogInput: AnalogAccelerationSignal;
            in item configuration: ConfigurationData;
            out item externalReport: ShockReport;
            out item alarmCommand: AlarmCommand;
            out item health: HealthStatus;

            action acquire: AcquireAcceleration;
            action filter: FilterAcceleration;
            action detect: DetectShockCandidate;
            action classify: ClassifyShock;
            action log: LogShockEvent;
            action annunciate: AnnunciateShock;
            action report: ReportShock;

            flow analogInput to acquire.analogInput;
            flow acquire.digitalOutput to filter.rawSample;
            flow filter.filteredSample to detect.filteredSample;
            flow configuration to detect.configuration;
            flow detect.candidate to classify.candidate;
            flow configuration to classify.configuration;
            flow classify.event to log.event;
            flow classify.event to annunciate.event;
            flow log.storedReport to report.storedReport;
            flow annunciate.alarmCommand to alarmCommand;
            flow report.externalReport to externalReport;
        }

        state def ShockDetectorOperatingStates {
            entry; then PoweredOff;

            state PoweredOff;
            state Initializing;
            state SelfTesting;
            state Standby;
            state Monitoring;
            state ShockConfirmed;
            state Reporting;
            state Fault;

            transition PowerApplied
                first PoweredOff
                then Initializing;

            transition InitializationComplete
                first Initializing
                then SelfTesting;

            transition SelfTestPassed
                first SelfTesting
                then Standby;

            transition MonitoringEnabled
                first Standby
                then Monitoring;

            transition CandidateExceedsThreshold
                first Monitoring
                then ShockConfirmed;

            transition EventClassified
                first ShockConfirmed
                then Reporting;

            transition ReportEmitted
                first Reporting
                then Monitoring;

            transition FaultDetectedFromInitializing
                first Initializing
                then Fault;

            transition FaultDetectedFromSelfTesting
                first SelfTesting
                then Fault;

            transition FaultDetectedFromMonitoring
                first Monitoring
                then Fault;

            transition FaultCleared
                first Fault
                then SelfTesting;

            transition PowerRemovedFromStandby
                first Standby
                then PoweredOff;

            transition PowerRemovedFromMonitoring
                first Monitoring
                then PoweredOff;

            transition PowerRemovedFromFault
                first Fault
                then PoweredOff;
        }
    }

    package Structure {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Behaviors::*;

        part def ShockSensorAssembly {
            port motionIn: ShockInputPort;
            port analogOut: AnalogSensorPort;
            port powerIn: RegulatedPowerPort;

            attribute measurementRange: Acceleration = (value = 490.5; unitSymbol = "m/s^2");
            attribute resonantFrequency: Frequency = (value = 18000.0; unitSymbol = "Hz");
            attribute noiseDensity: Acceleration = (value = 0.02; unitSymbol = "m/s^2");
            attribute operatingTemperatureMinimum: Temperature = (value = -40.0; unitSymbol = "degC");
            attribute operatingTemperatureMaximum: Temperature = (value = 85.0; unitSymbol = "degC");
        }

        part def SignalConditioner {
            port analogIn: AnalogSensorPort;
            port sampleOut: DigitalSamplePort;
            port powerIn: RegulatedPowerPort;

            attribute antiAliasCutoff: Frequency = (value = 5000.0; unitSymbol = "Hz");
            attribute adcResolution: Count = (value = 16; unitSymbol = "count");
            attribute conversionRate: Frequency = (value = 20000.0; unitSymbol = "Hz");

            perform action acquire: AcquireAcceleration;
        }

        part def ShockProcessingUnit {
            port sampleIn: DigitalSamplePort;
            port configurationIn: ConfigurationPort;
            port eventOut: EventPort;
            port healthOut: HealthPort;
            port maintenance: MaintenancePort;
            port powerIn: RegulatedPowerPort;

            attribute detectionLatencyBudget: TimeDuration = (value = 10.0; unitSymbol = "ms");
            attribute processorClock: Frequency = (value = 48000000.0; unitSymbol = "Hz");
            attribute currentMode: DetectorMode = DetectorMode::poweredOff;

            perform action filter: FilterAcceleration;
            perform action detect: DetectShockCandidate;
            perform action classify: ClassifyShock;
            perform action selfTest: PerformSelfTest;
            exhibit state operatingStates: ShockDetectorOperatingStates;
        }

        part def EventMemory {
            port eventIn: EventPort;
            port reportOut: ReportPort;
            port powerIn: RegulatedPowerPort;

            attribute capacity: MemorySize = (value = 512.0; unitSymbol = "kB");
            attribute maximumStoredEvents: Count = (value = 4096; unitSymbol = "count");
            attribute nonvolatile: Boolean = true;

            perform action log: LogShockEvent;
        }

        part def CommunicationInterface {
            port reportIn: ReportPort;
            port reportOut: ReportPort;
            port healthIn: HealthPort;
            port powerIn: RegulatedPowerPort;

            attribute interfaceVoltage: Voltage = (value = 3.3; unitSymbol = "V");
            attribute maximumReportLatency: TimeDuration = (value = 50.0; unitSymbol = "ms");

            perform action report: ReportShock;
        }

        part def AlarmIndicator {
            port alarmIn: AlarmPort;
            port powerIn: RegulatedPowerPort;

            attribute audibleLevelAtOneMeter: Count = (value = 85; unitSymbol = "count");
            attribute visualFlashRate: Frequency = (value = 2.0; unitSymbol = "Hz");

            perform action annunciate: AnnunciateShock;
        }

        part def PowerRegulator {
            port externalPowerIn: PowerInputPort;
            port regulatedPowerOut: RegulatedPowerPort;

            attribute nominalInputVoltage: Voltage = (value = 12.0; unitSymbol = "V");
            attribute minimumInputVoltage: Voltage = (value = 9.0; unitSymbol = "V");
            attribute maximumInputVoltage: Voltage = (value = 36.0; unitSymbol = "V");
            attribute regulatedVoltage: Voltage = (value = 3.3; unitSymbol = "V");
            attribute maximumOutputPower: ElectricPower = (value = 1500.0; unitSymbol = "mW");
        }

        part def ProtectiveHousing {
            port mechanicalInterface: ShockInputPort;

            attribute ingressProtectionRating: String = "IP67";
            attribute massLimit: Count = (value = 250; unitSymbol = "count");
            attribute mountResonance: Frequency = (value = 1200.0; unitSymbol = "Hz");
        }

        part def ShockDetector {
            port shockIn: ShockInputPort;
            port powerIn: PowerInputPort;
            port configurationIn: ConfigurationPort;
            port maintenance: MaintenancePort;
            port reportOut: ReportPort;
            port healthOut: HealthPort;
            port alarmOut: AlarmPort;

            attribute primaryFunction: String = "Sense mechanical acceleration, determine whether a shock event has occurred, classify the event severity, record it, and provide timely alarm and report outputs.";
            attribute nominalSampleRate: Frequency = (value = 20000.0; unitSymbol = "Hz");
            attribute minorShockThreshold: Acceleration = (value = 49.05; unitSymbol = "m/s^2");
            attribute moderateShockThreshold: Acceleration = (value = 98.10; unitSymbol = "m/s^2");
            attribute severeShockThreshold: Acceleration = (value = 196.20; unitSymbol = "m/s^2");
            attribute destructiveShockThreshold: Acceleration = (value = 392.40; unitSymbol = "m/s^2");
            attribute minimumDetectablePulseDuration: TimeDuration = (value = 1.0; unitSymbol = "ms");
            attribute maximumDetectionLatency: TimeDuration = (value = 10.0; unitSymbol = "ms");

            part housing: ProtectiveHousing;
            part sensor: ShockSensorAssembly;
            part conditioner: SignalConditioner;
            part processor: ShockProcessingUnit;
            part memory: EventMemory;
            part communications: CommunicationInterface;
            part alarm: AlarmIndicator;
            part powerRegulator: PowerRegulator;

            connect shockIn to housing.mechanicalInterface;
            connect housing.mechanicalInterface to sensor.motionIn;

            connect powerIn to powerRegulator.externalPowerIn;
            connect powerRegulator.regulatedPowerOut to sensor.powerIn;
            connect powerRegulator.regulatedPowerOut to conditioner.powerIn;
            connect powerRegulator.regulatedPowerOut to processor.powerIn;
            connect powerRegulator.regulatedPowerOut to memory.powerIn;
            connect powerRegulator.regulatedPowerOut to communications.powerIn;
            connect powerRegulator.regulatedPowerOut to alarm.powerIn;

            connect sensor.analogOut to conditioner.analogIn;
            connect conditioner.sampleOut to processor.sampleIn;
            connect configurationIn to processor.configurationIn;
            connect maintenance to processor.maintenance;
            connect processor.healthOut to healthOut;
            connect processor.healthOut to communications.healthIn;
            connect processor.eventOut to memory.eventIn;
            connect memory.reportOut to communications.reportIn;
            connect communications.reportOut to reportOut;
            connect alarmOut to alarm.alarmIn;

            perform action shockDetectionFunction: DetectAndReportShock;
            exhibit state lifecycle: ShockDetectorOperatingStates;
        }

        part def ShockEnvironment {
            port shockOut: ShockInputPort;

            attribute maximumExpectedShock: Acceleration = (value = 490.5; unitSymbol = "m/s^2");
            attribute shortestExpectedPulse: TimeDuration = (value = 0.5; unitSymbol = "ms");
        }

        part shockDetectorSystem {
            part environment: ShockEnvironment;
            part detector: ShockDetector;

            connect environment.shockOut to detector.shockIn;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Items::*;
        import Structure::*;
        import Constraints::*;

        requirement def PrimaryFunctionRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall provide the high-level function of sensing mechanical acceleration, detecting shock events, classifying shock severity, recording event data, and issuing alarm and report outputs."

            require constraint {
                detector.maximumDetectionLatency.value <= 10.0
            }
        }

        requirement def AccelerationSensingRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall sense three-axis mechanical acceleration sufficient to identify shock events up to 490.5 m/s^2."

            require constraint {
                detector.sensor.measurementRange.value >= 490.5
            }
        }

        requirement def ShockThresholdRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall classify minor, moderate, severe, and destructive shock levels using configured acceleration thresholds."

            require constraint {
                detector.minorShockThreshold.value < detector.moderateShockThreshold.value and
                detector.moderateShockThreshold.value < detector.severeShockThreshold.value and
                detector.severeShockThreshold.value < detector.destructiveShockThreshold.value
            }
        }

        requirement def MinimumPulseDetectionRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall detect shock pulses with duration greater than or equal to 1 ms when the measured peak acceleration exceeds the minor shock threshold."

            require constraint {
                detector.minimumDetectablePulseDuration.value <= 1.0
            }
        }

        requirement def DetectionLatencyRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall confirm and report a valid shock event within 10 ms of the threshold crossing."

            require constraint {
                detector.maximumDetectionLatency.value <= 10.0
            }
        }

        requirement def EventLoggingRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall store shock event identifier, peak acceleration, duration, severity, and event time in nonvolatile memory."

            require constraint {
                detector.memory.nonvolatile == true and detector.memory.maximumStoredEvents.value >= 4096
            }
        }

        requirement def AlarmOutputRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall activate a local alarm when a confirmed shock event is classified as minorShock or greater."

            require constraint {
                detector.alarm.audibleLevelAtOneMeter.value >= 85
            }
        }

        requirement def PowerRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall operate from an external DC supply between 9 V and 36 V and regulate internal power to 3.3 V."

            require constraint {
                detector.powerRegulator.minimumInputVoltage.value <= 9.0 and
                detector.powerRegulator.maximumInputVoltage.value >= 36.0 and
                detector.powerRegulator.regulatedVoltage.value == 3.3
            }
        }

        requirement def HealthMonitoringRequirement {
            subject detector: ShockDetector;

            doc "The shock detector shall provide health status including current mode, fault code, supply status, sensor status, storage status, temperature status, and self-test result."

            require constraint {
                detector.processor.currentMode != DetectorMode::fault or detector.processor.healthOut.health.fault != FaultCode::none
            }
        }

        requirement primaryFunction: PrimaryFunctionRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement accelerationSensing: AccelerationSensingRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement shockThresholds: ShockThresholdRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement pulseDetection: MinimumPulseDetectionRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement latency: DetectionLatencyRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement eventLogging: EventLoggingRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement alarmOutput: AlarmOutputRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement power: PowerRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }

        requirement healthMonitoring: HealthMonitoringRequirement {
            subject detector = Structure::shockDetectorSystem.detector;
        }
    }
}
