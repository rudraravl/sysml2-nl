package FlowInjectionAnalysisSystemModel {

	import ScalarValues::*;
	import SI::*;
	import ISQ::*;

	attribute def Volume {
		attribute unitSymbol: String = "mL";
	}
	attribute def FlowRate {
		attribute unitSymbol: String = "mL/min";
	}
	attribute def Pressure {
		attribute unitSymbol: String = "kPa";
	}
	attribute def Temperature {
		attribute unitSymbol: String = "degC";
	}
	attribute def TimeDuration {
		attribute unitSymbol: String = "s";
	}
	attribute def Length {
		attribute unitSymbol: String = "cm";
	}
	attribute def Wavelength {
		attribute unitSymbol: String = "nm";
	}
	attribute def Absorbance {
		attribute unitSymbol: String = "AU";
	}
	attribute def Concentration {
		attribute unitSymbol: String = "mg/L";
	}
	attribute def ElectricalVoltage {
		attribute unitSymbol: String = "V";
	}
	attribute def ElectricalPower {
		attribute unitSymbol: String = "W";
	}
	attribute def DimensionlessRatio {
		attribute unitSymbol: String = "1";
	}

	item def Liquid {
		attribute name: String;
		attribute temperature: Temperature;
		attribute pressure: Pressure;
	}

	item def CarrierStream :> Liquid {
		attribute bufferName: String = "phosphate buffer";
		attribute pH: DimensionlessRatio = 7.20;
		attribute nominalFlow: FlowRate = 1.20;
	}

	item def ReagentStream :> Liquid {
		attribute reagentName: String;
		attribute concentration: Concentration;
		attribute nominalFlow: FlowRate = 0.40;
	}

	item def LiquidSample :> Liquid {
		attribute sampleId: String;
		attribute requestedAnalyte: String;
		attribute sampleVolume: Volume = 2.00;
		attribute expectedConcentration: Concentration;
	}

	item def SamplePlug :> Liquid {
		attribute injectedVolume: Volume = 0.100;
		attribute dispersionRatio: DimensionlessRatio;
		attribute residenceTime: TimeDuration;
	}

	item def ReactionMixture :> Liquid {
		attribute analyteName: String;
		attribute reagentName: String;
		attribute residenceTime: TimeDuration;
		attribute reactedFraction: DimensionlessRatio;
	}

	item def WasteStream :> Liquid {
		attribute containsSample: Boolean;
		attribute containsReagent: Boolean;
	}

	item def OpticalSignal {
		attribute wavelength: Wavelength;
		attribute baselineAbsorbance: Absorbance;
		attribute peakAbsorbance: Absorbance;
		attribute peakArea: Absorbance;
		attribute peakTime: TimeDuration;
	}

	item def AnalysisResult {
		attribute sampleId: String;
		attribute analyteName: String;
		attribute measuredConcentration: Concentration;
		attribute peakAbsorbance: Absorbance;
		attribute methodName: String;
		attribute resultAccepted: Boolean;
		attribute qualityMessage: String;
	}

	item def FIA_Method {
		attribute methodName: String = "colorimetric flow injection analysis";
		attribute analyteName: String;
		attribute injectionVolume: Volume = 0.100;
		attribute carrierFlow: FlowRate = 1.20;
		attribute reagentFlow: FlowRate = 0.40;
		attribute coilLength: Length = 100.0;
		attribute detectorWavelength: Wavelength = 540.0;
		attribute minimumResidenceTime: TimeDuration = 18.0;
		attribute maximumResidenceTime: TimeDuration = 35.0;
	}

	item def StartCommand;
	item def StopCommand;
	item def PrimeCommand;
	item def InjectCommand;
	item def FlushCommand;
	item def CalibrationCommand;
	item def PowerOnCommand;
	item def PowerOffCommand;
	item def FaultDetectedEvent {
		attribute faultCode: String;
		attribute severity: String;
	}

	port def FluidSourcePort {
		out item fluidOut: Liquid;
	}

	port def FluidSinkPort {
		in item fluidIn: Liquid;
	}

	port def FluidTransferPort {
		in item fluidIn: Liquid;
		out item fluidOut: Liquid;
	}

	port def SampleInputPort {
		in item sampleIn: LiquidSample;
	}

	port def WasteInputPort {
		in item wasteIn: WasteStream;
	}

	port def OpticalSignalPort {
		out item signalOut: OpticalSignal;
	}

	port def ResultPort {
		out item resultOut: AnalysisResult;
	}

	port def CommandPort {
		in item start: StartCommand;
		in item stop: StopCommand;
		in item prime: PrimeCommand;
		in item inject: InjectCommand;
		in item flush: FlushCommand;
		in item calibrate: CalibrationCommand;
	}

	port def ElectricalPowerInPort {
		in item voltage: ElectricalVoltage;
		in item power: ElectricalPower;
	}

	port def ElectricalPowerOutPort {
		out item voltage: ElectricalVoltage;
		out item power: ElectricalPower;
	}

	port def DigitalControlPort {
		in item command: String;
		out item status: String;
	}

	part def CarrierReservoir {
		attribute capacity: Volume = 500.0;
		attribute workingVolume: Volume = 350.0;
		attribute minimumAllowedVolume: Volume = 50.0;
		part containedCarrier: CarrierStream;
		port outlet: FluidSourcePort;
		port refill: FluidSinkPort;
	}

	part def ReagentReservoir {
		attribute capacity: Volume = 250.0;
		attribute workingVolume: Volume = 150.0;
		attribute minimumAllowedVolume: Volume = 25.0;
		part containedReagent: ReagentStream;
		port outlet: FluidSourcePort;
		port refill: FluidSinkPort;
	}

	part def SampleIntroductionPort {
		attribute maximumSampleVialVolume: Volume = 10.0;
		attribute requiredMinimumSampleVolume: Volume = 1.0;
		port sampleIn: SampleInputPort;
		port sampleOut: FluidSourcePort;
	}

	part def PeristalticPump {
		attribute carrierChannelFlow: FlowRate = 1.20;
		attribute reagentChannelFlow: FlowRate = 0.40;
		attribute maximumBackPressure: Pressure = 250.0;
		attribute speedCommandPercent: DimensionlessRatio = 55.0;
		port carrierIn: FluidSinkPort;
		port carrierOut: FluidSourcePort;
		port reagentIn: FluidSinkPort;
		port reagentOut: FluidSourcePort;
		port control: DigitalControlPort;
		port powerIn: ElectricalPowerInPort;
	}

	part def SixPortInjectionValve {
		attribute loopVolume: Volume = 0.100;
		attribute switchingTime: TimeDuration = 0.50;
		attribute valvePosition: String = "load";
		port carrierIn: FluidSinkPort;
		port carrierOut: FluidSourcePort;
		port sampleIn: FluidSinkPort;
		port sampleWasteOut: FluidSourcePort;
		port injectedPlugOut: FluidSourcePort;
		port control: DigitalControlPort;
		port powerIn: ElectricalPowerInPort;
	}

	part def ConfluenceMixer {
		attribute internalVolume: Volume = 0.030;
		attribute mixingEfficiency: DimensionlessRatio = 0.95;
		port carrierSampleIn: FluidSinkPort;
		port reagentIn: FluidSinkPort;
		port mixtureOut: FluidSourcePort;
	}

	part def ReactionCoil {
		attribute internalDiameter: Length = 0.080;
		attribute length: Length = 100.0;
		attribute internalVolume: Volume = 0.500;
		attribute nominalResidenceTime: TimeDuration = 22.5;
		attribute controlledTemperature: Temperature = 25.0;
		port inlet: FluidSinkPort;
		port outlet: FluidSourcePort;
	}

	part def AbsorbanceDetector {
		attribute wavelength: Wavelength = 540.0;
		attribute opticalPathLength: Length = 1.00;
		attribute baselineNoise: Absorbance = 0.002;
		attribute linearRangeMinimum: Absorbance = 0.010;
		attribute linearRangeMaximum: Absorbance = 1.800;
		port flowCellIn: FluidSinkPort;
		port flowCellOut: FluidSourcePort;
		port signal: OpticalSignalPort;
		port control: DigitalControlPort;
		port powerIn: ElectricalPowerInPort;
	}

	part def WasteReservoir {
		attribute capacity: Volume = 1000.0;
		attribute currentVolume: Volume = 0.0;
		attribute highLevelLimit: Volume = 850.0;
		port inlet: WasteInputPort;
	}

	part def PowerSupply {
		attribute inputVoltage: ElectricalVoltage = 120.0;
		attribute dcOutputVoltage: ElectricalVoltage = 24.0;
		attribute ratedPower: ElectricalPower = 90.0;
		port pumpPower: ElectricalPowerOutPort;
		port valvePower: ElectricalPowerOutPort;
		port detectorPower: ElectricalPowerOutPort;
		port controllerPower: ElectricalPowerOutPort;
	}

	part def EmbeddedController {
		attribute firmwareVersion: String = "FIA-CTRL-2.4";
		attribute analysisCycleTime: TimeDuration = 65.0;
		attribute maximumQueueLength: Integer = 40;
		port operatorCommands: CommandPort;
		port pumpControl: DigitalControlPort;
		port valveControl: DigitalControlPort;
		port detectorControl: DigitalControlPort;
		port detectorSignalIn: OpticalSignalPort;
		port resultOut: ResultPort;
		port powerIn: ElectricalPowerInPort;
	}

	part def OperatorInterface {
		attribute displayName: String = "Flow Injection Analysis Console";
		attribute supportsManualPrime: Boolean = true;
		attribute supportsCalibration: Boolean = true;
		port commands: CommandPort;
		port results: ResultPort;
	}

	action def VerifyReady {
		in item method: FIA_Method;
		out item ready: Boolean;
	}

	action def PrimeHydraulicPath {
		in item carrier: CarrierStream;
		in item reagent: ReagentStream;
		out item primedCarrier: CarrierStream;
		out item primedReagent: ReagentStream;
	}

	action def LoadSampleLoop {
		in item sample: LiquidSample;
		out item loadedPlug: SamplePlug;
	}

	action def InjectSamplePlug {
		in item loadedPlug: SamplePlug;
		in item carrier: CarrierStream;
		out item dispersedPlug: SamplePlug;
	}

	action def MergeWithReagent {
		in item dispersedPlug: SamplePlug;
		in item reagent: ReagentStream;
		out item mixture: ReactionMixture;
	}

	action def DevelopReaction {
		in item mixture: ReactionMixture;
		out item developedMixture: ReactionMixture;
	}

	action def MeasureAbsorbancePeak {
		in item developedMixture: ReactionMixture;
		out item measuredSignal: OpticalSignal;
	}

	action def ComputeConcentration {
		in item measuredSignal: OpticalSignal;
		in item method: FIA_Method;
		out item result: AnalysisResult;
	}

	action def FlushToWaste {
		in item residualMixture: ReactionMixture;
		out item waste: WasteStream;
	}

	action def FlowInjectionAnalysisCycle {
		in item submittedSample: LiquidSample;
		in item selectedMethod: FIA_Method;
		out item analyticalResult: AnalysisResult;

		action verifyReady: VerifyReady;
		action primeHydraulics: PrimeHydraulicPath;
		action loadLoop: LoadSampleLoop;
		action injectPlug: InjectSamplePlug;
		action mergeReagent: MergeWithReagent;
		action reactInCoil: DevelopReaction;
		action detectPeak: MeasureAbsorbancePeak;
		action computeResult: ComputeConcentration;
		action flushSystem: FlushToWaste;

		succession verifyReady then primeHydraulics;
		succession primeHydraulics then loadLoop;
		succession loadLoop then injectPlug;
		succession injectPlug then mergeReagent;
		succession mergeReagent then reactInCoil;
		succession reactInCoil then detectPeak;
		succession detectPeak then computeResult;
		succession computeResult then flushSystem;
	}

	state def FIAOperatingStateMachine {
		state poweredOff;
		state standby;
		state priming;
		state ready;
		state loadingSample;
		state injecting;
		state reacting;
		state detecting;
		state computing;
		state flushing;
		state faulted;

		transition initialToOff first poweredOff;
		transition powerOn from poweredOff to standby accept PowerOnCommand;
		transition primeFromStandby from standby to priming accept PrimeCommand;
		transition primingComplete from priming to ready;
		transition startAnalysis from ready to loadingSample accept StartCommand;
		transition sampleLoaded from loadingSample to injecting;
		transition plugInjected from injecting to reacting;
		transition residenceComplete from reacting to detecting;
		transition peakCaptured from detecting to computing;
		transition resultComputed from computing to flushing;
		transition flushComplete from flushing to ready;
		transition stopToStandby from ready to standby accept StopCommand;
		transition detectedFaultFromAny from standby to faulted accept FaultDetectedEvent;
		transition faultDuringRun from reacting to faulted accept FaultDetectedEvent;
		transition faultDuringDetection from detecting to faulted accept FaultDetectedEvent;
		transition powerOffFromStandby from standby to poweredOff accept PowerOffCommand;
	}

	part def FlowInjectionAnalyzer {
		attribute systemName: String = "Automated Flow Injection Analysis System";
		attribute primaryFunctionDescription: String = "Automatically meters a liquid sample into a continuously flowing carrier stream, mixes it with reagent under controlled timing, measures the resulting transient detector peak, and reports analyte concentration.";
		attribute nominalThroughput: String = "55 samples per hour";
		attribute nominalCarrierFlow: FlowRate = 1.20;
		attribute nominalReagentFlow: FlowRate = 0.40;
		attribute nominalInjectionVolume: Volume = 0.100;
		attribute nominalOperatingTemperature: Temperature = 25.0;

		part carrierReservoir: CarrierReservoir;
		part reagentReservoir: ReagentReservoir;
		part samplePort: SampleIntroductionPort;
		part pump: PeristalticPump;
		part injectionValve: SixPortInjectionValve;
		part mixer: ConfluenceMixer;
		part reactionCoil: ReactionCoil;
		part detector: AbsorbanceDetector;
		part wasteReservoir: WasteReservoir;
		part powerSupply: PowerSupply;
		part controller: EmbeddedController;
		part operatorInterface: OperatorInterface;

		port sampleInput: SampleInputPort;
		port resultOutput: ResultPort;
		port commandInput: CommandPort;

		connection carrierFeed connect carrierReservoir.outlet to pump.carrierIn;
		connection carrierPressureLine connect pump.carrierOut to injectionValve.carrierIn;
		connection sampleTransfer connect samplePort.sampleOut to injectionValve.sampleIn;
		connection injectedCarrierLine connect injectionValve.injectedPlugOut to mixer.carrierSampleIn;
		connection reagentFeed connect reagentReservoir.outlet to pump.reagentIn;
		connection reagentPressureLine connect pump.reagentOut to mixer.reagentIn;
		connection mixedStreamLine connect mixer.mixtureOut to reactionCoil.inlet;
		connection detectorFeedLine connect reactionCoil.outlet to detector.flowCellIn;
		connection detectorWasteLine connect detector.flowCellOut to wasteReservoir.inlet;
		connection sampleExcessWasteLine connect injectionValve.sampleWasteOut to wasteReservoir.inlet;

		connection pumpPowerCable connect powerSupply.pumpPower to pump.powerIn;
		connection valvePowerCable connect powerSupply.valvePower to injectionValve.powerIn;
		connection detectorPowerCable connect powerSupply.detectorPower to detector.powerIn;
		connection controllerPowerCable connect powerSupply.controllerPower to controller.powerIn;

		connection controllerPumpLink connect controller.pumpControl to pump.control;
		connection controllerValveLink connect controller.valveControl to injectionValve.control;
		connection controllerDetectorLink connect controller.detectorControl to detector.control;
		connection detectorSignalLink connect detector.signal to controller.detectorSignalIn;
		connection operatorCommandLink connect operatorInterface.commands to controller.operatorCommands;
		connection operatorResultLink connect controller.resultOut to operatorInterface.results;

		perform action analysisCycle: FlowInjectionAnalysisCycle;
		exhibit state operatingState: FIAOperatingStateMachine;
	}

	constraint def ResidenceTimeConstraint {
		in coilVolume: Volume;
		in totalFlow: FlowRate;
		in residenceTime: TimeDuration;
		require residenceTime >= 18.0;
		require residenceTime <= 35.0;
	}

	constraint def DetectorLinearityConstraint {
		in peak: Absorbance;
		in minimumLinearPeak: Absorbance;
		in maximumLinearPeak: Absorbance;
		require peak >= minimumLinearPeak;
		require peak <= maximumLinearPeak;
	}

	constraint def WasteCapacityConstraint {
		in currentWaste: Volume;
		in highLevelLimit: Volume;
		require currentWaste < highLevelLimit;
	}

	requirement def PrimaryFunctionRequirement {
		subject fia: FlowInjectionAnalyzer;
		attribute id: String = "FIA-REQ-001";
		attribute text: String = "The system shall perform flow injection analysis by injecting a defined liquid sample volume into a continuous carrier stream, merging the sample plug with reagent, allowing controlled reaction development, detecting the transient analytical peak, and producing a concentration result for the requested analyte.";
		require constraint {
			fia.nominalInjectionVolume == 0.100 and
			fia.nominalCarrierFlow == 1.20 and
			fia.nominalReagentFlow == 0.40
		}
	}

	requirement def ThroughputRequirement {
		subject fia: FlowInjectionAnalyzer;
		attribute id: String = "FIA-REQ-002";
		attribute text: String = "The system shall complete a normal analysis cycle within 65 seconds after a ready state is established.";
		attribute maximumCycleTime: TimeDuration = 65.0;
		require constraint {
			fia.controller.analysisCycleTime <= maximumCycleTime
		}
	}

	requirement def DetectionRequirement {
		subject fia: FlowInjectionAnalyzer;
		attribute id: String = "FIA-REQ-003";
		attribute text: String = "The detector shall measure absorbance peaks at the configured analytical wavelength while maintaining the peak within the validated linear absorbance range.";
		require constraint {
			fia.detector.wavelength == fia.reactionCoil.controlledTemperature + 515.0 and
			fia.detector.linearRangeMinimum >= 0.010 and
			fia.detector.linearRangeMaximum <= 1.800
		}
	}

	requirement def HydraulicIntegrityRequirement {
		subject fia: FlowInjectionAnalyzer;
		attribute id: String = "FIA-REQ-004";
		attribute text: String = "The hydraulic path shall maintain continuous carrier and reagent flow without exceeding pump back-pressure capability.";
		attribute allowableBackPressure: Pressure = 250.0;
		require constraint {
			fia.pump.maximumBackPressure >= allowableBackPressure
		}
	}

	requirement def WasteContainmentRequirement {
		subject fia: FlowInjectionAnalyzer;
		attribute id: String = "FIA-REQ-005";
		attribute text: String = "The system shall route post-detection liquid and excess sample to a contained waste reservoir and prevent operation above the high-level waste limit.";
		require constraint {
			fia.wasteReservoir.currentVolume < fia.wasteReservoir.highLevelLimit
		}
	}

	part fiaSystem: FlowInjectionAnalyzer;

	requirement primaryFunction: PrimaryFunctionRequirement {
		subject fia = fiaSystem;
	}

	requirement throughput: ThroughputRequirement {
		subject fia = fiaSystem;
	}

	requirement detection: DetectionRequirement {
		subject fia = fiaSystem;
	}

	requirement hydraulicIntegrity: HydraulicIntegrityRequirement {
		subject fia = fiaSystem;
	}

	requirement wasteContainment: WasteContainmentRequirement {
		subject fia = fiaSystem;
	}

	satisfy primaryFunction by fiaSystem;
	satisfy throughput by fiaSystem.controller;
	satisfy detection by fiaSystem.detector;
	satisfy hydraulicIntegrity by fiaSystem.pump;
	satisfy wasteContainment by fiaSystem.wasteReservoir;
}
