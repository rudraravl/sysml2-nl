package SlugFlowSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SlugLengthValue :> LengthValue;
	attribute def SlugFrequencyValue :> FrequencyValue;
	attribute def GasVoidFractionValue :> Real;
	attribute def LiquidHoldupValue :> Real;
	attribute def FlowVelocityValue :> SpeedValue;
	attribute def PressureDropValue :> PressureValue;
	
	enum def FlowRegimeType {
		stratifiedFlow;
		slugFlow;
		annularFlow;
		bubbleFlow;
	}
	
	item def GasPhase {
		attribute volumeFraction : GasVoidFractionValue;
		attribute velocity : FlowVelocityValue;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
	}
	
	item def LiquidPhase {
		attribute volumeFraction : LiquidHoldupValue;
		attribute velocity : FlowVelocityValue;
		attribute density : DensityValue;
		attribute viscosity : DynamicViscosityValue;
	}
	
	item def SlugBody {
		attribute length : SlugLengthValue;
		attribute velocity : FlowVelocityValue;
		attribute frequency : SlugFrequencyValue;
		part liquidContent : LiquidPhase;
		part gasContent : GasPhase;
	}
	
	port def MultiphaseInletPort {
		in item gasStream : GasPhase;
		in item liquidStream : LiquidPhase;
		attribute inletPressure : PressureValue;
		attribute inletTemperature : TemperatureValue;
	}
	
	port def MultiphaseOutletPort {
		out item slugStream : SlugBody;
		attribute outletPressure : PressureValue;
		attribute outletTemperature : TemperatureValue;
	}
	
	port def MeasurementPort {
		out attribute measuredPressure : PressureValue;
		out attribute measuredVoidFraction : GasVoidFractionValue;
		out attribute measuredSlugFrequency : SlugFrequencyValue;
		out attribute measuredFlowRegime : FlowRegimeType;
	}
	
	part def PressureTransducer {
		port measurementOutput : MeasurementPort;
		attribute accuracy : Real;
		attribute responseTime : TimeValue;
	}
	
	part def VoidFractionMeter {
		port measurementOutput : MeasurementPort;
		attribute measurementTechnique : String;
	}
	
	part def FlowRegimeIdentifier {
		in attribute voidFraction : GasVoidFractionValue;
		in attribute velocity : FlowVelocityValue;
		in attribute pressure : PressureValue;
		out attribute identifiedRegime : FlowRegimeType;
		
		action identifyRegime {
			in vf : GasVoidFractionValue;
			in vel : FlowVelocityValue;
			out regime : FlowRegimeType;
		}
	}
	
	part def HorizontalPipeline {
		attribute diameter : LengthValue;
		attribute length : LengthValue;
		attribute inclination : Real;
		attribute roughness : LengthValue;
		port inlet : MultiphaseInletPort;
		port outlet : MultiphaseOutletPort;
		
		attribute pressureDrop : PressureDropValue;
	}
	
	part def SlugCatcherVessel {
		attribute vesselVolume : VolumeValue;
		attribute separationEfficiency : Real;
		attribute designPressure : PressureValue;
		port inlet : MultiphaseOutletPort;
		port gasOutlet {
			out item separatedGas : GasPhase;
		}
		port liquidOutlet {
			out item separatedLiquid : LiquidPhase;
		}
	}
	
	part def ThrottleValve {
		attribute openingPercentage : Real;
		attribute flowCoefficient : Real;
		port controlSignal {
			in attribute commandedOpening : Real;
		}
		port fluidInlet : MultiphaseInletPort;
		port fluidOutlet : MultiphaseOutletPort;
	}
	
	part def SlugFlowController {
		ref valve : ThrottleValve;
		ref pressureSensor : PressureTransducer;
		ref voidMeter : VoidFractionMeter;
		ref regimeIdentifier : FlowRegimeIdentifier;
		
		attribute targetPressure : PressureValue;
		attribute maxSlugFrequency : SlugFrequencyValue;
		
		action controlLoop {
			in measuredPressure : PressureValue;
			in measuredVoidFraction : GasVoidFractionValue;
			in measuredSlugFrequency : SlugFrequencyValue;
			in currentRegime : FlowRegimeType;
			out valveCommand : Real;
		}
	}
	
	action def MonitorSlugCharacteristics {
		in currentPressure : PressureValue;
		in currentVoidFraction : GasVoidFractionValue;
		in currentSlugFrequency : SlugFrequencyValue;
		out slugLength : SlugLengthValue;
		out flowRegime : FlowRegimeType;
		out slugVelocity : FlowVelocityValue;
	}
	
	action def DetectSlugFormation {
		in voidFraction : GasVoidFractionValue;
		in velocity : FlowVelocityValue;
		in pressureFluctuation : PressureValue;
		out isSlugPresent : Boolean;
		out slugFrequency : SlugFrequencyValue;
	}
	
	action def ComputePressureDrop {
		in slugLength : SlugLengthValue;
		in slugVelocity : FlowVelocityValue;
		in pipeGeometry : LengthValue;
		in fluidProperties : DensityValue;
		out pressureDrop : PressureDropValue;
	}
	
	action def AdjustValvePosition {
		in measuredPressure : PressureValue;
		in targetPressure : PressureValue;
		in slugFrequency : SlugFrequencyValue;
		in maxAllowableFrequency : SlugFrequencyValue;
		out newValvePosition : Real;
	}
	
	action def ManageSlugFlowOperation {
		first start;
		then merge continuousMonitoring;
		then action monitorCharacteristics : MonitorSlugCharacteristics {
			in currentPressure : PressureValue;
			in currentVoidFraction : GasVoidFractionValue;
			in currentSlugFrequency : SlugFrequencyValue;
			out slugLength : SlugLengthValue;
			out flowRegime : FlowRegimeType;
			out slugVelocity : FlowVelocityValue;
		}
		then action detectSlug : DetectSlugFormation {
			in voidFraction = monitorCharacteristics.currentVoidFraction;
			in velocity = monitorCharacteristics.slugVelocity;
			in pressureFluctuation : PressureValue;
			out isSlugPresent : Boolean;
			out slugFrequency : SlugFrequencyValue;
		}
		then decide;
			if detectSlug.isSlugPresent and monitorCharacteristics.flowRegime == FlowRegimeType::slugFlow then mitigateSlug;
			if not detectSlug.isSlugPresent or monitorCharacteristics.flowRegime != FlowRegimeType::slugFlow then continuousMonitoring;
		action mitigateSlug {
			first action computeDrop : ComputePressureDrop {
				in slugLength = monitorCharacteristics.slugLength;
				in slugVelocity = monitorCharacteristics.slugVelocity;
				in pipeGeometry : LengthValue;
				in fluidProperties : DensityValue;
				out pressureDrop : PressureDropValue;
			}
			then action adjustValve : AdjustValvePosition {
				in measuredPressure = monitorCharacteristics.currentPressure;
				in targetPressure : PressureValue;
				in slugFrequency = detectSlug.slugFrequency;
				in maxAllowableFrequency : SlugFrequencyValue;
				out newValvePosition : Real;
			}
			then continuousMonitoring;
		}
	}
	
	state def SlugFlowOperationalState {
		entry action initializeSystem;
		do action continuousDataAcquisition;
		exit action shutdownSequence;
		
		state normalFlow {
			entry action setNormalParameters;
		}
		
		state slugDetected {
			state lowFrequencySlug;
			state moderateFrequencySlug;
			state highFrequencySlug {
				entry action activateAlarm;
			}
		}
		
		state slugMitigation {
			entry action engageMitigationProtocol;
			do action adjustControlValve;
		}
		
		state systemShutdown;
		
		transition normalToSlugDetected
			first normalFlow
			accept event slugFormationDetected
			then slugDetected;
		
		transition slugDetectedToMitigation
			first slugDetected.highFrequencySlug
			accept event criticalSlugCondition
			then slugMitigation;
		
		transition mitigationToNormal
			first slugMitigation
			accept event slugStabilized
			then normalFlow;
		
		transition anyToShutdown
			first *
			accept event emergencyShutdownSignal
			then systemShutdown;
	}
	
	part def SlugFlowTransportSystem {
		attribute operatingPressure : PressureValue;
		attribute operatingTemperature : TemperatureValue;
		attribute maxAllowableSlugFrequency : SlugFrequencyValue;
		attribute totalPipelineLength : LengthValue;
		
		part inletPipeline : HorizontalPipeline {
			attribute :>> diameter = 0.4 [m];
			attribute :>> length = 500.0 [m];
			attribute :>> inclination = 1.5;
			attribute :>> roughness = 0.00005 [m];
		}
		
		part mainPipeline : HorizontalPipeline {
			attribute :>> diameter = 0.4 [m];
			attribute :>> length = 2000.0 [m];
			attribute :>> inclination = 2.0;
			attribute :>> roughness = 0.00005 [m];
		}
		
		part slugCatcher : SlugCatcherVessel {
			attribute :>> vesselVolume = 75.0 [m^3];
			attribute :>> separationEfficiency = 0.98;
			attribute :>> designPressure = 120.0 [bar];
		}
		
		part throttleValve : ThrottleValve {
			attribute :>> openingPercentage = 75.0;
			attribute :>> flowCoefficient = 150.0;
		}
		
		part upstreamPressureSensor : PressureTransducer {
			attribute :>> accuracy = 0.25;
			attribute :>> responseTime = 0.1 [s];
		}
		
		part downstreamPressureSensor : PressureTransducer {
			attribute :>> accuracy = 0.25;
			attribute :>> responseTime = 0.1 [s];
		}
		
		part voidFractionSensor : VoidFractionMeter {
			attribute :>> measurementTechnique = "gamma-ray densitometry";
		}
		
		part flowRegimeAnalyzer : FlowRegimeIdentifier;
		
		part systemController : SlugFlowController {
			ref valve = throttleValve;
			ref pressureSensor = upstreamPressureSensor;
			ref voidMeter = voidFractionSensor;
			ref regimeIdentifier = flowRegimeAnalyzer;
			attribute :>> targetPressure = 80.0 [bar];
			attribute :>> maxSlugFrequency = 0.3 [Hz];
		}
		
		connect throttleValve.fluidOutlet to inletPipeline.inlet;
		connect inletPipeline.outlet to mainPipeline.inlet;
		connect mainPipeline.outlet to slugCatcher.inlet;
		
		perform action slugFlowManagement : ManageSlugFlowOperation;
		
		exhibit state operationalBehavior : SlugFlowOperationalState;
	}
	
	requirement def SlugFlowControlRequirement {
		doc /* The system shall detect slug flow conditions and maintain slug frequency below specified limits. */
		
		require constraint slugFrequencyLimit {
			slugFlowTransportSystem.maxAllowableSlugFrequency <= 0.5 [Hz]
		}
		
		require constraint pressureStability {
			slugFlowTransportSystem.operatingPressure <= 100.0 [bar]
		}
	}
	
	requirement def SeparationEfficiencyRequirement {
		doc /* The slug catcher shall achieve minimum separation efficiency for gas-liquid phases. */
		
		require constraint minEfficiency {
			slugFlowTransportSystem.slugCatcher.separationEfficiency >= 0.95
		}
	}
	
	requirement def SystemSafetyRequirement {
		doc /* The slug flow system shall prevent pressure surges exceeding design limits and ensure safe operation. */
		
		assume constraint operatingConditions {
			slugFlowTransportSystem.operatingTemperature >= 273.15 [K] and
			slugFlowTransportSystem.operatingTemperature <= 393.15 [K]
		}
		
		require slugControlReq : SlugFlowControlRequirement;
		require separationReq : SeparationEfficiencyRequirement;
	}
	
	requirement <'SFS-001'> primarySystemRequirement {
		doc /* The slug flow transport system shall continuously monitor multiphase flow conditions in horizontal pipelines,
		        detect the formation and propagation of liquid slugs alternating with gas pockets, measure slug characteristics
		        including length and frequency, compute associated pressure drops, and automatically adjust throttle valve
		        positions to mitigate severe slugging while maintaining efficient gas-liquid separation in the slug catcher
		        vessel to ensure safe and stable delivery of separated phases to downstream processing facilities. */
		
		subject slugFlowTransportSystem;
		
		require constraint monitoringCapability {
			slugFlowTransportSystem.upstreamPressureSensor.responseTime <= 0.5 [s] and
			slugFlowTransportSystem.downstreamPressureSensor.responseTime <= 0.5 [s]
		}
		
		require constraint pipelineConfiguration {
			slugFlowTransportSystem.mainPipeline.diameter >= 0.2 [m] and
			slugFlowTransportSystem.totalPipelineLength >= 1000.0 [m]
		}
		
		require constraint vesselCapacity {
			slugFlowTransportSystem.slugCatcher.vesselVolume >= 50.0 [m^3]
		}
		
		require safetyReq : SystemSafetyRequirement;
	}
	
	part slugFlowTransportSystem : SlugFlowTransportSystem {
		attribute :>> operatingPressure = 85.0 [bar];
		attribute :>> operatingTemperature = 323.15 [K];
		attribute :>> maxAllowableSlugFrequency = 0.4 [Hz];
		attribute :>> totalPipelineLength = 2500.0 [m];
		
		satisfy primarySystemRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SlugFlowSystem::*;

    part testSubject : SlugFlowTransportSystem {
        exhibit state operationalBehavior : SlugFlowOperationalState;
    }

    action orchestrator {
        attribute testCurrentPressure : PressureValue;
        attribute testCurrentVoidFraction : GasVoidFractionValue = 0.0;
        attribute testCurrentSlugFrequency : SlugFrequencyValue;
        action actionProbe : MonitorSlugCharacteristics {
            in currentPressure = testCurrentPressure;
            in currentVoidFraction = testCurrentVoidFraction;
            in currentSlugFrequency = testCurrentSlugFrequency;
        }
        first actionProbe;
    }
}
