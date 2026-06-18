package BackIlluminatedSensingUnitModel {
    import ScalarValues::*;

    enum def OperatingMode {
        enum off;
        enum standby;
        enum calibrating;
        enum integrating;
        enum readingOut;
        enum processing;
        enum reporting;
        enum fault;
    }

    enum def CommandKind {
        enum powerOn;
        enum powerOff;
        enum calibrate;
        enum measure;
        enum resetFault;
    }

    enum def MeasurementValidity {
        enum valid;
        enum saturated;
        enum underRange;
        enum sensorFault;
        enum calibrationInvalid;
    }

    enum def SensorIlluminationArchitecture {
        enum frontIlluminated;
        enum backIlluminated;
    }

    enum def HealthCode {
        enum nominal;
        enum degradedTemperature;
        enum degradedSignal;
        enum opticalObstruction;
        enum detectorBiasFault;
        enum processingFault;
    }

    attribute def Voltage :> Real {
        attribute unit : String = "V";
    }

    attribute def Current :> Real {
        attribute unit : String = "A";
    }

    attribute def ElectricalPowerValue :> Real {
        attribute unit : String = "W";
    }

    attribute def Temperature :> Real {
        attribute unit : String = "degC";
    }

    attribute def Time :> Real {
        attribute unit : String = "s";
    }

    attribute def Length :> Real {
        attribute unit : String = "m";
    }

    attribute def Wavelength :> Real {
        attribute unit : String = "nm";
    }

    attribute def Area :> Real {
        attribute unit : String = "mm^2";
    }

    attribute def Irradiance :> Real {
        attribute unit : String = "W/m^2";
    }

    attribute def RadiantFlux :> Real {
        attribute unit : String = "W";
    }

    attribute def Frequency :> Real {
        attribute unit : String = "Hz";
    }

    attribute def DataRate :> Real {
        attribute unit : String = "bit/s";
    }

    attribute def Ratio :> Real {
        attribute unit : String = "1";
    }

    attribute def DigitalCount :> Integer {
        attribute unit : String = "count";
    }

    attribute def PixelCount :> Integer {
        attribute unit : String = "pixel";
    }

    attribute def BitDepth :> Integer {
        attribute unit : String = "bit";
    }

    item def OpticalRadiation {
        attribute centerWavelength : Wavelength;
        attribute spectralBandwidth : Wavelength;
        attribute irradiance : Irradiance;
        attribute totalFlux : RadiantFlux;
        attribute incidenceAngle : Real;
    }

    item def FocusedOpticalSignal :> OpticalRadiation {
        attribute imagePlaneDiameter : Length;
        attribute opticalThroughput : Ratio;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : ElectricalPowerValue;
    }

    item def ControlCommand {
        attribute kind : CommandKind;
        attribute requestedExposureTime : Time;
        attribute requestedSampleRate : Frequency;
    }

    item def SensorBias {
        attribute resetVoltage : Voltage;
        attribute photodiodeBiasVoltage : Voltage;
        attribute analogSupplyVoltage : Voltage;
        attribute digitalSupplyVoltage : Voltage;
    }

    item def RawChargePacket {
        attribute integratedCharge : DigitalCount;
        attribute integrationTime : Time;
        attribute pixelIndex : PixelCount;
    }

    item def RawDigitalFrame {
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute bitDepth : BitDepth;
        attribute frameRate : Frequency;
        attribute meanSignal : DigitalCount;
        attribute maximumSignal : DigitalCount;
        attribute darkReference : DigitalCount;
    }

    item def IrradianceMeasurement {
        attribute measuredIrradiance : Irradiance;
        attribute exposureTime : Time;
        attribute centerWavelength : Wavelength;
        attribute uncertainty : Irradiance;
        attribute validity : MeasurementValidity;
        attribute timeSinceLastCalibration : Time;
    }

    item def HealthStatus {
        attribute mode : OperatingMode;
        attribute code : HealthCode;
        attribute detectorTemperature : Temperature;
        attribute detectorBiasVoltage : Voltage;
        attribute saturatedPixelFraction : Ratio;
    }

    port def OpticalInputPort {
        in item radiation : OpticalRadiation;
    }

    port def OpticalOutputPort {
        out item radiation : FocusedOpticalSignal;
    }

    port def ElectricalPowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def BiasOutputPort {
        out item bias : SensorBias;
    }

    port def CommandInputPort {
        in item command : ControlCommand;
    }

    port def RawChargeOutputPort {
        out item charge : RawChargePacket;
    }

    port def RawFramePort {
        out item frame : RawDigitalFrame;
    }

    port def MeasurementOutputPort {
        out item measurement : IrradianceMeasurement;
    }

    port def HealthOutputPort {
        out item status : HealthStatus;
    }

    port def ThermalStatusPort {
        out attribute temperature : Temperature;
    }

    interface def OpticalRadiationTransfer {
        end source : OpticalOutputPort;
        end sink : OpticalInputPort;
        flow source.radiation to sink.radiation;
    }

    interface def PowerDelivery {
        end source : ElectricalPowerInputPort;
        end sink : ElectricalPowerInputPort;
        flow source.powerIn to sink.powerIn;
    }

    interface def BiasDelivery {
        end source : BiasOutputPort;
        end sink : BiasOutputPort;
        flow source.bias to sink.bias;
    }

    interface def RawFrameDelivery {
        end source : RawFramePort;
        end sink : RawFramePort;
        flow source.frame to sink.frame;
    }

    constraint def SpectralAcceptanceConstraint {
        in wavelength : Wavelength;
        in minimumWavelength : Wavelength;
        in maximumWavelength : Wavelength;
        constraint spectralRange {
            minimumWavelength <= wavelength and wavelength <= maximumWavelength
        }
    }

    constraint def IrradianceDynamicRangeConstraint {
        in measured : Irradiance;
        in lowerLimit : Irradiance;
        in upperLimit : Irradiance;
        constraint dynamicRange {
            lowerLimit <= measured and measured <= upperLimit
        }
    }

    constraint def BackIlluminatedArchitectureConstraint {
        in architecture : SensorIlluminationArchitecture;
        constraint isBackIlluminated {
            architecture == SensorIlluminationArchitecture::backIlluminated
        }
    }

    constraint def DetectorThermalConstraint {
        in detectorTemperature : Temperature;
        in minimumTemperature : Temperature;
        in maximumTemperature : Temperature;
        constraint allowedTemperature {
            minimumTemperature <= detectorTemperature and detectorTemperature <= maximumTemperature
        }
    }

    constraint def SignalProcessingLatencyConstraint {
        in latency : Time;
        in maximumLatency : Time;
        constraint latencyLimit {
            latency <= maximumLatency
        }
    }

    action def InitializeSensingUnit {
        in item command : ControlCommand;
        out item health : HealthStatus;
        attribute initializationTime : Time = 0.25;
    }

    action def StabilizeDetectorBias {
        in item power : ElectricalPower;
        out item bias : SensorBias;
        attribute biasSettlingTime : Time = 0.05;
    }

    action def CaptureBackIlluminatedSignal {
        in item opticalSignal : FocusedOpticalSignal;
        in item bias : SensorBias;
        out item rawCharge : RawChargePacket;
        attribute exposureTime : Time;
        attribute conversionEfficiency : Ratio;
    }

    action def DigitizeSensorCharge {
        in item rawCharge : RawChargePacket;
        out item rawFrame : RawDigitalFrame;
        attribute analogToDigitalResolution : BitDepth = 14;
        attribute readoutClock : Frequency = 24000000.0;
    }

    action def EstimateIncidentIrradiance {
        in item rawFrame : RawDigitalFrame;
        out item measurement : IrradianceMeasurement;
        attribute darkOffset : DigitalCount;
        attribute responsivity : Ratio;
        attribute processingLatency : Time = 0.010;
    }

    action def ReportMeasurement {
        in item measurement : IrradianceMeasurement;
        out item status : HealthStatus;
        attribute outputDataRate : DataRate = 1000000.0;
    }

    state def SensingUnitOperationalState {
        state off;
        state standby;
        state calibrating;
        state integrating;
        state readingOut;
        state processing;
        state reporting;
        state fault;

        transition initialOff first off;

        transition powerOn
            first off
            accept ControlCommand
            then standby;

        transition beginCalibration
            first standby
            accept ControlCommand
            then calibrating;

        transition calibrationComplete
            first calibrating
            then standby;

        transition beginMeasurement
            first standby
            accept ControlCommand
            then integrating;

        transition exposureComplete
            first integrating
            then readingOut;

        transition readoutComplete
            first readingOut
            then processing;

        transition processingComplete
            first processing
            then reporting;

        transition reportComplete
            first reporting
            then standby;

        transition detectedFaultFromStandby
            first standby
            then fault;

        transition detectedFaultFromIntegrating
            first integrating
            then fault;

        transition detectedFaultFromProcessing
            first processing
            then fault;

        transition resetFault
            first fault
            accept ControlCommand
            then standby;

        transition powerOffFromStandby
            first standby
            accept ControlCommand
            then off;
    }

    part def ApertureStop {
        port sceneSide : OpticalInputPort;
        port imageSide : OpticalOutputPort;

        attribute clearApertureDiameter : Length = 0.006;
        attribute apertureArea : Area = 28.27;
        attribute strayLightRejection : Ratio = 0.995;
    }

    part def SpectralFilter {
        port unfilteredInput : OpticalInputPort;
        port filteredOutput : OpticalOutputPort;

        attribute centerWavelength : Wavelength = 550.0;
        attribute fullWidthHalfMaximum : Wavelength = 80.0;
        attribute peakTransmission : Ratio = 0.92;
        attribute outOfBandRejection : Ratio = 0.999;
    }

    part def LensAssembly {
        port objectSide : OpticalInputPort;
        port imagePlane : OpticalOutputPort;

        attribute focalLength : Length = 0.012;
        attribute fNumber : Real = 2.8;
        attribute opticalTransmission : Ratio = 0.88;
        attribute fieldOfView : Real = 32.0;
    }

    part def OpticalFrontEnd {
        port externalRadiation : OpticalInputPort;
        port focusedSignal : OpticalOutputPort;

        part aperture : ApertureStop;
        part filter : SpectralFilter;
        part lens : LensAssembly;

        connect externalRadiation to aperture.sceneSide;
        connect aperture.imageSide to filter.unfilteredInput;
        connect filter.filteredOutput to lens.objectSide;
        connect lens.imagePlane to focusedSignal;

        attribute effectiveTransmission : Ratio = 0.808;
        attribute acceptedMinimumWavelength : Wavelength = 400.0;
        attribute acceptedMaximumWavelength : Wavelength = 700.0;
    }

    part def BackIlluminatedSensor {
        port opticalInput : OpticalInputPort;
        port biasInput : BiasOutputPort;
        port chargeOutput : RawChargeOutputPort;
        port thermalStatus : ThermalStatusPort;

        attribute illuminationArchitecture : SensorIlluminationArchitecture = SensorIlluminationArchitecture::backIlluminated;
        attribute activeArea : Area = 16.0;
        attribute pixelPitch : Length = 0.00000345;
        attribute horizontalPixels : PixelCount = 2048;
        attribute verticalPixels : PixelCount = 2048;
        attribute minimumWavelength : Wavelength = 350.0;
        attribute maximumWavelength : Wavelength = 900.0;
        attribute peakQuantumEfficiency : Ratio = 0.91;
        attribute backSurfacePassivationEfficiency : Ratio = 0.98;
        attribute microlensFillFactor : Ratio = 0.99;
        attribute darkCurrentAt25C : Current = 0.0000000000002;
        attribute fullWellCapacity : DigitalCount = 30000;
        attribute readNoise : DigitalCount = 2;
        attribute detectorTemperature : Temperature = 25.0;

        assert constraint BackIlluminatedArchitectureConstraint {
            architecture = illuminationArchitecture;
        }

        assert constraint SpectralAcceptanceConstraint {
            wavelength = opticalInput.radiation.centerWavelength;
            minimumWavelength = minimumWavelength;
            maximumWavelength = maximumWavelength;
        }
    }

    part def BiasAndClockGenerator {
        port powerInput : ElectricalPowerInputPort;
        port commandInput : CommandInputPort;
        port biasOutput : BiasOutputPort;
        port healthOutput : HealthOutputPort;

        attribute resetVoltage : Voltage = 3.3;
        attribute photodiodeBiasVoltage : Voltage = 2.8;
        attribute analogSupplyVoltage : Voltage = 3.3;
        attribute digitalSupplyVoltage : Voltage = 1.8;
        attribute masterClockFrequency : Frequency = 24000000.0;
        attribute clockJitter : Time = 0.000000001;
        attribute biasStability : Ratio = 0.995;
    }

    part def AnalogFrontEnd {
        port chargeInput : RawChargeOutputPort;
        port commandInput : CommandInputPort;
        port frameOutput : RawFramePort;

        attribute programmableGain : Ratio = 4.0;
        attribute correlatedDoubleSamplingEnabled : Boolean = true;
        attribute analogBandwidth : Frequency = 12000000.0;
        attribute adcResolution : BitDepth = 14;
        attribute maximumFrameRate : Frequency = 120.0;
    }

    part def DigitalSignalProcessor {
        port commandInput : CommandInputPort;
        port rawFrameInput : RawFramePort;
        port measurementOutput : MeasurementOutputPort;
        port healthOutput : HealthOutputPort;

        attribute darkFrameCorrectionEnabled : Boolean = true;
        attribute flatFieldCorrectionEnabled : Boolean = true;
        attribute nonlinearityCorrectionEnabled : Boolean = true;
        attribute radiometricCalibrationFactor : Ratio = 1.0;
        attribute measurementLatency : Time = 0.010;
        attribute outputRate : Frequency = 20.0;

        assert constraint SignalProcessingLatencyConstraint {
            latency = measurementLatency;
            maximumLatency = 0.050;
        }
    }

    part def ThermalController {
        port powerInput : ElectricalPowerInputPort;
        port detectorTemperatureInput : ThermalStatusPort;
        port healthOutput : HealthOutputPort;

        attribute targetTemperature : Temperature = 25.0;
        attribute minimumOperatingTemperature : Temperature = -20.0;
        attribute maximumOperatingTemperature : Temperature = 60.0;
        attribute controlLoopFrequency : Frequency = 10.0;
        attribute heaterPowerLimit : ElectricalPowerValue = 0.75;

        assert constraint DetectorThermalConstraint {
            detectorTemperature = detectorTemperatureInput.temperature;
            minimumTemperature = minimumOperatingTemperature;
            maximumTemperature = maximumOperatingTemperature;
        }
    }

    part def PowerRegulator {
        port unregulatedInput : ElectricalPowerInputPort;
        port regulatedOutput : ElectricalPowerInputPort;
        port healthOutput : HealthOutputPort;

        attribute inputVoltageMinimum : Voltage = 9.0;
        attribute inputVoltageMaximum : Voltage = 36.0;
        attribute regulatedVoltage : Voltage = 5.0;
        attribute maximumOutputCurrent : Current = 0.5;
        attribute conversionEfficiency : Ratio = 0.88;
        attribute outputRipple : Voltage = 0.010;
    }

    part def SensingUnit {
        port opticalInput : OpticalInputPort;
        port electricalInput : ElectricalPowerInputPort;
        port commandInput : CommandInputPort;
        port measurementOutput : MeasurementOutputPort;
        port healthOutput : HealthOutputPort;

        part optics : OpticalFrontEnd;
        part regulator : PowerRegulator;
        part biasClock : BiasAndClockGenerator;
        part detector : BackIlluminatedSensor;
        part analogFrontEnd : AnalogFrontEnd;
        part processor : DigitalSignalProcessor;
        part thermalController : ThermalController;

        attribute relevantQuantityName : String = "incident optical irradiance";
        attribute nominalCenterWavelength : Wavelength = 550.0;
        attribute measurableIrradianceMinimum : Irradiance = 0.000001;
        attribute measurableIrradianceMaximum : Irradiance = 1000.0;
        attribute nominalExposureTime : Time = 0.010;
        attribute maximumMeasurementLatency : Time = 0.075;
        attribute commandedSampleRate : Frequency = 20.0;
        attribute operatingMode : OperatingMode = OperatingMode::standby;

        connect opticalInput to optics.externalRadiation;
        connect optics.focusedSignal to detector.opticalInput;

        connect electricalInput to regulator.unregulatedInput;
        connect regulator.regulatedOutput to biasClock.powerInput;
        connect regulator.regulatedOutput to thermalController.powerInput;

        connect commandInput to biasClock.commandInput;
        connect commandInput to analogFrontEnd.commandInput;
        connect commandInput to processor.commandInput;

        connect biasClock.biasOutput to detector.biasInput;
        connect detector.chargeOutput to analogFrontEnd.chargeInput;
        connect analogFrontEnd.frameOutput to processor.rawFrameInput;

        connect detector.thermalStatus to thermalController.detectorTemperatureInput;
        connect processor.measurementOutput to measurementOutput;
        connect processor.healthOutput to healthOutput;

        exhibit state operationalState : SensingUnitOperationalState;

        perform action initialize : InitializeSensingUnit;
        perform action stabilizeBias : StabilizeDetectorBias;
        perform action captureSignal : CaptureBackIlluminatedSignal;
        perform action digitizeCharge : DigitizeSensorCharge;
        perform action estimateIrradiance : EstimateIncidentIrradiance;
        perform action reportResult : ReportMeasurement;

        assert constraint IrradianceDynamicRangeConstraint {
            measured = processor.measurementOutput.measurement.measuredIrradiance;
            lowerLimit = measurableIrradianceMinimum;
            upperLimit = measurableIrradianceMaximum;
        }

        assert constraint BackIlluminatedArchitectureConstraint {
            architecture = detector.illuminationArchitecture;
        }
    }

    requirement def MeasureRelevantQuantityRequirement {
        subject unit : SensingUnit;

        doc /* The sensing unit shall measure the relevant quantity, defined as incident optical irradiance at the sensing aperture. */

        require constraint {
            unit.relevantQuantityName == "incident optical irradiance"
        }

        require constraint IrradianceDynamicRangeConstraint {
            measured = unit.processor.measurementOutput.measurement.measuredIrradiance;
            lowerLimit = unit.measurableIrradianceMinimum;
            upperLimit = unit.measurableIrradianceMaximum;
        }
    }

    requirement def BackIlluminatedSensorRequirement {
        subject unit : SensingUnit;

        doc /* The sensing unit shall use a back-illuminated detector as the primary sensor for converting incident optical radiation into charge. */

        require constraint BackIlluminatedArchitectureConstraint {
            architecture = unit.detector.illuminationArchitecture;
        }
    }

    requirement def SpectralMeasurementRequirement {
        subject unit : SensingUnit;

        doc /* The sensing unit shall accept radiation in the visible measurement band centered at 550 nm. */

        require constraint SpectralAcceptanceConstraint {
            wavelength = unit.nominalCenterWavelength;
            minimumWavelength = unit.optics.acceptedMinimumWavelength;
            maximumWavelength = unit.optics.acceptedMaximumWavelength;
        }
    }

    requirement def MeasurementLatencyRequirement {
        subject unit : SensingUnit;

        doc /* The sensing unit shall produce a calibrated irradiance measurement within 75 ms of the beginning of exposure. */

        require constraint SignalProcessingLatencyConstraint {
            latency = unit.processor.measurementLatency;
            maximumLatency = unit.maximumMeasurementLatency;
        }
    }

    requirement def DetectorThermalRequirement {
        subject unit : SensingUnit;

        doc /* The back-illuminated sensor shall operate within its controlled detector temperature range during measurement. */

        require constraint DetectorThermalConstraint {
            detectorTemperature = unit.detector.detectorTemperature;
            minimumTemperature = unit.thermalController.minimumOperatingTemperature;
            maximumTemperature = unit.thermalController.maximumOperatingTemperature;
        }
    }

    requirement def DigitalOutputRequirement {
        subject unit : SensingUnit;

        doc /* The sensing unit shall output a calibrated irradiance measurement item with validity status and uncertainty. */

        require constraint {
            unit.processor.measurementOutput.measurement.validity != MeasurementValidity::sensorFault
        }
    }

    part sensingUnit : SensingUnit {
        attribute relevantQuantityName = "incident optical irradiance";
        attribute nominalCenterWavelength = 550.0;
        attribute measurableIrradianceMinimum = 0.000001;
        attribute measurableIrradianceMaximum = 1000.0;
        attribute nominalExposureTime = 0.010;
        attribute maximumMeasurementLatency = 0.075;
        attribute commandedSampleRate = 20.0;

        part detector :>> BackIlluminatedSensor {
            attribute illuminationArchitecture = SensorIlluminationArchitecture::backIlluminated;
            attribute peakQuantumEfficiency = 0.91;
            attribute activeArea = 16.0;
            attribute horizontalPixels = 2048;
            attribute verticalPixels = 2048;
        }
    }

    requirement measureRelevantQuantity : MeasureRelevantQuantityRequirement {
        subject unit = sensingUnit;
    }

    requirement useBackIlluminatedSensor : BackIlluminatedSensorRequirement {
        subject unit = sensingUnit;
    }

    requirement acceptVisibleBand : SpectralMeasurementRequirement {
        subject unit = sensingUnit;
    }

    requirement meetLatency : MeasurementLatencyRequirement {
        subject unit = sensingUnit;
    }

    requirement controlDetectorTemperature : DetectorThermalRequirement {
        subject unit = sensingUnit;
    }

    requirement provideDigitalOutput : DigitalOutputRequirement {
        subject unit = sensingUnit;
    }

    satisfy measureRelevantQuantity by sensingUnit;
    satisfy useBackIlluminatedSensor by sensingUnit.detector;
    satisfy acceptVisibleBand by sensingUnit.optics;
    satisfy meetLatency by sensingUnit.processor;
    satisfy controlDetectorTemperature by sensingUnit.thermalController;
    satisfy provideDigitalOutput by sensingUnit.processor;
}
