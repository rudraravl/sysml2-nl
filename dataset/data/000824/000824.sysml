package VITAbandHealthMonitoringSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ModelingMetadata::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    
    attribute def HeartRateValue :> Real {
        doc /* Heart rate measured in beats per minute */
    }
    
    attribute def BloodOxygenValue :> Real {
        doc /* Blood oxygen saturation percentage (SpO2) */
    }
    
    attribute def BodyTemperatureValue :> ThermodynamicTemperatureValue {
        doc /* Core body temperature */
    }
    
    attribute def StepCountValue :> Real {
        doc /* Number of steps taken */
    }
    
    attribute def BatteryChargeValue :> Real {
        doc /* Battery charge level percentage */
    }
    
    item def VitalSignsData {
        attribute heartRate : HeartRateValue;
        attribute bloodOxygen : BloodOxygenValue;
        attribute bodyTemperature : BodyTemperatureValue;
        attribute stepCount : StepCountValue;
        attribute timestamp : String;
    }
    
    item def AlertMessage {
        attribute alertType : AlertSeverity;
        attribute messageText : String;
        attribute vitalData : VitalSignsData;
    }
    
    item def UserConfiguration {
        attribute minHeartRate : HeartRateValue;
        attribute maxHeartRate : HeartRateValue;
        attribute minBloodOxygen : BloodOxygenValue;
        attribute maxTemperature : BodyTemperatureValue;
        attribute minTemperature : BodyTemperatureValue;
    }
    
    enum def AlertSeverity {
        enum normal;
        enum warning;
        enum critical;
    }
    
    port def SensorDataPort {
        out vitalSigns : VitalSignsData;
    }
    
    port def AlertPort {
        out alert : AlertMessage;
    }
    
    port def ConfigurationPort {
        in userConfig : UserConfiguration;
    }
    
    port def CommunicationPort {
        out telemetry : VitalSignsData;
        out alerts : AlertMessage;
        in configuration : UserConfiguration;
    }
    
    port def PowerPort {
        in powerSupply : ISQ::PowerValue;
        out batteryStatus : BatteryChargeValue;
    }
    
    part def BiometricSensorArray {
        port dataOutput : SensorDataPort;
        
        part heartRateSensor {
            action measureHeartRate {
                out hr : HeartRateValue;
            }
        }
        
        part pulseOximeter {
            action measureBloodOxygen {
                out spo2 : BloodOxygenValue;
            }
        }
        
        part thermometer {
            action measureTemperature {
                out temp : BodyTemperatureValue;
            }
        }
        
        part accelerometer {
            action countSteps {
                out steps : StepCountValue;
            }
        }
    }
    
    part def AnalyticsProcessor {
        port sensorInput : SensorDataPort;
        port alertOutput : AlertPort;
        port configInput : ConfigurationPort;
        
        action analyzeVitalSigns {
            in currentVitals : VitalSignsData;
            in thresholds : UserConfiguration;
            out alertLevel : AlertSeverity;
            out alertMsg : AlertMessage;
        }
    }
    
    part def WirelessTransceiver {
        port commPort : CommunicationPort;
        
        action transmitTelemetry {
            in data : VitalSignsData;
        }
        
        action transmitAlert {
            in alert : AlertMessage;
        }
        
        action receiveConfiguration {
            out config : UserConfiguration;
        }
    }
    
    part def DisplayInterface {
        port displayInput : SensorDataPort;
        port alertInput : AlertPort;
        
        action showVitalSigns {
            in vitals : VitalSignsData;
        }
        
        action showAlert {
            in alert : AlertMessage;
        }
    }
    
    part def PowerManagementUnit {
        port powerPort : PowerPort;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentCharge : BatteryChargeValue;
        
        action monitorBattery {
            out chargeLevel : BatteryChargeValue;
        }
        
        action distributePower {
            out power : ISQ::PowerValue;
        }
    }
    
    action def AcquireVitalSigns {
        out heartRateOut : HeartRateValue;
        out oxygenOut : BloodOxygenValue;
        out temperatureOut : BodyTemperatureValue;
        out stepsOut : StepCountValue;
    }
    
    part def VITAband {
        doc /* Wearable health monitoring device that continuously tracks vital signs, 
               analyzes health metrics in real-time, generates alerts for abnormal conditions, 
               and wirelessly transmits patient data to healthcare providers and caregivers. */
        
        port sensorPort : SensorDataPort;
        port alertPort : AlertPort;
        port configPort : ConfigurationPort;
        port commPort : CommunicationPort;
        port powerPort : PowerPort;
        
        part sensors : BiometricSensorArray;
        part processor : AnalyticsProcessor;
        part wireless : WirelessTransceiver;
        part display : DisplayInterface;
        part powerMgmt : PowerManagementUnit;
        
        connect sensors.dataOutput to processor.sensorInput;
        connect processor.alertOutput to display.alertInput;
        connect sensors.dataOutput to display.displayInput;
        connect processor.alertOutput to wireless.commPort;
        connect sensors.dataOutput to wireless.commPort;
        connect wireless.commPort to configPort;
        
        perform action continuousHealthMonitoring {
            first start;
            then merge monitoringLoop;
            
            action acquireVitalSigns : AcquireVitalSigns {
                out heartRateOut : HeartRateValue;
                out oxygenOut : BloodOxygenValue;
                out temperatureOut : BodyTemperatureValue;
                out stepsOut : StepCountValue;
            }
            
            then action processData : processor.analyzeVitalSigns {
                in currentVitals = VitalSignsData {
                    heartRate = acquireVitalSigns.heartRateOut;
                    bloodOxygen = acquireVitalSigns.oxygenOut;
                    bodyTemperature = acquireVitalSigns.temperatureOut;
                    stepCount = acquireVitalSigns.stepsOut;
                };
                out alertLevel : AlertSeverity;
                out alertMsg : AlertMessage;
            }
            
            then decide;
                if processData.alertLevel == AlertSeverity::critical then handleCritical;
                if processData.alertLevel == AlertSeverity::warning then handleWarning;
                if processData.alertLevel == AlertSeverity::normal then handleNormal;
            
            action handleCritical {
                action sendCriticalAlert : wireless.transmitAlert {
                    in alert = processData.alertMsg;
                }
                action displayCriticalAlert : display.showAlert {
                    in alert = processData.alertMsg;
                }
            }
            then monitoringLoop;
            
            action handleWarning {
                action sendWarningAlert : wireless.transmitAlert {
                    in alert = processData.alertMsg;
                }
                action displayWarningAlert : display.showAlert {
                    in alert = processData.alertMsg;
                }
            }
            then monitoringLoop;
            
            action handleNormal {
                action transmitNormalData : wireless.transmitTelemetry;
                action updateDisplay : display.showVitalSigns;
            }
            then monitoringLoop;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The VITAband shall continuously monitor user vital signs and provide 
               real-time health status information to users and healthcare providers. */
    }
    
    requirement def VitalSignsMonitoringRequirement {
        doc /* The VITAband shall continuously monitor heart rate, blood oxygen saturation, 
               body temperature, and physical activity. */
        
        require constraint heartRateRange {
            doc /* Heart rate shall be measured in the range 30-220 bpm with ±2 bpm accuracy */
        }
        
        require constraint oxygenRange {
            doc /* Blood oxygen saturation shall be measured in the range 70-100% with ±2% accuracy */
        }
        
        require constraint temperatureRange {
            doc /* Body temperature shall be measured in the range 35-42°C with ±0.1°C accuracy */
        }
    }
    
    requirement def AlertGenerationRequirement {
        doc /* The VITAband shall generate and transmit alerts when vital signs exceed safe thresholds. */
        
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = medium;
            }
            owner = "Clinical Safety Team";
        }
        
        require constraint criticalHeartRate {
            doc /* Critical alert when heart rate < 40 or > 180 bpm */
        }
        
        require constraint criticalOxygen {
            doc /* Critical alert when blood oxygen < 88% */
        }
        
        require constraint criticalTemperature {
            doc /* Critical alert when temperature < 35.5°C or > 39.5°C */
        }
    }
    
    requirement def DataTransmissionRequirement {
        doc /* The VITAband shall wirelessly transmit vital signs data and alerts 
               to authorized monitoring systems. */
        
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = medium;
                scheduleRisk = low;
            }
            owner = "Connectivity Team";
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Critical alerts shall be generated and transmitted within 3 seconds 
               of detecting an abnormal condition. */
        
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
            }
            owner = "Real-Time Systems Team";
        }
    }
    
    requirement def BatteryLifeRequirement {
        doc /* The VITAband shall operate continuously for at least 72 hours 
               on a single charge under normal usage conditions. */
        
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = low;
                scheduleRisk = low;
                costRisk = medium;
            }
            owner = "Power Systems Team";
        }
    }
    
    part vitabandSystem : VITAband;
    
    satisfy PrimaryFunctionRequirement by vitabandSystem.continuousHealthMonitoring;
    satisfy VitalSignsMonitoringRequirement by vitabandSystem.sensors;
    satisfy AlertGenerationRequirement by vitabandSystem.processor;
    satisfy DataTransmissionRequirement by vitabandSystem.wireless;
    satisfy ResponseTimeRequirement by vitabandSystem.continuousHealthMonitoring;
    satisfy BatteryLifeRequirement by vitabandSystem.powerMgmt;
}
