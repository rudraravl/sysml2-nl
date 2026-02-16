package 'AttitudeIndicatorSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PitchAngle :> ISQ::planeAngleValue {
        doc /* Aircraft rotation about lateral axis (nose up/down relative to horizon) */
    }

    attribute def RollAngle :> ISQ::planeAngleValue {
        doc /* Aircraft rotation about longitudinal axis (wing up/down relative to horizon) */
    }

    attribute def AngularRate :> ISQ::angularVelocityValue {
        doc /* Rate of angular change measured by gyroscope */
    }

    attribute def LinearAcceleration :> ISQ::accelerationValue {
        doc /* Linear acceleration measured by accelerometer */
    }

    attribute def DisplayBrightness :> Real {
        doc /* Normalized brightness level from 0.0 to 1.0 */
    }

    attribute def SupplyVoltage :> ISQ::electricPotentialValue {
        doc /* Electrical supply voltage for system components */
    }

    enum def SystemMode {
        off;
        selfTest;
        operational;
        degraded;
        failed;
    }

    item def GyroMeasurement {
        attribute pitchRate : AngularRate;
        attribute rollRate : AngularRate;
        attribute timestamp : ISQ::timeValue;
    }

    item def AccelMeasurement {
        attribute xAccel : LinearAcceleration;
        attribute yAccel : LinearAcceleration;
        attribute zAccel : LinearAcceleration;
        attribute timestamp : ISQ::timeValue;
    }

    item def AttitudeData {
        attribute pitch : PitchAngle;
        attribute roll : RollAngle;
        attribute timestamp : ISQ::timeValue;
        attribute quality : Real;
    }

    port def GyroDataPort {
        out gyroData : GyroMeasurement;
    }

    port def AccelDataPort {
        out accelData : AccelMeasurement;
    }

    port def AttitudeOutputPort {
        out attitude : AttitudeData;
    }

    port def PowerPort {
        in voltage : SupplyVoltage;
        in current : ISQ::electricCurrentValue;
    }

    part def RateGyroscope {
        doc /* Measures angular rotation rates about aircraft axes */
        attribute sampleRate : ISQ::frequencyValue;
        attribute driftRate : AngularRate;
        port gyroOut : GyroDataPort;
        port power : PowerPort;

        action measureRates {
            out measurement : GyroMeasurement;
        }
    }

    part def ThreeAxisAccelerometer {
        doc /* Measures linear acceleration along three orthogonal axes */
        attribute sensitivity : Real;
        attribute noiseLevel : LinearAcceleration;
        port accelOut : AccelDataPort;
        port power : PowerPort;

        action measureAcceleration {
            out measurement : AccelMeasurement;
        }
    }

    part def AttitudeComputer {
        doc /* Fuses sensor data to compute aircraft attitude */
        attribute filterGain : Real;
        attribute currentPitch : PitchAngle;
        attribute currentRoll : RollAngle;
        attribute mode : SystemMode;

        port gyroIn : ~GyroDataPort;
        port accelIn : ~AccelDataPort;
        port attitudeOut : AttitudeOutputPort;
        port power : PowerPort;

        action def IntegrateGyroData {
            in gyroMeasurement : GyroMeasurement;
            in previousPitch : PitchAngle;
            in previousRoll : RollAngle;
            in deltaTime : ISQ::timeValue;
            out integratedPitch : PitchAngle;
            out integratedRoll : RollAngle;
        }

        action def ComputeGravityVector {
            in accelMeasurement : AccelMeasurement;
            out gravityPitch : PitchAngle;
            out gravityRoll : RollAngle;
        }

        action def ApplyComplementaryFilter {
            in gyroPitch : PitchAngle;
            in gyroRoll : RollAngle;
            in accelPitch : PitchAngle;
            in accelRoll : RollAngle;
            in alpha : Real;
            out fusedPitch : PitchAngle;
            out fusedRoll : RollAngle;
        }

        action computeAttitude {
            in gyroData : GyroMeasurement;
            in accelData : AccelMeasurement;
            out attitude : AttitudeData;

            private attribute dt : ISQ::timeValue;
            private attribute filterCoeff : Real := 0.98;

            first start;
            then action integrate : IntegrateGyroData {
                in gyroMeasurement = gyroData;
                in previousPitch = currentPitch;
                in previousRoll = currentRoll;
                in deltaTime = dt;
                out integratedPitch;
                out integratedRoll;
            }
            then action computeGravity : ComputeGravityVector {
                in accelMeasurement = accelData;
                out gravityPitch;
                out gravityRoll;
            }
            then action applyFilter : ApplyComplementaryFilter {
                in gyroPitch = integrate.integratedPitch;
                in gyroRoll = integrate.integratedRoll;
                in accelPitch = computeGravity.gravityPitch;
                in accelRoll = computeGravity.gravityRoll;
                in alpha = filterCoeff;
                out fusedPitch;
                out fusedRoll;
            }
            then assign currentPitch := applyFilter.fusedPitch;
            then assign currentRoll := applyFilter.fusedRoll;
            then assign attitude := AttitudeData {
                pitch = currentPitch;
                roll = currentRoll;
                timestamp = gyroData.timestamp;
                quality = 1.0;
            }
            then done;
        }
    }

    part def HorizonDisplay {
        doc /* Visual display showing aircraft attitude relative to horizon */
        attribute brightness : DisplayBrightness;
        attribute updateRate : ISQ::frequencyValue;

        port attitudeIn : ~AttitudeOutputPort;
        port power : PowerPort;

        action renderHorizon {
            in attitudeData : AttitudeData;
            in brightnessLevel : DisplayBrightness;

            first start;
            then action drawSkyGround;
            then action drawHorizonLine;
            then action drawPitchLadder;
            then action drawRollScale;
            then action drawAircraftSymbol;
            then action refreshDisplay;
            then done;
        }
    }

    part def PowerManagementUnit {
        doc /* Regulates and distributes electrical power to system components */
        attribute inputVoltage : SupplyVoltage;
        attribute outputVoltage : SupplyVoltage;
        attribute powerEfficiency : Real;

        port powerIn : PowerPort;
        port gyroOut : ~PowerPort;
        port accelOut : ~PowerPort;
        port computerOut : ~PowerPort;
        port displayOut : ~PowerPort;

        state powerControl {
            entry; then powerOff;

            state powerOff;
            accept when inputVoltage >= 24.0[V];
            then initialization;

            state initialization {
                entry action performPowerOnSelfTest;
            }
            if selfTestPassed then distributing;
            if selfTestFailed then fault;

            state distributing {
                do action regulateVoltage;
            }
            accept when inputVoltage < 20.0[V];
            then powerOff;

            state fault;
            accept ResetCommand;
            then initialization;
        }
    }

    part def AttitudeIndicator {
        doc /*
            An attitude indicator (artificial horizon) displays the aircraft's orientation
            relative to Earth's horizon. It continuously measures angular rates and linear
            accelerations, fuses this sensor data through complementary filtering to compute
            pitch and roll angles, and presents this information visually to enable spatial
            awareness during flight, particularly in instrument meteorological conditions.
        */

        attribute systemMode : SystemMode := SystemMode::off;
        attribute operatingTemperature : ISQ::thermodynamicTemperatureValue;

        port externalPower : PowerPort;

        part gyro : RateGyroscope {
            attribute :>> sampleRate = 100.0[Hz];
            attribute :>> driftRate = 0.01[deg/s];
        }

        part accel : ThreeAxisAccelerometer {
            attribute :>> sensitivity = 1.0;
            attribute :>> noiseLevel = 0.01[m/s^2];
        }

        part computer : AttitudeComputer {
            attribute :>> filterGain = 0.98;
            attribute :>> mode = systemMode;
        }

        part display : HorizonDisplay {
            attribute :>> brightness = 0.8;
            attribute :>> updateRate = 60.0[Hz];
        }

        part powerUnit : PowerManagementUnit {
            attribute :>> inputVoltage = 28.0[V];
            attribute :>> outputVoltage = 5.0[V];
            attribute :>> powerEfficiency = 0.85;
        }

        connection powerDistribution connect externalPower to powerUnit.powerIn;
        connection gyroPower connect powerUnit.gyroOut to gyro.power;
        connection accelPower connect powerUnit.accelOut to accel.power;
        connection computerPower connect powerUnit.computerOut to computer.power;
        connection displayPower connect powerUnit.displayOut to display.power;

        connection gyroDataFlow connect gyro.gyroOut to computer.gyroIn;
        connection accelDataFlow connect accel.accelOut to computer.accelIn;
        connection attitudeDataFlow connect computer.attitudeOut to display.attitudeIn;

        action provideAttitudeReference {
            doc /*
                Primary system function: Continuously determine and display the aircraft's
                spatial orientation (pitch and roll) relative to Earth's horizon by integrating
                gyroscopic rate measurements with accelerometer-derived gravity references,
                enabling pilots to maintain controlled flight attitude in all visibility conditions.
            */

            first start;
            then merge continuousLoop;

            then action senseRates {
                perform gyro.measureRates;
            }

            then action senseAcceleration {
                perform accel.measureAcceleration;
            }

            then action processData {
                perform computer.computeAttitude;
            }

            then action updateDisplay {
                perform display.renderHorizon;
            }

            then continuousLoop;
        }

        perform action primaryOperation references provideAttitudeReference;
    }

    requirement def <'REQ-ATT-001'> AttitudeAccuracyRequirement {
        doc /*
            The attitude indicator shall display pitch and roll angles with an accuracy
            of ±2 degrees under normal operating conditions and ±5 degrees under degraded
            sensor conditions.
        */

        subject indicator : AttitudeIndicator;

        require constraint {
            indicator.computer.currentPitch >= -90.0[deg] and
            indicator.computer.currentPitch <= 90.0[deg] and
            indicator.computer.currentRoll >= -180.0[deg] and
            indicator.computer.currentRoll <= 180.0[deg]
        }
    }

    requirement def <'REQ-ATT-002'> DisplayUpdateRequirement {
        doc /*
            The attitude indicator shall update the displayed attitude at a minimum
            rate of 30 Hz to provide smooth, continuous visual feedback to the pilot.
        */

        subject displaySystem : HorizonDisplay;

        require constraint {
            displaySystem.updateRate >= 30.0[Hz]
        }
    }

    requirement def <'REQ-ATT-003'> PowerSupplyRequirement {
        doc /*
            The attitude indicator shall operate from aircraft 28V DC electrical
            system with tolerance of ±4V and consume no more than 15W of power.
        */

        subject powerSystem : PowerManagementUnit;

        require constraint {
            powerSystem.inputVoltage >= 24.0[V] and
            powerSystem.inputVoltage <= 32.0[V]
        }
    }

    requirement def <'REQ-ATT-004'> EnvironmentalRequirement {
        doc /*
            The attitude indicator shall operate reliably across the full range
            of aircraft environmental conditions: temperature -40°C to +70°C,
            altitude sea level to 50,000 feet, and vibration per DO-160G.
        */

        subject system : AttitudeIndicator;

        require constraint {
            system.operatingTemperature >= 233.15[K] and
            system.operatingTemperature <= 343.15[K]
        }
    }

    requirement def <'REQ-ATT-005'> StartupTimeRequirement {
        doc /*
            The attitude indicator shall provide valid attitude indication within
            60 seconds of power application, including completion of self-test.
        */

        subject system : AttitudeIndicator;
    }

    requirement <'REQ-ATT-MAIN'> attitudeIndicatorMissionRequirement {
        doc /*
            The attitude indicator system shall provide continuous, accurate aircraft
            attitude information to enable safe flight operations in visual and instrument
            meteorological conditions, meeting all applicable aviation certification standards.
        */

        require AttitudeAccuracyRequirement;
        require DisplayUpdateRequirement;
        require PowerSupplyRequirement;
        require EnvironmentalRequirement;
        require StartupTimeRequirement;
    }

    part attitudeIndicatorInstance : AttitudeIndicator {
        doc /*
            Operational attitude indicator system instance for installation in aircraft
            instrument panel, providing real-time pitch and roll indication through sensor
            fusion of gyroscopic and accelerometer measurements.
        */
    }
}
