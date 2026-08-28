package 'Inertial Navigation System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def AccelerationVector {
        x : AccelerationValue;
        y : AccelerationValue;
        z : AccelerationValue;
    }
    attribute def AngularVelocityVector {
        x : AngularVelocityValue;
        y : AngularVelocityValue;
        z : AngularVelocityValue;
    }
    attribute def Orientation {
        roll : AngleValue;
        pitch : AngleValue;
        yaw : AngleValue;
    }
    attribute def Position {
        x : LengthValue;
        y : LengthValue;
        z : LengthValue;
    }
    attribute def Velocity {
        x : SpeedValue;
        y : SpeedValue;
        z : SpeedValue;
    }
    attribute def NavigationSolution {
        position : Position;
        velocity : Velocity;
        orientation : Orientation;
    }
    attribute def CalibrationParameters {
        accelBias : AccelerationVector;
        gyroBias : AngularVelocityVector;
    }

    item def ElectricalPower;
    item def RawIMUData {
        acceleration : AccelerationVector;
        angularVelocity : AngularVelocityVector;
    }

    port def ElectricalPowerPort {
        power : ElectricalPower;
    }
    port def RawIMUDataPort {
        data : RawIMUData;
    }
    port def NavigationSolutionPort {
        solution : NavigationSolution;
    }
    port def CalibrationPort {
        params : CalibrationParameters;
    }

    attribute def PowerOn;
    attribute def SelfTestComplete;
    attribute def CalibrationComplete;
    attribute def InitComplete;
    attribute def StandbyCommand;
    attribute def WakeUpCommand;
    attribute def PowerOff;

    action def PerformSelfTest;
    action def ApplyCalibration;
    action def InitializeState {
        in initialPosition : Position;
        in initialVelocity : Velocity;
        in initialOrientation : Orientation;
    }
    action def ComputeNavigationSolution {
        in raw : RawIMUData;
        in calibration : CalibrationParameters;
        out solution : NavigationSolution;
    }

    part def Accelerometer {
        out acceleration : AccelerationVector;
    }
    part def Gyroscope {
        out angularVelocity : AngularVelocityVector;
    }

    part def IMU {
        port powerPort : ElectricalPowerPort;
        part accelerometers : Accelerometer[3];
        part gyroscopes : Gyroscope[3];
        port dataPort : RawIMUDataPort;
    }

    part def NavigationProcessor {
        port powerPort : ElectricalPowerPort;
        port dataPort : RawIMUDataPort;
        port calibrationPort : CalibrationPort;
        port solutionPort : NavigationSolutionPort;
        attribute frequency : FrequencyValue = 100 [Hz];
    }

    part def PowerManagementUnit {
        port powerPort : ElectricalPowerPort;
    }

    state def INSStates;

    part def INS {
        part imu : IMU;
        part processor : NavigationProcessor;
        part pmu : PowerManagementUnit;

        connect pmu.powerPort to imu.powerPort;
        connect pmu.powerPort to processor.powerPort;
        connect imu.dataPort to processor.dataPort;

        exhibit state insStates : INSStates {
            entry; then PoweredOff;
            state PoweredOff;
            accept PowerOn then SelfTest;
            state SelfTest {
                entry action performSelfTest : PerformSelfTest;
            }
            accept SelfTestComplete then Calibration;
            state Calibration {
                entry action applyCalibration : ApplyCalibration;
            }
            accept CalibrationComplete then Initialization;
            state Initialization {
                entry action initializeState : InitializeState;
            }
            accept InitComplete then Navigation;
            state Navigation {
                do action computeSolution : ComputeNavigationSolution;
            }
            accept StandbyCommand then Standby;
            state Standby;
            accept WakeUpCommand then Navigation;
            accept PowerOff then PoweredOff;
        }
    }

    requirement def INSRequirement {
        subject ins : INS;
        require constraint { ins.processor.frequency >= 100 [Hz] }
    }
}
