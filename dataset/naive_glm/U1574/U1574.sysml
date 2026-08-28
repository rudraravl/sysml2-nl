package TouchSensingUnit {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value Types with Units ----
    value def Force :> Real {
        unit 'N';
    }
    value def Capacitance :> Real {
        unit 'pF';
    }
    value def Voltage :> Real {
        unit 'V';
    }
    value def Timestamp :> Integer {
        unit 'ms';
    }
    value def SampleRate :> Real {
        unit 'Hz';
    }
    value def Dimensionless :> Real;

    // ---- Enumerations ----
    enum def TouchIntensity {
        noContact;
        lightTouch;
        firmTouch;
        heavyTouch;
    }

    enum def SensorMode {
        idle;
        active;
    }

    // ---- Item Definitions ----
    item def RawSensorData {
        attribute capacitanceReading : Capacitance;
        attribute forceReading : Force;
        attribute mode : SensorMode;
    }

    item def ConditionedSignal {
        attribute filteredForce : Force;
        attribute filteredCapacitance : Capacitance;
        attribute amplifiedVoltage : Voltage;
        attribute calibrationFactor : Dimensionless;
    }

    item def DataPacket {
        attribute measuredForce : Force;
        attribute capacitanceReading : Capacitance;
        attribute timestamp : Timestamp;
        attribute intensity : TouchIntensity;
    }

    // ---- Port Definitions ----
    port def RawDataPort {
        out raw : RawSensorData;
    }

    port def ConditionedSignalPort {
        out signal : ConditionedSignal;
    }

    port def DataPacketPort {
        out packet : DataPacket;
    }

    // ---- Touch Sensor ----
    part def TouchSensor {
        attribute maxForce : Force = 10.0 [N];
        attribute accuracy : Dimensionless = 0.02;
        attribute currentMode : SensorMode = SensorMode::idle;

        port rawOut : RawDataPort;

        part capacitiveElement {
            attribute capacitanceValue : Capacitance = 0.0 [pF];
            attribute touchThreshold : Capacitance = 1.0 [pF];

            action detectTouch {
                out capacitance : Capacitance;
                if capacitanceValue >= touchThreshold {
                    capacitance := capacitanceValue;
                } else {
                    capacitance := 0.0 [pF];
                }
            }
        }

        part forceTransducer {
            attribute forceValue : Force = 0.0 [N];
            attribute sensitivity : Dimensionless = 0.5;

            action measureForce {
                out force : Force;
                force := forceValue;
            }
        }

        state machine sensorModeBehavior {
            state idle;
            state active;

            transition idle to active
                when capacitiveElement.capacitanceValue >= capacitiveElement.touchThreshold;
            transition active to idle
                when forceTransducer.forceValue == 0.0 [N];

            entry action of idle {
                currentMode := SensorMode::idle;
            }
            entry action of active {
                currentMode := SensorMode::active;
            }
        }

        action produceRawData {
            out raw : RawSensorData;
            attribute cap : Capacitance;
            attribute frc : Force;
            perform capacitiveElement.detectTouch { out capacitance = cap; }
            perform forceTransducer.measureForce { out force = frc; }
            raw.capacitanceReading := cap;
            raw.forceReading := frc;
            raw.mode := currentMode;
        }
    }

    // ---- Signal Conditioner ----
    part def SignalConditioner {
        attribute gain : Dimensionless = 100.0;
        attribute noiseFloor : Voltage = 0.001 [V];
        attribute calibrationOffset : Force = 0.0 [N];
        attribute calibrationScale : Dimensionless = 1.0;

        port signalIn : RawDataPort;
        port signalOut : ConditionedSignalPort;

        action filterNoise {
            in rawForce : Force;
            in rawCapacitance : Capacitance;
            out filteredForce : Force;
            out filteredCapacitance : Capacitance;
            // Simple first-order low-pass approximation
            filteredForce := rawForce;
            filteredCapacitance := rawCapacitance;
        }

        action amplify {
            in filteredForce : Force;
            out amplifiedVoltage : Voltage;
            amplifiedVoltage := filteredForce * gain * 0.001 [V/N];
        }

        action calibrate {
            in filteredForce : Force;
            out calibratedForce : Force;
            calibratedForce := (filteredForce - calibrationOffset) * calibrationScale;
        }

        action conditionSignal {
            in raw : RawSensorData;
            out conditioned : ConditionedSignal;
            attribute ff : Force;
            attribute fc : Capacitance;
            attribute av : Voltage;
            attribute cf : Force;
            perform filterNoise {
                in rawForce = raw.forceReading;
                in rawCapacitance = raw.capacitanceReading;
                out filteredForce = ff;
                out filteredCapacitance = fc;
            }
            perform amplify {
                in filteredForce = ff;
                out amplifiedVoltage = av;
            }
            perform calibrate {
                in filteredForce = ff;
                out calibratedForce = cf;
            }
            conditioned.filteredForce := cf;
            conditioned.filteredCapacitance := fc;
            conditioned.amplifiedVoltage := av;
            conditioned.calibrationFactor := calibrationScale;
        }
    }

    // ---- Data Acquisition Unit ----
    part def DataAcquisitionUnit {
        attribute sampleRate : SampleRate = 100.0 [Hz];
        attribute bufferSize : Integer = 256;
        attribute lightTouchThreshold : Force = 2.0 [N];
        attribute firmTouchThreshold : Force = 5.0 [N];
        attribute heavyTouchThreshold : Force = 8.0 [N];

        port signalIn : ConditionedSignalPort;
        port packetOut : DataPacketPort;

        part buffer {
            attribute data : DataPacket[0..*];
            attribute count : Integer = 0;

            action store {
                in packet : DataPacket;
                if count < bufferSize {
                    data := data.append(packet);
                    count := count + 1;
                }
            }

            action retrieve {
                out packet : DataPacket;
                if count > 0 {
                    packet := data.first();
                    data := data.dropFirst();
                    count := count - 1;
                }
            }
        }

        action digitize {
            in signal : ConditionedSignal;
            out digitalForce : Force;
            out digitalCapacitance : Capacitance;
            digitalForce := signal.filteredForce;
            digitalCapacitance := signal.filteredCapacitance;
        }

        action timestampData {
            out ts : Timestamp;
            attribute counter : Timestamp = 0 [ms];
            counter := counter + (1000.0 / sampleRate) [ms];
            ts := counter;
        }

        action classifyTouch {
            in force : Force;
            out intensity : TouchIntensity;
            if force == 0.0 [N] {
                intensity := TouchIntensity::noContact;
            } else if force < lightTouchThreshold {
                intensity := TouchIntensity::lightTouch;
            } else if force < firmTouchThreshold {
                intensity := TouchIntensity::firmTouch;
            } else {
                intensity := TouchIntensity::heavyTouch;
            }
        }

        action acquireData {
            in signal : ConditionedSignal;
            out packet : DataPacket;
            attribute df : Force;
            attribute dc : Capacitance;
            attribute ts : Timestamp;
            attribute intensity : TouchIntensity;
            perform digitize {
                in signal = signal;
                out digitalForce = df;
                out digitalCapacitance = dc;
            }
            perform timestampData { out ts = ts; }
            perform classifyTouch {
                in force = df;
                out intensity = intensity;
            }
            packet.measuredForce := df;
            packet.capacitanceReading := dc;
            packet.timestamp := ts;
            packet.intensity := intensity;
            perform buffer.store { in packet = packet; }
        }
    }

    // ---- Top-Level Touch Sensing Unit ----
    part def TouchSensingUnit {
        attribute forceRange : Force = 10.0 [N];
        attribute accuracySpec : Dimensionless = 0.02;
        attribute minSampleRate : SampleRate = 50.0 [Hz];

        port dataOut : DataPacketPort;

        part sensor : TouchSensor {
            port rawOut : RawDataPort;
        }
        part conditioner : SignalConditioner {
            port signalIn : RawDataPort;
            port signalOut : ConditionedSignalPort;
        }
        part acquisition : DataAcquisitionUnit {
            port signalIn : ConditionedSignalPort;
            port packetOut : DataPacketPort;
        }

        connection rawFlow connect sensor.rawOut to conditioner.signalIn;
        connection conditionedFlow connect conditioner.signalOut to acquisition.signalIn;
        connection packetFlow connect acquisition.packetOut to dataOut;

        action operate {
            attribute raw : RawSensorData;
            attribute conditioned : ConditionedSignal;
            attribute packet : DataPacket;
            perform sensor.produceRawData { out raw = raw; }
            perform conditioner.conditionSignal {
                in raw = raw;
                out conditioned = conditioned;
            }
            perform acquisition.acquireData {
                in signal = conditioned;
                out packet = packet;
            }
        }
    }

    // ---- Requirements ----
    requirement def ForceRangeRequirement {
        subject tsu : TouchSensingUnit;
        objective {
            tsu.forceRange <= 10.0 [N]
        }
    }

    requirement def AccuracyRequirement {
        subject tsu : TouchSensingUnit;
        objective {
            tsu.accuracySpec <= 0.02
        }
    }

    requirement def SampleRateRequirement {
        subject tsu : TouchSensingUnit;
        objective {
            tsu.minSampleRate >= 50.0 [Hz]
        }
    }

    requirement def DualMethodSensingRequirement {
        subject sensor : TouchSensor;
        objective {
            sensor.capacitiveElement.touchThreshold > 0.0 [pF]
            and sensor.forceTransducer.sensitivity > 0.0
        }
    }

    requirement def ClassificationRequirement {
        subject acquisition : DataAcquisitionUnit;
        objective {
            acquisition.lightTouchThreshold > 0.0 [N]
            and acquisition.firmTouchThreshold > acquisition.lightTouchThreshold
            and acquisition.heavyTouchThreshold > acquisition.firmTouchThreshold
        }
    }

    requirement def TouchSensingUnitRequirements {
        requirement forceRangeReq : ForceRangeRequirement;
        requirement accuracyReq : AccuracyRequirement;
        requirement sampleRateReq : SampleRateRequirement;
        requirement dualMethodReq : DualMethodSensingRequirement;
        requirement classificationReq : ClassificationRequirement;
    }
}
