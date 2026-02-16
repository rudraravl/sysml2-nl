package CoronaryStentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StentDiameter :> LengthValue {
        doc /* Diameter of the stent in millimeters */
    }
    
    attribute def StentLength :> LengthValue {
        doc /* Axial length of the stent in millimeters */
    }
    
    attribute def RadialForce :> ForceValue {
        doc /* Radial force exerted by stent against vessel wall */
    }
    
    attribute def VesselDiameter :> LengthValue {
        doc /* Diameter of the coronary artery */
    }
    
    attribute def StenosisPercentage :> Real {
        doc /* Percentage of vessel lumen blockage */
    }
    
    attribute def BloodFlowRate :> VolumeFlowRateValue {
        doc /* Rate of blood flow through vessel */
    }
    
    attribute def InflationPressure :> PressureValue {
        doc /* Pressure applied to expand balloon and stent */
    }
    
    item def CoronaryArtery {
        attribute nativeDiameter : VesselDiameter;
        attribute stenosisLevel : StenosisPercentage;
        attribute currentFlowRate : BloodFlowRate;
        
        port vesselLumen {
            attribute effectiveDiameter : LengthValue;
        }
    }
    
    item def StentStrut {
        attribute thickness : LengthValue;
        attribute width : LengthValue;
        attribute material : String;
    }
    
    item def DrugCoating {
        attribute drugName : String;
        attribute coatingThickness : LengthValue;
        attribute releaseRate : Real;
        attribute releaseDuration : TimeValue;
    }
    
    part def CoronaryStent {
        doc /* 
            A coronary stent is a tubular mesh scaffold implanted in coronary arteries
            to restore and maintain vessel patency after angioplasty
        */
        
        attribute expandedDiameter : StentDiameter;
        attribute collapsedDiameter : StentDiameter;
        attribute length : StentLength;
        attribute radialStrength : RadialForce;
        attribute currentDiameter : StentDiameter;
        
        part struts : StentStrut[*] {
            doc /* Metallic struts forming the stent framework */
        }
        
        part coating : DrugCoating {
            doc /* Anti-proliferative drug coating to prevent restenosis */
        }
        
        port innerSurface {
            attribute contactArea : AreaValue;
        }
        
        port outerSurface {
            attribute contactArea : AreaValue;
        }
    }
    
    part def BalloonCatheter {
        doc /* Delivery system for stent deployment */
        
        attribute balloonDiameter : LengthValue;
        attribute inflationPressure : InflationPressure;
        attribute workingLength : LengthValue;
        
        port balloonSurface {
            out pressure : PressureValue;
        }
        
        port guidewireChannel;
    }
    
    part def StentDeliverySystem {
        doc /* Complete system for delivering and deploying the coronary stent */
        
        part stent : CoronaryStent {
            attribute expandedDiameter = 3.0 [SI::mm];
            attribute collapsedDiameter = 1.2 [SI::mm];
            attribute length = 18.0 [SI::mm];
            attribute radialStrength = 0.6 [SI::N];
        }
        
        part catheter : BalloonCatheter {
            attribute balloonDiameter = 3.0 [SI::mm];
            attribute workingLength = 1400.0 [SI::mm];
        }
        
        connect stent.innerSurface to catheter.balloonSurface;
    }
    
    action def NavigateToLesion {
        in targetLocation : LengthValue;
        out positioned : Boolean;
    }
    
    action def InflateBalloon {
        in targetPressure : PressureValue;
        in targetDiameter : LengthValue;
        out achievedPressure : PressureValue;
        out achievedDiameter : LengthValue;
    }
    
    action def ExpandStent {
        in balloonPressure : PressureValue;
        in vesselDiameter : LengthValue;
        out stentDiameter : LengthValue;
        out radialForce : RadialForce;
    }
    
    action def DeflateBalloon {
        out finalPressure : PressureValue;
    }
    
    action def RemoveCatheter {
        out catheterRemoved : Boolean;
    }
    
    action def ReleaseDrug {
        in releaseRate : Real;
        in elapsedTime : TimeValue;
        out drugConcentration : Real;
    }
    
    action def VerifyPatency {
        in stentDiameter : LengthValue;
        in vesselDiameter : LengthValue;
        out patencyRestored : Boolean;
    }
    
    action def DeployStent {
        doc /* 
            Primary action sequence for deploying a coronary stent
            to restore blood flow in a stenotic coronary artery
        */
        
        in vesselDiameter : VesselDiameter;
        in stenosisLevel : StenosisPercentage;
        in targetPressure : InflationPressure;
        out finalStentDiameter : StentDiameter;
        out deploymentSuccess : Boolean;
        
        first start;
        
        then action navigate : NavigateToLesion {
            in targetLocation = 0.0 [SI::mm];
            out positioned;
        }
        
        then decide;
            if navigate.positioned then inflate;
            if not navigate.positioned then done;
        
        action inflate : InflateBalloon {
            in targetPressure = DeployStent::targetPressure;
            in targetDiameter = vesselDiameter;
            out achievedPressure;
            out achievedDiameter;
        }
        
        then action expand : ExpandStent {
            in balloonPressure = inflate.achievedPressure;
            in vesselDiameter = vesselDiameter;
            out stentDiameter;
            out radialForce;
        }
        
        then action verify : VerifyPatency {
            in stentDiameter = expand.stentDiameter;
            in vesselDiameter = vesselDiameter;
            out patencyRestored;
        }
        
        then action deflate : DeflateBalloon {
            out finalPressure;
        }
        
        then action remove : RemoveCatheter {
            out catheterRemoved;
        }
        
        then assign finalStentDiameter := expand.stentDiameter;
        then assign deploymentSuccess := verify.patencyRestored;
        
        then done;
    }
    
    state def StentLifecycle {
        doc /* State machine representing stent lifecycle phases */
        
        entry; then collapsed;
        
        state collapsed {
            doc /* Stent in collapsed state on delivery catheter */
        }
        
        transition collapsed_to_deploying
            first collapsed
            then deploying;
        
        state deploying {
            doc /* Stent being expanded by balloon inflation */
            do action : ExpandStent;
        }
        
        transition deploying_to_deployed
            first deploying
            then deployed;
        
        state deployed {
            doc /* Stent fully expanded and maintaining vessel patency */
            
            state drugEluting {
                doc /* Active drug release phase */
                do action : ReleaseDrug;
            }
            
            state maintaining {
                doc /* Long-term vessel support phase */
            }
            
            transition drugEluting_to_maintaining
                first drugEluting
                then maintaining;
        }
    }
    
    requirement def <'REQ-001'> MaintainVesselPatency {
        doc /* 
            The stent shall maintain coronary artery patency by providing
            continuous radial support to prevent vessel collapse
        */
        
        subject stent : CoronaryStent;
        
        require constraint {
            stent.radialStrength >= 0.5 [SI::N]
        }
    }
    
    requirement def <'REQ-002'> RestoreBloodFlow {
        doc /* 
            The stent shall restore adequate blood flow by expanding
            the vessel lumen to at least 90% of reference diameter
        */
        
        subject vessel : CoronaryArtery;
        
        require constraint {
            vessel.vesselLumen.effectiveDiameter >= vessel.nativeDiameter * 0.90
        }
    }
    
    requirement def <'REQ-003'> PreventRestenosis {
        doc /* 
            The drug-eluting coating shall prevent restenosis by inhibiting
            neointimal hyperplasia for at least 180 days
        */
        
        subject coating : DrugCoating;
        
        require constraint {
            coating.releaseDuration >= 180.0 [SI::day]
        }
    }
    
    requirement def <'REQ-004'> BiocompatibleMaterial {
        doc /* 
            The stent material shall be biocompatible to minimize
            thrombosis and inflammatory response
        */
        
        subject stent : CoronaryStent;
        
        require constraint {
            stent.struts.material == "Cobalt-Chromium" or
            stent.struts.material == "Platinum-Chromium" or
            stent.struts.material == "Stainless Steel 316L"
        }
    }
    
    requirement <'SYS-001'> coronaryStentSystemRequirement {
        doc /* 
            The coronary stent system shall restore and maintain blood flow
            in stenotic coronary arteries through mechanical support and
            pharmacological intervention to treat coronary artery disease
        */
        
        subject stentSystem : StentDeliverySystem;
        
        require <'REQ-001'> MaintainVesselPatency;
        require <'REQ-002'> RestoreBloodFlow;
        require <'REQ-003'> PreventRestenosis;
        require <'REQ-004'> BiocompatibleMaterial;
    }
    
    part coronaryStentSystem : StentDeliverySystem {
        doc /* 
            Complete coronary stent system instance for treating
            atherosclerotic coronary artery disease by restoring vessel patency
        */
        
        perform action deployment : DeployStent {
            in vesselDiameter = 3.0 [SI::mm];
            in stenosisLevel = 75.0;
            in targetPressure = 12.0 [SI::bar];
            out finalStentDiameter;
            out deploymentSuccess;
        }
        
        exhibit state lifecycle : StentLifecycle;
        
        satisfy coronaryStentSystemRequirement;
    }
    
    part targetArtery : CoronaryArtery {
        attribute nativeDiameter = 3.0 [SI::mm];
        attribute stenosisLevel = 75.0;
        attribute currentFlowRate = 50.0 [SI::mL/SI::min];
    }
    
    connect coronaryStentSystem.stent.outerSurface to targetArtery.vesselLumen;
}
