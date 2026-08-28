package AutonomousStreamGauge {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQVolume::*;

    // ---------- Value Types with Units ----------
    value def Length_mm :> Real { unit 'mm'; }
    value def Velocity_mps :> Real { unit 'm/s'; }
    value def Temperature_C :> Real { unit '°C'; }
    value def FlowRate_m3ps :> Real { unit 'm³/s'; }
    value def Area_m2 :> Real { unit 'm²'; }
    value def Voltage_V :> Real { unit 'V'; }
    value def BatterySOC :> Real { unit '%'; }
    value def Power_W :> Real { unit 'W'; }
    value def TimeInterval_min :> Real { unit 'min'; }
    value def RecordCount :> Integer;

    // ---------- Item Definitions ----------
    item def RawSensorReading {
        attribute timestamp : TimeValue;
        attribute value : Real;
    }

    item def WaterLevelReading :> RawSensorReading {
        attribute level : Length_mm;
    }

    item def VelocityReading :> RawSensorReading {
        attribute velocity : Velocity_mps;
    }

    item def TemperatureReading :> RawSensorReading {
        attribute temperature : Temperature_C;
    }

    item def ChannelGeometry {
        attribute crossSectionalArea : Area_m2;
        attribute channelWidth : Length_mm;
        attribute channelSlope : Real;
        attribute roughnessCoefficient : Real;
    }

    item def ProcessedMeasurement {
        attribute timestamp : TimeValue;
        attribute waterLevel : Length_mm;
        attribute flowRate : FlowRate_m3ps;
        attribute temperature : Temperature_C;
    }

    item def TelemetryPacket {
        attribute sequenceId : Integer;
        attribute timestamp : TimeValue;
        attribute measurements : ProcessedMeasurement[0..*];
    }

    item def ConfigCommand {
        attribute commandId : String;
        attribute parameter : String;
        attribute value : String;
    }

    item def AlertMessage {
        attribute alertId : String;
        attribute timestamp : TimeValue;
        attribute alertLevel : AlertLevel;
        attribute waterLevel : Length_mm;
        attribute threshold : Length_mm;
        attribute stationId : String;
    }

    enum def AlertLevel {
        advisory;
        warning;
        critical;
    }

    item def PowerStatus {
        attribute batterySOC : BatterySOC;
        attribute solarOutput : Power_W;
        attribute loadPower : Power_W;
    }

    // ---------- Port Definitions ----------
    port def SensorOutputPort {
        out reading : RawSensorReading;
    }

    port def DataInputPort {
        in data : RawSensorReading;
    }

    port def ProcessedDataPort {
        out measurement : ProcessedMeasurement;
    }

    port def TelemetryPort {
        out packet : TelemetryPacket;
        out alert : AlertMessage;
        in command : ConfigCommand;
    }

    port def PowerPort {
        out voltage : Voltage_V;
        out power : Power_W;
    }

    port def ChannelConfigPort {
        in geometry : ChannelGeometry;
    }

    // ---------- Requirements ----------
    requirement def MeasurementAccuracy {
        subject sensor : Anything;
        attribute tolerance : Real;
        require sensor.accuracy <= tolerance;
    }

    requirement def WaterLevelMeasurement :> MeasurementAccuracy {
        subject ultrasonicSensor : Anything;
        attribute tolerance := 2.0; // mm
    }

    requirement def VelocityMeasurement :> MeasurementAccuracy {
        subject velocitySensor : Anything;
        attribute tolerance := 0.05; // m/s
    }

    requirement def TemperatureMeasurement :> MeasurementAccuracy {
        subject tempSensor : Anything;
        attribute tolerance := 0.5; // °C
    }

    requirement def DataStorageCapacity {
        subject dataLogger : Anything;
        attribute minRecords : RecordCount := 50000;
        require dataLogger.capacity >= minRecords;
    }

    requirement def TelemetryInterval {
        subject telemetryUnit : Anything;
        attribute maxInterval : TimeInterval_min := 15;
        require telemetryUnit.transmitInterval <= maxInterval;
    }

    requirement def AlertResponseTime {
        subject alertManager : Anything;
        attribute maxResponseTime : TimeInterval_min := 1;
        require alertManager.responseTime <= maxResponseTime;
    }

    requirement def PowerAutonomy {
        subject powerSystem : Anything;
        attribute minBatterySOC : BatterySOC := 30;
        require powerSystem.batterySOC >= minBatterySOC;
    }

    requirement def FloodThresholdConfig {
        subject alertManager : Anything;
        attribute advisoryLevel : Length_mm := 1500;
        attribute warningLevel : Length_mm := 2500;
        attribute criticalLevel : Length_mm := 3500;
    }

    // ---------- Part Definitions ----------

    part def UltrasonicLevelSensor {
        port levelOut : SensorOutputPort;
        attribute measurementRange : Length_mm := 10000;
        attribute accuracy : Length_mm := 2.0;
        attribute samplingInterval : TimeInterval_min := 5;

        action def takeReading {
            in currentLevel : Length_mm;
            out reading : WaterLevelReading;
        }

        perform takeReading every samplingInterval;
    }

    part def VelocitySensor {
        port velocityOut : SensorOutputPort;
        attribute measurementRange : Velocity_mps := 10.0;
        attribute accuracy : Velocity_mps := 0.05;
        attribute samplingInterval : TimeInterval_min := 5;

        action def measureVelocity {
            in currentVelocity : Velocity_mps;
            out reading : VelocityReading;
        }

        perform measureVelocity every samplingInterval;
    }

    part def TemperatureSensor {
        port tempOut : SensorOutputPort;
        attribute measurementRange : Temperature_C := 100.0;
        attribute accuracy : Temperature_C := 0.5;
        attribute samplingInterval : TimeInterval_min := 5;

        action def measureTemperature {
            in currentTemp : Temperature_C;
            out reading : TemperatureReading;
        }

        perform measureTemperature every samplingInterval;
    }

    part def DataProcessor {
        port levelIn : DataInputPort;
        port velocityIn : DataInputPort;
        port tempIn : DataInputPort;
        port configIn : ChannelConfigPort;
        port processedOut : ProcessedDataPort;

        attribute channelGeometry : ChannelGeometry;
        attribute lastMeasurement : ProcessedMeasurement;

        action def calculateFlowRate {
            in level : Length_mm;
            in velocity : Velocity_mps;
            in geometry : ChannelGeometry;
            out flowRate : FlowRate_m3ps;

            // Q = A * v, adjusted for actual wetted area based on level
            perform {
                attribute wettedArea : Area_m2 = geometry.crossSectionalArea * (level / geometry.channelWidth);
                flowRate = wettedArea * velocity;
            }
        }

        action def processReadings {
            in levelReading : WaterLevelReading;
            in velocityReading : VelocityReading;
            in tempReading : TemperatureReading;
            out measurement : ProcessedMeasurement;

            perform {
                attribute flowRate : FlowRate_m3ps;
                perform calculateFlowRate(levelReading.level, velocityReading.velocity, channelGeometry, flowRate);
                measurement.timestamp = levelReading.timestamp;
                measurement.waterLevel = levelReading.level;
                measurement.flowRate = flowRate;
                measurement.temperature = tempReading.temperature;
            }
        }

        state processingStateMachine {
            entry; then idle;
            state idle;
            state processing;
            state error;

            transition idle -> processing
                when levelIn.reading.isReceived();
            transition processing -> idle
                when processedOut.measurement.isSent();
            transition processing -> error
                when levelIn.reading.isInvalid() or velocityIn.reading.isInvalid();
            transition error -> idle
                when configIn.geometry.isReceived();
        }

        exhibit processingStateMachine;
    }

    part def DataLogger {
        port measurementIn : ProcessedDataPort;
        port measurementOut : ProcessedDataPort;

        attribute capacity : RecordCount := 50000;
        attribute storedRecords : ProcessedMeasurement[0..50000];
        attribute recordCount : RecordCount := 0;

        action def storeMeasurement {
            in measurement : ProcessedMeasurement;
            perform {
                if recordCount >= capacity then {
                    // overwrite oldest record (circular buffer)
                    storedRecords[0] = measurement;
                } else {
                    storedRecords[recordCount] = measurement;
                    recordCount = recordCount + 1;
                }
            }
        }

        action def retrieveMeasurements {
            out measurements : ProcessedMeasurement[0..*];
            perform {
                measurements = storedRecords;
            }
        }

        state loggerState {
            entry; then ready;
            state ready;
            state storing;
            state retrieving;

            transition ready -> storing
                when measurementIn.measurement.isReceived();
            transition storing -> ready
                when storeMeasurement.isDone();
            transition ready -> retrieving
                when measurementOut.measurement.isRequested();
            transition retrieving -> ready
                when retrieveMeasurements.isDone();
        }

        exhibit loggerState;
    }

    part def TelemetryUnit {
        port dataIn : ProcessedDataPort;
        port alertIn : ProcessedDataPort; // reused for alert pass-through
        port radioPort : TelemetryPort;

        attribute transmitInterval : TimeInterval_min := 15;
        attribute stationId : String := "SG-001";
        attribute sequenceCounter : Integer := 0;

        action def transmitData {
            in measurements : ProcessedMeasurement[0..*];
            out packet : TelemetryPacket;

            perform {
                sequenceCounter = sequenceCounter + 1;
                packet.sequenceId = sequenceCounter;
                packet.timestamp = now;
                packet.measurements = measurements;
            }
        }

        action def transmitAlert {
            in alert : AlertMessage;
            out transmittedAlert : AlertMessage;
            perform {
                transmittedAlert = alert;
            }
        }

        action def receiveCommand {
            in command : ConfigCommand;
            perform {
                // Process configuration command
            }
        }

        state telemetryState {
            entry; then standby;
            state standby;
            state transmitting;
            state receiving;

            transition standby -> transmitting
                when transmitInterval.elapsed() or alertIn.measurement.isReceived();
            transition transmitting -> standby
                when transmitData.isDone() and transmitAlert.isDone();
            transition standby -> receiving
                when radioPort.command.isReceived();
            transition receiving -> standby
                when receiveCommand.isDone();
        }

        exhibit telemetryState;
    }

    part def AlertManager {
        port measurementIn : ProcessedDataPort;
        port alertOut : ProcessedDataPort;

        attribute advisoryThreshold : Length_mm := 1500;
        attribute warningThreshold : Length_mm := 2500;
        attribute criticalThreshold : Length_mm := 3500;
        attribute currentAlertLevel : AlertLevel;
        attribute responseTime : TimeInterval_min := 1;

        action def evaluateThreshold {
            in waterLevel : Length_mm;
            out alert : AlertMessage;

            perform {
                if waterLevel >= criticalThreshold then {
                    alert.alertLevel = AlertLevel::critical;
                    alert.threshold = criticalThreshold;
                } else if waterLevel >= warningThreshold then {
                    alert.alertLevel = AlertLevel::warning;
                    alert.threshold = warningThreshold;
                } else if waterLevel >= advisoryThreshold then {
                    alert.alertLevel = AlertLevel::advisory;
                    alert.threshold = advisoryThreshold;
                } else {
                    alert = null;
                }
                alert.waterLevel = waterLevel;
                alert.timestamp = now;
                alert.alertId = "ALT-" + stationId;
            }
        }

        state alertState {
            entry; then monitoring;
            state monitoring;
            state alerting;
            state acknowledged;

            transition monitoring -> alerting
                when measurementIn.measurement.waterLevel >= advisoryThreshold;
            transition alerting -> monitoring
                when measurementIn.measurement.waterLevel < advisoryThreshold;
            transition alerting -> acknowledged
                when alertOut.measurement.isSent();
            transition acknowledged -> monitoring
                when measurementIn.measurement.waterLevel < advisoryThreshold;
        }

        exhibit alertState;
    }

    part def SolarPanel {
        port powerOut : PowerPort;
        attribute ratedPower : Power_W := 50.0;
        attribute currentOutput : Power_W;

        action def generatePower {
            in irradiance : Real;
            out power : Power_W;
            perform {
                power = ratedPower * irradiance;
            }
        }
    }

    part def Battery {
        port powerOut : PowerPort;
        port chargeIn : PowerPort;

        attribute capacity : Voltage_V := 12.0;
        attribute stateOfCharge : BatterySOC := 100;
        attribute maxCapacity : Power_W := 100.0;

        action def charge {
            in power : Power_W;
            perform {
                stateOfCharge = stateOfCharge + (power / maxCapacity) * 100;
                if stateOfCharge > 100 then stateOfCharge = 100;
            }
        }

        action def discharge {
            in power : Power_W;
            perform {
                stateOfCharge = stateOfCharge - (power / maxCapacity) * 100;
                if stateOfCharge < 0 then stateOfCharge = 0;
            }
        }

        state batteryState {
            entry; then charged;
            state charged;
            state charging;
            state discharging;
            state depleted;

            transition charged -> discharging
                when powerOut.power.isDrawn();
            transition discharging -> charging
                when chargeIn.power.isReceived();
            transition charging -> charged
                when stateOfCharge >= 100;
            transition discharging -> depleted
                when stateOfCharge <= 0;
            transition depleted -> charging
                when chargeIn.power.isReceived();
        }

        exhibit batteryState;
    }

    part def PowerManager {
        port solarIn : PowerPort;
        port batteryIn : PowerPort;
        port powerOut : PowerPort;

        attribute lowPowerThreshold : BatterySOC := 30;
        attribute currentMode : PowerMode;
        attribute batterySOC : BatterySOC;

        enum def PowerMode {
            normal;
            lowPower;
            emergency;
        }

        action def managePower {
            in solarPower : Power_W;
            in batteryLevel : BatterySOC;
            out outputPower : Power_W;
            out mode : PowerMode;

            perform {
                if batteryLevel <= lowPowerThreshold then {
                    mode = PowerMode::lowPower;
                    outputPower = solarPower * 0.5;
                } else if batteryLevel <= 10 then {
                    mode = PowerMode::emergency;
                    outputPower = solarPower * 0.2;
                } else {
                    mode = PowerMode::normal;
                    outputPower = solarPower;
                }
            }
        }

        state powerState {
            entry; then normal;
            state normal;
            state lowPower;
            state emergency;

            transition normal -> lowPower
                when batterySOC <= lowPowerThreshold;
            transition lowPower -> normal
                when batterySOC > lowPowerThreshold + 10;
            transition lowPower -> emergency
                when batterySOC <= 10;
            transition emergency -> lowPower
                when batterySOC > 15;
        }

        exhibit powerState;
    }

    // ---------- Top-Level System ----------
    part def StreamGaugeStation {
        attribute stationId : String := "SG-001";
        attribute location : String;
        attribute installationDate : Date;

        part ultrasonicSensor : UltrasonicLevelSensor {
            satisfy WaterLevelMeasurement;
        }
        part velocitySensor : VelocitySensor {
            satisfy VelocityMeasurement;
        }
        part temperatureSensor : TemperatureSensor {
            satisfy TemperatureMeasurement;
        }
        part dataProcessor : DataProcessor;
        part dataLogger : DataLogger {
            satisfy DataStorageCapacity;
        }
        part telemetryUnit : TelemetryUnit {
            satisfy TelemetryInterval;
        }
        part alertManager : AlertManager {
            satisfy AlertResponseTime;
            satisfy FloodThresholdConfig;
        }
        part solarPanel : SolarPanel;
        part battery : Battery;
        part powerManager : PowerManager {
            satisfy PowerAutonomy;
        }

        // Connections
        connect ultrasonicSensor.levelOut to dataProcessor.levelIn;
        connect velocitySensor.velocityOut to dataProcessor.velocityIn;
        connect temperatureSensor.tempOut to dataProcessor.tempIn;

        connect dataProcessor.processedOut to dataLogger.measurementIn;
        connect dataProcessor.processedOut to alertManager.measurementIn;

        connect dataLogger.measurementOut to telemetryUnit.dataIn;
        connect alertManager.alertOut to telemetryUnit.alertIn;

        connect solarPanel.powerOut to powerManager.solarIn;
        connect solarPanel.powerOut to battery.chargeIn;
        connect battery.powerOut to powerManager.batteryIn;
        connect powerManager.powerOut to dataProcessor;
        connect powerManager.powerOut to dataLogger;
        connect powerManager.powerOut to telemetryUnit;
        connect powerManager.powerOut to alertManager;
        connect powerManager.powerOut to ultrasonicSensor;
        connect powerManager.powerOut to velocitySensor;
        connect powerManager.powerOut to temperatureSensor;

        // System-level state machine
        state operationalState {
            entry; then initializing;
            state initializing {
                entry perform {
                    // Load channel geometry configuration
                    // Initialize all subsystems
                }
            }
            state normalOperation;
            state lowPowerOperation;
            state maintenanceMode;

            transition initializing -> normalOperation
                when dataProcessor.isReady() and telemetryUnit.isReady();
            transition normalOperation -> lowPowerOperation
                when powerManager.currentMode == PowerManager::PowerMode::lowPower;
            transition lowPowerOperation -> normalOperation
                when powerManager.currentMode == PowerManager::PowerMode::normal;
            transition normalOperation -> maintenanceMode
                when telemetryUnit.radioPort.command.isReceived() and telemetryUnit.radioPort.command.parameter == "maintenance";
            transition maintenanceMode -> normalOperation
                when telemetryUnit.radioPort.command.isReceived() and telemetryUnit.radioPort.command.parameter == "resume";
        }

        exhibit operationalState;
    }

    // ---------- Verification ----------
    verification WaterLevelAccuracyTest {
        subject sensor : UltrasonicLevelSensor;
        objective {
            doc verify that the ultrasonic sensor measures water level within specified tolerance
        }
        perform {
            attribute testLevel : Length_mm := 1000;
            attribute measuredLevel : Length_mm;
            attribute error : Length_mm = abs(measuredLevel - testLevel);
            assert error <= 2.0;
        }
    }

    verification FlowRateCalculationTest {
        subject processor : DataProcessor;
        objective {
            doc verify that flow rate is correctly calculated from level, velocity, and channel geometry
        }
        perform {
            attribute testLevel : Length_mm := 2000;
            attribute testVelocity : Velocity_mps := 1.5;
            attribute testArea : Area_m2 := 5.0;
            attribute expectedFlow : FlowRate_m3ps = testArea * testVelocity;
            attribute calculatedFlow : FlowRate_m3ps;
            assert abs(calculatedFlow - expectedFlow) < 0.1;
        }
    }

    verification AlertThresholdTest {
        subject manager : AlertManager;
        objective {
            doc verify that alerts are generated at correct threshold levels
        }
        perform {
            attribute testLevel : Length_mm := 2600;
            attribute generatedAlert : AlertMessage;
            assert generatedAlert.alertLevel == AlertLevel::warning;
        }
    }

    verification DataLoggerCapacityTest {
        subject logger : DataLogger;
        objective {
            doc verify that the data logger can store at least 50000 records
        }
        perform {
            assert logger.capacity >= 50000;
        }
    }

    verification TelemetryIntervalTest {
        subject telemetry : TelemetryUnit;
        objective {
            doc verify that telemetry transmits at least every 15 minutes
        }
        perform {
            assert telemetry.transmitInterval <= 15;
        }
    }

}
