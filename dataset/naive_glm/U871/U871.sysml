package TemperatureSensingUnit {
    import ScalarValues::*;

    // ===== Units =====
    unit Volt;
    unit Kelvin;
    unit Second;

    // ===== Value Types =====
    value def VoltageValue :> Real {
        :>> unit = Volt;
    }

    value def TemperatureValue :> Real {
        :>> unit = Kelvin;
    }

    value def TimeIntervalValue :> Real {
        :>> unit = Second;
    }

    // ===== Enumerations =====
    enum def ControllerState {
        INITIALIZING;
        READY;
        MEASURING;
        MAINTENANCE;
    }

    enum def SensorStatus {
        ACTIVE;
        INACTIVE;
        FAULTY;
    }

    // ===== Item Definitions =====
    item def SensorReading {
        attribute sensorId : String;
        attribute temperature : TemperatureValue;
        attribute status : SensorStatus;
        attribute timestamp : String;
    }

    item def AggregatedData {
        attribute averageTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        attribute activeSensorCount : Integer;
        attribute timestamp : String;
    }

    item def PowerOnSignal;
    item def MeasurementTriggerSignal;
    item def InitializationCompleteSignal;
    item def MeasurementCompleteSignal;
    item def MaintenanceRequestSignal;
    item def MaintenanceCompleteSignal;

    // ===== Port Definitions =====
    port def PowerOutPort {
        out voltage : VoltageValue;
    }

    port def PowerInPort {
        in voltage : VoltageValue;
    }

    port def SensorDataOutPort {
        out reading : SensorReading;
    }

    port def SensorDataInPort {
        in reading : SensorReading;
    }

    port def AggregatedDataOutPort {
        out data : AggregatedData;
    }

    port def AggregatedDataInPort {
        in data : AggregatedData;
    }

    port def TriggerOutPort {
        out trigger : MeasurementTriggerSignal;
    }

    port def TriggerInPort {
        in trigger : MeasurementTriggerSignal;
    }

    // ===== Part Definitions =====

    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 24 [Volt];
        attribute isPowered : Boolean = false;

        port powerOut : PowerOutPort;

        state powerState {
            entry; then Off;

            state Off {
                entry action { /* Power supply is off, no voltage output */ }
            }

            state On {
                entry action { /* Power supply is on, providing 24V output */ }
            }

            transition offToOn
                first Off
                accept PowerOnSignal
                then On;
        }
    }

    part def TemperatureSensor {
        attribute sensorId : String;
        attribute minRange : TemperatureValue = -40 [Kelvin];
        attribute maxRange : TemperatureValue = 125 [Kelvin];
        attribute calibrated : Boolean = false;
        attribute status : SensorStatus = SensorStatus::ACTIVE;

        port dataOut : SensorDataOutPort;
        port powerIn : PowerInPort;

        action def TakeMeasurement {
            out reading : SensorReading;

            action readTemperature {
                /* Read raw temperature value from sensor hardware */
            }

            action checkStatus {
                /* Verify sensor is active and not faulty before reporting */
            }

            action formatReading {
                /* Format result as SensorReading item with sensorId, temperature, status, timestamp */
            }

            first readTemperature then checkStatus then formatReading;
        }

        action def Calibrate {
            in referenceTemp : TemperatureValue;

            action applyCalibrationOffset {
                /* Apply calibration offset based on known reference temperature */
            }

            action markCalibrated {
                /* Set calibrated flag to true after successful calibration */
            }

            first applyCalibrationOffset then markCalibrated;
        }
    }

    part def DataAggregator {
        port sensorDataIn : SensorDataInPort[4];
        port aggregatedOut : AggregatedDataOutPort;
        port powerIn : PowerInPort;

        action def Aggregate {
            in readings : SensorReading[4];
            out result : AggregatedData;

            action filterActive {
                /* Filter out readings from sensors with status INACTIVE or FAULTY */
            }

            action computeAverage {
                /* Calculate average temperature across all active sensor readings */
            }

            action computeMin {
                /* Find minimum temperature among all active sensor readings */
            }

            action computeMax {
                /* Find maximum temperature among all active sensor readings */
            }

            action countActive {
                /* Count number of active sensors contributing to result */
            }

            action formatResult {
                /* Assemble AggregatedData item with average, min, max, count, and timestamp */
            }

            first filterActive
            then computeAverage
            then computeMin
            then computeMax
            then countActive
            then formatResult;
        }
    }

    part def SensingController {
        attribute measurementInterval : TimeIntervalValue = 0.5 [Second];
        attribute currentState : ControllerState = ControllerState::INITIALIZING;

        port triggerOut : TriggerOutPort;
        port dataIn : AggregatedDataInPort;
        port powerIn : PowerInPort;

        action def PerformMeasurementCycle {
            action sendTrigger {
                /* Send measurement trigger signal to sensor array */
            }

            action waitForAggregatedData {
                /* Wait for aggregated data from data aggregator */
            }

            action processData {
                /* Process, validate, and store consolidated measurement result */
            }

            first sendTrigger then waitForAggregatedData then processData;
        }

        action def InitializeSystem {
            action verifyPower {
                /* Verify power supply is operational and providing 24V */
            }

            action checkSensors {
                /* Poll each sensor in the array to verify connectivity and status */
            }

            action loadConfiguration {
                /* Load measurement interval, calibration data, and operational parameters */
            }

            first verifyPower then checkSensors then loadConfiguration;
        }

        action def EnterMaintenance {
            action disableScheduledMeasurements {
                /* Stop the periodic measurement trigger timer */
            }

            action enableCalibrationInterface {
                /* Enable individual sensor calibration commands */
            }

            first disableScheduledMeasurements then enableCalibrationInterface;
        }

        state controllerStateMachine {
            entry; then Initializing;

            state Initializing {
                entry action {
                    /* Set currentState to INITIALIZING and perform system initialization sequence */
                }
                do action initialize : InitializeSystem;
            }

            state Ready {
                entry action {
                    /* Set currentState to READY and arm measurement interval timer */
                }
                /* Controller stands by, waiting for next 0.5s measurement interval */
            }

            state Measuring {
                entry action {
                    /* Set currentState to MEASURING and execute measurement cycle */
                }
                do action measurementCycle : PerformMeasurementCycle;
            }

            state Maintenance {
                entry action {
                    /* Set currentState to MAINTENANCE and enter calibration mode */
                }
                do action enterMaintenance : EnterMaintenance;
            }

            transition initToReady
                first Initializing
                accept InitializationCompleteSignal
                then Ready;

            transition readyToMeasuring
                first Ready
                accept MeasurementTriggerSignal
                then Measuring;

            transition measuringToReady
                first Measuring
                accept MeasurementCompleteSignal
                then Ready;

            transition readyToMaintenance
                first Ready
                accept MaintenanceRequestSignal
                then Maintenance;

            transition maintenanceToReady
                first Maintenance
                accept MaintenanceCompleteSignal
                then Ready;
        }
    }

    part def SensorArray {
        attribute sensorCount : Integer = 4;

        part sensors : TemperatureSensor[4];

        port triggerIn : TriggerInPort;
        port dataOut : SensorDataOutPort[4];
        port powerIn : PowerInPort;

        action def TakeAllMeasurements {
            out readings : SensorReading[4];

            action triggerAllSensors {
                /* Trigger all four temperature sensors to take measurements simultaneously */
            }

            action collectAllReadings {
                /* Collect individual SensorReading items from all four sensors */
            }

            first triggerAllSensors then collectAllReadings;
        }
    }

    part def TemperatureSensingUnit {
        attribute unitId : String;
        attribute description : String = "Intelligent Temperature Sensing Unit";

        part powerSupply : PowerSupply;
        part controller : SensingController;
        part sensorArray : SensorArray;
        part aggregator : DataAggregator;

        // Power distribution from 24V power supply to all subsystems
        connection powerToController connect powerSupply.powerOut to controller.powerIn;
        connection powerToSensorArray connect powerSupply.powerOut to sensorArray.powerIn;
        connection powerToAggregator connect powerSupply.powerOut to aggregator.powerIn;

        // Controller triggers sensor array for measurements
        connection controllerToSensorArrayTrigger connect controller.triggerOut to sensorArray.triggerIn;

        // Raw sensor data flows from sensor array to aggregator
        connection sensorDataToAggregator connect sensorArray.dataOut to aggregator.sensorDataIn;

        // Aggregated data flows from aggregator to controller
        connection aggregatedDataToController connect aggregator.aggregatedOut to controller.dataIn;
    }

    // ===== Requirements =====

    requirement def TemperatureRangeRequirement {
        subject sensor : TemperatureSensor;
        requirement {
            sensor.minRange == -40 [Kelvin] and sensor.maxRange == 125 [Kelvin]
        }
    }

    requirement def RedundancyRequirement {
        subject array : SensorArray;
        requirement {
            array.sensorCount >= 4
        }
    }

    requirement def MeasurementIntervalRequirement {
        subject controller : SensingController;
        requirement {
            controller.measurementInterval == 0.5 [Second]
        }
    }

    requirement def PowerSupplyVoltageRequirement {
        subject psu : PowerSupply;
        requirement {
            psu.nominalVoltage == 24 [Volt]
        }
    }

    requirement def FaultToleranceRequirement {
        subject unit : TemperatureSensingUnit;
        doc /* The unit shall continue to provide valid consolidated temperature data when up to two of the four sensors are inactive or faulty. */;
    }

    requirement def AggregationRequirement {
        subject agg : DataAggregator;
        doc /* The data aggregator shall filter out readings from inactive or faulty sensors and compute the average, minimum, and maximum temperature across all active sensors in the array. */;
    }

    requirement def ControllerStatesRequirement {
        subject controller : SensingController;
        doc /* The sensing controller shall support four operational states: initializing on startup, ready standby, active measuring, and maintenance mode. */;
    }

    requirement def CalibrationRequirement {
        subject sensor : TemperatureSensor;
        doc /* Each individual temperature sensor shall be independently calibratable to maintain measurement accuracy over its operating range. */;
    }

    requirement def StandaloneOperationRequirement {
        subject unit : TemperatureSensingUnit;
        doc /* The unit shall be a self-contained, standalone device with integrated power supply, controller, and sensor array suitable for deployment in industrial or scientific settings. */;
    }
}
