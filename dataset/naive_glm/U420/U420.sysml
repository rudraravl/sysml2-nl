package TENS_Device_System {

    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit volt;
    unit milliampere;
    unit hertz;
    unit microsecond;
    unit ohm;
    unit percent;
    unit second;

    // ===== Value Type Definitions =====
    value def VoltageValue :> Real;
    value def CurrentValue :> Real;
    value def FrequencyValue :> Real;
    value def PulseWidthValue :> Real;
    value def ImpedanceValue :> Real;
    value def IntensityValue :> Real;
    value def TimeDurationValue :> Real;
    value def ChargeLevelValue :> Real;

    // ===== Enumeration Definitions =====
    enum def TherapyMode {
        continuous;
        burst;
        modulated;
    }

    enum def DeviceState {
        off;
        standby;
        active;
        fault;
    }

    enum def FaultType {
        electrodeContactLoss;
        overCurrent;
        lowBattery;
    }

    // ===== Item Definitions =====
    item def Power;
    item def ControlCommand;
    item def PulseInstruction;
    item def ElectricalPulse;
    item def ImpedanceMeasurement;
    item def CurrentMeasurement;
    item def SafetyAlert;

    // ===== Port Definitions =====
    port def PowerOutputPort {
        out power : Power;
    }

    port def PowerInputPort {
        in power : Power;
    }

    port def CommandOutputPort {
        out command : ControlCommand;
    }

    port def CommandInputPort {
        in command : ControlCommand;
    }

    port def InstructionOutputPort {
        out instruction : PulseInstruction;
    }

    port def InstructionInputPort {
        in instruction : PulseInstruction;
    }

    port def PulseOutputPort {
        out pulse : ElectricalPulse;
    }

    port def PulseInputPort {
        in pulse : ElectricalPulse;
    }

    port def ImpedanceOutputPort {
        out measurement : ImpedanceMeasurement;
    }

    port def ImpedanceInputPort {
        in measurement : ImpedanceMeasurement;
    }

    port def CurrentOutputPort {
        out measurement : CurrentMeasurement;
    }

    port def CurrentInputPort {
        in measurement : CurrentMeasurement;
    }

    port def AlertOutputPort {
        out alert : SafetyAlert;
    }

    port def AlertInputPort {
        in alert : SafetyAlert;
    }

    // ===== Battery Pack =====
    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 3.7;
        attribute capacityMilliampHours : Real = 2000;
        attribute currentChargeLevel : ChargeLevelValue = 100;
        attribute maxOutputCurrent : CurrentValue = 500;
        attribute lowBatteryThreshold : ChargeLevelValue = 10;
        attribute isLow : Boolean = (currentChargeLevel <= lowBatteryThreshold);

        port powerOut : PowerOutputPort;

        action providePower() {
            // Supply regulated DC power to all system components
            // while charge level remains above low battery threshold
        }

        action recharge() {
            // Accept external charging input to restore charge level
        }
    }

    // ===== User Control Panel =====
    part def UserControlPanel {
        attribute powerButtonPressed : Boolean = false;
        attribute modeSelectPressed : Boolean = false;
        attribute intensityUpPressed : Boolean = false;
        attribute intensityDownPressed : Boolean = false;
        attribute startStopPressed : Boolean = false;
        attribute displayedMode : TherapyMode = TherapyMode::continuous;
        attribute displayedIntensity : IntensityValue = 0;

        port commandOut : CommandOutputPort;

        action handleButtonPress() {
            // Detect physical button presses and emit corresponding
            // control commands to the microcontroller
        }

        action cycleTherapyMode() {
            // Advance selected mode through continuous, burst, modulated
        }

        action adjustIntensity(delta : IntensityValue) {
            // Increase or decrease displayed intensity by delta
        }

        action updateDisplay() {
            // Refresh visual indicators for mode and intensity level
        }
    }

    // ===== Microcontroller Unit =====
    part def MicrocontrollerUnit {
        attribute selectedMode : TherapyMode = TherapyMode::continuous;
        attribute intensityLevel : IntensityValue = 50;
        attribute pulseFrequency : FrequencyValue = 80;
        attribute pulseWidth : PulseWidthValue = 200;
        attribute sessionDurationLimit : TimeDurationValue = 30;
        attribute sessionTimeRemaining : TimeDurationValue = 30;
        attribute sessionTimerExpired : Boolean = false;

        attribute maxCurrentLimit : CurrentValue = 100;
        attribute maxPulseWidth : PulseWidthValue = 500;
        attribute minPulseWidth : PulseWidthValue = 50;
        attribute maxFrequency : FrequencyValue = 150;
        attribute minFrequency : FrequencyValue = 1;
        attribute maxIntensity : IntensityValue = 100;

        attribute therapyActive : Boolean = false;
        attribute faultActive : Boolean = false;
        attribute activeFaultType : FaultType;

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port alertIn : AlertInputPort;
        port instructionOut : InstructionOutputPort;
        port monitorControlOut : CommandOutputPort;

        action processUserCommand() {
            // Interpret incoming control commands and update
            // therapy mode, intensity, and session parameters
        }

        action computePulseParameters() {
            // Derive frequency, pulse width, and amplitude from
            // the selected therapy mode and intensity level
        }

        action sendPulseInstruction() {
            // Transmit computed pulse parameters to the
            // pulse generator circuit via instruction port
        }

        action handleSafetyAlert() {
            // Receive safety alerts and initiate fault handling
        }

        action stopTherapyImmediately() {
            // Cease all pulse output and return device to standby
        }

        action decrementSessionTimer() {
            // Count down session time remaining and flag expiration
        }

        action enableSafetyMonitor() {
            // Activate the safety monitoring system
        }
    }

    // ===== Pulse Generator Circuit =====
    part def PulseGeneratorCircuit {
        attribute outputFrequency : FrequencyValue = 80;
        attribute outputPulseWidth : PulseWidthValue = 200;
        attribute outputAmplitude : VoltageValue = 0;
        attribute maxOutputVoltage : VoltageValue = 80;
        attribute maxOutputCurrent : CurrentValue = 100;
        attribute measuredOutputCurrent : CurrentValue = 0;

        port powerIn : PowerInputPort;
        port instructionIn : InstructionInputPort;
        port pulseOutAnode : PulseOutputPort;
        port pulseOutCathode : PulseOutputPort;
        port currentOut : CurrentOutputPort;

        action generatePulseWaveform() {
            // Convert digital instructions into analog electrical
            // pulses with the specified frequency, width, and amplitude
        }

        action measureOutputCurrent() {
            // Sense the actual output current for safety feedback
        }

        action haltOutput() {
            // Immediately cease pulse generation on command or fault
        }
    }

    // ===== Electrode Pad =====
    part def ElectrodePad {
        attribute padRole : String;
        attribute contactImpedance : ImpedanceValue = 500;
        attribute maxAcceptableImpedance : ImpedanceValue = 2000;
        attribute properlyAttached : Boolean = true;

        port pulseIn : PulseInputPort;
        port impedanceOut : ImpedanceOutputPort;

        action deliverPulseToSkin() {
            // Transfer electrical pulse energy through the
            // adhesive gel contact to the user's skin
        }

        action measureContactImpedance() {
            // Continuously measure electrode-skin interface impedance
            // and report via the impedance output port
        }
    }

    // ===== Safety Monitoring System =====
    part def SafetyMonitoringSystem {
        attribute impedanceThreshold : ImpedanceValue = 2000;
        attribute currentLimit : CurrentValue = 100;
        attribute measuredAnodeImpedance : ImpedanceValue = 500;
        attribute measuredCathodeImpedance : ImpedanceValue = 500;
        attribute measuredTotalImpedance : ImpedanceValue = 1000;
        attribute measuredCurrent : CurrentValue = 0;
        attribute monitoringActive : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute activeFaultType : FaultType;

        port impedanceAnodeIn : ImpedanceInputPort;
        port impedanceCathodeIn : ImpedanceInputPort;
        port currentIn : CurrentInputPort;
        port alertOut : AlertOutputPort;
        port controlIn : CommandInputPort;

        action monitorElectrodeContact() {
            // Continuously evaluate anode and cathode contact
            // impedance against the acceptable threshold
        }

        action monitorOutputCurrent() {
            // Continuously compare measured output current against
            // the maximum current limit
        }

        action evaluateSafetyConditions() {
            // Determine whether impedance or current readings
            // indicate a fault condition
        }

        action triggerSafetyAlert() {
            // Emit a safety alert to the microcontroller when a
            // fault condition is detected
        }
    }

    // ===== Top-Level TENS Device =====
    part def TENSDevice {
        part battery : BatteryPack;
        part controlPanel : UserControlPanel;
        part microcontroller : MicrocontrollerUnit;
        part pulseGenerator : PulseGeneratorCircuit;
        part anodePad : ElectrodePad {
            :>> padRole = "anode";
        }
        part cathodePad : ElectrodePad {
            :>> padRole = "cathode";
        }
        part safetyMonitor : SafetyMonitoringSystem;

        // Power distribution
        connect battery.powerOut to microcontroller.powerIn;
        connect battery.powerOut to pulseGenerator.powerIn;

        // User control to microcontroller
        connect controlPanel.commandOut to microcontroller.commandIn;

        // Pulse instructions
        connect microcontroller.instructionOut to pulseGenerator.instructionIn;

        // Safety monitor enable/disable control
        connect microcontroller.monitorControlOut to safetyMonitor.controlIn;

        // Pulse delivery to electrode pads
        connect pulseGenerator.pulseOutAnode to anodePad.pulseIn;
        connect pulseGenerator.pulseOutCathode to cathodePad.pulseIn;

        // Impedance feedback from pads to safety monitor
        connect anodePad.impedanceOut to safetyMonitor.impedanceAnodeIn;
        connect cathodePad.impedanceOut to safetyMonitor.impedanceCathodeIn;

        // Current feedback from pulse generator to safety monitor
        connect pulseGenerator.currentOut to safetyMonitor.currentIn;

        // Safety alert to microcontroller
        connect safetyMonitor.alertOut to microcontroller.alertIn;

        // ===== State Machine =====
        state machine TENSStateMachine {

            state off {
                entry {
                    microcontroller.therapyActive = false;
                    safetyMonitor.monitoringActive = false;
                    microcontroller.faultActive = false;
                }
            }

            state standby {
                entry {
                    microcontroller.therapyActive = false;
                    safetyMonitor.monitoringActive = true;
                    microcontroller.sessionTimerExpired = false;
                }
            }

            state active {
                entry {
                    microcontroller.therapyActive = true;
                    microcontroller.sessionTimeRemaining = microcontroller.sessionDurationLimit;
                }
                exit {
                    microcontroller.therapyActive = false;
                }
            }

            state fault {
                entry {
                    microcontroller.therapyActive = false;
                    microcontroller.faultActive = true;
                }
            }

            transition powerOn
                from off
                to standby
                when controlPanel.powerButtonPressed;

            transition startTherapy
                from standby
                to active
                when controlPanel.startStopPressed;

            transition stopTherapyNormal
                from active
                to standby
                when controlPanel.startStopPressed;

            transition sessionTimeout
                from active
                to standby
                when microcontroller.sessionTimerExpired;

            transition safetyFaultFromActive
                from active
                to fault
                when safetyMonitor.faultDetected;

            transition safetyFaultFromStandby
                from standby
                to fault
                when safetyMonitor.faultDetected;

            transition clearFault
                from fault
                to off
                when controlPanel.powerButtonPressed;

            transition powerOff
                from standby
                to off
                when controlPanel.powerButtonPressed;
        }
    }

    // ===== Requirements =====
    requirement def TENSOverallRequirement {
        doc "The portable TENS device shall provide non-invasive pain relief by delivering controlled, low-voltage electrical pulses through self-adhesive electrode pads placed on the user's skin.";

        subject tensDevice : TENSDevice;

        requirement painReliefByNerveStimulation {
            doc "The device shall stimulate underlying nerves to help block or reduce pain signals sent to the brain.";
        }

        requirement microcontrollerManagedOperation {
            doc "A microcontroller unit shall manage therapy settings and ensure safe operation of the device at all times.";
        }

        requirement userControlPanelInterface {
            doc "A user control panel shall allow the user to power the unit on, select therapy modes (continuous, burst, or modulated), and adjust the intensity of electrical pulses to a comfortable level.";
        }

        requirement rechargeableBatteryPower {
            doc "An internal rechargeable battery pack shall provide power for the entire device.";
        }

        requirement pulseGenerationSpecification {
            doc "A pulse generator circuit shall create electrical pulses with specific frequencies, pulse widths, and amplitudes based on microcontroller instructions.";
        }

        requirement dualElectrodePads {
            doc "Two electrode pads, an anode and a cathode, shall deliver electrical pulses to the skin over the area of pain.";
        }

        requirement continuousImpedanceMonitoring {
            doc "A safety monitoring system shall continuously measure the electrical impedance of the skin through the electrode pads.";
        }

        requirement autoShutdownOnElectrodeLoss {
            doc "If an electrode loses proper contact or falls off and the impedance rises significantly, the safety system shall automatically shut down therapy to prevent harm or discomfort.";
        }

        requirement maxCurrentEnforcement {
            doc "The safety monitoring system shall enforce a strict maximum current limit of 100 mA that cannot be exceeded during therapy.";
        }

        requirement deviceStateManagement {
            doc "The device shall operate in off, standby, active, and fault states, entering the fault state upon detection of poor electrode contact or other safety issues.";
        }
    }
}
