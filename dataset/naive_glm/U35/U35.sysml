package Ammoniaphone {
    import ScalarValues::*;

    // ================================================================
    // VALUE TYPES (with units)
    // ================================================================

    value type Temperature :> Real {
        doc /* Thermodynamic temperature in Kelvin (K) */
    }

    value type Pressure :> Real {
        doc /* Pressure in Pascals (Pa) */
    }

    value type VolumetricFlowRate :> Real {
        doc /* Volumetric flow rate in liters per second (L/s) */
    }

    value type Frequency :> Real {
        doc /* Frequency in Hertz (Hz) */
    }

    value type SoundPressureLevel :> Real {
        doc /* Sound pressure level in decibels (dB SPL) */
    }

    value type Voltage :> Real {
        doc /* Electric potential in Volts (V) */
    }

    value type ElectricCurrent :> Real {
        doc /* Electric current in milliamperes (mA) */
    }

    value type Power :> Real {
        doc /* Power in Watts (W) */
    }

    value type Duration :> Real {
        doc /* Duration in seconds (s) */
    }

    value type Volume :> Real {
        doc /* Volume in liters (L) */
    }

    value type Length :> Real {
        doc /* Length in meters (m) */
    }

    // ================================================================
    // ITEM DEFINITIONS
    // ================================================================

    item def AmmoniaGas {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        doc /* Ammonia (NH3) gas stored in the reservoir, serving as the instrument's fuel source */
    }

    item def HeatedAmmoniaGas :> AmmoniaGas {
        doc /* Ammonia gas that has been heated above ambient temperature in the heating chamber */
    }

    item def SoundWave {
        attribute frequency : Frequency;
        attribute amplitude : SoundPressureLevel;
        doc /* Acoustic wave produced by the resonance cavity */
    }

    item def ControlSignal {
        attribute targetFrequency : Frequency;
        attribute targetVolume : SoundPressureLevel;
        attribute controlVoltage : Voltage;
        attribute controlCurrent : ElectricCurrent;
        doc /* Electrical signal encoding the desired pitch and volume for the flow regulator and heating chamber */
    }

    item def SystemCommand {
        attribute commandType : String;
        attribute desiredFrequency : Frequency;
        attribute desiredVolume : SoundPressureLevel;
        doc /* Operator command to start or stop sound production, with target pitch and volume */
    }

    item def HeatingStatus {
        attribute currentTemperature : Temperature;
        attribute targetTemperature : Temperature;
        attribute currentPower : Power;
        doc /* Status report from the heating chamber indicating current and target temperatures */
    }

    // ================================================================
    // PORT DEFINITIONS
    // ================================================================

    port def GasOutletPort {
        out item gas : AmmoniaGas;
        attribute flowRate : VolumetricFlowRate;
        doc /* Port that outputs ammonia gas with a specified flow rate */
    }

    port def GasInletPort {
        in item gas : AmmoniaGas;
        attribute flowRate : VolumetricFlowRate;
        doc /* Port that receives ammonia gas with a specified flow rate */
    }

    port def HeatedGasOutletPort {
        out item heatedGas : HeatedAmmoniaGas;
        attribute flowRate : VolumetricFlowRate;
        attribute gasTemperature : Temperature;
        doc /* Port that outputs heated ammonia gas with flow rate and temperature */
    }

    port def HeatedGasInletPort {
        in item heatedGas : HeatedAmmoniaGas;
        attribute flowRate : VolumetricFlowRate;
        attribute gasTemperature : Temperature;
        doc /* Port that receives heated ammonia gas with flow rate and temperature */
    }

    port def ControlSignalOut {
        out item signal : ControlSignal;
        doc /* Port that outputs a control signal to a downstream component */
    }

    port def ControlSignalIn {
        in item signal : ControlSignal;
        doc /* Port that receives a control signal from an upstream component */
    }

    port def CommandIn {
        in item command : SystemCommand;
        doc /* Port that receives an operator command */
    }

    port def StatusOut {
        out item status : HeatingStatus;
        doc /* Port that outputs heating chamber status information */
    }

    port def StatusIn {
        in item status : HeatingStatus;
        doc /* Port that receives heating chamber status information */
    }

    port def AcousticOut {
        out item sound : SoundWave;
        attribute frequency : Frequency;
        attribute level : SoundPressureLevel;
        doc /* Port that outputs acoustic energy as a sound wave */
    }

    port def AcousticIn {
        in item sound : SoundWave;
        attribute frequency : Frequency;
        attribute level : SoundPressureLevel;
        doc /* Port that receives acoustic energy as a sound wave */
    }

    // ================================================================
    // PART DEFINITIONS
    // ================================================================

    part def AmmoniaReservoir {
        port gasOutlet : GasOutletPort;
        attribute maxCapacity : Volume = 50.0;
        attribute currentLevel : Volume = 50.0;
        attribute storagePressure : Pressure = 8.0e5;
        attribute storageTemperature : Temperature = 293.15;
        attribute minLevel : Volume = 5.0;
        doc /* High-pressure storage vessel for ammonia (NH3) gas. Stores the instrument's fuel at approximately 8 bar and 20 degrees C. */
        constraint levelConstraint {
            currentLevel >= 0.0 and currentLevel <= maxCapacity
        }
        constraint minLevelConstraint {
            currentLevel >= minLevel
        }
    }

    part def ControlUnit {
        port commandInput : CommandIn;
        port flowControlOutput : ControlSignalOut;
        port heatingControlOutput : ControlSignalOut;
        port heatingStatusInput : StatusIn;
        attribute supplyVoltage : Voltage = 12.0;
        attribute maxOutputCurrent : ElectricCurrent = 500.0;
        attribute minFrequency : Frequency = 65.0;
        attribute maxFrequency : Frequency = 2000.0;
        doc /* Electronic controller that translates operator commands into precise electrical control signals for the flow regulator and heating chamber. Accepts pitch and volume commands and outputs proportional voltage and current signals. */

        action def processCommand {
            in cmd : SystemCommand;
            out flowSignal : ControlSignal;
            out heatingSignal : ControlSignal;
            doc /* Converts a system command into separate control signals for the flow regulator and heating chamber */
        }

        constraint frequencyRange {
            minFrequency >= 65.0 and maxFrequency <= 2000.0
        }
    }

    part def FlowRegulator {
        port gasInlet : GasInletPort;
        port gasOutlet : GasOutletPort;
        port controlInput : ControlSignalIn;
        attribute maxFlowRate : VolumetricFlowRate = 5.0;
        attribute responseTime : Duration = 0.05;
        attribute currentFlowRate : VolumetricFlowRate;
        doc /* Solenoid-driven proportional valve that meters the release of ammonia gas from the reservoir. Flow rate is proportional to the control signal voltage. */

        action def regulateFlow {
            in signal : ControlSignal;
            in inletGas : AmmoniaGas;
            out outletGas : AmmoniaGas;
            doc /* Adjusts the gas flow rate based on the control signal */
        }

        constraint flowRange {
            currentFlowRate >= 0.0 and currentFlowRate <= maxFlowRate
        }
    }

    part def HeatingChamber {
        port gasInlet : GasInletPort;
        port heatedGasOutlet : HeatedGasOutletPort;
        port controlInput : ControlSignalIn;
        port statusOutput : StatusOut;
        attribute operatingTemperature : Temperature = 573.15;
        attribute warmupTime : Duration = 30.0;
        attribute heatingPower : Power = 2000.0;
        attribute thermalEfficiency : Real = 0.85;
        attribute currentTemperature : Temperature = 293.15;
        attribute cooldownTarget : Temperature = 323.15;
        attribute maxSafeTemperature : Temperature = 773.15;
        doc /* Electrical heating element enclosed in a thermally-insulated chamber. Raises the temperature of ammonia gas from ambient to the operating temperature before it enters the resonance cavity. */

        action def warmUp {
            doc /* Heats the chamber from ambient to operating temperature */
        }

        action def maintainTemperature {
            doc /* Maintains the gas at the operating temperature during play */
        }

        action def coolDown {
            doc /* Allows the chamber to cool to a safe handling temperature */
        }

        constraint tempSafety {
            currentTemperature <= maxSafeTemperature
        }

        constraint warmupTimeConstraint {
            warmupTime <= 30.0
        }
    }

    part def ResonanceCavity {
        port heatedGasInlet : HeatedGasInletPort;
        port acousticOutlet : AcousticOut;
        attribute cavityLength : Length = 0.5;
        attribute cavityDiameter : Length = 0.08;
        attribute qualityFactor : Real = 15.0;
        attribute outputFrequency : Frequency;
        attribute outputLevel : SoundPressureLevel;
        doc /* Tuned cylindrical resonant chamber where heated ammonia gas is excited to produce a standing acoustic wave at a specific fundamental frequency. The cavity dimensions and gas properties determine the resonant frequency. */

        action def generateSound {
            in heatedGas : HeatedAmmoniaGas;
            in targetFrequency : Frequency;
            out sound : SoundWave;
            doc /* Excites the heated gas to produce a sound wave at the target frequency */
        }
    }

    part def AmplificationBell {
        port acousticInlet : AcousticIn;
        port acousticOutlet : AcousticOut;
        attribute acousticGain : Real = 15.0;
        attribute bellFlareRadius : Length = 0.12;
        attribute bellLength : Length = 0.35;
        doc /* Flared acoustic horn, similar to the bell of a trumpet or trombone, that amplifies the sound wave from the resonance cavity and projects it outward. Provides approximately 15 dB of acoustic gain. */

        action def amplifySound {
            in inputSound : SoundWave;
            out outputSound : SoundWave;
            doc /* Amplifies and projects the incoming sound wave */
        }
    }

    // ================================================================
    // STATE MACHINE DEFINITION
    // ================================================================

    state def AmmoniaphoneStateMachine {
        doc /* State machine governing the operational phases of the Ammoniaphone. Cycles through Idle, Warming, Playing, and Cooling states based on operator commands and thermal conditions. */

        state idle {
            doc /* System is powered on but not actively producing sound. Ready to receive a start command. All subsystems in standby mode. */
            entry action {
                doc /* Reset all subsystems to standby */
            }
        }

        state warming {
            doc /* Heating chamber is warming up from ambient temperature to the operating temperature. Gas flow is off during this phase. */
            entry action {
                doc /* Activate heating element at full power */
            }
            do action {
                doc /* Monitor chamber temperature until operating temperature is reached */
            }
            exit action {
                doc /* Confirm chamber at operating temperature, reduce heating power to maintenance level */
            }
        }

        state playing {
            doc /* System is actively producing sound. Heated ammonia gas flows through the resonance cavity, generating acoustic waves that are amplified by the bell. */
            entry action {
                doc /* Open flow regulator, begin gas flow to heating chamber and resonance cavity */
            }
            do action {
                doc /* Continuously regulate gas flow, heating power, and resonance frequency based on operator input */
            }
            exit action {
                doc /* Close flow regulator, stop gas flow to resonance cavity */
            }
        }

        state cooling {
            doc /* Heating chamber is cooling down from operating temperature to a safe handling temperature. Gas flow is off. */
            entry action {
                doc /* Disable heating element, activate cooling if available */
            }
            do action {
                doc /* Monitor chamber temperature until safe handling temperature is reached */
            }
            exit action {
                doc /* Confirm chamber at safe temperature, return all subsystems to standby */
            }
        }

        transition from idle to warming when startCommand;
        transition from warming to playing when chamberReady;
        transition from playing to cooling when stopCommand;
        transition from cooling to idle when cooledDown;
    }

    // ================================================================
    // TOP-LEVEL SYSTEM DEFINITION
    // ================================================================

    part def AmmoniaphoneSystem {
        port commandInput : CommandIn;
        port soundOutput : AcousticOut;

        part reservoir : AmmoniaReservoir;
        part controller : ControlUnit;
        part regulator : FlowRegulator;
        part heater : HeatingChamber;
        part cavity : ResonanceCavity;
        part bell : AmplificationBell;

        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute chamberReady : Boolean = false;
        attribute cooledDown : Boolean = false;
        attribute chamberTemperature : Temperature = 293.15;
        attribute operatingTemperature : Temperature = 573.15;
        attribute cooldownTemperature : Temperature = 323.15;
        attribute activeFrequency : Frequency;
        attribute activeVolume : SoundPressureLevel;

        connect reservoir.gasOutlet to regulator.gasInlet;
        connect controller.flowControlOutput to regulator.controlInput;
        connect regulator.gasOutlet to heater.gasInlet;
        connect controller.heatingControlOutput to heater.controlInput;
        connect heater.statusOutput to controller.heatingStatusInput;
        connect heater.heatedGasOutlet to cavity.heatedGasInlet;
        connect cavity.acousticOutlet to bell.acousticInlet;
        connect commandInput to controller.commandInput;
        connect bell.acousticOutlet to soundOutput;

        state operationState : AmmoniaphoneStateMachine;

        doc /* The Ammoniaphone: a sound-generating musical instrument that converts the chemical potential energy of heated ammonia gas into acoustic energy. Ammonia gas is released from a reservoir, heated in a chamber, and directed into a resonance cavity where it produces sound waves that are amplified and projected by a bell. */
    }

    // ================================================================
    // REQUIREMENTS
    // ================================================================

    requirement def SoundGenerationReq {
        doc /* The Ammoniaphone shall generate audible sound from heated ammonia gas */
        subject ammoniaphone : AmmoniaphoneSystem;
        requirement {
            doc /* The system shall produce sound waves with frequencies between 65 Hz and 2000 Hz */
        }
        requirement {
            doc /* The system shall produce sound at a minimum of 85 dB SPL at 1 meter distance */
        }
    }

    requirement def AmmoniaStorageReq {
        doc /* The ammonia reservoir shall store sufficient gas for at least 30 minutes of continuous play */
        subject reservoir : AmmoniaReservoir;
        requirement {
            doc /* The reservoir shall have a minimum capacity of 50 liters at 8 bar pressure */
        }
        requirement {
            doc /* The system shall alert the operator when the reservoir level falls below 5 liters */
        }
    }

    requirement def HeatingChamberReq {
        doc /* The heating chamber shall heat ammonia gas to the operating temperature within 30 seconds */
        subject heater : HeatingChamber;
        requirement {
            doc /* The operating temperature shall be 573.15 K plus or minus 10 K */
        }
        requirement {
            doc /* The heating chamber shall not exceed 773.15 K under any conditions */
        }
    }

    requirement def StateMachineReq {
        doc /* The Ammoniaphone shall operate through Idle, Warming, Playing, and Cooling states */
        subject ammoniaphone : AmmoniaphoneSystem;
        requirement {
            doc /* The system shall transition from Idle to Warming upon receiving a start command */
        }
        requirement {
            doc /* The system shall transition from Warming to Playing when the heating chamber reaches the operating temperature */
        }
        requirement {
            doc /* The system shall transition from Playing to Cooling upon receiving a stop command */
        }
        requirement {
            doc /* The system shall transition from Cooling to Idle when the heating chamber reaches a safe handling temperature of 323.15 K */
        }
    }

    requirement def AmplificationReq {
        doc /* The amplification bell shall amplify and project sound outward */
        subject bell : AmplificationBell;
        requirement {
            doc /* The bell shall provide at least 15 dB of acoustic gain */
        }
        requirement {
            doc /* The bell shall project sound in a directional pattern with a dispersion angle of approximately 60 degrees */
        }
    }

    requirement def FlowControlReq {
        doc /* The flow regulator shall precisely control the release of ammonia gas */
        subject regulator : FlowRegulator;
        requirement {
            doc /* The flow regulator shall have a response time of less than 50 milliseconds */
        }
        requirement {
            doc /* The flow regulator shall support flow rates from 0 to 5 liters per second */
        }
    }
}
