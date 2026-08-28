package 'Marata Vision System' {
	private import ScalarValues::*;

	item def RawFrame {
		attribute width : Integer = 3840;
		attribute height : Integer = 2160;
		attribute timestamp : Real;
		attribute pixelData : String;
	}

	item def ProcessedFrame {
		attribute frameId : Integer;
		attribute detectedObjects : String;
		attribute motionVectors : String;
		attribute colorCorrected : Boolean;
		attribute edgesDetected : Boolean;
		attribute sourceTimestamp : Real;
	}

	attribute def CameraSettings {
		attribute exposure : Real;
		attribute aperture : Real;
		attribute focus : Real;
	}

	attribute def ProcessingMode {
		attribute edgeDetection : Boolean = false;
		attribute objectTracking : Boolean = false;
		attribute motionVectors : Boolean = false;
		attribute colorCorrection : Boolean = false;
	}

	attribute def SystemStatus {
		attribute operationalState : String;
		attribute performanceLoad : Real;
		attribute currentFrameRate : Real;
		attribute errors : String;
	}

	item def Command;
	item def StartCommand :> Command {
		attribute targetFrameRate : Real;
		attribute processingMode : ProcessingMode;
	}
	item def PauseCommand :> Command;
	item def ResumeCommand :> Command;
	item def ShutdownCommand :> Command;

	part def OpticalSensor {
		port rawFrameOut {
			out rawFrame : RawFrame;
		}
		port controlIn {
			in settings : CameraSettings;
		}
		attribute width : Integer = 3840;
		attribute height : Integer = 2160;
		attribute maxFrameRate : Real = 120.0;
		attribute currentSettings : CameraSettings;
	}

	part def ImageProcessingUnit {
		port rawFrameIn {
			in rawFrame : RawFrame;
		}
		port processedFrameOut {
			out processedFrame : ProcessedFrame;
		}
		port controlIn {
			in mode : ProcessingMode;
		}
		attribute currentMode : ProcessingMode;
	}

	part def SystemController {
		port commandIn {
			in command : Command;
		}
		port statusOut {
			out status : SystemStatus;
		}
		port sensorControlOut {
			out settings : CameraSettings;
		}
		port ipuControlOut {
			out mode : ProcessingMode;
		}
		attribute currentStatus : SystemStatus;
	}

	part def DisplayController {
		port processedFrameIn {
			in processedFrame : ProcessedFrame;
		}
		port displayOut {
			out displaySignal : ProcessedFrame;
		}
		attribute displayWidth : Integer = 3840;
		attribute displayHeight : Integer = 2160;
	}

	part def DataStorageUnit {
		port processedFrameIn {
			in processedFrame : ProcessedFrame;
		}
		attribute capacity : Integer = 1000;
		attribute storedFrames : Integer = 0;
	}

	action def CaptureFrame {
		in settings : CameraSettings;
		out frame : RawFrame;
	}

	action def ProcessFrame {
		in frame : RawFrame;
		in mode : ProcessingMode;
		out processed : ProcessedFrame;
	}

	action def DisplayFrame {
		in processed : ProcessedFrame;
	}

	action def StoreFrame {
		in processed : ProcessedFrame;
	}

	action def CaptureProcessLoop {
		first start;
		then merge continue;
		then action capture : CaptureFrame;
		flow from capture.frame to process.frame;
		then action process : ProcessFrame;
		flow from process.processed to displayFrame.processed;
		flow from process.processed to storeFrame.processed;
		then action displayFrame : DisplayFrame;
		then action storeFrame : StoreFrame;
		then continue;
	}

	action def InitializeSystem;
	action def ShutdownSystem;

	part def MarataVisionSystem {
		part sensor : OpticalSensor;
		part ipu : ImageProcessingUnit;
		part controller : SystemController;
		part display : DisplayController;
		part storage : DataStorageUnit;

		flow rawFrameFlow of RawFrame
			from sensor.rawFrameOut.rawFrame to ipu.rawFrameIn.rawFrame;
		flow processedFrameToDisplay of ProcessedFrame
			from ipu.processedFrameOut.processedFrame to display.processedFrameIn.processedFrame;
		flow processedFrameToStorage of ProcessedFrame
			from ipu.processedFrameOut.processedFrame to storage.processedFrameIn.processedFrame;
		flow sensorControlFlow of CameraSettings
			from controller.sensorControlOut.settings to sensor.controlIn.settings;
		flow ipuControlFlow of ProcessingMode
			from controller.ipuControlOut.mode to ipu.controlIn.mode;

		state operationalStates {
			entry; then standby;

			state standby;
			accept startCmd : StartCommand then initializing;

			state initializing {
				do action initialize : InitializeSystem;
				then operational;
			}

			state operational {
				do CaptureProcessLoop;
			}
			accept pauseCmd : PauseCommand then paused;

			state paused;
			accept resumeCmd : ResumeCommand then operational;

			accept shutdownCmd : ShutdownCommand then shutdown;

			state shutdown {
				do action shutdown : ShutdownSystem;
				then done;
			}
		}
	}

	requirement def VisionSystemRequirements {
		subject system : MarataVisionSystem;

		requirement capture4KVideo {
			doc /* The Optical Sensor shall capture video at 4K resolution (3840x2160). */
			subject sensor : OpticalSensor;
			constraint { sensor.width == 3840 and sensor.height == 2160 }
		}

		requirement support120FPS {
			doc /* The system shall support capture and processing at up to 120 frames per second. */
			subject sensor : OpticalSensor;
			constraint { sensor.maxFrameRate <= 120.0 }
		}

		requirement store1000Frames {
			doc /* The Data Storage Unit shall archive at least 1000 processed frames. */
			subject storage : DataStorageUnit;
			constraint { storage.capacity >= 1000 }
		}

		requirement realTimePipeline {
			doc /* The system shall process frames in a continuous loop: capture, process, display, and store. */
			subject :>> system;
		}

		requirement stateManagement {
			doc /* The system shall support standby, initializing, operational, paused, and shutdown states. */
			subject :>> system;
		}
	}
}
