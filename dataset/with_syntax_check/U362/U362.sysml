package 'Pulse Duplicator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Pressure :> ISQ::PressureValue;
	attribute def FlowRate :> ISQ::VolumeFlowRateValue;
	attribute def HeartRate :> ISQ::FrequencyValue;
	attribute def StrokeVolume :> ISQ::VolumeValue;
	attribute def Duration :> ISQ::TimeValue;
	attribute def Compliance :> ISQ::VolumeValue;
	
	item def PressureWaveform {
		attribute systolicPressure : Pressure;
		attribute diastolicPressure : Pressure;
		attribute meanPressure : Pressure;
		attribute pulseRate : HeartRate;
	}
	
	item def FlowWaveform {
		attribute peakFlow : FlowRate;
		attribute meanFlow : FlowRate;
		attribute strokeVolume : StrokeVolume;
	}
	
	item def TestData {
		attribute timestamp : Duration;
		attribute upstreamPressure : Pressure;
		attribute downstreamPressure : Pressure;
		attribute flowRate : FlowRate;
		attribute pressureGradient : Pressure;
	}
	
	port def FluidPort {
		in item incomingFlow : FlowRate;
		out item outgoingFlow : FlowRate;
		attribute pressure : Pressure;
	}
	
	port def ControlPort {
		in item commandSignal : PressureWaveform;
		out item statusFeedback : Boolean;
	}
	
	port def SensorPort {
		out item measurement : Pressure;
	}
	
	part def PulsatilePump {
		port inlet : FluidPort;
		port outlet : FluidPort;
		port control : ControlPort;
		
		attribute targetWaveform : PressureWaveform;
		attribute currentStroke : StrokeVolume;
		
		state pumpBehavior {
			entry; then idle;
			
			state idle;
			transition idle_to_systole
				first idle
				accept control.commandSignal
				then systole;
			
			state systole;
			transition systole_to_diastole
				first systole
				then diastole;
			
			state diastole;
			transition diastole_to_systole
				first diastole
				then systole;
		}
	}
	
	part def ComplianceChamber {
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		attribute chamberCompliance : Compliance;
		attribute currentVolume : StrokeVolume;
	}
	
	part def ResistanceValve {
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		attribute resistanceLevel : Real;
		attribute isOpen : Boolean;
	}
	
	part def PressureSensor {
		port measurementPort : SensorPort;
		port fluidConnection : FluidPort;
		
		action measurePressure {
			in fluidPressure : Pressure;
			out reading : Pressure;
		}
	}
	
	part def FlowMeter {
		port fluidConnection : FluidPort;
		
		attribute currentFlow : FlowRate;
		
		action measureFlow {
			in flow : FlowRate;
			out reading : FlowRate;
		}
	}
	
	part def TestValve {
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		attribute valveType : String;
		attribute effectiveOrificeArea : Real;
	}
	
	part def SystemController {
		port pumpControl : ControlPort;
		
		attribute desiredWaveform : PressureWaveform;
		attribute testDuration : Duration;
		
		action generateControlSignal {
			in waveform : PressureWaveform;
			out signal : PressureWaveform;
		}
	}
	
	action def SimulateCardiacCycle {
		in waveform : PressureWaveform;
		in duration : Duration;
		out pressureData : TestData[*];
		out flowData : FlowWaveform;
	}
	
	action def CollectMeasurements {
		in upstreamPressure : Pressure;
		in downstreamPressure : Pressure;
		in flowRate : FlowRate;
		in timestamp : Duration;
		out dataPoint : TestData;
	}
	
	action def CalculatePressureGradient {
		in upstream : Pressure;
		in downstream : Pressure;
		out gradient : Pressure;
	}
	
	part def PulseDuplicator {
		port fluidInlet : FluidPort;
		port fluidOutlet : FluidPort;
		
		part controller : SystemController {
			attribute :>> desiredWaveform = PressureWaveform {
				systolicPressure = 120.0 [SI::mmHg];
				diastolicPressure = 80.0 [SI::mmHg];
				meanPressure = 93.3 [SI::mmHg];
				pulseRate = 70.0 [SI::Hz];
			}
			attribute :>> testDuration = 60.0 [SI::s];
		}
		
		part pump : PulsatilePump;
		
		part complianceChamber : ComplianceChamber {
			attribute :>> chamberCompliance = 2.0e-6 [SI::m^3];
		}
		
		part testValve : TestValve {
			attribute :>> valveType = "Prosthetic Heart Valve";
		}
		
		part afterloadResistance : ResistanceValve {
			attribute :>> resistanceLevel = 1.2e9;
			attribute :>> isOpen = true;
		}
		
		part upstreamSensor : PressureSensor;
		part downstreamSensor : PressureSensor;
		part flowSensor : FlowMeter;
		
		connect controller.pumpControl to pump.control;
		connect fluidInlet to pump.inlet;
		connect pump.outlet to complianceChamber.inlet;
		connect complianceChamber.outlet to upstreamSensor.fluidConnection;
		connect upstreamSensor.fluidConnection to testValve.inlet;
		connect testValve.outlet to downstreamSensor.fluidConnection;
		connect downstreamSensor.fluidConnection to flowSensor.fluidConnection;
		connect flowSensor.fluidConnection to afterloadResistance.inlet;
		connect afterloadResistance.outlet to fluidOutlet;
		
		perform action conductValveTest {
			first start;
			
			then action initializeSystem {
				out systemReady : Boolean;
			}
			
			then action runTestCycle : SimulateCardiacCycle {
				in waveform = controller.desiredWaveform;
				in duration = controller.testDuration;
				out pressureData;
				out flowData;
			}
			
			then merge collectData;
			
			action acquireData : CollectMeasurements {
				in upstreamPressure = upstreamSensor.measurementPort.measurement;
				in downstreamPressure = downstreamSensor.measurementPort.measurement;
				in flowRate = flowSensor.currentFlow;
				in timestamp;
				out dataPoint;
			}
			
			then action computeGradient : CalculatePressureGradient {
				in upstream = acquireData.upstreamPressure;
				in downstream = acquireData.downstreamPressure;
				out gradient;
			}
			
			then collectData;
			
			then action finalizeTest {
				in collectedData : TestData[*] = runTestCycle.pressureData;
				out testReport : String;
			}
			
			then done;
		}
	}
	
	requirement def FunctionalRequirement;
	
	requirement <'PD-REQ-001'> primaryFunction : FunctionalRequirement {
		doc /* The pulse duplicator shall replicate physiological cardiovascular flow and pressure conditions 
		     to enable in vitro testing and performance evaluation of prosthetic heart valves under 
		     controlled, repeatable hemodynamic conditions. */
		
		subject system : PulseDuplicator;
		
		require constraint physiologicalSimulation {
			doc /* The system shall generate pulsatile flow with pressure waveforms matching human cardiac cycles. */
		}
	}
	
	requirement <'PD-REQ-002'> pressureMeasurement : FunctionalRequirement {
		doc /* The system shall measure transvalvular pressure gradient with accuracy of ±2 mmHg. */
		
		refine primaryFunction;
	}
	
	requirement <'PD-REQ-003'> flowMeasurement : FunctionalRequirement {
		doc /* The system shall measure volumetric flow rate through the test valve with accuracy of ±5%. */
		
		refine primaryFunction;
	}
	
	requirement <'PD-REQ-004'> waveformControl : FunctionalRequirement {
		doc /* The system shall maintain programmable pressure waveforms with systolic and diastolic phases. */
		
		refine primaryFunction;
	}
	
	satisfy primaryFunction by PulseDuplicator;
	satisfy pressureMeasurement by PulseDuplicator::upstreamSensor, PulseDuplicator::downstreamSensor;
	satisfy flowMeasurement by PulseDuplicator::flowSensor;
	satisfy waveformControl by PulseDuplicator::controller, PulseDuplicator::pump;
}
