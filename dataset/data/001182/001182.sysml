package PhotoelectricSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import ISQBase::*;
	
	attribute def LuminousIntensityValue :> ISQ::LuminousIntensityValue;
	
	attribute def DistanceValue :> ISQ::LengthValue;
	
	attribute def VoltageValue :> ISQ::VoltageValue;
	
	attribute def DetectionStateValue {
		attribute detected : Boolean;
		attribute intensity : Real;
		attribute distance : Real;
	}
	
	item def LightBeam {
		attribute intensity : Real;
		attribute wavelength : Real;
	}
	
	item def Target {
		attribute position : Real;
		attribute reflectivity : Real;
	}
	
	port def OpticalPort {
		out item emittedBeam : LightBeam;
		in item receivedBeam : LightBeam;
	}
	
	port def SignalPort {
		out attribute outputVoltage : Real;
		out attribute detectionState : DetectionStateValue;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : Real;
		in attribute supplyCurrent : Real;
	}
	
	action def EmitLight {
		in power : Real;
		out beam : LightBeam;
	}
	
	action def MeasureIntensity {
		in light : LightBeam;
		out measuredIntensity : Real;
	}
	
	action def ConvertToVoltage {
		in intensity : Real;
		in gain : Real;
		out outputVoltage : Real;
	}
	
	action def EvaluateDetection {
		in intensity : Real;
		in threshold : Real;
		out detectionResult : DetectionStateValue;
	}
	
	action def AmplifySignal {
		in inputVoltage : Real;
		in gain : Real;
		out amplifiedVoltage : Real;
	}
	
	action def CompareThreshold {
		in signal : Real;
		in limit : Real;
		out isDetected : Boolean;
	}
	
	action def GenerateState {
		in detected : Boolean;
		in voltage : Real;
		out state : DetectionStateValue;
	}
	
	part def LightEmitter {
		port opticalOut : OpticalPort;
		port powerIn : PowerPort;
		
		attribute emissionIntensity : Real;
		attribute emissionWavelength : Real;
		
		action emit : EmitLight {
			in power;
			out beam;
		}
	}
	
	part def Photodetector {
		port opticalIn : OpticalPort;
		port signalOut : SignalPort;
		
		attribute sensitivity : Real;
		attribute responseTime : Real;
		attribute detectionThreshold : Real;
		
		action detect {
			in receivedLight : LightBeam;
			out voltage : Real;
			out state : DetectionStateValue;
			
			action measureIntensity : MeasureIntensity {
				in light = receivedLight;
				out measuredIntensity;
			}
			
			then action convertToVoltage : ConvertToVoltage {
				in intensity = measureIntensity.measuredIntensity;
				in gain = sensitivity;
				out outputVoltage;
			}
			
			then action evaluateDetection : EvaluateDetection {
				in intensity = measureIntensity.measuredIntensity;
				in threshold = detectionThreshold;
				out detectionResult;
			}
			
			flow from measureIntensity.measuredIntensity to convertToVoltage.intensity;
			flow from measureIntensity.measuredIntensity to evaluateDetection.intensity;
			flow from convertToVoltage.outputVoltage to detect.voltage;
			flow from evaluateDetection.detectionResult to detect.state;
		}
	}
	
	part def SignalProcessor {
		port signalIn : SignalPort;
		port dataOut : SignalPort;
		
		attribute thresholdVoltage : Real;
		attribute amplificationGain : Real;
		
		action process {
			in rawVoltage : Real;
			in threshold : Real;
			out processedState : DetectionStateValue;
			
			action amplifySignal : AmplifySignal {
				in inputVoltage = rawVoltage;
				in gain = amplificationGain;
				out amplifiedVoltage;
			}
			
			then action compareThreshold : CompareThreshold {
				in signal = amplifySignal.amplifiedVoltage;
				in limit = threshold;
				out isDetected;
			}
			
			then action generateState : GenerateState {
				in detected = compareThreshold.isDetected;
				in voltage = amplifySignal.amplifiedVoltage;
				out state;
			}
			
			flow from amplifySignal.amplifiedVoltage to compareThreshold.signal;
			flow from compareThreshold.isDetected to generateState.detected;
			flow from generateState.state to process.processedState;
		}
	}
	
	part def PhotoelectricSensor {
		port optical : OpticalPort;
		port output : SignalPort;
		port power : PowerPort;
		
		attribute sensingRange : Real;
		attribute detectionThreshold : Real;
		attribute operatingVoltage : Real;
		
		part emitter : LightEmitter[1];
		part detector : Photodetector[1];
		part processor : SignalProcessor[1];
		
		connect power to emitter.powerIn;
		connect emitter.opticalOut to optical;
		connect optical to detector.opticalIn;
		connect detector.signalOut to processor.signalIn;
		connect processor.dataOut to output;
	}
	
	part def SensingUnit {
		port sensorOutput : SignalPort;
		port powerSupply : PowerPort;
		
		attribute maxSensingRange : Real;
		attribute maxResponseTime : Real;
		
		part sensor : PhotoelectricSensor[1];
		
		connect powerSupply to sensor.power;
		connect sensor.output to sensorOutput;
		
		action performSensing {
			in supplyPower : Real;
			out detectionResult : DetectionStateValue;
			
			action initializeSensor {
				in powerLevel : Real;
			}
			
			then fork;
			
			then action emitLight {
				out lightBeam : LightBeam;
			}
			
			then action monitorReflection {
				in reflectedBeam : LightBeam;
				out receivedIntensity : Real;
			}
			
			then joinNode;
			
			join joinNode;
			
			then action processSignal {
				in intensity : Real;
				out detection : DetectionStateValue;
			}
			
			flow from monitorReflection.receivedIntensity to processSignal.intensity;
			flow from processSignal.detection to performSensing.detectionResult;
		}
	}
	
	state def SensorOperationStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_active
			first idle
			accept PowerApplied
			then active;
		
		state active {
			state detecting;
			
			transition detecting_to_objectDetected
				first detecting
				accept SignalAboveThreshold
				then objectDetected;
			
			state objectDetected;
			
			transition objectDetected_to_detecting
				first objectDetected
				accept SignalBelowThreshold
				then detecting;
		}
		
		transition active_to_fault
			first active
			accept SensorFailure
			then fault;
		
		state fault;
		
		transition fault_to_idle
			first fault
			accept Reset
			then idle;
	}
	
	requirement def SensingRequirement {
		doc /* The sensing unit shall measure the presence, intensity, and distance of objects using photoelectric detection. */
		
		require detectionCapability {
			doc /* The sensor shall detect objects within the specified sensing range. */
		}
		
		require responseTimeRequirement {
			doc /* The sensor shall respond to changes in target presence within the specified response time. */
		}
		
		require accuracyRequirement {
			doc /* The sensor shall provide accurate intensity measurements with specified sensitivity. */
		}
		
		require powerRequirement {
			doc /* The sensor shall operate within the specified voltage and current limits. */
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> maxSensingRange = 3.0;
		attribute :>> maxResponseTime = 0.002;
		
		part :>> sensor {
			attribute :>> sensingRange = 3.0;
			attribute :>> detectionThreshold = 2.0;
			attribute :>> operatingVoltage = 24.0;
			
			part :>> emitter {
				attribute :>> emissionIntensity = 150.0;
				attribute :>> emissionWavelength = 850.0;
			}
			
			part :>> detector {
				attribute :>> sensitivity = 0.85;
				attribute :>> responseTime = 0.001;
				attribute :>> detectionThreshold = 50.0;
			}
			
			part :>> processor {
				attribute :>> thresholdVoltage = 2.0;
				attribute :>> amplificationGain = 10.0;
			}
		}
	}
	
	requirement sensingUnitRequirement : SensingRequirement {
		subject sensingUnitInstance;
		
		require :>> detectionCapability {
			assume constraint { sensingUnitInstance.sensor.sensingRange >= 2.0 }
		}
		
		require :>> responseTimeRequirement {
			assume constraint { sensingUnitInstance.sensor.detector.responseTime <= 0.002 }
		}
		
		require :>> accuracyRequirement {
			assume constraint { sensingUnitInstance.sensor.detector.sensitivity >= 0.7 }
		}
		
		require :>> powerRequirement {
			assume constraint { 
				sensingUnitInstance.sensor.operatingVoltage >= 12.0 and 
				sensingUnitInstance.sensor.operatingVoltage <= 30.0 
			}
		}
	}
}
