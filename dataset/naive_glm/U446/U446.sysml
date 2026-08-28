package VITAband {
    import ScalarValues::*;
    import SI::*;
    import Quantities::*;

    attribute def HeartRate :> Integer {
        doc "Unit: beats per minute (bpm)";
    }
    attribute def OxygenSaturation :> Real {
        doc "Unit: percentage (%)";
    }
    attribute def Temperature :> Real {
        doc "Unit: degrees Celsius (degC)";
    }
    attribute def StepCount :> Integer {
        doc "Unit: steps";
    }
    attribute def BatteryLevel :> Real {
        doc "Unit: percentage (%)";
    }
    attribute def Hours :> Integer {
        doc "Unit: hours";
    }
    attribute def Voltage :> Real {
        doc "Unit: volts (V)";
    }

    enum def AlertLevel {
        NORMAL;
        WARNING;
        CRITICAL;
    }

    item def VitalSignData {
        attribute heartRate : HeartRate;
        attribute oxygenSaturation : OxygenSaturation;
        attribute bodyTemp : Temperature;
        attribute steps : StepCount;
        attribute timestamp : String;
    }

    item def TelemetryData {
        attribute vitals : VitalSignData;
        attribute deviceId : String;
    }

    item def AlertData {
        attribute alertType : AlertLevel;
        attribute vitalData : VitalSignData;
        attribute message : String;
    }

    item def DisplayData {
        attribute heartRate : HeartRate;
        attribute oxygenSaturation : OxygenSaturation;
        attribute bodyTemp : Temperature;
        attribute steps : StepCount;
        attribute alertStatus : AlertLevel;
    }

    attribute def ThresholdConfig {
        attribute minCriticalHR : HeartRate = 40;
        attribute maxCriticalHR : HeartRate = 180;
        attribute minCriticalSpO2 : OxygenSaturation = 90;
        attribute minCriticalTemp : Temperature = 35.0;
        attribute maxCriticalTemp : Temperature = 38.5;
        attribute minWarningHR : HeartRate = 50;
        attribute maxWarningHR : HeartRate = 160;
        attribute minWarningSpO2 : OxygenSaturation = 92;
    }

    port def VitalSignPort {
        out item vitals : VitalSignData;
    }

    port def DisplayPort {
        out item displayData : DisplayData;
    }

    port def AlertPort {
        out item alert : AlertData;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryData;
    }

    port def ConfigOutPort {
        out item thresholds : ThresholdConfig;
    }

    port def PowerOutPort {
        out attribute voltage : Voltage = 3.7;
    }

    port def BatteryStatusPort {
        out attribute chargeLevel : BatteryLevel;
    }

    port def WirelessExternalPort {
        out item telemetry : TelemetryData;
        out item alert : AlertData;
    }

    requirement def ContinuousTrackingReq {
        doc "The VITAband shall continuously track the user's vital signs in real-time.";
    }
    requirement def RemoteConfigReq {
        doc "The system shall support remote configuration of safety thresholds.";
    }
    requirement def AlertResponseTimeReq {
        doc "Critical alerts shall be transmitted within 2 seconds of detecting a threshold breach.";
    }
    requirement def BatteryLifeReq {
        doc "The VITAband shall provide at least 72 hours of continuous operation on a single charge.";
    }

    part def VITAband {
        doc "Wearable health monitoring system similar to a medical-grade smartwatch.";
        
        requirement continuousTracking : ContinuousTrackingReq;
        requirement remoteConfig : RemoteConfigReq;
        requirement alertResponse : AlertResponseTimeReq;
        requirement batteryLife : BatteryLifeReq;

        part sensorSuite : SensorSuite;
        part processor : AnalyticsProcessor;
        part display : DisplayUnit;
        part wirelessModule : WirelessCommModule;
        part powerMgmt : PowerManagementUnit;
        part battery : RechargeableBattery;
        part externalSystem : ExternalSystem;

        connection vitalsConn from sensorSuite.vitalsOut to processor.vitalsIn;
        connection displayConn from processor.displayOut to display.displayIn;
        connection alertConn from processor.alertOut to wirelessModule.alertIn;
        connection telemetryConn from processor.telemetryOut to wirelessModule.telemetryIn;
        connection configConn from externalSystem.configOut to wirelessModule.configIn;
        connection configPassConn from wirelessModule.configOut to processor.configIn;
        
        connection powerToProcessor from powerMgmt.powerOut to processor.powerIn;
        connection powerToSensors from powerMgmt.powerOut to sensorSuite.powerIn;
        connection powerToDisplay from powerMgmt.powerOut to display.powerIn;
        connection powerToWireless from powerMgmt.powerOut to wirelessModule.powerIn;
        
        connection batteryConn from battery.statusOut to powerMgmt.batteryIn;
        connection wirelessConn from wirelessModule.externalOut to externalSystem.wirelessIn;
    }

    part def SensorSuite {
        port vitalsOut : VitalSignPort;
        port powerIn : ~PowerOutPort;

        part heartRateSensor : HeartRateSensor;
        part pulseOximeter : PulseOximeter;
        part thermometer : Thermometer;
        part accelerometer : Accelerometer;

        action def collectVitals {
            doc "Collects data from sub-sensors and outputs via vitalsOut.";
        }
    }

    part def HeartRateSensor {
        doc "Measures heart rate in beats per minute.";
    }
    
    part def PulseOximeter {
        doc "Measures blood oxygen saturation.";
    }
    
    part def Thermometer {
        doc "Measures body temperature.";
    }
    
    part def Accelerometer {
        doc "Tracks physical activity and counts steps.";
    }

    part def AnalyticsProcessor {
        port vitalsIn : ~VitalSignPort;
        port displayOut : DisplayPort;
        port alertOut : AlertPort;
        port telemetryOut : TelemetryPort;
        port configIn : ~ConfigOutPort;
        port powerIn : ~PowerOutPort;

        attribute thresholds : ThresholdConfig;
        attribute currentVitals : VitalSignData;
        attribute currentAlertLevel : AlertLevel = AlertLevel::NORMAL;

        state processorState {
            state Idle;
            state Monitoring {
                entry / readSensors();
                do / updateDisplay();
                do / sendTelemetry();
            }
            state Alerting {
                entry / triggerAlarm();
                do / updateDisplay();
                do / sendAlert();
            }

            transition init from Idle to Monitoring;
            
            transition criticalAlert from Monitoring to Alerting 
                when (currentVitals.heartRate <= thresholds.minCriticalHR || 
                      currentVitals.heartRate >= thresholds.maxCriticalHR ||
                      currentVitals.oxygenSaturation <= thresholds.minCriticalSpO2 ||
                      currentVitals.bodyTemp <= thresholds.minCriticalTemp ||
                      currentVitals.bodyTemp >= thresholds.maxCriticalTemp);

            transition criticalRecovered from Alerting to Monitoring 
                when (currentVitals.heartRate > thresholds.minCriticalHR && 
                      currentVitals.heartRate < thresholds.maxCriticalHR &&
                      currentVitals.oxygenSaturation > thresholds.minCriticalSpO2 &&
                      currentVitals.bodyTemp > thresholds.minCriticalTemp &&
                      currentVitals.bodyTemp < thresholds.maxCriticalTemp);
        }

        action def readSensors {
            doc "Reads vitals from the input port and updates currentVitals.";
        }
        action def updateDisplay {
            doc "Formats and sends DisplayData to the displayOut port.";
        }
        action def sendTelemetry {
            doc "Sends routine telemetry to the telemetryOut port.";
        }
        action def triggerAlarm {
            doc "Updates currentAlertLevel and prepares alert data.";
        }
        action def sendAlert {
            doc "Sends AlertData to the alertOut port.";
        }
    }

    part def DisplayUnit {
        port displayIn : ~DisplayPort;
        port powerIn : ~PowerOutPort;
        
        state displayState {
            state Off;
            state On;
            transition from Off to On when (powerIn.voltage > 0);
        }
    }

    part def WirelessCommModule {
        port telemetryIn : ~TelemetryPort;
        port alertIn : ~AlertPort;
        port configIn : ~ConfigOutPort;
        port configOut : ConfigOutPort;
        port externalOut : WirelessExternalPort;
        port powerIn : ~PowerOutPort;

        action def transmitData {
            doc "Transmits telemetry and alerts to external systems.";
        }
    }

    part def PowerManagementUnit {
        port powerOut : PowerOutPort;
        port batteryIn : ~BatteryStatusPort;
        attribute minBatteryLife : Hours = 72;

        state powerState {
            state Discharging;
            state LowBattery;
            transition from Discharging to LowBattery when (batteryIn.chargeLevel < 20);
            transition from LowBattery to Discharging when (batteryIn.chargeLevel >= 20);
        }
    }

    part def RechargeableBattery {
        port statusOut : BatteryStatusPort;
        attribute capacity : Hours = 72;
        attribute currentCharge : BatteryLevel = 100;
    }

    part def ExternalSystem {
        port wirelessIn : ~WirelessExternalPort;
        port configOut : ConfigOutPort;
        
        action def receiveAlert {
            doc "Alerts caregiver or hospital monitoring station.";
        }
    }
}
