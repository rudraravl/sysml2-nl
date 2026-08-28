package VITAbandSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def HeartRateValue :> Real;
        attribute def BloodOxygenSaturationValue :> Real;
        attribute def BodyTemperatureValue :> Real;
        attribute def StepCountValue :> Integer;
        attribute def BatteryLevelValue :> Real;
        
        item def Power;
        item def Alert {
            attribute alertType : String;
            attribute severity : String;
        }
        item def Telemetry {
            attribute heartRate : HeartRateValue;
            attribute spo2 : BloodOxygenSaturationValue;
            attribute bodyTemp : BodyTemperatureValue;
            attribute stepCount : StepCountValue;
        }
        
        action def MeasureHeartRate;
        action def MeasureSpO2;
        action def MeasureTemperature;
        action def CountSteps;
        action def AnalyzeVitals {
            in heartRate : HeartRateValue;
            in spo2 : BloodOxygenSaturationValue;
            in bodyTemp : BodyTemperatureValue;
            in stepCount : StepCountValue;
            out telemetry : Telemetry;
            out alert : Alert;
            out displayMsg : String;
        }
        action def RenderDisplay;
        action def TransmitData;
        action def DistributePower;
        
        part def HeartRateSensor {
            port powerIn : Power;
            port heartRateOut : HeartRateValue;
            perform action measure : MeasureHeartRate;
        }
        part def PulseOximeter {
            port powerIn : Power;
            port spo2Out : BloodOxygenSaturationValue;
            perform action measure : MeasureSpO2;
        }
        part def Thermometer {
            port powerIn : Power;
            port tempOut : BodyTemperatureValue;
            perform action measure : MeasureTemperature;
        }
        part def Accelerometer {
            port powerIn : Power;
            port stepCountOut : StepCountValue;
            perform action measure : CountSteps;
        }
        
        part def BiometricSensorSuite {
            port powerIn : Power;
            part heartRateSensor : HeartRateSensor;
            part pulseOximeter : PulseOximeter;
            part thermometer : Thermometer;
            part accelerometer : Accelerometer;
            port heartRateOut : HeartRateValue;
            port spo2Out : BloodOxygenSaturationValue;
            port tempOut : BodyTemperatureValue;
            port stepCountOut : StepCountValue;
            connect heartRateSensor.heartRateOut to heartRateOut;
            connect pulseOximeter.spo2Out to spo2Out;
            connect thermometer.tempOut to tempOut;
            connect accelerometer.stepCountOut to stepCountOut;
        }
        
        part def AnalyticsProcessor {
            port powerIn : Power;
            port heartRateIn : HeartRateValue;
            port spo2In : BloodOxygenSaturationValue;
            port tempIn : BodyTemperatureValue;
            port stepCountIn : StepCountValue;
            port telemetryOut : Telemetry;
            port alertOut : Alert;
            port displayOut : String;
            attribute minHeartRate : HeartRateValue = 40;
            attribute maxHeartRate : HeartRateValue = 180;
            attribute minSpo2 : BloodOxygenSaturationValue = 90;
            perform action analyzeVitals : AnalyzeVitals;
            exhibit state healthStatus {
                entry; then normal;
                state normal;
                accept when heartRateIn < minHeartRate or spo2In < minSpo2
                    then warning;
                state warning;
                accept when heartRateIn < minHeartRate and spo2In < minSpo2
                    then critical;
                state critical;
                accept when heartRateIn >= minHeartRate and spo2In >= minSpo2
                    then normal;
            }
        }
        
        part def Display {
            port powerIn : Power;
            port displayIn : String;
            perform action renderDisplay : RenderDisplay;
        }
        
        part def WirelessTransmitter {
            port powerIn : Power;
            port telemetryIn : Telemetry;
            port alertIn : Alert;
            port telemetryOut : Telemetry;
            port alertWirelessOut : Alert;
            perform action transmit : TransmitData;
        }
        
        part def PowerManagementUnit {
            port batteryIn : Power;
            port powerOut : Power;
            attribute minBatteryLifeHours : Integer = 72;
            perform action distributePower : DistributePower;
        }
        
        part def RechargeableBattery {
            port powerOut : Power;
            attribute capacity : BatteryLevelValue = 100;
        }
        
        part def ExternalSystem {
            port telemetryIn : Telemetry;
            port alertIn : Alert;
        }
        
        requirement def BatteryLifeRequirement {
            doc /* The power management unit shall provide at least 72 hours of continuous operation on a single charge. */
            subject powerManagement : PowerManagementUnit;
            attribute requiredLife : Integer = 72;
        }
        
        requirement def AlertResponseTimeRequirement {
            doc /* Critical alerts shall be transmitted within 5 seconds of detection. */
            subject processor : AnalyticsProcessor;
            subject transmitter : WirelessTransmitter;
            attribute maxResponseTimeSeconds : Real = 5.0;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part vitaband {
            part sensorSuite : BiometricSensorSuite;
            part processor : AnalyticsProcessor;
            part display : Display;
            part transmitter : WirelessTransmitter;
            part powerManagement : PowerManagementUnit;
            part battery : RechargeableBattery;
            ref externalSystem : ExternalSystem;
            
            connect sensorSuite.heartRateOut to processor.heartRateIn;
            connect sensorSuite.spo2Out to processor.spo2In;
            connect sensorSuite.tempOut to processor.tempIn;
            connect sensorSuite.stepCountOut to processor.stepCountIn;
            
            connect processor.telemetryOut to transmitter.telemetryIn;
            connect processor.alertOut to transmitter.alertIn;
            connect processor.displayOut to display.displayIn;
            
            connect transmitter.telemetryOut to externalSystem.telemetryIn;
            connect transmitter.alertWirelessOut to externalSystem.alertIn;
            
            connect battery.powerOut to powerManagement.batteryIn;
            connect powerManagement.powerOut to processor.powerIn;
            connect powerManagement.powerOut to sensorSuite.powerIn;
            connect powerManagement.powerOut to display.powerIn;
            connect powerManagement.powerOut to transmitter.powerIn;
        }
        
        requirement batteryLife : BatteryLifeRequirement {
            subject powerManagement = vitaband.powerManagement;
        }
        
        requirement alertResponse : AlertResponseTimeRequirement {
            subject processor = vitaband.processor;
            subject transmitter = vitaband.transmitter;
        }
    }
}
