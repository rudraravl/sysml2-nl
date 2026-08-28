package GasDetectorSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import MeasurementReferences::*;
    import StateBehaviors::*;

    // ===== Units and Value Types =====
    unit ppm {
        shortName = "ppm";
    }

    value type Concentration :> Real {
        unit = ppm;
    }

    value type Voltage :> Real {
        unit = Volt;
    }

    value type Power :> Real {
        unit = Watt;
    }

    value type TimeSeconds :> Real {
        unit = "s";
    }

    value type TimeInterval :> Real {
        unit = "min";
    }

    // ===== Enumerations =====
    enum def AlarmLevel {
        normal;
        warning;
        danger;
        critical;
    }

    enum def SystemState {
        initializing;
        monitoring;
        alarming;
        fault;
    }

    enum def FaultCode {
        none;
        sensorOutOfRange;
        signalProcessorError;
        powerFault;
        loggerFull;
    }

    // ===== Item Definitions =====
    item def RawSensorReading {
        attribute value : Concentration;
        attribute timestamp : TimeSeconds;
        attribute sensorId : String;
    }

    item def ProcessedReading {
        attribute value : Concentration;
        attribute timestamp : TimeSeconds;
        attribute valid : Boolean;
        attribute calibrated : Boolean;
    }

    item def AlarmEvent {
        attribute level : AlarmLevel;
        attribute concentration : Concentration;
        attribute timestamp : TimeSeconds;
    }

    item def LogRecord {
        attribute reading : ProcessedReading;
        attribute alarm : AlarmEvent;
        attribute recordedAt : TimeSeconds;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute power : Power;
    }

    // ===== Port Definitions =====
    port def RawReadingOut {
        out reading : RawSensorReading;
    }

    port def RawReadingIn {
        in reading : RawSensorReading;
    }

    port def ProcessedReadingOut {
        out reading : ProcessedReading;
    }

    port def ProcessedReadingIn {
        in reading : ProcessedReading;
    }

    port def AlarmEventOut {
        out event : AlarmEvent;
    }

    port def AlarmEventIn {
        in event : AlarmEvent;
    }

    port def LogRecordOut {
        out record : LogRecord;
    }

    port def LogRecordIn {
        in record : LogRecord;
    }

    port def PowerOut {
        out power : ElectricalPower;
    }

    port def PowerIn {
        in power : ElectricalPower;
    }

    // ===== Requirements =====
    requirement def DetectGasRequirement {
        subject detector : GasDetectorSystem;
        objective {
            attribute minConcentration : Concentration = 0 [ppm];
            attribute maxConcentration : Concentration = 500 [ppm];
            attribute responseTime : TimeSeconds = 30 [s];
        }
        requirement {
            subject = detector;
            require detector.sensor.measurementRange.min >= minConcentration
                and detector.sensor.measurementRange.max <= maxConcentration
                and detector.sensor.responseTime <= responseTime
        }
    }

    requirement def SignalProcessingRequirement {
        subject processor : SignalProcessor;
        objective {
            attribute plausibleMin : Concentration = 0 [ppm];
            attribute plausibleMax : Concentration = 500 [ppm];
        }
        requirement {
            subject = processor;
            require processor.validatesRange
                and processor.filtersNoise
                and processor.appliesCalibration
        }
    }

    requirement def AlarmThresholdRequirement {
        subject alarmUnit : AlarmUnit;
        objective {
            attribute warningThreshold : Concentration = 50 [ppm];
            attribute dangerThreshold : Concentration = 100 [ppm];
            attribute criticalThreshold : Concentration = 200 [ppm];
        }
        requirement {
            subject = alarmUnit;
            require alarmUnit.warningThreshold == warningThreshold
                and alarmUnit.dangerThreshold == dangerThreshold
                and alarmUnit.criticalThreshold == criticalThreshold
        }
    }

    requirement def DataLoggingRequirement {
        subject logger : DataLogger;
        objective {
            attribute maxRecords : Integer = 10000;
            attribute interval : TimeInterval = 1 [min];
        }
        requirement {
            subject = logger;
            require logger.capacity >= maxRecords
                and logger.loggingInterval == interval
        }
    }

    requirement def PowerSupplyRequirement {
        subject supply : PowerSupply;
        objective {
            attribute inputVoltage : Voltage = 24 [V];
            attribute outputVoltage : Voltage = 5 [V];
        }
        requirement {
            subject = supply;
            require supply.nominalInputVoltage == inputVoltage
                and supply.nominalOutputVoltage == outputVoltage
        }
    }

    requirement def LifecycleRequirement {
        subject detector : GasDetectorSystem;
        objective {
            attribute warningLevel : Concentration = 50 [ppm];
            attribute clearLevel : Concentration = 45 [ppm];
        }
        requirement {
            subject = detector;
            require detector.stateMachine.transitionsDefined
                and detector.clearThreshold == clearLevel
        }
    }

    // ===== Parts =====
    part def ElectrochemicalSensor {
        attribute measurementRange : Concentration[2] = (0 [ppm], 500 [ppm]);
        attribute responseTime : TimeSeconds = 30 [s];
        attribute sensorId : String = "EC-001";
        attribute calibrationOffset : Concentration = 0 [ppm];

        port rawOut : RawReadingOut;

        attribute currentReading : Concentration;

        action def senseGas :> Action {
            in ambientConcentration : Concentration;
            out reading : RawSensorReading;
        }

        perform action senseGasCycle {
            in ambientConcentration : Concentration = currentReading;
            out reading : RawSensorReading;
            then send rawOut.reading := reading;
        }
    }

    part def SignalProcessor {
        attribute plausibleMin : Concentration = 0 [ppm];
        attribute plausibleMax : Concentration = 500 [ppm];
        attribute noiseFilterEnabled : Boolean = true;
        attribute calibrationFactor : Real = 1.0;

        attribute validatesRange : Boolean = true;
        attribute filtersNoise : Boolean = true;
        attribute appliesCalibration : Boolean = true;

        port rawIn : RawReadingIn;
        port processedOut : ProcessedReadingOut;

        action def processReading :> Action {
            in raw : RawSensorReading;
            out processed : ProcessedReading;
        }

        perform action processingCycle {
            in raw : RawSensorReading = rawIn.reading;
            out processed : ProcessedReading;
            decide {
                if raw.value >= plausibleMin and raw.value <= plausibleMax
                then {
                    assign processed.value := raw.value * calibrationFactor;
                    assign processed.valid := true;
                    assign processed.calibrated := true;
                }
                else {
                    assign processed.value := raw.value;
                    assign processed.valid := false;
                    assign processed.calibrated := false;
                }
            }
            assign processed.timestamp := raw.timestamp;
            then send processedOut.reading := processed;
        }
    }

    part def AlarmUnit {
        attribute warningThreshold : Concentration = 50 [ppm];
        attribute dangerThreshold : Concentration = 100 [ppm];
        attribute criticalThreshold : Concentration = 200 [ppm];

        attribute visualAlertActive : Boolean = false;
        attribute audibleAlertActive : Boolean = false;
        attribute currentLevel : AlarmLevel = AlarmLevel::normal;

        port processedIn : ProcessedReadingIn;
        port alarmOut : AlarmEventOut;

        action def evaluateAlarm :> Action {
            in reading : ProcessedReading;
            out event : AlarmEvent;
        }

        perform action evaluationCycle {
            in reading : ProcessedReading = processedIn.reading;
            out event : AlarmEvent;
            decide {
                if reading.value >= criticalThreshold
                then {
                    assign currentLevel := AlarmLevel::critical;
                    assign visualAlertActive := true;
                    assign audibleAlertActive := true;
                }
                else if reading.value >= dangerThreshold
                then {
                    assign currentLevel := AlarmLevel::danger;
                    assign visualAlertActive := true;
                    assign audibleAlertActive := true;
                }
                else if reading.value >= warningThreshold
                then {
                    assign currentLevel := AlarmLevel::warning;
                    assign visualAlertActive := true;
                    assign audibleAlertActive := false;
                }
                else {
                    assign currentLevel := AlarmLevel::normal;
                    assign visualAlertActive := false;
                    assign audibleAlertActive := false;
                }
            }
            assign event.level := currentLevel;
            assign event.concentration := reading.value;
            assign event.timestamp := reading.timestamp;
            then send alarmOut.event := event;
        }
    }

    part def DataLogger {
        attribute capacity : Integer = 10000;
        attribute loggingInterval : TimeInterval = 1 [min];
        attribute recordCount : Integer = 0;
        attribute records : LogRecord[0..10000];

        port logIn : LogRecordIn;

        action def logRecord :> Action {
            in record : LogRecord;
        }

        perform action loggingCycle {
            in record : LogRecord = logIn.record;
            decide {
                if recordCount < capacity
                then {
                    assign records[recordCount] := record;
                    assign recordCount := recordCount + 1;
                }
            }
        }
    }

    part def PowerSupply {
        attribute nominalInputVoltage : Voltage = 24 [V];
        attribute nominalOutputVoltage : Voltage = 5 [V];
        attribute outputPower : Power = 10 [W];
        attribute efficiency : Real = 0.85;

        port powerIn : PowerIn;
        port powerOut : PowerOut;

        action def convertPower :> Action {
            in input : ElectricalPower;
            out output : ElectricalPower;
        }

        perform action conversionCycle {
            in input : ElectricalPower = powerIn.power;
            out output : ElectricalPower;
            assign output.voltage := nominalOutputVoltage;
            assign output.power := input.power * efficiency;
            then send powerOut.power := output;
        }
    }

    // ===== State Machine =====
    state def GasDetectorStateMachine {
        attribute clearThreshold : Concentration = 45 [ppm];
        attribute warningThreshold : Concentration = 50 [ppm];
        attribute currentConcentration : Concentration;
        attribute faultDetected : Boolean = false;
        attribute activeFault : FaultCode = FaultCode::none;

        entry; then initializing;

        state initializing {
            entry {
                perform selfTest;
            }
            do {
                send selfTestComplete;
            }
            transition to monitoring
                when selfTestComplete
                guard not faultDetected;
            transition to fault
                when selfTestComplete
                guard faultDetected;
        }

        state monitoring {
            do {
                monitorConcentration;
            }
            transition to alarming
                when currentConcentration >= warningThreshold
                guard not faultDetected;
            transition to fault
                when faultDetected;
        }

        state alarming {
            entry {
                activateAlarms;
            }
            do {
                maintainAlarms;
            }
            exit {
                deactivateAlarms;
            }
            transition to monitoring
                when currentConcentration < clearThreshold
                guard not faultDetected;
            transition to fault
                when faultDetected;
        }

        state fault {
            entry {
                indicateFault;
            }
            do {
                awaitMaintenance;
            }
            transition to initializing
                when maintenanceReset;
        }

        action def selfTest :> Action;
        action def monitorConcentration :> Action;
        action def activateAlarms :> Action;
        action def maintainAlarms :> Action;
        action def deactivateAlarms :> Action;
        action def indicateFault :> Action;
        action def awaitMaintenance :> Action;

        event selfTestComplete;
        event maintenanceReset;
    }

    // ===== Top-level System =====
    part def GasDetectorSystem {
        attribute clearThreshold : Concentration = 45 [ppm];
        attribute warningThreshold : Concentration = 50 [ppm];
        attribute dangerThreshold : Concentration = 100 [ppm];
        attribute criticalThreshold : Concentration = 200 [ppm];

        attribute stateMachine : GasDetectorStateMachine;

        part sensor : ElectrochemicalSensor {
            port rawOut : RawReadingOut;
        }

        part processor : SignalProcessor {
            port rawIn : RawReadingIn;
            port processedOut : ProcessedReadingOut;
        }

        part alarmUnit : AlarmUnit {
            port processedIn : ProcessedReadingIn;
            port alarmOut : AlarmEventOut;
        }

        part logger : DataLogger {
            port logIn : LogRecordIn;
        }

        part powerSupply : PowerSupply {
            port powerIn : PowerIn;
            port powerOut : PowerOut;
        }

        // Internal connections
        connection rawReadingFlow connect sensor.rawOut to processor.rawIn;
        connection processedReadingFlow connect processor.processedOut to alarmUnit.processedIn;
        connection alarmEventFlow connect alarmUnit.alarmOut to logger.logIn;

        // Power distribution
        connection supplyPower connect powerSupply.powerOut to sensor.powerIn;
        connection supplyPowerProcessor connect powerSupply.powerOut to processor.powerIn;
        connection supplyPowerAlarm connect powerSupply.powerOut to alarmUnit.powerIn;
        connection supplyPowerLogger connect powerSupply.powerOut to logger.powerIn;

        // Requirement satisfactions
        satisfy DetectGasRequirement {
            subject = self;
        }
        satisfy SignalProcessingRequirement {
            subject = processor;
        }
        satisfy AlarmThresholdRequirement {
            subject = alarmUnit;
        }
        satisfy DataLoggingRequirement {
            subject = logger;
        }
        satisfy PowerSupplyRequirement {
            subject = powerSupply;
        }
        satisfy LifecycleRequirement {
            subject = self;
        }
    }
}
