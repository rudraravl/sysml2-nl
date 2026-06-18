package LevelSensingUnitSpecification {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Length_m :> ScalarValues::Real {
        doc /* Vertical distance measured in metres. */
    }

    attribute def Time_s :> ScalarValues::Real {
        doc /* Time duration or timestamp in seconds. */
    }

    attribute def Voltage_V :> ScalarValues::Real {
        doc /* Electrical potential in volts. */
    }

    attribute def Current_A :> ScalarValues::Real {
        doc /* Electrical current in amperes. */
    }

    attribute def Power_W :> ScalarValues::Real {
        doc /* Electrical power in watts. */
    }

    attribute def Temperature_degC :> ScalarValues::Real {
        doc /* Temperature in degrees Celsius. */
    }

    attribute def Percent :> ScalarValues::Real {
        doc /* Dimensionless percentage value from 0 to 100. */
    }

    attribute def Frequency_Hz :> ScalarValues::Real {
        doc /* Sampling or signaling frequency in hertz. */
    }

    attribute def Resistance_ohm :> ScalarValues::Real {
        doc /* Electrical resistance in ohms. */
    }

    attribute def BooleanFlag :> ScalarValues::Boolean;

    enum def MeasurementQuality {
        enum valid;
        enum suspect;
        enum invalid;
        enum unavailable;
    }

    enum def UnitHealth {
        enum initializing;
        enum operational;
        enum degraded;
        enum faulted;
        enum maintenance;
        enum poweredOff;
    }

    enum def SensorTechnology {
        enum ultrasonic;
        enum radar;
        enum capacitive;
        enum hydrostaticPressure;
        enum floatSwitch;
    }

    enum def DiagnosticCode {
        enum noFault;
        enum noEcho;
        enum outOfRange;
        enum unstableSignal;
        enum temperatureCompensationFault;
        enum powerSupplyFault;
        enum communicationFault;
        enum calibrationExpired;
    }

    item def ElectricalPower {
        attribute voltage: Voltage_V;
        attribute current: Current_A;
        attribute availablePower: Power_W;
    }

    item def LevelEchoSignal {
        attribute echoAmplitude: Percent;
        attribute timeOfFlight: Time_s;
        attribute signalToNoiseRatio: Percent;
        attribute sensorTemperature: Temperature_degC;
    }

    item def LevelMeasurement {
        attribute level: Length_m;
        attribute fillPercent: Percent;
        attribute timestamp: Time_s;
        attribute quality: MeasurementQuality;
        attribute diagnostic: DiagnosticCode;
    }

    item def LevelCommand {
        attribute requestMeasurement: BooleanFlag;
        attribute requestCalibration: BooleanFlag;
        attribute resetFaults: BooleanFlag;
        attribute timestamp: Time_s;
    }

    item def HealthStatus {
        attribute health: UnitHealth;
        attribute diagnostic: DiagnosticCode;
        attribute lastValidLevel: Length_m;
        attribute uptime: Time_s;
    }

    item def ConfigurationData {
        attribute tankReferenceHeight: Length_m;
        attribute emptyLevelOffset: Length_m;
        attribute fullLevelHeight: Length_m;
        attribute lowLevelAlarmThreshold: Length_m;
        attribute highLevelAlarmThreshold: Length_m;
        attribute samplePeriod: Time_s;
        attribute filterTimeConstant: Time_s;
    }

    port def PowerInputPort {
        in item power: ElectricalPower;
    }

    port def LevelSignalPort {
        out item rawEcho: LevelEchoSignal;
    }

    port def MeasurementOutputPort {
        out item measurement: LevelMeasurement;
    }

    port def CommandInputPort {
        in item command: LevelCommand;
    }

    port def HealthOutputPort {
        out item status: HealthStatus;
    }

    port def ConfigurationPort {
        in item configuration: ConfigurationData;
    }

    port def InternalEchoPort {
        in item rawEcho: LevelEchoSignal;
    }

    port def InternalMeasurementPort {
        out item measurement: LevelMeasurement;
    }

    port def InternalHealthPort {
        out item status: HealthStatus;
    }

    action def AcquireEcho {
        in attribute trigger: BooleanFlag;
        in attribute ambientTemperature: Temperature_degC;
        out item echo: LevelEchoSignal;

        doc /* Emits an acoustic or electromagnetic pulse, receives the reflected echo from the fluid surface, and packages the raw echo information. */
    }

    action def CompensateEchoForTemperature {
        in item uncompensatedEcho: LevelEchoSignal;
        out item compensatedEcho: LevelEchoSignal;

        doc /* Applies temperature compensation to time-of-flight data to reduce level error due to propagation speed variation. */
    }

    action def ConvertEchoToLevel {
        in item echo: LevelEchoSignal;
        in item configuration: ConfigurationData;
        out item measurement: LevelMeasurement;

        doc /* Converts compensated time-of-flight or equivalent raw sensor signal into a level measurement referenced to the configured tank datum. */
    }

    action def FilterLevelMeasurement {
        in item unfilteredMeasurement: LevelMeasurement;
        in item configuration: ConfigurationData;
        out item filteredMeasurement: LevelMeasurement;

        doc /* Applies deterministic smoothing while preserving alarm response within configured performance limits. */
    }

    action def EvaluateDiagnostics {
        in item measurement: LevelMeasurement;
        in item echo: LevelEchoSignal;
        out item status: HealthStatus;

        doc /* Determines whether the level sensor and sensing unit are healthy, degraded, or faulted based on signal, range, and conversion checks. */
    }

    action def PublishLevelAndHealth {
        in item measurement: LevelMeasurement;
        in item status: HealthStatus;

        doc /* Publishes the validated level measurement and diagnostic status to external consumers. */
    }

    state def LevelSensorStateMachine {
        in item command: LevelCommand;
        in item configuration: ConfigurationData;
        out item measurement: LevelMeasurement;
        out item status: HealthStatus;

        state poweredOff {
            entry action {
                send HealthStatus {
                    health = UnitHealth::poweredOff;
                    diagnostic = DiagnosticCode::noFault;
                    lastValidLevel = 0.0;
                    uptime = 0.0;
                } via status;
            }
        }

        state initializing {
            entry action {
                send HealthStatus {
                    health = UnitHealth::initializing;
                    diagnostic = DiagnosticCode::noFault;
                    lastValidLevel = 0.0;
                    uptime = 0.0;
                } via status;
            }
        }

        state selfTest {
            entry action {
                doc /* Verifies power input, sensor electronics, transducer continuity, and stored calibration configuration. */
            }
        }

        state measuring {
            entry action AcquireEcho;
            do action CompensateEchoForTemperature;
            do action ConvertEchoToLevel;
            do action FilterLevelMeasurement;
            do action EvaluateDiagnostics;
            exit action PublishLevelAndHealth;
        }

        state degradedOperation {
            entry action {
                send HealthStatus {
                    health = UnitHealth::degraded;
                    diagnostic = DiagnosticCode::unstableSignal;
                    lastValidLevel = 0.0;
                    uptime = 0.0;
                } via status;
            }
        }

        state faulted {
            entry action {
                send HealthStatus {
                    health = UnitHealth::faulted;
                    diagnostic = DiagnosticCode::outOfRange;
                    lastValidLevel = 0.0;
                    uptime = 0.0;
                } via status;
            }
        }

        state calibration {
            entry action {
                doc /* Captures reference empty and full levels and updates calibration constants. */
            }
        }

        transition initial then poweredOff;

        transition powerApplied
            first poweredOff
            then initializing;

        transition initializationComplete
            first initializing
            then selfTest;

        transition selfTestPassed
            first selfTest
            then measuring;

        transition selfTestFailed
            first selfTest
            then faulted;

        transition measurementSuspect
            first measuring
            then degradedOperation;

        transition measurementRecovered
            first degradedOperation
            then measuring;

        transition unrecoverableFault
            first measuring
            then faulted;

        transition degradedFault
            first degradedOperation
            then faulted;

        transition resetFault
            first faulted
            then initializing;

        transition startCalibration
            first measuring
            then calibration;

        transition calibrationComplete
            first calibration
            then measuring;

        transition removePowerFromAnyState
            first initializing
            then poweredOff;

        transition removePowerFromSelfTest
            first selfTest
            then poweredOff;

        transition removePowerFromMeasuring
            first measuring
            then poweredOff;

        transition removePowerFromFaulted
            first faulted
            then poweredOff;
    }

    part def RegulatedPowerSupply {
        attribute nominalInputVoltage: Voltage_V = 24.0;
        attribute minimumInputVoltage: Voltage_V = 18.0;
        attribute maximumInputVoltage: Voltage_V = 32.0;
        attribute maximumPowerConsumption: Power_W = 3.5;

        port powerIn: PowerInputPort;
        port regulatedPowerOut: PowerInputPort;
    }

    part def LevelSensor {
        attribute technology: SensorTechnology = SensorTechnology::ultrasonic;
        attribute minimumMeasurableLevel: Length_m = 0.05;
        attribute maximumMeasurableLevel: Length_m = 4.50;
        attribute measurementResolution: Length_m = 0.001;
        attribute measurementAccuracy: Length_m = 0.010;
        attribute warmupTime: Time_s = 2.0;
        attribute sampleFrequency: Frequency_Hz = 2.0;
        attribute operatingTemperatureMinimum: Temperature_degC = -20.0;
        attribute operatingTemperatureMaximum: Temperature_degC = 70.0;

        port powerIn: PowerInputPort;
        port commandIn: CommandInputPort;
        port rawEchoOut: LevelSignalPort;

        perform action acquireEcho: AcquireEcho;
    }

    part def SignalConditioner {
        attribute inputImpedance: Resistance_ohm = 1000000.0;
        attribute maximumSignalLatency: Time_s = 0.050;
        attribute temperatureCompensationEnabled: BooleanFlag = true;

        port echoIn: InternalEchoPort;
        port conditionedEchoOut: LevelSignalPort;

        perform action compensateEcho: CompensateEchoForTemperature;
    }

    part def MeasurementProcessor {
        attribute samplePeriod: Time_s = 0.5;
        attribute filterTimeConstant: Time_s = 1.5;
        attribute processingLatency: Time_s = 0.100;
        attribute configuredTankReferenceHeight: Length_m = 5.00;
        attribute configuredEmptyOffset: Length_m = 0.00;
        attribute configuredFullHeight: Length_m = 4.50;
        attribute lowAlarmThreshold: Length_m = 0.25;
        attribute highAlarmThreshold: Length_m = 4.25;

        port echoIn: InternalEchoPort;
        port configurationIn: ConfigurationPort;
        port commandIn: CommandInputPort;
        port measurementOut: InternalMeasurementPort;
        port healthOut: InternalHealthPort;

        perform action convertEchoToLevel: ConvertEchoToLevel;
        perform action filterLevel: FilterLevelMeasurement;
        perform action evaluateDiagnostics: EvaluateDiagnostics;
    }

    part def CommunicationInterface {
        attribute updatePeriod: Time_s = 0.5;
        attribute maximumOutputLatency: Time_s = 0.200;

        port measurementIn: InternalMeasurementPort;
        port healthIn: InternalHealthPort;
        port measurementOut: MeasurementOutputPort;
        port healthOut: HealthOutputPort;
        port commandIn: CommandInputPort;
        port configurationIn: ConfigurationPort;

        perform action publish: PublishLevelAndHealth;
    }

    part def SensingUnit {
        attribute measuredQuantityName: String = "liquid level";
        attribute requiredMeasurementRangeMinimum: Length_m = 0.05;
        attribute requiredMeasurementRangeMaximum: Length_m = 4.50;
        attribute requiredAccuracy: Length_m = 0.020;
        attribute requiredResolution: Length_m = 0.005;
        attribute requiredUpdatePeriod: Time_s = 1.0;
        attribute nominalSupplyVoltage: Voltage_V = 24.0;
        attribute health: UnitHealth = UnitHealth::poweredOff;

        port powerIn: PowerInputPort;
        port commandIn: CommandInputPort;
        port configurationIn: ConfigurationPort;
        port levelOut: MeasurementOutputPort;
        port healthOut: HealthOutputPort;

        part supply: RegulatedPowerSupply;
        part sensor: LevelSensor;
        part conditioner: SignalConditioner;
        part processor: MeasurementProcessor;
        part interface: CommunicationInterface;

        connect powerIn to supply.powerIn;
        connect supply.regulatedPowerOut to sensor.powerIn;

        connect commandIn to sensor.commandIn;
        connect commandIn to processor.commandIn;
        connect commandIn to interface.commandIn;

        connect configurationIn to processor.configurationIn;
        connect configurationIn to interface.configurationIn;

        connect sensor.rawEchoOut to conditioner.echoIn;
        connect conditioner.conditionedEchoOut to processor.echoIn;

        connect processor.measurementOut to interface.measurementIn;
        connect processor.healthOut to interface.healthIn;

        connect interface.measurementOut to levelOut;
        connect interface.healthOut to healthOut;

        exhibit state lifecycle: LevelSensorStateMachine;
    }

    requirement def SenseLevelUsingLevelSensorRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall measure the relevant quantity, liquid level, using a Level sensor and shall provide a validated level measurement to external consumers. */

        require constraint {
            unit.sensor.technology == SensorTechnology::ultrasonic
        }

        require constraint {
            unit.requiredMeasurementRangeMinimum >= unit.sensor.minimumMeasurableLevel
        }

        require constraint {
            unit.requiredMeasurementRangeMaximum <= unit.sensor.maximumMeasurableLevel
        }

        require constraint {
            unit.sensor.measurementAccuracy <= unit.requiredAccuracy
        }

        require constraint {
            unit.sensor.measurementResolution <= unit.requiredResolution
        }

        require constraint {
            unit.processor.samplePeriod <= unit.requiredUpdatePeriod
        }
    }

    requirement def LevelMeasurementRangeRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall measure level from 0.05 m to 4.50 m relative to the tank datum. */

        require constraint {
            unit.requiredMeasurementRangeMinimum == 0.05
        }

        require constraint {
            unit.requiredMeasurementRangeMaximum == 4.50
        }
    }

    requirement def LevelMeasurementAccuracyRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall report level with total error not exceeding 0.020 m under normal operating conditions. */

        require constraint {
            unit.requiredAccuracy <= 0.020
        }

        require constraint {
            unit.sensor.measurementAccuracy <= 0.010
        }
    }

    requirement def MeasurementFreshnessRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall publish a new level measurement at least once every 1.0 s during operational measuring state. */

        require constraint {
            unit.requiredUpdatePeriod <= 1.0
        }

        require constraint {
            unit.processor.samplePeriod <= 0.5
        }

        require constraint {
            unit.interface.updatePeriod <= 0.5
        }
    }

    requirement def DiagnosticRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall output health status indicating operational, degraded, or faulted state with a diagnostic code. */

        require constraint {
            unit.interface.maximumOutputLatency <= 0.200
        }
    }

    requirement def PowerRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall operate from a nominal 24 V DC supply over an allowed input range of 18 V to 32 V and consume no more than 3.5 W. */

        require constraint {
            unit.supply.nominalInputVoltage == 24.0
        }

        require constraint {
            unit.supply.minimumInputVoltage <= 18.0
        }

        require constraint {
            unit.supply.maximumInputVoltage >= 32.0
        }

        require constraint {
            unit.supply.maximumPowerConsumption <= 3.5
        }
    }

    requirement def EnvironmentalRequirement {
        subject unit: SensingUnit;

        doc /* The sensing unit shall remain capable of level sensing over the sensor ambient temperature range from -20 degC to 70 degC. */

        require constraint {
            unit.sensor.operatingTemperatureMinimum <= -20.0
        }

        require constraint {
            unit.sensor.operatingTemperatureMaximum >= 70.0
        }
    }

    part sensingUnit: SensingUnit {
        attribute measuredQuantityName = "liquid level";
        attribute requiredMeasurementRangeMinimum = 0.05;
        attribute requiredMeasurementRangeMaximum = 4.50;
        attribute requiredAccuracy = 0.020;
        attribute requiredResolution = 0.005;
        attribute requiredUpdatePeriod = 1.0;
        attribute nominalSupplyVoltage = 24.0;

        part sensor {
            attribute technology = SensorTechnology::ultrasonic;
            attribute minimumMeasurableLevel = 0.05;
            attribute maximumMeasurableLevel = 4.50;
            attribute measurementResolution = 0.001;
            attribute measurementAccuracy = 0.010;
            attribute warmupTime = 2.0;
            attribute sampleFrequency = 2.0;
        }

        part processor {
            attribute samplePeriod = 0.5;
            attribute filterTimeConstant = 1.5;
            attribute configuredTankReferenceHeight = 5.00;
            attribute configuredEmptyOffset = 0.00;
            attribute configuredFullHeight = 4.50;
            attribute lowAlarmThreshold = 0.25;
            attribute highAlarmThreshold = 4.25;
        }
    }

    satisfy SenseLevelUsingLevelSensorRequirement by sensingUnit;
    satisfy LevelMeasurementRangeRequirement by sensingUnit;
    satisfy LevelMeasurementAccuracyRequirement by sensingUnit;
    satisfy MeasurementFreshnessRequirement by sensingUnit;
    satisfy DiagnosticRequirement by sensingUnit;
    satisfy PowerRequirement by sensingUnit;
    satisfy EnvironmentalRequirement by sensingUnit;
}
