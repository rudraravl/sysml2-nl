package MedicalGownSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Units =====
    unit kPa;
    unit percent;
    unit g_per_m2_day;
    unit cm;
    unit N;
    unit m2;
    unit g_per_m2;

    // ===== Value types =====
    value type PressureValue :> Real {
        unit kPa;
    }
    value type PercentValue :> Real {
        unit percent;
    }
    value type MVTRValue :> Real {
        unit g_per_m2_day;
    }
    value type LengthValue :> Real {
        unit cm;
    }
    value type ForceValue :> Real {
        unit N;
    }
    value type AreaValue :> Real {
        unit m2;
    }
    value type MassPerAreaValue :> Real {
        unit g_per_m2;
    }
    value type SaturationFraction :> Real {
        unit percent;
    }

    // ===== Items =====
    item def BodyFluid;
    item def Pathogen;
    item def Contaminant {
        item bodyFluid : BodyFluid[0..*];
        item pathogen : Pathogen[0..*];
        attribute concentration : Real;
    }
    item def ContaminantFlow :> Contaminant {
        attribute flowRate : Real;
        attribute appliedPressure : PressureValue;
    }

    // ===== Enumerations =====
    enumeration def ProtectionLevel {
        Level1;
        Level2;
        Level3;
        Level4;
    }
    enumeration def GownLifecycleState {
        packaged;
        donned;
        inUse;
        contaminated;
        disposed;
    }

    // ===== Protection level specifications =====
    attribute def ProtectionLevelSpec {
        attribute level : ProtectionLevel;
        attribute minFluidResistance : PressureValue;
        attribute minBarrierEfficiency : PercentValue;
        attribute minBreathability : MVTRValue;
        attribute useCase : String;
    }
    attribute def Level1Spec :> ProtectionLevelSpec {
        :>> level = ProtectionLevel::Level1;
        :>> minFluidResistance = 1.0 [kPa];
        :>> minBarrierEfficiency = 95 [percent];
        :>> minBreathability = 700 [g_per_m2_day];
        :>> useCase = "Minimal-risk basic care";
    }
    attribute def Level2Spec :> ProtectionLevelSpec {
        :>> level = ProtectionLevel::Level2;
        :>> minFluidResistance = 2.0 [kPa];
        :>> minBarrierEfficiency = 98 [percent];
        :>> minBreathability = 600 [g_per_m2_day];
        :>> useCase = "Moderate-risk fluid contact";
    }
    attribute def Level3Spec :> ProtectionLevelSpec {
        :>> level = ProtectionLevel::Level3;
        :>> minFluidResistance = 3.5 [kPa];
        :>> minBarrierEfficiency = 99 [percent];
        :>> minBreathability = 450 [g_per_m2_day];
        :>> useCase = "High-risk surgical procedures";
    }
    attribute def Level4Spec :> ProtectionLevelSpec {
        :>> level = ProtectionLevel::Level4;
        :>> minFluidResistance = 14.0 [kPa];
        :>> minBarrierEfficiency = 99.9 [percent];
        :>> minBreathability = 300 [g_per_m2_day];
        :>> useCase = "High-risk fluid-intensive procedures";
    }

    // ===== Signals =====
    signal def Donning;
    signal def ProcedureStart;
    signal def ProcedureEnd;
    signal def DoffingComplete;
    signal def BarrierBreached;

    // ===== Ports =====
    port def ExternalExposurePort {
        in item incomingContaminant : ContaminantFlow;
        attribute appliedPressure : PressureValue;
    }
    port def BodyContactPort {
        out item blockedContaminant : ContaminantFlow;
        attribute bodyPressure : PressureValue;
    }
    port def TieAnchorPort {
        attribute tensileLoad : ForceValue;
    }
    port def CuffSealPort {
        attribute sealPressure : PressureValue;
        attribute fitDiameter : LengthValue;
    }
    port def FabricOverlapPort {
        attribute overlapWidth : LengthValue;
    }
    port def SleeveCuffInterfacePort {
        attribute attachmentLoad : ForceValue;
    }

    // ===== Fabric =====
    part def ProtectiveFabric {
        attribute barrierEfficiency : PercentValue;
        attribute fluidResistance : PressureValue;
        attribute breathability : MVTRValue;
        attribute thickness : LengthValue;
        attribute massPerArea : MassPerAreaValue;
        attribute isBarrierBreached : Boolean = false;
        attribute saturationLevel : SaturationFraction = 0.0 [percent];

        port externalSurfacePort : ExternalExposurePort;
        port bodySidePort : BodyContactPort;

        action def resistFluid {
            in appliedPressure : PressureValue;
            in incomingContaminant : ContaminantFlow;
            out blockedContaminant : ContaminantFlow;
            out passedContaminant : ContaminantFlow;
            out withstood : Boolean;
            if appliedPressure <= fluidResistance {
                withstood := true;
                blockedContaminant := incomingContaminant;
                isBarrierBreached := false;
            } else {
                withstood := false;
                isBarrierBreached := true;
                passedContaminant := incomingContaminant;
            }
        }

        exhibit state def BarrierIntegrity {
            state Intact;
            state Breached;
            state Saturated;
            transition from Intact to Breached when externalSurfacePort.appliedPressure > fluidResistance;
            transition from Intact to Saturated when saturationLevel >= 100 [percent];
            transition from Breached to Saturated when saturationLevel >= 100 [percent];
        }
    }

    // ===== Components =====
    part def FrontTorsoPanel {
        attribute coverageArea : AreaValue;
        attribute overlapWidth : LengthValue;
        part fabric : ProtectiveFabric {
            :>> barrierEfficiency = 99 [percent];
            :>> fluidResistance = 3.5 [kPa];
            :>> breathability = 450 [g_per_m2_day];
            :>> thickness = 0.1 [cm];
            :>> massPerArea = 50 [g_per_m2];
        }
        port externalPort : ExternalExposurePort;
        port bodyPort : BodyContactPort;
        port backOverlapPort : FabricOverlapPort;
    }

    part def BackTorsoPanel {
        attribute coverageArea : AreaValue;
        attribute overlapWidth : LengthValue;
        part fabric : ProtectiveFabric {
            :>> barrierEfficiency = 95 [percent];
            :>> fluidResistance = 1.6 [kPa];
            :>> breathability = 600 [g_per_m2_day];
            :>> thickness = 0.08 [cm];
            :>> massPerArea = 40 [g_per_m2];
        }
        port externalPort : ExternalExposurePort;
        port bodyPort : BodyContactPort;
        port overlapLeftPort : FabricOverlapPort;
        port overlapRightPort : FabricOverlapPort;
    }

    part def Sleeve {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        part fabric : ProtectiveFabric {
            :>> barrierEfficiency = 99 [percent];
            :>> fluidResistance = 3.5 [kPa];
            :>> breathability = 450 [g_per_m2_day];
            :>> thickness = 0.1 [cm];
            :>> massPerArea = 50 [g_per_m2];
        }
        port externalPort : ExternalExposurePort;
        port bodyPort : BodyContactPort;
        port cuffInterfacePort : SleeveCuffInterfacePort;
    }

    part def ElasticCuff {
        attribute innerDiameter : LengthValue;
        attribute stretchForce : ForceValue;
        attribute elasticModulus : Real;
        part material : ProtectiveFabric {
            :>> fluidResistance = 3.5 [kPa];
            :>> barrierEfficiency = 99 [percent];
        }
        port wristSealPort : CuffSealPort;
        port sleeveAttachmentPort : SleeveCuffInterfacePort;
        port bodyPort : BodyContactPort;
    }

    part def TieClosure {
        attribute location : String;
        attribute tensileStrength : ForceValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        port gownAttachmentPort : TieAnchorPort;
        port closureEndPort : TieAnchorPort;

        action def secure {
            in pullForce : ForceValue;
            out secured : Boolean;
            if pullForce <= tensileStrength {
                secured := true;
            } else {
                secured := false;
            }
        }
    }

    // ===== Top-level gown =====
    part def MedicalGown {
        attribute protectionLevel : ProtectionLevel = ProtectionLevel::Level3;
        attribute levelSpec : ProtectionLevelSpec;
        attribute size : String = "standard";
        attribute isSingleUse : Boolean = true;
        attribute isSterile : Boolean = true;
        attribute barrierBreached : Boolean = false;
        attribute isDonned : Boolean = false;
        attribute isInUse : Boolean = false;

        part frontTorsoPanel : FrontTorsoPanel;
        part backTorsoPanel : BackTorsoPanel;
        part sleeves : Sleeve[2];
        part cuffs : ElasticCuff[2];
        part neckTie : TieClosure {
            :>> location = "neck";
            :>> tensileStrength = 80 [N];
            :>> length = 30 [cm];
            :>> width = 1 [cm];
        }
        part waistTie : TieClosure {
            :>> location = "waist";
            :>> tensileStrength = 120 [N];
            :>> length = 80 [cm];
            :>> width = 2 [cm];
        }

        // Aggregate ports
        port externalExposure : ExternalExposurePort;
        port bodyContact : BodyContactPort;

        // Internal connections
        connection frontBackOverlap between frontTorsoPanel.backOverlapPort and backTorsoPanel.overlapLeftPort;
        connection backOverlapSeal between backTorsoPanel.overlapRightPort and backTorsoPanel.overlapLeftPort;
        connection sleeveCuff1 between sleeves[1].cuffInterfacePort and cuffs[1].sleeveAttachmentPort;
        connection sleeveCuff2 between sleeves[2].cuffInterfacePort and cuffs[2].sleeveAttachmentPort;
        connection neckTieAnchor between neckTie.gownAttachmentPort and frontTorsoPanel.bodyPort;
        connection waistTieAnchor between waistTie.gownAttachmentPort and backTorsoPanel.bodyPort;
        connection cuff1WristSeal between cuffs[1].wristSealPort and sleeves[1].cuffInterfacePort;
        connection cuff2WristSeal between cuffs[2].wristSealPort and sleeves[2].cuffInterfacePort;

        // External exposure routing
        connection externalFlowFront between externalExposure and frontTorsoPanel.externalPort;
        connection externalFlowBack between externalExposure and backTorsoPanel.externalPort;
        connection externalFlowSleeve1 between externalExposure and sleeves[1].externalPort;
        connection externalFlowSleeve2 between externalExposure and sleeves[2].externalPort;
        connection externalFlowCuff1 between externalExposure and cuffs[1].bodyPort;
        connection externalFlowCuff2 between externalExposure and cuffs[2].bodyPort;

        // Blocked contaminant routing to body contact
        connection blockedFlowFront between frontTorsoPanel.bodyPort and bodyContact;
        connection blockedFlowBack between backTorsoPanel.bodyPort and bodyContact;
        connection blockedFlowSleeve1 between sleeves[1].bodyPort and bodyContact;
        connection blockedFlowSleeve2 between sleeves[2].bodyPort and bodyContact;

        // Actions
        action def Donning {
            in user : String;
            out donned : Boolean;
            out secured : Boolean;
            donned := true;
            neckTie.secure(80 [N]);
            waistTie.secure(120 [N]);
            secured := true;
        }

        action def Doffing {
            attribute rolledInward : Boolean = false;
            attribute disposedToBiohazard : Boolean = false;
            rolledInward := true;
            disposedToBiohazard := true;
            then send DoffingComplete();
        }

        action def ProcedureStartAction {
            out started : Boolean;
            started := true;
        }

        action def ProcedureEndAction {
            out ended : Boolean;
            ended := true;
        }

        action def DetectBreach {
            barrierBreached := true;
            then send BarrierBreached();
        }

        // Lifecycle state machine
        exhibit state def Lifecycle {
            state packaged {
                entry { isSterile := true; }
                entry { barrierBreached := false; }
            }
            state donned {
                entry { isDonned := true; }
            }
            state inUse {
                entry { isInUse := true; }
                entry { isSterile := false; }
            }
            state contaminated {
                entry { barrierBreached := true; }
                entry { isSterile := false; }
            }
            state disposed {
                entry { isDonned := false; }
                entry { isInUse := false; }
                entry { isSterile := false; }
            }
            transition from packaged to donned on Donning;
            transition from donned to inUse on ProcedureStart;
            transition from inUse to contaminated on BarrierBreached;
            transition from inUse to donned on ProcedureEnd;
            transition from contaminated to disposed on DoffingComplete;
            transition from donned to disposed on DoffingComplete;
        }
    }

    // ===== Requirements =====
    package GownRequirements {

        requirement def BarrierFunctionRequirement {
            subject gown : MedicalGown;
            doc { The gown shall create a physical barrier that prevents the transfer of contaminants, such as body fluids and pathogens, between patients and medical staff during clinical procedures. }
            objective {
                gown.barrierBreached == false;
            }
        }

        requirement def FrontPanelFluidResistanceRequirement {
            subject panel : FrontTorsoPanel;
            attribute minResistance : PressureValue = 3.5 [kPa];
            doc { The front torso panel, facing the highest risk of exposure, shall exhibit higher fluid resistance than the back torso panel. }
            objective {
                panel.fabric.fluidResistance >= minResistance;
            }
        }

        requirement def BackPanelFluidResistanceRequirement {
            subject panel : BackTorsoPanel;
            attribute minResistance : PressureValue = 1.6 [kPa];
            doc { The back torso panel shall provide fluid resistance sufficient for lower-risk exposure scenarios. }
            objective {
                panel.fabric.fluidResistance >= minResistance;
            }
        }

        requirement def BreathabilityRequirement {
            subject fabric : ProtectiveFabric;
            attribute minMVTR : MVTRValue = 300 [g_per_m2_day];
            doc { The fabric shall be breathable to ensure user comfort during clinical procedures. }
            objective {
                fabric.breathability >= minMVTR;
            }
        }

        requirement def BarrierEfficiencyRequirement {
            subject fabric : ProtectiveFabric;
            attribute minEfficiency : PercentValue = 95 [percent];
            doc { The fabric shall provide a minimum barrier efficiency against contaminants. }
            objective {
                fabric.barrierEfficiency >= minEfficiency;
            }
        }

        requirement def CuffSealRequirement {
            subject cuff : ElasticCuff;
            doc { Elastic cuffs shall provide a snug and secure fit around the wrists to prevent gaps between the gown and gloves. }
            objective {
                cuff.wristSealPort.sealPressure > 0 [kPa];
                cuff.innerDiameter <= 8 [cm];
            }
        }

        requirement def TieClosureStrengthRequirement {
            subject tie : TieClosure;
            attribute minTensileStrength : ForceValue = 50 [N];
            doc { Tie closures at the neck and waist shall be strong enough to keep the gown secured during use. }
            objective {
                tie.tensileStrength >= minTensileStrength;
            }
        }

        requirement def SingleUseRequirement {
            subject gown : MedicalGown;
            doc { The gown shall be a single-use protective garment to prevent cross-contamination. }
            objective {
                gown.isSingleUse == true;
            }
        }

        requirement def LifecycleRequirement {
            subject gown : MedicalGown;
            doc { The gown shall follow a strict single-use lifecycle: packaged, donned, in use, optionally contaminated, then disposed in a biohazard container. }
            objective {
                gown.isSterile == true implies gown.isDonned == false;
            }
        }

        requirement def ProtectionLevelRequirement {
            subject gown : MedicalGown;
            attribute requiredLevel : ProtectionLevel;
            doc { The gown shall be selectable from four distinct protection levels (Level 1 to 4) based on the risk of exposure. }
            objective {
                gown.protectionLevel == requiredLevel;
            }
        }

        requirement def BackOverlapRequirement {
            subject back : BackTorsoPanel;
            attribute minOverlap : LengthValue = 10 [cm];
            doc { The back torso panel shall overlap to ensure a complete wrap-around shield. }
            objective {
                back.overlapWidth >= minOverlap;
            }
        }

        requirement def SleeveLengthRequirement {
            subject sleeve : Sleeve;
            attribute minLength : LengthValue = 50 [cm];
            doc { Sleeves shall be full-length to protect the wearer's arms. }
            objective {
                sleeve.length >= minLength;
            }
        }

        requirement def DoffingRequirement {
            subject gown : MedicalGown;
            doc { The doffing process shall roll the contaminated exterior inward before the gown is safely disposed of in a biohazard container. }
            objective {
                gown.Doffing.rolledInward == true;
                gown.Doffing.disposedToBiohazard == true;
            }
        }

        requirement def FrontBackCoverageRequirement {
            subject gown : MedicalGown;
            doc { The front panel shall have a higher fluid resistance than the back panel due to higher exposure risk. }
            objective {
                gown.frontTorsoPanel.fabric.fluidResistance > gown.backTorsoPanel.fabric.fluidResistance;
            }
        }

        requirement def SterilePackagingRequirement {
            subject gown : MedicalGown;
            doc { The gown shall begin its lifecycle in a sterile, packaged state. }
            objective {
                gown.isSterile == true;
            }
        }

        requirement gownLevel1Requirement : ProtectionLevelRequirement {
            :>> requiredLevel = ProtectionLevel::Level1;
            subject gownLevel1 : MedicalGown;
            doc { Level 1 gowns shall be used for minimal-risk situations such as basic care. }
        }
        requirement gownLevel2Requirement : ProtectionLevelRequirement {
            :>> requiredLevel = ProtectionLevel::Level2;
            subject gownLevel2 : MedicalGown;
            doc { Level 2 gowns shall be used for moderate-risk fluid contact scenarios. }
        }
        requirement gownLevel3Requirement : ProtectionLevelRequirement {
            :>> requiredLevel = ProtectionLevel::Level3;
            subject gownLevel3 : MedicalGown;
            doc { Level 3 gowns shall be used for high-risk surgical procedures. }
        }
        requirement gownLevel4Requirement : ProtectionLevelRequirement {
            :>> requiredLevel = ProtectionLevel::Level4;
            subject gownLevel4 : MedicalGown;
            doc { Level 4 gowns shall be used for high-risk, fluid-intensive surgical procedures. }
        }
    }

    // ===== Sample gown instance =====
    part def Level3SurgicalGown :> MedicalGown {
        :>> protectionLevel = ProtectionLevel::Level3;
        :>> levelSpec = Level3Spec;
        :>> size = "large";
        :>> isSingleUse = true;
        :>> frontTorsoPanel.coverageArea = 0.5 [m2];
        :>> frontTorsoPanel.overlapWidth = 5 [cm];
        :>> backTorsoPanel.coverageArea = 0.55 [m2];
        :>> backTorsoPanel.overlapWidth = 15 [cm];
        :>> sleeves[1].length = 60 [cm];
        :>> sleeves[2].length = 60 [cm];
        :>> cuffs[1].innerDiameter = 7 [cm];
        :>> cuffs[2].innerDiameter = 7 [cm];
        :>> cuffs[1].stretchForce = 15 [N];
        :>> cuffs[2].stretchForce = 15 [N];
    }
}
