package 'Transition Edge Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CriticalTemperature :> ThermodynamicTemperatureValue;
	attribute def BiasCurrentValue :> ElectricCurrentValue;
	attribute def ResistanceValue :> ISQ::ElectricResistanceValue;
	attribute def PhotonEnergyValue :> EnergyValue;
	attribute def PulseHeightValue :> ISQ::VoltageValue;
	
	item def PhotonPacket {
		attribute energy : PhotonEnergyValue;
		attribute wavelength : LengthValue;
	}
	
	item def ResistancePulse {
		attribute peakResistance : ResistanceValue;
		attribute riseTime : TimeValue;
		attribute fallTime : TimeValue;
	}
	
	item def VoltagePulse {
		attribute amplitude : PulseHeightValue;
		attribute duration : TimeValue;
	}
	
	item def MeasurementResult {
		attribute photonEnergy : PhotonEnergyValue;
		attribute detectionTime : TimeValue;
		attribute pulseHeight : PulseHeightValue;
	}
	
	item def CalibrationData {
		attribute energyCalibration : Real;
		attribute baselineResistance : ResistanceValue;
	}
	
	port def PhotonInputPort {
		in item photon : PhotonPacket;
	}
	
	port def BiasPort {
		in biasCurrent : BiasCurrentValue;
	}
	
	port def ReadoutPort {
		out item pulse : VoltagePulse;
	}
	
	port def DataPort {
		out item measurement : MeasurementResult;
	}
	
	connection def ThermalConnection {
		end [1] part sensor;
		end [1] part coldStage;
	}
	
	connection def ElectricalReadout {
		end [1] port sensorOutput : ReadoutPort;
		end [1] port amplifierInput;
	}
	
	state def TransitionEdgeSensorStates {
		entry; then initializing;
		
		state initializing;
		
		transition init_to_ready
			first initializing
			accept CalibrationData
			then ready;
		
		state ready;
		
		transition ready_to_detecting
			first ready
			accept PhotonPacket
			then detecting;
		
		state detecting {
			state absorbing;
			state thermalizing;
			state recovering;
			
			entry; then absorbing;
			
			transition absorb_to_thermalize
				first absorbing
				then thermalizing;
			
			transition thermalize_to_recover
				first thermalizing
				then recovering;
			
			transition recover_complete
				first recovering
				then ready;
		}
		
		transition detecting_to_ready
			first detecting
			then ready;
	}
	
	action def AbsorbPhoton {
		in photon : PhotonPacket;
		out temperatureRise : ThermodynamicTemperatureValue;
	}
	
	action def GenerateResistancePulse {
		in temperatureChange : ThermodynamicTemperatureValue;
		in operatingPoint : ResistanceValue;
		out resistancePulse : ResistancePulse;
	}
	
	action def ConvertToVoltage {
		in resistancePulse : ResistancePulse;
		in biasCurrent : BiasCurrentValue;
		out voltagePulse : VoltagePulse;
	}
	
	action def AmplifySignal {
		in inputPulse : VoltagePulse;
		out amplifiedPulse : VoltagePulse;
	}
	
	action def ExtractEnergy {
		in pulse : VoltagePulse;
		in calibration : CalibrationData;
		out energy : PhotonEnergyValue;
	}
	
	action def DetectAndMeasure {
		in item photonInput : PhotonPacket;
		in biasCurrent : BiasCurrentValue;
		in calibration : CalibrationData;
		out item result : MeasurementResult;
		
		action absorb : AbsorbPhoton {
			in photon;
			out temperatureRise;
		}
		
		flow from photonInput to absorb.photon;
		
		then action generatePulse : GenerateResistancePulse {
			in temperatureChange;
			in operatingPoint;
			out resistancePulse;
		}
		
		flow from absorb.temperatureRise to generatePulse.temperatureChange;
		
		then action convertVoltage : ConvertToVoltage {
			in resistancePulse;
			in biasCurrent;
			out voltagePulse;
		}
		
		flow from generatePulse.resistancePulse to convertVoltage.resistancePulse;
		
		then action amplify : AmplifySignal {
			in inputPulse;
			out amplifiedPulse;
		}
		
		flow from convertVoltage.voltagePulse to amplify.inputPulse;
		
		then action extract : ExtractEnergy {
			in pulse;
			in calibration;
			out energy;
		}
		
		flow from amplify.amplifiedPulse to extract.pulse;
		
		bind extract.energy = result.photonEnergy;
	}
	
	part def Cryostat {
		attribute baseTemperature : ThermodynamicTemperatureValue;
		port thermalInterface;
	}
	
	part def TransitionEdgeSensor {
		attribute criticalTemperature : CriticalTemperature;
		attribute normalResistance : ResistanceValue;
		attribute operatingResistance : ResistanceValue;
		attribute thermalConductance : Real;
		attribute heatCapacity : Real;
		
		port photonPort : PhotonInputPort;
		port biasPort : BiasPort;
		port readoutPort : ReadoutPort;
		
		exhibit state behavior : TransitionEdgeSensorStates;
	}
	
	part def SQUIDAmplifier {
		attribute gain : Real;
		attribute inputImpedance : ResistanceValue;
		attribute bandwidth : FrequencyValue;
		
		port signalIn;
		port signalOut;
		
		action amplify : AmplifySignal {
			in inputPulse;
			out amplifiedPulse;
		}
	}
	
	part def SignalProcessor {
		attribute samplingRate : FrequencyValue;
		attribute energyResolution : PhotonEnergyValue;
		
		port pulseIn;
		port dataOut : DataPort;
		
		action process {
			in pulse : VoltagePulse;
			in calibration : CalibrationData;
			out measurement : MeasurementResult;
		}
	}
	
	part def BiasCircuit {
		attribute nominalCurrent : BiasCurrentValue;
		attribute stability : Real;
		
		port biasOut : BiasPort;
	}
	
	part def SensingUnit {
		attribute operatingTemperature : ThermodynamicTemperatureValue default = 0.1[K];
		attribute targetEnergyRange : PhotonEnergyValue default = 1.0[eV];
		
		port photonInput : PhotonInputPort;
		port measurementOutput : DataPort;
		
		part cryostat : Cryostat {
			attribute :>> baseTemperature = 0.05[K];
		}
		
		part tes : TransitionEdgeSensor {
			attribute :>> criticalTemperature = 0.1[K];
			attribute :>> normalResistance = 10.0[ohm];
			attribute :>> operatingResistance = 5.0[ohm];
			attribute :>> thermalConductance = 1.0e-12;
			attribute :>> heatCapacity = 1.0e-15;
		}
		
		part biasCircuit : BiasCircuit {
			attribute :>> nominalCurrent = 10.0[uA];
			attribute :>> stability = 0.001;
		}
		
		part squidAmp : SQUIDAmplifier {
			attribute :>> gain = 1000.0;
			attribute :>> inputImpedance = 1.0[ohm];
			attribute :>> bandwidth = 1.0[MHz];
		}
		
		part processor : SignalProcessor {
			attribute :>> samplingRate = 10.0[MHz];
			attribute :>> energyResolution = 0.01[eV];
		}
		
		connection thermal : ThermalConnection
			connect sensor references tes
			to coldStage references cryostat.thermalInterface;
		
		connection readout : ElectricalReadout
			connect sensorOutput references tes.readoutPort
			to amplifierInput references squidAmp.signalIn;
		
		connect photonInput to tes.photonPort;
		connect biasCircuit.biasOut to tes.biasPort;
		connect squidAmp.signalOut to processor.pulseIn;
		connect processor.dataOut to measurementOutput;
		
		perform action detection : DetectAndMeasure {
			in item :>> photonInput;
			in :>> biasCurrent;
			in :>> calibration;
			out item :>> result;
		}
	}
	
	requirement def TransitionEdgeSensingRequirement {
		doc /* The sensing unit shall measure photon energy using a transition-edge sensor 
		        operating at its superconducting transition temperature. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.tes.criticalTemperature > 0.0[K] and
			unit.tes.criticalTemperature < 1.0[K]
		}
		
		require constraint {
			unit.tes.operatingResistance > 0.0[ohm] and
			unit.tes.operatingResistance < unit.tes.normalResistance
		}
		
		require constraint {
			unit.cryostat.baseTemperature < unit.tes.criticalTemperature
		}
	}
	
	requirement def EnergyResolutionRequirement {
		doc /* The sensing unit shall achieve energy resolution better than 1% of the photon energy. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.processor.energyResolution <= 0.01 * unit.targetEnergyRange
		}
	}
	
	part sensingSystem : SensingUnit;
	
	satisfy sensingSystem satisfies TransitionEdgeSensingRequirement;
	satisfy sensingSystem satisfies EnergyResolutionRequirement;
	
	individual def TestPhotonSource;
	individual def TestSensingUnit :> SensingUnit;
	
	individual testSystem : TestSensingUnit :> sensingSystem {
		timeslice calibration {
			perform action calibrate {
				out cal : CalibrationData {
					:>> energyCalibration = 1.0;
					:>> baselineResistance = 5.0[ohm];
				}
			}
		}
		then timeslice measurement1 {
			perform action :>> detection {
				in item :>> photonInput : PhotonPacket {
					:>> energy = 1.5[eV];
					:>> wavelength = 826.0[nm];
				}
				in :>> biasCurrent = 10.0[uA];
				out item :>> result {
					:>> photonEnergy = 1.5[eV];
					:>> detectionTime = 0.001[s];
					:>> pulseHeight = 50.0[uV];
				}
			}
		}
		then timeslice measurement2 {
			perform action :>> detection {
				in item :>> photonInput : PhotonPacket {
					:>> energy = 2.0[eV];
					:>> wavelength = 620.0[nm];
				}
				in :>> biasCurrent = 10.0[uA];
				out item :>> result {
					:>> photonEnergy = 2.0[eV];
					:>> detectionTime = 0.002[s];
					:>> pulseHeight = 67.0[uV];
				}
			}
		}
	}
}
