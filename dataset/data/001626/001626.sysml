package WebOfThingsSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def ThingDescription {
		attribute id : String;
		attribute title : String;
		attribute description : String;
		attribute properties : String[*];
		attribute actions : String[*];
		attribute events : String[*];
	}
	
	item def PropertyValue {
		attribute name : String;
		attribute value : Real;
		attribute timestamp : Real;
	}
	
	item def ActionRequest {
		attribute thingId : String;
		attribute actionName : String;
		attribute parameters : String;
	}
	
	item def ActionResponse {
		attribute thingId : String;
		attribute actionName : String;
		attribute success : Boolean;
		attribute result : String;
	}
	
	item def EventNotification {
		attribute thingId : String;
		attribute eventName : String;
		attribute data : String;
		attribute timestamp : Real;
	}
	
	attribute def TemperatureReading :> ISQ::ThermodynamicTemperatureValue;
	attribute def HumidityLevel :> Real;
	attribute def PowerConsumption :> ISQ::PowerValue;
	
	port def HTTPPort {
		in item request : String;
		out item response : String;
	}
	
	port def DataPort {
		out item data : PropertyValue;
	}
	
	port def CommandPort {
		in item command : ActionRequest;
		out item status : ActionResponse;
	}
	
	port def EventPort {
		out item notification : EventNotification;
	}
	
	part def Thing {
		attribute thingId : String;
		attribute td : ThingDescription;
		port webInterface : HTTPPort;
	}
	
	part def Sensor :> Thing {
		port dataOutput : DataPort;
		
		action def ReadValue {
			out reading : PropertyValue;
		}
	}
	
	part def TemperatureSensor :> Sensor {
		attribute currentTemp : TemperatureReading;
		
		action readTemperature : ReadValue {
			out tempReading : PropertyValue;
		}
		
		state sensorState {
			entry; then idle;
			
			state idle;
			transition idle_to_reading
				first idle
				accept readTemperature
				then reading;
			
			state reading {
				entry assign currentTemp := 293.15[SI::K];
			}
			transition reading_to_idle
				first reading
				then idle;
		}
	}
	
	part def HumiditySensor :> Sensor {
		attribute currentHumidity : HumidityLevel;
		
		action readHumidity : ReadValue {
			out humidityReading : PropertyValue;
		}
	}
	
	part def Actuator :> Thing {
		port controlInput : CommandPort;
		port eventOutput : EventPort;
		
		action def ExecuteAction {
			in request : ActionRequest;
			out response : ActionResponse;
		}
	}
	
	part def SmartThermostat :> Actuator {
		attribute targetTemp : TemperatureReading;
		attribute isHeating : Boolean;
		attribute isCooling : Boolean;
		
		action setTargetTemperature : ExecuteAction;
		action enableHeating : ExecuteAction;
		action enableCooling : ExecuteAction;
		
		state thermostatState {
			entry; then off;
			
			state off {
				entry assign isHeating := false;
				entry assign isCooling := false;
			}
			
			transition off_to_heating
				first off
				accept enableHeating
				then heating;
			
			transition off_to_cooling
				first off
				accept enableCooling
				then cooling;
			
			state heating {
				entry assign isHeating := true;
				entry assign isCooling := false;
			}
			
			state cooling {
				entry assign isHeating := false;
				entry assign isCooling := true;
			}
			
			transition heating_to_off
				first heating
				accept enableCooling
				then off;
			
			transition cooling_to_off
				first cooling
				accept enableHeating
				then off;
		}
	}
	
	part def SmartLight :> Actuator {
		attribute isOn : Boolean;
		attribute brightness : Real;
		attribute powerUsage : PowerConsumption;
		
		action toggleLight : ExecuteAction;
		action setBrightness : ExecuteAction;
	}
	
	part def WoTDirectory {
		attribute registeredThings : ThingDescription[*];
		port directoryInterface : HTTPPort;
		
		action def RegisterThing {
			in td : ThingDescription;
			out success : Boolean;
		}
		
		action def DiscoverThings {
			in query : String;
			out results : ThingDescription[*];
		}
		
		action registerNewThing : RegisterThing;
		action searchThings : DiscoverThings;
	}
	
	part def WoTGateway {
		port externalInterface : HTTPPort;
		port thingInterface : HTTPPort[*];
		
		action def RouteRequest {
			in request : String;
			out targetThing : String;
			out forwardedRequest : String;
		}
		
		action def AggregateResponses {
			in responses : String[*];
			out aggregated : String;
		}
		
		action routeToThing : RouteRequest;
		action combineData : AggregateResponses;
	}
	
	part def ApplicationServer {
		port clientInterface : HTTPPort;
		port gatewayInterface : HTTPPort;
		
		action def ProcessClientRequest {
			in clientRequest : String;
			out gatewayRequest : String;
		}
		
		action def AnalyzeData {
			in sensorData : PropertyValue[*];
			out decision : ActionRequest[*];
		}
		
		action def GenerateResponse {
			in data : String;
			out clientResponse : String;
		}
		
		action handleRequest : ProcessClientRequest;
		action analyzeEnvironment : AnalyzeData;
		action respondToClient : GenerateResponse;
	}
	
	requirement def WoTSystemRequirements {
		doc /* The Web of Things system shall enable standardized discovery, access, and control of distributed IoT devices through web protocols. */
		
		requirement <'WOT-REQ-1'> interoperabilityRequirement {
			doc /* All Things shall expose standardized Thing Descriptions enabling protocol-independent interaction. */
		}
		
		requirement <'WOT-REQ-2'> discoveryRequirement {
			doc /* The system shall provide a directory service for dynamic discovery of available Things. */
		}
		
		requirement <'WOT-REQ-3'> dataAggregationRequirement {
			doc /* The system shall aggregate data from multiple sensors to support informed decision-making. */
		}
		
		requirement <'WOT-REQ-4'> automationRequirement {
			doc /* The system shall automatically control actuators based on sensor data analysis. */
		}
		
		requirement <'WOT-REQ-5'> scalabilityRequirement {
			doc /* The system shall support addition of new Things without requiring system reconfiguration. */
		}
	}
	
	part wotSystem {
		doc /* 
		This Web of Things system enables interoperable monitoring and control of distributed IoT devices.
		Its primary function is to provide standardized web-based access to physical and virtual Things,
		allowing applications to discover, monitor, and control devices regardless of their underlying
		protocols. The system continuously collects environmental data from sensors, analyzes conditions,
		and automatically adjusts actuators to maintain optimal environmental parameters while providing
		web-based access to all connected Things through standardized interfaces.
		*/
		
		part directory : WoTDirectory;
		part gateway : WoTGateway;
		part appServer : ApplicationServer;
		
		part tempSensor1 : TemperatureSensor {
			:>> thingId = "temp-sensor-room-1";
		}
		
		part tempSensor2 : TemperatureSensor {
			:>> thingId = "temp-sensor-room-2";
		}
		
		part humiditySensor1 : HumiditySensor {
			:>> thingId = "humidity-sensor-room-1";
		}
		
		part thermostat : SmartThermostat {
			:>> thingId = "thermostat-main";
		}
		
		part light1 : SmartLight {
			:>> thingId = "light-room-1";
		}
		
		part light2 : SmartLight {
			:>> thingId = "light-room-2";
		}
		
		connect tempSensor1.webInterface to gateway.thingInterface;
		connect tempSensor2.webInterface to gateway.thingInterface;
		connect humiditySensor1.webInterface to gateway.thingInterface;
		connect thermostat.webInterface to gateway.thingInterface;
		connect light1.webInterface to gateway.thingInterface;
		connect light2.webInterface to gateway.thingInterface;
		connect directory.directoryInterface to gateway.thingInterface;
		connect gateway.externalInterface to appServer.gatewayInterface;
		
		perform action monitorAndControl {
			first start;
			then merge collectSensorData;
			
			action collectSensorData {
				action rt1 : tempSensor1.readTemperature {
					out tempReading;
				}
				action rt2 : tempSensor2.readTemperature {
					out tempReading;
				}
				action rh : humiditySensor1.readHumidity {
					out humidityReading;
				}
			}
			
			then action processData : appServer.analyzeEnvironment {
				in sensorData = (
					collectSensorData.rt1.tempReading,
					collectSensorData.rt2.tempReading,
					collectSensorData.rh.humidityReading
				);
			}
			
			then decide;
				if processData.decision != null then executeControl;
				else collectSensorData;
			
			action executeControl {
				action adjustThermostat : thermostat.setTargetTemperature;
				action controlLights : light1.toggleLight;
			}
			
			then collectSensorData;
		}
		
		satisfy WoTSystemRequirements::interoperabilityRequirement;
		satisfy WoTSystemRequirements::discoveryRequirement by directory;
		satisfy WoTSystemRequirements::dataAggregationRequirement by appServer;
		satisfy WoTSystemRequirements::automationRequirement by monitorAndControl;
		satisfy WoTSystemRequirements::scalabilityRequirement by gateway;
	}
}
