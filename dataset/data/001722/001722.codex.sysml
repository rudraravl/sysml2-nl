package OCFBasedSmartHomeSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def URI;
    attribute def UUID;
    attribute def IPv6Address;
    attribute def ManufacturerName;
    attribute def ModelNumber;
    attribute def FirmwareVersion;
    attribute def CertificateChain;
    attribute def AccessToken;
    attribute def ResourceTypeName;
    attribute def InterfaceName;
    attribute def RequestMethod;
    attribute def ResponseCode;
    attribute def PayloadFormat;
    attribute def SecurityProfile;

    enum def DeviceOperationalMode {
        enum off;
        enum standby;
        enum onboarding;
        enum operational;
        enum fault;
        enum maintenance;
    }

    enum def OCFMethodKind {
        enum retrieve;
        enum update;
        enum create;
        enum delete;
        enum notify;
    }

    enum def DiscoveryScope {
        enum localMulticast;
        enum cloudMediated;
        enum directedUnicast;
    }

    enum def SecurityState {
        enum unowned;
        enum owned;
        enum authenticated;
        enum authorized;
        enum revoked;
    }

    enum def AutomationDecision {
        enum noAction;
        enum switchOn;
        enum switchOff;
        enum adjustLevel;
        enum alertOccupant;
    }

    item def OCFRequest {
        attribute requestId : UUID;
        attribute method : OCFMethodKind;
        attribute targetUri : URI;
        attribute resourceType : ResourceTypeName;
        attribute interfaceName : InterfaceName;
        attribute payloadFormat : PayloadFormat;
        attribute accessToken : AccessToken;
        attribute maxAge : Time;
    }

    item def OCFResponse {
        attribute requestId : UUID;
        attribute responseCode : ResponseCode;
        attribute payloadFormat : PayloadFormat;
        attribute representationVersion : Integer;
        attribute cacheMaxAge : Time;
    }

    item def OCFNotification {
        attribute sourceDeviceId : UUID;
        attribute sourceUri : URI;
        attribute sequenceNumber : Integer;
        attribute eventTime : Time;
        attribute payloadFormat : PayloadFormat;
    }

    item def DiscoveryAdvertisement {
        attribute deviceId : UUID;
        attribute deviceName : String;
        attribute manufacturer : ManufacturerName;
        attribute model : ModelNumber;
        attribute resourceUri : URI;
        attribute resourceType : ResourceTypeName;
        attribute interfaceName : InterfaceName;
        attribute secureEndpoint : IPv6Address;
        attribute scope : DiscoveryScope;
    }

    item def SensorReading {
        attribute sourceDeviceId : UUID;
        attribute observedAt : Time;
        attribute validityPeriod : Time;
    }

    item def TemperatureReading specializes SensorReading {
        attribute temperature : TemperatureValue;
    }

    item def HumidityReading specializes SensorReading {
        attribute relativeHumidity : HumidityRatioValue;
    }

    item def OccupancyReading specializes SensorReading {
        attribute occupied : Boolean;
        attribute confidence : Real;
    }

    item def LightLevelReading specializes SensorReading {
        attribute illuminance : IlluminanceValue;
    }

    item def ActuatorCommand {
        attribute commandId : UUID;
        attribute issuedAt : Time;
        attribute targetDeviceId : UUID;
        attribute targetUri : URI;
        attribute decision : AutomationDecision;
    }

    item def LightCommand specializes ActuatorCommand {
        attribute on : Boolean;
        attribute brightness : BrightnessValue;
    }

    item def ThermostatCommand specializes ActuatorCommand {
        attribute targetTemperature : TemperatureValue;
        attribute mode : String;
    }

    item def SecurityCredential {
        attribute ownerUuid : UUID;
        attribute deviceUuid : UUID;
        attribute profile : SecurityProfile;
        attribute certificateChain : CertificateChain;
        attribute validFrom : Time;
        attribute validUntil : Time;
    }

    value def TemperatureValue {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    value def HumidityRatioValue {
        attribute value : Real;
        attribute unit : String = "percent";
    }

    value def IlluminanceValue {
        attribute value : Real;
        attribute unit : String = "lux";
    }

    value def BrightnessValue {
        attribute value : Real;
        attribute unit : String = "percent";
    }

    value def PowerValue {
        attribute value : Real;
        attribute unit : String = "W";
    }

    value def EnergyValue {
        attribute value : Real;
        attribute unit : String = "kWh";
    }

    value def LatencyValue {
        attribute value : Real;
        attribute unit : String = "ms";
    }

    port def OCFSecureEndpoint {
        in item request : OCFRequest;
        out item response : OCFResponse;
        out item notification : OCFNotification;
        out item advertisement : DiscoveryAdvertisement;
    }

    port def OCFClientEndpoint {
        out item request : OCFRequest;
        in item response : OCFResponse;
        in item notification : OCFNotification;
        in item advertisement : DiscoveryAdvertisement;
    }

    port def SensorOutputPort {
        out item reading : SensorReading;
    }

    port def ActuatorInputPort {
        in item command : ActuatorCommand;
    }

    port def CredentialPort {
        inout item credential : SecurityCredential;
    }

    part def OCFResource {
        attribute uri : URI;
        attribute resourceType : ResourceTypeName;
        attribute interfaceName : InterfaceName;
        attribute observable : Boolean;
        attribute discoverable : Boolean;
        attribute secureOnly : Boolean;
    }

    part def OCFDevice {
        attribute deviceId : UUID;
        attribute deviceName : String;
        attribute manufacturer : ManufacturerName;
        attribute model : ModelNumber;
        attribute firmwareVersion : FirmwareVersion;
        attribute operationalMode : DeviceOperationalMode;
        attribute securityState : SecurityState;
        attribute nominalPower : PowerValue;

        port secureEndpoint : OCFSecureEndpoint;
        port credentials : CredentialPort;

        part platformResource : OCFResource {
            attribute uri = "/oic/p";
            attribute resourceType = "oic.wk.p";
            attribute interfaceName = "oic.if.r";
            attribute observable = false;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        part deviceResource : OCFResource {
            attribute uri = "/oic/d";
            attribute resourceType = "oic.wk.d";
            attribute interfaceName = "oic.if.r";
            attribute observable = false;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        state def DeviceLifecycle {
            state Initializing;
            state AwaitingOwnership;
            state ProvisioningCredentials;
            state Discoverable;
            state ServingResources;
            state Faulted;
            state Retired;

            transition first Initializing;
            transition Initializing then AwaitingOwnership;
            transition AwaitingOwnership then ProvisioningCredentials
                accept OCFRequest
                if securityState == SecurityState::unowned;
            transition ProvisioningCredentials then Discoverable
                accept SecurityCredential;
            transition Discoverable then ServingResources
                accept OCFRequest
                if securityState == SecurityState::authorized;
            transition ServingResources then Faulted
                accept OCFNotification
                if operationalMode == DeviceOperationalMode::fault;
            transition Faulted then ServingResources
                accept OCFRequest
                if operationalMode == DeviceOperationalMode::operational;
            transition ServingResources then Retired
                accept OCFRequest
                if securityState == SecurityState::revoked;
        }
    }

    part def TemperatureSensorDevice specializes OCFDevice {
        attribute samplingPeriod : Time;
        attribute measurementRangeMin : TemperatureValue;
        attribute measurementRangeMax : TemperatureValue;
        attribute measurementAccuracy : TemperatureValue;

        port sensedTemperature : SensorOutputPort;

        part temperatureResource : OCFResource {
            attribute uri = "/temperature";
            attribute resourceType = "oic.r.temperature";
            attribute interfaceName = "oic.if.s";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action measureTemperature {
            out item reading : TemperatureReading;
        }

        state def TemperatureSensorBehavior {
            state Idle;
            state Sampling;
            state Publishing;
            state FaultDetected;

            transition first Idle;
            transition Idle then Sampling;
            transition Sampling then Publishing
                do measureTemperature;
            transition Publishing then Idle;
            transition Sampling then FaultDetected
                if operationalMode == DeviceOperationalMode::fault;
            transition FaultDetected then Idle
                if operationalMode == DeviceOperationalMode::operational;
        }
    }

    part def OccupancySensorDevice specializes OCFDevice {
        attribute detectionTimeout : Time;
        attribute confidenceThreshold : Real;

        port sensedOccupancy : SensorOutputPort;

        part occupancyResource : OCFResource {
            attribute uri = "/occupancy";
            attribute resourceType = "oic.r.sensor.presence";
            attribute interfaceName = "oic.if.s";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action detectOccupancy {
            out item reading : OccupancyReading;
        }
    }

    part def LightSensorDevice specializes OCFDevice {
        attribute samplingPeriod : Time;
        attribute maximumIlluminance : IlluminanceValue;

        port sensedLightLevel : SensorOutputPort;

        part illuminanceResource : OCFResource {
            attribute uri = "/illuminance";
            attribute resourceType = "oic.r.sensor.illuminance";
            attribute interfaceName = "oic.if.s";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action measureIlluminance {
            out item reading : LightLevelReading;
        }
    }

    part def SmartLightDevice specializes OCFDevice {
        attribute currentPower : PowerValue;
        attribute brightness : BrightnessValue;
        attribute on : Boolean;

        port actuatorControl : ActuatorInputPort;

        part binarySwitchResource : OCFResource {
            attribute uri = "/switch";
            attribute resourceType = "oic.r.switch.binary";
            attribute interfaceName = "oic.if.a";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        part dimmingResource : OCFResource {
            attribute uri = "/brightness";
            attribute resourceType = "oic.r.light.dimming";
            attribute interfaceName = "oic.if.a";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action applyLightCommand {
            in item command : LightCommand;
            out item response : OCFResponse;
        }

        state def LightActuatorBehavior {
            state Off;
            state On;
            state Dimming;
            state CommunicationFault;

            transition first Off;
            transition Off then On
                accept LightCommand
                if on == true;
            transition On then Off
                accept LightCommand
                if on == false;
            transition On then Dimming
                accept LightCommand;
            transition Dimming then On;
            transition On then CommunicationFault
                if operationalMode == DeviceOperationalMode::fault;
            transition CommunicationFault then Off
                if operationalMode == DeviceOperationalMode::operational and on == false;
        }
    }

    part def SmartThermostatDevice specializes OCFDevice {
        attribute currentTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        attribute heatingEnabled : Boolean;
        attribute coolingEnabled : Boolean;

        port actuatorControl : ActuatorInputPort;
        port sensedTemperature : SensorOutputPort;

        part thermostatResource : OCFResource {
            attribute uri = "/thermostat";
            attribute resourceType = "oic.r.thermostat";
            attribute interfaceName = "oic.if.a";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action regulateTemperature {
            in item command : ThermostatCommand;
            out item response : OCFResponse;
        }

        state def ThermostatBehavior {
            state Maintaining;
            state Heating;
            state Cooling;
            state Standby;
            state Faulted;

            transition first Standby;
            transition Standby then Maintaining
                accept ThermostatCommand;
            transition Maintaining then Heating
                if currentTemperature.value < targetTemperature.value;
            transition Maintaining then Cooling
                if currentTemperature.value > targetTemperature.value;
            transition Heating then Maintaining
                if currentTemperature.value >= targetTemperature.value;
            transition Cooling then Maintaining
                if currentTemperature.value <= targetTemperature.value;
            transition Maintaining then Faulted
                if operationalMode == DeviceOperationalMode::fault;
            transition Faulted then Standby
                if operationalMode == DeviceOperationalMode::operational;
        }
    }

    part def OCFNetwork {
        attribute networkId : UUID;
        attribute supportsIPv6 : Boolean = true;
        attribute supportsCoAP : Boolean = true;
        attribute supportsDTLS : Boolean = true;
        attribute maximumDiscoveryLatency : LatencyValue;
        attribute maximumCommandLatency : LatencyValue;

        port clientSide : OCFClientEndpoint;
        port deviceSide : OCFSecureEndpoint;

        action routeRequest {
            in item request : OCFRequest;
            out item response : OCFResponse;
        }

        action multicastDiscovery {
            in attribute scope : DiscoveryScope;
            out item advertisement : DiscoveryAdvertisement;
        }
    }

    part def OCFOnboardingTool {
        attribute toolId : UUID;
        attribute ownerUuid : UUID;

        port clientEndpoint : OCFClientEndpoint;
        port credentialEndpoint : CredentialPort;

        action discoverUnownedDevices {
            out item advertisement : DiscoveryAdvertisement;
        }

        action provisionOwnership {
            in item advertisement : DiscoveryAdvertisement;
            out item credential : SecurityCredential;
        }

        action authorizeClient {
            in item credential : SecurityCredential;
            out item request : OCFRequest;
        }
    }

    part def ResourceDirectory {
        attribute directoryId : UUID;
        attribute retainedAdvertisements : Integer;
        attribute maximumEntryAge : Time;

        port directoryEndpoint : OCFSecureEndpoint;

        part resourceDirectoryResource : OCFResource {
            attribute uri = "/oic/rd";
            attribute resourceType = "oic.wk.rd";
            attribute interfaceName = "oic.if.ll";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action registerResource {
            in item advertisement : DiscoveryAdvertisement;
            out item response : OCFResponse;
        }

        action lookupResource {
            in item request : OCFRequest;
            out item advertisement : DiscoveryAdvertisement;
        }
    }

    part def AutomationController specializes OCFDevice {
        attribute controllerPolicyVersion : Integer;
        attribute comfortTemperature : TemperatureValue;
        attribute awayTemperature : TemperatureValue;
        attribute occupiedLightLevelThreshold : IlluminanceValue;
        attribute commandRetryLimit : Integer;

        port clientEndpoint : OCFClientEndpoint;
        port temperatureInput : SensorOutputPort;
        port occupancyInput : SensorOutputPort;
        port illuminanceInput : SensorOutputPort;
        port commandOutput : ActuatorInputPort;

        part automationResource : OCFResource {
            attribute uri = "/automation/home";
            attribute resourceType = "oic.r.automation";
            attribute interfaceName = "oic.if.b";
            attribute observable = true;
            attribute discoverable = true;
            attribute secureOnly = true;
        }

        action evaluateContext {
            in item temperature : TemperatureReading;
            in item occupancy : OccupancyReading;
            in item illuminance : LightLevelReading;
            out attribute decision : AutomationDecision;
        }

        action issueLightControl {
            in attribute decision : AutomationDecision;
            out item command : LightCommand;
        }

        action issueThermostatControl {
            in item temperature : TemperatureReading;
            in item occupancy : OccupancyReading;
            out item command : ThermostatCommand;
        }

        state def AutomationControlBehavior {
            state DiscoveringResources;
            state SubscribingToObservations;
            state Monitoring;
            state EvaluatingPolicy;
            state SendingCommands;
            state DegradedOperation;

            transition first DiscoveringResources;
            transition DiscoveringResources then SubscribingToObservations
                accept DiscoveryAdvertisement;
            transition SubscribingToObservations then Monitoring
                accept OCFResponse
                if responseCode == "2.05";
            transition Monitoring then EvaluatingPolicy
                accept OCFNotification;
            transition EvaluatingPolicy then SendingCommands
                do evaluateContext;
            transition SendingCommands then Monitoring
                accept OCFResponse;
            transition Monitoring then DegradedOperation
                if operationalMode == DeviceOperationalMode::fault;
            transition DegradedOperation then DiscoveringResources
                if operationalMode == DeviceOperationalMode::operational;
        }
    }

    part def OCFSmartHome {
        attribute homeId : UUID;
        attribute primaryFunction : String =
            "Provide secure, interoperable discovery, monitoring, and control of smart-home sensors and actuators using Open Connectivity Foundation resource models and network protocols.";
        attribute targetAvailability : Real = 0.995;
        attribute maximumEndToEndCommandLatency : LatencyValue;
        attribute maximumDiscoveryLatency : LatencyValue;
        attribute annualEnergyBudget : EnergyValue;

        part network : OCFNetwork {
            attribute maximumDiscoveryLatency.value = 2000.0;
            attribute maximumDiscoveryLatency.unit = "ms";
            attribute maximumCommandLatency.value = 500.0;
            attribute maximumCommandLatency.unit = "ms";
        }

        part onboardingTool : OCFOnboardingTool;
        part directory : ResourceDirectory;
        part controller : AutomationController {
            attribute comfortTemperature.value = 21.0;
            attribute comfortTemperature.unit = "degC";
            attribute awayTemperature.value = 16.0;
            attribute awayTemperature.unit = "degC";
            attribute occupiedLightLevelThreshold.value = 250.0;
            attribute occupiedLightLevelThreshold.unit = "lux";
            attribute commandRetryLimit = 3;
        }

        part livingRoomTemperatureSensor : TemperatureSensorDevice {
            attribute deviceName = "Living Room Temperature Sensor";
            attribute samplingPeriod = 30 [s];
            attribute measurementRangeMin.value = -10.0;
            attribute measurementRangeMin.unit = "degC";
            attribute measurementRangeMax.value = 50.0;
            attribute measurementRangeMax.unit = "degC";
            attribute measurementAccuracy.value = 0.3;
            attribute measurementAccuracy.unit = "degC";
            attribute nominalPower.value = 1.2;
            attribute nominalPower.unit = "W";
        }

        part livingRoomOccupancySensor : OccupancySensorDevice {
            attribute deviceName = "Living Room Occupancy Sensor";
            attribute detectionTimeout = 300 [s];
            attribute confidenceThreshold = 0.85;
            attribute nominalPower.value = 0.8;
            attribute nominalPower.unit = "W";
        }

        part livingRoomLightSensor : LightSensorDevice {
            attribute deviceName = "Living Room Light Sensor";
            attribute samplingPeriod = 20 [s];
            attribute maximumIlluminance.value = 10000.0;
            attribute maximumIlluminance.unit = "lux";
            attribute nominalPower.value = 0.6;
            attribute nominalPower.unit = "W";
        }

        part livingRoomSmartLight : SmartLightDevice {
            attribute deviceName = "Living Room Dimmable Light";
            attribute currentPower.value = 0.0;
            attribute currentPower.unit = "W";
            attribute brightness.value = 0.0;
            attribute brightness.unit = "percent";
            attribute on = false;
            attribute nominalPower.value = 12.0;
            attribute nominalPower.unit = "W";
        }

        part hallwaySmartLight : SmartLightDevice {
            attribute deviceName = "Hallway Dimmable Light";
            attribute currentPower.value = 0.0;
            attribute currentPower.unit = "W";
            attribute brightness.value = 0.0;
            attribute brightness.unit = "percent";
            attribute on = false;
            attribute nominalPower.value = 9.0;
            attribute nominalPower.unit = "W";
        }

        part thermostat : SmartThermostatDevice {
            attribute deviceName = "Main Zone Smart Thermostat";
            attribute currentTemperature.value = 20.0;
            attribute currentTemperature.unit = "degC";
            attribute targetTemperature.value = 21.0;
            attribute targetTemperature.unit = "degC";
            attribute heatingEnabled = false;
            attribute coolingEnabled = false;
            attribute nominalPower.value = 3.0;
            attribute nominalPower.unit = "W";
        }

        connect onboardingTool.clientEndpoint to network.clientSide;
        connect controller.clientEndpoint to network.clientSide;
        connect directory.directoryEndpoint to network.deviceSide;
        connect livingRoomTemperatureSensor.secureEndpoint to network.deviceSide;
        connect livingRoomOccupancySensor.secureEndpoint to network.deviceSide;
        connect livingRoomLightSensor.secureEndpoint to network.deviceSide;
        connect livingRoomSmartLight.secureEndpoint to network.deviceSide;
        connect hallwaySmartLight.secureEndpoint to network.deviceSide;
        connect thermostat.secureEndpoint to network.deviceSide;

        connect livingRoomTemperatureSensor.sensedTemperature to controller.temperatureInput;
        connect thermostat.sensedTemperature to controller.temperatureInput;
        connect livingRoomOccupancySensor.sensedOccupancy to controller.occupancyInput;
        connect livingRoomLightSensor.sensedLightLevel to controller.illuminanceInput;
        connect controller.commandOutput to livingRoomSmartLight.actuatorControl;
        connect controller.commandOutput to hallwaySmartLight.actuatorControl;
        connect controller.commandOutput to thermostat.actuatorControl;

        action performPrimaryFunction {
            first start;
            then discoverAvailableOCFResources;
            then authenticateAndAuthorizeCommunication;
            then observeEnvironmentalResources;
            then evaluateAutomationPolicy;
            then commandActuators;
            then publishUpdatedResourceState;
            then done;

            action discoverAvailableOCFResources {
                out item advertisements : DiscoveryAdvertisement;
            }

            action authenticateAndAuthorizeCommunication {
                in item advertisements : DiscoveryAdvertisement;
                out item credentials : SecurityCredential;
            }

            action observeEnvironmentalResources {
                in item credentials : SecurityCredential;
                out item temperature : TemperatureReading;
                out item occupancy : OccupancyReading;
                out item illuminance : LightLevelReading;
            }

            action evaluateAutomationPolicy {
                in item temperature : TemperatureReading;
                in item occupancy : OccupancyReading;
                in item illuminance : LightLevelReading;
                out attribute decision : AutomationDecision;
            }

            action commandActuators {
                in attribute decision : AutomationDecision;
                out item lightCommand : LightCommand;
                out item thermostatCommand : ThermostatCommand;
            }

            action publishUpdatedResourceState {
                in item lightCommand : LightCommand;
                in item thermostatCommand : ThermostatCommand;
                out item notification : OCFNotification;
            }
        }
    }

    requirement def InteroperabilityRequirement {
        doc /* The system shall expose device capabilities as Open Connectivity Foundation resources with discoverable resource type names, interface names, and secure endpoints so clients can interact without vendor-specific protocols. */
        subject system : OCFSmartHome;
        require constraint {
            system.network.supportsIPv6 == true and
            system.network.supportsCoAP == true and
            system.network.supportsDTLS == true
        }
    }

    requirement def SecureCommunicationRequirement {
        doc /* All resource discovery beyond unowned onboarding and all resource access shall use authenticated and authorized OCF secure communication. */
        subject device : OCFDevice;
        require constraint {
            device.securityState == SecurityState::authorized implies
            device.deviceResource.secureOnly == true
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide high-level smart-home coordination by securely discovering OCF devices, observing environmental resources, evaluating automation policy, and controlling lights and thermostat resources. */
        subject system : OCFSmartHome;
        require constraint {
            system.targetAvailability >= 0.995
        }
    }

    requirement def CommandLatencyRequirement {
        doc /* The system shall deliver an authorized actuator command from the automation controller to the target OCF actuator within 500 ms under nominal local-network conditions. */
        subject system : OCFSmartHome;
        require constraint {
            system.network.maximumCommandLatency.value <= 500.0
        }
    }

    requirement def DiscoveryLatencyRequirement {
        doc /* The system shall discover local OCF resources within 2000 ms under nominal local multicast discovery conditions. */
        subject system : OCFSmartHome;
        require constraint {
            system.network.maximumDiscoveryLatency.value <= 2000.0
        }
    }

    requirement def ObservationRequirement {
        doc /* Observable OCF sensor resources shall publish notifications when their represented sensor value changes or when their configured sampling period expires. */
        subject sensor : TemperatureSensorDevice;
        require constraint {
            sensor.temperatureResource.observable == true and
            sensor.samplingPeriod <= 60 [s]
        }
    }

    requirement def EnergyRequirement {
        doc /* The deployed OCF smart-home system shall support automation policies that reduce unnecessary lighting and climate-control energy use while preserving occupancy-based comfort. */
        subject system : OCFSmartHome;
        require constraint {
            system.controller.commandRetryLimit <= 3
        }
    }

    satisfy PrimaryFunctionRequirement by OCFSmartHome::performPrimaryFunction;
    satisfy InteroperabilityRequirement by OCFSmartHome::network;
    satisfy CommandLatencyRequirement by OCFSmartHome::network;
    satisfy DiscoveryLatencyRequirement by OCFSmartHome::network;
    satisfy EnergyRequirement by OCFSmartHome::controller;
}