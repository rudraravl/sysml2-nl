package AirIoniser_BaseArchitecture {
    private import ScalarValues::*;
    private import SI::*;
    
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def PowerValue :> Real;
    attribute def AirFlowRateValue :> Real;
    attribute def ParticleConcentrationValue :> Real;
    attribute def IonDensityValue :> Real;
    
    part def AirIoniser;
    part def PowerSupply;
    part def IonGenerator;
    part def CollectionPlate;
    part def Fan;
    part def ControlUnit;
    part def HousingEnclosure;
}

package AirIoniser_StakeholderRequirements {
    requirement <'REQ-100'> purifyAir {
        doc /* The air ioniser shall reduce airborne particle 
             * concentration to improve indoor air quality.
             */
        subject ioniser : AirIoniser_BaseArchitecture::AirIoniser;
    }
    
    requirement <'REQ-101'> operateSafely {
        doc /* The air ioniser shall operate at safe voltage levels
             * and produce no harmful ozone concentrations.
             */
        subject ioniser : AirIoniser_BaseArchitecture::AirIoniser;
    }
    
    requirement <'REQ-102'> energyEfficient {
        doc /* The air ioniser shall operate with minimal power
             * consumption for continuous use.
             */
        subject ioniser : AirIoniser_BaseArchitecture::AirIoniser;
    }
}

package AirIoniser_SystemArchitecture {
    private import AirIoniser_BaseArchitecture::*;
    private import ScalarValues::*;
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def AirPort {
        attribute flowRate : AirFlowRateValue;
        attribute particleConcentration : ParticleConcentrationValue;
    }
    
    port def ControlSignalPort {
        attribute enable : Boolean;
        attribute outputLevel : Real;
    }
    
    part ioniser : AirIoniser {
        attribute totalPower : PowerValue = powerSupply.outputPower;
        attribute ionOutputDensity : IonDensityValue = ionGen.ionDensity;
        attribute particleReductionEfficiency : Real = 0.85;
        
        part powerSupply : PowerSupply {
            attribute inputVoltage : VoltageValue = 120.0;
            attribute outputVoltage : VoltageValue = 8000.0;
            attribute outputCurrent : CurrentValue = 0.0005;
            attribute outputPower : PowerValue = 4.0;
            attribute efficiency : Real = 0.90;
            
            port powerIn : PowerPort {
                :>> voltage = inputVoltage;
            }
            port powerOut : PowerPort {
                :>> voltage = outputVoltage;
                :>> current = outputCurrent;
            }
        }
        
        part ionGen : IonGenerator {
            attribute operatingVoltage : VoltageValue;
            attribute ionDensity : IonDensityValue = 2000000.0;
            attribute numberOfEmitters : Integer = 6;
            attribute emitterMaterial : String = "Carbon fiber";
            
            port hvInput : PowerPort {
                :>> voltage = operatingVoltage;
            }
            port ionOutput {
                attribute density : IonDensityValue = ionDensity;
            }
        }
        
        part collectionPlate : CollectionPlate {
            attribute surfaceArea : Real = 0.15;
            attribute collectionEfficiency : Real = 0.75;
            attribute materialType : String = "Aluminum";
            
            port particleCollector {
                attribute capacity : Real;
            }
        }
        
        part fan : Fan {
            attribute intakeFlowRate : AirFlowRateValue = 0.00083;
            
            port airIn : AirPort {
                :>> flowRate = intakeFlowRate;
            }
            port airOut : AirPort;
        }
        
        part controlUnit : ControlUnit {
            attribute operatingMode : String = "Auto";
            attribute powerState : Boolean = true;
            attribute fanSpeed : Real = 1.0;
            
            port controlOut : ControlSignalPort;
        }
        
        part housing : HousingEnclosure {
            attribute length : Real = 0.25;
            attribute width : Real = 0.15;
            attribute height : Real = 0.30;
            attribute totalMass : Real = 1.2;
        }
        
        connection hvPowerConnection connect powerSupply.powerOut to ionGen.hvInput;
        connection controlConnection connect controlUnit.controlOut to ionGen.ionOutput;
        connection airFlowConnection connect fan.airOut to collectionPlate.particleCollector;
    }
    
    satisfy AirIoniser_StakeholderRequirements::purifyAir by ioniser;
    satisfy AirIoniser_StakeholderRequirements::operateSafely by ioniser;
    satisfy AirIoniser_StakeholderRequirements::energyEfficient by ioniser;
}

package AirIoniser_SystemRequirements {
    private import AirIoniser_SystemArchitecture::*;
    
    requirement <'REQ-1001'> voltageLimit {
        subject ps :>> ioniser.powerSupply;
        assert constraint {
            ps.outputVoltage <= 10000.0
        }
    }
    
    requirement <'REQ-1002'> powerConsumption {
        subject device :>> ioniser;
        assert constraint {
            device.totalPower <= 5.0
        }
    }
    
    requirement <'REQ-1003'> ionDensityRequirement {
        subject generator :>> ioniser.ionGen;
        assert constraint {
            generator.ionDensity >= 1000000.0
        }
    }
    
    requirement <'REQ-1004'> particleReduction {
        subject device :>> ioniser;
        assert constraint {
            device.particleReductionEfficiency >= 0.80
        }
    }
    
    requirement <'REQ-1005'> airFlowRate {
        subject intake :>> ioniser.fan;
        assert constraint {
            intake.intakeFlowRate >= 0.0005
        }
    }
}

package AirIoniser_Behavior {
    private import ScalarValues::*;
    
    occurrence def PowerOnEvent;
    occurrence def AirQualityTargetEvent;
    occurrence def PowerOffEvent;
    
    action def GenerateIons {
        in highVoltage : Real;
        out negativeIons : Real;
    }
    
    action def AttractParticles {
        in ionDensity : Real;
        in particleCount : Real;
        out chargedParticles : Real;
    }
    
    action def CollectParticles {
        in chargedParticles : Real;
        out collectedMass : Real;
    }
    
    action def MonitorAirQuality {
        in particleConcentration : Real;
        out qualityLevel : Real;
    }
    
    action def ApplyPower {
        doc /* Power supply converts AC to high voltage DC */
    }
    
    action def IonisationCycle {
        first start;
        
        then action applyPower : ApplyPower;
        
        then action generateIons : GenerateIons {
            in highVoltage : Real = 8000.0;
            out negativeIons : Real;
        }
        
        then action attractParticles : AttractParticles {
            in ionDensity = generateIons.negativeIons;
            in particleCount : Real;
            out chargedParticles : Real;
        }
        
        then action collectParticles : CollectParticles {
            in chargedParticles = attractParticles.chargedParticles;
            out collectedMass : Real;
        }
        
        then action monitorQuality : MonitorAirQuality {
            in particleConcentration : Real;
            out qualityLevel : Real;
        }
        
        then decide;
            if monitorQuality.qualityLevel < 0.90 then continueOperation;
            if monitorQuality.qualityLevel >= 0.90 then reduceOutput;
        
        merge continueOperation;
        then generateIons;
        
        action reduceOutput {
            doc /* Reduce ion output when air quality is acceptable */
        }
        then done;
    }
    
    state def IoniserOperationStates {
        entry; then idle;
        
        state idle {
            entry action {
                doc /* System powered but not actively ionizing */
            }
        }
        
        transition idle_to_active
            first idle
            accept PowerOnEvent
            then active;
        
        state active {
            entry action {
                doc /* High voltage applied, ions being generated */
            }
            
            state generatingIons;
            state collectingParticles;
            
            transition generating_to_collecting
                first generatingIons
                then collectingParticles;
        }
        
        transition active_to_standby
            first active
            accept AirQualityTargetEvent
            then standby;
        
        state standby {
            entry action {
                doc /* Reduced power mode, monitoring only */
            }
        }
        
        transition standby_to_idle
            first standby
            accept PowerOffEvent
            then idle;
    }
}

package AirIoniser_Integration {
    private import AirIoniser_BaseArchitecture::*;
    private import AirIoniser_SystemArchitecture::*;
    private import AirIoniser_Behavior::*;
    
    part activeIoniser :> ioniser {
        perform action operationCycle[*] ordered : IonisationCycle;
        exhibit state operationStates : IoniserOperationStates;
    }
}
