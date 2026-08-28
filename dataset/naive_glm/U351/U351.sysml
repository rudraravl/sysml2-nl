package PerineometerSystem {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---------- Value Types with Units ----------
    value def PressureValue :> Real {
        unit "Pa";
        attribute min : PressureValue = 0.0;
        attribute max : PressureValue = 20000.0;
    }

    value def DurationValue :> Real {
        unit "s";
    }

    value def FrequencyValue :> Real {
        unit "Hz";
    }

    value def VolumeValue :> Real {
        unit "mL";
    }

    value def StrengthIndex :> Real {
        unit "1";
        attribute min : StrengthIndex = 0.0;
        attribute max : StrengthIndex = 100.0;
    }

    value def SignalAmplitude :> Real {
        unit "V";
    }

    // ---------- Enumerations ----------
    enum def MeasurementMode {
        quick;
        extended;
        endurance;
    }

    enum def CommandType {
        start;
        stop;
        calibrate;
        selectMode;
    }

    enum def SessionStatus {
        inactive;
        active;
        paused;
        complete;
    }

    // ---------- Item Types ----------
    item def RawPressureSignal {
        attribute sampleRate : FrequencyValue;
        attribute samples : PressureValue[0..*] ordered;
        attribute timestampStart : DateTime;
        attribute channel : String;
    }

    item def ProcessedSignal {
        attribute filteredSamples : PressureValue[0..*] ordered;
        attribute baseline : PressureValue;
        attribute noiseFloor : PressureValue;
    }

    item def MeasurementResult {
        attribute strengthIndex : StrengthIndex;
        attribute peakPressure : PressureValue;
        attribute contractionDuration : DurationValue;
        attribute averagePressure : PressureValue;
        attribute timestamp : DateTime;
        attribute mode : MeasurementMode;
    }

    item def DisplayData {
        attribute result : MeasurementResult;
        attribute mode : MeasurementMode;
        attribute sessionLabel : String;
        attribute realTimePressure : PressureValue;
    }

    item def ControlCommand {
        attribute commandType : CommandType;
        attribute mode : MeasurementMode;
        attribute issuedAt : DateTime;
    }

    item def CalibrationParameters {
        attribute zeroOffset : PressureValue;
        attribute gainFactor : Real;
        attribute calibrationTime : DurationValue;
    }

    // ---------- Port Definitions ----------
    port def PressureSignalOut {
        out item signal : RawPressureSignal;
    }

    port def PressureSignalIn {
        in item signal : RawPressureSignal;
    }

    port def ProcessedSignalOut {
        out item signal : ProcessedSignal;
    }

    port def ProcessedSignalIn {
        in item signal : ProcessedSignal;
    }

    port def ResultOut {
        out item result : MeasurementResult;
    }

    port def ResultIn {
        in item result : MeasurementResult;
    }

    port def DisplayDataOut {
        out item data : DisplayData;
    }

    port def DisplayDataIn {
        in item data : DisplayData;
    }

    port def CommandOut {
        out item command : ControlCommand;
    }

    port def CommandIn {
        in item command : ControlCommand;
    }

    // ---------- Actions ----------
    action def SensePressure {
        out item rawSignal : RawPressureSignal;
        attribute samplingInterval : DurationValue;
    }

    action def FilterSignal {
        in item rawSignal : RawPressureSignal;
        out item processedSignal : ProcessedSignal;
        attribute cutoffFrequency : FrequencyValue;
    }

    action def AnalyzeSignal {
        in item processedSignal : ProcessedSignal;
        out item result : MeasurementResult;
        attribute mode : MeasurementMode;
    }

    action def CalibrateSensor {
        out item params : CalibrationParameters;
        attribute warmupDuration : DurationValue;
    }

    action def RenderDisplay {
        in item data : DisplayData;
    }

    action def IssueCommand {
        out item command : ControlCommand;
    }

    // ---------- Parts ----------
    part def PressureSensor {
        port pressureOut : PressureSignalOut;
        attribute sensitivity : PressureValue = 1.0;
        attribute offset : PressureValue = 0.0;
        attribute operatingRange : PressureValue = 20000.0;
        attribute accuracy : PressureValue = 50.0;
        attribute isCalibrated : Boolean = false;

        action sense : SensePressure {
            out rawSignal;
        }

        perform action sense;
    }

    part def InflatableProbe {
        part sensor : PressureSensor;
        attribute inflationVolume : VolumeValue = 50.0;
        attribute maxInflationVolume : VolumeValue = 100.0;
        attribute material : String = "MedicalGradeSilicone";
        port pressureOut : PressureSignalOut;

        connection sensorSignalFlow = sensor.pressureOut to pressureOut;

        action inflate {
            in targetVolume : VolumeValue;
        }
    }

    part def ProcessingUnit {
        port pressureIn : PressureSignalIn;
        port processedOut : ProcessedSignalOut;
        port resultOut : ResultOut;
        port cmdIn : CommandIn;
        attribute filterCutoff : FrequencyValue = 10.0;
        attribute analysisWindow : DurationValue = 5.0;
        attribute currentMode : MeasurementMode = MeasurementMode::quick;
        attribute calibrationParams : CalibrationParameters;

        action filter : FilterSignal {
            in rawSignal;
            out processedSignal;
        }

        action analyze : AnalyzeSignal {
            in processedSignal;
            out result;
            attribute mode = currentMode;
        }

        perform action filter;
        perform action analyze;

        flow from pressureIn.signal to filter.rawSignal;
        flow from filter.processedSignal to processedOut.signal;
        flow from filter.processedSignal to analyze.processedSignal;
        flow from analyze.result to resultOut.result;
    }

    part def DisplayUnit {
        port dataIn : DisplayDataIn;
        port resultIn : ResultIn;
        attribute screenType : String = "LCD";
        attribute resolutionWidth : Integer = 480;
        attribute resolutionHeight : Integer = 320;
        attribute backlightEnabled : Boolean = true;
        attribute lastDisplayed : DisplayData;

        action render : RenderDisplay {
            in data;
        }

        perform action render;

        flow from dataIn.data to render.data;
        flow from resultIn.result to render.data.result;
    }

    part def ControlUnit {
        port cmdOut : CommandOut;
        attribute selectedMode : MeasurementMode = MeasurementMode::quick;
        attribute sessionStatus : SessionStatus = SessionStatus::inactive;
        attribute sessionStartTime : DateTime;
        attribute sessionEndTime : DateTime;

        action issueCommand : IssueCommand {
            out command;
        }

        action selectMode {
            in mode : MeasurementMode;
            then assign selectedMode = mode;
        }

        action startSession {
            then assign sessionStatus = SessionStatus::active;
        }

        action stopSession {
            then assign sessionStatus = SessionStatus::complete;
        }

        perform action issueCommand;

        flow from issueCommand.command to cmdOut.command;
    }

    // ---------- Top-Level Perineometer ----------
    part def Perineometer {
        part probe : InflatableProbe;
        part processor : ProcessingUnit;
        part display : DisplayUnit;
        part controller : ControlUnit;

        attribute deviceSerial : String;
        attribute firmwareVersion : String = "1.0.0";
        attribute powerOn : Boolean = false;
        attribute batteryLevel : Real = 100.0;

        // Connections between parts
        connection probeToProcessor : PressureSignalOut = probe.pressureOut to processor.pressureIn;
        connection processorToDisplay : ResultOut = processor.resultOut to display.resultIn;
        connection controllerToProcessor : CommandOut = controller.cmdOut to processor.cmdIn;

        // ---------- State Machine ----------
        state machine def OperationStateMachine {
            state off {
                entry then assign powerOn = false;
            }
            state idle {
                entry then assign controller.sessionStatus = SessionStatus::inactive;
            }
            state calibrating {
                entry action calibrate : CalibrateSensor {
                    out params;
                }
                do action monitorCalibration;
            }
            state measuring {
                entry then assign controller.sessionStatus = SessionStatus::active;
                do action collectData;
            }
            state analyzing {
                entry action runAnalysis : AnalyzeSignal {
                    in processedSignal;
                    out result;
                }
            }
            state displaying {
                entry action showResults : RenderDisplay {
                    in data;
                }
            }

            transition off_to_idle first off then idle when PowerOn;
            transition idle_to_calibrating first idle then calibrating when StartCalibration;
            transition calibrating_to_measuring first calibrating then measuring when CalibrationComplete;
            transition measuring_to_analyzing first measuring then analyzing when MeasurementComplete;
            transition analyzing_to_displaying first analyzing then displaying when AnalysisComplete;
            transition displaying_to_idle first displaying then idle when DisplayComplete;
            transition any_to_off first idle then off when PowerOff;
        }

        exhibit state machine OperationStateMachine;

        // ---------- Requirements Satisfaction ----------
        satisfy req MeasurePelvicFloorStrength by probe;
        satisfy req ProvideRealTimeBiofeedback by display;
        satisfy req SupportMultipleMeasurementModes by controller;
    }

    // ---------- Requirements ----------
    requirement def MeasurePelvicFloorStrength {
        subject device : Perineometer;
        objective {
            doc "The device shall measure intravaginal pressure to assess pelvic floor muscle strength."
        }
        attribute pressureRange : PressureValue = 20000.0;
        attribute accuracy : PressureValue = 50.0;
        require device.probe.sensor.operatingRange >= pressureRange;
        require device.probe.sensor.accuracy <= accuracy;
    }

    requirement def ProvideRealTimeBiofeedback {
        subject device : Perineometer;
        objective {
            doc "The device shall provide real-time visual feedback of pelvic floor muscle activity."
        }
        attribute maxDisplayLatency : DurationValue = 0.5;
        require device.display.backlightEnabled == true;
    }

    requirement def SupportMultipleMeasurementModes {
        subject device : Perineometer;
        objective {
            doc "The device shall support quick, extended, and endurance measurement modes."
        }
        require device.controller.selectedMode in {MeasurementMode::quick, MeasurementMode::extended, MeasurementMode::endurance};
    }

    requirement def CalculatePerformanceMetrics {
        subject device : Perineometer;
        objective {
            doc "The device shall calculate strength index, peak pressure, and contraction duration."
        }
        require device.processor.resultOut.result.strengthIndex >= 0.0;
        require device.processor.resultOut.result.strengthIndex <= 100.0;
        require device.processor.resultOut.result.peakPressure >= 0.0;
        require device.processor.resultOut.result.contractionDuration >= 0.0;
    }

    requirement def FollowOperationalSequence {
        subject device : Perineometer;
        objective {
            doc "The device shall follow the sequence: idle, calibrating, measuring, analyzing, displaying."
        }
        require device.powerOn == true;
    }

    // ---------- Top-level requirement aggregation ----------
    requirement PerineometerRequirements {
        subject device : Perineometer;
        satisfy req MeasurePelvicFloorStrength;
        satisfy req ProvideRealTimeBiofeedback;
        satisfy req SupportMultipleMeasurementModes;
        satisfy req CalculatePerformanceMetrics;
        satisfy req FollowOperationalSequence;
    }
}
