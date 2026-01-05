package 'Piezoelectric Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def VoltageValue :> ISQ::VoltageValue;
	attribute def ChargeValue :> ISQ::ElectricChargeValue;
	attribute def SensitivityCoefficient :> Real;
	
	item def MechanicalStimulus {
		attribute appliedPressure: PressureValue;
		attribute appliedForce: ISQ::ForceValue;
	}
	
	item def ElectricalSignal {
		attribute voltage: VoltageValue;
		attribute charge: ChargeValue;
	}
	
	item def DigitalReading {
		attribute pressureReading: PressureValue;
		attribute timestamp: Real;
	}
	
	port def MechanicalInputPort {
		in item stimulus: MechanicalStimulus;
	}
	
	port def ElectricalOutputPort {
		out item signal: ElectricalSignal;
	}
	
	port def DigitalOutputPort {
		out item reading: DigitalReading;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage: VoltageValue;
	}
	
	part def PiezoelectricCrystal {
		attribute materialType: String;
		attribute sensitivity: SensitivityCoefficient;
		attribute capacitance: Real;
		attribute operatingTempMin: Real;
		attribute operatingTempMax: Real;
		attribute resonantFrequency: Real;
	}
	
	part def ChargeAmplifier {
		attribute gain: Real;
		attribute inputImpedance: Real;
		attribute outputImpedance: Real;
		attribute bandwidth: Real;
		
		port chargeInput: ElectricalOutputPort;
		port voltageOutput: ElectricalOutputPort;
		port power: PowerSupplyPort;
		
		action amplify {
			in item inputSignal: ElectricalSignal;
			in amplifierGain: Real;
			out item outputSignal: ElectricalSignal;
		}
	}
	
	part def SignalConditioner {
		attribute filterType: String;
		attribute cutoffFrequency: Real;
		attribute amplificationFactor: Real;
		
		port signalInput: ElectricalOutputPort;
		port signalOutput: ElectricalOutputPort;
		
		action condition {
			in item rawSignal: ElectricalSignal;
			out item conditionedSignal: ElectricalSignal;
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution: Integer;
		attribute samplingRate: Real;
		attribute referenceVoltage: VoltageValue;
		
		port analogInput: ElectricalOutputPort;
		port digitalOutput: DigitalOutputPort;
		
		action convert {
			in item analogSignal: ElectricalSignal;
			in refVoltage: VoltageValue;
			in adcResolution: Integer;
			out item digitalData: DigitalReading;
		}
	}
	
	part def PiezoelectricSensor {
		attribute sensorId: String;
		attribute calibrationDate: String;
		attribute measurementRangeMin: PressureValue;
		attribute measurementRangeMax: PressureValue;
		
		part crystal: PiezoelectricCrystal[1] {
			attribute :>> materialType = "PZT-5H";
			attribute :>> sensitivity = 650;
			attribute :>> capacitance = 1800;
			attribute :>> operatingTempMin = -40;
			attribute :>> operatingTempMax = 200;
			attribute :>> resonantFrequency = 30000;
		}
		
		port mechanicalInput: MechanicalInputPort;
		port electricalOutput: ElectricalOutputPort;
		
		action sense {
			in item inputStimulus: MechanicalStimulus;
			out item outputSignal: ElectricalSignal;
			
			action applyStress {
				in item mechanicalInput: MechanicalStimulus;
				out attribute stress: PressureValue;
			}
			
			then action generateCharge {
				in attribute appliedStress: PressureValue;
				in attribute crystalSensitivity: SensitivityCoefficient;
				out attribute generatedCharge: ChargeValue;
			}
			
			then action produceVoltage {
				in attribute charge: ChargeValue;
				in attribute crystalCapacitance: Real;
				out item electricalSignal: ElectricalSignal;
			}
			
			flow from applyStress.stress to generateCharge.appliedStress;
			flow from generateCharge.generatedCharge to produceVoltage.charge;
		}
	}
	
	state def SensorOperationalStates {
		entry; then idle;
		
		state idle {
			entry action initializeSensor;
		}
		
		transition idle_to_ready
			first idle
			then ready;
		
		state ready {
			entry action performSelfTest;
		}
		
		transition ready_to_sensing
			first ready
			then sensing;
		
		state sensing {
			entry action startMeasurement;
			do action continuousSensing;
		}
		
		transition sensing_to_amplifying
			first sensing
			then amplifying;
		
		state amplifying {
			entry action amplifyCharge;
		}
		
		transition amplifying_to_conditioning
			first amplifying
			then conditioning;
		
		state conditioning {
			entry action filterSignal;
			do action conditionSignal;
		}
		
		transition conditioning_to_converting
			first conditioning
			then converting;
		
		state converting {
			entry action digitizeSignal;
		}
		
		transition converting_to_outputting
			first converting
			then outputting;
		
		state outputting {
			entry action transmitReading;
		}
		
		transition outputting_to_ready
			first outputting
			then ready;
		
		state fault {
			entry action reportFault;
			do action diagnostics;
		}
		
		transition fault_to_idle
			first fault
			then idle;
	}
	
	part def SensingUnit {
		attribute unitId: String;
		attribute operatingVoltage: VoltageValue;
		attribute outputRangeMin: VoltageValue;
		attribute outputRangeMax: VoltageValue;
		
		part sensor: PiezoelectricSensor[1] {
			attribute :>> sensorId = "PZT-SU-2025-001";
			attribute :>> calibrationDate = "2025-01-20";
			attribute :>> measurementRangeMin = 0[Pa];
			attribute :>> measurementRangeMax = 15000000[Pa];
		}
		
		part amplifier: ChargeAmplifier[1] {
			attribute :>> gain = 150;
			attribute :>> inputImpedance = 2000000000;
			attribute :>> outputImpedance = 100;
			attribute :>> bandwidth = 150000;
		}
		
		part conditioner: SignalConditioner[1] {
			attribute :>> filterType = "Butterworth Low-Pass";
			attribute :>> cutoffFrequency = 75000;
			attribute :>> amplificationFactor = 5;
		}
		
		part adc: AnalogToDigitalConverter[1] {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 200000;
			attribute :>> referenceVoltage = 5[V];
		}
		
		port mechanicalInterface: MechanicalInputPort;
		port dataOutput: DigitalOutputPort;
		port powerSupply: PowerSupplyPort;
		
		connection mechanicalConnection
			connect mechanicalInterface to sensor.mechanicalInput;
		
		connection sensorToAmplifier
			connect sensor.electricalOutput to amplifier.chargeInput;
		
		connection amplifierToConditioner
			connect amplifier.voltageOutput to conditioner.signalInput;
		
		connection conditionerToADC
			connect conditioner.signalOutput to adc.analogInput;
		
		connection adcToOutput
			connect adc.digitalOutput to dataOutput;
		
		connection powerToAmplifier
			connect powerSupply to amplifier.power;
		
		perform action operateUnit: OperateSensingUnit;
		
		exhibit state operationalState: SensorOperationalStates;
	}
	
	action def OperateSensingUnit {
		in item mechanicalInput: MechanicalStimulus;
		out item digitalOutput: DigitalReading;
		
		action receiveMechanicalInput {
			in item inputStim: MechanicalStimulus;
			out item stimulus: MechanicalStimulus;
		}
		
		then action performSensing {
			in item inputStimulus: MechanicalStimulus;
			out item rawSignal: ElectricalSignal;
		}
		
		then action amplifySignal {
			in item rawElectrical: ElectricalSignal;
			in amplifierGain: Real;
			out item amplifiedSignal: ElectricalSignal;
		}
		
		then action conditionSignal {
			in item amplifiedElectrical: ElectricalSignal;
			out item conditionedSignal: ElectricalSignal;
		}
		
		then action convertToDigital {
			in item analogSignal: ElectricalSignal;
			in refVoltage: VoltageValue;
			in resolution: Integer;
			out item digitalData: DigitalReading;
		}
		
		then action outputReading {
			in item finalData: DigitalReading;
			out item outputData: DigitalReading;
		}
		
		flow from receiveMechanicalInput.stimulus to performSensing.inputStimulus;
		flow from performSensing.rawSignal to amplifySignal.rawElectrical;
		flow from amplifySignal.amplifiedSignal to conditionSignal.amplifiedElectrical;
		flow from conditionSignal.conditionedSignal to convertToDigital.analogSignal;
		flow from convertToDigital.digitalData to outputReading.finalData;
	}
	
	requirement def SensingUnitRequirements {
		doc /* The sensing unit shall measure pressure using a piezoelectric sensor with specified performance characteristics. */
		
		requirement measurementAccuracy {
			doc /* The sensing unit shall provide measurement accuracy within ±1.5% of full scale. */
			attribute requiredAccuracy: Real = 0.015;
		}
		
		requirement responseTime {
			doc /* The sensing unit shall respond to pressure changes within 0.5 milliseconds. */
			attribute maxResponseTime: Real = 0.0005;
		}
		
		requirement operatingRange {
			doc /* The sensing unit shall operate over a pressure range of 0 to 15 MPa. */
			attribute minPressure: PressureValue = 0[Pa];
			attribute maxPressure: PressureValue = 15000000[Pa];
		}
		
		requirement temperatureStability {
			doc /* The sensing unit shall maintain accuracy over -40°C to 200°C. */
			attribute minTemperature: Real = -40;
			attribute maxTemperature: Real = 200;
		}
		
		requirement outputSignal {
			doc /* The sensing unit shall provide a digital output with 16-bit resolution. */
			attribute minResolution: Integer = 16;
		}
		
		requirement powerConsumption {
			doc /* The sensing unit shall operate on 24V DC supply with maximum 500mA current. */
			attribute nominalVoltage: VoltageValue = 24[V];
			attribute maxCurrent: Real = 0.5;
		}
	}
	
	requirement sensingUnitReqs: SensingUnitRequirements {
		subject sensingUnitSubject: SensingUnit;
		
		require measurementAccuracy;
		require responseTime;
		require operatingRange;
		require temperatureStability;
		require outputSignal;
		require powerConsumption;
	}
	
	part sensingUnitInstance: SensingUnit {
		attribute :>> unitId = "SU-PZT-2025-MAIN";
		attribute :>> operatingVoltage = 24[V];
		attribute :>> outputRangeMin = 0[V];
		attribute :>> outputRangeMax = 5[V];
		
		satisfy sensingUnitReqs by sensingUnitInstance;
	}
	
	individual def TestPressureSource :> MechanicalStimulus;
	individual def TestSensingUnit :> SensingUnit;
	
	individual testScenario: TestSensingUnit :> sensingUnitInstance {
		timeslice lowPressureTest {
			perform action :>> operateUnit {
				in individual :>> mechanicalInput: TestPressureSource {
					:>> appliedPressure = 500000[Pa];
					:>> appliedForce = 50[N];
				}
			}
		}
		
		then timeslice mediumPressureTest {
			perform action :>> operateUnit {
				in individual :>> mechanicalInput: TestPressureSource {
					:>> appliedPressure = 7500000[Pa];
					:>> appliedForce = 750[N];
				}
			}
		}
		
		then timeslice highPressureTest {
			perform action :>> operateUnit {
				in individual :>> mechanicalInput: TestPressureSource {
					:>> appliedPressure = 14000000[Pa];
					:>> appliedForce = 1400[N];
				}
			}
		}
	}
}
