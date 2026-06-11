package SurgicalMeshHighLevelSystem {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Millimeter :> LengthValue;
  attribute def SquareMillimeter :> AreaValue;
  attribute def Newton :> ForceValue;
  attribute def Kilopascal :> PressureValue;
  attribute def Megapascal :> PressureValue;
  attribute def Day :> TimeValue;
  attribute def Percent :> Real;

  item def TissueLoad {
    attribute peakForce : Newton;
    attribute distributedPressure : Kilopascal;
    attribute directionAngle : Real;
  }

  item def HostTissue {
    attribute defectArea : SquareMillimeter;
    attribute tissueThickness : Millimeter;
    attribute baselineTensileStrength : Megapascal;
    attribute biologicalState : TissueHealingStateKind;
  }

  item def CellularIngrowth {
    attribute collagenCoverage : Percent;
    attribute vascularization : Percent;
    attribute daysSinceImplant : Day;
  }

  enum def TissueHealingStateKind {
    enum acuteInflammation;
    enum granulation;
    enum remodeling;
    enum integrated;
    enum adverseResponse;
  }

  port def TissueContactPort {
    in item hostTissue : HostTissue;
    in item appliedLoad : TissueLoad;
    out item reactionLoad : TissueLoad;
    out item ingrowth : CellularIngrowth;
  }

  port def SurgeonHandlingPort {
    in item placementCommand : MeshPlacementCommand;
    out item placementFeedback : MeshPlacementFeedback;
  }

  item def MeshPlacementCommand {
    attribute targetOverlapMargin : Millimeter;
    attribute requiredOrientationAngle : Real;
    attribute fixationPatternPitch : Millimeter;
  }

  item def MeshPlacementFeedback {
    attribute achievedOverlapMargin : Millimeter;
    attribute wrinkleHeight : Millimeter;
    attribute orientationError : Real;
    attribute fixationCount : Integer;
  }

  part def SurgicalMeshSystem {
    attribute primaryFunction : String = "Reinforce a weakened or surgically repaired soft-tissue region by distributing mechanical loads across the defect while providing a porous scaffold for host tissue ingrowth.";

    port tissueInterface : TissueContactPort;
    port surgicalInterface : SurgeonHandlingPort;

    part mesh : SurgicalMeshImplant;
    part fixationSet : FixationSubsystem;
    part tissueBoundary : TissueInterfaceLayer;
    part packaging : SterilePackaging;

    connect tissueInterface to tissueBoundary.externalTissuePort;
    connect tissueBoundary.meshSidePort to mesh.tissueSidePort;
    connect mesh.fixationPort to fixationSet.meshAttachmentPort;
    connect surgicalInterface to fixationSet.surgeonPort;
  }

  part def SurgicalMeshImplant {
    attribute material : String = "monofilament polypropylene";
    attribute nominalLength : Millimeter = 150 [mm];
    attribute nominalWidth : Millimeter = 100 [mm];
    attribute thickness : Millimeter = 0.55 [mm];
    attribute poreDiameter : Millimeter = 1.4 [mm];
    attribute arealDensity : Real = 45.0;
    attribute tensileStrength : Megapascal = 32 [MPa];
    attribute elasticElongationAtWorkingLoad : Percent = 18.0;
    attribute minimumOverlapMargin : Millimeter = 30 [mm];

    port tissueSidePort : TissueContactPort;
    port fixationPort : MeshFixationPort;

    part fibers : FiberNetwork;
    part pores : PorousScaffold;
    part orientationMarker : OrientationMarker;
  }

  part def FiberNetwork {
    attribute warpFiberDiameter : Millimeter = 0.16 [mm];
    attribute weftFiberDiameter : Millimeter = 0.16 [mm];
    attribute knitPattern : String = "macroporous warp knit";
    attribute anisotropyRatio : Real = 1.25;
  }

  part def PorousScaffold {
    attribute openAreaFraction : Percent = 68.0;
    attribute meanPoreArea : SquareMillimeter = 1.55 [mm^2];
    attribute ingrowthTargetCoverageAt28Days : Percent = 60.0;
  }

  part def OrientationMarker {
    attribute visibleStripeColor : String = "blue";
    attribute stripeWidth : Millimeter = 2.0 [mm];
    attribute indicatesHighStrengthAxis : Boolean = true;
  }

  port def MeshFixationPort {
    in item fixationForce : TissueLoad;
    out item retentionReaction : TissueLoad;
  }

  part def FixationSubsystem {
    attribute defaultFixationPitch : Millimeter = 20 [mm];
    attribute minimumFixationCount : Integer = 8;

    port meshAttachmentPort : MeshFixationPort;
    port surgeonPort : SurgeonHandlingPort;

    part sutures : AbsorbableSuture[8..*];
  }

  part def AbsorbableSuture {
    attribute filamentDiameter : Millimeter = 0.30 [mm];
    attribute initialKnotPullStrength : Newton = 18 [N];
    attribute absorptionTime : Day = 90 [d];
  }

  part def TissueInterfaceLayer {
    attribute targetContactPressure : Kilopascal = 2.5 [kPa];
    attribute maximumWrinkleHeight : Millimeter = 2.0 [mm];

    port externalTissuePort : TissueContactPort;
    port meshSidePort : TissueContactPort;
  }

  part def SterilePackaging {
    attribute sterileBarrierIntegrity : Boolean = true;
    attribute shelfLife : Day = 1095 [d];
    attribute ethyleneOxideResidualLimit : Real = 4.0;
  }

  action def DistributeTissueLoad {
    in item incomingLoad : TissueLoad;
    in meshTensileStrength : Megapascal;
    out item distributedLoad : TissueLoad;

    assert constraint {
      distributedLoad.distributedPressure < incomingLoad.distributedPressure
    }
  }

  action def PromoteTissueIngrowth {
    in item hostTissue : HostTissue;
    in poreDiameter : Millimeter;
    out item ingrowth : CellularIngrowth;

    assert constraint {
      poreDiameter >= 1.0 [mm] and ingrowth.collagenCoverage >= 60.0
    }
  }

  action def PlaceAndFixMesh {
    in item command : MeshPlacementCommand;
    out item feedback : MeshPlacementFeedback;

    assert constraint {
      feedback.achievedOverlapMargin >= command.targetOverlapMargin and
      feedback.wrinkleHeight <= 2.0 [mm] and
      feedback.fixationCount >= 8
    }
  }

  state def MeshHealingLifecycle {
    entry action PlaceAndFixMesh;

    state packaged;
    state implanted;
    state acuteInflammatory;
    state granulation;
    state remodeling;
    state integrated;
    state adverseResponse;

    transition initial then packaged;
    transition packaged_to_implanted
      first packaged
      accept MeshPlaced
      then implanted;

    transition implanted_to_acute
      first implanted
      after 1 [d]
      then acuteInflammatory;

    transition acute_to_granulation
      first acuteInflammatory
      after 7 [d]
      then granulation;

    transition granulation_to_remodeling
      first granulation
      after 21 [d]
      then remodeling;

    transition remodeling_to_integrated
      first remodeling
      after 90 [d]
      then integrated;

    transition any_to_adverse
      first implanted
      accept ExcessiveInflammation
      then adverseResponse;
  }

  occurrence def MeshPlaced;
  occurrence def ExcessiveInflammation;

  requirement def PrimaryFunctionRequirement {
    subject meshSystem : SurgicalMeshSystem;

    require constraint {
      meshSystem.mesh.tensileStrength >= 25 [MPa] and
      meshSystem.mesh.poreDiameter >= 1.0 [mm] and
      meshSystem.mesh.minimumOverlapMargin >= 30 [mm]
    }
  }

  requirement def LoadDistributionRequirement {
    subject meshSystem : SurgicalMeshSystem;

    require constraint {
      meshSystem.tissueBoundary.targetContactPressure <= 5 [kPa] and
      meshSystem.mesh.elasticElongationAtWorkingLoad <= 25.0
    }
  }

  requirement def TissueIntegrationRequirement {
    subject meshSystem : SurgicalMeshSystem;

    require constraint {
      meshSystem.mesh.pores.openAreaFraction >= 55.0 and
      meshSystem.mesh.pores.ingrowthTargetCoverageAt28Days >= 60.0
    }
  }

  requirement def FixationRequirement {
    subject meshSystem : SurgicalMeshSystem;

    require constraint {
      meshSystem.fixationSet.minimumFixationCount >= 8 and
      meshSystem.fixationSet.defaultFixationPitch <= 25 [mm]
    }
  }

  requirement def HandlingRequirement {
    subject meshSystem : SurgicalMeshSystem;

    require constraint {
      meshSystem.tissueBoundary.maximumWrinkleHeight <= 2 [mm] and
      meshSystem.mesh.orientationMarker.indicatesHighStrengthAxis == true
    }
  }

  requirement def SterilityRequirement {
    subject meshSystem : SurgicalMeshSystem;

    require constraint {
      meshSystem.packaging.sterileBarrierIntegrity == true and
      meshSystem.packaging.shelfLife >= 730 [d]
    }
  }

  part surgicalMeshSystem : SurgicalMeshSystem;
}