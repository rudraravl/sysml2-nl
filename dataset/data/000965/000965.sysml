package 'Active Pixel Sensor Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PixelResolution {
		attribute width : Integer;
		attribute height : Integer;
	}
	
	item def OpticalScene {
		attribute illuminance : LuminousIntensityValue;
	}
	
	item def DigitalImage {
		attribute resolution : PixelResolution;
		attribute pixelData : Integer[*] ordered;
	}
	
	item def AnalogSignal {
		attribute voltage : VoltageValue;
	}
	
	port def OpticalInputPort {
		in item scene : OpticalScene;
	}
	
	port def ImageOutputPort {
		out item image : DigitalImage;
	}
	
	port def PowerPort {
		in item power : VoltageValue;
	}
	
	port def ControlPort {
		in item exposureTime : TimeValue;
		in item gain : Real;
	}
	
	action def PhotonCapture {
		in item incomingScene : OpticalScene;
		out item photoCurrent : AnalogSignal;
	}
	
	action def ChargeAccumulation {
		in item photoCurrent : AnalogSignal;
		in item exposureTime : TimeValue;
		out item accumulatedCharge : VoltageValue;
	}
	
	action def SignalAmplification {
		in item rawSignal : VoltageValue;
		in item gain : Real;
		out item amplifiedSignal : VoltageValue;
	}
	
	action def AnalogToDigitalConversion {
		in item analogSignal : VoltageValue;
		out item digitalValue : Integer;
	}
	
	action def ImageFormation {
		in item pixelValues : Integer[*] ordered;
		in item resolution : PixelResolution;
		out item image : DigitalImage;
	}
	
	action def PixelReadout {
		in item scene : OpticalScene;
		in item exposureTime : TimeValue;
		in item gain : Real;
		out item digitalPixelValue : Integer;
		
		action capturePhotons : PhotonCapture {
			in item :>> incomingScene = scene;
			out item photoCurrent;
		}
		then action accumulateCharge : ChargeAccumulation {
			in item :>> photoCurrent = capturePhotons.photoCurrent;
			in item :>> exposureTime;
			out item accumulatedCharge;
		}
		then action amplifySignal : SignalAmplification {
			in item :>> rawSignal = accumulateCharge.accumulatedCharge;
			in item :>> gain;
			out item amplifiedSignal;
		}
		then action convertToDigital : AnalogToDigitalConversion {
			in item :>> analogSignal = amplifySignal.amplifiedSignal;
			out item digitalValue;
		}
		
		bind convertToDigital.digitalValue = digitalPixelValue;
	}
	
	action def SensingCycle {
		in item scene : OpticalScene;
		in item exposureTime : TimeValue;
		in item gain : Real;
		in item resolution : PixelResolution;
		out item capturedImage : DigitalImage;
		
		fork;
		then action readPixels : PixelReadout[*] {
			in item :>> scene;
			in item :>> exposureTime;
			in item :>> gain;
			out item digitalPixelValue;
		}
		then join joinNode;
		
		join joinNode;
		then action formImage : ImageFormation {
			in item :>> pixelValues = readPixels.digitalPixelValue;
			in item :>> resolution;
			out item image;
		}
		
		bind formImage.image = capturedImage;
	}
	
	state def PixelState {
		entry; then idle;
		
		state idle;
		transition idle_to_exposing
			first idle
			then exposing;
			
		state exposing;
		transition exposing_to_reading
			first exposing
			then reading;
			
		state reading;
		transition reading_to_idle
			first reading
			then idle;
	}
	
	state def SensorState {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_initializing
			first powerOff
			then initializing;
			
		state initializing;
		transition initializing_to_ready
			first initializing
			then ready;
			
		state ready;
		transition ready_to_capturing
			first ready
			then capturing;
			
		state capturing;
		transition capturing_to_ready
			first capturing
			then ready;
			
		transition ready_to_powerOff
			first ready
			then powerOff;
	}
	
	part def Photodiode {
		attribute quantumEfficiency : Real;
		port opticalInput : OpticalInputPort;
	}
	
	part def InPixelAmplifier {
		attribute gainFactor : Real;
	}
	
	part def PixelTransistor {
		attribute transistorType : String;
	}
	
	part def ActivePixel {
		attribute pixelSize : LengthValue;
		attribute fillFactor : Real;
		
		part photodiode : Photodiode[1];
		part amplifier : InPixelAmplifier[1];
		part resetTransistor : PixelTransistor[1];
		part selectTransistor : PixelTransistor[1];
		
		exhibit state pixelStateMachine : PixelState;
	}
	
	part def PixelArray {
		attribute resolution : PixelResolution;
		part pixels : ActivePixel[*] ordered;
	}
	
	part def RowDecoder {
		attribute numberOfRows : Integer;
	}
	
	part def ColumnDecoder {
		attribute numberOfColumns : Integer;
	}
	
	part def TimingGenerator {
		attribute masterClock : FrequencyValue;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute conversionRate : FrequencyValue;
	}
	
	part def ImageProcessor {
		attribute processingCapability : String;
	}
	
	part def ActivePixelSensor {
		attribute sensorResolution : PixelResolution;
		attribute maxFrameRate : FrequencyValue;
		attribute powerConsumption : PowerValue;
		
		port opticalInput : OpticalInputPort;
		port imageOutput : ImageOutputPort;
		port powerInput : PowerPort;
		port controlInterface : ControlPort;
		
		part pixelArray : PixelArray[1] {
			attribute :>> resolution = sensorResolution;
		}
		
		part rowDecoder : RowDecoder[1] {
			attribute :>> numberOfRows = sensorResolution.height;
		}
		
		part columnDecoder : ColumnDecoder[1] {
			attribute :>> numberOfColumns = sensorResolution.width;
		}
		
		part timingGenerator : TimingGenerator[1];
		
		part adc : AnalogToDigitalConverter[1] {
			attribute :>> resolution = 12;
		}
		
		part imageProcessor : ImageProcessor[1];
		
		exhibit state sensorStateMachine : SensorState;
		
		connect opticalInput to pixelArray.pixels.photodiode.opticalInput;
	}
	
	part def SensingUnit {
		attribute operatingTemperature : TemperatureValue;
		attribute measurementRange : LuminousIntensityValue;
		
		port sceneInput : OpticalInputPort;
		port dataOutput : ImageOutputPort;
		port power : PowerPort;
		port control : ControlPort;
		
		part sensor : ActivePixelSensor[1];
		
		connect sceneInput to sensor.opticalInput;
		connect sensor.imageOutput to dataOutput;
		connect power to sensor.powerInput;
		connect control to sensor.controlInterface;
		
		perform action measure : SensingCycle;
	}
	
	requirement def SensingRequirement {
		doc /* The sensing unit shall measure illuminance using an active pixel sensor. */
		
		subject sensingUnit : SensingUnit;
		
		require constraint spatialResolutionConstraint {
			sensingUnit.sensor.sensorResolution.width >= 1280 and
			sensingUnit.sensor.sensorResolution.height >= 720
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> operatingTemperature = 298.15[SI::K];
		attribute :>> measurementRange = 1000.0[SI::cd];
		
		part :>> sensor {
			attribute :>> sensorResolution {
				attribute :>> width = 1920;
				attribute :>> height = 1080;
			}
			attribute :>> maxFrameRate = 60.0[SI::Hz];
			attribute :>> powerConsumption = 2.5[SI::W];
		}
	}
	
	requirement sensingRequirementInstance : SensingRequirement {
		subject sensingUnit = sensingUnitInstance;
	}
	
	verification def VerifySensingPerformance {
		subject testUnit : SensingUnit;
		
		return verdict : Boolean;
		
		objective {
			doc /* Verify that the sensing unit meets all performance requirements. */
		}
	}
	
	verification verifySensingUnitPerformance : VerifySensingPerformance {
		subject testUnit = sensingUnitInstance;
	}
}
