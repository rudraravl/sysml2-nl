package MedicalFetoscopySystem {
	private import ScalarValues::Real;
	private import ScalarValues::String;

	unit def mmHg;
	unit def mL_per_min;
	unit def lumen;
	unit def watt;
	unit def hertz;
	unit def degreeCelsius;
	unit def pixel;
	unit def ms;

	attribute def Pressure : Real { unit mmHg; }
	attribute def VolumeFlowRate : Real { unit mL_per_min; }
	attribute def LightIntensity : Real { unit lumen; }
	attribute def Power : Real { unit watt; }
	attribute def Frequency : Real { unit hertz; }
	attribute def Temperature : Real { unit degreeCelsius; }
	attribute def PixelCount : Real { unit pixel; }
	attribute def TimeDuration : Real { unit ms; }

	item def Light;
	item def OpticalImage;
	item def VideoStream;
	item def Fluid;
	item def SurgicalTool;
	item def FetalScene;
	item def ControlCommand {
		attribute targetIntensity : LightIntensity;
		attribute gain : Real;
		attribute enhancement : Real;
		attribute irrigationRate : VolumeFlowRate;
		attribute suctionRate : VolumeFlowRate;
	}

	item def StartPreparationSignal;
	item def StartOperatingSignal;
	item def StopOperatingSignal;
	item def CompleteWithdrawalSignal;
	item def EmergencyStopSignal;

	port def LightPort { out item light : Light; }
	port def OpticalImagePort { out item image : OpticalImage; }
	port def VideoPort { out item video : VideoStream; }
	port def ControlCommandPort { out item command : ControlCommand; }
	port def FluidPort { out item fluid : Fluid; }

	action def GenerateLight {
		in intensity : LightIntensity;
		out light : Light;
	}
	action def CaptureOpticalImage {
		in illumination : Light;
		out image : OpticalImage;
	}
	action def ConvertOpticalImageToVideo {
		in image : OpticalImage;
		out video : VideoStream;
	}
	action def ProcessVideoStream {
		in video : VideoStream;
		out processedVideo : VideoStream;
	}
	action def DisplayVideoStream {
		in video : VideoStream;
	}
	action def CirculateAmnioticFluid {
		in irrigationRate : VolumeFlowRate;
		in suctionRate : VolumeFlowRate;
		out irrigatedFluid : Fluid;
		in suctionedFluid : Fluid;
	}
	action def IssueControlCommands {
		in lightSetting : LightIntensity;
		in cameraGain : Real;
		in videoEnhancement : Real;
		in irrigationRate : VolumeFlowRate;
		in suctionRate : VolumeFlowRate;
		out lightCommand : ControlCommand;
		out cameraCommand : ControlCommand;
		out videoCommand : ControlCommand;
		out fluidCommand : ControlCommand;
	}

	part def ObjectiveLens {
		attribute focalLength : Real;
	}
	part def ImagingFiberBundle {
		attribute fiberCount : Real;
	}
	part def WorkingChannel {
		item surgicalTool : SurgicalTool;
	}
	part def ImageSensor {
		attribute resolution : PixelCount;
		attribute frameRate : Frequency;
		attribute sensitivity : Real;
	}
	part def Fetus {
		item scene : FetalScene;
	}

	part def LightSource {
		port lightOut : LightPort;
		port controlIn : ~ControlCommandPort;
		attribute targetIntensity : LightIntensity;
		perform action generate : GenerateLight {
			in intensity = targetIntensity;
			out light = lightOut.light;
		}
	}

	part def Fetoscope {
		port lightIn : ~LightPort;
		port imageOut : OpticalImagePort;
		part objectiveLens : ObjectiveLens;
		part imagingFibers : ImagingFiberBundle;
		part workingChannel : WorkingChannel;
		perform action capture : CaptureOpticalImage {
			in illumination = lightIn.light;
			out image = imageOut.image;
		}
	}

	part def CameraHead {
		port opticalIn : ~OpticalImagePort;
		port videoOut : VideoPort;
		port controlIn : ~ControlCommandPort;
		part imageSensor : ImageSensor;
		perform action convert : ConvertOpticalImageToVideo {
			in image = opticalIn.image;
			out video = videoOut.video;
		}
	}

	part def VideoProcessor {
		port videoIn : ~VideoPort;
		port displayOut : VideoPort;
		port controlIn : ~ControlCommandPort;
		attribute enhancementLevel : Real;
		perform action process : ProcessVideoStream {
			in video = videoIn.video;
			out processedVideo = displayOut.video;
		}
	}

	part def DisplayMonitor {
		port videoIn : ~VideoPort;
		perform action display : DisplayVideoStream {
			in video = videoIn.video;
		}
	}

	part def FluidManagementUnit {
		port irrigationOut : FluidPort;
		port suctionIn : ~FluidPort;
		port controlIn : ~ControlCommandPort;
		attribute irrigationRateSetting : VolumeFlowRate;
		attribute suctionRateSetting : VolumeFlowRate;
		perform action circulate : CirculateAmnioticFluid {
			in irrigationRate = irrigationRateSetting;
			in suctionRate = suctionRateSetting;
			out irrigatedFluid = irrigationOut.fluid;
			in suctionedFluid = suctionIn.fluid;
		}
	}

	part def ControlConsole {
		port lightControlOut : ControlCommandPort;
		port cameraControlOut : ControlCommandPort;
		port videoControlOut : ControlCommandPort;
		port fluidControlOut : ControlCommandPort;
		attribute lightIntensitySetting : LightIntensity;
		attribute cameraGainSetting : Real;
		attribute videoEnhancementSetting : Real;
		attribute irrigationRateSetting : VolumeFlowRate;
		attribute suctionRateSetting : VolumeFlowRate;
		perform action issueCommands : IssueControlCommands {
			in lightSetting = lightIntensitySetting;
			in cameraGain = cameraGainSetting;
			in videoEnhancement = videoEnhancementSetting;
			in irrigationRate = irrigationRateSetting;
			in suctionRate = suctionRateSetting;
			out lightCommand = lightControlOut.command;
			out cameraCommand = cameraControlOut.command;
			out videoCommand = videoControlOut.command;
			out fluidCommand = fluidControlOut.command;
		}
	}

	part def Uterus {
		port irrigationIn : ~FluidPort;
		port suctionOut : FluidPort;
		part fetus : Fetus;
		item amnioticFluid : Fluid;
		attribute intrauterinePressure : Pressure;
	}

	state def FetoscopySystemStates {
		entry; then standby;
		state standby;
		transition standby_to_preparing
			first standby
			accept StartPreparationSignal
			then preparing;
		state preparing;
		transition preparing_to_operating
			first preparing
			accept StartOperatingSignal
			then operating;
		state operating;
		transition operating_to_withdrawing
			first operating
			accept StopOperatingSignal
			then withdrawing;
		state withdrawing;
		transition withdrawing_to_standby
			first withdrawing
			accept CompleteWithdrawalSignal
			then standby;
		transition operating_to_standby_emergency
			first operating
			accept EmergencyStopSignal
			then standby;
	}

	requirement def RealTimeVisualizationRequirement {
		doc /* The system shall provide real-time high-definition video to the surgical team. */
		attribute minFrameRate : Frequency;
		attribute maxLatency : TimeDuration;
	}
	requirement def SafeIntrauterinePressureRequirement {
		doc /* The fluid management unit shall maintain intrauterine pressure within safe limits. */
		attribute minPressure : Pressure;
		attribute maxPressure : Pressure;
	}
	requirement def ClearFieldOfViewRequirement {
		doc /* The fluid circulation shall keep the surgical field clear of debris. */
		attribute maxDebrisSize : Real;
	}
	requirement def UserControlRequirement {
		doc /* The surgeon shall be able to adjust light, camera, video, and fluid settings from the control console. */
	}
	requirement def OperationalStatesRequirement {
		doc /* The system shall support standby, preparation/calibration, operating, and safe withdrawal states. */
	}

	requirement realTimeVisualization : RealTimeVisualizationRequirement;
	requirement safeIntrauterinePressure : SafeIntrauterinePressureRequirement;
	requirement clearFieldOfView : ClearFieldOfViewRequirement;
	requirement userControl : UserControlRequirement;
	requirement operationalStates : OperationalStatesRequirement;

	part context {
		part lightSource : LightSource;
		part fetoscope : Fetoscope;
		part cameraHead : CameraHead;
		part videoProcessor : VideoProcessor;
		part displayMonitor : DisplayMonitor;
		part fluidManagementUnit : FluidManagementUnit;
		part controlConsole : ControlConsole;
		part uterus : Uterus;

		flow from lightSource.lightOut.light to fetoscope.lightIn.light;
		flow from fetoscope.imageOut.image to cameraHead.opticalIn.image;
		flow from cameraHead.videoOut.video to videoProcessor.videoIn.video;
		flow from videoProcessor.displayOut.video to displayMonitor.videoIn.video;

		flow from controlConsole.lightControlOut.command to lightSource.controlIn.command;
		flow from controlConsole.cameraControlOut.command to cameraHead.controlIn.command;
		flow from controlConsole.videoControlOut.command to videoProcessor.controlIn.command;
		flow from controlConsole.fluidControlOut.command to fluidManagementUnit.controlIn.command;

		flow from fluidManagementUnit.irrigationOut.fluid to uterus.irrigationIn.fluid;
		flow from uterus.suctionOut.fluid to fluidManagementUnit.suctionIn.fluid;

		state systemState : FetoscopySystemStates;

		satisfy realTimeVisualization by displayMonitor;
		satisfy safeIntrauterinePressure by fluidManagementUnit;
		satisfy clearFieldOfView by fluidManagementUnit;
		satisfy userControl by controlConsole;
		satisfy operationalStates by systemState;
	}
}
