package 'Dew Warning System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RelativeHumidityValue :> Real;
    attribute def DewPointTemperature :> ISQ::ThermodynamicTemperatureValue;
    
    enum def AlertLevel {
        enum safe;
        enum caution;
        enum warning;
        enum critical;
    }
    
    attribute def SensorReading {
        attribute timestamp : ISQ::TimeValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute humidity : RelativeHumidityValue;
    }
    
    attribute def DewAnalysis {
        attribute surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute dewPoint : DewPointTemperature;
        attribute temperatureDelta : ISQ::ThermodynamicTemperatureValue;
        attribute alertLevel : AlertLevel;
    }
    
    port def EnvironmentalDataPort {
        out temperature : ISQ::ThermodynamicTemperatureValue;
        out humidity : RelativeHumidityValue;
    }
    
    port def SurfaceMonitorPort {
        out surfaceTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def AlertPort {
        out alert : AlertLevel;
        out message : String;
    }
    
    part def AmbientSensor {
        port dataOut : EnvironmentalDataPort;
        
        attribute measurementInterval : ISQ::TimeValue;
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute currentHumidity : RelativeHumidityValue;
    }
    
    part def SurfaceSensor {
        port surfaceOut : SurfaceMonitorPort;
        
        attribute monitoredSurfaceTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    part def DewPointProcessor {
        in ambientTemp : ISQ::ThermodynamicTemperatureValue;
        in relativeHumidity : RelativeHumidityValue;
        out calculatedDewPoint : DewPointTemperature;
        
        action computeDewPoint {
            in temp : ISQ::ThermodynamicTemperatureValue;
            in humidity : RelativeHumidityValue;
            out dewPoint : DewPointTemperature;
        }
    }
    
    part def RiskAnalyzer {
        in surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
        in dewPointTemperature : DewPointTemperature;
        out riskLevel : AlertLevel;
        out analysisResult : DewAnalysis;
        
        attribute criticalThreshold : ISQ::ThermodynamicTemperatureValue = 1.0 [SI::K];
        attribute warningThreshold : ISQ::ThermodynamicTemperatureValue = 3.0 [SI::K];
        attribute cautionThreshold : ISQ::ThermodynamicTemperatureValue = 5.0 [SI::K];
    }
    
    part def AlertGenerator {
        in riskLevel : AlertLevel;
        in analysis : DewAnalysis;
        out alertSignal : AlertLevel;
        out alertMessage : String;
    }
    
    part def VisualIndicator {
        port alertInput : AlertPort;
    }
    
    action def MonitorDewConditions {
        in ambientTemperature : ISQ::ThermodynamicTemperatureValue;
        in ambientHumidity : RelativeHumidityValue;
        in surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
        in criticalDelta : ISQ::ThermodynamicTemperatureValue;
        in warningDelta : ISQ::ThermodynamicTemperatureValue;
        in cautionDelta : ISQ::ThermodynamicTemperatureValue;
        out currentAlert : AlertLevel;
        out alertText : String;
        
        first start;
        then merge continuousMonitoring;
        
        then action calculateDew {
            in temp : ISQ::ThermodynamicTemperatureValue = ambientTemperature;
            in humidity : RelativeHumidityValue = ambientHumidity;
            out dewPoint : DewPointTemperature;
        }
        
        then action assessRisk {
            in surfaceTemp : ISQ::ThermodynamicTemperatureValue = surfaceTemperature;
            in dewTemp : DewPointTemperature = calculateDew.dewPoint;
            out delta : ISQ::ThermodynamicTemperatureValue;
            out level : AlertLevel;
        }
        
        then decide;
            if assessRisk.delta <= criticalDelta then issueCritical;
            if assessRisk.delta > criticalDelta and assessRisk.delta <= warningDelta then issueWarning;
            if assessRisk.delta > warningDelta and assessRisk.delta <= cautionDelta then issueCaution;
            if assessRisk.delta > cautionDelta then issueSafe;
        
        action issueCritical {
            then assign currentAlert := AlertLevel::critical;
            then assign alertText := "CRITICAL: Dew formation imminent";
        }
        then continuousMonitoring;
        
        action issueWarning {
            then assign currentAlert := AlertLevel::warning;
            then assign alertText := "WARNING: High risk of dew formation";
        }
        then continuousMonitoring;
        
        action issueCaution {
            then assign currentAlert := AlertLevel::caution;
            then assign alertText := "CAUTION: Moderate dew risk";
        }
        then continuousMonitoring;
        
        action issueSafe {
            then assign currentAlert := AlertLevel::safe;
            then assign alertText := "Safe: No dew risk";
        }
        then continuousMonitoring;
    }
    
    part def DewWarningSystem;
    
    part dewWarningSystem : DewWarningSystem {
        attribute systemCriticalThreshold : ISQ::ThermodynamicTemperatureValue = 1.0 [SI::K];
        attribute systemWarningThreshold : ISQ::ThermodynamicTemperatureValue = 3.0 [SI::K];
        attribute systemCautionThreshold : ISQ::ThermodynamicTemperatureValue = 5.0 [SI::K];
        
        part ambientSensor : AmbientSensor {
            port dataOut : EnvironmentalDataPort;
        }
        
        part surfaceSensor : SurfaceSensor {
            port surfaceOut : SurfaceMonitorPort;
        }
        
        part dewProcessor : DewPointProcessor;
        
        part riskAnalyzer : RiskAnalyzer {
            attribute criticalThreshold = systemCriticalThreshold;
            attribute warningThreshold = systemWarningThreshold;
            attribute cautionThreshold = systemCautionThreshold;
        }
        
        part alertGenerator : AlertGenerator;
        
        part visualIndicator : VisualIndicator {
            port alertInput : AlertPort;
        }
        
        connection ambientTempConnection connect 
            ambientSensor.dataOut.temperature to dewProcessor.ambientTemp;
        
        connection humidityConnection connect 
            ambientSensor.dataOut.humidity to dewProcessor.relativeHumidity;
        
        connection dewPointConnection connect 
            dewProcessor.calculatedDewPoint to riskAnalyzer.dewPointTemperature;
        
        connection surfaceTempConnection connect 
            surfaceSensor.surfaceOut.surfaceTemp to riskAnalyzer.surfaceTemperature;
        
        connection riskLevelConnection connect 
            riskAnalyzer.riskLevel to alertGenerator.riskLevel;
        
        connection analysisConnection connect 
            riskAnalyzer.analysisResult to alertGenerator.analysis;
        
        connection alertSignalConnection connect 
            alertGenerator.alertSignal to visualIndicator.alertInput.alert;
        
        connection alertMessageConnection connect 
            alertGenerator.alertMessage to visualIndicator.alertInput.message;
        
        perform action monitoring : MonitorDewConditions {
            in ambientTemperature = ambientSensor.currentTemperature;
            in ambientHumidity = ambientSensor.currentHumidity;
            in surfaceTemperature = surfaceSensor.monitoredSurfaceTemp;
            in criticalDelta = systemCriticalThreshold;
            in warningDelta = systemWarningThreshold;
            in cautionDelta = systemCautionThreshold;
            out currentAlert : AlertLevel;
            out alertText : String;
        }
    }
    
    requirement <'DEW-REQ-001'> dewDetectionCapability {
        doc /* The system shall continuously monitor environmental conditions 
               to detect potential dew formation on monitored surfaces. */
        
        subject dewWarningSystem;
    }
    
    requirement <'DEW-REQ-002'> dewPointCalculation {
        doc /* The system shall calculate dew point temperature based on 
               ambient temperature and relative humidity measurements. */
        
        subject dewWarningSystem.dewProcessor;
        
        refines dewDetectionCapability;
    }
    
    requirement <'DEW-REQ-003'> riskAssessment {
        doc /* The system shall assess dew formation risk by comparing 
               surface temperature to calculated dew point temperature. */
        
        subject dewWarningSystem.riskAnalyzer;
        
        refines dewDetectionCapability;
    }
    
    requirement <'DEW-REQ-004'> multiLevelAlerts {
        doc /* The system shall provide graduated alert levels: safe, caution, 
               warning, and critical based on temperature differential thresholds. */
        
        subject dewWarningSystem.alertGenerator;
        
        require constraint {
            dewWarningSystem.systemCriticalThreshold < dewWarningSystem.systemWarningThreshold and
            dewWarningSystem.systemWarningThreshold < dewWarningSystem.systemCautionThreshold
        }
    }
    
    requirement <'DEW-REQ-005'> visualFeedback {
        doc /* The system shall provide clear visual indication of current 
               dew formation risk level to operators. */
        
        subject dewWarningSystem.visualIndicator;
        
        refines multiLevelAlerts;
    }
    
    requirement <'DEW-REQ-006'> continuousOperation {
        doc /* The system shall operate continuously, providing real-time 
               monitoring and immediate alerts when conditions change. */
        
        subject dewWarningSystem.monitoring;
    }
    
    requirement systemMission {
        doc /* The dew warning system shall prevent condensation damage by 
               monitoring atmospheric conditions and surface temperatures, 
               calculating dew point, and providing timely graduated alerts 
               when surface temperatures approach conditions conducive to 
               dew formation. */
        
        assume constraint validSensorData {
            doc /* Environmental and surface sensors provide accurate, 
                   calibrated measurements within specified tolerances. */
        }
        
        require dewDetectionCapability;
        require dewPointCalculation;
        require riskAssessment;
        require multiLevelAlerts;
        require visualFeedback;
        require continuousOperation;
    }
}
