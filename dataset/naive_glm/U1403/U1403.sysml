package ResistivityMeasurementSystem {

    // ================================================================
    // Value Types with Units
    // ================================================================
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Resistance :> Real { unit 'Ω'; }
    value type Resistivity :> Real { unit 'Ω·m'; }
    value type Conductivity :> Real { unit 'S/m'; }
    value type Temperature :> Real { unit 'K'; }
    value type Power :> Real { unit 'W'; }
    value type Length :> Real { unit 'm'; }
    value type Duration :> Real { unit 's'; }
    value type Dimensionless :> Real { }

    // ================================================================
    // Item Definitions
    // ================================================================
    item def MaterialSample {
        attribute sampleId : String;
        attribute materialName : String;
        attribute thickness : Length;
        attribute width : Length;
        attribute length : Length;
    }

    item def RawData {
        attribute measuredVoltage : Voltage;
        attribute measuredCurrent : Current;
        attribute measuredTemperature : Temperature;
        attribute timestamp : Duration;
    }

    item def Result {
        attribute resistance : Resistance;
        attribute resistivity : Resistivity;
        attribute conductivity : Conductivity;
        attribute measurementTemperature : Temperature;
        attribute compensatedResistivity : Resistivity;
        attribute compensatedConductivity : Conductivity;
    }

    item def Calibration {
        attribute voltageOffset : Voltage;
        attribute currentOffset : Current;
        attribute temperatureOffset : Temperature;
        attribute calibrationTimestamp : Duration;
    }

    // ================================================================
    // Part Definitions
    // ================================================================
    part def VoltageSource {
        attribute nominalVoltage : Voltage;
        attribute maxCurrent : Current;
        attribute enabled : Boolean = false;
        attribute stability : Dimensionless;

        in port enableIn : Boolean;
        out port currentOut : Current;
        in port currentReturn : Current;

        action def supplyCurrent {
            in voltage : Voltage;
            out current : Current;
        }
    }

    part def CurrentMeter {
        attribute range : Current;
        attribute resolution : Current;
        attribute measuredCurrent : Current;

        in port currentIn : Current;
        out port currentOut : Current;
        out port reading : Current;

        action def measureCurrent {
            in inputCurrent : Current;
            out outputReading : Current;
        }
    }

    part def FourPointProbe {
        attribute probeSpacing : Length;
        attribute probeCount : Integer = 4;
        attribute contactForce : Power;
        attribute sample : MaterialSample;

        in port currentIn : Current;
        out port currentOut : Current;
        out port senseVoltage : Voltage;
    }

    part def Voltmeter {
        attribute inputImpedance : Resistance;
        attribute range : Voltage;
        attribute resolution : Voltage;
        attribute measuredVoltage : Voltage;

        in port voltageIn : Voltage;
        out port reading : Voltage;

        action def measureVoltage {
            in inputVoltage : Voltage;
            out outputReading : Voltage;
        }
    }

    part def TemperatureController {
        attribute targetTemperature : Temperature;
        attribute currentTemperature : Temperature;
        attribute stabilityTolerance : Temperature;
        attribute maxHeatingPower : Power;
        attribute maxCoolingPower : Power;

        in port command : Temperature;
        in port enable : Boolean;
        out port temperatureOut : Temperature;
        out port reading : Temperature;

        action def regulateTemperature {
            in target : Temperature;
            in current : Temperature;
            out heatingPower : Power;
            out coolingPower : Power;
        }

        action def stabilizeTemperature {
            in target : Temperature;
            in tolerance : Temperature;
            out stable : Boolean;
        }
    }

    part def DataAcquisitionUnit {
        attribute samplingRate : Duration;
        attribute resolutionBits : Integer;

        in port voltageIn : Voltage;
        in port currentIn : Current;
        in port temperatureIn : Temperature;
        out port rawDataOut : RawData;

        action def acquire {
            in voltage : Voltage;
            in current : Current;
            in temperature : Temperature;
            out data : RawData;
        }
    }

    part def ControlUnit {
        attribute probeSpacing : Length;
        attribute correctionFactor : Dimensionless;
        attribute temperatureCoefficient : Dimensionless;
        attribute calibrationData : Calibration;

        in port rawDataIn : RawData;
        out port resultOut : Result;
        out port tempCommandOut : Temperature;
        out port sourceEnableOut : Boolean;
        out port tempEnableOut : Boolean;

        action def calculateResistance {
            in voltage : Voltage;
            in current : Current;
            out resistance : Resistance;
        }

        action def calculateResistivity {
            in resistance : Resistance;
            in spacing : Length;
            in factor : Dimensionless;
            in thickness : Length;
            out resistivity : Resistivity;
        }

        action def calculateConductivity {
            in resistivity : Resistivity;
            out conductivity : Conductivity;
        }

        action def compensateForTemperature {
            in resistivity : Resistivity;
            in temperature : Temperature;
            in coefficient : Dimensionless;
            out compensatedResistivity : Resistivity;
            out compensatedConductivity : Conductivity;
        }

        action def processMeasurement {
            in rawData : RawData;
            in calibration : Calibration;
            in spacing : Length;
            in factor : Dimensionless;
            in coefficient : Dimensionless;
            out result : Result;
        }
    }

    // ================================================================
    // State Machine Definition
    // ================================================================
    state def MeasurementStateMachine {
        attribute startCommand : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute temperatureStable : Boolean = false;
        attribute measurementComplete : Boolean = false;
        attribute processingComplete : Boolean = false;
        attribute reportingComplete : Boolean = false;

        state idle;
        state calibrating;
        state stabilizingTemperature;
        state measuring;
        state processing;
        state reporting;

        transition from idle to calibrating when startCommand;
        transition from calibrating to stabilizingTemperature when calibrationComplete;
        transition from stabilizingTemperature to measuring when temperatureStable;
        transition from measuring to processing when measurementComplete;
        transition from processing to reporting when processingComplete;
        transition from reporting to idle when reportingComplete;
    }

    // ================================================================
    // System Definition
    // ================================================================
    part def ResistivityMeasurementSystem {
        attribute systemId : String;
        attribute systemStatus : String = "idle";

        part voltageSource : VoltageSource {
            :>> nominalVoltage = 10.0;
            :>> maxCurrent = 1.0;
            :>> stability = 1.0e-6;
        }

        part currentMeter : CurrentMeter {
            :>> range = 1.0;
            :>> resolution = 1.0e-9;
        }

        part probe : FourPointProbe {
            :>> probeSpacing = 1.0e-3;
            :>> contactForce = 0.5;
        }

        part voltmeter : Voltmeter {
            :>> inputImpedance = 1.0e12;
            :>> range = 1.0;
            :>> resolution = 1.0e-9;
        }

        part temperatureController : TemperatureController {
            :>> stabilityTolerance = 0.01;
            :>> maxHeatingPower = 100.0;
            :>> maxCoolingPower = 50.0;
        }

        part dataAcq : DataAcquisitionUnit {
            :>> samplingRate = 1.0;
            :>> resolutionBits = 24;
        }

        part control : ControlUnit {
            :>> probeSpacing = 1.0e-3;
            :>> correctionFactor = 4.532;
            :>> temperatureCoefficient = 3.93e-3;
        }

        // Current path: source -> ammeter -> outer probe -> sample -> outer probe -> return
        connect voltageSource.currentOut to currentMeter.currentIn;
        connect currentMeter.currentOut to probe.currentIn;
        connect probe.currentOut to voltageSource.currentReturn;

        // Voltage sense path: inner probes -> voltmeter
        connect probe.senseVoltage to voltmeter.voltageIn;

        // Data acquisition paths
        connect voltmeter.reading to dataAcq.voltageIn;
        connect currentMeter.reading to dataAcq.currentIn;
        connect temperatureController.reading to dataAcq.temperatureIn;
        connect dataAcq.rawDataOut to control.rawDataIn;

        // Control paths
        control.tempCommandOut to temperatureController.command;
        connect control.sourceEnableOut to voltageSource.enableIn;
        connect control.tempEnableOut to temperatureController.enable;

        exhibit state : MeasurementStateMachine;
    }

    // ================================================================
    // Requirements
    // ================================================================
    requirement MeasureResistivity {
        subject : ResistivityMeasurementSystem;
        doc { The system shall measure the electrical resistivity of material samples using the four-point probe technique with high accuracy. }
    }

    requirement MeasureConductivity {
        subject : ResistivityMeasurementSystem;
        doc { The system shall calculate the electrical conductivity from the measured resistivity values. }
    }

    requirement EliminateContactResistance {
        subject : ResistivityMeasurementSystem;
        doc { The four-point probe configuration shall eliminate measurement errors caused by probe contact resistance by sourcing current through outer probes and sensing voltage at inner probes. }
    }

    requirement MaintainTemperatureStability {
        subject : ResistivityMeasurementSystem;
        doc { The temperature controller shall maintain the sample at the target temperature within the specified stability tolerance during measurement. }
    }

    requirement CompensateTemperatureEffect {
        subject : ResistivityMeasurementSystem;
        doc { The control unit shall compensate the measured resistivity and conductivity values for the effect of temperature on material electrical properties. }
    }

    requirement AutomatedOperation {
        subject : ResistivityMeasurementSystem;
        doc { The system shall follow an automated operational sequence: calibrate, stabilize temperature, measure, process data, report results, and return to idle state. }
    }

    requirement HighPrecisionMeasurement {
        subject : ResistivityMeasurementSystem;
        doc { The system shall provide high-precision measurements suitable for applications in material science, semiconductor research, and quality control. }
    }
}
