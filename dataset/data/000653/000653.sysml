package 'Urology Instruments System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def IrrigationFluid {
		attribute volume : VolumeValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute pressure : PressureValue;
	}

	item def OpticalSignal {
		attribute intensity : LuminousIntensityValue;
		attribute wavelength : LengthValue;
	}

	item def VideoSignal {
		attribute resolution : Integer;
		attribute frameRate : Real;
		attribute brightness : Real;
	}

	item def TissueSample {
		attribute mass : MassValue;
		attribute length : LengthValue;
	}

	port def FluidInputPort {
		in item fluid : IrrigationFluid;
	}

	port def FluidOutputPort {
		out item fluid : IrrigationFluid;
	}

	port def OpticalInputPort {
		in item light : OpticalSignal;
	}

	port def OpticalOutputPort {
		out item light : OpticalSignal;
	}

	port def VideoOutputPort {
		out item video : VideoSignal;
	}

	port def VideoInputPort {
		in item video : VideoSignal;
	}

	port def ControlPort {
		in attribute flowCommand : VolumeFlowRateValue;
		in attribute pressureCommand : PressureValue;
		out attribute currentFlow : VolumeFlowRateValue;
		out attribute currentPressure : PressureValue;
	}

	part def FluidReservoir {
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		port fluidOut : FluidOutputPort;
	}

	part def IrrigationPump {
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute maxPressure : PressureValue;
		port fluidIn : FluidInputPort;
		port fluidOut : FluidOutputPort;
		port control : ControlPort;
	}

	part def LightSource {
		attribute intensity : LuminousIntensityValue;
		attribute colorTemperature : ThermodynamicTemperatureValue;
		port lightOut : OpticalOutputPort;
	}

	part def FiberOpticBundle {
		attribute fiberCount : Integer;
		attribute transmissionEfficiency : Real;
		port lightIn : OpticalInputPort;
		port lightOut : OpticalOutputPort;
	}

	part def CameraHead {
		attribute sensorResolution : Integer;
		attribute sensitivity : Real;
		port opticalIn : OpticalInputPort;
		port videoOut : VideoOutputPort;
	}

	part def VideoProcessor {
		attribute processingMode : String;
		port videoIn : VideoInputPort;
		port videoOut : VideoOutputPort;
	}

	part def DisplayMonitor {
		attribute screenSize : LengthValue;
		attribute resolution : Integer;
		port videoIn : VideoInputPort;
	}

	part def CystoscopeSheath {
		attribute outerDiameter : LengthValue;
		attribute workingLength : LengthValue;
		port fluidChannel : FluidInputPort;
		port opticalChannel : OpticalInputPort;
	}

	part def BiopsyForceps {
		attribute jawSize : LengthValue;
		attribute cupDepth : LengthValue;
	}

	part def ControlConsole {
		attribute operatingMode : String;
		port pumpControl : ControlPort;
	}

	action def InitializeSystem {
		in attribute targetPressure : PressureValue;
		in attribute targetFlowRate : VolumeFlowRateValue;
		out attribute systemReady : Boolean;
	}

	action def MonitorFluidParameters {
		in attribute reservoirLevel : VolumeValue;
		in attribute currentFlow : VolumeFlowRateValue;
		in attribute currentPressure : PressureValue;
		out attribute volumeRemaining : VolumeValue;
		out attribute flowStatus : String;
		out attribute pressureStatus : String;
	}

	action def CaptureImage {
		in attribute illuminationLevel : LuminousIntensityValue;
		in attribute exposureTime : TimeValue;
		out attribute imageData : VideoSignal;
	}

	action def RegulateIrrigation {
		in attribute desiredPressure : PressureValue;
		in attribute desiredFlowRate : VolumeFlowRateValue;
		in attribute measuredPressure : PressureValue;
		in attribute measuredFlowRate : VolumeFlowRateValue;
		out attribute pumpCommand : VolumeFlowRateValue;
		out attribute pressureCommand : PressureValue;
	}

	action def CollectBiopsy {
		in attribute targetDepth : LengthValue;
		in attribute targetLocation : String;
		out attribute sample : TissueSample;
		out attribute collectionSuccess : Boolean;
	}

	state def SystemOperationalStates {
		entry; then standby;

		state standby;

		transition standby_to_initialization
			first standby
			accept StartCommand
			then initialization;

		state initialization {
			entry; then performInitialization;
			action performInitialization : InitializeSystem;
		}

		transition initialization_to_operational
			first initialization
			then operational;

		state operational {
			state fluidManagement {
				entry; then monitorFluid;
				action monitorFluid : MonitorFluidParameters;
			}

			state visualization {
				entry; then captureFrame;
				action captureFrame : CaptureImage;
			}

			state pressureControl {
				entry; then regulateFlow;
				action regulateFlow : RegulateIrrigation;
			}
		}

		transition operational_to_standby
			first operational
			accept StopCommand
			then standby;

		transition operational_to_fault
			first operational
			accept FaultDetected
			then fault;

		state fault;

		transition fault_to_standby
			first fault
			accept ResetCommand
			then standby;
	}

	action def PerformCystoscopyProcedure {
		first start;
		then initializeEquipment;

		action initializeEquipment : InitializeSystem;

		then decide;
		if initializeEquipment.systemReady == true then proceedWithExamination;
		if initializeEquipment.systemReady == false then abortProcedure;

		action proceedWithExamination {
			first activateIllumination;
			action activateIllumination;
			then insertInstrument;
			action insertInstrument;
			then merge continuousMonitoring;
		}

		merge continuousMonitoring;
		then parallel {
			action maintainFluidFlow : MonitorFluidParameters;
			action acquireVideo : CaptureImage;
			action controlPressure : RegulateIrrigation;
		}

		then decide;
		if biopsyRequired == true then performBiopsy;
		if biopsyRequired == false and examinationComplete == false then continuousMonitoring;
		if examinationComplete == true then concludeExamination;

		action performBiopsy : CollectBiopsy;
		then continuousMonitoring;

		action concludeExamination {
			first withdrawInstrument;
			action withdrawInstrument;
			then stopIrrigation;
			action stopIrrigation;
			then deactivateIllumination;
			action deactivateIllumination;
			then done;
		}

		action abortProcedure;
		then done;

		attribute biopsyRequired : Boolean;
		attribute examinationComplete : Boolean;
	}

	part urologyInstrumentSystem {
		attribute systemIdentifier : String = "Cystoscopy System Model CS-2000";

		part reservoir : FluidReservoir {
			attribute :>> capacity = 3000.0 [SI::mL];
			attribute :>> currentLevel = 3000.0 [SI::mL];
		}

		part pump : IrrigationPump {
			attribute :>> maxFlowRate = 600.0 [SI::mL/SI::min];
			attribute :>> maxPressure = 350.0 [SI::mmHg];
		}

		part lightSource : LightSource {
			attribute :>> intensity = 6000.0 [SI::cd];
			attribute :>> colorTemperature = 5800.0 [SI::K];
		}

		part fiberOptics : FiberOpticBundle {
			attribute :>> fiberCount = 15000;
			attribute :>> transmissionEfficiency = 0.92;
		}

		part camera : CameraHead {
			attribute :>> sensorResolution = 1920;
			attribute :>> sensitivity = 0.85;
		}

		part videoProcessor : VideoProcessor {
			attribute :>> processingMode = "HD Enhancement";
		}

		part monitor : DisplayMonitor {
			attribute :>> screenSize = 27.0 [SI::inch];
			attribute :>> resolution = 1920;
		}

		part cystoscope {
			part sheath : CystoscopeSheath {
				attribute :>> outerDiameter = 7.0 [SI::mm];
				attribute :>> workingLength = 350.0 [SI::mm];
			}

			part forceps : BiopsyForceps {
				attribute :>> jawSize = 3.0 [SI::mm];
				attribute :>> cupDepth = 2.5 [SI::mm];
			}
		}

		part console : ControlConsole {
			attribute :>> operatingMode = "Automatic Pressure Control";
		}

		connection fluidSupplyLine connect reservoir.fluidOut to pump.fluidIn;
		connection fluidDeliveryLine connect pump.fluidOut to cystoscope.sheath.fluidChannel;
		connection pumpControlConnection connect console.pumpControl to pump.control;
		connection illuminationPath connect lightSource.lightOut to fiberOptics.lightIn;
		connection scopeIllumination connect fiberOptics.lightOut to cystoscope.sheath.opticalChannel;
		connection opticalToCamera connect cystoscope.sheath.opticalChannel to camera.opticalIn;
		connection cameraToProcessor connect camera.videoOut to videoProcessor.videoIn;
		connection processorToMonitor connect videoProcessor.videoOut to monitor.videoIn;

		perform action cystoscopyProcedure : PerformCystoscopyProcedure;

		exhibit state operationStateMachine : SystemOperationalStates;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The urology instrument system shall enable minimally invasive visualization and examination 
		        of the urinary tract, including the bladder and urethra, while maintaining controlled fluid 
		        irrigation and providing capability for tissue sampling. */

		subject system : UrologyInstrumentSystem;
	}

	requirement def SafeIrrigationPressureRequirement {
		doc /* The system shall maintain irrigation pressure below maximum safe threshold to prevent 
		        tissue damage and fluid extravasation. */

		subject system : UrologyInstrumentSystem;
	}

	requirement def AdequateFluidReserveRequirement {
		doc /* The system shall monitor fluid reservoir level and alert when volume falls below 
		        minimum safe operating level. */

		subject system : UrologyInstrumentSystem;
	}

	requirement def HighQualityVisualizationRequirement {
		doc /* The system shall provide clear, high-resolution visualization with adequate illumination 
		        for accurate diagnosis and intervention. */

		subject system : UrologyInstrumentSystem;
	}

	requirement def BiopsyCapabilityRequirement {
		doc /* The system shall provide means to collect tissue samples of adequate size for 
		        histopathological analysis when clinically indicated. */

		subject system : UrologyInstrumentSystem;
	}

	part def UrologyInstrumentSystem :> urologyInstrumentSystem;

	requirement primaryFunctionReq : PrimaryFunctionRequirement {
		subject systemInstance = urologyInstrumentSystem;
	}

	requirement safeIrrigationReq : SafeIrrigationPressureRequirement {
		subject systemInstance = urologyInstrumentSystem;
	}

	requirement fluidReserveReq : AdequateFluidReserveRequirement {
		subject systemInstance = urologyInstrumentSystem;
	}

	requirement visualizationReq : HighQualityVisualizationRequirement {
		subject systemInstance = urologyInstrumentSystem;
	}

	requirement biopsyCapabilityReq : BiopsyCapabilityRequirement {
		subject systemInstance = urologyInstrumentSystem;
	}

	satisfy primaryFunctionReq by urologyInstrumentSystem;
	satisfy safeIrrigationReq by urologyInstrumentSystem.pump;
	satisfy fluidReserveReq by urologyInstrumentSystem.reservoir;
	satisfy visualizationReq by urologyInstrumentSystem.lightSource, urologyInstrumentSystem.camera;
	satisfy biopsyCapabilityReq by urologyInstrumentSystem.cystoscope.forceps;
}
