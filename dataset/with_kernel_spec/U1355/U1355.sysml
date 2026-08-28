package SmartBuildingAutomationSystem {
	private import ScalarValues::*;

	unit degC;
	unit percent;
	unit kelvin;
	unit count;

	value Temperature :> Real;
	value Brightness :> Real;
	value ColorTemperature :> Integer;
	value PeopleCount :> Integer;

	enumeration HVACMode { off; eco; comfort; auto; }

	item def SensorData {
		attribute temperature : Temperature;
		attribute isOccupied : Boolean;
		attribute peopleCount : PeopleCount;
	}
	item def LightCommand {
		attribute isOn : Boolean;
		attribute brightness : Brightness;
		attribute colorTemp : ColorTemperature;
	}
	item def ThermostatCommand {
		attribute targetTemp : Temperature;
		attribute mode : HVACMode;
	}
	item def CloudData {
		attribute timestamp : String;
		attribute payload : String;
	}
	item def ProvisioningComplete;
	item def SyncTimer;

	port def SensorDataPort {
		out sensorData : SensorData;
	}
	port def LightCommandPort {
		in lightCommand : LightCommand;
	}
	port def ThermostatCommandPort {
		in thermostatCommand : ThermostatCommand;
	}
	port def CloudDataPort {
		out cloudData : CloudData;
	}

	part def Sensor {
		port sensorDataPort : SensorDataPort;
		perform action senseBehavior {
			action sense send new SensorData(22.0, true, 5) via sensorDataPort;
		}
	}
	part def SmartLight {
		port lightCommandPort : LightCommandPort;
		perform action lightBehavior {
			action receive accept cmd : LightCommand via lightCommandPort;
		}
	}
	part def SmartThermostat {
		port thermostatCommandPort : ThermostatCommandPort;
		perform action thermostatBehavior {
			action receive accept cmd : ThermostatCommand via thermostatCommandPort;
		}
	}
	part def CloudBridge {
		port cloudDataPort : ~CloudDataPort;
		perform action bridgeBehavior {
			action receive accept data : CloudData via cloudDataPort;
		}
	}
	part def BuildingGateway {
		port sensorDataPort : ~SensorDataPort;
		port lightCommandPort : ~LightCommandPort;
		port thermostatCommandPort : ~ThermostatCommandPort;
		port cloudDataPort : CloudDataPort;

		exhibit state gatewayBehavior {
			entry; then discovering;
			state discovering;
			transition provision
				first discovering
				accept ProvisioningComplete
				then provisioning;
			state provisioning;
			transition startOps
				first provisioning
				accept ProvisioningComplete
				then operational;
			state operational {
				entry; then collectingData;
				state collectingData;
				transition processData
					first collectingData
					accept data : SensorData via sensorDataPort
					do if data.isOccupied == false then {
						send new LightCommand(false, 0.0, 2700) via lightCommandPort;
						send new ThermostatCommand(18.0, HVACMode::eco) via thermostatCommandPort;
					} else {
						send new LightCommand(true, 100.0, 4000) via lightCommandPort;
						send new ThermostatCommand(22.0, HVACMode::comfort) via thermostatCommandPort;
					}
					then collectingData;
				transition syncData
					first collectingData
					accept SyncTimer
					do send new CloudData("now", "data") via cloudDataPort
					then collectingData;
			}
		}
	}

	requirement def EnergyEfficiencyRequirement {
		doc /* The building automation system shall optimize energy efficiency by adjusting lights and thermostats based on occupancy. */
	}
	requirement def OccupantComfortRequirement {
		doc /* The system shall maintain comfortable temperature and adequate lighting when zones are occupied. */
	}
	requirement def InteroperabilityRequirement {
		doc /* The system shall integrate IoT devices from different manufacturers via standard protocols. */
	}

	part def Building {
		requirement energyEfficiency : EnergyEfficiencyRequirement;
		requirement occupantComfort : OccupantComfortRequirement;
		requirement interoperability : InteroperabilityRequirement;

		part gateway : BuildingGateway;
		part sensor : Sensor;
		part light : SmartLight;
		part thermostat : SmartThermostat;
		part cloudBridge : CloudBridge;

		connect sensor.sensorDataPort to gateway.sensorDataPort;
		connect gateway.lightCommandPort to light.lightCommandPort;
		connect gateway.thermostatCommandPort to thermostat.thermostatCommandPort;
		connect gateway.cloudDataPort to cloudBridge.cloudDataPort;

		flow sensorDataFlow of SensorData from sensor.sensorDataPort.sensorData to gateway.sensorDataPort.sensorData;
		flow lightCommandFlow of LightCommand from gateway.lightCommandPort.lightCommand to light.lightCommandPort.lightCommand;
		flow thermostatCommandFlow of ThermostatCommand from gateway.thermostatCommandPort.thermostatCommand to thermostat.thermostatCommandPort.thermostatCommand;
		flow cloudDataFlow of CloudData from gateway.cloudDataPort.cloudData to cloudBridge.cloudDataPort.cloudData;

		satisfy energyEfficiency by gateway;
		satisfy occupantComfort by gateway;
		satisfy interoperability by gateway;
	}
}
