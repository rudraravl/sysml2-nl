package MicrocurrentNeuromuscularStimulatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MicrocurrentValue :> ElectricCurrentValue {
        doc /* Electric current in the microampere range (typically 10-1000 µA) */
    }
    
    attribute def StimulationFrequency :> FrequencyValue {
        doc /* Pulse frequency for neuromuscular stimulation (0.1-150 Hz) */
    }
    
    attribute def PulseWidth :> DurationValue {
        doc /* Duration of individual electrical pulses (50-500 µs) */
    }
    
    attribute def ImpedanceValue :> ElectricalResistanceValue {
        doc /* Tissue impedance measured at electrode interface */
    }
    
    attribute def TherapyDuration :> DurationValue {
        doc /* Total duration of stimulation session */
    }
    
    attribute def BatteryCapacity :> ElectricChargeValue {
        doc /* Battery capacity in milliampere-hours */
    }
    
    attribute def StimulationParameters {
        attribute intensity : MicrocurrentValue;
        attribute frequency : StimulationFrequency;
        attribute pulseWidth : PulseWidth;
        attribute duration : TherapyDuration;
    }
    
    attribute def SafetyLimits {
        attribute maxCurrent : MicrocurrentValue;
        attribute maxVoltage : ElectricPotentialValue;
        attribute maxImpedance : ImpedanceValue;
        attribute minImpedance : ImpedanceValue;
    }
    
    enum def DeviceState {
        off;
        standby;
        active;
        fault;
    }
    
    enum def TherapyMode {
        continuous;
        burst;
        modulated;
    }
    
    item def ElectricalPulse {
        attribute current : MicrocurrentValue;
        attribute voltage : ElectricPotentialValue;
        attribute frequency : StimulationFrequency;
        attribute pulseWidth : PulseWidth;
    }
    
    item def BiologicalResponse {
        attribute muscleActivation : Real;
        attribute painReduction : Real;
        attribute tissueImpedance : ImpedanceValue;
    }
    
    item def PowerSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    item def ControlCommand {
        attribute parameters : StimulationParameters;
        attribute mode : TherapyMode;
        attribute enable : Boolean;
    }
    
    item def StatusFeedback {
        attribute currentState : DeviceState;
        attribute deliveredCurrent : MicrocurrentValue;
        attribute measuredImpedance : ImpedanceValue;
        attribute batteryLevel : Real;
    }
    
    port def PowerPort {
        out item power : PowerSignal;
    }
    
    port def StimulationPort {
        out item pulse : ElectricalPulse;
        in item response : BiologicalResponse;
    }
    
    port def ControlPort {
        in item command : ControlCommand;
        out item status : StatusFeedback;
    }
    
    port def ElectrodeInterface {
        inout item signal : ElectricalPulse;
        out item impedance : ImpedanceValue;
    }
    
    part def BatteryModule {
        attribute capacity : BatteryCapacity;
        attribute chargeLevel : Real;
        attribute outputVoltage : ElectricPotentialValue;
        
        port powerOutput : PowerPort;
        
        action def SupplyPower {
            in requestedCurrent : ElectricCurrentValue;
            out suppliedPower : PowerSignal;
        }
        
        action def MonitorCharge {
            out remainingCharge : Real;
        }
    }
    
    part def PulseGenerator {
        attribute currentParameters : StimulationParameters;
        attribute activeMode : TherapyMode;
        
        port powerInput : PowerPort;
        port pulseOutput : StimulationPort;
        port control : ControlPort;
        
        action def GeneratePulse {
            in params : StimulationParameters;
            in mode : TherapyMode;
            out pulse : ElectricalPulse;
        }
        
        action def ModulatePulse {
            in basePulse : ElectricalPulse;
            in modulationMode : TherapyMode;
            out modulatedPulse : ElectricalPulse;
        }
        
        state def PulseGeneratorStateMachine {
            entry; then idle;
            
            state idle {
                doc /* Generator is powered but not producing pulses */
            }
            
            state generating {
                entry assign activeMode := control.command.mode;
                do action gen : GeneratePulse {
                    in params = currentParameters;
                    in mode = activeMode;
                    out pulse;
                }
            }
            
            state modulating {
                do action mod : ModulatePulse {
                    in basePulse = gen.pulse;
                    in modulationMode = activeMode;
                    out modulatedPulse;
                }
            }
            
            state fault {
                doc /* Generator has detected unsafe condition */
            }
            
            transition idle_to_generating
                first idle
                accept cmd : ControlCommand
                if cmd.enable
                then generating;
            
            transition generating_to_modulating
                first generating
                if activeMode != TherapyMode::continuous
                then modulating;
            
            transition modulating_to_generating
                first modulating
                then generating;
            
            transition to_fault
                first generating
                accept safetyViolation
                then fault;
            
            transition fault_to_idle
                first fault
                accept reset
                then idle;
            
            transition to_idle
                first generating
                accept cmd : ControlCommand
                if !cmd.enable
                then idle;
        }
    }
    
    part def CurrentRegulator {
        attribute safetyLimits : SafetyLimits;
        attribute measuredOutput : MicrocurrentValue;
        
        port signalInput : StimulationPort;
        port regulatedOutput : StimulationPort;
        
        action def RegulateOutput {
            in inputPulse : ElectricalPulse;
            in limits : SafetyLimits;
            out regulatedPulse : ElectricalPulse;
        }
        
        action def MonitorSafety {
            in pulse : ElectricalPulse;
            in impedance : ImpedanceValue;
            in limits : SafetyLimits;
            out isSafe : Boolean;
        }
        
        action def AdjustCurrent {
            in targetCurrent : MicrocurrentValue;
            in measuredImpedance : ImpedanceValue;
            out adjustedVoltage : ElectricPotentialValue;
        }
    }
    
    part def ElectrodeAssembly {
        attribute numberOfElectrodes : Integer;
        attribute contactArea : AreaValue;
        attribute placement : String;
        
        port electrodeInterface[2] : ElectrodeInterface;
        
        action def ConductCurrent {
            in pulse : ElectricalPulse;
            out tissueResponse : BiologicalResponse;
        }
        
        action def MeasureImpedance {
            out impedance : ImpedanceValue;
        }
    }
    
    part def ImpedanceSensor {
        attribute measurementFrequency : FrequencyValue;
        
        port senseInput : ElectrodeInterface;
        
        action def MeasureTissueImpedance {
            in testSignal : ElectricalPulse;
            out impedance : ImpedanceValue;
        }
        
        action def DetectElectrodeContact {
            in impedance : ImpedanceValue;
            out contactQuality : Real;
        }
    }
    
    part def UserInterface {
        attribute displayMode : String;
        attribute userSettings : StimulationParameters;
        
        port controlOutput : ControlPort;
        
        action def ConfigureTherapy {
            in userInput : String;
            out parameters : StimulationParameters;
        }
        
        action def DisplayStatus {
            in feedback : StatusFeedback;
        }
        
        action def HandleUserInput {
            in buttonPress : String;
            out command : ControlCommand;
        }
    }
    
    part def SafetyMonitor {
        attribute limits : SafetyLimits;
        attribute faultHistory : String[*];
        
        action def CheckSafetyConditions {
            in currentOutput : MicrocurrentValue;
            in impedance : ImpedanceValue;
            in limits : SafetyLimits;
            out safetyStatus : Boolean;
        }
        
        action def InitiateShutdown {
            in faultReason : String;
        }
    }
    
    action def DeliverTherapySession {
        doc /* Complete therapy session from initialization to completion */
        
        in sessionParameters : StimulationParameters;
        in safetyLimits : SafetyLimits;
        out sessionComplete : Boolean;
        out totalPulsesDelivered : Integer;
        
        private attribute elapsedTime : TherapyDuration := 0.0[s];
        private attribute pulseCount : Integer := 0;
        private attribute currentImpedance : ImpedanceValue;
        
        first start;
        then merge initializeSession;
        
        then action initialize {
            doc /* Verify system readiness and electrode contact */
        }
        
        then action checkContact {
            out contactValid : Boolean;
        }
        
        then decide;
            if checkContact.contactValid then beginStimulation;
            if !checkContact.contactValid then abortSession;
        
        action beginStimulation {
            then merge continuousDelivery;
        }
        
        then action deliverPulse {
            action generatePulse {
                in params = sessionParameters;
                out pulse : ElectricalPulse;
            }
            
            then action regulatePulse {
                in inputPulse = generatePulse.pulse;
                out regulatedPulse : ElectricalPulse;
            }
            
            then action monitorResponse {
                in deliveredPulse = regulatePulse.regulatedPulse;
                out response : BiologicalResponse;
            }
            
            then action checkSafety {
                in impedance = monitorResponse.response.tissueImpedance;
                out safe : Boolean;
            }
        }
        
        then assign elapsedTime := elapsedTime + (1.0[s] / sessionParameters.frequency);
        then assign pulseCount := pulseCount + 1;
        then assign currentImpedance := deliverPulse.monitorResponse.response.tissueImpedance;
        
        then decide;
            if deliverPulse.checkSafety.safe && elapsedTime < sessionParameters.duration 
                then continuousDelivery;
            if !deliverPulse.checkSafety.safe then emergencyStop;
            if elapsedTime >= sessionParameters.duration then completeSession;
        
        action emergencyStop {
            doc /* Immediate cessation due to safety violation */
        }
        then assign sessionComplete := false;
        then done;
        
        action abortSession {
            doc /* Session aborted due to poor electrode contact */
        }
        then assign sessionComplete := false;
        then done;
        
        action completeSession {
            doc /* Normal session completion */
        }
        then assign sessionComplete := true;
        then assign totalPulsesDelivered := pulseCount;
        then done;
    }
    
    action def CalibrateOutput {
        doc /* Calibrate current output based on tissue impedance */
        
        in targetCurrent : MicrocurrentValue;
        in measuredImpedance : ImpedanceValue;
        out calibratedVoltage : ElectricPotentialValue;
    }
    
    action def PerformSelfTest {
        doc /* System self-test at startup */
        
        out batteryOK : Boolean;
        out circuitryOK : Boolean;
        out electrodesOK : Boolean;
        out systemReady : Boolean;
    }
    
    requirement def TherapeuticEffectiveness {
        doc /* The stimulator shall deliver therapeutic microcurrent to neuromuscular tissue */
        
        require constraint currentRange {
            doc /* Output current shall be adjustable from 10 µA to 1000 µA */
        }
        
        require constraint frequencyRange {
            doc /* Pulse frequency shall be adjustable from 0.1 Hz to 150 Hz */
        }
        
        require constraint pulseWidthRange {
            doc /* Pulse width shall be adjustable from 50 µs to 500 µs */
        }
    }
    
    requirement def PatientSafety {
        doc /* The device shall ensure patient safety during all operating conditions */
        
        require constraint maxCurrentLimit {
            doc /* Maximum output current shall not exceed 1000 µA under any fault condition */
        }
        
        require constraint impedanceMonitoring {
            doc /* Device shall continuously monitor tissue impedance and cease operation if impedance exceeds 50 kOhm or falls below 100 Ohm */
        }
        
        require constraint emergencyShutoff {
            doc /* Device shall provide immediate shutoff accessible to both user and patient */
        }
        
        require constraint electrodeDetection {
            doc /* Device shall detect electrode detachment and cease stimulation within 100 ms */
        }
    }
    
    requirement def OperationalReliability {
        doc /* The device shall operate reliably throughout its service life */
        
        require constraint batteryLife {
            doc /* Device shall provide minimum 8 hours continuous operation on full charge */
        }
        
        require constraint outputAccuracy {
            doc /* Current output shall be accurate to within ±5% of set value */
        }
    }
    
    part def MicrocurrentStimulator {
        doc /* 
            Complete microcurrent electrical neuromuscular stimulator system.
            Delivers therapeutic low-intensity electrical stimulation to promote
            neuromuscular function, pain relief, and tissue healing.
        */
        
        attribute deviceIdentifier : String;
        attribute operatingState : DeviceState;
        attribute activeParameters : StimulationParameters;
        
        part battery : BatteryModule {
            attribute :>> capacity = 2200.0[mA*h];
            attribute :>> chargeLevel = 1.0;
            attribute :>> outputVoltage = 9.0[V];
        }
        
        part pulseGen : PulseGenerator {
            attribute :>> currentParameters {
                attribute :>> intensity = 500.0[uA];
                attribute :>> frequency = 10.0[Hz];
                attribute :>> pulseWidth = 200.0[us];
                attribute :>> duration = 1800.0[s];
            }
            attribute :>> activeMode = TherapyMode::continuous;
        }
        
        part regulator : CurrentRegulator {
            attribute :>> safetyLimits {
                attribute :>> maxCurrent = 1000.0[uA];
                attribute :>> maxVoltage = 40.0[V];
                attribute :>> maxImpedance = 50000.0[ohm];
                attribute :>> minImpedance = 100.0[ohm];
            }
        }
        
        part electrodes : ElectrodeAssembly {
            attribute :>> numberOfElectrodes = 2;
            attribute :>> placement = "bilateral neuromuscular placement";
        }
        
        part impedanceSensor : ImpedanceSensor {
            attribute :>> measurementFrequency = 1000.0[Hz];
        }
        
        part userInterface : UserInterface {
            attribute :>> displayMode = "therapy active";
            attribute :>> userSettings {
                attribute :>> intensity = 500.0[uA];
                attribute :>> frequency = 10.0[Hz];
                attribute :>> pulseWidth = 200.0[us];
                attribute :>> duration = 1800.0[s];
            }
        }
        
        part safetyMonitor : SafetyMonitor {
            attribute :>> limits {
                attribute :>> maxCurrent = 1000.0[uA];
                attribute :>> maxVoltage = 40.0[V];
                attribute :>> maxImpedance = 50000.0[ohm];
                attribute :>> minImpedance = 100.0[ohm];
            }
        }
        
        connection powerToPulseGen : ItemFlow 
            connect battery.powerOutput to pulseGen.powerInput;
        
        connection pulseToRegulator : ItemFlow 
            connect pulseGen.pulseOutput to regulator.signalInput;
        
        connection regulatorToElectrodes : ItemFlow 
            connect regulator.regulatedOutput to electrodes.electrodeInterface;
        
        connection electrodesToImpedance : ItemFlow 
            connect electrodes.electrodeInterface to impedanceSensor.senseInput;
        
        connection uiToControl : ItemFlow 
            connect userInterface.controlOutput to pulseGen.control;
        
        perform action therapySession : DeliverTherapySession {
            in sessionParameters = activeParameters;
            in safetyLimits = regulator.safetyLimits;
            out sessionComplete;
            out totalPulsesDelivered;
        }
    }
    
    requirement <'MENS-001'> primaryFunction : TherapeuticEffectiveness {
        doc /* 
            The Microcurrent Electrical Neuromuscular Stimulator shall deliver precisely 
            controlled, subsensory electrical currents in the microampere range to 
            neuromuscular tissue through surface electrodes. The primary therapeutic 
            function is to stimulate cellular healing processes, reduce pain, enhance 
            muscle function, and promote tissue repair by applying low-intensity 
            electrical pulses that mimic the body's natural bioelectrical signals.
            
            The system operates by generating biphasic microcurrent pulses with 
            adjustable intensity, frequency, and pulse width parameters. These pulses 
            are delivered through electrode pairs placed on the skin surface over target 
            neuromuscular areas. The device continuously monitors tissue impedance and 
            adjusts output to maintain safe, effective stimulation levels while preventing 
            patient discomfort or tissue damage.
        */
        
        subject stimulatorSystem : MicrocurrentStimulator;
        
        assume constraint validElectrodePlacement {
            doc /* Electrodes are properly placed on clean, intact skin over target tissue */
        }
        
        assume constraint adequateBatteryCharge {
            doc /* Battery charge level is sufficient for therapy session */
        }
        
        require therapeuticEffectiveness;
        require safety : PatientSafety;
        require reliability : OperationalReliability;
    }
    
    part mensDevice : MicrocurrentStimulator {
        attribute :>> deviceIdentifier = "MENS-2024-001";
        attribute :>> operatingState = DeviceState::standby;
    }
}
