package 'Silicon Bandgap Temperature Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VoltageValue :> ElectricPotentialValue;
	attribute def CurrentValue :> ElectricCurrentValue;
	attribute def ResistanceValue :> ISQ::ResistanceValue;
	
	alias Temperature for ISQ::ThermodynamicTemperatureValue;
	alias Voltage for VoltageValue;
	alias Current for CurrentValue;
	
	item def TemperatureMeasurement {
		attribute value : Temperature;
		attribute timestamp : Real;
		attribute accuracy : Temperature;
	}
	
	item def AnalogSignal {
		attribute voltage : Voltage;
	}
	
	item def DigitalData {
		attribute rawValue : Integer;
		attribute scaledValue : Temperature;
	}
	
	port def TemperatureOutputPort {
		out item measurement : TemperatureMeasurement;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage : Voltage;
		in attribute supplyCurrent : Current;
	}
	
	port def AnalogOutputPort {
		out item signal : AnalogSignal;
	}
	
	port def AnalogInputPort {
		in item signal : AnalogSignal;
	}
	
	port def DigitalOutputPort {
		out item data : DigitalData;
	}
	
	connection def AnalogConnection {
		end sourcePort : AnalogOutputPort;
		end sinkPort : AnalogInputPort;
	}
	
	part def BipolarJunctionTransistor {
		doc /*
		 * BJT used in bandgap reference circuit
		 */
		attribute emitterArea : Real;
		attribute baseEmitterVoltage : Voltage;
		attribute collectorCurrent : Current;
		attribute saturationCurrent : Current;
	}
	
	part def PTATVoltageGenerator {
		doc /*
		 * Proportional To Absolute Temperature voltage generator
		 * Exploits the temperature dependence of VBE difference
		 */
		attribute deltaVbe : Voltage;
		attribute temperatureCoefficient : Real;
		
		part bjt1 : BipolarJunctionTransistor {
			attribute :>> emitterArea = 1.0;
		}
		
		part bjt2 : BipolarJunctionTransistor {
			attribute :>> emitterArea = 8.0;
		}
		
		part resistor : Resistor {
			attribute resistance : ResistanceValue;
		}
	}
	
	part def Resistor {
		attribute resistance : ResistanceValue;
		attribute voltageDrop : Voltage;
	}
	
	part def BandgapReferenceCore {
		doc /*
		 * Core bandgap reference circuit generating stable voltage
		 */
		attribute referenceVoltage : Voltage;
		attribute temperatureDrift : Real;
		
		part ptatGenerator : PTATVoltageGenerator;
		part summing : SummingAmplifier;
	}
	
	part def SummingAmplifier {
		attribute gain : Real;
		attribute outputVoltage : Voltage;
	}
	
	part def OutputBuffer {
		attribute gain : Real;
		attribute outputImpedance : ResistanceValue;
	}
	
	part def SiliconBandgapSensor {
		doc /*
		 * Silicon bandgap temperature sensor using BJT characteristics
		 * to generate temperature-proportional voltage output
		 */
		port analogOut : AnalogOutputPort;
		port powerIn : PowerSupplyPort;
		
		attribute operatingRangeMin : Temperature;
		attribute operatingRangeMax : Temperature;
		attribute sensitivity : Real;
		attribute bandgapVoltage : Voltage;
		
		part bandgapCore : BandgapReferenceCore {
			attribute :>> referenceVoltage {
				attribute :>> num = 1.205;
				attribute :>> mRef = SI::V;
			}
			attribute :>> temperatureDrift = 0.00001;
			
			part :>> ptatGenerator {
				attribute :>> deltaVbe {
					attribute :>> num = 0.0002;
					attribute :>> mRef = SI::V;
				}
				attribute :>> temperatureCoefficient = 0.0033;
			}
		}
		
		part outputStage : OutputBuffer {
			attribute :>> gain = 5.0;
		}
		
		part biasCircuit : BiasCircuit {
			attribute biasCurrent : Current {
				attribute :>> num = 0.00001;
				attribute :>> mRef = SI::A;
			}
		}
	}
	
	part def BiasCircuit {
		attribute biasCurrent : Current;
		attribute stabilityFactor : Real;
	}
	
	part def AnalogToDigitalConverter {
		doc /*
		 * ADC for converting analog sensor voltage to digital value
		 */
		port analogIn : AnalogInputPort;
		port digitalOut : DigitalOutputPort;
		port powerIn : PowerSupplyPort;
		
		attribute resolution : Integer;
		attribute referenceVoltage : Voltage;
		attribute samplingRate : Real;
		attribute conversionTime : Real;
		
		action convertSignal {
			in analogSignal : AnalogSignal;
			out digitalValue : Integer;
		}
	}
	
	part def SignalProcessor {
		doc /*
		 * Processes digital data and applies calibration
		 */
		attribute calibrationOffset : Voltage;
		attribute calibrationGain : Real;
		
		action calibrateAndScale {
			in rawData : DigitalData;
			out calibratedTemperature : Temperature;
		}
	}
	
	part def SensorController {
		doc /*
		 * Controls measurement cycle and data processing
		 */
		
		action startMeasurement;
		action acquireData;
		action processAndCalibrate;
		action prepareOutput;
		action handleError;
		
		state controlStateMachine {
			entry; then powerUp;
			
			state powerUp {
				doc /* Initial power-up and stabilization */
			}
			
			transition powerUp_to_idle
				first powerUp
				accept StabilizedEvent
				then idle;
			
			state idle {
				doc /* Low-power standby state */
			}
			
			transition idle_to_measuring
				first idle
				accept MeasureCommand
				then measuring;
			
			state measuring {
				doc /* Active measurement in progress */
				entry startMeasurement;
				do acquireData;
			}
			
			transition measuring_to_processing
				first measuring
				accept DataReadyEvent
				then processing;
			
			state processing {
				doc /* Processing and calibrating data */
				do processAndCalibrate;
			}
			
			transition processing_to_outputReady
				first processing
				accept ProcessingCompleteEvent
				then outputReady;
			
			state outputReady {
				doc /* Measurement ready for output */
				entry prepareOutput;
			}
			
			transition outputReady_to_idle
				first outputReady
				accept OutputSentEvent
				then idle;
			
			transition error_transition
				first measuring
				accept ErrorEvent
				then errorState;
			
			state errorState {
				doc /* Error handling state */
				entry handleError;
			}
			
			transition errorState_to_idle
				first errorState
				accept RecoveryCompleteEvent
				then idle;
		}
	}
	
	part def TemperatureSensingUnit {
		doc /*
		 * Complete temperature sensing unit integrating sensor,
		 * ADC, signal processing, and control logic
		 */
		port powerSupply : PowerSupplyPort;
		port temperatureOutput : TemperatureOutputPort;
		
		part sensor : SiliconBandgapSensor {
			attribute :>> operatingRangeMin {
				attribute :>> num = 233.15;
				attribute :>> mRef = SI::K;
			}
			attribute :>> operatingRangeMax {
				attribute :>> num = 398.15;
				attribute :>> mRef = SI::K;
			}
			attribute :>> sensitivity = 10.0;
			attribute :>> bandgapVoltage {
				attribute :>> num = 1.205;
				attribute :>> mRef = SI::V;
			}
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 12;
			attribute :>> referenceVoltage {
				attribute :>> num = 3.3;
				attribute :>> mRef = SI::V;
			}
			attribute :>> samplingRate = 1000.0;
			attribute :>> conversionTime = 0.001;
		}
		
		part processor : SignalProcessor {
			attribute :>> calibrationOffset {
				attribute :>> num = 0.6;
				attribute :>> mRef = SI::V;
			}
			attribute :>> calibrationGain = 100.0;
		}
		
		part controller : SensorController;
		
		connection sensorToAdc : AnalogConnection
			connect sourcePort references sensor.analogOut
			to sinkPort references adc.analogIn;
		
		connect powerSupply to sensor.powerIn;
		connect powerSupply to adc.powerIn;
	}
	
	action def MeasureTemperature {
		doc /*
		 * Complete temperature measurement action sequence
		 */
		in item unit : TemperatureSensingUnit;
		out item result : TemperatureMeasurement;
		
		action initialize {
			in item sensingUnit : TemperatureSensingUnit;
		}
		
		then action stabilize {
			doc /* Allow sensor to reach thermal equilibrium */
		}
		
		then action generateAnalogSignal {
			out analogVoltage : AnalogSignal;
		}
		
		then action digitize {
			in analog : AnalogSignal;
			out digital : DigitalData;
		}
		
		then action calibrate {
			in rawData : DigitalData;
			out temperature : Temperature;
		}
		
		then action formatOutput {
			in temp : Temperature;
			out measurement : TemperatureMeasurement;
		}
		
		flow from generateAnalogSignal.analogVoltage to digitize.analog;
		flow from digitize.digital to calibrate.rawData;
		flow from calibrate.temperature to formatOutput.temp;
		
		bind formatOutput.measurement = result;
	}
	
	requirement def AccuracyRequirement {
		doc /*
		 * Sensor shall provide accurate temperature measurements
		 */
		subject sensor : SiliconBandgapSensor;
		
		attribute maxError : Temperature {
			attribute :>> num = 0.5;
			attribute :>> mRef = SI::K;
		}
		
		require constraint {
			sensor.sensitivity >= 5.0
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /*
		 * Sensor shall operate over industrial temperature range
		 */
		subject sensor : SiliconBandgapSensor;
		
		require constraint {
			sensor.operatingRangeMin.num >= 233.15 and
			sensor.operatingRangeMax.num <= 398.15
		}
	}
	
	requirement def PowerRequirement {
		doc /*
		 * Unit shall operate within power budget
		 */
		subject unit : TemperatureSensingUnit;
		
		attribute maxSupplyCurrent : Current {
			attribute :>> num = 0.001;
			attribute :>> mRef = SI::A;
		}
		
		require constraint {
			unit.powerSupply.supplyCurrent.num <= maxSupplyCurrent.num
		}
	}
	
	requirement def ResolutionRequirement {
		doc /*
		 * ADC shall provide sufficient resolution
		 */
		subject adc : AnalogToDigitalConverter;
		
		require constraint {
			adc.resolution >= 12
		}
	}
	
	part sensingUnitInstance : TemperatureSensingUnit {
		satisfy AccuracyRequirement by sensor;
		satisfy OperatingRangeRequirement by sensor;
		satisfy PowerRequirement by sensingUnitInstance;
		satisfy ResolutionRequirement by adc;
		
		perform measurementCycle : MeasureTemperature {
			in item :>> unit = sensingUnitInstance;
			out item :>> result {
				attribute :>> value {
					attribute :>> num = 298.15;
					attribute :>> mRef = SI::K;
				}
				attribute :>> timestamp = 0.0;
				attribute :>> accuracy {
					attribute :>> num = 0.5;
					attribute :>> mRef = SI::K;
				}
			}
		}
	}
	
	verification def VerifyAccuracy {
		subject testUnit : TemperatureSensingUnit;
		
		objective verifyAtRoomTemp {
			in testTemperature : Temperature {
				attribute :>> num = 298.15;
				attribute :>> mRef = SI::K;
			}
			
			perform testUnit.measurementCycle {
				in item :>> unit = testUnit;
				out item measured = result;
			}
			
			assert constraint {
				(measured.value.num >= testTemperature.num - 0.5) and
				(measured.value.num <= testTemperature.num + 0.5)
			}
		}
	}
}
