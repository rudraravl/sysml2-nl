package DigitalSensingUnit {
	private import ScalarValues::*;

	attribute def Illuminance :> Real;
	attribute def Confidence :> Real;
	attribute def Timestamp :> String;

	item def RawImage {
		attribute width : Integer = 1920;
		attribute height : Integer = 1080;
		attribute bitDepth : Integer = 12;
		attribute pixelData : Integer[*];
	}

	item def ProcessedImage {
		attribute width : Integer = 1920;
		attribute height : Integer = 1080;
		attribute averageIntensity : Real;
		attribute isOversaturated : Boolean;
		attribute pixelData : Integer[*];
	}

	item def IlluminanceMeasurement {
		attribute illuminance : Illuminance;
		attribute timestamp : Timestamp;
		attribute confidence : Confidence;
	}

	attribute def CaptureCommand;
	attribute def CaptureComplete;
	attribute def ProcessComplete;
	attribute def MeasureComplete;

	port def CommandPort { in item command : CaptureCommand; }
	port def RawImagePort { out item rawImage : RawImage; }
	port def ProcessedImagePort { out item processedImage : ProcessedImage; }
	port def MeasurementPort { out item measurement : IlluminanceMeasurement; }

	state def SensorStates {
		entry; then idle;
		state idle;
		accept CaptureCommand then capturing;
		state capturing;
		accept CaptureComplete then processing;
		state processing;
		accept ProcessComplete then measuring;
		state measuring;
		accept MeasureComplete then idle;
	}

	action def CaptureAction {
		in item command : CaptureCommand;
		out item rawImage : RawImage;
	}

	action def ProcessAction {
		in item rawImage : RawImage;
		out item processedImage : ProcessedImage;
	}

	action def MeasureAction {
		in item processedImage : ProcessedImage;
		out item measurement : IlluminanceMeasurement;
	}

	part def ImageSensor {
		attribute resolutionWidth : Integer = 1920;
		attribute resolutionHeight : Integer = 1080;
		attribute adcBitDepth : Integer = 12;

		port cmdIn : CommandPort;
		port rawOut : RawImagePort;

		exhibit sensorStates : SensorStates;

		action capture : CaptureAction;
	}

	part def SignalProcessor {
		port rawIn : RawImagePort;
		port procOut : ProcessedImagePort;

		action process : ProcessAction;
	}

	part def MeasurementEngine {
		attribute calibrationFactor : Real = 0.85;

		port procIn : ProcessedImagePort;
		port measOut : MeasurementPort;

		action measure : MeasureAction;
	}

	part def CentralController {
		port cmdOut : CommandPort;
		port measIn : MeasurementPort;
	}

	part def DigitalSensingUnit {
		part controller : CentralController;
		part sensor : ImageSensor;
		part processor : SignalProcessor;
		part engine : MeasurementEngine;

		port measurementOut : MeasurementPort;

		connect controller.cmdOut to sensor.cmdIn;
		connect sensor.rawOut to processor.rawIn;
		connect processor.procOut to engine.procIn;
		connect engine.measOut to controller.measIn;
		connect controller.measIn to measurementOut;
	}

	requirement def IlluminanceMeasurementRequirement {
		doc /* The system shall measure illuminance in lux with an accuracy of ±5% over a range of 0 to 100,000 lux. */
		attribute requiredResolutionWidth : Integer = 1920;
		attribute requiredResolutionHeight : Integer = 1080;
		attribute requiredBitDepth : Integer = 12;
		attribute accuracy : Confidence = 5.0;
		attribute minRange : Illuminance = 0.0;
		attribute maxRange : Illuminance = 100000.0;
	}

	requirement measurementReq : IlluminanceMeasurementRequirement;
}
