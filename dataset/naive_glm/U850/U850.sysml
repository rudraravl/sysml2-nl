package RainSensingUnit {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---- Value types with units ----
    value def Capacitance :> Real { unit 'pF'; }
    value def Voltage :> Real { unit 'V'; }
    value def Temperature :> Real { unit 'degC'; }
    value def PrecipitationRate :> Real { unit 'mm/h'; }
    value def RainfallDepth :> Real { unit 'mm'; }
    value def Duration :> Real { unit 's'; }

    // ---- Item types ----
    item def RawCapacitanceSignal {
        attribute capacitance : Capacitance;
        attribute timestamp : DateTime;
    }

    item def ConditionedSignal {
        attribute voltage : Voltage;
        attribute timestamp : DateTime;
    }

    item def TemperatureReading {
        attribute temperature : Temperature;
        attribute timestamp : DateTime;
    }

    item def PrecipitationMeasurement {
        attribute rate : PrecipitationRate;
        attribute timestamp : DateTime;
    }

    item def AccumulatedRainfall {
        attribute totalDepth : RainfallDepth;
        attribute lastUpdated : DateTime;
    }

    item def OperationalStatus :> String;

    item def DataReport {
        attribute currentRate : PrecipitationRate;
        attribute totalDepth : RainfallDepth;
        attribute timestamp : DateTime;
        attribute status : OperationalStatus;
    }

    item def Command {
        attribute commandType : CommandType;
        attribute issuedAt : DateTime;
    }

    enum def CommandType {
        START_MEASUREMENT;
        STOP_MEASUREMENT;
        RESET_TOTAL;
        TRIGGER_CALIBRATION;
    }

    // ---- Port definitions ----
    port def CapacitanceOut { out item rawSignal : RawCapacitanceSignal; }
    port def ConditionedSignalOut { out item conditioned : ConditionedSignal; }
    port def TemperatureOut { out item tempReading : TemperatureReading; }
    port def RateOut { out item measurement : PrecipitationMeasurement; }
    port def AccumulatedOut { out item accumulated : AccumulatedRainfall; }
    port def ReportOut { out item report : DataReport; }
    port def CommandIn { in item command : Command; }

    // ---- Parts ----
    part def CapacitiveRainSensor {
        attribute operatingTempMin : Temperature = -40 [degC];
        attribute operatingTempMax : Temperature = 85 [degC];
        attribute responseTime : Duration = 10 [s];
        port capacitanceOut : CapacitanceOut;
        attribute currentCapacitance : Capacitance;
        action def detectRain() {
            in currentCapacitance : Capacitance;
            out signal : RawCapacitanceSignal;
        }
        action detectRain;
    }

    part def SignalConditioner {
        port signalIn : CapacitanceOut;
        port signalOut : ConditionedSignalOut;
        attribute gain : Real = 1.0;
        attribute filterCutoffHz : Real = 10.0;
        action def conditionSignal() {
            in raw : RawCapacitanceSignal;
            out conditioned : ConditionedSignal;
        }
        action conditionSignal;
    }

    part def TemperatureSensor {
        port tempOut : TemperatureOut;
        attribute operatingTempMin : Temperature = -40 [degC];
        attribute operatingTempMax : Temperature = 85 [degC];
        action def readTemperature() {
            out reading : TemperatureReading;
        }
        action readTemperature;
    }

    part def CalibrationProcessor {
        port conditionedIn : ConditionedSignalOut;
        port tempIn : TemperatureOut;
        port rateOut : RateOut;
        attribute calibrationFactor : Real = 1.0;
        attribute tempCompensationEnabled : Boolean = true;
        action def calibrateAndCompute() {
            in conditioned : ConditionedSignal;
            in temp : TemperatureReading;
            out measurement : PrecipitationMeasurement;
        }
        action calibrateAndCompute;
    }

    part def DataAccumulator {
        port rateIn : RateOut;
        port accumulatedOut : AccumulatedOut;
        attribute totalDepth : RainfallDepth = 0 [mm];
        action def accumulate() {
            in measurement : PrecipitationMeasurement;
            out accumulated : AccumulatedRainfall;
        }
        action accumulate;
        action def reset() {
            out accumulated : AccumulatedRainfall;
        }
        action reset;
    }

    part def ReportPackager {
        port rateIn : RateOut;
        port accumulatedIn : AccumulatedOut;
        port reportOut : ReportOut;
        attribute currentStatus : OperationalStatus;
        action def packageReport() {
            in measurement : PrecipitationMeasurement;
            in accumulated : AccumulatedRainfall;
            in status : OperationalStatus;
            out report : DataReport;
        }
        action packageReport;
    }

    part def ExternalSystem {
        port commandOut : CommandIn;
        port reportIn : ReportOut;
        action def issueCommand() {
            out command : Command;
        }
        action issueCommand;
        action def receiveReport() {
            in report : DataReport;
        }
        action receiveReport;
    }

    // ---- The rain sensing unit ----
    part def RainSensorUnit {
        port commandPort : CommandIn;
        port reportPort : ReportOut;
        attribute operatingTempMin : Temperature = -40 [degC];
        attribute operatingTempMax : Temperature = 85 [degC];
        attribute maxResponseTime : Duration = 10 [s];

        part rainSensor : CapacitiveRainSensor;
        part conditioner : SignalConditioner;
        part tempSensor : TemperatureSensor;
        part processor : CalibrationProcessor;
        part accumulator : DataAccumulator;
        part packager : ReportPackager;

        connection rainSensorToConditioner connect rainSensor.capacitanceOut to conditioner.signalIn;
        connection tempSensorToProcessor connect tempSensor.tempOut to processor.tempIn;
        connection conditionerToProcessor connect conditioner.signalOut to processor.conditionedIn;
        connection processorToAccumulator connect processor.rateOut to accumulator.rateIn;
        connection processorToPackager connect processor.rateOut to packager.rateIn;
        connection accumulatorToPackager connect accumulator.accumulatedOut to packager.accumulatedIn;
        connection packagerToPort connect packager.reportOut to reportPort;

        state def UnitStateMachine {
            entry; then Off;
            state Off;
            state Standby;
            state Measuring;
            state Calibrating;

            transition offToStandby first Off if commandPort.command.commandType == CommandType::START_MEASUREMENT then Standby;
            transition standbyToMeasuring from Standby if commandPort.command.commandType == CommandType::START_MEASUREMENT then Measuring;
            transition measuringToStandby from Measuring if commandPort.command.commandType == CommandType::STOP_MEASUREMENT then Standby;
            transition anyToCalibrating from Standby, Measuring if commandPort.command.commandType == CommandType::TRIGGER_CALIBRATION then Calibrating;
            transition calibratingToStandby from Calibrating if true then Standby;
            transition measuringReset from Measuring if commandPort.command.commandType == CommandType::RESET_TOTAL then Measuring;
            transition standbyReset from Standby if commandPort.command.commandType == CommandType::RESET_TOTAL then Standby;
            transition anyToOff from Standby, Measuring, Calibrating if false then Off;
        }

        state machine :>> UnitStateMachine;
    }

    // ---- Requirements ----
    requirement def RainDetectionRequirement {
        doc "The unit shall detect the presence of raindrops on the sensing surface by measuring a change in electrical capacitance."
        subject rainSensor : CapacitiveRainSensor;
        objective {
            doc "Detect rainfall via capacitance change."
        }
    }

    requirement def SignalConditioningRequirement {
        doc "The signal conditioner shall filter noise and amplify the raw capacitance signal."
        subject conditioner : SignalConditioner;
        objective {
            doc "Produce a reliable conditioned signal."
        }
    }

    requirement def RateCalculationRequirement {
        doc "The calibration processor shall convert the conditioned signal into a precipitation rate in mm/h."
        subject processor : CalibrationProcessor;
        objective {
            doc "Calculate instantaneous precipitation rate."
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc "The calibration processor shall use an internal temperature sensor to compensate for temperature effects on readings."
        subject processor : CalibrationProcessor;
        objective {
            doc "Maintain accuracy across varying weather conditions."
        }
    }

    requirement def AccumulationRequirement {
        doc "The data accumulator shall integrate the precipitation rate over time to determine total accumulated rainfall depth."
        subject accumulator : DataAccumulator;
        objective {
            doc "Provide running total of accumulated rainfall depth."
        }
    }

    requirement def ReportingRequirement {
        doc "The unit shall package current rate, total depth, timestamp, and operational status into a data report sent to an external system."
        subject packager : ReportPackager;
        objective {
            doc "Deliver complete data report to external system."
        }
    }

    requirement def StateMachineRequirement {
        doc "The unit shall operate through states: powered off, standby, measuring, and calibration."
        subject unit : RainSensorUnit;
        objective {
            doc "Support commanded state transitions."
        }
    }

    requirement def CommandInterfaceRequirement {
        doc "The unit shall accept external commands to start/stop measurements, reset accumulated total, or trigger calibration."
        subject unit : RainSensorUnit;
        objective {
            doc "Respond to external control commands."
        }
    }

    requirement def OperatingTemperatureRequirement {
        doc "The unit shall operate over a temperature range of -40 degC to +85 degC."
        subject unit : RainSensorUnit;
        constraint { unit.operatingTempMin == -40 [degC] and unit.operatingTempMax == 85 [degC] }
    }

    requirement def ResponseTimeRequirement {
        doc "The unit shall provide accurate precipitation measurements within 10 seconds of rainfall starting."
        subject unit : RainSensorUnit;
        constraint { unit.maxResponseTime <= 10 [s] }
    }

    requirement package RainSensingRequirements {
        requirement rainDetection : RainDetectionRequirement;
        requirement signalConditioning : SignalConditioningRequirement;
        requirement rateCalculation : RateCalculationRequirement;
        requirement tempCompensation : TemperatureCompensationRequirement;
        requirement accumulation : AccumulationRequirement;
        requirement reporting : ReportingRequirement;
        requirement stateMachine : StateMachineRequirement;
        requirement commandInterface : CommandInterfaceRequirement;
        requirement operatingTemp : OperatingTemperatureRequirement;
        requirement responseTime : ResponseTimeRequirement;
    }

    // ---- Top-level assembly ----
    part def RainSensingSystem {
        part unit : RainSensorUnit;
        part external : ExternalSystem;

        connection commandLink connect external.commandOut to unit.commandPort;
        connection reportLink connect unit.reportPort to external.reportIn;

        satisfy RainSensingRequirements::rainDetection by unit.rainSensor;
        satisfy RainSensingRequirements::signalConditioning by unit.conditioner;
        satisfy RainSensingRequirements::rateCalculation by unit.processor;
        satisfy RainSensingRequirements::tempCompensation by unit.processor;
        satisfy RainSensingRequirements::accumulation by unit.accumulator;
        satisfy RainSensingRequirements::reporting by unit.packager;
        satisfy RainSensingRequirements::stateMachine by unit;
        satisfy RainSensingRequirements::commandInterface by unit;
        satisfy RainSensingRequirements::operatingTemp by unit;
        satisfy RainSensingRequirements::responseTime by unit;
    }
}
