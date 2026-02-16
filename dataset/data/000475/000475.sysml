package 'N95 Respirator System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FiltrationEfficiency {
        attribute value : Real;
    }
    
    attribute def ParticleDiameter :> ISQ::length;
    
    attribute def LeakageRate {
        attribute value : Real;
    }
    
    item def ContaminatedAir {
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute particleConcentration : Real;
        attribute pressure : ISQ::PressureValue;
    }
    
    item def FilteredAir {
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute particleConcentration : Real;
        attribute pressure : ISQ::PressureValue;
        attribute filtrationLevel : Real;
    }
    
    port def AirInletPort {
        in item contaminatedAir : ContaminatedAir;
    }
    
    port def AirOutletPort {
        out item filteredAir : FilteredAir;
    }
    
    port def FaceSealPort {
        attribute sealPressure : ISQ::PressureValue;
        attribute leakageRate : LeakageRate;
    }
    
    part def FilterMedium {
        attribute efficiency : FiltrationEfficiency;
        attribute breathingResistance : ISQ::PressureValue;
        attribute thickness : ISQ::LengthValue;
        
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
    }
    
    part def ElectrostaticFilterLayer :> FilterMedium {
        attribute electrostaticCharge : Real;
        attribute particleCaptureSize : ParticleDiameter;
    }
    
    part def MechanicalFilterLayer :> FilterMedium {
        attribute fiberDensity : Real;
        attribute poreSize : ISQ::LengthValue;
    }
    
    part def FacialSealAssembly {
        attribute sealEffectiveness : Real;
        attribute noseClipAdjustment : ISQ::LengthValue;
        
        port sealInterface : FaceSealPort;
        
        perform action createSeal {
            in facialContour : ISQ::LengthValue;
            out sealQuality : Real;
        }
    }
    
    part def RetentionStrapSystem {
        attribute tensionForce : ISQ::ForceValue;
        attribute adjustmentRange : ISQ::LengthValue;
        
        perform action maintainPosition {
            in headCircumference : ISQ::LengthValue;
            out retentionForce : ISQ::ForceValue;
        }
    }
    
    part def ExhalationValveAssembly {
        attribute openingThreshold : ISQ::PressureValue;
        attribute closingThreshold : ISQ::PressureValue;
        
        perform action regulateExhaust {
            in exhalationPressure : ISQ::PressureValue;
            out valvePosition : Real;
        }
    }
    
    action def CaptureParticulates {
        in contaminatedAirIn : ContaminatedAir;
        in filterEfficiency : FiltrationEfficiency;
        out cleanAirOut : FilteredAir;
    }
    
    action def InhalationCycle {
        in ambientAir : ContaminatedAir;
        in totalEfficiency : FiltrationEfficiency;
        out breathableAir : FilteredAir;
        
        action mechanicalCapture : CaptureParticulates {
            in contaminatedAirIn = ambientAir;
            in filterEfficiency;
            out cleanAirOut;
        }
        flow mechanicalCapture.cleanAirOut to electrostaticCapture.contaminatedAirIn;
        
        action electrostaticCapture : CaptureParticulates {
            in contaminatedAirIn;
            in filterEfficiency = totalEfficiency;
            out cleanAirOut;
        }
        flow electrostaticCapture.cleanAirOut to breathableAir;
    }
    
    action def ExhalationCycle {
        in expiredAir : FilteredAir;
        out exhaustAir : ContaminatedAir;
    }
    
    state def RespirationState {
        entry; then idle;
        
        state idle;
        
        transition startInhale
            first idle
            then inhaling;
        
        state inhaling {
            entry; do action performInhale : InhalationCycle;
        }
        
        transition completeInhale
            first inhaling
            then exhaling;
        
        state exhaling {
            entry; do action performExhale : ExhalationCycle;
        }
        
        transition completeExhale
            first exhaling
            then idle;
    }
    
    part def N95Respirator {
        attribute designEfficiency : FiltrationEfficiency = 95.0;
        attribute targetParticleSize : ParticleDiameter = 0.3e-6 [SI::m];
        attribute maxInhalationResistance : ISQ::PressureValue = 343.0 [SI::Pa];
        attribute maxExhalationResistance : ISQ::PressureValue = 245.0 [SI::Pa];
        attribute testFlowRate : ISQ::VolumeFlowRateValue = 85.0e-3 [SI::m^3/SI::s];
        
        port airIntake : AirInletPort;
        port breathingInterface : AirOutletPort;
        
        part outerMechanicalLayer : MechanicalFilterLayer {
            attribute efficiency : FiltrationEfficiency = 35.0;
            attribute thickness = 0.5e-3 [SI::m];
        }
        
        part primaryElectrostaticLayer : ElectrostaticFilterLayer {
            attribute efficiency : FiltrationEfficiency = 95.0;
            attribute electrostaticCharge = 0.90;
            attribute particleCaptureSize = 0.3e-6 [SI::m];
            attribute thickness = 0.3e-3 [SI::m];
        }
        
        part innerMechanicalLayer : MechanicalFilterLayer {
            attribute efficiency : FiltrationEfficiency = 30.0;
            attribute thickness = 0.4e-3 [SI::m];
        }
        
        part noseSeal : FacialSealAssembly {
            attribute sealEffectiveness = 0.96;
            attribute noseClipAdjustment = 15.0e-3 [SI::m];
        }
        
        part cheekSeal : FacialSealAssembly {
            attribute sealEffectiveness = 0.94;
        }
        
        part chinSeal : FacialSealAssembly {
            attribute sealEffectiveness = 0.93;
        }
        
        part headbandStraps : RetentionStrapSystem {
            attribute tensionForce = 10.0 [SI::N];
            attribute adjustmentRange = 50.0e-3 [SI::m];
        }
        
        part exhalationValve : ExhalationValveAssembly {
            attribute openingThreshold = 20.0 [SI::Pa];
            attribute closingThreshold = 5.0 [SI::Pa];
        }
        
        connection airFlow1 connect airIntake to outerMechanicalLayer.inlet;
        connection airFlow2 connect outerMechanicalLayer.outlet to primaryElectrostaticLayer.inlet;
        connection airFlow3 connect primaryElectrostaticLayer.outlet to innerMechanicalLayer.inlet;
        connection airFlow4 connect innerMechanicalLayer.outlet to breathingInterface;
        
        perform action protectUser {
            first start;
            then merge breathingLoop;
            
            then action inhale : InhalationCycle {
                in ambientAir;
                in totalEfficiency = primaryElectrostaticLayer.efficiency;
                out breathableAir;
            }
            
            then action exhale : ExhalationCycle {
                in expiredAir;
                out exhaustAir;
            }
            
            then breathingLoop;
        }
        
        perform behavior respirationStateMachine : RespirationState;
    }
    
    requirement def MinimumFiltrationRequirement {
        doc /* The respirator shall filter at least 95% of airborne particles 
               with diameter of 0.3 micrometers or larger. */
        
        subject respirator : N95Respirator;
        
        require constraint {
            respirator.primaryElectrostaticLayer.efficiency.value >= 95.0
        }
        
        require constraint {
            respirator.targetParticleSize <= 0.3e-6 [SI::m]
        }
    }
    
    requirement def InhalationResistanceRequirement {
        doc /* The pressure drop during inhalation shall not exceed 343 Pascals 
               at a flow rate of 85 liters per minute. */
        
        subject respirator : N95Respirator;
        
        require constraint {
            respirator.maxInhalationResistance <= 343.0 [SI::Pa]
        }
    }
    
    requirement def ExhalationResistanceRequirement {
        doc /* The pressure drop during exhalation shall not exceed 245 Pascals 
               at a flow rate of 85 liters per minute. */
        
        subject respirator : N95Respirator;
        
        require constraint {
            respirator.maxExhalationResistance <= 245.0 [SI::Pa]
        }
    }
    
    requirement def FacialSealRequirement {
        doc /* The respirator shall maintain an effective seal against the face 
               to prevent unfiltered air leakage around the edges. */
        
        subject respirator : N95Respirator;
        
        require constraint {
            respirator.noseSeal.sealEffectiveness >= 0.95 and
            respirator.cheekSeal.sealEffectiveness >= 0.90 and
            respirator.chinSeal.sealEffectiveness >= 0.90
        }
    }
    
    requirement <'N95-SYS-001'> respiratoryProtectionRequirement {
        doc /* The N95 respirator system shall protect the wearer from inhaling 
               hazardous airborne particles by filtering contaminated ambient air 
               through multiple filtration layers while maintaining breathability 
               and a secure facial seal. */
        
        subject n95System : N95Respirator;
        
        assume constraint environmentalHazard {
            doc /* The ambient environment contains airborne particulate matter 
                   that poses a respiratory health risk to the wearer. */
        }
        
        require minFiltration : MinimumFiltrationRequirement;
        require inhalationComfort : InhalationResistanceRequirement;
        require exhalationComfort : ExhalationResistanceRequirement;
        require effectiveSeal : FacialSealRequirement;
    }
    
    part respiratorSystem : N95Respirator;
}
