package BiometricMonitoringSystem {
    private import ScalarValues::*;

    package Definitions {
        attribute def HeartRateValue :> Real;
        attribute def BodyTemperatureValue :> Real;
        attribute def BloodOxygenValue :> Real;
        attribute def ActivityLevelValue :> Real;
        attribute def BatteryLevelValue :> Real;
        attribute def DeviceIdValue :> String;
        attribute def TimestampValue :> String;
        attribute def DistanceValue :> Real;
        attribute def DurationValue :> Real;

        enum def AlertSeverity {
            none;
            warning;
            critical;
        }

        item def BiometricDataPacket {
            attribute deviceId : DeviceIdValue;
            attribute timestamp : TimestampValue;
            attribute heartRate : HeartRateValue;
            attribute bodyTemperature : BodyTemperatureValue;
            attribute bloodOxygen : BloodOxygenValue;
            attribute activityLevel : ActivityLevelValue;
        }

        item def Alert {
            attribute timestamp : TimestampValue;
            attribute severity : AlertSeverity;
            attribute description : String;
        }

        port def WirelessTxPort {
            out item packet : BiometricDataPacket;
            out item alert : Alert;
        }

        port def WirelessRxPort {
            in item packet : BiometricDataPacket;
            in item alert : Alert;
        }

        part def RechargeableBatteryPack {
            attribute chargeLevel : BatteryLevelValue;
            attribute capacity : Real;
            port powerOut {
                out attribute power : Real;
            }
        }

        part def HeartRateSensor {
            port output {
                out attribute value : HeartRateValue;
            }
            port powerIn {
                in attribute power : Real;
            }
        }

        part def BodyTemperatureSensor {
            port output {
                out attribute value : BodyTemperatureValue;
            }
            port powerIn {
                in attribute power : Real;
            }
        }

        part def BloodOxygenSensor {
            port output {
                out attribute value : BloodOxygenValue;
            }
            port powerIn {
                in attribute power : Real;
            }
        }

        part def ActivityMonitor {
            port output {
                out attribute value : ActivityLevelValue;
            }
            port powerIn {
                in attribute power : Real;
            }
        }

        part def DataProcessor {
            port heartRateInput {
                in attribute value : HeartRateValue;
            }
            port bodyTemperatureInput {
                in attribute value : BodyTemperatureValue;
            }
            port bloodOxygenInput {
                in attribute value : BloodOxygenValue;
            }
            port activityInput {
                in attribute value : ActivityLevelValue;
            }
            port packetOutput {
                out item packet : BiometricDataPacket;
            }
            port alertOutput {
                out item alert : Alert;
            }
            port displayPacketOutput {
                out item packet : BiometricDataPacket;
            }
            port displayAlertOutput {
                out item alert : Alert;
            }
            port powerIn {
                in attribute power : Real;
            }
            attribute packetReady : Boolean;
            attribute analysisComplete : Boolean;
            attribute anomalyDetected : Boolean;
            perform action aggregateData;
            perform action analyzeData;
        }

        part def Display {
            port packetInput {
                in item packet : BiometricDataPacket;
            }
            port alertInput {
                in item alert : Alert;
            }
            port powerIn {
                in attribute power : Real;
            }
            perform action renderData;
        }

        part def WirelessTransceiver {
            port packetInput {
                in item packet : BiometricDataPacket;
            }
            port alertInput {
                in item alert : Alert;
            }
            port airPort : WirelessTxPort;
            port powerIn {
                in attribute power : Real;
            }
            attribute transmissionComplete : Boolean;
            perform action transmitData;
        }

        part def WirelessReceiver {
            port airPort : WirelessRxPort;
            port packetOutput {
                out item packet : BiometricDataPacket;
            }
            port alertOutput {
                out item alert : Alert;
            }
            port powerIn {
                in attribute power : Real;
            }
            attribute packetReceived : Boolean;
            attribute alertReceived : Boolean;
        }

        part def DataStorage {
            port packetInput {
                in item packet : BiometricDataPacket;
            }
            port alertInput {
                in item alert : Alert;
            }
            port powerIn {
                in attribute power : Real;
            }
            attribute archiveComplete : Boolean;
            perform action archiveData;
        }

        part def HubDisplay {
            port packetInput {
                in item packet : BiometricDataPacket;
            }
            port alertInput {
                in item alert : Alert;
            }
            port powerIn {
                in attribute power : Real;
            }
            attribute displayUpdateComplete : Boolean;
            perform action displayData;
        }

        part def AlertIndicator {
            port alertInput {
                in item alert : Alert;
            }
            port powerIn {
                in attribute power : Real;
            }
            attribute alertIndicationComplete : Boolean;
            perform action indicateAlert;
        }

        part def WearableDevice {
            attribute deviceId : DeviceIdValue;
            attribute lowBatteryThreshold : BatteryLevelValue = 20;
            attribute criticalBatteryThreshold : BatteryLevelValue = 5;
            part batteryPack : RechargeableBatteryPack;
            part heartRateSensor : HeartRateSensor;
            part bodyTemperatureSensor : BodyTemperatureSensor;
            part bloodOxygenSensor : BloodOxygenSensor;
            part activityMonitor : ActivityMonitor;
            part dataProcessor : DataProcessor;
            part display : Display;
            part wirelessTransceiver : WirelessTransceiver;
            port externalDataPort : WirelessTxPort;
            exhibit state wearableStates : WearableStates;
        }

        part def CentralMonitoringHub {
            part wirelessReceiver : WirelessReceiver;
            part storage : DataStorage;
            part display : HubDisplay;
            part alertIndicator : AlertIndicator;
            port externalDataPort : WirelessRxPort;
            exhibit state hubStates : HubStates;
        }

        state def WearableStates;
        state def HubStates;

        action def CollectSensorData;
        action def AggregateData {
            in attribute hr : HeartRateValue;
            in attribute temp : BodyTemperatureValue;
            in attribute spo2 : BloodOxygenValue;
            in attribute activity : ActivityLevelValue;
            out item packet : BiometricDataPacket;
        }
        action def AnalyzeData {
            in item packet : BiometricDataPacket;
            out item alert : Alert;
        }
        action def TransmitData {
            in item packet : BiometricDataPacket;
            in item alert : Alert;
        }
        action def ArchiveData {
            in item packet : BiometricDataPacket;
            in item alert : Alert;
        }
        action def DisplayData {
            in item packet : BiometricDataPacket;
            in item alert : Alert;
        }
        action def IndicateAlert {
            in item alert : Alert;
        }
        action def RenderData {
            in item packet : BiometricDataPacket;
            in item alert : Alert;
        }
        action def EnterLowPowerMode;
        action def ShutDown;

        requirement def HighAccuracySensorsRequirement {
            doc /* Sensors shall provide heart rate accuracy within 2 bpm, body temperature accuracy within 0.1 degrees, and blood oxygen accuracy within 2%. */
            attribute maxHeartRateError : Real = 2.0;
            attribute maxTempError : Real = 0.1;
            attribute maxSpo2Error : Real = 2.0;
        }

        requirement def StableWirelessConnectionRequirement {
            doc /* The wireless connection between wearable device and central monitoring hub shall remain stable up to 15 meters. */
            attribute maxDistance : Real = 15.0;
        }

        requirement def BatteryLifeRequirement {
            doc /* The wearable device shall operate for at least 48 hours on a single charge under normal monitoring conditions. */
            attribute minBatteryLife : Real = 48.0;
        }
    }

    private import Definitions::*;

    part biometricSystem {
        part wearableDevice : WearableDevice {
            :>> deviceId = "WD-001";

            action collectSensorData : CollectSensorData;
            action aggregateData : AggregateData;
            action analyzeData : AnalyzeData;
            action transmitData : TransmitData;
            action enterLowPowerMode : EnterLowPowerMode;
            action shutDown : ShutDown;

            connect heartRateSensor.output to dataProcessor.heartRateInput;
            connect bodyTemperatureSensor.output to dataProcessor.bodyTemperatureInput;
            connect bloodOxygenSensor.output to dataProcessor.bloodOxygenInput;
            connect activityMonitor.output to dataProcessor.activityInput;
            connect dataProcessor.packetOutput to wirelessTransceiver.packetInput;
            connect dataProcessor.alertOutput to wirelessTransceiver.alertInput;
            connect dataProcessor.displayPacketOutput to display.packetInput;
            connect dataProcessor.displayAlertOutput to display.alertInput;
            connect batteryPack.powerOut to heartRateSensor.powerIn;
            connect batteryPack.powerOut to bodyTemperatureSensor.powerIn;
            connect batteryPack.powerOut to bloodOxygenSensor.powerIn;
            connect batteryPack.powerOut to activityMonitor.powerIn;
            connect batteryPack.powerOut to dataProcessor.powerIn;
            connect batteryPack.powerOut to display.powerIn;
            connect batteryPack.powerOut to wirelessTransceiver.powerIn;
            connect wirelessTransceiver.airPort to externalDataPort;

            state wearableStates : WearableStates parallel {
                state operationalStates {
                    entry; then normalMonitoring;
                    state normalMonitoring {
                        entry collectSensorData;
                        do aggregateData;
                        exit analyzeData;
                    }
                    transition normalToProcessing
                        first normalMonitoring
                        accept when dataProcessor.packetReady
                        then dataProcessing;
                    state dataProcessing {
                        entry aggregateData;
                        do analyzeData;
                    }
                    transition processingToTransmission
                        first dataProcessing
                        accept when dataProcessor.analysisComplete
                        then wirelessTransmission;
                    state wirelessTransmission {
                        do transmitData;
                    }
                    transition transmissionToNormal
                        first wirelessTransmission
                        accept when wirelessTransceiver.transmissionComplete
                        then normalMonitoring;
                }
                state powerManagementStates {
                    entry; then fullPower;
                    state fullPower;
                    transition fullToLowPower
                        first fullPower
                        accept when batteryPack.chargeLevel < lowBatteryThreshold
                        then lowPowerMode;
                    state lowPowerMode {
                        do enterLowPowerMode;
                    }
                    transition lowToShutdown
                        first lowPowerMode
                        accept when batteryPack.chargeLevel < criticalBatteryThreshold
                        then shuttingDown;
                    transition lowToFullPower
                        first lowPowerMode
                        accept when batteryPack.chargeLevel >= lowBatteryThreshold
                        then fullPower;
                    state shuttingDown {
                        do shutDown;
                    }
                }
            }
        }

        part centralMonitoringHub : CentralMonitoringHub {
            action archiveData : ArchiveData;
            action displayData : DisplayData;
            action indicateAlert : IndicateAlert;

            connect wirelessReceiver.airPort to externalDataPort;
            connect wirelessReceiver.packetOutput to storage.packetInput;
            connect wirelessReceiver.alertOutput to storage.alertInput;
            connect wirelessReceiver.packetOutput to display.packetInput;
            connect wirelessReceiver.alertOutput to display.alertInput;
            connect wirelessReceiver.alertOutput to alertIndicator.alertInput;

            state hubStates : HubStates {
                entry; then idle;
                state idle;
                transition idleToArchiving
                    first idle
                    accept when wirelessReceiver.packetReceived
                    then archiving;
                transition idleToAlerting
                    first idle
                    accept when wirelessReceiver.alertReceived
                    then alerting;
                state archiving {
                    do archiveData;
                }
                transition archivingToIdle
                    first archiving
                    accept when storage.archiveComplete
                    then idle;
                state alerting {
                    entry displayData;
                    do indicateAlert;
                }
                transition alertingToIdle
                    first alerting
                    accept when alertIndicator.alertIndicationComplete
                    then idle;
            }
        }

        connect wearableDevice.externalDataPort to centralMonitoringHub.externalDataPort;

        requirement highAccuracySensors : HighAccuracySensorsRequirement;
        requirement stableWirelessConnection : StableWirelessConnectionRequirement;
        requirement batteryLife : BatteryLifeRequirement;

        satisfy highAccuracySensors by wearableDevice.heartRateSensor;
        satisfy highAccuracySensors by wearableDevice.bodyTemperatureSensor;
        satisfy highAccuracySensors by wearableDevice.bloodOxygenSensor;
        satisfy stableWirelessConnection by wearableDevice.wirelessTransceiver;
        satisfy batteryLife by wearableDevice.batteryPack;
    }
}
