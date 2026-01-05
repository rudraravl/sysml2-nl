package GastroenterologyInstrumentSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def TissueSpecimen {
		attribute specimenId : String;
		attribute tissueType : String;
		attribute collectionTimestamp : Real;
		attribute mass : Real;
	}

	item def VideoSignal {
		attribute frameRate : Real;
		attribute resolution : Real;
		attribute timestamp : Real;
	}

	item def InsufflationGas {
		attribute gasType : String;
		attribute purity : Real;
	}

	item def IrrigationFluid {
		attribute fluidType : String;
		attribute temperature : Real;
	}

	item def ControlCommand {
		attribute commandType : String;
		attribute targetPosition : Real;
	}

	attribute def PressureValue :> ISQ::PressureValue;
	attribute def FlowRateValue :> Real;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def LengthValue :> ISQ::LengthValue;
	attribute def MassValue :> ISQ::MassValue;
	attribute def PowerValue :> ISQ::PowerValue;

	port def VideoOutputPort {
		out item videoStream : VideoSignal;
	}

	port def GasDeliveryPort {
		out item gas : InsufflationGas;
		out attribute pressure : PressureValue;
		out attribute flowRate : FlowRateValue;
	}

	port def FluidDeliveryPort {
		out item fluid : IrrigationFluid;
		out attribute flowRate : FlowRateValue;
	}

	port def InstrumentChannelPort {
		in item command : ControlCommand;
		out item specimen : TissueSpecimen;
	}

	port def LightOutputPort {
		out attribute intensity : PowerValue;
		out attribute colorTemperature : TemperatureValue;
	}

	port def ControlInputPort {
		in item controlSignal : ControlCommand;
	}

	part def EndoscopeInsertion {
		attribute insertionLength : LengthValue;
		attribute outerDiameter : LengthValue;
		attribute flexibility : Real;
		attribute workingChannelDiameter : LengthValue;
		port videoOut : VideoOutputPort;
		port lightIn : ~LightOutputPort;
		port instrumentChannel : InstrumentChannelPort;
		port gasIn : ~GasDeliveryPort;
		port fluidIn : ~FluidDeliveryPort;
	}

	part def VideoProcessor {
		attribute processingCapability : Real;
		attribute enhancementMode : String;
		port videoIn : ~VideoOutputPort;
		port processedVideoOut : VideoOutputPort;
	}

	part def LightSource {
		attribute maxIntensity : PowerValue;
		attribute lightType : String;
		port lightOut : LightOutputPort;
	}

	part def InsufflationUnit {
		attribute maxPressure : PressureValue;
		attribute maxFlowRate : FlowRateValue;
		attribute currentPressure : PressureValue;
		port gasOut : GasDeliveryPort;
	}

	part def IrrigationPump {
		attribute maxFlowRate : FlowRateValue;
		attribute reservoirCapacity : Real;
		port fluidOut : FluidDeliveryPort;
	}

	part def BiopsyForceps {
		attribute jawDiameter : LengthValue;
		attribute cupDepth : LengthValue;
		attribute specimenCapacity : MassValue;
		port instrumentPort : ~InstrumentChannelPort;
	}

	part def DisplayMonitor {
		attribute screenSize : LengthValue;
		attribute displayResolution : Real;
		attribute brightness : PowerValue;
		port videoIn : ~VideoOutputPort;
	}

	part def ControlUnit {
		attribute operatingMode : String;
		port controlOut : ~ControlInputPort;
	}

	requirement def VisualizationQualityRequirement {
		doc /* The system shall provide high-definition visualization with minimum resolution of 1920x1080 pixels */
		subject system : EndoscopySystem;
		require constraint {
			system.displayMonitor.displayResolution >= 1920.0
		}
	}

	requirement def SafeInsufflationRequirement {
		doc /* The insufflation pressure shall not exceed 25 mmHg to prevent patient injury */
		subject insufflator : InsufflationUnit;
	}

	requirement def BiopsySamplingRequirement {
		doc /* The system shall enable collection of tissue specimens with minimum mass of 2 mg */
		subject forceps : BiopsyForceps;
	}

	requirement def SterilityRequirement {
		doc /* All patient-contact components shall maintain sterility throughout the procedure */
		subject system : EndoscopySystem;
	}

	action def IlluminateTissue {
		in targetIntensity : Real;
		out lightDelivered : Real;
	}

	action def CaptureVideo {
		in illumination : Real;
		out videoData : VideoSignal;
	}

	action def ProcessVideo {
		in rawVideo : VideoSignal;
		out enhancedVideo : VideoSignal;
	}

	action def DisplayImage {
		in videoInput : VideoSignal;
	}

	action def InsufflateOrgan {
		in targetPressure : Real;
		out currentPressure : Real;
	}

	action def IrrigateSurface {
		in targetFlowRate : Real;
		out fluidDelivered : Real;
	}

	action def CollectBiopsy {
		in targetLocation : String;
		out specimen : TissueSpecimen;
	}

	action def NavigateEndoscope {
		in targetPosition : String;
		out currentPosition : String;
	}

	state def EndoscopicProcedureStates {
		entry; then initialization;

		state initialization {
			entry; then equipmentCheck;
			state equipmentCheck;
			accept at checkComplete;
			then done;
		}
		then insertion;

		state insertion {
			entry; then advancing;
			state advancing;
			accept at targetReached;
			then done;
		}
		then examination;

		state examination {
			entry; then visualizing;

			state visualizing;
			accept at abnormalityDetected;
			then intervention;

			state intervention;
			accept at interventionComplete;
			then visualizing;

			accept at examinationComplete;
			then done;
		}
		then withdrawal;

		state withdrawal {
			entry; then retracting;
			state retracting;
			accept at fullyRetracted;
			then done;
		}
		then procedureComplete;

		state procedureComplete;
		then done;
	}

	part def EndoscopySystem {
		doc /* A complete gastroenterology endoscopy system for diagnostic and therapeutic procedures.
		       The primary function is to visualize the gastrointestinal tract, enable tissue sampling,
		       and perform therapeutic interventions through minimally invasive techniques. */

		attribute systemId : String;
		attribute operationalStatus : String;

		part insertionTube : EndoscopeInsertion;
		part videoProcessor : VideoProcessor;
		part lightSource : LightSource;
		part insufflator : InsufflationUnit;
		part irrigationPump : IrrigationPump;
		part biopsyForceps : BiopsyForceps;
		part displayMonitor : DisplayMonitor;
		part controlUnit : ControlUnit;

		perform action endoscopicExamination : PerformEndoscopicProcedure;

		connection lightDelivery connect lightSource.lightOut to insertionTube.lightIn;
		connection videoCapture connect insertionTube.videoOut to videoProcessor.videoIn;
		connection videoDisplay connect videoProcessor.processedVideoOut to displayMonitor.videoIn;
		connection gasDelivery connect insufflator.gasOut to insertionTube.gasIn;
		connection fluidDelivery connect irrigationPump.fluidOut to insertionTube.fluidIn;
		connection instrumentAccess connect biopsyForceps.instrumentPort to insertionTube.instrumentChannel;
	}

	action def PerformEndoscopicProcedure {
		first start;
		then merge procedureLoop;

		action illuminate : IlluminateTissue {
			in targetIntensity = 250.0;
			out lightDelivered;
		}

		then action captureVideo : CaptureVideo {
			in illumination = illuminate.lightDelivered;
			out videoData;
		}

		then action processVideo : ProcessVideo {
			in rawVideo = captureVideo.videoData;
			out enhancedVideo;
		}

		then action displayImage : DisplayImage {
			in videoInput = processVideo.enhancedVideo;
		}

		then action navigate : NavigateEndoscope {
			in targetPosition = "duodenum";
			out currentPosition;
		}

		then decide;
			if requiresInsufflation then performInsufflation;
			if requiresIrrigation then performIrrigation;
			if requiresBiopsy then performBiopsy;
			if procedureComplete then finalize;

		action performInsufflation : InsufflateOrgan {
			in targetPressure = 2666.0;
			out currentPressure;
		}
		then procedureLoop;

		action performIrrigation : IrrigateSurface {
			in targetFlowRate = 300.0;
			out fluidDelivered;
		}
		then procedureLoop;

		action performBiopsy {
			first action positionForceps;
			then action collectBiopsy : CollectBiopsy {
				in targetLocation = "gastric antrum";
				out specimen;
			}
			then action retractForceps;
		}
		then procedureLoop;

		action finalize;
		then done;
	}

	occurrence def DiagnosticEndoscopyScenario {
		ref part system : EndoscopySystem;
		ref part physician;
		ref part patient;

		message procedureInitiation
			from physician to system.controlUnit;

		then message lightActivation
			from system.controlUnit to system.lightSource;

		then message videoStreamStart
			from system.insertionTube to system.videoProcessor;

		then message displayActivation
			from system.videoProcessor to system.displayMonitor;

		then message insufflationStart
			from system.controlUnit to system.insufflator;

		then message gasDelivery
			from system.insufflator to system.insertionTube;

		then message biopsyRequest
			from physician to system.controlUnit;

		then message forcepsDeployment
			from system.controlUnit to system.biopsyForceps;

		then message specimenCollection
			from system.biopsyForceps to system.insertionTube;

		then message procedureCompletion
			from system.controlUnit to physician;
	}

	part endoscopySystem : EndoscopySystem {
		attribute systemId = "ENDO-SYS-001";
		attribute operationalStatus = "Active";
	}

	requirement visualizationReq : VisualizationQualityRequirement {
		subject system = endoscopySystem;
	}

	requirement insufflationSafetyReq : SafeInsufflationRequirement {
		subject insufflator = endoscopySystem.insufflator;
	}

	requirement biopsyCapabilityReq : BiopsySamplingRequirement {
		subject forceps = endoscopySystem.biopsyForceps;
	}

	requirement sterilityReq : SterilityRequirement {
		subject system = endoscopySystem;
	}
}
