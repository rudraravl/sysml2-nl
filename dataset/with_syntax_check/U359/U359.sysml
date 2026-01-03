package PortableOxygenConcentratorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OxygenConcentration :> Real;
	attribute def FlowRateSetting :> Real;
	attribute def BatteryChargeLevel :> Real;
	
	item def AmbientAir {
		attribute oxygenContent : OxygenConcentration;
		attribute nitrogenContent : Real;
		attribute pressure : ISQ::PressureValue;
	}
	
	item def ConcentratedOxygen {
		attribute purity : OxygenConcentration;
		attribute flowRate : ISQ::VolumeFlowRateValue;
		attribute pressure : ISQ::PressureValue;
	}
	
	item def NitrogenWaste {
		attribute nitrogenContent : Real;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::EMLVoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def AirIntakePort {
		in item ambientAir : AmbientAir;
	}
	
	port def OxygenOutputPort {
		out item concentratedOxygen : ConcentratedOxygen;
	}
	
	port def ExhaustPort {
		out item nitrogenWaste : NitrogenWaste;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	part def IntakeFilter {
		port airIn : AirIntakePort;
		port airOut : AirIntakePort;
		attribute filterEfficiency : Real;
	}
	
	part def AirCompressor {
		port airIn : AirIntakePort;
		port powerIn : PowerPort;
		out item compressedAir : AmbientAir;
		attribute compressionRatio : Real;
		attribute operatingPressure : ISQ::PressureValue;
		attribute powerConsumption : ISQ::PowerValue;
	}
	
	part def MolecularSieveAssembly {
		in item compressedAir : AmbientAir;
		out item oxygenRichAir : ConcentratedOxygen;
		out item nitrogenExhaust : NitrogenWaste;
		attribute sieveMaterial : String;
		attribute separationEfficiency : Real;
		attribute cycleTime : ISQ::DurationValue;
	}
	
	part def FlowRegulator {
		in item oxygenRichAir : ConcentratedOxygen;
		out item regulatedOxygen : ConcentratedOxygen;
		in attribute flowSetpoint : FlowRateSetting;
		attribute actualFlowRate : ISQ::VolumeFlowRateValue;
	}
	
	part def OxygenSensor {
		in item oxygenSample : ConcentratedOxygen;
		out attribute purityReading : OxygenConcentration;
		attribute accuracy : Real;
	}
	
	part def PressureSensor {
		in item airSample : AmbientAir;
		out attribute pressureReading : ISQ::PressureValue;
	}
	
	part def FlowSensor {
		in item oxygenSample : ConcentratedOxygen;
		out attribute flowReading : ISQ::VolumeFlowRateValue;
	}
	
	part def BatteryPack {
		port powerOut : PowerPort;
		attribute chargeLevel : BatteryChargeLevel;
		attribute capacity : ISQ::EnergyValue;
		attribute voltage : ISQ::EMLVoltageValue;
		attribute mass : ISQ::MassValue;
	}
	
	part def ACPowerAdapter {
		port acIn : PowerPort;
		port dcOut : PowerPort;
		attribute inputVoltage : ISQ::EMLVoltageValue;
		attribute outputVoltage : ISQ::EMLVoltageValue;
	}
	
	part def ControlModule {
		in attribute oxygenPurity : OxygenConcentration;
		in attribute systemPressure : ISQ::PressureValue;
		in attribute actualFlow : ISQ::VolumeFlowRateValue;
		in attribute batteryLevel : BatteryChargeLevel;
		in attribute userFlowSetting : FlowRateSetting;
		out attribute compressorControl : Real;
		out attribute flowControl : FlowRateSetting;
		out attribute alarmStatus : Boolean;
		attribute operatingMode : OperatingMode;
	}
	
	part def UserInterface {
		out attribute flowSetting : FlowRateSetting;
		in attribute systemStatus : SystemStatus;
		attribute powerButton : Boolean;
		attribute flowAdjustButtons : Real;
		attribute displayScreen : String;
	}
	
	enum def OperatingMode {
		enum standby;
		enum continuous;
		enum pulseMode;
		enum alarm;
		enum shutdown;
	}
	
	attribute def SystemStatus {
		attribute mode : OperatingMode;
		attribute oxygenPurity : OxygenConcentration;
		attribute batteryRemaining : BatteryChargeLevel;
		attribute currentFlow : ISQ::VolumeFlowRateValue;
		attribute alarmActive : Boolean;
	}
	
	part def PortableOxygenConcentrator {
		doc /*
		 * A portable oxygen concentrator extracts oxygen from ambient air and delivers
		 * concentrated medical-grade oxygen to patients requiring respiratory support.
		 * The system operates continuously by compressing ambient air, separating oxygen
		 * from nitrogen using molecular sieves, and delivering regulated oxygen flow.
		 */
		
		port airIntake : AirIntakePort;
		port oxygenOutput : OxygenOutputPort;
		port nitrogenExhaust : ExhaustPort;
		
		part intakeFilter : IntakeFilter {
			attribute redefines filterEfficiency = 0.95;
		}
		
		part compressor : AirCompressor {
			attribute redefines compressionRatio = 2.8;
			attribute redefines operatingPressure = 2.5[SI::'Pa'];
			attribute redefines powerConsumption = 45[SI::'W'];
		}
		
		part sieveAssembly : MolecularSieveAssembly {
			attribute redefines sieveMaterial = "Zeolite";
			attribute redefines separationEfficiency = 0.93;
			attribute redefines cycleTime = 4[SI::'s'];
		}
		
		part flowRegulator : FlowRegulator;
		
		part oxygenSensor : OxygenSensor {
			attribute redefines accuracy = 0.02;
		}
		
		part pressureSensor : PressureSensor;
		
		part flowSensor : FlowSensor;
		
		part battery : BatteryPack {
			attribute redefines capacity = 95[SI::'J'];
			attribute redefines voltage = 12[SI::'V'];
			attribute redefines mass = 0.8[SI::'kg'];
		}
		
		part acAdapter : ACPowerAdapter {
			attribute redefines inputVoltage = 110[SI::'V'];
			attribute redefines outputVoltage = 12[SI::'V'];
		}
		
		part controller : ControlModule;
		
		part userInterface : UserInterface;
		
		connect airIntake to intakeFilter.airIn;
		connect intakeFilter.airOut to compressor.airIn;
		connect battery.powerOut to compressor.powerIn;
		connect acAdapter.dcOut to compressor.powerIn;
		connect compressor.compressedAir to sieveAssembly.compressedAir;
		connect sieveAssembly.oxygenRichAir to flowRegulator.oxygenRichAir;
		connect flowRegulator.regulatedOxygen to oxygenOutput.concentratedOxygen;
		connect sieveAssembly.nitrogenExhaust to nitrogenExhaust.nitrogenWaste;
		connect flowRegulator.regulatedOxygen to oxygenSensor.oxygenSample;
		connect compressor.compressedAir to pressureSensor.airSample;
		connect flowRegulator.regulatedOxygen to flowSensor.oxygenSample;
		
		bind oxygenSensor.purityReading = controller.oxygenPurity;
		bind pressureSensor.pressureReading = controller.systemPressure;
		bind flowSensor.flowReading = controller.actualFlow;
		bind battery.chargeLevel = controller.batteryLevel;
		bind userInterface.flowSetting = controller.userFlowSetting;
		bind controller.flowControl = flowRegulator.flowSetpoint;
		
		perform action operateConcentrator;
		perform action operatingStateMachine;
	}
	
	action def IntakeAmbientAir {
		in ambientAir : AmbientAir;
		out filteredAir : AmbientAir;
	}
	
	action def CompressAir {
		in filteredAir : AmbientAir;
		in compressionPower : ElectricalPower;
		out compressedAir : AmbientAir;
	}
	
	action def SeparateOxygen {
		in compressedAir : AmbientAir;
		out oxygenRichAir : ConcentratedOxygen;
		out nitrogenWaste : NitrogenWaste;
	}
	
	action def RegulateFlow {
		in oxygenRichAir : ConcentratedOxygen;
		in targetFlow : FlowRateSetting;
		out regulatedOxygen : ConcentratedOxygen;
	}
	
	action def MonitorOxygenPurity {
		in oxygenSample : ConcentratedOxygen;
		out purityLevel : OxygenConcentration;
	}
	
	action def MonitorSystemPressure {
		in airSample : AmbientAir;
		out pressureLevel : ISQ::PressureValue;
	}
	
	action def CheckBatteryStatus {
		in batteryLevel : BatteryChargeLevel;
		out batteryOk : Boolean;
	}
	
	action def DeliverOxygen {
		in regulatedOxygen : ConcentratedOxygen;
		out deliveredOxygen : ConcentratedOxygen;
	}
	
	action def OperateConcentrator {
		in ambientAir : AmbientAir;
		in batteryLevel : BatteryChargeLevel;
		in compressionPower : ElectricalPower;
		in targetFlow : FlowRateSetting;
		out deliveredOxygen : ConcentratedOxygen;
	}
	
	action operateConcentrator : OperateConcentrator {
		doc /*
		 * Primary function: Continuously extract oxygen from ambient air and deliver
		 * concentrated medical-grade oxygen at a controlled flow rate to support
		 * patient respiratory therapy. The system monitors oxygen purity, system
		 * pressure, and battery status to ensure safe and effective operation.
		 */
		
		first start;
		then merge continuousOperation;
		
		action intakeAir : IntakeAmbientAir {
			in ambientAir;
			out filteredAir;
		}
		
		then action checkBattery : CheckBatteryStatus {
			in batteryLevel;
			out batteryOk;
		}
		
		then decide;
			if checkBattery.batteryOk then compressAir;
			if !checkBattery.batteryOk then lowBatteryAlarm;
		
		action compressAir : CompressAir {
			in filteredAir = intakeAir.filteredAir;
			in compressionPower;
			out compressedAir;
		}
		
		then action monitorPressure : MonitorSystemPressure {
			in airSample = compressAir.compressedAir;
			out pressureLevel;
		}
		
		then decide;
			if monitorPressure.pressureLevel >= 1.5[SI::'Pa'] and 
			   monitorPressure.pressureLevel <= 3.0[SI::'Pa'] then separateOxygen;
			if monitorPressure.pressureLevel < 1.5[SI::'Pa'] or 
			   monitorPressure.pressureLevel > 3.0[SI::'Pa'] then pressureAlarm;
		
		action separateOxygen : SeparateOxygen {
			in compressedAir = compressAir.compressedAir;
			out oxygenRichAir;
			out nitrogenWaste;
		}
		
		then action monitorPurity : MonitorOxygenPurity {
			in oxygenSample = separateOxygen.oxygenRichAir;
			out purityLevel;
		}
		
		then decide;
			if monitorPurity.purityLevel >= 0.87 then regulateFlow;
			if monitorPurity.purityLevel < 0.87 then purityAlarm;
		
		action regulateFlow : RegulateFlow {
			in oxygenRichAir = separateOxygen.oxygenRichAir;
			in targetFlow;
			out regulatedOxygen;
		}
		
		then action deliverOxygen : DeliverOxygen {
			in regulatedOxygen = regulateFlow.regulatedOxygen;
			out deliveredOxygen;
		}
		
		then continuousOperation;
		
		action lowBatteryAlarm {
			doc /* Alert user of low battery and switch to AC power if available. */
		}
		then done;
		
		action pressureAlarm {
			doc /* Alert user of abnormal system pressure and enter safe mode. */
		}
		then done;
		
		action purityAlarm {
			doc /* Alert user of insufficient oxygen purity and halt delivery. */
		}
		then done;
	}
	
	action def OperatingStateMachine;
	
	action operatingStateMachine : OperatingStateMachine {
		first start;
		then idle;
		
		action idle;
		
		then accept powerOn;
		
		then action starting;
		
		then action running;
		
		then merge runningMerge;
		
		action pulsing;
		
		then runningMerge;
		
		action alarm;
		
		then decide;
			if true then running;
		
		action shutdown;
		
		then idle;
	}
	
	requirement def OxygenPurityRequirement {
		doc /*
		 * The oxygen concentration delivered to the patient shall be at least 87%
		 * at all flow settings from 1 to 5 liters per minute.
		 */
		
		subject oxygenItem : ConcentratedOxygen;
		require constraint {
			oxygenItem.purity >= 0.87
		}
	}
	
	requirement def FlowRateRequirement {
		doc /*
		 * The system shall deliver oxygen at adjustable flow rates from 1 to 5
		 * liters per minute in 0.5 liter increments.
		 */
		
		subject flowRateValue : ISQ::VolumeFlowRateValue;
		require constraint {
			flowRateValue >= 1.0[SI::'m'^3/SI::'s'] and
			flowRateValue <= 5.0[SI::'m'^3/SI::'s']
		}
	}
	
	requirement def BatteryLifeRequirement {
		doc /*
		 * The battery shall provide at least 4 hours of continuous operation
		 * at maximum flow rate (5 L/min).
		 */
		
		subject batteryItem : BatteryPack;
		require constraint {
			batteryItem.capacity >= 95[SI::'J']
		}
	}
	
	requirement def PortabilityRequirement {
		doc /*
		 * The total system mass shall not exceed 2.5 kg to ensure portability
		 * for ambulatory patients.
		 */
		
		subject systemItem : PortableOxygenConcentrator;
		attribute systemMass : ISQ::MassValue;
		require constraint {
			systemMass <= 2.5[SI::'kg']
		}
	}
	
	requirement def NoiseRequirement {
		doc /*
		 * The system shall operate at a noise level not exceeding 45 dBA
		 * at 1 meter distance.
		 */
		
		subject systemItem : PortableOxygenConcentrator;
		attribute noiseLevel : ISQ::SoundPressureLevelValue;
		require constraint {
			noiseLevel <= 45[SI::'dB']
		}
	}
	
	requirement systemRequirements {
		doc /*
		 * Top-level requirements for portable oxygen concentrator system
		 * ensuring safe, effective, and portable oxygen therapy delivery.
		 */
		
		require oxygenPurityReq : OxygenPurityRequirement;
		require flowRateReq : FlowRateRequirement;
		require batteryLifeReq : BatteryLifeRequirement;
		require portabilityReq : PortabilityRequirement;
		require noiseReq : NoiseRequirement;
	}
}
