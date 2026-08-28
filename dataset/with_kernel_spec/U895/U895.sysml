package AutonomousStreamGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def AlertLevelKind {
        none;
        advisory;
        warning;
        critical;
    }

    enum def PowerModeKind {
        normal;
        lowPower;
    }

    enum def CommandKind {
        setInterval;
        setThresholds;
        reset;
    }

    item def ChannelGeometry {
        attribute crossSectionArea : Real = 0.0 [m^2];
        attribute roughnessCoefficient : Real;
    }

    item def ProcessedData {
        attribute timestamp : Real = 0.0 [s];
        attribute waterLevel : Real = 0.0 [m];
        attribute waterVelocity : Real = 0.0 [m/s];
        attribute waterTemperature : Real = 0.0 [degC];
        attribute discharge : Real = 0.0 [m^3/s];
    }

    item def AlertMessage {
        attribute level : AlertLevelKind;
        attribute waterLevel : Real = 0.0 [m];
        attribute timestamp : Real = 0.0 [s];
    }

    item def ConfigurationCommand {
        attribute commandType : CommandKind;
        attribute updateInterval : Real = 15.0 [min];
    }

    port def LevelPort {
        out level : Real;
    }
    port def VelocityPort {
        out velocity : Real;
    }
    port def TempPort {
        out temperature : Real;
    }
    port def DataPort {
        out data : ProcessedData;
    }
    port def AlertPort {
        out alert : AlertMessage;
    }
    port def TelemetryPort {
        out data : ProcessedData;
        out alert : AlertMessage;
        in command : ConfigurationCommand;
    }
    port def PowerPort {
        out power : Real;
    }

    part def UltrasonicSensor {
        port levelOut : LevelPort;
        port powerIn : ~PowerPort;
        attribute precision : Real = 0.001 [m];
        perform action measureLevel {
            out attribute level : Real;
            first start;
            then action emitPulse;
            then action receiveEcho;
            then action calculateDistance;
            then done;
        }
    }

    part def VelocitySensor {
        port velocityOut : VelocityPort;
        port powerIn : ~PowerPort;
        perform action measureVelocity {
            out attribute velocity : Real;
            first start;
            then action sampleFlow;
            then action computeSpeed;
            then done;
        }
    }

    part def TemperatureSensor {
        port tempOut : TempPort;
        port powerIn : ~PowerPort;
        perform action measureTemp {
            out attribute temperature : Real;
            first start;
            then action sampleMedium;
            then action convertToCelsius;
            then done;
        }
    }

    part def DataProcessor {
        port levelIn : ~LevelPort;
        port velocityIn : ~VelocityPort;
        port tempIn : ~TempPort;
        port dataOut : DataPort;
        port powerIn : ~PowerPort;
        attribute channelGeometry : ChannelGeometry;
        perform action calculateDischarge {
            in level : Real;
            in velocity : Real;
            in temperature : Real;
            in geometry : ChannelGeometry;
            out data : ProcessedData;
            first start;
            then action computeCrossSection;
            then action multiplyByVelocity;
            then action assembleRecord;
            then done;
        }
    }

    part def DataLogger {
        port dataIn : ~DataPort;
        port powerIn : ~PowerPort;
        attribute storageCapacity : Integer = 50000;
        attribute recordCount : Integer = 0;
        perform action storeRecord {
            in data : ProcessedData;
            first start;
            then action formatRecord;
            then action writeToMemory;
            then done;
        }
    }

    part def AlertManager {
        port levelIn : ~LevelPort;
        port alertOut : AlertPort;
        port powerIn : ~PowerPort;
        attribute advisoryThreshold : Real = 1.5 [m];
        attribute warningThreshold : Real = 2.5 [m];
        attribute criticalThreshold : Real = 3.5 [m];
        perform action checkThresholds {
            in level : Real;
            in advisory : Real;
            in warning : Real;
            in critical : Real;
            out alert : AlertMessage;
            first start;
            then action compareLevel;
            then action generateAlert;
            then done;
        }
    }

    part def TelemetryUnit {
        port dataIn : ~DataPort;
        port alertIn : ~AlertPort;
        port commPort : TelemetryPort;
        port powerIn : ~PowerPort;
        attribute transmissionInterval : Real = 15.0 [min];
        perform action transmitData {
            in data : ProcessedData;
            in alert : AlertMessage;
            first start;
            then action packagePayload;
            then action sendToRemoteCenter;
            then done;
        }
        perform action receiveCommand {
            in command : ConfigurationCommand;
            first start;
            then action parseCommand;
            then action applyConfiguration;
            then done;
        }
    }

    part def SolarPanel {
        port powerOut : PowerPort;
        perform action harvestEnergy {
            out attribute power : Real;
            first start;
            then action convertSunlight;
            then done;
        }
    }

    part def BackupBattery {
        port powerOut : PowerPort;
        port chargingIn : ~PowerPort;
        attribute capacity : Real = 1000.0 [W*h];
        attribute stateOfCharge : Real = 80.0;
        perform action charge {
            in power : Real;
            first start;
            then action storeEnergy;
            then done;
        }
        perform action discharge {
            out power : Real;
            first start;
            then action releaseEnergy;
            then done;
        }
    }

    part def PowerManagementModule {
        port solarIn : ~PowerPort;
        port batteryPowerIn : ~PowerPort;
        port powerOut : PowerPort;
        attribute currentMode : PowerModeKind = PowerModeKind::normal;
        attribute batteryChargeLevel : Real = 0.8;

        state machine PowerStateMachine {
            state normalOperation;
            state lowPowerMode;
            transition from normalOperation to lowPowerMode when (batteryChargeLevel < 0.2);
            transition from lowPowerMode to normalOperation when (batteryChargeLevel > 0.5);
        }

        perform action managePower {
            in solarPower : Real;
            in batteryPower : Real;
            out systemPower : Real;
            first start;
            then action evaluateSupply;
            then action distributePower;
            then done;
        }
    }

    part def RemoteMonitoringCenter {
        port commPort : ~TelemetryPort;
        perform action receiveData {
            in data : ProcessedData;
            in alert : AlertMessage;
            out command : ConfigurationCommand;
            first start;
            then action processData;
            then action evaluateAlerts;
            then done;
        }
    }

    part def StreamGaugeStation {
        doc /* An autonomous stream gauge station for continuous hydrological monitoring,
               flood forecasting, water resource management, and environmental monitoring. */

        part ultrasonicSensor : UltrasonicSensor;
        part velocitySensor : VelocitySensor;
        part temperatureSensor : TemperatureSensor;
        part dataProcessor : DataProcessor;
        part dataLogger : DataLogger;
        part alertManager : AlertManager;
        part telemetryUnit : TelemetryUnit;
        part solarPanel : SolarPanel;
        part backupBattery : BackupBattery;
        part powerManagement : PowerManagementModule;

        connect ultrasonicSensor.levelOut to dataProcessor.levelIn;
        connect velocitySensor.velocityOut to dataProcessor.velocityIn;
        connect temperatureSensor.tempOut to dataProcessor.tempIn;
        connect ultrasonicSensor.levelOut to alertManager.levelIn;
        connect dataProcessor.dataOut to dataLogger.dataIn;
        connect dataProcessor.dataOut to telemetryUnit.dataIn;
        connect alertManager.alertOut to telemetryUnit.alertIn;
        connect solarPanel.powerOut to powerManagement.solarIn;
        connect solarPanel.powerOut to backupBattery.chargingIn;
        connect backupBattery.powerOut to powerManagement.batteryPowerIn;
        connect powerManagement.powerOut to dataProcessor.powerIn;
        connect powerManagement.powerOut to dataLogger.powerIn;
        connect powerManagement.powerOut to alertManager.powerIn;
        connect powerManagement.powerOut to telemetryUnit.powerIn;
        connect powerManagement.powerOut to ultrasonicSensor.powerIn;
        connect powerManagement.powerOut to velocitySensor.powerIn;
        connect powerManagement.powerOut to temperatureSensor.powerIn;
    }

    part streamGaugeStation : StreamGaugeStation;
    part remoteCenter : RemoteMonitoringCenter;

    connect streamGaugeStation.telemetryUnit.commPort to remoteCenter.commPort;

    requirement def ContinuousMonitoringRequirement {
        doc /* The system shall continuously measure water level, water velocity,
               and water temperature using its integrated sensor suite. */
    }

    requirement def DischargeComputationRequirement {
        doc /* The system shall compute river flow rate (discharge) from sensor
               measurements and pre-configured river channel geometry. */
    }

    requirement def DataLoggingRequirement {
        doc /* The system shall store at least 50,000 measurement records locally
               to ensure no data is lost during communication interruptions. */
    }

    requirement def TelemetryIntervalRequirement {
        doc /* The system shall transmit collected and processed data to a remote
               monitoring center every 15 minutes. */
    }

    requirement def AlertingRequirement {
        doc /* The system shall generate and transmit alerts when water level exceeds
               predefined advisory, warning, or critical flood thresholds. */
    }

    requirement def AutonomousPowerRequirement {
        doc /* The system shall operate autonomously using solar power and a backup
               battery, switching to low-power mode to extend operation during periods
               of insufficient solar input. */
    }

    requirement def RemoteConfigurationRequirement {
        doc /* The system shall accept and process configuration commands received
               from the remote monitoring center. */
    }

    satisfy satisfyMonitoring from streamGaugeStation to ContinuousMonitoringRequirement;
    satisfy satisfyDischarge from streamGaugeStation.dataProcessor to DischargeComputationRequirement;
    satisfy satisfyLogging from streamGaugeStation.dataLogger to DataLoggingRequirement;
    satisfy satisfyTelemetry from streamGaugeStation.telemetryUnit to TelemetryIntervalRequirement;
    satisfy satisfyAlerting from streamGaugeStation.alertManager to AlertingRequirement;
    satisfy satisfyPower from streamGaugeStation.powerManagement to AutonomousPowerRequirement;
    satisfy satisfyConfig from streamGaugeStation.telemetryUnit to RemoteConfigurationRequirement;
}
