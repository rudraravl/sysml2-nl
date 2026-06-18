package LED_As_Light_Sensor_Sensing_Unit {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Voltage :> Real {
        doc "Electrical potential difference.";
        unit = "V";
    }

    attribute def Current :> Real {
        doc "Electrical current.";
        unit = "A";
    }

    attribute def Resistance :> Real {
        doc "Electrical resistance.";
        unit = "ohm";
    }

    attribute def Capacitance :> Real {
        doc "Electrical capacitance.";
        unit = "F";
    }

    attribute def Frequency :> Real {
        doc "Frequency.";
        unit = "Hz";
    }

    attribute def Time :> Real {
        doc "Time duration.";
        unit = "s";
    }

    attribute def Temperature :> Real {
        doc "Thermodynamic temperature in degrees Celsius for operational reporting.";
        unit = "degC";
    }

    attribute def Illuminance :> Real {
        doc "Photometric incident illumination.";
        unit = "lx";
    }

    attribute def Irradiance :> Real {
        doc "Radiometric incident optical power per area at the LED junction.";
        unit = "W_per_m2";
    }

    attribute def Wavelength :> Real {
        doc "Optical wavelength.";
        unit = "nm";
    }

    attribute def Responsivity :> Real {
        doc "Generated LED photocurrent per incident optical irradiance.";
        unit = "A_per_W_per_m2";
    }

    attribute def DigitalCount :> Integer {
        doc "Unsigned ADC conversion count.";
    }

    attribute def Ratio :> Real {
        doc "Dimensionless ratio.";
        unit = "one";
    }

    attribute def Area :> Real {
        doc "Effective optical receiving area.";
        unit = "mm2";
    }

    attribute def BitCount :> Integer {
        doc "Number of digital bits.";
    }

    attribute def SampleCount :> Integer {
        doc "Number of samples.";
    }

    attribute def MeasurementUncertainty :> Real {
        doc "Expanded relative uncertainty.";
        unit = "percent";
    }

    enum def SensorMode {
        enum off;
        enum standby;
        enum darkCalibration;
        enum measuring;
        enum saturated;
        enum fault;
    }

    enum def MeasurementQuality {
        enum valid;
        enum belowRange;
        enum aboveRange;
        enum saturated;
        enum unstable;
        enum sensorFault;
    }

    item def OpticalRadiation {
        attribute irradiance : Irradiance;
        attribute dominantWavelength : Wavelength;
        attribute bandwidth : Wavelength;
        attribute incidenceAngle : Real {
            unit = "deg";
        }
    }

    item def AmbientCondition {
        attribute temperature : Temperature;
        attribute supplyNoiseRms : Voltage;
        attribute darkIlluminanceEstimate : Illuminance;
    }

    item def AnalogVoltageSignal {
        attribute value : Voltage;
        attribute sourceImpedance : Resistance;
        attribute bandwidth : Frequency;
    }

    item def AnalogCurrentSignal {
        attribute value : Current;
        attribute leakage : Current;
        attribute bandwidth : Frequency;
    }

    item def DigitalSample {
        attribute adcCount : DigitalCount;
        attribute sampleTime : Time;
        attribute adcReference : Voltage;
        attribute resolution : BitCount;
    }

    item def IlluminanceMeasurement {
        attribute value : Illuminance;
        attribute irradianceEquivalent : Irradiance;
        attribute uncertainty : MeasurementUncertainty;
        attribute quality : MeasurementQuality;
        attribute timestamp : Time;
        attribute sensorTemperature : Temperature;
    }

    item def Command {
        attribute requestedMode : SensorMode;
        attribute requestedSampleRate : Frequency;
        attribute averagingWindow : SampleCount;
    }

    item def Status {
        attribute presentMode : SensorMode;
        attribute supplyOk : Boolean;
        attribute adcOk : Boolean;
        attribute calibrationValid : Boolean;
        attribute lastQuality : MeasurementQuality;
    }

    port def OpticalInputPort {
        in item light : OpticalRadiation;
    }

    port def AnalogCurrentPort {
        out item currentSignal : AnalogCurrentSignal;
    }

    port def AnalogVoltageOutPort {
        out item voltageSignal : AnalogVoltageSignal;
    }

    port def AnalogVoltageInPort {
        in item voltageSignal : AnalogVoltageSignal;
    }

    port def DigitalSampleOutPort {
        out item sample : DigitalSample;
    }

    port def DigitalSampleInPort {
        in item sample : DigitalSample;
    }

    port def MeasurementOutPort {
        out item measurement : IlluminanceMeasurement;
    }

    port def CommandInPort {
        in item command : Command;
    }

    port def StatusOutPort {
        out item status : Status;
    }

    port def PowerInPort {
        in item supplyVoltage : AnalogVoltageSignal;
    }

    port def GroundPort {
        inout item reference : AnalogVoltageSignal;
    }

    port def BiasControlPort {
        in item reverseBias : AnalogVoltageSignal;
    }

    port def TemperatureOutPort {
        out item ambient : AmbientCondition;
    }

    action def ConvertLightToPhotocurrent {
        in item incidentLight : OpticalRadiation;
        in attribute effectiveArea : Area;
        in attribute peakWavelength : Wavelength;
        in attribute responsivityAtPeak : Responsivity;
        in attribute darkCurrent : Current;
        out item generatedCurrent : AnalogCurrentSignal;

        action computeSpectralFactor {
            in attribute lambda : Wavelength = incidentLight.dominantWavelength;
            out attribute spectralFactor : Ratio;
        }

        action computePhotocurrent {
            in attribute irradiance : Irradiance = incidentLight.irradiance;
            in attribute area : Area = effectiveArea;
            in attribute responsivity : Responsivity = responsivityAtPeak;
            in attribute factor : Ratio;
            out attribute photocurrent : Current;
        }

        first computeSpectralFactor then computePhotocurrent;

        assert constraint {
            generatedCurrent.value >= darkCurrent
        }
    }

    action def TransimpedanceAmplify {
        in item inputCurrent : AnalogCurrentSignal;
        in attribute feedbackResistance : Resistance;
        in attribute outputOffset : Voltage;
        in attribute minimumOutput : Voltage;
        in attribute maximumOutput : Voltage;
        out item outputVoltage : AnalogVoltageSignal;

        assert constraint {
            outputVoltage.value >= minimumOutput and outputVoltage.value <= maximumOutput
        }
    }

    action def SampleAnalogVoltage {
        in item analogVoltage : AnalogVoltageSignal;
        in attribute referenceVoltage : Voltage;
        in attribute adcResolution : BitCount;
        in attribute samplePeriod : Time;
        out item sample : DigitalSample;

        assert constraint {
            sample.adcCount >= 0
        }

        assert constraint {
            sample.adcCount <= 4095
        }
    }

    action def EstimateIlluminance {
        in item sample : DigitalSample;
        in item environment : AmbientCondition;
        in attribute darkOffsetCount : DigitalCount;
        in attribute calibrationSlope : Real {
            unit = "lx_per_count";
        }
        in attribute temperatureCoefficient : Real {
            unit = "percent_per_degC";
        }
        out item measurement : IlluminanceMeasurement;

        action subtractDarkOffset;
        action applyCalibrationSlope;
        action compensateTemperature;
        action assignQuality;

        first subtractDarkOffset then applyCalibrationSlope then compensateTemperature then assignQuality;

        assert constraint {
            measurement.value >= 0.0
        }
    }

    action def AverageMeasurements {
        in item newMeasurement : IlluminanceMeasurement;
        in attribute windowLength : SampleCount;
        out item averagedMeasurement : IlluminanceMeasurement;

        assert constraint {
            windowLength >= 1
        }

        assert constraint {
            averagedMeasurement.uncertainty <= newMeasurement.uncertainty
        }
    }

    state def SensingUnitOperationalStates {
        entry action initializeElectronics;
        exit action storeLastValidMeasurement;

        state Off {
            entry action disableReverseBias;
            entry action disableAdc;
        }

        state Standby {
            entry action enableReference;
            entry action waitForCommand;
        }

        state DarkCalibration {
            entry action shieldAssumedOrLedReverseBiasedNoLight;
            do action measureDarkCurrent;
            exit action updateDarkOffset;
        }

        state Measuring {
            entry action enableReverseBias;
            entry action configureAdcSampling;
            do action acquireAverageAndReport;
        }

        state Saturated {
            entry action flagAboveRange;
            do action reduceGainIfAllowed;
        }

        state Fault {
            entry action disableSensorBias;
            entry action reportFaultStatus;
        }

        transition offToStandby first Off then Standby {
            trigger commandReceived;
            guard command.requestedMode == SensorMode::standby;
        }

        transition standbyToDarkCalibration first Standby then DarkCalibration {
            trigger commandReceived;
            guard command.requestedMode == SensorMode::darkCalibration;
        }

        transition darkCalibrationToStandby first DarkCalibration then Standby {
            trigger darkCalibrationComplete;
        }

        transition standbyToMeasuring first Standby then Measuring {
            trigger commandReceived;
            guard command.requestedMode == SensorMode::measuring;
        }

        transition measuringToSaturated first Measuring then Saturated {
            trigger adcNearFullScale;
        }

        transition saturatedToMeasuring first Saturated then Measuring {
            trigger signalBackInRange;
        }

        transition measuringToStandby first Measuring then Standby {
            trigger commandReceived;
            guard command.requestedMode == SensorMode::standby;
        }

        transition anyToFault first Off then Fault {
            trigger selfTestFailed;
        }

        transition faultToStandby first Fault then Standby {
            trigger resetCommand;
        }
    }

    part def LightEmittingDiodeSensor {
        doc "A visible LED used as a photodiode-style light sensor. Incident photons generate a small current when the LED junction is reverse biased or read in photovoltaic mode.";

        port opticalInput : OpticalInputPort;
        port photocurrentOutput : AnalogCurrentPort;
        port biasInput : BiasControlPort;
        port cathodeReference : GroundPort;

        attribute peakSensitivityWavelength : Wavelength = 630.0;
        attribute spectralBandwidthFwhm : Wavelength = 45.0;
        attribute junctionArea : Area = 0.28;
        attribute responsivityAtPeak : Responsivity = 2.1e-9;
        attribute darkCurrentAt25C : Current = 8.0e-9;
        attribute maximumReverseBias : Voltage = 3.0;
        attribute junctionCapacitance : Capacitance = 25.0e-12;
        attribute operatingTemperatureMin : Temperature = -20.0;
        attribute operatingTemperatureMax : Temperature = 70.0;

        perform action lightToCurrent : ConvertLightToPhotocurrent {
            in incidentLight = opticalInput.light;
            in effectiveArea = junctionArea;
            in peakWavelength = peakSensitivityWavelength;
            in responsivityAtPeak = responsivityAtPeak;
            in darkCurrent = darkCurrentAt25C;
            out generatedCurrent = photocurrentOutput.currentSignal;
        }

        assert constraint {
            biasInput.reverseBias.value <= maximumReverseBias
        }
    }

    part def ReverseBiasNetwork {
        doc "Provides a stable low-noise reverse bias for the LED junction so that photocurrent is repeatable and response time is improved.";

        port powerInput : PowerInPort;
        port ground : GroundPort;
        port biasOutput : BiasControlPort;

        attribute nominalSupply : Voltage = 3.3;
        attribute reverseBiasSetpoint : Voltage = 1.8;
        attribute biasTolerance : Voltage = 0.05;
        attribute biasNoiseRms : Voltage = 0.001;
        attribute currentLimit : Current = 100.0e-6;

        assert constraint {
            reverseBiasSetpoint > 0.0 and reverseBiasSetpoint <= 3.0
        }
    }

    part def TransimpedanceAmplifier {
        doc "Converts the LED-generated photocurrent into a voltage suitable for analog-to-digital conversion.";

        port currentInput : AnalogVoltageInPort;
        port voltageOutput : AnalogVoltageOutPort;
        port powerInput : PowerInPort;
        port ground : GroundPort;

        attribute feedbackResistance : Resistance = 1000000.0;
        attribute feedbackCapacitance : Capacitance = 47.0e-12;
        attribute outputOffset : Voltage = 0.050;
        attribute outputMinimum : Voltage = 0.0;
        attribute outputMaximum : Voltage = 3.0;
        attribute inputBiasCurrent : Current = 2.0e-12;
        attribute bandwidth : Frequency = 1000.0;

        perform action amplify : TransimpedanceAmplify {
            in feedbackResistance = feedbackResistance;
            in outputOffset = outputOffset;
            in minimumOutput = outputMinimum;
            in maximumOutput = outputMaximum;
            out outputVoltage = voltageOutput.voltageSignal;
        }

        assert constraint {
            feedbackResistance >= 100000.0 and feedbackResistance <= 10000000.0
        }
    }

    part def AnalogToDigitalConverter {
        doc "Samples the conditioned LED sensor voltage and produces digital counts.";

        port analogInput : AnalogVoltageInPort;
        port sampleOutput : DigitalSampleOutPort;
        port powerInput : PowerInPort;
        port ground : GroundPort;

        attribute referenceVoltage : Voltage = 3.0;
        attribute resolution : BitCount = 12;
        attribute maximumCount : DigitalCount = 4095;
        attribute sampleRate : Frequency = 100.0;
        attribute inputImpedance : Resistance = 1000000.0;
        attribute acquisitionTime : Time = 0.00001;

        perform action sampleAnalog : SampleAnalogVoltage {
            in analogVoltage = analogInput.voltageSignal;
            in referenceVoltage = referenceVoltage;
            in adcResolution = resolution;
            in samplePeriod = 0.01;
            out sample = sampleOutput.sample;
        }

        assert constraint {
            referenceVoltage > 0.0
        }

        assert constraint {
            resolution == 12
        }
    }

    part def TemperatureSensor {
        doc "Measures local electronics temperature for LED dark-current and sensitivity compensation.";

        port environmentOutput : TemperatureOutPort;
        port powerInput : PowerInPort;
        port ground : GroundPort;

        attribute accuracy : Temperature = 1.0;
        attribute measurementRate : Frequency = 1.0;
        attribute nominalTemperature : Temperature = 25.0;
    }

    part def MeasurementProcessor {
        doc "Executes dark calibration, converts ADC counts to illuminance, compensates temperature, applies averaging, and produces a reported measurement.";

        port sampleInput : DigitalSampleInPort;
        port environmentInput : TemperatureOutPort;
        port commandInput : CommandInPort;
        port measurementOutput : MeasurementOutPort;
        port statusOutput : StatusOutPort;
        port powerInput : PowerInPort;
        port ground : GroundPort;

        attribute mode : SensorMode = SensorMode::standby;
        attribute darkOffsetCount : DigitalCount = 14;
        attribute saturationThresholdCount : DigitalCount = 4000;
        attribute minimumValidCountAboveDark : DigitalCount = 3;
        attribute calibrationSlope : Real = 0.85 {
            unit = "lx_per_count";
        }
        attribute calibrationReferenceWavelength : Wavelength = 630.0;
        attribute temperatureCoefficient : Real = 0.18 {
            unit = "percent_per_degC";
        }
        attribute averagingWindow : SampleCount = 16;
        attribute outputRate : Frequency = 10.0;
        attribute maximumReportedIlluminance : Illuminance = 3000.0;
        attribute expandedUncertainty : MeasurementUncertainty = 8.0;

        perform state operationalBehavior : SensingUnitOperationalStates;

        perform action estimate : EstimateIlluminance {
            in sample = sampleInput.sample;
            in darkOffsetCount = darkOffsetCount;
            in calibrationSlope = calibrationSlope;
            in temperatureCoefficient = temperatureCoefficient;
            out measurement = measurementOutput.measurement;
        }

        perform action average : AverageMeasurements {
            in newMeasurement = measurementOutput.measurement;
            in windowLength = averagingWindow;
            out averagedMeasurement = measurementOutput.measurement;
        }

        assert constraint {
            darkOffsetCount < saturationThresholdCount
        }

        assert constraint {
            averagingWindow >= 1 and averagingWindow <= 64
        }
    }

    part def PowerRegulator {
        doc "Provides regulated analog and digital power rails for the sensing unit.";

        port supplyInput : PowerInPort;
        port regulatedOutput : PowerInPort;
        port ground : GroundPort;

        attribute inputVoltageMin : Voltage = 3.0;
        attribute inputVoltageMax : Voltage = 5.5;
        attribute regulatedVoltage : Voltage = 3.3;
        attribute voltageTolerance : Voltage = 0.05;
        attribute outputNoiseRms : Voltage = 0.002;
        attribute maximumLoadCurrent : Current = 0.020;

        assert constraint {
            regulatedVoltage >= 3.25 and regulatedVoltage <= 3.35
        }
    }

    part def LEDLightSensingUnit {
        doc "A compact sensing unit that measures illuminance by using a conventional LED junction as the light-sensitive element.";

        port opticalAperture : OpticalInputPort;
        port externalCommand : CommandInPort;
        port measurementReport : MeasurementOutPort;
        port statusReport : StatusOutPort;
        port externalSupply : PowerInPort;
        port externalGround : GroundPort;

        part regulator : PowerRegulator;
        part ledSensor : LightEmittingDiodeSensor;
        part biasNetwork : ReverseBiasNetwork;
        part amplifier : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part processor : MeasurementProcessor;

        attribute measurableQuantity : String = "illuminance";
        attribute nominalSampleRate : Frequency = 100.0;
        attribute reportedOutputRate : Frequency = 10.0;
        attribute measurementRangeLow : Illuminance = 1.0;
        attribute measurementRangeHigh : Illuminance = 3000.0;
        attribute responseTime : Time = 0.25;
        attribute warmupTime : Time = 0.5;
        attribute nominalSupplyVoltage : Voltage = 3.3;
        attribute maximumSupplyCurrent : Current = 0.020;
        attribute totalExpandedUncertainty : MeasurementUncertainty = 10.0;
        attribute opticalAcceptanceHalfAngle : Real = 35.0 {
            unit = "deg";
        }

        connect externalSupply to regulator.supplyInput;
        connect externalGround to regulator.ground;
        connect regulator.regulatedOutput to biasNetwork.powerInput;
        connect regulator.regulatedOutput to amplifier.powerInput;
        connect regulator.regulatedOutput to adc.powerInput;
        connect regulator.regulatedOutput to temperatureSensor.powerInput;
        connect regulator.regulatedOutput to processor.powerInput;

        connect externalGround to biasNetwork.ground;
        connect externalGround to ledSensor.cathodeReference;
        connect externalGround to amplifier.ground;
        connect externalGround to adc.ground;
        connect externalGround to temperatureSensor.ground;
        connect externalGround to processor.ground;

        connect opticalAperture to ledSensor.opticalInput;
        connect biasNetwork.biasOutput to ledSensor.biasInput;
        connect ledSensor.photocurrentOutput to amplifier.currentInput;
        connect amplifier.voltageOutput to adc.analogInput;
        connect adc.sampleOutput to processor.sampleInput;
        connect temperatureSensor.environmentOutput to processor.environmentInput;
        connect externalCommand to processor.commandInput;
        connect processor.measurementOutput to measurementReport;
        connect processor.statusOutput to statusReport;

        assert constraint {
            measurementRangeLow >= 0.0
        }

        assert constraint {
            measurementRangeHigh > measurementRangeLow
        }

        assert constraint {
            totalExpandedUncertainty <= 10.0
        }

        assert constraint {
            responseTime <= 0.5
        }
    }

    requirement def UseLEDAsLightSensorRequirement {
        doc "The sensing unit shall measure the relevant optical quantity using a light-emitting diode junction as the light sensor rather than a dedicated photodiode or phototransistor.";

        subject unit : LEDLightSensingUnit;

        require constraint {
            unit.measurableQuantity == "illuminance"
        }

        require constraint {
            unit.ledSensor.peakSensitivityWavelength >= 600.0 and unit.ledSensor.peakSensitivityWavelength <= 660.0
        }

        require constraint {
            unit.ledSensor.responsivityAtPeak > 0.0
        }
    }

    requirement def MeasurementRangeRequirement {
        doc "The sensing unit shall report illuminance from 1 lx to 3000 lx.";

        subject unit : LEDLightSensingUnit;

        require constraint {
            unit.measurementRangeLow <= 1.0 and unit.measurementRangeHigh >= 3000.0
        }
    }

    requirement def AccuracyRequirement {
        doc "The sensing unit shall provide reported illuminance with expanded uncertainty no greater than 10 percent after dark calibration.";

        subject unit : LEDLightSensingUnit;

        require constraint {
            unit.totalExpandedUncertainty <= 10.0
        }

        require constraint {
            unit.processor.calibrationSlope > 0.0
        }
    }

    requirement def SamplingRequirement {
        doc "The unit shall sample the LED sensor signal at no less than 100 Hz and report averaged measurements at 10 Hz.";

        subject unit : LEDLightSensingUnit;

        require constraint {
            unit.adc.sampleRate >= 100.0
        }

        require constraint {
            unit.reportedOutputRate == 10.0
        }
    }

    requirement def SaturationDetectionRequirement {
        doc "The processor shall identify saturated measurements before reporting quality as valid.";

        subject processor : MeasurementProcessor;

        require constraint {
            processor.saturationThresholdCount < 4095
        }

        require constraint {
            processor.minimumValidCountAboveDark >= 1
        }
    }

    requirement def SafeBiasRequirement {
        doc "The reverse-bias network shall not exceed the LED maximum reverse-bias rating.";

        subject unit : LEDLightSensingUnit;

        require constraint {
            unit.biasNetwork.reverseBiasSetpoint <= unit.ledSensor.maximumReverseBias
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc "The sensing unit shall compensate the LED dark current and sensitivity using local temperature measurement.";

        subject unit : LEDLightSensingUnit;

        require constraint {
            unit.processor.temperatureCoefficient > 0.0
        }

        require constraint {
            unit.temperatureSensor.accuracy <= 2.0
        }
    }

    part ledIlluminanceSensorUnit : LEDLightSensingUnit {
        attribute measurableQuantity = "illuminance";
        attribute nominalSampleRate = 100.0;
        attribute reportedOutputRate = 10.0;
        attribute measurementRangeLow = 1.0;
        attribute measurementRangeHigh = 3000.0;
        attribute responseTime = 0.25;
        attribute totalExpandedUncertainty = 10.0;

        part redefines ledSensor {
            attribute peakSensitivityWavelength = 630.0;
            attribute spectralBandwidthFwhm = 45.0;
            attribute junctionArea = 0.28;
            attribute responsivityAtPeak = 2.1e-9;
            attribute darkCurrentAt25C = 8.0e-9;
            attribute maximumReverseBias = 3.0;
        }

        part redefines biasNetwork {
            attribute reverseBiasSetpoint = 1.8;
            attribute biasNoiseRms = 0.001;
        }

        part redefines amplifier {
            attribute feedbackResistance = 1000000.0;
            attribute feedbackCapacitance = 47.0e-12;
            attribute outputOffset = 0.050;
            attribute bandwidth = 1000.0;
        }

        part redefines adc {
            attribute referenceVoltage = 3.0;
            attribute resolution = 12;
            attribute sampleRate = 100.0;
        }

        part redefines processor {
            attribute darkOffsetCount = 14;
            attribute saturationThresholdCount = 4000;
            attribute calibrationSlope = 0.85;
            attribute averagingWindow = 16;
            attribute expandedUncertainty = 8.0;
        }
    }

    satisfy UseLEDAsLightSensorRequirement by ledIlluminanceSensorUnit;
    satisfy MeasurementRangeRequirement by ledIlluminanceSensorUnit;
    satisfy AccuracyRequirement by ledIlluminanceSensorUnit;
    satisfy SamplingRequirement by ledIlluminanceSensorUnit;
    satisfy SafeBiasRequirement by ledIlluminanceSensorUnit;
    satisfy TemperatureCompensationRequirement by ledIlluminanceSensorUnit;
    satisfy SaturationDetectionRequirement by ledIlluminanceSensorUnit.processor;
}
