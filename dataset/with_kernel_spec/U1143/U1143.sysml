package 'Nanocarrier Cancer Therapy System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def pHValue :> Real;
    attribute def DrugMass :> ISQ::MassValue;

    item def ChemotherapyDrug;

    attribute def MarkerDetected;
    attribute def ReleaseTriggered;

    part def PolymerCore {
        attribute capacity : DrugMass;
        item payload : ChemotherapyDrug;
    }

    part def LipidBilayerShell {
        attribute thickness : ISQ::LengthValue;
        attribute integrity : Boolean = true;
    }

    part def TargetingAntibody {
        attribute targetMarker : String;
        attribute bindingAffinity : Real;
    }

    part def pHResponsiveGate {
        attribute triggerThreshold : pHValue = 6.5;
        attribute isOpen : Boolean = false;
    }

    port def EnvironmentSensingPort {
        in environmentpH : pHValue;
        in cancerMarkerDetected : Boolean;
    }

    port def DrugReleasePort {
        out releasedDrug : ChemotherapyDrug;
    }

    state def Mission {
        state Circulation;
        state Targeting;
        state Binding;
        state Release;
        state Depletion;

        transition t1 first Circulation then Targeting accept marker : MarkerDetected;
        transition t2 first Targeting then Binding;
        transition t3 first Binding then Release accept trigger : ReleaseTriggered;
        transition t4 first Release then Depletion;
    }

    part def SmartNanocarrier {
        attribute id : String;
        part core : PolymerCore;
        part shell : LipidBilayerShell;
        part antibodies : TargetingAntibody[1..*];
        part gate : pHResponsiveGate;

        port environmentSensing : EnvironmentSensingPort;
        port drugRelease : DrugReleasePort;

        state mission : Mission;
    }

    part def CancerCell {
        attribute surfaceMarker : String;
        attribute localpH : pHValue = 6.2;
    }

    part def HealthyTissue {
        attribute localpH : pHValue = 7.4;
    }

    part def Bloodstream {
        attribute flowRate : ISQ::SpeedValue;
        attribute pH : pHValue = 7.4;
    }

    part def Patient {
        part bloodstream : Bloodstream;
        part tumor : CancerCell[1..*];
        part healthyTissue : HealthyTissue;
    }

    part def TherapySystem {
        part patient : Patient;
        part swarm : SmartNanocarrier[1000..*];
    }

    part therapySystem : TherapySystem {}

    action def DetectCancer {
        in marker : String;
        out detected : Boolean;
    }

    action def NavigateToTarget {
        in detected : Boolean;
        out arrived : Boolean;
    }

    action def BindToCell {
        in arrived : Boolean;
        out bound : Boolean;
    }

    action def CheckEnvironment {
        in bound : Boolean;
        in localpH : pHValue;
        in threshold : pHValue;
        out releaseTriggered : Boolean;
    }

    action def DeliverDrug {
        in releaseTriggered : Boolean;
        in drug : ChemotherapyDrug;
        out delivered : Boolean;
    }

    action def ExecuteMission {
        in target : CancerCell;
        in carrier : SmartNanocarrier;
        out missionComplete : Boolean;

        action detect : DetectCancer {
            in marker = target.surfaceMarker;
        }
        action navigate : NavigateToTarget;
        action bind : BindToCell;
        action checkpH : CheckEnvironment {
            in localpH = target.localpH;
            in threshold = carrier.gate.triggerThreshold;
        }
        action deliver : DeliverDrug {
            in drug = carrier.core.payload;
        }

        flow detect.detected to navigate.detected;
        flow navigate.arrived to bind.arrived;
        flow bind.bound to checkpH.bound;
        flow checkpH.releaseTriggered to deliver.releaseTriggered;

        first start;
        then detect;
        then navigate;
        then bind;
        then checkpH;
        then deliver;
        then assign missionComplete := deliver.delivered;
    }

    requirement def TargetedDrugDelivery {
        doc "The system shall deliver chemotherapy drugs specifically to cancer cells while minimizing exposure to healthy tissue.";
    }
    requirement def CancerCellBindingReq {
        doc "Nanocarriers shall bind to cancer cells using targeting antibodies.";
    }
    requirement def pHTriggeredReleaseReq {
        doc "Drug release shall be triggered only when the local pH is below 6.5.";
    }
    requirement def DrugProtectionReq {
        doc "The lipid bilayer shell shall protect the drug payload during circulation.";
    }

    #derivation connection def ReqDerivation {
        end #original r1 : TargetedDrugDelivery;
        end #derive r1_1 : CancerCellBindingReq;
        end #derive r1_2 : pHTriggeredReleaseReq;
        end #derive r1_3 : DrugProtectionReq;
    }

    part satisfactionContext {
        ref :>> therapySystem;
        satisfy requirement req1 : TargetedDrugDelivery by therapySystem;
        satisfy requirement req1_1 : CancerCellBindingReq by therapySystem;
        satisfy requirement req1_2 : pHTriggeredReleaseReq by therapySystem;
        satisfy requirement req1_3 : DrugProtectionReq by therapySystem;
        #derivation connection : ReqDerivation {
            end r1 ::> req1;
            end r1_1 ::> req1_1;
            end r1_2 ::> req1_2;
            end r1_3 ::> req1_3;
        }
    }
}
