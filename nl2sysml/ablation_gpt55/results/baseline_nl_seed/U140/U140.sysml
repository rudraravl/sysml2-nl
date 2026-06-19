package AirIoniserHighLevelModel {
	import ScalarValues::*;

	attribute def Voltage {
		attribute value : Real;
		attribute unit : String = "V";
	}

	attribute def Current {
		attribute value : Real;
		attribute unit : String = "A";
	}

	attribute def Power {
		attribute value : Real;
		attribute unit : String = "W";
	}

	attribute def Frequency {
		attribute value : Real;
		attribute unit : String = "Hz";
	}

	attribute def AirFlowRate {
		attribute value : Real;
		attribute unit : String = "m^3/s";
	}

	attribute def IonProductionRate {
		attribute value : Real;
		attribute unit : String = "ions/s";
	}

	attribute def IonConcentration {
		attribute value : Real;
		attribute unit : String = "ions/cm^3";
	}

	attribute def OzoneConcentration {
		attribute value : Real;
		attribute unit : String = "ppm";
	}

	attribute def ParticleConcentration {
		attribute value : Real;
		attribute unit : String = "particles/cm^3";
	}

	attribute def Temperature {
		attribute value : Real;
		attribute unit : String = "degC";
	}

	attribute def RelativeHumidity {
		attribute value : Real;
		attribute unit : String = "%";
	}

	attribute def Duration {
		attribute value : Real;
		attribute unit : String = "s";
	}

	attribute def SoundPressureLevel {
		attribute value : Real;
		attribute unit : String = "dBA";
	}

	enum def CommandKind {
		enum powerOn;
		enum powerOff;
		enum setLow;
		enum setMedium;
		enum setHigh;
		enum resetFault;
	}

	enum def OperatingMode {
		enum off;
		enum standby;
		enum purging;
		enum ionisingLow;
		enum ionisingMedium;
		enum ionisingHigh;
		enum fault;
	}

	enum def FaultKind {
		enum none;
		enum overVoltage;
		enum fanStalled;
		enum ozoneLimitExceeded;
		enum emitterContaminated;
		enum coverOpen;
	}

	item def AmbientAir {
		attribute temperature : Temperature;
		attribute relativeHumidity : RelativeHumidity;
		attribute particleConcentration : ParticleConcentration;
		attribute negativeIonConcentration : IonConcentration;
	}

	item def IonisedAir :> AmbientAir {
		attribute addedNegativeIonConcentration : IonConcentration;
		attribute residualOzoneConcentration : OzoneConcentration;
	}

	item def ElectricalEnergy {
		attribute voltage : Voltage;
		attribute current : Current;
		attribute frequency : Frequency;
		attribute availablePower : Power;
	}

	item def UserCommand {
		attribute command : CommandKind;
	}

	item def DeviceStatus {
		attribute mode : OperatingMode;
		attribute fault : FaultKind;
		attribute measuredOzone : OzoneConcentration;
		attribute measuredAirflow : AirFlowRate;
		attribute measuredIonProductionRate : IonProductionRate;
	}

	item def OzoneByproduct {
		attribute concentration : OzoneConcentration;
	}

	port def AirInletPort {
		in item air : AmbientAir;
	}

	port def AirOutletPort {
		out item air : IonisedAir;
	}

	port def AirTransferPort {
		inout item air : AmbientAir;
	}

	port def IonisedAirTransferPort {
		inout item air : IonisedAir;
	}

	port def ElectricalPowerInPort {
		in item energy : ElectricalEnergy;
	}

	port def ElectricalPowerOutPort {
		out item energy : ElectricalEnergy;
	}

	port def ControlInputPort {
		in item command : UserCommand;
	}

	port def StatusOutputPort {
		out item status : DeviceStatus;
	}

	port def ByproductMonitorPort {
		out item ozone : OzoneByproduct;
	}

	part def IntakeFilter {
		attribute filtrationParticleLimit : ParticleConcentration;
		attribute nominalPressureDrop : Real;
		port inlet : AirInletPort;
		port outlet : AirTransferPort;

		action def RemoveCoarseParticles {
			in item unfilteredAir : AmbientAir;
			out item filteredAir : AmbientAir;
		}

		perform action filtering : RemoveCoarseParticles;
	}

	part def AxialFan {
		attribute nominalFlowRate : AirFlowRate;
		attribute lowFlowRate : AirFlowRate;
		attribute mediumFlowRate : AirFlowRate;
		attribute highFlowRate : AirFlowRate;
		attribute acousticNoise : SoundPressureLevel;

		port inlet : AirTransferPort;
		port outlet : AirTransferPort;
		port power : ElectricalPowerInPort;

		action def MoveAir {
			in item inletAir : AmbientAir;
			in item driveEnergy : ElectricalEnergy;
			out item outletAir : AmbientAir;
		}

		perform action movingAir : MoveAir;
	}

	part def HighVoltagePowerSupply {
		attribute inputVoltage : Voltage;
		attribute outputVoltage : Voltage;
		attribute maximumOutputCurrent : Current;
		attribute maximumOutputPower : Power;

		port mainsInput : ElectricalPowerInPort;
		port highVoltageOutput : ElectricalPowerOutPort;

		action def ConvertMainsToHighVoltage {
			in item mainsEnergy : ElectricalEnergy;
			out item highVoltageEnergy : ElectricalEnergy;
		}

		perform action conversion : ConvertMainsToHighVoltage;
	}

	part def CoronaEmitterArray {
		attribute emitterNeedleCount : Integer;
		attribute negativeIonProductionRateLow : IonProductionRate;
		attribute negativeIonProductionRateMedium : IonProductionRate;
		attribute negativeIonProductionRateHigh : IonProductionRate;
		attribute maximumOzoneConcentration : OzoneConcentration;

		port airIn : AirTransferPort;
		port airOut : IonisedAirTransferPort;
		port highVoltageInput : ElectricalPowerInPort;
		port ozoneMonitor : ByproductMonitorPort;

		action def GenerateNegativeIons {
			in item neutralAir : AmbientAir;
			in item highVoltageEnergy : ElectricalEnergy;
			out item ionisedAir : IonisedAir;
			out item ozone : OzoneByproduct;
		}

		perform action ionGeneration : GenerateNegativeIons;
	}

	part def OutletGrille {
		attribute dischargeDiffusionAngle : Real;
		port inlet : IonisedAirTransferPort;
		port outlet : AirOutletPort;

		action def DistributeIonisedAir {
			in item concentratedIonisedAir : IonisedAir;
			out item roomIonisedAir : IonisedAir;
		}

		perform action distribution : DistributeIonisedAir;
	}

	part def AirflowSensor {
		attribute measurementRange : AirFlowRate;
		attribute responseTime : Duration;
		port sampledAir : AirTransferPort;
		port statusOut : StatusOutputPort;

		action def MeasureAirflow {
			in item sampledAirItem : AmbientAir;
			out item status : DeviceStatus;
		}

		perform action airflowMeasurement : MeasureAirflow;
	}

	part def OzoneSensor {
		attribute measurementRange : OzoneConcentration;
		attribute responseTime : Duration;
		port ozoneIn : ByproductMonitorPort;
		port statusOut : StatusOutputPort;

		action def MeasureOzone {
			in item ozoneSample : OzoneByproduct;
			out item status : DeviceStatus;
		}

		perform action ozoneMeasurement : MeasureOzone;
	}

	part def Microcontroller {
		attribute controlLoopPeriod : Duration;
		attribute selectedMode : OperatingMode;
		attribute detectedFault : FaultKind;

		port commandIn : ControlInputPort;
		port fanPowerOut : ElectricalPowerOutPort;
		port highVoltageEnableOut : ElectricalPowerOutPort;
		port statusOut : StatusOutputPort;
		port airflowStatusIn : StatusOutputPort;
		port ozoneStatusIn : StatusOutputPort;

		action def RegulateIoniser {
			in item command : UserCommand;
			in item airflowStatus : DeviceStatus;
			in item ozoneStatus : DeviceStatus;
			out item fanEnergy : ElectricalEnergy;
			out item highVoltageEnergy : ElectricalEnergy;
			out item status : DeviceStatus;
		}

		state def ControllerStates {
			state Off;
			state Standby;
			state Purging;
			state IonisingLow;
			state IonisingMedium;
			state IonisingHigh;
			state Fault;

			transition InitialToOff first Off;
			transition OffToStandby first Off accept UserCommand then Standby;
			transition StandbyToPurge first Standby accept UserCommand then Purging;
			transition PurgeToLow first Purging then IonisingLow;
			transition LowToMedium first IonisingLow accept UserCommand then IonisingMedium;
			transition MediumToHigh first IonisingMedium accept UserCommand then IonisingHigh;
			transition HighToMedium first IonisingHigh accept UserCommand then IonisingMedium;
			transition AnyIonisingToFault first IonisingLow accept DeviceStatus then Fault;
			transition FaultToStandby first Fault accept UserCommand then Standby;
			transition StandbyToOff first Standby accept UserCommand then Off;
		}

		perform action regulation : RegulateIoniser;
		exhibit state controllerState : ControllerStates;
	}

	action def AirIonisationPrimaryFunction {
		in item untreatedRoomAir : AmbientAir;
		in item suppliedElectricalEnergy : ElectricalEnergy;
		in item operatorCommand : UserCommand;
		out item treatedRoomAir : IonisedAir;
		out item operatingStatus : DeviceStatus;

		action filterIncomingAir;
		action moveAirAcrossEmitter;
		action convertPowerToHighVoltage;
		action chargeOxygenAndNitrogenMolecules;
		action disperseNegativeIonsIntoRoom;
		action monitorOzoneAndAirflow;
		action reportStatus;

		succession first filterIncomingAir then moveAirAcrossEmitter;
		succession moveAirAcrossEmitter then chargeOxygenAndNitrogenMolecules;
		succession suppliedElectricalEnergy then convertPowerToHighVoltage;
		succession convertPowerToHighVoltage then chargeOxygenAndNitrogenMolecules;
		succession chargeOxygenAndNitrogenMolecules then disperseNegativeIonsIntoRoom;
		succession disperseNegativeIonsIntoRoom then monitorOzoneAndAirflow;
		succession monitorOzoneAndAirflow then reportStatus;
	}

	part def AirIoniser {
		doc /* Primary high-level function: draw ambient room air through the device, apply controlled high voltage to an emitter array to create negative air ions, mix those ions into the airflow, and discharge ion-enriched air back into the room while monitoring airflow, ozone, and faults. */

		attribute nominalInputVoltage : Voltage;
		attribute nominalInputFrequency : Frequency;
		attribute maximumInputPower : Power;
		attribute standbyPower : Power;
		attribute nominalAirflow : AirFlowRate;
		attribute minimumIonProductionRate : IonProductionRate;
		attribute targetOutletIonConcentration : IonConcentration;
		attribute maximumAllowedOzone : OzoneConcentration;
		attribute purgeTimeBeforeIonising : Duration;
		attribute maximumAcousticNoise : SoundPressureLevel;

		port roomAirIn : AirInletPort;
		port ionisedAirOut : AirOutletPort;
		port mainsPowerIn : ElectricalPowerInPort;
		port userControlIn : ControlInputPort;
		port deviceStatusOut : StatusOutputPort;

		part intakeFilter : IntakeFilter;
		part fan : AxialFan;
		part highVoltageSupply : HighVoltagePowerSupply;
		part emitterArray : CoronaEmitterArray;
		part outletGrille : OutletGrille;
		part airflowSensor : AirflowSensor;
		part ozoneSensor : OzoneSensor;
		part controller : Microcontroller;

		connect roomAirIn to intakeFilter.inlet;
		connect intakeFilter.outlet to fan.inlet;
		connect fan.outlet to emitterArray.airIn;
		connect emitterArray.airOut to outletGrille.inlet;
		connect outletGrille.outlet to ionisedAirOut;

		connect mainsPowerIn to highVoltageSupply.mainsInput;
		connect highVoltageSupply.highVoltageOutput to emitterArray.highVoltageInput;
		connect controller.fanPowerOut to fan.power;
		connect controller.highVoltageEnableOut to highVoltageSupply.mainsInput;

		connect fan.outlet to airflowSensor.sampledAir;
		connect emitterArray.ozoneMonitor to ozoneSensor.ozoneIn;
		connect userControlIn to controller.commandIn;
		connect airflowSensor.statusOut to controller.airflowStatusIn;
		connect ozoneSensor.statusOut to controller.ozoneStatusIn;
		connect controller.statusOut to deviceStatusOut;

		perform action primaryFunction : AirIonisationPrimaryFunction;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The air ioniser shall convert supplied electrical energy and untreated ambient air into discharged ion-enriched air for room conditioning. */
		subject ioniser : AirIoniser;
		require constraint {
			ioniser.minimumIonProductionRate.value >= 2000000.0
		}
	}

	requirement def OzoneSafetyRequirement {
		doc /* The air ioniser shall limit ozone byproduct concentration at the outlet during ionising operation. */
		subject ioniser : AirIoniser;
		require constraint {
			ioniser.maximumAllowedOzone.value <= 0.05
		}
	}

	requirement def AirflowRequirement {
		doc /* The air ioniser shall maintain sufficient airflow to transport generated ions from the emitter array to the room. */
		subject ioniser : AirIoniser;
		require constraint {
			ioniser.nominalAirflow.value >= 0.025
		}
	}

	requirement def LowPowerStandbyRequirement {
		doc /* The air ioniser shall reduce consumption when not ionising. */
		subject ioniser : AirIoniser;
		require constraint {
			ioniser.standbyPower.value <= 1.0
		}
	}

	requirement def AcousticRequirement {
		doc /* The air ioniser shall operate quietly enough for occupied indoor spaces. */
		subject ioniser : AirIoniser;
		require constraint {
			ioniser.maximumAcousticNoise.value <= 35.0
		}
	}

	part householdAirIoniser : AirIoniser {
		:>> nominalInputVoltage.value = 230.0;
		:>> nominalInputVoltage.unit = "V";
		:>> nominalInputFrequency.value = 50.0;
		:>> nominalInputFrequency.unit = "Hz";
		:>> maximumInputPower.value = 12.0;
		:>> maximumInputPower.unit = "W";
		:>> standbyPower.value = 0.8;
		:>> standbyPower.unit = "W";
		:>> nominalAirflow.value = 0.032;
		:>> nominalAirflow.unit = "m^3/s";
		:>> minimumIonProductionRate.value = 2500000.0;
		:>> minimumIonProductionRate.unit = "ions/s";
		:>> targetOutletIonConcentration.value = 1200000.0;
		:>> targetOutletIonConcentration.unit = "ions/cm^3";
		:>> maximumAllowedOzone.value = 0.03;
		:>> maximumAllowedOzone.unit = "ppm";
		:>> purgeTimeBeforeIonising.value = 5.0;
		:>> purgeTimeBeforeIonising.unit = "s";
		:>> maximumAcousticNoise.value = 32.0;
		:>> maximumAcousticNoise.unit = "dBA";
	}

	requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
		subject ioniser = householdAirIoniser;
	}

	requirement ozoneSafetyRequirement : OzoneSafetyRequirement {
		subject ioniser = householdAirIoniser;
	}

	requirement airflowRequirement : AirflowRequirement {
		subject ioniser = householdAirIoniser;
	}

	requirement standbyRequirement : LowPowerStandbyRequirement {
		subject ioniser = householdAirIoniser;
	}

	requirement acousticRequirement : AcousticRequirement {
		subject ioniser = householdAirIoniser;
	}

	satisfy primaryFunctionRequirement by householdAirIoniser;
	satisfy ozoneSafetyRequirement by householdAirIoniser;
	satisfy airflowRequirement by householdAirIoniser;
	satisfy standbyRequirement by householdAirIoniser;
	satisfy acousticRequirement by householdAirIoniser;
}
