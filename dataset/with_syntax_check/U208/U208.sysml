package 'Drug Delivery System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	alias Volume for ISQ::VolumeValue;
	alias Pressure for ISQ::PressureValue;
	alias Time for ISQ::TimeValue;
	
	attribute def FlowRate {
		attribute value : Real;
		attribute unit : String = "mL/hr";
	}
	
	attribute def Concentration {
		attribute value : Real;
		attribute unit : String = "mg/mL";
	}
	
	attribute def DoseAmount {
		attribute value : Real;
		attribute unit : String = "mg";
	}
	
	item def Drug {
		attribute concentration : Concentration;
		attribute volume : Volume;
	}
	
	item def ElectricalPower;
	
	port def DrugOutPort {
		out item drugFlow : Drug;
		attribute flowRate : FlowRate;
		attribute pressure : Pressure;
	}
	
	port def DrugInPort {
		in item drugFlow : Drug;
		attribute flowRate : FlowRate;
		attribute pressure : Pressure;
	}
	
	port def SensorPort {
		out attribute measuredPressure : Pressure;
		out attribute measuredFlow : FlowRate;
	}
	
	port def ControlPort {
		in attribute commandedRate : FlowRate;
		in attribute commandedDose : DoseAmount;
		out attribute status : String;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	part def Reservoir {
		attribute capacity : Volume;
		attribute currentLevel : Volume;
		port outlet : DrugOutPort;
	}
	
	part def PumpMechanism {
		attribute maxFlowRate : FlowRate;
		attribute currentRate : FlowRate;
		port inlet : DrugInPort;
		port outlet : DrugOutPort;
		port control : ControlPort;
		port powerIn : PowerPort;
	}
	
	part def FlowSensor {
		port inlet : DrugInPort;
		port outlet : DrugOutPort;
		port sensorData : SensorPort;
		port powerIn : PowerPort;
	}
	
	part def PressureSensor {
		port monitorPoint : DrugInPort;
		port sensorData : SensorPort;
		port powerIn : PowerPort;
	}
	
	part def ControlUnit {
		attribute targetDose : DoseAmount;
		attribute targetRate : FlowRate;
		attribute maxPressureLimit : Pressure;
		port pumpControl : ControlPort;
		port flowSensorInput : SensorPort;
		port pressureSensorInput : SensorPort;
		port powerIn : PowerPort;
		perform action controlDelivery[*] ordered references controlDrugDelivery;
	}
	
	part def DeliveryCatheter {
		port inlet : DrugInPort;
		attribute insertionDepth : Real;
	}
	
	part def PowerSupply {
		attribute batteryCapacity : Real;
		port powerOut : PowerPort;
	}
	
	part def DrugDeliverySystem {
		part reservoir : Reservoir {
			capacity = 500.0;
		}
		part pump : PumpMechanism {
			maxFlowRate = 100.0;
		}
		part flowSensor : FlowSensor;
		part pressureSensor : PressureSensor;
		part controller : ControlUnit {
			targetDose = 50.0;
			targetRate = 10.0;
			maxPressureLimit = 300000.0;
		}
		part catheter : DeliveryCatheter;
		part battery : PowerSupply {
			batteryCapacity = 5000.0;
		}
		
		connect reservoir.outlet to pump.inlet;
		connect pump.outlet to flowSensor.inlet;
		connect flowSensor.outlet to pressureSensor.monitorPoint;
		connect pressureSensor.monitorPoint to catheter.inlet;
		
		connect flowSensor.sensorData to controller.flowSensorInput;
		connect pressureSensor.sensorData to controller.pressureSensorInput;
		connect controller.pumpControl to pump.control;
		
		connect battery.powerOut to controller.powerIn;
		connect battery.powerOut to pump.powerIn;
		connect battery.powerOut to flowSensor.powerIn;
		connect battery.powerOut to pressureSensor.powerIn;
	}
	
	action def MonitorSensors {
		out currentFlow : FlowRate;
		out currentPressure : Pressure;
	}
	
	action def CalculatePumpRate {
		in targetDose : DoseAmount;
		in targetRate : FlowRate;
		in currentFlow : FlowRate;
		in deliveredAmount : DoseAmount;
		out commandRate : FlowRate;
	}
	
	action def CheckSafety {
		in currentPressure : Pressure;
		in maxPressure : Pressure;
		out safetyStatus : Boolean;
	}
	
	action def ActivatePump {
		in pumpRate : FlowRate;
	}
	
	action def HaltPump;
	
	action def ControlDrugDelivery {
		in targetDose : DoseAmount;
		in targetRate : FlowRate;
		in maxPressure : Pressure;
		attribute deliveredDose : DoseAmount = 0.0;
		
		first start;
		then merge continueDelivery;
		
		then action monitor : MonitorSensors {
			out currentFlow : FlowRate;
			out currentPressure : Pressure;
		}
		
		then action safetyCheck : CheckSafety {
			in currentPressure = monitor.currentPressure;
			in maxPressure = maxPressure;
			out safetyStatus : Boolean;
		}
		
		then decide;
			if not safetyCheck.safetyStatus then haltDelivery;
			if deliveredDose >= targetDose then haltDelivery;
			if safetyCheck.safetyStatus and deliveredDose < targetDose then calculateAndDeliver;
		
		action calculateAndDeliver {
			action calculate : CalculatePumpRate {
				in targetDose = targetDose;
				in targetRate = targetRate;
				in currentFlow = monitor.currentFlow;
				in deliveredAmount = deliveredDose;
				out commandRate : FlowRate;
			}
			flow calculate.commandRate to activate.pumpRate;
			action activate : ActivatePump {
				in pumpRate : FlowRate;
			}
		}
		then continueDelivery;
		
		action haltDelivery : HaltPump;
		then done;
	}
	
	action controlDrugDelivery : ControlDrugDelivery {
		in targetDose : DoseAmount;
		in targetRate : FlowRate;
		in maxPressure : Pressure;
	}
	
	requirement def TherapeuticDelivery;
	requirement def SafetyCompliance;
	requirement def DoseAccuracy;
	
	requirement <'REQ-001'> primaryFunction : TherapeuticDelivery {
		doc /* The Drug Delivery System shall automatically administer a prescribed 
		       dose of medication to a patient at a controlled rate, maintaining 
		       therapeutic levels while ensuring patient safety. */
		require doseDeliveryRequirement;
		require safetyMonitoring;
	}
	
	requirement <'REQ-002'> doseDeliveryRequirement : DoseAccuracy {
		doc /* The system shall deliver the prescribed drug dose with an accuracy 
		       of ±3% of the target dose amount. */
	}
	
	requirement <'REQ-003'> safetyMonitoring : SafetyCompliance {
		doc /* The system shall continuously monitor delivery pressure and 
		       immediately halt delivery if pressure exceeds the maximum safe 
		       threshold for more than 0.5 seconds. */
	}
	
	requirement <'REQ-004'> flowRateControl {
		doc /* The system shall maintain the commanded flow rate within ±5% 
		       of the target rate during active delivery. */
	}
	
	requirement systemMission {
		assume constraint validDoseRange {
			doc /* The prescribed dose shall be within the therapeutic range 
			       for the specific medication being delivered. */
		}
		require primaryFunction;
		require flowRateControl;
	}
}
