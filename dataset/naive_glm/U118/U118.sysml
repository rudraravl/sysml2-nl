package MedicalStentSystem {

    import ScalarValues::*;

    // ===== Dimensions =====
    dimension LengthDim;
    dimension PressureDim;
    dimension ForceDim;
    dimension VolumeDim;
    dimension TimeDim;
    dimension FlowRateDim;

    // ===== Units =====
    unit mm : LengthDim;
    unit Pa : PressureDim;
    unit N : ForceDim;
    unit mL : VolumeDim;
    unit sec : TimeDim;
    unit mL_per_sec : FlowRateDim;

    // ===== Value Types =====
    value type DiameterValue :> Real {
        unit mm;
    }
    value type LengthValue :> Real {
        unit mm;
    }
    value type PressureValue :> Real {
        unit Pa;
    }
    value type ForceValue :> Real {
        unit N;
    }
    value type VolumeValue :> Real {
        unit mL;
    }
    value type FlowRateValue :> Real {
        unit mL_per_sec;
    }
    value type PercentageValue :> Real {
        unit 1;
    }

    // ===== Item Definitions =====
    item def Blood {
        doc "Physiological blood flowing through the vascular system";
        attribute viscosity : Real = 0.004;
        attribute hematocrit : Real = 0.42;
        attribute oxygenSaturation : Real = 0.97;
    }

    item def Plaque {
        doc "Atherosclerotic plaque causing vessel stenosis";
        attribute composition : String = "Fibrocalcific";
        attribute degreeOfStenosis : PercentageValue;
        attribute calciumContent : Real;
    }

    item def InflationFluid {
        doc "Fluid mixture used to inflate the balloon during deployment";
        attribute fluidType : String = "Saline contrast mixture";
        attribute contrastRatio : Real = 0.5;
        attribute volume : VolumeValue;
    }

    item def ContrastMedia {
        doc "Radiopaque contrast media for fluoroscopic visualization";
        attribute iodineConcentration : Real = 350;
        attribute volume : VolumeValue;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        doc "Port for fluid pressure application and inflation fluid flow";
        attribute pressure : PressureValue;
        in item inflationFluid : InflationFluid [0..*];
    }

    port def MechanicalContactPort {
        doc "Port for mechanical contact and force transmission";
        attribute contactForce : ForceValue;
        attribute contactDiameter : DiameterValue;
    }

    port def VascularPort {
        doc "Port for blood flow through a vessel segment";
        in item inflow : Blood [0..*];
        out item outflow : Blood [0..*];
        attribute flowRate : FlowRateValue;
        attribute vesselDiameter : DiameterValue;
    }

    // ===== Interface Definitions =====
    interface def FluidInterface {
        doc "Fluid connection between two fluid ports";
        end supplier : FluidPort;
        end consumer : FluidPort;
    }

    interface def MechanicalInterface {
        doc "Mechanical contact interface between two surfaces";
        end supplier : MechanicalContactPort;
        end consumer : MechanicalContactPort;
    }

    // ===== Requirement Definitions =====
    requirement def StentSystemRequirement {
        doc "The medical stent system shall reopen a stenosed blood vessel and restore adequate blood flow.";

        subject system : StentSystem;

        requirement reopenVessel {
            doc "The system shall reopen the stenosed vessel to the healthy vessel diameter.";
        }

        requirement restoreBloodFlow {
            doc "The system shall restore adequate blood flow through the treated vessel segment.";
        }

        requirement permanentImplant {
            doc "The stent shall remain permanently implanted providing a continuous scaffold.";
        }

        requirement disposableDelivery {
            doc "The delivery catheter shall be a single-use disposable device.";
        }

        requirement biocompatibility {
            doc "All implant materials shall be biocompatible.";
        }
    }

    requirement def StentImplantRequirement {
        doc "The stent shall expand from a collapsed state and maintain vessel patency.";

        subject stent : Stent;

        attribute collapsedDiameter : DiameterValue = 1.0;
        attribute expandedDiameter : DiameterValue = 3.5;
        attribute minRadialForce : ForceValue = 0.15;
        attribute biocompatible : Boolean = true;
        attribute material : String = "Cobalt-Chromium Alloy";

        requirement expandable {
            doc "Stent shall be expandable from a collapsed crimped state to a fully deployed state.";
        }

        requirement radialScaffold {
            doc "Stent shall exert continuous outward radial force after deployment.";
        }

        requirement biocompatibleMaterial {
            doc "Stent shall be made from a biocompatible Cobalt-Chromium alloy.";
        }

        requirement radialFlexibility {
            doc "Stent shall be flexible enough to conform to vessel curvature.";
        }

        requirement foreshorteningLimit {
            doc "Stent foreshortening during expansion shall not exceed 8 percent.";
        }
    }

    requirement def DeliveryCatheterRequirement {
        doc "The delivery catheter shall navigate the vasculature and deploy the stent.";

        subject catheter : DeliveryCatheter;

        attribute workingLength : LengthValue = 1500;
        attribute maxOuterDiameter : DiameterValue = 2.0;
        attribute flexibility : Real = 0.8;
        attribute trackability : Real = 0.9;

        requirement navigate {
            doc "Catheter shall navigate through the vascular system to the lesion site.";
        }

        requirement deploy {
            doc "Catheter shall deploy the stent via balloon inflation at the target site.";
        }

        requirement withdraw {
            doc "Catheter shall be withdrawable from the body after stent deployment.";
        }

        requirement singleUse {
            doc "Catheter shall be designed for single patient use only.";
        }

        requirement radiopaqueMarkers {
            doc "Catheter shall have radiopaque markers for fluoroscopic positioning.";
        }
    }

    requirement def BalloonRequirement {
        doc "The balloon shall inflate and deflate to deploy and release the stent.";

        subject balloon : Balloon;

        attribute nominalPressure : PressureValue = 800000;
        attribute burstPressure : PressureValue = 1400000;
        attribute nominalDiameter : DiameterValue = 3.5;
        attribute deflatedDiameter : DiameterValue = 1.5;

        requirement inflateToNominal {
            doc "Balloon shall inflate to the nominal pressure to fully expand the stent.";
        }

        requirement deflateForRemoval {
            doc "Balloon shall deflate to permit catheter withdrawal.";
        }

        requirement withstandBurstPressure {
            doc "Balloon shall not rupture below the rated burst pressure.";
        }

        requirement compliantExpansion {
            doc "Balloon shall expand uniformly along its working length.";
        }
    }

    // ===== Action Definitions =====
    action def NavigateToLesion {
        doc "Navigate the delivery catheter through the patient vasculature to the lesion site";
        in catheter : DeliveryCatheter;
        in lesion : Lesion;
        out positioned : Boolean;
    }

    action def InflateBalloonAction {
        doc "Inflate the balloon to expand the stent against the vessel wall";
        in balloon : Balloon;
        in targetPressure : PressureValue;
        out stentExpanded : Boolean;
        out appliedPressure : PressureValue;
    }

    action def DeflateBalloonAction {
        doc "Deflate the balloon after stent deployment";
        in balloon : Balloon;
        out deflated : Boolean;
    }

    action def WithdrawCatheterAction {
        doc "Withdraw the delivery catheter from the patient body";
        in catheter : DeliveryCatheter;
        out withdrawn : Boolean;
    }

    action def StentDeploymentProcedure {
        doc "Complete stent deployment procedure action sequence";

        action navigate : NavigateToLesion;
        action inflate : InflateBalloonAction;
        action deflate : DeflateBalloonAction;
        action withdraw : WithdrawCatheterAction;

        succession navigate then inflate;
        succession inflate then deflate;
        succession deflate then withdraw;
    }

    // ===== State Definitions =====
    state def StentStateMachine {
        doc "Stent lifecycle states from manufacturing to permanent deployment";

        state Collapsed {
            doc "Initial collapsed state at manufacturing diameter";
            attribute currentDiameter : DiameterValue = 1.0;
        }

        state Crimped {
            doc "Stent crimped onto balloon catheter";
            attribute currentDiameter : DiameterValue = 1.0;
        }

        state Expanding {
            doc "Stent being expanded by balloon inflation";
            attribute currentDiameter : DiameterValue;
        }

        state Deployed {
            doc "Stent fully deployed in vessel providing scaffold";
            attribute currentDiameter : DiameterValue = 3.5;
        }

        transition from Collapsed to Crimped;
        transition from Crimped to Expanding;
        transition from Expanding to Deployed;
    }

    state def BalloonStateMachine {
        doc "Balloon inflation and deflation cycle states";

        state Deflated {
            doc "Balloon in deflated state for navigation";
            attribute currentDiameter : DiameterValue = 1.5;
            attribute currentPressure : PressureValue = 0;
        }

        state Inflating {
            doc "Balloon being inflated with fluid";
            attribute currentPressure : PressureValue;
        }

        state Inflated {
            doc "Balloon at nominal inflation pressure";
            attribute currentPressure : PressureValue = 800000;
            attribute currentDiameter : DiameterValue = 3.5;
        }

        state Deflating {
            doc "Balloon being deflated for catheter withdrawal";
            attribute currentPressure : PressureValue;
        }

        transition from Deflated to Inflating;
        transition from Inflating to Inflated;
        transition from Inflated to Deflating;
        transition from Deflating to Deflated;
    }

    state def ProcedureStateMachine {
        doc "Overall stent placement procedure states from insertion to completion";

        state CatheterInsertion {
            doc "Delivery catheter inserted into patient vasculature";
        }

        state VascularNavigation {
            doc "Catheter advanced through vascular system toward lesion";
        }

        state LesionPositioning {
            doc "Stent positioned across the lesion site using fluoroscopy";
        }

        state BalloonInflation {
            doc "Balloon inflated to expand stent against vessel wall";
        }

        state StentDeployment {
            doc "Stent fully deployed providing radial scaffold";
        }

        state BalloonDeflation {
            doc "Balloon deflated after stent deployment confirmed";
        }

        state CatheterWithdrawal {
            doc "Delivery catheter withdrawn from patient body";
        }

        state ProcedureComplete {
            doc "Procedure complete with stent permanently in place";
        }

        transition from CatheterInsertion to VascularNavigation;
        transition from VascularNavigation to LesionPositioning;
        transition from LesionPositioning to BalloonInflation;
        transition from BalloonInflation to StentDeployment;
        transition from StentDeployment to BalloonDeflation;
        transition from BalloonDeflation to CatheterWithdrawal;
        transition from CatheterWithdrawal to ProcedureComplete;
    }

    // ===== Part Definitions =====
    part def Stent {
        doc "Permanent tubular mesh scaffold made from biocompatible Cobalt-Chromium alloy";

        attribute material : String = "Cobalt-Chromium Alloy L605";
        attribute meshType : String = "Laser-cut tubular mesh";
        attribute collapsedDiameter : DiameterValue = 1.0;
        attribute expandedDiameter : DiameterValue = 3.5;
        attribute stentLength : LengthValue = 20;
        attribute strutThickness : LengthValue = 0.08;
        attribute strutWidth : LengthValue = 0.08;
        attribute nominalRadialForce : ForceValue = 0.2;
        attribute foreshorteningRatio : PercentageValue = 0.05;
        attribute isPermanent : Boolean = true;
        attribute surfaceArea : Real = 7.5;
        attribute metalAratio : Real = 0.15;

        port outerSurface : MechanicalContactPort;
        port innerSurface : MechanicalContactPort;
        port proximalEnd : MechanicalContactPort;
        port distalEnd : MechanicalContactPort;

        requirement stentReq : StentImplantRequirement {
            subject = this;
        }

        state stentStates : StentStateMachine;

        action provideScaffold {
            doc "Stent provides continuous outward radial force to hold vessel open";
            out radialForce : ForceValue = 0.2;
        }

        action expandStent {
            doc "Stent expands from collapsed to deployed diameter";
            in currentDiameter : DiameterValue;
            out deployedDiameter : DiameterValue = 3.5;
        }

        satisfy stentReq.expandable by expandStent;
        satisfy stentReq.radialScaffold by provideScaffold;
        satisfy stentReq.biocompatibleMaterial by material;
        satisfy stentReq.radialFlexibility by stentStates;
    }

    part def Balloon {
        doc "Inflatable balloon mounted on catheter tip for stent deployment";

        attribute material : String = "Semi-compliant Polyamide";
        attribute deflatedDiameter : DiameterValue = 1.5;
        attribute inflatedDiameter : DiameterValue = 3.5;
        attribute balloonLength : LengthValue = 20;
        attribute nominalInflationPressure : PressureValue = 800000;
        attribute ratedBurstPressure : PressureValue = 1400000;
        attribute maximumVolume : VolumeValue = 2.0;
        attribute compliance : Real = 0.05;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port outerSurface : MechanicalContactPort;

        requirement balloonReq : BalloonRequirement {
            subject = this;
        }

        state balloonStates : BalloonStateMachine;

        action inflate {
            doc "Inflate balloon to nominal pressure to expand stent";
            in targetPressure : PressureValue = 800000;
            out achievedDiameter : DiameterValue = 3.5;
        }

        action deflate {
            doc "Deflate balloon to permit catheter withdrawal";
            out finalDiameter : DiameterValue = 1.5;
        }

        satisfy balloonReq.inflateToNominal by inflate;
        satisfy balloonReq.deflateForRemoval by deflate;
        satisfy balloonReq.withstandBurstPressure by material;
    }

    part def DeliveryCatheter {
        doc "Disposable delivery catheter for stent navigation and deployment";

        attribute workingLength : LengthValue = 1500;
        attribute outerDiameter : DiameterValue = 2.0;
        attribute innerDiameter : DiameterValue = 1.0;
        attribute shaftMaterial : String = "Pebax 72D";
        attribute isDisposable : Boolean = true;
        attribute flexibility : Real = 0.8;
        attribute trackability : Real = 0.9;
        attribute pushability : Real = 0.7;
        attribute radiopaqueMarkerType : String = "Platinum-iridium";

        port proximalFluidPort : FluidPort;
        port distalTipPort : MechanicalContactPort;

        part balloon : Balloon;
        part stent : Stent;

        requirement catheterReq : DeliveryCatheterRequirement {
            subject = this;
        }

        action deploymentProcedure : StentDeploymentProcedure;
        state procedureStates : ProcedureStateMachine;

        connection fluidPath : FluidInterface {
            supplier = proximalFluidPort;
            consumer = balloon.fluidInlet;
        }

        connection stentBalloonInterface : MechanicalInterface {
            supplier = balloon.outerSurface;
            consumer = stent.innerSurface;
        }

        satisfy catheterReq.navigate by deploymentProcedure;
        satisfy catheterReq.deploy by deploymentProcedure;
        satisfy catheterReq.withdraw by deploymentProcedure;
        satisfy catheterReq.singleUse by isDisposable;
        satisfy catheterReq.radiopaqueMarkers by radiopaqueMarkerType;
    }

    part def Lesion {
        doc "Vascular stenosis or atherosclerotic plaque blockage";

        attribute degreeOfStenosis : PercentageValue = 0.7;
        attribute lesionLength : LengthValue = 15;
        attribute plaqueType : String = "Fibrocalcific";
        attribute calciumScore : Real = 200;
        attribute eccentricity : Real = 0.3;

        port lesionSurface : MechanicalContactPort;

        item plaque : Plaque;
    }

    part def BloodVessel {
        doc "Target blood vessel with stenosis requiring treatment";

        attribute vesselType : String = "Coronary Artery";
        attribute healthyDiameter : DiameterValue = 3.5;
        attribute stenosedDiameter : DiameterValue = 1.0;
        attribute vesselLength : LengthValue = 100;
        attribute wallThickness : LengthValue = 1.0;
        attribute vesselElasticity : Real = 0.6;

        port proximalEnd : VascularPort;
        port distalEnd : VascularPort;
        port lesionSite : MechanicalContactPort;

        part lesion : Lesion;

        connection bloodFlowPath : FluidInterface {
            supplier = proximalEnd;
            consumer = distalEnd;
        }
    }

    part def StentSystem {
        doc "Medical stent system for treating vascular stenosis";

        port systemFluidPort : FluidPort;
        port systemProximalPort : VascularPort;
        port systemDistalPort : VascularPort;

        part implant : Stent;
        part deliveryDevice : DeliveryCatheter;
        part targetVessel : BloodVessel;

        requirement systemReq : StentSystemRequirement {
            subject = this;
        }

        state procedureState : ProcedureStateMachine;
        action systemProcedure : StentDeploymentProcedure;

        connection stentBalloonMount : MechanicalInterface {
            supplier = deliveryDevice.balloon.outerSurface;
            consumer = implant.innerSurface;
        }

        connection stentVesselInterface : MechanicalInterface {
            supplier = implant.outerSurface;
            consumer = targetVessel.lesionSite;
        }

        connection inflationFluidPath : FluidInterface {
            supplier = systemFluidPort;
            consumer = deliveryDevice.proximalFluidPort;
        }

        connection vesselInflow : FluidInterface {
            supplier = systemProximalPort;
            consumer = targetVessel.proximalEnd;
        }

        connection vesselOutflow : FluidInterface {
            supplier = targetVessel.distalEnd;
            consumer = systemDistalPort;
        }

        satisfy systemReq.reopenVessel by systemProcedure;
        satisfy systemReq.restoreBloodFlow by procedureState;
        satisfy systemReq.permanentImplant by implant;
        satisfy systemReq.disposableDelivery by deliveryDevice;
        satisfy systemReq.biocompatibility by implant.material;
    }

}
