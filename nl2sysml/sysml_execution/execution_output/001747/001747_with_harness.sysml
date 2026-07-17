package AtmosphericPressureSystem {
    attribute def MaintenanceRequest;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AtmosphericPressureValue :> ISQ::PressureValue;
    attribute def AltitudeValue :> ISQ::LengthValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def PressureTrend;
    
    item def PressureMeasurement {
        attribute pressure : AtmosphericPressureValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def CorrectedPressureData {
        attribute seaLevelPressure : AtmosphericPressureValue;
        attribute localPressure : AtmosphericPressureValue;
        attribute altitude : AltitudeValue;
    }
    
    item def WeatherForecast {
        attribute trend : PressureTrend;
        attribute forecastType : String;
        attribute confidence : Real;
    }
    
    port def SensorDataPort {
        out item measurement : PressureMeasurement;
    }
    
    port def ProcessedDataPort {
        in item rawData : PressureMeasurement;
        out item correctedData : CorrectedPressureData;
    }
    
    port def ForecastPort {
        in item pressureData : CorrectedPressureData;
        out item forecast : WeatherForecast;
    }
    
    port def DisplayPort {
        in item displayData : CorrectedPressureData;
        in item forecastData : WeatherForecast;
    }
    
    part def BarometricSensor {
        port sensorOutput : SensorDataPort;
        attribute sensorAccuracy : AtmosphericPressureValue;
        attribute calibrationOffset : AtmosphericPressureValue;
    }
    
    part def DataProcessor {
        port dataInput : ProcessedDataPort;
        attribute referenceAltitude : AltitudeValue;
        attribute pressureHistory : AtmosphericPressureValue[24];
    }
    
    part def ForecastEngine {
        port forecastInput : ForecastPort;
        attribute trendWindow : ISQ::TimeValue;
        attribute pressureChangeThreshold : AtmosphericPressureValue;
    }
    
    part def DisplayUnit {
        port displayInput : DisplayPort;
        attribute updateInterval : ISQ::TimeValue;
    }
    
    action def AcquirePressureReading {
        out rawPressure : AtmosphericPressureValue;
        out ambientTemp : TemperatureValue;
        out relativeHumidity : HumidityValue;
    }
    
    action def CorrectForAltitude {
        in measuredPressure : AtmosphericPressureValue;
        in temperature : TemperatureValue;
        in altitude : AltitudeValue;
        out seaLevelEquivalent : AtmosphericPressureValue;
    }
    
    action def UpdatePressureHistory {
        in newPressure : AtmosphericPressureValue;
        in existingHistory : AtmosphericPressureValue[*];
        out updatedHistory : AtmosphericPressureValue[*];
    }
    
    action def AnalyzePressureTrend {
        in pressureHistory : AtmosphericPressureValue[*];
        out trend : PressureTrend;
        out changeRate : Real;
    }
    
    action def GenerateForecast {
        in currentPressure : AtmosphericPressureValue;
        in trend : PressureTrend;
        in changeRate : Real;
        out forecast : WeatherForecast;
    }
    
    action def MonitorAtmosphericPressure {
        first start;
        then merge continuousMonitoring;
        
        then action acquire : AcquirePressureReading {
            out rawPressure;
            out ambientTemp;
            out relativeHumidity;
        }
        
        then action correct : CorrectForAltitude {
            in measuredPressure = acquire.rawPressure;
            in temperature = acquire.ambientTemp;
            in altitude;
            out seaLevelEquivalent;
        }
        
        then action updateHistory : UpdatePressureHistory {
            in newPressure = correct.seaLevelEquivalent;
            in existingHistory;
            out updatedHistory;
        }
        
        then action analyzeTrend : AnalyzePressureTrend {
            in pressureHistory = updateHistory.updatedHistory;
            out trend;
            out changeRate;
        }
        
        then action generateForecast : GenerateForecast {
            in currentPressure = correct.seaLevelEquivalent;
            in trend = analyzeTrend.trend;
            in changeRate = analyzeTrend.changeRate;
            out forecast;
        }
        
        then action displayResults;
        then action waitInterval;
        then continuousMonitoring;
    }
    
    state def PressureMonitoringStates {
        entry; then initializing;
        
        state initializing {
            entry action calibrateSensor;
        }
        then operational;
        
        state operational {
            entry; then monitoring;
            
            state monitoring {
                entry action startMonitoring;
                entry; then stable;
                
                state stable;
                state rising;
                state falling;
                state rapidChange;
                
                transition first stable
                    accept at pressureChangeRate > 0.5
                    then rising;
                
                transition first stable
                    accept at pressureChangeRate < -0.5
                    then falling;
                
                transition first rising
                    accept at pressureChangeRate >= -0.1 and pressureChangeRate <= 0.1
                    then stable;
                
                transition first falling
                    accept at pressureChangeRate >= -0.1 and pressureChangeRate <= 0.1
                    then stable;
                
                transition first rising
                    accept at pressureChangeRate > 3.0
                    then rapidChange;
                
                transition first falling
                    accept at pressureChangeRate < -3.0
                    then rapidChange;
                
                transition first rapidChange
                    accept at pressureChangeRate >= -0.5 and pressureChangeRate <= 0.5
                    then stable;
            }
            
            transition first monitoring
                accept MaintenanceRequest
                then maintenance;
            
            state maintenance {
                entry action suspendMonitoring;
                exit action resumeMonitoring;
            }
            then monitoring;
        }
    }
    
    requirement def FunctionalRequirements {
        doc /* The atmospheric pressure system shall measure, process, and display 
               atmospheric pressure data for weather monitoring and forecasting. */
        
        requirement <'FR-1'> pressureMeasurement {
            doc /* The system shall measure atmospheric pressure with accuracy 
                   of ±1.0 hPa in the range 800-1100 hPa. */
        }
        
        requirement <'FR-2'> altitudeCorrection {
            doc /* The system shall correct pressure readings to sea level equivalent 
                   using configured altitude and measured temperature. */
        }
        
        requirement <'FR-3'> trendAnalysis {
            doc /* The system shall analyze pressure trends over 24 hours and 
                   classify as rising, falling, or stable. */
        }
        
        requirement <'FR-4'> forecastGeneration {
            doc /* The system shall generate basic weather forecasts based on 
                   pressure trends and rate of change. */
        }
        
        requirement <'FR-5'> continuousOperation {
            doc /* The system shall operate continuously with measurement updates 
                   at intervals not exceeding 5 minutes. */
        }
    }
    
    requirement systemObjective {
        doc /* The atmospheric pressure monitoring system provides continuous measurement 
               and analysis of atmospheric pressure to support weather forecasting and 
               environmental monitoring applications. */
        
        assume constraint environmentalConditions {
            doc /* System operates in temperature range -20°C to +50°C and 
                   humidity range 10-95% RH non-condensing. */
        }
        
        require FunctionalRequirements::pressureMeasurement;
        require FunctionalRequirements::altitudeCorrection;
        require FunctionalRequirements::trendAnalysis;
        require FunctionalRequirements::forecastGeneration;
        require FunctionalRequirements::continuousOperation;
    }
    
    part atmosphericPressureMonitor {
        doc /* Complete atmospheric pressure monitoring system that continuously measures 
               local atmospheric pressure, corrects for altitude, analyzes trends, and 
               generates weather forecasts for display to users. */
        
        perform action monitoring : MonitorAtmosphericPressure;
        
        exhibit state behavior : PressureMonitoringStates;
        
        part sensor : BarometricSensor {
            attribute :>> sensorAccuracy = 0.5 [hPa];
            attribute :>> calibrationOffset = 0.0 [hPa];
        }
        
        part processor : DataProcessor {
            attribute :>> referenceAltitude = 150.0 [m];
            perform monitoring.correct;
            perform monitoring.updateHistory;
        }
        
        part forecastEngine : ForecastEngine {
            attribute :>> trendWindow = 86400.0 [s];
            attribute :>> pressureChangeThreshold = 2.0 [hPa];
            perform monitoring.analyzeTrend;
            perform monitoring.generateForecast;
        }
        
        part display : DisplayUnit {
            attribute :>> updateInterval = 300.0 [s];
        }
        
        connect sensor.sensorOutput to processor.dataInput;
        connect processor.dataInput to forecastEngine.forecastInput;
        connect processor.dataInput to display.displayInput;
        connect forecastEngine.forecastInput to display.displayInput;
        
        satisfy systemObjective;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import AtmosphericPressureSystem::*;

    part testSubject = atmosphericPressureMonitor {
        exhibit state sm : PressureMonitoringStates;
    }
}
