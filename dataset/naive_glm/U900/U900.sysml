package DigitalSunSensorModel {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQElectromagnetism::*;

    // ---------- Value Types ----------
    value def Voltage :> Real { unit 'V' "volt"; }
    value def Angle :> Real { unit 'deg' "degree"; }
    value def QualityScore :> Real { unit '1' "dimensionless"; min 0; max 1; }
    value def Timestamp :> Real { unit 's' "second"; }
    value def Gain :> Real { unit '1' "dimensionless"; }
    value def Frequency :> Real { unit 'Hz' "hertz"; }

    // ---------- Item Definitions ----------
    item def RawVoltageSet {
        attribute vTop : Voltage;
        attribute vBottom : Voltage;
        attribute vLeft : Voltage;
        attribute vRight : Voltage;
    }

    item def CleanVoltageSet {
        attribute vTop : Voltage;
        attribute vBottom : Voltage;
        attribute vLeft : Voltage;
        attribute vRight : Voltage;
    }

    item def CalibrationCoefficients {
        attribute kAzimuth : Real;
        attribute kElevation : Real;
        attribute offsetAzimuth : Angle;
        attribute offsetElevation : Angle;
    }

    item def AngleData {
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    item def ValidatedMeasurement {
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute timestamp : Timestamp;
        attribute quality : QualityScore;
        attribute valid : Boolean;
    }

    item def Sunlight {
        attribute irradiance : Real; // W/m^2
    }

    // ---------- Interfaces ----------
    interface def RawSignalFlow {
        end source : RawVoltageSet;
        end target : RawVoltageSet;
    }

    interface def CleanSignalFlow {
        end source : CleanVoltageSet;
        end target : CleanVoltageSet;
    }

    interface def AngleDataFlow {
        end source : AngleData;
        end target : AngleData;
    }

    interface def MeasurementFlow {
        end source : ValidatedMeasurement;
        end target : ValidatedMeasurement;
    }

    // ---------- Part Definitions ----------
    part def Photodiode {
        attribute id : String;
        port opticalIn : in Sunlight;
        port voltageOut : out Voltage;
        attribute sensitivity : Real = 0.5; // V per (W/m^2)
        action generateVoltage {
            in irradiance : Real;
            out v : Voltage;
        }
    }

    part def SensorHead {
        attribute quadrantSpacing : Angle = 45.0 ['deg'];
        port opticalAperture : in Sunlight;
        port rawSignalsOut : out RawVoltageSet;

        part topPhotodiode : Photodiode { id = "top"; }
        part bottomPhotodiode : Photodiode { id = "bottom"; }
        part leftPhotodiode : Photodiode { id = "left"; }
        part rightPhotodiode : Photodiode { id = "right"; }

        action assembleRawSet {
            in vTop : Voltage;
            in vBottom : Voltage;
            in vLeft : Voltage;
            in vRight : Voltage;
            out set : RawVoltageSet;
        }

        connection opticalAperture to topPhotodiode.opticalIn;
        connection opticalAperture to bottomPhotodiode.opticalIn;
        connection opticalAperture to leftPhotodiode.opticalIn;
        connection opticalAperture to rightPhotodiode.opticalIn;

        connection topPhotodiode.voltageOut to assembleRawSet.vTop;
        connection bottomPhotodiode.voltageOut to assembleRawSet.vBottom;
        connection leftPhotodiode.voltageOut to assembleRawSet.vLeft;
        connection rightPhotodiode.voltageOut to assembleRawSet.vRight;

        connection assembleRawSet.set to rawSignalsOut;
    }

    part def SignalProcessor {
        attribute amplifierGain : Gain = 100.0;
        attribute filterCutoff : Frequency = 1000.0 ['Hz'];
        port rawIn : in RawVoltageSet;
        port cleanOut : out CleanVoltageSet;

        action amplify {
            in raw : RawVoltageSet;
            out amplified : RawVoltageSet;
        }

        action filter {
            in amplified : RawVoltageSet;
            out clean : CleanVoltageSet;
        }

        flow rawIn to amplify.raw;
        connection amplify.amplified to filter.amplified;
        connection filter.clean to cleanOut;
    }

    part def AngleCalculator {
        attribute coefficients : CalibrationCoefficients;
        port cleanIn : in CleanVoltageSet;
        port anglesOut : out AngleData;

        action computeDifferences {
            in clean : CleanVoltageSet;
            out deltaVertical : Voltage;
            out deltaHorizontal : Voltage;
        }

        action computeAngles {
            in deltaVertical : Voltage;
            in deltaHorizontal : Voltage;
            in coeffs : CalibrationCoefficients;
            out angles : AngleData;
        }

        flow cleanIn to computeDifferences.clean;
        connection computeDifferences.deltaVertical to computeAngles.deltaVertical;
        connection computeDifferences.deltaHorizontal to computeAngles.deltaHorizontal;
        connection coefficients to computeAngles.coeffs;
        connection computeAngles.angles to anglesOut;
    }

    part def MeasurementValidator {
        attribute minElevation : Angle = -5.0 ['deg'];
        attribute maxElevation : Angle = 90.0 ['deg'];
        attribute minAzimuth : Angle = -180.0 ['deg'];
        attribute maxAzimuth : Angle = 180.0 ['deg'];
        port anglesIn : in AngleData;
        port measurementOut : out ValidatedMeasurement;

        action validate {
            in angles : AngleData;
            in now : Timestamp;
            out measurement : ValidatedMeasurement;
        }

        flow anglesIn to validate.angles;
        connection validate.measurement to measurementOut;
    }

    part def DigitalSunSensor {
        attribute deviceSerial : String;
        attribute firmwareVersion : String = "1.0.0";
        attribute powerOn : Boolean = false;

        port sunlightIn : in Sunlight;
        port telemetryOut : out ValidatedMeasurement;

        part sensorHead : SensorHead;
        part signalProcessor : SignalProcessor;
        part angleCalculator : AngleCalculator;
        part measurementValidator : MeasurementValidator;

        connection sunlightIn to sensorHead.opticalAperture;
        connection sensorHead.rawSignalsOut to signalProcessor.rawIn;
        connection signalProcessor.cleanOut to angleCalculator.cleanIn;
        connection angleCalculator.anglesOut to measurementValidator.anglesIn;
        connection measurementValidator.measurementOut to telemetryOut;

        // ---------- Lifecycle State Machine ----------
        state def Lifecycle {
            entry; then Off;

            state Off {
                entry action { powerOn = false; }
                transition off_to_init
                    first Off
                    accept PowerOn
                    then Initializing;
            }

            state Initializing {
                entry action { powerOn = true; }
                do action performSelfTest;
                transition init_to_cal
                    first Initializing
                    accept SelfTestPassed
                    then Calibrating;
                transition init_to_fault
                    first Initializing
                    accept SelfTestFailed
                    then Fault;
            }

            state Calibrating {
                do action loadCalibrationCoefficients;
                transition cal_to_ready
                    first Calibrating
                    accept CalibrationComplete
                    then Ready;
                transition cal_to_fault
                    first Calibrating
                    accept CalibrationFailed
                    then Fault;
            }

            state Ready {
                transition ready_to_operating
                    first Ready
                    accept StartMeasurement
                    then Operating;
            }

            state Operating {
                entry action { /* begin continuous measurement loop */ }
                do action takeContinuousMeasurements;
                transition operating_to_fault
                    first Operating
                    accept ErrorDetected
                    then Fault;
                transition operating_to_ready
                    first Operating
                    accept StopMeasurement
                    then Ready;
            }

            state Fault {
                entry action { /* log fault and halt outputs */ }
                transition fault_to_off
                    first Fault
                    accept Reset
                    then Off;
            }
        }

        action performSelfTest {
            out status : Boolean;
        }

        action loadCalibrationCoefficients {
            out coeffs : CalibrationCoefficients;
        }

        action takeContinuousMeasurements {
            in sunlight : Sunlight;
            out measurement : ValidatedMeasurement;
        }
    }

    // ---------- Requirements ----------
    requirement def SunSensingRequirement {
        subject sensor : DigitalSunSensor;
        objective {
            doc /* The sensor shall determine the direction of the sun relative to itself. */
        }
    }

    requirement def AzimuthAccuracyRequirement :> SunSensingRequirement {
        attribute maxAzimuthError : Angle = 0.1 ['deg'];
        require sensor.telemetryOut.azimuth accuracy <= maxAzimuthError;
    }

    requirement def ElevationAccuracyRequirement :> SunSensingRequirement {
        attribute maxElevationError : Angle = 0.1 ['deg'];
        require sensor.telemetryOut.elevation accuracy <= maxElevationError;
    }

    requirement def OutputRateRequirement :> SunSensingRequirement {
        attribute minOutputRate : Frequency = 10.0 ['Hz'];
        require sensor.telemetryOut rate >= minOutputRate;
    }

    requirement def ValidatedOutputRequirement :> SunSensingRequirement {
        require sensor.telemetryOut.valid == true when sensor in Operating;
    }

    requirement def FaultHandlingRequirement :> SunSensingRequirement {
        require sensor in Fault implies sensor.telemetryOut.valid == false;
    }

    requirement SunSensing : SunSensingRequirement {
        subject sensor : DigitalSunSensor;
    }

    requirement AzimuthAccuracy : AzimuthAccuracyRequirement {
        subject sensor : DigitalSunSensor;
    }

    requirement ElevationAccuracy : ElevationAccuracyRequirement {
        subject sensor : DigitalSunSensor;
    }

    requirement OutputRate : OutputRateRequirement {
        subject sensor : DigitalSunSensor;
    }

    requirement ValidatedOutput : ValidatedOutputRequirement {
        subject sensor : DigitalSunSensor;
    }

    requirement FaultHandling : FaultHandlingRequirement {
        subject sensor : DigitalSunSensor;
    }

}
