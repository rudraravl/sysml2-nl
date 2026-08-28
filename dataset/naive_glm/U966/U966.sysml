package AirPollutionMonitoringAndControlSystem {

    import ScalarValues::*;

    // ===== Value Types =====

    value type MassConcentration > Real {
        unit "ug/m3";
    }

    value type VolumeConcentration > Real {
        unit "ppm";
    }

    value type AQIValue > Integer {
        unit "index";
    }

    value type AirflowRate > Real {
        unit "m3/h";
    }

    value type Efficiency > Real {
        unit "%";
    }

    value type TimeValue > Real {
        unit "s";
    }

    value type DataRate > Real {
        unit "Mbps";
    }

    // ===== Enumerations =====

    enum PollutantType {
        PM25;
        PM10;
        O3;
        NO2;
        CO;
        SO2;
    }

    enum AQICategory {
        Good;
        Moderate;
        UnhealthyForSensitiveGroups;
        Unhealthy;
        VeryUnhealthy;
        Hazardous;
    }

    enum AlertSeverity {
        Info;
        Warning;
        Severe;
        Emergency;
    }

    enum FiltrationMode {
        standby;
        active;
        highEfficiency;
    }

    // ===== Item Definitions =====

    item def PollutantReading {
        attribute pollutant: PollutantType;
        attribute concentration: MassConcentration;
        attribute timestamp: String;
        attribute locationId: String;
    }

    item def SensorData {
        attribute readings: PollutantReading[1..*];
        attribute timestamp: String;
        attribute locationId: String;
    }

    item def AQIResult {
        attribute aqiValue: AQIValue;
        attribute category: AQICategory;
        attribute dominantPollutant: PollutantType;
        attribute timestamp: String;
        attribute locationId: String;
    }

    item def AlertNotification {
        attribute severity: AlertSeverity;
        attribute pollutantType: PollutantType;
        attribute healthActions: String;
        attribute aqiValue: AQIValue;
        attribute timestamp: String;
        attribute locationId: String;
    }

    item def FiltrationCommand {
        attribute mode: FiltrationMode;
        attribute requiredAirflow: AirflowRate;
        attribute efficiencyLevel: Efficiency;
        attribute timestamp: String;
    }

    item def DisplayMessage {
        attribute aqiValue: AQIValue;
        attribute category: AQICategory;
        attribute dominantPollutant: PollutantType;
        attribute alert: AlertNotification;
        attribute timestamp: String;
    }

    // ===== Port Definitions =====

    port def SensorDataOutPort {
        out sensorData: SensorData;
    }

    port def SensorDataInPort {
        in sensorData: SensorData;
    }

    port def AQIOutPort {
        out aqiResult: AQIResult;
    }

    port def AQIInPort {
        in aqiResult: AQIResult;
    }

    port def AlertOutPort {
        out alert: AlertNotification;
    }

    port def AlertInPort {
        in alert: AlertNotification;
    }

    port def CommandOutPort {
        out command: FiltrationCommand;
    }

    port def CommandInPort {
        in command: FiltrationCommand;
    }

    port def DisplayOutPort {
        out message: DisplayMessage;
    }

    // ===== Connection Definitions =====

    connection def SensorDataLink {
        end source: SensorDataOutPort;
        end target: SensorDataInPort;
        flow sensorData: SensorData;
    }

    connection def AQILink {
        end source: AQIOutPort;
        end target: AQIInPort;
        flow aqiResult: AQIResult;
    }

    connection def AlertLink {
        end source: AlertOutPort;
        end target: AlertInPort;
        flow alert: AlertNotification;
    }

    connection def CommandLink {
        end source: CommandOutPort;
        end target: CommandInPort;
        flow command: FiltrationCommand;
    }

    // ===== Part Definitions =====

    part def MultiPollutantSensor {
        port sensorOut: SensorDataOutPort;

        attribute samplingInterval: TimeValue = 60;
        attribute locationId: String = "District-1";
        attribute pm25Range: MassConcentration = 500;
        attribute pm10Range: MassConcentration = 600;
        attribute o3Range: VolumeConcentration = 0.5;
        attribute no2Range: VolumeConcentration = 2.0;
        attribute coRange: VolumeConcentration = 50.0;
        attribute so2Range: VolumeConcentration = 1.0;

        action def measurePollutants {
            out pm25Reading: PollutantReading;
            out pm10Reading: PollutantReading;
            out o3Reading: PollutantReading;
            out no2Reading: PollutantReading;
            out coReading: PollutantReading;
            out so2Reading: PollutantReading;
        }

        action def assembleSensorData {
            in readings: PollutantReading[6];
            out data: SensorData;
        }

        do {
            // Continuously sample air pollutants at the configured sampling interval
            // Assemble all pollutant readings into SensorData with timestamp and location
            // Emit SensorData through sensorOut port
        }
    }

    part def DataArchiveSystem {
        port archiveIn: SensorDataInPort;

        attribute storageCapacity: Real = 1000;
        attribute retentionPeriodDays: Integer = 365;
        attribute compressionEnabled: Boolean = true;

        action def storeData {
            in data: SensorData;
        }

        action def retrieveHistoricalData {
            in startDate: String;
            in endDate: String;
            in locationId: String;
            out records: SensorData[0..*];
        }

        do {
            // Receive sensor data from archiveIn port
            // Persist data with timestamp indexing for long-term storage
            // Support historical analysis and regulatory compliance queries
        }
    }

    part def AirQualityAnalyzer {
        port analyzerIn: SensorDataInPort;
        port analyzerOut: AQIOutPort;

        attribute calculationInterval: TimeValue = 60;
        attribute pm25Breakpoints: Real[4] = (0, 12.0, 35.5, 55.5);
        attribute pm10Breakpoints: Real[4] = (0, 54.0, 154.0, 254.0);
        attribute o3Breakpoints: Real[4] = (0, 0.054, 0.070, 0.085);
        attribute no2Breakpoints: Real[4] = (0, 53.0, 100.0, 360.0);
        attribute coBreakpoints: Real[4] = (0, 4.4, 9.4, 12.4);
        attribute so2Breakpoints: Real[4] = (0, 35.0, 75.0, 185.0);

        action def calculateSubIndex {
            in pollutant: PollutantType;
            in concentration: MassConcentration;
            out subIndex: AQIValue;
        }

        action def calculateAQI {
            in sensorData: SensorData;
            out aqiResult: AQIResult;
        }

        action def determineCategory {
            in aqiValue: AQIValue;
            out category: AQICategory;
        }

        do {
            // Receive raw sensor data from analyzerIn port
            // Calculate individual pollutant sub-indices using breakpoint tables
            // Determine overall AQI as the maximum sub-index
            // Identify the dominant pollutant contributing to the AQI
            // Assign AQI category based on the AQI value
            // Emit AQIResult through analyzerOut port
        }
    }

    part def PublicInformationDisplay {
        port displayAQIIn: AQIInPort;
        port displayAlertIn: AlertInPort;

        attribute refreshInterval: TimeValue = 30;
        attribute displayType: String = "DigitalBillboard";
        attribute url: String = "https://airquality.city.gov";

        action def showAQI {
            in aqi: AQIResult;
        }

        action def showAlert {
            in alert: AlertNotification;
        }

        action def updateDisplay {
            in aqi: AQIResult;
            in alert: AlertNotification;
        }

        do {
            // Continuously receive AQI results and alerts
            // Display current AQI value, category, and dominant pollutant
            // Display active alerts with severity, pollutant type, and health actions
            // Refresh display at configured interval
        }
    }

    part def AlertManagementSystem {
        port alertAQIIn: AQIInPort;
        port alertOut: AlertOutPort;

        attribute alertThreshold: AQIValue = 101;
        attribute severeThreshold: AQIValue = 151;
        attribute emergencyThreshold: AQIValue = 201;
        attribute hazardousThreshold: AQIValue = 301;

        action def generateAlert {
            in aqi: AQIResult;
            out alert: AlertNotification;
        }

        action def determineSeverity {
            in aqiValue: AQIValue;
            out severity: AlertSeverity;
        }

        action def composeHealthActions {
            in severity: AlertSeverity;
            in pollutant: PollutantType;
            out actions: String;
        }

        state {
            entry;
            state Monitoring;
            state AlertActive;
            state EmergencyActive;

            transition Init_to_Monitoring
                first entry
                then Monitoring;

            transition Monitoring_to_AlertActive
                first Monitoring
                if (aqiValue >= alertThreshold && aqiValue < emergencyThreshold)
                then AlertActive;

            transition Monitoring_to_EmergencyActive
                first Monitoring
                if (aqiValue >= emergencyThreshold)
                then EmergencyActive;

            transition AlertActive_to_Monitoring
                first AlertActive
                if (aqiValue < alertThreshold)
                then Monitoring;

            transition AlertActive_to_EmergencyActive
                first AlertActive
                if (aqiValue >= emergencyThreshold)
                then EmergencyActive;

            transition EmergencyActive_to_AlertActive
                first EmergencyActive
                if (aqiValue < emergencyThreshold && aqiValue >= alertThreshold)
                then AlertActive;

            transition EmergencyActive_to_Monitoring
                first EmergencyActive
                if (aqiValue < alertThreshold)
                then Monitoring;
        }

        do {
            // Monitor incoming AQI results from alertAQIIn port
            // When AQI exceeds alertThreshold, generate alert with severity, pollutant type, health actions
            // Escalate to EmergencyActive when AQI exceeds emergencyThreshold
            // Continue monitoring while alerts are active
            // Emit AlertNotification through alertOut port
        }
    }

    part def AirFiltrationController {
        port controllerAQIIn: AQIInPort;
        port controllerCommandOut: CommandOutPort;

        attribute activationThreshold: AQIValue = 151;
        attribute highEfficiencyThreshold: AQIValue = 201;
        attribute defaultAirflow: AirflowRate = 2000;
        attribute highEffAirflow: AirflowRate = 5000;
        attribute defaultEfficiency: Efficiency = 85;
        attribute highEffEfficiency: Efficiency = 99;

        action def evaluateAQI {
            in aqi: AQIResult;
            out command: FiltrationCommand;
        }

        action def determineMode {
            in aqiValue: AQIValue;
            out mode: FiltrationMode;
        }

        action def determineAirflow {
            in mode: FiltrationMode;
            out airflow: AirflowRate;
        }

        action def determineEfficiency {
            in mode: FiltrationMode;
            out efficiency: Efficiency;
        }

        do {
            // Monitor incoming AQI results from controllerAQIIn port
            // If AQI >= activationThreshold, generate filtration command with active mode
            // If AQI >= highEfficiencyThreshold, set highEfficiency mode
            // If AQI < activationThreshold, set standby mode
            // Specify required airflow and efficiency based on mode
            // Emit FiltrationCommand through controllerCommandOut port
        }
    }

    part def AirFiltrationUnit {
        port commandIn: CommandInPort;

        attribute maxAirflow: AirflowRate = 5000;
        attribute standbyAirflow: AirflowRate = 0;
        attribute activeAirflow: AirflowRate = 2000;
        attribute highEffAirflow: AirflowRate = 5000;
        attribute standbyEfficiency: Efficiency = 0;
        attribute activeEfficiency: Efficiency = 85;
        attribute highEffEfficiency: Efficiency = 99;
        attribute currentMode: FiltrationMode = FiltrationMode::standby;
        attribute currentAirflow: AirflowRate = 0;
        attribute currentEfficiency: Efficiency = 0;
        attribute filterLoad: Real = 0;
        attribute maxFilterLoad: Real = 100;

        action def cleanAir {
            in mode: FiltrationMode;
            in airflow: AirflowRate;
            in efficiency: Efficiency;
        }

        action def updateFilterLoad {
            in airflow: AirflowRate;
            in duration: TimeValue;
            out load: Real;
        }

        state {
            entry;
            state Standby;
            state Active;
            state HighEfficiency;

            transition Init_to_Standby
                first entry
                then Standby;

            transition Standby_to_Active
                first Standby
                if (command.mode == FiltrationMode::active)
                then Active;

            transition Standby_to_HighEfficiency
                first Standby
                if (command.mode == FiltrationMode::highEfficiency)
                then HighEfficiency;

            transition Active_to_HighEfficiency
                first Active
                if (command.mode == FiltrationMode::highEfficiency)
                then HighEfficiency;

            transition Active_to_Standby
                first Active
                if (command.mode == FiltrationMode::standby)
                then Standby;

            transition HighEfficiency_to_Active
                first HighEfficiency
                if (command.mode == FiltrationMode::active)
                then Active;

            transition HighEfficiency_to_Standby
                first HighEfficiency
                if (command.mode == FiltrationMode::standby)
                then Standby;
        }

        do {
            // Receive filtration commands from commandIn port
            // Transition between operational modes based on command
            // Physically filter air at specified airflow and efficiency
            // Monitor filter load and trigger maintenance when needed
        }
    }

    // ===== Top-level System =====

    part def AirPollutionControlSystem {

        part sensor: MultiPollutantSensor;
        part archive: DataArchiveSystem;
        part analyzer: AirQualityAnalyzer;
        part display: PublicInformationDisplay;
        part alertSystem: AlertManagementSystem;
        part filtrationController: AirFiltrationController;
        part filtrationUnit: AirFiltrationUnit;

        connection sensorToArchive: SensorDataLink
            from sensor.sensorOut to archive.archiveIn;

        connection sensorToAnalyzer: SensorDataLink
            from sensor.sensorOut to analyzer.analyzerIn;

        connection analyzerToDisplay: AQILink
            from analyzer.analyzerOut to display.displayAQIIn;

        connection analyzerToAlert: AQILink
            from analyzer.analyzerOut to alertSystem.alertAQIIn;

        connection analyzerToController: AQILink
            from analyzer.analyzerOut to filtrationController.controllerAQIIn;

        connection alertToDisplay: AlertLink
            from alertSystem.alertOut to display.displayAlertIn;

        connection controllerToUnit: CommandLink
            from filtrationController.controllerCommandOut to filtrationUnit.commandIn;
    }

    // ===== Requirements =====

    requirement def MultiPollutantMonitoringRequirement {
        subject sensor: MultiPollutantSensor;
        doc /* The system shall continuously measure PM2.5, PM10, O3, NO2, CO, and SO2 concentrations in the air. Each measurement shall include a timestamp and location identifier. */;
    }

    requirement def DataArchivingRequirement {
        subject archive: DataArchiveSystem;
        doc /* The system shall archive all sensor readings for long-term storage, supporting historical analysis and regulatory compliance. Data shall be retained for at least 365 days. */;
    }

    requirement def AQICalculationRequirement {
        subject analyzer: AirQualityAnalyzer;
        doc /* The analyzer shall calculate a single AQI value from multi-pollutant sensor data in real-time, categorize air quality into levels (Good, Moderate, Unhealthy for Sensitive Groups, Unhealthy, Very Unhealthy, Hazardous), and identify the dominant pollutant. */;
    }

    requirement def PublicInformationRequirement {
        subject display: PublicInformationDisplay;
        doc /* The display shall show current AQI value, category, and dominant pollutant to the public. The display shall refresh at least every 30 seconds. */;
    }

    requirement def AlertingRequirement {
        subject alertSystem: AlertManagementSystem;
        doc /* The alert system shall generate and issue alerts when AQI exceeds the Unhealthy for Sensitive Groups threshold (AQI >= 101). Alerts shall include severity level, pollutant type, and recommended health actions. Alerts shall be displayed on the public information display. */;
    }

    requirement def AlertEscalationRequirement {
        subject alertSystem: AlertManagementSystem;
        doc /* The alert system shall escalate alert severity when AQI reaches emergency levels (AQI >= 201) and shall de-escalate when air quality improves below thresholds. */;
    }

    requirement def ActiveMitigationRequirement {
        subject filtrationController: AirFiltrationController;
        subject filtrationUnit: AirFiltrationUnit;
        doc /* The filtration controller shall activate the filtration unit when AQI reaches the Unhealthy level (AQI >= 151). The command shall specify required airflow rate and efficiency level. The filtration unit shall operate in standby, active, or high-efficiency mode based on the command. */;
    }

    requirement def FiltrationModeRequirement {
        subject filtrationUnit: AirFiltrationUnit;
        doc /* The filtration unit shall support three operational modes: standby (airflow = 0), active (airflow up to 2000 m3/h, efficiency >= 85%), and high-efficiency (airflow up to 5000 m3/h, efficiency >= 99%). The unit shall transition between modes based on received commands. */;
    }

    requirement def ClosedLoopOperationRequirement {
        subject system: AirPollutionControlSystem;
        doc /* The system shall operate as a closed loop: continuously monitor air quality, calculate AQI, alert the public to hazardous conditions, and actively mitigate dangerous pollution levels by deploying air filtration technology. */;
    }

    requirement def RealTimeProcessingRequirement {
        subject analyzer: AirQualityAnalyzer;
        doc /* The analyzer shall process sensor data and emit AQI results within 60 seconds of receiving sensor data. */;
    }

    requirement def SensorDataDistributionRequirement {
        subject sensor: MultiPollutantSensor;
        doc /* The sensor shall simultaneously transmit raw data to the Data Archive System and the Air Quality Analyzer. */;
    }

    // ===== Requirement Satisfaction =====

    satisfy MultiPollutantMonitoringRequirement by MultiPollutantSensor;
    satisfy DataArchivingRequirement by DataArchiveSystem;
    satisfy AQICalculationRequirement by AirQualityAnalyzer;
    satisfy PublicInformationRequirement by PublicInformationDisplay;
    satisfy AlertingRequirement by AlertManagementSystem;
    satisfy AlertEscalationRequirement by AlertManagementSystem;
    satisfy ActiveMitigationRequirement by AirFiltrationController;
    satisfy FiltrationModeRequirement by AirFiltrationUnit;
    satisfy ClosedLoopOperationRequirement by AirPollutionControlSystem;
    satisfy RealTimeProcessingRequirement by AirQualityAnalyzer;
    satisfy SensorDataDistributionRequirement by MultiPollutantSensor;
}
