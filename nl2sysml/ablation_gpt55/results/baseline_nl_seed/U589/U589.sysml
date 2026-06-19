package ActivePixelSensingUnitModel {
    import ScalarValues::*;

    enum def SensorCommandKind {
        enum powerOn;
        enum powerOff;
        enum enterStandby;
        enum acquireSingleFrame;
        enum acquireContinuousFrames;
        enum stopAcquisition;
        enum calibrateDarkFrame;
        enum resetFault;
    }

    enum def SensorHealthKind {
        enum nominal;
        enum warmingUp;
        enum saturated;
        enum underExposed;
        enum communicationFault;
        enum powerFault;
        enum temperatureFault;
        enum opticalPathFault;
    }

    enum def ShutterModeKind {
        enum rollingShutter;
        enum globalResetRollingReadout;
        enum globalShutter;
    }

    attribute def IlluminanceValue :> Real {
        attribute unitSymbol: String = "lx";
        attribute quantityKind: String = "illuminance";
    }

    attribute def IrradianceValue :> Real {
        attribute unitSymbol: String = "W/m^2";
        attribute quantityKind: String = "irradiance";
    }

    attribute def WavelengthValue :> Real {
        attribute unitSymbol: String = "nm";
        attribute quantityKind: String = "optical wavelength";
    }

    attribute def TimeValue :> Real {
        attribute unitSymbol: String = "s";
        attribute quantityKind: String = "time";
    }

    attribute def FrequencyValue :> Real {
        attribute unitSymbol: String = "Hz";
        attribute quantityKind: String = "frequency";
    }

    attribute def VoltageValue :> Real {
        attribute unitSymbol: String = "V";
        attribute quantityKind: String = "electric potential";
    }

    attribute def CurrentValue :> Real {
        attribute unitSymbol: String = "A";
        attribute quantityKind: String = "electric current";
    }

    attribute def PowerValue :> Real {
        attribute unitSymbol: String = "W";
        attribute quantityKind: String = "power";
    }

    attribute def TemperatureValue :> Real {
        attribute unitSymbol: String = "degC";
        attribute quantityKind: String = "temperature";
    }

    attribute def LengthValue :> Real {
        attribute unitSymbol: String = "um";
        attribute quantityKind: String = "length";
    }

    attribute def PercentValue :> Real {
        attribute unitSymbol: String = "%";
        attribute quantityKind: String = "ratio";
    }

    attribute def ElectronCountValue :> Real {
        attribute unitSymbol: String = "e-";
        attribute quantityKind: String = "electric charge in electrons";
    }

    attribute def DigitalNumberValue :> Integer {
        attribute unitSymbol: String = "DN";
        attribute quantityKind: String = "digital code";
    }

    attribute def PixelCountValue :> Integer {
        attribute unitSymbol: String = "pixel";
        attribute quantityKind: String = "pixel count";
    }

    attribute def GainValue :> Real {
        attribute unitSymbol: String = "V/e-";
        attribute quantityKind: String = "conversion gain";
    }

    item def OpticalRadiation {
        attribute illuminance: IlluminanceValue;
        attribute irradiance: IrradianceValue;
        attribute dominantWavelength: WavelengthValue;
        attribute spectralRangeMin: WavelengthValue;
        attribute spectralRangeMax: WavelengthValue;
        attribute fieldOfViewHorizontal: Real;
        attribute fieldOfViewVertical: Real;
    }

    item def ElectricalPower {
        attribute voltage: VoltageValue;
        attribute current: CurrentValue;
        attribute power: PowerValue;
        attribute ripple: VoltageValue;
    }

    item def SensorCommand {
        attribute commandKind: SensorCommandKind;
        attribute requestedExposureTime: TimeValue;
        attribute requestedAnalogGain: Real;
        attribute requestedFrameRate: FrequencyValue;
    }

    item def SensorStatus {
        attribute health: SensorHealthKind;
        attribute focalPlaneTemperature: TemperatureValue;
        attribute actualExposureTime: TimeValue;
        attribute actualAnalogGain: Real;
        attribute actualFrameRate: FrequencyValue;
        attribute saturationFraction: PercentValue;
    }

    item def TimingPattern {
        attribute resetPulseWidth: TimeValue;
        attribute integrationTime: TimeValue;
        attribute rowPeriod: TimeValue;
        attribute framePeriod: TimeValue;
        attribute shutterMode: ShutterModeKind;
    }

    item def PixelAnalogSignal {
        attribute resetLevel: VoltageValue;
        attribute signalLevel: VoltageValue;
        attribute correlatedSignal: VoltageValue;
        attribute columnIndex: PixelCountValue;
        attribute rowIndex: PixelCountValue;
    }

    item def RawDigitalPixel {
        attribute rowIndex: PixelCountValue;
        attribute columnIndex: PixelCountValue;
        attribute rawCode: DigitalNumberValue;
        attribute bitDepth: Integer;
    }

    item def RawImageFrame {
        attribute width: PixelCountValue;
        attribute height: PixelCountValue;
        attribute bitDepth: Integer;
        attribute exposureTime: TimeValue;
        attribute frameTimestamp: TimeValue;
        attribute meanRawCode: DigitalNumberValue;
        attribute saturatedPixelCount: PixelCountValue;
    }

    item def CalibratedMeasurementFrame {
        attribute width: PixelCountValue;
        attribute height: PixelCountValue;
        attribute measuredQuantityName: String;
        attribute measuredIlluminance: IlluminanceValue;
        attribute uncertaintyPercent: PercentValue;
        attribute exposureTime: TimeValue;
        attribute frameTimestamp: TimeValue;
        attribute darkCorrectedMeanCode: DigitalNumberValue;
        attribute saturatedPixelCount: PixelCountValue;
    }

    port def OpticalInputPort {
        in item incidentRadiation: OpticalRadiation;
    }

    port def OpticalOutputPort {
        out item transmittedRadiation: OpticalRadiation;
    }

    port def PowerInputPort {
        in item supply: ElectricalPower;
    }

    port def SensorControlPort {
        in item command: SensorCommand;
        out item status: SensorStatus;
    }

    port def TimingOutputPort {
        out item timing: TimingPattern;
    }

    port def TimingInputPort {
        in item timing: TimingPattern;
    }

    port def AnalogSignalOutputPort {
        out item analogPixel: PixelAnalogSignal;
    }

    port def AnalogSignalInputPort {
        in item analogPixel: PixelAnalogSignal;
    }

    port def RawDigitalOutputPort {
        out item rawPixel: RawDigitalPixel;
        out item rawFrame: RawImageFrame;
    }

    port def RawDigitalInputPort {
        in item rawPixel: RawDigitalPixel;
        in item rawFrame: RawImageFrame;
    }

    port def MeasurementOutputPort {
        out item measurementFrame: CalibratedMeasurementFrame;
    }

    part def ObjectiveLens {
        attribute apertureDiameter: LengthValue = 3500.0;
        attribute focalLength: LengthValue = 4200.0;
        attribute transmission: PercentValue = 92.0;
        attribute horizontalFieldOfView: Real = 62.0;
        attribute verticalFieldOfView: Real = 48.0;

        port sceneIn: OpticalInputPort;
        port focusedOut: OpticalOutputPort;
    }

    part def OpticalBandpassFilter {
        attribute passBandMin: WavelengthValue = 400.0;
        attribute passBandMax: WavelengthValue = 700.0;
        attribute peakTransmission: PercentValue = 88.0;
        attribute outOfBandRejection: PercentValue = 99.0;

        port unfilteredIn: OpticalInputPort;
        port filteredOut: OpticalOutputPort;
    }

    part def ActivePixelSensorArray {
        attribute technology: String = "CMOS active pixel sensor";
        attribute pixelColumns: PixelCountValue = 1920;
        attribute pixelRows: PixelCountValue = 1080;
        attribute pixelPitch: LengthValue = 2.2;
        attribute activeAreaWidth: LengthValue = 4224.0;
        attribute activeAreaHeight: LengthValue = 2376.0;
        attribute quantumEfficiencyAt550nm: PercentValue = 62.0;
        attribute fullWellCapacity: ElectronCountValue = 9500.0;
        attribute darkCurrentAt25C: ElectronCountValue = 4.0;
        attribute readNoise: ElectronCountValue = 2.1;
        attribute conversionGain: GainValue = 0.000085;
        attribute supportedShutterMode: ShutterModeKind = ShutterModeKind::rollingShutter;

        port opticalIn: OpticalInputPort;
        port powerIn: PowerInputPort;
        port timingIn: TimingInputPort;
        port analogOut: AnalogSignalOutputPort;
    }

    part def AnalogFrontEnd {
        attribute inputReferredNoise: VoltageValue = 0.00035;
        attribute programmableGainMin: Real = 1.0;
        attribute programmableGainMax: Real = 16.0;
        attribute correlatedDoubleSamplingEnabled: Boolean = true;
        attribute blackLevelClamp: DigitalNumberValue = 64;

        port analogIn: AnalogSignalInputPort;
        port powerIn: PowerInputPort;
        port conditionedOut: AnalogSignalOutputPort;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits: Integer = 12;
        attribute sampleRate: FrequencyValue = 74250000.0;
        attribute referenceVoltage: VoltageValue = 1.2;
        attribute integralNonlinearity: DigitalNumberValue = 2;

        port analogIn: AnalogSignalInputPort;
        port powerIn: PowerInputPort;
        port digitalOut: RawDigitalOutputPort;
    }

    part def TimingAndBiasController {
        attribute masterClockFrequency: FrequencyValue = 24000000.0;
        attribute minimumExposureTime: TimeValue = 0.000020;
        attribute maximumExposureTime: TimeValue = 0.500000;
        attribute nominalFrameRate: FrequencyValue = 30.0;
        attribute biasVoltage: VoltageValue = 2.8;

        port control: SensorControlPort;
        port powerIn: PowerInputPort;
        port timingOut: TimingOutputPort;
    }

    part def ImageSignalProcessor {
        attribute darkFrameSubtractionEnabled: Boolean = true;
        attribute flatFieldCorrectionEnabled: Boolean = true;
        attribute linearizationEnabled: Boolean = true;
        attribute calibrationConstantLuxPerCode: Real = 0.0185;
        attribute maximumMeasurementError: PercentValue = 5.0;
        attribute outputQuantityName: String = "incident illuminance";

        port rawIn: RawDigitalInputPort;
        port control: SensorControlPort;
        port measurementOut: MeasurementOutputPort;
    }

    part def ThermalMonitor {
        attribute warningTemperature: TemperatureValue = 70.0;
        attribute shutdownTemperature: TemperatureValue = 85.0;
        attribute measurementResolution: TemperatureValue = 0.5;

        port powerIn: PowerInputPort;
        port control: SensorControlPort;
    }

    part def ActivePixelSensingUnit {
        attribute measuredQuantityName: String = "incident illuminance";
        attribute spectralRangeMin: WavelengthValue = 400.0;
        attribute spectralRangeMax: WavelengthValue = 700.0;
        attribute minimumMeasurableIlluminance: IlluminanceValue = 0.5;
        attribute maximumMeasurableIlluminance: IlluminanceValue = 100000.0;
        attribute measurementErrorPercent: PercentValue = 5.0;
        attribute outputFrameRate: FrequencyValue = 30.0;
        attribute nominalSupplyVoltage: VoltageValue = 3.3;
        attribute nominalSupplyPower: PowerValue = 1.8;
        attribute operatingTemperatureMin: TemperatureValue = -20.0;
        attribute operatingTemperatureMax: TemperatureValue = 60.0;

        port opticalAperture: OpticalInputPort;
        port power: PowerInputPort;
        port control: SensorControlPort;
        port measurementOut: MeasurementOutputPort;

        part objective: ObjectiveLens;
        part visibleFilter: OpticalBandpassFilter;
        part aps: ActivePixelSensorArray;
        part analogFrontEnd: AnalogFrontEnd;
        part adc: AnalogToDigitalConverter;
        part timingController: TimingAndBiasController;
        part processor: ImageSignalProcessor;
        part thermalMonitor: ThermalMonitor;

        connection opticalApertureToLens connect opticalAperture to objective.sceneIn;
        connection lensToFilter connect objective.focusedOut to visibleFilter.unfilteredIn;
        connection filterToAps connect visibleFilter.filteredOut to aps.opticalIn;

        connection unitPowerToAps connect power to aps.powerIn;
        connection unitPowerToAfe connect power to analogFrontEnd.powerIn;
        connection unitPowerToAdc connect power to adc.powerIn;
        connection unitPowerToTiming connect power to timingController.powerIn;
        connection unitPowerToThermalMonitor connect power to thermalMonitor.powerIn;

        connection unitControlToTiming connect control to timingController.control;
        connection unitControlToProcessor connect control to processor.control;
        connection unitControlToThermalMonitor connect control to thermalMonitor.control;

        connection timingToAps connect timingController.timingOut to aps.timingIn;
        connection apsAnalogToAfe connect aps.analogOut to analogFrontEnd.analogIn;
        connection afeToAdc connect analogFrontEnd.conditionedOut to adc.analogIn;
        connection adcToProcessor connect adc.digitalOut to processor.rawIn;
        connection processorToUnitOutput connect processor.measurementOut to measurementOut;

        exhibit state operatingState: SensingUnitOperatingState;
        perform action measurementBehavior: AcquireIlluminanceWithActivePixelSensor;
    }

    action def AcquireIlluminanceWithActivePixelSensor {
        in item sceneRadiation: OpticalRadiation;
        in item command: SensorCommand;
        in item supply: ElectricalPower;
        out item measurementFrame: CalibratedMeasurementFrame;
        out item status: SensorStatus;

        action validateCommand;
        action applyBiasAndTiming;
        action resetPixelPhotodiodes;
        action integratePhotochargeInActivePixels;
        action readPixelSourceFollowers;
        action performCorrelatedDoubleSampling;
        action convertAnalogLevelsToDigitalCodes;
        action subtractDarkFrame;
        action applyFlatFieldCalibration;
        action computeIncidentIlluminance;
        action publishCalibratedFrame;
    }

    item def PowerOnCommand :> SensorCommand;
    item def PowerOffCommand :> SensorCommand;
    item def StandbyCommand :> SensorCommand;
    item def AcquireSingleFrameCommand :> SensorCommand;
    item def AcquireContinuousFramesCommand :> SensorCommand;
    item def StopAcquisitionCommand :> SensorCommand;
    item def CalibrateDarkFrameCommand :> SensorCommand;
    item def ResetFaultCommand :> SensorCommand;

    state def SensingUnitOperatingState {
        entry; then poweredOff;

        state poweredOff;
        accept PowerOnCommand then initializing;

        state initializing;
        then standby;

        state standby;
        accept AcquireSingleFrameCommand then exposing;
        accept AcquireContinuousFramesCommand then exposing;
        accept CalibrateDarkFrameCommand then darkCalibration;
        accept PowerOffCommand then poweredOff;

        state darkCalibration;
        then standby;

        state exposing;
        accept StopAcquisitionCommand then standby;
        then readout;

        state readout;
        then processing;

        state processing;
        then publishing;

        state publishing;
        accept AcquireContinuousFramesCommand then exposing;
        then standby;

        state fault;
        accept ResetFaultCommand then standby;
        accept PowerOffCommand then poweredOff;
    }

    constraint def IlluminanceRangeConstraint {
        in measured: IlluminanceValue;
        in minimumAllowed: IlluminanceValue;
        in maximumAllowed: IlluminanceValue;
        measured >= minimumAllowed and measured <= maximumAllowed
    }

    constraint def PercentAtMostConstraint {
        in actual: PercentValue;
        in allowed: PercentValue;
        actual <= allowed
    }

    constraint def SpectralBandConstraint {
        in lowerWavelength: WavelengthValue;
        in upperWavelength: WavelengthValue;
        lowerWavelength <= 400.0 and upperWavelength >= 700.0
    }

    constraint def SupplyVoltageConstraint {
        in voltage: VoltageValue;
        voltage >= 3.0 and voltage <= 3.6
    }

    requirement def RelevantQuantityMeasurementRequirement {
        subject unit: ActivePixelSensingUnit;

        attribute requiredMeasuredQuantityName: String = "incident illuminance";
        attribute allowedMeasurementError: PercentValue = 5.0;
        attribute requiredMinimumIlluminance: IlluminanceValue = 0.5;
        attribute requiredMaximumIlluminance: IlluminanceValue = 100000.0;

        require constraint { unit.measuredQuantityName == requiredMeasuredQuantityName }
        require constraint { unit.measurementErrorPercent <= allowedMeasurementError }
        require constraint { unit.minimumMeasurableIlluminance <= requiredMinimumIlluminance }
        require constraint { unit.maximumMeasurableIlluminance >= requiredMaximumIlluminance }
    }

    requirement def ActivePixelSensorTechnologyRequirement {
        subject unit: ActivePixelSensingUnit;

        attribute requiredTechnology: String = "CMOS active pixel sensor";
        attribute minimumColumns: PixelCountValue = 1280;
        attribute minimumRows: PixelCountValue = 720;
        attribute maximumReadNoise: ElectronCountValue = 3.0;

        require constraint { unit.aps.technology == requiredTechnology }
        require constraint { unit.aps.pixelColumns >= minimumColumns }
        require constraint { unit.aps.pixelRows >= minimumRows }
        require constraint { unit.aps.readNoise <= maximumReadNoise }
    }

    requirement def VisibleBandOpticalRequirement {
        subject unit: ActivePixelSensingUnit;

        attribute requiredBandMin: WavelengthValue = 400.0;
        attribute requiredBandMax: WavelengthValue = 700.0;
        attribute minimumFilterTransmission: PercentValue = 80.0;

        require constraint { unit.spectralRangeMin <= requiredBandMin }
        require constraint { unit.spectralRangeMax >= requiredBandMax }
        require constraint { unit.visibleFilter.peakTransmission >= minimumFilterTransmission }
    }

    requirement def ElectricalPowerRequirement {
        subject unit: ActivePixelSensingUnit;

        attribute nominalVoltageMinimum: VoltageValue = 3.0;
        attribute nominalVoltageMaximum: VoltageValue = 3.6;
        attribute maximumPower: PowerValue = 2.5;

        require constraint { unit.nominalSupplyVoltage >= nominalVoltageMinimum }
        require constraint { unit.nominalSupplyVoltage <= nominalVoltageMaximum }
        require constraint { unit.nominalSupplyPower <= maximumPower }
    }

    requirement def OutputFrameRequirement {
        subject unit: ActivePixelSensingUnit;

        attribute minimumFrameRate: FrequencyValue = 10.0;
        attribute requiredOutputQuantity: String = "incident illuminance";

        require constraint { unit.outputFrameRate >= minimumFrameRate }
        require constraint { unit.processor.outputQuantityName == requiredOutputQuantity }
    }

    part activePixelSensingUnit: ActivePixelSensingUnit;

    requirement relevantQuantityMeasurement: RelevantQuantityMeasurementRequirement {
        subject unit = activePixelSensingUnit;
    }

    requirement activePixelSensorTechnology: ActivePixelSensorTechnologyRequirement {
        subject unit = activePixelSensingUnit;
    }

    requirement visibleBandOpticalPerformance: VisibleBandOpticalRequirement {
        subject unit = activePixelSensingUnit;
    }

    requirement electricalPowerPerformance: ElectricalPowerRequirement {
        subject unit = activePixelSensingUnit;
    }

    requirement outputFramePerformance: OutputFrameRequirement {
        subject unit = activePixelSensingUnit;
    }
}
