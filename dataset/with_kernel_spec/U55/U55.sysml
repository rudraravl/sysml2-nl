package AED_System {
    private import ScalarValues::*;
    
    attribute def Voltage :> Real;
    attribute def Energy :> Real;
    attribute def Impedance :> Real;
    
    attribute def ECGSignal :> Real;
    attribute def RhythmAnalysisResult :> String;
    attribute def ShockAdvised :> RhythmAnalysisResult;
    attribute def NoShockAdvised :> RhythmAnalysisResult;
    attribute def ChargeCommand :> String;
    attribute def ShockCommand :> String;
    attribute def ChargeComplete :> Boolean;
    attribute def ShockButtonPressed :> Boolean;
    attribute def SafetyArmed :> Boolean;
    attribute def PadContactOK :> Boolean;
    attribute def VoicePrompt :> String;
    attribute def VisualInstruction :> String;
    
    attribute def ElectricalEnergy :> Real {
        attribute energyAmount : Energy;
    }
    
    port def ECGPort {
        attribute ecgSignal : ECGSignal;
    }
    port def EnergyPort {
        attribute electricalEnergy : ElectricalEnergy;
    }
    port def ChargeCommandPort {
        attribute chargeCommand : ChargeCommand;
    }
    port def ShockCommandPort {
        attribute shockCommand : ShockCommand;
    }
    port def StatusPort {
        attribute status : ChargeComplete;
    }
    port def ImpedancePort {
        attribute impedance : Impedance;
    }
    port def SafetyPort {
        attribute safetyArmed : SafetyArmed;
    }
    port def UICommandPort {
        attribute voicePrompt : VoicePrompt;
        attribute visualInstruction : VisualInstruction;
    }
    port def ButtonPort {
        attribute buttonPressed : ShockButtonPressed;
    }
    port def PowerPort {
        attribute voltage : Voltage;
    }
    port def ResultPort {
        attribute result : RhythmAnalysisResult;
    }
    port def ContactPort {
        attribute contact : PadContactOK;
    }
    
    action def AnalyzeECG {
        in ecg : ECGSignal;
        out result : RhythmAnalysisResult;
    }
    action def ChargeCapacitor {
        in targetEnergy : Energy;
    }
    action def DeliverShockAction {
        in energy : ElectricalEnergy;
        in patientImpedance : Impedance;
    }
    action def ProvideVoicePromptAction {
        in message : String;
    }
    action def DisplayInstructionAction {
        in instruction : String;
    }
    
    action analyzeECG : AnalyzeECG;
    action chargeCapacitor : ChargeCapacitor;
    action deliverShock : DeliverShockAction;
    action provideVoicePrompt : ProvideVoicePromptAction;
    action displayInstruction : DisplayInstructionAction;
    
    state def AEDStates;
    
    part def ElectrodePads {
        port ecgOut : ECGPort;
        port shockIn : EnergyPort;
        port contactOut : ContactPort;
        port impedanceOut : ImpedancePort;
        attribute patientImpedance : Impedance;
        attribute contactQuality : PadContactOK;
    }
    
    part def ECGAnalysisModule {
        port ecgIn : ECGPort;
        port resultOut : ResultPort;
    }
    
    part def BatteryPack {
        port powerOut : PowerPort;
        attribute chargeLevel : Energy;
    }
    
    part def EnergyStorageUnit {
        port powerIn : PowerPort;
        port chargeCmdIn : ChargeCommandPort;
        port chargeStatusOut : StatusPort;
        port storedEnergyOut : EnergyPort;
        attribute capacitorVoltage : Voltage;
        attribute storedEnergyValue : Energy;
    }
    
    part def ShockDeliveryCircuit {
        port storedEnergyIn : EnergyPort;
        port shockCmdIn : ShockCommandPort;
        port patientImpedanceIn : ImpedancePort;
        port shockEnergyOut : EnergyPort;
    }
    
    part def SafetyInterlockSystem {
        port padContactIn : ContactPort;
        port impedanceIn : ImpedancePort;
        port chargeStatusIn : StatusPort;
        port shockButtonIn : ButtonPort;
        port safetyArmedOut : SafetyPort;
        attribute allConditionsMet : SafetyArmed;
    }
    
    part def OperatorInterface {
        port uiCommandIn : UICommandPort;
        port shockButtonOut : ButtonPort;
    }
    
    part def ControlProcessor {
        port resultIn : ResultPort;
        port safetyArmedIn : SafetyPort;
        port chargeCmdOut : ChargeCommandPort;
        port shockCmdOut : ShockCommandPort;
        port uiCmdOut : UICommandPort;
    }
    
    state aedStates : AEDStates {
        entry; then Analyzing;
        state Analyzing {
            do analyzeECG;
        }
        accept ShockAdvised then Charging;
        accept NoShockAdvised then Analyzing;
        state Charging {
            do chargeCapacitor;
        }
        accept ChargeComplete then ReadyToShock;
        state ReadyToShock {
            do provideVoicePrompt;
        }
        accept ShockButtonPressed then ShockDelivery;
        state ShockDelivery {
            do deliverShock;
        }
        accept ShockCommand then Analyzing;
    }
    
    part def AutomatedExternalDefibrillator {
        part controlProcessor : ControlProcessor;
        part electrodePads : ElectrodePads;
        part ecgAnalysisModule : ECGAnalysisModule;
        part batteryPack : BatteryPack;
        part energyStorageUnit : EnergyStorageUnit;
        part shockDeliveryCircuit : ShockDeliveryCircuit;
        part safetyInterlockSystem : SafetyInterlockSystem;
        part operatorInterface : OperatorInterface;
        
        connect electrodePads.ecgOut to ecgAnalysisModule.ecgIn;
        connect ecgAnalysisModule.resultOut to controlProcessor.resultIn;
        connect batteryPack.powerOut to energyStorageUnit.powerIn;
        connect controlProcessor.chargeCmdOut to energyStorageUnit.chargeCmdIn;
        connect energyStorageUnit.chargeStatusOut to safetyInterlockSystem.chargeStatusIn;
        connect energyStorageUnit.storedEnergyOut to shockDeliveryCircuit.storedEnergyIn;
        connect controlProcessor.shockCmdOut to shockDeliveryCircuit.shockCmdIn;
        connect shockDeliveryCircuit.shockEnergyOut to electrodePads.shockIn;
        connect electrodePads.contactOut to safetyInterlockSystem.padContactIn;
        connect electrodePads.impedanceOut to safetyInterlockSystem.impedanceIn;
        connect electrodePads.impedanceOut to shockDeliveryCircuit.patientImpedanceIn;
        connect operatorInterface.shockButtonOut to safetyInterlockSystem.shockButtonIn;
        connect safetyInterlockSystem.safetyArmedOut to controlProcessor.safetyArmedIn;
        connect controlProcessor.uiCmdOut to operatorInterface.uiCommandIn;
    }
    
    part aed : AutomatedExternalDefibrillator;
    
    requirement def AEDRequirement {
        subject aed : AutomatedExternalDefibrillator;
    }
    
    requirement def ShockDeliveryRequirement :> AEDRequirement {
        doc /* The AED must deliver a biphasic shock when a shockable rhythm is detected and all safety conditions are met. */
    }
    
    requirement def SafetyInterlockRequirement :> AEDRequirement {
        doc /* The Safety Interlock System must verify all shock conditions before allowing a shock to be delivered. */
    }
    
    requirement def AnalysisCycleRequirement :> AEDRequirement {
        doc /* The system shall continuously cycle through rhythm analysis, operator advisement, charging, shock delivery, and re-analysis. */
    }
    
    requirement def VoicePromptRequirement :> AEDRequirement {
        doc /* The Operator Interface shall provide clear voice prompts and visual instructions for each step of the resuscitation protocol. */
    }
    
    requirement def ImpedanceCompensationRequirement :> AEDRequirement {
        doc /* The Shock Delivery Circuit shall compensate for patient impedance to deliver the correct energy dose. */
    }
}
