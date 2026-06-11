package WingedInfusionSetModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Pressure :> ISQ::pressure;
    attribute def FlowRate :> ISQ::volumeFlowRate;
    attribute def Volume :> ISQ::volume;
    attribute def Length :> ISQ::length;
    attribute def Time :> ISQ::time;

    item def SterileFluid {
        attribute volume : Volume;
        attribute viscosity : Real;
    }

    item def Blood {
        attribute sampleVolume : Volume;
    }

    item def VenousAccess {
        attribute veinDepth : Length;
        attribute vesselPressure : Pressure;
    }

    port def FluidPort {
        in item fluidIn : SterileFluid;
        out item fluidOut : SterileFluid;
    }

    port def BloodPort {
        in item bloodIn : Blood;
        out item bloodOut : Blood;
    }

    port def PatientTissuePort {
        in item access : VenousAccess;
    }

    port def OperatorGripPort {
        in attribute pinchForce : Real;
        in attribute insertionAngle : Real;
    }

    value def NeedleGauge {
        attribute gaugeNumber : Integer;
    }

    part def WingedInfusionSet {
        attribute nominalNeedleGauge : NeedleGauge;
        attribute tubingLength : Length;
        attribute primingVolume : Volume;
        attribute maxRecommendedFlow : FlowRate;
        attribute sterile : Boolean;
        attribute singleUse : Boolean;

        port proximalFluidPort : FluidPort;
        port distalPatientPort : PatientTissuePort;
        port bloodCollectionPort : BloodPort;
        port gripPort : OperatorGripPort;

        part needle : StainlessSteelNeedle {
            attribute bevelAngle : Real = 12.0;
            attribute exposedLength : Length = 19 [mm];
        }

        part leftWing : FlexibleWing {
            attribute colorCode : String = "gauge-dependent";
        }

        part rightWing : FlexibleWing {
            attribute colorCode : String = "gauge-dependent";
        }

        part hub : NeedleHub {
            attribute transparent : Boolean = true;
        }

        part tubing : FlexibleTubing {
            attribute internalVolume : Volume = 0.4 [mL];
            attribute length : Length = 300 [mm];
        }

        part connector : LuerConnector {
            attribute compatibleWithSyringe : Boolean = true;
            attribute compatibleWithIVLine : Boolean = true;
            attribute compatibleWithVacuumTubeHolder : Boolean = true;
        }

        part protectiveCap : NeedleCap {
            attribute installedBeforeUse : Boolean = true;
        }

        part clamp : TubeClamp {
            attribute normallyOpen : Boolean = true;
        }

        connect connector.fluidPort to tubing.proximalPort;
        connect tubing.distalPort to hub.fluidPort;
        connect hub.needlePort to needle.lumenPort;
        connect needle.patientPort to distalPatientPort;
        connect leftWing.gripSurface to gripPort;
        connect rightWing.gripSurface to gripPort;
        connect connector.bloodPort to bloodCollectionPort;

        action primeSet {
            in item flushFluid : SterileFluid;
            out item airRemovedFluid : SterileFluid;
            first start;
            then fillConnector;
            then fillTubing;
            then fillHub;
            then purgeNeedle;
            then done;
        }

        action insertNeedle {
            in item target : VenousAccess;
            in attribute angle : Real;
            out attribute veinAccessEstablished : Boolean;
            first alignBevel;
            then stabilizeWings;
            then punctureSkin;
            then advanceIntoVein;
            then confirmFlashback;
            then done;
        }

        action deliverFluid {
            in item prescribedFluid : SterileFluid;
            in attribute commandedFlow : FlowRate;
            out item deliveredFluid : SterileFluid;
            first openFluidPath;
            then regulateFlow;
            then transferThroughTubing;
            then exitNeedleTip;
            then done;
        }

        action collectBlood {
            in item venousBlood : Blood;
            out item collectedBlood : Blood;
            first attachCollectionDevice;
            then openBloodPath;
            then drawSample;
            then stopFlow;
            then done;
        }

        state def InfusionSetLifecycle {
            state packaged;
            state cappedSterile;
            state primed;
            state inserted;
            state infusing;
            state sampling;
            state removed;
            state disposed;

            entry action packaged {
                protectiveCap.installedBeforeUse = true;
                sterile = true;
            }

            transition first packaged then cappedSterile;
            transition cappedSterile then primed
                accept PrimeCommand
                do primeSet;
            transition primed then inserted
                accept InsertCommand
                do insertNeedle;
            transition inserted then infusing
                accept StartInfusionCommand
                do deliverFluid;
            transition inserted then sampling
                accept StartBloodCollectionCommand
                do collectBlood;
            transition infusing then inserted
                accept StopInfusionCommand;
            transition sampling then inserted
                accept StopBloodCollectionCommand;
            transition inserted then removed
                accept RemoveNeedleCommand;
            transition removed then disposed
                accept DisposeCommand;
        }

        exhibit state lifecycle : InfusionSetLifecycle;
    }

    part def StainlessSteelNeedle {
        attribute bevelAngle : Real;
        attribute exposedLength : Length;
        attribute outerDiameter : Length;
        attribute innerDiameter : Length;

        port lumenPort : FluidPort;
        port patientPort : PatientTissuePort;

        requirement sharpTipRequirement {
            doc /* The needle shall provide a beveled sharp tip suitable for percutaneous venous access. */
        }

        requirement lumenPatencyRequirement {
            doc /* The needle lumen shall remain open during normal insertion and fluid transfer. */
        }
    }

    part def FlexibleWing {
        attribute flexible : Boolean = true;
        attribute texturedSurface : Boolean = true;
        attribute colorCode : String;

        port gripSurface : OperatorGripPort;

        requirement stabilizationRequirement {
            doc /* The wing shall allow an operator to hold, orient, insert, and tape the device with controlled needle position. */
        }
    }

    part def NeedleHub {
        attribute transparent : Boolean;
        attribute flashbackVisible : Boolean;

        port fluidPort : FluidPort;
        port needlePort : FluidPort;

        requirement flashbackRequirement {
            doc /* The hub shall permit visual confirmation of venous entry by blood flashback when applicable. */
        }
    }

    part def FlexibleTubing {
        attribute length : Length;
        attribute internalVolume : Volume;
        attribute kinkResistant : Boolean = true;

        port proximalPort : FluidPort;
        port distalPort : FluidPort;

        requirement flexibilityRequirement {
            doc /* The tubing shall allow connection to external fluid or collection equipment while reducing transmitted motion at the inserted needle. */
        }
    }

    part def LuerConnector {
        attribute compatibleWithSyringe : Boolean;
        attribute compatibleWithIVLine : Boolean;
        attribute compatibleWithVacuumTubeHolder : Boolean;
        attribute leakTight : Boolean = true;

        port fluidPort : FluidPort;
        port bloodPort : BloodPort;

        requirement connectionRequirement {
            doc /* The connector shall provide a secure, leak-resistant interface to standard infusion or blood collection accessories. */
        }
    }

    part def NeedleCap {
        attribute installedBeforeUse : Boolean;
        attribute punctureResistant : Boolean = true;

        requirement protectionRequirement {
            doc /* The cap shall protect the needle from contamination and accidental contact before clinical use. */
        }
    }

    part def TubeClamp {
        attribute normallyOpen : Boolean;
        attribute closed : Boolean;

        action closeClamp {
            out attribute flowPermitted : Boolean = false;
        }

        action openClamp {
            out attribute flowPermitted : Boolean = true;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The winged infusion set shall provide temporary venous access through a small-bore wing-stabilized needle and flexible tubing to enable controlled infusion of sterile fluid into a patient or collection of venous blood from the patient. */
    }

    requirement def SterilityRequirement {
        doc /* All patient-fluid-contacting components shall be sterile before first use and intended for single-patient, single-use operation. */
    }

    requirement def FlowPathRequirement {
        doc /* The device shall maintain a continuous fluid path from the proximal connector through the tubing, hub, and needle lumen to the venous access site. */
    }

    requirement def StabilizedInsertionRequirement {
        doc /* The paired flexible wings shall support manual control of insertion angle and post-insertion stabilization. */
    }

    requirement def SafeDisposalRequirement {
        doc /* After removal from the patient, the used device shall be treated as a sharps-containing biohazard and routed to approved disposal. */
    }

    part wingedInfusionSet : WingedInfusionSet {
        attribute nominalNeedleGauge.gaugeNumber = 23;
        attribute tubingLength = 300 [mm];
        attribute primingVolume = 0.5 [mL];
        attribute maxRecommendedFlow = 30 [mL/min];
        attribute sterile = true;
        attribute singleUse = true;
    }

    satisfy PrimaryFunctionRequirement by wingedInfusionSet;
    satisfy SterilityRequirement by wingedInfusionSet;
    satisfy FlowPathRequirement by wingedInfusionSet.tubing;
    satisfy StabilizedInsertionRequirement by wingedInfusionSet.leftWing;
    satisfy StabilizedInsertionRequirement by wingedInfusionSet.rightWing;
    satisfy SafeDisposalRequirement by wingedInfusionSet;

}