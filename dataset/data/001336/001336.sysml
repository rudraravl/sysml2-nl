package AirPollutionMonitoringAndControlSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ConcentrationPPM :> Real;
    attribute def ConcentrationUgM3 :> Real;
    attribute def AirFlowRate :> Real;
    
    item def PollutantReading {
        attribute pm25Level : ConcentrationUgM3;
        attribute pm10Level : ConcentrationUgM3;
        attribute ozoneLevel : ConcentrationPPM;
        attribute no2Level : ConcentrationPPM;
        attribute coLevel : ConcentrationPPM;
        attribute so2Level : ConcentrationPPM;
        attribute timestamp : String;
        attribute locationId : String;
    }
    
    item def AirQualityIndex {
        attribute aqiValue : Integer;
        attribute category : String;
        attribute dominantPollutant : String;
    }
    
    item def AlertNotification {
        attribute severity : String;
        attribute pollutantType : String;
        attribute currentLevel : Real;
        attribute thresholdLevel : Real;
        attribute recommendedAction : String;
    }
    
    item def FilterControlCommand {
        attribute activateFilter : Boolean;
        attribute targetEfficiency : Real;
        attribute flowRate : AirFlowRate;
    }
    
    port def SensorDataPort {
        out reading : PollutantReading;
    }
    
    port def AnalysisPort {
        in pollutantData : PollutantReading;
        out aqiResult : AirQualityIndex;
    }
    
    port def AlertPort {
        out notification : AlertNotification;
    }
    
    port def ControlPort {
        out command : FilterControlCommand;
    }
    
    port def FilterPort {
        in controlSignal : FilterControlCommand;
    }
    
    part def MultiPollutantSensor {
        port dataOutput : SensorDataPort;
        
        attribute pm25Threshold : ConcentrationUgM3 = 35.0;
        attribute ozoneThreshold : ConcentrationPPM = 0.070;
        attribute no2Threshold : ConcentrationPPM = 0.100;
        
        perform action measurePollutants {
            out measurement : PollutantReading;
        }
    }
    
    part def AirQualityAnalyzer {
        port dataInput : AnalysisPort;
        
        attribute goodAQILimit : Integer = 50;
        attribute moderateAQILimit : Integer = 100;
        attribute unhealthySensitiveAQILimit : Integer = 150;
        attribute unhealthyAQILimit : Integer = 200;
        attribute veryUnhealthyAQILimit : Integer = 300;
        
        perform action calculateAQI {
            in pollutantReading : PollutantReading;
            out aqiIndex : AirQualityIndex;
        }
    }
    
    part def AlertManagementSystem {
        port aqiInput : AirQualityIndex;
        port alertOutput : AlertPort;
        
        perform action evaluateAndAlert {
            in currentAQI : AirQualityIndex;
            out alert : AlertNotification;
        }
        
        exhibit state alertStateMachine {
            entry; then normal;
            
            state normal {
                entry; then sendNormalStatus;
                action sendNormalStatus;
            }
            
            state moderate {
                entry; then sendModerateAlert;
                action sendModerateAlert;
            }
            
            state unhealthySensitive {
                entry; then sendUnhealthySensitiveAlert;
                action sendUnhealthySensitiveAlert;
            }
            
            state unhealthy {
                entry; then sendUnhealthyAlert;
                action sendUnhealthyAlert;
            }
            
            state hazardous {
                entry; then sendHazardousAlert;
                action sendHazardousAlert;
            }
            
            transition normalToModerate
                first normal
                accept aqiChange : AirQualityIndex
                if aqiChange.aqiValue > 50 and aqiChange.aqiValue <= 100
                then moderate;
            
            transition moderateToUnhealthySensitive
                first moderate
                accept aqiChange : AirQualityIndex
                if aqiChange.aqiValue > 100 and aqiChange.aqiValue <= 150
                then unhealthySensitive;
            
            transition unhealthySensitiveToUnhealthy
                first unhealthySensitive
                accept aqiChange : AirQualityIndex
                if aqiChange.aqiValue > 150 and aqiChange.aqiValue <= 200
                then unhealthy;
            
            transition unhealthyToHazardous
                first unhealthy
                accept aqiChange : AirQualityIndex
                if aqiChange.aqiValue > 200
                then hazardous;
            
            transition improvementToNormal
                first moderate
                accept aqiChange : AirQualityIndex
                if aqiChange.aqiValue <= 50
                then normal;
        }
    }
    
    part def AirFiltrationController {
        port controlOutput : ControlPort;
        
        attribute maxFlowRate : AirFlowRate = 1000.0;
        attribute minEfficiency : Real = 0.95;
        
        perform action determineFilterAction {
            in aqiData : AirQualityIndex;
            out filterCommand : FilterControlCommand;
        }
    }
    
    part def AirFiltrationUnit {
        port controlInput : FilterPort;
        
        attribute currentEfficiency : Real;
        attribute operationalStatus : Boolean;
        
        perform action filterAir {
            in command : FilterControlCommand;
        }
        
        exhibit state filterStateMachine {
            entry; then standby;
            
            state standby;
            state active;
            state highEfficiency;
            
            transition activateFilter
                first standby
                accept cmd : FilterControlCommand
                if cmd.activateFilter
                then active;
            
            transition increaseEfficiency
                first active
                accept cmd : FilterControlCommand
                if cmd.targetEfficiency > 0.95
                then highEfficiency;
            
            transition deactivateFilter
                first active
                accept cmd : FilterControlCommand
                if not cmd.activateFilter
                then standby;
        }
    }
    
    part def DataArchiveSystem {
        port dataInput : PollutantReading;
        
        perform action storeHistoricalData {
            in reading : PollutantReading;
        }
    }
    
    part def PublicInformationDisplay {
        port aqiInput : AirQualityIndex;
        port alertInput : AlertNotification;
        
        perform action displayCurrentStatus {
            in aqi : AirQualityIndex;
            in alert : AlertNotification;
        }
    }
    
    action def MonitorAndControlAirQuality {
        first start;
        then merge continuousMonitoring;
        
        then action sampleAir {
            out currentReading : PollutantReading;
        }
        
        then action analyzeData {
            in reading = sampleAir.currentReading;
            out aqiResult : AirQualityIndex;
        }
        
        then action checkThresholds {
            in aqi = analyzeData.aqiResult;
            out exceedsThreshold : Boolean;
            out requiresFiltration : Boolean;
        }
        
        then decide;
            if checkThresholds.exceedsThreshold then issueAlert;
            if checkThresholds.requiresFiltration then activateFiltration;
            else continuousMonitoring;
        
        action issueAlert {
            action generateAlert {
                in aqi = analyzeData.aqiResult;
                out alertMsg : AlertNotification;
            }
            then action broadcastAlert {
                in alert = generateAlert.alertMsg;
            }
        }
        then continuousMonitoring;
        
        action activateFiltration {
            action createFilterCommand {
                in aqi = analyzeData.aqiResult;
                out command : FilterControlCommand;
            }
            then action executeFiltering {
                in cmd = createFilterCommand.command;
            }
        }
        then continuousMonitoring;
    }
    
    part airPollutionSystem : AirPollutionMonitoringAndControlSystem {
        doc /* 
         * An integrated air pollution monitoring and control system that continuously
         * measures ambient air quality, calculates real-time Air Quality Index values,
         * issues public health alerts when pollution exceeds safe thresholds, and
         * automatically activates air filtration systems to mitigate hazardous conditions.
         */
        
        perform action monitorAndControl[*] ordered references MonitorAndControlAirQuality;
        
        part sensor : MultiPollutantSensor {
            perform monitorAndControl.sampleAir;
        }
        
        part analyzer : AirQualityAnalyzer {
            perform monitorAndControl.analyzeData;
        }
        
        part alertSystem : AlertManagementSystem {
            perform monitorAndControl.checkThresholds;
            perform monitorAndControl.issueAlert.generateAlert;
            perform monitorAndControl.issueAlert.broadcastAlert;
        }
        
        part filtrationController : AirFiltrationController {
            perform monitorAndControl.activateFiltration.createFilterCommand;
        }
        
        part filtrationUnit : AirFiltrationUnit {
            perform monitorAndControl.activateFiltration.executeFiltering;
        }
        
        part dataArchive : DataArchiveSystem;
        
        part publicDisplay : PublicInformationDisplay;
        
        connection sensorToAnalyzer connect sensor.dataOutput to analyzer.dataInput;
        connection sensorToArchive connect sensor.dataOutput to dataArchive.dataInput;
        connection analyzerToAlert connect analyzer.dataInput to alertSystem.aqiInput;
        connection analyzerToController connect analyzer.dataInput to filtrationController.controlOutput;
        connection analyzerToDisplay connect analyzer.dataInput to publicDisplay.aqiInput;
        connection controllerToFilter connect filtrationController.controlOutput to filtrationUnit.controlInput;
        connection alertToDisplay connect alertSystem.alertOutput to publicDisplay.alertInput;
    }
    
    requirement def AirQualityRequirement;
    
    requirement <'AQR-001'> continuousMonitoringRequirement : AirQualityRequirement {
        doc /* The system shall continuously monitor air pollutant concentrations including PM2.5, PM10, ozone, NO2, CO, and SO2 at intervals not exceeding 5 minutes. */
        subject airPollutionSystem.sensor;
    }
    
    requirement <'AQR-002'> aqiCalculationRequirement : AirQualityRequirement {
        doc /* The system shall calculate Air Quality Index values in real-time based on EPA standards for all monitored pollutants. */
        subject airPollutionSystem.analyzer;
    }
    
    requirement <'AQR-003'> alertGenerationRequirement : AirQualityRequirement {
        doc /* The system shall generate and broadcast public health alerts within 60 seconds when AQI exceeds 100 (Unhealthy for Sensitive Groups). */
        subject airPollutionSystem.alertSystem;
    }
    
    requirement <'AQR-004'> automaticMitigationRequirement : AirQualityRequirement {
        doc /* The system shall automatically activate air filtration systems when AQI exceeds 150 (Unhealthy) to reduce pollutant concentrations. */
        subject airPollutionSystem.filtrationController;
    }
    
    requirement <'AQR-005'> filtrationEfficiencyRequirement : AirQualityRequirement {
        doc /* Air filtration units shall achieve minimum 95% removal efficiency for particulate matter when activated. */
        subject airPollutionSystem.filtrationUnit;
    }
    
    requirement <'AQR-006'> dataArchivalRequirement : AirQualityRequirement {
        doc /* The system shall archive all pollutant readings and AQI calculations for historical analysis and regulatory compliance. */
        subject airPollutionSystem.dataArchive;
    }
    
    requirement <'AQR-007'> publicDisplayRequirement : AirQualityRequirement {
        doc /* The system shall provide real-time air quality information and health recommendations to the public through accessible displays. */
        subject airPollutionSystem.publicDisplay;
    }
    
    requirement systemMissionRequirement {
        doc /* 
         * The air pollution monitoring and control system shall protect public health
         * and environmental quality by providing continuous air quality surveillance,
         * timely hazard warnings, and automated pollution mitigation capabilities.
         */
        
        require continuousMonitoringRequirement;
        require aqiCalculationRequirement;
        require alertGenerationRequirement;
        require automaticMitigationRequirement;
        require filtrationEfficiencyRequirement;
        require dataArchivalRequirement;
        require publicDisplayRequirement;
    }
    
    part def AirPollutionMonitoringAndControlSystem;
}
