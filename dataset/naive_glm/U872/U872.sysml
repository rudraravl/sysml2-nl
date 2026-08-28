package SensorFusionSensingUnit {

    import ScalarValues::*;

    package ValueTypes {

        value def Acceleration :> Real {
            attribute unit : String = "m/s^2";
        }
        value def AngularVelocity :> Real {
            attribute unit : String = "rad/s";
        }
        value def MagneticFluxDensity :> Real {
            attribute unit : String = "uT";
        }
        value def Time :> Real {
            attribute unit : String = "s";
        }
        value def Frequency :> Real {
            attribute unit : String = "Hz";
        }
        value def Angle :> Real {
            attribute unit : String = "rad";
        }
        value def Velocity :> Real {
            attribute unit : String = "m/s";
        }
        value def Position :> Real {
            attribute unit : String = "m";
        }
        value def Confidence :> Real {
            attribute unit : String = "%";
        }

        value def Acceleration3D {
            attribute x : Acceleration;
            attribute y : Acceleration;
            attribute z : Acceleration;
        }
        value def AngularVelocity3D {
            attribute x : AngularVelocity;
            attribute y : AngularVelocity;
            attribute z : AngularVelocity;
        }
        value def MagneticField3D {
            attribute x : MagneticFluxDensity;
            attribute y : MagneticFluxDensity;
            attribute z : MagneticFluxDensity;
        }
        value def Position3D {
            attribute x : Position;
            attribute y : Position;
            attribute z : Position;
        }
        value def Velocity3D {
            attribute x : Velocity;
            attribute y : Velocity;
            attribute z : Velocity;
        }
        value def EulerAngles {
            attribute roll : Angle;
            attribute pitch : Angle;
            attribute yaw : Angle;
        }
    }

    package Items {
        import ValueTypes::*;

        item def RawAccelerometerData {
            attribute timestamp : Time;
            attribute acceleration : Acceleration3D;
            attribute valid : Boolean;
        }
        item def RawGyroscopeData {
            attribute timestamp : Time;
            attribute angularVelocity : AngularVelocity3D;
            attribute valid : Boolean;
        }
        item def RawMagnetometerData {
            attribute timestamp : Time;
            attribute magneticField : MagneticField3D;
            attribute valid : Boolean;
        }
        item def SynchronizedSensorFrame {
            attribute timestamp : Time;
            attribute acceleration : Acceleration3D;
            attribute angularVelocity : AngularVelocity3D;
            attribute magneticField : MagneticField3D;
            attribute integrityOK : Boolean;
        }
        item def KalmanEstimate {
            attribute timestamp : Time;
            attribute position : Position3D;
            attribute velocity : Velocity3D;
            attribute orientation : EulerAngles;
            attribute confidence : Confidence;
        }
        item def ComplementaryEstimate {
            attribute timestamp : Time;
            attribute orientation : EulerAngles;
            attribute confidence : Confidence;
        }
        item def FusedEstimate {
            attribute timestamp : Time;
            attribute position : Position3D;
            attribute velocity : Velocity3D;
            attribute orientation : EulerAngles;
            attribute confidence : Confidence;
            attribute degraded : Boolean;
        }
        item def CalibrationParameters {
            attribute accelBias : Acceleration3D;
            attribute gyroBias : AngularVelocity3D;
            attribute magBias : MagneticField3D;
            attribute calibrated : Boolean;
        }
        item def SensorStatus {
            attribute accelerometerOK : Boolean;
            attribute gyroscopeOK : Boolean;
            attribute magnetometerOK : Boolean;
        }
    }

    package Ports {
        import Items::*;

        port def AccelerometerOut {
            out data : RawAccelerometerData;
        }
        port def GyroscopeOut {
            out data : RawGyroscopeData;
        }
        port def MagnetometerOut {
            out data : RawMagnetometerData;
        }
        port def AccelIn {
            in data : RawAccelerometerData;
        }
        port def GyroIn {
            in data : RawGyroscopeData;
        }
        port def MagIn {
            in data : RawMagnetometerData;
        }
        port def FusedEstimateOut {
            out estimate : FusedEstimate;
        }
        port def CalibrationIn {
            in params : CalibrationParameters;
        }
        port def PowerIn {
            in voltage : Real;
        }
    }

    package Components {
        import Ports::*;
        import Items::*;
        import ValueTypes::*;

        part def Accelerometer {
            attribute sampleRate : Frequency = 1000;
            attribute fullScaleRange : Acceleration = 196;
            attribute noiseDensity : Acceleration = 0.0003;
            attribute bias : Acceleration3D;
            port accelOut : AccelerometerOut;
            port power : PowerIn;

            action def SampleAcceleration {
                in timestamp : Time;
                out data : RawAccelerometerData;
            }

            action def SelfTest {
                out passed : Boolean;
            }
        }

        part def Gyroscope {
            attribute sampleRate : Frequency = 1000;
            attribute fullScaleRange : AngularVelocity = 34.9;
            attribute noiseDensity : AngularVelocity = 0.000087;
            attribute bias : AngularVelocity3D;
            port gyroOut : GyroscopeOut;
            port power : PowerIn;

            action def SampleAngularVelocity {
                in timestamp : Time;
                out data : RawGyroscopeData;
            }

            action def SelfTest {
                out passed : Boolean;
            }
        }

        part def Magnetometer {
            attribute sampleRate : Frequency = 100;
            attribute fullScaleRange : MagneticFluxDensity = 4900;
            attribute noiseDensity : MagneticFluxDensity = 1.5;
            attribute bias : MagneticField3D;
            port magOut : MagnetometerOut;
            port power : PowerIn;

            action def SampleMagneticField {
                in timestamp : Time;
                out data : RawMagnetometerData;
            }

            action def SelfTest {
                out passed : Boolean;
            }
        }

        part def FusionProcessor {
            attribute processingFrequency : Frequency = 500;
            attribute kalmanGain : Real = 0.85;
            attribute complementaryGain : Real = 0.98;
            attribute mergeWeightKalman : Real = 0.7;
            attribute mergeWeightComplementary : Real = 0.3;
            attribute currentCalibration : CalibrationParameters;
            attribute sensorStatus : SensorStatus;
            attribute lastFusedEstimate : FusedEstimate;

            port accelIn : AccelIn;
            port gyroIn : GyroIn;
            port magIn : MagIn;
            port estimateOut : FusedEstimateOut;
            port calibIn : CalibrationIn;
            port power : PowerIn;

            action def ValidateIntegrity {
                in accel : RawAccelerometerData;
                in gyro : RawGyroscopeData;
                in mag : RawMagnetometerData;
                out frame : SynchronizedSensorFrame;
                out integrityOK : Boolean;
            }

            action def TimeSynchronize {
                in accel : RawAccelerometerData;
                in gyro : RawGyroscopeData;
                in mag : RawMagnetometerData;
                out frame : SynchronizedSensorFrame;
            }

            action def RunKalmanFilter {
                in frame : SynchronizedSensorFrame;
                in previousEstimate : KalmanEstimate;
                out estimate : KalmanEstimate;
            }

            action def RunComplementaryFilter {
                in frame : SynchronizedSensorFrame;
                in previousEstimate : ComplementaryEstimate;
                out estimate : ComplementaryEstimate;
            }

            action def MergeEstimates {
                in kalmanEst : KalmanEstimate;
                in compEst : ComplementaryEstimate;
                out fused : FusedEstimate;
            }

            action def FuseCycle {
                in accel : RawAccelerometerData;
                in gyro : RawGyroscopeData;
                in mag : RawMagnetometerData;
                in previousKalman : KalmanEstimate;
                in previousComplementary : ComplementaryEstimate;
                out fused : FusedEstimate;

                action sync : TimeSynchronize;
                action validate : ValidateIntegrity;
                action kalman : RunKalmanFilter;
                action complementary : RunComplementaryFilter;
                action merge : MergeEstimates;

                flow accel to sync.accel;
                flow gyro to sync.gyro;
                flow mag to sync.mag;
                flow accel to validate.accel;
                flow gyro to validate.gyro;
                flow mag to validate.mag;
                flow sync.frame to kalman.frame;
                flow sync.frame to complementary.frame;
                flow previousKalman to kalman.previousEstimate;
                flow previousComplementary to complementary.previousEstimate;
                flow kalman.estimate to merge.kalmanEst;
                flow complementary.estimate to merge.compEst;
                flow merge.fused to fused;
            }

            action def CalibrateSensors {
                in accelSamples : RawAccelerometerData[0..*];
                in gyroSamples : RawGyroscopeData[0..*];
                in magSamples : RawMagnetometerData[0..*];
                out params : CalibrationParameters;
            }

            action def DetectSensorFailure {
                in status : SensorStatus;
                in accel : RawAccelerometerData;
                in gyro : RawGyroscopeData;
                in mag : RawMagnetometerData;
                out failureDetected : Boolean;
                out failedSensor : String;
            }

            action def DegradedEstimate {
                in frame : SynchronizedSensorFrame;
                in availableSensors : SensorStatus;
                in previousEstimate : FusedEstimate;
                out fused : FusedEstimate;
            }

            action def AttemptRecovery {
                in failedSensor : String;
                out recovered : Boolean;
                out updatedStatus : SensorStatus;
            }
        }
    }

    package System {
        import Components::*;
        import Ports::*;
        import Items::*;
        import ValueTypes::*;

        part def SensorFusionSensingUnit {
            attribute updateRate : Frequency = 500;
            attribute powerOn : Boolean = false;
            attribute calibrationComplete : Boolean = false;
            attribute sensorFailure : Boolean = false;
            attribute recoverySuccessful : Boolean = false;
            attribute unrecoverable : Boolean = false;
            attribute bootComplete : Boolean = false;

            port estimateOut : FusedEstimateOut;
            port calibPort : CalibrationIn;
            port powerPort : PowerIn;

            part accelerometer : Accelerometer;
            part gyroscope : Gyroscope;
            part magnetometer : Magnetometer;
            part processor : FusionProcessor;

            connection powerToAccel connect powerPort to accelerometer.power;
            connection powerToGyro connect powerPort to gyroscope.power;
            connection powerToMag connect powerPort to magnetometer.power;
            connection powerToProc connect powerPort to processor.power;

            connection accelLink connect accelerometer.accelOut to processor.accelIn;
            connection gyroLink connect gyroscope.gyroOut to processor.gyroIn;
            connection magLink connect magnetometer.magOut to processor.magIn;
            connection outputLink connect processor.estimateOut to estimateOut;
            connection calibLink connect calibPort to processor.calibIn;

            state machine OperationStates {
                initial initialPseudostate;

                state Off {
                    entry { powerOn = false; }
                }

                state Initializing {
                    entry { /* load firmware and configure sensors */ }
                    do { /* run self-test on each sensor */ }
                    exit { bootComplete = true; }
                }

                state Calibrating {
                    entry { /* begin sensor calibration routine */ }
                    do { /* collect samples and compute bias corrections */ }
                    exit { calibrationComplete = true; }
                }

                state Operational {
                    entry { /* start continuous sense-process-fuse cycle */ }
                    do { /* run fusion at high frequency */ }
                    exit { /* stop fusion cycle */ }

                    state Sensing {
                        entry { /* acquire raw data from all sensors */ }
                    }
                    state Processing {
                        entry { /* validate integrity and time-synchronize */ }
                    }
                    state Fusing {
                        entry { /* run EKF and Complementary filter, merge */ }
                    }

                    initial operationalInitial;
                    transition operationalInitial to Sensing;
                    transition Sensing to Processing;
                    transition Processing to Fusing;
                    transition Fusing to Sensing;
                }

                state ErrorHandling {
                    entry { /* detect and identify failed sensor */ }
                    do { /* attempt recovery and provide degraded estimate */ }
                    exit { /* log error and update status */ }
                }

                transition initialPseudostate to Off;
                transition Off to Initializing when powerOn;
                transition Initializing to Calibrating when bootComplete;
                transition Calibrating to Operational when calibrationComplete;
                transition Operational to ErrorHandling when sensorFailure;
                transition ErrorHandling to Operational when recoverySuccessful;
                transition ErrorHandling to Off when unrecoverable;
            }
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Items::*;

        requirement def HighAccuracyEstimation {
            doc /* The unit shall provide highly accurate real-time estimates of position, velocity, and orientation. */
            attribute maxPositionError : Position = 0.10;
            attribute maxVelocityError : Velocity = 0.05;
            attribute maxOrientationError : Angle = 0.017;
            attribute maxLatency : Time = 0.005;
            attribute actualPositionError : Position;
            attribute actualVelocityError : Velocity;
            attribute actualOrientationError : Angle;
            attribute actualLatency : Time;
            require actualPositionError <= maxPositionError;
            require actualVelocityError <= maxVelocityError;
            require actualOrientationError <= maxOrientationError;
            require actualLatency <= maxLatency;
        }

        requirement def MultiSensorFusion {
            doc /* The unit shall combine data from accelerometer, gyroscope, and magnetometer into a single reliable picture. */
            attribute accelerometerDataUsed : Boolean = true;
            attribute gyroscopeDataUsed : Boolean = true;
            attribute magnetometerDataUsed : Boolean = true;
            require accelerometerDataUsed;
            require gyroscopeDataUsed;
            require magnetometerDataUsed;
        }

        requirement def DualAlgorithmFusion {
            doc /* The unit shall simultaneously run an Extended Kalman Filter and a Complementary Filter and merge their results. */
            attribute kalmanFilterActive : Boolean = true;
            attribute complementaryFilterActive : Boolean = true;
            attribute estimatesMerged : Boolean = true;
            require kalmanFilterActive;
            require complementaryFilterActive;
            require estimatesMerged;
        }

        requirement def DataIntegrityValidation {
            doc /* Raw sensor data shall be validated for integrity before fusion. */
            attribute rawDataValidated : Boolean = true;
            require rawDataValidated;
        }

        requirement def TimeSynchronization {
            doc /* All sensor measurements shall be time-synchronized to the same moment. */
            attribute maxTimeSkew : Time = 0.001;
            attribute actualTimeSkew : Time;
            require actualTimeSkew <= maxTimeSkew;
        }

        requirement def CalibrationPhase {
            doc /* The unit shall enter a mandatory calibration phase on power-up to tune each sensor and correct biases and drift. */
            attribute calibrationPerformedBeforeOperation : Boolean = true;
            require calibrationPerformedBeforeOperation;
        }

        requirement def ErrorHandlingCapability {
            doc /* The unit shall detect sensor failures, attempt recovery, and provide degraded estimates using remaining functioning sensors. */
            attribute sensorFailureDetected : Boolean = true;
            attribute recoveryAttempted : Boolean = true;
            attribute degradedEstimateProvided : Boolean = true;
            require sensorFailureDetected;
            require recoveryAttempted;
            require degradedEstimateProvided;
        }

        requirement def HighFrequencyOperation {
            doc /* The sense-process-fuse cycle shall run at high frequency. */
            attribute minUpdateRate : Frequency = 400;
            attribute actualUpdateRate : Frequency;
            require actualUpdateRate >= minUpdateRate;
        }

        requirement def CompactModule {
            doc /* The unit shall be a compact electronic module. */
            attribute maxLength_mm : Real = 50;
            attribute maxWidth_mm : Real = 50;
            attribute maxHeight_mm : Real = 10;
            attribute actualLength_mm : Real;
            attribute actualWidth_mm : Real;
            attribute actualHeight_mm : Real;
            require actualLength_mm <= maxLength_mm;
            require actualWidth_mm <= maxWidth_mm;
            require actualHeight_mm <= maxHeight_mm;
        }

        package SensorFusionRequirements {
            requirement highAccuracy : HighAccuracyEstimation;
            requirement multiSensor : MultiSensorFusion;
            requirement dualAlgorithm : DualAlgorithmFusion;
            requirement dataIntegrity : DataIntegrityValidation;
            requirement timeSync : TimeSynchronization;
            requirement calibration : CalibrationPhase;
            requirement errorHandling : ErrorHandlingCapability;
            requirement highFreq : HighFrequencyOperation;
            requirement compactForm : CompactModule;
        }
    }

    package Verification {
        import System::SensorFusionSensingUnit;
        import Requirements::SensorFusionRequirements::*;

        part fusionUnitInstance : SensorFusionSensingUnit;

        satisfy highAccuracy by fusionUnitInstance;
        satisfy multiSensor by fusionUnitInstance;
        satisfy dualAlgorithm by fusionUnitInstance;
        satisfy dataIntegrity by fusionUnitInstance;
        satisfy timeSync by fusionUnitInstance;
        satisfy calibration by fusionUnitInstance;
        satisfy errorHandling by fusionUnitInstance;
        satisfy highFreq by fusionUnitInstance;
        satisfy compactForm by fusionUnitInstance;
    }
}
