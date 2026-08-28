package CapacitiveSensingSystem {
    import ScalarValues::*;
    import SIUnits::*;
    import ISQ::*;

    // ---- Units ----
    unit def picofarad;
    unit def volt;
    unit def kilohertz;
    unit def megahertz;
    unit def millimeter;
    unit def milliampere;
    unit def millisecond;

    // ---- Value types ----
    value def Capacitance :> Real { unit picofarad; }
    value def Voltage :> Real { unit volt; }
    value def Frequency :> Real { unit kilohertz; }
    value def Distance :> Real { unit millimeter; }
    value def Current :> Real { unit milliampere; }
    value def Time :> Real { unit millisecond; }
    value def Gain :> Real;

    // ---- Item types ----
    item def ExcitationSignal {
        attribute frequency : Frequency;
        attribute amplitude : Voltage;
    }

    item def ElectrodeResponse {
        attribute rawVoltage : Voltage;
        attribute noiseLevel : Voltage;
        attribute parasiticCapacitance : Capacitance;
    }

    item def ConditionedSignal {
        attribute voltage : Voltage;
        attribute gain : Gain;
        attribute snr : Real;
    }

    item def CapacitanceReading {
        attribute value : Capacitance;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }

    item def DetectionEvent {
        attribute kind : String;
        attribute distance : Distance;
        attribute deltaC : Capacitance;
        attribute confidence : Real;
    }

    item def PowerRail {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute stable : Boolean;
    }

    // ---- Port definitions ----
    port def ExcitationPort {
        out excitation : ExcitationSignal;
    }

    port def ResponsePort {
        in response : ElectrodeResponse;
    }

    port def ConditionedPort {
        out signal : ConditionedSignal;
    }

    port def DigitalPort {
        out reading : CapacitanceReading;
    }

    port def PowerPort {
        in rail : PowerRail;
    }

    port def EventPort {
        out event : DetectionEvent;
    }

    // ---- Part definitions ----
    part def ExcitationGenerator {
        attribute nominalFrequency : Frequency = 1000.0;
        attribute nominalAmplitude : Voltage = 3.3;
        attribute dutyCycle : Real = 0.5;
        port excitationOut : ExcitationPort;
        port powerIn : PowerPort;

        action def generateExcitation {
            in p : PowerRail;
            out s : ExcitationSignal;
        }

        perform generateExcitation;
    }

    part def SensingElectrode {
        attribute area : Real;
        attribute baselineCapacitance : Capacitance;
        attribute currentCapacitance : Capacitance;
        port excitationIn : ExcitationPort;
        port responseOut : ResponsePort;

        action def sense {
            in excitation : ExcitationSignal;
            out response : ElectrodeResponse;
        }

        perform sense;
    }

    part def SignalConditioner {
        attribute gain : Gain = 100.0;
        attribute bandwidth : Frequency = 50.0;
        attribute offsetCompensation : Voltage = 0.0;
        port responseIn : ResponsePort;
        port signalOut : ConditionedPort;
        port powerIn : PowerPort;

        action def condition {
            in r : ElectrodeResponse;
            in p : PowerRail;
            out s : ConditionedSignal;
        }

        perform condition;
    }

    part def CapacitanceConverter {
        attribute resolution : Integer = 16;
        attribute sampleRate : Frequency = 1.0;
        attribute fullScale : Capacitance = 100.0;
        port signalIn : ConditionedPort;
        port digitalOut : DigitalPort;
        port powerIn : PowerPort;

        action def convert {
            in s : ConditionedSignal;
            in p : PowerRail;
            out reading : CapacitanceReading;
        }

        perform convert;
    }

    part def ProcessingUnit {
        attribute baseline : Capacitance;
        attribute proximityThreshold : Capacitance = 0.5;
        attribute touchThreshold : Capacitance = 2.0;
        attribute currentReading : Capacitance;
        attribute deltaC : Capacitance;
        attribute estimatedDistance : Distance;
        attribute calibrationSamples : Integer = 0;
        attribute calibrationTarget : Integer = 64;
        port readingIn : DigitalPort;
        port eventOut : EventPort;
        port powerIn : PowerPort;

        action def calibrate {
            in reading : CapacitanceReading;
            out newBaseline : Capacitance;
        }

        action def evaluate {
            in reading : CapacitanceReading;
            out event : DetectionEvent;
        }

        state machine DetectionStateMachine {
            initial state idle {
                entry { /* low-power standby awaiting power-up */ }
            }

            state calibration {
                entry { calibrationSamples = 0; }
                do { perform calibrate; }
            }

            state monitoring {
                do { perform evaluate; }
            }

            state proximityActive {
                do { perform evaluate; }
            }

            state touchActive {
                do { perform evaluate; }
            }

            transition from idle to calibration
                when powerIn.rail.stable == true;

            transition from calibration to monitoring
                when calibrationSamples >= calibrationTarget
                    and baseline > 0.0;

            transition from monitoring to proximityActive
                when deltaC > proximityThreshold
                    and deltaC <= touchThreshold;

            transition from monitoring to touchActive
                when deltaC > touchThreshold;

            transition from proximityActive to touchActive
                when deltaC > touchThreshold;

            transition from proximityActive to monitoring
                when deltaC <= proximityThreshold;

            transition from touchActive to monitoring
                when deltaC <= touchThreshold;
        }

        state machine DetectionStateMachine;
    }

    part def PowerManagement {
        attribute inputVoltage : Voltage = 5.0;
        attribute regulatedVoltage : Voltage = 3.3;
        attribute maxCurrent : Current = 500.0;
        attribute efficiency : Real = 0.9;
        port railOut : PowerPort;

        action def regulate {
            out rail : PowerRail;
        }

        perform regulate;
    }

    // ---- Top-level system ----
    part def CapacitiveSensingSystem {
        attribute systemName : String = "Capacitive Touch and Proximity Sensor";
        attribute designVersion : String = "1.0";

        part excitationGenerator : ExcitationGenerator;
        part sensingElectrode : SensingElectrode;
        part signalConditioner : SignalConditioner;
        part capacitanceConverter : CapacitanceConverter;
        part processingUnit : ProcessingUnit;
        part powerManagement : PowerManagement;

        connection excitationLink
            connect excitationGenerator.excitationOut
            to sensingElectrode.excitationIn;

        connection responseLink
            connect sensingElectrode.responseOut
            to signalConditioner.responseIn;

        connection conditionedLink
            connect signalConditioner.signalOut
            to capacitanceConverter.signalIn;

        connection digitalLink
            connect capacitanceConverter.digitalOut
            to processingUnit.readingIn;

        connection powerToGenerator
            connect powerManagement.railOut
            to excitationGenerator.powerIn;

        connection powerToConditioner
            connect powerManagement.railOut
            to signalConditioner.powerIn;

        connection powerToConverter
            connect powerManagement.railOut
            to capacitanceConverter.powerIn;

        connection powerToProcessor
            connect powerManagement.railOut
            to processingUnit.powerIn;

        port externalEventOut : EventPort;

        connection eventLink
            connect processingUnit.eventOut
            to externalEventOut;
    }

    // ---- Requirements ----
    requirement def CapacitiveSensingRequirements {
        subject system : CapacitiveSensingSystem;

        requirement NonPressureSensing {
            doc {
                The system shall detect the touch and proximity of conductive
                objects, such as a human finger, without requiring physical
                pressure on the sensing electrode.
            }
        }

        requirement StableExcitation {
            doc {
                The Excitation Generator shall produce a stable high-frequency
                electric field around the Sensing Electrode.
            }
        }

        requirement SignalConditioning {
            doc {
                The Signal Conditioner shall amplify the weak electrode
                response and filter environmental noise to produce a clear
                analog signal.
            }
        }

        requirement CapacitanceDigitization {
            doc {
                The Capacitance Converter shall convert the conditioned analog
                signal into a precise digital capacitance value.
            }
        }

        requirement BaselineCalibration {
            doc {
                The Processing Unit shall establish a baseline capacitance
                during a calibration phase prior to active monitoring.
            }
        }

        requirement ProximityDetection {
            doc {
                The Processing Unit shall report a proximity event when the
                capacitance change exceeds the proximity threshold but not
                the touch threshold, and shall estimate the distance of the
                approaching object.
            }
        }

        requirement TouchDetection {
            doc {
                The Processing Unit shall register a definitive touch event
                when the capacitance change exceeds the touch threshold.
            }
        }

        requirement StateBehavior {
            doc {
                The system shall operate through the states idle, calibration,
                monitoring, proximityActive, and touchActive, returning to
                monitoring when the interaction ends.
            }
        }

        requirement PowerStability {
            doc {
                The Power Management unit shall provide a stable regulated
                voltage to all components under all operating states.
            }
        }

        satisfy NonPressureSensing by system;
        satisfy StableExcitation by system.excitationGenerator;
        satisfy SignalConditioning by system.signalConditioner;
        satisfy CapacitanceDigitization by system.capacitanceConverter;
        satisfy BaselineCalibration by system.processingUnit;
        satisfy ProximityDetection by system.processingUnit;
        satisfy TouchDetection by system.processingUnit;
        satisfy StateBehavior by system.processingUnit;
        satisfy PowerStability by system.powerManagement;
    }
}
