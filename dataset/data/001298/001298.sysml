package TristimulusColorimeterSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TristimulusValue :> Real {
		doc /* CIE tristimulus value representing color stimulus */
	}
	
	attribute def ChromaticityCoordinate :> Real {
		doc /* CIE chromaticity coordinate (x or y) normalized between 0 and 1 */
	}
	
	attribute def ColorTemperature :> ThermodynamicTemperatureValue {
		doc /* Correlated color temperature in Kelvin */
	}
	
	attribute def FilterPosition {
		doc /* Position of optical filter in measurement path */
	}
	
	enum def FilterType {
		xFilter;
		yFilter;
		zFilter;
	}
	
	item def LightStimulus {
		doc /* Incident light to be measured */
		attribute spectralDistribution : PowerValue;
		attribute incidentAngle : Real;
	}
	
	item def FilteredLight :> LightStimulus {
		doc /* Light after passing through tristimulus filter */
		attribute filterType : FilterType;
	}
	
	item def PhotocurrentSignal {
		doc /* Electrical signal from photodetector */
		attribute current : ElectricCurrentValue;
		attribute filterChannel : FilterType;
	}
	
	item def DigitalReading {
		doc /* Digitized detector reading */
		attribute value : Real;
		attribute channel : FilterType;
	}
	
	item def ColorMeasurement {
		doc /* Complete tristimulus color measurement result */
		attribute X : TristimulusValue;
		attribute Y : TristimulusValue;
		attribute Z : TristimulusValue;
		attribute x : ChromaticityCoordinate;
		attribute y : ChromaticityCoordinate;
		attribute CCT : ColorTemperature;
		attribute illuminance : LuminousFluxValue;
	}
	
	port def OpticalPort {
		in item lightIn : LightStimulus;
		out item lightOut : FilteredLight;
	}
	
	port def ElectricalSignalPort {
		out item signal : PhotocurrentSignal;
	}
	
	port def DataPort {
		in item dataIn : DigitalReading;
		out item dataOut : ColorMeasurement;
	}
	
	port def ControlPort {
		in attribute calibrateCmd : Boolean;
		in attribute measureCmd : Boolean;
		out attribute filterPos : FilterPosition;
		out attribute status : Boolean;
	}
	
	part def IntegratingSphere {
		doc /* Optical integrating sphere for uniform illumination */
		port opticalInput : OpticalPort;
		port opticalOutput : OpticalPort;
		
		attribute diameter : LengthValue;
		attribute reflectance : Real;
	}
	
	part def FilterWheel {
		doc /* Rotating wheel containing X, Y, Z tristimulus filters */
		port lightInput : OpticalPort;
		port xOutput : OpticalPort;
		port yOutput : OpticalPort;
		port zOutput : OpticalPort;
		port control : ControlPort;
		
		part xFilter {
			doc /* CIE X tristimulus filter matching x-bar color matching function */
			attribute peakTransmission : LengthValue;
		}
		
		part yFilter {
			doc /* CIE Y tristimulus filter matching y-bar color matching function */
			attribute peakTransmission : LengthValue;
		}
		
		part zFilter {
			doc /* CIE Z tristimulus filter matching z-bar color matching function */
			attribute peakTransmission : LengthValue;
		}
		
		state filterState : FilterWheelStateMachine;
	}
	
	state def FilterWheelStateMachine {
		entry; then idle;
		
		state idle {
			doc /* Filter wheel at rest position */
		}
		
		state rotatingToX {
			doc /* Rotating to X filter position */
		}
		
		state measuringX {
			doc /* X filter in measurement position */
		}
		
		state rotatingToY {
			doc /* Rotating to Y filter position */
		}
		
		state measuringY {
			doc /* Y filter in measurement position */
		}
		
		state rotatingToZ {
			doc /* Rotating to Z filter position */
		}
		
		state measuringZ {
			doc /* Z filter in measurement position */
		}
		
		transition first start;
		then idle;
		accept measureCmd;
		then rotatingToX;
		accept positionReached;
		then measuringX;
		accept readingComplete;
		then rotatingToY;
		accept positionReached;
		then measuringY;
		accept readingComplete;
		then rotatingToZ;
		accept positionReached;
		then measuringZ;
		accept readingComplete;
		then idle;
	}
	
	part def SiliconPhotodiode {
		doc /* Silicon photodiode detector for measuring filtered light intensity */
		port lightInput : OpticalPort;
		port signalOutput : ElectricalSignalPort;
		
		attribute activeArea : AreaValue;
		attribute responsivity : Real;
		attribute darkCurrent : ElectricCurrentValue;
	}
	
	part def TransimpedanceAmplifier {
		doc /* Converts photodiode current to voltage signal */
		port currentInput : ElectricalSignalPort;
		port voltageOutput;
		
		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
	}
	
	part def AnalogToDigitalConverter {
		doc /* Digitizes amplified detector signals */
		port analogInput;
		port digitalOutput;
		
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
	}
	
	part def MicroprocessorUnit {
		doc /* Processes digital readings and computes colorimetric values */
		port dataInput : DataPort;
		port dataOutput : DataPort;
		port control : ControlPort;
		
		attribute calibrationMatrix : Real[3][3];
		
		perform action processColorimetry;
	}
	
	part def DisplayModule {
		doc /* Displays measurement results to user */
		port dataInput : DataPort;
		
		attribute screenSize : LengthValue;
		attribute resolution : Integer[2];
	}
	
	action def CaptureFilteredLight {
		doc /* Capture light intensity through single filter */
		in lightStimulus : LightStimulus;
		in filterType : FilterType;
		out photocurrent : PhotocurrentSignal;
	}
	
	action def AmplifySignal {
		doc /* Amplify photodiode current to measurable voltage */
		in photocurrent : PhotocurrentSignal;
		out voltage : VoltageValue;
	}
	
	action def DigitizeSignal {
		doc /* Convert analog voltage to digital reading */
		in voltage : VoltageValue;
		in channel : FilterType;
		out digitalValue : DigitalReading;
	}
	
	action def ComputeTristimulusValues {
		doc /* Compute CIE XYZ tristimulus values from raw readings */
		in xReading : DigitalReading;
		in yReading : DigitalReading;
		in zReading : DigitalReading;
		in calibrationMatrix : Real[3][3];
		out X : TristimulusValue;
		out Y : TristimulusValue;
		out Z : TristimulusValue;
	}
	
	action def ComputeChromaticity {
		doc /* Compute chromaticity coordinates from tristimulus values */
		in X : TristimulusValue;
		in Y : TristimulusValue;
		in Z : TristimulusValue;
		out x : ChromaticityCoordinate;
		out y : ChromaticityCoordinate;
	}
	
	action def ComputeCorrelatedColorTemperature {
		doc /* Compute CCT from chromaticity coordinates using McCamy approximation */
		in x : ChromaticityCoordinate;
		in y : ChromaticityCoordinate;
		out CCT : ColorTemperature;
	}
	
	action def PerformCalibration {
		doc /* Calibrate colorimeter against standard illuminant */
		in referenceIlluminant : LightStimulus;
		out calibrationMatrix : Real[3][3];
	}
	
	action def MeasureTristimulusColor {
		doc /* Complete tristimulus color measurement sequence */
		in lightStimulus : LightStimulus;
		out measurement : ColorMeasurement;
		
		first start;
		
		then action captureX : CaptureFilteredLight {
			in lightStimulus = MeasureTristimulusColor::lightStimulus;
			in filterType = FilterType::xFilter;
			out photocurrent;
		}
		
		then action amplifyX : AmplifySignal {
			in photocurrent = captureX.photocurrent;
			out voltage;
		}
		
		then action digitizeX : DigitizeSignal {
			in voltage = amplifyX.voltage;
			in channel = FilterType::xFilter;
			out digitalValue;
		}
		
		then action captureY : CaptureFilteredLight {
			in lightStimulus = MeasureTristimulusColor::lightStimulus;
			in filterType = FilterType::yFilter;
			out photocurrent;
		}
		
		then action amplifyY : AmplifySignal {
			in photocurrent = captureY.photocurrent;
			out voltage;
		}
		
		then action digitizeY : DigitizeSignal {
			in voltage = amplifyY.voltage;
			in channel = FilterType::yFilter;
			out digitalValue;
		}
		
		then action captureZ : CaptureFilteredLight {
			in lightStimulus = MeasureTristimulusColor::lightStimulus;
			in filterType = FilterType::zFilter;
			out photocurrent;
		}
		
		then action amplifyZ : AmplifySignal {
			in photocurrent = captureZ.photocurrent;
			out voltage;
		}
		
		then action digitizeZ : DigitizeSignal {
			in voltage = amplifyZ.voltage;
			in channel = FilterType::zFilter;
			out digitalValue;
		}
		
		then action computeXYZ : ComputeTristimulusValues {
			in xReading = digitizeX.digitalValue;
			in yReading = digitizeY.digitalValue;
			in zReading = digitizeZ.digitalValue;
			in calibrationMatrix;
			out X;
			out Y;
			out Z;
		}
		
		then action computeChrom : ComputeChromaticity {
			in X = computeXYZ.X;
			in Y = computeXYZ.Y;
			in Z = computeXYZ.Z;
			out x;
			out y;
		}
		
		then action computeCCT : ComputeCorrelatedColorTemperature {
			in x = computeChrom.x;
			in y = computeChrom.y;
			out CCT;
		}
		
		then action assembleMeasurement {
			in X = computeXYZ.X;
			in Y = computeXYZ.Y;
			in Z = computeXYZ.Z;
			in x = computeChrom.x;
			in y = computeChrom.y;
			in CCT = computeCCT.CCT;
			out result : ColorMeasurement;
		}
		
		then assign measurement := assembleMeasurement.result;
		then done;
	}
	
	part def TristimulusColorimeter {
		doc /* Complete tristimulus colorimeter system for objective color measurement */
		
		port opticalInput;
		port measurementOutput : DataPort;
		port systemControl : ControlPort;
		
		part sphere : IntegratingSphere {
			attribute :>> diameter = 150.0 [mm];
			attribute :>> reflectance = 0.98;
		}
		
		part filterWheel : FilterWheel;
		
		part detectorX : SiliconPhotodiode {
			attribute :>> activeArea = 100.0 [mm^2];
			attribute :>> responsivity = 0.5;
		}
		
		part detectorY : SiliconPhotodiode {
			attribute :>> activeArea = 100.0 [mm^2];
			attribute :>> responsivity = 0.5;
		}
		
		part detectorZ : SiliconPhotodiode {
			attribute :>> activeArea = 100.0 [mm^2];
			attribute :>> responsivity = 0.5;
		}
		
		part amplifierX : TransimpedanceAmplifier {
			attribute :>> gain = 1000000.0;
		}
		
		part amplifierY : TransimpedanceAmplifier {
			attribute :>> gain = 1000000.0;
		}
		
		part amplifierZ : TransimpedanceAmplifier {
			attribute :>> gain = 1000000.0;
		}
		
		part adcX : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0 [Hz];
		}
		
		part adcY : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0 [Hz];
		}
		
		part adcZ : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0 [Hz];
		}
		
		part processor : MicroprocessorUnit;
		
		part display : DisplayModule {
			attribute :>> screenSize = 7.0 [inch];
		}
		
		connect opticalInput to sphere.opticalInput;
		connect sphere.opticalOutput to filterWheel.lightInput;
		
		connect filterWheel.xOutput to detectorX.lightInput;
		connect filterWheel.yOutput to detectorY.lightInput;
		connect filterWheel.zOutput to detectorZ.lightInput;
		
		connect detectorX.signalOutput to amplifierX.currentInput;
		connect detectorY.signalOutput to amplifierY.currentInput;
		connect detectorZ.signalOutput to amplifierZ.currentInput;
		
		connect amplifierX.voltageOutput to adcX.analogInput;
		connect amplifierY.voltageOutput to adcY.analogInput;
		connect amplifierZ.voltageOutput to adcZ.analogInput;
		
		connect adcX.digitalOutput to processor.dataInput;
		connect adcY.digitalOutput to processor.dataInput;
		connect adcZ.digitalOutput to processor.dataInput;
		
		connect processor.dataOutput to display.dataInput;
		connect processor.dataOutput to measurementOutput;
		
		connect systemControl to processor.control;
		connect processor.control to filterWheel.control;
		
		perform action operateColorimeter : MeasureTristimulusColor[*] ordered;
	}
	
	part colorimeterSystem : TristimulusColorimeter {
		doc /* Operational tristimulus colorimeter system instance */
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* Requirement for colorimetric measurement accuracy */
		subject colorimeterSystem;
	}
	
	requirement def SpectralRangeRequirement {
		doc /* Requirement for spectral measurement range */
		subject colorimeterSystem;
	}
	
	requirement def RepeatabilityRequirement {
		doc /* Requirement for measurement repeatability */
		subject colorimeterSystem;
	}
	
	requirement <'REQ-001'> tristimulusAccuracy : MeasurementAccuracyRequirement {
		doc /* The colorimeter shall measure CIE XYZ tristimulus values with accuracy within ±2% of reference values under CIE Standard Illuminant D65 */
		
		require constraint {
			doc /* XYZ measurement error < 2% */
		}
	}
	
	requirement <'REQ-002'> visibleSpectrum : SpectralRangeRequirement {
		doc /* The colorimeter shall operate over the complete visible spectrum from 380 nm to 780 nm */
		
		require constraint {
			doc /* Wavelength range: 380-780 nm */
		}
	}
	
	requirement <'REQ-003'> measurementRepeatability : RepeatabilityRequirement {
		doc /* The colorimeter shall demonstrate repeatability with standard deviation less than 0.001 in chromaticity coordinates for 10 consecutive measurements */
		
		require constraint {
			doc /* Chromaticity repeatability σ(x,y) < 0.001 */
		}
	}
	
	requirement <'REQ-004'> measurementSpeed {
		doc /* The colorimeter shall complete a full tristimulus measurement cycle in less than 2 seconds */
		
		subject colorimeterSystem.operateColorimeter;
		
		require constraint {
			doc /* Measurement cycle time < 2 s */
		}
	}
	
	requirement <'REQ-005'> primaryFunction {
		doc /* The primary function of the tristimulus colorimeter is to objectively measure the color of light stimuli by sequentially filtering incident light through three optical filters matching the CIE standard observer color matching functions, detecting the filtered light intensities, and computing standardized tristimulus values and derived colorimetric quantities including chromaticity coordinates and correlated color temperature */
		
		subject colorimeterSystem;
		
		satisfy tristimulusAccuracy by colorimeterSystem.operateColorimeter;
		satisfy visibleSpectrum by colorimeterSystem.filterWheel;
		satisfy measurementRepeatability by colorimeterSystem.operateColorimeter;
	}
}
