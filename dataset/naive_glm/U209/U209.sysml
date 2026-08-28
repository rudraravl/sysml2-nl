package DualPhaseSignalGenerator {
    import ScalarValues::*;
    import SI::*;
    
    value def Voltage :> Real { unit 'V'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Phase :> Real { unit 'deg'; }
    value def Quality :> Real { unit '1'; }
    value def Current :> Real { unit 'A'; }
    
    item def ElectricalSignal {
        attribute frequency : Frequency;
        attribute phase : Phase;
        attribute amplitude : Voltage;
    }
    
    item def ControlSignal {
        attribute phaseCorrection : Phase;
    }
    
    item def Power {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    port def SignalOutPort {
        out signal : ElectricalSignal;
    }
    
    port def SignalInPort {
        in signal : ElectricalSignal;
    }
    
    port def ControlOutPort {
        out correction : ControlSignal;
    }
    
    port def ControlInPort {
        in correction : ControlSignal;
    }
    
    port def PowerOutPort {
        out pwr : Power;
    }
    
    port def PowerInPort {
        in pwr : Power;
    }
    
    part def PrimaryOscillator {
        attribute nominalFrequency : Frequency = 1000 [Hz];
        port powerIn : PowerInPort;
        port signalOut : SignalOutPort;
        port controlIn : ControlInPort;
        
        action def generateSignal {
            out signal : ElectricalSignal;
        }
    }
    
    part def SecondaryOscillator {
        attribute nominalFrequency : Frequency = 1000 [Hz];
        port powerIn : PowerInPort;
        port signalOut : SignalOutPort;
        port controlIn : ControlInPort;
        
        action def generateSignal {
            out signal : ElectricalSignal;
        }
    }
    
    part def PhaseSynchronizer {
        attribute targetPhaseDiff : Phase = 90 [deg];
        port powerIn : PowerInPort;
        port primarySignalIn : SignalInPort;
        port secondarySignalIn : SignalInPort;
        port primaryControlOut : ControlOutPort;
        port secondaryControlOut : ControlOutPort;
        
        action def synchronize {
            in primarySignal : ElectricalSignal;
            in secondarySignal : ElectricalSignal;
            out primaryCorrection : ControlSignal;
            out secondaryCorrection : ControlSignal;
        }
    }
    
    part def PowerSupply {
        attribute inputVoltage : Voltage = 12 [V];
        attribute outputVoltage : Voltage = 5 [V];
        port rawPowerIn : PowerInPort;
        port regulatedPowerOut : PowerOutPort;
        
        action def regulatePower {
            in rawPower : Power;
            out regulatedPower : Power;
        }
    }
    
    part def MonitoringUnit {
        attribute errorCount : Integer = 0;
        attribute syncQuality : Quality = 0.0;
        port powerIn : PowerInPort;
        port primarySignalIn : SignalInPort;
        port secondarySignalIn : SignalInPort;
        
        action def monitorSystem {
            in primarySignal : ElectricalSignal;
            in secondarySignal : ElectricalSignal;
            out quality : Quality;
        }
    }
    
    part def DualPhaseGeneratorSystem {
        port rawPower : PowerInPort;
        port primaryOutput : SignalOutPort;
        port secondaryOutput : SignalOutPort;
        
        part powerSupply : PowerSupply;
        part primaryOsc : PrimaryOscillator;
        part secondaryOsc : SecondaryOscillator;
        part synchronizer : PhaseSynchronizer;
        part monitor : MonitoringUnit;
        
        connection rawPowerConn connect rawPower to powerSupply.rawPowerIn;
        connection powerDist1 connect powerSupply.regulatedPowerOut to primaryOsc.powerIn;
        connection powerDist2 connect powerSupply.regulatedPowerOut to secondaryOsc.powerIn;
        connection powerDist3 connect powerSupply.regulatedPowerOut to synchronizer.powerIn;
        connection powerDist4 connect powerSupply.regulatedPowerOut to monitor.powerIn;
        
        connection primarySignalFeedback connect primaryOsc.signalOut to synchronizer.primarySignalIn;
        connection secondarySignalFeedback connect secondaryOsc.signalOut to synchronizer.secondarySignalIn;
        
        connection primaryControlConn connect synchronizer.primaryControlOut to primaryOsc.controlIn;
        connection secondaryControlConn connect synchronizer.secondaryControlOut to secondaryOsc.controlIn;
        
        connection primarySignalMonitor connect primaryOsc.signalOut to monitor.primarySignalIn;
        connection secondarySignalMonitor connect secondaryOsc.signalOut to monitor.secondarySignalIn;
        
        connection primarySignalOutput connect primaryOsc.signalOut to primaryOutput;
        connection secondarySignalOutput connect secondaryOsc.signalOut to secondaryOutput;
        
        state systemStateMachine {
            attribute syncQuality : Quality;
            attribute phaseError : Phase;
            
            state standby;
            state initializing;
            state active;
            state synchronized;
            state degraded;
            
            transition init first standby then initializing;
            transition start first initializing then active;
            transition lock first active then synchronized when syncQuality > 0.95 and phaseError < 1 [deg];
            transition loseLock first synchronized then degraded when syncQuality < 0.8;
            transition recover first degraded then active when syncQuality > 0.9;
        }
    }
    
    requirement def DualPhaseRequirements {
        requirement generate1000Hz {
            subject system : DualPhaseGeneratorSystem;
            require system.primaryOutput.signal.frequency == 1000 [Hz];
            require system.secondaryOutput.signal.frequency == 1000 [Hz];
        }
        
        requirement maintain90DegPhase {
            subject system : DualPhaseGeneratorSystem;
            require system.synchronizer.targetPhaseDiff == 90 [deg];
        }
        
        requirement powerConversion {
            subject system : DualPhaseGeneratorSystem;
            require system.powerSupply.inputVoltage == 12 [V];
            require system.powerSupply.outputVoltage == 5 [V];
        }
    }
}
