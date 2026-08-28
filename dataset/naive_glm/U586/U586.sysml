package AcousticRadiometerModel {
    doc /* Acoustic Radiometer - a specialized instrument that measures the total power of a sound wave by detecting the radiation pressure it exerts on a highly absorbent target. */;

    import ScalarValues::*;

    // ===== Value Types with Units =====

    value def ForceValue :> Real {
        doc /* Force in newtons (N). */;
    }

    value def PowerValue :> Real {
        doc /* Acoustic power in watts (W). */;
    }

    value def PressureValue :> Real {
        doc /* Pressure in pascals (Pa). */;
    }

    value def FrequencyValue :> Real {
        doc /* Frequency in hertz (Hz). */;
    }

    value def AreaValue :> Real {
        doc /* Area in square meters (m^2). */;
    }

    value def VelocityValue :> Real {
        doc /* Velocity in meters per second (m/s). */;
    }

    value def DensityValue :> Real {
        doc /* Mass density in kilograms per cubic meter (kg/m^3). */;
    }

    value def VoltageValue :> Real {
        doc /* Electric potential difference in volts (V). */;
    }

    // ===== Item Definitions =====

    item def SoundField {
        doc /* Incoming acoustic field characterized by intensity and sound pressure. */;
        attribute intensity : PowerValue;
        attribute pressure : PressureValue;
    }

    item def RadiationForce {
        doc /* Steady force exerted on the target due to acoustic radiation pressure. */;
        attribute magnitude : ForceValue;
    }

    item def RawSignal {
        doc /* Raw electrical signal output from the force sensor, proportional to detected force. */;
        attribute voltage : VoltageValue;
    }

    item def ConditionedSignal {
        doc /* Amplified and filtered electrical signal from the signal conditioner. */;
        attribute voltage : VoltageValue;
    }

    item def PowerResult {
        doc /* Computed acoustic power measurement result with timestamp. */;
        attribute power : PowerValue;
        attribute timestamp : Real;
    }

    // ===== Port Definitions =====

    port def AcousticInPort {
        in field : SoundField;
    }

    port def ForceOutputPort {
        out force : RadiationForce;
    }

    port def ForceInputPort {
        in force : RadiationForce;
    }

    port def RawSignalOutputPort {
        out signal : RawSignal;
    }

    port def RawSignalInputPort {
        in signal : RawSignal;
    }

    port def ConditionedSignalOutputPort {
        out signal : ConditionedSignal;
    }

    port def ConditionedSignalInputPort {
        in signal : ConditionedSignal;
    }

    port def PowerOutputPort {
        out result : PowerResult;
    }

    port def PowerInputPort {
        in result : PowerResult;
    }

    // ===== Requirement Definitions =====

    requirement def AccuracyRequirement {
        doc /* The acoustic radiometer shall measure acoustic power with an accuracy of at least plus or minus 3 percent. */;
        attribute accuracyThreshold : Real = 0.03;
        attribute maxRelativeError : Real = 0.03;
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate continuously by cycling through measuring, processing, and displaying states to provide rapid updates. */;
        attribute minimumUpdateRate : FrequencyValue;
        attribute maximumLatency : Real;
    }

    requirement def PrecisionMeasurementRequirement {
        doc /* The system shall be designed for high-precision applications requiring steady radiation force detection. */;
        attribute targetAbsorption : Real = 0.99;
        attribute sensorSensitivity : Real;
    }

    // ===== Component Part Definitions =====

    part def AbsorbingTarget {
        doc /* A highly absorbent target that converts incoming sound field energy into a steady radiation pressure force. */;
        port acousticIn : AcousticInPort;
        port forceOut : ForceOutputPort;
        attribute area : AreaValue;
        attribute absorptionCoefficient : Real;
        attribute currentForce : ForceValue;

        action exertRadiationPressure {
            doc /* Converts the acoustic energy of the incoming sound field into a steady radiation force on the target surface. */;
            in field : SoundField;
            out force : RadiationForce;
        }
    }

    part def ForceSensor {
        doc /* A highly sensitive transducer that converts the physical radiation force into a raw electrical signal. */;
        port forceIn : ForceInputPort;
        port signalOut : RawSignalOutputPort;
        attribute sensitivity : Real;
        attribute zeroOffset : VoltageValue;
        attribute measuredVoltage : VoltageValue;

        action convertForceToVoltage {
            doc /* Transduces the detected radiation force magnitude into a proportional electrical voltage signal. */;
            in force : RadiationForce;
            out signal : RawSignal;
        }
    }

    part def SignalConditioner {
        doc /* Amplifies and filters the raw electrical signal to remove noise and produce a clean, reliable conditioned signal. */;
        port signalIn : RawSignalInputPort;
        port signalOut : ConditionedSignalOutputPort;
        attribute gain : Real;
        attribute cutoffFrequency : FrequencyValue;
        attribute noiseFloor : VoltageValue;
        attribute outputVoltage : VoltageValue;

        action amplifyAndFilter {
            doc /* Applies gain amplification and low-pass filtering to the raw signal to remove noise and ensure a clean reading. */;
            in raw : RawSignal;
            out conditioned : ConditionedSignal;
        }
    }

    part def ComputationUnit {
        doc /* Processes the conditioned signal using known physical properties of the medium and a calibration factor to compute acoustic power. */;
        port signalIn : ConditionedSignalInputPort;
        port powerOut : PowerOutputPort;
        attribute mediumDensity : DensityValue;
        attribute speedOfSound : VelocityValue;
        attribute calibrationFactor : Real;
        attribute computedPower : PowerValue;

        action computeAcousticPower {
            doc /* Calculates the original acoustic power of the wave based on the measured force, medium density, speed of sound, and calibration factor. */;
            in signal : ConditionedSignal;
            in density : DensityValue;
            in speed : VelocityValue;
            in calibFactor : Real;
            out result : PowerResult;
        }
    }

    part def DisplayUnit {
        doc /* Presents the computed acoustic power measurement to the operator with a clear reading. */;
        port powerIn : PowerInputPort;
        attribute displayedValue : PowerValue;
        attribute resolution : PowerValue;

        action showReading {
            doc /* Renders the computed acoustic power on the display for operator observation. */;
            in result : PowerResult;
        }
    }

    // ===== State Machine Definition =====

    state def AcousticRadiometerStates {
        doc /* Continuous operation state machine cycling through measuring, processing, and displaying to provide rapid updates. */;
        state measuring {
            doc /* The target is exposed to the incoming sound field and the force sensor acquires the raw radiation force signal. */;
        }
        state processing {
            doc /* The signal conditioner amplifies and filters the signal; the computation unit computes the acoustic power. */;
        }
        state displaying {
            doc /* The display unit presents the computed acoustic power to the operator. */;
        }
        transition from measuring to processing;
        transition from processing to displaying;
        transition from displaying to measuring;
    }

    // ===== Top-Level Acoustic Radiometer System =====

    part AcousticRadiometerSystem {
        doc /* Complete Acoustic Radiometer system composing all interconnected components for high-precision acoustic power measurement. */;

        port acousticInput : AcousticInPort;

        part target : AbsorbingTarget {
            port acousticIn : AcousticInPort;
            port forceOut : ForceOutputPort;
            attribute area : AreaValue = 0.01;
            attribute absorptionCoefficient : Real = 0.99;
        }

        part sensor : ForceSensor {
            port forceIn : ForceInputPort;
            port signalOut : RawSignalOutputPort;
            attribute sensitivity : Real = 1.0;
            attribute zeroOffset : VoltageValue = 0.0;
        }

        part conditioner : SignalConditioner {
            port signalIn : RawSignalInputPort;
            port signalOut : ConditionedSignalOutputPort;
            attribute gain : Real = 100.0;
            attribute cutoffFrequency : FrequencyValue = 1000.0;
            attribute noiseFloor : VoltageValue = 0.001;
        }

        part processor : ComputationUnit {
            port signalIn : ConditionedSignalInputPort;
            port powerOut : PowerOutputPort;
            attribute mediumDensity : DensityValue = 1.2;
            attribute speedOfSound : VelocityValue = 343.0;
            attribute calibrationFactor : Real = 1.0;
        }

        part display : DisplayUnit {
            port powerIn : PowerInputPort;
            attribute resolution : PowerValue = 0.001;
        }

        // Inter-component connections
        connection acousticInputToTarget from acousticInput to target.acousticIn;
        connection forceToSensor from target.forceOut to sensor.forceIn;
        connection rawToConditioner from sensor.signalOut to conditioner.signalIn;
        connection conditionedToProcessor from conditioner.signalOut to processor.signalIn;
        connection powerToDisplay from processor.powerOut to display.powerIn;

        // Continuous operation state machine
        exhibit state operationCycle : AcousticRadiometerStates;

        // Requirements
        requirement accReq : AccuracyRequirement;
        requirement contReq : ContinuousOperationRequirement;
        requirement precReq : PrecisionMeasurementRequirement;

        satisfy accReq by operationCycle;
        satisfy contReq by operationCycle;
        satisfy precReq by target;
    }
}
