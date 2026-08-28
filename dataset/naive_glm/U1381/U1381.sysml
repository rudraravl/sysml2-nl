package CesiumAtomicClockSystem {
    import ScalarValues::*;

    // Value Types with Units
    attribute def Frequency :> Real { attribute unit : String = "Hz"; }
    attribute def Pressure :> Real { attribute unit : String = "Pa"; }
    attribute def Temperature :> Real { attribute unit : String = "K"; }
    attribute def Voltage :> Real { attribute unit : String = "V"; }
    attribute def Power :> Real { attribute unit : String = "W"; }

    // Items
    item def ElectricPower {
        attribute power : Power;
        attribute voltage : Voltage;
    }
    item def RFSignal {
        attribute frequency : Frequency;
        attribute power : Power;
    }
    item def MicrowaveSignal {
        attribute frequency : Frequency;
        attribute power : Power;
    }
    item def AtomicResponse {
        attribute amplitude : Real;
        attribute phase : Real;
    }
    item def ErrorSignal {
        attribute voltage : Voltage;
    }
    item def CorrectionSignal {
        attribute voltage : Voltage;
    }
    item def TimePulse {
        attribute frequency : Frequency;
    }

    // Requirements
    requirement def HighPrecisionTimekeepingReq {
        doc "The system shall generate a highly stable and accurate time reference based on Cesium-133 resonance frequency.";
    }
    requirement def IsolationReq {
        doc "The resonator shall be kept in an ultra-high vacuum and protected from external magnetic interference.";
    }
    requirement def TemperatureStabilityReq {
        doc "The resonator shall be kept at a precise and stable operating temperature.";
    }
    requirement def FeedbackLoopReq {
        doc "A phase detector and servo controller shall lock the crystal oscillator to the atomic resonance.";
    }
    requirement def OutputReq {
        doc "A frequency divider shall produce a standard one-pulse-per-second time signal from the locked oscillator.";
    }
    requirement def SystemStateReq {
        doc "The system shall operate through Initialization, Warming Up, Stabilization, Locked, Operational, and Fault states with reset capability.";
    }

    // Component Definitions
    part def PowerSupply {
        out port powerOut : ElectricPower;
        attribute outputPower : Power;
        attribute outputVoltage : Voltage;
    }

    part def VacuumChamber {
        attribute internalPressure : Pressure;
    }

    part def MagneticShield {
        attribute shieldingFactor : Real;
    }

    part def TemperatureController {
        in port powerIn : ElectricPower;
        attribute targetTemperature : Temperature;
        attribute currentTemperature : Temperature;
        action def regulate;
    }

    part def CesiumResonator {
        in port powerIn : ElectricPower;
        in port mwIn : MicrowaveSignal;
        out port responseOut : AtomicResponse;

        attribute resonanceFrequency : Frequency = 9192631770;

        part vacuumChamber : VacuumChamber;
        part magneticShield : MagneticShield;
        part tempController : TemperatureController;

        connect powerIn to tempController.powerIn;

        action def interrogate {
            in mw : MicrowaveSignal;
            out response : AtomicResponse;
        }
    }

    part def CrystalOscillator {
        in port powerIn : ElectricPower;
        in port correctionIn : CorrectionSignal;
        out port rfOut : RFSignal;

        attribute nominalFrequency : Frequency = 10000000;
        attribute currentFrequency : Frequency;

        action def tune {
            in correction : CorrectionSignal;
        }
    }

    part def FrequencyMultiplier {
        in port powerIn : ElectricPower;
        in port rfIn : RFSignal;
        out port mwOut : MicrowaveSignal;
        attribute multiplicationFactor : Real;
        action def multiply;
    }

    part def PhaseDetector {
        in port powerIn : ElectricPower;
        in port mwIn : MicrowaveSignal;
        in port responseIn : AtomicResponse;
        out port errorOut : ErrorSignal;

        action def compare {
            in mw : MicrowaveSignal;
            in resp : AtomicResponse;
            out error : ErrorSignal;
        }
    }

    part def ServoController {
        in port powerIn : ElectricPower;
        in port errorIn : ErrorSignal;
        out port correctionOut : CorrectionSignal;
        attribute gain : Real;

        action def compute {
            in error : ErrorSignal;
            out correction : CorrectionSignal;
        }
    }

    part def FrequencyDivider {
        in port powerIn : ElectricPower;
        in port rfIn : RFSignal;
        out port timeOut : TimePulse;
        attribute divisionFactor : Integer = 10000000;
        action def divide;
    }

    // Action Definitions for State Machine
    action def initializeSystem;
    action def startHeaters;
    action def closeFeedbackLoop;
    action def verifyFrequencyLock;
    action def enableTimeOutputs;
    action def logFault;

    // State Machine Definition
    state def ClockBehavior {
        state initialization {
            entry perform initializeSystem;
        }
        state warmingUp {
            entry perform startHeaters;
        }
        state stabilization {
            entry perform closeFeedbackLoop;
        }
        state locked {
            entry perform verifyFrequencyLock;
        }
        state operational {
            entry perform enableTimeOutputs;
        }
        state fault {
            entry perform logFault;
        }

        transition init_to_warm {
            from initialization;
            to warmingUp;
        }
        transition warm_to_stab {
            from warmingUp;
            to stabilization;
        }
        transition stab_to_lock {
            from stabilization;
            to locked;
        }
        transition lock_to_op {
            from locked;
            to operational;
        }
        transition op_to_fault {
            from operational;
            to fault;
        }
        transition lock_to_fault {
            from locked;
            to fault;
        }
        transition stab_to_fault {
            from stabilization;
            to fault;
        }
        transition warm_to_fault {
            from warmingUp;
            to fault;
        }
        transition init_to_fault {
            from initialization;
            to fault;
        }
        transition fault_to_init {
            from fault;
            to initialization;
        }
    }

    // Main System Definition
    part def CesiumAtomicClock {
        requirement highPrecisionReq : HighPrecisionTimekeepingReq;
        requirement isolationReq : IsolationReq;
        requirement tempStabReq : TemperatureStabilityReq;
        requirement feedbackReq : FeedbackLoopReq;
        requirement outputReq : OutputReq;
        requirement stateReq : SystemStateReq;

        part powerSupply : PowerSupply;
        part crystalOscillator : CrystalOscillator;
        part frequencyMultiplier : FrequencyMultiplier;
        part cesiumResonator : CesiumResonator;
        part phaseDetector : PhaseDetector;
        part servoController : ServoController;
        part frequencyDivider : FrequencyDivider;

        out port timeOutput : TimePulse;

        // Power Connections
        connect powerSupply.powerOut to crystalOscillator.powerIn;
        connect powerSupply.powerOut to frequencyMultiplier.powerIn;
        connect powerSupply.powerOut to cesiumResonator.powerIn;
        connect powerSupply.powerOut to phaseDetector.powerIn;
        connect powerSupply.powerOut to servoController.powerIn;
        connect powerSupply.powerOut to frequencyDivider.powerIn;

        // RF and Microwave Connections
        connect crystalOscillator.rfOut to frequencyMultiplier.rfIn;
        connect frequencyMultiplier.mwOut to cesiumResonator.mwIn;
        connect frequencyMultiplier.mwOut to phaseDetector.mwIn;

        // Feedback Loop Connections
        connect cesiumResonator.responseOut to phaseDetector.responseIn;
        connect phaseDetector.errorOut to servoController.errorIn;
        connect servoController.correctionOut to crystalOscillator.correctionIn;

        // Output Connections
        connect crystalOscillator.rfOut to frequencyDivider.rfIn;
        connect frequencyDivider.timeOut to timeOutput;

        // Behavior
        perform clockBehavior : ClockBehavior;
    }
}
