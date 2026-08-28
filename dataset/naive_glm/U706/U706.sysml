package HeartbeatSensingUnitModel {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type BPM :> Real {
        attribute unit : String = "beats per minute";
    }

    value type Voltage :> Real {
        attribute unit : String = "V";
    }

    value type TimeSeconds :> Real {
        attribute unit : String = "s";
    }

    value type Frequency :> Real {
        attribute unit : String = "Hz";
    }

    value type Current :> Real {
        attribute unit : String = "A";
    }

    value type Dimensionless :> Real;

    // ===== Item Definitions =====
    item def RawPulseSignal {
        attribute amplitude : Voltage;
        attribute sampleRate : Frequency;
        attribute timestamp : TimeSeconds;
    }

    item def CleanedSignal {
        attribute amplitude : Voltage;
        attribute noiseLevel : Dimensionless;
        attribute motionArtifactRemoved : Boolean;
    }

    item def HeartRateMeasurement {
        attribute heartRate : BPM;
        attribute signalQuality : Dimensionless;
        attribute isValid : Boolean;
        attribute timestamp : TimeSeconds;
    }

    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def MeasurementCommand {
        attribute commandType : String;
        attribute timestamp : TimeSeconds;
    }

    item def StatusReport {
        attribute state : String;
        attribute errorCode : Integer;
        attribute timestamp : TimeSeconds;
    }

    // ===== Part Definitions =====
    part def OpticalPPGSensor {
        attribute wavelength : Real = 530;
        attribute ledIntensity : Real = 1.0;
        attribute sampleRate : Frequency = 100;
        attribute isActivated : Boolean = false;

        port powerIn : PowerSignal;
        port activateIn : MeasurementCommand;
        port rawSignalOut : ~ RawPulseSignal;

        action def SensePulse {
            in power : PowerSignal;
            in activate : MeasurementCommand;
            out rawSignal : RawPulseSignal;
        }

        perform action sensePulse : SensePulse;
    }

    part def SignalProcessor {
        attribute filterCutoff : Frequency = 5.0;
        attribute motionArtifactThreshold : Dimensionless = 0.1;
        attribute minValidQuality : Dimensionless = 0.7;
        attribute isProcessing : Boolean = false;

        port powerIn : PowerSignal;
        port rawSignalIn : RawPulseSignal;
        port cleanSignalOut : ~ CleanedSignal;
        port heartRateOut : ~ HeartRateMeasurement;

        action def FilterSignal {
            in raw : RawPulseSignal;
            out clean : CleanedSignal;
        }

        action def DetectHeartbeats {
            in clean : CleanedSignal;
            out beatCount : Integer;
            out beatTimestamps : TimeSeconds[0..*];
        }

        action def CalculateHeartRate {
            in beatCount : Integer;
            in timeWindow : TimeSeconds;
            out heartRate : BPM;
        }

        action def EvaluateSignalQuality {
            in clean : CleanedSignal;
            out quality : Dimensionless;
            out isValid : Boolean;
        }

        action def ProcessSignal {
            in raw : RawPulseSignal;
            out hr : HeartRateMeasurement;

            perform action filter : FilterSignal;
            perform action detect : DetectHeartbeats;
            perform action calculate : CalculateHeartRate;
            perform action evaluate : EvaluateSignalQuality;
        }

        perform action processSignal : ProcessSignal;
    }

    part def DataBuffer {
        attribute capacity : Integer = 10;
        attribute count : Integer = 0;

        port measurementIn : HeartRateMeasurement;
        port measurementOut : ~ HeartRateMeasurement;

        action def StoreMeasurement {
            in measurement : HeartRateMeasurement;
        }

        action def RetrieveMeasurement {
            out measurement : HeartRateMeasurement;
        }

        perform action store : StoreMeasurement;
        perform action retrieve : RetrieveMeasurement;
    }

    // ===== State Machine Definition =====
    state def HeartbeatUnitLifecycle {
        state powerOnInitializing {
            entry action {
                assign self.currentState = "powerOnInitializing";
            }
            transition to ready
                when self.initializationComplete;
        }

        state ready {
            entry action {
                assign self.currentState = "ready";
            }
            transition to measuring
                when self.measureCommandReceived;
        }

        state measuring {
            entry action {
                assign self.currentState = "measuring";
            }
            transition to transmitting
                when self.measurementComplete;
            transition to fault
                when self.measurementError;
        }

        state transmitting {
            entry action {
                assign self.currentState = "transmitting";
            }
            transition to ready
                when self.transmissionComplete;
        }

        state fault {
            entry action {
                assign self.currentState = "fault";
            }
            transition to ready
                when self.resetCommandReceived;
        }
    }

    // ===== Top-Level Part Definition =====
    part def HeartbeatSensingUnit {
        attribute measuredHeartRate : BPM;
        attribute trueHeartRate : BPM;
        attribute updateTime : TimeSeconds;
        attribute currentState : String;
        attribute initializationComplete : Boolean = false;
        attribute measureCommandReceived : Boolean = false;
        attribute measurementComplete : Boolean = false;
        attribute measurementError : Boolean = false;
        attribute transmissionComplete : Boolean = false;
        attribute resetCommandReceived : Boolean = false;
        attribute signalQuality : Dimensionless;
        attribute isValid : Boolean;
        attribute errorCode : Integer = 0;

        port powerInput : PowerSignal;
        port commandInput : MeasurementCommand;
        port heartRateOutput : ~ HeartRateMeasurement;
        port statusOutput : ~ StatusReport;

        part ppgSensor : OpticalPPGSensor;
        part processor : SignalProcessor;
        part dataBuffer : DataBuffer;

        connection powerToPPG : PowerSignal
            connect powerInput to ppgSensor.powerIn;

        connection powerToProcessor : PowerSignal
            connect powerInput to processor.powerIn;

        connection commandToPPG : MeasurementCommand
            connect commandInput to ppgSensor.activateIn;

        connection rawSignalFlow : RawPulseSignal
            connect ppgSensor.rawSignalOut to processor.rawSignalIn;

        connection processedHeartRate : HeartRateMeasurement
            connect processor.heartRateOut to dataBuffer.measurementIn;

        connection bufferedOutput : HeartRateMeasurement
            connect dataBuffer.measurementOut to heartRateOutput;

        state lifecycle : HeartbeatUnitLifecycle;
    }

    // ===== Requirements =====
    requirement def HeartRateRangeRequirement {
        doc /* The unit shall measure heart rates between 40 and 200 BPM. */
        subject unit : HeartbeatSensingUnit;
        constraint { unit.measuredHeartRate >= 40 and unit.measuredHeartRate <= 200 }
    }

    requirement def HeartRateAccuracyRequirement {
        doc /* The unit shall measure heart rate with an accuracy of plus or minus 2 BPM. */
        subject unit : HeartbeatSensingUnit;
        constraint { unit.measuredHeartRate - unit.trueHeartRate <= 2 and unit.trueHeartRate - unit.measuredHeartRate <= 2 }
    }

    requirement def UpdateTimeRequirement {
        doc /* The unit shall provide an updated reading within 2 seconds. */
        subject unit : HeartbeatSensingUnit;
        constraint { unit.updateTime <= 2.0 }
    }

    requirement def SignalQualityRequirement {
        doc /* The unit shall evaluate signal quality and mark measurements as valid or invalid. */
        subject unit : HeartbeatSensingUnit;
        constraint { unit.signalQuality >= 0.7 implies unit.isValid == true }
    }

    requirement def LifecycleRequirement {
        doc /* The unit shall follow the lifecycle: power on, ready, measuring, transmitting, fault. */
        subject unit : HeartbeatSensingUnit;
        constraint { unit.currentState in {"powerOnInitializing", "ready", "measuring", "transmitting", "fault"} }
    }

    // ===== Part Usage and Satisfaction =====
    part sensingUnit : HeartbeatSensingUnit;

    satisfy HeartRateRangeRequirement by sensingUnit;
    satisfy HeartRateAccuracyRequirement by sensingUnit;
    satisfy UpdateTimeRequirement by sensingUnit;
    satisfy SignalQualityRequirement by sensingUnit;
    satisfy LifecycleRequirement by sensingUnit;
}
