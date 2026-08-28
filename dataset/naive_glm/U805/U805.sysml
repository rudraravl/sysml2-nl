package PDG_System {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Units and Value Types ----
    attribute def Pascal :> Unit { shortName 'Pa'; }
    attribute def Celsius :> Unit { shortName 'degC'; }
    attribute def BarrelPerDay :> Unit { shortName 'bbl/d'; }
    attribute def GForce :> Unit { shortName 'g'; }
    attribute def Volt :> Unit { shortName 'V'; }
    attribute def AmpereHour :> Unit { shortName 'Ah'; }
    attribute def Hertz :> Unit { shortName 'Hz'; }
    attribute def BitPerSecond :> Unit { shortName 'bps'; }

    value def Pressure :> Real { unit : Pascal; }
    value def Temperature :> Real { unit : Celsius; }
    value def FlowRate :> Real { unit : BarrelPerDay; }
    value def Vibration :> Real { unit : GForce; }
    value def Voltage :> Real { unit : Volt; }
    value def BatteryCapacity :> Real { unit : AmpereHour; }
    value def SampleRate :> Real { unit : Hertz; }
    value def DataRate :> Real { unit : BitPerSecond; }
    value def HealthIndex :> Real;

    // ---- Items ----
    item def RawSensorReading {
        attribute timestamp : Integer;
        attribute sourceId : String;
    }
    item def PressureReading :> RawSensorReading {
        attribute value : Pressure;
    }
    item def TemperatureReading :> RawSensorReading {
        attribute value : Temperature;
    }
    item def FlowReading :> RawSensorReading {
        attribute value : FlowRate;
    }
    item def VibrationReading :> RawSensorReading {
        attribute value : Vibration;
    }
    item def CalibratedDataSet {
        attribute timestamp : Integer;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        attribute vibration : Vibration;
        attribute health : HealthIndex;
    }
    item def TelemetryPacket {
        attribute sequenceId : Integer;
        attribute payload : CalibratedDataSet;
        attribute checksum : Integer;
    }
    item def SurfaceCommand {
        attribute commandId : Integer;
        attribute commandType : String;
    }
    item def AlertMessage {
        attribute faultCode : Integer;
        attribute description : String;
        attribute severity : Integer;
    }

    // ---- Ports ----
    port def PressureSignalPort {
        out reading : PressureReading;
    }
    port def TemperatureSignalPort {
        out reading : TemperatureReading;
    }
    port def FlowSignalPort {
        out reading : FlowReading;
    }
    port def VibrationSignalPort {
        out reading : VibrationReading;
    }
    port def AcquisitionInputPort {
        in readings : RawSensorReading[*];
    }
    port def AcquisitionOutputPort {
        out dataSet : CalibratedDataSet;
    }
    port def TelemetryUplinkPort {
        out packets : TelemetryPacket[*];
        out alerts : AlertMessage[*];
        in commands : SurfaceCommand[*];
    }
    port def PowerPort {
        out supplyVoltage : Voltage;
    }
    port def WellboreInterfacePort {
        in ambientPressure : Pressure;
        in ambientTemperature : Temperature;
        in ambientFlow : FlowRate;
        in ambientVibration : Vibration;
    }

    // ---- Sensor Parts ----
    part def PressureTransducer {
        attribute measurementRange : Pressure = 150.0e6 [Pa];
        attribute accuracy : Real = 0.01;
        attribute sampleRate : SampleRate = 1.0 [Hz];
        port wellbore : WellboreInterfacePort;
        port signal : PressureSignalPort;
        action def measure {
            in ambient : Pressure;
            out result : PressureReading;
        }
    }

    part def TemperatureTransducer {
        attribute measurementRange : Temperature = 200.0 [degC];
        attribute accuracy : Real = 0.05;
        attribute sampleRate : SampleRate = 1.0 [Hz];
        port wellbore : WellboreInterfacePort;
        port signal : TemperatureSignalPort;
        action def measure {
            in ambient : Temperature;
            out result : TemperatureReading;
        }
    }

    part def FlowSensor {
        attribute measurementRange : FlowRate = 10000.0 [bbl/d];
        attribute accuracy : Real = 0.02;
        attribute sampleRate : SampleRate = 0.5 [Hz];
        port wellbore : WellboreInterfacePort;
        port signal : FlowSignalPort;
        action def measure {
            in ambient : FlowRate;
            out result : FlowReading;
        }
    }

    part def Accelerometer {
        attribute measurementRange : Vibration = 50.0 [g];
        attribute accuracy : Real = 0.03;
        attribute sampleRate : SampleRate = 100.0 [Hz];
        port wellbore : WellboreInterfacePort;
        port signal : VibrationSignalPort;
        action def measure {
            in ambient : Vibration;
            out result : VibrationReading;
        }
    }

    // ---- Data Acquisition Module ----
    part def DataAcquisitionModule {
        attribute sampleRate : SampleRate = 1.0 [Hz];
        port inputs : AcquisitionInputPort;
        port output : AcquisitionOutputPort;
        action def acquire {
            in rawReadings : RawSensorReading[*];
            out aggregated : CalibratedDataSet;
        }
    }

    // ---- Calibration Module ----
    part def CalibrationModule {
        attribute calibrationIntervalHours : Integer = 168;
        attribute lastCalibration : Integer = 0;
        port input : AcquisitionInputPort;
        port output : AcquisitionOutputPort;
        action def calibrate {
            in raw : CalibratedDataSet;
            out corrected : CalibratedDataSet;
        }
        action def selfCalibrate {
            out status : Boolean;
        }
    }

    // ---- Telemetry Unit ----
    part def TelemetryUnit {
        attribute dataRate : DataRate = 9600.0 [bps];
        attribute encodingScheme : String = "CRC32";
        port input : AcquisitionOutputPort;
        port uplink : TelemetryUplinkPort;
        action def encode {
            in data : CalibratedDataSet;
            out packet : TelemetryPacket;
        }
        action def decode {
            in command : SurfaceCommand;
        }
        action def raiseAlert {
            in faultCode : Integer;
            out alert : AlertMessage;
        }
    }

    // ---- Battery Pack ----
    part def BatteryPack {
        attribute nominalCapacity : BatteryCapacity = 30.0 [Ah];
        attribute nominalVoltage : Voltage = 3.6 [V];
        attribute remainingCapacity : BatteryCapacity = 30.0 [Ah];
        attribute estimatedLifeYears : Real = 10.0;
        port power : PowerPort;
        action def discharge {
            in current : Real;
            out voltage : Voltage;
        }
    }

    // ---- Protective Housing ----
    part def ProtectiveHousing {
        attribute material : String = "Inconel 718";
        attribute pressureRating : Pressure = 170.0e6 [Pa];
        attribute temperatureRating : Temperature = 175.0 [degC];
        attribute corrosionResistanceClass : String = "NACE MR0175";
    }

    // ---- PDG State Machine ----
    state def PDGOperatingStates {
        attribute selfTestPassed : Boolean;
        attribute faultDetected : Boolean;

        state initializing {
            entry action runSelfTest {
                // perform power-up diagnostics
            }
            do action initializeSensors;
            do action loadCalibrationTable;
        }

        state operational {
            entry action startMonitoring;
            do action continuousAcquisition {
                // sample sensors, calibrate, encode, transmit
            }
            do action listenForCommands;
        }

        state calibrating {
            entry action beginCalibration;
            do action applyCorrections;
        }

        state fault {
            entry action diagnoseFault;
            do action transmitAlert;
            do action awaitRecoveryCommand;
        }

        state shutdown {
            entry action safePowerDown;
        }

        transition init_to_operational
            from initializing
            to operational
            when selfTestPassed;

        transition operational_to_calibrating
            from operational
            to calibrating
            when CalibrationModule.lastCalibration >= CalibrationModule.calibrationIntervalHours;

        transition calibrating_to_operational
            from calibrating
            to operational
            when selfTestPassed;

        transition operational_to_fault
            from operational
            to fault
            when faultDetected;

        transition fault_to_operational
            from fault
            to operational
            when selfTestPassed;

        transition any_to_shutdown
            from operational
            to shutdown
            when BatteryPack.remainingCapacity <= 0.0 [Ah];
    }

    // ---- Top-level PDG Part ----
    part def PermanentDownholeGauge {
        attribute serialNumber : String;
        attribute installationDepth : Real;
        attribute firmwareVersion : String = "1.4.0";

        part housing : ProtectiveHousing;

        part pressureTransducer : PressureTransducer;
        part temperatureTransducer : TemperatureTransducer;
        part flowSensor : FlowSensor;
        part accelerometer : Accelerometer;

        part dataAcquisition : DataAcquisitionModule;
        part calibration : CalibrationModule;
        part telemetry : TelemetryUnit;
        part battery : BatteryPack;

        port wellboreInterface : WellboreInterfacePort;
        port surfaceLink : TelemetryUplinkPort;

        exhibit state machine : PDGOperatingStates;

        connection def SensorToAcquisition {
            end source : PressureSignalPort;
            end target : AcquisitionInputPort;
        }

        connection pressureToAcquisition connect pressureTransducer.signal to dataAcquisition.inputs;
        connection temperatureToAcquisition connect temperatureTransducer.signal to dataAcquisition.inputs;
        connection flowToAcquisition connect flowSensor.signal to dataAcquisition.inputs;
        connection vibrationToAcquisition connect accelerometer.signal to dataAcquisition.inputs;

        connection acquisitionToCalibration connect dataAcquisition.output to calibration.input;
        connection calibrationToTelemetry connect calibration.output to telemetry.input;

        connection batteryToPressure connect battery.power to pressureTransducer.wellbore;
        connection batteryToTemperature connect battery.power to temperatureTransducer.wellbore;
        connection batteryToFlow connect battery.power to flowSensor.wellbore;
        connection batteryToVibration connect battery.power to accelerometer.wellbore;

        connection wellboreToPressure connect wellboreInterface to pressureTransducer.wellbore;
        connection wellboreToTemperature connect wellboreInterface to temperatureTransducer.wellbore;
        connection wellboreToFlow connect wellboreInterface to flowSensor.wellbore;
        connection wellboreToVibration connect wellboreInterface to accelerometer.wellbore;

        connection telemetryToSurface connect telemetry.uplink to surfaceLink;
    }

    // ---- Requirements ----
    requirement def RuggedEnvironmentSurvivability {
        subject pdg : PermanentDownholeGauge;
        requirement
            /* The PDG shall survive continuous exposure to wellbore pressures
               up to 150 MPa and temperatures up to 175 degC for a minimum
               service life of 10 years. */
        {
            pdg.housing.pressureRating >= 150.0e6 [Pa];
            pdg.housing.temperatureRating >= 175.0 [degC];
            pdg.battery.estimatedLifeYears >= 10.0;
        }
    }

    requirement def ContinuousMonitoring {
        subject pdg : PermanentDownholeGauge;
        requirement
            /* The PDG shall continuously acquire pressure, temperature,
               flow rate, and vibration data at a minimum sample rate of
               1 Hz during the operational state. */
        {
            pdg.pressureTransducer.sampleRate >= 1.0 [Hz];
            pdg.temperatureTransducer.sampleRate >= 1.0 [Hz];
            pdg.flowSensor.sampleRate >= 0.5 [Hz];
            pdg.accelerometer.sampleRate >= 100.0 [Hz];
        }
    }

    requirement def DataCalibration {
        subject pdg : PermanentDownholeGauge;
        requirement
            /* The PDG shall self-calibrate at least every 168 hours of
               operation and apply corrections to raw sensor data prior
               to transmission. */
        {
            pdg.calibration.calibrationIntervalHours <= 168;
        }
    }

    requirement def RealTimeTelemetry {
        subject pdg : PermanentDownholeGauge;
        requirement
            /* The PDG shall transmit calibrated data packets to surface
               facilities in real time with error-checking, and shall
               receive operator commands. */
        {
            pdg.telemetry.dataRate >= 9600.0 [bps];
            pdg.telemetry.encodingScheme == "CRC32";
        }
    }

    requirement def FaultDetectionAndAlerting {
        subject pdg : PermanentDownholeGauge;
        requirement
            /* The PDG shall enter a fault state upon detection of an
               internal anomaly, diagnose the fault, and transmit an
               alert message to the surface. */
        {
            // state machine transition operational -> fault triggered
            // by faultDetected condition
        }
    }

    requirement def SelfPoweredOperation {
        subject pdg : PermanentDownholeGauge;
        requirement
            /* The PDG shall be powered by an internal battery pack
               requiring no intervention for the duration of its
               service life. */
        {
            pdg.battery.nominalCapacity >= 30.0 [Ah];
            pdg.battery.nominalVoltage >= 3.6 [V];
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction ruggedEnvSatisfiesRuggedEnvironmentSurvivability
        by PermanentDownholeGauge.housing
        satisfy RuggedEnvironmentSurvivability;

    satisfaction monitoringSatisfiesContinuousMonitoring
        by PermanentDownholeGauge
        satisfy ContinuousMonitoring;

    satisfaction calibrationSatisfiesDataCalibration
        by PermanentDownholeGauge.calibration
        satisfy DataCalibration;

    satisfaction telemetrySatisfiesRealTimeTelemetry
        by PermanentDownholeGauge.telemetry
        satisfy RealTimeTelemetry;

    satisfaction faultHandlingSatisfiesFaultDetectionAndAlerting
        by PermanentDownholeGauge
        satisfy FaultDetectionAndAlerting;

    satisfaction powerSatisfiesSelfPoweredOperation
        by PermanentDownholeGauge.battery
        satisfy SelfPoweredOperation;

}
