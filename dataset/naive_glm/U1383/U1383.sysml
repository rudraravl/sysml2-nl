package BangladeshFloodEarlyWarningSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    attribute def WaterLevel :> Real { unit 'm'; }
    attribute def RainfallRate :> Real { unit 'mm/h'; }
    attribute def RiverDischarge :> Real { unit 'm3/s'; }
    attribute def PopulationCount :> Integer { unit 'people'; }
    attribute def Probability :> Real { unit '%'; }
    attribute def DistrictId :> String;
    attribute def StationId :> String;
    attribute def DateTime :> String;
    attribute def Message :> String;

    // ---------- Enumerations ----------
    enum def SystemAlertLevel {
        normal;
        advisory;
        watch;
        warning;
        severe;
    }

    enum def TowerBroadcastMode {
        silent;
        sms;
        radio;
        siren;
        all;
    }

    enum def CenterStatus {
        standby;
        activated;
        coordinating;
        stoodDown;
    }

    // ---------- Item Definitions ----------
    item def RiverData {
        attribute stationId : StationId;
        attribute riverName : String;
        attribute waterLevel : WaterLevel;
        attribute rainfallRate : RainfallRate;
        attribute riverDischarge : RiverDischarge;
        attribute timestamp : DateTime;
    }

    item def WeatherForecast {
        attribute radarStationId : StationId;
        attribute region : String;
        attribute predictedRainfall : RainfallRate;
        attribute forecastHorizonHours : Integer;
        attribute confidence : Probability;
        attribute timestamp : DateTime;
    }

    item def FloodAlert {
        attribute level : SystemAlertLevel;
        attribute districtId : DistrictId;
        attribute affectedPopulation : PopulationCount;
        attribute message : Message;
        attribute timestamp : DateTime;
    }

    item def EvacuationOrder {
        attribute districtId : DistrictId;
        attribute affectedPopulation : PopulationCount;
        attribute shelterLocations : String;
        attribute priority : Integer;
        attribute timestamp : DateTime;
    }

    item def RiskAssessment {
        attribute overallRisk : Probability;
        attribute projectedPeakLevel : WaterLevel;
        attribute projectedPeakTime : DateTime;
        attribute affectedDistricts : String;
    }

    // ---------- Port Definitions ----------
    port def RiverDataOut { out item : RiverData; }
    port def RiverDataIn { in item : RiverData; }
    port def WeatherForecastOut { out item : WeatherForecast; }
    port def WeatherForecastIn { in item : WeatherForecast; }
    port def AlertOut { out item : FloodAlert; }
    port def AlertIn { in item : FloodAlert; }
    port def EvacuationOrderOut { out item : EvacuationOrder; }
    port def EvacuationOrderIn { in item : EvacuationOrder; }
    port def RiskAssessmentOut { out item : RiskAssessment; }
    port def RiskAssessmentIn { in item : RiskAssessment; }

    // ---------- Connection Definitions ----------
    connection def RiverDataFlow {
        end source : RiverDataOut;
        end target : RiverDataIn;
        flow of RiverData;
    }

    connection def WeatherForecastFlow {
        end source : WeatherForecastOut;
        end target : WeatherForecastIn;
        flow of WeatherForecast;
    }

    connection def AlertFlow {
        end source : AlertOut;
        end target : AlertIn;
        flow of FloodAlert;
    }

    connection def EvacuationOrderFlow {
        end source : EvacuationOrderOut;
        end target : EvacuationOrderIn;
        flow of EvacuationOrder;
    }

    connection def RiskAssessmentFlow {
        end source : RiskAssessmentOut;
        end target : RiskAssessmentIn;
        flow of RiskAssessment;
    }

    // ---------- Action Definitions ----------
    action def MeasureRiverData {
        in stationId : StationId;
        in riverName : String;
        out data : RiverData;
    }

    action def GenerateWeatherForecast {
        in radarStationId : StationId;
        in region : String;
        out forecast : WeatherForecast;
    }

    action def AnalyzeFloodRisk {
        in riverData : RiverData;
        in forecast : WeatherForecast;
        out assessment : RiskAssessment;
    }

    action def ComposeFloodAlert {
        in level : SystemAlertLevel;
        in districtId : DistrictId;
        in affectedPopulation : PopulationCount;
        out alert : FloodAlert;
    }

    action def ComposeEvacuationOrder {
        in districtId : DistrictId;
        in affectedPopulation : PopulationCount;
        out order : EvacuationOrder;
    }

    action def BroadcastAlert {
        in alert : FloodAlert;
        out mode : TowerBroadcastMode;
    }

    action def CoordinateResponse {
        in order : EvacuationOrder;
        out status : CenterStatus;
    }

    // ---------- River Monitoring Station ----------
    part def RiverMonitoringStation {
        attribute stationId : StationId;
        attribute riverName : String;
        attribute location : String;
        attribute operational : Boolean = true;

        port riverDataOut : RiverDataOut;

        part waterLevelSensor {
            attribute currentValue : WaterLevel;
        }
        part rainfallSensor {
            attribute currentValue : RainfallRate;
        }
        part dischargeSensor {
            attribute currentValue : RiverDischarge;
        }

        action measure : MeasureRiverData {
            in stationId = RiverMonitoringStation::this.stationId;
            in riverName = RiverMonitoringStation::this.riverName;
        }

        state machine stationStatus {
            state operational {
                entry { operational = true; }
                do measure;
            }
            state maintenance {
                entry { operational = false; }
            }
            state fault {
                entry { operational = false; }
            }
            transition from operational to maintenance when maintenanceRequested;
            transition from maintenance to operational when maintenanceComplete;
            transition from operational to fault when sensorFailureDetected;
            transition from fault to maintenance when faultAcknowledged;
        }

        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute sensorFailureDetected : Boolean = false;
        attribute faultAcknowledged : Boolean = false;
    }

    // ---------- Weather Radar Station ----------
    part def WeatherRadarStation {
        attribute radarStationId : StationId;
        attribute region : String;
        attribute coverageRadiusKm : Real;

        port weatherForecastOut : WeatherForecastOut;

        action generateForecast : GenerateWeatherForecast {
            in radarStationId = WeatherRadarStation::this.radarStationId;
            in region = WeatherRadarStation::this.region;
        }

        state machine radarStatus {
            state scanning {
                do generateForecast;
            }
            state standby;
            state calibration;
            transition from scanning to standby when weatherClear;
            transition from standby to scanning when stormDetected;
            transition from scanning to calibration when calibrationDue;
            transition from calibration to scanning when calibrationComplete;
        }

        attribute weatherClear : Boolean = false;
        attribute stormDetected : Boolean = false;
        attribute calibrationDue : Boolean = false;
        attribute calibrationComplete : Boolean = false;
    }

    // ---------- Communication Tower ----------
    part def CommunicationTower {
        attribute towerId : String;
        attribute districtId : DistrictId;
        attribute broadcastMode : TowerBroadcastMode = TowerBroadcastMode::silent;

        port alertIn : AlertIn;

        action broadcast : BroadcastAlert;

        state machine towerStatus {
            state idle {
                entry { broadcastMode = TowerBroadcastMode::silent; }
            }
            state broadcasting {
                do broadcast;
            }
            transition from idle to broadcasting when alertReceived;
            transition from broadcasting to idle when broadcastComplete;
        }

        attribute alertReceived : Boolean = false;
        attribute broadcastComplete : Boolean = false;
    }

    // ---------- District Emergency Center ----------
    part def DistrictEmergencyCenter {
        attribute centerId : String;
        attribute districtId : DistrictId;
        attribute status : CenterStatus = CenterStatus::standby;
        attribute estimatedAffectedPopulation : PopulationCount = 0;

        port evacuationOrderIn : EvacuationOrderIn;
        port riskAssessmentIn : RiskAssessmentIn;

        action coordinate : CoordinateResponse;

        state machine centerStatus {
            state standby {
                entry { status = CenterStatus::standby; }
            }
            state activated {
                entry { status = CenterStatus::activated; }
                do coordinate;
            }
            state coordinating {
                entry { status = CenterStatus::coordinating; }
                do coordinate;
            }
            state stoodDown {
                entry { status = CenterStatus::stoodDown; }
            }
            transition from standby to activated when evacuationOrderReceived;
            transition from activated to coordinating when responsePlanReady;
            transition from coordinating to stoodDown when threatPassed;
            transition from stoodDown to standby when resetComplete;
        }

        attribute evacuationOrderReceived : Boolean = false;
        attribute responsePlanReady : Boolean = false;
        attribute threatPassed : Boolean = false;
        attribute resetComplete : Boolean = false;
    }

    // ---------- Central Processing Hub ----------
    part def CentralProcessingHub {
        port riverDataIn : RiverDataIn;
        port weatherForecastIn : WeatherForecastIn;
        port alertOut : AlertOut;
        port evacuationOrderOut : EvacuationOrderOut;
        port riskAssessmentOut : RiskAssessmentOut;

        attribute currentAlertLevel : SystemAlertLevel = SystemAlertLevel::normal;
        attribute latestWaterLevel : WaterLevel = 0.0;
        attribute latestRainfallRate : RainfallRate = 0.0;
        attribute latestRiverDischarge : RiverDischarge = 0.0;
        attribute predictedRainfall : RainfallRate = 0.0;
        attribute overallRisk : Probability = 0.0;
        attribute affectedDistricts : String = "";
        attribute estimatedAffectedPopulation : PopulationCount = 0;

        attribute thresholdAdvisory : WaterLevel = 5.0;
        attribute thresholdWatch : WaterLevel = 7.0;
        attribute thresholdWarning : WaterLevel = 9.0;
        attribute thresholdSevere : WaterLevel = 11.0;

        action analyze : AnalyzeFloodRisk;
        action composeAlert : ComposeFloodAlert;
        action composeEvacuation : ComposeEvacuationOrder;

        state machine FloodMonitoringStateMachine {
            state normal {
                entry { currentAlertLevel = SystemAlertLevel::normal; }
                do analyze;
            }
            state advisory {
                entry { currentAlertLevel = SystemAlertLevel::advisory; }
                do composeAlert;
            }
            state watch {
                entry { currentAlertLevel = SystemAlertLevel::watch; }
                do composeAlert;
            }
            state warning {
                entry {
                    currentAlertLevel = SystemAlertLevel::warning;
                    estimatedAffectedPopulation = 50000;
                }
                do composeAlert;
                do composeEvacuation;
            }
            state severe {
                entry {
                    currentAlertLevel = SystemAlertLevel::severe;
                    estimatedAffectedPopulation = 250000;
                }
                do composeAlert;
                do composeEvacuation;
            }

            transition from normal to advisory
                when latestWaterLevel > thresholdAdvisory and latestWaterLevel <= thresholdWatch;
            transition from advisory to watch
                when latestWaterLevel > thresholdWatch and latestWaterLevel <= thresholdWarning;
            transition from watch to warning
                when latestWaterLevel > thresholdWarning and latestWaterLevel <= thresholdSevere;
            transition from warning to severe
                when latestWaterLevel > thresholdSevere;
            transition from severe to warning
                when latestWaterLevel <= thresholdSevere and latestWaterLevel > thresholdWarning;
            transition from warning to watch
                when latestWaterLevel <= thresholdWarning and latestWaterLevel > thresholdWatch;
            transition from watch to advisory
                when latestWaterLevel <= thresholdWatch and latestWaterLevel > thresholdAdvisory;
            transition from advisory to normal
                when latestWaterLevel <= thresholdAdvisory;
        }
    }

    // ---------- System ----------
    part def BangladeshFloodEarlyWarningSystem {
        attribute systemName : String = "Bangladesh Flood Early Warning System";
        attribute coverageRegion : String = "Ganges-Brahmaputra-Meghna Delta";

        part riverMonitoringStations : RiverMonitoringStation[75];
        part weatherRadarStations : WeatherRadarStation[8];
        part communicationTowers : CommunicationTower[64];
        part districtEmergencyCenters : DistrictEmergencyCenter[64];
        part centralProcessingHub : CentralProcessingHub;

        connection riverDataFlow : RiverDataFlow
            connect riverMonitoringStations.riverDataOut to centralProcessingHub.riverDataIn;

        connection weatherForecastFlow : WeatherForecastFlow
            connect weatherRadarStations.weatherForecastOut to centralProcessingHub.weatherForecastIn;

        connection alertFlow : AlertFlow
            connect centralProcessingHub.alertOut to communicationTowers.alertIn;

        connection evacuationOrderFlow : EvacuationOrderFlow
            connect centralProcessingHub.evacuationOrderOut to districtEmergencyCenters.evacuationOrderIn;

        connection riskAssessmentFlow : RiskAssessmentFlow
            connect centralProcessingHub.riskAssessmentOut to districtEmergencyCenters.riskAssessmentIn;
    }

    // ---------- Requirements ----------
    requirement def ProtectPopulationRequirement {
        doc "The system shall protect the population of the Ganges-Brahmaputra-Meghna delta by providing timely flood warnings to facilitate evacuation and emergency response.";
        subject system : BangladeshFloodEarlyWarningSystem;
        objective {
            doc "Minimize loss of life and property through early warning."
        }
    }

    requirement def RiverMonitoringCoverageRequirement {
        doc "The system shall deploy 75 automated river monitoring stations along the Ganges, Brahmaputra, and Meghna rivers.";
        subject system : BangladeshFloodEarlyWarningSystem;
        assume {
            doc "Stations are distributed to cover critical flood-prone reaches."
        }
    }

    requirement def RiverDataMeasurementRequirement {
        doc "Each river monitoring station shall continuously measure water level, rainfall rate, and river discharge.";
        subject station : RiverMonitoringStation;
    }

    requirement def WeatherRadarCoverageRequirement {
        doc "The system shall operate 8 weather radar stations to provide regional rainfall forecasts.";
        subject system : BangladeshFloodEarlyWarningSystem;
    }

    requirement def CommunicationDisseminationRequirement {
        doc "The system shall disseminate flood alerts to the public through 64 communication towers using SMS, radio broadcasts, or sirens.";
        subject system : BangladeshFloodEarlyWarningSystem;
    }

    requirement def DistrictEmergencyCenterRequirement {
        doc "The system shall include 64 district emergency centers to coordinate on-ground emergency response and evacuation.";
        subject system : BangladeshFloodEarlyWarningSystem;
    }

    requirement def AlertEscalationRequirement {
        doc "The central processing hub shall escalate alert status through advisory, watch, warning, and severe levels based on predefined water level thresholds.";
        subject hub : CentralProcessingHub;
    }

    requirement def HighRiskResponseRequirement {
        doc "At warning or severe alert levels, the system shall generate district-specific alerts, estimate affected population, broadcast warnings, and activate district emergency centers with evacuation information.";
        subject system : BangladeshFloodEarlyWarningSystem;
    }

    requirement def ContinuousMonitoringRequirement {
        doc "The system shall continuously feed river and weather data into the central processing hub for risk assessment.";
        subject system : BangladeshFloodEarlyWarningSystem;
    }

    requirement systemRequirements {
        satisfy ProtectPopulationRequirement;
        satisfy RiverMonitoringCoverageRequirement;
        satisfy RiverDataMeasurementRequirement;
        satisfy WeatherRadarCoverageRequirement;
        satisfy CommunicationDisseminationRequirement;
        satisfy DistrictEmergencyCenterRequirement;
        satisfy AlertEscalationRequirement;
        satisfy HighRiskResponseRequirement;
        satisfy ContinuousMonitoringRequirement;
    }
}
