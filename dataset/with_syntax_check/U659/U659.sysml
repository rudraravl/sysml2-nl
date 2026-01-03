package 'Electrochemical Gas Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Measurement::*;

	attribute def ConcentrationUnit :> MeasurementUnit;
	attribute ppm : ConcentrationUnit;
	
	attribute def GasConcentrationValue :> QuantityValue {
		attribute num : Real;
		attribute mRef : ConcentrationUnit;
	}
	
	attribute def VoltageValue :> ElectricPotentialDifferenceValue;
	attribute def CurrentValue :> ElectricCurrentValue;
	attribute def TemperatureValue :> ThermodynamicTemperatureValue;
	attribute def PressureValue :> ISQ::PressureValue;
	
	enum def GasType {
		carbonMonoxide;
		ozone;
		nitrogenDioxide;
		sulfurDioxide;
		oxygen;
		hydrogenSulfide;
	}
	
	enum def SensorStatus {
		off;
		warmingUp;
		ready;
		measuring;
		calibrating;
		fault;
	}
	
	item def GasSample {
		attribute targetGas : GasType;
		attribute concentration : GasConcentrationValue;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	item def MeasurementReading {
		attribute gasType : GasType;
		attribute concentration : GasConcentrationValue;
		attribute timestamp : Real;
		attribute temperature : TemperatureValue;
		attribute isValid : Boolean;
	}
	
	port def GasInputPort {
		in item sample : GasSample;
	}
	
	port def SignalOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def DataOutputPort {
		out item reading : MeasurementReading;
	}
	
	port def PowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : CurrentValue;
	}
	
	part def WorkingElectrode {
		attribute material : String;
		attribute surfaceArea : Real;
		attribute catalystType : String;
	}
	
	part def CounterElectrode {
		attribute material : String;
		attribute surfaceArea : Real;
	}
	
	part def ReferenceElectrode {
		attribute material : String;
		attribute referencePotential : VoltageValue;
	}
	
	part def Electrolyte {
		attribute composition : String;
		attribute ionicConductivity : Real;
	}
	
	part def GasPermeableMembrane {
		attribute material : String;
		attribute thickness : Real;
		attribute permeability : Real;
	}
	
	part def SensingCell {
		part workingElectrode : WorkingElectrode[1];
		part counterElectrode : CounterElectrode[1];
		part referenceElectrode : ReferenceElectrode[1];
		part electrolyte : Electrolyte[1];
		part membrane : GasPermeableMembrane[1];
		
		port gasInput : GasInputPort;
		port signalOutput : SignalOutputPort;
	}
	
	part def Potentiostat {
		attribute biasVoltage : VoltageValue;
		attribute amplificationGain : Real;
		
		port signalInput : SignalOutputPort;
		port amplifiedOutput : SignalOutputPort;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		
		port analogInput : SignalOutputPort;
		port digitalOutput : DataOutputPort;
	}
	
	part def TemperatureSensor {
		attribute accuracy : TemperatureValue;
		port tempOutput : DataOutputPort;
	}
	
	part def SignalProcessor {
		attribute calibrationCoefficients : Real[3];
		
		port rawDataInput : DataOutputPort;
		port processedDataOutput : DataOutputPort;
	}
	
	action def WarmUpSensor {
		in power : VoltageValue;
		out ready : Boolean;
	}
	
	action def DetectGas {
		in sample : GasSample;
		out signal : ElectricalSignal;
	}
	
	action def AmplifySignal {
		in rawSignal : ElectricalSignal;
		in gain : Real;
		out amplifiedSignal : ElectricalSignal;
	}
	
	action def DigitizeSignal {
		in analogSignal : ElectricalSignal;
		out digitalReading : MeasurementReading;
	}
	
	action def CompensateTemperature {
		in rawReading : MeasurementReading;
		in temperature : TemperatureValue;
		in coefficients : Real[3];
		out compensatedReading : MeasurementReading;
	}
	
	action def PerformCalibration {
		in referenceGas : GasSample;
		out calibrationCoefficients : Real[3];
	}
	
	part def ElectrochemicalGasSensor {
		attribute targetGas : GasType;
		attribute measurementRange : GasConcentrationValue[2];
		attribute responseTime : Real;
		attribute status : SensorStatus;
		
		port gasInput : GasInputPort;
		port dataOutput : DataOutputPort;
		port power : PowerPort;
		
		part sensingCell : SensingCell[1];
		part potentiostat : Potentiostat[1];
		part adc : AnalogToDigitalConverter[1];
		part tempSensor : TemperatureSensor[1];
		part processor : SignalProcessor[1];
		
		connect sensingCell.gasInput to gasInput;
		connect sensingCell.signalOutput to potentiostat.signalInput;
		connect potentiostat.amplifiedOutput to adc.analogInput;
		connect adc.digitalOutput to processor.rawDataInput;
		connect tempSensor.tempOutput to processor.rawDataInput;
		connect processor.processedDataOutput to dataOutput;
		
		state sensorBehavior {
			entry; then off;
			
			state off;
			
			transition off_to_warmingUp
				first off
				accept powerApplied
				then warmingUp;
			
			state warmingUp {
				do action warmUp : WarmUpSensor;
			}
			
			transition warmingUp_to_ready
				first warmingUp
				if warmUp.ready
				then ready;
			
			state ready;
			
			transition ready_to_measuring
				first ready
				accept sampleDetected
				then measuring;
			
			transition ready_to_calibrating
				first ready
				accept calibrationRequested
				then calibrating;
			
			state measuring {
				do action measure : DetectGas;
			}
			
			transition measuring_to_ready
				first measuring
				then ready;
			
			transition measuring_to_fault
				first measuring
				accept errorDetected
				then fault;
			
			state calibrating {
				do action calibrate : PerformCalibration;
			}
			
			transition calibrating_to_ready
				first calibrating
				then ready;
			
			state fault;
			
			transition fault_to_off
				first fault
				accept reset
				then off;
		}
	}
	
	action def MeasureGasConcentration {
		in item gasSample : GasSample;
		out item measurement : MeasurementReading;
		
		bind detect.sample = gasSample;
		
		action detect : DetectGas {
			in sample;
			out signal;
		}
		then action amplify : AmplifySignal {
			in rawSignal = detect.signal;
			in gain = 100.0;
			out amplifiedSignal;
		}
		then action digitize : DigitizeSignal {
			in analogSignal = amplify.amplifiedSignal;
			out digitalReading;
		}
		then action compensate : CompensateTemperature {
			in rawReading = digitize.digitalReading;
			in temperature;
			in coefficients;
			out compensatedReading;
		}
		
		bind compensate.compensatedReading = measurement;
	}
	
	part def SensingUnit {
		attribute operatingTemperatureRange : TemperatureValue[2];
		attribute powerConsumption : Real;
		
		part sensor : ElectrochemicalGasSensor[1];
		
		port gasInput : GasInputPort;
		port dataOutput : DataOutputPort;
		port power : PowerPort;
		
		connect sensor.gasInput to gasInput;
		connect sensor.dataOutput to dataOutput;
		connect sensor.power to power;
		
		perform action sensing : MeasureGasConcentration;
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensor shall measure gas concentration within specified accuracy */
		subject sensor : ElectrochemicalGasSensor;
		require constraint {
			sensor.measurementRange[1].num >= 0.0 and
			sensor.measurementRange[2].num > sensor.measurementRange[1].num
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensor shall respond within specified time */
		subject sensor : ElectrochemicalGasSensor;
		require constraint {
			sensor.responseTime <= 60.0
		}
	}
	
	requirement def OperatingConditionsRequirement {
		doc /* The sensing unit shall operate within environmental limits */
		subject unit : SensingUnit;
		require constraint {
			unit.operatingTemperatureRange[1].num >= -20.0 and
			unit.operatingTemperatureRange[2].num <= 50.0
		}
	}
	
	part coSensingUnit : SensingUnit {
		part redefines sensor : ElectrochemicalGasSensor {
			attribute redefines targetGas = GasType::carbonMonoxide;
			
			part redefines sensingCell {
				part redefines workingElectrode {
					attribute redefines material = "Platinum";
					attribute redefines surfaceArea = 0.5;
					attribute redefines catalystType = "Pt-black";
				}
				part redefines counterElectrode {
					attribute redefines material = "Platinum";
					attribute redefines surfaceArea = 1.0;
				}
				part redefines referenceElectrode {
					attribute redefines material = "Ag/AgCl";
				}
				part redefines electrolyte {
					attribute redefines composition = "H2SO4";
					attribute redefines ionicConductivity = 0.8;
				}
				part redefines membrane {
					attribute redefines material = "PTFE";
					attribute redefines thickness = 0.025;
					attribute redefines permeability = 0.95;
				}
			}
			
			part redefines potentiostat {
				attribute redefines amplificationGain = 100.0;
			}
			
			part redefines adc {
				attribute redefines resolution = 16;
				attribute redefines samplingRate = 10.0;
			}
			
			part redefines processor {
				attribute redefines calibrationCoefficients = (1.0, 0.0, 0.0);
			}
		}
		
		attribute redefines powerConsumption = 0.05;
		
		satisfy accuracyReq : AccuracyRequirement {
			subject sensorUnderTest = sensor;
		}
		
		satisfy responseReq : ResponseTimeRequirement {
			subject sensorUnderTest = sensor;
		}
		
		satisfy operatingReq : OperatingConditionsRequirement {
			subject unitUnderTest = coSensingUnit;
		}
	}
}
