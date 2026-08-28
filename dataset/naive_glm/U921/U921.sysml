package CapacitiveTouchSwitchSystem {

    import ScalarValues::*;

    // ============================================================
    // UNITS
    // ============================================================
    private unit pF;
    private unit V;
    private unit A;
    private unit s;
    private unit Hz;
    private unit unity;

    // ============================================================
    // VALUE TYPES (with units)
    // ============================================================
    value type CapacitanceValue :> Real { :>> unit = pF; }
    value type VoltageValue :> Real { :>> unit = V; }
    value type CurrentValue :> Real { :>> unit = A; }
    value type TimeDuration :> Real { :>> unit = s; }
    value type FrequencyValue :> Real { :>> unit = Hz; }
    value type GainValue :> Real { :>> unit = unity; }

    // ============================================================
    // ITEM DEFINITIONS
    // ============================================================
    item def RawSensorSignal {
        attribute capacitanceDelta : CapacitanceValue;
        attribute timestamp : TimeDuration;
    }
    item def FilteredSignal {
        attribute capacitanceDelta : CapacitanceValue;
        attribute signalStrength : VoltageValue;
        attribute timestamp : TimeDuration;
    }
    item def TouchEvent {
        attribute detected : Boolean;
        attribute timestamp : TimeDuration;
    }
    item def PowerCommand {
        attribute state : Boolean;
        attribute timestamp : TimeDuration;
    }
    item def StatusCommand {
        attribute state : Boolean;
        attribute timestamp : TimeDuration;
    }
    item def ACLinePower {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute currentAvailable : CurrentValue;
    }
    item def DCRegulatedPower {
        attribute voltage : VoltageValue;
        attribute currentMax : CurrentValue;
    }
    item def LoadPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute on : Boolean;
    }

    // ============================================================
    // SYSTEM CONFIGURATION
    // ============================================================
    attribute def SystemConfig {
        attribute debouncePeriod : TimeDuration = 0.050;
        attribute touchThreshold : CapacitanceValue = 3.0;
        attribute baselineCap : CapacitanceValue = 2.0;
        attribute operatingVoltage : VoltageValue = 5.0;
        attribute householdVoltage : VoltageValue = 230.0;
        attribute lineFrequency : FrequencyValue = 50.0;
        attribute maxLoadCurrent : CurrentValue = 10.0;
        attribute ampGain : GainValue = 100.0;
        attribute filterCutoffFreq : FrequencyValue = 100.0;
        attribute minRepressTime : TimeDuration = 0.200;
        attribute samplePeriod : TimeDuration = 0.005;
        attribute noiseFloor : VoltageValue = 0.01;
        attribute conversionEfficiency : GainValue = 0.8;
    }

    // ============================================================
    // PORT DEFINITIONS
    // ============================================================
    port def CapSensorOut { out signal : RawSensorSignal; }
    port def SignalCondIn { in signal : RawSensorSignal; }
    port def SignalCondOut { out signal : FilteredSignal; }
    port def DebounceIn { in signal : FilteredSignal; }
    port def DebounceOut { out event : TouchEvent; }
    port def ProcessorCmdIn { in event : TouchEvent; }
    port def ProcessorPowerOut { out cmd : PowerCommand; }
    port def ProcessorStatusOut { out cmd : StatusCommand; }
    port def SwitchCmdIn { in cmd : PowerCommand; }
    port def SwitchLoadOut { out power : LoadPower; }
    port def StatusIndIn { in cmd : StatusCommand; }
    port def PowerSupplyACIn { in power : ACLinePower; }
    port def PowerSupplyDCOut { out power : DCRegulatedPower; }
    port def PowerSupplyDCIn { in power : DCRegulatedPower; }

    // ============================================================
    // PART DEFINITIONS
    // ============================================================

    part def CapacitiveTouchSensor {
        attribute baselineCap : CapacitanceValue = 2.0;
        attribute currentCap : CapacitanceValue = 0.0;
        attribute touchThreshold : CapacitanceValue = 3.0;
        attribute measuredDelta : CapacitanceValue = 0.0;
        attribute samplePeriod : TimeDuration = 0.005;
        attribute lastSignal : RawSensorSignal;

        port powerIn : PowerSupplyDCIn;
        port capOut : CapSensorOut;

        action measureCapacitance {
            in current : CapacitanceValue;
            in baseline : CapacitanceValue;
            in threshold : CapacitanceValue;
            out delta : CapacitanceValue;
            if (current > baseline + threshold) {
                delta := current - baseline;
            } else {
                delta := 0.0;
            }
        }

        action emitSignal {
            in delta : CapacitanceValue;
            in t : TimeDuration;
            out signal : RawSensorSignal;
            signal.capacitanceDelta := delta;
            signal.timestamp := t;
        }

        action sampleLoop {
            out measured : CapacitanceValue;
            out signal : RawSensorSignal;
            measureCapacitance(currentCap, baselineCap, touchThreshold, measured);
            emitSignal(measured, 0.0, signal);
        }

        state machine sensorStateMachine {
            state monitoring {
                entry / sampleLoop(measuredDelta, lastSignal);
            }
            state touchDetected;
            state touchReleased;
            transition from monitoring to touchDetected
                if measuredDelta > touchThreshold;
            transition from touchDetected to touchReleased
                if measuredDelta <= touchThreshold;
            transition from touchReleased to monitoring;
        }
    }

    part def SignalConditioner {
        attribute filterCutoffFreq : FrequencyValue = 100.0;
        attribute ampGain : GainValue = 100.0;
        attribute noiseFloor : VoltageValue = 0.01;
        attribute lastInput : RawSensorSignal;
        attribute lastOutput : FilteredSignal;

        port powerIn : PowerSupplyDCIn;
        port sigIn : SignalCondIn;
        port sigOut : SignalCondOut;

        action filterNoise {
            in input : RawSensorSignal;
            in cutoff : FrequencyValue;
            in noiseFloor : VoltageValue;
            out filtered : FilteredSignal;
            filtered.capacitanceDelta := input.capacitanceDelta;
            filtered.signalStrength := input.capacitanceDelta;
            filtered.timestamp := input.timestamp;
        }

        action amplify {
            in input : FilteredSignal;
            in gain : GainValue;
            out amplified : FilteredSignal;
            amplified.capacitanceDelta := input.capacitanceDelta;
            amplified.signalStrength := input.signalStrength * gain;
            amplified.timestamp := input.timestamp;
        }

        action conditionSignal {
            in input : RawSensorSignal;
            out output : FilteredSignal;
            filterNoise(input, filterCutoffFreq, noiseFloor, lastOutput);
            amplify(lastOutput, ampGain, output);
        }

        state machine condStateMachine {
            state idle;
            state filtering;
            state amplifying;
            transition from idle to filtering
                if sigIn.signal.capacitanceDelta > 0.0;
            transition from filtering to amplifying;
            transition from amplifying to idle;
        }
    }

    part def DebounceCircuit {
        attribute debouncePeriod : TimeDuration = 0.050;
        attribute stableTime : TimeDuration = 0.0;
        attribute isStable : Boolean = false;
        attribute lastEvent : TouchEvent;

        port powerIn : PowerSupplyDCIn;
        port sigIn : DebounceIn;
        port sigOut : DebounceOut;

        action debounceSignal {
            in input : FilteredSignal;
            in debounceDelay : TimeDuration;
            out event : TouchEvent;
            if (input.capacitanceDelta > 0.0 && stableTime >= debounceDelay) {
                event.detected := true;
            } else {
                event.detected := false;
            }
            event.timestamp := input.timestamp;
        }

        action resetStable {
            stableTime := 0.0;
            isStable := false;
        }

        state machine debounceStateMachine {
            state idle;
            state waiting {
                entry / resetStable();
            }
            state stable;
            transition from idle to waiting
                if sigIn.signal.capacitanceDelta > 0.0;
            transition from waiting to idle
                if sigIn.signal.capacitanceDelta <= 0.0;
            transition from waiting to stable
                if stableTime >= debouncePeriod;
            transition from stable to idle
                if sigIn.signal.capacitanceDelta <= 0.0;
        }
    }

    part def ControlProcessor {
        attribute currentState : Boolean = false;
        attribute lastToggleTime : TimeDuration = 0.0;
        attribute minRepressTime : TimeDuration = 0.200;
        attribute timestamp : TimeDuration = 0.0;

        port powerIn : PowerSupplyDCIn;
        port cmdIn : ProcessorCmdIn;
        port powerCmdOut : ProcessorPowerOut;
        port statusCmdOut : ProcessorStatusOut;

        action toggleState {
            in event : TouchEvent;
            in current : Boolean;
            in currentTime : TimeDuration;
            in lastToggle : TimeDuration;
            in minRepress : TimeDuration;
            out newPowerState : Boolean;
            out newStatusState : Boolean;
            if (event.detected == true && (currentTime - lastToggle) >= minRepress) {
                newPowerState := !current;
                newStatusState := !current;
            } else {
                newPowerState := current;
                newStatusState := current;
            }
        }

        action updateOutputs {
            in state : Boolean;
            powerCmdOut.cmd.state := state;
            statusCmdOut.cmd.state := state;
        }

        state machine processorStateMachine {
            state off {
                entry / updateOutputs(false);
            }
            state on {
                entry / updateOutputs(true);
            }
            transition from off to on
                if cmdIn.event.detected == true
                && (timestamp - lastToggleTime) >= minRepressTime;
            transition from on to off
                if cmdIn.event.detected == true
                && (timestamp - lastToggleTime) >= minRepressTime;
        }
    }

    part def HighPowerSwitch {
        attribute maxLoadCurrent : CurrentValue = 10.0;
        attribute householdVoltage : VoltageValue = 230.0;
        attribute loadEnabled : Boolean = false;

        port powerIn : PowerSupplyDCIn;
        port cmdIn : SwitchCmdIn;
        port loadOut : SwitchLoadOut;

        action driveLoad {
            in cmd : PowerCommand;
            in maxCurrent : CurrentValue;
            in mainsVoltage : VoltageValue;
            out loadPower : LoadPower;
            if (cmd.state == true) {
                loadPower.on := true;
                loadPower.voltage := mainsVoltage;
                loadPower.current := maxCurrent;
            } else {
                loadPower.on := false;
                loadPower.voltage := 0.0;
                loadPower.current := 0.0;
            }
        }

        state machine switchStateMachine {
            state open {
                entry / driveLoad(cmdIn.cmd, 0.0, householdVoltage, loadOut.power);
            }
            state closed {
                entry / driveLoad(cmdIn.cmd, maxLoadCurrent, householdVoltage, loadOut.power);
            }
            transition from open to closed
                if cmdIn.cmd.state == true;
            transition from closed to open
                if cmdIn.cmd.state == false;
        }
    }

    part def StatusIndicator {
        attribute ledState : Boolean = false;
        attribute ledOnColor : String = "blue";
        attribute ledOffColor : String = "off";

        port powerIn : PowerSupplyDCIn;
        port statusIn : StatusIndIn;

        action updateLED {
            in cmd : StatusCommand;
            out ledOn : Boolean;
            ledOn := cmd.state;
        }

        state machine ledStateMachine {
            state dark;
            state illuminated;
            transition from dark to illuminated
                if statusIn.cmd.state == true;
            transition from illuminated to dark
                if statusIn.cmd.state == false;
        }
    }

    part def PowerSupplyModule {
        attribute inputVoltage : VoltageValue = 230.0;
        attribute inputFreq : FrequencyValue = 50.0;
        attribute outputVoltage : VoltageValue = 5.0;
        attribute outputCurrent : CurrentValue = 1.0;
        attribute conversionEfficiency : GainValue = 0.8;

        port acIn : PowerSupplyACIn;
        port dcOut : PowerSupplyDCOut;

        action convertAC2DC {
            in acInput : ACLinePower;
            in targetVoltage : VoltageValue;
            in maxCurrent : CurrentValue;
            out dcOutput : DCRegulatedPower;
            dcOutput.voltage := targetVoltage;
            dcOutput.currentMax := maxCurrent;
        }

        state machine powerSupplyStateMachine {
            state unpowered;
            state powered {
                entry / convertAC2DC(acIn.power, outputVoltage, outputCurrent, dcOut.power);
            }
            transition from unpowered to powered
                if acIn.power.voltage > 0.0;
            transition from powered to unpowered
                if acIn.power.voltage <= 0.0;
        }
    }

    // ============================================================
    // ASSEMBLY DEFINITION
    // ============================================================
    part def CapacitiveTouchSwitchAssembly {
        attribute config : SystemConfig;

        port acIn : PowerSupplyACIn;
        port loadOut : SwitchLoadOut;

        part powerSupply : PowerSupplyModule {
            :>> inputVoltage = config.householdVoltage;
            :>> inputFreq = config.lineFrequency;
            :>> outputVoltage = config.operatingVoltage;
            :>> outputCurrent = 1.0;
        }

        part touchSensor : CapacitiveTouchSensor {
            :>> baselineCap = config.baselineCap;
            :>> touchThreshold = config.touchThreshold;
            :>> samplePeriod = config.samplePeriod;
        }

        part signalConditioner : SignalConditioner {
            :>> filterCutoffFreq = config.filterCutoffFreq;
            :>> ampGain = config.ampGain;
            :>> noiseFloor = config.noiseFloor;
        }

        part debounce : DebounceCircuit {
            :>> debouncePeriod = config.debouncePeriod;
        }

        part processor : ControlProcessor {
            :>> minRepressTime = config.minRepressTime;
        }

        part highPowerSwitch : HighPowerSwitch {
            :>> maxLoadCurrent = config.maxLoadCurrent;
            :>> householdVoltage = config.householdVoltage;
        }

        part statusIndicator : StatusIndicator;

        // Power distribution
        connection powerSupply.dcOut to touchSensor.powerIn;
        connection powerSupply.dcOut to signalConditioner.powerIn;
        connection powerSupply.dcOut to debounce.powerIn;
        connection powerSupply.dcOut to processor.powerIn;
        connection powerSupply.dcOut to highPowerSwitch.powerIn;
        connection powerSupply.dcOut to statusIndicator.powerIn;

        // Signal flow
        connection touchSensor.capOut to signalConditioner.sigIn;
        connection signalConditioner.sigOut to debounce.sigIn;
        connection debounce.sigOut to processor.cmdIn;
        connection processor.powerCmdOut to highPowerSwitch.cmdIn;
        connection processor.statusCmdOut to statusIndicator.statusIn;

        // External
        connection acIn to powerSupply.acIn;
        connection highPowerSwitch.loadOut to loadOut;
    }

    part capacitiveTouchSwitch : CapacitiveTouchSwitchAssembly;

    // ============================================================
    // REQUIREMENTS
    // ============================================================
    requirement DetectTouchReq {
        doc The system shall detect a user touch via change in electrical capacitance exceeding 3.0 pF above the 2.0 pF baseline.
        subject sensor : CapacitiveTouchSensor;
        constraint sensor.currentCap > sensor.baselineCap + 3.0;
    }

    requirement SignalConditionReq {
        doc The signal conditioner shall filter noise and amplify the raw sensor signal by a gain of 100.
        subject cond : SignalConditioner;
        constraint cond.ampGain >= 50.0;
        constraint cond.filterCutoffFreq <= 1000.0;
    }

    requirement DebounceReq {
        doc The system shall debounce the touch signal for 50 ms before validating the touch event.
        subject debounceComp : DebounceCircuit;
        constraint debounceComp.debouncePeriod == 0.050;
    }

    requirement TogglePowerReq {
        doc Upon valid touch, the processor shall toggle the power state with a minimum repress time of 0.2 seconds between toggles.
        subject proc : ControlProcessor;
        constraint proc.minRepressTime >= 0.200;
    }

    requirement HighPowerControlReq {
        doc The high-power switch shall control electricity flow to the connected load up to 10 A at 230 VAC.
        subject sw : HighPowerSwitch;
        constraint sw.maxLoadCurrent >= 10.0;
        constraint sw.householdVoltage >= 110.0;
    }

    requirement StatusIndicationReq {
        doc The status indicator shall reflect the current on/off state using LED illumination.
        subject ind : StatusIndicator;
        constraint ind.ledState == ind.statusIn.cmd.state;
    }

    requirement PowerSupplyReq {
        doc The power supply shall convert household 230V/50Hz AC into regulated 5V DC for the sensitive electronics with at least 0.5 A capacity.
        subject ps : PowerSupplyModule;
        constraint ps.outputVoltage == 5.0;
        constraint ps.outputCurrent >= 0.5;
        constraint ps.inputFreq == 50.0;
    }

    requirement CapacitiveTouchSwitchOverallReq {
        doc The capacitive touch switch shall safely control power to a connected appliance through touch sensing with debounce protection and visual feedback.
        satisfy DetectTouchReq;
        satisfy SignalConditionReq;
        satisfy DebounceReq;
        satisfy TogglePowerReq;
        satisfy HighPowerControlReq;
        satisfy StatusIndicationReq;
        satisfy PowerSupplyReq;
    }

    // ============================================================
    // ALLOCATIONS
    // ============================================================
    allocation SystemAllocation {
        allocate DetectTouchReq to touchSensor;
        allocate SignalConditionReq to signalConditioner;
        allocate DebounceReq to debounce;
        allocate TogglePowerReq to processor;
        allocate HighPowerControlReq to highPowerSwitch;
        allocate StatusIndicationReq to statusIndicator;
        allocate PowerSupplyReq to powerSupply;
    }

}
