package AttitudeIndicatorSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----

    value def Angle :> Real {
        unit unit(deg);
    }

    value def AngularRate :> Real {
        unit unit(deg / s);
    }

    value def AccelerationValue :> Real {
        unit unit(m / s**2);
    }

    value def Voltage :> Real {
        unit unit(V);
    }

    value def Frequency :> Real {
        unit unit(Hz);
    }

    value def Power :> Real {
        unit unit(W);
    }

    value def TimeValue :> Real {
        unit unit(s);
    }

    // ---- Item definitions ----

    item def GyroData {
        attribute pitchRate : AngularRate;
        attribute rollRate : AngularRate;
        attribute yawRate : AngularRate;
        attribute timestamp : TimeValue;
    }

    item def AccelData {
        attribute xAccel : AccelerationValue;
        attribute yAccel : AccelerationValue;
        attribute zAccel : AccelerationValue;
        attribute timestamp : TimeValue;
    }

    item def AttitudeSolution {
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def DisplayCommand {
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute brightness : Real;
        attribute updateFlag : Boolean;
    }

    item def PowerStatus {
        attribute inputVoltage : Voltage;
        attribute regulatedVoltage : Voltage;
        attribute powerGood : Boolean;
        attribute selfTestPassed : Boolean;
    }

    item def PowerDemand {
        attribute voltage : Voltage;
        attribute current : Real;
    }

    // ---- Port definitions ----

    port def GyroDataOut {
        out item : GyroData;
    }

    port def GyroDataIn {
        in item : GyroData;
    }

    port def AccelDataOut {
        out item : AccelData;
    }

    port def AccelDataIn {
        in item : AccelData;
    }

    port def AttitudeOut {
        out item : AttitudeSolution;
    }

    port def AttitudeIn {
        in item : AttitudeSolution;
    }

    port def DisplayCmdOut {
        out item : DisplayCommand;
    }

    port def DisplayCmdIn {
        in item : DisplayCommand;
    }

    port def PowerOut {
        out item : PowerStatus;
    }

    port def PowerIn {
        in item : PowerStatus;
    }

    port def RawPowerIn {
        in attribute voltage : Voltage;
    }

    port def RawPowerOut {
        out attribute voltage : Voltage;
    }

    // ---- Requirements ----

    requirement def ProvideAttitudeIndication {
        subject : AttitudeIndicator;
        objective {
            doc /* The attitude indicator shall provide a real-time visual representation of aircraft pitch and roll relative to the horizon. */
        }
    }

    requirement def MeasurePitchAndRollRate {
        subject : RateGyroscope;
        objective {
            doc /* The rate gyroscope shall measure pitch rate and roll rate of the aircraft. */
        }
    }

    requirement def MeasureGravityReference {
        subject : ThreeAxisAccelerometer;
        objective {
            doc /* The three-axis accelerometer shall measure linear accelerations to determine the gravity reference direction. */
        }
    }

    requirement def FuseSensorData {
        subject : AttitudeComputer;
        objective {
            doc /* The attitude computer shall fuse gyroscope and accelerometer data using a complementary filter to compute pitch and roll angles. */
        }
    }

    requirement def DisplayAttitude {
        subject : HorizonDisplay;
        objective {
            doc /* The horizon display shall present pitch and roll using a moving horizon, pitch ladder, and roll scale. */
        }
    }

    requirement def RegulatePower {
        subject : PowerManagementUnit;
        objective {
            doc /* The power management unit shall regulate 28V DC input and distribute stable voltage to all subsystems. */
        }
    }

    requirement def SupportOperationalStates {
        subject : AttitudeIndicator;
        objective {
            doc /* The system shall support off, self-test, normal, and degraded operational states. */
        }
    }

    requirement def UpdateRate {
        subject : HorizonDisplay;
        attribute minUpdateRate : Frequency = 60 [Hz];
        objective {
            doc /* The display shall update at least 60 times per second. */
        }
    }

    // ---- Part definitions ----

    part def RateGyroscope {
        port gyroOut : GyroDataOut;
        port powerPort : PowerIn;

        attribute sampleRate : Frequency = 200 [Hz];
        attribute noiseFloor : AngularRate = 0.01 [deg/s];

        action def SenseRotation {
            in currentPitchRate : AngularRate;
            in currentRollRate : AngularRate;
            in currentYawRate : AngularRate;
            out data : GyroData;
        }

        perform SenseRotation continuously {
            in currentPitchRate = 0 [deg/s];
            in currentRollRate = 0 [deg/s];
            in currentYawRate = 0 [deg/s];
            out data = gyroOut.item;
        }

        satisfy MeasurePitchAndRollRate;
    }

    part def ThreeAxisAccelerometer {
        port accelOut : AccelDataOut;
        port powerPort : PowerIn;

        attribute sampleRate : Frequency = 100 [Hz];
        attribute gravityRef : AccelerationValue = 9.80665 [m/s^2];

        action def SenseAcceleration {
            in x : AccelerationValue;
            in y : AccelerationValue;
            in z : AccelerationValue;
            out data : AccelData;
        }

        perform SenseAcceleration continuously {
            in x = 0 [m/s^2];
            in y = 0 [m/s^2];
            in z = gravityRef;
            out data = accelOut.item;
        }

        satisfy MeasureGravityReference;
    }

    part def AttitudeComputer {
        port gyroIn : GyroDataIn;
        port accelIn : AccelDataIn;
        port attitudeOut : AttitudeOut;
        port powerPort : PowerIn;

        attribute filterCoefficient : Real = 0.98;
        attribute computedPitch : Angle = 0 [deg];
        attribute computedRoll : Angle = 0 [deg];
        attribute lastTimestamp : TimeValue = 0 [s];
        attribute sensorHealthy : Boolean = true;

        action def FuseData {
            in gyro : GyroData;
            in accel : AccelData;
            in prevPitch : Angle;
            in prevRoll : Angle;
            in alpha : Real;
            out solution : AttitudeSolution;
        }

        action def DetectSensorFault {
            in gyro : GyroData;
            in accel : AccelData;
            out faultDetected : Boolean;
        }

        perform FuseData {
            in gyro = gyroIn.item;
            in accel = accelIn.item;
            in prevPitch = computedPitch;
            in prevRoll = computedRoll;
            in alpha = filterCoefficient;
            out solution = attitudeOut.item;
        }

        perform DetectSensorFault {
            in gyro = gyroIn.item;
            in accel = accelIn.item;
            out faultDetected = sensorHealthy;
        }

        satisfy FuseSensorData;
    }

    part def HorizonDisplay {
        port displayIn : AttitudeIn;
        port powerPort : PowerIn;

        attribute updateRate : Frequency = 60 [Hz];
        attribute brightness : Real = 1.0;
        attribute currentPitch : Angle = 0 [deg];
        attribute currentRoll : Angle = 0 [deg];

        action def RenderHorizon {
            in pitch : Angle;
            in roll : Angle;
            in brightnessLevel : Real;
        }

        perform RenderHorizon at updateRate {
            in pitch = displayIn.item.pitch;
            in roll = displayIn.item.roll;
            in brightnessLevel = brightness;
        }

        satisfy DisplayAttitude;
        satisfy UpdateRate;
    }

    part def PowerManagementUnit {
        port rawPower : RawPowerIn;
        port powerStatus : PowerOut;
        port gyroPower : PowerOut;
        port accelPower : PowerOut;
        port computerPower : PowerOut;
        port displayPower : PowerOut;

        attribute nominalInput : Voltage = 28 [V];
        attribute regulatedOutput : Voltage = 5 [V];
        attribute lowVoltageThreshold : Voltage = 22 [V];
        attribute selfTestComplete : Boolean = false;
        attribute selfTestResult : Boolean = true;

        action def RunSelfTest {
            in inputV : Voltage;
            out passed : Boolean;
        }

        action def RegulateVoltage {
            in inputV : Voltage;
            out outputV : Voltage;
            out powerGood : Boolean;
        }

        action def MonitorInput {
            in inputV : Voltage;
            out lowPower : Boolean;
        }

        perform RunSelfTest {
            in inputV = rawPower.voltage;
            out passed = selfTestResult;
        }

        perform RegulateVoltage continuously {
            in inputV = rawPower.voltage;
            out outputV = regulatedOutput;
            out powerGood = (rawPower.voltage >= lowVoltageThreshold);
        }

        perform MonitorInput continuously {
            in inputV = rawPower.voltage;
            out lowPower = (rawPower.voltage < lowVoltageThreshold);
        }

        satisfy RegulatePower;
    }

    // ---- System-level part ----

    part def AttitudeIndicator {

        port aircraftPower : RawPowerIn;

        part rateGyro : RateGyroscope;
        part accelerometer : ThreeAxisAccelerometer;
        part computer : AttitudeComputer;
        part display : HorizonDisplay;
        part pmu : PowerManagementUnit;

        // Power distribution connections
        connection rawPowerFeed connect aircraftPower to pmu.rawPower;

        connection pmuToGyroPower connect pmu.gyroPower to rateGyro.powerPort;
        connection pmuToAccelPower connect pmu.accelPower to accelerometer.powerPort;
        connection pmuToComputerPower connect pmu.computerPower to computer.powerPort;
        connection pmuToDisplayPower connect pmu.displayPower to display.powerPort;

        // Data flow connections
        connection gyroToComputer connect rateGyro.gyroOut to computer.gyroIn;
        connection accelToComputer connect accelerometer.accelOut to computer.accelIn;
        connection computerToDisplay connect computer.attitudeOut to display.displayIn;

        // System state machine
        state def AttitudeIndicatorStates {
            entry;
            off;
            selfTest;
            normal;
            degraded;
        }

        state machine AttitudeIndicatorStateMachine {

            state off {
                entry {
                    doc /* System is unpowered. */
                }
            }

            state selfTest {
                entry {
                    doc /* Power management unit runs self-test; sensors and display initialize. */
                }
                do perform pmu.RunSelfTest;
            }

            state normal {
                entry {
                    doc /* All subsystems operational; attitude data flows continuously. */
                }
                do perform rateGyro.SenseRotation;
                do perform accelerometer.SenseAcceleration;
                do perform computer.FuseData;
                do perform display.RenderHorizon;
            }

            state degraded {
                entry {
                    doc /* A sensor fault has been detected; system operates with reduced accuracy. */
                }
                do perform computer.DetectSensorFault;
            }

            transition off_to_selfTest
                first off
                if aircraftPower.voltage > 0 [V]
                then selfTest;

            transition selfTest_to_normal
                from selfTest
                if pmu.selfTestResult == true
                then normal;

            transition selfTest_to_off
                from selfTest
                if pmu.selfTestResult == false
                then off;

            transition normal_to_degraded
                from normal
                if computer.sensorHealthy == false
                then degraded;

            transition degraded_to_normal
                from degraded
                if computer.sensorHealthy == true
                then normal;

            transition any_to_off
                from normal
                if aircraftPower.voltage == 0 [V]
                then off;
        }

        exhibit AttitudeIndicatorStateMachine;

        satisfy ProvideAttitudeIndication;
        satisfy SupportOperationalStates;
    }

    // ---- Instantiated system ----

    part attitudeIndicator : AttitudeIndicator {
        port aircraftPower : RawPowerIn {
            attribute voltage : Voltage = 28 [V];
        }
    }

}
