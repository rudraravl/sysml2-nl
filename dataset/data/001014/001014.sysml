package ContactImageSensorSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	attribute def ResolutionValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ResolutionUnit;
	}
	
	attribute def ResolutionUnit :> MeasurementUnit;
	attribute def DotsPerInch :> ResolutionUnit;
	
	attribute def IlluminanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : IlluminanceUnit;
	}
	
	attribute def IlluminanceUnit :> MeasurementUnit;
	attribute def Lux :> IlluminanceUnit;
	
	item def PhysicalDocument {
		attribute width : LengthValue;
		attribute length : LengthValue;
		attribute surfaceReflectance : Real;
	}
	
	item def OpticalLine {
		attribute position : LengthValue;
		attribute reflectedIntensity : Real[*];
	}
	
	item def ElectricalSignal {
		attribute voltageLevel : Real[*];
		attribute linePosition : LengthValue;
	}
	
	item def DigitalLineData {
		attribute pixelValues : Integer[*];
		attribute linePosition : LengthValue;
		attribute timestamp : Real;
	}
	
	item def ScannedImage {
		attribute resolution : ResolutionValue;
		attribute width : LengthValue;
		attribute height : LengthValue;
		attribute imageData : DigitalLineData[*];
	}
	
	port def DocumentInputPort {
		in item document : PhysicalDocument;
	}
	
	port def ImageOutputPort {
		out item image : ScannedImage;
	}
	
	port def OpticalPort {
		out item illumination : IlluminanceValue;
		in item reflectedLight : OpticalLine;
	}
	
	port def AnalogPort {
		in item opticalInput : OpticalLine;
		out item electricalOutput : ElectricalSignal;
	}
	
	port def DigitalPort {
		in item analogInput : ElectricalSignal;
		out item digitalOutput : DigitalLineData;
	}
	
	action def IlluminateLine {
		in document : PhysicalDocument;
		in linePosition : LengthValue;
		out illumination : IlluminanceValue;
		out reflectedLine : OpticalLine;
	}
	
	action def ConvertToElectrical {
		in opticalLine : OpticalLine;
		out electricalSignal : ElectricalSignal;
	}
	
	action def DigitizeSignal {
		in analogSignal : ElectricalSignal;
		in bitDepth : Integer;
		out digitalData : DigitalLineData;
	}
	
	action def AssembleImage {
		in lineData : DigitalLineData[*];
		in scanResolution : ResolutionValue;
		in documentDimensions : LengthValue[2];
		out completeImage : ScannedImage;
	}
	
	action def ScanSingleLine {
		in document : PhysicalDocument;
		in currentPosition : LengthValue;
		in operatingResolution : ResolutionValue;
		out lineData : DigitalLineData;
		
		bind illuminate.document = document;
		bind illuminate.linePosition = currentPosition;
		
		action illuminate : IlluminateLine {
			in document;
			in linePosition;
			out illumination;
			out reflectedLine;
		}
		
		flow from illuminate.reflectedLine to convert.opticalLine;
		
		then action convert : ConvertToElectrical {
			in opticalLine;
			out electricalSignal;
		}
		
		flow from convert.electricalSignal to digitize.analogSignal;
		
		then action digitize : DigitizeSignal {
			in analogSignal;
			in bitDepth = 16;
			out digitalData;
		}
		
		bind digitize.digitalData = lineData;
	}
	
	action def PerformScan {
		in document : PhysicalDocument;
		in resolution : ResolutionValue;
		out scannedImage : ScannedImage;
		
		action scanLines {
			in document : PhysicalDocument = PerformScan::document;
			in resolution : ResolutionValue = PerformScan::resolution;
			out allLines : DigitalLineData[*];
		}
		
		then action assemble : AssembleImage {
			in lineData = scanLines.allLines;
			in scanResolution = resolution;
			in documentDimensions;
			out completeImage;
		}
		
		bind assemble.completeImage = scannedImage;
	}
	
	part def LEDIlluminationModule {
		attribute numberOfLEDs : Integer;
		attribute wavelength : LengthValue;
		attribute outputIntensity : IlluminanceValue;
		
		port illuminationPort : OpticalPort;
		
		action illuminate : IlluminateLine;
	}
	
	part def SelfocLensArray {
		attribute numberOfLenses : Integer;
		attribute focalLength : LengthValue;
		attribute pitchDistance : LengthValue;
		attribute numericalAperture : Real;
	}
	
	part def PhotodiodeArray {
		attribute numberOfElements : Integer;
		attribute elementPitch : LengthValue;
		attribute spectralSensitivity : Real;
		attribute quantumEfficiency : Real;
		
		port opticalInputPort : AnalogPort;
		
		action convert : ConvertToElectrical;
	}
	
	part def AnalogFrontEnd {
		attribute amplificationGain : Real;
		attribute noiseLevel : Real;
		
		port analogInputPort {
			in item signal : ElectricalSignal;
		}
		
		port analogOutputPort {
			out item amplifiedSignal : ElectricalSignal;
		}
	}
	
	part def ADCModule {
		attribute bitResolution : Integer;
		attribute samplingRate : Real;
		attribute conversionTime : Real;
		
		port adcInputPort : DigitalPort;
		
		action digitize : DigitizeSignal;
	}
	
	part def ImageProcessingUnit {
		attribute processorSpeed : Real;
		attribute memorySize : Integer;
		attribute correctionAlgorithms : String[*];
		
		port dataInputPort {
			in item rawData : DigitalLineData;
		}
		
		port dataOutputPort {
			out item processedData : DigitalLineData;
		}
		
		action processLine {
			in rawLine : DigitalLineData;
			out correctedLine : DigitalLineData;
		}
	}
	
	part def ContactImageSensorModule {
		attribute operatingResolution : ResolutionValue;
		attribute activeWidth : LengthValue;
		attribute scanSpeed : Real;
		attribute powerConsumption : Real;
		
		port opticalInterface : OpticalPort;
		port digitalInterface : DigitalPort;
		
		part ledModule : LEDIlluminationModule {
			attribute :>> numberOfLEDs = 3;
			attribute :>> wavelength = 0.000000625[m];
		}
		
		part lensArray : SelfocLensArray {
			attribute :>> numberOfLenses = 5100;
			attribute :>> focalLength = 0.0025[m];
			attribute :>> pitchDistance = 0.000042[m];
			attribute :>> numericalAperture = 0.46;
		}
		
		part photodiodeArray : PhotodiodeArray {
			attribute :>> numberOfElements = 5100;
			attribute :>> elementPitch = 0.000042[m];
			attribute :>> spectralSensitivity = 0.65;
			attribute :>> quantumEfficiency = 0.85;
		}
		
		part afe : AnalogFrontEnd {
			attribute :>> amplificationGain = 100.0;
			attribute :>> noiseLevel = 0.001;
		}
		
		part adc : ADCModule {
			attribute :>> bitResolution = 16;
			attribute :>> samplingRate = 96000.0;
			attribute :>> conversionTime = 0.00001;
		}
		
		part imageProcessor : ImageProcessingUnit {
			attribute :>> processorSpeed = 2000000.0;
			attribute :>> memorySize = 8192;
			attribute :>> correctionAlgorithms = ("shading", "offset", "gain");
		}
		
		connect ledModule.illuminationPort to photodiodeArray.opticalInputPort;
		connect photodiodeArray.opticalInputPort to afe.analogInputPort;
		connect afe.analogOutputPort to adc.adcInputPort;
		connect adc.adcInputPort to imageProcessor.dataInputPort;
		connect imageProcessor.dataOutputPort to digitalInterface;
	}
	
	part def TransportMechanism {
		attribute stepSize : LengthValue;
		attribute transportSpeed : Real;
		attribute positionAccuracy : LengthValue;
		
		action advanceDocument {
			in currentPosition : LengthValue;
			out nextPosition : LengthValue;
		}
	}
	
	part def SensingUnit {
		attribute targetResolution : ResolutionValue;
		attribute maxDocumentWidth : LengthValue;
		attribute maxDocumentLength : LengthValue;
		attribute operatingVoltage : Real;
		
		ref item documentToScan : PhysicalDocument;
		part scannedImages : ScannedImage[*];
		
		port documentInput : DocumentInputPort {
			in ref item document : PhysicalDocument = SensingUnit::documentToScan;
		}
		
		port imageOutput : ImageOutputPort {
			out ref item image : ScannedImage :> scannedImages;
		}
		
		part cisModule : ContactImageSensorModule {
			attribute :>> operatingResolution = SensingUnit::targetResolution;
			attribute :>> activeWidth = SensingUnit::maxDocumentWidth;
			attribute :>> scanSpeed = 50.8;
			attribute :>> powerConsumption = 3.5;
		}
		
		part transport : TransportMechanism {
			attribute :>> stepSize = 0.000042[m];
			attribute :>> transportSpeed = 0.0508;
			attribute :>> positionAccuracy = 0.000001[m];
		}
		
		connect documentInput to cisModule.opticalInterface;
		connect cisModule.digitalInterface to imageOutput;
		
		action performScan : PerformScan {
			in document = documentToScan;
			in resolution = targetResolution;
			out scannedImage;
		}
	}
	
	part sensingUnit : SensingUnit {
		attribute :>> maxDocumentWidth = 0.216[m];
		attribute :>> maxDocumentLength = 0.356[m];
		attribute :>> operatingVoltage = 5.0;
		
		ref item :>> documentToScan;
	}
	
	requirement def ResolutionRequirement {
		doc /* The sensing unit shall achieve minimum specified resolution. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.cisModule.operatingResolution.num >= 300.0
		}
	}
	
	requirement def OpticalQualityRequirement {
		doc /* The contact image sensor shall maintain optical quality standards. */
		
		subject cis : ContactImageSensorModule;
		
		require constraint {
			cis.photodiodeArray.quantumEfficiency >= 0.8 and
			cis.lensArray.numericalAperture >= 0.4
		}
	}
	
	requirement def PositionalAccuracyRequirement {
		doc /* The transport mechanism shall maintain positional accuracy. */
		
		subject transport : TransportMechanism;
		
		require constraint {
			transport.positionAccuracy.num <= 0.000005
		}
	}
	
	requirement def SignalProcessingRequirement {
		doc /* The sensing unit shall process signals with adequate bit depth. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.cisModule.adc.bitResolution >= 12
		}
	}
	
	requirement def ContactImageSensorRequirements {
		doc /* Top-level requirements for contact image sensor based sensing unit. */
		
		subject unit : SensingUnit;
		
		requirement resolutionReq : ResolutionRequirement {
			subject sensingUnit = unit;
		}
		
		requirement opticalReq : OpticalQualityRequirement {
			subject cis = unit.cisModule;
		}
		
		requirement positionReq : PositionalAccuracyRequirement {
			subject transport = unit.transport;
		}
		
		requirement processingReq : SignalProcessingRequirement {
			subject sensingUnit = unit;
		}
	}
}
