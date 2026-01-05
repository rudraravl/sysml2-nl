package IntelligentHomeControlSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureValue :> Real;
	
	attribute def LightIntensityValue :> Real;
	
	attribute def HumidityValue :> Real;
	
	attribute def PowerValue :> Real;
	
	item def TemperatureReading {
		attribute value : TemperatureValue;
		attribute timestamp : Real;
	}
	
	item def LightReading {
		attribute intensity : LightIntensityValue;
		attribute timestamp : Real;
	}
	
	item def OccupancyReading {
		attribute isOccupied : Boolean;
		attribute timestamp : Real;
	}
	
	item def HumidityReading {
		attribute value : HumidityValue;
		attribute timestamp : Real;
	}
	
	item def ClimateCommand {
		attribute targetTemperature : TemperatureValue;
		attribute mode : ClimateMode;
	}
	
	item def LightingCommand {
		attribute targetIntensity : LightIntensityValue;
		attribute zone : Integer;
		attribute enabled : Boolean;
	}
	
	item def SecurityCommand {
		attribute armed : Boolean;
		attribute zone : Integer;
	}
	
	item def UserPreferences {
		attribute preferredTemperature : TemperatureValue;
		attribute preferredLightLevel : LightIntensityValue;
		attribute awayModeEnabled : Boolean;
		attribute scheduleActive : Boolean;
	}
	
	item def SystemStatus {
		attribute currentTemperature : TemperatureValue;
		attribute currentLightLevel : LightIntensityValue;
		attribute currentHumidity : HumidityValue;
		attribute energyConsumption : PowerValue;
		attribute securityArmed : Boolean;
		attribute operationalMode : String;
	}
	
	enum def ClimateMode {
		heating;
		cooling;
		ventilation;
		off;
	}
	
	port def SensorDataPort {
		out item temperatureData : TemperatureReading;
		out item lightData : LightReading;
		out item occupancyData : OccupancyReading;
		out item humidityData : HumidityReading;
	}
	
	port def ActuatorCommandPort {
		in item climateCmd : ClimateCommand;
		in item lightCmd : LightingCommand;
		in item securityCmd : SecurityCommand;
	}
	
	port def UserInterfacePort {
		in item preferences : UserPreferences;
		out item status : SystemStatus;
	}
	
	part def TemperatureSensor {
		port dataOut : SensorDataPort;
		
		action sense : MeasureTemperature {
			out reading : TemperatureReading;
		}
	}
	
	part def LightSensor {
		port dataOut : SensorDataPort;
		
		action sense : MeasureLightIntensity {
			out reading : LightReading;
		}
	}
	
	part def OccupancySensor {
		port dataOut : SensorDataPort;
		
		action sense : DetectOccupancy {
			out reading : OccupancyReading;
		}
	}
	
	part def HumiditySensor {
		port dataOut : SensorDataPort;
		
		action sense : MeasureHumidity {
			out reading : HumidityReading;
		}
	}
	
	part def ClimateActuator {
		port cmdIn : ActuatorCommandPort;
		
		action execute : ExecuteClimateControl {
			in command : ClimateCommand;
		}
	}
	
	part def LightingActuator {
		port cmdIn : ActuatorCommandPort;
		
		action execute : ExecuteLightingControl {
			in command : LightingCommand;
		}
	}
	
	part def SecurityActuator {
		port cmdIn : ActuatorCommandPort;
		
		action execute : ExecuteSecurityControl {
			in command : SecurityCommand;
		}
	}
	
	part def CentralController {
		port userInterface : UserInterfacePort;
		
		attribute currentTemp : TemperatureValue;
		attribute currentLight : LightIntensityValue;
		attribute currentHumidity : HumidityValue;
		attribute isOccupied : Boolean;
		attribute targetTemp : TemperatureValue;
		attribute targetLight : LightIntensityValue;
		attribute awayMode : Boolean;
		
		perform action manageHome : ManageHomeEnvironment;
	}
	
	action def MeasureTemperature {
		out reading : TemperatureReading;
	}
	
	action def MeasureLightIntensity {
		out reading : LightReading;
	}
	
	action def DetectOccupancy {
		out reading : OccupancyReading;
	}
	
	action def MeasureHumidity {
		out reading : HumidityReading;
	}
	
	action def ExecuteClimateControl {
		in command : ClimateCommand;
	}
	
	action def ExecuteLightingControl {
		in command : LightingCommand;
	}
	
	action def ExecuteSecurityControl {
		in command : SecurityCommand;
	}
	
	action def ProcessUserPreferences {
		in preferences : UserPreferences;
		out targetTemperature : TemperatureValue;
		out targetLightLevel : LightIntensityValue;
		out awayModeActive : Boolean;
	}
	
	action def AnalyzeSensorData {
		in tempReading : TemperatureReading;
		in lightReading : LightReading;
		in occupancyReading : OccupancyReading;
		in humidityReading : HumidityReading;
		out currentTemp : TemperatureValue;
		out currentLight : LightIntensityValue;
		out currentHumidity : HumidityValue;
		out occupied : Boolean;
	}
	
	action def DetermineClimateAction {
		in currentTemp : TemperatureValue;
		in targetTemp : TemperatureValue;
		in occupied : Boolean;
		in awayMode : Boolean;
		out command : ClimateCommand;
	}
	
	action def DetermineLightingAction {
		in currentLight : LightIntensityValue;
		in targetLight : LightIntensityValue;
		in occupied : Boolean;
		in awayMode : Boolean;
		out command : LightingCommand;
	}
	
	action def DetermineSecurityAction {
		in occupied : Boolean;
		in awayMode : Boolean;
		out command : SecurityCommand;
	}
	
	action def ManageHomeEnvironment {
		first start;
		then merge controlLoop;
		
		action collectSensorData : AnalyzeSensorData {
			in tempReading;
			in lightReading;
			in occupancyReading;
			in humidityReading;
			out currentTemp;
			out currentLight;
			out currentHumidity;
			out occupied;
		}
		
		then action processPreferences : ProcessUserPreferences {
			in preferences;
			out targetTemperature;
			out targetLightLevel;
			out awayModeActive;
		}
		
		then action decideClimate : DetermineClimateAction {
			in currentTemp = collectSensorData.currentTemp;
			in targetTemp = processPreferences.targetTemperature;
			in occupied = collectSensorData.occupied;
			in awayMode = processPreferences.awayModeActive;
			out command;
		}
		
		then action decideLighting : DetermineLightingAction {
			in currentLight = collectSensorData.currentLight;
			in targetLight = processPreferences.targetLightLevel;
			in occupied = collectSensorData.occupied;
			in awayMode = processPreferences.awayModeActive;
			out command;
		}
		
		then action decideSecurity : DetermineSecurityAction {
			in occupied = collectSensorData.occupied;
			in awayMode = processPreferences.awayModeActive;
			out command;
		}
		
		then action applyClimate : ExecuteClimateControl {
			in command = decideClimate.command;
		}
		
		then action applyLighting : ExecuteLightingControl {
			in command = decideLighting.command;
		}
		
		then action applySecurity : ExecuteSecurityControl {
			in command = decideSecurity.command;
		}
		
		then controlLoop;
	}
	
	part def IntelligentHomeSystem {
		part tempSensor : TemperatureSensor;
		part lightSensor : LightSensor;
		part occupancySensor : OccupancySensor;
		part humiditySensor : HumiditySensor;
		part controller : CentralController;
		part climateActuator : ClimateActuator;
		part lightingActuator : LightingActuator;
		part securityActuator : SecurityActuator;
		
		connection tempSensorConnection connect tempSensor.dataOut to controller;
		connection lightSensorConnection connect lightSensor.dataOut to controller;
		connection occupancySensorConnection connect occupancySensor.dataOut to controller;
		connection humiditySensorConnection connect humiditySensor.dataOut to controller;
		connection climateConnection connect controller to climateActuator.cmdIn;
		connection lightingConnection connect controller to lightingActuator.cmdIn;
		connection securityConnection connect controller to securityActuator.cmdIn;
	}
	
	part intelligentHome : IntelligentHomeSystem {
		perform action optimizeEnvironment : ManageHomeEnvironment;
	}
	
	state def HomeOperationalStates {
		entry;
		then idle;
		
		state idle;
		
		transition idleToMonitoring
			first idle
			accept OccupancyDetected
			then monitoring;
		
		state monitoring {
			state parallel monitoringActivities {
				state climateControl {
					entry;
					then checkingClimate;
					
					state checkingClimate;
					
					transition checkingToAdjusting
						first checkingClimate
						if temperatureDeviation
						then adjustingClimate;
					
					state adjustingClimate;
					
					transition adjustingToChecking
						first adjustingClimate
						then checkingClimate;
				}
				
				state lightingControl {
					entry;
					then checkingLighting;
					
					state checkingLighting;
					
					transition checkingToAdjusting
						first checkingLighting
						if lightLevelDeviation
						then adjustingLighting;
					
					state adjustingLighting;
					
					transition adjustingToChecking
						first adjustingLighting
						then checkingLighting;
				}
				
				state securityControl {
					entry;
					then disarmed;
					
					state disarmed;
					
					transition disarmToArm
						first disarmed
						accept AwayModeActivated
						then armed;
					
					state armed;
					
					transition armToDisarm
						first armed
						accept AwayModeDeactivated
						then disarmed;
				}
			}
		}
		
		transition monitoringToIdle
			first monitoring
			accept NoOccupancyDetected
			then idle;
		
		attribute temperatureDeviation : Boolean;
		attribute lightLevelDeviation : Boolean;
	}
	
	event OccupancyDetected;
	event NoOccupancyDetected;
	event AwayModeActivated;
	event AwayModeDeactivated;
	
	requirement def PrimaryFunctionRequirement {
		doc /* The Intelligent Home Control System shall automatically monitor environmental conditions 
		       and control climate, lighting, and security subsystems to maintain comfort, safety, and 
		       energy efficiency without manual intervention. */
	}
	
	requirement def ComfortRequirement {
		doc /* The system shall maintain indoor temperature and lighting levels within user-specified 
		       comfort ranges when the home is occupied. */
		
		require constraint temperatureComfort {
			attribute actualTemp : TemperatureValue;
			attribute targetTemp : TemperatureValue;
			attribute tolerance : Real;
			
			actualTemp >= targetTemp - tolerance and actualTemp <= targetTemp + tolerance
		}
		
		require constraint lightingComfort {
			attribute actualLight : LightIntensityValue;
			attribute targetLight : LightIntensityValue;
			attribute tolerance : Real;
			
			actualLight >= targetLight - tolerance
		}
	}
	
	requirement def EnergyEfficiencyRequirement {
		doc /* The system shall minimize energy consumption by adjusting climate and lighting based on 
		       occupancy status and user preferences. */
		
		require constraint occupancyBasedControl {
			attribute isOccupied : Boolean;
			attribute climateActive : Boolean;
			attribute lightingActive : Boolean;
			
			not isOccupied implies (not climateActive or not lightingActive)
		}
	}
	
	requirement def SecurityRequirement {
		doc /* The system shall automatically arm security subsystems when away mode is activated and 
		       no occupancy is detected. */
		
		require constraint awayModeArming {
			attribute awayMode : Boolean;
			attribute isOccupied : Boolean;
			attribute securityArmed : Boolean;
			
			(awayMode and not isOccupied) implies securityArmed
		}
	}
	
	requirement def ResponsivenessRequirement {
		doc /* The system shall respond to environmental changes and user commands within specified 
		       time limits to ensure timely comfort adjustments. */
		
		require constraint responseTime {
			attribute detectionTime : Real;
			attribute actionTime : Real;
			attribute maxResponseTime : Real;
			
			actionTime - detectionTime <= maxResponseTime
		}
	}
	
	requirement intelligentHomeSystemRequirements {
		doc /* Top-level requirements for the Intelligent Home Control System. */
		
		require primaryFunction : PrimaryFunctionRequirement;
		require comfort : ComfortRequirement;
		require efficiency : EnergyEfficiencyRequirement;
		require security : SecurityRequirement;
		require responsiveness : ResponsivenessRequirement;
	}
	
	satisfy requirement intelligentHomeSystemRequirements by intelligentHome;
}
