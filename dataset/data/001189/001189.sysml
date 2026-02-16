package PhototubeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PhotonFluxDensity :> ISQ::PowerValue;
	attribute def PhotocurrentValue :> ISQ::ElectricCurrentValue;
	attribute def SpectralSensitivity :> Real;
	attribute def WorkFunctionValue :> ISQ::EnergyValue;
	attribute def BiasVoltageValue :> ISQ::ElectricPotentialDifferenceValue;
	
	item def PhotonStream {
		attribute flux : PhotonFluxDensity;
		attribute wavelength : ISQ::LengthValue;
	}
	
	item def ElectronStream {
		attribute current : PhotocurrentValue;
	}
	
	port def OpticalPort {
		in item photons : PhotonStream;
	}
	
	port def ElectricalPort {
		out attribute current : PhotocurrentValue;
	}
	
	port def BiasPort {
		in attribute voltage : BiasVoltageValue;
	}
	
	part def Photocathode {
		attribute workFunction : WorkFunctionValue;
		attribute spectralSensitivity : SpectralSensitivity;
		
		action def PhotoelectricEmission {
			in incidentPhotons : PhotonStream;
			in workFunc : WorkFunctionValue;
			in sensitivity : SpectralSensitivity;
			out emittedElectrons : ElectronStream;
		}
	}
	
	part def Anode {
		attribute collectionEfficiency : Real;
		
		action def CollectElectrons {
			in electrons : ElectronStream;
			in efficiency : Real;
			out measuredCurrent : PhotocurrentValue;
		}
	}
	
	part def VacuumEnvelope {
		attribute internalPressure : ISQ::PressureValue;
	}
	
	part def Phototube {
		doc /* A vacuum tube device that converts incident light into electrical current through the photoelectric effect. */
		
		attribute operatingVoltage : BiasVoltageValue;
		attribute responsivity : SpectralSensitivity;
		
		port opticalInput : OpticalPort;
		port electricalOutput : ElectricalPort;
		port biasInput : BiasPort;
		
		part photocathode : Photocathode {
			attribute :>> workFunction = 2.1[SI::eV];
			attribute :>> spectralSensitivity = 0.08;
		}
		
		part anode : Anode {
			attribute :>> collectionEfficiency = 0.92;
		}
		
		part envelope : VacuumEnvelope {
			attribute :>> internalPressure = 1.0e-7[SI::Pa];
		}
		
		binding biasBinding bind biasInput.voltage = operatingVoltage;
		binding outputBinding bind electricalOutput.current = anode.collectedCurrent;
		
		attribute anode.collectedCurrent : PhotocurrentValue;
		
		action def PhotodetectionProcess {
			first start;
			then action receiveLight {
				in lightInput : PhotonStream = opticalInput.photons;
				out receivedPhotons : PhotonStream;
			}
			then action emitElectrons : photocathode.PhotoelectricEmission {
				in incidentPhotons = receiveLight.receivedPhotons;
				in workFunc = photocathode.workFunction;
				in sensitivity = photocathode.spectralSensitivity;
				out emittedElectrons;
			}
			then action accelerate {
				in electrons : ElectronStream = emitElectrons.emittedElectrons;
				in acceleratingVoltage : BiasVoltageValue = biasInput.voltage;
				out acceleratedElectrons : ElectronStream;
			}
			then action collectElectrons : anode.CollectElectrons {
				in electrons = accelerate.acceleratedElectrons;
				in efficiency = anode.collectionEfficiency;
				out measuredCurrent;
			}
			then assign anode.collectedCurrent := collectElectrons.measuredCurrent;
		}
		
		state def OperationalStates {
			entry; then standby;
			
			state standby {
				entry assign electricalOutput.current := 0.0[SI::A];
			}
			
			transition toActive
				first standby
				accept at opticalInput
				if opticalInput.photons.flux > 0.0[SI::W]
				then active;
			
			state active {
				do action PhotodetectionProcess;
			}
			
			transition toStandby
				first active
				accept at opticalInput
				if opticalInput.photons.flux == 0.0[SI::W]
				then standby;
			
			transition continueActive
				first active
				accept at opticalInput
				if opticalInput.photons.flux > 0.0[SI::W]
				then active;
		}
		
		exhibit state behavior : OperationalStates;
	}
	
	part def VoltageSource {
		attribute outputVoltage : BiasVoltageValue;
		
		port biasOutput : BiasPort {
			out attribute :>> voltage = outputVoltage;
		}
	}
	
	part def OpticalSource {
		attribute emissionPower : ISQ::PowerValue;
		attribute emissionWavelength : ISQ::LengthValue;
		
		port lightOutput : OpticalPort {
			out item :>> photons : PhotonStream;
		}
		
		action def GenerateLight {
			in power : ISQ::PowerValue = emissionPower;
			in wavelength : ISQ::LengthValue = emissionWavelength;
			out photonOutput : PhotonStream;
		}
	}
	
	part def CurrentMeter {
		attribute reading : PhotocurrentValue;
		
		port input : ElectricalPort {
			in attribute :>> current;
		}
		
		action def MeasureCurrent {
			in signal : PhotocurrentValue = input.current;
			out measurement : PhotocurrentValue;
		}
	}
	
	part phototubeDetectionSystem {
		doc /* Complete phototube-based light detection system with bias supply and measurement. */
		
		part source : OpticalSource {
			attribute :>> emissionPower = 0.5[SI::W];
			attribute :>> emissionWavelength = 450.0[SI::nm];
		}
		
		part tube : Phototube {
			attribute :>> operatingVoltage = 100.0[SI::V];
			attribute :>> responsivity = 0.08;
		}
		
		part biasSupply : VoltageSource {
			attribute :>> outputVoltage = 100.0[SI::V];
		}
		
		part meter : CurrentMeter;
		
		connection opticalLink connect source.lightOutput to tube.opticalInput;
		connection biasLink connect biasSupply.biasOutput to tube.biasInput;
		connection measurementLink connect tube.electricalOutput to meter.input;
		
		perform action SystemOperation {
			first start;
			then action generateLight : source.GenerateLight {
				out photonOutput;
			}
			then action detectLight : tube.PhotodetectionProcess;
			then action measureCurrent : meter.MeasureCurrent {
				out measurement;
			}
		}
	}
	
	requirement def PhototubeSystemRequirements {
		doc /* Requirements governing phototube system operation and performance. */
		
		requirement <'PT-REQ-1'> vacuumIntegrity {
			doc /* The vacuum envelope shall maintain internal pressure below 1.0e-6 Pa to ensure unimpeded electron transit. */
			
			subject env : VacuumEnvelope;
			
			require constraint {
				env.internalPressure < 1.0e-6[SI::Pa]
			}
		}
		
		requirement <'PT-REQ-2'> biasVoltageRange {
			doc /* The phototube shall operate with bias voltage between 50V and 200V for proper electron acceleration. */
			
			subject device : Phototube;
			
			require constraint {
				device.operatingVoltage >= 50.0[SI::V] and
				device.operatingVoltage <= 200.0[SI::V]
			}
		}
		
		requirement <'PT-REQ-3'> photocathodeEfficiency {
			doc /* The photocathode spectral sensitivity shall be at least 0.05 for adequate photoelectric conversion. */
			
			subject cathode : Photocathode;
			
			require constraint {
				cathode.spectralSensitivity >= 0.05
			}
		}
		
		requirement <'PT-REQ-4'> photoelectricThreshold {
			doc /* Incident photon energy must exceed the photocathode work function to enable electron emission. */
			
			subject cathode : Photocathode;
			
			require constraint {
				cathode.workFunction < 3.0[SI::eV]
			}
		}
		
		requirement <'PT-REQ-5'> primaryFunction {
			doc /* The phototube system shall convert incident optical radiation into proportional electrical current. */
			
			subject system : Phototube;
		}
	}
	
	requirement systemRequirements : PhototubeSystemRequirements {
		subject detectionSystem : Phototube = phototubeDetectionSystem.tube;
		
		assume constraint opticalInputPresent {
			phototubeDetectionSystem.source.emissionPower > 0.0[SI::W]
		}
		
		assume constraint biasApplied {
			phototubeDetectionSystem.biasSupply.outputVoltage > 0.0[SI::V]
		}
		
		require vacuumIntegrity;
		require biasVoltageRange;
		require photocathodeEfficiency;
		require photoelectricThreshold;
		require primaryFunction;
	}
}
