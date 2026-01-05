package 'Visible Light Photon Counter System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PhotonCount :> Integer;
	attribute def Wavelength :> LengthValue;
	attribute def PhotonEnergy :> EnergyValue;
	attribute def QuantumEfficiency :> Real;
	attribute def DetectorBias :> ElectricPotentialValue;
	attribute def CountRate :> FrequencyValue;
	attribute def DarkCountRate :> FrequencyValue;
	attribute def IntegrationPeriod :> TimeValue;
	attribute def SignalAmplitude :> ElectricPotentialValue;
	attribute def TemperatureSetpoint :> ThermodynamicTemperatureValue;
	
	attribute def VisibleSpectrum {
		attribute lowerBound : Wavelength = 380.0 [nm];
		attribute upperBound : Wavelength = 750.0 [nm];
	}
	
	item def Photon {
		attribute wavelength : Wavelength;
		attribute energy : PhotonEnergy;
	}
	
	item def DetectionPulse {
		attribute amplitude : SignalAmplitude;
		attribute timestamp : TimeValue;
	}
	
	item def CountData {
		attribute totalCount : PhotonCount;
		attribute rate : CountRate;
		attribute integrationTime : IntegrationPeriod;
	}
	
	port def OpticalPort {
		in item photonStream : Photon[*];
	}
	
	port def SignalPort {
		out item pulseStream : DetectionPulse[*];
	}
	
	port def DataPort {
		out item countData : CountData;
	}
	
	port def ControlPort {
		in attribute startCommand : Boolean;
		in attribute stopCommand : Boolean;
		in attribute resetCommand : Boolean;
		out attribute systemReady : Boolean;
	}
	
	port def PowerPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def CoolingPort {
		in attribute targetTemp : TemperatureSetpoint;
		out attribute actualTemp : ThermodynamicTemperatureValue;
	}
	
	part def PhotonDetectorModule {
		doc /* Silicon avalanche photodiode operating in Geiger mode for single-photon detection */
		
		port opticalInput : OpticalPort;
		port signalOutput : SignalPort;
		port biasSupply : PowerPort;
		port cooling : CoolingPort;
		
		attribute quantumEff : QuantumEfficiency = 0.45;
		attribute activeArea : AreaValue = 0.5 [mm^2];
		attribute spectralRange : VisibleSpectrum;
		attribute operatingBias : DetectorBias = 250.0 [V];
		attribute darkCount : DarkCountRate = 50.0 [Hz];
		
		perform action detectPhoton {
			in photon : Photon;
			out pulse : DetectionPulse;
		}
	}
	
	part def SignalConditioner {
		doc /* Amplifies and shapes detector pulses for digital processing */
		
		port pulseInput : SignalPort;
		port pulseOutput : SignalPort;
		port power : PowerPort;
		
		attribute gain : Real = 100.0;
		attribute bandwidth : FrequencyValue = 100.0 [MHz];
		attribute noiseFloor : SignalAmplitude = 5.0 [mV];
		
		perform action conditionSignal {
			in rawPulse : DetectionPulse;
			out conditionedPulse : DetectionPulse;
		}
	}
	
	part def PulseDiscriminator {
		doc /* Filters noise and validates genuine photon detection events */
		
		port pulseInput : SignalPort;
		port pulseOutput : SignalPort;
		port power : PowerPort;
		
		attribute threshold : SignalAmplitude = 50.0 [mV];
		attribute deadTime : TimeValue = 50.0 [ns];
		
		perform action discriminatePulse {
			in inputPulse : DetectionPulse;
			out validPulse : DetectionPulse;
		}
	}
	
	part def CountingLogic {
		doc /* Accumulates validated photon events over specified integration periods */
		
		port pulseInput : SignalPort;
		port dataOutput : DataPort;
		port control : ControlPort;
		port power : PowerPort;
		
		attribute currentCount : PhotonCount := 0;
		attribute integrationWindow : IntegrationPeriod = 1.0 [s];
		attribute maxCountRate : CountRate = 10.0 [MHz];
		
		perform action countPhotons : CountPhotonEvents;
	}
	
	part def ThermalController {
		doc /* Maintains detector at optimal operating temperature to minimize dark counts */
		
		port cooling : CoolingPort;
		port power : PowerPort;
		
		attribute setpoint : TemperatureSetpoint = 253.15 [K];
		attribute coolingCapacity : PowerValue = 5.0 [W];
		attribute stabilityTolerance : ThermodynamicTemperatureValue = 0.1 [K];
		
		perform action regulateTemperature {
			in targetTemp : TemperatureSetpoint;
			out coolingPower : PowerValue;
		}
	}
	
	part def CalibrationModule {
		doc /* Performs dark count measurement and efficiency calibration */
		
		port dataInput : DataPort;
		port control : ControlPort;
		
		attribute darkCountBaseline : DarkCountRate;
		attribute efficiencyCalibration : QuantumEfficiency[*];
		
		perform action calibrateSystem {
			in measuredDarkCount : DarkCountRate;
			out correctionFactor : Real;
		}
	}
	
	part def DataInterface {
		doc /* Provides external communication and data export capabilities */
		
		port dataInput : DataPort;
		port control : ControlPort;
		
		attribute outputFormat : String;
		attribute dataRate : FrequencyValue = 1000.0 [Hz];
		
		perform action transmitData {
			in countData : CountData;
			out formattedOutput : String;
		}
	}
	
	action def CountPhotonEvents {
		in pulseStream : DetectionPulse[*];
		in integrationTime : IntegrationPeriod;
		in startCmd : Boolean;
		in stopCmd : Boolean;
		in resetCmd : Boolean;
		out totalCount : PhotonCount := 0;
		out instantRate : CountRate;
		
		first start;
		then merge waitForStart;
		
		action waitForStart {
			accept startCmd;
		}
		then assign totalCount := 0;
		then merge counting;
		
		loop {
			action counting {
				for pulse in pulseStream {
					then assign totalCount := totalCount + 1;
				}
			}
			then decide;
				if stopCmd then finalize;
				if resetCmd then waitForStart;
				else counting;
		}
		
		action finalize {
			assign instantRate := totalCount / integrationTime;
		}
		then done;
	}
	
	action def InitializeSystem {
		in biasVoltage : DetectorBias;
		in coolingTarget : TemperatureSetpoint;
		out systemReady : Boolean;
		
		first start;
		then action applyBias {
			in voltage = biasVoltage;
		}
		then action coolDown {
			in target = coolingTarget;
			out currentTemp : ThermodynamicTemperatureValue;
		}
		then decide;
			if coolDown.currentTemp <= coolingTarget + 0.5 [K] then ready;
			else coolDown;
		
		action ready {
			assign systemReady := true;
		}
		then done;
	}
	
	action def MeasureDarkCount {
		in integrationTime : IntegrationPeriod;
		out darkCount : PhotonCount;
		out darkRate : DarkCountRate;
		
		first start;
		then action blockOpticalInput;
		then action acquireDarkCounts {
			in duration = integrationTime;
			out counts : PhotonCount;
		}
		then assign darkCount := acquireDarkCounts.counts;
		then assign darkRate := darkCount / integrationTime;
		then done;
	}
	
	action def AcquirePhotonData {
		in integrationTime : IntegrationPeriod;
		in wavelengthFilter : Wavelength;
		out rawCount : PhotonCount;
		out correctedCount : PhotonCount;
		out countRate : CountRate;
		
		first start;
		then action measureDark : MeasureDarkCount {
			in integrationTime = integrationTime;
			out darkCount;
			out darkRate;
		}
		then action measureSignal {
			in duration = integrationTime;
			out signalCount : PhotonCount;
		}
		then assign rawCount := measureSignal.signalCount;
		then assign correctedCount := rawCount - measureDark.darkCount;
		then assign countRate := correctedCount / integrationTime;
		then done;
	}
	
	part def VisibleLightPhotonCounterSystem {
		doc /* 
			A high-sensitivity visible light photon counter system designed to detect 
			and quantify individual photons in the 380-750 nm wavelength range. 
			The system employs avalanche photodiode technology operating in Geiger mode 
			for single-photon sensitivity, coupled with precision signal conditioning, 
			pulse discrimination, and counting electronics. Thermoelectric cooling 
			minimizes dark counts while calibration routines ensure measurement accuracy. 
			Primary applications include quantum optics experiments, fluorescence 
			spectroscopy, bioluminescence detection, and ultra-low-light imaging.
		*/
		
		port opticalInterface : OpticalPort;
		port dataInterface : DataPort;
		port systemControl : ControlPort;
		port mainPower : PowerPort;
		
		part detector : PhotonDetectorModule;
		part conditioner : SignalConditioner;
		part discriminator : PulseDiscriminator;
		part counter : CountingLogic;
		part thermalControl : ThermalController;
		part calibrator : CalibrationModule;
		part dataIface : DataInterface;
		
		connection opticalPath connect opticalInterface to detector.opticalInput;
		connection detectorSignal connect detector.signalOutput to conditioner.pulseInput;
		connection conditionedSignal connect conditioner.pulseOutput to discriminator.pulseInput;
		connection validatedPulses connect discriminator.pulseOutput to counter.pulseInput;
		connection countOutput connect counter.dataOutput to dataIface.dataInput;
		connection finalOutput connect dataIface.dataInput to dataInterface;
		connection controlBus connect systemControl to counter.control;
		connection calibrationData connect counter.dataOutput to calibrator.dataInput;
		connection thermalLink connect thermalControl.cooling to detector.cooling;
		
		flow detector.signalOutput.pulseStream to conditioner.pulseInput.pulseStream;
		flow conditioner.pulseOutput.pulseStream to discriminator.pulseInput.pulseStream;
		flow discriminator.pulseOutput.pulseStream to counter.pulseInput.pulseStream;
		flow counter.dataOutput.countData to dataIface.dataInput.countData;
		
		perform action operatePhotonCounter {
			first start;
			then action initialize : InitializeSystem {
				in biasVoltage = 250.0 [V];
				in coolingTarget = 253.15 [K];
				out systemReady;
			}
			then decide;
				if initialize.systemReady then calibrate;
				else done;
			
			action calibrate : MeasureDarkCount {
				in integrationTime = 10.0 [s];
				out darkCount;
				out darkRate;
			}
			then assign calibrator.darkCountBaseline := calibrate.darkRate;
			then merge continuousOperation;
			
			loop {
				action continuousOperation : AcquirePhotonData {
					in integrationTime = 1.0 [s];
					in wavelengthFilter = 550.0 [nm];
					out rawCount;
					out correctedCount;
					out countRate;
				}
				flow continuousOperation.correctedCount to dataInterface.countData.totalCount;
				flow continuousOperation.countRate to dataInterface.countData.rate;
			}
		}
	}
	
	part visibleLightPhotonCounter : VisibleLightPhotonCounterSystem;
	
	attribute def PowerOnSignal;
	attribute def PowerDownSignal;
	attribute def CalibrateCommandSignal;
	attribute def CalibrationCompleteSignal;
	
	state def SystemOperationalStates {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_initializing
			first powerOff
			accept powerOnCmd : PowerOnSignal
			then initializing;
		
		state initializing {
			entry action visibleLightPhotonCounter.operatePhotonCounter;
		}
		transition initializing_to_standby
			first initializing
			if visibleLightPhotonCounter.thermalControl.cooling.actualTemp <= 253.65 [K]
			then standby;
		
		state standby {
			entry assign visibleLightPhotonCounter.systemControl.systemReady := true;
		}
		transition standby_to_calibrating
			first standby
			accept calibrateCmd : CalibrateCommandSignal
			then calibrating;
		transition standby_to_measuring
			first standby
			accept visibleLightPhotonCounter.systemControl.startCommand
			then measuring;
		
		state calibrating {
			entry action visibleLightPhotonCounter.calibrator.calibrateSystem;
		}
		transition calibrating_to_standby
			first calibrating
			accept calibrationDone : CalibrationCompleteSignal
			then standby;
		
		state measuring {
			entry action visibleLightPhotonCounter.counter.countPhotons;
		}
		transition measuring_to_standby
			first measuring
			accept visibleLightPhotonCounter.systemControl.stopCommand
			then standby;
		transition measuring_to_error
			first measuring
			if visibleLightPhotonCounter.detector.darkCount > 500.0 [Hz]
			then error;
		
		state error;
		transition error_to_standby
			first error
			accept visibleLightPhotonCounter.systemControl.resetCommand
			then standby;
		
		transition standby_to_powerOff
			first standby
			accept powerDownCmd : PowerDownSignal
			then powerOff;
	}
	
	requirement <'REQ-001'> singlePhotonDetection {
		doc /* 
			The system shall detect individual photons in the visible spectrum 
			(380-750 nm) with quantum efficiency exceeding 40% at peak wavelength.
		*/
		
		subject visibleLightPhotonCounter.detector;
		
		require constraint {
			visibleLightPhotonCounter.detector.quantumEff > 0.40 and
			visibleLightPhotonCounter.detector.spectralRange.lowerBound == 380.0 [nm] and
			visibleLightPhotonCounter.detector.spectralRange.upperBound == 750.0 [nm]
		}
	}
	
	requirement <'REQ-002'> darkCountPerformance {
		doc /* 
			The system shall maintain dark count rate below 100 counts per second 
			when operated at the specified cooling temperature of -20°C.
		*/
		
		subject visibleLightPhotonCounter.detector;
		
		require constraint {
			visibleLightPhotonCounter.detector.darkCount < 100.0 [Hz] and
			visibleLightPhotonCounter.thermalControl.setpoint == 253.15 [K]
		}
	}
	
	requirement <'REQ-003'> countingCapability {
		doc /* 
			The system shall accurately count photons at rates up to 10 MHz 
			with temporal resolution better than 50 nanoseconds.
		*/
		
		subject visibleLightPhotonCounter.counter;
		
		require constraint {
			visibleLightPhotonCounter.counter.maxCountRate >= 10.0 [MHz] and
			visibleLightPhotonCounter.discriminator.deadTime <= 50.0 [ns]
		}
	}
	
	requirement <'REQ-004'> thermalStability {
		doc /* 
			The thermal control system shall maintain detector temperature 
			within ±0.1 K of the setpoint during operation.
		*/
		
		subject visibleLightPhotonCounter.thermalControl;
		
		require constraint {
			visibleLightPhotonCounter.thermalControl.stabilityTolerance <= 0.1 [K]
		}
	}
	
	requirement <'REQ-005'> signalProcessing {
		doc /* 
			The signal conditioning chain shall provide minimum gain of 100 
			with bandwidth exceeding 100 MHz and noise floor below 5 mV.
		*/
		
		subject visibleLightPhotonCounter.conditioner;
		
		require constraint {
			visibleLightPhotonCounter.conditioner.gain >= 100.0 and
			visibleLightPhotonCounter.conditioner.bandwidth >= 100.0 [MHz] and
			visibleLightPhotonCounter.conditioner.noiseFloor <= 5.0 [mV]
		}
	}
	
	requirement systemMissionRequirement {
		doc /* 
			The Visible Light Photon Counter System shall provide high-sensitivity 
			detection and accurate quantification of individual photons across the 
			visible spectrum to enable quantum optics research, ultra-low-light 
			spectroscopy, single-molecule fluorescence studies, and advanced 
			bioluminescence imaging applications.
		*/
		
		require singlePhotonDetection;
		require darkCountPerformance;
		require countingCapability;
		require thermalStability;
		require signalProcessing;
	}
}
