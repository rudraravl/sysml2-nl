package 'Electromagnetic Cloaking System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def PermittivityValue :> Real;
	attribute def PermeabilityValue :> Real;
	attribute def RefractiveIndexValue :> Real;

	item def WaveCharacteristics {
		attribute frequency : ISQ::FrequencyValue;
		attribute amplitude : Real;
		attribute approachAngle : ISQ::PlaneAngleValue;
	}

	item def CellControlCommand {
		attribute layerId : Integer;
		attribute cellId : Integer;
		attribute permittivity : PermittivityValue;
		attribute permeability : PermeabilityValue;
	}

	item def RefractiveIndexPattern {
		attribute layerId : Integer;
		attribute cellId : Integer;
		attribute refractiveIndex : RefractiveIndexValue;
	}

	item def VerificationResult {
		attribute distortionDetected : Boolean;
		attribute scatteringLevel : Real;
	}

	attribute def PowerOnCommand;
	attribute def ActivateCommand;
	attribute def StandbyCommand;
	attribute def PowerOffCommand;

	action def SelfCalibration;
	action def ProvideRegulatedPower {
		out powerOutput : ISQ::PowerValue;
	}
	action def SenseIncomingWave {
		out waveData : WaveCharacteristics;
	}
	action def CalculateAdjustments {
		in sensorData : WaveCharacteristics;
		in verification : VerificationResult;
		out pattern : RefractiveIndexPattern[*];
	}
	action def ModulateLayers {
		in pattern : RefractiveIndexPattern[*];
		out commands : CellControlCommand[*];
	}
	action def VerifyCloaking {
		out result : VerificationResult;
	}
	action def OptimizeSettings {
		in verifyResult : VerificationResult;
		out refinedPattern : RefractiveIndexPattern[*];
	}

	part def MetamaterialCell {
		attribute cellId : Integer;
		attribute permittivity : PermittivityValue;
		attribute permeability : PermeabilityValue;
		port controlPort {
			in command : CellControlCommand;
		}
		port powerPort {
			in power : ISQ::PowerValue;
		}
	}

	part def MetamaterialLayer {
		attribute layerId : Integer;
		part cells : MetamaterialCell[64];
		port controlPort {
			in command : CellControlCommand;
		}
		port powerPort {
			in power : ISQ::PowerValue;
		}
	}

	part def MetamaterialShell {
		part layers : MetamaterialLayer[4];
		port controlPort {
			in command : CellControlCommand;
		}
		port powerPort {
			in power : ISQ::PowerValue;
		}
		port waveInPort {
			in incomingWave : WaveCharacteristics;
		}
		port waveOutPort {
			out outgoingWave : WaveCharacteristics;
		}
	}

	part def WaveSensor {
		port sensedWavePort {
			out waveData : WaveCharacteristics;
		}
		port powerPort {
			in power : ISQ::PowerValue;
		}
	}

	part def VerificationSensor {
		port measuredWavePort {
			in measuredWave : WaveCharacteristics;
		}
		port verificationPort {
			out result : VerificationResult;
		}
		port powerPort {
			in power : ISQ::PowerValue;
		}
	}

	part def ControlProcessor {
		port sensorDataPort {
			in waveData : WaveCharacteristics;
		}
		port verificationPort {
			in result : VerificationResult;
		}
		port controlCommandPort {
			out command : CellControlCommand;
		}
		port powerPort {
			in power : ISQ::PowerValue;
		}
	}

	part def PowerSupply {
		port powerOutputPort {
			out powerOutput : ISQ::PowerValue;
		}
	}

	part def CloakedObject;

	part def CloakingSystem {
		part powerSupply : PowerSupply;
		part controlProcessor : ControlProcessor;
		part waveSensor : WaveSensor;
		part verificationSensor : VerificationSensor;
		part shell : MetamaterialShell;
		part cloakedObject : CloakedObject;

		flow powerFlowToProcessor of ISQ::PowerValue
			from powerSupply.powerOutputPort.powerOutput to controlProcessor.powerPort.power;
		flow powerFlowToSensor of ISQ::PowerValue
			from powerSupply.powerOutputPort.powerOutput to waveSensor.powerPort.power;
		flow powerFlowToVerificationSensor of ISQ::PowerValue
			from powerSupply.powerOutputPort.powerOutput to verificationSensor.powerPort.power;
		flow powerFlowToShell of ISQ::PowerValue
			from powerSupply.powerOutputPort.powerOutput to shell.powerPort.power;
		flow sensorDataFlow of WaveCharacteristics
			from waveSensor.sensedWavePort.waveData to controlProcessor.sensorDataPort.waveData;
		flow verificationDataFlow of VerificationResult
			from verificationSensor.verificationPort.result to controlProcessor.verificationPort.result;
		flow controlCommandFlow of CellControlCommand
			from controlProcessor.controlCommandPort.command to shell.controlPort.command;
		flow incomingWaveFlow of WaveCharacteristics
			from waveSensor.sensedWavePort.waveData to shell.waveInPort.incomingWave;
		flow outgoingWaveFlow of WaveCharacteristics
			from shell.waveOutPort.outgoingWave to verificationSensor.measuredWavePort.measuredWave;

		state cloakingStates {
			entry; then powerOff;

			state powerOff;
			accept PowerOnCommand then initialization;

			state initialization {
				entry SelfCalibration;
				do action ProvideRegulatedPower;
			}
			transition first initialization then standby;

			state standby {
				do action ProvideRegulatedPower;
			}
			accept ActivateCommand then activeCloaking;
			accept PowerOffCommand then powerOff;

			state activeCloaking {
				entry; then sensing;

				state sensing {
					do action SenseIncomingWave;
				}
				transition first sensing then processing;

				state processing {
					do action CalculateAdjustments;
				}
				transition first processing then modulating;

				state modulating {
					do action ModulateLayers;
				}
				transition first modulating then verifying;

				state verifying {
					do action VerifyCloaking;
				}
				transition first verifying then optimizing;

				state optimizing {
					do action OptimizeSettings;
				}
				transition first optimizing then sensing;
			}

			accept StandbyCommand then standby;
			accept PowerOffCommand then powerOff;
		}
	}

	requirement def CloakingEffectiveness {
		doc /* The system shall render the cloaked object invisible to radar detection by guiding EM waves around the object. */
		subject : cloakingSystem : CloakingSystem;
		objective {
			doc /* Residual scattering must be below detection threshold. */
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall adapt to changing electromagnetic conditions within 1 microsecond. */
		subject : cloakingSystem : CloakingSystem;
		attribute maxResponseTime : ISQ::TimeValue = 0.000001;
		objective {
			doc /* Maximum response latency is 1 microsecond. */
		}
	}

	requirement def LayerCountRequirement {
		doc /* The metamaterial shell shall consist of exactly four distinct layers. */
		subject : shell : MetamaterialShell;
		objective {
			doc /* shell.layers has exactly 4 elements. */
		}
	}

	requirement def CellsPerLayerRequirement {
		doc /* Each metamaterial layer shall contain exactly 64 individually controlled cells. */
		subject : layer : MetamaterialLayer;
		objective {
			doc /* layer.cells has exactly 64 elements. */
		}
	}

	requirement def PowerStabilityRequirement {
		doc /* The power supply shall provide stable, regulated power to the control processor and all metamaterial layers during active cloaking. */
		subject : powerSupply : PowerSupply;
		objective {
			doc /* Power output remains within regulated tolerance under load. */
		}
	}

	requirement def ContinuousOptimizationRequirement {
		doc /* The system shall continuously verify cloaking effectiveness and refine cell settings in real-time when distortion is detected. */
		subject : cloakingSystem : CloakingSystem;
		objective {
			doc /* The sense-process-modulate-verify loop runs continuously during activeCloaking state. */
		}
	}
}
