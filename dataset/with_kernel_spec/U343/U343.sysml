package MedicalOxygenConcentratorSystem {
	private import ScalarValues::*;

	item def AmbientAir {
		attribute temperature : Real;
		attribute pressure : Real;
	}
	item def CompressedAir {
		attribute pressure : Real;
		attribute temperature : Real;
	}
	item def EnrichedOxygen {
		attribute purity : Real;
		attribute pressure : Real;
		attribute flowRate : Real;
	}
	item def WasteNitrogen;
	item def OxygenQualityData {
		attribute purity : Real;
		attribute pressure : Real;
		attribute flowRate : Real;
		attribute temperature : Real;
	}
	item def CompressorSpeedCommand {
		attribute targetSpeed : Real;
	}
	item def FlowRateSetpoint {
		attribute flowRate : Real;
	}
	item def SwitchToAdsorption;
	item def SwitchToDesorption;
	item def AlarmSignal;
	item def ShutdownCommand;

	part def AirCompressor {
		port ambientAirIn {
			in air : AmbientAir;
		}
		port compressedAirOut {
			out compressedAir : CompressedAir;
		}
		port speedCommandPort {
			in command : CompressorSpeedCommand;
		}
		port shutdownPort {
			in command : ShutdownCommand;
		}
		action compressAir;
		state def CompressorOperationalStates;
		state compressorStates : CompressorOperationalStates {
			entry; then running;
			state running {
				do action compressAir;
			}
			accept ShutdownCommand then stopped;
			state stopped;
		}
	}

	part def MolecularSieveBed {
		port compressedAirIn {
			in compressedAir : CompressedAir;
		}
		port oxygenOut {
			out oxygen : EnrichedOxygen;
		}
		port wasteOut {
			out waste : WasteNitrogen;
		}
		port adsorbCommandPort {
			in command : SwitchToAdsorption;
		}
		port desorbCommandPort {
			in command : SwitchToDesorption;
		}
		action separateOxygen;
		action releaseNitrogen;
		state def SieveBedCycleStates;
		state bedCycle : SieveBedCycleStates {
			entry; then desorbing;
			state desorbing {
				entry action releaseNitrogen;
			}
			state adsorbing {
				entry action separateOxygen;
			}
			accept SwitchToAdsorption then adsorbing;
			accept SwitchToDesorption then desorbing;
		}
	}

	part def ProductTank {
		port oxygenInletA {
			in oxygen : EnrichedOxygen;
		}
		port oxygenInletB {
			in oxygen : EnrichedOxygen;
		}
		port oxygenOut {
			out oxygen : EnrichedOxygen;
		}
		attribute tankPressure : Real;
		action bufferOxygen;
	}

	part def FlowController {
		port oxygenIn {
			in oxygen : EnrichedOxygen;
		}
		port patientOxygenOut {
			out oxygen : EnrichedOxygen;
		}
		port setpointPort {
			in setpoint : FlowRateSetpoint;
		}
		attribute flowRate : Real;
		action regulateFlow;
		state def FlowControlStates;
		state flowControlState : FlowControlStates {
			entry; then regulating;
			state regulating {
				do action regulateFlow;
			}
		}
	}

	part def OxygenSensor {
		port oxygenSensePort {
			in oxygen : EnrichedOxygen;
		}
		port dataOut {
			out data : OxygenQualityData;
		}
		action senseOxygen;
	}

	part def PSAController {
		port dataIn {
			in data : OxygenQualityData;
		}
		port setpointIn {
			in setpoint : FlowRateSetpoint;
		}
		port compressorCmdOut {
			out command : CompressorSpeedCommand;
		}
		port bed1AdsorbCmd {
			out command : SwitchToAdsorption;
		}
		port bed1DesorbCmd {
			out command : SwitchToDesorption;
		}
		port bed2AdsorbCmd {
			out command : SwitchToAdsorption;
		}
		port bed2DesorbCmd {
			out command : SwitchToDesorption;
		}
		port flowSetpointOut {
			out setpoint : FlowRateSetpoint;
		}
		port alarmIn {
			in alarm : AlarmSignal;
		}
		port shutdownIn {
			in command : ShutdownCommand;
		}
		action controlPSACycle;
		action emergencyShutdown;
		state def PSAControlStates;
		state controlState : PSAControlStates {
			entry; then running;
			state running {
				do action controlPSACycle;
			}
			accept AlarmSignal then alarming;
			state alarming {
				entry action emergencyShutdown;
			}
			accept ShutdownCommand then stopped;
			state stopped;
		}
	}

	part def SafetySystem {
		port dataIn {
			in data : OxygenQualityData;
		}
		port alarmOut {
			out alarm : AlarmSignal;
		}
		port shutdownOut {
			out command : ShutdownCommand;
		}
		attribute purityThreshold : Real;
		attribute maxPressure : Real;
		attribute maxTemperature : Real;
		action monitorVitals;
		state def SafetyMonitoringStates;
		state safetyState : SafetyMonitoringStates {
			entry; then monitoring;
			state monitoring {
				do action monitorVitals;
			}
		}
	}

	part def Patient {
		port oxygenIn {
			in oxygen : EnrichedOxygen;
		}
	}

	part def MedicalOxygenConcentrator {
		port ambientAirInlet {
			in air : AmbientAir;
		}
		port patientOxygenOutlet {
			out oxygen : EnrichedOxygen;
		}
		port wasteVent1 {
			out waste : WasteNitrogen;
		}
		port wasteVent2 {
			out waste : WasteNitrogen;
		}
		port alarmOutput {
			out alarm : AlarmSignal;
		}

		part compressor : AirCompressor;
		part bed1 : MolecularSieveBed;
		part bed2 : MolecularSieveBed;
		part productTank : ProductTank;
		part flowController : FlowController;
		part psaController : PSAController;
		part oxygenSensor : OxygenSensor;
		part safetySystem : SafetySystem;

		bind ambientAirInlet = compressor.ambientAirIn;
		bind patientOxygenOutlet = flowController.patientOxygenOut;
		bind wasteVent1 = bed1.wasteOut;
		bind wasteVent2 = bed2.wasteOut;
		bind alarmOutput = safetySystem.alarmOut;

		flow compressedAirToBed1 of CompressedAir
			from compressor.compressedAirOut.compressedAir to bed1.compressedAirIn.compressedAir;
		flow compressedAirToBed2 of CompressedAir
			from compressor.compressedAirOut.compressedAir to bed2.compressedAirIn.compressedAir;

		flow oxygenFromBed1 of EnrichedOxygen
			from bed1.oxygenOut.oxygen to productTank.oxygenInletA.oxygen;
		flow oxygenFromBed2 of EnrichedOxygen
			from bed2.oxygenOut.oxygen to productTank.oxygenInletB.oxygen;

		flow productToFlowController of EnrichedOxygen
			from productTank.oxygenOut.oxygen to flowController.oxygenIn.oxygen;
		flow productToSensor of EnrichedOxygen
			from productTank.oxygenOut.oxygen to oxygenSensor.oxygenSensePort.oxygen;

		flow sensorDataToController of OxygenQualityData
			from oxygenSensor.dataOut.data to psaController.dataIn.data;
		flow sensorDataToSafety of OxygenQualityData
			from oxygenSensor.dataOut.data to safetySystem.dataIn.data;

		flow compressorSpeedCommand of CompressorSpeedCommand
			from psaController.compressorCmdOut.command to compressor.speedCommandPort.command;

		flow bed1AdsorbCommand of SwitchToAdsorption
			from psaController.bed1AdsorbCmd.command to bed1.adsorbCommandPort.command;
		flow bed1DesorbCommand of SwitchToDesorption
			from psaController.bed1DesorbCmd.command to bed1.desorbCommandPort.command;
		flow bed2AdsorbCommand of SwitchToAdsorption
			from psaController.bed2AdsorbCmd.command to bed2.adsorbCommandPort.command;
		flow bed2DesorbCommand of SwitchToDesorption
			from psaController.bed2DesorbCmd.command to bed2.desorbCommandPort.command;

		flow flowSetpointCommand of FlowRateSetpoint
			from psaController.flowSetpointOut.setpoint to flowController.setpointPort.setpoint;

		flow alarmToController of AlarmSignal
			from safetySystem.alarmOut.alarm to psaController.alarmIn.alarm;
		flow shutdownToController of ShutdownCommand
			from safetySystem.shutdownOut.command to psaController.shutdownIn.command;
		flow shutdownToCompressor of ShutdownCommand
			from safetySystem.shutdownOut.command to compressor.shutdownPort.command;
	}

	requirement def MinimumOxygenPurity {
		doc /* The delivered oxygen purity shall be at least 90 percent under normal operating conditions. */
		subject concentrator : MedicalOxygenConcentrator;
		attribute minPurity : Real = 90.0;
	}

	requirement def SafetyAlarmAndShutdown {
		doc /* The safety system shall trigger an alarm and initiate a shutdown if oxygen purity falls below the safe threshold or if pressure or temperature exceeds operational limits. */
		subject safetySystem : SafetySystem;
		attribute minSafePurity : Real = 85.0;
		attribute maxPressure : Real = 250.0;
		attribute maxTemperature : Real = 80.0;
	}
}
