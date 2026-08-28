package DigitalSensingUnit {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types ----------
	value def Illuminance :> Real {
		unit lux;
	}
	
	value def CalibrationFactor :> Real {
		doc { Conversion factor from average intensity to illuminance. }
		unit lux;
	}
	
	value def AverageIntensity :> Real {
		doc { Normalized average pixel intensity, dimensionless in [0,1]. }
	}
	
	value def Confidence :> Real {
		doc { Confidence level in [0,1]. }
	}
	
	value def PixelCount :> Integer;
	value def BitDepth :> Integer;
	value def Timestamp :> String;
	
	// ---------- Item Definitions ----------
	item def RawImage {
		attribute width : PixelCount = 1920;
		attribute height : PixelCount = 1080;
		attribute bitDepth : BitDepth = 12;
		attribute pixelData : List(0..*) List(0..*) Integer;
		attribute captureTime : Timestamp;
	}
	
	item def ProcessedImage {
		attribute width : PixelCount;
		attribute height : PixelCount;
		attribute filteredData : List(0..*) List(0..*) Real;
		attribute averageIntensity : AverageIntensity;
		attribute oversaturated : Boolean;
		attribute valid : Boolean;
		attribute processingTime : Timestamp;
	}
	
	item def MeasurementResult {
		attribute illuminance : Illuminance;
		attribute timestamp : Timestamp;
		attribute confidence : Confidence;
		attribute valid : Boolean;
	}
	
	item def CaptureCommand {
		attribute commandId : String;
		attribute issuedAt : Timestamp;
	}
	
	item def ControlStatus {
		attribute stage : String;
		attribute success : Boolean;
	}
	
	// ---------- Port Definitions ----------
	port def LightInputPort {
		out item light : Real; // incident light intensity (relative)
	}
	
	port def CommandPort {
		out item command : CaptureCommand;
		in item ack : ControlStatus;
	}
	
	port def RawImagePort {
		out item raw : RawImage;
	}
	
	port def ProcessedImagePort {
		out item processed : ProcessedImage;
	}
	
	port def MeasurementPort {
		out item result : MeasurementResult;
	}
	
	port def ControlBusPort {
		out item command : CaptureCommand;
		in item status : ControlStatus;
	}
	
	// ---------- Image Sensor ----------
	part def ImageSensor {
		attribute resolutionWidth : PixelCount = 1920;
		attribute resolutionHeight : PixelCount = 1080;
		attribute adcBitDepth : BitDepth = 12;
		attribute saturationThreshold : AverageIntensity = 0.98;
		
		port lightIn : LightInputPort;
		port cmdIn : CommandPort;
		port rawOut : RawImagePort;
		
		part adc {
			doc { 12-bit analog-to-digital converter. }
			attribute bitDepth : BitDepth = 12;
		}
		
		part pixelArray {
			attribute width : PixelCount = 1920;
			attribute height : PixelCount = 1080;
		}
		
		state machine SensorStateMachine {
			entry; then Idle;
			
			state Idle;
			
			transition from Idle to Capturing
				when cmdIn.command->notEmpty()
				effect { rawOut.raw.captureTime = cmdIn.command.issuedAt; };
			
			state Capturing {
				entry { /* expose pixel array, run ADC */ }
				do { /* sample incident light into pixelData */ }
				then Processing;
			}
			
			state Processing {
				entry { /* assemble RawImage from ADC output */ }
				then Measuring;
			}
			
			state Measuring {
				entry {
					rawOut.raw.width = resolutionWidth;
					rawOut.raw.height = resolutionHeight;
					rawOut.raw.bitDepth = adcBitDepth;
					cmdIn.ack.stage = "captured";
					cmdIn.ack.success = true;
				}
				then Idle;
			}
		}
	}
	
	// ---------- Signal Processor ----------
	part def SignalProcessor {
		attribute noiseReductionStrength : Real = 0.25;
		attribute saturationThreshold : AverageIntensity = 0.98;
		attribute minValidAverage : AverageIntensity = 0.02;
		
		port rawIn : RawImagePort;
		port processedOut : ProcessedImagePort;
		
		action processImage {
			in raw : RawImage;
			out processed : ProcessedImage;
			
			perform action reduceNoise {
				in dataIn : List(0..*) List(0..*) Integer = raw.pixelData;
				out dataOut : List(0..*) List(0..*) Real;
			}
			
			perform action computeAverage {
				in data : List(0..*) List(0..*) Real = reduceNoise.dataOut;
				out avg : AverageIntensity;
			}
			
			perform action validate {
				in avg : AverageIntensity = computeAverage.avg;
				out oversat : Boolean;
				out valid : Boolean;
			}
			
			then action assemble {
				in filtered : List(0..*) List(0..*) Real = reduceNoise.dataOut;
				in avg : AverageIntensity = computeAverage.avg;
				in oversat : Boolean = validate.oversat;
				in valid : Boolean = validate.valid;
				out proc : ProcessedImage = processed;
				effect {
					proc.width = raw.width;
					proc.height = raw.height;
					proc.filteredData = filtered;
					proc.averageIntensity = avg;
					proc.oversaturated = oversat;
					proc.valid = valid;
					proc.processingTime = raw.captureTime;
				}
			}
		}
		
		state machine ProcessorStateMachine {
			entry; then Waiting;
			
			state Waiting;
			
			transition from Waiting to Reducing
				when rawIn.raw->notEmpty();
			
			state Reducing {
				do processImage;
				then Validating;
			}
			
			state Validating {
				entry {
					processedOut.processed.oversaturated =
						(processedOut.processed.averageIntensity >= saturationThreshold);
					processedOut.processed.valid =
						(processedOut.processed.averageIntensity >= minValidAverage
						 and not processedOut.processed.oversaturated);
				}
				then Waiting;
			}
		}
	}
	
	// ---------- Measurement Engine ----------
	part def MeasurementEngine {
		attribute calibrationFactor : CalibrationFactor = 750.0 [lux];
		attribute baseConfidence : Confidence = 0.95;
		attribute oversatPenalty : Confidence = 0.40;
		attribute undersamplePenalty : Confidence = 0.30;
		
		port processedIn : ProcessedImagePort;
		port resultOut : MeasurementPort;
		
		action computeMeasurement {
			in proc : ProcessedImage;
			out result : MeasurementResult;
			
			perform action convertIlluminance {
				in avg : AverageIntensity = proc.averageIntensity;
				in factor : CalibrationFactor = calibrationFactor;
				out illum : Illuminance;
				effect { illum = avg * factor; }
			}
			
			perform action assessConfidence {
				in valid : Boolean = proc.valid;
				in oversat : Boolean = proc.oversaturated;
				out conf : Confidence;
				effect {
					if not valid then conf = 0.0;
					else if oversat then conf = baseConfidence - oversatPenalty;
					else conf = baseConfidence;
				}
			}
			
			then action finalize {
				in illum : Illuminance = convertIlluminance.illum;
				in conf : Confidence = assessConfidence.conf;
				in valid : Boolean = proc.valid;
				out res : MeasurementResult = result;
				effect {
					res.illuminance = illum;
					res.timestamp = proc.processingTime;
					res.confidence = conf;
					res.valid = valid;
				}
			}
		}
		
		state machine EngineStateMachine {
			entry; then Ready;
			
			state Ready;
			
			transition from Ready to Converting
				when processedIn.processed->notEmpty();
			
			state Converting {
				do computeMeasurement;
				then Emitting;
			}
			
			state Emitting {
				entry { /* publish result on resultOut */ }
				then Ready;
			}
		}
	}
	
	// ---------- Controller ----------
	part def Controller {
		port sensorBus : ControlBusPort;
		port processorBus : ControlBusPort;
		port engineBus : ControlBusPort;
		port measurementOut : MeasurementPort;
		
		attribute cycleCount : Integer = 0;
		
		state machine ControllerStateMachine {
			entry; then Standby;
			
			state Standby {
				entry { /* await external trigger */ }
			}
			
			transition from Standby to IssuingCapture
				when sensorBus.command->isEmpty();
			
			state IssuingCapture {
				entry {
					sensorBus.command.commandId = "CAPTURE_" + cycleCount.toString();
					sensorBus.command.issuedAt = "now";
				}
				then AwaitingCaptureAck;
			}
			
			state AwaitingCaptureAck {
				transition to RoutingToProcessor
					when sensorBus.status.stage == "captured" and sensorBus.status.success;
			}
			
			state RoutingToProcessor {
				entry {
					processorBus.command.commandId = "PROCESS_" + cycleCount.toString();
					processorBus.command.issuedAt = "now";
				}
				then AwaitingProcessAck;
			}
			
			state AwaitingProcessAck {
				transition to RoutingToEngine
					when processorBus.status.stage == "processed" and processorBus.status.success;
			}
			
			state RoutingToEngine {
				entry {
					engineBus.command.commandId = "MEASURE_" + cycleCount.toString();
					engineBus.command.issuedAt = "now";
				}
				then AwaitingMeasurementAck;
			}
			
			state AwaitingMeasurementAck {
				transition to PublishingResult
					when engineBus.status.stage == "measured" and engineBus.status.success;
			}
			
			state PublishingResult {
				entry {
					measurementOut.result = engineBus.status; // conceptual handoff
					cycleCount = cycleCount + 1;
				}
				then Standby;
			}
		}
	}
	
	// ---------- Top-level System ----------
	part sensingUnit {
		port lightInput : LightInputPort;
		port measurementOutput : MeasurementPort;
		port trigger : ControlBusPort;
		
		part controller : Controller;
		part imageSensor : ImageSensor;
		part signalProcessor : SignalProcessor;
		part measurementEngine : MeasurementEngine;
		
		connection lightInput to imageSensor.lightIn;
		
		connection controller.sensorBus to imageSensor.cmdIn {
			item command : CaptureCommand;
			item ack : ControlStatus;
		}
		
		connection imageSensor.rawOut to signalProcessor.rawIn {
			item raw : RawImage;
		}
		
		connection controller.processorBus to signalProcessor /* control linkage */ {
			item command : CaptureCommand;
			item status : ControlStatus;
		}
		
		connection signalProcessor.processedOut to measurementEngine.processedIn {
			item processed : ProcessedImage;
		}
		
		connection controller.engineBus to measurementEngine /* control linkage */ {
			item command : CaptureCommand;
			item status : ControlStatus;
		}
		
		connection measurementEngine.resultOut to measurementOutput {
			item result : MeasurementResult;
		}
		
		connection trigger to controller.sensorBus {
			item command : CaptureCommand;
			item status : ControlStatus;
		}
	}
	
	// ---------- Requirements ----------
	requirement def ShallMeasureIlluminance {
		doc { The system shall measure environmental illuminance from captured scene images. }
		subject : sensingUnit;
		objective {
			measurementOutput.result.illuminance >= 0 [lux]
			and measurementOutput.result.illuminance <= 200000 [lux]
		}
	}
	
	requirement def ShallProvideCalibratedResult {
		doc { The measurement result shall include illuminance, timestamp, and confidence. }
		subject : sensingUnit;
		objective {
			measurementOutput.result.illuminance->notEmpty()
			and measurementOutput.result.timestamp->notEmpty()
			and measurementOutput.result.confidence >= 0.0
			and measurementOutput.result.confidence <= 1.0
		}
	}
	
	requirement def ShallDetectOversaturation {
		doc { The signal processor shall flag oversaturated captures as invalid. }
		subject : signalProcessor;
		objective {
			signalProcessor.processedOut.processed.oversaturated == true
			implies signalProcessor.processedOut.processed.valid == false
		}
	}
	
	requirement def ShallUse1920x1080Sensor {
		doc { The image sensor shall use a 1920x1080 pixel array with a 12-bit ADC. }
		subject : imageSensor;
		objective {
			imageSensor.resolutionWidth == 1920
			and imageSensor.resolutionHeight == 1080
			and imageSensor.adcBitDepth == 12
		}
	}
	
	requirement def ShallOrchestrateCycle {
		doc { The controller shall orchestrate capture, processing, and measurement in sequence. }
		subject : controller;
		objective {
			controller.cycleCount >= 0
		}
	}
	
	requirement sensingUnitRequirements : ShallMeasureIlluminance;
	requirement calibratedResultRequirement : ShallProvideCalibratedResult;
	requirement oversaturationRequirement : ShallDetectOversaturation;
	requirement sensorSpecRequirement : ShallUse1920x1080Sensor;
	requirement orchestrationRequirement : ShallOrchestrateCycle;
	
}
