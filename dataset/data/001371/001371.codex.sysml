package BLEEnvironmentalMonitoringSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Percent;
    attribute def dBm;
    attribute def ByteCount;
    attribute def Millisecond;
    attribute def Second;
    attribute def Meter;
    attribute def Volt;
    attribute def Milliampere;
    attribute def Celsius;
    attribute def Pascal;

    item def SensorSample {
        attribute temperature : Celsius;
        attribute humidity : Percent;
        attribute pressure : Pascal;
        attribute batteryVoltage : Volt;
        attribute sampleTime : Second;
        attribute sequenceNumber : Integer;
    }

    item def BLEAdvertisement {
        attribute deviceId : String;
        attribute serviceUuid : String;
        attribute payloadLength : ByteCount;
        attribute transmitPower : dBm;
        attribute sampleSummary : SensorSample;
    }

    item def GATTReadRequest {
        attribute centralId : String;
        attribute characteristicUuid : String;
        attribute requestTime : Second;
    }

    item def GATTReadResponse {
        attribute peripheralId : String;
        attribute characteristicUuid : String;
        attribute valuePayload : SensorSample;
        attribute responseTime : Second;
    }

    item def BatteryEnergy {
        attribute voltage : Volt;
        attribute current : Milliampere;
        attribute stateOfCharge : Percent;
    }

    port def BLEPeripheralRadioPort {
        out item advertisement : BLEAdvertisement;
        in item readRequest : GATTReadRequest;
        out item readResponse : GATTReadResponse;
    }

    port def BLECentralRadioPort {
        in item advertisement : BLEAdvertisement;
        out item readRequest : GATTReadRequest;
        in item readResponse : GATTReadResponse;
    }

    port def SensorDataPort {
        out item sample : SensorSample;
    }

    port def PowerOutputPort {
        out item batteryEnergy : BatteryEnergy;
    }

    port def PowerInputPort {
        in item batteryEnergy : BatteryEnergy;
    }

    part def EnvironmentalSensorModule {
        attribute measurementPeriod : Second = 30;
        attribute temperatureAccuracy : Celsius = 0.5;
        attribute humidityAccuracy : Percent = 2.0;
        attribute pressureAccuracy : Pascal = 100;

        port dataOut : SensorDataPort;
        port powerIn : PowerInputPort;

        action senseEnvironment {
            out item measuredSample : SensorSample;
            first start;
            then readTemperature;
            then readHumidity;
            then readPressure;
            then timestampSample;
            then publishSample;
            then done;

            action readTemperature;
            action readHumidity;
            action readPressure;
            action timestampSample;
            action publishSample;
        }
    }

    part def BLEController {
        attribute deviceName : String = "BLE-Env-Monitor";
        attribute serviceUuid : String = "181A";
        attribute sampleCharacteristicUuid : String = "2A6E";
        attribute advertisingInterval : Millisecond = 1000;
        attribute connectionInterval : Millisecond = 50;
        attribute maximumPayloadSize : ByteCount = 31;
        attribute nominalTransmitPower : dBm = 0;
        attribute connectionRange : Meter = 20;

        port sensorIn : SensorDataPort;
        port radio : BLEPeripheralRadioPort;
        port powerIn : PowerInputPort;

        part advertisingService {
            attribute includeDeviceId : Boolean = true;
            attribute includeBatteryVoltage : Boolean = true;
            attribute includeLatestSampleSummary : Boolean = true;
        }

        part gattServer {
            attribute supportsRead : Boolean = true;
            attribute supportsNotify : Boolean = true;
            attribute encryptedAccessRequired : Boolean = false;
        }

        action advertiseLatestSample {
            in item latestSample : SensorSample;
            out item advertisement : BLEAdvertisement;
            first encodeServiceUuid;
            then encodeDeviceIdentifier;
            then encodeSensorSummary;
            then setTransmitPower;
            then emitAdvertisement;
            then done;

            action encodeServiceUuid;
            action encodeDeviceIdentifier;
            action encodeSensorSummary;
            action setTransmitPower;
            action emitAdvertisement;
        }

        action serveReadRequest {
            in item request : GATTReadRequest;
            in item latestSample : SensorSample;
            out item response : GATTReadResponse;
            first validateCharacteristic;
            then loadLatestSample;
            then encodeGattResponse;
            then transmitGattResponse;
            then done;

            action validateCharacteristic;
            action loadLatestSample;
            action encodeGattResponse;
            action transmitGattResponse;
        }

        state bleOperatingState {
            entry action initializeController;
            state PoweredOff;
            state Standby;
            state Advertising;
            state Connected;
            state LowPowerSleep;
            state Fault;

            initial then PoweredOff;

            transition PowerApplied
                first PoweredOff
                then Standby;

            transition BeginAdvertising
                first Standby
                then Advertising;

            transition CentralConnected
                first Advertising
                then Connected;

            transition CentralDisconnected
                first Connected
                then Advertising;

            transition AdvertisingTimeout
                first Advertising
                then LowPowerSleep;

            transition WakeTimerExpired
                first LowPowerSleep
                then Advertising;

            transition CriticalBattery
                first Standby
                then Fault;

            transition CriticalBatteryWhileAdvertising
                first Advertising
                then Fault;

            transition CriticalBatteryWhileConnected
                first Connected
                then Fault;
        }
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 3.0;
        attribute minimumOperatingVoltage : Volt = 2.1;
        attribute capacity : Milliampere = 220;
        attribute stateOfCharge : Percent = 100;

        port powerOut : PowerOutputPort;

        action supplyPower {
            out item energy : BatteryEnergy;
            first measureVoltage;
            then measureLoadCurrent;
            then estimateStateOfCharge;
            then provideEnergy;
            then done;

            action measureVoltage;
            action measureLoadCurrent;
            action estimateStateOfCharge;
            action provideEnergy;
        }
    }

    part def MobileGatewayApplication {
        attribute centralId : String = "mobile-gateway-01";
        attribute scanWindow : Millisecond = 5000;
        attribute expectedServiceUuid : String = "181A";
        attribute cloudUploadPeriod : Second = 300;

        port radio : BLECentralRadioPort;

        part localDataStore {
            attribute maximumStoredSamples : Integer = 10000;
            attribute retainedDays : Integer = 30;
        }

        action scanAndCollect {
            in item receivedAdvertisement : BLEAdvertisement;
            out item readRequest : GATTReadRequest;
            in item readResponse : GATTReadResponse;
            first scanForAdvertisements;
            then filterByServiceUuid;
            then estimateLinkQuality;
            then requestCurrentSample;
            then storeSample;
            then done;

            action scanForAdvertisements;
            action filterByServiceUuid;
            action estimateLinkQuality;
            action requestCurrentSample;
            action storeSample;
        }

        state gatewayState {
            state Idle;
            state Scanning;
            state ReadingGatt;
            state StoringData;
            state UploadingSummary;
            state GatewayFault;

            initial then Idle;

            transition StartScan
                first Idle
                then Scanning;

            transition AdvertisementMatched
                first Scanning
                then ReadingGatt;

            transition ReadComplete
                first ReadingGatt
                then StoringData;

            transition StoreComplete
                first StoringData
                then Idle;

            transition UploadTimerExpired
                first Idle
                then UploadingSummary;

            transition UploadComplete
                first UploadingSummary
                then Idle;

            transition CommunicationError
                first ReadingGatt
                then Scanning;

            transition StorageFailure
                first StoringData
                then GatewayFault;
        }
    }

    part def BLEEnvironmentalMonitor {
        attribute primaryFunction : String =
            "Periodically measure local environmental conditions and make the latest sensor data available wirelessly to nearby Bluetooth Low Energy central devices using advertisements and GATT read services.";

        part battery : BatteryPack;
        part sensor : EnvironmentalSensorModule;
        part ble : BLEController;
        part gateway : MobileGatewayApplication;

        connect battery.powerOut to sensor.powerIn;
        connect battery.powerOut to ble.powerIn;
        connect sensor.dataOut to ble.sensorIn;
        connect ble.radio to gateway.radio;

        action monitorEnvironment {
            first powerSubsystems;
            then acquireSensorSample;
            then updateBlePayload;
            then advertiseAvailability;
            then respondToCentralRead;
            then gatewayStoresData;
            then done;

            action powerSubsystems;
            action acquireSensorSample;
            action updateBlePayload;
            action advertiseAvailability;
            action respondToCentralRead;
            action gatewayStoresData;
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        doc /* The system shall provide low power wireless access to environmental measurements using Bluetooth Low Energy. */
        subject monitor : BLEEnvironmentalMonitor;
        require constraint {
            monitor.primaryFunction ==
            "Periodically measure local environmental conditions and make the latest sensor data available wirelessly to nearby Bluetooth Low Energy central devices using advertisements and GATT read services."
        }
    }

    requirement def BLEAdvertisingRequirement {
        doc /* The peripheral shall advertise its environmental sensing service at an interval suitable for discovery by nearby central devices. */
        subject controller : BLEController;
        require constraint {
            controller.advertisingInterval <= 1000 [Millisecond]
        }
    }

    requirement def BLEPayloadRequirement {
        doc /* The BLE advertising payload shall fit within the legacy BLE advertising payload size. */
        subject controller : BLEController;
        require constraint {
            controller.maximumPayloadSize <= 31 [ByteCount]
        }
    }

    requirement def BLERangeRequirement {
        doc /* The system shall support reliable discovery by a central device within normal room-scale range. */
        subject controller : BLEController;
        require constraint {
            controller.connectionRange >= 10 [Meter]
        }
    }

    requirement def MeasurementPeriodRequirement {
        doc /* The system shall acquire environmental measurements at least once every sixty seconds during normal operation. */
        subject sensor : EnvironmentalSensorModule;
        require constraint {
            sensor.measurementPeriod <= 60 [Second]
        }
    }

    requirement def BatteryVoltageRequirement {
        doc /* The system shall remain operational while the battery voltage is above the minimum BLE controller and sensor operating voltage. */
        subject battery : BatteryPack;
        require constraint {
            battery.nominalVoltage >= battery.minimumOperatingVoltage
        }
    }

    requirement def TemperatureAccuracyRequirement {
        doc /* The temperature measurement error shall not exceed one degree Celsius for normal indoor monitoring. */
        subject sensor : EnvironmentalSensorModule;
        require constraint {
            sensor.temperatureAccuracy <= 1.0 [Celsius]
        }
    }

    requirement def HumidityAccuracyRequirement {
        doc /* The humidity measurement error shall not exceed five percent relative humidity for normal indoor monitoring. */
        subject sensor : EnvironmentalSensorModule;
        require constraint {
            sensor.humidityAccuracy <= 5.0 [Percent]
        }
    }

    requirement def GatewayCollectionRequirement {
        doc /* The central application shall discover BLE advertisements, request the latest sample using GATT, and store the returned measurement. */
        subject gateway : MobileGatewayApplication;
        require constraint {
            gateway.scanWindow >= 1000 [Millisecond]
        }
    }

    satisfy HighLevelPrimaryFunctionRequirement by BLEEnvironmentalMonitor;
    satisfy BLEAdvertisingRequirement by BLEController;
    satisfy BLEPayloadRequirement by BLEController;
    satisfy BLERangeRequirement by BLEController;
    satisfy MeasurementPeriodRequirement by EnvironmentalSensorModule;
    satisfy BatteryVoltageRequirement by BatteryPack;
    satisfy TemperatureAccuracyRequirement by EnvironmentalSensorModule;
    satisfy HumidityAccuracyRequirement by EnvironmentalSensorModule;
    satisfy GatewayCollectionRequirement by MobileGatewayApplication;
}