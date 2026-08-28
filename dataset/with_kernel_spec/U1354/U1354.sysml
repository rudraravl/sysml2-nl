package IoTAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        // ---- Value types ----
        attribute def TemperatureValue :> ISQ::TemperatureValue;
        attribute def HumidityValue :> ScalarValues::Real;
        attribute def PowerValue :> ISQ::PowerValue;
        attribute def LightLevelValue :> ScalarValues::Real;

        // ---- Data types ----
        attribute def SensorMeasurement {
            attribute timestamp: String;
            attribute sensorId: String;
            attribute value: Real;
        }
        attribute def ActuatorCommand {
            attribute actuatorId: String;
            attribute command: String;
            attribute parameter: Real = 0;
        }
        attribute def DeviceDescriptor {
            attribute deviceId: String;
            attribute deviceType: String;
            attribute location: String;
        }

        // ---- Port definitions ----
        port def MqttPublish {
            out measurement: SensorMeasurement;
        }
        port def MqttSubscribe {
            in measurement: SensorMeasurement;
        }
        port def MqttCommandOut {
            out command: ActuatorCommand;
        }
        port def MqttCommandIn {
            in command: ActuatorCommand;
        }
        port def MqttBrokerPort {
            in published: SensorMeasurement;
            out delivered: SensorMeasurement;
            in cmdPublished: ActuatorCommand;
            out cmdDelivered: ActuatorCommand;
        }
        port def DashboardDataPort {
            in measurement: SensorMeasurement;
            in deviceStatus: DeviceDescriptor;
            out overrideCommand: ActuatorCommand;
        }
        port def AssetRegistryPort {
            in registration: DeviceDescriptor;
            out acknowledged: Boolean;
        }
        port def DataStorePort {
            in logged: SensorMeasurement;
        }

        // ---- Part definitions ----
        part def Sensor {
            attribute deviceId: String;
            attribute location: String;
            port publish: MqttPublish;
            port register: ~AssetRegistryPort;
            exhibit state 'sensor states': 'Sensor States';
        }
        part def TemperatureSensor :> Sensor {
            attribute maxThreshold: TemperatureValue = 22 [K];
            perform action 'measure temperature': 'Measure Temperature';
        }
        part def HumiditySensor :> Sensor {
            perform action 'measure humidity': 'Measure Humidity';
        }
        part def PowerSensor :> Sensor {
            perform action 'measure power': 'Measure Power';
        }
        part def LightSensor :> Sensor {
            perform action 'measure light': 'Measure Light';
        }

        part def Actuator {
            attribute deviceId: String;
            attribute location: String;
            port cmdIn: MqttCommandIn;
            port register: ~AssetRegistryPort;
            exhibit state 'actuator states': 'Actuator States';
        }
        part def HVACUnit :> Actuator {
            attribute mode: String = "idle";
            attribute setpoint: TemperatureValue = 22 [K];
            perform action 'control climate': 'Control Climate';
        }
        part def LightingUnit :> Actuator {
            attribute brightness: Real = 0;
            perform action 'control lighting': 'Control Lighting';
        }

        part def MqttBroker {
            port sensorPort: MqttBrokerPort;
            port commandPort: MqttBrokerPort;
        }

        part def AssetManagementService {
            port registryPort: AssetRegistryPort;
            attribute deviceInventory: DeviceDescriptor[*];
            perform action 'register device': 'Register Device';
        }

        part def AutomationRuleEngine {
            port dataIn: MqttSubscribe;
            port commandOut: MqttCommandOut;
            attribute rules: String[*];
            exhibit state 'rule engine states': 'Rule Engine States';
            perform action 'evaluate rules': 'Evaluate Rules';
        }

        part def TimeSeriesDataStore {
            port dataIn: DataStorePort;
            attribute history: SensorMeasurement[*];
            perform action 'store measurement': 'Store Measurement';
        }

        part def WebDashboard {
            port dataPort: DashboardDataPort;
            perform action 'display data': 'Display Data';
            perform action 'send override': 'Send Override';
        }

        part def CentralPlatform {
            part mqttBroker: MqttBroker;
            part assetManagement: AssetManagementService;
            part ruleEngine: AutomationRuleEngine;
            part dataStore: TimeSeriesDataStore;
            part dashboard: WebDashboard;
        }

        part def IoTSystem {
            part platform: CentralPlatform;
            part sensors: Sensor[1..*];
            part actuators: Actuator[1..*];
        }

        // ---- State definitions ----
        state def 'Sensor States' {
            state idle;
            state measuring;
            state publishing;
            transition 'idle-measuring' first idle then measuring;
            transition 'measuring-publishing' first measuring then publishing;
            transition 'publishing-idle' first publishing then idle;
        }
        state def 'Actuator States' {
            state standby;
            state active;
            transition 'standby-active'
                first standby
                accept actuatorCmd: ActuatorCommand
                if actuatorCmd.command == "activate"
                then active;
            transition 'active-standby'
                first active
                accept actuatorCmd: ActuatorCommand
                if actuatorCmd.command == "deactivate"
                then standby;
        }
        state def 'Rule Engine States' {
            state waiting;
            state evaluating;
            state dispatching;
            transition 'waiting-evaluating'
                first waiting
                accept sensorMsg: SensorMeasurement
                then evaluating;
            transition 'evaluating-dispatching' first evaluating then dispatching;
            transition 'dispatching-waiting' first dispatching then waiting;
        }

        // ---- Action definitions ----
        action def 'Measure Temperature' {
            out temp: SensorMeasurement;
        }
        action def 'Measure Humidity' {
            out humidity: SensorMeasurement;
        }
        action def 'Measure Power' {
            out power: SensorMeasurement;
        }
        action def 'Measure Light' {
            out light: SensorMeasurement;
        }
        action def 'Control Climate' {
            in cmd: ActuatorCommand;
        }
        action def 'Control Lighting' {
            in cmd: ActuatorCommand;
        }
        action def 'Register Device' {
            in descriptor: DeviceDescriptor;
            out ack: Boolean;
        }
        action def 'Evaluate Rules' {
            in measurement: SensorMeasurement;
            out command: ActuatorCommand;
        }
        action def 'Store Measurement' {
            in measurement: SensorMeasurement;
        }
        action def 'Display Data' {
            in measurement: SensorMeasurement;
            in status: DeviceDescriptor;
        }
        action def 'Send Override' {
            out command: ActuatorCommand;
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        part iotSystem: IoTSystem {
            part platform: CentralPlatform {
                part mqttBroker: MqttBroker {
                    port sensorPort: MqttBrokerPort;
                    port commandPort: MqttBrokerPort;
                }
                part assetManagement: AssetManagementService {
                    port registryPort: AssetRegistryPort;
                }
                part ruleEngine: AutomationRuleEngine {
                    port dataIn: MqttSubscribe;
                    port commandOut: MqttCommandOut;
                    exhibit state 'rule engine states': 'Rule Engine States' {
                        state waiting;
                        state evaluating;
                        state dispatching;
                        transition 'w-e'
                            first waiting
                            accept sensorMsg: SensorMeasurement
                            then evaluating;
                        transition 'e-d' first evaluating then dispatching;
                        transition 'd-w' first dispatching then waiting;
                    }
                }
                part dataStore: TimeSeriesDataStore {
                    port dataIn: DataStorePort;
                }
                part dashboard: WebDashboard {
                    port dataPort: DashboardDataPort;
                }
            }

            part sensors: Sensor[1..*] {
                part tempSensor: TemperatureSensor {
                    attribute deviceId = "TS-001";
                    attribute location = "Room-A";
                    port publish: MqttPublish;
                    port register: ~AssetRegistryPort;
                    perform action 'measure temperature': 'Measure Temperature';
                }
                part humiditySensor: HumiditySensor {
                    attribute deviceId = "HS-001";
                    attribute location = "Room-A";
                    port publish: MqttPublish;
                    port register: ~AssetRegistryPort;
                    perform action 'measure humidity': 'Measure Humidity';
                }
                part powerSensor: PowerSensor {
                    attribute deviceId = "PS-001";
                    attribute location = "MainPanel";
                    port publish: MqttPublish;
                    port register: ~AssetRegistryPort;
                    perform action 'measure power': 'Measure Power';
                }
                part lightSensor: LightSensor {
                    attribute deviceId = "LS-001";
                    attribute location = "Room-A";
                    port publish: MqttPublish;
                    port register: ~AssetRegistryPort;
                    perform action 'measure light': 'Measure Light';
                }
            }

            part actuators: Actuator[1..*] {
                part hvac: HVACUnit {
                    attribute deviceId = "HVAC-001";
                    attribute location = "Room-A";
                    port cmdIn: MqttCommandIn;
                    port register: ~AssetRegistryPort;
                    perform action 'control climate': 'Control Climate';
                }
                part lighting: LightingUnit {
                    attribute deviceId = "LIGHT-001";
                    attribute location = "Room-A";
                    port cmdIn: MqttCommandIn;
                    port register: ~AssetRegistryPort;
                    perform action 'control lighting': 'Control Lighting';
                }
            }

            // Connections: sensors to broker
            connect sensors.tempSensor.publish to platform.mqttBroker.sensorPort;
            connect sensors.humiditySensor.publish to platform.mqttBroker.sensorPort;
            connect sensors.powerSensor.publish to platform.mqttBroker.sensorPort;
            connect sensors.lightSensor.publish to platform.mqttBroker.sensorPort;

            // Broker to rule engine
            connect platform.mqttBroker.sensorPort to platform.ruleEngine.dataIn;

            // Rule engine commands to broker
            connect platform.ruleEngine.commandOut to platform.mqttBroker.commandPort;

            // Broker commands to actuators
            connect platform.mqttBroker.commandPort to actuators.hvac.cmdIn;
            connect platform.mqttBroker.commandPort to actuators.lighting.cmdIn;

            // Broker to data store
            connect platform.mqttBroker.sensorPort to platform.dataStore.dataIn;

            // Broker to dashboard
            connect platform.mqttBroker.sensorPort to platform.dashboard.dataPort;

            // Dashboard override to broker
            connect platform.dashboard.dataPort to platform.mqttBroker.commandPort;

            // Device registration
            connect sensors.tempSensor.register to platform.assetManagement.registryPort;
            connect sensors.humiditySensor.register to platform.assetManagement.registryPort;
            connect sensors.powerSensor.register to platform.assetManagement.registryPort;
            connect sensors.lightSensor.register to platform.assetManagement.registryPort;
            connect actuators.hvac.register to platform.assetManagement.registryPort;
            connect actuators.lighting.register to platform.assetManagement.registryPort;
        }

        // Operational behavior
        action 'operational cycle' {
            first start;
            then action 'sensors measure' {
                action 'temp measure': 'Measure Temperature';
                action 'humidity measure': 'Measure Humidity';
                action 'power measure': 'Measure Power';
                action 'light measure': 'Measure Light';
            }
            then action 'publish to broker' {
                in measurement: SensorMeasurement;
            }
            then action 'store data': 'Store Measurement' {
                in measurement: SensorMeasurement;
            }
            then action 'evaluate': 'Evaluate Rules' {
                in measurement: SensorMeasurement;
                out command: ActuatorCommand;
            }
            then action 'dispatch command' {
                in command: ActuatorCommand;
            }
            then action 'actuate' {
                action 'climate control': 'Control Climate';
                action 'light control': 'Control Lighting';
            }
            then merge loopBack;
            then decide;
                if true then 'sensors measure';
                else done;
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def 'Environmental Monitoring Requirement' {
            doc /* The system shall monitor temperature, humidity, power consumption, and ambient light levels in the physical space. */
        }
        requirement def 'Automated Control Requirement' {
            doc /* The rule engine shall evaluate sensor data against predefined rules and issue commands to actuators to maintain desired conditions. */
        }
        requirement def 'Data Logging Requirement' {
            doc /* All sensor measurements shall be stored with timestamps in the time-series data store for historical analysis. */
        }
        requirement def 'Communication Requirement' {
            doc /* The MQTT broker shall reliably relay sensor data and actuator commands between all distributed components. */
        }
        requirement def 'User Interface Requirement' {
            doc /* The web dashboard shall display real-time sensor data and device status, and allow manual override of automated controls. */
        }
        requirement def 'Device Registration Requirement' {
            doc /* The asset management service shall maintain an inventory of all connected devices including identity, type, and location. */
        }

        requirement 'monitoring req': 'Environmental Monitoring Requirement';
        requirement 'control req': 'Automated Control Requirement';
        requirement 'logging req': 'Data Logging Requirement';
        requirement 'comm req': 'Communication Requirement';
        requirement 'ui req': 'User Interface Requirement';
        requirement 'registration req': 'Device Registration Requirement';
    }
}
