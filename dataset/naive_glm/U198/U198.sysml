package AED_Model {
    import ScalarValues::*;
    
    // Value Types
    item def Energy :> Real { attribute unit : String = "Joules"; }
    item def Voltage :> Real { attribute unit : String = "Volts"; }
    item def Current :> Real { attribute unit : String = "Amperes"; }
    item def Impedance :> Real { attribute unit : String = "Ohms"; }
    item def Time :> Real { attribute unit : String = "Seconds"; }
    
    // Enumerations
    enum def RhythmType { normal; vfib; vtach; asystole; }
    enum def PromptType { applyPads; standClear; pressShock; startCPR; allClear; }
    
    // Item Types
    item def ECGSignal { 
        attribute rhythm : RhythmType; 
        attribute amplitude : Voltage; 
    }
    item def ShockWaveform {
        attribute energy : Energy;
        attribute peakVoltage : Voltage;
        attribute duration : Time;
    }
    item def ControlCommand;
    item def ChargeCommand { attribute targetEnergy : Energy; }
    item def ShockCommand;
    item def ImpedanceMeasurement { attribute value : Impedance; }
    item def AudioPrompt { attribute message : PromptType; }
    item def VisualInstruction { attribute message : PromptType; }
    
    // Port Definitions
    port def ECGFlowPort { out signal : ECGSignal; }
    port def PowerFlowPort { out current : Current; out voltage : Voltage; }
    port def ControlFlowPort { out command : ControlCommand; }
    port def TherapyFlowPort { out waveform : ShockWaveform; }
    port def AudioFlowPort { out prompt : AudioPrompt; }
    port def VisualFlowPort { out instruction : VisualInstruction; }
    port def ImpedanceFlowPort { out measurement : ImpedanceMeasurement; }
    
    // Part Definitions
    part def MicrocontrollerUnit {
        port in ecgIn : ECGFlowPort;
        port out chargeCmd : ControlFlowPort;
        port out shockCmd : ControlFlowPort;
        port out audioOut : AudioFlowPort;
        port out visualOut : VisualFlowPort;
        port in shockButtonIn : ControlFlowPort;
        port in impedanceIn : ImpedanceFlowPort;
        
        attribute isShockable : Boolean = false;
        
        action def AnalyzeRhythm {
            in signal : ECGSignal;
            out shockable : Boolean;
        }
    }
    
    part def BatteryModule {
        port out powerOut : PowerFlowPort;
        attribute capacity : Energy = 3000;
        attribute remainingCharge : Energy = 3000;
    }
    
    part def DefibrillationElectrodes {
        port out ecgOut : ECGFlowPort;
        port in therapyIn : TherapyFlowPort;
        port out impedanceOut : ImpedanceFlowPort;
        attribute isAttached : Boolean = false;
    }
    
    part def ECGAnalysisModule {
        port in ecgIn : ECGFlowPort;
        port out analysisOut : ECGFlowPort;
        
        action def RunAlgorithm {
            in signal : ECGSignal;
            out rhythm : RhythmType;
        }
    }
    
    part def HighVoltageCapacitor {
        port in powerIn : PowerFlowPort;
        port in chargeCmdIn : ControlFlowPort;
        port out therapyOut : TherapyFlowPort;
        attribute storedEnergy : Energy = 0;
    }
    
    part def TherapyDeliveryCircuit {
        port in capacitorIn : TherapyFlowPort;
        port in shockCmdIn : ControlFlowPort;
        port in impedanceIn : ImpedanceFlowPort;
        port out therapyOut : TherapyFlowPort;
        attribute waveform : ShockWaveform;
    }
    
    part def OperatorInterface {
        port in audioIn : AudioFlowPort;
        port in visualIn : VisualFlowPort;
        port out shockButtonOut : ControlFlowPort;
        attribute displayActive : Boolean = true;
    }
    
    part def AutomatedExternalDefibrillator {
        part mcu : MicrocontrollerUnit;
        part battery : BatteryModule;
        part electrodes : DefibrillationElectrodes;
        part ecgModule : ECGAnalysisModule;
        part hvCapacitor : HighVoltageCapacitor;
        part therapyCircuit : TherapyDeliveryCircuit;
        part operatorInterface : OperatorInterface;
        
        connection ecgToModule connect electrodes.ecgOut to ecgModule.ecgIn;
        connection moduleToMcu connect ecgModule.analysisOut to mcu.ecgIn;
        connection mcuToChargeCmd connect mcu.chargeCmd to hvCapacitor.chargeCmdIn;
        connection batteryToCapacitor connect battery.powerOut to hvCapacitor.powerIn;
        connection capacitorToTherapy connect hvCapacitor.therapyOut to therapyCircuit.capacitorIn;
        connection mcuToShockCmd connect mcu.shockCmd to therapyCircuit.shockCmdIn;
        connection electrodesToTherapyImpedance connect electrodes.impedanceOut to therapyCircuit.impedanceIn;
        connection therapyToElectrodes connect therapyCircuit.therapyOut to electrodes.therapyIn;
        connection mcuToInterfaceAudio connect mcu.audioOut to operatorInterface.audioIn;
        connection mcuToInterfaceVisual connect mcu.visualOut to operatorInterface.visualIn;
        connection interfaceToMcuShock connect operatorInterface.shockButtonOut to mcu.shockButtonIn;
        
        state def AEDBehavior {
            state off;
            state standby;
            state padsAttached;
            state analyzing;
            state shockAdvised;
            state charging;
            state readyToShock;
            state shockDelivered;
            state cprInterval;
            
            transition off to standby;
            transition standby to padsAttached when electrodes.isAttached;
            transition padsAttached to analyzing;
            transition analyzing to shockAdvised when mcu.isShockable;
            transition analyzing to cprInterval when !mcu.isShockable;
            transition shockAdvised to charging;
            transition charging to readyToShock when hvCapacitor.storedEnergy >= 150;
            transition readyToShock to shockDelivered;
            transition shockDelivered to analyzing;
            transition cprInterval to analyzing;
        }
    }
    
    requirement def AnalyzeHeartRhythmReq {
        subject aed : AutomatedExternalDefibrillator;
        objective {
            doc /* The AED shall automatically analyze the patient's heart rhythm via ECG electrodes. */
        }
    }
    
    requirement def DeliverShockReq {
        subject aed : AutomatedExternalDefibrillator;
        objective {
            doc /* If a shockable rhythm is detected, the AED shall deliver a controlled electrical shock tailored to patient impedance. */
        }
    }
    
    requirement def OperatorGuidanceReq {
        subject aed : AutomatedExternalDefibrillator;
        objective {
            doc /* The AED shall provide clear voice and visual instructions to guide the operator through the rescue process. */
        }
    }
    
    requirement def PowerSupplyReq {
        subject aed : AutomatedExternalDefibrillator;
        objective {
            doc /* The AED battery shall be capable of delivering multiple shocks and hours of continuous monitoring. */
        }
    }
}
