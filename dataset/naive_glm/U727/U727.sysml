package INSModel {

    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value type AccelerationValue :> Real { doc "Linear acceleration, m/s^2"; }
    value type AngularVelocityValue :> Real { doc "Angular velocity, rad/s"; }
    value type VelocityValue :> Real { doc "Linear velocity, m/s"; }
    value type PositionValue :> Real { doc "Position, m"; }
    value type AngleValue :> Real { doc "Angle, rad"; }
    value type TimeValue :> Real { doc "Time, s"; }
    value type VoltageValue :> Real { doc "Voltage, V"; }
    value type CurrentValue :> Real { doc "Current, A"; }
    value type PowerValue :> Real { doc "Power, W"; }
    value type FrequencyValue :> Real { doc "Frequency, Hz"; }
    value type TemperatureValue :> Real { doc "Temperature, degC"; }

    // ===== Item Definitions =====
    item def AccelVector {
        attribute x : AccelerationValue;
        attribute y : AccelerationValue;
        attribute z : AccelerationValue;
    }

    item def AngularVelocityVector {
        attribute x : AngularVelocityValue;
        attribute y : AngularVelocityValue;
        attribute z : AngularVelocityValue;
    }

    item def PositionVector {
        attribute x : PositionValue;
        attribute y : PositionValue;
        attribute z : PositionValue;
    }

    item def VelocityVector {
        attribute x : VelocityValue;
        attribute y : VelocityValue;
        attribute z : VelocityValue;
    }

    item def Orientation {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def RawSensorData {
        attribute acceleration : AccelVector;
        attribute angularRate : AngularVelocityVector;
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeValue;
    }

    item def CalibrationParameters {
        attribute accelBias : AccelVector;
        attribute gyroBias : AngularVelocityVector;
        attribute accelScale1 : Real;
        attribute accelScale2 : Real;
        attribute accelScale3 : Real;
        attribute gyroScale1 : Real;
        attribute gyroScale2 : Real;
        attribute gyroScale3 : Real;
    }

    item def NavSolution {
        attribute position : PositionVector;
        attribute velocity : VelocityVector;
        attribute orientation : Orientation;
        attribute timestamp : TimeValue;
    }

    item def InitState {
        attribute position : PositionVector;
        attribute velocity : VelocityVector;
        attribute orientation : Orientation;
    }

    item def Power {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def SystemStatus {
        attribute mode : String;
        attribute healthy : Boolean;
        attribute errorCode : Integer;
        attribute message : String;
    }

    item def ControlCommand {
        attribute command : String;
        attribute value : String;
    }

    // ===== Port Definitions =====
    port def RawSensorDataPort {
        out raw : RawSensorData;
    }

    port def NavSolutionPort {
        out solution : NavSolution;
    }

    port def InitDataPort {
        in init : InitState;
    }

    port def PowerInPort {
        in power : Power;
    }

    port def PowerOutPort {
        out power : Power;
    }

    port def StatusPort {
        out status : SystemStatus;
    }

    port def CommandPort {
        in command : ControlCommand;
    }

    // ===== Accelerometer =====
    part def Accelerometer {
        attribute id : String;
        attribute axis : String;
        attribute sampleRate : FrequencyValue;
        attribute range : AccelerationValue;
        attribute bias : AccelerationValue;
        attribute noiseDensity : Real;
        port sensorOut : RawSensorDataPort;
        port powerIn : PowerInPort;

        action def measure {
            out reading : AccelerationValue;
        }

        action def zeroBiasCalibrate {
            in samples : AccelerationValue[0..*];
            return biasEstimate : AccelerationValue;
        }
    }

    // ===== Gyroscope =====
    part def Gyroscope {
        attribute id : String;
        attribute axis : String;
        attribute sampleRate : FrequencyValue;
        attribute range : AngularVelocityValue;
        attribute bias : AngularVelocityValue;
        attribute noiseDensity : Real;
        port sensorOut : RawSensorDataPort;
        port powerIn : PowerInPort;

        action def measure {
            out reading : AngularVelocityValue;
        }

        action def zeroBiasCalibrate {
            in samples : AngularVelocityValue[0..*];
            return biasEstimate : AngularVelocityValue;
        }
    }

    // ===== Inertial Measurement Unit =====
    part def IMU {
        part accelX : Accelerometer {
            attribute id : String = "A1";
            attribute axis : String = "X";
            attribute sampleRate : FrequencyValue = 100.0;
            attribute range : AccelerationValue = 20.0;
            attribute bias : AccelerationValue = 0.05;
        }
        part accelY : Accelerometer {
            attribute id : String = "A2";
            attribute axis : String = "Y";
            attribute sampleRate : FrequencyValue = 100.0;
            attribute range : AccelerationValue = 20.0;
            attribute bias : AccelerationValue = 0.05;
        }
        part accelZ : Accelerometer {
            attribute id : String = "A3";
            attribute axis : String = "Z";
            attribute sampleRate : FrequencyValue = 100.0;
            attribute range : AccelerationValue = 20.0;
            attribute bias : AccelerationValue = 0.05;
        }
        part gyroX : Gyroscope {
            attribute id : String = "G1";
            attribute axis : String = "X";
            attribute sampleRate : FrequencyValue = 100.0;
            attribute range : AngularVelocityValue = 5.0;
            attribute bias : AngularVelocityValue = 0.01;
        }
        part gyroY : Gyroscope {
            attribute id : String = "G2";
            attribute axis : String = "Y";
            attribute sampleRate : FrequencyValue = 100.0;
            attribute range : AngularVelocityValue = 5.0;
            attribute bias : AngularVelocityValue = 0.01;
        }
        part gyroZ : Gyroscope {
            attribute id : String = "G3";
            attribute axis : String = "Z";
            attribute sampleRate : FrequencyValue = 100.0;
            attribute range : AngularVelocityValue = 5.0;
            attribute bias : AngularVelocityValue = 0.01;
        }

        port sensorDataOut : RawSensorDataPort;
        port powerIn : PowerInPort;
        port statusOut : StatusPort;

        action def assembleRawData {
            in ax : AccelerationValue;
            in ay : AccelerationValue;
            in az : AccelerationValue;
            in gx : AngularVelocityValue;
            in gy : AngularVelocityValue;
            in gz : AngularVelocityValue;
            in temp : TemperatureValue;
            in ts : TimeValue;
            return raw : RawSensorData;
        }

        action def readAllSensors {
            out raw : RawSensorData;
        }

        action def performSelfTest {
            return status : SystemStatus;
        }

        action update {
            out raw : RawSensorData;
        }
    }

    // ===== Navigation Processor =====
    part def NavigationProcessor {
        port rawIn : RawSensorDataPort;
        port navOut : NavSolutionPort;
        port initIn : InitDataPort;
        port statusOut : StatusPort;
        port powerIn : PowerInPort;

        attribute calibration : CalibrationParameters;
        attribute updateRate : FrequencyValue = 100.0;
        attribute currentSolution : NavSolution;
        attribute initialized : Boolean = false;
        attribute lastTimestamp : TimeValue;
        attribute deltaTime : TimeValue = 0.01;
        attribute gravity : AccelerationValue = 9.81;

        action def applyCalibration {
            in raw : RawSensorData;
            in cal : CalibrationParameters;
            return corrected : RawSensorData;
        }

        action def integrateAcceleration {
            in accel : AccelVector;
            in dt : TimeValue;
            in previousVel : VelocityVector;
            in gravityComp : AccelerationValue;
            return newVel : VelocityVector;
        }

        action def integrateVelocity {
            in vel : VelocityVector;
            in dt : TimeValue;
            in previousPos : PositionVector;
            return newPos : PositionVector;
        }

        action def integrateGyro {
            in angVel : AngularVelocityVector;
            in dt : TimeValue;
            in previousOrient : Orientation;
            return newOrient : Orientation;
        }

        action def computeSolution {
            in raw : RawSensorData;
            in dt : TimeValue;
            return solution : NavSolution;
        }

        action def initialize {
            in init : InitState;
        }

        action def loadCalibration {
            in cal : CalibrationParameters;
        }

        action update {
            in raw : RawSensorData;
            out solution : NavSolution;
        }
    }

    // ===== Power Management Unit =====
    part def PowerManagementUnit {
        port powerIn : PowerInPort;
        port imuPowerOut : PowerOutPort;
        port procPowerOut : PowerOutPort;
        port statusOut : StatusPort;

        attribute inputVoltage : VoltageValue;
        attribute imuVoltage : VoltageValue = 5.0;
        attribute procVoltage : VoltageValue = 3.3;
        attribute maxOutputCurrent : CurrentValue = 5.0;
        attribute efficiency : Real = 0.92;
        attribute inputFrequency : FrequencyValue = 0.0;

        action def regulate {
            in raw : Power;
            return regulated : Power;
        }

        action def distribute {
            in regulated : Power;
            out imuPower : Power;
            out procPower : Power;
        }

        action def monitor {
            return status : SystemStatus;
        }

        action def shutdownPower {
            out status : SystemStatus;
        }
    }

    // ===== Top-Level Inertial Navigation System =====
    part def InertialNavigationSystem {
        part imu : IMU;
        part navProc : NavigationProcessor;
        part pmu : PowerManagementUnit;

        port systemPowerIn : PowerInPort;
        port navOutput : NavSolutionPort;
        port initInput : InitDataPort;
        port commandInput : CommandPort;
        port statusOutput : StatusPort;

        connection imu2proc : imu.sensorDataOut <> navProc.rawIn;
        connection pmuImu : pmu.imuPowerOut <> imu.powerIn;
        connection pmuProc : pmu.procPowerOut <> navProc.powerIn;
        connection sys2pmu : systemPowerIn <> pmu.powerIn;
        connection init2proc : initInput <> navProc.initIn;
        connection navOut2sys : navProc.navOut <> navOutput;
        connection imu2status : imu.statusOut <> statusOutput;
        connection procStatus2sys : navProc.statusOut <> statusOutput;
        connection pmu2status : pmu.statusOut <> statusOutput;
    }

    // ===== State Machine =====
    state def InertialNavigationSystemState {
        state PoweredOff {
            entry action PowerDown;
            do action WaitForPower;
        }
        state SelfTest {
            entry action RunSelfTest;
            do action PerformDiagnostics;
            exit action ReportSelfTestResult;
        }
        state Calibration {
            entry action LoadCalibration;
            do action ApplyCalibrationParameters;
            exit action ReportCalibrationComplete;
        }
        state Initialization {
            entry action ReceiveInitState;
            do action WaitForInitData;
            exit action StoreInitialState;
        }
        state Navigation {
            entry action StartNavigation;
            do action ContinuouslyOutputNavSolution;
        }
        state Standby {
            entry action EnterLowPower;
            do action ConservePower;
        }
        state Shutdown {
            entry action BeginShutdown;
            do action FlushOutputs;
            exit action RemovePower;
        }

        transition from PoweredOff to SelfTest when powerApplied;
        transition from SelfTest to Calibration when selfTestPassed;
        transition from SelfTest to PoweredOff when selfTestFailed;
        transition from Calibration to Initialization when calibrationApplied;
        transition from Calibration to PoweredOff when calibrationFailed;
        transition from Initialization to Navigation when initReceived;
        transition from Initialization to Calibration when initTimeout;
        transition from Navigation to Standby when standbyCommand;
        transition from Standby to Navigation when resumeCommand;
        transition from Navigation to Shutdown when shutdownCommand;
        transition from Standby to Shutdown when shutdownCommand;
        transition from Shutdown to PoweredOff when powerRemoved;
    }

    part ins : InertialNavigationSystem {
        state operatingState : InertialNavigationSystemState;
        attribute operatingMode : String;
        attribute uptime : TimeValue;
    }

    // ===== Requirements =====
    requirement def SelfContainedNavReq {
        subject ins : InertialNavigationSystem;
        doc "The INS shall determine the vehicle's position, velocity, and orientation (roll, pitch, yaw) without external references such as GPS.";
        require ins.navOutput != null;
        require ins.initInput != null;
    }

    requirement def IMUThreeAxesReq {
        subject imu : IMU;
        doc "The IMU shall contain three accelerometers and three gyroscopes mounted at right angles along the X, Y, and Z axes.";
        require imu.accelX.axis == "X";
        require imu.accelY.axis == "Y";
        require imu.accelZ.axis == "Z";
        require imu.gyroX.axis == "X";
        require imu.gyroY.axis == "Y";
        require imu.gyroZ.axis == "Z";
    }

    requirement def IMUSampleRateReq {
        subject imu : IMU;
        doc "Each accelerometer and gyroscope shall sample at least at 100 Hz.";
        require imu.accelX.sampleRate >= 100.0;
        require imu.accelY.sampleRate >= 100.0;
        require imu.accelZ.sampleRate >= 100.0;
        require imu.gyroX.sampleRate >= 100.0;
        require imu.gyroY.sampleRate >= 100.0;
        require imu.gyroZ.sampleRate >= 100.0;
    }

    requirement def RawDataReq {
        subject imu : IMU;
        doc "The IMU shall provide a continuous stream of raw acceleration and angular velocity data via the sensor data port.";
        require imu.sensorDataOut != null;
    }

    requirement def NavProcUpdateRateReq {
        subject np : NavigationProcessor;
        doc "The Navigation Processor shall produce a navigation solution at 100 Hz.";
        require np.updateRate == 100.0;
    }

    requirement def NavProcIntegrationReq {
        subject np : NavigationProcessor;
        doc "The Navigation Processor shall integrate raw acceleration and angular rate data, starting from a known initial position and orientation, to compute position, velocity, and orientation.";
        require np.calibration != null;
        require np.currentSolution != null;
    }

    requirement def CalibrationReq {
        subject np : NavigationProcessor;
        doc "The Navigation Processor shall apply pre-loaded calibration parameters to correct for known inaccuracies and biases in the physical sensors.";
        require np.calibration.accelBias != null;
        require np.calibration.gyroBias != null;
    }

    requirement def PowerStabilityReq {
        subject pmu : PowerManagementUnit;
        doc "The Power Management Unit shall provide stable, regulated electrical power to the IMU and the Navigation Processor.";
        require pmu.imuVoltage == 5.0;
        require pmu.procVoltage == 3.3;
        require pmu.maxOutputCurrent >= 5.0;
    }

    requirement def PowerInputReq {
        subject pmu : PowerManagementUnit;
        doc "The Power Management Unit shall accept a vehicle power input of 28 V nominal.";
        require pmu.inputVoltage <= 32.0;
        require pmu.inputVoltage >= 18.0;
    }

    requirement def LifecycleReq {
        subject ins : InertialNavigationSystem;
        doc "The INS shall transition through the lifecycle states: power-on (self-test), calibration, initialization, and navigation, with standby and shutdown options.";
        require ins.operatingState != null;
    }

    requirement def NavOutputReq {
        subject ins : InertialNavigationSystem;
        doc "The INS shall continuously output the calculated navigation solution, including position, velocity, and orientation, during navigation mode.";
        require ins.navOutput != null;
    }

    // ===== Verification Definitions =====
    verification def IMUAxesVerification {
        subject imu : IMU;
        objective {
            doc "Verify that the IMU contains three accelerometers and three gyroscopes, one per orthogonal axis.";
        }
    }

    verification def NavUpdateRateVerification {
        subject np : NavigationProcessor;
        objective {
            doc "Verify that the navigation processor updates the navigation solution at 100 Hz.";
        }
    }

    verification def PowerRegulationVerification {
        subject pmu : PowerManagementUnit;
        objective {
            doc "Verify that the power management unit regulates input voltage to the required IMU and processor supply rails.";
        }
    }

    verification def LifecycleVerification {
        subject ins : InertialNavigationSystem;
        objective {
            doc "Verify that the INS correctly transitions through the lifecycle states under all commanded events.";
        }
    }
}
