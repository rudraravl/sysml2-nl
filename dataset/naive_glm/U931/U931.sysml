package UltrasonicSensingUnit {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type DistanceValue :> Real {
        m : DistanceUnit;
        unit m;
    }
    value type TimeValue :> Real {
        s : TimeUnit;
        unit s;
    }
    value type TemperatureValue :> Real {
        degC : TemperatureUnit;
        unit degC;
    }
    value type SpeedValue :> Real {
        mPerS : SpeedUnit;
        unit m/s;
    }
    value type FrequencyValue :> Real {
        Hz : FrequencyUnit;
        unit Hz;
    }

    // ---- Item types ----
    item def AcousticPulse {
        attribute frequency : FrequencyValue;
        attribute duration : TimeValue;
    }
    item def EchoSignal {
        attribute amplitude : Real;
        attribute arrivalTime : TimeValue;
    }
    item def TemperatureReading {
        attribute value : TemperatureValue;
    }
    item def DistanceMeasurement {
        attribute distance : DistanceValue;
        attribute valid : Boolean;
    }

    // ---- Requirements ----
    requirement def DistanceMeasurementRequirement {
        doc "The unit shall measure distance to an object without physical contact.";
        attribute minRange : DistanceValue = 0.02 [m];
        attribute maxRange : DistanceValue = 4.0 [m];
        subject sensor : UltrasonicSensingUnit;
        objective {
            sensor.measuredDistance >= minRange and
            sensor.measuredDistance <= maxRange
        }
    }

    requirement def OperatingTemperatureRequirement {
        doc "The unit shall operate across -20 degC to 60 degC.";
        attribute minTemp : TemperatureValue = -20 [degC];
        attribute maxTemp : TemperatureValue = 60 [degC];
        subject sensor : UltrasonicSensingUnit;
        objective {
            sensor.ambientTemperature >= minTemp and
            sensor.ambientTemperature <= maxTemp
        }
    }

    requirement def TimeOfFlightRequirement {
        doc "The signal processor shall compute distance from time of flight and speed of sound.";
        subject processor : SignalProcessor;
        objective {
            processor.computedDistance == (processor.timeOfFlight * processor.speedOfSound) / 2.0
        }
    }

    // ---- Ports ----
    port def AcousticOutPort {
        out pulse : AcousticPulse;
    }
    port def AcousticInPort {
        in echo : EchoSignal;
    }
    port def TemperaturePort {
        out reading : TemperatureReading;
    }
    port def SpeedPort {
        out speed : SpeedValue;
    }
    port def MeasurementPort {
        out measurement : DistanceMeasurement;
    }
    port def TriggerPort {
        in trigger : Boolean;
    }

    // ---- Transducer ----
    part def UltrasonicTransducer {
        attribute nominalFrequency : FrequencyValue = 40000 [Hz];
        attribute beamAngle : Real = 15.0;
        port acousticOut : AcousticOutPort;
        port acousticIn : AcousticInPort;
        port controlIn : TriggerPort;

        action def EmitPulse {
            in pulse : AcousticPulse;
            out emitted : AcousticPulse;
        }
        action def ReceiveEcho {
            in incoming : EchoSignal;
            out detected : EchoSignal;
        }

        action emit : EmitPulse;
        action receive : ReceiveEcho;
    }

    // ---- Temperature compensator ----
    part def TemperatureCompensator {
        attribute minOperatingTemp : TemperatureValue = -20 [degC];
        attribute maxOperatingTemp : TemperatureValue = 60 [degC];
        port tempOut : TemperaturePort;
        port speedOut : SpeedPort;

        attribute currentTemperature : TemperatureValue;
        attribute correctedSpeed : SpeedValue;

        action def MeasureTemperature {
            out temp : TemperatureValue;
        }
        action def ComputeSpeedOfSound {
            in temp : TemperatureValue;
            out speed : SpeedValue;
        }

        action measureTemp : MeasureTemperature;
        action computeSpeed : ComputeSpeedOfSound;

        satisfy OperatingTemperatureRequirement {
            subject = TemperatureCompensator::self;
        }
    }

    // ---- Signal processor ----
    part def SignalProcessor {
        attribute timeOfFlight : TimeValue;
        attribute speedOfSound : SpeedValue;
        attribute computedDistance : DistanceValue;
        attribute maxTimeout : TimeValue = 0.025 [s];
        attribute minRange : DistanceValue = 0.02 [m];
        attribute maxRange : DistanceValue = 4.0 [m];

        port speedIn : SpeedPort;
        port measurementOut : MeasurementPort;
        port transducerControl : TriggerPort;
        port echoIn : AcousticInPort;

        action def StartTimer {
            out startTime : TimeValue;
        }
        action def StopTimer {
            in startTime : TimeValue;
            in echoArrival : TimeValue;
            out tof : TimeValue;
        }
        action def ComputeDistance {
            in tof : TimeValue;
            in speed : SpeedValue;
            out distance : DistanceValue;
        }
        action def ValidateRange {
            in distance : DistanceValue;
            out valid : Boolean;
        }

        action startTimer : StartTimer;
        action stopTimer : StopTimer;
        action computeDistance : ComputeDistance;
        action validateRange : ValidateRange;

        satisfy TimeOfFlightRequirement {
            subject = SignalProcessor::self;
        }
    }

    // ---- State machine for measurement cycle ----
    state def MeasurementCycle {
        entry; exit;

        state idle {
            entry action { /* ready for next measurement */ }
        }

        state measuring {
            entry action { /* begin measurement cycle */ }
            do action { send trigger; }
            state transmitting {
                entry action { emit pulse; start timer; }
            }
            state listening {
                entry action { wait for echo; }
                transition to timedOut
                    when (timeOfFlight > maxTimeout);
                transition to computing
                    when (echoReceived);
            }
            state computing {
                entry action { stop timer; compute distance; }
            }
            state timedOut {
                entry action { report invalid measurement; }
            }
            state validating {
                entry action { validate range; }
                transition to reporting
                    when (measurement.valid);
                transition to idle
                    when (!measurement.valid);
            }
            state reporting {
                entry action { output measurement; }
            }

            transition transmitting -> listening;
            transition computing -> validating;
            transition reporting -> idle;
        }

        transition idle -> measuring
            when (triggerReceived);
        transition measuring -> idle
            when (cycleComplete);
    }

    // ---- Top-level assembly ----
    part def UltrasonicSensingUnit {
        attribute measuredDistance : DistanceValue;
        attribute ambientTemperature : TemperatureValue;
        attribute measurementValid : Boolean;

        port externalTrigger : TriggerPort;
        port reportedMeasurement : MeasurementPort;

        part transducer : UltrasonicTransducer {
            reframe port acousticOut;
            reframe port acousticIn;
            reframe port controlIn;
        }
        part processor : SignalProcessor {
            reframe port speedIn;
            reframe port measurementOut;
            reframe port transducerControl;
            reframe port echoIn;
        }
        part compensator : TemperatureCompensator {
            reframe port tempOut;
            reframe port speedOut;
        }

        connection : FlowConnection {
            source : compensator.speedOut.speed;
            target : processor.speedIn.speed;
        }
        connection : FlowConnection {
            source : compensator.tempOut.reading;
            target : processor.speedIn;
        }
        connection : FlowConnection {
            source : processor.transducerControl.trigger;
            target : transducer.controlIn.trigger;
        }
        connection : FlowConnection {
            source : transducer.acousticOut.pulse;
            target : external medium;
        }
        connection : FlowConnection {
            source : external medium;
            target : transducer.acousticIn.echo;
        }
        connection : FlowConnection {
            source : transducer.acousticIn.echo;
            target : processor.echoIn.echo;
        }
        connection : FlowConnection {
            source : processor.measurementOut.measurement;
            target : reportedMeasurement.measurement;
        }

        exhibit state measurementBehavior : MeasurementCycle;

        satisfy DistanceMeasurementRequirement {
            subject = UltrasonicSensingUnit::self;
        }
        satisfy OperatingTemperatureRequirement {
            subject = UltrasonicSensingUnit::self;
        }
    }
}
