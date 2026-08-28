package 'Endobronchial Valve System' {
    private import ScalarValues::*;
    
    item def Air;
    item def Secretion;
    
    port def AirflowPort {
        in item air : Air;
        in item secretion : Secretion;
        out item escapedAir : Air;
        out item escapedSecretion : Secretion;
        attribute pressure : Real;
    }
    
    part def ValveBody {
        attribute material : String = "Biocompatible Polymer";
    }
    
    part def ValveMembrane {
        attribute flexibility : Real;
        attribute isOpen : Boolean;
    }
    
    part def AnchoringMechanism {
        attribute expansionForce : Real;
        attribute isDeployed : Boolean;
    }
    
    action def ReleaseAirAndSecretions {
        in item trappedAir : Air;
        in item trappedSecretion : Secretion;
        out item escapedAir : Air;
        out item escapedSecretion : Secretion;
    }
    
    action def SealValve {
        out isOpen : Boolean = false;
    }
    
    action def OpenValve {
        out isOpen : Boolean = true;
    }
    
    part def EndobronchialValve {
        port airwayPort : AirflowPort;
        
        part body : ValveBody;
        part membrane : ValveMembrane;
        part anchor : AnchoringMechanism;
        
        attribute isSealed : Boolean;
        
        state def ValveOperation {
            state Closed {
                entry action seal : SealValve;
            }
            state Open {
                entry action open : OpenValve;
                do action release : ReleaseAirAndSecretions;
            }
            transition from Closed to Open when airwayPort.pressure > 0;
            transition from Open to Closed when airwayPort.pressure <= 0;
        }
        
        perform valveOperation : ValveOperation;
    }
    
    part def LungSegment {
        attribute volume : Real;
        attribute initialVolume : Real;
        attribute pressure : Real;
        attribute isDiseased : Boolean = true;
        port airwayPort : ~AirflowPort;
    }
    
    part def MainAirway {
        port airwayPort : ~AirflowPort;
    }
    
    action def Exhale {
        out pressure : Real = 10.0;
    }
    
    action def Inhale {
        out pressure : Real = -5.0;
    }
    
    action def Breathe {
        loop action breathing {
            action exhale : Exhale;
            then action inhale : Inhale;
        }
    }
    
    part def Patient {
        part mainAirway : MainAirway;
        part diseasedLungSegment : LungSegment;
        part healthyLungSegment : LungSegment {
            attribute isDiseased = false;
        }
        
        perform breathe : Breathe;
    }
    
    requirement def TherapeuticGoal {
        doc /* The device shall reduce the volume of the targeted lung segment by at least 30% within 6 months. */
        attribute targetVolume : Real;
        subject patient : Patient;
    }
    
    requirement def Biocompatibility {
        doc /* All materials shall be biocompatible per ISO 10993. */
        subject device : EndobronchialValve;
    }
    
    requirement def StructuralStability {
        doc /* The valve shall withstand airway pressure differentials up to 40 cmH2O without migration or structural failure. */
        attribute maxPressureDifferential : Real = 40.0;
        subject device : EndobronchialValve;
    }
    
    part context {
        part patient : Patient;
        part valve : EndobronchialValve;
        
        flow of air : Air
            from patient.diseasedLungSegment.airwayPort.air to valve.airwayPort.air;
        
        flow of secretion : Secretion
            from patient.diseasedLungSegment.airwayPort.secretion to valve.airwayPort.secretion;
        
        flow of escapedAir : Air
            from valve.airwayPort.escapedAir to patient.mainAirway.airwayPort.escapedAir;
        
        flow of escapedSecretion : Secretion
            from valve.airwayPort.escapedSecretion to patient.mainAirway.airwayPort.escapedSecretion;
        
        requirement therapeuticGoal : TherapeuticGoal {
            targetVolume = 500.0;
        }
        requirement biocompatibilityReq : Biocompatibility;
        requirement structuralStabilityReq : StructuralStability;
    }
}
