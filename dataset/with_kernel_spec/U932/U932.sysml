package 'Ultrasonic Thickness Gauge' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def ElectricalSignal;
    item def UltrasonicWave;

    item def Material {
        attribute name : String;
        attribute soundSpeed : SpeedValue;
        attribute tempCoefficient : Real;
    }

    item def CalibrationStandard {
        attribute knownThickness : LengthValue;
        ref item material : Material;
    }

    enum def MeasurementStatus {
        enum Valid;
        enum Error;
        enum Calibrating;
        enum Idle;
    }

    action def FirePulse {
        in trigger : ElectricalSignal;
        out pulse : ElectricalSignal;
    }

    action def ProcessEcho {
        in echo : ElectricalSignal;
        out tof : TimeValue;
        out status : MeasurementStatus;
    }

    constraint def ThicknessEquation {
        in p_tof : TimeValue;
        in p_v : SpeedValue;
        in p_k : Real;
        out p_d : LengthValue;
        p_d == p_k * (p_v * p_tof) / 2.0
    }

    constraint def TemperatureCompensatedSpeed {
        in p_baseSpeed : SpeedValue;
        in p_coeff : Real;
        in p_deltaTemp : ThermodynamicTemperatureValue;
        out p_compensatedSpeed : SpeedValue;
        p_compensatedSpeed == p_baseSpeed * (1.0 + p_coeff * p_deltaTemp)
    }

    action def CalculateThickness {
        in tof : TimeValue;
        in baseSpeed : SpeedValue;
        in temp : ThermodynamicTemperatureValue;
        in tempCoeff : Real;
        in calFactor : Real;
        out thickness : LengthValue;
        out status : MeasurementStatus;

        attribute refTemp : ThermodynamicTemperatureValue = 293.15 [K];
        attribute deltaTemp : ThermodynamicTemperatureValue;
        attribute adjustedSpeed : SpeedValue;

        assert constraint tempComp : TemperatureCompensatedSpeed {
            in p_baseSpeed = baseSpeed;
            in p_coeff = tempCoeff;
            in p_deltaTemp = temp - refTemp;
            in p_compensatedSpeed = adjustedSpeed;
        }
        assert constraint calc : ThicknessEquation {
            in p_tof = tof;
            in p_v = adjustedSpeed;
            in p_k = calFactor;
            in p_d = thickness;
        }
    }

    action def CalibrateWithStandard {
        in known : LengthValue;
        in measured : LengthValue;
        out factor : Real;
    }

    action def SelectMaterial {
        in material : Material;
        out speed : SpeedValue;
        out coeff : Real;
    }

    action def DisplayResult {
        in thickness : LengthValue;
        in status : MeasurementStatus;
    }

    part def Transducer {
        in port electricalIn : ElectricalSignal;
        out port electricalOut : ElectricalSignal;
        out port acousticOut : UltrasonicWave;
        in port acousticIn : UltrasonicWave;
        attribute frequency : FrequencyValue;
    }

    part def PulseGenerator {
        in port triggerIn : ElectricalSignal;
        out port pulseOut : ElectricalSignal;
    }

    part def SignalProcessor {
        in port echoIn : ElectricalSignal;
        out port timeOfFlightOut : TimeValue;
        out port statusOut : MeasurementStatus;
        attribute gain : Real;
        attribute threshold : Real;
    }

    part def ThicknessCalculator {
        in port timeOfFlightIn : TimeValue;
        in port soundSpeedIn : SpeedValue;
        in port temperatureIn : ThermodynamicTemperatureValue;
        in port tempCoeffIn : Real;
        in port calibrationFactorIn : Real;
        out port thicknessOut : LengthValue;
        out port statusOut : MeasurementStatus;
    }

    part def CalibrationModule {
        in port commandIn : String;
        out port soundSpeedOut : SpeedValue;
        out port tempCoeffOut : Real;
        out port calibrationFactorOut : Real;
        attribute referenceThickness : LengthValue;
        attribute measuredThickness : LengthValue;
    }

    part def TemperatureSensor {
        out port temperatureOut : ThermodynamicTemperatureValue;
    }

    part def ControlUnit {
        in port userCommandIn : String;
        out port triggerOut : ElectricalSignal;
        out port calibCommandOut : String;
        out port displayCommandOut : String;
        in port measurementResultIn : LengthValue;
        in port measurementStatusIn : MeasurementStatus;
        out port displayDataOut : LengthValue;
        out port displayStatusOut : MeasurementStatus;

        attribute userCommand : String;
        attribute measurementComplete : Boolean;
        attribute calibrationComplete : Boolean;

        state machine {
            initial state Idle;
            state Measuring;
            state Calibrating;
            transition Idle to Measuring when userCommand == "MEASURE";
            transition Measuring to Idle when measurementComplete;
            transition Idle to Calibrating when userCommand == "CALIBRATE";
            transition Calibrating to Idle when calibrationComplete;
        }
    }

    part def DisplayUnit {
        in port thicknessIn : LengthValue;
        in port statusIn : MeasurementStatus;
        in port commandIn : String;
        attribute displayedThickness : LengthValue;
        attribute displayedStatus : MeasurementStatus;
    }

    part def UltrasonicThicknessGauge {
        part transducer : Transducer;
        part pulseGenerator : PulseGenerator;
        part signalProcessor : SignalProcessor;
        part thicknessCalculator : ThicknessCalculator;
        part calibrationModule : CalibrationModule;
        part temperatureSensor : TemperatureSensor;
        part controlUnit : ControlUnit;
        part displayUnit : DisplayUnit;

        connection pulseToTransducer connect pulseGenerator.pulseOut to transducer.electricalIn;
        connection transducerToProcessor connect transducer.electricalOut to signalProcessor.echoIn;
        connection processorToCalc connect signalProcessor.timeOfFlightOut to thicknessCalculator.timeOfFlightIn;
        connection calibSpeedToCalc connect calibrationModule.soundSpeedOut to thicknessCalculator.soundSpeedIn;
        connection calibCoeffToCalc connect calibrationModule.tempCoeffOut to thicknessCalculator.tempCoeffIn;
        connection calibFactorToCalc connect calibrationModule.calibrationFactorOut to thicknessCalculator.calibrationFactorIn;
        connection tempToCalc connect temperatureSensor.temperatureOut to thicknessCalculator.temperatureIn;
        connection calcResultToControl connect thicknessCalculator.thicknessOut to controlUnit.measurementResultIn;
        connection calcStatusToControl connect thicknessCalculator.statusOut to controlUnit.measurementStatusIn;
        connection controlToPulse connect controlUnit.triggerOut to pulseGenerator.triggerIn;
        connection controlToCalib connect controlUnit.calibCommandOut to calibrationModule.commandIn;
        connection controlDataToDisplay connect controlUnit.displayDataOut to displayUnit.thicknessIn;
        connection controlStatusToDisplay connect controlUnit.displayStatusOut to displayUnit.statusIn;
        connection controlToDisplayCmd connect controlUnit.displayCommandOut to displayUnit.commandIn;

        attribute currentCalibrationFactor : Real = 1.0;

        action def MeasurementSequence {
            step generate : FirePulse;
            step process : ProcessEcho;
            step compute : CalculateThickness;
            step display : DisplayResult;
            first generate;
            next process after generate;
            next compute after process;
            next display after compute;
        }
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The gauge shall measure thickness with an accuracy of +/- 0.1 mm for standard metals. */
        subject gauge : UltrasonicThicknessGauge;
        attribute tolerance : LengthValue = 0.1 [mm];
        objective {
            require gauge.thicknessCalculator.thicknessOut >= 0 [mm];
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The thickness calculation shall compensate for material temperature variations to maintain accuracy. */
        subject gauge : UltrasonicThicknessGauge;
    }

    requirement def CalibrationRequirement {
        doc /* The device shall support calibration using a reference standard of known thickness or a pre-loaded material library. */
        subject gauge : UltrasonicThicknessGauge;
        objective {
            require gauge.calibrationModule.calibrationFactorOut > 0;
        }
    }

    individual def SteelMaterial :> Material {
        :>> name = "Steel";
        :>> soundSpeed = 5920 [m/s];
        :>> tempCoefficient = 2.4e-4;
    }

    individual def SteelCalibrationStandard :> CalibrationStandard {
        :>> knownThickness = 10.0 [mm];
    }

    individual def TestGauge :> UltrasonicThicknessGauge {
        :>> currentCalibrationFactor = 0.995;
    }
}
