package CancerVisionGoggles {
	private import ScalarValues::*;

	item def NIRLight;
	item def FluorescenceSignal;
	item def RawVideoFeed;
	item def NormalVideoFeed;
	item def EnhancedVideoFeed;
	item def TumorAnalysisResult {
		attribute confidenceScore : Real;
		attribute resectionMargin : Real;
	}
	item def DigitalOverlay;
	item def CombinedVideoFeed;
	item def ElectricalPower;

	item def StartCalibration;
	item def CalibrationComplete;
	item def PowerOff;

	requirement def LowLatencyRequirement {
		attribute maxLatency : Real;
		constraint { maxLatency <= 20.0 }
	}

	requirement def BatteryLifeRequirement {
		attribute minDuration : Real;
		constraint { minDuration >= 4.0 }
	}

	requirement def DetectionAccuracyRequirement {
		attribute minConfidence : Real;
		constraint { minConfidence > 0.95 }
	}

	part def Surgeon {
		port eyePort { in item combinedVideo : CombinedVideoFeed; }
	}

	part def Patient {
		port surgicalFieldNIRPort { in item nirLight : NIRLight; }
		port fluorEmissionPort { out item fluorSignal : FluorescenceSignal; }
	}

	part def BatteryPack {
		attribute capacity : Real;
		out item power : ElectricalPower;
	}

	part def NIRLightSource {
		in item power : ElectricalPower;
		out item nirLight : NIRLight;
	}

	part def FluorescenceCamera {
		in item power : ElectricalPower;
		in item fluorSignal : FluorescenceSignal;
		out item rawVideo : RawVideoFeed;
		out item normalVideo : NormalVideoFeed;
	}

	part def ImageProcessingUnit {
		in item power : ElectricalPower;
		in item rawVideo : RawVideoFeed;
		out item enhancedVideo : EnhancedVideoFeed;
	}

	part def TumorDetectionEngine {
		in item power : ElectricalPower;
		in item enhancedVideo : EnhancedVideoFeed;
		out item analysisResult : TumorAnalysisResult;
		attribute confidence : Real;
	}

	part def HeadMountedDisplay {
		in item power : ElectricalPower;
		in item normalVideo : NormalVideoFeed;
		in item analysisResult : TumorAnalysisResult;
		out item combinedVideo : CombinedVideoFeed;
		out item overlay : DigitalOverlay;
	}

	part def SystemController {
		in item power : ElectricalPower;
	}

	part def CancerVisionGoggles {
		attribute weight : Real;
		requirement lowLatencyReq : LowLatencyRequirement { :>> maxLatency = 20.0; }
		requirement batteryLifeReq : BatteryLifeRequirement { :>> minDuration = 4.0; }
		requirement detectionAccuracyReq : DetectionAccuracyRequirement { :>> minConfidence = 0.95; }

		port surgicalFieldNIRPort { out item nirLight : NIRLight; }
		port surgicalFieldFluorPort { in item fluorSignal : FluorescenceSignal; }
		port surgeonVisionPort { out item combinedVideo : CombinedVideoFeed; }

		part battery : BatteryPack;
		part nirSource : NIRLightSource;
		part fluorCamera : FluorescenceCamera;
		part ipu : ImageProcessingUnit;
		part tde : TumorDetectionEngine;
		part hmd : HeadMountedDisplay;
		part controller : SystemController;

		flow battery.power to nirSource.power;
		flow battery.power to fluorCamera.power;
		flow battery.power to ipu.power;
		flow battery.power to tde.power;
		flow battery.power to hmd.power;
		flow battery.power to controller.power;

		bind surgicalFieldNIRPort.nirLight = nirSource.nirLight;
		bind surgicalFieldFluorPort.fluorSignal = fluorCamera.fluorSignal;

		flow fluorCamera.rawVideo to ipu.rawVideo;
		flow ipu.enhancedVideo to tde.enhancedVideo;
		flow fluorCamera.normalVideo to hmd.normalVideo;
		flow tde.analysisResult to hmd.analysisResult;

		bind surgeonVisionPort.combinedVideo = hmd.combinedVideo;

		state machine def GogglesStateMachine {
			state standby;
			state calibration;
			state activeImaging;

			transition from standby to calibration accept StartCalibration;
			transition from calibration to activeImaging accept CalibrationComplete;
			transition from activeImaging to standby accept PowerOff;
		}

		part stateMachineBehavior : GogglesStateMachine;
	}

	part gogglesSystem : CancerVisionGoggles {
		ref part surgeon : Surgeon;
		ref part patient : Patient;

		flow surgicalFieldNIRPort.nirLight to patient.surgicalFieldNIRPort.nirLight;
		flow patient.fluorEmissionPort.fluorSignal to surgicalFieldFluorPort.fluorSignal;
		flow surgeonVisionPort.combinedVideo to surgeon.eyePort.combinedVideo;
	}
}
