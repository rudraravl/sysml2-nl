package 'Active Pixel Sensor Sensing Unit' {
	private import ScalarValues::*;

	attribute def LightIntensityValue {
		attribute num : Real;
		attribute unit : String;
	}

	attribute def VoltageValue {
		attribute num : Real;
		attribute unit : String;
	}

	attribute def IlluminanceValue {
		attribute num : Real;
		attribute unit : String;
	}

	attribute def LengthValue {
		attribute num : Real;
		attribute unit : String;
	}

	attribute def RelevantQuantity :> LightIntensityValue;

	attribute def ImageResolution {
		attribute width : Integer;
		attribute height : Integer;
	}

	item def PixelData {
		attribute intensity : VoltageValue;
		attribute rowIndex : Integer;
		attribute columnIndex : Integer;
	}

	item def ImageData {
		attribute resolution : ImageResolution;
		attribute pixelArray : PixelData[*] ordered;
		attribute captureTimestamp : Real;
	}

	port def LightInputPort {
		in item lightIntensity : LightIntensityValue;
	}

	port def ImageOutputPort {
		out item imageData : ImageData;
	}

	part def Photodiode {
		port lightIn : LightInputPort;
		attribute photocurrent : VoltageValue;
		attribute quantumEfficiency : Real;
		attribute fullWellCapacity : Real;
	}

	part def PixelAmplifier {
		in attribute inputVoltage : VoltageValue;
		out attribute amplifiedVoltage : VoltageValue;
		attribute gainFactor : Real default = 2.5;
	}

	part def ResetTransistor {
		attribute resetVoltage : VoltageValue;
		attribute onResistance : Real;
	}

	part def ActivePixelCell {
		attribute rowPosition : Integer;
		attribute columnPosition : Integer;
		part photodiode : Photodiode[1];
		part amplifier : PixelAmplifier[1];
		part resetTransistor : ResetTransistor[1];
		connect photodiode.photocurrent to amplifier.inputVoltage;
	}

	part def PixelArray {
		attribute arrayResolution : ImageResolution;
		attribute pixelPitch : LengthValue;
		part pixels : ActivePixelCell[*] ordered;
	}

	part def RowSelectCircuit {
		attribute currentRow : Integer;
		attribute totalRows : Integer;
	}

	part def ColumnReadoutCircuit {
		attribute currentColumn : Integer;
		attribute totalColumns : Integer;
		out attribute pixelOutput : VoltageValue;
	}

	part def CorrelatedDoubleSampler {
		attribute noiseFloor : VoltageValue;
		in attribute analogIn : VoltageValue;
		out attribute analogOut : VoltageValue;
	}

	part def AnalogToDigitalConverter {
		in attribute analogInput : VoltageValue;
		out attribute digitalOutput : Integer;
		attribute bitDepth : Integer default = 12;
		attribute referenceVoltage : VoltageValue;
	}

	part def ImageProcessor {
		attribute blackLevel : Integer;
		attribute gainCorrection : Real;
		in attribute digitalIn : ImageData;
		out attribute digitalOut : ImageData;
	}

	action def ConvertLightToCharge {
		in lightIntensity : LightIntensityValue;
		out photocurrent : VoltageValue;
	}

	action def AmplifySignal {
		in inputSignal : VoltageValue;
		in gain : Real;
		out amplifiedSignal : VoltageValue;
	}

	action def ReadoutPixel {
		in pixel : ActivePixelCell;
		out pixelData : PixelData;
	}

	action def ScanPixelArray {
		in pixelArray : PixelArray;
		out imageData : ImageData;
	}

	action def RowSelection {
		in rowIndex : Integer;
		out selectedPixels : ActivePixelCell[*];
	}

	action def ColumnReadout {
		in pixel : ActivePixelCell;
		out digitalValue : Integer;
	}

	action def CorrelatedDoubleSampling {
		in analogSignal : VoltageValue;
		out sampledSignal : VoltageValue;
	}

	action def DigitizeSignal {
		in analogSignal : VoltageValue;
		out digitalValue : Integer;
	}

	action def ImageAssembly {
		in pixelValues : PixelData[*];
		out assembledImage : ImageData;
	}

	action def ProcessImage {
		in rawImage : ImageData;
		out processedImage : ImageData;
	}

	action def ExposePixelArray {
		in sceneLight : LightIntensityValue;
		out chargeAccumulation : VoltageValue[*];
		attribute exposureTime : Real;
	}

	action def CaptureSensingCycle {
		in item scene : LightIntensityValue;
		out item capturedImage : ImageData;
		
		first expose : ExposePixelArray {
			in sceneLight;
			out chargeAccumulation;
		}
		
		then readout : ScanPixelArray {
			in pixelArray;
			out imageData;
		}
		
		then process : ProcessImage {
			in rawImage;
			out processedImage;
		}
		
		bind expose.sceneLight = scene;
		flow from expose.chargeAccumulation to readout.pixelArray;
		flow from readout.imageData to process.rawImage;
		bind process.processedImage = capturedImage;
	}

	action def Measure {
		in quantity : RelevantQuantity;
		out measurement : ImageData;
	}

	state def SensorOperatingState {
		entry action initialize;
		state idle;
		state exposing;
		state reading;
		state converting;
		state processing;
		state outputReady;

		transition initial_to_idle
			first initial
			then idle;
		
		transition idle_to_exposing
			first idle
			accept lightInput : LightIntensityValue
			then exposing;

		transition exposing_to_reading
			first exposing
			accept exposureComplete
			then reading;

		transition reading_to_converting
			first reading
			accept readoutComplete
			then converting;

		transition converting_to_processing
			first converting
			accept conversionComplete
			then processing;

		transition processing_to_outputReady
			first processing
			accept processingComplete
			then outputReady;

		transition outputReady_to_idle
			first outputReady
			accept frameDelivered
			then idle;
	}

	part def ActivePixelSensor {
		port lightInput : LightInputPort;
		port imageOutput : ImageOutputPort;
		
		part sensorArray : PixelArray[1] {
			attribute :>> arrayResolution {
				attribute :>> width = 1920;
				attribute :>> height = 1080;
			}
			attribute :>> pixelPitch {
				attribute :>> num = 2.2e-6;
				attribute :>> unit = "m";
			}
		}
		
		part rowSelect : RowSelectCircuit[1] {
			attribute :>> totalRows = 1080;
		}
		
		part columnReadout : ColumnReadoutCircuit[1920] {
			attribute :>> totalColumns = 1920;
		}

		part cds : CorrelatedDoubleSampler[1] {
			attribute :>> noiseFloor {
				attribute :>> num = 0.001;
				attribute :>> unit = "V";
			}
		}
		
		part adc : AnalogToDigitalConverter[1] {
			attribute :>> bitDepth = 14;
			attribute :>> referenceVoltage {
				attribute :>> num = 1.8;
				attribute :>> unit = "V";
			}
		}

		part processor : ImageProcessor[1] {
			attribute :>> blackLevel = 64;
			attribute :>> gainCorrection = 1.0;
		}
		
		connect columnReadout.pixelOutput to cds.analogIn;
		connect cds.analogOut to adc.analogInput;

		perform action measureAction : Measure;
	}

	part def TimingController {
		attribute frameRate : Real;
		attribute pixelClockFrequency : Real;
		attribute exposureTime : Real;
	}

	part def SensingUnit {
		port lightIn : LightInputPort;
		port dataOut : ImageOutputPort;
		
		part sensor : ActivePixelSensor[1];
		part timing : TimingController[1] {
			attribute :>> frameRate = 30.0;
			attribute :>> pixelClockFrequency = 74.25e6;
			attribute :>> exposureTime = 10.0e-3;
		}
		
		connect lightIn to sensor.lightInput;
		connect sensor.imageOutput to dataOut;
		
		perform action sensingOperation : CaptureSensingCycle;
		perform action measureAction : Measure;
		exhibit state operatingState : SensorOperatingState;
	}

	requirement def SensingRequirement {
		attribute id : String;
		attribute text : String;
	}

	requirement measureLightReq : SensingRequirement {
		attribute :>> id = "REQ-APS-001";
		attribute :>> text = "The sensing unit shall measure incident light using an active pixel sensor with per-pixel amplification.";
	}

	requirement frameRateReq : SensingRequirement {
		attribute :>> id = "REQ-APS-002";
		attribute :>> text = "The sensing unit shall support a minimum frame rate of 30 Hz.";
		subject sensingUnit : SensingUnit;
		require constraint {
			sensingUnit.timing.frameRate >= 30.0
		}
	}

	requirement resolutionReq : SensingRequirement {
		attribute :>> id = "REQ-APS-003";
		attribute :>> text = "The sensing unit shall provide Full HD resolution (1920x1080 pixels).";
		subject sensingUnit : SensingUnit;
		require constraint {
			sensingUnit.sensor.sensorArray.arrayResolution.width == 1920 and
			sensingUnit.sensor.sensorArray.arrayResolution.height == 1080
		}
	}

	requirement bitDepthReq : SensingRequirement {
		attribute :>> id = "REQ-APS-004";
		attribute :>> text = "The sensing unit shall provide at least 12-bit digital output per pixel.";
		subject sensingUnit : SensingUnit;
		require constraint {
			sensingUnit.sensor.adc.bitDepth >= 12
		}
	}

	part sensingSystem : SensingUnit {
		attribute sensorSensitivity : LightIntensityValue;
		attribute operatingVoltage : VoltageValue {
			attribute :>> num = 3.3;
			attribute :>> unit = "V";
		}
		attribute minimumIlluminance : IlluminanceValue {
			attribute :>> num = 1;
			attribute :>> unit = "lx";
		}
		attribute maximumIlluminance : IlluminanceValue {
			attribute :>> num = 100000;
			attribute :>> unit = "lx";
		}
		
		part :>> sensor {
			part :>> sensorArray {
				part :>> pixels {
					part :>> photodiode {
						attribute :>> quantumEfficiency = 0.65;
						attribute :>> fullWellCapacity = 10000.0;
					}
					part :>> amplifier {
						attribute :>> gainFactor = 3.0;
					}
					part :>> resetTransistor {
						attribute :>> resetVoltage {
							attribute :>> num = 3.3;
							attribute :>> unit = "V";
						}
						attribute :>> onResistance = 100.0;
					}
				}
			}
		}

		perform :>> sensingOperation {
			in item sceneLight : LightIntensityValue;
			out item capturedImage : ImageData;
		}
	}

	satisfy measureLightReq by sensingSystem;
	satisfy frameRateReq by sensingSystem;
	satisfy resolutionReq by sensingSystem;
	satisfy bitDepthReq by sensingSystem;
}
