package TristimulusColorimeterModel {

    import ScalarValues::*;
    import SI::*;

    metadata def UnitSymbol {
        attribute symbol: String;
    }

    attribute def Wavelength :> Real {
        @UnitSymbol { symbol = "nm"; }
    }

    attribute def SpectralIrradiance :> Real {
        @UnitSymbol { symbol = "W/m^2/nm"; }
    }

    attribute def Irradiance :> Real {
        @UnitSymbol { symbol = "W/m^2"; }
    }

    attribute def Illuminance :> Real {
        @UnitSymbol { symbol = "lx"; }
    }

    attribute def Luminance :> Real {
        @UnitSymbol { symbol = "cd/m^2"; }
    }

    attribute def ElectricPotential :> Real {
        @UnitSymbol { symbol = "V"; }
    }

    attribute def ElectricCurrent :> Real {
        @UnitSymbol { symbol = "A"; }
    }

    attribute def ElectricPower :> Real {
        @UnitSymbol { symbol = "W"; }
    }

    attribute def Temperature :> Real {
        @UnitSymbol { symbol = "degC"; }
    }

    attribute def Duration :> Real {
        @UnitSymbol { symbol = "s"; }
    }

    attribute def Frequency :> Real {
        @UnitSymbol { symbol = "Hz"; }
    }

    attribute def DigitalCount :> Integer {
        @UnitSymbol { symbol = "count"; }
    }

    attribute def ChromaticityCoordinate :> Real {
        @UnitSymbol { symbol = "1"; }
    }

    attribute def TristimulusValue :> Real {
        @UnitSymbol { symbol = "1"; }
    }

    attribute def ColorTemperature :> Real {
        @UnitSymbol { symbol = "K"; }
    }

    attribute def DeltaE :> Real {
        @UnitSymbol { symbol = "1"; }
    }

    attribute def Percent :> Real {
        @UnitSymbol { symbol = "%"; }
    }

    attribute def BitRate :> Real {
        @UnitSymbol { symbol = "bit/s"; }
    }

    enum def MeasurementMode {
        enum idle;
        enum singleSample;
        enum continuous;
        enum calibration;
        enum diagnostics;
    }

    enum def HealthStatus {
        enum nominal;
        enum degraded;
        enum faulted;
        enum calibrationRequired;
    }

    enum def MeasurementValidity {
        enum valid;
        enum saturated;
        enum underRange;
        enum unstable;
        enum invalid;
    }

    enum def ColorSpace {
        enum CIE1931_XYZ;
        enum CIE1931_xyY;
        enum CIE1976_uprimevprime;
        enum sRGB;
    }

    enum def InterfaceProtocol {
        enum USB_CDC;
        enum I2C;
        enum SPI;
        enum UART;
        enum Ethernet;
    }

    item def IncidentVisibleLight {
        attribute wavelengthMin: Wavelength = 380.0;
        attribute wavelengthMax: Wavelength = 780.0;
        attribute irradiance: Irradiance;
        attribute illuminanceEstimate: Illuminance;
        attribute sourceModulationFrequency: Frequency;
    }

    item def SpectralSample {
        attribute wavelength: Wavelength;
        attribute spectralIrradiance: SpectralIrradiance;
    }

    item def OpticalChannelSignal {
        attribute channelName: String;
        attribute filteredIrradiance: Irradiance;
        attribute detectorCurrent: ElectricCurrent;
        attribute integrationTime: Duration;
        attribute saturated: Boolean;
    }

    item def RawAdcFrame {
        attribute xCounts: DigitalCount;
        attribute yCounts: DigitalCount;
        attribute zCounts: DigitalCount;
        attribute darkCountsX: DigitalCount;
        attribute darkCountsY: DigitalCount;
        attribute darkCountsZ: DigitalCount;
        attribute integrationTime: Duration;
        attribute detectorTemperature: Temperature;
    }

    item def CalibrationCoefficients {
        attribute matrixXX: Real;
        attribute matrixXY: Real;
        attribute matrixXZ: Real;
        attribute matrixYX: Real;
        attribute matrixYY: Real;
        attribute matrixYZ: Real;
        attribute matrixZX: Real;
        attribute matrixZY: Real;
        attribute matrixZZ: Real;
        attribute darkOffsetX: DigitalCount;
        attribute darkOffsetY: DigitalCount;
        attribute darkOffsetZ: DigitalCount;
        attribute temperatureCoefficientX: Real;
        attribute temperatureCoefficientY: Real;
        attribute temperatureCoefficientZ: Real;
        attribute validFromTemperature: Temperature;
        attribute validToTemperature: Temperature;
    }

    item def XYZColorMeasurement {
        attribute X: TristimulusValue;
        attribute Y: TristimulusValue;
        attribute Z: TristimulusValue;
        attribute illuminance: Illuminance;
        attribute detectorTemperature: Temperature;
        attribute integrationTime: Duration;
        attribute validity: MeasurementValidity;
    }

    item def xyYColorMeasurement {
        attribute x: ChromaticityCoordinate;
        attribute y: ChromaticityCoordinate;
        attribute Y: Luminance;
        attribute illuminance: Illuminance;
        attribute correlatedColorTemperature: ColorTemperature;
        attribute validity: MeasurementValidity;
    }

    item def ColorMeasurementReport {
        attribute timestampSeconds: Duration;
        attribute mode: MeasurementMode;
        attribute colorSpace: ColorSpace;
        attribute X: TristimulusValue;
        attribute Y: TristimulusValue;
        attribute Z: TristimulusValue;
        attribute x: ChromaticityCoordinate;
        attribute y: ChromaticityCoordinate;
        attribute illuminance: Illuminance;
        attribute correlatedColorTemperature: ColorTemperature;
        attribute deltaEToReference: DeltaE;
        attribute validity: MeasurementValidity;
        attribute health: HealthStatus;
    }

    item def CommandMessage {
        attribute commandId: String;
        attribute requestedMode: MeasurementMode;
        attribute requestedIntegrationTime: Duration;
        attribute requestedReportRate: Frequency;
        attribute requestedColorSpace: ColorSpace;
    }

    item def StatusMessage {
        attribute health: HealthStatus;
        attribute activeMode: MeasurementMode;
        attribute detectorTemperature: Temperature;
        attribute supplyVoltage: ElectricPotential;
        attribute lastErrorCode: String;
    }

    item def ElectricalEnergy {
        attribute voltage: ElectricPotential;
        attribute current: ElectricCurrent;
        attribute power: ElectricPower;
    }

    port def LightInputPort {
        in item incidentLight: IncidentVisibleLight;
    }

    port def FilteredOpticalPort {
        out item filteredSignal: OpticalChannelSignal;
    }

    port def DetectorSignalPort {
        out item detectorSignal: OpticalChannelSignal;
    }

    port def AdcDataPort {
        out item adcFrame: RawAdcFrame;
    }

    port def CalibrationDataPort {
        out item coefficients: CalibrationCoefficients;
    }

    port def ColorResultPort {
        out item report: ColorMeasurementReport;
    }

    port def CommandPort {
        in item command: CommandMessage;
    }

    port def StatusPort {
        out item status: StatusMessage;
    }

    port def PowerInputPort {
        in item powerIn: ElectricalEnergy;
    }

    port def PowerDistributionPort {
        out item regulatedPower: ElectricalEnergy;
    }

    interface def OpticalSamplingInterface {
        end source: LightInputPort;
        end receiver: LightInputPort;
    }

    interface def SignalTransferInterface {
        end source: DetectorSignalPort;
        end receiver: DetectorSignalPort;
    }

    interface def DigitalFrameInterface {
        end source: AdcDataPort;
        end receiver: AdcDataPort;
    }

    interface def CalibrationInterface {
        end source: CalibrationDataPort;
        end receiver: CalibrationDataPort;
    }

    interface def ReportInterface {
        end source: ColorResultPort;
        end receiver: ColorResultPort;
    }

    interface def CommandInterface {
        end source: CommandPort;
        end receiver: CommandPort;
    }

    interface def StatusInterface {
        end source: StatusPort;
        end receiver: StatusPort;
    }

    interface def PowerInterface {
        end source: PowerDistributionPort;
        end receiver: PowerInputPort;
    }

    part def Aperture {
        attribute clearDiameter: Real = 8.0;
        attribute fieldOfViewDegrees: Real = 2.0;
        attribute strayLightRejection: Percent = 99.0;
        port sceneLight: LightInputPort;
        port conditionedLight: LightInputPort;
    }

    part def Diffuser {
        attribute material: String = "PTFE cosine diffuser";
        attribute transmittance: Percent = 78.0;
        attribute angularErrorAt60Degrees: Percent = 3.0;
        port incomingLight: LightInputPort;
        port uniformLight: LightInputPort;
    }

    part def TristimulusFilterSet {
        attribute functionBasis: String = "Approximation to CIE 1931 2-degree color matching functions";
        attribute xFilterPeak: Wavelength = 600.0;
        attribute yFilterPeak: Wavelength = 555.0;
        attribute zFilterPeak: Wavelength = 445.0;
        attribute outOfBandBlocking: Percent = 99.5;
        port mixedLight: LightInputPort;
        port xBand: FilteredOpticalPort;
        port yBand: FilteredOpticalPort;
        port zBand: FilteredOpticalPort;
    }

    part def SiliconPhotodiode {
        attribute activeArea: Real = 2.4;
        attribute responsivityAt555nm: Real = 0.32;
        attribute darkCurrentAt25C: ElectricCurrent = 0.000000001;
        attribute saturationCurrent: ElectricCurrent = 0.001;
        attribute detectorTemperature: Temperature;
        port opticalInput: LightInputPort;
        port currentOutput: DetectorSignalPort;
    }

    part def TristimulusDetectorArray {
        part xDetector: SiliconPhotodiode {
            attribute responsivityAt555nm = 0.20;
        }
        part yDetector: SiliconPhotodiode {
            attribute responsivityAt555nm = 0.32;
        }
        part zDetector: SiliconPhotodiode {
            attribute responsivityAt555nm = 0.18;
        }
        port xOpticalIn: LightInputPort;
        port yOpticalIn: LightInputPort;
        port zOpticalIn: LightInputPort;
        port xSignal: DetectorSignalPort;
        port ySignal: DetectorSignalPort;
        port zSignal: DetectorSignalPort;

        connect xOpticalIn to xDetector.opticalInput;
        connect yOpticalIn to yDetector.opticalInput;
        connect zOpticalIn to zDetector.opticalInput;
        connect xDetector.currentOutput to xSignal;
        connect yDetector.currentOutput to ySignal;
        connect zDetector.currentOutput to zSignal;
    }

    part def TransimpedanceAmplifier {
        attribute feedbackResistance: Real = 1000000.0;
        attribute bandwidth: Frequency = 1000.0;
        attribute inputNoiseCurrent: ElectricCurrent = 0.0000000000005;
        port detectorInput: DetectorSignalPort;
        port voltageOutput: DetectorSignalPort;
    }

    part def AnalogFrontEnd {
        part xAmplifier: TransimpedanceAmplifier;
        part yAmplifier: TransimpedanceAmplifier;
        part zAmplifier: TransimpedanceAmplifier;
        attribute programmableGain: Real = 1.0;
        attribute antiAliasCutoff: Frequency = 250.0;
        port xCurrentIn: DetectorSignalPort;
        port yCurrentIn: DetectorSignalPort;
        port zCurrentIn: DetectorSignalPort;
        port xVoltageOut: DetectorSignalPort;
        port yVoltageOut: DetectorSignalPort;
        port zVoltageOut: DetectorSignalPort;

        connect xCurrentIn to xAmplifier.detectorInput;
        connect yCurrentIn to yAmplifier.detectorInput;
        connect zCurrentIn to zAmplifier.detectorInput;
        connect xAmplifier.voltageOutput to xVoltageOut;
        connect yAmplifier.voltageOutput to yVoltageOut;
        connect zAmplifier.voltageOutput to zVoltageOut;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits: Integer = 24;
        attribute sampleRate: Frequency = 1000.0;
        attribute inputRange: ElectricPotential = 2.5;
        attribute integralNonlinearityPpm: Real = 10.0;
        port xAnalogIn: DetectorSignalPort;
        port yAnalogIn: DetectorSignalPort;
        port zAnalogIn: DetectorSignalPort;
        port digitalFrameOut: AdcDataPort;
    }

    part def TemperatureSensor {
        attribute accuracy: Temperature = 0.5;
        attribute samplingRate: Frequency = 1.0;
        attribute measuredTemperature: Temperature;
        port statusOut: StatusPort;
    }

    part def CalibrationMemory {
        attribute memoryType: String = "nonvolatile EEPROM";
        attribute calibrationDate: String = "2026-01-01";
        attribute referenceIlluminant: String = "CIE Illuminant D65";
        item storedCoefficients: CalibrationCoefficients;
        port coefficientsOut: CalibrationDataPort;
    }

    part def ProcessingUnit {
        attribute clockFrequency: Frequency = 48000000.0;
        attribute firmwareVersion: String = "1.0.0";
        attribute activeMode: MeasurementMode = MeasurementMode::idle;
        attribute health: HealthStatus = HealthStatus::nominal;
        attribute measurementLatency: Duration = 0.050;
        port adcIn: AdcDataPort;
        port calibrationIn: CalibrationDataPort;
        port commandIn: CommandPort;
        port reportOut: ColorResultPort;
        port statusOut: StatusPort;

        action computeDarkCorrectedCounts {
            in item adcFrame: RawAdcFrame;
            in item coefficients: CalibrationCoefficients;
            out attribute correctedX: Real;
            out attribute correctedY: Real;
            out attribute correctedZ: Real;
        }

        action applyTristimulusMatrix {
            in attribute correctedX: Real;
            in attribute correctedY: Real;
            in attribute correctedZ: Real;
            in item coefficients: CalibrationCoefficients;
            out item xyz: XYZColorMeasurement;
        }

        action deriveChromaticity {
            in item xyz: XYZColorMeasurement;
            out item xyY: xyYColorMeasurement;
        }

        action estimateCorrelatedColorTemperature {
            in item xyY: xyYColorMeasurement;
            out attribute cct: ColorTemperature;
        }

        action publishMeasurementReport {
            in item xyz: XYZColorMeasurement;
            in item xyY: xyYColorMeasurement;
            out item report: ColorMeasurementReport;
        }

        action performMeasurementCycle {
            in item adcFrame: RawAdcFrame;
            in item coefficients: CalibrationCoefficients;
            out item report: ColorMeasurementReport;

            first start;
            then computeDarkCorrectedCounts;
            then applyTristimulusMatrix;
            then deriveChromaticity;
            then estimateCorrelatedColorTemperature;
            then publishMeasurementReport;
            then done;
        }

        state behavior measurementController {
            entry action initializeProcessor;

            state poweredOff;
            state booting;
            state selfTest;
            state idle;
            state acquiring;
            state processing;
            state reporting;
            state calibrating;
            state fault;

            transition initial then poweredOff;
            transition poweredOff then booting
                accept PowerApplied;
            transition booting then selfTest
                after 0.5;
            transition selfTest then idle
                if health == HealthStatus::nominal;
            transition selfTest then fault
                if health == HealthStatus::faulted;
            transition idle then acquiring
                accept StartSingleMeasurement;
            transition idle then acquiring
                accept StartContinuousMeasurement;
            transition idle then calibrating
                accept StartCalibration;
            transition acquiring then processing
                accept AdcFrameReady;
            transition processing then reporting
                accept ComputationComplete;
            transition reporting then idle
                if activeMode == MeasurementMode::singleSample;
            transition reporting then acquiring
                if activeMode == MeasurementMode::continuous;
            transition calibrating then idle
                accept CalibrationComplete;
            transition acquiring then fault
                accept DetectorSaturationFault;
            transition processing then fault
                accept ComputationFault;
            transition fault then idle
                accept ClearFault
                if health != HealthStatus::faulted;
        }
    }

    part def UserCommunicationInterface {
        attribute protocol: InterfaceProtocol = InterfaceProtocol::USB_CDC;
        attribute maximumBitRate: BitRate = 12000000.0;
        port commandIn: CommandPort;
        port statusOut: StatusPort;
        port measurementOut: ColorResultPort;
    }

    part def PowerRegulator {
        attribute inputVoltageNominal: ElectricPotential = 5.0;
        attribute regulatedVoltage: ElectricPotential = 3.3;
        attribute maximumOutputCurrent: ElectricCurrent = 0.5;
        attribute efficiency: Percent = 90.0;
        port externalPower: PowerInputPort;
        port regulatedOutput: PowerDistributionPort;
    }

    part def Housing {
        attribute material: String = "black anodized aluminum";
        attribute ingressProtection: String = "IP40";
        attribute internalReflectance: Percent = 2.0;
        attribute operatingTemperatureMin: Temperature = 0.0;
        attribute operatingTemperatureMax: Temperature = 40.0;
    }

    part def ReferenceTileAdapter {
        attribute referenceWhiteReflectance: Percent = 98.0;
        attribute usedForFieldCalibration: Boolean = true;
        port referenceLightInput: LightInputPort;
    }

    action def AcquireIncidentLight {
        in item incidentLight: IncidentVisibleLight;
        out item conditionedLight: IncidentVisibleLight;
    }

    action def SeparateLightIntoTristimulusBands {
        in item conditionedLight: IncidentVisibleLight;
        out item xBandSignal: OpticalChannelSignal;
        out item yBandSignal: OpticalChannelSignal;
        out item zBandSignal: OpticalChannelSignal;
    }

    action def ConvertOpticalBandsToCurrents {
        in item xBandSignal: OpticalChannelSignal;
        in item yBandSignal: OpticalChannelSignal;
        in item zBandSignal: OpticalChannelSignal;
        out item xCurrent: OpticalChannelSignal;
        out item yCurrent: OpticalChannelSignal;
        out item zCurrent: OpticalChannelSignal;
    }

    action def DigitizeDetectorSignals {
        in item xCurrent: OpticalChannelSignal;
        in item yCurrent: OpticalChannelSignal;
        in item zCurrent: OpticalChannelSignal;
        out item rawFrame: RawAdcFrame;
    }

    action def ComputeStandardColor {
        in item rawFrame: RawAdcFrame;
        in item coefficients: CalibrationCoefficients;
        out item report: ColorMeasurementReport;
    }

    action def TristimulusColorMeasurementFunction {
        in item incidentLight: IncidentVisibleLight;
        in item coefficients: CalibrationCoefficients;
        out item report: ColorMeasurementReport;

        first start;
        then AcquireIncidentLight;
        then SeparateLightIntoTristimulusBands;
        then ConvertOpticalBandsToCurrents;
        then DigitizeDetectorSignals;
        then ComputeStandardColor;
        then done;
    }

    part def TristimulusColorimeter {
        attribute primaryFunction: String =
            "Measure incident visible light through three color-matching optical channels and report standardized CIE tristimulus color values at a high level.";
        attribute supportedWavelengthMin: Wavelength = 380.0;
        attribute supportedWavelengthMax: Wavelength = 780.0;
        attribute nominalIntegrationTime: Duration = 0.100;
        attribute minimumIntegrationTime: Duration = 0.001;
        attribute maximumIntegrationTime: Duration = 1.000;
        attribute reportRate: Frequency = 10.0;
        attribute chromaticityAccuracy: DeltaE = 2.0;
        attribute illuminanceRangeMin: Illuminance = 0.1;
        attribute illuminanceRangeMax: Illuminance = 100000.0;
        attribute activeMode: MeasurementMode = MeasurementMode::idle;
        attribute overallHealth: HealthStatus = HealthStatus::nominal;

        port opticalInput: LightInputPort;
        port powerInput: PowerInputPort;
        port commandInput: CommandPort;
        port statusOutput: StatusPort;
        port measurementOutput: ColorResultPort;

        part housing: Housing;
        part aperture: Aperture;
        part diffuser: Diffuser;
        part filterSet: TristimulusFilterSet;
        part detectorArray: TristimulusDetectorArray;
        part analogFrontEnd: AnalogFrontEnd;
        part adc: AnalogToDigitalConverter;
        part temperatureSensor: TemperatureSensor;
        part calibrationMemory: CalibrationMemory;
        part processor: ProcessingUnit;
        part communication: UserCommunicationInterface;
        part powerRegulator: PowerRegulator;
        part referenceTileAdapter: ReferenceTileAdapter;

        perform action highLevelMeasurement: TristimulusColorMeasurementFunction;

        connect opticalInput to aperture.sceneLight;
        connect aperture.conditionedLight to diffuser.incomingLight;
        connect diffuser.uniformLight to filterSet.mixedLight;

        connect filterSet.xBand to detectorArray.xOpticalIn;
        connect filterSet.yBand to detectorArray.yOpticalIn;
        connect filterSet.zBand to detectorArray.zOpticalIn;

        connect detectorArray.xSignal to analogFrontEnd.xCurrentIn;
        connect detectorArray.ySignal to analogFrontEnd.yCurrentIn;
        connect detectorArray.zSignal to analogFrontEnd.zCurrentIn;

        connect analogFrontEnd.xVoltageOut to adc.xAnalogIn;
        connect analogFrontEnd.yVoltageOut to adc.yAnalogIn;
        connect analogFrontEnd.zVoltageOut to adc.zAnalogIn;

        connect adc.digitalFrameOut to processor.adcIn;
        connect calibrationMemory.coefficientsOut to processor.calibrationIn;

        connect commandInput to communication.commandIn;
        connect communication.commandIn to processor.commandIn;
        connect processor.reportOut to communication.measurementOut;
        connect communication.measurementOut to measurementOutput;
        connect processor.statusOut to communication.statusOut;
        connect communication.statusOut to statusOutput;

        connect powerInput to powerRegulator.externalPower;
        connect powerRegulator.regulatedOutput to processor;
        connect powerRegulator.regulatedOutput to adc;
        connect powerRegulator.regulatedOutput to analogFrontEnd;
        connect powerRegulator.regulatedOutput to temperatureSensor;
        connect powerRegulator.regulatedOutput to calibrationMemory;
        connect powerRegulator.regulatedOutput to communication;

        state behavior systemOperatingStates {
            state off;
            state ready;
            state measuringSingle;
            state measuringContinuous;
            state reportingResult;
            state calibratingWhiteReference;
            state diagnostics;
            state safeFault;

            transition initial then off;
            transition off then ready
                accept PowerApplied;
            transition ready then measuringSingle
                accept SingleMeasurementCommand;
            transition ready then measuringContinuous
                accept ContinuousMeasurementCommand;
            transition measuringSingle then reportingResult
                accept MeasurementComputed;
            transition reportingResult then ready
                accept ReportTransmitted;
            transition measuringContinuous then reportingResult
                accept MeasurementComputed;
            transition reportingResult then measuringContinuous
                accept ContinueStreaming;
            transition ready then calibratingWhiteReference
                accept CalibrationCommand;
            transition calibratingWhiteReference then ready
                accept CalibrationStored;
            transition ready then diagnostics
                accept DiagnosticsCommand;
            transition diagnostics then ready
                accept DiagnosticsComplete;
            transition ready then safeFault
                accept InternalFaultDetected;
            transition measuringSingle then safeFault
                accept DetectorSaturationFault;
            transition measuringContinuous then safeFault
                accept DetectorSaturationFault;
            transition safeFault then ready
                accept FaultCleared;
            transition ready then off
                accept PowerRemoved;
        }
    }

    constraint def VisibleRangeConstraint {
        in attribute minimum: Wavelength;
        in attribute maximum: Wavelength;
        minimum <= 380.0 and maximum >= 780.0;
    }

    constraint def IlluminanceRangeConstraint {
        in attribute low: Illuminance;
        in attribute high: Illuminance;
        low <= 0.1 and high >= 100000.0;
    }

    constraint def ChromaticityAccuracyConstraint {
        in attribute error: DeltaE;
        error <= 2.0;
    }

    constraint def IntegrationTimeConstraint {
        in attribute minimum: Duration;
        in attribute nominal: Duration;
        in attribute maximum: Duration;
        minimum <= nominal and nominal <= maximum;
    }

    constraint def ValidChromaticityConstraint {
        in attribute x: ChromaticityCoordinate;
        in attribute y: ChromaticityCoordinate;
        x >= 0.0 and x <= 1.0 and y >= 0.0 and y <= 1.0 and x + y <= 1.0;
    }

    requirement def PrimaryFunctionRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The system shall provide the high-level primary function of converting incident visible light into standardized tristimulus color information.";
        require constraint {
            colorimeter.primaryFunction ==
            "Measure incident visible light through three color-matching optical channels and report standardized CIE tristimulus color values at a high level."
        }
    }

    requirement def ThreeChannelTristimulusRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall use three optically filtered detector channels corresponding to X, Y, and Z tristimulus response approximations.";
        require constraint {
            colorimeter.filterSet.functionBasis ==
            "Approximation to CIE 1931 2-degree color matching functions"
        }
    }

    requirement def VisibleSpectrumRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The optical input path shall accept visible light over the 380 nm to 780 nm range.";
        require VisibleRangeConstraint {
            minimum = colorimeter.supportedWavelengthMin;
            maximum = colorimeter.supportedWavelengthMax;
        }
    }

    requirement def IlluminanceMeasurementRangeRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall measure illuminance from 0.1 lx to 100000 lx.";
        require IlluminanceRangeConstraint {
            low = colorimeter.illuminanceRangeMin;
            high = colorimeter.illuminanceRangeMax;
        }
    }

    requirement def ColorAccuracyRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall report color with a maximum color error of Delta E 2.0 under calibrated reference conditions.";
        require ChromaticityAccuracyConstraint {
            error = colorimeter.chromaticityAccuracy;
        }
    }

    requirement def IntegrationControlRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall support programmable integration time to prevent saturation and improve low-light sensitivity.";
        require IntegrationTimeConstraint {
            minimum = colorimeter.minimumIntegrationTime;
            nominal = colorimeter.nominalIntegrationTime;
            maximum = colorimeter.maximumIntegrationTime;
        }
    }

    requirement def OutputReportRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall output a measurement report containing X, Y, Z, chromaticity x and y, illuminance, correlated color temperature, validity, and health.";
        require constraint {
            colorimeter.communication.protocol == InterfaceProtocol::USB_CDC
        }
    }

    requirement def CalibrationRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall apply stored calibration coefficients to raw detector counts before calculating CIE tristimulus values.";
        require constraint {
            colorimeter.calibrationMemory.memoryType == "nonvolatile EEPROM"
        }
    }

    requirement def ThermalCompensationRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall sense internal detector temperature and use calibration temperature coefficients for compensation.";
        require constraint {
            colorimeter.temperatureSensor.accuracy <= 0.5
        }
    }

    requirement def SafetyFaultRequirement {
        subject colorimeter: TristimulusColorimeter;
        doc
            "The colorimeter shall enter a safe fault state when detector saturation, computation failure, or internal health failure is detected.";
        require constraint {
            colorimeter.overallHealth != HealthStatus::faulted or colorimeter.activeMode == MeasurementMode::idle
        }
    }

    satisfy PrimaryFunctionRequirement by TristimulusColorimeter;
    satisfy ThreeChannelTristimulusRequirement by TristimulusColorimeter::filterSet;
    satisfy VisibleSpectrumRequirement by TristimulusColorimeter::aperture;
    satisfy IlluminanceMeasurementRangeRequirement by TristimulusColorimeter::detectorArray;
    satisfy ColorAccuracyRequirement by TristimulusColorimeter::processor;
    satisfy IntegrationControlRequirement by TristimulusColorimeter::adc;
    satisfy OutputReportRequirement by TristimulusColorimeter::communication;
    satisfy CalibrationRequirement by TristimulusColorimeter::calibrationMemory;
    satisfy ThermalCompensationRequirement by TristimulusColorimeter::temperatureSensor;
    satisfy SafetyFaultRequirement by TristimulusColorimeter::systemOperatingStates;

    part tristimulusColorimeterSystem: TristimulusColorimeter {
        attribute primaryFunction =
            "Measure incident visible light through three color-matching optical channels and report standardized CIE tristimulus color values at a high level.";
        attribute activeMode = MeasurementMode::idle;
        attribute overallHealth = HealthStatus::nominal;
    }

}
