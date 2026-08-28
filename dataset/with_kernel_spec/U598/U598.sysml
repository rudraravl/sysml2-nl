package 'Meteorological Anemometer System' {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::Real;

    item def VoltageSignal {
        attribute value : ElectricPotentialValue;
    }

    item def WindMeasurement {
        attribute timestamp : TimeValue;
        attribute speed : SpeedValue;
        attribute direction : PlaneAngleValue;
    }

    port def VoltagePort {
        in signal : VoltageSignal;
    }

    port def MeasurementPort {
        in measurement : WindMeasurement;
    }

    port def RotationRatePort {
        in rotationRate : Real;
    }

    port def OrientationPort {
        in orientation : PlaneAngleValue;
    }

    action def AcquireSensorData {
        in speedSignal : VoltageSignal;
        in directionSignal : VoltageSignal;
        out rawSpeed : ElectricPotentialValue;
        out rawDirection : ElectricPotentialValue;
    }

    action def ComputeWindMeasurement {
        in rawSpeed : ElectricPotentialValue;
        in rawDirection : ElectricPotentialValue;
        in speedFactor : Real;
        in dirOffset : PlaneAngleValue;
        out speed : SpeedValue;
        out direction : PlaneAngleValue;
    }

    action def OutputMeasurement {
        in speed : SpeedValue;
        in direction : PlaneAngleValue;
        out measurement : WindMeasurement;
    }

    action def MeasurementCycle {
        in speedSignal : VoltageSignal;
        in directionSignal : VoltageSignal;
        in speedFactor : Real;
        in dirOffset : PlaneAngleValue;
        out measurement : WindMeasurement;

        action acquire : AcquireSensorData;
        then action compute : ComputeWindMeasurement;
        then action output : OutputMeasurement;

        flow acquire.rawSpeed to compute.rawSpeed;
        flow acquire.rawDirection to compute.rawDirection;
        flow compute.speed to output.speed;
        flow compute.direction to output.direction;
    }

    state machine def ProcessorControl {
        state Off;
        state Initializing;
        state Running;
        state Fault;

        transition Off -> Initializing;
        transition Initializing -> Running;
        transition Running -> Fault;
        transition Fault -> Off;
    }

    part def CupAssembly {
        port out rotationPort : ~RotationRatePort;
    }

    part def VaneAssembly {
        port out orientationPort : ~OrientationPort;
    }

    part def RotationSensor {
        port in shaftPort : RotationRatePort;
        port out voltage : ~VoltagePort;
    }

    part def AngleSensor {
        port in vanePort : OrientationPort;
        port out voltage : ~VoltagePort;
    }

    part def DataProcessor {
        port in speedVoltageIn : VoltagePort;
        port in directionVoltageIn : VoltagePort;
        port out measurementOut : ~MeasurementPort;
        attribute speedConversionFactor : Real;
        attribute directionOffset : PlaneAngleValue;

        perform MeasurementCycle {
            in speedSignal :>> speedVoltageIn.signal;
            in directionSignal :>> directionVoltageIn.signal;
            in speedFactor :>> speedConversionFactor;
            in dirOffset :>> directionOffset;
            out measurement :>> measurementOut.measurement;
        }
        perform ProcessorControl;
    }

    part def Anemometer {
        port out measurement : ~MeasurementPort;

        part cups : CupAssembly;
        part vane : VaneAssembly;
        part rotationSensor : RotationSensor;
        part angleSensor : AngleSensor;
        part processor : DataProcessor;

        connect cups.rotationPort to rotationSensor.shaftPort;
        connect vane.orientationPort to angleSensor.vanePort;
        connect rotationSensor.voltage to processor.speedVoltageIn;
        connect angleSensor.voltage to processor.directionVoltageIn;
        connect processor.measurementOut to measurement;
    }

    requirement def WindSpeedAccuracyRequirement {
        attribute maxError : SpeedValue;
        constraint speedLimit { maxError <= 0.5 [m/s] }
    }

    requirement def WindDirectionAccuracyRequirement {
        attribute maxError : PlaneAngleValue;
        constraint directionLimit { maxError <= 5 [deg] }
    }

    requirement def OperatingEnvironmentRequirement {
        attribute minTemp : ThermodynamicTemperatureValue;
        attribute maxTemp : ThermodynamicTemperatureValue;
        attribute maxWindSpeed : SpeedValue;
        constraint tempRange { minTemp >= 233.15 [K] and maxTemp <= 333.15 [K] }
        constraint windRange { maxWindSpeed >= 75 [m/s] }
    }

    requirement speedAccuracy : WindSpeedAccuracyRequirement {
        :>> maxError = 0.5 [m/s];
    }

    requirement directionAccuracy : WindDirectionAccuracyRequirement {
        :>> maxError = 5 [deg];
    }

    requirement operatingEnvironment : OperatingEnvironmentRequirement {
        :>> minTemp = 233.15 [K];
        :>> maxTemp = 333.15 [K];
        :>> maxWindSpeed = 75 [m/s];
    }

    part anemometerSystem : Anemometer {
        satisfy speedAccuracy;
        satisfy directionAccuracy;
        satisfy operatingEnvironment;
    }
}
