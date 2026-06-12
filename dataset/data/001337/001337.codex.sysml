package AllJoynBasedSmartEnvironmentSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Percentage :> Real {
        doc /* Percent value in range 0..100. */
    }

    attribute def TemperatureCelsius :> Real {
        doc /* Temperature measured in degree Celsius. */
    }

    attribute def IlluminanceLux :> Real {
        doc /* Illuminance measured in lux. */
    }

    attribute def PowerWatt :> Real {
        doc /* Electrical power measured in watts. */
    }

    attribute def VoltageVolt :> Real {
        doc /* Electrical potential measured in volts. */
    }

    attribute def CurrentAmpere :> Real {
        doc /* Electrical current measured in amperes. */
    }

    attribute def DataRateMbps :> Real {
        doc /* Network throughput measured in megabits per second. */
    }

    attribute def TimeSecond :> Real {
        doc /* Time duration measured in seconds. */
    }

    attribute def DeviceIdentifier :> String;
    attribute def ServiceName :> String;
    attribute def InterfaceName :> String;
    attribute def ObjectPath :> String;
    attribute def SessionIdentifier :> Integer;
    attribute def MessagePayload :> String;
    attribute def SecurityCredential :> String;

    item def AllJoynAdvertisement {
        attribute serviceName : ServiceName;
        attribute interfaceName : InterfaceName;
        attribute objectPath : ObjectPath;
        attribute producerDeviceId : DeviceIdentifier;
    }

    item def AllJoynSignal {
        attribute interfaceName : InterfaceName;
        attribute memberName : String;
        attribute objectPath : ObjectPath;
        attribute payload : MessagePayload;
        attribute senderDeviceId : DeviceIdentifier;
    }

    item def AllJoynMethodCall {
        attribute interfaceName : InterfaceName;
        attribute memberName : String;
        attribute objectPath : ObjectPath;
        attribute payload : MessagePayload;
        attribute callerDeviceId : DeviceIdentifier;
        attribute sessionId : SessionIdentifier;
    }

    item def AllJoynMethodReply {
        attribute payload : MessagePayload;
        attribute success : Boolean;
        attribute diagnosticText : String;
        attribute sessionId : SessionIdentifier;
    }

    item def SensorSample {
        attribute sourceDeviceId : DeviceIdentifier;
        attribute timestampS : TimeSecond;
    }

    item def TemperatureSample :> SensorSample {
        attribute temperature : TemperatureCelsius;
    }

    item def OccupancySample :> SensorSample {
        attribute occupied : Boolean;
        attribute confidence : Percentage;
    }

    item def LightSample :> SensorSample {
        attribute illuminance : IlluminanceLux;
    }

    item def DeviceCommand {
        attribute targetDeviceId : DeviceIdentifier;
        attribute commandName : String;
        attribute commandPayload : MessagePayload;
        attribute priority : Integer;
    }

    item def DeviceStatus {
        attribute deviceId : DeviceIdentifier;
        attribute online : Boolean;
        attribute faulted : Boolean;
        attribute statusText : String;
    }

    port def AllJoynBusPort {
        out advertisement : AllJoynAdvertisement;
        in discoveredAdvertisement : AllJoynAdvertisement;
        out signalOut : AllJoynSignal;
        in signalIn : AllJoynSignal;
        out methodCallOut : AllJoynMethodCall;
        in methodCallIn : AllJoynMethodCall;
        out methodReplyOut : AllJoynMethodReply;
        in methodReplyIn : AllJoynMethodReply;
    }

    port def SensorDataPort {
        out temperatureSample : TemperatureSample;
        out occupancySample : OccupancySample;
        out lightSample : LightSample;
    }

    port def CommandPort {
        in command : DeviceCommand;
        out status : DeviceStatus;
    }

    port def PowerPort {
        in supplyVoltage : VoltageVolt;
        in supplyCurrent : CurrentAmpere;
        out consumedPower : PowerWatt;
    }

    port def UserControlPort {
        in requestedMode : String;
        in requestedTemperature : TemperatureCelsius;
        in requestedLightLevel : Percentage;
        out displayedStatus : String;
    }

    part def AllJoynRouterNode {
        attribute routerDeviceId : DeviceIdentifier;
        attribute maxSessionCount : Integer;
        attribute activeSessionCount : Integer;
        attribute nominalDataRate : DataRateMbps;
        attribute discoveryEnabled : Boolean;
        attribute authenticationRequired : Boolean;

        port bus : AllJoynBusPort;
        port power : PowerPort;

        action advertiseService {
            in serviceName : ServiceName;
            in interfaceName : InterfaceName;
            in objectPath : ObjectPath;
            out advertisement : AllJoynAdvertisement;
        }

        action routeMethodCall {
            in request : AllJoynMethodCall;
            out routedRequest : AllJoynMethodCall;
        }

        action routeSignal {
            in signal : AllJoynSignal;
            out routedSignal : AllJoynSignal;
        }

        action establishSession {
            in requesterDeviceId : DeviceIdentifier;
            in serviceName : ServiceName;
            out sessionId : SessionIdentifier;
            out accepted : Boolean;
        }

        state machine routerLifecycle {
            state poweredOff;
            state initializing;
            state discovering;
            state routing;
            state degraded;
            state faulted;

            transition first poweredOff;
            transition powerApplied from poweredOff to initializing;
            transition initialized from initializing to discovering;
            transition servicesFound from discovering to routing;
            transition discoveryTimeout from discovering to degraded;
            transition routeFault from routing to degraded;
            transition recovered from degraded to routing;
            transition unrecoverableFault from degraded to faulted;
            transition shutdown from routing to poweredOff;
            transition reset from faulted to initializing;
        }
    }

    part def AllJoynServiceFramework {
        attribute supportedProtocolVersion : String = "AllJoyn Core 16.04";
        attribute introspectionEnabled : Boolean = true;
        attribute secureInterfaceDefault : Boolean = true;
        attribute serviceDiscoveryPeriod : TimeSecond = 5.0;

        port bus : AllJoynBusPort;

        action discoverServices {
            in advertisement : AllJoynAdvertisement;
            out accepted : Boolean;
        }

        action introspectRemoteObject {
            in serviceName : ServiceName;
            in objectPath : ObjectPath;
            out interfaceDescription : MessagePayload;
        }

        action invokeRemoteMethod {
            in call : AllJoynMethodCall;
            out reply : AllJoynMethodReply;
        }

        action publishSignal {
            in signal : AllJoynSignal;
        }
    }

    part def EnvironmentalSensorDevice {
        attribute deviceId : DeviceIdentifier;
        attribute advertisedServiceName : ServiceName = "org.example.environment.Sensor";
        attribute alljoynObjectPath : ObjectPath = "/Environment/Sensor";
        attribute samplePeriod : TimeSecond = 2.0;
        attribute measuredTemperature : TemperatureCelsius;
        attribute measuredIlluminance : IlluminanceLux;
        attribute occupied : Boolean;
        attribute occupancyConfidence : Percentage;
        attribute online : Boolean;

        port bus : AllJoynBusPort;
        port sensorData : SensorDataPort;
        port power : PowerPort;

        action sampleEnvironment {
            out temperature : TemperatureSample;
            out occupancy : OccupancySample;
            out light : LightSample;
        }

        action publishSensorSignal {
            in temperature : TemperatureSample;
            in occupancy : OccupancySample;
            in light : LightSample;
            out signal : AllJoynSignal;
        }

        state machine sensorLifecycle {
            state off;
            state joiningBus;
            state advertising;
            state sampling;
            state reportingFault;

            transition first off;
            transition powerOn from off to joiningBus;
            transition busJoined from joiningBus to advertising;
            transition serviceAdvertised from advertising to sampling;
            transition sensorFailure from sampling to reportingFault;
            transition faultCleared from reportingFault to sampling;
            transition powerOff from sampling to off;
        }
    }

    part def SmartThermostatDevice {
        attribute deviceId : DeviceIdentifier;
        attribute advertisedServiceName : ServiceName = "org.example.environment.Thermostat";
        attribute alljoynObjectPath : ObjectPath = "/Environment/Thermostat";
        attribute currentTemperature : TemperatureCelsius;
        attribute setpointTemperature : TemperatureCelsius = 22.0;
        attribute heatingEnabled : Boolean;
        attribute coolingEnabled : Boolean;
        attribute hvacOutputPower : PowerWatt;
        attribute online : Boolean;

        port bus : AllJoynBusPort;
        port commandPort : CommandPort;
        port power : PowerPort;

        action receiveTemperatureSignal {
            in signal : AllJoynSignal;
            out temperature : TemperatureSample;
        }

        action regulateTemperature {
            in measuredTemperature : TemperatureCelsius;
            in setpoint : TemperatureCelsius;
            out heatCommand : Boolean;
            out coolCommand : Boolean;
        }

        action exposeAllJoynMethods {
            in methodCall : AllJoynMethodCall;
            out reply : AllJoynMethodReply;
        }

        state machine thermostatControl {
            state unavailable;
            state idle;
            state heating;
            state cooling;
            state faulted;

            transition first unavailable;
            transition connected from unavailable to idle;
            transition belowSetpoint from idle to heating;
            transition aboveSetpoint from idle to cooling;
            transition setpointReachedFromHeat from heating to idle;
            transition setpointReachedFromCool from cooling to idle;
            transition equipmentFault from heating to faulted;
            transition equipmentFault2 from cooling to faulted;
            transition reset from faulted to idle;
            transition disconnected from idle to unavailable;
        }
    }

    part def SmartLightingDevice {
        attribute deviceId : DeviceIdentifier;
        attribute advertisedServiceName : ServiceName = "org.example.environment.Lighting";
        attribute alljoynObjectPath : ObjectPath = "/Environment/Lighting";
        attribute commandedBrightness : Percentage = 50.0;
        attribute measuredIlluminance : IlluminanceLux;
        attribute occupied : Boolean;
        attribute lampPower : PowerWatt;
        attribute online : Boolean;

        port bus : AllJoynBusPort;
        port commandPort : CommandPort;
        port power : PowerPort;

        action receiveOccupancyAndLightSignals {
            in occupancySignal : AllJoynSignal;
            in lightSignal : AllJoynSignal;
            out occupancy : OccupancySample;
            out light : LightSample;
        }

        action computeBrightness {
            in occupied : Boolean;
            in illuminance : IlluminanceLux;
            out brightness : Percentage;
        }

        action applyBrightness {
            in brightness : Percentage;
            out status : DeviceStatus;
        }

        state machine lightingControl {
            state off;
            state standby;
            state illuminated;
            state dimmed;
            state faulted;

            transition first off;
            transition connected from off to standby;
            transition occupancyDetected from standby to illuminated;
            transition sufficientDaylight from illuminated to dimmed;
            transition areaVacant from illuminated to standby;
            transition areaVacant2 from dimmed to standby;
            transition driverFault from illuminated to faulted;
            transition reset from faulted to standby;
        }
    }

    part def UserGatewayApplication {
        attribute deviceId : DeviceIdentifier;
        attribute advertisedServiceName : ServiceName = "org.example.environment.UserGateway";
        attribute alljoynObjectPath : ObjectPath = "/Environment/Gateway";
        attribute preferredTemperature : TemperatureCelsius = 22.0;
        attribute preferredBrightness : Percentage = 60.0;
        attribute currentMode : String = "Automatic";
        attribute authenticated : Boolean;

        port bus : AllJoynBusPort;
        port userControl : UserControlPort;
        port power : PowerPort;

        action discoverControllableDevices {
            in advertisement : AllJoynAdvertisement;
            out deviceStatus : DeviceStatus;
        }

        action requestTemperatureSetpoint {
            in targetDeviceId : DeviceIdentifier;
            in setpoint : TemperatureCelsius;
            out methodCall : AllJoynMethodCall;
        }

        action requestLightingLevel {
            in targetDeviceId : DeviceIdentifier;
            in brightness : Percentage;
            out methodCall : AllJoynMethodCall;
        }

        action renderStatus {
            in thermostatStatus : DeviceStatus;
            in lightingStatus : DeviceStatus;
            out displayedStatus : String;
        }

        state machine gatewayLifecycle {
            state notConnected;
            state joiningBus;
            state discoveringDevices;
            state interactiveControl;
            state limitedConnectivity;
            state lockedOut;

            transition first notConnected;
            transition networkAvailable from notConnected to joiningBus;
            transition joinedBus from joiningBus to discoveringDevices;
            transition devicesDiscovered from discoveringDevices to interactiveControl;
            transition partialDiscovery from discoveringDevices to limitedConnectivity;
            transition connectivityRestored from limitedConnectivity to interactiveControl;
            transition authenticationFailure from joiningBus to lockedOut;
            transition reauthenticate from lockedOut to joiningBus;
        }
    }

    part def SecurityManager {
        attribute trustStoreVersion : String;
        attribute authenticationTimeout : TimeSecond = 30.0;
        attribute activeCredentialCount : Integer;
        attribute encryptionRequired : Boolean = true;

        port bus : AllJoynBusPort;

        action authenticatePeer {
            in peerDeviceId : DeviceIdentifier;
            in credential : SecurityCredential;
            out authenticated : Boolean;
        }

        action authorizeMethodCall {
            in call : AllJoynMethodCall;
            out permitted : Boolean;
        }

        action rotateCredential {
            in deviceId : DeviceIdentifier;
            out newCredential : SecurityCredential;
        }

        state machine securityLifecycle {
            state locked;
            state provisioning;
            state operational;
            state credentialExpired;
            state compromised;

            transition first locked;
            transition beginProvisioning from locked to provisioning;
            transition provisioned from provisioning to operational;
            transition credentialAgingLimitReached from operational to credentialExpired;
            transition credentialRotated from credentialExpired to operational;
            transition intrusionDetected from operational to compromised;
            transition revokeAndReprovision from compromised to provisioning;
        }
    }

    part def AllJoynSmartEnvironmentSystem {
        doc /*
        Primary function: provide a local, peer-to-peer AllJoyn-based smart environment system that discovers nearby devices, exposes interoperable service interfaces, exchanges sensor events and control commands, and coordinates comfort, lighting, and user control without requiring a cloud service.
        */

        attribute systemName : String = "AllJoyn Smart Environment System";
        attribute requiredAvailability : Percentage = 99.0;
        attribute maximumDiscoveryLatency : TimeSecond = 10.0;
        attribute maximumCommandLatency : TimeSecond = 1.0;
        attribute nominalBusDataRate : DataRateMbps = 54.0;

        part router : AllJoynRouterNode {
            attribute routerDeviceId = "alljoyn-router-001";
            attribute maxSessionCount = 64;
            attribute nominalDataRate = 54.0;
            attribute discoveryEnabled = true;
            attribute authenticationRequired = true;
        }

        part framework : AllJoynServiceFramework;

        part sensor : EnvironmentalSensorDevice {
            attribute deviceId = "environment-sensor-001";
            attribute samplePeriod = 2.0;
            attribute online = true;
        }

        part thermostat : SmartThermostatDevice {
            attribute deviceId = "thermostat-001";
            attribute setpointTemperature = 22.0;
            attribute online = true;
        }

        part lighting : SmartLightingDevice {
            attribute deviceId = "lighting-001";
            attribute commandedBrightness = 50.0;
            attribute online = true;
        }

        part gateway : UserGatewayApplication {
            attribute deviceId = "gateway-001";
            attribute currentMode = "Automatic";
            attribute authenticated = true;
        }

        part security : SecurityManager {
            attribute trustStoreVersion = "2026.06";
            attribute activeCredentialCount = 5;
            attribute encryptionRequired = true;
        }

        connect router.bus to framework.bus;
        connect router.bus to sensor.bus;
        connect router.bus to thermostat.bus;
        connect router.bus to lighting.bus;
        connect router.bus to gateway.bus;
        connect router.bus to security.bus;

        connect sensor.sensorData to thermostat.commandPort;
        connect sensor.sensorData to lighting.commandPort;

        flow sensor.bus.signalOut to router.bus.signalIn;
        flow router.bus.signalOut to thermostat.bus.signalIn;
        flow router.bus.signalOut to lighting.bus.signalIn;
        flow gateway.bus.methodCallOut to router.bus.methodCallIn;
        flow router.bus.methodCallOut to thermostat.bus.methodCallIn;
        flow router.bus.methodCallOut to lighting.bus.methodCallIn;
        flow thermostat.bus.methodReplyOut to router.bus.methodReplyIn;
        flow lighting.bus.methodReplyOut to router.bus.methodReplyIn;
        flow router.bus.methodReplyOut to gateway.bus.methodReplyIn;

        action coordinateEnvironment {
            in temperature : TemperatureSample;
            in occupancy : OccupancySample;
            in light : LightSample;
            in userMode : String;
            out thermostatCommand : DeviceCommand;
            out lightingCommand : DeviceCommand;

            first start;
            then evaluateOccupancy;
            then evaluateTemperature;
            then evaluateLighting;
            then publishAllJoynCommands;
            then done;
        }

        state machine systemOperationalState {
            state unpowered;
            state bootstrapping;
            state discoveringAllJoynServices;
            state provisioningSecurity;
            state operatingAutomatically;
            state userOverride;
            state degradedLocalOperation;
            state securedShutdown;

            transition first unpowered;
            transition powerApplied from unpowered to bootstrapping;
            transition busReady from bootstrapping to discoveringAllJoynServices;
            transition servicesDiscovered from discoveringAllJoynServices to provisioningSecurity;
            transition peersAuthenticated from provisioningSecurity to operatingAutomatically;
            transition manualRequestReceived from operatingAutomatically to userOverride;
            transition overrideExpired from userOverride to operatingAutomatically;
            transition deviceUnavailable from operatingAutomatically to degradedLocalOperation;
            transition deviceRecovered from degradedLocalOperation to operatingAutomatically;
            transition shutdownRequested from operatingAutomatically to securedShutdown;
            transition shutdownComplete from securedShutdown to unpowered;
        }
    }

    requirement def AllJoynBasedSystemRequirement {
        subject system : AllJoynSmartEnvironmentSystem;
    }

    requirement primaryFunctionRequirement : AllJoynBasedSystemRequirement {
        doc /*
        The system shall use AllJoyn local peer-to-peer service discovery, session establishment, method calls, replies, and signals to coordinate environmental sensing, thermostat control, lighting control, and user commands on a local network.
        */
        require constraint {
            system.maximumDiscoveryLatency <= 10.0 and
            system.maximumCommandLatency <= 1.0
        }
    }

    requirement localOperationRequirement : AllJoynBasedSystemRequirement {
        doc /*
        The system shall perform its core comfort and lighting coordination functions without depending on a cloud service after devices have joined the local AllJoyn bus.
        */
        require constraint {
            system.requiredAvailability >= 99.0
        }
    }

    requirement discoveryRequirement : AllJoynBasedSystemRequirement {
        doc /*
        Each controllable or sensing device shall advertise an AllJoyn service name, object path, and interface name so that the gateway and peer devices can discover and introspect the service.
        */
    }

    requirement interoperabilityRequirement : AllJoynBasedSystemRequirement {
        doc /*
        Sensor, thermostat, lighting, security, and gateway parts shall exchange typed AllJoyn advertisements, signals, method calls, and method replies using explicit interfaces and object paths.
        */
    }

    requirement securityRequirement : AllJoynBasedSystemRequirement {
        doc /*
        The system shall authenticate peers and authorize AllJoyn method calls before allowing commands that change thermostat setpoints, lighting brightness, or security credentials.
        */
        require constraint {
            system.security.encryptionRequired == true
        }
    }

    requirement latencyRequirement : AllJoynBasedSystemRequirement {
        doc /*
        A user command issued through the gateway shall be delivered to the target AllJoyn device and acknowledged within one second during normal local network operation.
        */
        require constraint {
            system.maximumCommandLatency <= 1.0
        }
    }

    requirement sensorReportingRequirement : AllJoynBasedSystemRequirement {
        doc /*
        The environmental sensor shall publish temperature, occupancy, and illuminance changes as AllJoyn signals at least every two seconds during normal operation.
        */
        require constraint {
            system.sensor.samplePeriod <= 2.0
        }
    }

    requirement gracefulDegradationRequirement : AllJoynBasedSystemRequirement {
        doc /*
        If one peer device becomes unavailable, remaining authenticated devices shall continue local AllJoyn operation in a degraded state and recover automatically when the peer advertises its service again.
        */
    }

    satisfy primaryFunctionRequirement by AllJoynSmartEnvironmentSystem;
    satisfy localOperationRequirement by AllJoynSmartEnvironmentSystem;
    satisfy discoveryRequirement by AllJoynServiceFramework;
    satisfy interoperabilityRequirement by AllJoynRouterNode;
    satisfy securityRequirement by SecurityManager;
    satisfy latencyRequirement by AllJoynRouterNode;
    satisfy sensorReportingRequirement by EnvironmentalSensorDevice;
    satisfy gracefulDegradationRequirement by AllJoynSmartEnvironmentSystem;
}