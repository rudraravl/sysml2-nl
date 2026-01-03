package EndobronchialValveSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    
    attribute def AirPressure :> PressureValue {
        attribute magnitude : Real;
    }
    
    attribute def AirFlowRate :> FlowRateValue {
        attribute magnitude : Real;
    }
    
    attribute def LungVolume :> VolumeValue {
        attribute magnitude : Real;
    }
    
    enum def ValveState {
        open;
        closed;
    }
    
    enum def RespiratoryPhase {
        inhalation;
        exhalation;
    }
    
    item def Air {
        attribute pressure : AirPressure;
        attribute flowRate : AirFlowRate;
    }
    
    port def AirwayPort {
        in airIn : Air;
        out airOut : Air;
    }
    
    port def LungSegmentPort {
        in airSupply : Air;
        out airExpelled : Air;
        attribute segmentPressure : AirPressure;
    }
    
    part def EndobronchialValve {
        doc /* 
            One-way valve device implanted in diseased lung airways to allow air 
            and secretions to escape during exhalation while preventing air entry 
            during inhalation, thereby reducing hyperinflation in emphysema patients.
        */
        
        attribute valveState : ValveState;
        attribute openingPressureThreshold : AirPressure;
        attribute closingPressureThreshold : AirPressure;
        
        port proximalPort : AirwayPort;
        port distalPort : LungSegmentPort;
        
        part valveBody {
            doc /* Biocompatible housing structure for valve mechanism */
        }
        
        part valveMembrane {
            doc /* Flexible membrane that opens and closes based on pressure differential */
            attribute membraneFlexibility : Real;
        }
        
        part anchoringMechanism {
            doc /* Self-expanding structure for secure placement in bronchus */
            attribute expansionForce : Real;
        }
    }
    
    part def DiseasedLungSegment {
        doc /* Hyperinflated lung segment targeted for volume reduction treatment */
        
        attribute currentVolume : LungVolume;
        attribute residualVolume : LungVolume;
        attribute trappedAirVolume : LungVolume;
        attribute segmentCompliance : Real;
        
        port segmentPort : LungSegmentPort;
    }
    
    part def BronchialAirway {
        doc /* Bronchial passage connecting to diseased lung segment */
        
        attribute airwayDiameter : ISQ::LengthValue;
        attribute airwayPressure : AirPressure;
        
        port airwayInlet : AirwayPort;
        port airwayOutlet : AirwayPort;
    }
    
    action def DetectRespiratoryPhase {
        in proximalPressure : AirPressure;
        in distalPressure : AirPressure;
        out phase : RespiratoryPhase;
    }
    
    action def AllowExhalation {
        in exhalationPressure : AirPressure;
        in trappedVolume : LungVolume;
        out expelledAir : Air;
        out volumeReduction : LungVolume;
    }
    
    action def BlockInhalation {
        in inhalationPressure : AirPressure;
        out blockedFlow : AirFlowRate;
    }
    
    action def ReduceLungHyperinflation {
        doc /* 
            Primary therapeutic function: progressively reduce trapped air volume 
            in diseased lung segment through controlled one-way airflow regulation.
        */
        
        in initialVolume : LungVolume;
        in targetVolumeReduction : LungVolume;
        out finalVolume : LungVolume;
        out achievedReduction : LungVolume;
        
        private attribute currentVolume : LungVolume := initialVolume;
        private attribute targetVolume : LungVolume;
        
        first start;
        then merge continuousMonitoring;
        
        then action detectPhase : DetectRespiratoryPhase {
            in proximalPressure : AirPressure;
            in distalPressure : AirPressure;
            out phase : RespiratoryPhase;
        }
        
        then decide;
            if detectPhase.phase == RespiratoryPhase::exhalation then allowExhalation;
            if detectPhase.phase == RespiratoryPhase::inhalation then blockInhalation;
        
        action allowExhalation : AllowExhalation {
            in exhalationPressure : AirPressure;
            in trappedVolume = currentVolume;
            out expelledAir : Air;
            out volumeReduction : LungVolume;
        }
        then continuousMonitoring;
        
        action blockInhalation : BlockInhalation {
            in inhalationPressure : AirPressure;
            out blockedFlow : AirFlowRate;
        }
        then continuousMonitoring;
    }
    
    part endobronchialValveSystem {
        doc /* 
            Complete therapeutic system for treating severe emphysema through 
            bronchoscopic lung volume reduction by controlling airflow to 
            diseased lung segments via one-way valve mechanism.
        */
        
        part valve : EndobronchialValve {
            attribute :>> openingPressureThreshold : AirPressure;
            attribute :>> closingPressureThreshold : AirPressure;
        }
        
        part targetSegment : DiseasedLungSegment {
            attribute :>> currentVolume : LungVolume;
            attribute :>> residualVolume : LungVolume;
            attribute :>> trappedAirVolume : LungVolume;
        }
        
        part bronchus : BronchialAirway {
            attribute :>> airwayDiameter : ISQ::LengthValue;
            attribute :>> airwayPressure : AirPressure;
        }
        
        connect bronchus.airwayOutlet to valve.proximalPort;
        connect valve.distalPort to targetSegment.segmentPort;
        
        perform action therapeuticFunction : ReduceLungHyperinflation {
            in initialVolume = targetSegment.currentVolume;
            in targetVolumeReduction : LungVolume;
            out finalVolume : LungVolume;
            out achievedReduction : LungVolume;
        }
    }
    
    requirement def TherapeuticEffectiveness {
        doc /* Valve must achieve clinically significant lung volume reduction */
        
        subject system : endobronchialValveSystem;
        
        require constraint volumeReductionTarget {
            doc /* Minimum 350mL reduction in residual volume per treated lobe */
        }
        
        require constraint airflowControl {
            doc /* Complete blockage during inhalation, free flow during exhalation */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Device must maintain biocompatibility and structural integrity */
        
        subject valve : EndobronchialValve;
        
        require constraint biocompatibility {
            doc /* Materials must meet ISO 10993 biocompatibility standards */
        }
        
        require constraint anchoringStability {
            doc /* Valve must remain securely positioned without migration */
        }
    }
    
    requirement def FunctionalRequirement {
        doc /* Valve must operate reliably across respiratory cycles */
        
        subject valve : EndobronchialValve;
        
        require constraint pressureResponse {
            doc /* Valve opens at appropriate exhalation pressure differential */
        }
        
        require constraint closureIntegrity {
            doc /* Complete seal during inhalation phase */
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for endobronchial valve system */
        
        require therapeuticReq : TherapeuticEffectiveness;
        require safetyReq : SafetyRequirement;
        require functionalReq : FunctionalRequirement;
    }
}
