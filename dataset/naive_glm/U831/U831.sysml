package PotentiometricSensingUnit {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQElectricity::*;
    import ISQEnergy::*;

    // ---- Value Types ----

    value type DisplacementValue :> Real {
        unit :> mm;
    }

    value type VoltageValue :> Real {
        unit :> V;
    }

    value type CurrentValue :> Real {
        unit :> A;
    }

    value type ResistanceValue :> Real {
        unit :> Ohm;
    }

    value type FrequencyValue :> Real {
        unit :> Hz;
    }

    value type TemperatureValue :> Real {
        unit :> degC;
    }

    value type DigitalCode :> Integer {
        min = 0;
        max = 4095;
    }

    value type PositionPercent :> Real {
        min = 0.0;
        max = 100.0;
        unit :> percent;
    }

    value type TimeValue :> Real {
        unit :> s;
    }

    // ---- Item Types ----

    item def MechanicalDisplacement {
        attr displacement : DisplacementValue;
    }

    item def RawAnalogSignal {
        attr voltage : VoltageValue;
    }

    item def ConditionedAnalogSignal {
        attr voltage : VoltageValue;
        attr noiseLevel : VoltageValue;
    }

    item def DigitalSample {
        attr code : DigitalCode;
        attr timestamp : TimeValue;
    }

    item def CalibratedPosition {
        attr position : PositionPercent;
        attr valid : Boolean;
    }

    item def CalibrationData {
        attr zeroOffset : DigitalCode;
        attr scaleFactor : Real;
        attr tempCompensation : Real;
    }

    item def CommandSignal {
        attr command : String;
    }

    item def FaultReport {
        attr faultCode : Integer;
        attr description : String;
    }

    // ---- Port Definitions ----

    port def MechanicalInputPort {
        out displacement : MechanicalDisplacement;
    }

    port def RawAnalogPort {
        out signal : RawAnalogSignal;
    }

    port def ConditionedAnalogPort {
        out signal : ConditionedAnalogSignal;
    }

    port def DigitalDataPort {
        out sample : DigitalSample;
    }

    port def PositionOutputPort {
        out position : CalibratedPosition;
    }

    port def CommandPort {
        in command : CommandSignal;
    }

    port def DiagnosticPort {
        out fault : FaultReport;
    }

    // ---- Requirements ----

    requirement def MeasurementAccuracyRequirement {
        doc "The system shall measure position with high accuracy.";
        constraint { self.accuracy <= 0.1 [percent] }
        attribute accuracy : PositionPercent;
    }

    requirement def ResponseTimeRequirement {
        doc "The system shall respond to displacement changes within specified time.";
        constraint { self.responseTime <= 1.0e-3 [s] }
        attribute responseTime : TimeValue;
    }

    requirement def OperatingTemperatureRequirement {
        doc "The system shall operate reliably across a wide temperature range.";
        constraint { self.minTemp >= -40.0 [degC] }
        constraint { self.maxTemp <= 125.0 [degC] }
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
    }

    requirement def SamplingRateRequirement {
        doc "The ADC shall sample at high frequency.";
        constraint { self.samplingRate >= 1000.0 [Hz] }
        attribute samplingRate : FrequencyValue;
    }

    requirement def LifecycleRequirement {
        doc "The system shall implement defined operational states.";
        constraint { self.states.includes("initialization") }
        constraint { self.states.includes("idle") }
        constraint { self.states.includes("measuring") }
        constraint { self.states.includes("fault") }
        attribute states : String[0..*];
    }

    // ---- Potentiometric Sensor ----

    part def PotentiometricSensor {
        attribute supplyVoltage : VoltageValue = 5.0 [V];
        attribute trackResistance : ResistanceValue = 10000.0 [Ohm];
        attribute wiperPosition : PositionPercent = 0.0;
        attribute operatingTempRange : TemperatureValue[2] = (-40.0 [degC], 125.0 [degC]);

        port mechanicalInput : MechanicalInputPort;
        port rawOutput : RawAnalogPort;

        action def TranslateDisplacement {
            in displacement : MechanicalDisplacement;
            out signal : RawAnalogSignal;
        }

        action translate : TranslateDisplacement {
            in displacement = mechanicalInput.displacement;
            out signal to rawOutput.signal;
        }

        satisfy MeasurementAccuracyRequirement by sensorAccuracy;
        attribute sensorAccuracy : PositionPercent = 0.05 [percent];
    }

    // ---- Signal Conditioner ----

    part def SignalConditioner {
        attribute gain : Real = 2.0;
        attribute cutoffFrequency : FrequencyValue = 500.0 [Hz];
        attribute inputImpedance : ResistanceValue = 100000.0 [Ohm];
        attribute outputImpedance : ResistanceValue = 50.0 [Ohm];

        port analogInput : RawAnalogPort;
        port conditionedOutput : ConditionedAnalogPort;

        action def Amplify {
            in raw : RawAnalogSignal;
            out amplified : RawAnalogSignal;
        }

        action def LowPassFilter {
            in noisy : RawAnalogSignal;
            out clean : ConditionedAnalogSignal;
        }

        action amplify : Amplify {
            in raw = analogInput.signal;
        }

        action filter : LowPassFilter {
            in noisy = amplify.amplified;
            out clean to conditionedOutput.signal;
        }
    }

    // ---- Analog-to-Digital Converter ----

    part def AnalogDigitalConverter {
        attribute resolution : Integer = 12;
        attribute samplingRate : FrequencyValue = 2000.0 [Hz];
        attribute referenceVoltage : VoltageValue = 5.0 [V];
        attribute lsbVoltage : VoltageValue = referenceVoltage / (2^resolution);

        port analogInput : ConditionedAnalogPort;
        port digitalOutput : DigitalDataPort;

        action def SampleAndConvert {
            in analog : ConditionedAnalogSignal;
            out digital : DigitalSample;
        }

        action convert : SampleAndConvert {
            in analog = analogInput.signal;
            out digital to digitalOutput.sample;
        }

        satisfy SamplingRateRequirement by adcSamplingRate;
        attribute adcSamplingRate : FrequencyValue = samplingRate;
    }

    // ---- Microcontroller ----

    part def Microcontroller {
        attribute clockFrequency : FrequencyValue = 16000000.0 [Hz];
        attribute calibration : CalibrationData;
        attribute processingLatency : TimeValue = 0.0002 [s];

        port digitalInput : DigitalDataPort;
        port commandInput : CommandPort;
        port positionOutput : PositionOutputPort;
        port diagnosticOutput : DiagnosticPort;

        action def LoadCalibration {
            out data : CalibrationData;
        }

        action def ApplyCalibration {
            in raw : DigitalSample;
            in cal : CalibrationData;
            out position : CalibratedPosition;
        }

        action loadCal : LoadCalibration {
            out data = calibration;
        }

        action process : ApplyCalibration {
            in raw = digitalInput.sample;
            in cal = calibration;
            out position to positionOutput.position;
        }
    }

    // ---- Operational State Machine ----

    state def OperationalLifecycle {
        entry action selfTest {
            // Perform self-test and load calibration
        }

        state initialization {
            entry action initSelfTest;
            do action loadCalibrationData;
            transition to idle
                if (selfTestPassed == true);
        }

        state idle {
            entry action enterLowPower;
            transition to measuring
                if (commandReceived == true);
            transition to fault
                if (errorDetected == true);
        }

        state measuring {
            entry action startSampling;
            do action continuousMeasurement;
            transition to idle
                if (stopCommandReceived == true);
            transition to fault
                if (errorDetected == true);
        }

        state fault {
            entry action reportFault;
            do action holdFaultState;
            transition to initialization
                if (resetCommandReceived == true);
        }

        attribute selfTestPassed : Boolean;
        attribute commandReceived : Boolean;
        attribute stopCommandReceived : Boolean;
        attribute errorDetected : Boolean;
        attribute resetCommandReceived : Boolean;
    }

    // ---- Top-level Potentiometric Sensing Unit ----

    part def PotentiometricSensingSystem {

        attribute systemId : String = "PSU-001";
        attribute firmwareVersion : String = "1.2.0";
        attribute operatingTemperatureRange : TemperatureValue[2] = (-40.0 [degC], 125.0 [degC]);
        attribute responseTime : TimeValue = 0.0005 [s];

        port mechanicalInput : MechanicalInputPort;
        port commandInput : CommandPort;
        port positionOutput : PositionOutputPort;
        port diagnosticOutput : DiagnosticPort;

        part sensor : PotentiometricSensor {
            port mechanicalInput : MechanicalInputPort;
            port rawOutput : RawAnalogPort;
        }

        part conditioner : SignalConditioner {
            port analogInput : RawAnalogPort;
            port conditionedOutput : ConditionedAnalogPort;
        }

        part adc : AnalogDigitalConverter {
            port analogInput : ConditionedAnalogPort;
            port digitalOutput : DigitalDataPort;
        }

        part controller : Microcontroller {
            port digitalInput : DigitalDataPort;
            port commandInput : CommandPort;
            port positionOutput : PositionOutputPort;
            port diagnosticOutput : DiagnosticPort;
        }

        // Internal connections
        connection rawSignalConnection connect sensor.rawOutput to conditioner.analogInput;
        connection conditionedSignalConnection connect conditioner.conditionedOutput to adc.analogInput;
        connection digitalDataConnection connect adc.digitalOutput to controller.digitalInput;

        // External flow bindings
        flow from mechanicalInput.displacement to sensor.mechanicalInput.displacement;
        flow from commandInput.command to controller.commandInput.command;
        flow from controller.positionOutput.position to positionOutput.position;
        flow from controller.diagnosticOutput.fault to diagnosticOutput.fault;

        // Operational lifecycle
        exhibit state lifecycle : OperationalLifecycle;

        // Requirement satisfactions
        satisfy MeasurementAccuracyRequirement by systemAccuracy;
        attribute systemAccuracy : PositionPercent = 0.08 [percent];

        satisfy ResponseTimeRequirement by systemResponseTime;
        attribute systemResponseTime : TimeValue = responseTime;

        satisfy OperatingTemperatureRequirement by tempRange;
        attribute tempRange : TemperatureValue[2] = operatingTemperatureRange;

        satisfy LifecycleRequirement by lifecycleStates;
        attribute lifecycleStates : String[4] = ("initialization", "idle", "measuring", "fault");
    }

}
