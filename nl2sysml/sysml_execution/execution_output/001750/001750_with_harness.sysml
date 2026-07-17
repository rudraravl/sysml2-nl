package BangladeshFloodEarlyWarningSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def WaterLevel :> LengthValue;
    attribute def RainfallRate :> VolumeFlowRateValue;
    attribute def RiverDischarge :> VolumeFlowRateValue;
    attribute def PopulationCount :> Real;
    
    enum def AlertLevel {
        enum normal;
        enum advisory;
        enum watch;
        enum warning;
        enum severe;
    }
    
    enum def RiverBasinType {
        enum ganges;
        enum brahmaputra;
        enum meghna;
        enum jamuna;
        enum padma;
    }
    
    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute location : String;
        attribute waterLevel : WaterLevel;
        attribute rainfall : RainfallRate;
        attribute discharge : RiverDischarge;
    }
    
    item def FloodAlert {
        attribute alertLevel : AlertLevel;
        attribute affectedDistricts : String[*];
        attribute estimatedImpact : PopulationCount;
        attribute issuedTime : TimeValue;
        attribute validUntil : TimeValue;
    }
    
    item def WeatherForecast {
        attribute forecastPeriod : TimeValue;
        attribute predictedRainfall : RainfallRate;
        attribute confidence : Real;
    }
    
    port def SensorDataPort {
        out reading : SensorReading;
    }
    
    port def AlertPort {
        in alert : FloodAlert;
    }
    
    port def ForecastPort {
        in forecast : WeatherForecast;
    }
    
    port def ControlPort {
        out command : String;
        in status : String;
    }
    
    part def RiverMonitoringStation {
        attribute stationId : String;
        attribute basinType : RiverBasinType;
        attribute criticalLevel : WaterLevel;
        attribute dangerLevel : WaterLevel;
        
        port sensorOutput : SensorDataPort;
        
        action measureWaterLevel {
            out currentLevel : WaterLevel;
        }
        
        action measureRainfall {
            out currentRate : RainfallRate;
        }
        
        action measureDischarge {
            out currentDischarge : RiverDischarge;
        }
    }
    
    part def WeatherRadarStation {
        attribute stationId : String;
        attribute coverageRadius : LengthValue;
        
        port forecastOutput : ForecastPort;
        
        action generateForecast {
            in historicalData : RainfallRate[*];
            out forecast : WeatherForecast;
        }
    }
    
    part def CommunicationTower {
        attribute towerId : String;
        attribute signalRange : LengthValue;
        
        port alertOutput : AlertPort;
        
        action broadcastAlert {
            in alert : FloodAlert;
            out transmissionStatus : Boolean;
        }
    }
    
    part def DistrictEmergencyCenter {
        attribute districtName : String;
        attribute evacuationCapacity : PopulationCount;
        
        port alertInput : AlertPort;
        port controlOutput : ControlPort;
        
        action coordinateEvacuation {
            in alert : FloodAlert;
            out evacuationPlan : String;
        }
    }
    
    action def CollectSensorData {
        in stations : RiverMonitoringStation[*];
        out readings : SensorReading[*];
    }
    
    action def AnalyzeFloodRisk {
        in sensorData : SensorReading[*];
        in weatherForecast : WeatherForecast;
        in historicalData : SensorReading[*];
        out riskLevel : AlertLevel;
        out affectedAreas : String[*];
        out estimatedPopulation : PopulationCount;
    }
    
    action def GenerateAlert {
        in riskLevel : AlertLevel;
        in affectedAreas : String[*];
        in population : PopulationCount;
        out alert : FloodAlert;
    }
    
    action def DisseminateWarning {
        in alert : FloodAlert;
        in communicationChannels : CommunicationTower[*];
        out notificationsSent : Integer;
    }
    
    action def ActivateEmergencyResponse {
        in alert : FloodAlert;
        in emergencyCenters : DistrictEmergencyCenter[*];
        out responsePlan : String;
    }
    
    state def FloodMonitoringStates {
        in attribute advisoryThreshold : WaterLevel;
        in attribute watchThreshold : WaterLevel;
        in attribute warningThreshold : WaterLevel;
        in attribute severeThreshold : WaterLevel;
        
        attribute currentStatus : AlertLevel;
        
        entry; then normalMonitoring;
        
        state normalMonitoring;
        
        transition normalToAdvisory
            first normalMonitoring
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel > advisoryThreshold
            then advisoryState;
        
        state advisoryState;
        
        transition advisoryToWatch
            first advisoryState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel > watchThreshold
            then watchState;
        
        transition advisoryToNormal
            first advisoryState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel < advisoryThreshold
            then normalMonitoring;
        
        state watchState;
        
        transition watchToWarning
            first watchState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel > warningThreshold
            then warningState;
        
        transition watchToAdvisory
            first watchState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel < watchThreshold
            then advisoryState;
        
        state warningState;
        
        transition warningToSevere
            first warningState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel > severeThreshold
            then severeState;
        
        transition warningToWatch
            first warningState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel < warningThreshold
            then watchState;
        
        state severeState;
        
        transition severeToWarning
            first severeState
            accept dataUpdate : SensorReading
            if dataUpdate.waterLevel < severeThreshold
            then warningState;
    }
    
    action def FloodEarlyWarningOperation {
        first start;
        then merge monitoringLoop;
        
        action collectData : CollectSensorData {
            in stations;
            out readings;
        }
        then collectData;
        
        action getForecast {
            in weatherStations : WeatherRadarStation[*];
            out forecast : WeatherForecast;
        }
        then getForecast;
        
        action analyzeRisk : AnalyzeFloodRisk {
            in sensorData = collectData.readings;
            in weatherForecast = getForecast.forecast;
            in historicalData;
            out riskLevel;
            out affectedAreas;
            out estimatedPopulation;
        }
        then analyzeRisk;
        
        then decide riskDecision;
            if analyzeRisk.riskLevel == AlertLevel::normal then monitoringLoop;
            if analyzeRisk.riskLevel == AlertLevel::advisory then issueAdvisory;
            if analyzeRisk.riskLevel == AlertLevel::watch then issueWatch;
            if analyzeRisk.riskLevel == AlertLevel::warning then issueWarning;
            if analyzeRisk.riskLevel == AlertLevel::severe then issueSevere;
        
        action issueAdvisory {
            action generate : GenerateAlert {
                in riskLevel = analyzeRisk.riskLevel;
                in affectedAreas = analyzeRisk.affectedAreas;
                in population = analyzeRisk.estimatedPopulation;
                out alert;
            }
        }
        then monitoringLoop;
        
        action issueWatch {
            action generate : GenerateAlert {
                in riskLevel = analyzeRisk.riskLevel;
                in affectedAreas = analyzeRisk.affectedAreas;
                in population = analyzeRisk.estimatedPopulation;
                out alert;
            }
            then action disseminate : DisseminateWarning {
                in alert = generate.alert;
                in communicationChannels;
                out notificationsSent;
            }
        }
        then monitoringLoop;
        
        action issueWarning {
            action generate : GenerateAlert {
                in riskLevel = analyzeRisk.riskLevel;
                in affectedAreas = analyzeRisk.affectedAreas;
                in population = analyzeRisk.estimatedPopulation;
                out alert;
            }
            then action disseminate : DisseminateWarning {
                in alert = generate.alert;
                in communicationChannels;
                out notificationsSent;
            }
            then action activate : ActivateEmergencyResponse {
                in alert = generate.alert;
                in emergencyCenters;
                out responsePlan;
            }
        }
        then monitoringLoop;
        
        action issueSevere {
            action generate : GenerateAlert {
                in riskLevel = analyzeRisk.riskLevel;
                in affectedAreas = analyzeRisk.affectedAreas;
                in population = analyzeRisk.estimatedPopulation;
                out alert;
            }
            then action disseminate : DisseminateWarning {
                in alert = generate.alert;
                in communicationChannels;
                out notificationsSent;
            }
            then action activate : ActivateEmergencyResponse {
                in alert = generate.alert;
                in emergencyCenters;
                out responsePlan;
            }
        }
        then monitoringLoop;
        
        merge monitoringLoop;
        then done;
    }
    
    part bangladeshFloodEarlyWarningSystem {
        doc /*
            The Bangladesh Flood Early Warning System is a comprehensive monitoring and alert
            system designed to protect the population of Bangladesh from devastating floods
            caused by monsoon rains and river overflow in the Ganges-Brahmaputra-Meghna delta.
            
            The system continuously monitors water levels at critical points across major river
            basins, integrates weather forecasts, analyzes flood risk using historical data and
            predictive models, and disseminates timely warnings to affected communities through
            multiple communication channels. When flood conditions are detected, the system
            coordinates with district emergency centers to activate evacuation and relief operations,
            potentially saving thousands of lives and reducing economic losses.
        */
        
        part gangesStations : RiverMonitoringStation[25] {
            attribute :>> basinType = RiverBasinType::ganges;
            attribute :>> criticalLevel = 8.5 [SI::m];
            attribute :>> dangerLevel = 7.0 [SI::m];
        }
        
        part brahmaputraStations : RiverMonitoringStation[30] {
            attribute :>> basinType = RiverBasinType::brahmaputra;
            attribute :>> criticalLevel = 9.0 [SI::m];
            attribute :>> dangerLevel = 7.5 [SI::m];
        }
        
        part meghnaStations : RiverMonitoringStation[20] {
            attribute :>> basinType = RiverBasinType::meghna;
            attribute :>> criticalLevel = 7.5 [SI::m];
            attribute :>> dangerLevel = 6.0 [SI::m];
        }
        
        part weatherRadars : WeatherRadarStation[8] {
            attribute :>> coverageRadius = 250.0 [SI::km];
        }
        
        part communicationTowers : CommunicationTower[64] {
            attribute :>> signalRange = 50.0 [SI::km];
        }
        
        part districtCenters : DistrictEmergencyCenter[64] {
            attribute :>> evacuationCapacity = 50000.0;
        }
        
        part centralProcessing {
            port dataInput : SensorDataPort[75];
            port forecastInput : ForecastPort[8];
            port alertOutput : AlertPort;
        }
        
        connection gangesDataFlow : item flow 
            from gangesStations.sensorOutput 
            to centralProcessing.dataInput;
        
        connection brahmaputraDataFlow : item flow 
            from brahmaputraStations.sensorOutput 
            to centralProcessing.dataInput;
        
        connection meghnaDataFlow : item flow 
            from meghnaStations.sensorOutput 
            to centralProcessing.dataInput;
        
        connection forecastFlow : item flow 
            from weatherRadars.forecastOutput 
            to centralProcessing.forecastInput;
        
        connection alertFlow : item flow 
            from centralProcessing.alertOutput 
            to communicationTowers.alertOutput;
        
        connection emergencyFlow : item flow 
            from centralProcessing.alertOutput 
            to districtCenters.alertInput;
        
        perform action warningOperation : FloodEarlyWarningOperation;
        
        exhibit state systemState : FloodMonitoringStates {
            in attribute :>> advisoryThreshold = 5.0 [SI::m];
            in attribute :>> watchThreshold = 6.5 [SI::m];
            in attribute :>> warningThreshold = 7.5 [SI::m];
            in attribute :>> severeThreshold = 9.0 [SI::m];
        }
    }
    
    requirement <'FEWS-001'> primaryMissionRequirement {
        doc /*
            The Bangladesh Flood Early Warning System shall provide timely and accurate
            flood warnings to protect the population of Bangladesh from flood-related
            casualties and economic losses by monitoring river levels across the
            Ganges-Brahmaputra-Meghna delta and disseminating alerts at least 24 hours
            before predicted flooding events.
        */
        
        subject system : bangladeshFloodEarlyWarningSystem;
        
        require monitoringCoverageRequirement;
        require alertTimingRequirement;
        require accuracyRequirement;
        require disseminationRequirement;
    }
    
    requirement <'FEWS-002'> monitoringCoverageRequirement {
        doc /*
            The system shall maintain continuous monitoring coverage across all major
            river basins with a minimum of 75 monitoring stations distributed across
            the Ganges (25), Brahmaputra (30), and Meghna (20) river systems.
        */
        
        subject gangesStations : RiverMonitoringStation[25];
        subject brahmaputraStations : RiverMonitoringStation[30];
        subject meghnaStations : RiverMonitoringStation[20];
    }
    
    requirement <'FEWS-003'> alertTimingRequirement {
        doc /*
            The system shall issue flood warnings at least 24 hours before predicted
            flooding events to allow sufficient time for evacuation and emergency
            response preparation.
        */
    }
    
    requirement <'FEWS-004'> accuracyRequirement {
        doc /*
            The system shall achieve a minimum flood prediction accuracy of 85%
            for warning-level events and 90% for severe-level events to minimize
            false alarms while ensuring public safety.
        */
    }
    
    requirement <'FEWS-005'> disseminationRequirement {
        doc /*
            The system shall disseminate flood warnings to affected populations
            through multiple communication channels including SMS, radio broadcast,
            and community sirens, reaching at least 95% of the at-risk population
            within 2 hours of alert issuance.
        */
        
        subject communicationTowers : CommunicationTower[64];
        subject districtCenters : DistrictEmergencyCenter[64];
    }
    
    requirement <'FEWS-006'> populationProtectionRequirement {
        doc /*
            The system shall provide flood protection coverage for a population
            of at least 160 million people living in flood-prone areas of Bangladesh,
            with coordinated emergency response capacity for evacuating up to
            3.2 million people simultaneously across all district centers.
        */
        
        assume constraint evacuationCapacity {
            64 * 50000.0 >= 3200000.0
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import BangladeshFloodEarlyWarningSystem::*;

    part testSubject = bangladeshFloodEarlyWarningSystem {
        exhibit state sm : FloodMonitoringStates;
    }

    action orchestrator {
        action collectDataProbe : CollectSensorData {
            // TODO(human): unsupported input type for stations: RiverMonitoringStation[*] (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first collectDataProbe;
    }
}
