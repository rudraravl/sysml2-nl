package PlanarHallSensingUnitModel {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		item def ElectricalPower;
		item def AnalogSignal {
			attribute voltage : ElectricPotential;
		}
		item def DigitalValue {
			attribute reading : Real;
		}
		item def MeasurementResult {
			attribute fluxDensity : MagneticFluxDensity;
		}
		
		attribute def CalibrationCoeffs {
			attribute offset : Real;
			attribute gain : Real;
		}
		
		attribute def 'Init Complete';
		attribute def 'Start Measuring';
		attribute def 'Stop Measuring';
		attribute def 'Enter Calibration';
		attribute def 'Calibration Done';
		attribute def 'Fault Detected';
		attribute def 'Reset';
		
		port def ExtPowerPort {
			in item power : ElectricalPower;
		}
		port def RegPowerPort {
			out item power : ElectricalPower;
		}
		port def BiasPort {
			out item current : ElectricCurrent;
		}
		port def AnalogOutPort {
			out item signal : AnalogSignal;
		}
		port def DigitalOutPort {
			out item data : DigitalValue;
		}
		port def TempOutPort {
			out item temp : ThermodynamicTemperature;
		}
		port def MeasurementOutPort {
			out item result : MeasurementResult;
		}
		
		part def PlanarHallElement {
			doc /* Core sensor composed of thin ferromagnetic and conductive layers. */
			port biasIn : ~BiasPort;
			port voltageOut : AnalogOutPort;
			perform action senseField : SenseField;
		}
		part def BiasCircuit {
			port powerIn : ~RegPowerPort;
			port biasOut : BiasPort;
			perform action generateBias : GenerateBias;
		}
		part def SignalConditioner {
			doc /* Uses a differential amplifier and low-pass filter. */
			port powerIn : ~RegPowerPort;
			port analogIn : ~AnalogOutPort;
			port analogOut : AnalogOutPort;
			perform action conditionSignal : ConditionSignal;
		}
		part def ADC {
			port powerIn : ~RegPowerPort;
			port analogIn : ~AnalogOutPort;
			port digitalOut : DigitalOutPort;
			perform action convert : ConvertToDigital;
		}
		part def TemperatureSensor {
			port powerIn : ~RegPowerPort;
			port tempOut : TempOutPort;
			perform action senseTemp : SenseTemp;
		}
		part def SignalProcessor {
			port powerIn : ~RegPowerPort;
			port digitalIn : ~DigitalOutPort;
			port tempIn : ~TempOutPort;
			port measurementOut : MeasurementOutPort;
			attribute coeffs : CalibrationCoeffs;
			perform action processMeasurement : ProcessMeasurement;
		}
		part def PowerSupply {
			port extPowerIn : ExtPowerPort;
			port regPowerOut : RegPowerPort;
			perform action regulatePower : RegulatePower;
		}
		
		part def PlanarHallSensingUnit {
			port extPower : ExtPowerPort;
			port dataOut : MeasurementOutPort;
			exhibit state 'operational states' : OperationalStates;
		}
		
		state def OperationalStates;
		
		action def RegulatePower {
			in extPower : ElectricalPower;
			out regPower : ElectricalPower;
		}
		action def GenerateBias {
			in power : ElectricalPower;
			out current : ElectricCurrent;
		}
		action def SenseField {
			in current : ElectricCurrent;
			out voltage : AnalogSignal;
		}
		action def ConditionSignal {
			in rawSignal : AnalogSignal;
			out conditionedSignal : AnalogSignal;
		}
		action def ConvertToDigital {
			in analog : AnalogSignal;
			out digital : DigitalValue;
		}
		action def SenseTemp {
			out temp : ThermodynamicTemperature;
		}
		action def ProcessMeasurement {
			in digital : DigitalValue;
			in temp : ThermodynamicTemperature;
			in coeffs : CalibrationCoeffs;
			out result : MeasurementResult;
		}
		action def Initialize;
		action def Measure;
		action def Calibrate;
		action def HandleFault;
		
		requirement def MeasurementAccuracy {
			doc /* The Planar Hall Sensing Unit shall measure magnetic flux density with high precision. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part sensingUnit : PlanarHallSensingUnit {
			action initialize : Initialize;
			action measure : Measure;
			action calibrate : Calibrate;
			action handleFault : HandleFault;
			
			part powerSupply : PowerSupply;
			part biasCircuit : BiasCircuit;
			part planarHallElement : PlanarHallElement;
			part signalConditioner : SignalConditioner;
			part adc : ADC;
			part tempSensor : TemperatureSensor;
			part signalProcessor : SignalProcessor;
			
			flow of power : ElectricalPower
				from extPower.power to powerSupply.extPowerIn.power;
			flow of power : ElectricalPower
				from powerSupply.regPowerOut.power to biasCircuit.powerIn.power;
			flow of power : ElectricalPower
				from powerSupply.regPowerOut.power to signalConditioner.powerIn.power;
			flow of power : ElectricalPower
				from powerSupply.regPowerOut.power to adc.powerIn.power;
			flow of power : ElectricalPower
				from powerSupply.regPowerOut.power to tempSensor.powerIn.power;
			flow of power : ElectricalPower
				from powerSupply.regPowerOut.power to signalProcessor.powerIn.power;
				
			flow of current : ElectricCurrent
				from biasCircuit.biasOut.current to planarHallElement.biasIn.current;
				
			flow of signal : AnalogSignal
				from planarHallElement.voltageOut.signal to signalConditioner.analogIn.signal;
			flow of signal : AnalogSignal
				from signalConditioner.analogOut.signal to adc.analogIn.signal;
				
			flow of data : DigitalValue
				from adc.digitalOut.data to signalProcessor.digitalIn.data;
				
			flow of temp : ThermodynamicTemperature
				from tempSensor.tempOut.temp to signalProcessor.tempIn.temp;
				
			flow of result : MeasurementResult
				from signalProcessor.measurementOut.result to dataOut.result;
			
			state 'operational states' : OperationalStates parallel {
				state 'lifecycle' {
					entry; then initialization;
					state initialization {
						do initialize;
					}
					accept 'Init Complete' then idle;
					state idle;
					accept 'Start Measuring' then active;
					state active {
						do measure;
					}
					accept 'Stop Measuring' then idle;
					accept 'Enter Calibration' then calibration;
					state calibration {
						do calibrate;
					}
					accept 'Calibration Done' then idle;
					accept 'Fault Detected' then fault;
					state fault {
						do handleFault;
					}
					accept 'Reset' then initialization;
				}
			}
		}
		
		satisfy MeasurementAccuracy by sensingUnit;
	}
}
