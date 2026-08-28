package BangladeshFloodEarlyWarningSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    enum def AlertLevel {
        normal;
        advisory;
        watch;
        warning;
        severe;
    }

    item def RiverData {
        attribute waterLevel : ISQ::LengthValue;
        attribute rainfallRate : ISQ::SpeedValue;
        attribute riverDischarge : ISQ::VolumeFlowRateValue;
    }

    item def WeatherForecast {
        attribute predictedRainfall : ISQ::LengthValue;
        attribute forecastPeriod : ISQ::TimeValue;
    }

    item def FloodAlert {
        attribute level : AlertLevel;
        attribute districtId : String;
        attribute estimatedAffectedPopulation : Integer;
        attribute alertText : String;
    }

    port def RiverDataOut {
        out data : RiverData;
    }
    port def RiverDataIn {
        in data : RiverData;
    }
    port def ForecastDataOut {
        out forecast : WeatherForecast;
    }
    port def ForecastDataIn {
        in forecast : WeatherForecast;
    }
    port def AlertBroadcastOut {
        out alert : FloodAlert;
    }
    port def AlertBroadcastIn {
        in alert : FloodAlert;
    }
    port def EmergencyCommandOut {
        out command : FloodAlert;
    }
    port def EmergencyCommandIn {
        in command : FloodAlert;
    }

    part def RiverMonitoringStation {
        attribute stationId : String;
        port sensorOut : RiverDataOut;
        action measureEnvironment {
            out data : RiverData;
        }
    }

    part def WeatherRadarStation {
        attribute stationId : String;
        port forecastOut : ForecastDataOut;
        action predictWeather {
            out forecast : WeatherForecast;
        }
    }

    part def CommunicationTower {
        attribute towerId : String;
        port alertIn : AlertBroadcastIn;
        action broadcastAlert {
            in alert : FloodAlert;
        }
    }

    part def DistrictEmergencyCenter {
        attribute centerId : String;
        port commandPort : EmergencyCommandIn;
        action coordinateResponse {
            in command : FloodAlert;
        }
    }

    action def AnalyzeFloodRisk {
        in sensorData : RiverData;
        in weatherForecast : WeatherForecast;
        out riskLevel : AlertLevel;
    }

    action def GenerateAlert {
        in riskLevel : AlertLevel;
        out alert : FloodAlert;
    }

    action def EstimateAffectedPopulation {
        in alert : FloodAlert;
        out updatedAlert : FloodAlert;
    }

    action def MonitorData;
    action def IssueAdvisory;
    action def IssueWatch;
    action def GenerateDetailedAlert;
    action def ActivateEmergencyCenters;

    part def CentralProcessingHub {
        attribute currentAlertLevel : AlertLevel;
        port sensorIn : RiverDataIn;
        port forecastIn : ForecastDataIn;
        port alertOut : AlertBroadcastOut;
        port emergencyOut : EmergencyCommandOut;

        perform action monitorData : MonitorData;
        perform action issueAdvisory : IssueAdvisory;
        perform action issueWatch : IssueWatch;
        perform action generateDetailedAlert : GenerateDetailedAlert;
        perform action activateEmergencyCenters : ActivateEmergencyCenters;

        exhibit state floodAlertStates {
            entry; then normal;

            state normal {
                do monitorData;
            }
            accept when currentAlertLevel == AlertLevel::advisory
                then advisory;
            accept when currentAlertLevel == AlertLevel::watch
                then watch;
            accept when currentAlertLevel == AlertLevel::warning
                then warning;
            accept when currentAlertLevel == AlertLevel::severe
                then severe;

            state advisory {
                do issueAdvisory;
            }
            accept when currentAlertLevel == AlertLevel::watch
                then watch;
            accept when currentAlertLevel == AlertLevel::warning
                then warning;
            accept when currentAlertLevel == AlertLevel::severe
                then severe;
            accept when currentAlertLevel == AlertLevel::normal
                then normal;

            state watch {
                do issueWatch;
            }
            accept when currentAlertLevel == AlertLevel::warning
                then warning;
            accept when currentAlertLevel == AlertLevel::severe
                then severe;
            accept when currentAlertLevel == AlertLevel::advisory
                then advisory;
            accept when currentAlertLevel == AlertLevel::normal
                then normal;

            state warning {
                entry generateDetailedAlert;
                do activateEmergencyCenters;
            }
            accept when currentAlertLevel == AlertLevel::severe
                then severe;
            accept when currentAlertLevel == AlertLevel::watch
                then watch;
            accept when currentAlertLevel == AlertLevel::advisory
                then advisory;
            accept when currentAlertLevel == AlertLevel::normal
                then normal;

            state severe {
                entry generateDetailedAlert;
                do activateEmergencyCenters;
            }
            accept when currentAlertLevel == AlertLevel::warning
                then warning;
            accept when currentAlertLevel == AlertLevel::advisory
                then advisory;
            accept when currentAlertLevel == AlertLevel::normal
                then normal;
        }
    }

    part def FloodEarlyWarningSystem {
        part riverStations : RiverMonitoringStation[75];
        part radarStations : WeatherRadarStation[8];
        part commTowers : CommunicationTower[64];
        part emergencyCenters : DistrictEmergencyCenter[64];
        part centralHub : CentralProcessingHub;

        interface riverDataInterface connect riverStations.sensorOut to centralHub.sensorIn {
            flow sensorDataFlow of RiverData
                from riverStations.sensorOut.data to centralHub.sensorIn.data;
        }

        interface forecastInterface connect radarStations.forecastOut to centralHub.forecastIn {
            flow forecastDataFlow of WeatherForecast
                from radarStations.forecastOut.forecast to centralHub.forecastIn.forecast;
        }

        interface alertInterface connect centralHub.alertOut to commTowers.alertIn {
            flow alertFlow of FloodAlert
                from centralHub.alertOut.alert to commTowers.alertIn.alert;
        }

        interface emergencyInterface connect centralHub.emergencyOut to emergencyCenters.commandPort {
            flow emergencyCommandFlow of FloodAlert
                from centralHub.emergencyOut.command to emergencyCenters.commandPort.command;
        }
    }

    requirement def TimelyWarningRequirement {
        doc /* The system must provide flood warnings at least 24 hours before severe flooding. */
        subject system : FloodEarlyWarningSystem;
        objective {
            doc /* Warning is issued 24 hours in advance. */
        }
    }

    requirement def DataCollectionRequirement {
        doc /* The system must continuously collect water level, rainfall, and discharge data. */
        subject system : FloodEarlyWarningSystem;
        objective {
            doc /* Data is collected continuously from all stations. */
        }
    }

    requirement def AlertEscalationRequirement {
        doc /* The system shall escalate through advisory, watch, warning, and severe alert levels based on predefined water level thresholds. */
        subject system : FloodEarlyWarningSystem;
        objective {
            doc /* Alert levels escalate according to thresholds. */
        }
    }

    requirement def EmergencyActivationRequirement {
        doc /* The system shall activate District Emergency Centers during warning and severe alert levels. */
        subject system : FloodEarlyWarningSystem;
        objective {
            doc /* Emergency centers are activated at high alert levels. */
        }
    }

    requirement def PublicDisseminationRequirement {
        doc /* The system shall disseminate flood alerts to the public via 64 communication towers using SMS, radio, or sirens. */
        subject system : FloodEarlyWarningSystem;
        objective {
            doc /* Alerts are broadcast through communication towers. */
        }
    }
}
