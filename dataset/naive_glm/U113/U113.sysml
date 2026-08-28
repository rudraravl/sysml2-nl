package DigitalScoliometer {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQElectromagnetism::*;

    // ---- Value Types ----
    def type def AngleOfTrunkRotation :> Real {
        attribute value : Real;
        attribute unit : String = "degree";
    }

    def type def RawAngle :> Real {
        attribute value : Real;
        attribute unit : String = "degree";
    }

    def type def VertebralLevel :> String;
    def type def PatientPosition :> String;
    def type def SeverityLevel :> String;

    value type def CalibrationOffset :> Real {
        attribute value : Real;
        attribute unit : String = "degree";
    }

    value type def NoiseThreshold :> Real {
        attribute value : Real;
        attribute unit : String = "degree";
    }

    value type def BatteryCharge :> Real {
        attribute value : Real;
        attribute unit : String = "percent";
    }

    value type def Voltage :> Real {
        attribute value : Real;
        attribute unit : String = "volt";
    }

    // ---- Item Types ----
    item def RawAngleMeasurement {
        attribute rawAngle : RawAngle;
        attribute timestamp : DateTime;
    }

    item def ProcessedATR {
        attribute atr : AngleOfTrunkRotation;
        attribute severity : SeverityLevel;
        attribute vertebralLevel : VertebralLevel;
        attribute patientPosition : PatientPosition;
        attribute timestamp : DateTime;
    }

    item def DisplayContent {
        attribute atr : AngleOfTrunkRotation;
        attribute severity : SeverityLevel;
    }

    item def LogRecord {
        attribute atr : AngleOfTrunkRotation;
        attribute severity : SeverityLevel;
        attribute vertebralLevel : VertebralLevel;
        attribute patientPosition : PatientPosition;
        attribute timestamp : DateTime;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute charge : BatteryCharge;
    }

    // ---- Port Definitions ----
    port def RawAnglePort {
        out rawAngle : RawAngleMeasurement;
    }

    port def ProcessedATRPort {
        out processedATR : ProcessedATR;
    }

    port def DisplayPort {
        out displayContent : DisplayContent;
    }

    port def LogPort {
        out logRecord : LogRecord;
    }

    port def PowerPort {
        out power : ElectricalPower;
    }

    // ---- Requirements ----
    requirement def ScoliometerFunctionalRequirement {
        doc /* The digital scoliometer shall measure spinal asymmetry by determining the Angle of Trunk Rotation (ATR) during a forward bend test. */
        subject device : DigitalScoliometerDevice;
        objective {
            assert device.measuredATR.value >= 0.0 and device.measuredATR.value <= 30.0;
        }
    }

    requirement def InclinometerAccuracyRequirement {
        doc /* The inclinometer sensor shall provide raw angle measurements with an accuracy of at least plus or minus 1 degree. */
        subject sensor : InclinometerSensor;
        objective {
            assert sensor.accuracy.value <= 1.0;
        }
    }

    requirement def ProcessorCalibrationRequirement {
        doc /* The signal processor shall apply calibration corrections and noise filtering to produce a precise ATR value. */
        subject processor : SignalProcessor;
        objective {
            assert processor.calibratedATR.value >= 0.0;
        }
    }

    requirement def SeverityClassificationRequirement {
        doc /* The processor shall classify ATR results as normal, monitor, or refer based on clinical thresholds. */
        subject processor : SignalProcessor;
        objective {
            assert processor.severity == "normal" or processor.severity == "monitor" or processor.severity == "refer";
        }
    }

    requirement def DisplayRequirement {
        doc /* The digital display shall show both the final ATR angle and the severity classification. */
        subject display : DigitalDisplay;
        objective {
            assert display.shownATR.value >= 0.0;
            assert display.shownSeverity != "";
        }
    }

    requirement def DataLoggerRequirement {
        doc /* The data logger shall store measurement history including angle, timestamp, vertebral level, and patient position. */
        subject logger : DataLogger;
        objective {
            assert logger.recordCount >= 0;
        }
    }

    requirement def BatteryRequirement {
    doc /* The internal battery shall power the handheld unit for portable clinical use. */
        subject battery : InternalBattery;
        objective {
            assert battery.charge.value >= 0.0 and battery.charge.value <= 100.0;
        }
    }

    // ---- Parts ----

    part def InclinometerSensor {
        attribute accuracy : CalibrationOffset = CalibrationOffset(1.0);
        port out rawAngleOut : RawAnglePort;
        port in powerIn : PowerPort;

        action def takeMeasurement :> Action {
            out raw : RawAngleMeasurement;
        }

        action def senseAngle {
            out sensedAngle : RawAngle;
        }

        perform action sense : senseAngle;
    }

    part def SignalProcessor {
        attribute calibrationOffset : CalibrationOffset = CalibrationOffset(0.5);
        attribute noiseThreshold : NoiseThreshold = NoiseThreshold(0.2);
        attribute severity : SeverityLevel;
        attribute calibratedATR : AngleOfTrunkRotation;

        port in rawAngleIn : RawAnglePort;
        port out processedATROut : ProcessedATRPort;
        port out displayOut : DisplayPort;
        port out logOut : LogPort;
        port in powerIn : PowerPort;

        action def processRawData :> Action {
            in raw : RawAngleMeasurement;
            out processed : ProcessedATR;
        }

        action def applyCalibration {
            in rawAngle : RawAngle;
            out calibrated : AngleOfTrunkRotation;
        }

        action def filterNoise {
            in rawAngle : RawAngle;
            out filtered : RawAngle;
        }

        action def classifySeverity {
            in atr : AngleOfTrunkRotation;
            out severity : SeverityLevel;
        }

        perform action calibrate : applyCalibration;
        perform action filter : filterNoise;
        perform action classify : classifySeverity;
    }

    part def DigitalDisplay {
        attribute shownATR : AngleOfTrunkRotation;
        attribute shownSeverity : SeverityLevel;

        port in displayIn : DisplayPort;
        port in powerIn : PowerPort;

        action def renderDisplay :> Action {
            in content : DisplayContent;
        }

        perform action render : renderDisplay;
    }

    part def DataLogger {
        attribute recordCount : Integer = 0;
        attribute records : LogRecord[0..*];

        port in logIn : LogPort;
        port in powerIn : PowerPort;

        action def storeRecord :> Action {
            in record : LogRecord;
        }

        perform action store : storeRecord;
    }

    part def InternalBattery {
        attribute charge : BatteryCharge = BatteryCharge(100.0);
        attribute nominalVoltage : Voltage = Voltage(3.7);

        port out powerOut : PowerPort;

        action def supplyPower :> Action {
            out power : ElectricalPower;
        }

        perform action supply : supplyPower;
    }

    // ---- Device ----
    part def DigitalScoliometerDevice {
        attribute measuredATR : AngleOfTrunkRotation;

        part inclinometer : InclinometerSensor;
        part processor : SignalProcessor;
        part display : DigitalDisplay;
        part logger : DataLogger;
        part battery : InternalBattery;

        // Connections
        connection inclinometerToProcessor connect inclinometer.rawAngleOut to processor.rawAngleIn;
        connection processorToDisplay connect processor.displayOut to display.displayIn;
        connection processorToLogger connect processor.logOut to logger.logIn;
        connection batteryToInclinometer connect battery.powerOut to inclinometer.powerIn;
        connection batteryToProcessor connect battery.powerOut to processor.powerIn;
        connection batteryToDisplay connect battery.powerOut to display.powerIn;
        connection batteryToLogger connect battery.powerOut to logger.powerIn;

        // ---- State Machine ----
        state def ScoliometerStateMachine {
            entry action initializeDevice {
                // Initialize all subsystems
            }

            state poweredOff {
                entry action powerOffAction {
                    // Device is off
                }
                transition powerOnTransition first poweredOff to initializing accept PowerOn;
            }

            state initializing {
                entry action initAction {
                    // Perform self-test and calibration
                }
                transition initCompleteTransition to ready accept InitComplete;
            }

            state ready {
                entry action readyAction {
                    // Device ready for measurement
                }
                transition beginScreeningTransition to measuring accept BeginScreening;
            }

            state measuring {
                entry action measureAction {
                    // Inclinometer actively measuring ATR
                }
                transition measurementDoneTransition to processing accept MeasurementComplete;
            }

            state processing {
                entry action processAction {
                    // Processor applies calibration, filtering, and severity classification
                }
                transition processingDoneTransition to displaying accept ProcessingComplete;
            }

            state displaying {
                entry action displayAction {
                    // Display ATR and severity; log record
                }
                transition acknowledgeTransition to ready accept AcknowledgeResult;
            }

            transition powerOffTransition from ready to poweredOff accept PowerOff;
        }

        perform state machine operation : ScoliometerStateMachine;

        satisfy ScoliometerFunctionalRequirement by self;
        satisfy InclinometerAccuracyRequirement by inclinometer;
        satisfy ProcessorCalibrationRequirement by processor;
        satisfy SeverityClassificationRequirement by processor;
        satisfy DisplayRequirement by display;
        satisfy DataLoggerRequirement by logger;
        satisfy BatteryRequirement by battery;
    }

    // ---- Top-level package requirements ----
    requirement ScoliometerSystemRequirement : ScoliometerFunctionalRequirement {
        doc /* Top-level requirement: The digital scoliometer shall measure spinal asymmetry by determining ATR during a forward bend test. */
    }

    requirement SensorAccuracyReq : InclinometerAccuracyRequirement {
        doc /* The inclinometer sensor shall measure raw angle with accuracy of at most 1 degree. */
    }

    requirement ProcessorReq : ProcessorCalibrationRequirement {
        doc /* The signal processor shall calibrate and filter raw data to produce a precise ATR. */
    }

    requirement SeverityReq : SeverityClassificationRequirement {
        doc /* The processor shall classify ATR results into normal, monitor, or refer. */
    }

    requirement DisplayReq : DisplayRequirement {
        doc /* The display shall show ATR angle and severity classification. */
    }

    requirement LoggerReq : DataLoggerRequirement {
        doc /* The data logger shall store measurement history with angle, timestamp, vertebral level, and patient position. */
    }

    requirement BatteryReq : BatteryRequirement {
        doc /* The internal battery shall power the handheld unit for portable clinical use. */
    }
}
