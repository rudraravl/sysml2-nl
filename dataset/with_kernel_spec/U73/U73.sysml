package 'Impella Cardiac Support System' {
	private import ScalarValues::*;
	
	package Definitions {
		item def Blood;
		item def PurgeFluid {
			attribute dextroseConcentration : Real;
			attribute heparinConcentration : Real;
		}
		
		attribute def Pressure { unit = 'mmHg'; }
		attribute def FlowRate { unit = 'L/min'; }
		attribute def MotorSpeed { unit = 'RPM'; }
		attribute def Temperature { unit = 'degC'; }
		attribute def Current { unit = 'A'; }
		
		port def BloodPort {
			out item blood : Blood;
		}
		port def PurgePort {
			out item purgeFluid : PurgeFluid;
		}
		port def PowerPort {
			out attribute power : Real;
		}
		port def ControlPort {
			in attribute speedCmd : MotorSpeed;
		}
		port def SignalPort {
			out attribute value : Real;
		}
		port def MotorStatusPort {
			out attribute speed : MotorSpeed;
			out attribute temperature : Temperature;
			out attribute current : Current;
		}
		port def AlarmPort {
			out attribute active : Boolean;
		}
		
		part def Sensor {
			port signalOut : SignalPort;
		}
		part def PressureSensor :> Sensor {
			attribute pressureValue : Pressure;
		}
		part def FlowSensor :> Sensor {
			attribute flowValue : FlowRate;
		}
		part def PositionSensor :> Sensor {
			attribute positionValid : Boolean;
		}
		part def MotorTempSensor :> Sensor {
			attribute tempValue : Temperature;
		}
		part def MotorCurrentSensor :> Sensor {
			attribute currentValue : Current;
		}
		
		part def Impeller {
			port bloodInlet : ~BloodPort;
			port bloodOutlet : BloodPort;
			port driveInput : ~SignalPort;
		}
		
		part def MicroaxialMotor {
			port powerIn : ~PowerPort;
			port controlIn : ControlPort;
			port purgeIn : ~PurgePort;
			port statusOut : MotorStatusPort;
			port driveOut : SignalPort;
			attribute speed : MotorSpeed;
			attribute temperature : Temperature;
			attribute current : Current;
		}
		
		part def MicroaxialPump {
			part impeller : Impeller;
			part motor : MicroaxialMotor;
			connect motor.driveOut to impeller.driveInput;
		}
		
		part def PurgeReservoir {
			item purgeFluid : PurgeFluid;
			port fluidOut : PurgePort;
		}
		
		part def PurgePump {
			port fluidIn : ~PurgePort;
			port fluidOut : PurgePort;
		}
		
		part def PurgeSystem {
			part reservoir : PurgeReservoir;
			part purgePump : PurgePump;
			port purgeOut : PurgePort;
			connect reservoir.fluidOut to purgePump.fluidIn;
			connect purgePump.fluidOut to purgeOut;
		}
		
		part def ImpellaCatheter {
			part pump : MicroaxialPump;
			part purgeSystem : PurgeSystem;
			part pressureSensor : PressureSensor;
			part flowSensor : FlowSensor;
			part positionSensor : PositionSensor;
			part motorTempSensor : MotorTempSensor;
			part motorCurrentSensor : MotorCurrentSensor;
			
			port ventriclePort : ~BloodPort;
			port aortaPort : BloodPort;
			
			connect ventriclePort to pump.impeller.bloodInlet;
			connect pump.impeller.bloodOutlet to aortaPort;
			connect purgeSystem.purgeOut to pump.motor.purgeIn;
		}
		
		part def UserInterface {
			attribute displayFlow : FlowRate;
			attribute displayPressure : Pressure;
			attribute displayMode : String;
		}
		
		action def AdjustMotorSpeed {
			in targetFlow : FlowRate;
			in currentFlow : FlowRate;
			out speedCmd : MotorSpeed;
		}
		
		action def EvaluateSensors {
			in pressure : Pressure;
			in flow : FlowRate;
			in positionValid : Boolean;
			in temp : Temperature;
			in current : Current;
			out faultDetected : Boolean;
		}
		
		part def ConsoleController {
			part ui : UserInterface;
			port powerOut : PowerPort;
			port controlOut : ~ControlPort;
			port pressureSensorIn : ~SignalPort;
			port flowSensorIn : ~SignalPort;
			port positionSensorIn : ~SignalPort;
			port motorTempSensorIn : ~SignalPort;
			port motorCurrentSensorIn : ~SignalPort;
			port motorStatusIn : ~MotorStatusPort;
			port alarmOut : AlarmPort;
			attribute targetFlow : FlowRate;
			attribute currentFlow : FlowRate;
			attribute aorticPressure : Pressure;
			attribute primed : Boolean;
			attribute targetReached : Boolean;
			attribute weanRequested : Boolean;
			attribute escalateRequested : Boolean;
			attribute weanComplete : Boolean;
			attribute faultDetected : Boolean;
			attribute alarmReset : Boolean;
		}
		
		state machine def OperationalStates {
			in controller : ConsoleController;
			state priming;
			state ramping;
			state fullSupport;
			state weaning;
			state standby;
			state fault;
			
			transition initial to priming;
			transition priming to ramping when controller.primed;
			transition ramping to fullSupport when controller.targetReached;
			transition fullSupport to weaning when controller.weanRequested;
			transition weaning to fullSupport when controller.escalateRequested;
			transition weaning to standby when controller.weanComplete;
			transition standby to ramping when controller.escalateRequested;
			transition priming to fault when controller.faultDetected;
			transition ramping to fault when controller.faultDetected;
			transition fullSupport to fault when controller.faultDetected;
			transition weaning to fault when controller.faultDetected;
			transition standby to fault when controller.faultDetected;
			transition fault to standby when controller.alarmReset;
		}
		
		part def HeartChamber {
			port bloodPort : BloodPort;
		}
		part def AortaSegment {
			port bloodPort : ~BloodPort;
		}
		
		part def Patient {
			part leftVentricle : HeartChamber;
			part ascendingAorta : AortaSegment;
		}
		
		part def OperatorDisplay {
			port alarmIn : ~AlarmPort;
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part impellaSystem {
			part patient : Patient;
			part catheter : ImpellaCatheter;
			part console : ConsoleController;
			part operatorDisplay : OperatorDisplay;
			
			connect console.powerOut to catheter.pump.motor.powerIn;
			connect console.controlOut to catheter.pump.motor.controlIn;
			
			connect catheter.pressureSensor.signalOut to console.pressureSensorIn;
			connect catheter.flowSensor.signalOut to console.flowSensorIn;
			connect catheter.positionSensor.signalOut to console.positionSensorIn;
			connect catheter.motorTempSensor.signalOut to console.motorTempSensorIn;
			connect catheter.motorCurrentSensor.signalOut to console.motorCurrentSensorIn;
			connect catheter.pump.motor.statusOut to console.motorStatusIn;
			
			connect console.alarmOut to operatorDisplay.alarmIn;
			
			flow of blood : Blood
				from patient.leftVentricle.bloodPort.blood to catheter.ventriclePort.blood;
			flow of blood : Blood
				from catheter.aortaPort.blood to patient.ascendingAorta.bloodPort.blood;
			flow of purgeFluid : PurgeFluid
				from catheter.purgeSystem.purgeOut.purgeFluid to catheter.pump.motor.purgeIn.purgeFluid;
			
			exhibit operationalStates : OperationalStates {
				in controller = console;
			}
		}
	}
	
	package Requirements {
		requirement def 'Maintain Hemodynamic Support' {
			doc = "The pump shall deliver continuous blood flow from left ventricle to ascending aorta.";
		}
		requirement def 'Prevent Motor Housing Thrombosis' {
			doc = "The purge system shall continuously deliver dextrose-heparin fluid through the catheter channel to the motor housing.";
		}
		requirement def 'Control Target Blood Flow' {
			doc = "The console controller shall adjust motor speed to achieve and maintain the target blood flow.";
		}
		requirement def 'Ensure Safe Catheter Positioning' {
			doc = "The system shall monitor catheter position and alarm if incorrect placement is detected.";
		}
		requirement def 'Alarm on Abnormal Conditions' {
			doc = "The system shall trigger alarms for flow obstruction, potential motor failure, and abnormal motor temperature or current.";
		}
	}
}
