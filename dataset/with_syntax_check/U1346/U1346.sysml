package IoTivitySmartHomeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def ResourceURI :> String;
    attribute def DeviceIdentifier :> String;
    attribute def PayloadData :> String;
    
    enum def ResourceTypeEnum {
        temperature;
        humidity;
        light;
        motion;
        actuator;
    }
    
    enum def ProtocolType {
        coap;
        http;
        mqtt;
    }
    
    enum def QoSLevel {
        confirmable;
        nonConfirmable;
        acknowledgement;
    }
    
    attribute def LatencyValue :> ISQ::DurationValue;
    attribute def DataRateValue :> ISQ::DataRateValue;
    
    item def IoTivityResource {
        attribute uri : ResourceURI;
        attribute resourceType : ResourceTypeEnum;
        attribute isObservable : Boolean;
        attribute isDiscoverable : Boolean;
        attribute lastUpdated : ISQ::DurationValue;
    }
    
    item def ResourceRequest {
        attribute targetUri : ResourceURI;
        attribute method : String;
        attribute payload : PayloadData;
        attribute qos : QoSLevel;
    }
    
    item def ResourceResponse {
        attribute sourceUri : ResourceURI;
        attribute statusCode : Integer;
        attribute payload : PayloadData;
        attribute timestamp : ISQ::DurationValue;
    }
    
    port def IoTivityPort {
        out request : ResourceRequest[0..*];
        in response : ResourceResponse[0..*];
    }
    
    part def IoTDevice {
        attribute deviceId : DeviceIdentifier;
        attribute powerConsumption : ISQ::PowerValue;
        port iotPort : IoTivityPort;
    }
    
    part def TemperatureSensor :> IoTDevice {
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute samplingInterval : ISQ::DurationValue = 2.0 [SI::s];
        attribute :>> powerConsumption = 0.5 [SI::W];
        
        item sensorResource : IoTivityResource {
            :>> uri = "/sensors/temperature";
            :>> resourceType = ResourceTypeEnum::temperature;
            :>> isObservable = true;
            :>> isDiscoverable = true;
        }
    }
    
    part def HumiditySensor :> IoTDevice {
        attribute currentHumidity : Real;
        attribute samplingInterval : ISQ::DurationValue = 3.0 [SI::s];
        attribute :>> powerConsumption = 0.4 [SI::W];
        
        item sensorResource : IoTivityResource {
            :>> uri = "/sensors/humidity";
            :>> resourceType = ResourceTypeEnum::humidity;
            :>> isObservable = true;
            :>> isDiscoverable = true;
        }
    }
    
    part def MotionSensor :> IoTDevice {
        attribute motionDetected : Boolean;
        attribute detectionRange : ISQ::LengthValue = 5.0 [SI::m];
        attribute :>> powerConsumption = 0.3 [SI::W];
        
        item sensorResource : IoTivityResource {
            :>> uri = "/sensors/motion";
            :>> resourceType = ResourceTypeEnum::motion;
            :>> isObservable = true;
            :>> isDiscoverable = true;
        }
    }
    
    part def SmartLightActuator :> IoTDevice {
        attribute brightness : Real;
        attribute isOn : Boolean;
        attribute :>> powerConsumption = 10.0 [SI::W];
        
        item actuatorResource : IoTivityResource {
            :>> uri = "/actuators/light";
            :>> resourceType = ResourceTypeEnum::actuator;
            :>> isObservable = true;
            :>> isDiscoverable = true;
        }
    }
    
    part def IoTivityServer :> IoTDevice {
        attribute maxConnections : Integer = 100;
        attribute activeConnections : Integer;
        attribute registeredResourceCount : Integer;
        attribute :>> powerConsumption = 20.0 [SI::W];
        port serverPort : IoTivityPort;
    }
    
    part def IoTGateway :> IoTDevice {
        attribute protocol : ProtocolType = ProtocolType::coap;
        attribute maxThroughput : DataRateValue = 50.0e6 [SI::Hz];
        attribute networkLatency : LatencyValue = 0.1 [SI::s];
        attribute :>> powerConsumption = 12.0 [SI::W];
        port gatewayPort : IoTivityPort;
    }
    
    action def DiscoverResources {
        in searchType : ResourceTypeEnum;
        out discoveredResources : IoTivityResource[0..*];
        
        first start;
        then action broadcastDiscovery {
            out discoveryRequest : ResourceRequest;
        }
        then action collectResponses {
            in responses : ResourceResponse[0..*];
        }
        then action filterResults {
            in allResources = collectResponses.responses;
            out filteredResources : IoTivityResource[0..*];
        }
        then done;
    }
    
    action def RegisterResource {
        in resource : IoTivityResource;
        out registrationSuccess : Boolean;
        
        first start;
        then action validateResource {
            in res = resource;
            out isValid : Boolean;
        }
        then decide;
            if validateResource.isValid then addToRegistry;
            if not validateResource.isValid then registrationFailed;
        action addToRegistry {
            in res = resource;
        }
        then done;
        action registrationFailed;
        then done;
    }
    
    action def ObserveResource {
        in targetUri : ResourceURI;
        out observedData : PayloadData;
        
        first start;
        then merge observeLoop;
        action sendObserveRequest {
            in uri = targetUri;
            out request : ResourceRequest;
        }
        then action waitForNotification {
            in req = sendObserveRequest.request;
            out notification : ResourceResponse;
        }
        then action extractData {
            in notif = waitForNotification.notification;
            out data : PayloadData;
        }
        then observeLoop;
    }
    
    action def UpdateResource {
        in targetUri : ResourceURI;
        in newValue : PayloadData;
        out updateSuccess : Boolean;
        
        first start;
        then action createUpdateRequest {
            in uri = targetUri;
            in value = newValue;
            out request : ResourceRequest;
        }
        then action sendUpdate {
            in req = createUpdateRequest.request;
        }
        then action receiveConfirmation {
            out confirmation : ResourceResponse;
        }
        then decide;
            if receiveConfirmation.confirmation.statusCode == 200 then updateSucceeded;
            if receiveConfirmation.confirmation.statusCode != 200 then updateFailed;
        action updateSucceeded;
        then done;
        action updateFailed;
        then done;
    }
    
    state def IoTDeviceLifecycle {
        entry; then uninitialized;
        
        state uninitialized;
        transition first uninitialized
            then initializing;
        
        state initializing;
        transition first initializing
            then discovering;
        
        state discovering;
        transition first discovering
            then registering;
        
        state registering;
        transition first registering
            then operational;
        
        state operational {
            state idle;
            state publishing;
            state observing;
            state updating;
            
            transition first idle
                then publishing;
            transition first publishing
                then idle;
            transition first idle
                then observing;
            transition first idle
                then updating;
        }
        
        transition first operational
            then error;
        
        state error;
        transition first error
            then recovering;
        
        state recovering;
        transition first recovering
            then operational;
        transition first recovering
            then error;
        
        transition first operational
            then shutdown;
        
        state shutdown;
        then done;
    }
    
    action def IoTivitySystemOperation {
        first start;
        then action initializeServer {
            out serverReady : Boolean;
        }
        then merge mainLoop;
        
        action discoverDevices : DiscoverResources {
            in searchType = ResourceTypeEnum::temperature;
            out foundDevices : IoTivityResource[0..*];
        }
        then action registerDiscoveredDevices {
            in devices = discoverDevices.foundDevices;
            out registrationResults : Boolean[0..*];
        }
        then action monitorSensors : ObserveResource {
            in targetUri = "/sensors/temperature";
            out sensorData : PayloadData;
        }
        then action analyzeData {
            in data = monitorSensors.sensorData;
            out controlDecision : Boolean;
        }
        then decide;
            if analyzeData.controlDecision then controlActuators;
            if not analyzeData.controlDecision then mainLoop;
        
        action controlActuators : UpdateResource {
            in targetUri = "/actuators/light";
            in newValue = "ON";
            out controlSuccess : Boolean;
        }
        then mainLoop;
    }
    
    requirement def InteroperabilityRequirement {
        doc /* The system shall enable seamless communication and resource 
             * sharing between heterogeneous IoT devices using IoTivity 
             * standard protocols. */
        subject system : IoTivitySmartHomeSystem;
    }
    
    requirement <'REQ-001'> primaryFunction {
        doc /* The IoTivity-based smart home system shall automatically discover, 
             * register, monitor, and control IoT devices to provide intelligent 
             * environmental management and automation. */
        subject system : IoTivitySmartHomeSystem;
    }
    
    requirement <'REQ-002'> discoveryTime {
        doc /* The system shall discover and register new IoT devices within 
             * 10 seconds of device availability. */
        subject server : IoTivityServer;
    }
    
    requirement <'REQ-003'> scalability {
        doc /* The IoTivity server shall support at least 100 concurrent 
             * device connections. */
        subject server : IoTivityServer;
        require constraint {
            server.maxConnections >= 100
        }
    }
    
    requirement <'REQ-004'> latency {
        doc /* Resource state updates shall be propagated with network latency 
             * not exceeding 200 milliseconds. */
        subject gateway : IoTGateway;
        require constraint {
            gateway.networkLatency <= 0.2 [SI::s]
        }
    }
    
    requirement <'REQ-005'> powerEfficiency {
        doc /* The total system power consumption shall not exceed 50 watts 
             * during normal operation. */
        subject system : IoTivitySmartHomeSystem;
    }
    
    part smartHomeSystem : IoTivitySmartHomeSystem {
        doc /* IoTivity-based smart home automation system that discovers and 
             * manages IoT devices for environmental monitoring and intelligent 
             * control. The system uses CoAP protocol for resource discovery, 
             * observation, and manipulation, enabling interoperable communication 
             * between sensors and actuators to maintain optimal home conditions. */
        
        attribute totalPowerConsumption : ISQ::PowerValue;
        attribute systemLatency : LatencyValue;
        
        part server : IoTivityServer {
            attribute :>> deviceId = "IOTIVITY_SERVER_MAIN";
            attribute :>> activeConnections = 0;
            attribute :>> registeredResourceCount = 0;
        }
        
        part gateway : IoTGateway {
            attribute :>> deviceId = "GATEWAY_001";
            attribute :>> networkLatency = 0.15 [SI::s];
        }
        
        part tempSensor1 : TemperatureSensor {
            attribute :>> deviceId = "TEMP_SENSOR_LIVING";
            attribute :>> currentTemperature = 295.65 [SI::K];
        }
        
        part tempSensor2 : TemperatureSensor {
            attribute :>> deviceId = "TEMP_SENSOR_BEDROOM";
            attribute :>> currentTemperature = 294.15 [SI::K];
        }
        
        part humiditySensor1 : HumiditySensor {
            attribute :>> deviceId = "HUMIDITY_SENSOR_LIVING";
            attribute :>> currentHumidity = 45.0;
        }
        
        part motionSensor1 : MotionSensor {
            attribute :>> deviceId = "MOTION_SENSOR_ENTRANCE";
            attribute :>> motionDetected = false;
        }
        
        part smartLight1 : SmartLightActuator {
            attribute :>> deviceId = "LIGHT_LIVING_ROOM";
            attribute :>> brightness = 75.0;
            attribute :>> isOn = true;
        }
        
        part smartLight2 : SmartLightActuator {
            attribute :>> deviceId = "LIGHT_BEDROOM";
            attribute :>> brightness = 50.0;
            attribute :>> isOn = false;
        }
        
        connection serverToGateway connect server.serverPort to gateway.gatewayPort;
        connection gatewayToTemp1 connect gateway.iotPort to tempSensor1.iotPort;
        connection gatewayToTemp2 connect gateway.iotPort to tempSensor2.iotPort;
        connection gatewayToHumidity connect gateway.iotPort to humiditySensor1.iotPort;
        connection gatewayToMotion connect gateway.iotPort to motionSensor1.iotPort;
        connection gatewayToLight1 connect gateway.iotPort to smartLight1.iotPort;
        connection gatewayToLight2 connect gateway.iotPort to smartLight2.iotPort;
        
        perform action systemOperation : IoTivitySystemOperation;
        
        assert constraint totalPowerConstraint {
            totalPowerConsumption == server.powerConsumption + gateway.powerConsumption +
                tempSensor1.powerConsumption + tempSensor2.powerConsumption +
                humiditySensor1.powerConsumption + motionSensor1.powerConsumption +
                smartLight1.powerConsumption + smartLight2.powerConsumption
        }
        
        assert constraint powerLimit {
            totalPowerConsumption <= 50.0 [SI::W]
        }
    }
    
    satisfy primaryFunction by smartHomeSystem.systemOperation;
    satisfy discoveryTime by smartHomeSystem.server;
    satisfy scalability by smartHomeSystem.server;
    satisfy latency by smartHomeSystem.gateway;
    satisfy powerEfficiency by smartHomeSystem;
}
