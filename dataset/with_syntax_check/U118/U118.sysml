package StentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VesselDiameter :> ISQ::LengthValue {
        doc /* Internal diameter of blood vessel */
    }
    
    attribute def RadialForce :> ISQ::ForceValue {
        doc /* Outward radial force exerted by stent against vessel wall */
    }
    
    attribute def DeploymentPressure :> ISQ::PressureValue {
        doc /* Pressure applied to expand stent */
    }
    
    attribute def BloodFlowRate :> ISQ::VolumeFlowRateValue {
        doc /* Rate of blood flow through vessel */
    }
    
    attribute def StrutThickness :> ISQ::LengthValue {
        doc /* Thickness of stent strut material */
    }
    
    item def Blood {
        attribute flowRate : BloodFlowRate;
        attribute pressure : ISQ::PressureValue;
    }
    
    item def VesselWall {
        attribute diameter : VesselDiameter;
        attribute elasticity : Real;
    }
    
    attribute def DeployCommand;
    attribute def PositionConfirmed;
    attribute def ExpansionComplete;
    
    port def VesselInterface {
        out radialSupport : RadialForce;
        in vesselReaction : ISQ::PressureValue;
    }
    
    port def DeliveryInterface {
        in deploymentCommand : DeploymentPressure;
        out expansionStatus : Boolean;
    }
    
    port def FlowInterface {
        in bloodFlow : Blood;
        out patencyStatus : Boolean;
    }
    
    part def Stent {
        doc /* Tubular mesh device that provides mechanical support to maintain vessel patency */
        
        attribute collapsedDiameter : VesselDiameter;
        attribute expandedDiameter : VesselDiameter;
        attribute strutThickness : StrutThickness;
        attribute radialStrength : RadialForce;
        attribute material : String;
        
        port vesselContact : VesselInterface;
        port deliveryPort : DeliveryInterface;
    }
    
    part def Balloon {
        doc /* Inflatable component used to expand stent */
        
        attribute maxPressure : DeploymentPressure;
        attribute currentPressure : DeploymentPressure;
    }
    
    part def DeliveryCatheter {
        doc /* Catheter system for delivering and deploying stent */
        
        attribute outerDiameter : VesselDiameter;
        attribute workingLength : ISQ::LengthValue;
        
        part mountedBalloon : Balloon;
        part mountedStent : Stent;
        
        port catheterTip : DeliveryInterface;
    }
    
    part def BloodVessel {
        doc /* Arterial or venous vessel requiring treatment */
        
        attribute nativeDiameter : VesselDiameter;
        attribute lesionLength : ISQ::LengthValue;
        attribute occlusionSeverity : Real;
        
        part vesselWall : VesselWall;
        
        port lumen : FlowInterface;
        port wallInterface : VesselInterface;
    }
    
    action def NavigateToLesion {
        in targetSite : String;
        in vesselAccess : BloodVessel;
        out positioned : Boolean;
    }
    
    action def PositionStent {
        in lesionLocation : ISQ::LengthValue;
        out aligned : Boolean;
    }
    
    action def InflateBalloon {
        in targetPressure : DeploymentPressure;
        in rampRate : Real;
        out pressureAchieved : DeploymentPressure;
        out stentExpanded : Boolean;
    }
    
    action def ExpandStent {
        in deploymentPressure : DeploymentPressure;
        in targetDiameter : VesselDiameter;
        out achievedDiameter : VesselDiameter;
        out radialForceApplied : RadialForce;
    }
    
    action def DeflateBalloon {
        out deflated : Boolean;
    }
    
    action def WithdrawCatheter {
        out removed : Boolean;
    }
    
    action def MonitorPatency {
        in vesselDiameter : VesselDiameter;
        in bloodFlow : BloodFlowRate;
        out patencyMaintained : Boolean;
    }
    
    action def MaintainVesselPatency {
        doc /* Primary system function: restore and maintain open vessel lumen to ensure adequate blood flow */
        
        in treatedVessel : BloodVessel;
        in stentDevice : Stent;
        in deliverySystem : DeliveryCatheter;
        out vesselRestored : BloodVessel;
        out patencyAchieved : Boolean;
        
        first start;
        
        then action navigate : NavigateToLesion {
            in targetSite = "stenotic lesion";
            in vesselAccess = treatedVessel;
            out positioned;
        }
        
        then action position : PositionStent {
            in lesionLocation = treatedVessel.lesionLength;
            out aligned;
        }
        
        then accept posConfirmed : PositionConfirmed;
        
        then action inflate : InflateBalloon {
            in targetPressure : DeploymentPressure;
            in rampRate = 0.5;
            out pressureAchieved;
            out stentExpanded;
        }
        
        then action expand : ExpandStent {
            in deploymentPressure = inflate.pressureAchieved;
            in targetDiameter = treatedVessel.nativeDiameter;
            out achievedDiameter;
            out radialForceApplied;
        }
        
        then action deflate : DeflateBalloon {
            out deflated;
        }
        
        then action withdraw : WithdrawCatheter {
            out removed;
        }
        
        then merge continuousMonitoring;
        
        then action monitor : MonitorPatency {
            in vesselDiameter = expand.achievedDiameter;
            in bloodFlow : BloodFlowRate;
            out patencyMaintained;
        }
        
        then decide;
            if monitor.patencyMaintained then maintainSupport;
            if !monitor.patencyMaintained then requireIntervention;
        
        action maintainSupport {
            doc /* Stent continues providing radial support */
        }
        then continuousMonitoring;
        
        action requireIntervention {
            doc /* Additional treatment needed */
        }
        then done;
    }
    
    part stentSystem {
        doc /* Complete stent system for treating vascular stenosis */
        
        part implant : Stent {
            attribute :>> collapsedDiameter = 1.2 [mm];
            attribute :>> expandedDiameter = 3.5 [mm];
            attribute :>> strutThickness = 0.08 [mm];
            attribute :>> radialStrength = 0.6 [N];
            attribute :>> material = "Cobalt-Chromium Alloy";
        }
        
        part delivery : DeliveryCatheter {
            attribute :>> outerDiameter = 1.8 [mm];
            attribute :>> workingLength = 1400 [mm];
            
            part :>> mountedBalloon {
                attribute :>> maxPressure = 1800 [kPa];
            }
        }
        
        part targetVessel : BloodVessel {
            attribute :>> nativeDiameter = 3.0 [mm];
            attribute :>> lesionLength = 18 [mm];
            attribute :>> occlusionSeverity = 0.70;
            
            part :>> vesselWall {
                attribute :>> diameter = 3.0 [mm];
                attribute :>> elasticity = 0.85;
            }
        }
        
        connection stentDeployment
            connect delivery.catheterTip.deploymentCommand
            to implant.deliveryPort.deploymentCommand;
        
        connection vesselSupport
            connect implant.vesselContact.radialSupport
            to targetVessel.wallInterface.radialSupport;
        
        perform action treatStenosis : MaintainVesselPatency {
            in treatedVessel = targetVessel;
            in stentDevice = implant;
            in deliverySystem = delivery;
            out vesselRestored;
            out patencyAchieved;
        }
    }
    
    requirement <'STENT-REQ-001'> primaryFunctionRequirement {
        doc /* The stent system shall restore and maintain vessel patency by providing continuous radial support to the vessel wall */
        
        subject stentSystem;
        
        require constraint radialSupportConstraint {
            stentSystem.implant.radialStrength >= 0.5 [N]
        }
        
        require constraint diameterMatchConstraint {
            stentSystem.implant.expandedDiameter >= stentSystem.targetVessel.nativeDiameter
        }
    }
    
    requirement <'STENT-REQ-002'> bloodFlowRestorationRequirement {
        doc /* The stent system shall restore adequate blood flow through the treated vessel segment */
        
        subject stentSystem;
        
        assume constraint vesselOccluded {
            stentSystem.targetVessel.occlusionSeverity >= 0.50
        }
        
        require constraint flowRestored {
            stentSystem.treatStenosis.patencyAchieved
        }
    }
    
    requirement <'STENT-REQ-003'> deploymentAccuracyRequirement {
        doc /* The stent shall be accurately positioned and expanded to the target diameter */
        
        subject stentSystem.implant;
    }
    
    requirement <'STENT-REQ-004'> biocompatibilityRequirement {
        doc /* The stent shall be biocompatible for long-term vascular implantation */
        
        subject stentSystem.implant;
    }
    
    requirement <'STENT-REQ-005'> mechanicalDurabilityRequirement {
        doc /* The stent shall maintain structural integrity and radial support over the implant lifetime */
        
        subject stentSystem.implant;
        
        require constraint radialStrengthMaintenance {
            stentSystem.implant.radialStrength >= 0.5 [N]
        }
    }
}
