package 'Nest Learning Thermostat System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> TemperatureValue;
	attribute def HumidityLevel :> Real;
	
	enum def HVACMode {
		off;
		heating;
		cooling;
		fan;
	}
	
	enum def OccupancyState {
		home;
		away;
		sleep;
	}
	
	item def HVACCommand {
		attribute mode : HVACMode;
		attribute targetTemp : TemperatureValue;
	}
	
	item def ScheduleEntry {
		attribute timeOfDay : TimeValue;
		attribute targetTemperature : TemperatureValue;
		attribute occupancyExpected : OccupancyState;
	}
	
	item def LearningData {
		attribute userAdjustments : TemperatureSetpoint[*] ordered;
		attribute occupancyPatterns : OccupancyState[*] ordered;
		attribute adjustmentTimes : TimeValue[*] ordered;
	}
	
	port def TemperatureSensorPort {
		out currentTemperature : TemperatureValue;
		out humidity : HumidityLevel;
	}
	
	port def OccupancySensorPort {
		out occupancyDetected : Boolean;
		out motionTimestamp : TimeValue;
	}
	
	port def HVACControlPort {
		out command : HVACCommand;
		in status : HVACMode;
	}
	
	port def UserInterfacePort {
		in userSetpoint : TemperatureSetpoint;
		in modeOverride : HVACMode;
		out displayTemp : TemperatureValue;
		out displayMode : HVACMode;
	}
	
	port def NetworkPort {
		in remoteSetpoint : TemperatureSetpoint;
		out telemetry : Real[*];
		in weatherData : TemperatureValue;
	}
	
	part def TemperatureSensor {
		port output : TemperatureSensorPort;
		attribute measuredTemp : TemperatureValue;
		attribute measuredHumidity : HumidityLevel;
	}
	
	part def OccupancySensor {
		port output : OccupancySensorPort;
		attribute motionDetected : Boolean;
		attribute lastMotionTime : TimeValue;
	}
	
	part def LearningEngine {
		attribute learningData : LearningData;
		attribute learnedSchedule : ScheduleEntry[*] ordered;
		
		in userBehavior : TemperatureSetpoint[*];
		in occupancyHistory : OccupancyState[*];
		out predictedSetpoint : TemperatureSetpoint;
		out optimizedSchedule : ScheduleEntry[*];
	}
	
	action def ManageThermostat {
		first start;
		then merge continuousControl;
		
		action sense : SenseEnvironment {
			out ambientTemp : TemperatureValue;
			out humidity : HumidityLevel;
			out occupancy : Boolean;
		}
		
		then action determineOccupancy : DetermineOccupancy {
			in motionDetected = sense.occupancy;
			in currentTime : TimeValue;
			in historicalPattern : LearningData;
			out occupancyState : OccupancyState;
		}
		
		then action learn : LearnPreferences {
			in userSetpoints : TemperatureSetpoint[*];
			in occupancyHistory : OccupancyState[*];
			in timeHistory : TimeValue[*];
			out updatedLearning : LearningData;
			out newSchedule : ScheduleEntry[*];
		}
		
		then action computeTarget : ComputeTargetTemperature {
			in currentOccupancy : OccupancyState = determineOccupancy.occupancyState;
			in schedule : ScheduleEntry[*] = learn.newSchedule;
			in currentTime : TimeValue;
			in userOverride : TemperatureSetpoint;
			out targetTemp : TemperatureSetpoint;
		}
		
		then action control : ControlHVAC {
			in currentTemp : TemperatureValue = sense.ambientTemp;
			in targetTemp : TemperatureSetpoint = computeTarget.targetTemp;
			in tolerance : TemperatureValue = 0.5;
			out hvacCommand : HVACCommand;
		}
		
		then continuousControl;
	}
	
	state def ThermostatStates {
		entry; then idle;
		
		state idle {
			entry assign activeMode = HVACMode::off;
		}
		
		state heating {
			entry assign activeMode = HVACMode::heating;
			do action heatAction {
				out heatingCmd : HVACCommand;
			}
		}
		
		state cooling {
			entry assign activeMode = HVACMode::cooling;
			do action coolAction {
				out coolingCmd : HVACCommand;
			}
		}
		
		state energySaving {
			entry assign activeMode = HVACMode::off;
			do action ecoMode {
				out ecoCmd : HVACCommand;
			}
		}
		
		transition idle_to_heating
			first idle
			then heating;
		
		transition heating_to_idle
			first heating
			then idle;
		
		transition idle_to_cooling
			first idle
			then cooling;
		
		transition cooling_to_idle
			first cooling
			then idle;
		
		transition any_to_away
			then energySaving;
		
		transition away_to_idle
			first energySaving
			then idle;
	}
	
	state def HVACOperationStates {
		entry; then off;
		
		state off;
		
		state heating {
			do action runHeater;
		}
		
		state cooling {
			do action runCooler;
		}
		
		transition off_to_heating
			first off
			then heating;
		
		transition heating_to_off
			first heating
			then off;
		
		transition off_to_cooling
			first off
			then cooling;
		
		transition cooling_to_off
			first cooling
			then off;
	}
	
	part def ThermostatController {
		attribute currentSetpoint : TemperatureSetpoint;
		attribute activeMode : HVACMode;
		attribute schedule : ScheduleEntry[*] ordered;
		attribute energySavingOffset : TemperatureValue;
		
		port tempSensor : ~TemperatureSensorPort;
		port occupancySensor : ~OccupancySensorPort;
		port hvacControl : HVACControlPort;
		port userIface : ~UserInterfacePort;
		port network : ~NetworkPort;
		
		part learningEngine : LearningEngine;
		
		perform action manageThermostat : ManageThermostat;
		exhibit state operatingStates : ThermostatStates;
	}
	
	part def HVACSystem {
		port control : ~HVACControlPort;
		
		attribute currentMode : HVACMode;
		attribute heatingCapacity : PowerValue;
		attribute coolingCapacity : PowerValue;
		
		exhibit state hvacStates : HVACOperationStates;
	}
	
	part def UserDisplay {
		port userPort : UserInterfacePort;
		attribute displayedTemperature : TemperatureValue;
		attribute displayedMode : HVACMode;
	}
	
	action def SenseEnvironment {
		out ambientTemp : TemperatureValue;
		out humidity : HumidityLevel;
		out occupancy : Boolean;
	}
	
	action def DetermineOccupancy {
		in motionDetected : Boolean;
		in currentTime : TimeValue;
		in historicalPattern : LearningData;
		out occupancyState : OccupancyState;
		
		first start;
		then decide;
			if motionDetected then assignHome;
			if not motionDetected then checkTime;
		action assignHome {
			then assign occupancyState = OccupancyState::home;
		}
		action checkTime {
			then decide;
				if currentTime >= 22.0 then assignSleep;
				if currentTime < 22.0 then assignAway;
		}
		action assignSleep {
			then assign occupancyState = OccupancyState::sleep;
		}
		action assignAway {
			then assign occupancyState = OccupancyState::away;
		}
		then done;
	}
	
	action def LearnPreferences {
		in userSetpoints : TemperatureSetpoint[*];
		in occupancyHistory : OccupancyState[*];
		in timeHistory : TimeValue[*];
		out updatedLearning : LearningData;
		out newSchedule : ScheduleEntry[*];
	}
	
	action def ComputeTargetTemperature {
		in currentOccupancy : OccupancyState;
		in schedule : ScheduleEntry[*];
		in currentTime : TimeValue;
		in userOverride : TemperatureSetpoint;
		out targetTemp : TemperatureSetpoint;
		
		first start;
		then decide;
			if currentOccupancy == OccupancyState::away then applyOffset;
			if currentOccupancy != OccupancyState::away then useScheduled;
		action applyOffset {
			then assign targetTemp = 18.0;
		}
		action useScheduled {
			then assign targetTemp = 21.0;
		}
		then done;
	}
	
	action def ControlHVAC {
		in currentTemp : TemperatureValue;
		in targetTemp : TemperatureSetpoint;
		in tolerance : TemperatureValue;
		out hvacCommand : HVACCommand;
		
		first start;
		then decide;
			if currentTemp < targetTemp - tolerance then heat;
			if currentTemp > targetTemp + tolerance then cool;
		action heat {
			then assign hvacCommand.mode = HVACMode::heating;
			then assign hvacCommand.targetTemp = targetTemp;
		}
		action cool {
			then assign hvacCommand.mode = HVACMode::cooling;
			then assign hvacCommand.targetTemp = targetTemp;
		}
		then done;
	}
	
	part nestSystem {
		part thermostat : ThermostatController {
			part tempSensor : TemperatureSensor;
			part occupancySensor : OccupancySensor;
			part display : UserDisplay;
			
			connect tempSensor.output to tempSensor;
			connect occupancySensor.output to occupancySensor;
			connect display.userPort to userIface;
		}
		
		part hvac : HVACSystem;
		
		connect thermostat.hvacControl to hvac.control;
	}
	
	requirement <'NEST-REQ-001'> primaryFunction {
		doc /* The Nest Learning Thermostat shall automatically regulate indoor climate 
		       by learning occupant preferences and schedules, optimizing comfort while 
		       minimizing energy consumption through intelligent HVAC control. */
		
		subject nestSystem;
		
		require learningCapability;
		require temperatureRegulation;
		require energyEfficiency;
	}
	
	requirement <'NEST-REQ-002'> learningCapability {
		doc /* The system shall learn user temperature preferences by observing manual 
		       adjustments and automatically generate a personalized schedule within 
		       one week of operation. */
		
		require constraint scheduleGeneration {
			learningPeriod : TimeValue;
			scheduleEntries : ScheduleEntry[*];
			learningPeriod <= 168.0 and scheduleEntries->size() >= 7
		}
	}
	
	requirement <'NEST-REQ-003'> temperatureRegulation {
		doc /* The system shall maintain indoor temperature within ±0.5°C of the target 
		       setpoint during occupied periods. */
		
		require constraint temperatureTolerance {
			currentTemp : TemperatureValue;
			targetTemp : TemperatureSetpoint;
			abs(currentTemp - targetTemp) <= 0.5
		}
	}
	
	requirement <'NEST-REQ-004'> energyEfficiency {
		doc /* The system shall reduce HVAC energy consumption by at least 20% compared 
		       to traditional programmable thermostats through occupancy-based control 
		       and predictive scheduling. */
		
		require constraint energyReduction {
			baselineEnergy : EnergyValue;
			actualEnergy : EnergyValue;
			savingsPercent : Real;
			savingsPercent = (baselineEnergy - actualEnergy) / baselineEnergy;
			savingsPercent >= 0.20
		}
	}
	
	requirement <'NEST-REQ-005'> occupancyDetection {
		doc /* The system shall detect occupancy changes and adjust to energy-saving mode 
		       within 30 minutes of the space becoming unoccupied. */
		
		require constraint occupancyResponse {
			responseTime : TimeValue;
			responseTime <= 30.0
		}
	}
}
