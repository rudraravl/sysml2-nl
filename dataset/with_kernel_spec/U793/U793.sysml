package OmniviewSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import Time::TimeInstantValue;
	private import Time::DurationOf;

	item def VideoFrame {
		attribute width : Integer = 3840;
		attribute height : Integer = 2160;
		attribute frameRate : FrequencyValue = 30 [Hz];
		attribute timestamp : TimeInstantValue;
		attribute sensorId : String;
		attribute encoding : String = "RAW";
	}

	item def PanoramicImage {
		attribute timestamp : TimeInstantValue;
		attribute width : Integer = 7680;
		attribute height : Integer = 4320;
		attribute encoding : String = "RAW";
	}

	item def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	item def Velocity3D {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}

	item def DetectedObject {
		attribute trackingId : Integer;
		attribute objectType : String;
		attribute position : Position3D;
		attribute velocity : Velocity3D;
		attribute confidence : Real;
	}

	item def SystemStatus {
		attribute mode : String;
		attribute health : String;
		attribute activeTracks : Integer;
	}

	item def OperatorCommand {
		attribute commandType : String;
	}

	attribute def StartCommand;
	attribute def InitComplete;
	attribute def CalibrationComplete;
	attribute def StopCommand;

	part def OpticalSensor {
		attribute sensorId : String;
		attribute location : String;
		attribute resolution : String = "4K";
		attribute frameRate : FrequencyValue = 30 [Hz];
		out port videoFeed : VideoFrame;
	}

	part def ImageStitchingProcessor {
		in port feed1 : VideoFrame;
		in port feed2 : VideoFrame;
		in port feed3 : VideoFrame;
		in port feed4 : VideoFrame;
		in port feed5 : VideoFrame;
		in port feed6 : VideoFrame;
		in port feed7 : VideoFrame;
		in port feed8 : VideoFrame;
		out port panoramicFeed : PanoramicImage;
		attribute maxDelay : DurationValue = 0.5 [s];
		action stitch {
			in frames : VideoFrame[8];
			out panorama : PanoramicImage;
		}
		constraint { maxDelay <= 0.5 [s] }
	}

	part def ObjectDetectionUnit {
		in port panoramicImage : PanoramicImage;
		out port detectedObjects : DetectedObject[*];
		attribute maxTrackedObjects : Integer = 100;
		attribute minConfidence : Real = 0.85;
		action detect {
			in panorama : PanoramicImage;
			out objects : DetectedObject[*];
		}
		constraint { maxTrackedObjects <= 100 }
	}

	part def DataArchive {
		in port imagery : PanoramicImage[*];
		in port objects : DetectedObject[*];
		attribute retentionPeriod : DurationValue = 720 [h];
		constraint { retentionPeriod >= 720 [h] }
	}

	part def SystemController {
		in port command : OperatorCommand;
		out port status : SystemStatus;
		out port controlSignal : String;
		attribute mode : String = "standby";
		attribute health : String = "nominal";
	}

	part def PowerSupply {
		attribute outputPower : PowerValue = 500 [W];
		out port power : PowerValue;
	}

	state operatingStates {
		in controller : SystemController;
		entry; then standby;
		state standby {
			entry assign controller.mode := "standby";
		}
		accept StartCommand then initializing;
		state initializing {
			entry assign controller.mode := "initializing";
		}
		accept InitComplete then calibrating;
		state calibrating {
			entry assign controller.mode := "calibrating";
			assert constraint { DurationOf(calibrating) < 60 [s] }
		}
		accept CalibrationComplete then activeSurveillance;
		state activeSurveillance {
			entry assign controller.mode := "activeSurveillance";
		}
		accept StopCommand then standby;
	}

	part def OmniviewPlatform {
		part frontSensor : OpticalSensor { attribute location = "front"; attribute sensorId = "S1"; }
		part backSensor : OpticalSensor { attribute location = "back"; attribute sensorId = "S2"; }
		part leftSensor : OpticalSensor { attribute location = "left"; attribute sensorId = "S3"; }
		part rightSensor : OpticalSensor { attribute location = "right"; attribute sensorId = "S4"; }
		part topSensor : OpticalSensor { attribute location = "top"; attribute sensorId = "S5"; }
		part bottomSensor : OpticalSensor { attribute location = "bottom"; attribute sensorId = "S6"; }
		part frontLeftSensor : OpticalSensor { attribute location = "frontLeft"; attribute sensorId = "S7"; }
		part frontRightSensor : OpticalSensor { attribute location = "frontRight"; attribute sensorId = "S8"; }

		part stitcher : ImageStitchingProcessor;
		part detector : ObjectDetectionUnit;
		part archive : DataArchive;
		part controller : SystemController;
		part power : PowerSupply;

		flow frontSensor.videoFeed to stitcher.feed1;
		flow backSensor.videoFeed to stitcher.feed2;
		flow leftSensor.videoFeed to stitcher.feed3;
		flow rightSensor.videoFeed to stitcher.feed4;
		flow topSensor.videoFeed to stitcher.feed5;
		flow bottomSensor.videoFeed to stitcher.feed6;
		flow frontLeftSensor.videoFeed to stitcher.feed7;
		flow frontRightSensor.videoFeed to stitcher.feed8;

		flow stitcher.panoramicFeed to detector.panoramicImage;
		flow stitcher.panoramicFeed to archive.imagery;
		flow detector.detectedObjects to archive.objects;
	}

	part omniview : OmniviewPlatform;

	requirement req_360Coverage {
		doc /* The system shall provide a complete, real-time, 360-degree view of the environment with no blind spots using eight strategically placed optical sensors. */;
	}

	requirement req_stitchingDelay {
		doc /* The image stitching process shall have a total delay of less than half a second. */;
	}

	requirement req_trackingCapacity {
		doc /* The system shall be capable of tracking up to 100 objects simultaneously with high accuracy. */;
	}

	requirement req_archiveRetention {
		doc /* The data archive shall retain all panoramic imagery and detected object lists for at least 30 days. */;
	}

	requirement req_continuousPower {
		doc /* The entire system shall be designed to run continuously, powered by an external source. */;
	}

	satisfy req_360Coverage by omniview;
	satisfy req_stitchingDelay by omniview;
	satisfy req_trackingCapacity by omniview;
	satisfy req_archiveRetention by omniview;
	satisfy req_continuousPower by omniview;
}
