package WordCatheterSystemModel {
  import ScalarValues::*;
  import SI::*;

  item def CystFluid {
    attribute volume : Real;
    attribute viscosity : Real;
  }

  item def SterileSaline {
    attribute volume : Real;
  }

  item def Air {
    attribute volume : Real;
  }

  item def DrainageFlow {
    attribute flowRate_ml_per_min : Real;
  }

  value type Millimeter :> Real;
  value type Milliliter :> Real;
  value type Minute :> Real;
  value type Kilopascal :> Real;
  value type Newton :> Real;

  port def FluidDrainagePort {
    in item cystFluidIn : CystFluid;
    out item drainageOut : DrainageFlow;
  }

  port def InflationPort {
    in item inflationMedium : SterileSaline;
    out item residualMedium : SterileSaline;
  }

  port def TissueInterfacePort {
    in item placementForce : Newton;
    out item retentionReaction : Newton;
  }

  part def WordCatheterSystem {
    attribute catheterLength_mm : Millimeter = 55.0;
    attribute shaftOuterDiameter_mm : Millimeter = 3.0;
    attribute lumenInnerDiameter_mm : Millimeter = 1.5;
    attribute balloonNominalVolume_ml : Milliliter = 3.0;
    attribute balloonMaximumVolume_ml : Milliliter = 4.0;
    attribute intendedResidenceTime_days : Real = 28.0;

    port proximalDrainagePort : FluidDrainagePort;
    port proximalInflationPort : InflationPort;
    port distalDrainagePort : FluidDrainagePort;
    port distalTissuePort : TissueInterfacePort;

    part shaft : FlexibleCatheterShaft;
    part drainageLumen : DrainageLumen;
    part inflationLumen : InflationLumen;
    part retentionBalloon : RetentionBalloon;
    part roundedTip : AtraumaticTip;
    part externalHub : ExternalHub;

    connection drainagePath connect proximalDrainagePort to drainageLumen.proximalPort;
    connection drainageExit connect drainageLumen.distalPort to distalDrainagePort;
    connection inflationPath connect proximalInflationPort to inflationLumen.proximalPort;
    connection balloonFill connect inflationLumen.distalPort to retentionBalloon.fillPort;
    connection tissueRetention connect retentionBalloon.tissuePort to distalTissuePort;

    action primaryFunction : MaintainTemporaryDrainageTract;
    action insertionProcedure : InsertAndRetainCatheter;
    action removalProcedure : DeflateAndRemoveCatheter;

    state retentionLifecycle : CatheterRetentionLifecycle;
  }

  part def FlexibleCatheterShaft {
    attribute materialName : String = "medical grade silicone";
    attribute outsideDiameter_mm : Millimeter = 3.0;
    attribute bendingStiffness_relative : Real = 0.35;
    attribute biocompatible : Boolean = true;

    port proximalPort : FluidDrainagePort;
    port distalPort : FluidDrainagePort;
  }

  part def DrainageLumen {
    attribute innerDiameter_mm : Millimeter = 1.5;
    attribute minimumOpenArea_mm2 : Real = 1.7;
    attribute obstructionDetected : Boolean = false;

    port proximalPort : FluidDrainagePort;
    port distalPort : FluidDrainagePort;
  }

  part def InflationLumen {
    attribute innerDiameter_mm : Millimeter = 0.6;
    attribute leakDetected : Boolean = false;

    port proximalPort : InflationPort;
    port distalPort : InflationPort;
  }

  part def RetentionBalloon {
    attribute fillVolume_ml : Milliliter = 0.0;
    attribute inflationPressure_kPa : Kilopascal = 0.0;
    attribute nominalRetainedDiameter_mm : Millimeter = 10.0;
    attribute inflated : Boolean = false;

    port fillPort : InflationPort;
    port tissuePort : TissueInterfacePort;

    state balloonState : BalloonInflationState;
  }

  part def AtraumaticTip {
    attribute tipRadius_mm : Millimeter = 1.2;
    attribute edgeFree : Boolean = true;
  }

  part def ExternalHub {
    attribute visibleOutsideBody : Boolean = true;
    attribute supportsManualDeflation : Boolean = true;

    port drainagePort : FluidDrainagePort;
    port inflationPort : InflationPort;
  }

  action def MaintainTemporaryDrainageTract {
    in item glandFluid : CystFluid;
    out item drainedFluid : DrainageFlow;

    attribute targetFlowRate_ml_per_min : Real = 0.05;
    attribute tractPatencyMaintained : Boolean;

    first start;
    then receiveFluid;
    then conductFluid;
    then dischargeFluid;
    then maintainBalloonRetention;
    then done;

    action start;
    action receiveFluid {
      in item glandFluid : CystFluid;
    }
    action conductFluid {
      attribute lumenPatent : Boolean;
    }
    action dischargeFluid {
      out item drainedFluid : DrainageFlow;
    }
    action maintainBalloonRetention {
      attribute retentionEnabled : Boolean;
    }
  }

  action def InsertAndRetainCatheter {
    in item inflationMedium : SterileSaline;
    out item retainedCatheter : WordCatheterSystem;

    action createIncision;
    action advanceTipIntoCavity;
    action inflateBalloon;
    action confirmDrainage;
    action positionExternalHub;

    first createIncision;
    then advanceTipIntoCavity;
    then inflateBalloon;
    then confirmDrainage;
    then positionExternalHub;
    then done;
  }

  action def DeflateAndRemoveCatheter {
    in item retainedCatheter : WordCatheterSystem;
    out item removedCatheter : WordCatheterSystem;

    action withdrawInflationMedium;
    action collapseBalloon;
    action removeShaft;
    action verifyRemoval;

    first withdrawInflationMedium;
    then collapseBalloon;
    then removeShaft;
    then verifyRemoval;
    then done;
  }

  state def BalloonInflationState {
    entry action initialize {
      attribute fillVolume_ml : Milliliter = 0.0;
      attribute inflationPressure_kPa : Kilopascal = 0.0;
    }

    state Deflated;
    state Filling;
    state InflatedForRetention;
    state Overfilled;
    state Leaking;
    state Collapsing;

    transition initial then Deflated;
    transition Deflated to Filling accept InflationStarted;
    transition Filling to InflatedForRetention
      if fillVolume_ml >= 2.5 and fillVolume_ml <= 3.5;
    transition Filling to Overfilled
      if fillVolume_ml > 4.0;
    transition InflatedForRetention to Leaking
      if inflationPressure_kPa < 5.0;
    transition InflatedForRetention to Collapsing accept DeflationStarted;
    transition Collapsing to Deflated
      if fillVolume_ml <= 0.2;
  }

  state def CatheterRetentionLifecycle {
    state PackagedSterile;
    state PreparedForInsertion;
    state InsertedDeflated;
    state BalloonInflated;
    state DrainageMaintained;
    state ReadyForRemoval;
    state Removed;
    state Disposed;

    transition initial then PackagedSterile;
    transition PackagedSterile to PreparedForInsertion accept PackageOpened;
    transition PreparedForInsertion to InsertedDeflated accept CatheterInserted;
    transition InsertedDeflated to BalloonInflated accept BalloonInflated;
    transition BalloonInflated to DrainageMaintained accept DrainageObserved;
    transition DrainageMaintained to ReadyForRemoval accept TherapyComplete;
    transition ReadyForRemoval to Removed accept BalloonDeflated;
    transition Removed to Disposed accept DisposalComplete;
  }

  requirement def PrimaryFunctionRequirement {
    subject catheter : WordCatheterSystem;

    doc /* The system shall provide temporary drainage of fluid from a Bartholin gland cyst or abscess cavity by maintaining a patent tract with a small retained balloon catheter. */

    require constraint {
      catheter.drainageLumen.minimumOpenArea_mm2 >= 1.0
    }

    require constraint {
      catheter.retentionBalloon.balloonNominalVolume_ml >= 2.5 and
      catheter.retentionBalloon.balloonNominalVolume_ml <= 3.5
    }
  }

  requirement def AtraumaticInterfaceRequirement {
    subject tip : AtraumaticTip;

    require constraint {
      tip.tipRadius_mm >= 1.0
    }

    require constraint {
      tip.edgeFree == true
    }
  }

  requirement def RetentionRequirement {
    subject balloon : RetentionBalloon;

    require constraint {
      balloon.nominalRetainedDiameter_mm >= 8.0 and
      balloon.nominalRetainedDiameter_mm <= 12.0
    }

    require constraint {
      balloon.fillVolume_ml <= 4.0
    }
  }

  requirement def PatencyRequirement {
    subject lumen : DrainageLumen;

    require constraint {
      lumen.innerDiameter_mm >= 1.2
    }

    require constraint {
      lumen.obstructionDetected == false
    }
  }

  requirement def BiocompatibilityRequirement {
    subject shaft : FlexibleCatheterShaft;

    require constraint {
      shaft.biocompatible == true
    }

    require constraint {
      shaft.materialName == "medical grade silicone"
    }
  }

  satisfy PrimaryFunctionRequirement by WordCatheterSystem;
  satisfy AtraumaticInterfaceRequirement by AtraumaticTip;
  satisfy RetentionRequirement by RetentionBalloon;
  satisfy PatencyRequirement by DrainageLumen;
  satisfy BiocompatibilityRequirement by FlexibleCatheterShaft;
}