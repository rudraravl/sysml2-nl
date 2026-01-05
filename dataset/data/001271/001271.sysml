package 'Superconducting Nanowire Single-Photon Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def QuantumEfficiency :> Real;
	attribute def DarkCountRate :> Real;
	attribute def TimingJitter :> TimeValue;
	attribute def DeadTime :> TimeValue;

	item def Photon {
		attribute wavelength : LengthValue;
		attribute energy : EnergyValue;
		attribute arrivalTime : TimeValue;
	}

	item def ElectricalPulse {
		attribute amplitude : ElectricPotentialValue;
		attribute width : TimeValue;
		attribute timestamp : TimeValue;
	}

	item def CryogenicCoolant {
		attribute temperature : ThermodynamicTemperatureValue;
		attribute flowRate : VolumeFlowRateValue;
	}

	port def OpticalInputPort {
		in item photonSignal : Photon;
	}

	port def ElectricalOutputPort {
		out item pulseSignal : ElectricalPulse;
	}

	port def CryogenicInterfacePort {
		in item coolant : CryogenicCoolant;
	}

	port def BiasCurrentPort {
		in attribute current : ElectricCurrentValue;
	}

	part def SuperconductingNanowire {
		attribute material : String = "NbN";
		attribute width : LengthValue = 100.0 [SI::nm];
		attribute thickness : LengthValue = 5.0 [SI::nm];
		attribute length : LengthValue = 15.0 [SI::μm];
		attribute criticalTemperature : ThermodynamicTemperatureValue = 10.0 [SI::K];
		attribute operatingTemperature : ThermodynamicTemperatureValue = 2.5 [SI::K];
		attribute criticalCurrent : ElectricCurrentValue = 20.0 [SI::μA];
		attribute kineticInductance : InductanceValue = 150.0 [SI::nH];

		port opticalIn : OpticalInputPort;
		port electricalOut : ElectricalOutputPort;
		port biasIn : BiasCurrentPort;
		port cryoIn : CryogenicInterfacePort;

		action def maintainSuperconductivity;
		action def absorbPhotonEnergy;
		action def formHotspot;
		action def generateVoltagePulse;
		action def coolDown;

		state def DetectionStateMachine {
			entry; then Superconducting;

			state Superconducting {
				entry action ms : maintainSuperconductivity;
			}

			state PhotonAbsorption {
				entry action ape : absorbPhotonEnergy;
			}

			state ResistiveHotspot {
				entry action fh : formHotspot;
			}

			state VoltageTransient {
				entry action gvp : generateVoltagePulse;
			}

			state Recovery {
				entry action cd : coolDown;
			}

			transition photonArrival
				first Superconducting
				accept at opticalIn
				then PhotonAbsorption;

			transition hotspotFormation
				first PhotonAbsorption
				then ResistiveHotspot;

			transition pulseGeneration
				first ResistiveHotspot
				then VoltageTransient;

			transition beginRecovery
				first VoltageTransient
				then Recovery;

			transition returnToSuperconducting
				first Recovery
				then Superconducting;
		}

		exhibit state detectionBehavior : DetectionStateMachine;
	}

	part def CryogenicRefrigerator {
		attribute coolingPower : PowerValue = 1.5 [SI::W];
		attribute baseTemperature : ThermodynamicTemperatureValue = 1.8 [SI::K];
		attribute stabilityTolerance : ThermodynamicTemperatureValue = 0.1 [SI::K];

		port cryoOut : CryogenicInterfacePort;

		perform action maintainCryogenicTemperature {
			in targetTemp : ThermodynamicTemperatureValue;
			out actualTemp : ThermodynamicTemperatureValue;

			first start;
			then action circulateCoolant {
				out coolantFlow : CryogenicCoolant;
			}
			then action regulateTemperature {
				in flow : CryogenicCoolant = circulateCoolant.coolantFlow;
				out stabilizedTemp : ThermodynamicTemperatureValue;
			}
			then done;
		}
	}

	part def BiasCurrentSource {
		attribute biasVoltage : ElectricPotentialValue = 1.2 [SI::V];
		attribute loadResistance : Real = 50.0;
		attribute outputCurrent : ElectricCurrentValue = 18.0 [SI::μA];

		port currentOut : BiasCurrentPort;

		perform action supplyBiasCurrent {
			in voltage : ElectricPotentialValue;
			in resistance : Real;
			out current : ElectricCurrentValue;
		}
	}

	part def ReadoutAmplifier {
		attribute gain : Real = 1000.0;
		attribute bandwidth : FrequencyValue = 2.0e9 [SI::Hz];
		attribute inputImpedance : Real = 50.0;
		attribute noiseTemperature : ThermodynamicTemperatureValue = 4.0 [SI::K];

		port signalIn : ElectricalOutputPort;
		port amplifiedOut : ElectricalOutputPort;

		perform action amplifyDetectionPulse {
			in inputPulse : ElectricalPulse;
			out amplifiedPulse : ElectricalPulse;

			first start;
			then action applyGain {
				in pulse : ElectricalPulse = inputPulse;
				out boostedPulse : ElectricalPulse;
			}
			then action filterNoise {
				in pulse : ElectricalPulse = applyGain.boostedPulse;
				out cleanPulse : ElectricalPulse = amplifiedPulse;
			}
			then done;
		}
	}

	part def PulseDiscriminator {
		attribute thresholdVoltage : ElectricPotentialValue = 0.15 [SI::V];
		attribute discriminationTime : TimeValue = 500.0 [SI::ps];

		port analogIn : ElectricalOutputPort;
		port digitalOut : ElectricalOutputPort;

		perform action discriminateSignal {
			in analogPulse : ElectricalPulse;
			out digitalPulse : ElectricalPulse;

			first start;
			then decide;
				if analogPulse.amplitude >= thresholdVoltage then acceptPulse;
				if analogPulse.amplitude < thresholdVoltage then rejectPulse;

			action acceptPulse {
				out validPulse : ElectricalPulse = digitalPulse;
			}
			then done;

			action rejectPulse;
			then done;
		}
	}

	part def TimingModule {
		attribute timeResolution : TimeValue = 30.0 [SI::ps];
		attribute clockFrequency : FrequencyValue = 10.0e9 [SI::Hz];
		attribute timestampPrecision : TimeValue = 50.0 [SI::ps];

		port pulseIn : ElectricalOutputPort;

		perform action recordPhotonArrival {
			in detectionPulse : ElectricalPulse;
			out timestamp : TimeValue;

			first start;
			then action captureTimestamp {
				in pulse : ElectricalPulse = detectionPulse;
				out time : TimeValue = timestamp;
			}
			then action storeEvent {
				in eventTime : TimeValue = captureTimestamp.time;
			}
			then done;
		}
	}

	part def SNSPDDetectorSystem {
		attribute systemEfficiency : QuantumEfficiency = 0.85;
		attribute systemDarkCountRate : DarkCountRate = 50.0;
		attribute systemJitter : TimingJitter = 40.0 [SI::ps];
		attribute systemDeadTime : DeadTime = 30.0 [SI::ns];

		part nanowire : SuperconductingNanowire;
		part cryostat : CryogenicRefrigerator;
		part biasSource : BiasCurrentSource;
		part amplifier : ReadoutAmplifier;
		part discriminator : PulseDiscriminator;
		part timingUnit : TimingModule;

		port opticalInterface : OpticalInputPort;
		port detectionOutput : ElectricalOutputPort;

		connection cryogenicConnection connect cryostat.cryoOut to nanowire.cryoIn;
		connection biasConnection connect biasSource.currentOut to nanowire.biasIn;
		connection opticalConnection connect opticalInterface to nanowire.opticalIn;
		connection nanowireToAmplifier connect nanowire.electricalOut to amplifier.signalIn;
		connection amplifierToDiscriminator connect amplifier.amplifiedOut to discriminator.analogIn;
		connection discriminatorToTiming connect discriminator.digitalOut to timingUnit.pulseIn;
		connection discriminatorToOutput connect discriminator.digitalOut to detectionOutput;

		perform action detectSinglePhoton {
			doc /*
			 * Primary Function: Detect individual photons with high quantum efficiency and precise timing.
			 * 
			 * The SNSPD system operates by maintaining a superconducting nanowire at cryogenic temperatures
			 * (typically 2-3 Kelvin) using a closed-cycle refrigerator. A bias current flows through the
			 * nanowire, keeping it just below its critical current threshold while in the superconducting state.
			 * 
			 * When a single photon is absorbed by the nanowire, its energy breaks Cooper pairs and creates
			 * a localized resistive hotspot. This hotspot temporarily disrupts superconductivity in that region,
			 * causing the bias current to redistribute around the resistive area. The redistribution creates
			 * a measurable voltage pulse across the nanowire due to its kinetic inductance.
			 * 
			 * This voltage pulse is amplified by low-noise cryogenic amplifiers, then discriminated against
			 * noise using a threshold comparator. Valid detection events are timestamped with picosecond
			 * precision by high-speed timing electronics. After pulse generation, the nanowire cools and
			 * returns to its superconducting state, ready to detect the next photon after a brief dead time.
			 * 
			 * SNSPDs achieve quantum efficiencies exceeding 80%, dark count rates below 100 Hz, timing jitter
			 * under 50 ps, and dead times of tens of nanoseconds, making them ideal for quantum key distribution,
			 * quantum computing readout, LIDAR, and time-correlated single-photon counting applications.
			 */

			in photonStream : Photon[0..*];
			out detectionEvents : ElectricalPulse[0..*];
			out eventTimestamps : TimeValue[0..*];

			first start;
			then merge readyForDetection;

			action maintainOperatingConditions {
				perform cryostat.maintainCryogenicTemperature;
				perform biasSource.supplyBiasCurrent;
			}

			then readyForDetection;

			then action awaitPhoton {
				in incomingPhoton : Photon;
			}

			then action absorbPhotonInNanowire {
				doc /* Photon energy absorbed, Cooper pairs broken, hotspot forms */
			}

			then action generateResistivePulse {
				doc /* Current redistribution creates voltage pulse across nanowire */
				out rawPulse : ElectricalPulse;
			}

			then action amplifySignal {
				perform amplifier.amplifyDetectionPulse;
			}

			then action discriminatePulse {
				perform discriminator.discriminateSignal;
			}

			then action timestampEvent {
				perform timingUnit.recordPhotonArrival;
			}

			then action nanowireRecovery {
				doc /* Hotspot dissipates, nanowire returns to superconducting state */
			}

			then readyForDetection;
		}
	}

	requirement def QuantumEfficiencyRequirement {
		subject detector : SNSPDDetectorSystem;

		require constraint efficiencySpec {
			detector.systemEfficiency >= 0.80
		}
	}

	requirement def DarkCountRequirement {
		subject detector : SNSPDDetectorSystem;

		require constraint darkCountSpec {
			detector.systemDarkCountRate <= 100.0
		}
	}

	requirement def TimingPerformanceRequirement {
		subject detector : SNSPDDetectorSystem;

		require constraint jitterSpec {
			detector.systemJitter <= 50.0 [SI::ps]
		}

		require constraint deadTimeSpec {
			detector.systemDeadTime <= 50.0 [SI::ns]
		}
	}

	requirement def OperationalRequirement {
		subject system : SNSPDDetectorSystem;

		require constraint temperatureSpec {
			system.nanowire.operatingTemperature <= 3.0 [SI::K]
		}

		require constraint biasSpec {
			system.biasSource.outputCurrent < system.nanowire.criticalCurrent
		}
	}

	part snspd : SNSPDDetectorSystem {
		satisfy efficiencyReq : QuantumEfficiencyRequirement by snspd;
		satisfy darkCountReq : DarkCountRequirement by snspd;
		satisfy timingReq : TimingPerformanceRequirement by snspd;
		satisfy operationalReq : OperationalRequirement by snspd;
	}
}
