package TouchSwitchSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def CapacitanceValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def FrequencyValue :> Real;
    
    enum def SwitchState {
        off;
        on;
    }
    
    enum def TouchDetectionState {
        idle;
        detecting;
        confirmed;
    }

    item def HumanTouch {
        attribute bodyCapacitance : CapacitanceValue;
        attribute contactArea : ISQ::AreaValue;
    }

    part def CapacitiveTouchSensor {
        attribute baselineCapacitance : CapacitanceValue;
        attribute touchThreshold : CapacitanceValue;
        attribute scanFrequency : FrequencyValue;
        attribute currentCapacitance : CapacitanceValue;
        
        port sensorOutput {
            out touchDetected : Boolean;
            out capacitanceReading : CapacitanceValue;
            out signalStrength : Real;
        }
        
        port powerInput {
            in voltage : ISQ::VoltageValue;
            in current : ISQ::ElectricCurrentValue;
        }
    }

    part def SignalConditioner {
        attribute filterCutoffFrequency : FrequencyValue;
        attribute amplificationGain : Real;
        attribute noiseThreshold : ISQ::VoltageValue;
        
        port conditionerInput {
            in rawSignal : Boolean;
            in signalLevel : Real;
        }
        
        port conditionerOutput {
            out filteredSignal : Boolean;
            out signalQuality : Real;
        }
    }

    part def DebounceCircuit {
        attribute debounceTime : Time::TimeValue;
        attribute stabilityWindow : Time::TimeValue;
        attribute transitionCount : Integer;
        
        port debounceInput {
            in unstableSignal : Boolean;
        }
        
        port debounceOutput {
            out stableSignal : Boolean;
            out validTransition : Boolean;
        }
    }

    part def ControlProcessor {
        attribute currentState : SwitchState;
        attribute previousState : SwitchState;
        attribute toggleCount : Integer;
        attribute operatingMode : String;
        
        port processorInput {
            in touchCommand : Boolean;
            in validationFlag : Boolean;
        }
        
        port processorOutput {
            out switchCommand : SwitchState;
            out stateChanged : Boolean;
        }
        
        port statusOutput {
            out currentMode : SwitchState;
            out operationCount : Integer;
        }
    }

    part def PowerSwitch {
        attribute maxSwitchingVoltage : ISQ::VoltageValue;
        attribute maxSwitchingCurrent : ISQ::ElectricCurrentValue;
        attribute contactResistance : ResistanceValue;
        attribute switchState : SwitchState;
        
        port switchControl {
            in controlSignal : SwitchState;
        }
        
        port powerInputPort {
            in inputVoltage : ISQ::VoltageValue;
            in inputCurrent : ISQ::ElectricCurrentValue;
        }
        
        port powerOutputPort {
            out outputVoltage : ISQ::VoltageValue;
            out outputCurrent : ISQ::ElectricCurrentValue;
            out powerDelivered : ISQ::PowerValue;
        }
    }

    part def StatusIndicator {
        attribute indicatorType : String;
        attribute brightness : Real;
        attribute blinkRate : FrequencyValue;
        
        port indicatorInput {
            in displayState : SwitchState;
            in powerAvailable : Boolean;
        }
        
        port indicatorPower {
            in voltage : ISQ::VoltageValue;
        }
    }

    part def PowerSupplyModule {
        attribute inputVoltage : ISQ::VoltageValue;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute maxOutputCurrent : ISQ::ElectricCurrentValue;
        attribute efficiency : Real;
        attribute regulationType : String;
        
        port supplyInput {
            in lineVoltage : ISQ::VoltageValue;
        }
        
        port supplyOutput {
            out regulatedVoltage : ISQ::VoltageValue;
            out availableCurrent : ISQ::ElectricCurrentValue;
        }
        
        port sensorSupply {
            out sensorVoltage : ISQ::VoltageValue;
        }
    }

    part def LoadDevice {
        attribute ratedVoltage : ISQ::VoltageValue;
        attribute ratedPower : ISQ::PowerValue;
        attribute powerFactor : Real;
        attribute operationalState : Boolean;
        
        port loadPower {
            in voltage : ISQ::VoltageValue;
            in current : ISQ::ElectricCurrentValue;
        }
    }

    action def SenseTouch {
        in baselineCapacitance : CapacitanceValue;
        in threshold : CapacitanceValue;
        out measuredCapacitance : CapacitanceValue;
        out touchDetected : Boolean;
        out deltaCapacitance : CapacitanceValue;
    }

    action def FilterSignal {
        in rawSignal : Boolean;
        in signalQuality : Real;
        in noiseLevel : ISQ::VoltageValue;
        out cleanSignal : Boolean;
        out confidence : Real;
    }

    action def ValidateTouch {
        in signal : Boolean;
        in debounceDelay : Time::TimeValue;
        out validatedTouch : Boolean;
        out transitionValid : Boolean;
    }

    action def ToggleState {
        in touchEvent : Boolean;
        inout currentState : SwitchState;
        out newState : SwitchState;
        out stateChanged : Boolean;
    }

    action def SwitchPower {
        in commandState : SwitchState;
        in inputVoltage : ISQ::VoltageValue;
        out outputActive : Boolean;
        out deliveredPower : ISQ::PowerValue;
    }

    action def UpdateIndicator {
        in systemState : SwitchState;
        in powerStatus : Boolean;
        out indicatorActive : Boolean;
    }

    action def TouchSwitchControlFlow {
        first start;
        then merge continuousOperation;
        
        then action sensingPhase : SenseTouch {
            in baselineCapacitance : CapacitanceValue;
            in threshold : CapacitanceValue;
            out measuredCapacitance : CapacitanceValue;
            out touchDetected : Boolean;
            out deltaCapacitance : CapacitanceValue;
        }
        
        then decide;
            if sensingPhase.touchDetected then filterPhase;
            else continuousOperation;
        
        action filterPhase : FilterSignal {
            in rawSignal = sensingPhase.touchDetected;
            in signalQuality : Real;
            in noiseLevel : ISQ::VoltageValue;
            out cleanSignal : Boolean;
            out confidence : Real;
        }
        
        then decide;
            if filterPhase.confidence > 0.8 then validationPhase;
            else continuousOperation;
        
        action validationPhase : ValidateTouch {
            in signal = filterPhase.cleanSignal;
            in debounceDelay : Time::TimeValue;
            out validatedTouch : Boolean;
            out transitionValid : Boolean;
        }
        
        then decide;
            if validationPhase.validatedTouch then togglePhase;
            else continuousOperation;
        
        action togglePhase : ToggleState {
            in touchEvent = validationPhase.validatedTouch;
            inout currentState : SwitchState;
            out newState : SwitchState;
            out stateChanged : Boolean;
        }
        
        then action switchingPhase : SwitchPower {
            in commandState = togglePhase.newState;
            in inputVoltage : ISQ::VoltageValue;
            out outputActive : Boolean;
            out deliveredPower : ISQ::PowerValue;
        }
        
        then action indicatorUpdate : UpdateIndicator {
            in systemState = togglePhase.newState;
            in powerStatus = switchingPhase.outputActive;
            out indicatorActive : Boolean;
        }
        
        then continuousOperation;
    }

    state def TouchSwitchStateMachine {
        entry; then systemOff;
        
        state systemOff {
            entry assign outputState = SwitchState::off;
        }
        
        transition offToSensing
            first systemOff
            accept touchApproach
            then sensing;
        
        state sensing;
        
        transition sensingToDebounce
            first sensing
            if capacitanceExceedsThreshold
            then debouncing;
        
        transition sensingToOff
            first sensing
            if !capacitanceExceedsThreshold
            then systemOff;
        
        state debouncing;
        
        transition debounceToToggle
            first debouncing
            if signalStable
            then toggling;
        
        transition debounceToOff
            first debouncing
            if !signalStable
            then systemOff;
        
        state toggling;
        
        transition toggleToOn
            first toggling
            if previousStateWasOff
            then systemOn;
        
        transition toggleToOff
            first toggling
            if previousStateWasOn
            then systemOff;
        
        state systemOn {
            entry assign outputState = SwitchState::on;
        }
        
        transition onToSensing
            first systemOn
            accept touchApproach
            then sensing;
    }

    part def TouchSwitchSystem;

    part touchSwitchSystem : TouchSwitchSystem {
        attribute systemVoltage : ISQ::VoltageValue = 230.0 [SI::V];
        attribute touchSensitivity : CapacitanceValue = 12.0;
        attribute debounceInterval : Time::TimeValue = 50.0 [SI::ms];
        attribute maxLoadPower : ISQ::PowerValue = 1000.0 [SI::W];
        
        part sensor : CapacitiveTouchSensor {
            attribute :>> baselineCapacitance = 8.0;
            attribute :>> touchThreshold = touchSwitchSystem.touchSensitivity;
            attribute :>> scanFrequency = 100.0;
        }
        
        part conditioner : SignalConditioner {
            attribute :>> filterCutoffFrequency = 10.0;
            attribute :>> amplificationGain = 20.0;
            attribute :>> noiseThreshold = 0.05 [SI::V];
        }
        
        part debouncer : DebounceCircuit {
            attribute :>> debounceTime = touchSwitchSystem.debounceInterval;
            attribute :>> stabilityWindow = 30.0 [SI::ms];
            attribute :>> transitionCount = 0;
        }
        
        part processor : ControlProcessor {
            attribute :>> currentState = SwitchState::off;
            attribute :>> previousState = SwitchState::off;
            attribute :>> toggleCount = 0;
            attribute :>> operatingMode = "automatic";
        }
        
        part powerSwitch : PowerSwitch {
            attribute :>> maxSwitchingVoltage = 250.0 [SI::V];
            attribute :>> maxSwitchingCurrent = 10.0 [SI::A];
            attribute :>> contactResistance = 0.05;
            attribute :>> switchState = SwitchState::off;
        }
        
        part indicator : StatusIndicator {
            attribute :>> indicatorType = "LED";
            attribute :>> brightness = 0.75;
            attribute :>> blinkRate = 0.0;
        }
        
        part powerSupply : PowerSupplyModule {
            attribute :>> inputVoltage = 230.0 [SI::V];
            attribute :>> outputVoltage = 5.0 [SI::V];
            attribute :>> maxOutputCurrent = 0.5 [SI::A];
            attribute :>> efficiency = 0.88;
            attribute :>> regulationType = "switching";
        }
        
        part load : LoadDevice {
            attribute :>> ratedVoltage = touchSwitchSystem.systemVoltage;
            attribute :>> ratedPower = 500.0 [SI::W];
            attribute :>> powerFactor = 0.95;
            attribute :>> operationalState = false;
        }
        
        connection sensorToConditioner connect 
            sensor.sensorOutput to conditioner.conditionerInput;
        
        connection conditionerToDebouncer connect 
            conditioner.conditionerOutput to debouncer.debounceInput;
        
        connection debouncerToProcessor connect 
            debouncer.debounceOutput to processor.processorInput;
        
        connection processorToSwitch connect 
            processor.processorOutput to powerSwitch.switchControl;
        
        connection processorToIndicator connect 
            processor.statusOutput to indicator.indicatorInput;
        
        connection supplyToSensor connect 
            powerSupply.sensorSupply to sensor.powerInput;
        
        connection supplyToIndicator connect 
            powerSupply.supplyOutput to indicator.indicatorPower;
        
        connection switchToLoad connect 
            powerSwitch.powerOutputPort to load.loadPower;
        
        perform action operation : TouchSwitchControlFlow;
        
        exhibit state behavior : TouchSwitchStateMachine;
    }

    requirement <'REQ-TS-001'> primaryFunction {
        doc /* The touch switch system shall detect human touch through capacitive 
             * sensing and control electrical power delivery to a connected load by 
             * toggling between on and off states with each validated touch event.
             */
        subject system : TouchSwitchSystem;
        
        require touchDetection;
        require signalProcessing;
        require powerControl;
        require userFeedback;
    }

    requirement <'REQ-TS-002'> touchDetection {
        doc /* The system shall detect capacitance changes of at least 12 pF when 
             * a human finger approaches within 5mm of the sensing surface.
             */
        subject sensor :>> touchSwitchSystem.sensor;
        
        assert constraint {
            sensor.touchThreshold >= 12.0
        }
    }

    requirement <'REQ-TS-003'> signalProcessing {
        doc /* The system shall filter and debounce touch signals for at least 50ms 
             * to eliminate false triggering from electrical noise and transients.
             */
        subject debouncer :>> touchSwitchSystem.debouncer;
        
        assert constraint {
            debouncer.debounceTime >= 50.0 [SI::ms]
        }
    }

    requirement <'REQ-TS-004'> powerControl {
        doc /* The system shall switch electrical loads up to 1000W at 230V AC 
             * with contact resistance not exceeding 0.1 ohms.
             */
        subject powerSwitch :>> touchSwitchSystem.powerSwitch;
        
        assert constraint {
            powerSwitch.maxSwitchingVoltage >= 230.0 [SI::V]
        }
    }

    requirement <'REQ-TS-005'> userFeedback {
        doc /* The system shall provide visual indication of the current switch 
             * state through an LED indicator.
             */
        subject indicator :>> touchSwitchSystem.indicator;
    }

    requirement <'REQ-TS-006'> powerSupplyRegulation {
        doc /* The internal power supply shall provide regulated 5V DC with 
             * efficiency of at least 85% for sensor and control circuits.
             */
        subject powerSupply :>> touchSwitchSystem.powerSupply;
        
        assert constraint {
            powerSupply.outputVoltage == 5.0 [SI::V]
        }
    }

    requirement <'REQ-TS-007'> stateToggling {
        doc /* The system shall toggle between on and off states with each validated 
             * touch event, maintaining the current state until the next touch.
             */
        subject processor :>> touchSwitchSystem.processor;
    }

    satisfy primaryFunction by touchSwitchSystem;
}
