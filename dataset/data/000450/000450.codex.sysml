package GaitBeltHighLevelModel {

  attribute def kg :> ScalarValues::Real;
  attribute def cm :> ScalarValues::Real;
  attribute def N :> ScalarValues::Real;
  attribute def s :> ScalarValues::Real;
  attribute def deg :> ScalarValues::Real;

  item def HumanBodyLoad;
  item def CaregiverGripForce;
  item def StabilizingSupport;
  item def UserPositionIntent;
  item def BeltStatusSignal;
  item def FitAdjustment;

  port def GripPort {
    in forceFromCaregiver: CaregiverGripForce;
    out supportToCaregiver: StabilizingSupport;
  }

  port def BodyContactPort {
    in bodyLoad: HumanBodyLoad;
    out stabilizingSupport: StabilizingSupport;
  }

  port def AdjustmentPort {
    in adjustment: FitAdjustment;
    out status: BeltStatusSignal;
  }

  part def GaitBeltSystem {
    attribute primaryFunction: String =
      "Provide a secure handhold around a person torso so a caregiver can stabilize, guide, and assist the person during standing, walking, transfer, or fall prevention.";

    attribute ratedUserMass: kg = 136.0;
    attribute minimumWaistCircumference: cm = 61.0;
    attribute maximumWaistCircumference: cm = 132.0;
    attribute beltWidth: cm = 5.0;
    attribute allowableAssistForce: N = 450.0;
    attribute maximumFitGap: cm = 5.0;
    attribute nominalDonningTime: s = 20.0;

    port caregiverInterface: GripPort;
    port userTorsoInterface: BodyContactPort;
    port fitInterface: AdjustmentPort;

    part belt: BeltWebbing;
    part closure: ClosureAssembly;
    part handles[4]: AssistHandle;
    part label: SafetyLabel;
    part caregiver: Caregiver;
    part user: MobilityUser;

    connect caregiverInterface to handles.gripInterface;
    connect handles.loadInterface to belt.loadDistributionInterface;
    connect belt.bodyInterface to userTorsoInterface;
    connect closure.adjustmentInterface to fitInterface;
    connect belt.closureInterface to closure.webbingInterface;

    action assistMobility {
      in userLoad: HumanBodyLoad;
      in caregiverInput: CaregiverGripForce;
      out transferredSupport: StabilizingSupport;

      action confirmUserConsent;
      action positionBeltAroundTorso;
      action tightenBeltToTwoFingerFit;
      action lockClosure;
      action graspHandle;
      action guideUserMovement;
      action monitorSlipAndComfort;
      action releaseWhenStable;

      first start;
      then confirmUserConsent;
      then positionBeltAroundTorso;
      then tightenBeltToTwoFingerFit;
      then lockClosure;
      then graspHandle;
      then guideUserMovement;
      then monitorSlipAndComfort;
      then releaseWhenStable;
    }

    state usageLifecycle {
      state stored;
      state positioned;
      state fitted;
      state assisting;
      state removed;
      state outOfService;

      transition first stored;
      transition stored then positioned accept positionBelt;
      transition positioned then fitted accept tightenAndClose;
      transition fitted then assisting accept caregiverAppliesGripForce;
      transition assisting then fitted accept userStandingStable;
      transition fitted then removed accept removeBelt;
      transition positioned then removed accept cancelUse;
      transition fitted then outOfService accept damageDetected;
      transition assisting then outOfService accept unsafeSlipDetected;
      transition removed then stored accept cleanAndStore;
    }
  }

  part def BeltWebbing {
    attribute material: String = "woven nylon";
    attribute width: cm = 5.0;
    attribute length: cm = 152.0;
    attribute tensileCapacity: N = 1800.0;
    attribute edgeRadius: cm = 0.15;

    port bodyInterface: BodyContactPort;
    port loadDistributionInterface: GripPort;
    port closureInterface: AdjustmentPort;
  }

  part def ClosureAssembly {
    attribute closureType: String = "quick-release buckle with friction adjuster";
    attribute locked: Boolean = false;
    attribute slipLimitUnderLoad: cm = 2.0;
    attribute releaseForce: N = 35.0;

    port webbingInterface: AdjustmentPort;
    port adjustmentInterface: AdjustmentPort;

    action secureClosure {
      in adjustment: FitAdjustment;
      out status: BeltStatusSignal;

      action removeSlack;
      action routeWebbingThroughBuckle;
      action engageLatch;
      action verifyNoTwist;
      action verifyFitGap;

      first start;
      then removeSlack;
      then routeWebbingThroughBuckle;
      then engageLatch;
      then verifyNoTwist;
      then verifyFitGap;
    }
  }

  part def AssistHandle {
    attribute handleOpeningWidth: cm = 11.0;
    attribute handleOpeningHeight: cm = 4.0;
    attribute ratedGripForce: N = 450.0;
    attribute padded: Boolean = true;

    port gripInterface: GripPort;
    port loadInterface: GripPort;
  }

  part def SafetyLabel {
    attribute text: String =
      "Use only for mobility assistance and stabilization. Do not use to lift full body weight or restrain a person.";
    attribute cleaningInstruction: String = "wipe or launder according to facility infection-control procedure";
  }

  part def Caregiver {
    attribute trainedForUse: Boolean = true;
    attribute maximumSustainedAssistForce: N = 300.0;

    port handInterface: GripPort;
  }

  part def MobilityUser {
    attribute mass: kg = 82.0;
    attribute waistCircumference: cm = 94.0;
    attribute canBearPartialWeight: Boolean = true;
    attribute fallRiskLevel: String = "moderate";

    port torsoInterface: BodyContactPort;
  }

  requirement def PrimaryFunctionRequirement {
    subject system: GaitBeltSystem;

    require constraint {
      system.primaryFunction ==
      "Provide a secure handhold around a person torso so a caregiver can stabilize, guide, and assist the person during standing, walking, transfer, or fall prevention."
    }
  }

  requirement def FitRangeRequirement {
    subject system: GaitBeltSystem;

    require constraint {
      system.minimumWaistCircumference <= system.user.waistCircumference and
      system.user.waistCircumference <= system.maximumWaistCircumference
    }
  }

  requirement def LoadSupportRequirement {
    subject system: GaitBeltSystem;

    require constraint {
      system.user.mass <= system.ratedUserMass and
      system.allowableAssistForce <= system.belt.tensileCapacity
    }
  }

  requirement def ClosureSecurityRequirement {
    subject system: GaitBeltSystem;

    require constraint {
      system.closure.slipLimitUnderLoad <= 2.0
    }
  }

  requirement def SafeUseRequirement {
    subject system: GaitBeltSystem;

    require constraint {
      system.user.canBearPartialWeight == true and
      system.caregiver.trainedForUse == true
    }
  }

  requirement def ComfortAndPlacementRequirement {
    subject system: GaitBeltSystem;

    require constraint {
      system.beltWidth >= 4.0 and
      system.maximumFitGap <= 5.0
    }
  }

  part gaitBeltAssistSystem: GaitBeltSystem;

}