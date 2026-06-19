package MicrobolometerThermalImagerModel {
	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def Temperature :> ISQ::thermodynamicTemperature {
		:>> unit = SI::K;
	}

	attribute def TemperatureDifference :> ISQ::thermodynamicTemperature {
		:>> unit = SI::K;
	}

	attribute def Wavelength :> ISQ::length {
		:>> unit = SI::m;
	}

	attribute def TimeDuration :> ISQ::time {
		:>> unit = SI::s;
	}

	attribute def RadiantPower :> ISQ::power {
		:>> unit = SI::W;
	}

	attribute def ElectricalPowerValue :> ISQ::power {
		:>> unit = SI::W;
	}

	attribute def Voltage :> ISQ::electricPotential {
		:>> unit = SI::V;
	}

	attribute def Current :> ISQ::electricCurrent {
		:>> unit = SI::A;
	}

	attribute def Resistance :> ISQ::resistance {
		:>> unit = SI::Ohm;
	}

	attribute def FrameRate :> ISQ::frequency {
		:>> unit = SI::Hz;
	}

	attribute def PixelPitch :> ISQ::length {
		:>> unit = SI::m;
	}

	attribute def ThermalConductance :> ScalarValues::Real {
		attribute unitSymbol : ScalarValues::String = "W/K";
	}

	attribute def Responsivity :> ScalarValues::Real {
		attribute unitSymbol : ScalarValues::String = "V/W";
	}

	attribute def DataRate :> ScalarValues::Real {
		attribute unitSymbol : ScalarValues::String = "bit/s";
	}

	attribute def PixelCount :> ScalarValues::Integer {
		attribute unitSymbol : ScalarValues::String = "pixel";
	}

	attribute def Fraction :> ScalarValues::Real {
		attribute unitSymbol : ScalarValues::String = "1";
	}

	attribute def DigitalCount :> ScalarValues::Integer {
		attribute unitSymbol : ScalarValues::String = "count";
	}

	item def InfraredPhotonFlux {
		attribute lowerWavelength : Wavelength = 0.000008;
		attribute upperWavelength : Wavelength = 0.000014;
		attribute totalRadiantPower : RadiantPower;
		attribute apparentSceneTemperature : Temperature;
		attribute emissivity : Fraction;
	}

	item def FilteredInfraredFlux :> InfraredPhotonFlux {
		attribute bandpassTransmission : Fraction = 0.85;
	}

	item def SensorBias {
		attribute biasVoltage : Voltage = 3.3;
		attribute biasCurrent : Current = 0.015;
		attribute biasPower : ElectricalPowerValue = 0.0495;
	}

	item def PixelElectricalSignal {
		attribute pixelRow : PixelCount;
		attribute pixelColumn : PixelCount;
		attribute bolometerResistance : Resistance;
		attribute signalVoltage : Voltage;
		attribute integrationTime : TimeDuration;
	}

	item def AnalogVideoSignal {
		attribute lineCount : PixelCount = 288;
		attribute sampleCountPerLine : PixelCount = 384;
		attribute minimumSignalVoltage : Voltage = 0.0;
		attribute maximumSignalVoltage : Voltage = 1.8;
	}

	item def DigitalPixelStream {
		attribute widthPixels : PixelCount = 384;
		attribute heightPixels : PixelCount = 288;
		attribute bitsPerPixel : PixelCount = 14;
		attribute pixelClockRate : FrameRate = 10000000.0;
		attribute dataRate : DataRate = 46448640.0;
	}

	item def ThermalImageFrame {
		attribute widthPixels : PixelCount = 384;
		attribute heightPixels : PixelCount = 288;
		attribute frameRate : FrameRate = 30.0;
		attribute minimumApparentTemperature : Temperature = 233.15;
		attribute maximumApparentTemperature : Temperature = 423.15;
		attribute noiseEquivalentTemperatureDifference : TemperatureDifference = 0.050;
		attribute validPixelFraction : Fraction = 0.99;
		attribute calibrationApplied : ScalarValues::Boolean = true;
	}

	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : Current;
		attribute power : ElectricalPowerValue;
	}

	item def RegulatedPower :> ElectricalPower {
		attribute rippleVoltage : Voltage = 0.010;
	}

	item def HeatFlow {
		attribute thermalPower : RadiantPower;
		attribute sourceTemperature : Temperature;
		attribute sinkTemperature : Temperature;
	}

	item def ImagerCommand {
		attribute powerEnable : ScalarValues::Boolean;
		attribute imagingEnable : ScalarValues::Boolean;
		attribute performCalibration : ScalarValues::Boolean;
		attribute requestedFrameRate : FrameRate = 30.0;
	}

	item def ImagerStatus {
		attribute powered : ScalarValues::Boolean;
		attribute stabilized : ScalarValues::Boolean;
		attribute imaging : ScalarValues::Boolean;
		attribute faultPresent : ScalarValues::Boolean;
		attribute focalPlaneTemperature : Temperature;
		attribute producedFrameRate : FrameRate;
	}

	port def InfraredInputPort {
		in item flux : InfraredPhotonFlux;
	}

	port def InfraredOutputPort {
		out item flux : FilteredInfraredFlux;
	}

	port def BiasInputPort {
		in item bias : SensorBias;
	}

	port def PixelSignalOutputPort {
		out item signal : PixelElectricalSignal;
	}

	port def PixelSignalInputPort {
		in item signal : PixelElectricalSignal;
	}

	port def AnalogVideoOutputPort {
		out item video : AnalogVideoSignal;
	}

	port def AnalogVideoInputPort {
		in item video : AnalogVideoSignal;
	}

	port def DigitalPixelOutputPort {
		out item pixels : DigitalPixelStream;
	}

	port def DigitalPixelInputPort {
		in item pixels : DigitalPixelStream;
	}

	port def ThermalImageOutputPort {
		out item frame : ThermalImageFrame;
	}

	port def ThermalImageInputPort {
		in item frame : ThermalImageFrame;
	}

	port def PowerInputPort {
		in item power : ElectricalPower;
	}

	port def PowerOutputPort {
		out item power : RegulatedPower;
	}

	port def CommandInputPort {
		in item command : ImagerCommand;
	}

	port def StatusOutputPort {
		out item status : ImagerStatus;
	}

	port def HeatInputPort {
		in item heat : HeatFlow;
	}

	port def HeatOutputPort {
		out item heat : HeatFlow;
	}

	action def AdmitLongWaveInfraredBand {
		in item incomingFlux : InfraredPhotonFlux;
		out item filteredFlux : FilteredInfraredFlux;
	}

	action def StabilizeFocalPlaneTemperature {
		in item heatLoad : HeatFlow;
		out item stabilizedStatus : ImagerStatus;
	}

	action def BolometricTransduction {
		in item absorbedFlux : FilteredInfraredFlux;
		in item bias : SensorBias;
		out item pixelSignal : PixelElectricalSignal;
	}

	action def ReadoutPixelArray {
		in item pixelSignal : PixelElectricalSignal;
		out item analogVideo : AnalogVideoSignal;
	}

	action def DigitizeAnalogVideo {
		in item analogVideo : AnalogVideoSignal;
		out item digitalPixels : DigitalPixelStream;
	}

	action def CorrectAndMapTemperature {
		in item digitalPixels : DigitalPixelStream;
		out item thermalFrame : ThermalImageFrame;
	}

	action def PublishThermalImage {
		in item thermalFrame : ThermalImageFrame;
		out item publishedFrame : ThermalImageFrame;
	}

	action def HighLevelThermalImagingFunction {
		in item sceneFlux : InfraredPhotonFlux;
		in item command : ImagerCommand;
		out item imageFrame : ThermalImageFrame;

		action admitBand : AdmitLongWaveInfraredBand;
		then action transduceSceneRadiance : BolometricTransduction;
		then action readArray : ReadoutPixelArray;
		then action digitizeVideo : DigitizeAnalogVideo;
		then action mapToTemperature : CorrectAndMapTemperature;
		then action publishFrame : PublishThermalImage;
	}

	state def PixelState {
		state ambientEquilibrium;
		state absorbingInfraredRadiation;
		state resistanceChanged;
		state sampled;
		state reset;

		transition initialEquilibrium first ambientEquilibrium then absorbingInfraredRadiation;
		transition thermalResponse first absorbingInfraredRadiation then resistanceChanged;
		transition electricalSample first resistanceChanged then sampled;
		transition pixelReset first sampled then reset;
		transition reEquilibrate first reset then ambientEquilibrium;
	}

	state def ImagerOperatingState {
		state off;
		state standby;
		state stabilizing;
		state ready;
		state imaging;
		state calibration;
		state fault;

		transition powerApplied first off then standby;
		transition enableImaging first standby then stabilizing;
		transition temperatureStable first stabilizing then ready;
		transition startFrames first ready then imaging;
		transition requestCalibration first imaging then calibration;
		transition calibrationComplete first calibration then imaging;
		transition detectedFaultFromStandby first standby then fault;
		transition detectedFaultFromImaging first imaging then fault;
		transition resetFault first fault then standby;
		transition powerRemoved first standby then off;
	}

	part def InfraredOptics {
		attribute apertureDiameter : Wavelength = 0.000012;
		attribute spectralBandLower : Wavelength = 0.000008;
		attribute spectralBandUpper : Wavelength = 0.000014;
		attribute transmission : Fraction = 0.85;
		attribute fNumber : Fraction = 1.0;

		port sceneInput : InfraredInputPort;
		port filteredOutput : InfraredOutputPort;

		perform action filtering : AdmitLongWaveInfraredBand;
	}

	part def VacuumPackage {
		attribute internalPressure : ScalarValues::Real = 0.01;
		attribute pressureUnitSymbol : ScalarValues::String = "Pa";
		attribute windowTransmission : Fraction = 0.90;
		attribute thermalIsolationEffectiveness : Fraction = 0.95;

		port incidentIr : InfraredInputPort;
		port transmittedIr : InfraredOutputPort;
		port heatToSink : HeatOutputPort;
	}

	part def MicrobolometerPixel {
		attribute pixelPitch : PixelPitch = 0.000012;
		attribute absorberTemperature : Temperature = 300.15;
		attribute substrateTemperature : Temperature = 300.15;
		attribute nominalResistance : Resistance = 100000.0;
		attribute temperatureCoefficientOfResistance : ScalarValues::Real = -0.02;
		attribute thermalConductance : ThermalConductance = 0.00000007;
		attribute responsivity : Responsivity = 650000.0;

		port incidentIr : InfraredInputPort;
		port biasInput : BiasInputPort;
		port electricalOutput : PixelSignalOutputPort;

		perform action transduction : BolometricTransduction;
		exhibit state pixelLifecycle : PixelState;
	}

	part def MicrobolometerFocalPlaneArray {
		attribute arrayWidth : PixelCount = 384;
		attribute arrayHeight : PixelCount = 288;
		attribute totalPixels : PixelCount = 110592;
		attribute spectralBandLower : Wavelength = 0.000008;
		attribute spectralBandUpper : Wavelength = 0.000014;
		attribute nominalFocalPlaneTemperature : Temperature = 300.15;
		attribute noiseEquivalentTemperatureDifference : TemperatureDifference = 0.050;
		attribute fillFactor : Fraction = 0.80;

		port infraredInput : InfraredInputPort;
		port biasInput : BiasInputPort;
		port pixelSignalOutput : PixelSignalOutputPort;
		port heatOutput : HeatOutputPort;

		part pixels : MicrobolometerPixel[110592];

		perform action convertRadianceToResistanceChange : BolometricTransduction;
	}

	part def ReadoutIntegratedCircuit {
		attribute integrationTime : TimeDuration = 0.000030;
		attribute rowRate : FrameRate = 8640.0;
		attribute outputVoltageMinimum : Voltage = 0.0;
		attribute outputVoltageMaximum : Voltage = 1.8;
		attribute readNoise : Voltage = 0.0005;

		port pixelSignalInput : PixelSignalInputPort;
		port biasOutput : PowerOutputPort;
		port analogVideoOutput : AnalogVideoOutputPort;

		perform action rowColumnReadout : ReadoutPixelArray;
	}

	part def AnalogToDigitalConverter {
		attribute resolutionBits : PixelCount = 14;
		attribute sampleRate : FrameRate = 10000000.0;
		attribute referenceVoltage : Voltage = 1.8;
		attribute quantizationLevels : DigitalCount = 16384;

		port analogInput : AnalogVideoInputPort;
		port digitalOutput : DigitalPixelOutputPort;

		perform action digitization : DigitizeAnalogVideo;
	}

	part def ImageProcessingUnit {
		attribute badPixelReplacementEnabled : ScalarValues::Boolean = true;
		attribute nonUniformityCorrectionEnabled : ScalarValues::Boolean = true;
		attribute radiometricMappingEnabled : ScalarValues::Boolean = true;
		attribute outputFrameRate : FrameRate = 30.0;
		attribute outputWidth : PixelCount = 384;
		attribute outputHeight : PixelCount = 288;

		port digitalInput : DigitalPixelInputPort;
		port thermalImageOutput : ThermalImageOutputPort;

		perform action correctionAndTemperatureMapping : CorrectAndMapTemperature;
	}

	part def FocalPlaneThermalStabilizer {
		attribute setPointTemperature : Temperature = 300.15;
		attribute controlTolerance : TemperatureDifference = 0.020;
		attribute maximumHeatRemoval : RadiantPower = 0.50;
		attribute stabilizationTime : TimeDuration = 2.0;

		port heatInput : HeatInputPort;
		port statusOutput : StatusOutputPort;

		perform action stabilize : StabilizeFocalPlaneTemperature;
	}

	part def PowerConditioningUnit {
		attribute inputVoltageNominal : Voltage = 5.0;
		attribute detectorBiasVoltage : Voltage = 3.3;
		attribute logicVoltage : Voltage = 1.8;
		attribute maximumInputPower : ElectricalPowerValue = 2.5;
		attribute conversionEfficiency : Fraction = 0.88;

		port externalPowerInput : PowerInputPort;
		port detectorBiasOutput : PowerOutputPort;
		port electronicsPowerOutput : PowerOutputPort;
	}

	part def CommandAndStatusController {
		attribute commandedFrameRate : FrameRate = 30.0;
		attribute faultLatched : ScalarValues::Boolean = false;
		attribute powerEnabled : ScalarValues::Boolean = false;
		attribute imagingEnabled : ScalarValues::Boolean = false;

		port commandInput : CommandInputPort;
		port statusOutput : StatusOutputPort;
		port processedFrameInput : ThermalImageInputPort;

		exhibit state operatingState : ImagerOperatingState;
	}

	part def MicrobolometerThermalImager {
		attribute primaryFunctionDescription : ScalarValues::String = "Convert incident long-wave infrared scene radiation into calibrated digital thermal image frames representing apparent scene temperature.";
		attribute spectralBandLower : Wavelength = 0.000008;
		attribute spectralBandUpper : Wavelength = 0.000014;
		attribute nominalFrameRate : FrameRate = 30.0;
		attribute imageWidth : PixelCount = 384;
		attribute imageHeight : PixelCount = 288;
		attribute netd : TemperatureDifference = 0.050;
		attribute validPixelFraction : Fraction = 0.99;
		attribute maximumInputPower : ElectricalPowerValue = 2.5;
		attribute operatingTemperatureMinimum : Temperature = 253.15;
		attribute operatingTemperatureMaximum : Temperature = 333.15;

		port sceneInput : InfraredInputPort;
		port powerInput : PowerInputPort;
		port commandInput : CommandInputPort;
		port thermalImageOutput : ThermalImageOutputPort;
		port statusOutput : StatusOutputPort;

		part optics : InfraredOptics;
		part package : VacuumPackage;
		part focalPlane : MicrobolometerFocalPlaneArray;
		part roic : ReadoutIntegratedCircuit;
		part adc : AnalogToDigitalConverter;
		part processor : ImageProcessingUnit;
		part stabilizer : FocalPlaneThermalStabilizer;
		part powerUnit : PowerConditioningUnit;
		part controller : CommandAndStatusController;

		connect sceneToOptics from sceneInput to optics.sceneInput;
		connect opticsToPackage from optics.filteredOutput to package.incidentIr;
		connect packageToFocalPlane from package.transmittedIr to focalPlane.infraredInput;
		connect focalPlaneToRoic from focalPlane.pixelSignalOutput to roic.pixelSignalInput;
		connect roicToAdc from roic.analogVideoOutput to adc.analogInput;
		connect adcToProcessor from adc.digitalOutput to processor.digitalInput;
		connect processorToOutput from processor.thermalImageOutput to thermalImageOutput;
		connect externalPowerToConditioner from powerInput to powerUnit.externalPowerInput;
		connect biasToFocalPlane from powerUnit.detectorBiasOutput to focalPlane.biasInput;
		connect electronicsPowerToRoic from powerUnit.electronicsPowerOutput to roic.biasOutput;
		connect heatToStabilizer from focalPlane.heatOutput to stabilizer.heatInput;
		connect commandToController from commandInput to controller.commandInput;
		connect controllerStatusToSystem from controller.statusOutput to statusOutput;
		connect processedFrameToController from processor.thermalImageOutput to controller.processedFrameInput;

		perform action primaryThermalImagingFunction : HighLevelThermalImagingFunction;
		exhibit state lifecycle : ImagerOperatingState;
	}

	constraint def LongWaveInfraredBandConstraint {
		in lower : Wavelength;
		in upper : Wavelength;

		constraint bandIsLongWaveInfrared {
			lower <= 0.000008 and upper >= 0.000014 and lower < upper
		}
	}

	constraint def ThermalImageQualityConstraint {
		in frameRate : FrameRate;
		in netd : TemperatureDifference;
		in validPixels : Fraction;

		constraint qualityAcceptable {
			frameRate >= 30.0 and netd <= 0.050 and validPixels >= 0.98
		}
	}

	constraint def PowerLimitConstraint {
		in consumedPower : ElectricalPowerValue;

		constraint withinPowerLimit {
			consumedPower <= 2.5
		}
	}

	requirement def PrimaryFunctionRequirement {
		subject imager : MicrobolometerThermalImager;

		require constraint primaryFunctionPerformance {
			imager.spectralBandLower <= 0.000008 and
			imager.spectralBandUpper >= 0.000014 and
			imager.nominalFrameRate >= 30.0 and
			imager.imageWidth == 384 and
			imager.imageHeight == 288
		}
	}

	requirement def ThermalSensitivityRequirement {
		subject imager : MicrobolometerThermalImager;

		require constraint sensitivityPerformance {
			imager.netd <= 0.050 and imager.validPixelFraction >= 0.98
		}
	}

	requirement def PowerConsumptionRequirement {
		subject imager : MicrobolometerThermalImager;

		require constraint powerPerformance {
			imager.maximumInputPower <= 2.5
		}
	}

	requirement def OperatingEnvironmentRequirement {
		subject imager : MicrobolometerThermalImager;

		require constraint temperatureRange {
			imager.operatingTemperatureMinimum <= 253.15 and
			imager.operatingTemperatureMaximum >= 333.15
		}
	}

	part microbolometerSystem : MicrobolometerThermalImager;

	requirement primaryFunction : PrimaryFunctionRequirement {
		subject imager = microbolometerSystem;
	}

	requirement thermalSensitivity : ThermalSensitivityRequirement {
		subject imager = microbolometerSystem;
	}

	requirement powerConsumption : PowerConsumptionRequirement {
		subject imager = microbolometerSystem;
	}

	requirement operatingEnvironment : OperatingEnvironmentRequirement {
		subject imager = microbolometerSystem;
	}

	satisfy primaryFunction by microbolometerSystem;
	satisfy thermalSensitivity by microbolometerSystem;
	satisfy powerConsumption by microbolometerSystem;
	satisfy operatingEnvironment by microbolometerSystem;
}
