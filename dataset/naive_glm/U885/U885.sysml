package SoftSensor {

    import ScalarValues::*;

    // ================================================================
    // Value Types
    // ================================================================

    value type TemperatureValue :> Real {
        doc /* Temperature in degrees Celsius (°C). */;
    }

    value type PressureValue :> Real {
        doc /* Pressure in Pascals (Pa). */;
    }

    value type FlowRateValue :> Real {
        doc /* Volumetric flow rate in litres per minute (L/min). */;
    }

    value type ConcentrationValue :> Real {
        doc /* Molar concentration in moles per litre (mol/L). */;
    }

    value type PercentageValue :> Real {
        doc /* Dimensionless value expressed as a percentage (0–100). */;
    }

    value type LatencyValue :> Real {
        doc /* Elapsed time in milliseconds (ms). */;
    }

    // ================================================================
    // Item Definitions
    // ================================================================

    item def RawSensorData {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute timestamp : Real;
        attribute sensorId : String;
    }

    item def ProcessedData {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute timestamp : Real;
        attribute signalQuality : PercentageValue;
    }

    item def CalibrationCoefficients {
        attribute beta0 : Real;
        attribute beta1 : Real;
        attribute beta2 : Real;
        attribute beta3 : Real;
        attribute lastUpdate : Real;
        attribute modelVersion : String;
    }

    item def ConcentrationEstimate {
        attribute value : ConcentrationValue;
        attribute confidence : PercentageValue;
        attribute quality : PercentageValue;
        attribute timestamp : Real;
        attribute isOutlier : Boolean;
        attribute latency : LatencyValue;
        attribute isValid : Boolean;
    }

    item def ValidationThresholds {
        attribute minConcentration : ConcentrationValue = 0.0;
        attribute maxConcentration : ConcentrationValue = 10.0;
        attribute maxLatency : LatencyValue = 200.0;
        attribute minConfidence : PercentageValue = 70.0;
        attribute outlierZScoreThreshold : Real = 3.0;
    }

    item def FaultEvent {
        attribute faultId : String;
        attribute timestamp : Real;
        attribute description : String;
        attribute severity : Real;
    }

    // ================================================================
    // Port Definitions
    // ================================================================

    port def RawDataOutPort {
        out raw : RawSensorData;
    }

    port def RawDataInPort {
        in raw : RawSensorData;
    }

    port def ProcessedDataOutPort {
        out processed : ProcessedData;
    }

    port def ProcessedDataInPort {
        in processed : ProcessedData;
    }

    port def EstimateOutPort {
        out estimate : ConcentrationEstimate;
    }

    port def EstimateInPort {
        in estimate : ConcentrationEstimate;
    }

    port def CalibrationInPort {
        in coefficients : CalibrationCoefficients;
    }

    port def FaultOutPort {
        out fault : FaultEvent;
    }

    // ================================================================
    // Physical Sensors
    // ================================================================

    part def PhysicalSensor {
        port dataOut : RawDataOutPort;
        attribute samplingRateHz : Integer = 100;
        attribute isEnabled : Boolean = true;
        attribute lastReading : Real;
        attribute measurementCount : Integer = 0;

        action def takeSample {
            out result : RawSensorData;
        }
    }

    part def TemperatureSensor :> PhysicalSensor {
        :>> samplingRateHz = 50;
        attribute rangeMin : TemperatureValue = -20.0;
        attribute rangeMax : TemperatureValue = 200.0;
        attribute accuracyPercent : Real = 0.5;
    }

    part def PressureSensor :> PhysicalSensor {
        :>> samplingRateHz = 50;
        attribute rangeMin : PressureValue = 0.0;
        attribute rangeMax : PressureValue = 5000000.0;
        attribute accuracyPercent : Real = 0.5;
    }

    part def FlowRateSensor :> PhysicalSensor {
        :>> samplingRateHz = 20;
        attribute rangeMin : FlowRateValue = 0.0;
        attribute rangeMax : FlowRateValue = 1000.0;
        attribute accuracyPercent : Real = 1.0;
    }

    // ================================================================
    // Data Acquisition Module
    // ================================================================

    part def DataAcquisitionModule {
        port rawOut : RawDataOutPort;

        part temperatureSensor : TemperatureSensor;
        part pressureSensor : PressureSensor;
        part flowRateSensor : FlowRateSensor;

        attribute acquisitionIntervalMs : LatencyValue = 20.0;
        attribute isComplete : Boolean = false;
        attribute lastAcquisitionTime : Real;
        attribute totalAcquisitions : Integer = 0;

        action def acquireData {
            in sensors : PhysicalSensor[3];
            out result : RawSensorData;
        }

        action def synchronize {
            doc /* Time-aligns readings from all three sensors to a common clock. */;
        }

        action def checkSensorHealth {
            out allHealthy : Boolean;
        }
    }

    // ================================================================
    // Signal Processor
    // ================================================================

    part def SignalProcessor {
        port rawIn : RawDataInPort;
        port processedOut : ProcessedDataOutPort;

        attribute filterWindow : Integer = 5;
        attribute noiseThreshold : Real = 0.05;
        attribute isComplete : Boolean = false;
        attribute filterCoefficients : Real[*];
        attribute processedCount : Integer = 0;

        action def filter {
            in raw : RawSensorData;
            out result : ProcessedData;
            doc /* Applies a moving-average low-pass filter to each measured variable. */;
        }

        action def detectNoise {
            in raw : RawSensorData;
            out isNoiseDetected : Boolean;
        }

        action def computeSignalQuality {
            in raw : RawSensorData;
            in noiseDetected : Boolean;
            out quality : PercentageValue;
        }

        action def process {
            in raw : RawSensorData;
            out processed : ProcessedData;
        }
    }

    // ================================================================
    // Mathematical Model
    // ================================================================

    part def MathematicalModel {
        port processedIn : ProcessedDataInPort;
        port estimateOut : EstimateOutPort;
        port calibrationIn : CalibrationInPort;

        attribute coefficients : CalibrationCoefficients;
        attribute calibrationLastUpdate : Real;
        attribute modelType : String = "MultipleLinearRegression";
        attribute isComplete : Boolean = false;
        attribute estimationCount : Integer = 0;

        action def applyRegression {
            in data : ProcessedData;
            in coeffs : CalibrationCoefficients;
            out concentration : ConcentrationValue;
            doc /* Concentration = beta0 + beta1*T + beta2*P + beta3*F. */;
        }

        action def updateCoefficients {
            in newCoeffs : CalibrationCoefficients;
        }

        action def computeEstimate {
            in data : ProcessedData;
            out estimate : ConcentrationEstimate;
        }

        action def checkCalibrationAge {
            in lastUpdate : Real;
            in maxAgeMs : LatencyValue;
            out needsUpdate : Boolean;
        }
    }

    // ================================================================
    // Validation Module
    // ================================================================

    part def ValidationModule {
        port estimateIn : EstimateInPort;
        port validatedOut : EstimateOutPort;
        port faultOut : FaultOutPort;

        attribute thresholds : ValidationThresholds;
        attribute faultDetected : Boolean = false;
        attribute historyBuffer : ConcentrationValue[*];
        attribute isComplete : Boolean = false;
        attribute maxHistorySize : Integer = 100;
        attribute validatedCount : Integer = 0;

        action def checkThresholds {
            in estimate : ConcentrationEstimate;
            in thresholds : ValidationThresholds;
            out isValid : Boolean;
        }

        action def detectOutlier {
            in estimate : ConcentrationEstimate;
            in history : ConcentrationValue[*];
            in zThreshold : Real;
            out isOutlier : Boolean;
            doc /* Z-score based outlier detection over a sliding history window. */;
        }

        action def computeConfidence {
            in isOutlier : Boolean;
            in signalQuality : PercentageValue;
            in thresholds : ValidationThresholds;
            out confidence : PercentageValue;
        }

        action def computeQuality {
            in isValid : Boolean;
            in signalQuality : PercentageValue;
            in latency : LatencyValue;
            in thresholds : ValidationThresholds;
            out quality : PercentageValue;
        }

        action def validate {
            in estimate : ConcentrationEstimate;
            in thresholds : ValidationThresholds;
            in history : ConcentrationValue[*];
            out validated : ConcentrationEstimate;
            out fault : FaultEvent;
        }

        action def updateHistory {
            in value : ConcentrationValue;
            inout history : ConcentrationValue[*];
        }
    }

    // ================================================================
    // Soft Sensor System (Top-Level Integration)
    // ================================================================

    part def SoftSensorSystem {
        port finalOutput : EstimateOutPort;
        port calibrationInterface : CalibrationInPort;
        port faultOutput : FaultOutPort;

        part dataAcquisition : DataAcquisitionModule;
        part signalProcessor : SignalProcessor;
        part mathematicalModel : MathematicalModel;
        part validationModule : ValidationModule;

        // Internal data-flow connections
        connection dataAcquisition.rawOut to signalProcessor.rawIn;
        connection signalProcessor.processedOut to mathematicalModel.processedIn;
        connection mathematicalModel.estimateOut to validationModule.estimateIn;
        connection validationModule.validatedOut to finalOutput;
        connection validationModule.faultOut to faultOutput;
        connection calibrationInterface to mathematicalModel.calibrationIn;

        attribute isEnabled : Boolean = true;
        attribute cycleStartTime : Real;
        attribute currentEstimate : ConcentrationEstimate;
        attribute currentLatency : LatencyValue;
        attribute recoveryTriggered : Boolean = false;
        attribute totalCycles : Integer = 0;
        attribute faultCount : Integer = 0;

        action def runCycle {
            in startTime : Real;
            out result : ConcentrationEstimate;
            doc /* Executes one full acquire-process-estimate-validate cycle. */;
        }

        action def handleFault {
            in fault : FaultEvent;
            doc /* Logs a fault event and initiates recovery procedures. */;
        }

        // Continuous-cycle operating state machine
        state machine OperatingStates {
            state Idle {
                entry / {
                    doc /* System powered but not yet enabled. */;
                }
            }

            state Acquiring {
                entry / {
                    doc /* Trigger simultaneous sampling from all three physical sensors. */;
                }
            }

            state Processing {
                entry / {
                    doc /* Filter raw data and compute per-channel signal quality. */;
                }
            }

            state Estimating {
                entry / {
                    doc /* Apply multiple linear regression with current calibration coefficients. */;
                }
            }

            state Validating {
                entry / {
                    doc /* Check thresholds, detect outliers, compute confidence and quality. */;
                }
            }

            state Fault {
                entry / {
                    doc /* Fault detected – log event, flag output invalid, await recovery. */;
                }
            }

            transition from Idle to Acquiring when isEnabled;
            transition from Acquiring to Processing;
            transition from Processing to Estimating;
            transition from Estimating to Validating;
            transition from Validating to Acquiring when not validationModule.faultDetected;
            transition from Validating to Fault when validationModule.faultDetected;
            transition from Fault to Acquiring when recoveryTriggered;
        }
    }

    // ================================================================
    // Requirements
    // ================================================================

    requirement def AccuracyRequirement {
        attribute maxErrorPercent : Real = 3.0;
        doc /* The soft sensor shall estimate product concentration to within 3 % of the actual value. */;
    }

    requirement def LatencyRequirement {
        attribute maxLatencyMs : LatencyValue = 200.0;
        doc /* A complete estimation cycle shall be produced within 200 ms of receiving new sensor data. */;
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate in a continuous cycle without manual intervention under normal conditions. */;
    }

    requirement def OutputContentRequirement {
        doc /* The final output shall include the estimated concentration value, a confidence score, and a quality metric. */;
    }

    requirement def CalibrationUpdateRequirement {
        doc /* The system shall accept periodic updates to the set of calibration coefficients to maintain accuracy. */;
    }

    requirement def OutlierDetectionRequirement {
        doc /* The validation module shall detect and flag outlier estimates that deviate from expected statistical bounds. */;
    }

    requirement def DataAcquisitionRequirement {
        doc /* The data acquisition module shall collect temperature, pressure, and flow rate from dedicated physical sensors. */;
    }

    requirement def SignalProcessingRequirement {
        doc /* The signal processor shall filter and clean raw sensor data to reduce noise before model estimation. */;
    }

    requirement def ModelTypeRequirement {
        doc /* The mathematical model shall use a multiple linear regression formulation with at least four calibrated coefficients. */;
    }

    // ================================================================
    // Verified System Specialisation
    // ================================================================

    part def SoftSensorSystemVerified :> SoftSensorSystem {
        satisfy accReq : AccuracyRequirement;
        satisfy latReq : LatencyRequirement;
        satisfy contOpReq : ContinuousOperationRequirement;
        satisfy outReq : OutputContentRequirement;
        satisfy calReq : CalibrationUpdateRequirement;
        satisfy outDetReq : OutlierDetectionRequirement;
        satisfy daReq : DataAcquisitionRequirement;
        satisfy spReq : SignalProcessingRequirement;
        satisfy mtReq : ModelTypeRequirement;
    }

}
