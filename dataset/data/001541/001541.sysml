package 'RadioFrequencySystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def TimeValue :> ISQ::TimeValue;
	
	enum def ModulationType {
		AM;
		FM;
		PM;
		QAM;
		OFDM;
	}
	
	enum def OperatingMode {
		idle;
		transmit;
		receive;
		calibration;
		fault;
	}
	
	item def RFSignal {
		attribute carrierFrequency : FrequencyValue;
		attribute signalPower : PowerValue;
		attribute bandwidth : FrequencyValue;
		attribute modulation : ModulationType;
		attribute signalToNoiseRatio : Real;
	}
	
	item def BasebandSignal {
		attribute dataRate : Real;
		attribute amplitude : Real;
	}
	
	item def ControlCommand {
		attribute targetFrequency : FrequencyValue;
		attribute targetPower : PowerValue;
		attribute mode : OperatingMode;
	}
	
	port def RFPort {
		in item rfInput : RFSignal[0..1];
		out item rfOutput : RFSignal[0..1];
	}
	
	port def BasebandPort {
		in item bbInput : BasebandSignal[0..1];
		out item bbOutput : BasebandSignal[0..1];
	}
	
	port def ControlPort {
		in item command : ControlCommand[0..1];
		out attribute status : OperatingMode;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : Real;
		in attribute supplyCurrent : Real;
	}
	
	part def Antenna {
		port rfPort : RFPort;
		attribute resonantFrequency : FrequencyValue;
		attribute gain : Real;
		attribute vswr : Real;
		attribute efficiency : Real;
	}
	
	part def RFAmplifier {
		port rfIn : RFPort;
		port rfOut : RFPort;
		port power : PowerPort;
		attribute gainFactor : Real;
		attribute maxOutputPower : PowerValue;
		attribute linearityFactor : Real;
	}
	
	part def Mixer {
		port rfIn : RFPort;
		port localOscillator : RFPort;
		port intermediateFrequency : RFPort;
		attribute conversionGain : Real;
		attribute isolationFactor : Real;
	}
	
	part def LocalOscillator {
		port rfOut : RFPort;
		port control : ControlPort;
		attribute outputFrequency : FrequencyValue;
		attribute phaseNoise : Real;
		attribute frequencyStability : Real;
	}
	
	part def BandpassFilter {
		port rfIn : RFPort;
		port rfOut : RFPort;
		attribute centerFrequency : FrequencyValue;
		attribute passbandWidth : FrequencyValue;
		attribute insertionLoss : Real;
		attribute rejectionRatio : Real;
	}
	
	part def Modulator {
		port bbIn : BasebandPort;
		port rfOut : RFPort;
		port control : ControlPort;
		attribute modulationType : ModulationType;
		attribute symbolRate : Real;
	}
	
	part def Demodulator {
		port rfIn : RFPort;
		port bbOut : BasebandPort;
		attribute demodulationType : ModulationType;
		attribute errorVectorMagnitude : Real;
	}
	
	part def SystemController {
		port controlOut : ControlPort[*];
		port statusIn : ControlPort[*];
		attribute currentMode : OperatingMode;
		attribute targetFrequency : FrequencyValue;
		attribute targetPower : PowerValue;
	}
	
	action def ModulateSignal {
		in attribute basebandInput : BasebandSignal;
		in attribute carrierFreq : FrequencyValue;
		in attribute modType : ModulationType;
		out attribute rfOutput : RFSignal;
	}
	
	action def DemodulateSignal {
		in attribute rfInput : RFSignal;
		in attribute localOscFreq : FrequencyValue;
		out attribute basebandOutput : BasebandSignal;
	}
	
	action def AmplifySignal {
		in attribute inputSignal : RFSignal;
		in attribute gainValue : Real;
		out attribute amplifiedSignal : RFSignal;
	}
	
	action def FilterSignal {
		in attribute inputSignal : RFSignal;
		in attribute centerFreq : FrequencyValue;
		in attribute bandwidth : FrequencyValue;
		out attribute filteredSignal : RFSignal;
	}
	
	action def TransmitRFSignal {
		in attribute basebandData : BasebandSignal;
		in attribute transmitFreq : FrequencyValue;
		in attribute transmitPower : PowerValue;
		out attribute transmittedSignal : RFSignal;
		
		first start;
		then action modulate : ModulateSignal {
			in attribute :>> basebandInput = basebandData;
			in attribute :>> carrierFreq = transmitFreq;
			in attribute :>> modType = ModulationType::QAM;
		}
		then action amplifyStep : AmplifySignal {
			in attribute :>> inputSignal = modulate.rfOutput;
			in attribute :>> gainValue = 20.0;
		}
		then action filterStep : FilterSignal {
			in attribute :>> inputSignal = amplifyStep.amplifiedSignal;
			in attribute :>> centerFreq = transmitFreq;
			in attribute :>> bandwidth = 20.0e6[SI::Hz];
		}
		then assign transmittedSignal := filterStep.filteredSignal;
		then done;
	}
	
	action def ReceiveRFSignal {
		in attribute receivedSignal : RFSignal;
		in attribute tuningFreq : FrequencyValue;
		out attribute basebandData : BasebandSignal;
		
		first start;
		then action filterReceived : FilterSignal {
			in attribute :>> inputSignal = receivedSignal;
			in attribute :>> centerFreq = tuningFreq;
			in attribute :>> bandwidth = 20.0e6[SI::Hz];
		}
		then action amplifyReceived : AmplifySignal {
			in attribute :>> inputSignal = filterReceived.filteredSignal;
			in attribute :>> gainValue = 15.0;
		}
		then action demodulate : DemodulateSignal {
			in attribute :>> rfInput = amplifyReceived.amplifiedSignal;
			in attribute :>> localOscFreq = tuningFreq;
		}
		then assign basebandData := demodulate.basebandOutput;
		then done;
	}
	
	state def RFSystemStateMachine {
		entry; then idle;
		
		state idle {
			entry assign controller.currentMode := OperatingMode::idle;
		}
		
		accept powerOn;
		accept transmitCommand;
		accept receiveCommand;
		accept calibrateCommand;
		accept faultDetected;
		accept resetCommand;
		
		transition idle_to_transmit
			first idle
			accept transmitCommand
			then transmitting;
		
		state transmitting {
			entry assign controller.currentMode := OperatingMode::transmit;
			do action transmit : TransmitRFSignal;
		}
		
		transition transmit_to_idle
			first transmitting
			accept powerOn
			then idle;
		
		transition idle_to_receive
			first idle
			accept receiveCommand
			then receiving;
		
		state receiving {
			entry assign controller.currentMode := OperatingMode::receive;
			do action receive : ReceiveRFSignal;
		}
		
		transition receive_to_idle
			first receiving
			accept powerOn
			then idle;
		
		transition idle_to_calibration
			first idle
			accept calibrateCommand
			then calibration;
		
		state calibration {
			entry assign controller.currentMode := OperatingMode::calibration;
		}
		
		transition calibration_to_idle
			first calibration
			accept powerOn
			then idle;
		
		transition any_to_fault
			first idle
			accept faultDetected
			then fault;
		
		transition transmit_to_fault
			first transmitting
			accept faultDetected
			then fault;
		
		transition receive_to_fault
			first receiving
			accept faultDetected
			then fault;
		
		state fault {
			entry assign controller.currentMode := OperatingMode::fault;
		}
		
		transition fault_to_idle
			first fault
			accept resetCommand
			then idle;
	}
	
	part def RFTransceiver {
		attribute operatingFrequency : FrequencyValue;
		attribute operatingBandwidth : FrequencyValue;
		attribute maxTransmitPower : PowerValue;
		attribute receiverSensitivity : PowerValue;
		attribute channelSpacing : FrequencyValue;
		
		part antenna : Antenna {
			attribute :>> resonantFrequency = operatingFrequency;
			attribute :>> gain = 3.0;
			attribute :>> vswr = 1.5;
			attribute :>> efficiency = 0.85;
		}
		
		part txAmplifier : RFAmplifier {
			attribute :>> gainFactor = 25.0;
			attribute :>> maxOutputPower = maxTransmitPower;
			attribute :>> linearityFactor = 0.95;
		}
		
		part rxAmplifier : RFAmplifier {
			attribute :>> gainFactor = 18.0;
			attribute :>> maxOutputPower = 0.1[SI::W];
			attribute :>> linearityFactor = 0.98;
		}
		
		part txMixer : Mixer {
			attribute :>> conversionGain = 7.0;
			attribute :>> isolationFactor = 30.0;
		}
		
		part rxMixer : Mixer {
			attribute :>> conversionGain = 6.5;
			attribute :>> isolationFactor = 35.0;
		}
		
		part localOsc : LocalOscillator {
			attribute :>> outputFrequency = operatingFrequency;
			attribute :>> phaseNoise = -110.0;
			attribute :>> frequencyStability = 0.0001;
		}
		
		part txFilter : BandpassFilter {
			attribute :>> centerFrequency = operatingFrequency;
			attribute :>> passbandWidth = operatingBandwidth;
			attribute :>> insertionLoss = 1.5;
			attribute :>> rejectionRatio = 45.0;
		}
		
		part rxFilter : BandpassFilter {
			attribute :>> centerFrequency = operatingFrequency;
			attribute :>> passbandWidth = operatingBandwidth;
			attribute :>> insertionLoss = 1.2;
			attribute :>> rejectionRatio = 50.0;
		}
		
		part modulator : Modulator {
			attribute :>> modulationType = ModulationType::QAM;
			attribute :>> symbolRate = 1.0e6;
		}
		
		part demodulator : Demodulator {
			attribute :>> demodulationType = ModulationType::QAM;
			attribute :>> errorVectorMagnitude = 0.05;
		}
		
		part controller : SystemController {
			attribute :>> currentMode = OperatingMode::idle;
			attribute :>> targetFrequency = operatingFrequency;
			attribute :>> targetPower = maxTransmitPower;
		}
		
		port antennaPort : RFPort;
		port txBasebandPort : BasebandPort;
		port rxBasebandPort : BasebandPort;
		port systemControl : ControlPort;
		port mainPower : PowerPort;
		
		connection txModToMixer connect modulator.rfOut to txMixer.rfIn;
		connection txOscToMixer connect localOsc.rfOut to txMixer.localOscillator;
		connection txMixerToFilter connect txMixer.intermediateFrequency to txFilter.rfIn;
		connection txFilterToAmp connect txFilter.rfOut to txAmplifier.rfIn;
		connection txAmpToAntenna connect txAmplifier.rfOut to antenna.rfPort;
		
		connection rxAntennaToFilter connect antenna.rfPort to rxFilter.rfIn;
		connection rxFilterToAmp connect rxFilter.rfOut to rxAmplifier.rfIn;
		connection rxAmpToMixer connect rxAmplifier.rfOut to rxMixer.rfIn;
		connection rxOscToMixer connect localOsc.rfOut to rxMixer.localOscillator;
		connection rxMixerToDemod connect rxMixer.intermediateFrequency to demodulator.rfIn;
		
		connection controlToOsc connect controller.controlOut to localOsc.control;
		connection controlToMod connect controller.controlOut to modulator.control;
		
		perform action operateTransceiver {
			first start;
			then merge modeCheck;
			
			action modeCheck;
			then decide;
				if controller.currentMode == OperatingMode::transmit then transmitMode;
				if controller.currentMode == OperatingMode::receive then receiveMode;
				if controller.currentMode == OperatingMode::idle then idleMode;
				if controller.currentMode == OperatingMode::calibration then calibrationMode;
			
			action transmitMode : TransmitRFSignal {
				in attribute :>> transmitFreq = controller.targetFrequency;
				in attribute :>> transmitPower = controller.targetPower;
			}
			then modeCheck;
			
			action receiveMode : ReceiveRFSignal {
				in attribute :>> tuningFreq = controller.targetFrequency;
			}
			then modeCheck;
			
			action idleMode;
			then modeCheck;
			
			action calibrationMode;
			then modeCheck;
		}
		
		exhibit state systemBehavior : RFSystemStateMachine;
	}
	
	part rfSystem : RFTransceiver {
		attribute :>> operatingFrequency = 2.4e9[SI::Hz];
		attribute :>> operatingBandwidth = 20.0e6[SI::Hz];
		attribute :>> maxTransmitPower = 2.0[SI::W];
		attribute :>> receiverSensitivity = 1.0e-10[SI::W];
		attribute :>> channelSpacing = 5.0e6[SI::Hz];
	}
	
	requirement def RFSystemRequirement {
		doc /* The RF system shall transmit and receive electromagnetic signals by converting 
		       baseband information signals to radio frequency carriers for wireless propagation 
		       and converting received RF signals back to baseband information. */
	}
	
	requirement def FrequencyStabilityRequirement {
		subject transceiver : RFTransceiver;
		doc /* The local oscillator frequency stability shall be better than 0.01% to ensure 
		       reliable signal transmission and reception. */
		require constraint {
			transceiver.localOsc.frequencyStability <= 0.0001
		}
	}
	
	requirement def TransmitPowerRequirement {
		subject transceiver : RFTransceiver;
		doc /* The transmit amplifier shall deliver the specified maximum output power 
		       with sufficient linearity. */
		require constraint {
			transceiver.txAmplifier.maxOutputPower >= transceiver.maxTransmitPower and
			transceiver.txAmplifier.linearityFactor >= 0.90
		}
	}
	
	requirement def ReceiverSensitivityRequirement {
		subject transceiver : RFTransceiver;
		doc /* The receiver shall detect signals at or above the specified sensitivity level 
		       with acceptable error vector magnitude. */
		require constraint {
			transceiver.receiverSensitivity <= 1.0e-9[SI::W] and
			transceiver.demodulator.errorVectorMagnitude <= 0.08
		}
	}
	
	requirement def AntennaPerformanceRequirement {
		subject transceiver : RFTransceiver;
		doc /* The antenna shall operate at the specified resonant frequency with acceptable 
		       gain, VSWR, and efficiency. */
		require constraint {
			transceiver.antenna.resonantFrequency == transceiver.operatingFrequency and
			transceiver.antenna.gain >= 2.0 and
			transceiver.antenna.vswr <= 2.0 and
			transceiver.antenna.efficiency >= 0.80
		}
	}
	
	requirement <'RF-SYS-001'> primaryFunction : RFSystemRequirement {
		doc /* The RF transceiver system shall enable wireless communication by modulating 
		       baseband signals onto radio frequency carriers for transmission through free 
		       space and demodulating received RF signals back to baseband information. 
		       The system operates at 2.4 GHz with 20 MHz bandwidth, supporting QAM modulation 
		       with up to 2W transmit power and -100 dBm receiver sensitivity. */
		
		assume constraint operatingConditions {
			doc /* The system operates within the ISM band with specified frequency and power limits. */
			rfSystem.operatingFrequency >= 2.4e9[SI::Hz] and
			rfSystem.operatingFrequency <= 2.5e9[SI::Hz] and
			rfSystem.maxTransmitPower <= 4.0[SI::W]
		}
		
		satisfy FrequencyStabilityRequirement by rfSystem;
		satisfy TransmitPowerRequirement by rfSystem;
		satisfy ReceiverSensitivityRequirement by rfSystem;
		satisfy AntennaPerformanceRequirement by rfSystem;
	}
}
