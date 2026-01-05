package PacemakerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def HeartRateValue :> FrequencyValue;
    attribute def VoltageValue :> ElectricPotentialValue;
    attribute def PulseWidthValue :> DurationValue;
    attribute def EnergyValue :> Real;
    attribute def ImpedanceValue :> Real;
    
    enum def PacingMode {
        AAI;
        VVI;
        DDD;
        DDDR;
    }
    
    enum def RhythmState {
        normal;
        bradycardia;
        tachycardia;
        asystole;
    }
    
    item def CardiacSignal {
        attribute amplitude : VoltageValue;
        attribute frequency : HeartRateValue;
    }
    
    item def PacingPulse {
        attribute voltage : VoltageValue;
        attribute width : PulseWidthValue;
        attribute energy : EnergyValue;
    }
    
    port def CardiacInterface {
        in sensedSignal : CardiacSignal;
        out pacingPulse : PacingPulse;
    }
    
    port def PowerInterface {
        out voltage : VoltageValue;
        out current : Real;
    }
    
    port def TelemetryInterface {
        in programmingData : Real;
        out diagnosticData : Real;
    }
    
    part def Heart {
        attribute intrinsicRate : HeartRateValue;
        attribute rhythmState : RhythmState;
        port atrialTissue : CardiacInterface;
        port ventricularTissue : CardiacInterface;
    }
    
    part def SensingAmplifier {
        attribute sensitivity : VoltageValue;
        attribute gain : Real;
        port cardiacInput {
            in signal : CardiacSignal;
        }
        port senseOutput {
            out detectedRate : HeartRateValue;
            out signalQuality : Real;
        }
    }
    
    part def PulseGenerator {
        attribute outputVoltage : VoltageValue;
        attribute pulseWidth : PulseWidthValue;
        attribute outputEnergy : EnergyValue;
        port controlInput {
            in paceCommand : Boolean;
            in voltage : VoltageValue;
            in width : PulseWidthValue;
        }
        port pulseOutput {
            out pulse : PacingPulse;
        }
    }
    
    part def TimingCircuit {
        attribute lowerRateInterval : DurationValue;
        attribute upperRateInterval : DurationValue;
        attribute atrioventricularDelay : DurationValue;
        attribute postVentricularAtrialRefractoryPeriod : DurationValue;
        port timingControl {
            in sensedEvent : Boolean;
            out escapeInterval : DurationValue;
            out refractoryPeriod : DurationValue;
        }
    }
    
    part def ControlLogic {
        attribute programmedLowerRate : HeartRateValue;
        attribute programmedUpperRate : HeartRateValue;
        attribute operatingMode : PacingMode;
        attribute hysteresisRate : HeartRateValue;
        port sensingInput {
            in detectedRate : HeartRateValue;
            in signalQuality : Real;
        }
        port timingInput {
            in escapeInterval : DurationValue;
            in refractoryPeriod : DurationValue;
        }
        port pacingControl {
            out paceCommand : Boolean;
            out pulseVoltage : VoltageValue;
            out pulseWidth : PulseWidthValue;
        }
        port telemetry : TelemetryInterface;
    }
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute voltage : VoltageValue;
        attribute remainingLife : DurationValue;
        attribute impedance : ImpedanceValue;
        port power : PowerInterface;
    }
    
    part def Lead {
        attribute impedance : ImpedanceValue;
        attribute length : Real;
        port proximal {
            in pacingPulse : PacingPulse;
            out sensedSignal : CardiacSignal;
        }
        port distal {
            out deliveredPulse : PacingPulse;
            in cardiacSignal : CardiacSignal;
        }
    }
    
    part def Pacemaker {
        attribute deviceSerialNumber : String;
        attribute implantDate : String;
        attribute manufacturerModel : String;
        
        part sensingAmp : SensingAmplifier {
            attribute :>> sensitivity = 2.0 [V];
            attribute :>> gain = 100.0;
        }
        
        part pulseGen : PulseGenerator {
            attribute :>> outputVoltage = 3.5 [V];
            attribute :>> pulseWidth = 0.4 [s];
            attribute :>> outputEnergy = 0.5;
        }
        
        part timingCircuit : TimingCircuit {
            attribute :>> lowerRateInterval = 1000.0 [s];
            attribute :>> upperRateInterval = 400.0 [s];
            attribute :>> atrioventricularDelay = 150.0 [s];
            attribute :>> postVentricularAtrialRefractoryPeriod = 250.0 [s];
        }
        
        part controller : ControlLogic {
            attribute :>> programmedLowerRate = 60.0 [Hz];
            attribute :>> programmedUpperRate = 130.0 [Hz];
            attribute :>> operatingMode = PacingMode::DDD;
            attribute :>> hysteresisRate = 50.0 [Hz];
        }
        
        part battery : Battery {
            attribute :>> capacity = 2.8;
            attribute :>> voltage = 3.2 [V];
            attribute :>> remainingLife = 10.0 [s];
            attribute :>> impedance = 50.0;
        }
        
        part atrialLead : Lead {
            attribute :>> impedance = 500.0;
            attribute :>> length = 52.0;
        }
        
        part ventricularLead : Lead {
            attribute :>> impedance = 550.0;
            attribute :>> length = 58.0;
        }
        
        connection sensingToController connect 
            sensingAmp.senseOutput to controller.sensingInput;
        
        connection timingToController connect 
            timingCircuit.timingControl to controller.timingInput;
        
        connection controllerToPulseGen connect 
            controller.pacingControl to pulseGen.controlInput;
        
        connection atrialLeadSensing connect 
            atrialLead.proximal.sensedSignal to sensingAmp.cardiacInput.signal;
        
        connection ventricularLeadPacing connect 
            pulseGen.pulseOutput.pulse to ventricularLead.proximal.pacingPulse;
        
        perform action maintainCardiacRhythm[*] ordered references pacingOperation;
    }
    
    action def SenseCardiacActivity {
        in sensitivity : VoltageValue;
        in cardiacSignal : CardiacSignal;
        out detectedRate : HeartRateValue;
        out rhythmClassification : RhythmState;
    }
    
    action def EvaluatePacingRequirement {
        in detectedRate : HeartRateValue;
        in lowerRateLimit : HeartRateValue;
        in rhythmState : RhythmState;
        in operatingMode : PacingMode;
        out pacingRequired : Boolean;
        out pacingChamber : String;
    }
    
    action def CalculateTimingIntervals {
        in lowerRate : HeartRateValue;
        in upperRate : HeartRateValue;
        in mode : PacingMode;
        out escapeInterval : DurationValue;
        out avDelay : DurationValue;
    }
    
    action def GenerateTherapeuticPulse {
        in voltage : VoltageValue;
        in width : PulseWidthValue;
        out pulse : PacingPulse;
    }
    
    action def DeliverStimulation {
        in pulse : PacingPulse;
        in leadImpedance : ImpedanceValue;
        out deliveredEnergy : Real;
        out captureAchieved : Boolean;
    }
    
    action def MonitorBatteryHealth {
        in currentVoltage : VoltageValue;
        in impedance : ImpedanceValue;
        out remainingCapacity : Real;
        out endOfLifeWarning : Boolean;
    }
    
    action def ProcessTelemetry {
        in programmingCommands : Real;
        out deviceParameters : Real;
        out storedDiagnostics : Real;
    }
    
    action pacingOperation {
        first start;
        then merge continuousOperation;
        
        action senseRhythm : SenseCardiacActivity {
            in sensitivity = 2.0 [V];
            in cardiacSignal;
            out currentRate : HeartRateValue;
            out rhythmStatus : RhythmState;
        }
        then continuousOperation;
        
        then action calculateTiming : CalculateTimingIntervals {
            in lowerRate = 60.0 [Hz];
            in upperRate = 130.0 [Hz];
            in mode = PacingMode::DDD;
            out interval : DurationValue;
            out delay : DurationValue;
        }
        
        then action evaluateNeed : EvaluatePacingRequirement {
            in detectedRate = senseRhythm.currentRate;
            in lowerRateLimit = 60.0 [Hz];
            in rhythmState = senseRhythm.rhythmStatus;
            in operatingMode = PacingMode::DDD;
            out needsPacing : Boolean;
            out chamber : String;
        }
        
        then decide;
            if evaluateNeed.needsPacing then deliverTherapy;
            if !evaluateNeed.needsPacing then continuousOperation;
        
        action deliverTherapy {
            first action generatePulse : GenerateTherapeuticPulse {
                in voltage = 3.5 [V];
                in width = 0.4 [s];
                out therapyPulse : PacingPulse;
            }
            then action applyStimulation : DeliverStimulation {
                in pulse = generatePulse.therapyPulse;
                in leadImpedance = 550.0;
                out energy : Real;
                out captured : Boolean;
            }
        }
        then continuousOperation;
        
        action monitorBattery : MonitorBatteryHealth {
            in currentVoltage = 3.2 [V];
            in impedance = 50.0;
            out capacity : Real;
            out warning : Boolean;
        }
        
        action telemetryProcessing : ProcessTelemetry {
            in programmingCommands;
            out deviceParameters;
            out storedDiagnostics;
        }
    }
    
    part therapySystem {
        part implantedDevice : Pacemaker {
            perform action maintainCardiacRhythm[*];
            
            part :>> sensingAmp {
                perform maintainCardiacRhythm.senseRhythm;
            }
            part :>> controller {
                perform maintainCardiacRhythm.evaluateNeed;
                perform maintainCardiacRhythm.calculateTiming;
            }
            part :>> pulseGen {
                perform maintainCardiacRhythm.deliverTherapy.generatePulse;
            }
            part :>> ventricularLead {
                perform maintainCardiacRhythm.deliverTherapy.applyStimulation;
            }
            part :>> battery {
                perform maintainCardiacRhythm.monitorBattery;
            }
        }
        
        part patient : Heart {
            attribute :>> intrinsicRate = 45.0 [Hz];
            attribute :>> rhythmState = RhythmState::bradycardia;
        }
        
        connection atrialConnection connect 
            implantedDevice.atrialLead.distal to patient.atrialTissue;
        
        connection ventricularConnection connect 
            implantedDevice.ventricularLead.distal to patient.ventricularTissue;
    }
}

package PacemakerRequirements {
    private import PacemakerSystem::*;
    private import SI::*;
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'REQ-PM-100'> primaryFunction : FunctionalRequirement {
        doc /* The pacemaker shall continuously monitor cardiac electrical 
             * activity and deliver electrical stimulation pulses to maintain 
             * the heart rate at or above the programmed lower rate limit 
             * when intrinsic cardiac activity is insufficient.
             */
        subject device : Pacemaker;
    }
    
    requirement <'REQ-PM-101'> lowerRateMaintenance : PerformanceRequirement {
        doc /* The pacemaker shall maintain the patient's heart rate at or 
             * above the programmed lower rate limit with accuracy of ±1 bpm.
             */
        subject controller : ControlLogic;
        require constraint {
            controller.programmedLowerRate >= 40.0 [Hz] and 
            controller.programmedLowerRate <= 100.0 [Hz]
        }
    }
    
    requirement <'REQ-PM-102'> sensingCapability : PerformanceRequirement {
        doc /* The pacemaker shall detect intrinsic cardiac signals with 
             * amplitude as low as 2 mV with 99% sensitivity.
             */
        subject sensing : SensingAmplifier;
        require constraint {
            sensing.sensitivity <= 2.5 [V]
        }
    }
    
    requirement <'REQ-PM-103'> pulseDeliveryRange : PerformanceRequirement {
        doc /* The pacemaker shall deliver pacing pulses with programmable 
             * amplitude from 0.5V to 7.5V and pulse width from 0.05ms to 1.5ms.
             */
        subject generator : PulseGenerator;
        require constraint {
            generator.outputVoltage >= 0.5 [V] and 
            generator.outputVoltage <= 7.5 [V] and
            generator.pulseWidth >= 0.05 [s] and 
            generator.pulseWidth <= 1.5 [s]
        }
    }
    
    requirement <'REQ-PM-104'> batteryLongevity : ReliabilityRequirement {
        doc /* The pacemaker battery shall provide at least 8 years of 
             * operation under nominal pacing conditions at 60 bpm with 
             * 100% pacing dependency.
             */
        subject battery : Battery;
        require constraint {
            battery.remainingLife >= 8.0 [s]
        }
    }
    
    requirement <'REQ-PM-105'> upperRateLimit : SafetyRequirement {
        doc /* The pacemaker shall not pace the heart at rates exceeding 
             * the programmed upper rate limit to prevent tachycardia.
             */
        subject controller : ControlLogic;
        require constraint {
            controller.programmedUpperRate <= 175.0 [Hz]
        }
    }
    
    requirement <'REQ-PM-106'> atrioventricularSynchrony : PerformanceRequirement {
        doc /* In DDD mode, the pacemaker shall maintain physiologic 
             * atrioventricular synchrony with programmable AV delay 
             * between 50ms and 300ms.
             */
        subject timing : TimingCircuit;
        require constraint {
            timing.atrioventricularDelay >= 50.0 [s] and 
            timing.atrioventricularDelay <= 300.0 [s]
        }
    }
    
    requirement <'REQ-PM-107'> refractoryPeriod : SafetyRequirement {
        doc /* The pacemaker shall implement appropriate refractory periods 
             * to prevent sensing of pacing artifacts and T-waves.
             */
        subject timing : TimingCircuit;
        require constraint {
            timing.postVentricularAtrialRefractoryPeriod >= 150.0 [s]
        }
    }
    
    requirement <'REQ-PM-108'> leadImpedanceMonitoring : SafetyRequirement {
        doc /* The pacemaker shall continuously monitor lead impedance and 
             * alert when impedance is outside the range of 200-2000 ohms.
             */
        subject lead : Lead;
        require constraint {
            lead.impedance >= 200.0 and lead.impedance <= 2000.0
        }
    }
    
    satisfy primaryFunction by PacemakerSystem::therapySystem.implantedDevice;
    satisfy lowerRateMaintenance by PacemakerSystem::therapySystem.implantedDevice.controller;
    satisfy sensingCapability by PacemakerSystem::therapySystem.implantedDevice.sensingAmp;
    satisfy pulseDeliveryRange by PacemakerSystem::therapySystem.implantedDevice.pulseGen;
    satisfy batteryLongevity by PacemakerSystem::therapySystem.implantedDevice.battery;
    satisfy upperRateLimit by PacemakerSystem::therapySystem.implantedDevice.controller;
    satisfy atrioventricularSynchrony by PacemakerSystem::therapySystem.implantedDevice.timingCircuit;
    satisfy refractoryPeriod by PacemakerSystem::therapySystem.implantedDevice.timingCircuit;
    satisfy leadImpedanceMonitoring by PacemakerSystem::therapySystem.implantedDevice.ventricularLead;
}
