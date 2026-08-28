package UltrasonicParkingSensor {

    import ScalarValues::*;
    import SI::*;

    // ============ Units ============
    unit cm;
    unit ms;
    unit kHz;
    unit degC;
    unit percent;
    unit dB;
    unit V;

    // ============ Value Types ============
    value type Distance :> Real { unit = cm; }
    value type TimeOfFlight :> Real { unit = ms; }
    value type FrequencyValue :> Real { unit = kHz; }
    value type TemperatureValue :> Real { unit = degC; }
    value type ConfidenceValue :> Real { unit = percent; }
    value type SignalStrengthValue :> Real { unit = dB; }
    value type VoltageValue :> Real { unit = V; }
    value type ErrorCode :> Integer;

    // ============ Enumerations ============
    enum def DetectionStatus {
        NoObstacle;
        ObstaclePresent;
    }

    enum def OperationalState {
        idle;
        active;
        fault;
    }

    // ============ Item Definitions ============
    item def AcousticPulse {
        attribute frequency : FrequencyValue;
        attribute amplitude : SignalStrengthValue;
    }

    item def RawMeasurement {
        attribute timeOfFlight : TimeOfFlight;
        attribute signalStrength : SignalStrengthValue;
    }

    item def ProcessedMeasurement {
        attribute distance : Distance;
        attribute status : DetectionStatus;
        attribute confidence : ConfidenceValue;
    }

    item def DiagnosticInfo {
        attribute temperature : TemperatureValue;
        attribute errorCode : ErrorCode;
        attribute state : OperationalState;
    }

    item def Power {
        attribute voltage : VoltageValue;
    }

    // ============ Port Definitions ============
    port def PowerInIf {
        in item power : Power;
    }

    port def DataOutIf {
        out item measurement : ProcessedMeasurement;
    }

    port def DiagOutIf {
        out item diagnostics : DiagnosticInfo;
    }

    port def DriveInIf {
        in item pulse : AcousticPulse;
    }

    port def RawOutIf {
        out item raw : RawMeasurement;
    }

    port def ProcOutIf {
        out item processed : ProcessedMeasurement;
    }

    port def TempOutIf {
        out item temperature : TemperatureValue;
    }

    // ============ Part: Ultrasonic Transducer ============
    part def UltrasonicTransducer {
        attribute operatingFrequency : FrequencyValue = 40[kHz];
        attribute minEchoStrength : SignalStrengthValue = -30[dB];
        attribute beamAngle : Real = 120; // degrees

        port drive : DriveInIf;
        port rawOut : RawOutIf;

        action def Transmit {
            in pulse : AcousticPulse;
            doc /* Emit ultrasonic burst through the transducer membrane. */
        }

        action def Receive {
            out echo : AcousticPulse;
            doc /* Listen for returning echo and capture timing. */
        }

        action def MeasureTimeOfFlight {
            in echo : AcousticPulse;
            out raw : RawMeasurement;
            doc /* Convert echo arrival into time-of-flight and signal strength. */
        }

        perform transmit : Transmit;
        perform receive : Receive;
        perform measure : MeasureTimeOfFlight;
    }

    // ============ Part: Signal Processor ============
    part def SignalProcessor {
        attribute nominalSpeedOfSound : Real = 34300; // cm/s at 20 degC
        attribute minConfidenceThreshold : ConfidenceValue = 50[percent];
        attribute maxPlausibleDistance : Distance = 250[cm];

        port rawIn : ~RawOutIf;
        port tempIn : ~TempOutIf;
        port procOut : ProcOutIf;

        action def ComputeDistance {
            in tof : TimeOfFlight;
            in temp : TemperatureValue;
            out dist : Distance;
            doc /* Calculate distance using temperature-compensated speed of sound. */
        }

        action def ValidateMeasurement {
            in dist : Distance;
            in strength : SignalStrengthValue;
            out confidence : ConfidenceValue;
            out valid : Boolean;
            doc /* Assess echo strength and plausibility to determine confidence. */
        }

        action def ProcessCycle {
            in raw : RawMeasurement;
            in temp : TemperatureValue;
            out processed : ProcessedMeasurement;

            perform compute : ComputeDistance;
            perform validate : ValidateMeasurement;
        }

        perform process : ProcessCycle;
    }

    // ============ Part: Temperature Sensor ============
    part def TemperatureSensor {
        attribute currentTemp : TemperatureValue;
        attribute operatingMin : TemperatureValue = -40[degC];
        attribute operatingMax : TemperatureValue = 85[degC];
        attribute samplingInterval : TimeOfFlight = 100[ms];

        port tempOut : TempOutIf;

        action def SenseTemperature {
            out temp : TemperatureValue;
            doc /* Measure ambient temperature for speed-of-sound compensation. */
        }

        perform sense : SenseTemperature;
    }

    // ============ Part: Control Unit ============
    part def ControlUnit {
        attribute firmwareVersion : String = "v1.2";
        attribute currentState : OperationalState;
        attribute lastErrorCode : ErrorCode = 0;
        attribute powerOn : Boolean;
        attribute echoReceived : Boolean;
        attribute internalError : Boolean;
        attribute recoverySuccessful : Boolean;
        attribute measurementTimeout : TimeOfFlight = 30[ms];

        port power : PowerInIf;
        port data : DataOutIf;
        port diag : DiagOutIf;
        port transducerDrive : ~DriveInIf;
        port procIn : ~ProcOutIf;
        port tempIn : ~TempOutIf;

        action def OrchestrateSensing {
            in processed : ProcessedMeasurement;
            in temp : TemperatureValue;
            out finalMeasurement : ProcessedMeasurement;
            out diagnostics : DiagnosticInfo;
            doc /* Determine final detection status and assemble diagnostic output. */
        }

        action def ReportFault {
            out errorCode : ErrorCode;
            doc /* Report internal error via diagnostic port. */
        }

        action def AttemptRecovery {
            out success : Boolean;
            doc /* Attempt to recover from a fault condition. */
        }

        perform orchestrate : OrchestrateSensing;

        state def ControlUnitBehavior {
            entry; then idle;

            state idle {
                doc /* Low-power conservation state; awaiting activation. */
                entry action {
                    currentState = OperationalState::idle;
                }
            }

            transition idle_to_active
                first idle
                if powerOn
                then active;

            state active {
                entry; then transmitting;

                state transmitting {
                    doc /* Emit ultrasonic pulse via the transducer. */
                    entry action {
                        currentState = OperationalState::active;
                    }
                }

                transition tx_to_rx
                    first transmitting
                    after 1[ms]
                    then listening;

                state listening {
                    doc /* Listen for returning echo within the timeout window. */
                    entry action {
                        echoReceived = false;
                    }
                }

                transition rx_to_proc
                    first listening
                    if echoReceived
                    then processing;

                transition rx_timeout
                    first listening
                    after 30[ms]
                    then processing;

                state processing {
                    doc /* Validate measurement, compute distance, and determine status. */
                    entry action {
                        // Process received data and assemble final measurement
                    }
                }

                transition proc_to_tx
                    first processing
                    then transmitting;
            }

            transition active_to_fault
                first active
                if internalError
                then fault;

            transition idle_to_fault
                first idle
                if internalError
                then fault;

            state fault {
                doc /* Internal error detected; attempt recovery or report issue. */
                entry action {
                    currentState = OperationalState::fault;
                }
                do action {
                    // Attempt recovery procedure
                }
            }

            transition fault_to_idle
                first fault
                if recoverySuccessful
                then idle;
        }

        exhibit stateBehavior : ControlUnitBehavior;
    }

    // ============ Composite: Parking Sensor Unit ============
    part def ParkingSensorUnit {
        attribute designation : String = "Rear Parking Sensor";
        attribute minRange : Distance = 15[cm];
        attribute maxRange : Distance = 250[cm];
        attribute accuracy : Distance = 3[cm];
        attribute freqMin : FrequencyValue = 40[kHz];
        attribute freqMax : FrequencyValue = 48[kHz];
        attribute tempMin : TemperatureValue = -40[degC];
        attribute tempMax : TemperatureValue = 85[degC];

        port powerIn : PowerInIf;
        port dataOut : DataOutIf;
        port diagOut : DiagOutIf;

        part transducer : UltrasonicTransducer;
        part processor : SignalProcessor;
        part tempSensor : TemperatureSensor;
        part controller : ControlUnit;

        // Internal connections
        connection powerToController
            connect powerIn to controller.power;

        connection dataFromController
            connect controller.data to dataOut;

        connection diagFromController
            connect controller.diag to diagOut;

        connection controllerToTransducer
            connect controller.transducerDrive to transducer.drive;

        connection transducerToProcessor
            connect transducer.rawOut to processor.rawIn;

        connection tempToProcessor
            connect tempSensor.tempOut to processor.tempIn;

        connection tempToController
            connect tempSensor.tempOut to controller.tempIn;

        connection processorToController
            connect processor.procOut to controller.procIn;
    }

    // ============ Requirements ============
    requirement def FrequencyRangeRequirement {
        doc /* The sensor shall operate within a frequency range of 40 to 48 kHz. */
        subject sensor : ParkingSensorUnit;
        require sensor.freqMin >= 40[kHz];
        require sensor.freqMax <= 48[kHz];
    }

    requirement def DetectionRangeRequirement {
        doc /* The sensor shall detect obstacles from as close as 15 cm up to 2.5 meters. */
        subject sensor : ParkingSensorUnit;
        require sensor.minRange <= 15[cm];
        require sensor.maxRange >= 250[cm];
    }

    requirement def AccuracyRequirement {
        doc /* The sensor shall maintain a measurement accuracy of within 3 centimeters. */
        subject sensor : ParkingSensorUnit;
        require sensor.accuracy <= 3[cm];
    }

    requirement def TemperatureRangeRequirement {
        doc /* The sensor shall function reliably across -40 degC to +85 degC. */
        subject sensor : ParkingSensorUnit;
        require sensor.tempMin <= -40[degC];
        require sensor.tempMax >= 85[degC];
    }

    requirement def DetectionStatusRequirement {
        doc /* The sensor shall report a detection status of Obstacle Present or No Obstacle Detected. */
        subject sensor : ParkingSensorUnit;
    }

    requirement def DiagnosticInterfaceRequirement {
        doc /* The sensor shall provide real-time health information including operating temperature and error codes via a diagnostic port. */
        subject sensor : ParkingSensorUnit;
    }

    requirement def OperationalStatesRequirement {
        doc /* The sensor shall support idle, active, and fault operational states. */
        subject sensor : ParkingSensorUnit;
    }

    requirement freqReq : FrequencyRangeRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }

    requirement rangeReq : DetectionRangeRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }

    requirement accuracyReq : AccuracyRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }

    requirement tempReq : TemperatureRangeRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }

    requirement statusReq : DetectionStatusRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }

    requirement diagReq : DiagnosticInterfaceRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }

    requirement statesReq : OperationalStatesRequirement {
        subject :>> sensor : ParkingSensorUnit;
    }
}
