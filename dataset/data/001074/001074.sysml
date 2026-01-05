package GroundPenetratingRadarSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FrequencyRange {
		attribute minFrequency : Real;
		attribute maxFrequency : Real;
		attribute unit : String = "MHz";
	}
	
	attribute def SignalStrength {
		attribute value : Real;
		attribute unit : String = "dBm";
	}
	
	item def EMPulse {
		attribute frequency : Real;
		attribute power : PowerValue;
		attribute duration : TimeValue;
		attribute timestamp : Real;
	}
	
	item def EchoSignal {
		attribute amplitude : SignalStrength;
		attribute travelTime : TimeValue;
		attribute phaseShift : Real;
	}
	
	item def DepthMeasurement {
		attribute depth : LengthValue;
		attribute reflectionCoefficient : Real;
		attribute materialProperty : Real;
	}
	
	item def RadarImage {
		attribute scanWidth : LengthValue;
		attribute maxDepth : LengthValue;
		attribute resolution : LengthValue;
		attribute imageData : Real[*];
	}
	
	item def StartScanCommand;
	item def ErrorCondition;
	item def ResetCommand;
	
	port def TransmitPort {
		out item pulse : EMPulse;
	}
	
	port def ReceivePort {
		in item echo : EchoSignal;
	}
	
	port def ProcessingPort {
		in item rawEcho : EchoSignal;
		out item depthData : DepthMeasurement;
	}
	
	port def DisplayPort {
		in item imageData : RadarImage;
	}
	
	part def PulseGenerator {
		attribute pulseRepetitionRate : Real;
		attribute pulseDuration : TimeValue;
		port output : TransmitPort;
	}
	
	part def TransmitAntenna {
		attribute operatingFrequency : FrequencyRange;
		attribute gain : Real;
		port input : TransmitPort;
	}
	
	part def ReceiveAntenna {
		attribute sensitivity : SignalStrength;
		attribute noiseFloor : SignalStrength;
		port output : ReceivePort;
	}
	
	part def SignalAmplifier {
		attribute gainFactor : Real;
		port input : ReceivePort;
		port output : ReceivePort;
	}
	
	part def DigitalSignalProcessor {
		attribute samplingRate : Real;
		attribute filterBandwidth : Real;
		port signalInput : ReceivePort;
		port dataOutput : ProcessingPort;
	}
	
	part def DepthCalculator {
		attribute propagationVelocity : SpeedValue;
		port input : ProcessingPort;
		port output : ProcessingPort;
	}
	
	part def ImageGenerator {
		attribute scanResolution : LengthValue;
		port depthInput : ProcessingPort;
		port imageOutput : DisplayPort;
	}
	
	part def ControlUnit {
		attribute scanMode : String;
		attribute scanSpeed : Real;
		attribute positionX : LengthValue;
		attribute positionY : LengthValue;
	}
	
	part def DisplayMonitor {
		attribute screenSize : String;
		port dataInput : DisplayPort;
	}
	
	action def GenerateRadarPulse {
		in frequency : Real;
		in power : PowerValue;
		in duration : TimeValue;
		out pulse : EMPulse;
	}
	
	action def TransmitPulse {
		in pulse : EMPulse;
	}
	
	action def ReceiveEcho {
		out echo : EchoSignal;
	}
	
	action def AmplifySignal {
		in rawEcho : EchoSignal;
		in gainFactor : Real;
		out amplifiedEcho : EchoSignal;
	}
	
	action def DigitizeSignal {
		in analogEcho : EchoSignal;
		out digitalEcho : EchoSignal;
	}
	
	action def CalculateDepth {
		in echo : EchoSignal;
		in velocity : SpeedValue;
		out measurement : DepthMeasurement;
	}
	
	action def ProcessDepthData {
		in measurement : DepthMeasurement;
		out processedData : Real[*];
	}
	
	action def CreateRadarImage {
		in depthData : Real[*];
		in scanParameters : Real[*];
		out image : RadarImage;
	}
	
	action def RenderImage {
		in image : RadarImage;
	}
	
	action def PerformSubsurfaceScan {
		first start;
		then action generate : GenerateRadarPulse {
			in frequency;
			in power;
			in duration;
			out emPulse : EMPulse;
		}
		then action transmit : TransmitPulse {
			in pulse = generate.emPulse;
		}
		then action receive : ReceiveEcho {
			out returnEcho : EchoSignal;
		}
		then action amplify : AmplifySignal {
			in rawEcho = receive.returnEcho;
			in gainFactor;
			out boostedEcho : EchoSignal;
		}
		then action digitize : DigitizeSignal {
			in analogEcho = amplify.boostedEcho;
			out digitalData : EchoSignal;
		}
		then action computeDepth : CalculateDepth {
			in echo = digitize.digitalData;
			in velocity;
			out depthResult : DepthMeasurement;
		}
		then action processData : ProcessDepthData {
			in measurement = computeDepth.depthResult;
			out processed : Real[*];
		}
		then action generateImage : CreateRadarImage {
			in depthData = processData.processed;
			in scanParameters;
			out radarImage : RadarImage;
		}
		then action display : RenderImage {
			in image = generateImage.radarImage;
		}
		then done;
	}
	
	state def GPROperationalStates {
		entry; then standby;
		
		state standby {
			doc /* System is powered but not actively scanning */
		}
		
		transition standby_to_initializing
			first standby
			accept StartScanCommand
			then initializing;
		
		state initializing {
			doc /* System calibration and parameter setup */
			entry; then calibrating;
			
			state calibrating;
			transition calibrating_to_ready
				first calibrating
				then ready;
			
			state ready;
		}
		
		transition initializing_to_scanning
			first initializing.ready
			then scanning;
		
		state scanning {
			doc /* Active subsurface scanning operation */
			entry; then transmitting;
			
			state transmitting {
				doc /* Transmitting EM pulse into ground */
			}
			
			transition transmitting_to_receiving
				first transmitting
				then receiving;
			
			state receiving {
				doc /* Receiving reflected signals */
			}
			
			transition receiving_to_processing
				first receiving
				then processing;
			
			state processing {
				doc /* Processing echo data and calculating depth */
			}
			
			transition processing_to_imaging
				first processing
				then imaging;
			
			state imaging {
				doc /* Generating radar image from processed data */
			}
			
			transition imaging_to_transmitting
				first imaging
				then transmitting;
			
			transition imaging_to_complete
				first imaging
				then complete;
			
			state complete;
		}
		
		transition scanning_to_standby
			first scanning.complete
			then standby;
		
		transition any_to_error
			first standby
			accept ErrorCondition
			then error;
		
		state error {
			doc /* System error state requiring intervention */
		}
		
		transition error_to_standby
			first error
			accept ResetCommand
			then standby;
	}
	
	part def GroundPenetratingRadar {
		attribute systemFrequency : FrequencyRange;
		attribute maxScanDepth : LengthValue;
		attribute waveVelocity : SpeedValue;
		attribute verticalResolution : LengthValue;
		
		part pulseGen : PulseGenerator;
		part txAntenna : TransmitAntenna;
		part rxAntenna : ReceiveAntenna;
		part amplifier : SignalAmplifier;
		part dsp : DigitalSignalProcessor;
		part depthCalc : DepthCalculator;
		part imageGen : ImageGenerator;
		part controller : ControlUnit;
		part monitor : DisplayMonitor;
	}
	
	part gprSystem : GroundPenetratingRadar {
		doc /* Complete Ground-Penetrating Radar system for subsurface imaging */
		
		attribute :>> systemFrequency {
			attribute :>> minFrequency = 100.0;
			attribute :>> maxFrequency = 1000.0;
		}
		
		attribute :>> maxScanDepth = 15.0 [m];
		attribute :>> waveVelocity = 0.1 [m/ns];
		attribute :>> verticalResolution = 0.05 [m];
		
		part :>> pulseGen {
			attribute :>> pulseRepetitionRate = 50000.0;
			attribute :>> pulseDuration = 10.0 [ns];
		}
		
		part :>> txAntenna {
			attribute :>> operatingFrequency = gprSystem.systemFrequency;
			attribute :>> gain = 6.0;
		}
		
		part :>> rxAntenna {
			attribute :>> sensitivity.value = -95.0;
			attribute :>> noiseFloor.value = -100.0;
		}
		
		part :>> amplifier {
			attribute :>> gainFactor = 40.0;
		}
		
		part :>> dsp {
			attribute :>> samplingRate = 2000000.0;
			attribute :>> filterBandwidth = 800.0;
		}
		
		part :>> depthCalc {
			attribute :>> propagationVelocity = gprSystem.waveVelocity;
		}
		
		part :>> imageGen {
			attribute :>> scanResolution = gprSystem.verticalResolution;
		}
		
		part :>> controller {
			attribute :>> scanMode = "continuous";
			attribute :>> scanSpeed = 0.3;
			attribute :>> positionX = 0.0 [m];
			attribute :>> positionY = 0.0 [m];
		}
		
		part :>> monitor {
			attribute :>> screenSize = "15 inch";
		}
		
		connect pulseGen.output to txAntenna.input;
		connect rxAntenna.output to amplifier.input;
		connect amplifier.output to dsp.signalInput;
		connect dsp.dataOutput to depthCalc.input;
		connect depthCalc.output to imageGen.depthInput;
		connect imageGen.imageOutput to monitor.dataInput;
		
		perform action subsurfaceScan[*] ordered : PerformSubsurfaceScan {
			in frequency = gprSystem.systemFrequency.minFrequency;
			in power = 5.0 [W];
			in duration = pulseGen.pulseDuration;
			in gainFactor = amplifier.gainFactor;
			in velocity = gprSystem.waveVelocity;
			in scanParameters;
		}
		
		exhibit state systemState : GPROperationalStates;
	}
	
	requirement def <'GPR-REQ-001'> subsurfaceDetectionCapability {
		doc /* The GPR system shall detect and image subsurface objects, 
		        structures, and geological features to a minimum depth of 15 meters 
		        in standard soil conditions with dielectric constant between 4 and 12. */
		
		subject system : GroundPenetratingRadar;
		
		require constraint {
			system.maxScanDepth >= 15.0 [m]
		}
	}
	
	requirement def <'GPR-REQ-002'> verticalResolutionRequirement {
		doc /* The GPR system shall provide vertical resolution of 5 centimeters 
		        or better to distinguish closely spaced subsurface features. */
		
		subject system : GroundPenetratingRadar;
		
		require constraint {
			system.verticalResolution <= 0.05 [m]
		}
	}
	
	requirement def <'GPR-REQ-003'> realTimeImagingRequirement {
		doc /* The GPR system shall process received signals and generate 
		        subsurface images in real-time during scanning operations 
		        with latency not exceeding 100 milliseconds. */
		
		subject system : GroundPenetratingRadar;
	}
	
	requirement def <'GPR-REQ-004'> frequencyRangeRequirement {
		doc /* The GPR system shall operate within the frequency range of 
		        100 MHz to 1000 MHz to balance penetration depth and resolution. */
		
		subject system : GroundPenetratingRadar;
		
		require constraint {
			system.systemFrequency.minFrequency >= 100.0 and
			system.systemFrequency.maxFrequency <= 1000.0
		}
	}
	
	requirement <'GPR-SYS-REQ'> groundPenetratingRadarSystemRequirement {
		doc /* The Ground-Penetrating Radar system shall transmit electromagnetic 
		        pulses into the subsurface, receive and analyze reflected signals, 
		        and generate interpretable two-dimensional images revealing buried 
		        objects, voids, geological layers, and structural features for 
		        applications in archaeology, utility detection, geological surveying, 
		        and infrastructure assessment. */
		
		subject gprSystem;
		
		require subsurfaceDetectionCapability;
		require verticalResolutionRequirement;
		require realTimeImagingRequirement;
		require frequencyRangeRequirement;
	}
}
