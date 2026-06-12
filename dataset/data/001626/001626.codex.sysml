package WebOfThingsSystem {

    import ScalarValues::*;
    import Quantities::*;
    import ISQ::*;
    import SI::*;

    attribute def URI;
    attribute def JSONText;
    attribute def Percentage;
    attribute def Celsius;
    attribute def Lux;
    attribute def Watt;
    attribute def WattHour;
    attribute def Millisecond;
    attribute def BooleanStatus;
    attribute def SecurityToken;

    item def WoTMessage {
        attribute messageId : URI;
        attribute correlationId : URI;
        attribute payload : JSONText;
        attribute timestamp : Time;
    }

    item def ThingDescription {
        attribute thingId : URI;
        attribute title : String;
        attribute securityScheme : String;
        attribute properties : JSONText;
        attribute actions : JSONText;
        attribute events : JSONText;
        attribute links : JSONText;
    }

    item def SensorObservation {
        attribute sourceThingId : URI;
        attribute observedProperty : String;
        attribute numericValue : Real;
        attribute unitSymbol : String;
        attribute sampleTime : Time;
        attribute quality : Percentage;
    }

    item def ActuationCommand {
        attribute targetThingId : URI;
        attribute commandName : String;
        attribute commandPayload : JSONText;
        attribute priority : Integer;
        attribute expiresAfter : Millisecond;
    }

    item def EnergyReport {
        attribute reportingThingId : URI;
        attribute instantaneousPower : Watt;
        attribute intervalEnergy : WattHour;
        attribute intervalStart : Time;
        attribute intervalEnd : Time;
    }

    item def OccupancyEvent {
        attribute spaceId : String;
        attribute occupied : Boolean;
        attribute confidence : Percentage;
        attribute eventTime : Time;
    }

    item def SecurityCredential {
        attribute token : SecurityToken;
        attribute issuer : URI;
        attribute subject : URI;
        attribute expiresAt : Time;
    }

    port def HttpWoTPort {
        in request : WoTMessage;
        out response : WoTMessage;
    }

    port def MqttWoTPort {
        in subscribedMessage : WoTMessage;
        out publishedMessage : WoTMessage;
    }

    port def SensorDataPort {
        out observation : SensorObservation;
        out occupancy : OccupancyEvent;
        out energy : EnergyReport;
    }

    port def CommandPort {
        in command : ActuationCommand;
        out commandStatus : WoTMessage;
    }

    port def ThingDescriptionPort {
        out description : ThingDescription;
    }

    port def CredentialPort {
        in credential : SecurityCredential;
        out authorizationDecision : BooleanStatus;
    }

    requirement def InteroperableThingRequirement {
        doc
        /* Every connected Thing shall expose a machine-readable Thing Description
           containing properties, actions, events, protocol bindings, and security metadata. */
    }

    requirement def SecureAccessRequirement {
        doc
        /* The system shall reject unauthenticated or unauthorized attempts to read properties,
           invoke actions, subscribe to events, or modify automation policies. */
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The Web of Things system shall integrate heterogeneous physical and virtual Things
           through Web standards to observe environment state, exchange semantic descriptions,
           coordinate automation, and execute authorized actuation commands. */
    }

    requirement def LatencyRequirement {
        attribute maxCommandLatency : Millisecond = 500 [ms];
        doc
        /* Authorized actuation commands shall be delivered from the WoT gateway to the target Thing
           within 500 ms under nominal network conditions. */
    }

    requirement def AvailabilityRequirement {
        attribute minimumAvailability : Percentage = 99.5;
        doc
        /* The WoT gateway and directory services shall maintain at least 99.5 percent monthly availability. */
    }

    action def DiscoverThings {
        in directoryRequest : WoTMessage;
        out discoveredDescriptions : ThingDescription;
    }

    action def ValidateCredential {
        in suppliedCredential : SecurityCredential;
        out valid : BooleanStatus;
    }

    action def NormalizeObservation {
        in rawObservation : SensorObservation;
        out normalizedObservation : SensorObservation;
    }

    action def EvaluateAutomationPolicy {
        in observation : SensorObservation;
        in occupancy : OccupancyEvent;
        in energy : EnergyReport;
        out command : ActuationCommand;
    }

    action def InvokeThingAction {
        in command : ActuationCommand;
        out result : WoTMessage;
    }

    state def ThingLifecycle {
        entry action initialize;
        state Unregistered;
        state Registered;
        state Online;
        state Degraded;
        state Offline;

        transition first Unregistered;
        transition registerThing
            first Unregistered
            then Registered;

        transition establishConnectivity
            first Registered
            then Online;

        transition detectFault
            first Online
            then Degraded;

        transition recoverFault
            first Degraded
            then Online;

        transition loseConnectivityFromOnline
            first Online
            then Offline;

        transition loseConnectivityFromDegraded
            first Degraded
            then Offline;

        transition reconnect
            first Offline
            then Online;
    }

    state def GatewayOperation {
        state Starting;
        state Discovering;
        state Monitoring;
        state Evaluating;
        state Commanding;
        state SecurityLockdown;

        transition initialStartup
            first Starting
            then Discovering;

        transition discoveryComplete
            first Discovering
            then Monitoring;

        transition observationReceived
            first Monitoring
            then Evaluating;

        transition commandRequired
            first Evaluating
            then Commanding;

        transition commandCompleted
            first Commanding
            then Monitoring;

        transition noActionRequired
            first Evaluating
            then Monitoring;

        transition authorizationFailure
            first Monitoring
            then SecurityLockdown;

        transition securityCleared
            first SecurityLockdown
            then Discovering;
    }

    part def WebThing {
        attribute thingId : URI;
        attribute displayName : String;
        attribute manufacturer : String;
        attribute firmwareVersion : String;
        attribute online : BooleanStatus;
        attribute lifecycle : ThingLifecycle;

        port http : HttpWoTPort;
        port mqtt : MqttWoTPort;
        port td : ThingDescriptionPort;
        port credentials : CredentialPort;
    }

    part def EnvironmentalSensor :> WebThing {
        attribute temperature : Celsius;
        attribute illuminance : Lux;
        attribute relativeHumidity : Percentage;
        attribute samplePeriod : Millisecond = 1000 [ms];

        port sensorOutput : SensorDataPort;
    }

    part def OccupancySensor :> WebThing {
        attribute occupied : BooleanStatus;
        attribute confidence : Percentage;
        attribute detectionZone : String;

        port occupancyOutput : SensorDataPort;
    }

    part def SmartLight :> WebThing {
        attribute brightness : Percentage;
        attribute colorTemperature : Real;
        attribute powerDraw : Watt;
        attribute enabled : BooleanStatus;

        port commandInput : CommandPort;
        port energyOutput : SensorDataPort;
    }

    part def SmartThermostat :> WebThing {
        attribute measuredTemperature : Celsius;
        attribute setpointTemperature : Celsius;
        attribute operatingMode : String;
        attribute hvacPower : Watt;

        port commandInput : CommandPort;
        port climateOutput : SensorDataPort;
    }

    part def SmartPlug :> WebThing {
        attribute switchedOn : BooleanStatus;
        attribute loadPower : Watt;
        attribute accumulatedEnergy : WattHour;

        port commandInput : CommandPort;
        port energyOutput : SensorDataPort;
    }

    part def ThingDirectory {
        attribute directoryUri : URI;
        attribute descriptionCount : Integer;
        attribute lastSyncTime : Time;

        port registrationApi : HttpWoTPort;
        port descriptionFeed : ThingDescriptionPort;

        action discover : DiscoverThings;
    }

    part def SecurityManager {
        attribute trustedIssuer : URI;
        attribute activeSessions : Integer;
        attribute failedAuthorizationCount : Integer;

        port credentialApi : CredentialPort;

        action validate : ValidateCredential;
    }

    part def SemanticAdapter {
        attribute contextUri : URI;
        attribute normalizedModelVersion : String;

        port rawDataIn : SensorDataPort;
        port normalizedDataOut : SensorDataPort;

        action normalize : NormalizeObservation;
    }

    part def AutomationEngine {
        attribute policyVersion : String;
        attribute occupiedLightingThreshold : Lux = 300;
        attribute comfortLowTemperature : Celsius = 20;
        attribute comfortHighTemperature : Celsius = 24;
        attribute standbyPowerLimit : Watt = 8;

        port observationIn : SensorDataPort;
        port commandOut : CommandPort;

        action evaluate : EvaluateAutomationPolicy;
    }

    part def WoTGateway {
        attribute gatewayId : URI;
        attribute publicBaseUri : URI;
        attribute operation : GatewayOperation;
        attribute commandLatencyBudget : Millisecond = 500 [ms];

        port northboundHttp : HttpWoTPort;
        port southboundHttp : HttpWoTPort;
        port southboundMqtt : MqttWoTPort;
        port descriptions : ThingDescriptionPort;
        port credentials : CredentialPort;
        port normalizedObservations : SensorDataPort;
        port commands : CommandPort;

        part directory : ThingDirectory;
        part security : SecurityManager;
        part adapter : SemanticAdapter;
        part automation : AutomationEngine;

        connect descriptions to directory.descriptionFeed;
        connect credentials to security.credentialApi;
        connect normalizedObservations to adapter.normalizedDataOut;
        connect automation.commandOut to commands;
    }

    part def WoTApplication {
        attribute applicationId : URI;
        attribute userRole : String;
        attribute dashboardRefreshPeriod : Millisecond = 2000 [ms];

        port userApi : HttpWoTPort;
        port credentials : CredentialPort;
    }

    part def WebOfThingsAutomationSystem {
        attribute systemName : String = "Interoperable Web of Things Automation System";
        attribute primaryFunction : String =
            "Integrate Web-enabled Things by discovering their Thing Descriptions, observing their properties and events, evaluating automation policies, and invoking secure actions through standard Web protocols.";

        part gateway : WoTGateway;
        part application : WoTApplication;

        part roomEnvironmentSensor : EnvironmentalSensor {
            attribute thingId = "urn:wot:thing:room-environment-01";
            attribute displayName = "Room Environment Sensor";
            attribute manufacturer = "Acme Sensing";
            attribute firmwareVersion = "3.4.2";
            attribute online = true;
            attribute temperature = 22 [degC];
            attribute illuminance = 180;
            attribute relativeHumidity = 45;
        }

        part roomOccupancySensor : OccupancySensor {
            attribute thingId = "urn:wot:thing:occupancy-01";
            attribute displayName = "Ceiling Occupancy Sensor";
            attribute manufacturer = "Acme Sensing";
            attribute firmwareVersion = "2.1.0";
            attribute online = true;
            attribute occupied = true;
            attribute confidence = 96;
            attribute detectionZone = "office-zone-a";
        }

        part taskLight : SmartLight {
            attribute thingId = "urn:wot:thing:light-01";
            attribute displayName = "Task Light";
            attribute manufacturer = "Lumina Web";
            attribute firmwareVersion = "5.8.1";
            attribute online = true;
            attribute brightness = 65;
            attribute colorTemperature = 4000;
            attribute powerDraw = 12 [W];
            attribute enabled = true;
        }

        part thermostat : SmartThermostat {
            attribute thingId = "urn:wot:thing:thermostat-01";
            attribute displayName = "Office Thermostat";
            attribute manufacturer = "ClimaNet";
            attribute firmwareVersion = "4.0.7";
            attribute online = true;
            attribute measuredTemperature = 22 [degC];
            attribute setpointTemperature = 22 [degC];
            attribute operatingMode = "auto";
            attribute hvacPower = 430 [W];
        }

        part equipmentPlug : SmartPlug {
            attribute thingId = "urn:wot:thing:plug-01";
            attribute displayName = "Equipment Smart Plug";
            attribute manufacturer = "GridLink";
            attribute firmwareVersion = "6.2.3";
            attribute online = true;
            attribute switchedOn = true;
            attribute loadPower = 42 [W];
            attribute accumulatedEnergy = 1.8 [W*h];
        }

        connect application.userApi to gateway.northboundHttp;
        connect application.credentials to gateway.credentials;

        connect roomEnvironmentSensor.http to gateway.southboundHttp;
        connect roomEnvironmentSensor.mqtt to gateway.southboundMqtt;
        connect roomEnvironmentSensor.td to gateway.descriptions;
        connect roomEnvironmentSensor.sensorOutput to gateway.adapter.rawDataIn;

        connect roomOccupancySensor.http to gateway.southboundHttp;
        connect roomOccupancySensor.mqtt to gateway.southboundMqtt;
        connect roomOccupancySensor.td to gateway.descriptions;
        connect roomOccupancySensor.occupancyOutput to gateway.adapter.rawDataIn;

        connect taskLight.http to gateway.southboundHttp;
        connect taskLight.mqtt to gateway.southboundMqtt;
        connect taskLight.td to gateway.descriptions;
        connect gateway.commands to taskLight.commandInput;
        connect taskLight.energyOutput to gateway.adapter.rawDataIn;

        connect thermostat.http to gateway.southboundHttp;
        connect thermostat.mqtt to gateway.southboundMqtt;
        connect thermostat.td to gateway.descriptions;
        connect gateway.commands to thermostat.commandInput;
        connect thermostat.climateOutput to gateway.adapter.rawDataIn;

        connect equipmentPlug.http to gateway.southboundHttp;
        connect equipmentPlug.mqtt to gateway.southboundMqtt;
        connect equipmentPlug.td to gateway.descriptions;
        connect gateway.commands to equipmentPlug.commandInput;
        connect equipmentPlug.energyOutput to gateway.adapter.rawDataIn;

        connect gateway.adapter.normalizedDataOut to gateway.automation.observationIn;
    }

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject system : WebOfThingsAutomationSystem;
    }

    requirement interoperableThingRequirement : InteroperableThingRequirement {
        subject sensor1 : EnvironmentalSensor;
        subject sensor2 : OccupancySensor;
        subject actuator1 : SmartLight;
        subject actuator2 : SmartThermostat;
        subject actuator3 : SmartPlug;
    }

    requirement secureAccessRequirement : SecureAccessRequirement {
        subject gateway : WoTGateway;
        subject security : SecurityManager;
        subject application : WoTApplication;
    }

    requirement latencyRequirement : LatencyRequirement {
        subject gateway : WoTGateway;
        subject light : SmartLight;
        subject thermostat : SmartThermostat;
        subject plug : SmartPlug;
    }

    requirement availabilityRequirement : AvailabilityRequirement {
        subject gateway : WoTGateway;
        subject directory : ThingDirectory;
    }

    satisfy primaryFunctionRequirement by WebOfThingsAutomationSystem;
    satisfy interoperableThingRequirement by EnvironmentalSensor;
    satisfy interoperableThingRequirement by OccupancySensor;
    satisfy interoperableThingRequirement by SmartLight;
    satisfy interoperableThingRequirement by SmartThermostat;
    satisfy interoperableThingRequirement by SmartPlug;
    satisfy secureAccessRequirement by SecurityManager;
    satisfy secureAccessRequirement by WoTGateway;
    satisfy latencyRequirement by WoTGateway;
    satisfy availabilityRequirement by WoTGateway;
    satisfy availabilityRequirement by ThingDirectory;

    action def ExecutePrimaryWoTFunction {
        in credential : SecurityCredential;
        in directoryRequest : WoTMessage;
        in rawEnvironment : SensorObservation;
        in rawOccupancy : OccupancyEvent;
        in rawEnergy : EnergyReport;
        out actuationResult : WoTMessage;

        first start;
        then validateUser : ValidateCredential {
            in suppliedCredential = credential;
        }

        then discoverAvailableThings : DiscoverThings {
            in directoryRequest = directoryRequest;
        }

        then normalizeEnvironment : NormalizeObservation {
            in rawObservation = rawEnvironment;
        }

        then evaluatePolicy : EvaluateAutomationPolicy {
            in observation = normalizeEnvironment.normalizedObservation;
            in occupancy = rawOccupancy;
            in energy = rawEnergy;
        }

        then invokeAction : InvokeThingAction {
            in command = evaluatePolicy.command;
            out result = actuationResult;
        }

        then done;
    }

}