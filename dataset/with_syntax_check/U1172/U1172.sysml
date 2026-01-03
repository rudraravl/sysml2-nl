package 'Quantum Dot Photon Emission System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def QuantumState {
		attribute energyLevel : EnergyValue;
		attribute electronCount : Integer;
		attribute holeCount : Integer;
		attribute isExcited : Boolean;
	}
	
	attribute def PhotonEnergy :> EnergyValue;
	
	attribute def WavelengthValue :> LengthValue;
	
	attribute def EmissionSpectrum {
		attribute peakWavelength : WavelengthValue;
		attribute intensity : Real;
		attribute bandwidth : WavelengthValue;
		attribute quantumYield : Real;
	}
	
	item def Photon {
		attribute energy : PhotonEnergy;
		attribute wavelength : WavelengthValue;
		attribute polarization : Real;
	}
	
	item def Exciton {
		attribute bindingEnergy : EnergyValue;
		attribute lifetime : TimeValue;
	}
	
	port def OpticalPort {
		in item incidentPhoton : Photon;
		out item emittedPhoton : Photon;
	}
	
	port def ElectricalPort {
		in voltage : ElectricPotentialValue;
		in current : ElectricCurrentValue;
	}
	
	port def ThermalPort {
		in temperature : TemperatureValue;
		out heatDissipation : PowerValue;
	}
	
	part def QuantumDot {
		doc /* 
		 * A semiconductor nanocrystal that exhibits quantum confinement effects.
		 * Absorbs high-energy photons and emits lower-energy photons at wavelengths
		 * determined by the dot size and composition.
		 */
		
		attribute diameter : LengthValue;
		attribute bandgapEnergy : EnergyValue;
		attribute currentState : QuantumState;
		attribute material : String;
		
		port opticalInterface : OpticalPort;
		port thermalInterface : ThermalPort;
		
		perform action quantumConfinementBehavior;
	}
	
	part def ExcitationSource {
		doc /* 
		 * Provides high-energy photons to excite the quantum dot.
		 * Typically a UV or blue LED or laser.
		 */
		
		attribute excitationWavelength : WavelengthValue;
		attribute outputPower : PowerValue;
		attribute pulseWidth : TimeValue;
		
		port opticalOutput : OpticalPort;
		port electricalInput : ElectricalPort;
		
		perform action generateExcitation;
	}
	
	part def OpticalFilter {
		doc /* 
		 * Filters out excitation light and passes only emission from quantum dot.
		 */
		
		attribute cutoffWavelength : WavelengthValue;
		attribute transmissionEfficiency : Real;
		
		port inputPort : OpticalPort;
		port outputPort : OpticalPort;
		
		perform action filterLight;
	}
	
	part def PhotoDetector {
		doc /* 
		 * Measures the emission spectrum and intensity from the quantum dot.
		 */
		
		attribute sensitivity : Real;
		attribute detectionRange : WavelengthValue[2];
		attribute responseTime : TimeValue;
		
		port opticalInput : OpticalPort;
		port dataOutput {
			out spectrum : EmissionSpectrum;
			out intensity : Real;
		}
		
		perform action measureEmission;
	}
	
	part def TemperatureController {
		doc /* 
		 * Maintains stable temperature for consistent quantum dot performance.
		 */
		
		attribute setpoint : TemperatureValue;
		attribute controlRange : TemperatureValue[2];
		
		port thermalControl : ThermalPort;
		port electricalInput : ElectricalPort;
		
		perform action regulateTemperature;
	}
	
	action def AbsorbPhoton {
		in incidentPhoton : Photon;
		in currentState : QuantumState;
		in bandgap : EnergyValue;
		out excitedState : QuantumState;
		out exciton : Exciton;
	}
	
	action def RelaxAndEmit {
		in excitedState : QuantumState;
		in bandgap : EnergyValue;
		in temperature : TemperatureValue;
		out groundState : QuantumState;
		out emittedPhoton : Photon;
	}
	
	action def GenerateExcitationLight {
		in wavelength : WavelengthValue;
		in power : PowerValue;
		in voltage : ElectricPotentialValue;
		out photon : Photon;
	}
	
	action def FilterPhotons {
		in inputPhoton : Photon;
		in cutoff : WavelengthValue;
		out filteredPhoton : Photon;
		out isTransmitted : Boolean;
	}
	
	action def DetectEmission {
		in photon : Photon;
		in sensitivity : Real;
		out spectrum : EmissionSpectrum;
		out measuredIntensity : Real;
	}
	
	action def RegulateTemp {
		in targetTemp : TemperatureValue;
		in currentTemp : TemperatureValue;
		out controlSignal : ElectricPotentialValue;
		out stabilizedTemp : TemperatureValue;
	}
	
	action def QuantumConfinementBehavior {
		doc /* 
		 * Core behavior of quantum dot: absorbs high-energy photons and emits
		 * photons at wavelength determined by quantum confinement.
		 */
		
		in incidentPhoton : Photon;
		in dotDiameter : LengthValue;
		in bandgap : EnergyValue;
		in ambientTemp : TemperatureValue;
		out emittedPhoton : Photon;
		out currentSpectrum : EmissionSpectrum;
	}
	
	action quantumConfinementBehavior : QuantumConfinementBehavior {
		in incidentPhoton : Photon;
		in dotDiameter : LengthValue;
		in bandgap : EnergyValue;
		in ambientTemp : TemperatureValue;
		out emittedPhoton : Photon;
		out currentSpectrum : EmissionSpectrum;
		
		first start;
		then merge waitingForExcitation;
		
		action waitForPhoton {
			accept arrival : Photon;
		}
		
		then decide;
			if waitForPhoton.arrival.energy >= bandgap then absorb;
			else waitingForExcitation;
		
		action absorb : AbsorbPhoton {
			in incidentPhoton = waitForPhoton.arrival;
			in currentState : QuantumState;
			in bandgap = quantumConfinementBehavior::bandgap;
			out excitedState : QuantumState;
			out exciton : Exciton;
		}
		
		then action thermalize {
			doc /* Exciton thermalizes to band edge */
		}
		
		then action emit : RelaxAndEmit {
			in excitedState = absorb.excitedState;
			in bandgap = quantumConfinementBehavior::bandgap;
			in temperature = quantumConfinementBehavior::ambientTemp;
			out groundState : QuantumState;
			out emittedPhoton : Photon;
		}
		
		then assign emittedPhoton := emit.emittedPhoton;
		then assign currentSpectrum := EmissionSpectrum {
			peakWavelength = emit.emittedPhoton.wavelength;
			intensity = 1.0;
			bandwidth = 25.0 [nm];
			quantumYield = 0.85;
		};
		
		then waitingForExcitation;
	}
	
	action generateExcitation : GenerateExcitationLight {
		in wavelength : WavelengthValue;
		in power : PowerValue;
		in voltage : ElectricPotentialValue;
		out photon : Photon;
		
		first start;
		then loop {
			action createPhoton {
				then assign photon := Photon {
					wavelength = generateExcitation::wavelength;
					energy = 1240.0 [eV*nm] / generateExcitation::wavelength;
					polarization = 0.0;
				};
			}
			then send photon;
		}
	}
	
	action filterLight : FilterPhotons {
		in inputPhoton : Photon;
		in cutoff : WavelengthValue;
		out filteredPhoton : Photon;
		out isTransmitted : Boolean;
		
		first start;
		then decide;
			if inputPhoton.wavelength > cutoff then transmit;
			else block;
		
		action transmit {
			then assign filteredPhoton := inputPhoton;
			then assign isTransmitted := true;
		}
		then done;
		
		action block {
			then assign isTransmitted := false;
		}
		then done;
	}
	
	action measureEmission : DetectEmission {
		in photon : Photon;
		in sensitivity : Real;
		out spectrum : EmissionSpectrum;
		out measuredIntensity : Real;
		
		first start;
		then action analyzePhoton {
			then assign spectrum := EmissionSpectrum {
				peakWavelength = measureEmission::photon.wavelength;
				intensity = measureEmission::sensitivity;
				bandwidth = 30.0 [nm];
				quantumYield = 0.80;
			};
			then assign measuredIntensity := measureEmission::sensitivity;
		}
		then done;
	}
	
	action regulateTemperature : RegulateTemp {
		in targetTemp : TemperatureValue;
		in currentTemp : TemperatureValue;
		out controlSignal : ElectricPotentialValue;
		out stabilizedTemp : TemperatureValue;
		
		first start;
		then merge controlLoop;
		
		action measureTemp;
		
		then decide;
			if currentTemp < targetTemp then heat;
			if currentTemp > targetTemp then cool;
			else maintain;
		
		action heat {
			then assign controlSignal := 5.0 [V];
		}
		then controlLoop;
		
		action cool {
			then assign controlSignal := -5.0 [V];
		}
		then controlLoop;
		
		action maintain {
			then assign controlSignal := 0.0 [V];
			then assign stabilizedTemp := targetTemp;
		}
		then done;
	}
	
	part def QuantumDotSystem {
		doc /* 
		 * Complete quantum dot photon emission system.
		 * Primary function: Convert high-energy excitation photons into 
		 * lower-energy emission photons with precisely controlled wavelength
		 * determined by quantum confinement in the nanoscale semiconductor dot.
		 * Applications include displays, biological imaging, and quantum light sources.
		 */
		
		part uvSource : ExcitationSource;
		part qdot : QuantumDot;
		part filter : OpticalFilter;
		part detector : PhotoDetector;
		part tempController : TemperatureController;
		
		perform action operateQuantumDotSystem;
	}
	
	part quantumDotSystem : QuantumDotSystem {
		part uvSource : ExcitationSource {
			attribute :>> excitationWavelength = 365.0 [nm];
			attribute :>> outputPower = 100.0 [mW];
			attribute :>> pulseWidth = 10.0 [ns];
			
			perform action generateExcitation;
		}
		
		part qdot : QuantumDot {
			attribute :>> diameter = 5.0 [nm];
			attribute :>> bandgapEnergy = 2.48 [eV];
			attribute :>> material = "CdSe";
			attribute :>> currentState = QuantumState {
				energyLevel = 0.0 [eV];
				electronCount = 0;
				holeCount = 0;
				isExcited = false;
			};
			
			perform action quantumConfinementBehavior;
		}
		
		part filter : OpticalFilter {
			attribute :>> cutoffWavelength = 450.0 [nm];
			attribute :>> transmissionEfficiency = 0.95;
			
			perform action filterLight;
		}
		
		part detector : PhotoDetector {
			attribute :>> sensitivity = 0.90;
			attribute :>> detectionRange = (400.0 [nm], 700.0 [nm]);
			attribute :>> responseTime = 1.0 [ns];
			
			perform action measureEmission;
		}
		
		part tempController : TemperatureController {
			attribute :>> setpoint = 298.15 [K];
			attribute :>> controlRange = (273.15 [K], 323.15 [K]);
			
			perform action regulateTemperature;
		}
		
		connection excitationPath connect uvSource.opticalOutput.emittedPhoton 
			to qdot.opticalInterface.incidentPhoton;
		
		connection emissionToFilter connect qdot.opticalInterface.emittedPhoton 
			to filter.inputPort.incidentPhoton;
		
		connection filterToDetector connect filter.outputPort.emittedPhoton 
			to detector.opticalInput.incidentPhoton;
		
		connection thermalControl connect tempController.thermalControl 
			to qdot.thermalInterface;
		
		perform action operateQuantumDotSystem;
	}
	
	action operateQuantumDotSystem {
		doc /* 
		 * High-level operation: continuous excitation and emission cycle
		 * with temperature stabilization and spectral measurement.
		 */
		
		first start;
		
		then action initializeSystem {
			action setupSource;
			action prepareQuantumDot;
			action calibrateDetector;
			action stabilizeTemperature;
		}
		
		then merge continuousOperation;
		
		action exciteAndEmit {
			action excite {
				perform quantumDotSystem::uvSource.generateExcitation;
			}
			flow excite to convert;
			
			action convert {
				perform quantumDotSystem::qdot.quantumConfinementBehavior;
			}
			flow convert to filterEmission;
			
			action filterEmission {
				perform quantumDotSystem::filter.filterLight;
			}
			flow filterEmission to detect;
			
			action detect {
				perform quantumDotSystem::detector.measureEmission;
			}
		}
		
		then continuousOperation;
	}
	
	requirement <'QD-SYS-001'> primaryFunctionRequirement {
		doc /* 
		 * The quantum dot system shall convert high-energy excitation photons
		 * into lower-energy emission photons with wavelength controlled by
		 * quantum confinement effects in the nanoscale semiconductor structure.
		 */
		
		subject quantumDotSystem;
		
		require constraint energyConversion {
			doc /* Emitted photon energy shall be less than absorbed photon energy. */
		}
		
		require constraint wavelengthControl {
			doc /* Emission wavelength shall be determined by quantum dot diameter 
			       according to quantum confinement principles. */
		}
	}
	
	requirement <'QD-SYS-002'> quantumYieldRequirement {
		doc /* 
		 * The quantum dot shall exhibit quantum yield greater than 70%
		 * for efficient photon emission after excitation.
		 */
		
		subject quantumDotSystem.qdot;
		
		require constraint minQuantumYield {
			quantumDotSystem.qdot.currentState.isExcited implies 
			quantumDotSystem.detector.dataOutput.spectrum.quantumYield > 0.70
		}
	}
	
	requirement <'QD-SYS-003'> spectralPurityRequirement {
		doc /* 
		 * The emission spectrum bandwidth shall be less than 35 nm FWHM
		 * for narrow-band color-pure light emission.
		 */
		
		subject quantumDotSystem.detector;
		
		require constraint bandwidthLimit {
			quantumDotSystem.detector.dataOutput.spectrum.bandwidth < 35.0 [nm]
		}
	}
	
	requirement <'QD-SYS-004'> thermalStabilityRequirement {
		doc /* 
		 * The system shall maintain quantum dot temperature within ±2 K
		 * of setpoint during operation for stable emission characteristics.
		 */
		
		subject quantumDotSystem.tempController;
		
		require constraint temperatureStability {
			abs(quantumDotSystem.tempController.thermalControl.temperature - 
			    quantumDotSystem.tempController.setpoint) < 2.0 [K]
		}
	}
	
	requirement <'QD-SYS-005'> emissionWavelengthRequirement {
		doc /* 
		 * For a 5 nm CdSe quantum dot, the emission peak wavelength
		 * shall be 500 ± 10 nm (green emission).
		 */
		
		subject quantumDotSystem.qdot;
		
		require constraint wavelengthRange {
			quantumDotSystem.qdot.diameter == 5.0 [nm] implies
			(quantumDotSystem.detector.dataOutput.spectrum.peakWavelength >= 490.0 [nm] and
			 quantumDotSystem.detector.dataOutput.spectrum.peakWavelength <= 510.0 [nm])
		}
	}
	
	requirement <'QD-SYS-006'> systemIntegrationRequirement {
		doc /* 
		 * The complete system shall integrate excitation, quantum dot emission,
		 * optical filtering, and detection subsystems for controlled photon generation.
		 */
		
		subject quantumDotSystem;
		
		assume primaryFunctionRequirement;
		require quantumYieldRequirement;
		require spectralPurityRequirement;
		require thermalStabilityRequirement;
		require emissionWavelengthRequirement;
	}
}
