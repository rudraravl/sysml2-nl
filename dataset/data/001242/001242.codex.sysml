package SensorFusionSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def DegreeCelsius : Real {
        unit = "degC";
    }

    attribute def Millisecond : Real {
        unit = "ms";
    }

    attribute def Milliampere : Real {
        unit = "mA";
    }

    attribute def Volt : Real {
        unit = "V";
    }

    attribute def MeterPerSecondSquared : Real {
        unit = "m/s^2";
    }

    attribute def DegreePerSecond : Real {
        unit = "deg/s";
    }

    attribute def Gauss : Real {
        unit = "G";
    }

    attribute def DimensionlessQuality : Real {
        unit = "1";
    }

    item def AccelerationSample {
        attribute ax : MeterPerSecondSquared;
        attribute ay : MeterPerSecondSquared;
        attribute az : MeterPerSecondSquared;
        attribute timestamp : Millisecond;
        attribute temperature : DegreeCelsius;
    }

    item def AngularRateSample {
        attribute wx : DegreePerSecond;
        attribute wy : DegreePerSecond;
        attribute wz : DegreePerSecond;
        attribute timestamp : Millisecond;
        attribute temperature : DegreeCelsius;
    }

    item def MagneticFieldSample {
        attribute mx : Gauss;
        attribute my : Gauss;
        attribute mz : Gauss;
        attribute timestamp : Millisecond;
        attribute temperature : DegreeCelsius;
    }

    item def BarometricSample {
        attribute pressure : PressureValue;
        attribute altitudeEstimate : LengthValue;
        attribute timestamp : Millisecond;
        attribute temperature : DegreeCelsius;
    }

    item def FusedPoseEstimate {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
        attribute verticalPosition : LengthValue;
        attribute verticalVelocity : SpeedValue;
        attribute confidence : DimensionlessQuality;
        attribute timestamp : Millisecond;
    }

    item def HealthStatus {
        attribute sensorOk : Boolean;
        attribute fusionOk : Boolean;
        attribute calibrated : Boolean;
        attribute faultCode : Integer;
        attribute confidence : DimensionlessQuality;
    }

    item def ConfigurationCommand {
        attribute samplePeriod : Millisecond;
        attribute enableMagnetometer : Boolean;
        attribute enableBarometer : Boolean;
        attribute resetBiasEstimate : Boolean;
    }

    item def PowerSupply {
        attribute voltage : Volt;
        attribute currentLimit : Milliampere;
    }

    port def PowerInputPort {
        in item power : PowerSupply;
    }

    port def ConfigurationPort {
        in item command : ConfigurationCommand;
    }

    port def AccelerationPort {
        out item sample : AccelerationSample;
    }

    port def AngularRatePort {
        out item sample : AngularRateSample;
    }

    port def MagneticFieldPort {
        out item sample : MagneticFieldSample;
    }

    port def BarometricPort {
        out item sample : BarometricSample;
    }

    port def PoseOutputPort {
        out item estimate : FusedPoseEstimate;
    }

    port def HealthOutputPort {
        out item status : HealthStatus;
    }

    port def SensorDataInputPort {
        in item acceleration : AccelerationSample;
        in item angularRate : AngularRateSample;
        in item magneticField : MagneticFieldSample;
        in item barometric : BarometricSample;
    }

    part def Accelerometer {
        attribute measurementRange : MeterPerSecondSquared = 156.96;
        attribute noiseDensity : MeterPerSecondSquared = 0.002;
        attribute biasStability : MeterPerSecondSquared = 0.03;
        attribute samplePeriod : Millisecond = 5.0;
        attribute currentDraw : Milliampere = 1.2;

        port powerIn : PowerInputPort;
        port accelerationOut : AccelerationPort;

        action sampleAcceleration {
            out item measuredAcceleration : AccelerationSample;
        }

        state def AccelerometerState {
            state off;
            state selfTest;
            state measuring;
            state fault;

            transition first off;
            transition off_to_selfTest from off to selfTest;
            transition selfTest_to_measuring from selfTest to measuring;
            transition selfTest_to_fault from selfTest to fault;
            transition measuring_to_fault from measuring to fault;
        }
    }

    part def Gyroscope {
        attribute measurementRange : DegreePerSecond = 2000.0;
        attribute noiseDensity : DegreePerSecond = 0.005;
        attribute biasStability : DegreePerSecond = 0.8;
        attribute samplePeriod : Millisecond = 5.0;
        attribute currentDraw : Milliampere = 3.1;

        port powerIn : PowerInputPort;
        port angularRateOut : AngularRatePort;

        action sampleAngularRate {
            out item measuredAngularRate : AngularRateSample;
        }

        state def GyroscopeState {
            state off;
            state selfTest;
            state measuring;
            state fault;

            transition first off;
            transition off_to_selfTest from off to selfTest;
            transition selfTest_to_measuring from selfTest to measuring;
            transition selfTest_to_fault from selfTest to fault;
            transition measuring_to_fault from measuring to fault;
        }
    }

    part def Magnetometer {
        attribute measurementRange : Gauss = 8.0;
        attribute noiseDensity : Gauss = 0.0015;
        attribute samplePeriod : Millisecond = 20.0;
        attribute currentDraw : Milliampere = 0.6;

        port powerIn : PowerInputPort;
        port magneticFieldOut : MagneticFieldPort;

        action sampleMagneticField {
            out item measuredMagneticField : MagneticFieldSample;
        }

        state def MagnetometerState {
            state off;
            state calibrating;
            state measuring;
            state disturbed;
            state fault;

            transition first off;
            transition off_to_calibrating from off to calibrating;
            transition calibrating_to_measuring from calibrating to measuring;
            transition measuring_to_disturbed from measuring to disturbed;
            transition disturbed_to_measuring from disturbed to measuring;
            transition measuring_to_fault from measuring to fault;
        }
    }

    part def Barometer {
        attribute pressureRangeMinimum : PressureValue = 30000.0 [Pa];
        attribute pressureRangeMaximum : PressureValue = 110000.0 [Pa];
        attribute pressureNoise : PressureValue = 1.5 [Pa];
        attribute samplePeriod : Millisecond = 20.0;
        attribute currentDraw : Milliampere = 0.8;

        port powerIn : PowerInputPort;
        port barometricOut : BarometricPort;

        action sampleBarometricPressure {
            out item measuredBarometricPressure : BarometricSample;
        }

        state def BarometerState {
            state off;
            state selfTest;
            state measuring;
            state fault;

            transition first off;
            transition off_to_selfTest from off to selfTest;
            transition selfTest_to_measuring from selfTest to measuring;
            transition selfTest_to_fault from selfTest to fault;
            transition measuring_to_fault from measuring to fault;
        }
    }

    part def SensorFusionProcessor {
        attribute updatePeriod : Millisecond = 5.0;
        attribute accelerometerWeight : DimensionlessQuality = 0.35;
        attribute gyroscopeWeight : DimensionlessQuality = 0.45;
        attribute magnetometerWeight : DimensionlessQuality = 0.10;
        attribute barometerWeight : DimensionlessQuality = 0.10;
        attribute minimumConfidence : DimensionlessQuality = 0.85;
        attribute currentDraw : Milliampere = 15.0;

        port powerIn : PowerInputPort;
        port configurationIn : ConfigurationPort;
        port sensorDataIn : SensorDataInputPort;
        port poseOut : PoseOutputPort;
        port healthOut : HealthOutputPort;

        action initializeFusion {
            in item configuration : ConfigurationCommand;
            out item initialStatus : HealthStatus;
        }

        action estimateSensorBias {
            in item acceleration : AccelerationSample;
            in item angularRate : AngularRateSample;
            in item magneticField : MagneticFieldSample;
            out item status : HealthStatus;
        }

        action rejectOutliers {
            in item acceleration : AccelerationSample;
            in item angularRate : AngularRateSample;
            in item magneticField : MagneticFieldSample;
            in item barometric : BarometricSample;
            out item status : HealthStatus;
        }

        action computeFusedPose {
            in item acceleration : AccelerationSample;
            in item angularRate : AngularRateSample;
            in item magneticField : MagneticFieldSample;
            in item barometric : BarometricSample;
            out item estimate : FusedPoseEstimate;
        }

        state def FusionProcessorState {
            state unpowered;
            state booting;
            state calibrating;
            state fusing;
            state degraded;
            state fault;

            transition first unpowered;
            transition powerApplied from unpowered to booting;
            transition bootComplete from booting to calibrating;
            transition calibrationComplete from calibrating to fusing;
            transition lowConfidence from fusing to degraded;
            transition confidenceRecovered from degraded to fusing;
            transition unrecoverableFault from fusing to fault;
            transition degradedFault from degraded to fault;
        }
    }

    part def SensingUnit {
        attribute supplyVoltageNominal : Volt = 3.3;
        attribute maximumCurrentDraw : Milliampere = 30.0;
        attribute operatingTemperatureMinimum : DegreeCelsius = -40.0;
        attribute operatingTemperatureMaximum : DegreeCelsius = 85.0;
        attribute fusedUpdatePeriod : Millisecond = 5.0;
        attribute requiredConfidence : DimensionlessQuality = 0.85;

        port powerIn : PowerInputPort;
        port configurationIn : ConfigurationPort;
        port poseOut : PoseOutputPort;
        port healthOut : HealthOutputPort;

        part accelerometer : Accelerometer;
        part gyroscope : Gyroscope;
        part magnetometer : Magnetometer;
        part barometer : Barometer;
        part fusionProcessor : SensorFusionProcessor;

        connect powerIn to accelerometer.powerIn;
        connect powerIn to gyroscope.powerIn;
        connect powerIn to magnetometer.powerIn;
        connect powerIn to barometer.powerIn;
        connect powerIn to fusionProcessor.powerIn;

        connect configurationIn to fusionProcessor.configurationIn;

        connect accelerometer.accelerationOut to fusionProcessor.sensorDataIn;
        connect gyroscope.angularRateOut to fusionProcessor.sensorDataIn;
        connect magnetometer.magneticFieldOut to fusionProcessor.sensorDataIn;
        connect barometer.barometricOut to fusionProcessor.sensorDataIn;

        connect fusionProcessor.poseOut to poseOut;
        connect fusionProcessor.healthOut to healthOut;

        action operate {
            first start;
            then initializeFusion;
            then collectAcceleration;
            then collectAngularRate;
            then collectMagneticField;
            then collectBarometricPressure;
            then fuseMeasurements;
            then publishPose;
        }

        action initializeFusion {
            in item command : ConfigurationCommand;
            out item status : HealthStatus;
        }

        action collectAcceleration {
            out item acceleration : AccelerationSample;
        }

        action collectAngularRate {
            out item angularRate : AngularRateSample;
        }

        action collectMagneticField {
            out item magneticField : MagneticFieldSample;
        }

        action collectBarometricPressure {
            out item barometric : BarometricSample;
        }

        action fuseMeasurements {
            in item acceleration : AccelerationSample;
            in item angularRate : AngularRateSample;
            in item magneticField : MagneticFieldSample;
            in item barometric : BarometricSample;
            out item estimate : FusedPoseEstimate;
            out item status : HealthStatus;
        }

        action publishPose {
            in item estimate : FusedPoseEstimate;
            in item status : HealthStatus;
        }

        state def SensingUnitState {
            state off;
            state starting;
            state calibration;
            state operational;
            state degraded;
            state failed;

            transition first off;
            transition powerOn from off to starting;
            transition startupComplete from starting to calibration;
            transition calibrationValid from calibration to operational;
            transition sensorDisturbance from operational to degraded;
            transition disturbanceCleared from degraded to operational;
            transition criticalFault from operational to failed;
            transition degradedCriticalFault from degraded to failed;
            transition powerRemoved from operational to off;
            transition powerRemovedDegraded from degraded to off;
        }
    }

    requirement def PoseMeasurementRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.fusedUpdatePeriod <= 5.0
        }

        require constraint {
            sensingUnit.requiredConfidence >= 0.85
        }
    }

    requirement def FusionRequirement {
        subject sensingUnit : SensingUnit;

        doc /* The sensing unit shall compute a fused pose estimate from acceleration, angular rate, magnetic field, and barometric pressure measurements. */

        require constraint {
            sensingUnit.fusionProcessor.accelerometerWeight > 0.0 and
            sensingUnit.fusionProcessor.gyroscopeWeight > 0.0 and
            sensingUnit.fusionProcessor.magnetometerWeight > 0.0 and
            sensingUnit.fusionProcessor.barometerWeight > 0.0
        }

        require constraint {
            sensingUnit.fusionProcessor.minimumConfidence >= sensingUnit.requiredConfidence
        }
    }

    requirement def PowerRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.supplyVoltageNominal == 3.3
        }

        require constraint {
            sensingUnit.maximumCurrentDraw <= 30.0
        }
    }

    requirement def EnvironmentalRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.operatingTemperatureMinimum <= -40.0
        }

        require constraint {
            sensingUnit.operatingTemperatureMaximum >= 85.0
        }
    }

    requirement def FaultHandlingRequirement {
        subject sensingUnit : SensingUnit;

        doc /* The sensing unit shall enter degraded operation when one auxiliary sensor is disturbed and shall enter failed state when fusion confidence cannot meet the required threshold. */
    }

    part sensingUnit : SensingUnit;

    satisfy PoseMeasurementRequirement by sensingUnit;
    satisfy FusionRequirement by sensingUnit;
    satisfy PowerRequirement by sensingUnit;
    satisfy EnvironmentalRequirement by sensingUnit;
    satisfy FaultHandlingRequirement by sensingUnit;
}