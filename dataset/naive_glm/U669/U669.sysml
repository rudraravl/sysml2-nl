package EngineKnockControlSystem {
    import ISQ::*;
    
    // Value Types
    value type SparkTimingDelay :> Real {
        unit 'deg';
    }
    
    value type FuelEnrichmentFactor :> Real {
        unit '%';
    }
    
    item def VibrationSignal {
        attr amplitude : Real; // in Volts
        attr frequency : Real; // in Hz
    }
    
    enum def KnockIntensityLevel {
        none = 0;
        light = 1;
        moderate = 2;
        severe = 3;
    }
    
    // Ports
    port def KnockSignalPort {
        out signal : VibrationSignal;
    }
    
    port def IgnitionCommandPort {
        out delay : SparkTimingDelay;
    }
    
    port def FuelCommandPort {
        out enrichment : FuelEnrichmentFactor;
    }
    
    // Parts
    part def KnockSensor {
        port knockOut : KnockSignalPort;
        
        attribute currentSignal : VibrationSignal;
        
        action def GenerateSignal {
            out signal : VibrationSignal;
            // Simulate sending signal based on detected vibrations
            signal := currentSignal;
        }
    }
    
    part def IgnitionSystem {
        port ignitionIn : ~IgnitionCommandPort;
        
        action def AdjustTiming {
            in delay : SparkTimingDelay;
            // Adjust spark timing based on command
        }
    }
    
    part def FuelInjectionSystem {
        port fuelIn : ~FuelCommandPort;
        
        action def AdjustMixture {
            in enrichment : FuelEnrichmentFactor;
            // Adjust fuel mixture based on command
        }
    }
    
    part def EngineControlUnit {
        port knockIn : ~KnockSignalPort;
        port ignitionOut : IgnitionCommandPort;
        port fuelOut : FuelCommandPort;
        
        attribute currentKnockIntensity : KnockIntensityLevel = KnockIntensityLevel::none;
        
        action def AnalyzeSignal {
            in signal : VibrationSignal;
            out intensity : KnockIntensityLevel;
            // Analyze signal amplitude and frequency to determine intensity
            if signal.amplitude > 5.0 {
                intensity := KnockIntensityLevel::severe;
            } else if signal.amplitude > 3.0 {
                intensity := KnockIntensityLevel::moderate;
            } else if signal.amplitude > 1.0 {
                intensity := KnockIntensityLevel::light;
            } else {
                intensity := KnockIntensityLevel::none;
            }
        }
        
        state machine ECUStateMachine {
            state Monitoring {
                entry {
                    /* Normal monitoring logic */
                }
                do {
                    // Continuously analyze incoming knock signals
                }
            }
            
            state LightKnockMitigation {
                entry {
                    send ignitionOut.delay := 2.0 ['deg'];
                }
            }
            
            state ModerateKnockMitigation {
                entry {
                    send ignitionOut.delay := 5.0 ['deg'];
                    send fuelOut.enrichment := 10.0 ['%'];
                }
            }
            
            state SevereProtection {
                entry {
                    send ignitionOut.delay := 10.0 ['deg'];
                    send fuelOut.enrichment := 25.0 ['%'];
                }
            }
            
            transition Monitoring to LightKnockMitigation when currentKnockIntensity == KnockIntensityLevel::light;
            transition Monitoring to ModerateKnockMitigation when currentKnockIntensity == KnockIntensityLevel::moderate;
            transition Monitoring to SevereProtection when currentKnockIntensity == KnockIntensityLevel::severe;
            
            transition LightKnockMitigation to Monitoring when currentKnockIntensity == KnockIntensityLevel::none;
            transition LightKnockMitigation to ModerateKnockMitigation when currentKnockIntensity == KnockIntensityLevel::moderate;
            transition LightKnockMitigation to SevereProtection when currentKnockIntensity == KnockIntensityLevel::severe;
            
            transition ModerateKnockMitigation to Monitoring when currentKnockIntensity == KnockIntensityLevel::none;
            transition ModerateKnockMitigation to LightKnockMitigation when currentKnockIntensity == KnockIntensityLevel::light;
            transition ModerateKnockMitigation to SevereProtection when currentKnockIntensity == KnockIntensityLevel::severe;
            
            transition SevereProtection to Monitoring when currentKnockIntensity == KnockIntensityLevel::none;
            transition SevereProtection to ModerateKnockMitigation when currentKnockIntensity == KnockIntensityLevel::moderate;
            transition SevereProtection to LightKnockMitigation when currentKnockIntensity == KnockIntensityLevel::light;
        }
    }
    
    part def EngineBlock {
        part knockSensor1 : KnockSensor;
        part ignitionSystem : IgnitionSystem;
        part fuelInjectionSystem : FuelInjectionSystem;
        part ecu : EngineControlUnit;
        
        connection knockSignalConn connect knockSensor1.knockOut to ecu.knockIn;
        connection ignitionCmdConn connect ecu.ignitionOut to ignitionSystem.ignitionIn;
        connection fuelCmdConn connect ecu.fuelOut to fuelInjectionSystem.fuelIn;
    }
    
    // Requirements
    requirement def ProtectEngine {
        doc "Protect the engine from damage caused by engine knock while optimizing performance and fuel efficiency.";
    }
    
    requirement def DetectKnock {
        doc "Detect high-frequency vibrations produced by abnormal combustion using one or more knock sensors.";
    }
    
    requirement def ClassifyKnock {
        doc "Classify knock intensity as light, moderate, or severe based on sensor signal analysis.";
    }
    
    requirement def MitigateLightKnock {
        doc "For light knock, slightly delay the spark timing via the Ignition System.";
    }
    
    requirement def MitigateModerateSevereKnock {
        doc "For moderate or severe knock, delay the spark timing and temporarily enrich the fuel mixture via the Fuel Injection System.";
    }
    
    requirement def ContinuousClosedLoop {
        doc "Operate in a continuous closed loop, monitoring sensors after adjustments to confirm knock elimination.";
    }
    
    requirement def SevereProtectionMode {
        doc "Enter a more aggressive protection mode for severe, persistent knocking to prevent catastrophic engine failure.";
    }
    
    // Requirement Satisfaction
    requirement engineProtectionReq : ProtectEngine {
        subject engine : EngineBlock;
    }
    
    requirement knockDetectionReq : DetectKnock {
        subject sensor : KnockSensor;
    }
    
    requirement knockClassificationReq : ClassifyKnock {
        subject ecu : EngineControlUnit;
    }
    
    requirement lightKnockMitigationReq : MitigateLightKnock {
        subject ecu : EngineControlUnit;
    }
    
    requirement moderateSevereKnockMitigationReq : MitigateModerateSevereKnock {
        subject ecu : EngineControlUnit;
    }
    
    requirement closedLoopReq : ContinuousClosedLoop {
        subject ecu : EngineControlUnit;
    }
    
    requirement severeProtectionReq : SevereProtectionMode {
        subject ecu : EngineControlUnit;
    }
}
