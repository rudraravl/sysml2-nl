package 'Incubator System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Percentage :> Real;
	
	item def ControlSignal {
		attribute enabled : Boolean;
		attribute level : Percentage;
	}
	
	item def AlarmSignal {
		attribute active : Boolean;
		attribute code : String;
	}
	
	port def TemperatureSensorPort {
		out temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def HumiditySensorPort {
		out humidity : Percentage;
	}
	
	port def CO2SensorPort {
		out co2Level : Percentage;
	}
	
	port def DoorSensorPort {
		out doorOpen : Boolean;
	}
	
	port def HeaterControlPort {
		in heaterSignal : ControlSignal;
	}
	
	port def HumidifierControlPort {
		in humidifierSignal : ControlSignal;
	}
	
	port def CO2ControlPort {
		in co2Signal : ControlSignal;
	}
	
	port def AlarmPort {
		out alarm : AlarmSignal;
	}
	
	port def UserInterfacePort {
		in targetTemperature : ISQ::ThermodynamicTemperatureValue;
		in targetHumidity : Percentage;
		in targetCO2 : Percentage;
		in powerOn : Boolean;
		out currentTemperature : ISQ::ThermodynamicTemperatureValue;
		out currentHumidity : Percentage;
		out currentCO2 : Percentage;
		out systemStatus : String;
	}
	
	part def TemperatureSensor {
		port reading : TemperatureSensorPort;
	}
	
	part def HumiditySensor {
		port reading : HumiditySensorPort;
	}
	
	part def CO2Sensor {
		port reading : CO2SensorPort;
	}
	
	part def DoorSensor {
		port reading : DoorSensorPort;
	}
	
	part def HeatingElement {
		port control : HeaterControlPort;
		attribute powerRating : ISQ::PowerValue;
	}
	
	part def HumidificationSystem {
		port control : HumidifierControlPort;
		attribute capacity : Real;
	}
	
	part def CO2InjectionSystem {
		port control : CO2ControlPort;
		attribute flowRate : Real;
	}
	
	part def Chamber {
		attribute volume : ISQ::VolumeValue;
		attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute currentHumidity : Percentage;
		attribute currentCO2 : Percentage;
		
		part tempSensor : TemperatureSensor;
		part humiditySensor : HumiditySensor;
		part co2Sensor : CO2Sensor;
		part doorSensor : DoorSensor;
	}
	
	part def AlarmSystem {
		port alarmOut : AlarmPort;
	}
	
	part def UserInterface {
		port ui : UserInterfacePort;
	}
	
	action def ReadSensors {
		in tempReading : ISQ::ThermodynamicTemperatureValue;
		in humidityReading : Percentage;
		in co2Reading : Percentage;
		in doorStatus : Boolean;
		out measuredTemp : ISQ::ThermodynamicTemperatureValue;
		out measuredHumidity : Percentage;
		out measuredCO2 : Percentage;
		out doorOpen : Boolean;
	}
	
	action def ComputeControl {
		in targetTemp : ISQ::ThermodynamicTemperatureValue;
		in targetHumidity : Percentage;
		in targetCO2 : Percentage;
		in measuredTemp : ISQ::ThermodynamicTemperatureValue;
		in measuredHumidity : Percentage;
		in measuredCO2 : Percentage;
		in doorOpen : Boolean;
		out heaterCmd : ControlSignal;
		out humidifierCmd : ControlSignal;
		out co2Cmd : ControlSignal;
		out alarmCmd : AlarmSignal;
	}
	
	action def RegulateEnvironment {
		in targetTemp : ISQ::ThermodynamicTemperatureValue;
		in targetHumidity : Percentage;
		in targetCO2 : Percentage;
		in tempReading : ISQ::ThermodynamicTemperatureValue;
		in humidityReading : Percentage;
		in co2Reading : Percentage;
		in doorStatus : Boolean;
		out heaterControl : ControlSignal;
		out humidifierControl : ControlSignal;
		out co2Control : ControlSignal;
		out alarm : AlarmSignal;
		
		action readSensors : ReadSensors {
			in tempReading = RegulateEnvironment::tempReading;
			in humidityReading = RegulateEnvironment::humidityReading;
			in co2Reading = RegulateEnvironment::co2Reading;
			in doorStatus = RegulateEnvironment::doorStatus;
			out measuredTemp;
			out measuredHumidity;
			out measuredCO2;
			out doorOpen;
		}
		
		flow readSensors.measuredTemp to computeControl.measuredTemp;
		flow readSensors.measuredHumidity to computeControl.measuredHumidity;
		flow readSensors.measuredCO2 to computeControl.measuredCO2;
		flow readSensors.doorOpen to computeControl.doorOpen;
		
		action computeControl : ComputeControl {
			in targetTemp = RegulateEnvironment::targetTemp;
			in targetHumidity = RegulateEnvironment::targetHumidity;
			in targetCO2 = RegulateEnvironment::targetCO2;
			in measuredTemp;
			in measuredHumidity;
			in measuredCO2;
			in doorOpen;
			out heaterCmd;
			out humidifierCmd;
			out co2Cmd;
			out alarmCmd;
		}
		
		flow computeControl.heaterCmd to RegulateEnvironment::heaterControl;
		flow computeControl.humidifierCmd to RegulateEnvironment::humidifierControl;
		flow computeControl.co2Cmd to RegulateEnvironment::co2Control;
		flow computeControl.alarmCmd to RegulateEnvironment::alarm;
	}
	
	state def IncubatorStateMachine {
		in powerOn : Boolean;
		in doorOpen : Boolean;
		in tempInRange : Boolean;
		in humidityInRange : Boolean;
		in co2InRange : Boolean;
		
		attribute systemState : String;
		
		entry; then idle;
		
		state idle {
			entry assign systemState = "Idle";
		}
		
		transition idle_to_startup
			first idle
			accept at powerOn
			then startup;
		
		state startup {
			entry assign systemState = "Starting Up";
		}
		
		transition startup_to_monitoring
			first startup
			accept when tempInRange and not doorOpen
			then monitoring;
			
		transition startup_to_doorOpen
			first startup
			accept when doorOpen
			then doorOpenState;
		
		state monitoring {
			entry assign systemState = "Monitoring";
		}
		
		transition monitoring_to_maintaining
			first monitoring
			accept when tempInRange and humidityInRange and co2InRange
			then maintaining;
			
		transition monitoring_to_doorOpen
			first monitoring
			accept when doorOpen
			then doorOpenState;
			
		transition monitoring_to_alarm
			first monitoring
			accept when not tempInRange or not humidityInRange or not co2InRange
			then alarm;
			
		transition monitoring_to_idle
			first monitoring
			accept when not powerOn
			then idle;
		
		state maintaining {
			entry assign systemState = "Maintaining";
		}
		
		transition maintaining_to_monitoring
			first maintaining
			accept when not tempInRange or not humidityInRange or not co2InRange
			then monitoring;
			
		transition maintaining_to_doorOpen
			first maintaining
			accept when doorOpen
			then doorOpenState;
			
		transition maintaining_to_idle
			first maintaining
			accept when not powerOn
			then idle;
		
		state doorOpenState {
			entry assign systemState = "Door Open - Systems Disabled";
		}
		
		transition doorOpen_to_startup
			first doorOpenState
			accept when not doorOpen and powerOn
			then startup;
			
		transition doorOpen_to_idle
			first doorOpenState
			accept when not powerOn
			then idle;
		
		state alarm {
			entry assign systemState = "Alarm - Out of Range";
		}
		
		transition alarm_to_monitoring
			first alarm
			accept when tempInRange and humidityInRange and co2InRange
			then monitoring;
			
		transition alarm_to_idle
			first alarm
			accept when not powerOn
			then idle;
	}
	
	part def ControlUnit {
		attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute targetHumidity : Percentage;
		attribute targetCO2 : Percentage;
		attribute temperatureTolerance : ISQ::ThermodynamicTemperatureValue;
		attribute humidityTolerance : Percentage;
		attribute co2Tolerance : Percentage;
		
		port tempSensorIn : TemperatureSensorPort;
		port humiditySensorIn : HumiditySensorPort;
		port co2SensorIn : CO2SensorPort;
		port doorSensorIn : DoorSensorPort;
		port heaterOut : HeaterControlPort;
		port humidifierOut : HumidifierControlPort;
		port co2Out : CO2ControlPort;
		port alarmOut : AlarmPort;
		port userInterface : UserInterfacePort;
		
		perform action controlLoop : RegulateEnvironment {
			in targetTemp = targetTemperature;
			in targetHumidity = targetHumidity;
			in targetCO2 = targetCO2;
			in tempReading = tempSensorIn.temperature;
			in humidityReading = humiditySensorIn.humidity;
			in co2Reading = co2SensorIn.co2Level;
			in doorStatus = doorSensorIn.doorOpen;
			out heaterControl;
			out humidifierControl;
			out co2Control;
			out alarm;
		}
	}
	
	part def Incubator {
		doc /* 
		An incubator system provides a precisely controlled environment for biological 
		specimens, cell cultures, or neonatal care. Its primary function is to maintain 
		stable temperature, humidity, and CO2 levels within a sealed chamber by continuously 
		monitoring environmental conditions and activating heating, humidification, and gas 
		injection systems as needed. The system ensures optimal growth conditions through 
		automated feedback control while providing safety interlocks and alarms for out-of-range 
		conditions or door access events.
		*/
		
		part chamber : Chamber {
			attribute volume = 50.0[L];
			attribute currentTemperature = 25.0[degC];
			attribute currentHumidity = 40.0;
			attribute currentCO2 = 0.04;
		}
		
		part heater : HeatingElement {
			attribute powerRating = 500.0[W];
		}
		
		part humidifier : HumidificationSystem {
			attribute capacity = 2.0;
		}
		
		part co2Injector : CO2InjectionSystem {
			attribute flowRate = 0.5;
		}
		
		part controller : ControlUnit {
			attribute targetTemperature = 37.0[degC];
			attribute targetHumidity = 95.0;
			attribute targetCO2 = 5.0;
			attribute temperatureTolerance = 0.5[K];
			attribute humidityTolerance = 2.0;
			attribute co2Tolerance = 0.5;
		}
		
		part alarmSystem : AlarmSystem;
		part userInterface : UserInterface;
		
		connect chamber.tempSensor.reading to controller.tempSensorIn;
		connect chamber.humiditySensor.reading to controller.humiditySensorIn;
		connect chamber.co2Sensor.reading to controller.co2SensorIn;
		connect chamber.doorSensor.reading to controller.doorSensorIn;
		connect controller.heaterOut to heater.control;
		connect controller.humidifierOut to humidifier.control;
		connect controller.co2Out to co2Injector.control;
		connect controller.alarmOut to alarmSystem.alarmOut;
		connect controller.userInterface to userInterface.ui;
	}
	
	requirement def EnvironmentalStabilityRequirement {
		doc /* The incubator shall maintain environmental parameters within specified tolerances. */
		subject incubator : Incubator;
		require constraint {
			incubator.chamber.currentTemperature >= incubator.controller.targetTemperature - incubator.controller.temperatureTolerance and
			incubator.chamber.currentTemperature <= incubator.controller.targetTemperature + incubator.controller.temperatureTolerance
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The incubator shall disable all actuators when the door is open. */
		subject incubator : Incubator;
		require constraint {
			incubator.chamber.doorSensor.reading.doorOpen implies 
			(not incubator.heater.control.heaterSignal.enabled and 
			 not incubator.humidifier.control.humidifierSignal.enabled and 
			 not incubator.co2Injector.control.co2Signal.enabled)
		}
	}
	
	requirement def AlarmRequirement {
		doc /* The incubator shall activate an alarm when environmental parameters exceed safe limits. */
		subject incubator : Incubator;
		require constraint {
			(incubator.chamber.currentTemperature > incubator.controller.targetTemperature + 2.0[K] or
			 incubator.chamber.currentTemperature < incubator.controller.targetTemperature - 2.0[K]) implies
			incubator.alarmSystem.alarmOut.alarm.active
		}
	}
	
	part incubatorSystem : Incubator;
	
	requirement tempStability : EnvironmentalStabilityRequirement {
		subject incubator = incubatorSystem;
	}
	
	requirement doorSafety : SafetyRequirement {
		subject incubator = incubatorSystem;
	}
	
	requirement alarmActivation : AlarmRequirement {
		subject incubator = incubatorSystem;
	}
}
