package StrawSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def LengthValue {
    :>> scalar : Real;
    unit = m;
  }

  value def DiameterValue {
    :>> scalar : Real;
    unit = m;
  }

  value def AreaValue {
    :>> scalar : Real;
    unit = m^2;
  }

  value def VolumeFlowRateValue {
    :>> scalar : Real;
    unit = m^3 / s;
  }

  value def PressureValue {
    :>> scalar : Real;
    unit = Pa;
  }

  value def ForceValue {
    :>> scalar : Real;
    unit = N;
  }

  value def AngleValue {
    :>> scalar : Real;
    unit = rad;
  }

  value def TemperatureValue {
    :>> scalar : Real;
    unit = K;
  }

  value def MassValue {
    :>> scalar : Real;
    unit = kg;
  }

  enum def MaterialKind {
    enum paper;
    enum polypropylene;
    enum stainlessSteel;
    enum silicone;
    enum bamboo;
  }

  enum def FluidKind {
    enum water;
    enum juice;
    enum milkshake;
    enum soda;
    enum coffee;
    enum air;
  }

  item def Beverage {
    attribute fluidKind : FluidKind;
    attribute temperature : TemperatureValue;
    attribute dynamicViscosity : Real;
    attribute density : Real;
  }

  item def Air {
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
  }

  item def SuctionPressure {
    attribute pressureDrop : PressureValue;
  }

  item def SipFlow {
    attribute flowRate : VolumeFlowRateValue;
    attribute fluidKind : FluidKind;
  }

  port def FluidPort {
    in item suction : SuctionPressure;
    out item beverageFlow : SipFlow;
  }

  port def MouthPort {
    out item suction : SuctionPressure;
    in item beverageFlow : SipFlow;
  }

  port def ImmersionPort {
    in item beverage : Beverage;
    out item beverageFlow : SipFlow;
  }

  port def VentPort {
    in item surroundingAir : Air;
  }

  port def MechanicalSupportPort {
    in item appliedLoad : ForceValue;
  }

  part def DrinkingStraw {
    attribute material : MaterialKind = MaterialKind::paper;
    attribute totalLength : LengthValue = 0.210 [m];
    attribute outerDiameter : DiameterValue = 0.0075 [m];
    attribute innerDiameter : DiameterValue = 0.0060 [m];
    attribute wallThickness : LengthValue = 0.00075 [m];
    attribute internalFlowArea : AreaValue = 0.0000283 [m^2];
    attribute maximumRecommendedPressureDrop : PressureValue = 12000 [Pa];
    attribute maximumBendAngle : AngleValue = 0.785 [rad];
    attribute dryMass : MassValue = 0.0012 [kg];

    port mouthEnd : FluidPort;
    port drinkEnd : FluidPort;
    port ambientVent : VentPort;
    port sideLoadInterface : MechanicalSupportPort;

    part mouthpiece {
      attribute exposedLength : LengthValue = 0.035 [m];
      attribute lipContactDiameter : DiameterValue = 0.0075 [m];
      attribute roundedEdgeRadius : LengthValue = 0.0005 [m];
    }

    part tubularBody {
      attribute flowPathLength : LengthValue = 0.175 [m];
      attribute boreDiameter : DiameterValue = 0.0060 [m];
      attribute nominalStraightnessTolerance : LengthValue = 0.002 [m];
    }

    part intakeTip {
      attribute submergedLength : LengthValue = 0.025 [m];
      attribute cutAngle : AngleValue = 0.349 [rad];
      attribute inletOpeningArea : AreaValue = 0.0000300 [m^2];
    }

    part optionalFlexibleSection {
      attribute isPresent : Boolean = true;
      attribute corrugationCount : Integer = 18;
      attribute bendRadiusMinimum : LengthValue = 0.018 [m];
      attribute currentBendAngle : AngleValue = 0.0 [rad];
    }

    connect mouthpiece to tubularBody;
    connect tubularBody to intakeTip;
    connect mouthEnd to mouthpiece;
    connect drinkEnd to intakeTip;

    action transmitBeverage {
      in item inletBeverage : Beverage;
      in item suction : SuctionPressure;
      out item deliveredFlow : SipFlow;

      first start;
      then evaluatePressureDrop;
      then drawFluid;
      then deliverToMouth;
      then done;

      action evaluatePressureDrop {
        in item suction : SuctionPressure;
      }

      action drawFluid {
        in item inletBeverage : Beverage;
        out item internalFlow : SipFlow;
      }

      action deliverToMouth {
        in item internalFlow : SipFlow;
        out item deliveredFlow : SipFlow;
      }
    }

    state def StrawOperationalState {
      entry action initialize {
        optionalFlexibleSection.currentBendAngle = 0.0 [rad];
      }

      state DryIdle;
      state InsertedInBeverage;
      state Sipping;
      state Draining;
      state Blocked;
      state Deformed;
      state Disposed;

      transition first DryIdle;

      transition DryIdle_to_Inserted
        first DryIdle
        then InsertedInBeverage
        accept BeverageDetected;

      transition Inserted_to_Sipping
        first InsertedInBeverage
        then Sipping
        accept SuctionApplied;

      transition Sipping_to_Inserted
        first Sipping
        then InsertedInBeverage
        accept SuctionReleased;

      transition Sipping_to_Blocked
        first Sipping
        then Blocked
        accept FlowObstructed;

      transition Blocked_to_Inserted
        first Blocked
        then InsertedInBeverage
        accept ObstructionCleared;

      transition Inserted_to_Deformed
        first InsertedInBeverage
        then Deformed
        accept ExcessiveSideLoad;

      transition Sipping_to_Deformed
        first Sipping
        then Deformed
        accept ExcessiveBend;

      transition Inserted_to_Draining
        first InsertedInBeverage
        then Draining
        accept RemovedFromBeverage;

      transition Draining_to_DryIdle
        first Draining
        then DryIdle
        accept InternalFluidDrained;

      transition DryIdle_to_Disposed
        first DryIdle
        then Disposed
        accept Discarded;
    }
  }

  part def BeverageContainer {
    attribute beverageDepth : LengthValue = 0.110 [m];
    attribute rimHeight : LengthValue = 0.120 [m];
    attribute internalPressure : PressureValue = 101325 [Pa];

    port beverageInterface : ImmersionPort;
    port headspaceVent : VentPort;

    part beverageReservoir {
      item containedBeverage : Beverage {
        fluidKind = FluidKind::water;
        temperature = 295.15 [K];
        dynamicViscosity = 0.001;
        density = 997.0;
      }
    }

    part headspace {
      item air : Air {
        pressure = 101325 [Pa];
        temperature = 295.15 [K];
      }
    }
  }

  part def HumanUser {
    attribute typicalSuctionPressureDrop : PressureValue = 3500 [Pa];
    attribute maximumComfortableSuctionPressureDrop : PressureValue = 9000 [Pa];

    port mouth : MouthPort;

    action sipThroughStraw {
      out item generatedSuction : SuctionPressure;
      in item receivedFlow : SipFlow;

      first formSealAroundMouthpiece;
      then reduceMouthPressure;
      then ingestDeliveredBeverage;
      then releaseSuction;

      action formSealAroundMouthpiece;
      action reduceMouthPressure {
        out item generatedSuction : SuctionPressure;
      }
      action ingestDeliveredBeverage {
        in item receivedFlow : SipFlow;
      }
      action releaseSuction;
    }
  }

  part def StrawBasedDrinkingSystem {
    attribute primaryFunction : String =
      "Provide a passive tubular flow path that transfers beverage from a container to a user's mouth when the user applies suction.";

    part straw : DrinkingStraw {
      material = MaterialKind::paper;
      totalLength = 0.210 [m];
      innerDiameter = 0.0060 [m];
      outerDiameter = 0.0075 [m];
    }

    part cup : BeverageContainer;
    part user : HumanUser;

    connect user.mouth.suction to straw.mouthEnd.suction;
    connect straw.mouthEnd.beverageFlow to user.mouth.beverageFlow;
    connect cup.beverageInterface.beverageFlow to straw.drinkEnd.beverageFlow;
    connect straw.drinkEnd.suction to cup.beverageInterface.beverageFlow;
    connect cup.headspaceVent to straw.ambientVent;

    action performPrimaryFunction {
      objective {
        doc /* Move drinkable liquid from the beverage reservoir through the straw bore and into the user's mouth by pressure differential generated by suction. */
      }

      first insertStrawTip;
      then sealMouthpiece;
      then applySuction;
      then transportBeverage;
      then deliverSip;
      then stopSipping;

      action insertStrawTip {
        out item availableBeverage : Beverage;
      }

      action sealMouthpiece;

      action applySuction {
        out item suction : SuctionPressure;
      }

      action transportBeverage {
        in item availableBeverage : Beverage;
        in item suction : SuctionPressure;
        out item sipFlow : SipFlow;
      }

      action deliverSip {
        in item sipFlow : SipFlow;
      }

      action stopSipping;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : StrawBasedDrinkingSystem;

    require constraint {
      system.primaryFunction ==
      "Provide a passive tubular flow path that transfers beverage from a container to a user's mouth when the user applies suction."
    }

    doc /* The straw system shall enable beverage transfer from a container to a user's mouth using user-generated suction as the driving pressure differential. */
  }

  requirement def FlowCapacityRequirement {
    subject straw : DrinkingStraw;

    attribute minimumSipFlowRate : VolumeFlowRateValue = 0.000003 [m^3 / s];
    attribute maximumComfortablePressureDrop : PressureValue = 9000 [Pa];

    require constraint {
      straw.innerDiameter >= 0.0045 [m] and
      straw.maximumRecommendedPressureDrop >= maximumComfortablePressureDrop
    }

    doc /* The straw shall provide adequate internal bore size to support normal sipping flow without requiring uncomfortable suction pressure. */
  }

  requirement def UserInterfaceRequirement {
    subject straw : DrinkingStraw;

    require constraint {
      straw.mouthpiece.lipContactDiameter <= 0.0090 [m] and
      straw.mouthpiece.roundedEdgeRadius >= 0.0003 [m]
    }

    doc /* The mouthpiece shall be sized and finished so that a user can seal lips around it comfortably during drinking. */
  }

  requirement def ImmersionRequirement {
    subject straw : DrinkingStraw;
    subject cup : BeverageContainer;

    require constraint {
      straw.intakeTip.submergedLength <= cup.beverageDepth and
      straw.totalLength > cup.rimHeight
    }

    doc /* The straw shall be long enough to extend above the container rim while allowing the intake tip to remain submerged in the beverage. */
  }

  requirement def StructuralIntegrityRequirement {
    subject straw : DrinkingStraw;

    attribute allowableSideLoad : ForceValue = 2.0 [N];

    require constraint {
      straw.wallThickness >= 0.0004 [m] and
      straw.optionalFlexibleSection.currentBendAngle <= straw.maximumBendAngle
    }

    doc /* The straw shall maintain a continuous open flow path under normal handling loads and normal bending during use. */
  }

  requirement def MaterialRequirement {
    subject straw : DrinkingStraw;

    require constraint {
      straw.material == MaterialKind::paper or
      straw.material == MaterialKind::polypropylene or
      straw.material == MaterialKind::stainlessSteel or
      straw.material == MaterialKind::silicone or
      straw.material == MaterialKind::bamboo
    }

    doc /* The straw shall be made from a material suitable for direct contact with beverages and the user's mouth. */
  }

  satisfy PrimaryFunctionRequirement by StrawBasedDrinkingSystem::performPrimaryFunction;
  satisfy FlowCapacityRequirement by DrinkingStraw::tubularBody;
  satisfy UserInterfaceRequirement by DrinkingStraw::mouthpiece;
  satisfy ImmersionRequirement by DrinkingStraw::intakeTip;
  satisfy StructuralIntegrityRequirement by DrinkingStraw::tubularBody;
  satisfy MaterialRequirement by DrinkingStraw;

}