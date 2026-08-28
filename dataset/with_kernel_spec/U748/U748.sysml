package LightSensingUnitModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    value def IlluminanceValue :> ISQ::Illuminance;
    value def CurrentValue :> ISQ::ElectricCurrent;
    value def VoltageValue :> ISQ::ElectricPotential;
    value def TemperatureValue :> ISQ::ThermodynamicTemperature;
    value def DigitalValue :> Integer;

    item def LightSignal {
        attribute illuminance : IlluminanceValue;
    }
    item def CurrentSignal {
        attribute current : CurrentValue;
    }
    item def VoltageSignal {
        attribute voltage : VoltageValue;
    }
    item def RawDigital {
        attribute value : DigitalValue;
    }
    item def CalibrationData {
        attribute offset : DigitalValue;
        attribute gain : Real;
    }
    item def IlluminanceData {
        attribute illuminance : IlluminanceValue;
        attribute timestamp : DateTime;
        attribute sensorId : String;
    }
    item def StatusSignal {
        attribute operationalStatus : String;
        attribute temperature : TemperatureValue;
    }

    attribute def EnableCommand;
    attribute def DisableCommand;
    attribute def ResetCommand;
    attribute def CalibrateCommand;
    attribute def CalibrationComplete;
    attribute def InitializationComplete;
    attribute def FaultSignal;

    action def ConvertLightToCurrent {
        in light : LightSignal;
        out current : CurrentSignal;
    }
    action def AmplifyCurrentToVoltage {
        in current : CurrentSignal;
        out voltage : VoltageSignal;
    }
    action def FilterVoltage {
        in voltage : VoltageSignal;
        out filteredVoltage : VoltageSignal;
    }
    action def ConvertVoltageToDigital {
        in voltage : VoltageSignal;
        out raw : RawDigital;
    }
    action def ApplyCalibration {
        in raw : RawDigital;
        in calibration : CalibrationData;
        out calibratedIlluminance : IlluminanceValue;
    }
    action def ValidateRange {
        in illuminance : IlluminanceValue;
        out isValid : Boolean;
    }
    action def PackageData {
        in illuminance : IlluminanceValue;
        in timestamp : DateTime;
        in sensorId : String;
        out data : IlluminanceData;
    }
    action def ProcessAndCalibrate {
        in raw : RawDigital;
        in calibration : CalibrationData;
        in timestamp : DateTime;
        in sensorId : String;
        out data : IlluminanceData;

        action applyCalibration : ApplyCalibration;
        action validateRange : ValidateRange;
        action packageData : PackageData;

        bind applyCalibration.raw = raw;
        bind applyCalibration.calibration = calibration;
        flow applyCalibration.calibratedIlluminance to validateRange.illuminance;
        flow applyCalibration.calibratedIlluminance to packageData.illuminance;
        bind packageData.timestamp = timestamp;
        bind packageData.sensorId = sensorId;
        bind packageData.data = data;
    }
    action def PerformMeasurement {
        in light : LightSignal;
        in calibration : CalibrationData;
        in timestamp : DateTime;
        in sensorId : String;
        out data : IlluminanceData;

        action convertLight : ConvertLightToCurrent;
        action amplify : AmplifyCurrentToVoltage;
        action filterVoltage : FilterVoltage;
        action adcConvert : ConvertVoltageToDigital;
        action process : ProcessAndCalibrate;

        bind convertLight.light = light;
        flow convertLight.current to amplify.current;
        flow amplify.voltage to filterVoltage.voltage;
        flow filterVoltage.filteredVoltage to adcConvert.voltage;
        flow adcConvert.raw to process.raw;
        bind process.calibration = calibration;
        bind process.timestamp = timestamp;
        bind process.sensorId = sensorId;
        bind process.data = data;
    }
    action def PerformSelfTest {
        out done : Boolean;
    }
    action def ApplyUploadedCalibration {
        in uploadedCalibration : CalibrationData;
        out done : Boolean;
    }
    action def ReportFault;

    part def Photodiode {
        in item light : LightSignal;
        out item current : CurrentSignal;
        perform action convert : ConvertLightToCurrent;
    }
    part def TransimpedanceAmplifier {
        in item current : CurrentSignal;
        out item voltage : VoltageSignal;
        perform action amplify : AmplifyCurrentToVoltage;
    }
    part def LowPassFilter {
        in item voltage : VoltageSignal;
        out item filteredVoltage : VoltageSignal;
        perform action filterAction : FilterVoltage;
    }
    part def AnalogToDigitalConverter {
        in item voltage : VoltageSignal;
        out item raw : RawDigital;
        perform action convert : ConvertVoltageToDigital;
    }
    part def Microcontroller {
        in item raw : RawDigital;
        ref item calibrationData : CalibrationData;
        out item measurementData : IlluminanceData;
        out item status : StatusSignal;
        attribute sensorId : String = "LSU-001";
        attribute temperature : TemperatureValue;
        perform action process : ProcessAndCalibrate;
    }
    part def ControlInterface {
        ref item calibrationData : CalibrationData;
        out item status : StatusSignal;
    }

    part def LightSensingUnit {
        in item ambientLight : LightSignal;
        out item measurementData : IlluminanceData;
        out item status : StatusSignal;
        ref item calibrationData : CalibrationData;
        attribute fault : Boolean;
        attribute currentTime : DateTime;

        part photodiode : Photodiode;
        part amplifier : TransimpedanceAmplifier;
        part lowPassFilter : LowPassFilter;
        part adc : AnalogToDigitalConverter;
        part mcu : Microcontroller;
        part ctrlInterface : ControlInterface;

        flow ambientLight to photodiode.light;
        flow photodiode.current to amplifier.current;
        flow amplifier.voltage to lowPassFilter.voltage;
        flow lowPassFilter.filteredVoltage to adc.voltage;
        flow adc.raw to mcu.raw;
        flow mcu.measurementData to measurementData;
        flow mcu.status to status;

        action performSelfTest : PerformSelfTest;
        action performMeasurement : PerformMeasurement {
            in light = ambientLight;
            in calibration = mcu.calibrationData;
            in timestamp = currentTime;
            in sensorId = mcu.sensorId;
            out data = measurementData;
        }
        action applyUploadedCalibration : ApplyUploadedCalibration;
        action reportFault : ReportFault;

        exhibit state operationalState {
            entry; then initialization;

            state initialization {
                do performSelfTest;
            }
            accept InitializationComplete then idle;

            state idle;
            accept EnableCommand then active;
            accept CalibrateCommand then calibration;
            accept ResetCommand then initialization;

            state active {
                do performMeasurement;
            }
            accept DisableCommand then idle;
            accept ResetCommand then initialization;
            accept FaultSignal then error;

            state calibration {
                do applyUploadedCalibration;
            }
            accept CalibrationComplete then idle;
            accept ResetCommand then initialization;

            state error {
                do reportFault;
            }
            accept ResetCommand then initialization;
        }
    }

    requirement def AccuracyRequirement {
        doc /* The sensor shall measure illuminance with an accuracy of ±5% of the actual value. */
        attribute actualIlluminance : IlluminanceValue;
        attribute measuredIlluminance : IlluminanceValue;
        constraint { measuredIlluminance >= actualIlluminance * 0.95 and measuredIlluminance <= actualIlluminance * 1.05 }
    }

    requirement def RangeValidationRequirement {
        doc /* The sensor shall validate that the measured illuminance is within the range 0 to 100000 lux. */
        attribute illuminance : IlluminanceValue;
        constraint { illuminance >= 0.0 and illuminance <= 100000.0 }
    }

    requirement def ErrorHandlingRequirement {
        doc /* The sensor shall enter an error state upon detection of an internal fault and report the error. */
    }

    requirement def ControlInterfaceRequirement {
        doc /* The sensor shall support enable, reset, calibration upload, and status check commands. */
    }
}
