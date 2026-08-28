package AllJoynSmartHome {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type PowerState :> ScalarValue {
        attribute status : PowerStatusEnum;
        enum PowerStatusEnum { off, on };
    }

    value type Brightness :> Real {
        :>> unit = 'percent';
        attribute value : Real(0 .. 100);
    }

    value type ColorTemperature :> Integer {
        :>> unit = 'K';
        attribute value : Integer(1000 .. 10000);
    }

    value type Temperature :> Real {
        :>> unit = 'degC';
    }

    value type Humidity :> Real {
        :>> unit = 'percent';
        attribute value : Real(0 .. 100);
    }

    value type AirQualityIndex :> Integer {
        :>> unit = 'AQI';
        attribute value : Integer(0 .. 500);
    }

    value type TargetTemperature :> Real {
        :>> unit = 'degC';
        attribute value : Real(10 .. 35);
    }

    value type SignalStrength :> Real {
        :>> unit = 'dBm';
    }

    value type Latency :> Real {
        :>> unit = 'ms';
    }

    enum ThermostatMode { off, heat, cool, auto, eco }

    enum NetworkType { wifi, bluetooth, ethernet }

    enum SecurityLevel { none, authenticated, encrypted }

    enum DeviceCategory { lighting, sensor, climate, controller }

    // ===== Item Types =====

    item def DeviceAnnouncement {
        attribute deviceId : String;
        attribute deviceName : String;
        attribute manufacturer : String;
        attribute category : DeviceCategory;
        attribute services : String[*];
        attribute network : NetworkType;
        attribute timestamp : Time;
    }

    item def ControlCommand {
        attribute targetDeviceId : String;
        attribute commandType : String;
        attribute payload : String;
        attribute security : SecurityLevel = SecurityLevel::encrypted;
        attribute sequenceId : Integer;
    }

    item def CommandResponse {
        attribute sequenceId : Integer;
        attribute success : Boolean;
        attribute message : String;
    }

    item def SensorReading {
        attribute deviceId : String;
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute airQuality : AirQualityIndex;
        attribute timestamp : Time;
    }

    item def ClimateAdjustment {
        attribute sourceSensorId : String;
        attribute targetMode : ThermostatMode;
        attribute targetTemp : TargetTemperature;
        attribute reason : String;
    }

    item def DiscoveryResult {
        attribute deviceId : String;
        attribute deviceName : String;
        attribute category : DeviceCategory;
        attribute capabilities : String[*];
        attribute network : NetworkType;
        attribute signal : SignalStrength;
    }

    // ===== Port Definitions =====

    port def AllJoynBusPort {
        attribute busAddress : String;
        attribute security : SecurityLevel;
        in item announcement : DeviceAnnouncement;
        in item command : ControlCommand;
        out item response : CommandResponse;
        out item reading : SensorReading;
        out item discovery : DiscoveryResult;
    }

    port def NetworkPort {
        attribute networkType : NetworkType;
        attribute macAddress : String;
        attribute active : Boolean;
        in item rxAnnouncement : DeviceAnnouncement;
        in item rxCommand : ControlCommand;
        out item txAnnouncement : DeviceAnnouncement;
        out item txCommand : ControlCommand;
        out item txResponse : CommandResponse;
        out item txReading : SensorReading;
    }

    port def LightControlPort {
        in item command : ControlCommand;
        out item response : CommandResponse;
        out item announcement : DeviceAnnouncement;
    }

    port def SensorPublishPort {
        out item reading : SensorReading;
        out item announcement : DeviceAnnouncement;
    }

    port def ThermostatControlPort {
        in item command : ControlCommand;
        in item reading : SensorReading;
        out item response : CommandResponse;
        out item announcement : DeviceAnnouncement;
        out item adjustment : ClimateAdjustment;
    }

    port def AppControlPort {
        in item discovery : DiscoveryResult;
        in item response : CommandResponse;
        out item command : ControlCommand;
    }

    // ===== Interfaces =====

    interface def DeviceDiscoveryInterface {
        end provider : AllJoynBusPort;
        end consumer : AllJoynBusPort;
        flow announcement from provider to consumer;
    }

    interface def CommandRoutingInterface {
        end sender : AllJoynBusPort;
        end receiver : AllJoynBusPort;
        flow command from sender to receiver;
        flow response from receiver to sender;
    }

    interface def SensorDataInterface {
        end sensor : AllJoynBusPort;
        end consumer : AllJoynBusPort;
        flow reading from sensor to consumer;
    }

    interface def NetworkTransportInterface {
        end device : NetworkPort;
        end daemon : NetworkPort;
        flow txAnnouncement from device to daemon;
        flow rxAnnouncement from daemon to device;
        flow txCommand from device to daemon;
        flow rxCommand from daemon to device;
        flow txResponse from device to daemon;
        flow txReading from device to daemon;
    }

    // ===== AllJoyn Daemon =====

    part def AllJoynDaemon {
        attribute daemonId : String = "aj-daemon-01";
        attribute version : String = "17.04";
        attribute offlineCapable : Boolean = true;
        attribute maxDevices : Integer = 256;
        attribute activeSessions : Integer;

        port busPort : AllJoynBusPort;
        port wifiPort : NetworkPort {
            :>> networkType = NetworkType::wifi;
            :>> macAddress = "00:1A:2B:3C:4D:01";
        }
        port bluetoothPort : NetworkPort {
            :>> networkType = NetworkType::bluetooth;
            :>> macAddress = "00:1A:2B:3C:4D:02";
        }
        port ethernetPort : NetworkPort {
            :>> networkType = NetworkType::ethernet;
            :>> macAddress = "00:1A:2B:3C:4D:03";
        }

        part discoveryService {
            attribute discoveredDevices : String[*];
            action discover {
                in item announcement : DeviceAnnouncement;
                out item discovery : DiscoveryResult;
            }
        }

        part sessionManager {
            attribute activeSessions : Integer = 0;
            attribute securityLevel : SecurityLevel = SecurityLevel::encrypted;
            action establishSession {
                in item deviceId : String;
                out item sessionId : String;
            }
            action terminateSession {
                in item sessionId : String;
            }
        }

        part messageRouter {
            attribute routingTable : String[*];
            action routeCommand {
                in item command : ControlCommand;
                out item forwarded : ControlCommand;
            }
            action routeResponse {
                in item response : CommandResponse;
                out item forwarded : CommandResponse;
            }
            action routeReading {
                in item reading : SensorReading;
                out item forwarded : SensorReading;
            }
        }

        part securityEngine {
            attribute encryptionEnabled : Boolean = true;
            attribute authenticationRequired : Boolean = true;
            action authenticate {
                in item deviceId : String;
                out item authenticated : Boolean;
            }
            action encrypt {
                in item payload : String;
                out item encryptedPayload : String;
            }
            action decrypt {
                in item encryptedPayload : String;
                out item payload : String;
            }
        }

        state daemonStateMachine {
            entry action { activeSessions = 0; }
            state Initializing;
            state Ready;
            state Operating;
            state Degraded;
            state Offline;

            transition init from Initializing to Ready
                when (wifiPort.active or ethernetPort.active)
                do action { log("Daemon ready"); };

            transition startOp from Ready to Operating
                when (activeSessions > 0);

            transition degrade from Operating to Degraded
                when (wifiPort.active == false and bluetoothPort.active == false)
                do action { log("Network degraded"); };

            transition recover from Degraded to Operating
                when (wifiPort.active or ethernetPort.active);

            transition goOffline from Operating to Offline
                when (wifiPort.active == false and bluetoothPort.active == false and ethernetPort.active == false);

            transition reconnect from Offline to Ready
                when (wifiPort.active or ethernetPort.active or bluetoothPort.active);
        }

        action handleAnnouncement {
            in item announcement : DeviceAnnouncement;
            out item discovery : DiscoveryResult;
            do {
                discoveryService.discover(announcement, discovery);
                sessionManager.establishSession(announcement.deviceId, ?);
            }
        }

        action routeMessage {
            in item command : ControlCommand;
            out item response : CommandResponse;
            do {
                securityEngine.decrypt(command.payload, ?);
                messageRouter.routeCommand(command, ?);
                // forward to target device
                // receive response
                securityEngine.encrypt(response.message, ?);
            }
        }
    }

    // ===== Smart Device Base =====

    part def SmartDevice {
        attribute deviceId : String;
        attribute deviceName : String;
        attribute manufacturer : String;
        attribute category : DeviceCategory;
        attribute firmwareVersion : String;
        attribute networkPreference : NetworkType;
        attribute securityLevel : SecurityLevel = SecurityLevel::encrypted;

        port networkPort : NetworkPort;
        port busPort : AllJoynBusPort;

        action announce {
            out item announcement : DeviceAnnouncement;
            do {
                announcement = DeviceAnnouncement{
                    deviceId = deviceId,
                    deviceName = deviceName,
                    manufacturer = manufacturer,
                    category = category,
                    services = {},
                    network = networkPreference,
                    timestamp = now()
                };
            }
        }

        action joinBus {
            do {
                networkPort.active = true;
            }
        }

        state deviceLifecycle {
            state PoweredOff;
            state Booting;
            state Announcing;
            state Connected;
            state Active;
            state Disconnected;

            transition powerOn from PoweredOff to Booting
                when (powerApplied == true);

            transition bootComplete from Booting to Announcing
                when (firmwareLoaded == true)
                do action { joinBus(); };

            transition announced from Announcing to Connected
                when (sessionEstablished == true);

            transition activate from Connected to Active
                when (ready == true);

            transition disconnect from Active to Disconnected
                when (networkPort.active == false);

            transition reconnect from Disconnected to Announcing
                when (networkPort.active == true);
        }

        attribute powerApplied : Boolean = false;
        attribute firmwareLoaded : Boolean = false;
        attribute sessionEstablished : Boolean = false;
        attribute ready : Boolean = false;
    }

    // ===== Smart Light Bulb =====

    part def SmartLightBulb :> SmartDevice {
        :>> category = DeviceCategory::lighting;
        attribute powerState : PowerState;
        attribute brightness : Brightness = 100;
        attribute colorTemp : ColorTemperature = 2700;
        attribute supportsDimming : Boolean = true;
        attribute supportsColorTemp : Boolean = true;

        port lightControlPort : LightControlPort;

        action turnOn {
            do { powerState.status = PowerState::PowerStatusEnum::on; }
        }

        action turnOff {
            do { powerState.status = PowerState::PowerStatusEnum::off; }
        }

        action setBrightness {
            in item level : Brightness;
            do { brightness = level; }
        }

        action setColorTemperature {
            in item temp : ColorTemperature;
            do { colorTemp = temp; }
        }

        action processCommand {
            in item command : ControlCommand;
            out item response : CommandResponse;
            do {
                if (command.commandType == "turnOn") {
                    turnOn();
                    response = CommandResponse{ sequenceId = command.sequenceId, success = true, message = "Light on" };
                } else if (command.commandType == "turnOff") {
                    turnOff();
                    response = CommandResponse{ sequenceId = command.sequenceId, success = true, message = "Light off" };
                } else if (command.commandType == "setBrightness") {
                    setBrightness(Brightness{ value = command.payload.toReal() });
                    response = CommandResponse{ sequenceId = command.sequenceId, success = true, message = "Brightness set" };
                } else if (command.commandType == "setColorTemp") {
                    setColorTemperature(ColorTemperature{ value = command.payload.toInteger() });
                    response = CommandResponse{ sequenceId = command.sequenceId, success = true, message = "Color temp set" };
                } else {
                    response = CommandResponse{ sequenceId = command.sequenceId, success = false, message = "Unknown command" };
                }
            }
        }

        state lightStateMachine {
            state Off;
            state On;
            state Dimming;
            state ColorAdjusting;

            transition powerOn from Off to On
                when (powerState.status == PowerState::PowerStatusEnum::on)
                do action { brightness = 100; };

            transition powerOff from On to Off
                when (powerState.status == PowerState::PowerStatusEnum::off)
                do action { brightness = 0; };

            transition startDim from On to Dimming
                when (brightness != 100 and brightness != 0);

            transition endDim from Dimming to On
                when (dimComplete == true);

            transition startColor from On to ColorAdjusting
                when (colorTemp != 2700);

            transition endColor from ColorAdjusting to On
                when (colorComplete == true);

            transition emergencyOff from Dimming to Off
                when (powerState.status == PowerState::PowerStatusEnum::off);

            transition emergencyOff2 from ColorAdjusting to Off
                when (powerState.status == PowerState::PowerStatusEnum::off);
        }

        attribute dimComplete : Boolean = false;
        attribute colorComplete : Boolean = false;
    }

    part def PhilipsHueBulb :> SmartLightBulb {
        :>> manufacturer = "Philips";
        :>> deviceName = "Philips Hue";
        :>> firmwareVersion = "1.46.2";
        :>> networkPreference = NetworkType::wifi;
        attribute modelNumber : String = "LCA001";
        attribute maxLumens : Integer = 800;
    }

    part def LIFXBulb :> SmartLightBulb {
        :>> manufacturer = "LIFX";
        :>> deviceName = "LIFX A60";
        :>> firmwareVersion = "3.70";
        :>> networkPreference = NetworkType::wifi;
        attribute modelNumber : String = "LHA60";
        attribute maxLumens : Integer = 1100;
        attribute supportsInfrared : Boolean = true;
    }

    // ===== Environment Sensor =====

    part def EnvironmentSensor :> SmartDevice {
        :>> category = DeviceCategory::sensor;
        :>> manufacturer = "Nest";
        :>> deviceName = "Nest Environment Sensor";
        :>> firmwareVersion = "2.1.0";
        :>> networkPreference = NetworkType::wifi;

        attribute currentTemperature : Temperature;
        attribute currentHumidity : Humidity;
        attribute currentAirQuality : AirQualityIndex;
        attribute samplingInterval : Time = 60 [s];
        attribute lastReadingTime : Time;

        port sensorPublishPort : SensorPublishPort;

        action sampleEnvironment {
            out item reading : SensorReading;
            do {
                currentTemperature = readTemperature();
                currentHumidity = readHumidity();
                currentAirQuality = readAirQuality();
                reading = SensorReading{
                    deviceId = deviceId,
                    temperature = currentTemperature,
                    humidity = currentHumidity,
                    airQuality = currentAirQuality,
                    timestamp = now()
                };
                lastReadingTime = now();
            }
        }

        action readTemperature {
            out item temp : Temperature;
            do { temp = Temperature{ value = 22.5 }; }
        }

        action readHumidity {
            out item hum : Humidity;
            do { hum = Humidity{ value = 45.0 }; }
        }

        action readAirQuality {
            out item aq : AirQualityIndex;
            do { aq = AirQualityIndex{ value = 42 }; }
        }

        action publishReading {
            in item reading : SensorReading;
            do {
                sensorPublishPort.reading = reading;
            }
        }

        state sensorStateMachine {
            state Idle;
            state Sampling;
            state Publishing;
            state Sleeping;

            transition wake from Sleeping to Sampling
                when (samplingTimerExpired == true)
                do action { samplingTimerExpired = false; };

            transition collect from Sampling to Publishing
                when (sampleComplete == true)
                do action { sampleComplete = false; };

            transition published from Publishing to Sleeping
                when (publishComplete == true)
                do action { publishComplete = false; };

            transition initial from Idle to Sleeping
                when (initialized == true);
        }

        attribute samplingTimerExpired : Boolean = false;
        attribute sampleComplete : Boolean = false;
        attribute publishComplete : Boolean = false;
        attribute initialized : Boolean = false;
    }

    // ===== Smart Thermostat =====

    part def SmartThermostat :> SmartDevice {
        :>> category = DeviceCategory::climate;
        :>> manufacturer = "Honeywell";
        :>> deviceName = "Honeywell Thermostat";
        :>> firmwareVersion = "4.0.1";
        :>> networkPreference = NetworkType::wifi;

        attribute currentMode : ThermostatMode = ThermostatMode::off;
        attribute targetTemp : TargetTemperature = 21;
        attribute currentTemp : Temperature;
        attribute connectedSensorId : String;
        attribute hysteresis : Temperature = 0.5 [degC];
        attribute ecoThreshold : Temperature = 18 [degC];

        port thermostatControlPort : ThermostatControlPort;

        action setMode {
            in item mode : ThermostatMode;
            do { currentMode = mode; }
        }

        action setTargetTemperature {
            in item temp : TargetTemperature;
            do { targetTemp = temp; }
        }

        action receiveSensorReading {
            in item reading : SensorReading;
            do {
                currentTemp = reading.temperature;
                connectedSensorId = reading.deviceId;
            }
        }

        action evaluateClimate {
            out item adjustment : ClimateAdjustment;
            do {
                if (currentTemp.value < targetTemp.value - hysteresis.value) {
                    currentMode = ThermostatMode::heat;
                    adjustment = ClimateAdjustment{
                        sourceSensorId = connectedSensorId,
                        targetMode = ThermostatMode::heat,
                        targetTemp = targetTemp,
                        reason = "Below target"
                    };
                } else if (currentTemp.value > targetTemp.value + hysteresis.value) {
                    currentMode = ThermostatMode::cool;
                    adjustment = ClimateAdjustment{
                        sourceSensorId = connectedSensorId,
                        targetMode = ThermostatMode::cool,
                        targetTemp = targetTemp,
                        reason = "Above target"
                    };
                } else if (currentTemp.value < ecoThreshold.value) {
                    currentMode = ThermostatMode::eco;
                    adjustment = ClimateAdjustment{
                        sourceSensorId = connectedSensorId,
                        targetMode = ThermostatMode::eco,
                        targetTemp = targetTemp,
                        reason = "Eco mode activated"
                    };
                }
            }
        }

        action processCommand {
            in item command : ControlCommand;
            out item response : CommandResponse;
            do {
                if (command.commandType == "setMode") {
                    setMode(ThermostatMode::byName(command.payload));
                    response = CommandResponse{ sequenceId = command.sequenceId, success = true, message = "Mode set" };
                } else if (command.commandType == "setTargetTemp") {
                    setTargetTemperature(TargetTemperature{ value = command.payload.toReal() });
                    response = CommandResponse{ sequenceId = command.sequenceId, success = true, message = "Target temp set" };
                } else {
                    response = CommandResponse{ sequenceId = command.sequenceId, success = false, message = "Unknown command" };
                }
            }
        }

        state thermostatStateMachine {
            state Off;
            state Heating;
            state Cooling;
            state Eco;
            state Auto;

            transition toHeat from Off to Heating
                when (currentMode == ThermostatMode::heat);

            transition toCool from Off to Cooling
                when (currentMode == ThermostatMode::cool);

            transition toEco from Off to Eco
                when (currentMode == ThermostatMode::eco);

            transition toAuto from Off to Auto
                when (currentMode == ThermostatMode::auto);

            transition heatToOff from Heating to Off
                when (currentMode == ThermostatMode::off);

            transition coolToOff from Cooling to Off
                when (currentMode == ThermostatMode::off);

            transition ecoToOff from Eco to Off
                when (currentMode == ThermostatMode::off);

            transition autoToOff from Auto to Off
                when (currentMode == ThermostatMode::off);

            transition autoToHeat from Auto to Heating
                when (currentMode == ThermostatMode::auto and currentTemp.value < targetTemp.value - hysteresis.value);

            transition autoToCool from Auto to Cooling
                when (currentMode == ThermostatMode::auto and currentTemp.value > targetTemp.value + hysteresis.value);

            transition heatToAuto from Heating to Auto
                when (currentMode == ThermostatMode::auto and currentTemp.value >= targetTemp.value - hysteresis.value);

            transition coolToAuto from Cooling to Auto
                when (currentMode == ThermostatMode::auto and currentTemp.value <= targetTemp.value + hysteresis.value);
        }
    }

    // ===== Mobile Control App =====

    part def MobileControlApp {
        attribute appId : String = "mobile-app-01";
        attribute appName : String = "AllJoyn Home Control";
        attribute platform : String;
        attribute version : String = "2.3.0";
        attribute discoveredDevices : DiscoveryResult[*];
        attribute selectedDeviceId : String;
        attribute networkPreference : NetworkType = NetworkType::wifi;

        port appControlPort : AppControlPort;
        port busPort : AllJoynBusPort;

        action scanNetwork {
            out item results : DiscoveryResult[*];
            do {
                // Trigger discovery via daemon
                results = discoveredDevices;
            }
        }

        action displayDevices {
            in item results : DiscoveryResult[*];
            do { discoveredDevices = results; }
        }

        action selectDevice {
            in item deviceId : String;
            do { selectedDeviceId = deviceId; }
        }

        action sendCommand {
            in item commandType : String;
            in item payload : String;
            out item command : ControlCommand;
            do {
                command = ControlCommand{
                    targetDeviceId = selectedDeviceId,
                    commandType = commandType,
                    payload = payload,
                    security = SecurityLevel::encrypted,
                    sequenceId = nextSequenceId()
                };
            }
        }

        action receiveResponse {
            in item response : CommandResponse;
            do {
                if (response.success) {
                    log("Command succeeded: " + response.message);
                } else {
                    log("Command failed: " + response.message);
                }
            }
        }

        action nextSequenceId {
            out item id : Integer;
            do { id = sequenceCounter + 1; sequenceCounter = id; }
        }

        attribute sequenceCounter : Integer = 0;

        state appStateMachine {
            state Launched;
            state Scanning;
            state Browsing;
            state Controlling;
            state WaitingResponse;
            state Error;

            transition startScan from Launched to Scanning
                when (scanRequested == true)
                do action { scanRequested = false; };

            transition scanDone from Scanning to Browsing
                when (scanComplete == true)
                do action { scanComplete = false; };

            transition select from Browsing to Controlling
                when (deviceSelected == true)
                do action { deviceSelected = false; };

            transition sendCmd from Controlling to WaitingResponse
                when (commandSent == true)
                do action { commandSent = false; };

            transition responseReceived from WaitingResponse to Controlling
                when (responseReady == true)
                do action { responseReady = false; };

            transition errorState from WaitingResponse to Error
                when (timeout == true);

            transition retry from Error to Browsing
                when (retryRequested == true)
                do action { retryRequested = false; };
        }

        attribute scanRequested : Boolean = false;
        attribute scanComplete : Boolean = false;
        attribute deviceSelected : Boolean = false;
        attribute commandSent : Boolean = false;
        attribute responseReady : Boolean = false;
        attribute timeout : Boolean = false;
        attribute retryRequested : Boolean = false;
    }

    // ===== Smart Home Ecosystem Assembly =====

    part def SmartHomeEcosystem {
        attribute ecosystemId : String = "smart-home-001";
        attribute offlineMode : Boolean = true;
        attribute cloudIndependent : Boolean = true;

        part daemon : AllJoynDaemon;

        part philipsBulb : PhilipsHueBulb {
            :>> deviceId = "light-philips-01";
        }

        part lifxBulb : LIFXBulb {
            :>> deviceId = "light-lifx-02";
        }

        part envSensor : EnvironmentSensor {
            :>> deviceId = "sensor-nest-01";
        }

        part thermostat : SmartThermostat {
            :>> deviceId = "thermostat-honeywell-01";
        }

        part mobileApp : MobileControlApp {
            :>> platform = "Android";
        }

        // Network connections to daemon
        connection def NetworkLink {
            end deviceSide : NetworkPort;
            end daemonSide : NetworkPort;
        }

        connection : NetworkLink connect philipsBulb.networkPort to daemon.wifiPort;
        connection : NetworkLink connect lifxBulb.networkPort to daemon.wifiPort;
        connection : NetworkLink connect envSensor.networkPort to daemon.wifiPort;
        connection : NetworkLink connect thermostat.networkPort to daemon.wifiPort;
        connection : NetworkLink connect mobileApp.busPort to daemon.busPort;

        // Bus connections for discovery and command routing
        connection def BusLink {
            end deviceEnd : AllJoynBusPort;
            end daemonEnd : AllJoynBusPort;
        }

        connection : BusLink connect philipsBulb.busPort to daemon.busPort;
        connection : BusLink connect lifxBulb.busPort to daemon.busPort;
        connection : BusLink connect envSensor.busPort to daemon.busPort;
        connection : BusLink connect thermostat.busPort to daemon.busPort;

        // Sensor to thermostat data flow via daemon
        interface : SensorDataInterface connect envSensor.busPort to thermostat.busPort;

        // App to light command flow via daemon
        interface : CommandRoutingInterface connect mobileApp.busPort to philipsBulb.busPort;
        interface : CommandRoutingInterface connect mobileApp.busPort to lifxBulb.busPort;
        interface : CommandRoutingInterface connect mobileApp.busPort to thermostat.busPort;

        // Discovery interfaces
        interface : DeviceDiscoveryInterface connect philipsBulb.busPort to mobileApp.busPort;
        interface : DeviceDiscoveryInterface connect lifxBulb.busPort to mobileApp.busPort;
        interface : DeviceDiscoveryInterface connect envSensor.busPort to mobileApp.busPort;
        interface : DeviceDiscoveryInterface connect thermostat.busPort to mobileApp.busPort;
    }

    // ===== Requirements =====

    requirement def LocalCommunicationRequirement {
        doc /* The system shall enable direct device-to-device communication on a local network without relying on a central cloud server. */
        attribute cloudDependency : Boolean = false;
        attribute maxLatency : Latency = 200 [ms];
        satisfy by SmartHomeEcosystem;
    }

    requirement def MultiNetworkSupportRequirement {
        doc /* The AllJoyn daemon shall manage traffic over Wi-Fi, Bluetooth, and Ethernet simultaneously. */
        attribute supportedNetworks : NetworkType[3] = { NetworkType::wifi, NetworkType::bluetooth, NetworkType::ethernet };
        satisfy by AllJoynDaemon;
    }

    requirement def DeviceDiscoveryRequirement {
        doc /* Devices shall announce their presence and services on the network, and the control app shall discover them. */
        attribute announcementInterval : Time = 30 [s];
        satisfy by SmartDevice;
        satisfy by MobileControlApp;
    }

    requirement def SecureSessionRequirement {
        doc /* All communication sessions shall be authenticated and encrypted. */
        attribute minSecurityLevel : SecurityLevel = SecurityLevel::encrypted;
        satisfy by AllJoynDaemon;
        satisfy by SmartDevice;
    }

    requirement def LightControlRequirement {
        doc /* Smart light bulbs shall support on/off, brightness, and color temperature control. */
        attribute supportedCommands : String[4] = { "turnOn", "turnOff", "setBrightness", "setColorTemp" };
        satisfy by SmartLightBulb;
    }

    requirement def EnvironmentMonitoringRequirement {
        doc /* Environment sensors shall monitor temperature, humidity, and air quality and publish readings to the network. */
        attribute samplingInterval : Time = 60 [s];
        satisfy by EnvironmentSensor;
    }

    requirement def ClimateRegulationRequirement {
        doc /* The thermostat shall use data from the environment sensor to automatically regulate climate. */
        attribute hysteresisRange : Temperature = 0.5 [degC];
        satisfy by SmartThermostat;
    }

    requirement def ManufacturerInteroperabilityRequirement {
        doc /* The system shall support devices from different manufacturers interoperably. */
        attribute manufacturerAgnostic : Boolean = true;
        satisfy by SmartHomeEcosystem;
    }

    requirement def OfflineOperationRequirement {
        doc /* The system shall function entirely offline without internet connectivity. */
        attribute internetRequired : Boolean = false;
        satisfy by SmartHomeEcosystem;
    }

    requirement def AppControlRequirement {
        doc /* The mobile control app shall scan the network, display device capabilities, and send control commands. */
        satisfy by MobileControlApp;
    }

    requirement spec SmartHomeRequirements {
        requirement r1 : LocalCommunicationRequirement;
        requirement r2 : MultiNetworkSupportRequirement;
        requirement r3 : DeviceDiscoveryRequirement;
        requirement r4 : SecureSessionRequirement;
        requirement r5 : LightControlRequirement;
        requirement r6 : EnvironmentMonitoringRequirement;
        requirement r7 : ClimateRegulationRequirement;
        requirement r8 : ManufacturerInteroperabilityRequirement;
        requirement r9 : OfflineOperationRequirement;
        requirement r10 : AppControlRequirement;
    }

    // ===== Verification Actions =====

    action def VerifyOfflineOperation {
        in item ecosystem : SmartHomeEcosystem;
        out item result : Boolean;
        do {
            result = ecosystem.cloudIndependent and ecosystem.offlineMode;
        }
    }

    action def VerifySecurity {
        in item daemon : AllJoynDaemon;
        out item result : Boolean;
        do {
            result = daemon.securityEngine.encryptionEnabled and daemon.securityEngine.authenticationRequired;
        }
    }

    action def VerifyDiscovery {
        in item app : MobileControlApp;
        in item device : SmartDevice;
        out item result : Boolean;
        do {
            result = device.busPort.isConnected() and app.busPort.isConnected();
        }
    }

    action def VerifyLightControl {
        in item bulb : SmartLightBulb;
        out item result : Boolean;
        do {
            bulb.turnOn();
            result = (bulb.powerState.status == PowerState::PowerStatusEnum::on);
            bulb.setBrightness(Brightness{ value = 50 });
            result = result and (bulb.brightness.value == 50);
            bulb.setColorTemperature(ColorTemperature{ value = 4000 });
            result = result and (bulb.colorTemp.value == 4000);
            bulb.turnOff();
            result = result and (bulb.powerState.status == PowerState::PowerStatusEnum::off);
        }
    }

    action def VerifyClimateRegulation {
        in item thermostat : SmartThermostat;
        in item sensor : EnvironmentSensor;
        out item result : Boolean;
        do {
            sensor.sampleEnvironment(?);
            thermostat.receiveSensorReading(sensor.lastReading);
            thermostat.evaluateClimate(?);
            result = (thermostat.currentMode != ThermostatMode::off);
        }
    }
}
