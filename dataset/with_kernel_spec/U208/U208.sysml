package 'Infusion Pump System' {
	private import ScalarValues::*;
	
	item def Medication;
	item def PumpCommand;
	
	attribute def 'Start Signal';
	attribute def 'Stop Signal';
	attribute def 'Dose Complete';
	attribute def 'Over Pressure';
	attribute def 'Reset';
	
	attribute def FlowRate :> Real;
	attribute def Pressure :> Real;
	attribute def Volume :> Real;
	attribute def Dose :> Volume;
	
	port def DrugOutPort {
		out item drugFlow : Medication;
	}
	
	port def DrugInPort {
		in item drugFlow : Medication;
	}
	
	port def FlowSensorPort {
		out measuredFlow : FlowRate;
	}
	
	port def PressureSensorPort {
		out measuredPressure : Pressure;
	}
	
	port def PumpControlPort {
		in pumpCommand : PumpCommand;
	}
	
	port def ControllerDataPort {
		in sensedFlow : FlowRate;
		in sensedPressure : Pressure;
	}
	
	part def Battery;
	
	part def DrugReservoir {
		port drugOutPort : DrugOutPort;
		attribute capacity : Volume;
		attribute currentVolume : Volume;
	}
	
	part def PumpMechanism {
		port drugInPort : DrugInPort;
		port drugOutPort : DrugOutPort;
		port controlPort : PumpControlPort;
		attribute speed : FlowRate;
	}
	
	part def FlowSensor {
		port drugInPort : DrugInPort;
		port drugOutPort : DrugOutPort;
		port sensorPort : FlowSensorPort;
	}
	
	part def PressureSensor {
		port drugInPort : DrugInPort;
		port drugOutPort : DrugOutPort;
		port sensorPort : PressureSensorPort;
	}
	
	part def ControlUnit {
		port dataPort : ControllerDataPort;
		port pumpControlPort : PumpControlPort;
		
		attribute targetRate : FlowRate;
		attribute targetDose : Dose;
		attribute deliveredDose : Dose;
		attribute maxSafePressure : Pressure;
		
		action def CalculatePumpSpeed {
			in sensedFlow : FlowRate;
			in targetFlow : FlowRate;
			out command : PumpCommand;
		}
		
		action def CheckPressure {
			in sensedPressure : Pressure;
			in maxPressure : Pressure;
			out stop : PumpCommand;
		}
		
		action def CheckDose {
			in delivered : Dose;
			in target : Dose;
			out stop : PumpCommand;
		}
		
		action calculatePumpSpeed : CalculatePumpSpeed;
		action checkPressure : CheckPressure;
		action checkDose : CheckDose;
		
		exhibit state 'Control States' {
			entry; then idle;
			state idle;
			accept 'Start Signal'
				then delivering;
			state delivering {
				do calculatePumpSpeed;
				do checkPressure;
				do checkDose;
			}
			accept 'Stop Signal'
				then idle;
			accept 'Dose Complete'
				then completed;
			accept 'Over Pressure'
				then error;
			state completed;
			accept 'Reset'
				then idle;
			state error;
			accept 'Reset'
				then idle;
		}
	}
	
	part def DeliveryCatheter {
		port drugInPort : DrugInPort;
		port drugOutPort : DrugOutPort;
	}
	
	part def Patient {
		port medicationPort : DrugInPort;
	}
	
	part def InfusionPump {
		part battery : Battery;
		part reservoir : DrugReservoir;
		part pump : PumpMechanism;
		part flowSensor : FlowSensor;
		part pressureSensor : PressureSensor;
		part controller : ControlUnit;
		part catheter : DeliveryCatheter;
		part patient : Patient;
		
		flow drugFlow1 of Medication from reservoir.drugOutPort.drugFlow to pump.drugInPort.drugFlow;
		flow drugFlow2 of Medication from pump.drugOutPort.drugFlow to flowSensor.drugInPort.drugFlow;
		flow drugFlow3 of Medication from flowSensor.drugOutPort.drugFlow to pressureSensor.drugInPort.drugFlow;
		flow drugFlow4 of Medication from pressureSensor.drugOutPort.drugFlow to catheter.drugInPort.drugFlow;
		flow drugFlow5 of Medication from catheter.drugOutPort.drugFlow to patient.medicationPort.drugFlow;
		
		flow flowFeedback of FlowRate from flowSensor.sensorPort.measuredFlow to controller.dataPort.sensedFlow;
		flow pressureFeedback of Pressure from pressureSensor.sensorPort.measuredPressure to controller.dataPort.sensedPressure;
		flow pumpControlFlow of PumpCommand from controller.pumpControlPort.pumpCommand to pump.controlPort.pumpCommand;
	}
	
	requirement def MedicationDeliveryRequirement {
		subject pump : InfusionPump;
		
		requirement deliverTargetDose {
			doc /* The pump shall deliver the prescribed total dose. */
			subject deliveredDose : Dose;
			constraint { deliveredDose == pump.controller.targetDose }
		}
		
		requirement maintainFlowRate {
			doc /* The pump shall maintain the flow rate within 5% of the target rate. */
			subject actualFlow : FlowRate;
			constraint { actualFlow <= pump.controller.targetRate * 1.05 and actualFlow >= pump.controller.targetRate * 0.95 }
		}
		
		requirement preventOverPressure {
			doc /* The pump shall halt if pressure exceeds the maximum safe limit. */
			subject linePressure : Pressure;
			constraint { linePressure <= pump.controller.maxSafePressure }
		}
	}
}
