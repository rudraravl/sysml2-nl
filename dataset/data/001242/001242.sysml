package SensorFusionSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;
    
    comment about SensorFusionUnit
    /* This model describes a sensor fusion sensing unit that combines measurements
     * from multiple heterogeneous sensors to produce accurate estimates of position,
     * velocity, and orientation. The system integrates data from accelerometers,
     * gyroscopes, and magnetometers using advanced fusion algorithms to overcome
     * individual sensor limitations and provide robust state estimation.
     */
    
    attribute def AccelerationVector :> VectorQuantityValue {
        attribute :>> num : Real[3] ordered;
        attribute :>> mRef : AccelerationUnit;
    }
    
    attribute def AngularVelocityVector :> VectorQuantityValue {
        attribute :>> num : Real[3] ordered;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def MagneticFieldVector :> VectorQuantityValue {
        attribute :>> num : Real[3] ordered;
        attribute :>> mRef : MagneticFluxDensityUnit;
    }
    
    attribute def PositionVector :> VectorQuantityValue {
        attribute :>> num : Real[3] ordered;
        attribute :>> mRef : LengthUnit;
    }
    
    attribute def VelocityVector :> VectorQuantityValue {
        attribute :>> num : Real[3] ordered;
        attribute :>> mRef : SpeedUnit;
    }
    
    attribute def QuaternionOrientation :> VectorQuantityValue {
        attribute :>> num : Real[4] ordered;
        attribute :>> mRef : SimpleUnit;
    }
    
    attribute def ConfidenceFactor :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : SimpleUnit;
    }
    
    attribute def TimestampValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : TimeUnit;
    }
    
    item def SensorMeasurement {
        attribute timestamp : TimestampValue;
        attribute confidence : ConfidenceFactor;
        attribute isValid : Boolean;
    }
    
    item def AccelerometerData :> SensorMeasurement {
        attribute acceleration : AccelerationVector;
        attribute temperature : TemperatureValue;
        attribute bias : AccelerationVector;
    }
    
    item def GyroscopeData :> SensorMeasurement {
        attribute angularVelocity : AngularVelocityVector;
        attribute temperature : TemperatureValue;
        attribute drift : AngularVelocityVector;
    }
    
    item def MagnetometerData :> SensorMeasurement {
        attribute magneticField : MagneticFieldVector;
        attribute hardIronOffset : MagneticFieldVector;
    }
    
    item def FusedStateEstimate {
        attribute timestamp : TimestampValue;
        attribute position : PositionVector;
        attribute velocity : VelocityVector;
        attribute orientation : QuaternionOrientation;
        attribute confidence : ConfidenceFactor;
        attribute covarianceMatrix : Real[9] ordered;
    }
    
    item def CalibrationParameters {
        attribute accelBias : AccelerationVector;
        attribute gyroDrift : AngularVelocityVector;
        attribute magOffset : MagneticFieldVector;
        attribute calibrationTimestamp : TimestampValue;
    }
    
    port def AccelerometerDataPort {
        out item accelData : AccelerometerData;
    }
    
    port def GyroscopeDataPort {
        out item gyroData : GyroscopeData;
    }
    
    port def MagnetometerDataPort {
        out item magData : MagnetometerData;
    }
    
    port def FusedEstimatePort {
        out item estimate : FusedStateEstimate;
    }
    
    port def CalibrationControlPort {
        in item calibrationCommand : CalibrationCommand;
        out item calibrationStatus : CalibrationStatus;
    }
    
    item def CalibrationCommand {
        attribute targetSensor : String;
        attribute calibrationType : String;
        attribute duration : TimeValue;
    }
    
    item def CalibrationStatus {
        attribute isCalibrated : Boolean;
        attribute calibrationQuality : ConfidenceFactor;
        attribute lastCalibration : TimestampValue;
    }
    
    part def ThreeAxisAccelerometer {
        port dataOutput : AccelerometerDataPort;
        port calibrationControl : CalibrationControlPort;
        
        attribute samplingRate : FrequencyValue;
        attribute measurementRange : AccelerationVector;
        attribute resolution : AccelerationVector;
        attribute noiseLevel : AccelerationVector;
    }
    
    part def ThreeAxisGyroscope {
        port dataOutput : GyroscopeDataPort;
        port calibrationControl : CalibrationControlPort;
        
        attribute samplingRate : FrequencyValue;
        attribute measurementRange : AngularVelocityVector;
        attribute resolution : AngularVelocityVector;
        attribute driftRate : AngularVelocityVector;
    }
    
    part def ThreeAxisMagnetometer {
        port dataOutput : MagnetometerDataPort;
        port calibrationControl : CalibrationControlPort;
        
        attribute samplingRate : FrequencyValue;
        attribute measurementRange : MagneticFieldVector;
        attribute resolution : MagneticFieldVector;
    }
    
    action def AcquireAccelerometerData {
        out item rawAccelData : AccelerometerData;
    }
    
    action def AcquireGyroscopeData {
        out item rawGyroData : GyroscopeData;
    }
    
    action def AcquireMagnetometerData {
        out item rawMagData : MagnetometerData;
    }
    
    action def ValidateSensorData {
        in item sensorData : SensorMeasurement;
        out item validatedData : SensorMeasurement;
        out item validationResult : Boolean;
    }
    
    action def ApplyCalibration {
        in item rawData : SensorMeasurement;
        in item calibrationParams : CalibrationParameters;
        out item calibratedData : SensorMeasurement;
    }
    
    action def SynchronizeSensorData {
        in item accelData : AccelerometerData;
        in item gyroData : GyroscopeData;
        in item magData : MagnetometerData;
        out item syncedAccel : AccelerometerData;
        out item syncedGyro : GyroscopeData;
        out item syncedMag : MagnetometerData;
    }
    
    action def ExtendedKalmanFilter {
        in item previousEstimate : FusedStateEstimate;
        in item accelMeasurement : AccelerometerData;
        in item gyroMeasurement : GyroscopeData;
        in item magMeasurement : MagnetometerData;
        out item updatedEstimate : FusedStateEstimate;
    }
    
    action def ComplementaryFilterOrientation {
        in item accelData : AccelerometerData;
        in item gyroData : GyroscopeData;
        in item magData : MagnetometerData;
        out item orientationEstimate : QuaternionOrientation;
    }
    
    action def PerformSensorCalibration {
        in item calibrationCmd : CalibrationCommand;
        out item calibrationParams : CalibrationParameters;
        out item status : CalibrationStatus;
    }
    
    action def FuseSensorMeasurements {
        in item accelInput : AccelerometerData;
        in item gyroInput : GyroscopeData;
        in item magInput : MagnetometerData;
        out item fusedEstimate : FusedStateEstimate;
        
        action acquireAccel : AcquireAccelerometerData {
            out rawAccelData;
        }
        then validateAccel;
        
        action validateAccel : ValidateSensorData {
            in sensorData references acquireAccel.rawAccelData;
            out validatedAccel : AccelerometerData;
            out accelValid : Boolean;
        }
        then fork acquisitionFork;
        
        fork acquisitionFork;
        then acquireGyro;
        
        action acquireGyro : AcquireGyroscopeData {
            out rawGyroData;
        }
        then validateGyro;
        
        action validateGyro : ValidateSensorData {
            in sensorData references acquireGyro.rawGyroData;
            out validatedGyro : GyroscopeData;
            out gyroValid : Boolean;
        }
        then synchronizeJoin;
        
        then acquisitionFork;
        then acquireMag;
        
        action acquireMag : AcquireMagnetometerData {
            out rawMagData;
        }
        then validateMag;
        
        action validateMag : ValidateSensorData {
            in sensorData references acquireMag.rawMagData;
            out validatedMag : MagnetometerData;
            out magValid : Boolean;
        }
        then synchronizeJoin;
        
        join synchronizeJoin;
        then synchronize;
        
        action synchronize : SynchronizeSensorData {
            in accelData references validateAccel.validatedAccel;
            in gyroData references validateGyro.validatedGyro;
            in magData references validateMag.validatedMag;
            out syncedAccel : AccelerometerData;
            out syncedGyro : GyroscopeData;
            out syncedMag : MagnetometerData;
        }
        then fork fusionFork;
        
        fork fusionFork;
        then kalmanFiltering;
        
        action kalmanFiltering : ExtendedKalmanFilter {
            in previousEstimate : FusedStateEstimate;
            in accelMeasurement references synchronize.syncedAccel;
            in gyroMeasurement references synchronize.syncedGyro;
            in magMeasurement references synchronize.syncedMag;
            out ekfEstimate : FusedStateEstimate;
        }
        then fusionJoin;
        
        then fusionFork;
        then complementaryFiltering;
        
        action complementaryFiltering : ComplementaryFilterOrientation {
            in accelData references synchronize.syncedAccel;
            in gyroData references synchronize.syncedGyro;
            in magData references synchronize.syncedMag;
            out cfOrientation : QuaternionOrientation;
        }
        then fusionJoin;
        
        join fusionJoin;
        then mergeEstimates;
        
        action mergeEstimates {
            in ekfResult references kalmanFiltering.ekfEstimate;
            in cfResult references complementaryFiltering.cfOrientation;
            out finalEstimate : FusedStateEstimate;
        }
        
        flow from mergeEstimates.finalEstimate to fusedEstimate;
        
        bind accelInput = acquireAccel.rawAccelData;
        bind gyroInput = acquireGyro.rawGyroData;
        bind magInput = acquireMag.rawMagData;
    }
    
    state def SensorFusionStateMachine {
        entry action initializeSensors;
        do action continuousFusion;
        exit action shutdownSensors;
        
        state Initialization;
        
        transition first Initialization;
        
        transition InitToCalibration
            first Initialization
            accept CalibrationRequest
            then Calibration;
        
        state Calibration {
            entry action startCalibration : PerformSensorCalibration;
            
            state CalibratingAccelerometer;
            
            transition first CalibratingAccelerometer;
            
            transition AccelToGyro
                first CalibratingAccelerometer
                accept AccelCalibrationDone
                then CalibratingGyroscope;
            
            state CalibratingGyroscope;
            
            transition GyroToMag
                first CalibratingGyroscope
                accept GyroCalibrationDone
                then CalibratingMagnetometer;
            
            state CalibratingMagnetometer;
            
            transition MagToComplete
                first CalibratingMagnetometer
                accept MagCalibrationDone
                then CalibrationComplete;
            
            state CalibrationComplete;
        }
        
        transition CalToOperational
            first Calibration.CalibrationComplete
            accept CalibrationValidated
            then Operational;
        
        state Operational {
            do action fusionOperation : FuseSensorMeasurements;
            
            state Acquiring {
                do action acquireSensorData;
            }
            
            transition first Acquiring;
            
            transition AcqToProcessing
                first Acquiring
                accept DataReady
                then Processing;
            
            state Processing {
                do action processFusion;
                
                state Synchronizing;
                
                transition first Synchronizing;
                
                transition SyncToFiltering
                    first Synchronizing
                    accept DataSynchronized
                    then Filtering;
                
                state Filtering {
                    state KalmanFiltering;
                    state ComplementaryFiltering;
                    
                    transition first fork filterFork;
                    
                    fork filterFork;
                    then KalmanFiltering;
                    then filterFork;
                    then ComplementaryFiltering;
                    
                    join filterJoin;
                }
                
                transition FilterToMerging
                    first Filtering
                    accept FilteringComplete
                    then Merging;
                
                state Merging;
                
                transition MergeToReady
                    first Merging
                    accept MergingComplete
                    then OutputReady;
                
                state OutputReady;
            }
            
            transition ProcessToAcq
                first Processing.OutputReady
                accept OutputPublished
                then Acquiring;
        }
        
        transition OpToError
            first Operational
            accept SensorFailureDetected
            then ErrorHandling;
        
        state ErrorHandling {
            entry action logError;
            do action attemptRecovery;
            
            state DiagnosingFailure;
            
            transition first DiagnosingFailure;
            
            transition DiagToRecovery
                first DiagnosingFailure
                accept DiagnosisComplete
                then RecoveryAttempt;
            
            state RecoveryAttempt;
        }
        
        transition ErrorToCalibration
            first ErrorHandling.RecoveryAttempt
            accept RecoveryRequiresCalibration
            then Calibration;
        
        transition ErrorToOperational
            first ErrorHandling.RecoveryAttempt
            accept RecoverySuccessful
            then Operational;
        
        transition OpToShutdown
            first Operational
            accept ShutdownRequest
            then Shutdown;
        
        state Shutdown;
    }
    
    part def FusionProcessingUnit {
        attribute fusionAlgorithm : String;
        attribute updateFrequency : FrequencyValue;
        attribute estimationWindow : TimeValue;
        attribute filterGain : Real;
        
        port accelInput : AccelerometerDataPort;
        port gyroInput : GyroscopeDataPort;
        port magInput : MagnetometerDataPort;
        port estimateOutput : FusedEstimatePort;
        
        perform action fusionBehavior : FuseSensorMeasurements;
        exhibit state fusionState : SensorFusionStateMachine;
    }
    
    part def SensorFusionUnit {
        attribute unitIdentifier : String;
        attribute operatingTemperature : TemperatureValue;
        attribute powerConsumption : PowerValue;
        attribute dataLatency : TimeValue;
        
        part accelerometer : ThreeAxisAccelerometer[1] {
            attribute :>> samplingRate = 200.0[Hz];
            attribute :>> measurementRange {
                attribute :>> num = [16.0, 16.0, 16.0];
            }
            attribute :>> resolution {
                attribute :>> num = [0.001, 0.001, 0.001];
            }
        }
        
        part gyroscope : ThreeAxisGyroscope[1] {
            attribute :>> samplingRate = 200.0[Hz];
            attribute :>> measurementRange {
                attribute :>> num = [2000.0, 2000.0, 2000.0];
            }
            attribute :>> resolution {
                attribute :>> num = [0.01, 0.01, 0.01];
            }
        }
        
        part magnetometer : ThreeAxisMagnetometer[1] {
            attribute :>> samplingRate = 100.0[Hz];
            attribute :>> measurementRange {
                attribute :>> num = [1000.0, 1000.0, 1000.0];
            }
        }
        
        part processor : FusionProcessingUnit[1] {
            attribute :>> fusionAlgorithm = "Extended Kalman Filter with Complementary Orientation";
            attribute :>> updateFrequency = 100.0[Hz];
            attribute :>> estimationWindow = 0.1[s];
            attribute :>> filterGain = 0.98;
        }
        
        connection accelDataConnection 
            connect accelerometer.dataOutput to processor.accelInput;
        
        connection gyroDataConnection 
            connect gyroscope.dataOutput to processor.gyroInput;
        
        connection magDataConnection 
            connect magnetometer.dataOutput to processor.magInput;
        
        port fusedOutput : FusedEstimatePort;
        
        connection estimateOutputConnection 
            connect processor.estimateOutput to fusedOutput;
    }
    
    requirement def SensorFusionSystemRequirements {
        doc /* The sensor fusion system shall meet performance, accuracy, and reliability requirements. */
        
        requirement positionAccuracyRequirement {
            doc /* The fused position estimate shall achieve accuracy better than 0.1 meters RMS. */
            
            subject fusionUnit : SensorFusionUnit;
            
            require constraint {
                fusionUnit.processor.estimateOutput.estimate.confidence.num >= 0.95
            }
        }
        
        requirement orientationAccuracyRequirement {
            doc /* The fused orientation estimate shall achieve accuracy better than 1 degree RMS. */
            
            subject fusionUnit : SensorFusionUnit;
        }
        
        requirement updateRateRequirement {
            doc /* The fusion system shall provide state estimates at minimum 50 Hz. */
            
            subject fusionUnit : SensorFusionUnit;
            
            require constraint {
                fusionUnit.processor.updateFrequency.num >= 50.0
            }
        }
        
        requirement latencyRequirement {
            doc /* Total latency from sensor acquisition to fused output shall not exceed 20 milliseconds. */
            
            subject fusionUnit : SensorFusionUnit;
            
            require constraint {
                fusionUnit.dataLatency.num <= 0.020
            }
        }
        
        requirement calibrationRequirement {
            doc /* All sensors shall be calibrated before operational mode and recalibrated every 24 hours. */
            
            subject fusionUnit : SensorFusionUnit;
        }
        
        requirement redundancyRequirement {
            doc /* The system shall provide degraded estimates if one sensor fails. */
            
            subject fusionUnit : SensorFusionUnit;
        }
        
        requirement powerConsumptionRequirement {
            doc /* The sensing unit shall consume less than 3 watts during normal operation. */
            
            subject fusionUnit : SensorFusionUnit;
            
            require constraint {
                fusionUnit.powerConsumption.num <= 3.0
            }
        }
    }
    
    part sensorFusionSystem : SensorFusionUnit {
        attribute :>> unitIdentifier = "SFU-2025-001";
        attribute :>> operatingTemperature = 298.15[K];
        attribute :>> powerConsumption = 2.3[W];
        attribute :>> dataLatency = 0.015[s];
        
        satisfy SensorFusionSystemRequirements::positionAccuracyRequirement by processor;
        satisfy SensorFusionSystemRequirements::orientationAccuracyRequirement by processor;
        satisfy SensorFusionSystemRequirements::updateRateRequirement by processor;
        satisfy SensorFusionSystemRequirements::latencyRequirement by processor;
        satisfy SensorFusionSystemRequirements::calibrationRequirement by accelerometer, gyroscope, magnetometer;
        satisfy SensorFusionSystemRequirements::redundancyRequirement by processor.fusionBehavior;
        satisfy SensorFusionSystemRequirements::powerConsumptionRequirement by accelerometer, gyroscope, magnetometer, processor;
    }
}
