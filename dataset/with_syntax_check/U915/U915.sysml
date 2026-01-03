package 'Throttle Position Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	attribute def AngleUnit :> SimpleUnit;
	
	attribute def AngleValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : AngleUnit;
	}
	
	attribute def VoltageUnit :> SimpleUnit;
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : VoltageUnit;
	}
	
	attribute def PercentageValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : ScalarMeasurementReference;
	}
	
	item def ThrottleShaft {
		attribute currentAngle : AngleValue;
		attribute minAngle : AngleValue;
		attribute maxAngle : AngleValue;
	}
	
	item def ThrottlePositionData {
		attribute angle : AngleValue;
		attribute percentage : PercentageValue;
		attribute voltage : VoltageValue;
	}
	
	port def MechanicalInputPort {
		in item shaft : ThrottleShaft;
	}
	
	port def ElectricalOutputPort {
		out item positionData : ThrottlePositionData;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : VoltageValue;
		in attribute groundVoltage : VoltageValue;
	}
	
	connection def MechanicalCoupling {
		end source : MechanicalInputPort;
		end sink : MechanicalInputPort;
	}
	
	connection def SignalWire {
		end source : ElectricalOutputPort;
		end sink : ~ElectricalOutputPort;
	}
	
	action def SenseAngle {
		in shaftAngle : AngleValue;
		out measuredAngle : AngleValue;
	}
	
	action def ConvertToVoltage {
		in angle : AngleValue;
		in minAngle : AngleValue;
		in maxAngle : AngleValue;
		in supplyVoltage : VoltageValue;
		out outputVoltage : VoltageValue;
	}
	
	action def CalculatePercentage {
		in angle : AngleValue;
		in minAngle : AngleValue;
		in maxAngle : AngleValue;
		out percentage : PercentageValue;
	}
	
	action def MeasureThrottlePosition {
		in item shaft : ThrottleShaft;
		in supplyVoltage : VoltageValue;
		out item positionData : ThrottlePositionData;
		
		action senseAngle : SenseAngle {
			in shaftAngle = shaft.currentAngle;
			out measuredAngle;
		}
		
		then fork;
		
		then action convertToVoltage : ConvertToVoltage {
			in angle = senseAngle.measuredAngle;
			in minAngle = shaft.minAngle;
			in maxAngle = shaft.maxAngle;
			in supplyVoltage;
			out outputVoltage;
		}
		
		then joinNode;
		
		then action calculatePercentage : CalculatePercentage {
			in angle = senseAngle.measuredAngle;
			in minAngle = shaft.minAngle;
			in maxAngle = shaft.maxAngle;
			out percentage;
		}
		
		then joinNode;
		
		join joinNode;
		
		then action assembleData {
			bind positionData.angle = senseAngle.measuredAngle;
			bind positionData.voltage = convertToVoltage.outputVoltage;
			bind positionData.percentage = calculatePercentage.percentage;
		}
	}
	
	state def SensorOperationalStates {
		entry; then powerOff;
		
		state powerOff;
		accept PowerApplied;
		then initialization;
		
		state initialization {
			entry action selfTest;
			do action calibrateSensor;
		}
		accept InitializationComplete;
		then ready;
		
		state ready;
		accept StartMeasurement;
		then measuring;
		
		state measuring {
			do action continuousSensing {
				action samplePosition;
				then action processSignal;
				then action transmitData;
			}
		}
		accept StopMeasurement;
		then ready;
		
		accept PowerRemoved;
		then powerOff;
		
		accept ErrorDetected;
		then fault;
		
		state fault {
			entry action logError;
			do action diagnostics;
		}
		accept ErrorCleared;
		then initialization;
	}
	
	part def ThrottlePositionSensor {
		attribute sensorId : String;
		attribute sensorType : String;
		attribute operatingVoltage : VoltageValue;
		attribute outputRange : VoltageValue[2];
		attribute measurementAccuracy : PercentageValue;
		
		port mechanicalInput : MechanicalInputPort;
		port electricalOutput : ElectricalOutputPort;
		port power : PowerPort;
		
		part sensingElement {
			attribute resistanceRange : Real;
			attribute wiperPosition : Real;
		}
		
		exhibit state operationalState : SensorOperationalStates;
		
		perform action measure : MeasureThrottlePosition;
	}
	
	part def SignalProcessor {
		attribute processorId : String;
		attribute filterCutoffFrequency : Real;
		attribute amplificationGain : Real;
		
		port dataInput : ~ElectricalOutputPort;
		port dataOutput : ElectricalOutputPort;
		
		action filterSignal {
			in rawData : ThrottlePositionData;
			out filteredData : ThrottlePositionData;
		}
		
		action amplifySignal {
			in inputData : ThrottlePositionData;
			out amplifiedData : ThrottlePositionData;
		}
		
		perform action processSignal {
			action filter : filterSignal;
			then action amplify : amplifySignal;
			flow from filter.filteredData to amplify.inputData;
		}
	}
	
	part def ControlModule {
		attribute moduleId : String;
		attribute throttlePositionReading : PercentageValue;
		attribute throttleAngleReading : AngleValue;
		
		port sensorDataInput : ~ElectricalOutputPort;
		
		action interpretThrottleData {
			in positionData : ThrottlePositionData;
			out throttleCommand : PercentageValue;
		}
		
		perform action processData : interpretThrottleData;
	}
	
	part throttlePositionSensingUnit {
		attribute unitSerialNumber : String;
		
		part throttleShaft : ThrottleShaft {
			attribute :>> currentAngle = 30.0[deg];
			attribute :>> minAngle = 0.0[deg];
			attribute :>> maxAngle = 90.0[deg];
		}
		
		part tpSensor : ThrottlePositionSensor {
			attribute :>> sensorId = "TPS-001";
			attribute :>> sensorType = "Potentiometric";
			attribute :>> operatingVoltage = 5.0[V];
			attribute :>> outputRange = (0.5[V], 4.5[V]);
			
			perform action :>> measure {
				in :>> shaft = throttleShaft;
				in :>> supplyVoltage = 5.0[V];
				out :>> positionData;
			}
		}
		
		part processor : SignalProcessor {
			attribute :>> processorId = "SP-001";
			attribute :>> filterCutoffFrequency = 100.0;
			attribute :>> amplificationGain = 1.0;
		}
		
		part controller : ControlModule {
			attribute :>> moduleId = "CM-001";
		}
		
		connection mechanicalLink : MechanicalCoupling
			connect source references tpSensor.mechanicalInput
			to sink references tpSensor.mechanicalInput;
		
		connection sensorToProcessor : SignalWire
			connect source references tpSensor.electricalOutput
			to sink references processor.dataInput;
		
		connection processorToController : SignalWire
			connect source references processor.dataOutput
			to sink references controller.sensorDataInput;
		
		flow from throttleShaft to tpSensor.mechanicalInput.shaft;
		flow from tpSensor.electricalOutput.positionData to processor.dataInput.positionData;
		flow from processor.dataOutput.positionData to controller.sensorDataInput.positionData;
	}
	
	requirement def AccuracyRequirement {
		doc /* The throttle position sensor shall measure throttle angle 
		       with an accuracy of +/- 0.5% over the full operating range. */
		
		subject sensor : ThrottlePositionSensor;
		
		require constraint {
			sensor.measurementAccuracy.num <= 0.5
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The throttle position sensor shall respond to throttle 
		       position changes within 10 milliseconds. */
		
		subject sensor : ThrottlePositionSensor;
		
		attribute maxResponseTime : Real = 10.0;
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The sensing unit shall measure throttle positions 
		       over a range of 0 to 90 degrees. */
		
		subject unit : throttlePositionSensingUnit;
		
		require constraint {
			unit.throttleShaft.minAngle.num == 0.0 and
			unit.throttleShaft.maxAngle.num == 90.0
		}
	}
	
	requirement def VoltageOutputRequirement {
		doc /* The sensor shall provide an output voltage between 
		       0.5V and 4.5V corresponding to the throttle range. */
		
		subject sensor : ThrottlePositionSensor;
		
		require constraint {
			sensor.outputRange[1].num == 0.5 and
			sensor.outputRange[2].num == 4.5
		}
	}
	
	requirement sensingUnitRequirements {
		subject unit : throttlePositionSensingUnit;
		
		require accuracy : AccuracyRequirement {
			subject sensor = unit.tpSensor;
		}
		
		require responseTime : ResponseTimeRequirement {
			subject sensor = unit.tpSensor;
		}
		
		require operatingRange : OperatingRangeRequirement {
			subject :>> unit;
		}
		
		require voltageOutput : VoltageOutputRequirement {
			subject sensor = unit.tpSensor;
		}
	}
	
	verification def VerifyThrottlePositionAccuracy {
		subject testSensor : ThrottlePositionSensor;
		
		objective verifyAccuracy {
			doc /* Verify that the sensor measures throttle position 
			       within specified accuracy limits across the full range. */
		}
		
		return verdict : Boolean;
	}
	
	part testSetup {
		part calibratedShaft : ThrottleShaft {
			attribute :>> currentAngle = 45.0[deg];
			attribute :>> minAngle = 0.0[deg];
			attribute :>> maxAngle = 90.0[deg];
		}
		
		part testSensor : ThrottlePositionSensor :> throttlePositionSensingUnit.tpSensor;
		
		verification verifyAccuracy : VerifyThrottlePositionAccuracy {
			subject :>> testSensor;
		}
		
		perform verifyAccuracy {
			in :>> testSensor;
			out :>> verdict;
		}
	}
}
