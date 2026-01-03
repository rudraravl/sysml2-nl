package 'Industrial Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def VolumeFlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def LengthValue :> ISQ::LengthValue;
	
	item def ProcessCommand {
		attribute commandType : String;
		attribute targetValue : Real;
		attribute timestamp : Real;
	}
	
	item def SensorReading {
		attribute sensorID : String;
		attribute value : Real;
		attribute unit : String;
		attribute timestamp : Real;
	}
	
	item def AlarmSignal {
		attribute alarmID : String;
		attribute severity : Integer;
		attribute message : String;
	}
	
	item def ProductBatch {
		attribute batchID : String;
		attribute quantity : Integer;
		attribute qualityStatus : String;
	}
	
	port def ControlPort {
		in attribute setpoint : Real;
		out attribute feedback : Real;
		out attribute status : String;
	}
	
	port def SensorPort {
		out attribute reading : SensorReading;
	}
	
	port def ActuatorPort {
		in attribute command : ProcessCommand;
		out attribute position : LengthValue;
	}
	
	port def SupervisoryPort {
		in attribute processCommand : ProcessCommand;
		out attribute processStatus : String;
		out attribute alarmNotification : AlarmSignal;
	}
	
	part def ProgrammableLogicController {
		port supervisoryInterface : SupervisoryPort;
		port sensorInput1 : SensorPort;
		port sensorInput2 : SensorPort;
		port actuatorOutput1 : ActuatorPort;
		port actuatorOutput2 : ActuatorPort;
		
		attribute scanCycleTime : TimeValue;
		attribute programMemory : Integer;
		
		perform action executeControlLogic;
	}
	
	part def PressureSensor {
		port output : SensorPort;
		
		attribute range : PressureValue;
		attribute accuracy : Real;
		attribute currentReading : PressureValue;
		
		perform action measurePressure;
	}
	
	part def TemperatureSensor {
		port output : SensorPort;
		
		attribute range : TemperatureValue;
		attribute accuracy : Real;
		attribute currentReading : TemperatureValue;
		
		perform action measureTemperature;
	}
	
	part def ControlValve {
		port input : ActuatorPort;
		
		attribute valvePosition : LengthValue;
		attribute maxFlow : VolumeFlowRateValue;
		attribute responseTime : TimeValue;
		
		perform action adjustPosition;
	}
	
	part def ConveyorMotor {
		port input : ActuatorPort;
		
		attribute speed : SpeedValue;
		attribute power : PowerValue;
		attribute currentPosition : LengthValue;
		
		perform action controlSpeed;
	}
	
	part def HumanMachineInterface {
		port supervisoryControl : SupervisoryPort;
		
		attribute displayResolution : String;
		attribute touchEnabled : Boolean;
		
		perform action displayProcessData;
		perform action acceptOperatorInput;
	}
	
	part def ProcessReactor {
		attribute volume : VolumeValue;
		attribute maxPressure : PressureValue;
		attribute maxTemperature : TemperatureValue;
		attribute currentPressure : PressureValue;
		attribute currentTemperature : TemperatureValue;
		
		perform action executeReaction;
	}
	
	action def MonitorProcess {
		in pressureReading : SensorReading;
		in temperatureReading : SensorReading;
		out processNormal : Boolean;
		out alarmRequired : Boolean;
	}
	
	action def CalculateControlAction {
		in setpoint : Real;
		in processVariable : Real;
		in proportionalGain : Real;
		in integralGain : Real;
		out controlOutput : Real;
	}
	
	action def AdjustValve {
		in targetPosition : LengthValue;
		in currentPosition : LengthValue;
		out newPosition : LengthValue;
	}
	
	action def UpdateConveyor {
		in targetSpeed : SpeedValue;
		in currentSpeed : SpeedValue;
		out newSpeed : SpeedValue;
	}
	
	action def GenerateAlarm {
		in condition : Boolean;
		in severity : Integer;
		out alarm : AlarmSignal;
	}
	
	state def PLCOperatingState {
		entry action initializePLC;
		do action scanInputs;
		exit action shutdownPLC;
		
		state startup;
		state running;
		state fault;
		state maintenance;
		
		transition startup_to_running
			first startup
			then running;
		
		transition running_to_fault
			first running
			then fault;
		
		transition fault_to_maintenance
			first fault
			then maintenance;
		
		transition maintenance_to_startup
			first maintenance
			then startup;
		
		transition running_to_maintenance
			first running
			then maintenance;
	}
	
	state def ReactorState {
		entry action prepareReactor;
		do action monitorReaction;
		exit action cleanReactor;
		
		state idle;
		state filling;
		state heating;
		state reacting;
		state cooling;
		state draining;
		state emergency;
		
		transition idle_to_filling
			first idle
			then filling;
		
		transition filling_to_heating
			first filling
			then heating;
		
		transition heating_to_reacting
			first heating
			then reacting;
		
		transition reacting_to_cooling
			first reacting
			then cooling;
		
		transition cooling_to_draining
			first cooling
			then draining;
		
		transition draining_to_idle
			first draining
			then idle;
		
		transition any_to_emergency
			first idle
			then emergency;
	}
	
	action def AutomatedProcessControl {
		first start;
		then merge monitorLoop;
		
		then action monitor : MonitorProcess {
			in pressureReading;
			in temperatureReading;
			out processNormal;
			out alarmRequired;
		}
		
		then decide;
			if monitor.processNormal then calculateControl;
			if monitor.alarmRequired then generateAlarmAction;
		
		action calculateControl : CalculateControlAction {
			in setpoint;
			in processVariable = monitor.pressureReading.value;
			in proportionalGain = 1.5;
			in integralGain = 0.8;
			out controlOutput;
		}
		then action adjustValveAction : AdjustValve {
			in targetPosition;
			in currentPosition;
			out newPosition;
		}
		then action updateConveyorAction : UpdateConveyor {
			in targetSpeed;
			in currentSpeed;
			out newSpeed;
		}
		then monitorLoop;
		
		action generateAlarmAction : GenerateAlarm {
			in condition = monitor.alarmRequired;
			in severity = 2;
			out alarm;
		}
		then monitorLoop;
		
		merge monitorLoop;
		then done;
	}
	
	part automationSystem : ProgrammableLogicController {
		perform action processControl[*] ordered references AutomatedProcessControl;
		
		port operatorInterface : SupervisoryPort;
		
		part plc : ProgrammableLogicController {
			perform processControl.monitor;
			perform processControl.calculateControl;
			
			port hmiConnection : SupervisoryPort;
			port pressureSensorPort : SensorPort;
			port temperatureSensorPort : SensorPort;
			port valveControlPort : ActuatorPort;
			port conveyorControlPort : ActuatorPort;
			
			attribute scanCycleTime = 10.0;
			attribute programMemory = 65536;
			
			exhibit state plcState : PLCOperatingState;
		}
		
		part hmi : HumanMachineInterface {
			perform processControl.generateAlarmAction;
			
			port controlInterface : SupervisoryPort;
			
			attribute displayResolution = "1920x1080";
			attribute touchEnabled = true;
		}
		
		part pressureSensor : PressureSensor {
			port sensorOutput : SensorPort;
			
			attribute range : PressureValue = 1000000.0;
			attribute accuracy = 0.5;
		}
		
		part temperatureSensor : TemperatureSensor {
			port sensorOutput : SensorPort;
			
			attribute range : TemperatureValue = 500.0;
			attribute accuracy = 1.0;
		}
		
		part controlValve : ControlValve {
			port actuatorInput : ActuatorPort;
			perform processControl.adjustValveAction;
			
			attribute maxFlow : VolumeFlowRateValue = 0.01;
			attribute responseTime = 2.0;
		}
		
		part conveyorMotor : ConveyorMotor {
			port actuatorInput : ActuatorPort;
			perform processControl.updateConveyorAction;
			
			attribute power : PowerValue = 5000.0;
		}
		
		part reactor : ProcessReactor {
			attribute volume : VolumeValue = 5.0;
			attribute maxPressure : PressureValue = 2000000.0;
			attribute maxTemperature : TemperatureValue = 473.15;
			
			exhibit state reactorState : ReactorState;
		}
		
		connection hmiToPLC connect hmi.controlInterface to plc.hmiConnection;
		connection pressureSensorToPLC connect pressureSensor.sensorOutput to plc.pressureSensorPort;
		connection temperatureSensorToPLC connect temperatureSensor.sensorOutput to plc.temperatureSensorPort;
		connection plcToValve connect plc.valveControlPort to controlValve.actuatorInput;
		connection plcToConveyor connect plc.conveyorControlPort to conveyorMotor.actuatorInput;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'REQ-F-001'> processAutomation : FunctionalRequirement {
		doc /* The automation system shall continuously monitor process variables and automatically 
		       adjust control outputs to maintain setpoints within specified tolerances. */
	}
	
	requirement <'REQ-F-002'> alarmManagement : FunctionalRequirement {
		doc /* The system shall generate and display alarms when process variables exceed 
		       safe operating limits. */
	}
	
	requirement <'REQ-P-001'> scanCyclePerformance : PerformanceRequirement {
		doc /* The PLC shall complete one full scan cycle in less than 50 milliseconds. */
	}
	
	requirement <'REQ-P-002'> sensorAccuracy : PerformanceRequirement {
		doc /* Pressure and temperature sensors shall maintain accuracy within 1 percent 
		       of full scale. */
	}
	
	requirement <'REQ-S-001'> emergencyShutdown : SafetyRequirement {
		doc /* The system shall initiate emergency shutdown within 500 milliseconds 
		       when critical safety limits are exceeded. */
	}
	
	requirement <'REQ-S-002'> pressureProtection : SafetyRequirement {
		doc /* The reactor pressure shall never exceed the maximum rated pressure. */
	}
	
	requirement <'REQ-R-001'> systemAvailability : ReliabilityRequirement {
		doc /* The automation system shall maintain 99.5 percent uptime during 
		       scheduled production periods. */
	}
	
	requirement primaryAutomationMission {
		doc /* The industrial automation system shall autonomously control a chemical 
		       process reactor by continuously monitoring pressure and temperature, 
		       calculating optimal control actions, and adjusting valves and conveyors 
		       to maintain safe and efficient production while providing real-time 
		       operator visibility and alarm management. */
		
		assume constraint processInputsAvailable {
			doc /* Raw materials and utilities are available at required specifications. */
		}
		
		assume constraint powerSupplyReliable {
			doc /* Electrical power supply is stable and within voltage specifications. */
		}
		
		require processAutomation;
		require alarmManagement;
		require scanCyclePerformance;
		require sensorAccuracy;
		require emergencyShutdown;
		require pressureProtection;
		require systemAvailability;
	}
}
