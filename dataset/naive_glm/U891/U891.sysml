package SpeedSensingUnit {
    doc "Self-contained Speed Sensing Unit - an electronic module for accurately measuring and reporting speed.";
    import ScalarValues::*;

    // ===== Value Types =====
    value def Voltage :> Real;
    value def Current :> Real;
    value def Frequency :> Real;
    value def Speed :> Real;
    value def Timestamp :> Real;
    value def Percentage :> Real;

    // ===== Enumerations =====
    enum def CommandType {
        start;
        stop;
        reset;
        powerDown;
    }

    enum def SystemStateKind {
        off;
        initializing;
        ready;
        measuring;
        fault;
    }

    enum def ValidityStatus {
        valid;
        outOfRange;
        sensorError;
        calibrationError;
    }

    // ===== Items =====
    item def RawSensorSignal {
        doc "Raw electrical signal from the speed sensor.";
        attribute voltage : Voltage;
        attribute pulseFrequency : Frequency;
        attribute noiseLevel : Real;
    }

    item def ConditionedSignal {
        doc "Filtered and amplified sensor signal.";
        attribute voltage : Voltage;
        attribute pulseFrequency : Frequency;
        attribute signalToNoiseRatio : Real;
    }

    item def CalibratedSpeed {
        doc "Calibrated speed value derived from conditioned signal.";
        attribute value : Speed;
        attribute confidence : Percentage;
    }

    item def MeasurementMessage {
        doc "Final packaged speed measurement with metadata.";
        attribute speedValue : Speed;
        attribute timestamp : Timestamp;
        attribute isValid : Boolean;
        attribute validityStatus : ValidityStatus;
        attribute sequenceNumber : Integer;
    }

    item def DiagnosticReport {
        doc "Diagnostic information for fault reporting.";
        attribute statusCode : Integer;
        attribute message : String;
        attribute timestamp : Timestamp;
        attribute systemState : SystemStateKind;
        attribute errorCount : Integer;
    }

    item def CommandMessage {
        doc "Command received from external system.";
        attribute commandType : CommandType;
        attribute timestamp : Timestamp;
    }

    // ===== Ports =====
    port def PowerPort {
        doc "Power input port for 5V DC supply.";
        attribute voltage : Voltage;
        attribute current : Current;
        attribute powerOn : Boolean;
    }

    port def DataOutputPort {
        doc "Data output port for speed measurements.";
        out item measurement : MeasurementMessage;
    }

    port def DiagnosticPort {
        doc "Bidirectional port for diagnostics and commands.";
        out item diagnostic : DiagnosticReport;
        in item command : CommandMessage;
    }

    // ===== Requirements =====
    requirement def PowerRequirement {
        doc "The unit shall operate on a 5V DC power supply.";
        attribute nominalVoltage : Voltage = 5.0;
        attribute voltageTolerance : Voltage = 0.25;
        constraint { nominalVoltage == 5.0; }
        constraint { voltageTolerance <= 0.25; }
    }

    requirement def SamplingRateRequirement {
        doc "The unit shall provide measurements at a rate of at least 10 Hz.";
        attribute minSamplingRate : Frequency = 10.0;
        constraint { minSamplingRate >= 10.0; }
    }

    requirement def AccuracyRequirement {
        doc "The unit shall maintain an accuracy of better than 1%.";
        attribute maxError : Percentage = 1.0;
        constraint { maxError < 1.0; }
    }

    requirement def OperationalRangeRequirement {
        doc "The unit shall measure speed in the range of 0 to 200 m/s.";
        attribute minSpeed : Speed = 0.0;
        attribute maxSpeed : Speed = 200.0;
        constraint { minSpeed >= 0.0; }
        constraint { maxSpeed <= 200.0; }
    }

    requirement def SelfTestRequirement {
        doc "The unit shall perform a self-test during initialization.";
        attribute selfTestTimeout : Timestamp = 2.0;
        constraint { selfTestTimeout <= 2.0; }
    }

    // ===== Sub-Components =====
    part def SpeedSensor {
        doc "Core transducer that generates raw electrical signal in response to motion.";
        attribute supplyVoltage : Voltage = 5.0;
        attribute operatingRange : Speed = 200.0;
        attribute accuracy : Percentage = 0.5;
        attribute responseTime : Timestamp = 0.001;
        out port rawSignalOut : RawSensorSignal;

        action def sense {
            doc "Generate raw signal in response to motion.";
            in motionInput : Speed;
            out rawSignal : RawSensorSignal;
        }

        action def calibrate {
            doc "Perform sensor calibration.";
            out calibrationResult : Boolean;
        }
    }

    part def SignalConditioner {
        doc "Filters and amplifies raw sensor signal.";
        attribute gain : Real = 10.0;
        attribute filterCutoff : Frequency = 1000.0;
        attribute noiseRejection : Percentage = 80.0;
        in port rawSignalIn : RawSensorSignal;
        out port conditionedSignalOut : ConditionedSignal;

        action def filter {
            doc "Apply low-pass filter to remove noise.";
            in input : RawSensorSignal;
            out filtered : RawSensorSignal;
        }

        action def amplify {
            doc "Amplify filtered signal.";
            in input : RawSensorSignal;
            out amplified : RawSensorSignal;
        }

        action def condition {
            doc "Full signal conditioning pipeline.";
            in input : RawSensorSignal;
            out output : ConditionedSignal;
            first filter;
            then amplify;
        }
    }

    part def DataLogger {
        doc "Stores a history of recent speed measurements.";
        attribute bufferSize : Integer = 100;
        attribute currentIndex : Integer = 0;
        attribute totalLogged : Integer = 0;
        attribute measurementHistory : MeasurementMessage[0..100];
        in port measurementIn : MeasurementMessage;
        out port historyOut : MeasurementMessage[0..100];

        action def store {
            doc "Store a measurement in the buffer.";
            in measurement : MeasurementMessage;
        }

        action def retrieve {
            doc "Retrieve measurement history.";
            out measurements : MeasurementMessage[0..100];
        }

        action def clear {
            doc "Clear the measurement buffer.";
        }

        action def getLatest {
            doc "Get the most recent measurement.";
            out latest : MeasurementMessage;
        }
    }

    // ===== Main System =====
    part def SpeedSensingUnit {
        doc "Complete speed sensing system-on-a-chip integrating sensor, conditioner, and data logger.";

        // External Ports
        port powerInput : PowerPort;
        port dataOutput : DataOutputPort;
        port diagPort : DiagnosticPort;

        // Sub-components
        part speedSensor : SpeedSensor;
        part signalConditioner : SignalConditioner;
        part dataLogger : DataLogger;

        // System Attributes
        attribute systemState : SystemStateKind = SystemStateKind::off;
        attribute samplingRate : Frequency = 10.0;
        attribute operatingVoltage : Voltage = 5.0;
        attribute minSpeed : Speed = 0.0;
        attribute maxSpeed : Speed = 200.0;
        attribute accuracy : Percentage = 1.0;
        attribute lastMeasurement : MeasurementMessage;
        attribute lastDiagnostic : DiagnosticReport;
        attribute currentTime : Timestamp;
        attribute selfTestResult : Boolean;
        attribute errorDetected : Boolean = false;
        attribute sequenceCounter : Integer = 0;
        attribute selfTestStartTime : Timestamp;
        attribute selfTestTimeout : Timestamp = 2.0;
        attribute errorCount : Integer = 0;

        // Internal connections
        connect speedSensor.rawSignalOut to signalConditioner.rawSignalIn;
        connect signalConditioner.conditionedSignalOut to dataLogger.measurementIn;

        // ===== Action Definitions =====
        action def acquireData {
            doc "Acquire raw data from the speed sensor.";
            out rawSignal : RawSensorSignal;
        }

        action def convertToSpeed {
            doc "Convert conditioned signal into a calibrated speed value.";
            in conditioned : ConditionedSignal;
            out calibrated : CalibratedSpeed;
        }

        action def validateMeasurement {
            doc "Validate that speed measurement falls within operational range.";
            in calibrated : CalibratedSpeed;
            out isValid : Boolean;
            out validity : ValidityStatus;
        }

        action def packageMeasurement {
            doc "Package speed value with timestamp and validity status.";
            in calibrated : CalibratedSpeed;
            in isValid : Boolean;
            in validity : ValidityStatus;
            in timestamp : Timestamp;
            out message : MeasurementMessage;
        }

        action def performSelfTest {
            doc "Perform system self-test during initialization.";
            out success : Boolean;
            out errorCode : Integer;
        }

        action def reportDiagnostic {
            doc "Report diagnostic information through diagnostic port.";
            in statusCode : Integer;
            in message : String;
        }

        action def resetSystem {
            doc "Reset the system from fault state.";
        }

        action def measurementCycle {
            doc "Complete measurement cycle: acquire, convert, validate, package.";
            out measurement : MeasurementMessage;
            first acquireData;
            then convertToSpeed;
            then validateMeasurement;
            then packageMeasurement;
        }

        // ===== State Machine =====
        state machine operationStates {
            doc "Defines the operational states of the speed sensing unit.";

            state off {
                doc "Powered off state.";
                entry {
                    systemState = SystemStateKind::off;
                    errorDetected = false;
                }
            }

            state initializing {
                doc "Initialization state with self-test.";
                entry {
                    systemState = SystemStateKind::initializing;
                }
                do performSelfTest;
            }

            state ready {
                doc "Ready state, awaiting commands.";
                entry {
                    systemState = SystemStateKind::ready;
                }
            }

            state measuring {
                doc "Continuous measurement loop.";
                entry {
                    systemState = SystemStateKind::measuring;
                    sequenceCounter = 0;
                }
                do measurementCycle;
            }

            state fault {
                doc "Fault state with diagnostic reporting.";
                entry {
                    systemState = SystemStateKind::fault;
                    errorCount = errorCount + 1;
                }
            }

            // Transitions
            transition from off to initializing
                when powerInput.powerOn;

            transition from initializing to ready
                when selfTestResult == true;

            transition from initializing to fault
                when selfTestResult == false;

            transition from ready to measuring
                when diagPort.command.commandType == CommandType::start;

            transition from ready to off
                when diagPort.command.commandType == CommandType::powerDown;

            transition from measuring to ready
                when diagPort.command.commandType == CommandType::stop;

            transition from measuring to fault
                when errorDetected == true;

            transition from fault to initializing
                when diagPort.command.commandType == CommandType::reset;

            transition from fault to off
                when diagPort.command.commandType == CommandType::powerDown;
        }

        // ===== Requirements Satisfaction =====
        requirement powerReq : PowerRequirement;
        requirement samplingRateReq : SamplingRateRequirement;
        requirement accuracyReq : AccuracyRequirement;
        requirement opRangeReq : OperationalRangeRequirement;
        requirement selfTestReq : SelfTestRequirement;

        satisfy powerReq by operatingVoltage;
        satisfy samplingRateReq by samplingRate;
        satisfy accuracyReq by accuracy;
        satisfy opRangeReq by maxSpeed;
        satisfy selfTestReq by selfTestTimeout;
    }
}
