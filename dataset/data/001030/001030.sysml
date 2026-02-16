package 'Doppler Radar System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CarrierFrequency :> ISQ::FrequencyValue;
	attribute def DopplerFrequency :> ISQ::FrequencyValue;
	attribute def RadialVelocity :> ISQ::SpeedValue;
	attribute def TargetRange :> ISQ::LengthValue;
	attribute def SignalPower :> ISQ::PowerValue;
	attribute def TimeDelay :> ISQ::TimeValue;
	attribute def PhaseShift :> ISQ::DimensionOneValue;
	
	enum def ScanMode {
		continuous;
		pulsed;
		tracking;
	}
	
	item def TransmittedSignal {
		attribute frequency : CarrierFrequency;
		attribute power : SignalPower;
		attribute transmitTime : ISQ::TimeValue;
		attribute phase : PhaseShift;
	}
	
	item def ReceivedEcho {
		attribute frequency : CarrierFrequency;
		attribute dopplerShift : DopplerFrequency;
		attribute power : SignalPower;
		attribute receiveTime : ISQ::TimeValue;
		attribute phase : PhaseShift;
	}
	
	item def TargetInformation {
		attribute velocity : RadialVelocity;
		attribute range : TargetRange;
		attribute signalStrength : SignalPower;
		attribute detectionConfidence : Real;
	}
	
	item def SystemCommand {
		attribute scanMode : ScanMode;
		attribute powerLevel : SignalPower;
	}
	
	port def RFTransmitPort {
		out txSignal : TransmittedSignal;
	}
	
	port def RFReceivePort {
		in echoSignal : ReceivedEcho;
	}
	
	port def SignalProcessingPort {
		in txReference : TransmittedSignal;
		in rxEcho : ReceivedEcho;
		out targetData : TargetInformation;
	}
	
	port def ControlPort {
		in command : SystemCommand;
	}
	
	port def DataOutputPort {
		out targetInfo : TargetInformation;
	}
	
	part def RFTransmitter {
		port txPort : RFTransmitPort;
		port controlIn : ControlPort;
		
		attribute operatingFrequency : CarrierFrequency;
		attribute outputPower : SignalPower;
		attribute pulseWidth : ISQ::TimeValue;
		
		action generateCarrierSignal {
			in frequency : CarrierFrequency;
			in power : SignalPower;
			out signal : TransmittedSignal;
		}
	}
	
	part def RFReceiver {
		port rxPort : RFReceivePort;
		
		attribute sensitivity : SignalPower;
		attribute noiseFloor : SignalPower;
		attribute bandwidth : ISQ::FrequencyValue;
		
		action amplifySignal {
			in echo : ReceivedEcho;
			out amplifiedEcho : ReceivedEcho;
		}
		
		action filterSignal {
			in rawEcho : ReceivedEcho;
			out filteredEcho : ReceivedEcho;
		}
	}
	
	part def DopplerProcessor {
		port processingPort : SignalProcessingPort;
		
		attribute speedOfLight : ISQ::SpeedValue;
		
		action computeDopplerShift {
			in transmittedFreq : CarrierFrequency;
			in receivedFreq : CarrierFrequency;
			out dopplerFreq : DopplerFrequency;
		}
		
		action calculateVelocity {
			in dopplerShift : DopplerFrequency;
			in carrierFreq : CarrierFrequency;
			in lightSpeed : ISQ::SpeedValue;
			out velocity : RadialVelocity;
		}
		
		action measureRange {
			in txTime : ISQ::TimeValue;
			in rxTime : ISQ::TimeValue;
			in lightSpeed : ISQ::SpeedValue;
			out range : TargetRange;
		}
		
		action assessTargetQuality {
			in signalPower : SignalPower;
			in noiseLevel : SignalPower;
			out confidence : Real;
		}
	}
	
	part def AntennaAssembly {
		attribute gain : Real;
		attribute beamWidth : ISQ::DimensionOneValue;
		attribute polarization : String;
		
		action transmitWave {
			in signal : TransmittedSignal;
		}
		
		action receiveReflection {
			out echo : ReceivedEcho;
		}
	}
	
	part def DisplayUnit {
		port dataIn : DataOutputPort;
		
		action renderTargetData {
			in targetInfo : TargetInformation;
		}
		
		action updateDisplay {
			in velocity : RadialVelocity;
			in range : TargetRange;
		}
	}
	
	part def SystemController {
		port commandOut : ControlPort;
		
		attribute operatingMode : ScanMode;
		
		action issueCommand {
			out cmd : SystemCommand;
		}
		
		action monitorStatus;
	}
	
	requirement def <'REQ-DRS-001'> PrimaryFunctionRequirement {
		doc /* The Doppler radar system shall measure the radial velocity and range 
		       of moving targets by detecting frequency shifts in reflected electromagnetic waves. */
	}
	
	requirement def <'REQ-DRS-002'> VelocityMeasurementRequirement {
		doc /* The system shall measure target radial velocities from 5 m/s to 500 m/s 
		       with an accuracy of ±1 m/s. */
		
		require constraint velocityRange {
			doc /* Measurable velocity range: 5 to 500 m/s */
		}
		
		require constraint velocityAccuracy {
			doc /* Velocity measurement accuracy: ±1 m/s */
		}
	}
	
	requirement def <'REQ-DRS-003'> RangeMeasurementRequirement {
		doc /* The system shall measure target range from 100 meters to 10 kilometers 
		       with an accuracy of ±5 meters. */
		
		require constraint rangeExtent {
			doc /* Detection range: 100 m to 10 km */
		}
		
		require constraint rangeAccuracy {
			doc /* Range measurement accuracy: ±5 m */
		}
	}
	
	requirement def <'REQ-DRS-004'> UpdateRateRequirement {
		doc /* The system shall update target measurements at a minimum rate of 20 Hz 
		       to support continuous tracking. */
	}
	
	requirement def <'REQ-DRS-005'> OperationalRequirement {
		doc /* The system shall operate continuously in specified environmental conditions 
		       and maintain measurement accuracy. */
	}
	
	action def MeasureTargetVelocityAndRange {
		in carrierFrequency : CarrierFrequency;
		in transmitPower : SignalPower;
		in lightSpeed : ISQ::SpeedValue;
		out targetData : TargetInformation;
		
		first start;
		then merge continuousScan;
		
		then action transmitPulse {
			in frequency : CarrierFrequency = carrierFrequency;
			in power : SignalPower = transmitPower;
			out txSignal : TransmittedSignal;
		}
		
		then action propagateAndReflect {
			in outgoingSignal : TransmittedSignal = transmitPulse.txSignal;
			out returnEcho : ReceivedEcho;
		}
		
		then action receiveEcho {
			in incomingEcho : ReceivedEcho = propagateAndReflect.returnEcho;
			out processedEcho : ReceivedEcho;
		}
		
		then action analyzeSignals {
			in txReference : TransmittedSignal = transmitPulse.txSignal;
			in rxEcho : ReceivedEcho = receiveEcho.processedEcho;
			out analysis : TargetInformation;
			
			action extractDoppler {
				in txFreq : CarrierFrequency = txReference.frequency;
				in rxFreq : CarrierFrequency = rxEcho.frequency;
				out doppler : DopplerFrequency;
			}
			
			then action computeVelocity {
				in dopplerShift : DopplerFrequency = extractDoppler.doppler;
				in carrier : CarrierFrequency = carrierFrequency;
				in c : ISQ::SpeedValue = lightSpeed;
				out radialVelocity : RadialVelocity;
			}
			
			then action computeRange {
				in txTime : ISQ::TimeValue = txReference.transmitTime;
				in rxTime : ISQ::TimeValue = rxEcho.receiveTime;
				in c : ISQ::SpeedValue = lightSpeed;
				out distance : TargetRange;
			}
			
			then action assembleTargetData {
				in velocity : RadialVelocity = computeVelocity.radialVelocity;
				in range : TargetRange = computeRange.distance;
				in strength : SignalPower = rxEcho.power;
				out data : TargetInformation;
			}
		}
		
		then decide;
			if analyzeSignals.analysis.detectionConfidence > 0.7 then displayTarget;
			if analyzeSignals.analysis.detectionConfidence <= 0.7 then continuousScan;
		
		action displayTarget {
			in data : TargetInformation = analyzeSignals.analysis;
		}
		
		then continuousScan;
	}
	
	part def DopplerRadarSystem {
		part transmitter : RFTransmitter {
			attribute :>> operatingFrequency = 10.0 [SI::GHz];
			attribute :>> outputPower = 1.0 [SI::W];
			attribute :>> pulseWidth = 1.0e-6 [SI::s];
		}
		
		part receiver : RFReceiver {
			attribute :>> sensitivity = 1.0e-13 [SI::W];
			attribute :>> noiseFloor = 1.0e-14 [SI::W];
			attribute :>> bandwidth = 100.0 [SI::MHz];
		}
		
		part processor : DopplerProcessor {
			attribute :>> speedOfLight = 299792458.0 [SI::m/SI::s];
		}
		
		part antenna : AntennaAssembly {
			attribute :>> gain = 25.0;
			attribute :>> beamWidth = 10.0;
			attribute :>> polarization = "vertical";
		}
		
		part display : DisplayUnit;
		
		part controller : SystemController {
			attribute :>> operatingMode = ScanMode::continuous;
		}
		
		connection txToAntenna connect transmitter.txPort to antenna;
		connection antennaToRx connect antenna to receiver.rxPort;
		connection txToProcessor connect transmitter.txPort to processor.processingPort;
		connection rxToProcessor connect receiver.rxPort to processor.processingPort;
		connection processorToDisplay connect processor.processingPort to display.dataIn;
		connection controlToTx connect controller.commandOut to transmitter.controlIn;
		
		perform action measureTargets : MeasureTargetVelocityAndRange {
			in carrierFrequency = transmitter.operatingFrequency;
			in transmitPower = transmitter.outputPower;
			in lightSpeed = processor.speedOfLight;
			out targetData;
		}
	}
	
	part dopplerRadar : DopplerRadarSystem {
		satisfy primaryFunction;
		satisfy velocityMeasurement;
		satisfy rangeMeasurement;
		satisfy updateRate;
		satisfy operational;
		
		perform measureTargets.transmitPulse by transmitter;
		perform measureTargets.receiveEcho by receiver;
		perform measureTargets.analyzeSignals by processor;
		perform measureTargets.displayTarget by display;
	}
	
	requirement primaryFunction : PrimaryFunctionRequirement {
		subject dopplerRadar;
	}
	
	requirement velocityMeasurement : VelocityMeasurementRequirement {
		subject dopplerRadar;
	}
	
	requirement rangeMeasurement : RangeMeasurementRequirement {
		subject dopplerRadar;
	}
	
	requirement updateRate : UpdateRateRequirement {
		subject dopplerRadar;
	}
	
	requirement operational : OperationalRequirement {
		subject dopplerRadar;
	}
}
