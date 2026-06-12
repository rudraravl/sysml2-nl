package SunSensorSensingUnitModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Irradiance {
        unit = SI::watt / SI::meter^2;
    }

    attribute def TimeDuration :> ISQ::duration {
        unit = SI::second;
    }

    attribute def DataRate {
        unit = SI::bit / SI::second;
    }

    attribute def DigitalCount {
        unit = one;
    }

    attribute def Confidence {
        unit = one;
    }

    item def PowerInput {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def RegulatedPower {
        attribute voltage : Voltage;
        attribute currentLimit : Current;
        attribute ripple : Voltage;
    }

    item def Sunlight {
        attribute irradiance : Irradiance;
        attribute incidenceAzimuth : Angle;
        attribute incidenceElevation : Angle;
    }

    item def PhotodiodeCurrent {
        attribute xPositiveCurrent : Current;
        attribute xNegativeCurrent : Current;
        attribute yPositiveCurrent : Current;
        attribute yNegativeCurrent : Current;
        attribute referenceCurrent : Current;
    }

    item def DigitizedSunMeasurement {
        attribute xPositiveCount : DigitalCount;
        attribute xNegativeCount : DigitalCount;
        attribute yPositiveCount : DigitalCount;
        attribute yNegativeCount : DigitalCount;
        attribute referenceCount : DigitalCount;
        attribute detectorTemperature : Temperature;
        attribute sampleTime : TimeDuration;
    }

    item def SunVectorMeasurement {
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute sunPresent : Boolean;
        attribute confidence : Confidence;
        attribute irradianceEstimate : Irradiance;
        attribute measurementAge : TimeDuration;
    }

    item def HealthStatus {
        attribute powerGood : Boolean;
        attribute detectorHealthy : Boolean;
        attribute processorHealthy : Boolean;
        attribute calibrationValid : Boolean;
        attribute faultCode : Integer;
        attribute internalTemperature : Temperature;
    }

    item def SensorCommand {
        attribute enableMeasurement : Boolean;
        attribute requestCalibration : Boolean;
        attribute resetFaults : Boolean;
        attribute samplePeriod : TimeDuration;
    }

    port def PowerInPort {
        in item inputPower : PowerInput;
    }

    port def RegulatedPowerPort {
        out item regulatedPower : RegulatedPower;
    }

    port def OpticalPort {
        in item incidentLight : Sunlight;
    }

    port def PhotodiodeSignalPort {
        out item diodeSignal : PhotodiodeCurrent;
    }

    port def AnalogSignalPort {
        in item diodeSignal : PhotodiodeCurrent;
        out item conditionedSignal : PhotodiodeCurrent;
    }

    port def DigitalMeasurementPort {
        out item digitalMeasurement : DigitizedSunMeasurement;
    }

    port def SunVectorOutPort {
        out item sunVector : SunVectorMeasurement;
    }

    port def CommandInPort {
        in item command : SensorCommand;
    }

    port def HealthOutPort {
        out item health : HealthStatus;
    }

    port def ThermalInterfacePort {
        out attribute dissipatedPower : Power;
        in attribute mountingTemperature : Temperature;
    }

    action def ConvertLightToPhotocurrent {
        in item incidentLight : Sunlight;
        out item diodeSignal : PhotodiodeCurrent;

        attribute responsivity : Current = 0.42 [SI::ampere] / (1.0 [SI::watt]);
        attribute apertureArea = 0.000025 [SI::meter^2];
        attribute fieldOfViewHalfAngle : Angle = 60 [SI::degree];
    }

    action def ConditionPhotodiodeSignals {
        in item rawSignal : PhotodiodeCurrent;
        out item conditionedSignal : PhotodiodeCurrent;

        attribute transimpedanceGain = 200000 [SI::ohm];
        attribute lowPassCutoff = 50 [SI::hertz];
        attribute offsetError : Current = 2.0e-9 [SI::ampere];
    }

    action def DigitizeSignals {
        in item conditionedSignal : PhotodiodeCurrent;
        out item digitalMeasurement : DigitizedSunMeasurement;

        attribute adcResolutionBits : Integer = 16;
        attribute conversionTime : TimeDuration = 0.002 [SI::second];
        attribute samplePeriod : TimeDuration = 0.1 [SI::second];
    }

    action def EstimateSunVector {
        in item digitalMeasurement : DigitizedSunMeasurement;
        out item sunVector : SunVectorMeasurement;

        attribute minimumValidIrradiance : Irradiance = 50 [SI::watt / SI::meter^2];
        attribute angularResolution : Angle = 0.1 [SI::degree];
        attribute maximumError : Angle = 0.5 [SI::degree];
    }

    action def RunBuiltInTest {
        out item health : HealthStatus;

        attribute maximumElectronicsTemperature : Temperature = 85 [SI::degreeCelsius];
        attribute minimumSupplyVoltage : Voltage = 4.75 [SI::volt];
        attribute maximumSupplyVoltage : Voltage = 5.25 [SI::volt];
    }

    part def OpticalBaffle {
        port opticalIn : OpticalPort;

        attribute fieldOfViewHalfAngle : Angle = 60 [SI::degree];
        attribute strayLightRejectionAngle : Angle = 75 [SI::degree];
        attribute transmissionEfficiency : Real = 0.92;
    }

    part def QuadrantPhotodiodeDetector {
        port opticalIn : OpticalPort;
        port signalOut : PhotodiodeSignalPort;

        attribute spectralRangeMin = 400 [SI::nanometer];
        attribute spectralRangeMax = 1100 [SI::nanometer];
        attribute activeArea = 25 [SI::millimeter^2];
        attribute darkCurrent : Current = 5.0e-9 [SI::ampere];
        attribute operatingTemperatureMin : Temperature = -40 [SI::degreeCelsius];
        attribute operatingTemperatureMax : Temperature = 85 [SI::degreeCelsius];

        perform action lightConversion : ConvertLightToPhotocurrent {
            in incidentLight = opticalIn.incidentLight;
            out diodeSignal = signalOut.diodeSignal;
        }
    }

    part def AnalogFrontEnd {
        port signalIn : AnalogSignalPort;
        port powerIn : RegulatedPowerPort;
        port signalOut : PhotodiodeSignalPort;

        attribute inputNoise : Current = 1.0e-9 [SI::ampere];
        attribute bandwidth = 50 [SI::hertz];
        attribute gainError : Real = 0.002;
        attribute consumedPower : Power = 0.12 [SI::watt];

        perform action conditioning : ConditionPhotodiodeSignals {
            in rawSignal = signalIn.diodeSignal;
            out conditionedSignal = signalOut.diodeSignal;
        }
    }

    part def AnalogToDigitalConverter {
        port signalIn : AnalogSignalPort;
        port measurementOut : DigitalMeasurementPort;
        port powerIn : RegulatedPowerPort;

        attribute resolutionBits : Integer = 16;
        attribute inputVoltageRange : Voltage = 3.3 [SI::volt];
        attribute sampleRate = 10 [SI::hertz];
        attribute consumedPower : Power = 0.08 [SI::watt];

        perform action digitization : DigitizeSignals {
            in conditionedSignal = signalIn.conditionedSignal;
            out digitalMeasurement = measurementOut.digitalMeasurement;
        }
    }

    part def SunVectorProcessor {
        port measurementIn : DigitalMeasurementPort;
        port commandIn : CommandInPort;
        port sunVectorOut : SunVectorOutPort;
        port healthOut : HealthOutPort;
        port powerIn : RegulatedPowerPort;

        attribute processorClockRate = 16 [SI::megahertz];
        attribute nominalSamplePeriod : TimeDuration = 0.1 [SI::second];
        attribute outputDataRate : DataRate = 1000 [SI::bit / SI::second];
        attribute consumedPower : Power = 0.18 [SI::watt];

        perform action vectorEstimation : EstimateSunVector {
            in digitalMeasurement = measurementIn.digitalMeasurement;
            out sunVector = sunVectorOut.sunVector;
        }

        perform action builtInTest : RunBuiltInTest {
            out health = healthOut.health;
        }

        state def ProcessorOperatingState {
            entry action initialize {
                then builtInTest;
            }

            state off;
            state initializing;
            state standby;
            state measuring;
            state calibrating;
            state faulted;

            transition first off;
            transition off_to_initializing
                first off
                then initializing
                if commandIn.command.enableMeasurement;

            transition initializing_to_standby
                first initializing
                then standby
                if healthOut.health.powerGood and healthOut.health.processorHealthy;

            transition standby_to_measuring
                first standby
                then measuring
                if commandIn.command.enableMeasurement and not commandIn.command.requestCalibration;

            transition measuring_to_standby
                first measuring
                then standby
                if not commandIn.command.enableMeasurement;

            transition standby_to_calibrating
                first standby
                then calibrating
                if commandIn.command.requestCalibration;

            transition calibrating_to_standby
                first calibrating
                then standby
                if healthOut.health.calibrationValid;

            transition any_to_faulted
                first standby
                then faulted
                if not healthOut.health.powerGood or not healthOut.health.detectorHealthy or not healthOut.health.processorHealthy;

            transition faulted_to_initializing
                first faulted
                then initializing
                if commandIn.command.resetFaults;
        }
    }

    part def PowerConditioner {
        port powerIn : PowerInPort;
        port regulatedOut : RegulatedPowerPort;

        attribute inputVoltageMin : Voltage = 9 [SI::volt];
        attribute inputVoltageMax : Voltage = 36 [SI::volt];
        attribute outputVoltage : Voltage = 5 [SI::volt];
        attribute efficiency : Real = 0.86;
        attribute outputCurrentLimit : Current = 0.25 [SI::ampere];
        attribute outputRipple : Voltage = 0.02 [SI::volt];
    }

    part def ThermalMount {
        port thermal : ThermalInterfacePort;

        attribute conductance = 1.5 [SI::watt / SI::kelvin];
        attribute allowableMountingTemperatureMin : Temperature = -40 [SI::degreeCelsius];
        attribute allowableMountingTemperatureMax : Temperature = 70 [SI::degreeCelsius];
    }

    part def SunSensorSensingUnit {
        port sunlightIn : OpticalPort;
        port primaryPowerIn : PowerInPort;
        port commandIn : CommandInPort;
        port sunVectorOut : SunVectorOutPort;
        port healthOut : HealthOutPort;
        port thermalInterface : ThermalInterfacePort;

        attribute totalMass = 0.18 [SI::kilogram];
        attribute nominalInputPower : Power = 0.55 [SI::watt];
        attribute measurementAccuracy : Angle = 0.5 [SI::degree];
        attribute measurementRangeAzimuth : Angle = 120 [SI::degree];
        attribute measurementRangeElevation : Angle = 120 [SI::degree];
        attribute updatePeriod : TimeDuration = 0.1 [SI::second];

        part baffle : OpticalBaffle;
        part detector : QuadrantPhotodiodeDetector;
        part analogFrontEnd : AnalogFrontEnd;
        part adc : AnalogToDigitalConverter;
        part processor : SunVectorProcessor;
        part powerConditioner : PowerConditioner;
        part thermalMount : ThermalMount;

        connect sunlightIn to baffle.opticalIn;
        connect baffle.opticalIn to detector.opticalIn;
        connect detector.signalOut to analogFrontEnd.signalIn;
        connect analogFrontEnd.signalOut to adc.signalIn;
        connect adc.measurementOut to processor.measurementIn;
        connect processor.sunVectorOut to sunVectorOut;
        connect processor.healthOut to healthOut;
        connect commandIn to processor.commandIn;
        connect primaryPowerIn to powerConditioner.powerIn;
        connect powerConditioner.regulatedOut to analogFrontEnd.powerIn;
        connect powerConditioner.regulatedOut to adc.powerIn;
        connect powerConditioner.regulatedOut to processor.powerIn;
        connect thermalInterface to thermalMount.thermal;

        constraint totalPowerLimit {
            analogFrontEnd.consumedPower + adc.consumedPower + processor.consumedPower <= nominalInputPower;
        }

        constraint validMeasurementRange {
            sunVectorOut.sunVector.azimuth >= -60 [SI::degree] and
            sunVectorOut.sunVector.azimuth <= 60 [SI::degree] and
            sunVectorOut.sunVector.elevation >= -60 [SI::degree] and
            sunVectorOut.sunVector.elevation <= 60 [SI::degree];
        }
    }

    requirement def MeasureSunVectorRequirement {
        subject sensingUnit : SunSensorSensingUnit;

        require constraint {
            sensingUnit.sunVectorOut.sunVector.sunPresent implies
            abs(sensingUnit.sunVectorOut.sunVector.azimuth - sensingUnit.sunlightIn.incidentLight.incidenceAzimuth) <= 0.5 [SI::degree] and
            abs(sensingUnit.sunVectorOut.sunVector.elevation - sensingUnit.sunlightIn.incidentLight.incidenceElevation) <= 0.5 [SI::degree];
        }
    }

    requirement def DetectSunPresenceRequirement {
        subject sensingUnit : SunSensorSensingUnit;

        require constraint {
            sensingUnit.sunlightIn.incidentLight.irradiance >= 50 [SI::watt / SI::meter^2] implies
            sensingUnit.sunVectorOut.sunVector.sunPresent == true;
        }
    }

    requirement def UpdateRateRequirement {
        subject sensingUnit : SunSensorSensingUnit;

        require constraint {
            sensingUnit.sunVectorOut.sunVector.measurementAge <= 0.1 [SI::second];
        }
    }

    requirement def ElectricalInterfaceRequirement {
        subject sensingUnit : SunSensorSensingUnit;

        require constraint {
            sensingUnit.primaryPowerIn.inputPower.voltage >= 9 [SI::volt] and
            sensingUnit.primaryPowerIn.inputPower.voltage <= 36 [SI::volt] and
            sensingUnit.primaryPowerIn.inputPower.current <= 0.25 [SI::ampere];
        }
    }

    requirement def EnvironmentalTemperatureRequirement {
        subject sensingUnit : SunSensorSensingUnit;

        require constraint {
            sensingUnit.thermalInterface.mountingTemperature >= -40 [SI::degreeCelsius] and
            sensingUnit.thermalInterface.mountingTemperature <= 70 [SI::degreeCelsius];
        }
    }

    requirement def HealthReportingRequirement {
        subject sensingUnit : SunSensorSensingUnit;

        require constraint {
            sensingUnit.healthOut.health.powerGood and
            sensingUnit.healthOut.health.detectorHealthy and
            sensingUnit.healthOut.health.processorHealthy and
            sensingUnit.healthOut.health.calibrationValid implies
            sensingUnit.healthOut.health.faultCode == 0;
        }
    }

    satisfy MeasureSunVectorRequirement by SunSensorSensingUnit;
    satisfy DetectSunPresenceRequirement by SunSensorSensingUnit;
    satisfy UpdateRateRequirement by SunSensorSensingUnit;
    satisfy ElectricalInterfaceRequirement by SunSensorSensingUnit;
    satisfy EnvironmentalTemperatureRequirement by SunSensorSensingUnit;
    satisfy HealthReportingRequirement by SunSensorSensingUnit;

}