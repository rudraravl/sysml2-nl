package 'MAP_Sensor_Sensing_Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	comment about MAPSensingUnit
	/* This model describes a Manifold Absolute Pressure (MAP) sensor sensing unit
	 * used in automotive engine management systems. The unit measures intake manifold
	 * absolute pressure and converts it to an electrical signal for engine control.
	 */
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def VoltageValue :> ISQ::VoltageValue;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	
	item def PressureSignal {
		attribute pressure : PressureValue;
		attribute timestamp : Real;
		attribute valid : Boolean;
	}
	
	item def VoltageSignal {
		attribute voltage : VoltageValue;
		attribute timestamp : Real;
	}
	
	item def DigitalPressureData {
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute status : SensorStatus;
		attribute timestamp : Real;
	}
	
	enum def SensorStatus {
		enum normal;
		enum degraded;
		enum outOfRange;
		enum fault;
	}
	
	port def PneumaticPort {
		in item pressureInput : PressureSignal;
	}
	
	port def AnalogOutputPort {
		out item analogSignal : VoltageSignal;
	}
	
	port def DigitalOutputPort {
		out item digitalData : DigitalPressureData;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : VoltageValue;
		in attribute groundReference : VoltageValue;
	}
	
	part def PiezoelectricElement {
		attribute sensitivity : Real;
		attribute pressureRange : PressureValue[2];
		
		port pneumaticInput : PneumaticPort;
		
		action transduce {
			in item inputPressure : PressureSignal;
			out attribute mechanicalStrain : Real;
		}
	}
	
	part def StrainGaugeBridge {
		attribute bridgeResistance : Real;
		attribute gaugeFactorValue : Real;
		
		action convertStrainToVoltage {
			in attribute strain : Real;
			in attribute excitationVoltage : VoltageValue;
			out attribute outputVoltage : VoltageValue;
		}
	}
	
	part def SignalAmplifier {
		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
		attribute inputImpedance : Real;
		
		action amplify {
			in attribute inputVoltage : VoltageValue;
			out attribute amplifiedVoltage : VoltageValue;
		}
	}
	
	part def TemperatureCompensator {
		attribute compensationCoefficient : Real;
		
		action compensate {
			in attribute rawVoltage : VoltageValue;
			in attribute temperature : TemperatureValue;
			out attribute compensatedVoltage : VoltageValue;
		}
	}
	
	part def LowPassFilter {
		attribute cutoffFrequency : FrequencyValue;
		attribute filterOrder : Integer;
		
		action filterSignal {
			in attribute inputSignal : VoltageValue;
			out attribute filteredSignal : VoltageValue;
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute referenceVoltage : VoltageValue;
		
		action convert {
			in attribute analogInput : VoltageValue;
			out attribute digitalValue : Integer;
		}
	}
	
	part def TemperatureSensor {
		attribute temperatureRange : TemperatureValue[2];
		attribute accuracy : TemperatureValue;
		
		action measureTemperature {
			out attribute currentTemperature : TemperatureValue;
		}
	}
	
	part def Microcontroller {
		attribute processingFrequency : FrequencyValue;
		
		action calibrate {
			in attribute rawDigitalValue : Integer;
			in attribute temperature : TemperatureValue;
			out attribute calibratedPressure : PressureValue;
		}
		
		action performDiagnostics {
			in attribute pressureReading : PressureValue;
			in attribute expectedRange : PressureValue[2];
			out attribute diagnosticStatus : SensorStatus;
		}
		
		action formatOutput {
			in attribute pressure : PressureValue;
			in attribute temperature : TemperatureValue;
			in attribute status : SensorStatus;
			out item outputData : DigitalPressureData;
		}
	}
	
	part def VoltageRegulator {
		attribute outputVoltage : VoltageValue;
		attribute currentLimit : Real;
		
		port powerInput : PowerPort;
		
		action regulate {
			in attribute inputVoltage : VoltageValue;
			out attribute regulatedVoltage : VoltageValue;
		}
	}
	
	part def MAPSensorElement {
		attribute sensorID : String;
		attribute calibrationDate : String;
		attribute operatingPressureRange : PressureValue[2];
		attribute operatingTemperatureRange : TemperatureValue[2];
		
		port pneumaticInterface : PneumaticPort;
		port analogOutput : AnalogOutputPort;
		port digitalOutput : DigitalOutputPort;
		port power : PowerPort;
		
		part piezoElement : PiezoelectricElement[1];
		part strainBridge : StrainGaugeBridge[1];
		part amplifier : SignalAmplifier[1];
		part tempCompensator : TemperatureCompensator[1];
		part lowPassFilter : LowPassFilter[1];
		part adc : AnalogToDigitalConverter[1];
		part tempSensor : TemperatureSensor[1];
		part microcontroller : Microcontroller[1];
		part regulator : VoltageRegulator[1];
		
		connect pneumaticInterface to piezoElement.pneumaticInput;
		connect power to regulator.powerInput;
	}
	
	state def MAPSensorStates {
		entry; then powerOn;
		
		state powerOn {
			entry action initializePower;
		}
		then selfTest;
		
		state selfTest {
			entry action runDiagnostics {
				out attribute testResult : Boolean;
			}
		}
		if selfTest.runDiagnostics.testResult == true then operational;
		if selfTest.runDiagnostics.testResult == false then faultMode;
		
		state operational {
			entry; then measuring;
			
			state measuring {
				entry action acquirePressure;
				do action continuousSampling;
			}
			then processing;
			
			state processing {
				entry action processSignal;
				do action applyCalibration;
			}
			then transmitting;
			
			state transmitting {
				entry action sendData;
			}
			then measuring;
		}
		
		accept at operational
			if microcontroller.performDiagnostics.diagnosticStatus == SensorStatus::fault
			then faultMode;
		
		state faultMode {
			entry action reportFault;
			do action attemptRecovery;
		}
		accept at faultMode then selfTest;
		
		accept at operational then powerDown;
		
		state powerDown {
			entry action shutdownSequence;
		}
		then done;
	}
	
	action def MeasureManifoldPressure {
		in item manifoldPressure : PressureSignal;
		out item digitalOutput : DigitalPressureData;
		
		action acquirePressure {
			in item pressure : PressureSignal;
			out attribute strain : Real;
			
			bind pressure = manifoldPressure;
		}
		then convertToVoltage;
		
		flow from acquirePressure.strain to convertToVoltage.strainInput;
		
		action convertToVoltage {
			in attribute strainInput : Real;
			in attribute excitation : VoltageValue;
			out attribute bridgeVoltage : VoltageValue;
		}
		then amplifySignal;
		
		flow from convertToVoltage.bridgeVoltage to amplifySignal.inputVoltage;
		
		action amplifySignal {
			in attribute inputVoltage : VoltageValue;
			out attribute amplifiedVoltage : VoltageValue;
		}
		then compensateTemperature;
		
		flow from amplifySignal.amplifiedVoltage to compensateTemperature.rawVoltage;
		
		action compensateTemperature {
			in attribute rawVoltage : VoltageValue;
			in attribute temperature : TemperatureValue;
			out attribute compensatedVoltage : VoltageValue;
		}
		then applyFilter;
		
		flow from compensateTemperature.compensatedVoltage to applyFilter.inputSignal;
		
		action applyFilter {
			in attribute inputSignal : VoltageValue;
			out attribute filteredSignal : VoltageValue;
		}
		then digitize;
		
		flow from applyFilter.filteredSignal to digitize.analogInput;
		
		action digitize {
			in attribute analogInput : VoltageValue;
			out attribute digitalValue : Integer;
		}
		then calibrateAndFormat;
		
		flow from digitize.digitalValue to calibrateAndFormat.rawValue;
		
		action calibrateAndFormat {
			in attribute rawValue : Integer;
			in attribute temperature : TemperatureValue;
			out item formattedData : DigitalPressureData;
			
			bind formattedData = digitalOutput;
		}
	}
	
	part def IntakeManifold {
		attribute volume : Real;
		attribute currentPressure : PressureValue;
		attribute currentTemperature : TemperatureValue;
		
		port pressurePort : PneumaticOutputPort;
	}
	
	port def PneumaticOutputPort {
		out item pressureOutput : PressureSignal;
	}
	
	part def EngineControlUnit {
		port sensorDataInput : DigitalInputPort;
		port powerOutput : PowerSupplyPort;
		
		action processPressureData {
			in item pressureData : DigitalPressureData;
			out attribute fuelAdjustment : Real;
			out attribute ignitionTiming : Real;
		}
		
		action calculateEngineLoad {
			in attribute manifoldPressure : PressureValue;
			in attribute engineSpeed : FrequencyValue;
			out attribute engineLoad : Real;
		}
	}
	
	port def DigitalInputPort {
		in item dataInput : DigitalPressureData;
	}
	
	port def PowerSupplyPort {
		out attribute supply : VoltageValue;
		out attribute ground : VoltageValue;
	}
	
	connection def PneumaticConnection {
		end source : PneumaticOutputPort;
		end target : PneumaticPort;
	}
	
	connection def DigitalDataConnection {
		end source : DigitalOutputPort;
		end target : DigitalInputPort;
	}
	
	connection def PowerConnection {
		end source : PowerSupplyPort;
		end target : PowerPort;
	}
	
	part MAPSensingUnit {
		part manifold : IntakeManifold[1];
		part mapSensor : MAPSensorElement[1];
		part ecu : EngineControlUnit[1];
		
		connection pneumaticLink : PneumaticConnection
			connect source => manifold.pressurePort
			to target => mapSensor.pneumaticInterface;
		
		connection dataLink : DigitalDataConnection
			connect source => mapSensor.digitalOutput
			to target => ecu.sensorDataInput;
		
		connection powerLink : PowerConnection
			connect source => ecu.powerOutput
			to target => mapSensor.power;
	}
	
	requirement def AccuracyRequirement {
		doc /* The MAP sensor shall measure manifold absolute pressure
		 * with an accuracy of +/- 0.5% of full scale over the operating range. */
		
		subject sensor : MAPSensorElement;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The MAP sensor shall respond to pressure changes
		 * within 5 milliseconds from 10% to 90% of final value. */
		
		subject sensor : MAPSensorElement;
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The MAP sensor shall operate correctly over the temperature
		 * range of -40°C to +150°C. */
		
		subject sensor : MAPSensorElement;
	}
	
	requirement def OutputRangeRequirement {
		doc /* The MAP sensor shall provide an analog voltage output
		 * in the range of 0.5V to 4.5V corresponding to the pressure range. */
		
		subject sensor : MAPSensorElement;
	}
	
	requirement def DiagnosticCapabilityRequirement {
		doc /* The MAP sensor shall perform continuous self-diagnostics
		 * and report fault conditions to the ECU. */
		
		subject sensor : MAPSensorElement;
		
		require sensor.microcontroller.performDiagnostics;
	}
	
	requirement def PowerSupplyRequirement {
		doc /* The MAP sensor shall operate from a 5V +/- 0.25V supply
		 * with current consumption not exceeding 10mA. */
		
		subject sensor : MAPSensorElement;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the MAP sensor sensing unit. */
		
		subject unit : MAPSensingUnit;
		
		requirement :> AccuracyRequirement;
		requirement :> ResponseTimeRequirement;
		requirement :> TemperatureRangeRequirement;
		requirement :> OutputRangeRequirement;
		requirement :> DiagnosticCapabilityRequirement;
		requirement :> PowerSupplyRequirement;
	}
	
	part mapSensingUnitInstance : MAPSensingUnit {
		part :>> mapSensor {
			attribute :>> sensorID = "MAP-2025-001";
			attribute :>> calibrationDate = "2025-01-15";
			attribute :>> operatingPressureRange = (20.0[kPa], 250.0[kPa]);
			attribute :>> operatingTemperatureRange = (-40.0['°C'], 150.0['°C']);
			
			part :>> piezoElement {
				attribute :>> sensitivity = 0.025;
				attribute :>> pressureRange = (20.0[kPa], 250.0[kPa]);
			}
			
			part :>> strainBridge {
				attribute :>> bridgeResistance = 350.0;
				attribute :>> gaugeFactorValue = 2.1;
			}
			
			part :>> amplifier {
				attribute :>> gain = 100.0;
				attribute :>> bandwidth = 1000.0[Hz];
				attribute :>> inputImpedance = 1.0e6;
			}
			
			part :>> tempCompensator {
				attribute :>> compensationCoefficient = 0.002;
			}
			
			part :>> lowPassFilter {
				attribute :>> cutoffFrequency = 500.0[Hz];
				attribute :>> filterOrder = 2;
			}
			
			part :>> adc {
				attribute :>> resolution = 12;
				attribute :>> samplingRate = 2000.0[Hz];
				attribute :>> referenceVoltage = 5.0[V];
			}
			
			part :>> tempSensor {
				attribute :>> temperatureRange = (-40.0['°C'], 150.0['°C']);
				attribute :>> accuracy = 1.0['°C'];
			}
			
			part :>> microcontroller {
				attribute :>> processingFrequency = 16.0[MHz];
			}
			
			part :>> regulator {
				attribute :>> outputVoltage = 5.0[V];
				attribute :>> currentLimit = 0.01;
			}
		}
		
		part :>> manifold {
			attribute :>> volume = 3.5;
			attribute :>> currentPressure = 101.3[kPa];
			attribute :>> currentTemperature = 25.0['°C'];
		}
	}
}
