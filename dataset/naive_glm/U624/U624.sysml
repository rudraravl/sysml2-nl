package CapacitanceProbeSystem {
    import ScalarValues::*;

    value type CapacitanceValue :> Real { unit 'F'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type ThicknessValue :> Real { unit 'm'; }
    value type DielectricConstant :> Real { unit '1'; }
    value type DistanceValue :> Real { unit 'm'; }
    value type PowerValue :> Real { unit 'W'; }
    value type GainValue :> Real { unit '1'; }
    value type ConfidenceValue :> Real { unit '1'; }

    item def ElectricalSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : VoltageValue;
        attribute phase : Real;
    }

    item def RawCapacitanceReading {
        attribute capacitance : CapacitanceValue;
        attribute timestamp : Real;
        attribute valid : Boolean;
        attribute noiseLevel : Real;
    }

    item def ProcessedData {
        attribute thickness : ThicknessValue;
        attribute dielectricConstant : DielectricConstant;
        attribute proximity : DistanceValue;
        attribute confidence : ConfidenceValue;
        attribute measurementId : Integer;
    }

    item def CalibrationParameters {
        attribute offset : CapacitanceValue;
        attribute scale : Real;
        attribute referenceThickness : ThicknessValue;
        attribute referenceDielectric : DielectricConstant;
        attribute lastCalibrationTime : Real;
    }

    item def TargetMaterial {
        attribute nominalThickness : ThicknessValue;
        attribute nominalDielectric : DielectricConstant;
        attribute position : DistanceValue;
    }

    port def ACSignalPort {
        out signal : ElectricalSignal;
    }

    port def PowerPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
    }

    port def CapacitanceDataPort {
        out reading : RawCapacitanceReading;
    }

    port def ProcessedDataPort {
        out data : ProcessedData;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    enumeration def SystemState {
        off;
        initializing;
        standby;
        active;
        recalibrating;
    }

    enumeration def MeasurementStatus {
        valid;
        invalid;
        pending;
    }

    enumeration def FaultCode {
        none;
        signalLoss;
        outOfRange;
        oscillatorDrift;
        calibrationError;
    }

    part def ProbeSensor {
        port acIn : ~ACSignalPort;
        port capOut : CapacitanceDataPort;
        port control : ControlPort;

        attribute generatedField : Boolean = false;
        attribute targetDistance : DistanceValue;
        attribute measuredCapacitance : CapacitanceValue;
        attribute electrodeArea : Real = 1.0e-4;
        attribute permittivityFreeSpace : Real = 8.854e-12;

        action def MeasureCapacitance {
            in excitation : ElectricalSignal;
            in target : TargetMaterial;
            out reading : RawCapacitanceReading;
        }

        action def GenerateField {
            in signal : ElectricalSignal;
            out fieldActive : Boolean;
        }

        action measure : MeasureCapacitance;
        action generateField : GenerateField;
    }

    part def OscillatorCircuit {
        port powerIn : ~PowerPort;
        port acOut : ACSignalPort;
        port control : ControlPort;

        attribute outputFrequency : FrequencyValue = 1000000.0;
        attribute outputAmplitude : VoltageValue = 5.0;
        attribute stability : Real = 0.99;
        attribute warmupTime : Real = 2.0;
        attribute crystalTolerance : Real = 5.0e-6;

        action def GenerateSignal {
            in supplyVoltage : VoltageValue;
            in supplyCurrent : CurrentValue;
            out signal : ElectricalSignal;
        }

        action def StabilizeFrequency {
            in targetFreq : FrequencyValue;
            out actualFreq : FrequencyValue;
        }

        action generate : GenerateSignal;
        action stabilize : StabilizeFrequency;
    }

    part def PowerSupplyUnit {
        port powerOut : PowerPort;
        port control : ControlPort;

        attribute outputVoltage : VoltageValue = 12.0;
        attribute outputCurrent : CurrentValue = 2.0;
        attribute maxPower : PowerValue = 24.0;
        attribute efficiency : Real = 0.85;
        attribute rippleVoltage : VoltageValue = 0.05;
        attribute lineRegulation : Real = 0.01;

        action def SupplyPower {
            in inputAC : VoltageValue;
            out voltage : VoltageValue;
            out current : CurrentValue;
        }

        action def RegulateOutput {
            in rawVoltage : VoltageValue;
            out regulatedVoltage : VoltageValue;
        }

        action supply : SupplyPower;
        action regulate : RegulateOutput;
    }

    part def SignalProcessor {
        port capIn : ~CapacitanceDataPort;
        port dataOut : ProcessedDataPort;
        port control : ControlPort;

        attribute filterGain : GainValue = 10.0;
        attribute calibration : CalibrationParameters;
        attribute status : MeasurementStatus = MeasurementStatus::pending;
        attribute activeFault : FaultCode = FaultCode::none;
        attribute processingLatency : Real = 0.005;
        attribute filterCutoff : FrequencyValue = 10000.0;

        action def FilterSignal {
            in reading : RawCapacitanceReading;
            in cutoff : FrequencyValue;
            out filtered : RawCapacitanceReading;
        }

        action def ApplyGain {
            in filtered : RawCapacitanceReading;
            in gain : GainValue;
            out amplified : RawCapacitanceReading;
        }

        action def ValidateReading {
            in reading : RawCapacitanceReading;
            out status : MeasurementStatus;
            out fault : FaultCode;
        }

        action def CalculateResults {
            in reading : RawCapacitanceReading;
            in calibration : CalibrationParameters;
            out data : ProcessedData;
        }

        action def Recalibrate {
            in referenceReading : RawCapacitanceReading;
            out updatedCalibration : CalibrationParameters;
        }

        action def ProcessData {
            in reading : RawCapacitanceReading;
            in calibration : CalibrationParameters;
            out data : ProcessedData;
            out status : MeasurementStatus;

            action filter : FilterSignal;
            action amplify : ApplyGain;
            action validate : ValidateReading;
            action calculate : CalculateResults;

            succession first filter then amplify;
            succession first amplify then validate;
            succession first validate then calculate;
        }

        action process : ProcessData;
        action recalibrate : Recalibrate;
    }

    part def DisplayInterface {
        port dataIn : ~ProcessedDataPort;
        port control : ControlPort;

        attribute brightness : Real = 0.8;
        attribute units : String = "metric";
        attribute refreshRate : FrequencyValue = 5.0;
        attribute lastDisplayed : ProcessedData;

        action def DisplayResults {
            in data : ProcessedData;
        }

        action def UpdateDisplay {
            in data : ProcessedData;
            out rendered : Boolean;
        }

        action display : DisplayResults;
        action update : UpdateDisplay;
    }

    part def CapacitanceProbeSystem {
        part powerSupply : PowerSupplyUnit;
        part oscillator : OscillatorCircuit;
        part probe : ProbeSensor;
        part processor : SignalProcessor;
        part display : DisplayInterface;

        attribute systemState : SystemState = SystemState::off;
        attribute targetMaterial : TargetMaterial;
        attribute measurementCycleCount : Integer = 0;
        attribute maxCyclesBeforeCalibration : Integer = 1000;

        attribute powerOn : Boolean = false;
        attribute powerOff : Boolean = false;
        attribute startMeasurement : Boolean = false;
        attribute stopMeasurement : Boolean = false;
        attribute readingInvalid : Boolean = false;
        attribute calibrationRequested : Boolean = false;

        connection powerToOscillator connect powerSupply.powerOut to oscillator.powerIn;
        connection oscToProbe connect oscillator.acOut to probe.acIn;
        connection probeToProcessor connect probe.capOut to processor.capIn;
        connection processorToDisplay connect processor.dataOut to display.dataIn;

        action powerOffAction;
        action initializeSystem;
        action runDiagnostics;
        action enterStandby;
        action startContinuousMeasurement;
        action continuousMeasurement;
        action performRecalibration;
        action returnToActive;

        state machine SystemStates {
            state off {
                entry powerOffAction;
            }

            state initializing {
                entry initializeSystem;
                do runDiagnostics;
            }

            state standby {
                entry enterStandby;
            }

            state active {
                entry startContinuousMeasurement;
                do continuousMeasurement;
            }

            state recalibrating {
                entry performRecalibration;
            }

            transition t_power_on
                first off
                if powerOn
                then initializing;

            transition t_init_complete
                first initializing
                then standby;

            transition t_start_meas
                first standby
                if startMeasurement
                then active;

            transition t_reading_invalid
                first active
                if readingInvalid
                then recalibrating;

            transition t_recal_complete
                first recalibrating
                then active;

            transition t_stop_meas
                first active
                if stopMeasurement
                then standby;

            transition t_standby_power_off
                first standby
                if powerOff
                then off;

            transition t_active_power_off
                first active
                if powerOff
                then off;

            transition t_recal_power_off
                first recalibrating
                if powerOff
                then off;

            transition t_init_power_off
                first initializing
                if powerOff
                then off;
        }
    }

    requirement def MeasurementRequirement {
        doc /* Base requirement for capacitance probe measurement system. */
        attribute targetAccuracy : Real;
        attribute measurementRange : CapacitanceValue;
    }

    requirement MeasureThickness :> MeasurementRequirement {
        doc /* The system shall measure material thickness without physical contact. */
        attribute targetAccuracy = 0.01;
        attribute measurementRange = 0.1e-12;
    }

    requirement MeasureDielectric :> MeasurementRequirement {
        doc /* The system shall determine dielectric properties of target material. */
        attribute targetAccuracy = 0.05;
    }

    requirement MeasureProximity :> MeasurementRequirement {
        doc /* The system shall determine proximity of target material to sensor. */
        attribute targetAccuracy = 0.001;
    }

    requirement NonContactOperation :> MeasurementRequirement {
        doc /* The system shall operate without making physical contact with target material. */
    }

    requirement ContinuousMeasurement :> MeasurementRequirement {
        doc /* The system shall perform continuous measurement cycles during active state. */
        attribute minCycleRate : FrequencyValue = 100.0;
    }

    requirement AutoRecalibration :> MeasurementRequirement {
        doc /* The system shall trigger recalibration when a reading is deemed invalid. */
        attribute maxRecalibrationTime : Real = 5.0;
    }

    requirement PowerStability :> MeasurementRequirement {
        doc /* The power supply shall provide stable voltage and current to operate oscillator and processing electronics. */
        attribute requiredVoltage : VoltageValue = 12.0;
        attribute requiredCurrent : CurrentValue = 2.0;
        attribute maxRipple : VoltageValue = 0.05;
    }

    requirement OscillatorStability :> MeasurementRequirement {
        doc /* The oscillator shall produce a stable high-frequency AC signal to energize the probe. */
        attribute minFrequency : FrequencyValue = 1000000.0;
        attribute minStability : Real = 0.95;
    }

    requirement SignalProcessing :> MeasurementRequirement {
        doc /* The signal processor shall filter, amplify, and convert raw capacitance into processed data. */
        attribute requiredGain : GainValue = 10.0;
        attribute maxLatency : Real = 0.01;
    }

    requirement DisplayOutput :> MeasurementRequirement {
        doc /* The system shall display processed measurement results to an operator. */
        attribute minRefreshRate : FrequencyValue = 5.0;
    }

    requirement SystemStates :> MeasurementRequirement {
        doc /* The system shall operate through states: off, initializing, standby, active, and recalibrating. */
    }

    part capSystem : CapacitanceProbeSystem {
        satisfy MeasureThickness by processor;
        satisfy MeasureDielectric by processor;
        satisfy MeasureProximity by processor;
        satisfy NonContactOperation by probe;
        satisfy ContinuousMeasurement by capSystem;
        satisfy AutoRecalibration by processor;
        satisfy PowerStability by powerSupply;
        satisfy OscillatorStability by oscillator;
        satisfy SignalProcessing by processor;
        satisfy DisplayOutput by display;
        satisfy SystemStates by capSystem;
    }
}
