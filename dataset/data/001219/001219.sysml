package 'Radio Direction Finder System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BearingAngle :> ISQ::AngleValue;
	attribute def RFFrequency :> ISQ::FrequencyValue;
	attribute def SignalStrength :> ISQ::PowerValue;
	attribute def ConfidenceLevel :> Real;
	
	item def RFSignal {
		attribute frequency : RFFrequency;
		attribute strength : SignalStrength;
		attribute polarization : String;
	}
	
	item def AntennaSignal {
		attribute rfSignal : RFSignal;
		attribute phaseAngle : ISQ::AngleValue;
		attribute amplitude : Real;
	}
	
	item def BearingResult {
		attribute bearing : BearingAngle;
		attribute confidence : ConfidenceLevel;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def RFInputPort {
		in item signal : RFSignal;
	}
	
	port def AntennaOutputPort {
		out item antennaSignal : AntennaSignal;
	}
	
	port def ProcessorInputPort {
		in item antennaSignals : AntennaSignal[*];
	}
	
	port def BearingOutputPort {
		out item bearingResult : BearingResult;
	}
	
	port def ControlPort {
		in item targetFrequency : RFFrequency;
		in item scanMode : Integer;
		out item systemStatus : String;
	}
	
	part def AntennaElement {
		attribute elementPosition : ISQ::LengthValue;
		attribute elementOrientation : ISQ::AngleValue;
		port rfInput : RFInputPort;
		port signalOutput : AntennaOutputPort;
	}
	
	part def AntennaArray {
		attribute arrayType : String;
		attribute elementSpacing : ISQ::LengthValue;
		attribute numberOfElements : Integer;
		part elements : AntennaElement[4];
	}
	
	part def RFReceiver {
		attribute tunedFrequency : RFFrequency;
		attribute bandwidth : ISQ::FrequencyValue;
		attribute sensitivity : SignalStrength;
		port rfInput : RFInputPort;
		port controlInput : ControlPort;
		port signalOutput : AntennaOutputPort;
	}
	
	part def SignalProcessor {
		attribute processingAlgorithm : String;
		attribute updateRate : ISQ::FrequencyValue;
		port signalInputs : ProcessorInputPort;
		port bearingOutput : BearingOutputPort;
	}
	
	part def DisplayUnit {
		attribute displayType : String;
		attribute refreshRate : ISQ::FrequencyValue;
		port bearingInput : BearingOutputPort;
		attribute currentBearing : BearingAngle;
	}
	
	part def ControlUnit {
		attribute operatingMode : String;
		port controlOutput : ControlPort;
		port displayInterface;
	}
	
	action def CaptureSignals {
		in targetFreq : RFFrequency;
		out capturedSignals : AntennaSignal[4];
	}
	
	action def CalculatePhaseDelays {
		in signals : AntennaSignal[4];
		out phaseDelays : ISQ::AngleValue[3];
	}
	
	action def DetermineBearing {
		in phaseDelays : ISQ::AngleValue[3];
		in spacing : ISQ::LengthValue;
		in wavelength : ISQ::LengthValue;
		out bearing : BearingAngle;
		out confidence : ConfidenceLevel;
	}
	
	action def ValidateBearing {
		in bearing : BearingAngle;
		in confidence : ConfidenceLevel;
		out isValid : Boolean;
	}
	
	action def DisplayBearing {
		in bearingResult : BearingResult;
	}
	
	action def LocateRFSource {
		in targetFrequency : RFFrequency;
		in arraySpacing : ISQ::LengthValue;
		out finalBearing : BearingResult;
		
		first start;
		then action capture : CaptureSignals {
			in targetFreq = targetFrequency;
			out capturedSignals;
		}
		then action calculatePhases : CalculatePhaseDelays {
			in signals = capture.capturedSignals;
			out phaseDelays;
		}
		then action computeBearing : DetermineBearing {
			in phaseDelays = calculatePhases.phaseDelays;
			in spacing = arraySpacing;
			in wavelength = 3.0e8 [SI::m/SI::s] / targetFrequency;
			out bearing;
			out confidence;
		}
		then action validate : ValidateBearing {
			in bearing = computeBearing.bearing;
			in confidence = computeBearing.confidence;
			out isValid;
		}
		then decide;
			if validate.isValid then presentResult;
			if not validate.isValid then recalibrate;
		action presentResult : DisplayBearing {
			in bearingResult : BearingResult {
				attribute :>> bearing = computeBearing.bearing;
				attribute :>> confidence = computeBearing.confidence;
			}
		}
		then assign finalBearing := presentResult.bearingResult;
		then done;
		action recalibrate;
		then start;
	}
	
	state def SystemOperationalStates {
		attribute systemPowerLevel : Real;
		
		entry; then powerOff;
		
		state powerOff {
			entry assign systemPowerLevel := 0.0;
		}
		
		transition powerOff_to_standby
			first powerOff
			accept powerOnCommand
			then standby;
		
		state standby {
			entry assign systemPowerLevel := 0.3;
			do action selfTest;
		}
		
		transition standby_to_ready
			first standby
			accept systemReady
			then ready;
		
		state ready {
			entry assign systemPowerLevel := 0.8;
		}
		
		transition ready_to_tracking
			first ready
			accept startTracking
			then tracking;
		
		state tracking {
			entry assign systemPowerLevel := 1.0;
			do action continuousTracking : LocateRFSource;
			
			state scanning;
			state processing;
			state displaying;
			
			transition scanning_to_processing
				first scanning
				accept signalsCaptured
				then processing;
			
			transition processing_to_displaying
				first processing
				accept bearingCalculated
				then displaying;
			
			transition displaying_to_scanning
				first displaying
				accept displayComplete
				then scanning;
		}
		
		transition tracking_to_ready
			first tracking
			accept stopTracking
			then ready;
		
		transition ready_to_standby
			first ready
			accept enterStandby
			then standby;
		
		transition standby_to_powerOff
			first standby
			accept powerOffCommand
			then powerOff;
	}
	
	connection def SignalConnection {
		end source;
		end target;
	}
	
	part def RadioDirectionFinderSystem {
		doc /* 
		The Radio Direction Finder System determines the bearing angle to a radio frequency signal source.
		It operates by receiving the same RF signal at multiple antenna elements arranged in a known geometry,
		measuring the phase differences between the signals at each element, and computing the direction of arrival
		based on these phase relationships and the array geometry.
		*/
		
		attribute operatingFrequencyRange : RFFrequency[2];
		attribute bearingAccuracy : BearingAngle;
		attribute maximumRange : ISQ::LengthValue;
		attribute minimumSignalStrength : SignalStrength;
		
		part antennaArray : AntennaArray {
			:>> arrayType = "Circular";
			:>> elementSpacing = 0.5 [SI::m];
			:>> numberOfElements = 4;
		}
		
		part receivers : RFReceiver[4] {
			:>> bandwidth = 10.0e3 [SI::Hz];
			:>> sensitivity = -120.0 [SI::W];
		}
		
		part processor : SignalProcessor {
			:>> processingAlgorithm = "Phase Interferometry";
			:>> updateRate = 10.0 [SI::Hz];
		}
		
		part display : DisplayUnit {
			:>> displayType = "Polar Plot";
			:>> refreshRate = 10.0 [SI::Hz];
		}
		
		part controller : ControlUnit {
			:>> operatingMode = "Automatic";
		}
		
		connection arrayToReceivers : SignalConnection[4]
			connect antennaArray.elements.signalOutput to receivers.signalOutput;
		
		connection receiversToProcessor : SignalConnection
			connect receivers.signalOutput to processor.signalInputs;
		
		connection processorToDisplay : SignalConnection
			connect processor.bearingOutput to display.bearingInput;
		
		connection controlToReceivers : SignalConnection[4]
			connect controller.controlOutput to receivers.controlInput;
		
		perform action locateSource[*] ordered references LocateRFSource {
			in targetFrequency = controller.controlOutput.targetFrequency;
			in arraySpacing = antennaArray.elementSpacing;
			out finalBearing;
		}
		
		exhibit state systemBehavior : SystemOperationalStates;
	}
	
	part radioDirectionFinderSystem : RadioDirectionFinderSystem;
	
	requirement def DirectionFindingRequirements {
		doc /* 
		The Radio Direction Finder System shall locate radio frequency signal sources by determining 
		their bearing angle relative to the system's reference orientation.
		*/
		
		requirement <'RDF-001'> bearingAccuracyRequirement {
			doc /* The system shall determine bearing with an accuracy of +/- 3 degrees RMS. */
			subject radioDirectionFinderSystem;
			require constraint {
				radioDirectionFinderSystem.bearingAccuracy <= 3.0 [SI::deg]
			}
		}
		
		requirement <'RDF-002'> frequencyRangeRequirement {
			doc /* The system shall operate across the HF to UHF frequency range (3 MHz to 3 GHz). */
			subject radioDirectionFinderSystem;
			require constraint {
				radioDirectionFinderSystem.operatingFrequencyRange[1] >= 3.0e6 [SI::Hz] and
				radioDirectionFinderSystem.operatingFrequencyRange[2] <= 3.0e9 [SI::Hz]
			}
		}
		
		requirement <'RDF-003'> updateRateRequirement {
			doc /* The system shall provide bearing updates at a minimum rate of 5 Hz during tracking mode. */
			subject radioDirectionFinderSystem;
			require constraint {
				radioDirectionFinderSystem.processor.updateRate >= 5.0 [SI::Hz]
			}
		}
		
		requirement <'RDF-004'> sensitivityRequirement {
			doc /* The system shall detect and process signals with strength down to -110 dBm. */
			subject radioDirectionFinderSystem;
			require constraint {
				radioDirectionFinderSystem.minimumSignalStrength <= -110.0 [SI::W]
			}
		}
		
		requirement <'RDF-005'> coverageRequirement {
			doc /* The system shall provide 360-degree azimuthal coverage. */
		}
	}
	
	requirement primaryMissionRequirement {
		doc /* 
		The Radio Direction Finder System shall determine the bearing angle to radio frequency signal sources
		by measuring phase differences across a spatially distributed antenna array and computing the direction
		of arrival using interferometric techniques.
		*/
		
		assume constraint validSignalAssumption {
			doc /* A radio frequency signal of detectable strength is present within the operational frequency range. */
		}
		
		assume constraint arrayCalibrationAssumption {
			doc /* The antenna array geometry is accurately known and calibrated. */
		}
		
		require DirectionFindingRequirements;
	}
}
