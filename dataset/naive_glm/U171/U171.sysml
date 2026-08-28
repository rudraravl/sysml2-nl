package BiometricMonitoringSystem {
    import ScalarValues::*;

    /* ==================== Units ==================== */
    unit beatsPerMinute;
    unit degreesCelsius;
    unit percent;
    unit meters;
    unit hours;
    unit millivolts;
    unit dBm;
    unit milliamperes;

    /* ==================== Value Types ==================== */
    value type HeartRate :> Real {
        unit beatsPerMinute;
    }
    value type BodyTemperature :> Real {
        unit degreesCelsius;
    }
    value type SpO2Value :> Real {
        unit percent;
    }
    value type ActivityValue :> Real {
        unit percent;
    }
    value type BatteryLevel :> Real {
        unit percent;
    }
    value type WirelessRange :> Real {
        unit meters;
    }
    value type BatteryLifeDuration :> Real {
        unit hours;
    }
    value type VoltageValue :> Real {
        unit millivolts;
    }
    value type SignalStrengthValue :> Real {
        unit dBm;
    }
    value type CurrentValue :> Real {
        unit milliamperes;
    }

    /* ==================== Enumerations ==================== */
    enum def AlertType {
        HeartRateLow;
        HeartRateHigh;
        TemperatureHigh;
        SpO2Low;
        LowBattery;
        SensorFault;
    }
    enum def AlertSeverity {
        Info;
        Warning;
        Critical;
        Emergency;
    }

    /* ==================== Item Types ==================== */
    item def BiometricDataPacket {
        attribute deviceId : String;
        attribute sequenceNumber : Integer;
        attribute timestamp : Real;
        attribute heartRate : HeartRate;
        attribute bodyTemperature : BodyTemperature;
        attribute bloodOxygen : SpO2Value;
        attribute activityLevel : ActivityValue;
        attribute batteryLevel : BatteryLevel;
    }
    item def HealthAlert {
        attribute deviceId : String;
        attribute timestamp : Real;
        attribute alertType : AlertType;
        attribute severity : AlertSeverity;
        attribute message : String;
        attribute associatedPacket : BiometricDataPacket;
    }

    /* ==================== Port Definitions ==================== */
    port def HeartRatePort {
        out heartRate : HeartRate;
    }
    port def TemperaturePort {
        out bodyTemp : BodyTemperature;
    }
    port def SpO2Port {
        out bloodO2 : SpO2Value;
    }
    port def ActivityPort {
        out activity : ActivityValue;
    }
    port def DataPacketOutPort {
        out packet : BiometricDataPacket;
    }
    port def DataPacketInPort {
        in packet : BiometricDataPacket;
    }
    port def AlertOutPort {
        out alert : HealthAlert;
    }
    port def AlertInPort {
        in alert : HealthAlert;
    }
    port def BatteryPort {
        out level : BatteryLevel;
        out voltage : VoltageValue;
        out currentDraw : CurrentValue;
    }

    /* ==================== Sensor Parts ==================== */
    part def HeartRateSensor {
        port hrOut : HeartRatePort;
        attribute samplingRateHz : Real = 1.0;
        attribute accuracyBpm : HeartRate = 2.0;
        attribute measurementRangeMin : HeartRate = 25;
        attribute measurementRangeMax : HeartRate = 220;
        attribute isOperational : Boolean = true;

        action def MeasureHeartRate {
            in samplingInterval : Real;
            out measuredRate : HeartRate;
        }
        action def Calibrate {
            out calibrationOffset : HeartRate;
        }
    }

    part def BodyTemperatureSensor {
        port tempOut : TemperaturePort;
        attribute samplingRateHz : Real = 0.2;
        attribute accuracyCelsius : BodyTemperature = 0.2;
        attribute measurementRangeMin : BodyTemperature = 20;
        attribute measurementRangeMax : BodyTemperature = 45;
        attribute isOperational : Boolean = true;

        action def MeasureTemperature {
            in samplingInterval : Real;
            out measuredTemp : BodyTemperature;
        }
    }

    part def BloodOxygenSensor {
        port spo2Out : SpO2Port;
        attribute samplingRateHz : Real = 0.5;
        attribute accuracyPercent : SpO2Value = 2.0;
        attribute measurementRangeMin : SpO2Value = 70;
        attribute measurementRangeMax : SpO2Value = 100;
        attribute isOperational : Boolean = true;

        action def MeasureSpO2 {
            in samplingInterval : Real;
            out measuredSpO2 : SpO2Value;
        }
    }

    part def ActivityMonitor {
        port actOut : ActivityPort;
        attribute samplingRateHz : Real = 4.0;
        attribute stepCount : Integer = 0;
        attribute isOperational : Boolean = true;

        action def MeasureActivity {
            in samplingInterval : Real;
            out measuredActivity : ActivityValue;
        }
        action def ResetStepCount {
            out resetValue : Integer;
        }
    }

    /* ==================== Battery Pack ==================== */
    part def BatteryPack {
        port batOut : BatteryPort;
        attribute currentLevel : BatteryLevel = 100;
        attribute nominalVoltage : VoltageValue = 3700;
        attribute capacitymAh : Real = 500;
        attribute isCharging : Boolean = false;
        attribute chargeCycles : Integer = 0;
        attribute internalResistance : Real = 0.15;

        action def Discharge {
            in consumptionRate : Real;
            in duration : Real;
            out level : BatteryLevel;
            out voltage : VoltageValue;
        }
        action def Recharge {
            in chargeCurrent : Real;
            in duration : Real;
            out level : BatteryLevel;
        }
        action def EstimateRemainingLife {
            out remainingHours : BatteryLifeDuration;
        }
    }

    /* ==================== Data Processor ==================== */
    part def DataProcessor {
        port hrIn : ~HeartRatePort;
        port tempIn : ~TemperaturePort;
        port spo2In : ~SpO2Port;
        port actIn : ~ActivityPort;
        port batIn : ~BatteryPort;

        port dataOut : DataPacketOutPort;
        port alertOut : AlertOutPort;
        port displayDataOut : DataPacketOutPort;
        port displayAlertOut : AlertOutPort;

        attribute deviceId : String = "WB-001";
        attribute sequenceCounter : Integer = 0;
        attribute minSafeHeartRate : HeartRate = 40;
        attribute maxSafeHeartRate : HeartRate = 180;
        attribute minSafeSpO2 : SpO2Value = 90;
        attribute maxSafeBodyTemp : BodyTemperature = 38.5;
        attribute lowBatteryThreshold : BatteryLevel = 15;
        attribute processingLatencyMs : Real = 50;

        action def AggregateData {
            in hr : HeartRate;
            in bt : BodyTemperature;
            in spo2 : SpO2Value;
            in act : ActivityValue;
            in batLvl : BatteryLevel;
            in deviceIdentifier : String;
            out packet : BiometricDataPacket;
        }
        action def DetectAnomalies {
            in packet : BiometricDataPacket;
            out alert : HealthAlert;
            out anomalyDetected : Boolean;
        }
        action def GenerateAlert {
            in alertType : AlertType;
            in severity : AlertSeverity;
            in message : String;
            in packet : BiometricDataPacket;
            out alert : HealthAlert;
        }
        action def TimeStampPacket {
            in rawPacket : BiometricDataPacket;
            out stampedPacket : BiometricDataPacket;
        }
    }

    /* ==================== Display ==================== */
    part def Display {
        port displayDataIn : DataPacketInPort;
        port displayAlertIn : AlertInPort;

        attribute backlightBrightness : Real = 50;
        attribute screenWidth : Real = 1.5;
        attribute screenHeight : Real = 1.5;
        attribute isBacklightOn : Boolean = true;
        attribute refreshRateHz : Real = 2.0;

        action def RenderBiometricData {
            in packet : BiometricDataPacket;
        }
        action def RenderAlert {
            in alert : HealthAlert;
        }
        action def AdjustBacklight {
            in brightness : Real;
        }
    }

    /* ==================== Wireless Transceiver ==================== */
    part def WirelessTransceiver {
        port txDataIn : DataPacketInPort;
        port txAlertIn : AlertInPort;
        port txDataOut : DataPacketOutPort;
        port txAlertOut : AlertOutPort;

        attribute maxRangeMeters : WirelessRange = 15;
        attribute currentSignalStrength : SignalStrengthValue = -40;
        attribute isConnected : Boolean = true;
        attribute protocol : String = "BLE_5.0";
        attribute transmitPower : Real = 3.0;
        attribute dataRateKbps : Real = 250;

        action def TransmitData {
            in packet : BiometricDataPacket;
            out success : Boolean;
        }
        action def TransmitAlert {
            in alert : HealthAlert;
            out success : Boolean;
        }
        action def EstablishConnection {
            in targetHubId : String;
            out success : Boolean;
            out signalStr : SignalStrengthValue;
        }
        action def MonitorConnection {
            out signalStr : SignalStrengthValue;
            out isStable : Boolean;
        }
    }

    /* ==================== Central Monitoring Hub ==================== */
    part def CentralMonitoringHub {
        port hubDataIn : DataPacketInPort;
        port hubAlertIn : AlertInPort;

        attribute hubId : String = "HUB-001";
        attribute isOnline : Boolean = true;
        attribute archiveCapacity : Integer = 10000;
        attribute dataReceived : Boolean = false;
        attribute alertReceived : Boolean = false;
        attribute archiveComplete : Boolean = false;
        attribute alertDisplayed : Boolean = false;

        part dataArchive {
            attribute storedPackets : BiometricDataPacket[0..*];
            attribute storedAlerts : HealthAlert[0..*];
            attribute currentEntryCount : Integer = 0;
            attribute maxEntries : Integer = 10000;
        }

        part hubDisplay {
            attribute screenSize : Real = 7.0;
            attribute resolution : String = "1080x1920";
            attribute isBacklightOn : Boolean = true;
        }

        part hubAlertManager {
            attribute pendingAlerts : HealthAlert[0..*];
            attribute activeEmergencyAlerts : HealthAlert[0..*];
        }

        action def ReceiveData {
            in packet : BiometricDataPacket;
        }
        action def ArchiveData {
            in packet : BiometricDataPacket;
        }
        action def DisplayEmergencyAlert {
            in alert : HealthAlert;
        }
        action def ReviewHistoricalData {
            in startTime : Real;
            in endTime : Real;
            out packets : BiometricDataPacket[0..*];
        }
        action def GenerateReport {
            in startTime : Real;
            in endTime : Real;
            out reportText : String;
        }
        action def NotifyCaregiver {
            in alert : HealthAlert;
            out notificationSent : Boolean;
        }

        state def HubOperationState {
            state Idle;
            state Receiving;
            state Archiving;
            state AlertDisplay;
            state ReportGeneration;

            transition from Idle to Receiving when dataReceived;
            transition from Receiving to Archiving;
            transition from Archiving to Idle when archiveComplete;
            transition from Idle to AlertDisplay when alertReceived;
            transition from AlertDisplay to Idle when alertDisplayed;
            transition from Idle to ReportGeneration;
            transition from ReportGeneration to Idle;
        }
    }

    /* ==================== Wearable Device ==================== */
    part def WearableDevice {
        attribute deviceId : String = "WB-001";
        attribute firmwareVersion : String = "1.0.0";
        attribute deviceWeight : Real = 35;
        attribute sensorDataReady : Boolean = false;
        attribute dataPacketReady : Boolean = false;
        attribute transmissionComplete : Boolean = false;
        attribute currentPowerMode : String = "Normal";

        part battery : BatteryPack;
        part heartRateSensor : HeartRateSensor;
        part bodyTempSensor : BodyTemperatureSensor;
        part bloodOxygenSensor : BloodOxygenSensor;
        part activityMonitor : ActivityMonitor;
        part processor : DataProcessor;
        part display : Display;
        part transceiver : WirelessTransceiver;

        connect heartRateSensor.hrOut to processor.hrIn;
        connect bodyTempSensor.tempOut to processor.tempIn;
        connect bloodOxygenSensor.spo2Out to processor.spo2In;
        connect activityMonitor.actOut to processor.actIn;
        connect battery.batOut to processor.batIn;

        connect processor.dataOut to transceiver.txDataIn;
        connect processor.alertOut to transceiver.txAlertIn;

        connect processor.displayDataOut to display.displayDataIn;
        connect processor.displayAlertOut to display.displayAlertIn;

        state def PowerManagement {
            state Normal {
                entry;
            }
            state LowPower {
                entry;
            }
            state Critical {
                entry;
            }
            state Shutdown {
                entry;
            }

            transition from Normal to LowPower when battery.currentLevel <= 20;
            transition from LowPower to Critical when battery.currentLevel <= 10;
            transition from Critical to Shutdown when battery.currentLevel <= 5;
            transition from Shutdown to Normal when battery.isCharging;
        }

        state def MonitoringStateMachine {
            state Measuring {
                entry;
            }
            state Processing {
                entry;
            }
            state Transmitting {
                entry;
            }

            transition from Measuring to Processing when sensorDataReady;
            transition from Processing to Transmitting when dataPacketReady;
            transition from Transmitting to Measuring when transmissionComplete;
        }
    }

    /* ==================== Biometric System ==================== */
    part def BiometricSystem {
        attribute systemId : String = "BIO-SYS-001";
        attribute isOperational : Boolean = true;

        part wearable : WearableDevice;
        part hub : CentralMonitoringHub;

        connect wearable.transceiver.txDataOut to hub.hubDataIn;
        connect wearable.transceiver.txAlertOut to hub.hubAlertIn;
    }

    /* ==================== Requirements ==================== */
    requirement def HighAccuracySensors {
        doc "All biometric sensors shall maintain measurement accuracy within specified tolerances for reliable health monitoring.";

        subject hrSensor : HeartRateSensor;
        subject tempSensor : BodyTemperatureSensor;
        subject spo2Sensor : BloodOxygenSensor;
        subject actMonitor : ActivityMonitor;

        constraint { hrSensor.accuracyBpm <= 2.0 }
        constraint { tempSensor.accuracyCelsius <= 0.2 }
        constraint { spo2Sensor.accuracyPercent <= 2.0 }
        constraint { hrSensor.measurementRangeMin <= 30 }
        constraint { hrSensor.measurementRangeMax >= 220 }
    }

    requirement def WirelessRangeRequirement {
        doc "The wireless transceiver shall maintain a stable connection with the central hub at distances up to 15 meters.";
        subject tx : WirelessTransceiver;
        attribute requiredRange : WirelessRange = 15;
        constraint { tx.maxRangeMeters >= 15 }
        constraint { tx.protocol == "BLE_5.0" }
    }

    requirement def BatteryLifeRequirement {
        doc "The wearable device battery shall support continuous operation for at least 48 hours on a single full charge under normal monitoring conditions.";
        subject bat : BatteryPack;
        attribute requiredDuration : BatteryLifeDuration = 48;
        constraint { bat.capacitymAh >= 500 }
        constraint { bat.nominalVoltage >= 3700 }
    }

    requirement def ContinuousMonitoringRequirement {
        doc "The system shall provide continuous real-time monitoring of user vital signs including heart rate, body temperature, blood oxygen saturation, and activity level.";
        subject wearableDev : WearableDevice;
        subject hubDev : CentralMonitoringHub;

        constraint { wearableDev.heartRateSensor.samplingRateHz >= 1.0 }
        constraint { wearableDev.bloodOxygenSensor.samplingRateHz >= 0.5 }
        constraint { wearableDev.bodyTempSensor.samplingRateHz >= 0.2 }
        constraint { wearableDev.activityMonitor.samplingRateHz >= 2.0 }
    }

    requirement def RealTimeAlertingRequirement {
        doc "The system shall detect biometric anomalies in real-time and generate appropriate alerts displayed on both the wearable device and the central monitoring hub.";
        subject proc : DataProcessor;
        subject hub1 : CentralMonitoringHub;

        constraint { proc.minSafeHeartRate == 40 }
        constraint { proc.maxSafeHeartRate == 180 }
        constraint { proc.minSafeSpO2 == 90 }
        constraint { proc.maxSafeBodyTemp == 38.5 }
        constraint { proc.processingLatencyMs <= 100 }
    }

    requirement def DataArchivingRequirement {
        doc "The central monitoring hub shall receive, archive, and display all incoming health data packets and emergency alerts for caregiver review.";
        subject hub2 : CentralMonitoringHub;

        constraint { hub2.archiveCapacity >= 10000 }
        constraint { hub2.dataArchive.maxEntries >= 10000 }
    }

    requirement def PowerManagementRequirement {
        doc "The wearable device shall automatically enter low-power mode when battery is low and shut down to protect hardware when battery is critically low.";
        subject wearableDev2 : WearableDevice;
        subject bat2 : BatteryPack;

        constraint { bat2.currentLevel <= 20 implies wearableDev2.currentPowerMode == "LowPower" }
        constraint { bat2.currentLevel <= 5 implies wearableDev2.currentPowerMode == "Shutdown" }
    }

    requirement def ReliabilityRequirement {
        doc "The biometric monitoring system shall maintain reliable operation with fault-tolerant sensor communication and automatic reconnection to the central hub.";
        subject tx2 : WirelessTransceiver;
        subject sys : BiometricSystem;

        constraint { tx2.isConnected == true }
        constraint { sys.isOperational == true }
    }

    /* ==================== System Instance ==================== */
    part biometricSystem : BiometricSystem;
}
