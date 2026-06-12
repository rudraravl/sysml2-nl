package GoogleNestSmartThermostatModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import Time::*;

    /* Value and item definitions */

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Watt :> Real {
        unit = "W";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def AmpereHour :> Real {
        unit = "Ah";
    }

    attribute def PartsPerMillion :> Real {
        unit = "ppm";
    }

    attribute def Seconds :> Real {
        unit = "s";
    }

    item def AirSample {
        attribute temperature : Celsius;
        attribute humidity : Percent;
        attribute occupancyDetected : Boolean;
        attribute co2Estimate : PartsPerMillion;
        attribute sampleAge : Seconds;
    }

    item def UserCommand {
        attribute requestedMode : ThermostatMode;
        attribute requestedHeatSetpoint : Celsius;
        attribute requestedCoolSetpoint : Celsius;
        attribute source : CommandSource;
    }

    item def HvacCommand {
        attribute heatCall : Boolean;
        attribute coolCall : Boolean;
        attribute fanCall : Boolean;
        attribute emergencyHeatCall : Boolean;
    }

    item def CloudMessage {
        attribute deviceId : String;
        attribute timestamp : Seconds;
        attribute payloadType : CloudPayloadType;
        attribute authenticated : Boolean;
    }

    item def PowerFlow {
        attribute voltage : Volt;
        attribute current : Real;
        attribute availablePower : Watt;
    }

    enum def ThermostatMode {
        enum off;
        enum heat;
        enum cool;
        enum heatCool;
        enum eco;
    }

    enum def CommandSource {
        enum localDial;
        enum mobileApp;
        enum cloudAutomation;
        enum learnedSchedule;
        enum safetyController;
    }

    enum def CloudPayloadType {
        enum telemetry;
        enum configurationUpdate;
        enum userCommand;
        enum firmwareUpdateNotice;
        enum demandResponseSignal;
    }

    enum def ConnectivityState {
        enum disconnected;
        enum joiningWifi;
        enum connectedLocal;
        enum connectedCloud;
    }

    enum def HvacOperatingState {
        enum idle;
        enum heating;
        enum cooling;
        enum fanOnly;
        enum protectionDelay;
        enum fault;
    }

    /* Ports */

    port def AirSensingPort {
        in item ambientAir : AirSample;
    }

    port def UserInterfacePort {
        in item commandIn : UserCommand;
        out item statusOut : CloudMessage;
    }

    port def WirelessNetworkPort {
        in item inboundCloudMessage : CloudMessage;
        out item outboundCloudMessage : CloudMessage;
    }

    port def HvacControlPort {
        out item hvacCommand : HvacCommand;
    }

    port def PowerInputPort {
        in item power : PowerFlow;
    }

    port def BatteryPort {
        inout item storedEnergy : PowerFlow;
    }

    /* Actions */

    action def SenseIndoorEnvironment {
        in item air : AirSample;
        out attribute measuredTemperature : Celsius;
        out attribute measuredHumidity : Percent;
        out attribute occupancy : Boolean;

        action readTemperature;
        action readHumidity;
        action readOccupancy;

        first readTemperature then readHumidity then readOccupancy;

        measuredTemperature = air.temperature;
        measuredHumidity = air.humidity;
        occupancy = air.occupancyDetected;
    }

    action def SelectThermalSetpoints {
        in attribute activeMode : ThermostatMode;
        in attribute scheduledHeatSetpoint : Celsius;
        in attribute scheduledCoolSetpoint : Celsius;
        in attribute ecoHeatSetpoint : Celsius;
        in attribute ecoCoolSetpoint : Celsius;
        in attribute occupancy : Boolean;
        out attribute heatSetpoint : Celsius;
        out attribute coolSetpoint : Celsius;

        if activeMode == ThermostatMode::eco or occupancy == false {
            heatSetpoint = ecoHeatSetpoint;
            coolSetpoint = ecoCoolSetpoint;
        } else {
            heatSetpoint = scheduledHeatSetpoint;
            coolSetpoint = scheduledCoolSetpoint;
        }
    }

    action def DecideHvacCall {
        in attribute mode : ThermostatMode;
        in attribute indoorTemperature : Celsius;
        in attribute heatSetpoint : Celsius;
        in attribute coolSetpoint : Celsius;
        in attribute deadband : Celsius;
        out item command : HvacCommand;

        command.heatCall = false;
        command.coolCall = false;
        command.fanCall = false;
        command.emergencyHeatCall = false;

        if mode == ThermostatMode::heat and indoorTemperature < heatSetpoint - deadband {
            command.heatCall = true;
            command.fanCall = true;
        }

        if mode == ThermostatMode::cool and indoorTemperature > coolSetpoint + deadband {
            command.coolCall = true;
            command.fanCall = true;
        }

        if mode == ThermostatMode::heatCool and indoorTemperature < heatSetpoint - deadband {
            command.heatCall = true;
            command.fanCall = true;
        }

        if mode == ThermostatMode::heatCool and indoorTemperature > coolSetpoint + deadband {
            command.coolCall = true;
            command.fanCall = true;
        }
    }

    action def PublishTelemetry {
        in attribute temperature : Celsius;
        in attribute humidity : Percent;
        in attribute mode : ThermostatMode;
        in attribute hvacState : HvacOperatingState;
        out item message : CloudMessage;

        message.deviceId = "nest-thermostat-main-zone";
        message.payloadType = CloudPayloadType::telemetry;
        message.authenticated = true;
    }

    /* State machines */

    state def ThermostatControlStateMachine {
        attribute mode : ThermostatMode;
        attribute hvacState : HvacOperatingState;
        attribute indoorTemperature : Celsius;
        attribute heatSetpoint : Celsius;
        attribute coolSetpoint : Celsius;
        attribute compressorDelaySatisfied : Boolean;

        entry action initialize {
            mode = ThermostatMode::heatCool;
            hvacState = HvacOperatingState::idle;
            heatSetpoint = 20.0;
            coolSetpoint = 24.0;
            compressorDelaySatisfied = true;
        }

        state Off;
        state Monitoring;
        state Heating;
        state Cooling;
        state EcoHold;
        state CompressorProtection;
        state Fault;

        transition initial then Monitoring;

        transition Monitoring to Heating
            if mode == ThermostatMode::heat or mode == ThermostatMode::heatCool
            and indoorTemperature < heatSetpoint - 0.3
            do {
                hvacState = HvacOperatingState::heating;
            }

        transition Monitoring to Cooling
            if mode == ThermostatMode::cool or mode == ThermostatMode::heatCool
            and indoorTemperature > coolSetpoint + 0.3
            and compressorDelaySatisfied == true
            do {
                hvacState = HvacOperatingState::cooling;
            }

        transition Monitoring to EcoHold
            if mode == ThermostatMode::eco
            do {
                heatSetpoint = 16.0;
                coolSetpoint = 28.0;
            }

        transition Heating to Monitoring
            if indoorTemperature >= heatSetpoint
            do {
                hvacState = HvacOperatingState::idle;
            }

        transition Cooling to CompressorProtection
            if indoorTemperature <= coolSetpoint
            do {
                hvacState = HvacOperatingState::protectionDelay;
                compressorDelaySatisfied = false;
            }

        transition CompressorProtection to Monitoring
            if compressorDelaySatisfied == true
            do {
                hvacState = HvacOperatingState::idle;
            }

        transition EcoHold to Monitoring
            if mode != ThermostatMode::eco;

        transition Monitoring to Off
            if mode == ThermostatMode::off
            do {
                hvacState = HvacOperatingState::idle;
            }

        transition Off to Monitoring
            if mode != ThermostatMode::off;

        transition Monitoring to Fault
            if indoorTemperature < 0.0 or indoorTemperature > 50.0
            do {
                hvacState = HvacOperatingState::fault;
            }
    }

    state def ConnectivityStateMachine {
        attribute connectivity : ConnectivityState;
        attribute wifiConfigured : Boolean;
        attribute cloudAuthenticated : Boolean;

        state Disconnected;
        state JoiningWifi;
        state LocalConnected;
        state CloudConnected;

        transition initial then Disconnected;

        transition Disconnected to JoiningWifi
            if wifiConfigured == true
            do {
                connectivity = ConnectivityState::joiningWifi;
            }

        transition JoiningWifi to LocalConnected
            if wifiConfigured == true
            do {
                connectivity = ConnectivityState::connectedLocal;
            }

        transition LocalConnected to CloudConnected
            if cloudAuthenticated == true
            do {
                connectivity = ConnectivityState::connectedCloud;
            }

        transition CloudConnected to LocalConnected
            if cloudAuthenticated == false
            do {
                connectivity = ConnectivityState::connectedLocal;
            }

        transition LocalConnected to Disconnected
            if wifiConfigured == false
            do {
                connectivity = ConnectivityState::disconnected;
            }
    }

    /* System structure */

    part def TemperatureSensor {
        port airIn : AirSensingPort;
        attribute accuracy : Celsius = 0.2;
        attribute samplingPeriod : Seconds = 10.0;
        attribute lastMeasuredTemperature : Celsius;
    }

    part def HumiditySensor {
        port airIn : AirSensingPort;
        attribute accuracy : Percent = 3.0;
        attribute lastMeasuredHumidity : Percent;
    }

    part def OccupancySensor {
        port airIn : AirSensingPort;
        attribute detectionRange : Real = 6.0;
        attribute occupancyDetected : Boolean;
    }

    part def LocalDisplayAndDial {
        port ui : UserInterfacePort;
        attribute displayBrightness : Percent = 70.0;
        attribute touchEnabled : Boolean = true;
        attribute dialRotationEnabled : Boolean = true;
    }

    part def WifiRadio {
        port network : WirelessNetworkPort;
        attribute frequencyGhz : Real = 2.4;
        attribute connected : Boolean;
        attribute receivedSignalStrength : Real;
    }

    part def CloudGateway {
        port network : WirelessNetworkPort;
        attribute authenticated : Boolean;
        attribute accountLinked : Boolean;
    }

    part def LearningScheduler {
        attribute learnedHeatSetpoint : Celsius = 20.0;
        attribute learnedCoolSetpoint : Celsius = 24.0;
        attribute ecoHeatSetpoint : Celsius = 16.0;
        attribute ecoCoolSetpoint : Celsius = 28.0;
        attribute occupancyConfidence : Percent;
    }

    part def HvacRelayInterface {
        port hvacOut : HvacControlPort;
        attribute maxRelayVoltage : Volt = 24.0;
        attribute heatRelayClosed : Boolean;
        attribute coolRelayClosed : Boolean;
        attribute fanRelayClosed : Boolean;
    }

    part def PowerManager {
        port cWirePower : PowerInputPort;
        port backupBattery : BatteryPort;
        attribute inputVoltage : Volt = 24.0;
        attribute operatingPower : Watt = 3.5;
        attribute batteryCapacity : AmpereHour = 2.0;
        attribute lowPowerMode : Boolean;
    }

    part def SecurityManager {
        attribute secureBootEnabled : Boolean = true;
        attribute cloudTokenValid : Boolean;
        attribute localCommandAuthenticated : Boolean;
    }

    part def GoogleNestThermostat {
        port indoorAir : AirSensingPort;
        port userInterface : UserInterfacePort;
        port wirelessNetwork : WirelessNetworkPort;
        port hvacControl : HvacControlPort;
        port powerInput : PowerInputPort;

        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part displayAndDial : LocalDisplayAndDial;
        part wifiRadio : WifiRadio;
        part cloudGateway : CloudGateway;
        part scheduler : LearningScheduler;
        part hvacRelayInterface : HvacRelayInterface;
        part powerManager : PowerManager;
        part securityManager : SecurityManager;

        attribute primaryFunction : String =
            "Maintain indoor comfort by sensing room conditions, learning preferred schedules, accepting local and remote commands, and controlling residential HVAC equipment.";

        attribute activeMode : ThermostatMode = ThermostatMode::heatCool;
        attribute indoorTemperature : Celsius;
        attribute indoorHumidity : Percent;
        attribute heatSetpoint : Celsius = 20.0;
        attribute coolSetpoint : Celsius = 24.0;
        attribute deadband : Celsius = 0.3;
        attribute hvacState : HvacOperatingState = HvacOperatingState::idle;
        attribute connectivity : ConnectivityState = ConnectivityState::disconnected;

        perform action SenseIndoorEnvironment;
        perform action SelectThermalSetpoints;
        perform action DecideHvacCall;
        perform action PublishTelemetry;

        exhibit state ThermostatControlStateMachine;
        exhibit state ConnectivityStateMachine;

        connect indoorAir to temperatureSensor.airIn;
        connect indoorAir to humiditySensor.airIn;
        connect indoorAir to occupancySensor.airIn;
        connect userInterface to displayAndDial.ui;
        connect wirelessNetwork to wifiRadio.network;
        connect wifiRadio.network to cloudGateway.network;
        connect hvacControl to hvacRelayInterface.hvacOut;
        connect powerInput to powerManager.cWirePower;
    }

    part def ResidentialHvacPlant {
        port controlIn : HvacControlPort;
        attribute furnaceAvailable : Boolean = true;
        attribute airConditionerAvailable : Boolean = true;
        attribute fanAvailable : Boolean = true;
        attribute heatingCapacity : Watt = 10000.0;
        attribute coolingCapacity : Watt = 9000.0;
    }

    part def MobileApp {
        port appUi : UserInterfacePort;
        attribute remoteUserAuthenticated : Boolean;
        attribute geofenceAway : Boolean;
    }

    part def HomeWifiNetwork {
        port network : WirelessNetworkPort;
        attribute internetAvailable : Boolean;
        attribute ssidConfigured : Boolean;
    }

    part def NestBasedHomeComfortSystem {
        part thermostat : GoogleNestThermostat;
        part hvacPlant : ResidentialHvacPlant;
        part mobileApp : MobileApp;
        part homeWifi : HomeWifiNetwork;

        connect thermostat.hvacControl to hvacPlant.controlIn;
        connect thermostat.wirelessNetwork to homeWifi.network;
        connect mobileApp.appUi to thermostat.userInterface;
    }

    /* Requirements */

    requirement def PrimaryComfortControlRequirement {
        doc /* The thermostat shall maintain the indoor temperature within the active comfort band by commanding heating, cooling, or fan operation when sensed conditions differ from selected setpoints. */
        subject thermostat : GoogleNestThermostat;
        require constraint {
            thermostat.indoorTemperature >= thermostat.heatSetpoint - thermostat.deadband and
            thermostat.indoorTemperature <= thermostat.coolSetpoint + thermostat.deadband
        }
    }

    requirement def RemoteAccessRequirement {
        doc /* The thermostat shall accept authenticated remote commands through the cloud-connected mobile application when wireless connectivity and account authentication are available. */
        subject thermostat : GoogleNestThermostat;
        require constraint {
            thermostat.securityManager.cloudTokenValid implies
            thermostat.connectivity == ConnectivityState::connectedCloud
        }
    }

    requirement def EnergySavingEcoRequirement {
        doc /* The thermostat shall support an Eco mode that relaxes heating and cooling setpoints when occupancy is not detected or when an away condition is received. */
        subject thermostat : GoogleNestThermostat;
        require constraint {
            thermostat.activeMode == ThermostatMode::eco implies
            thermostat.heatSetpoint <= thermostat.scheduler.ecoHeatSetpoint and
            thermostat.coolSetpoint >= thermostat.scheduler.ecoCoolSetpoint
        }
    }

    requirement def HvacProtectionRequirement {
        doc /* The thermostat shall prevent rapid compressor cycling by entering a protection delay after cooling is stopped. */
        subject thermostat : GoogleNestThermostat;
        require constraint {
            thermostat.hvacState == HvacOperatingState::protectionDelay implies
            thermostat.hvacRelayInterface.coolRelayClosed == false
        }
    }

    requirement def LocalOperationRequirement {
        doc /* The thermostat shall continue basic local temperature control when cloud connectivity is unavailable. */
        subject thermostat : GoogleNestThermostat;
        require constraint {
            thermostat.connectivity != ConnectivityState::connectedCloud implies
            thermostat.displayAndDial.touchEnabled == true
        }
    }

    requirement def SafePowerRequirement {
        doc /* The thermostat shall enter low-power operation when available HVAC control power is insufficient for normal operation. */
        subject thermostat : GoogleNestThermostat;
        require constraint {
            thermostat.powerManager.inputVoltage < 18.0 implies
            thermostat.powerManager.lowPowerMode == true
        }
    }

    satisfy PrimaryComfortControlRequirement by GoogleNestThermostat;
    satisfy RemoteAccessRequirement by GoogleNestThermostat;
    satisfy EnergySavingEcoRequirement by GoogleNestThermostat;
    satisfy HvacProtectionRequirement by GoogleNestThermostat;
    satisfy LocalOperationRequirement by GoogleNestThermostat;
    satisfy SafePowerRequirement by GoogleNestThermostat;
}