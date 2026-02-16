package 'Home System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
	attribute def Humidity :> Real;
	attribute def LightIntensity :> ISQ::LuminousIntensityValue;
	attribute def AirQuality :> Real;
	attribute def OccupancyLevel :> Integer;
	attribute def EnergyRate :> ISQ::PowerValue;
	
	enum def OccupancyState {
		vacant;
		occupied;
		sleeping;
	}
	
	enum def SecurityState {
		disarmed;
		armed_home;
		armed_away;
		alarm;
	}
	
	enum def ClimateMode {
		off;
		heating;
		cooling;
		auto;
	}
	
	item def ClimateSetpoint {
		attribute targetTemperature : Temperature;
		attribute targetHumidity : Humidity;
		attribute mode : ClimateMode;
	}
	
	item def LightingCommand {
		attribute intensity : LightIntensity;
		attribute zone : String;
		attribute enabled : Boolean;
	}
	
	item def SecurityCommand {
		attribute commandState : SecurityState;
		attribute zones : String[*];
	}
	
	item def EnvironmentalData {
		attribute temperature : Temperature;
		attribute humidity : Humidity;
		attribute airQuality : AirQuality;
		attribute lightLevel : LightIntensity;
	}
	
	port def EnvironmentalSensorPort {
		out envData : EnvironmentalData;
	}
	
	port def OccupancySensorPort {
		out occupancy : OccupancyState;
		out count : OccupancyLevel;
	}
	
	port def ClimateControlPort {
		in setpoint : ClimateSetpoint;
		out currentTemp : Temperature;
		out powerDraw : EnergyRate;
	}
	
	port def LightingControlPort {
		in command : LightingCommand;
		out status : Boolean;
		out powerDraw : EnergyRate;
	}
	
	port def SecurityControlPort {
		in command : SecurityCommand;
		out currentState : SecurityState;
		out alerts : String[*];
	}
	
	port def EnergyMonitorPort {
		in totalLoad : EnergyRate;
		out optimizationSignal : Boolean;
	}
	
	part def EnvironmentalSensor {
		port output : EnvironmentalSensorPort;
		attribute sampleRate : ISQ::FrequencyValue;
	}
	
	part def OccupancySensor {
		port output : OccupancySensorPort;
		attribute detectionRange : ISQ::LengthValue;
	}
	
	part def ClimateControlSystem {
		port controlInterface : ClimateControlPort;
		part hvacUnit {
			attribute capacity : EnergyRate;
		}
		part thermostat {
			attribute precision : Temperature;
		}
		part airHandler;
		part ductwork;
	}
	
	part def LightingSystem {
		port controlInterface : LightingControlPort;
		part fixtures[*] {
			attribute maxIntensity : LightIntensity;
		}
		part controllers[*];
		part dimmers[*];
	}
	
	part def SecuritySystem {
		port controlInterface : SecurityControlPort;
		part cameras[*] {
			attribute resolution : String;
		}
		part motionSensors[*];
		part doorContactSensors[*];
		part windowSensors[*];
		part alarmSiren;
		part controlPanel;
	}
	
	part def EnergyManagementSystem {
		port monitorInterface : EnergyMonitorPort;
		attribute peakLoadLimit : EnergyRate;
		part smartMeter;
		part loadBalancer;
	}
	
	part def HomeAutomationController {
		port envInput : EnvironmentalSensorPort;
		port occInput : OccupancySensorPort;
		port climateCtrl : ClimateControlPort;
		port lightCtrl : LightingControlPort;
		port securityCtrl : SecurityControlPort;
		port energyMon : EnergyMonitorPort;
		
		attribute operatingMode : String;
		attribute userPreferences[*];
	}
	
	action def SenseEnvironment {
		in sensorData : EnvironmentalData;
		out processedData : EnvironmentalData;
	}
	
	action def DetermineOccupancy {
		in rawOccupancy : OccupancyState;
		in occupantCount : OccupancyLevel;
		out occupancyStatus : OccupancyState;
	}
	
	action def RegulateClimate {
		in currentEnv : EnvironmentalData;
		in desiredSetpoint : ClimateSetpoint;
		in occupancy : OccupancyState;
		out climateControl : ClimateSetpoint;
	}
	
	action def ManageLighting {
		in ambientLight : LightIntensity;
		in occupancy : OccupancyState;
		in timeOfDay : ISQ::TimeValue;
		out lightingControl : LightingCommand;
	}
	
	action def ControlSecurity {
		in occupancy : OccupancyState;
		in userCommand : SecurityCommand;
		in timeOfDay : ISQ::TimeValue;
		out securityControl : SecurityCommand;
	}
	
	action def OptimizeEnergy {
		in climatePower : EnergyRate;
		in lightingPower : EnergyRate;
		in occupancy : OccupancyState;
		in peakLimit : EnergyRate;
		out optimizationActions : String[*];
	}
	
	action def ProvideComfortableSecureLiving {
		doc /* 
			Primary function: Continuously monitor and adjust home systems to provide 
			a comfortable, secure, and energy-efficient living environment by coordinating 
			climate control, lighting, security, and energy management based on occupancy 
			and environmental conditions.
		*/
		
		first start;
		then merge continuousMonitoring;
		
		action senseEnvironment : SenseEnvironment {
			in sensorData;
			out processedData;
		}
		
		then action determineOccupancy : DetermineOccupancy {
			in rawOccupancy;
			in occupantCount;
			out occupancyStatus;
		}
		
		then fork parallelOperations;
		
		action regulateClimate : RegulateClimate {
			in currentEnv = senseEnvironment.processedData;
			in desiredSetpoint;
			in occupancy = determineOccupancy.occupancyStatus;
			out climateControl;
		}
		
		action manageLighting : ManageLighting {
			in ambientLight = senseEnvironment.processedData.lightLevel;
			in occupancy = determineOccupancy.occupancyStatus;
			in timeOfDay;
			out lightingControl;
		}
		
		action controlSecurity : ControlSecurity {
			in occupancy = determineOccupancy.occupancyStatus;
			in userCommand;
			in timeOfDay;
			out securityControl;
		}
		
		then join afterParallelOperations;
		
		then action optimizeEnergy : OptimizeEnergy {
			in climatePower;
			in lightingPower;
			in occupancy = determineOccupancy.occupancyStatus;
			in peakLimit;
			out optimizationActions;
		}
		
		then continuousMonitoring;
	}
	
	part def Home;
	
	part home : Home {
		doc /* 
			A comprehensive smart home system that integrates environmental monitoring, 
			climate control, lighting, security, and energy management to provide an 
			optimal living environment that adapts to occupant needs while maximizing 
			comfort, safety, and energy efficiency.
		*/
		
		attribute address : String;
		attribute totalArea : ISQ::AreaValue;
		attribute numberOfRooms : Integer;
		attribute constructionYear : Integer;
		
		perform action primaryFunction : ProvideComfortableSecureLiving;
		
		part envSensor : EnvironmentalSensor {
			perform primaryFunction.senseEnvironment;
			attribute :>> sampleRate = 0.1 [SI::Hz];
		}
		
		part occSensor : OccupancySensor {
			perform primaryFunction.determineOccupancy;
			attribute :>> detectionRange = 10.0 [SI::m];
		}
		
		part climate : ClimateControlSystem {
			perform primaryFunction.regulateClimate;
		}
		
		part lighting : LightingSystem {
			perform primaryFunction.manageLighting;
		}
		
		part security : SecuritySystem {
			perform primaryFunction.controlSecurity;
		}
		
		part energyMgmt : EnergyManagementSystem {
			perform primaryFunction.optimizeEnergy;
			attribute :>> peakLoadLimit = 15000.0 [SI::W];
		}
		
		part controller : HomeAutomationController;
		
		connect envSensor.output to controller.envInput;
		connect occSensor.output to controller.occInput;
		connect controller.climateCtrl to climate.controlInterface;
		connect controller.lightCtrl to lighting.controlInterface;
		connect controller.securityCtrl to security.controlInterface;
		connect controller.energyMon to energyMgmt.monitorInterface;
	}
	
	requirement def ComfortRequirement {
		doc /* The home system shall maintain indoor temperature within acceptable range. */
		subject home;
		require constraint temperatureRange {
			18.0 [SI::'°C'] <= home.climate.controlInterface.currentTemp.num <= 26.0 [SI::'°C']
		}
	}
	
	requirement def SecurityRequirement {
		doc /* The home system shall detect and respond to security breaches within 5 seconds. */
		subject home.security;
	}
	
	requirement def EnergyEfficiencyRequirement {
		doc /* The home system shall reduce energy consumption by at least 20% during unoccupied periods. */
		subject home.energyMgmt;
	}
	
	requirement def OccupancyResponsivenessRequirement {
		doc /* The home system shall adjust all subsystems within 30 seconds of occupancy state changes. */
		subject home.controller;
	}
	
	requirement def SystemIntegrationRequirement {
		doc /* All subsystems shall communicate through the central controller with 99.9% reliability. */
		subject home;
	}
	
	requirement homeSystemRequirements {
		doc /* 
			The Home system shall provide a safe, comfortable, and efficient living environment 
			through integrated automation and intelligent control of climate, lighting, security, 
			and energy systems.
		*/
		subject home;
		
		require comfortReq : ComfortRequirement;
		require securityReq : SecurityRequirement;
		require energyReq : EnergyEfficiencyRequirement;
		require responsivenessReq : OccupancyResponsivenessRequirement;
		require integrationReq : SystemIntegrationRequirement;
	}
}
