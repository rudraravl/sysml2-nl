package MEMSInertialSensorSystem {
    import ScalarValues::*;
    import SI::*;

    attribute def Acceleration :> Real {
        unit = "m/s^2";
    }

    attribute def AngularRate :> Real {
        unit = "rad/s";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Capacitance :> Real {
        unit = "F";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def Frequency :> Real {
        unit = "Hz";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def DataRate :> Real {
        unit = "sample/s";
    }

    item def MechanicalMotion {
        attribute linearAcceleration : Acceleration;
        attribute angularRate : AngularRate;
        attribute vibrationFrequency : Frequency;
    }

    item def DifferentialCapacitanceSignal {
        attribute capacitanceX : Capacitance;
        attribute capacitanceY : Capacitance;
        attribute capacitanceZ : Capacitance;
        attribute senseBias : Voltage;
    }

    item def AnalogSenseSignal {
        attribute voltageX : Voltage;
        attribute voltageY : Voltage;
        attribute voltageZ : Voltage;
        attribute noiseRms : Voltage;
    }

    item def DigitalInertialSample {
        attribute accelerationX : Acceleration;
        attribute accelerationY : Acceleration;
        attribute accelerationZ : Acceleration;
        attribute temperature : Temperature;
        attribute samplePeriod : TimeDuration;
        attribute validity : Boolean;
    }

    item def ConfigurationCommand {
        attribute fullScaleRange : Acceleration;
        attribute outputDataRate : DataRate;
        attribute selfTestEnabled : Boolean;
        attribute lowPowerModeEnabled : Boolean;
    }

    port def MotionInputPort {
        in item motion : MechanicalMotion;
    }

    port def CapacitiveSensePort {
        out item capacitance : DifferentialCapacitanceSignal;
    }

    port def AnalogSignalPort {
        out item analogSignal : AnalogSenseSignal;
    }

    port def DigitalDataPort {
        out item sample : DigitalInertialSample;
        in item command : ConfigurationCommand;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrent : Real;
    }

    port def ClockPort {
        in attribute clockFrequency : Frequency;
    }

    action def ConvertMotionToCapacitance {
        in item motion : MechanicalMotion;
        out item capacitance : DifferentialCapacitanceSignal;
    }

    action def ConditionAnalogSignal {
        in item capacitance : DifferentialCapacitanceSignal;
        out item analogSignal : AnalogSenseSignal;
    }

    action def DigitizeAndCompensate {
        in item analogSignal : AnalogSenseSignal;
        in attribute dieTemperature : Temperature;
        out item sample : DigitalInertialSample;
    }

    action def PublishInertialSample {
        in item sample : DigitalInertialSample;
        out item publishedSample : DigitalInertialSample;
    }

    part def MEMSProofMassAccelerometer {
        attribute proofMass : Real {
            unit = "kg";
            default = 0.000000002;
        }

        attribute springConstant : Real {
            unit = "N/m";
            default = 0.42;
        }

        attribute dampingCoefficient : Real {
            unit = "N*s/m";
            default = 0.0000016;
        }

        attribute nominalSenseGap : Real {
            unit = "m";
            default = 0.000002;
        }

        port motionIn : MotionInputPort;
        port capacitiveOut : CapacitiveSensePort;

        perform action transduction : ConvertMotionToCapacitance {
            in motion = motionIn.motion;
            out capacitance = capacitiveOut.capacitance;
        }
    }

    part def CapacitiveReadoutASIC {
        attribute excitationVoltage : Voltage = 1.8;
        attribute inputReferredNoise : Voltage = 0.000015;
        attribute bandwidth : Frequency = 400.0;

        port capacitiveIn : CapacitiveSensePort;
        port analogOut : AnalogSignalPort;

        perform action analogConditioning : ConditionAnalogSignal {
            in capacitance = capacitiveIn.capacitance;
            out analogSignal = analogOut.analogSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : DataRate = 1000.0;
        attribute referenceVoltage : Voltage = 1.2;

        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalDataPort;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Temperature;
        attribute accuracy : Temperature = 1.0;
    }

    part def DigitalSignalProcessor {
        attribute offsetTrimX : Acceleration = 0.0;
        attribute offsetTrimY : Acceleration = 0.0;
        attribute offsetTrimZ : Acceleration = 0.0;
        attribute scaleFactorError : Real = 0.005;
        attribute configuredDataRate : DataRate = 1000.0;

        port rawDataIn : DigitalDataPort;
        port dataOut : DigitalDataPort;

        perform action compensation : DigitizeAndCompensate {
            in analogSignal = rawDataIn.sample;
            out sample = dataOut.sample;
        }
    }

    part def SerialInterface {
        attribute protocol : String = "SPI";
        attribute maximumClockRate : Frequency = 10000000.0;

        port dataPort : DigitalDataPort;
        port clock : ClockPort;
    }

    part def PowerManagementUnit {
        attribute minimumSupplyVoltage : Voltage = 1.71;
        attribute nominalSupplyVoltage : Voltage = 1.8;
        attribute maximumSupplyVoltage : Voltage = 3.6;
        attribute sleepCurrent : Real = 0.000002;
        attribute activeCurrent : Real = 0.0012;

        port powerIn : ElectricalPowerPort;
    }

    state def SensorOperatingStateMachine {
        state initial Off;

        state Off;
        state PowerUp;
        state SelfTest;
        state Calibrating;
        state Measuring;
        state LowPower;
        state Fault;

        transition first Off then PowerUp
            accept PowerApplied;

        transition PowerUp then SelfTest
            accept SupplyStable;

        transition SelfTest then Calibrating
            accept SelfTestPassed;

        transition SelfTest then Fault
            accept SelfTestFailed;

        transition Calibrating then Measuring
            accept CalibrationComplete;

        transition Measuring then LowPower
            accept EnterLowPower;

        transition LowPower then Measuring
            accept ExitLowPower;

        transition Measuring then Fault
            accept SignalOutOfRange;

        transition Fault then PowerUp
            accept ResetCommand;
    }

    part def MEMSInertialMeasurementUnit {
        doc /* Primary function: sense mechanical acceleration applied to a microelectromechanical proof mass, convert the resulting microscopic displacement into differential capacitance, condition and digitize the signal, compensate it for temperature and calibration error, and provide calibrated digital inertial samples to a host controller. */

        attribute measurementRange : Acceleration = 156.96;
        attribute noiseDensity : Real {
            unit = "m/s^2/sqrt(Hz)";
            default = 0.0015;
        }

        attribute startupTime : TimeDuration = 0.012;
        attribute operatingTemperatureMin : Temperature = -40.0;
        attribute operatingTemperatureMax : Temperature = 85.0;

        port mechanicalInput : MotionInputPort;
        port hostInterface : DigitalDataPort;
        port power : ElectricalPowerPort;
        port serialClock : ClockPort;

        part mechanicalSensor : MEMSProofMassAccelerometer;
        part readout : CapacitiveReadoutASIC;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part processor : DigitalSignalProcessor;
        part interface : SerialInterface;
        part powerManager : PowerManagementUnit;

        connection mechanicalPath
            connect mechanicalInput to mechanicalSensor.motionIn;

        connection capacitivePath
            connect mechanicalSensor.capacitiveOut to readout.capacitiveIn;

        connection analogPath
            connect readout.analogOut to adc.analogIn;

        connection rawDigitalPath
            connect adc.digitalOut to processor.rawDataIn;

        connection compensatedDataPath
            connect processor.dataOut to interface.dataPort;

        connection hostDataPath
            connect interface.dataPort to hostInterface;

        connection clockPath
            connect serialClock to interface.clock;

        connection powerPath
            connect power to powerManager.powerIn;

        exhibit stateMachine : SensorOperatingStateMachine;

        perform action acquisitionPipeline {
            first start;
            then transduce : ConvertMotionToCapacitance {
                in motion = mechanicalInput.motion;
            }
            then condition : ConditionAnalogSignal {
                in capacitance = transduce.capacitance;
            }
            then compensate : DigitizeAndCompensate {
                in analogSignal = condition.analogSignal;
                in dieTemperature = temperatureSensor.measuredTemperature;
            }
            then publish : PublishInertialSample {
                in sample = compensate.sample;
                out publishedSample = hostInterface.sample;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject imu : MEMSInertialMeasurementUnit;

        require constraint {
            imu.hostInterface.sample.validity == true
        }

        doc /* The MEMS inertial measurement unit shall transform externally applied acceleration into calibrated digital acceleration samples for host use. */
    }

    requirement def MeasurementRangeRequirement {
        subject imu : MEMSInertialMeasurementUnit;

        require constraint {
            imu.measurementRange >= 156.96
        }

        doc /* The sensor shall measure acceleration over at least plus or minus 16 g on each orthogonal axis. */
    }

    requirement def StartupRequirement {
        subject imu : MEMSInertialMeasurementUnit;

        require constraint {
            imu.startupTime <= 0.020
        }

        doc /* The sensor shall become ready to report valid samples within 20 milliseconds after stable supply voltage is applied. */
    }

    requirement def EnvironmentalRequirement {
        subject imu : MEMSInertialMeasurementUnit;

        require constraint {
            imu.operatingTemperatureMin <= -40.0 and imu.operatingTemperatureMax >= 85.0
        }

        doc /* The sensor shall operate across the industrial temperature range. */
    }

    requirement def InterfaceRequirement {
        subject imu : MEMSInertialMeasurementUnit;

        require constraint {
            imu.interface.maximumClockRate >= 10000000.0
        }

        doc /* The sensor shall provide calibrated acceleration data through a synchronous serial digital interface. */
    }

    part imuSystem : MEMSInertialMeasurementUnit;

    satisfy PrimaryFunctionRequirement by imuSystem;
    satisfy MeasurementRangeRequirement by imuSystem;
    satisfy StartupRequirement by imuSystem;
    satisfy EnvironmentalRequirement by imuSystem;
    satisfy InterfaceRequirement by imuSystem;
}