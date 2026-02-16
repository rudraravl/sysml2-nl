package 'OmnidirectionalCameraSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ImageResolution {
		attribute width : Integer;
		attribute height : Integer;
	}
	
	attribute def FieldOfView {
		attribute horizontal : Real;
		attribute vertical : Real;
	}
	
	attribute def ExposureTime :> ISQ::TimeValue;
	attribute def FrameRate :> ISQ::FrequencyValue;
	attribute def BitDepth :> Integer;
	
	item def RawImageFrame {
		attribute resolution : ImageResolution;
		attribute timestamp : ISQ::TimeValue;
		attribute sensorId : Integer;
		attribute exposure : ExposureTime;
	}
	
	item def PanoramicImage {
		attribute resolution : ImageResolution;
		attribute fieldOfView : FieldOfView;
		attribute timestamp : ISQ::TimeValue;
		attribute bitDepth : BitDepth;
	}
	
	item def CalibrationData {
		attribute lensDistortion : Real[*];
		attribute sensorAlignment : Real[*];
		attribute colorCorrection : Real[*];
	}
	
	attribute def CaptureCommand;
	attribute def ProcessingComplete;
	attribute def SystemReady;
	
	port def ImageOutputPort {
		out item panoramicOutput : PanoramicImage;
	}
	
	port def ControlInputPort {
		in attribute captureCmd : CaptureCommand;
		out attribute systemStatus : SystemReady;
	}
	
	port def PowerInputPort {
		in attribute powerSupply : ISQ::PowerValue;
	}
	
	part def ImageSensor {
		attribute sensorResolution : ImageResolution;
		attribute sensorFOV : FieldOfView;
		attribute frameRate : FrameRate;
		out item rawImage : RawImageFrame;
		port powerIn : PowerInputPort;
	}
	
	part def ImageProcessor {
		in item rawImages : RawImageFrame[*];
		in attribute calibration : CalibrationData;
		out item stitchedImage : PanoramicImage;
		attribute processingPower : ISQ::PowerValue;
		port powerIn : PowerInputPort;
	}
	
	part def CalibrationModule {
		out attribute calibrationData : CalibrationData;
		attribute lastCalibrationTime : ISQ::TimeValue;
	}
	
	part def StorageUnit {
		in item imageToStore : PanoramicImage;
		attribute capacity : Real;
		attribute usedSpace : Real;
		port powerIn : PowerInputPort;
	}
	
	part def PowerManagementUnit {
		in attribute inputPower : ISQ::PowerValue;
		out attribute sensorPower : ISQ::PowerValue;
		out attribute processorPower : ISQ::PowerValue;
		out attribute storagePower : ISQ::PowerValue;
		attribute efficiency : Real;
	}
	
	action def CaptureSingleFrame {
		in sensorId : Integer;
		in exposureTime : ExposureTime;
		out frame : RawImageFrame;
	}
	
	action def StitchImages {
		in frames : RawImageFrame[*];
		in calibration : CalibrationData;
		out panorama : PanoramicImage;
	}
	
	action def StoreImage {
		in image : PanoramicImage;
		in storageUnit : StorageUnit;
	}
	
	action def CalibrateSystem {
		out calibration : CalibrationData;
	}
	
	action def ValidateImageQuality {
		in image : PanoramicImage;
		out qualityScore : Real;
	}
	
	action def Capture360Panorama {
		in captureCommand : CaptureCommand;
		in calibrationData : CalibrationData;
		out finalPanorama : PanoramicImage;
		
		first start;
		then merge captureLoop;
		
		action captureLoop {
			private attribute collectedFrames : RawImageFrame[*] := ();
			private attribute currentSensor : Integer := 1;
			private attribute totalSensors : Integer := 6;
			
			first merge continueCapture;
			then action captureFrame : CaptureSingleFrame {
				in sensorId = currentSensor;
				in exposureTime = 0.01 [s];
				out frame : RawImageFrame;
			}
			then assign collectedFrames := collectedFrames->including(captureFrame.frame);
			then assign currentSensor := currentSensor + 1;
			then decide;
				if currentSensor <= totalSensors then continueCapture;
				if currentSensor > totalSensors then processImages;
			
			action processImages {
				first action stitch : StitchImages {
					in frames = collectedFrames;
					in calibration = calibrationData;
					out panorama : PanoramicImage;
				}
				then action validate : ValidateImageQuality {
					in image = stitch.panorama;
					out qualityScore : Real;
				}
				then assign finalPanorama := stitch.panorama;
			}
			then done;
		}
		then done;
	}
	
	state def SystemOperationStates {
		entry; then idle;
		
		state idle;
		state calibrating;
		state capturing;
		state processing;
		state storing;
		state error;
		
		transition idle_to_calibrating
			first idle
			accept calibrateCmd
			then calibrating;
		
		transition calibrating_to_idle
			first calibrating
			accept calibrationComplete
			then idle;
		
		transition idle_to_capturing
			first idle
			accept captureCmd
			then capturing;
		
		transition capturing_to_processing
			first capturing
			accept captureComplete
			then processing;
		
		transition processing_to_storing
			first processing
			accept processingComplete
			then storing;
		
		transition storing_to_idle
			first storing
			accept storageComplete
			then idle;
		
		transition any_to_error
			first any
			accept faultDetected
			then error;
		
		transition error_to_idle
			first error
			accept resetCmd
			then idle;
	}
	
	part def OmnidirectionalCamera {
		attribute systemResolution : ImageResolution {
			attribute width = 8192;
			attribute height = 4096;
		}
		
		attribute totalFOV : FieldOfView {
			attribute horizontal = 360.0;
			attribute vertical = 180.0;
		}
		
		attribute operatingFrameRate : FrameRate = 30.0 [Hz];
		attribute imageBitDepth : BitDepth = 12;
		
		port controlPort : ControlInputPort;
		port imagePort : ImageOutputPort;
		port mainPowerPort : PowerInputPort;
		
		part frontSensor : ImageSensor {
			attribute sensorResolution : ImageResolution {
				attribute width = 2048;
				attribute height = 2048;
			}
			attribute sensorFOV : FieldOfView {
				attribute horizontal = 90.0;
				attribute vertical = 90.0;
			}
			attribute frameRate = 30.0 [Hz];
		}
		
		part rightSensor : ImageSensor {
			attribute sensorResolution : ImageResolution {
				attribute width = 2048;
				attribute height = 2048;
			}
			attribute sensorFOV : FieldOfView {
				attribute horizontal = 90.0;
				attribute vertical = 90.0;
			}
			attribute frameRate = 30.0 [Hz];
		}
		
		part backSensor : ImageSensor {
			attribute sensorResolution : ImageResolution {
				attribute width = 2048;
				attribute height = 2048;
			}
			attribute sensorFOV : FieldOfView {
				attribute horizontal = 90.0;
				attribute vertical = 90.0;
			}
			attribute frameRate = 30.0 [Hz];
		}
		
		part leftSensor : ImageSensor {
			attribute sensorResolution : ImageResolution {
				attribute width = 2048;
				attribute height = 2048;
			}
			attribute sensorFOV : FieldOfView {
				attribute horizontal = 90.0;
				attribute vertical = 90.0;
			}
			attribute frameRate = 30.0 [Hz];
		}
		
		part topSensor : ImageSensor {
			attribute sensorResolution : ImageResolution {
				attribute width = 2048;
				attribute height = 2048;
			}
			attribute sensorFOV : FieldOfView {
				attribute horizontal = 90.0;
				attribute vertical = 90.0;
			}
			attribute frameRate = 30.0 [Hz];
		}
		
		part bottomSensor : ImageSensor {
			attribute sensorResolution : ImageResolution {
				attribute width = 2048;
				attribute height = 2048;
			}
			attribute sensorFOV : FieldOfView {
				attribute horizontal = 90.0;
				attribute vertical = 90.0;
			}
			attribute frameRate = 30.0 [Hz];
		}
		
		part processor : ImageProcessor {
			attribute processingPower = 50.0 [W];
		}
		
		part calibration : CalibrationModule {
			attribute lastCalibrationTime = 0.0 [s];
		}
		
		part storage : StorageUnit {
			attribute capacity = 512.0;
			attribute usedSpace = 0.0;
		}
		
		part powerMgmt : PowerManagementUnit {
			attribute inputPower = 100.0 [W];
			attribute efficiency = 0.92;
		}
		
		connection powerDistribution1 : ItemFlow connect mainPowerPort to powerMgmt.inputPower;
		connection powerToSensors1 : ItemFlow connect powerMgmt.sensorPower to frontSensor.powerIn;
		connection powerToSensors2 : ItemFlow connect powerMgmt.sensorPower to rightSensor.powerIn;
		connection powerToSensors3 : ItemFlow connect powerMgmt.sensorPower to backSensor.powerIn;
		connection powerToSensors4 : ItemFlow connect powerMgmt.sensorPower to leftSensor.powerIn;
		connection powerToSensors5 : ItemFlow connect powerMgmt.sensorPower to topSensor.powerIn;
		connection powerToSensors6 : ItemFlow connect powerMgmt.sensorPower to bottomSensor.powerIn;
		connection powerToProcessor : ItemFlow connect powerMgmt.processorPower to processor.powerIn;
		connection powerToStorage : ItemFlow connect powerMgmt.storagePower to storage.powerIn;
		
		connection imageFlow1 : ItemFlow connect frontSensor.rawImage to processor.rawImages;
		connection imageFlow2 : ItemFlow connect rightSensor.rawImage to processor.rawImages;
		connection imageFlow3 : ItemFlow connect backSensor.rawImage to processor.rawImages;
		connection imageFlow4 : ItemFlow connect leftSensor.rawImage to processor.rawImages;
		connection imageFlow5 : ItemFlow connect topSensor.rawImage to processor.rawImages;
		connection imageFlow6 : ItemFlow connect bottomSensor.rawImage to processor.rawImages;
		connection calibrationFlow : ItemFlow connect calibration.calibrationData to processor.calibration;
		connection processedImageFlow : ItemFlow connect processor.stitchedImage to storage.imageToStore;
		connection outputImageFlow : ItemFlow connect processor.stitchedImage to imagePort.panoramicOutput;
		
		perform action capture360[*] ordered references Capture360Panorama {
			in captureCommand = controlPort.captureCmd;
			in calibrationData = calibration.calibrationData;
			out finalPanorama;
		}
		
		exhibit state operationStates : SystemOperationStates;
	}
	
	part omnidirectionalCameraSystem : OmnidirectionalCamera {
		doc /*
		 * The omnidirectional camera system captures a complete 360-degree spherical view
		 * of the surrounding environment by simultaneously acquiring images from six
		 * strategically positioned image sensors covering all spatial directions (front,
		 * back, left, right, top, bottom). The system processes and stitches these
		 * individual sensor images into a single seamless panoramic representation,
		 * providing comprehensive spatial awareness for applications including surveillance,
		 * autonomous vehicle navigation, virtual reality content creation, immersive
		 * photography, and environmental monitoring. The primary function is to deliver
		 * high-resolution, geometrically corrected panoramic imagery with minimal latency
		 * and consistent image quality across all viewing angles.
		 */
	}
	
	requirement def ImageQualityRequirement {
		doc /* The stitched panoramic image shall maintain uniform resolution and color consistency across sensor boundaries with minimal visible seams. */
		
		require constraint {
			omnidirectionalCameraSystem.systemResolution.width >= 8000 and
			omnidirectionalCameraSystem.systemResolution.height >= 4000
		}
	}
	
	requirement def FieldOfViewRequirement {
		doc /* The system shall capture a complete spherical field of view covering 360 degrees horizontally and 180 degrees vertically without blind spots. */
		
		require constraint {
			omnidirectionalCameraSystem.totalFOV.horizontal == 360.0 and
			omnidirectionalCameraSystem.totalFOV.vertical == 180.0
		}
	}
	
	requirement def FrameRateRequirement {
		doc /* The system shall maintain a minimum frame rate of 30 frames per second for real-time panoramic video capture. */
		
		require constraint {
			omnidirectionalCameraSystem.operatingFrameRate >= 30.0 [Hz]
		}
	}
	
	requirement def ProcessingLatencyRequirement {
		doc /* The system shall complete image stitching and produce the final panoramic output within 100 milliseconds of frame capture. */
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The total system power consumption shall not exceed 100 watts during continuous operation. */
		
		require constraint {
			omnidirectionalCameraSystem.powerMgmt.inputPower <= 100.0 [W]
		}
	}
	
	requirement def StorageCapacityRequirement {
		doc /* The system shall provide sufficient storage capacity for at least 2 hours of continuous panoramic video recording at maximum resolution. */
		
		require constraint {
			omnidirectionalCameraSystem.storage.capacity >= 512.0
		}
	}
	
	requirement <'OMN-SYS-001'> systemRequirements {
		doc /* The omnidirectional camera system shall meet all functional, performance, and operational requirements for comprehensive 360-degree environmental capture. */
		
		require ImageQualityRequirement;
		require FieldOfViewRequirement;
		require FrameRateRequirement;
		require ProcessingLatencyRequirement;
		require PowerConsumptionRequirement;
		require StorageCapacityRequirement;
	}
}
