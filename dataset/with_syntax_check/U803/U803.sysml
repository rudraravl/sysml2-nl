package PassiveInfraredSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def VoltageValue :> ISQ::VoltageValue;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def LengthValue :> ISQ::LengthValue;
	attribute def TimeValue :> ISQ::TimeValue;
	attribute def AngleValue :> ISQ::AngleValue;
	
	item def InfraredRadiation {
		attribute intensity : PowerValue;
		attribute wavelength : LengthValue;
		attribute sourceTemperature : TemperatureValue;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
		attribute timestamp : TimeValue;
	}
	
	item def MotionDetectionOutput {
		attribute motionDetected : Boolean;
		attribute signalStrength : VoltageValue;
		attribute detectionTime : TimeValue;
	}
	
	port def IRInputPort {
		in item radiation : InfraredRadiation;
	}
	
	port def AnalogSignalPort {
		out item signal : ElectricalSignal;
	}
	
	port def DigitalOutputPort {
		out item detection : MotionDetectionOutput;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage : VoltageValue;
	}
	
	part def FresnelLensArray {
		attribute focalLength : LengthValue;
		attribute numberOfSegments : Integer;
		attribute transmittance : Real;
		
		port irIn : IRInputPort;
		port irOut : IRInputPort;
	}
	
	part def PyroelectricSensor {
		attribute sensitivity : Real;
		attribute detectionThreshold : VoltageValue;
		attribute activeArea : LengthValue;
		
		port irInput : IRInputPort;
		port analogOutput : AnalogSignalPort;
		port powerIn : PowerSupplyPort;
		
		attribute currentVoltage : VoltageValue;
	}
	
	part def SignalAmplificationStage {
		attribute gainFactor : Real;
		attribute bandwidth : Real;
		
		port signalIn : AnalogSignalPort;
		port signalOut : AnalogSignalPort;
	}
	
	part def SignalProcessingUnit {
		attribute filterCutoffFrequency : Real;
		attribute noiseThreshold : VoltageValue;
		attribute processingDelay : TimeValue;
		
		port analogIn : AnalogSignalPort;
		port digitalOut : DigitalOutputPort;
	}
	
	part def VoltageRegulator {
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;
		
		port powerIn : PowerSupplyPort;
		port powerOut : PowerSupplyPort;
	}
	
	connection def IRRadiationFlow {
		end source : IRInputPort;
		end target : IRInputPort;
	}
	
	connection def AnalogSignalFlow {
		end source : AnalogSignalPort;
		end target : AnalogSignalPort;
	}
	
	connection def PowerConnection {
		end supply : PowerSupplyPort;
		end load : PowerSupplyPort;
	}
	
	action def FocusInfraredRadiation {
		in item ambientRadiation : InfraredRadiation;
		out item focusedRadiation : InfraredRadiation;
	}
	
	action def ConvertRadiationToElectrical {
		in item irRadiation : InfraredRadiation;
		out item electricalOutput : ElectricalSignal;
	}
	
	action def AmplifySignal {
		in item inputSignal : ElectricalSignal;
		out item amplifiedSignal : ElectricalSignal;
	}
	
	action def ProcessAndDetect {
		in item rawSignal : ElectricalSignal;
		out item detectionResult : MotionDetectionOutput;
	}
	
	action def PerformMotionDetection {
		in item environmentalIR : InfraredRadiation;
		out item motionOutput : MotionDetectionOutput;
		
		bind focusIR.ambientRadiation = environmentalIR;
		
		action focusIR : FocusInfraredRadiation {
			in ambientRadiation;
			out focusedRadiation;
		}
		
		flow from focusIR.focusedRadiation to convertSignal.irRadiation;
		
		action convertSignal : ConvertRadiationToElectrical {
			in irRadiation;
			out electricalOutput;
		}
		
		flow from convertSignal.electricalOutput to amplify.inputSignal;
		
		action amplify : AmplifySignal {
			in inputSignal;
			out amplifiedSignal;
		}
		
		flow from amplify.amplifiedSignal to processDetect.rawSignal;
		
		action processDetect : ProcessAndDetect {
			in rawSignal;
			out detectionResult;
		}
		
		bind processDetect.detectionResult = motionOutput;
	}
	
	part def PassiveInfraredSensingUnit {
		attribute detectionRange : LengthValue;
		attribute fieldOfView : AngleValue;
		attribute operatingTemperature : TemperatureValue[2];
		attribute powerConsumption : PowerValue;
		attribute responseTime : TimeValue;
		
		port environmentPort : IRInputPort;
		port outputPort : DigitalOutputPort;
		port powerInputPort : PowerSupplyPort;
		
		part lensArray : FresnelLensArray[1] {
			attribute :>> focalLength = 25.0[mm];
			attribute :>> numberOfSegments = 32;
			attribute :>> transmittance = 0.90;
		}
		
		part sensorElements : PyroelectricSensor[2] {
			attribute :>> sensitivity = 3000.0;
			attribute :>> detectionThreshold = 0.003[V];
			attribute :>> activeArea = 2.0[mm];
			attribute :>> currentVoltage = 0.0[V];
		}
		
		part amplifier : SignalAmplificationStage[1] {
			attribute :>> gainFactor = 800.0;
			attribute :>> bandwidth = 10.0;
		}
		
		part processor : SignalProcessingUnit[1] {
			attribute :>> filterCutoffFrequency = 5.0;
			attribute :>> noiseThreshold = 0.001[V];
			attribute :>> processingDelay = 0.15[s];
		}
		
		part regulator : VoltageRegulator[1] {
			attribute :>> inputVoltage = 12.0[V];
			attribute :>> outputVoltage = 5.0[V];
			attribute :>> efficiency = 0.85;
		}
		
		connection lensToSensor : IRRadiationFlow
			connect lensArray.irOut to sensorElements.irInput;
		
		connection sensorToAmplifier : AnalogSignalFlow
			connect sensorElements.analogOutput to amplifier.signalIn;
		
		connection amplifierToProcessor : AnalogSignalFlow
			connect amplifier.signalOut to processor.analogIn;
		
		connection powerRegulation : PowerConnection
			connect regulator.powerOut to sensorElements.powerIn;
		
		perform action detectionBehavior : PerformMotionDetection;
		
		exhibit state operationalStateMachine {
			entry; then initialization;
			
			state initialization;
			
			transition init_to_warmup
				first initialization
				then warmup;
			
			state warmup;
			
			transition warmup_to_monitoring
				first warmup
				then monitoring;
			
			state monitoring;
			
			transition monitoring_to_detecting
				first monitoring
				then detecting;
			
			state detecting;
			
			transition detecting_to_processing
				first detecting
				then processing;
			
			state processing;
			
			transition processing_to_output
				first processing
				then outputting;
			
			state outputting;
			
			transition output_to_monitoring
				first outputting
				then monitoring;
		}
	}
	
	part pirSensingUnit : PassiveInfraredSensingUnit {
		attribute :>> detectionRange = 10.0[m];
		attribute :>> fieldOfView = 120.0[deg];
		attribute :>> operatingTemperature = (243.15[K], 343.15[K]);
		attribute :>> powerConsumption = 0.5[W];
		attribute :>> responseTime = 0.2[s];
		
		part :>> lensArray {
			attribute :>> focalLength = 25.0[mm];
			attribute :>> numberOfSegments = 32;
			attribute :>> transmittance = 0.90;
		}
		
		part :>> sensorElements {
			attribute :>> sensitivity = 3000.0;
			attribute :>> detectionThreshold = 0.003[V];
			attribute :>> activeArea = 2.0[mm];
			attribute :>> currentVoltage = 0.0[V];
		}
		
		part :>> amplifier {
			attribute :>> gainFactor = 800.0;
			attribute :>> bandwidth = 10.0;
		}
		
		part :>> processor {
			attribute :>> filterCutoffFrequency = 5.0;
			attribute :>> noiseThreshold = 0.001[V];
			attribute :>> processingDelay = 0.15[s];
		}
		
		part :>> regulator {
			attribute :>> inputVoltage = 12.0[V];
			attribute :>> outputVoltage = 5.0[V];
			attribute :>> efficiency = 0.85;
		}
	}
	
	requirement def PIRMeasurementRequirement {
		doc /* The sensing unit shall measure infrared radiation changes using a passive infrared sensor to detect motion. */
		
		subject sensingSystem : PassiveInfraredSensingUnit;
		
		require constraint { sensingSystem.sensorElements.sensitivity > 0.0 }
		require constraint { sensingSystem.detectionRange == 10.0[m] }
		require constraint { sensingSystem.fieldOfView == 120.0[deg] }
	}
	
	requirement def DetectionPerformanceRequirement {
		doc /* The sensor shall detect human motion within specified range and field of view with adequate response time. */
		
		subject sensor : PassiveInfraredSensingUnit;
		
		require constraint { sensor.detectionRange == 10.0[m] }
		require constraint { sensor.fieldOfView == 120.0[deg] }
		require constraint { sensor.responseTime == 0.2[s] }
		require constraint { sensor.powerConsumption == 0.5[W] }
	}
	
	requirement def OperationalRequirement {
		doc /* The sensor shall operate reliably within specified temperature range and maintain stable performance. */
		
		subject sensor : PassiveInfraredSensingUnit;
		
		require constraint { sensor.operatingTemperature[1] == 243.15[K] }
		require constraint { sensor.operatingTemperature[2] == 343.15[K] }
		require constraint { sensor.regulator.efficiency == 0.85 }
	}
	
	requirement measurementReq : PIRMeasurementRequirement {
		subject sensingSystem = pirSensingUnit;
	}
	
	requirement performanceReq : DetectionPerformanceRequirement {
		subject sensor = pirSensingUnit;
	}
	
	requirement operationalReq : OperationalRequirement {
		subject sensor = pirSensingUnit;
	}
}
