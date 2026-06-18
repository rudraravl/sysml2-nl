package TrussBasedSupportSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Length :> Real {
    doc "Unit: metre (m)."
  }

  attribute def Area :> Real {
    doc "Unit: square metre (m^2)."
  }

  attribute def Volume :> Real {
    doc "Unit: cubic metre (m^3)."
  }

  attribute def Mass :> Real {
    doc "Unit: kilogram (kg)."
  }

  attribute def Density :> Real {
    doc "Unit: kilogram per cubic metre (kg/m^3)."
  }

  attribute def Force :> Real {
    doc "Unit: kilonewton (kN)."
  }

  attribute def Moment :> Real {
    doc "Unit: kilonewton metre (kN*m)."
  }

  attribute def Pressure :> Real {
    doc "Unit: megapascal (MPa)."
  }

  attribute def Stiffness :> Real {
    doc "Unit: kilonewton per metre (kN/m)."
  }

  attribute def DistributedLoad :> Real {
    doc "Unit: kilonewton per metre (kN/m)."
  }

  attribute def Acceleration :> Real {
    doc "Unit: metre per second squared (m/s^2)."
  }

  attribute def Ratio :> Real {
    doc "Unit: dimensionless."
  }

  attribute def Temperature :> Real {
    doc "Unit: degree Celsius (degC)."
  }

  attribute def TimeDuration :> Real {
    doc "Unit: second (s)."
  }

  attribute def Frequency :> Real {
    doc "Unit: hertz (Hz)."
  }

  enum def MemberRole {
    enum chord;
    enum verticalWeb;
    enum diagonalWeb;
    enum lateralBrace;
  }

  enum def MaterialGrade {
    enum structuralSteelS355;
    enum structuralSteelS460;
    enum aluminum6082T6;
    enum timberGlulamGL32;
  }

  enum def LoadCategory {
    enum deadLoad;
    enum liveLoad;
    enum windLoad;
    enum seismicLoad;
    enum maintenanceLoad;
    enum thermalLoad;
  }

  item def ForceVector {
    attribute fx : Force = 0.0;
    attribute fy : Force = 0.0;
    attribute fz : Force = 0.0;
  }

  item def MomentVector {
    attribute mx : Moment = 0.0;
    attribute my : Moment = 0.0;
    attribute mz : Moment = 0.0;
  }

  item def LoadCase {
    attribute category : LoadCategory;
    attribute totalVerticalForce : Force;
    attribute totalLateralForce : Force = 0.0;
    attribute distributedVerticalLoad : DistributedLoad;
    attribute eccentricMoment : Moment = 0.0;
    attribute loadDuration : TimeDuration;
    attribute dynamicAmplification : Ratio = 1.0;
  }

  item def PanelPointLoad {
    attribute verticalForce : Force;
    attribute lateralForce : Force = 0.0;
    attribute longitudinalForce : Force = 0.0;
    attribute panelIndex : Integer;
  }

  item def SupportReaction {
    attribute verticalReaction : Force;
    attribute horizontalReaction : Force;
    attribute longitudinalReaction : Force = 0.0;
    attribute reactionMoment : Moment = 0.0;
  }

  item def ReactionSet {
    item left : SupportReaction;
    item right : SupportReaction;
    attribute resultantVertical : Force;
    attribute resultantHorizontal : Force;
  }

  item def AxialMemberForce {
    attribute tensionPositiveForce : Force;
    attribute utilizationRatio : Ratio;
    attribute memberIdentifier : String;
  }

  item def HealthStatus {
    attribute measuredDeflection : Length;
    attribute maximumMemberUtilization : Ratio;
    attribute detectedCrackLength : Length = 0.0;
    attribute corrosionLossRatio : Ratio = 0.0;
    attribute serviceable : Boolean;
  }

  item def InspectionReport {
    item status : HealthStatus;
    attribute inspectionTime : TimeDuration;
    attribute recommendedRepairRequired : Boolean;
  }

  port def StructuralPinPort {
    inout item axialShearForce : ForceVector;
    inout item endMoment : MomentVector;
  }

  port def LoadInputPort {
    in item appliedLoad : LoadCase;
  }

  port def PanelLoadPort {
    out item panelLoad : PanelPointLoad;
  }

  port def JointLoadPort {
    in item panelLoad : PanelPointLoad;
    inout item jointForce : ForceVector;
  }

  port def BearingReactionPort {
    in item jointForce : ForceVector;
    out item reaction : SupportReaction;
  }

  port def FoundationPort {
    in item reaction : SupportReaction;
  }

  port def HealthMonitoringPort {
    out item health : HealthStatus;
    out item inspection : InspectionReport;
  }

  port def EnvironmentPort {
    in attribute ambientTemperature : Temperature;
    in attribute windPressure : Pressure;
    in attribute groundAcceleration : Acceleration;
  }

  constraint def AxialStressLimit {
    in axialForce : Force;
    in crossSectionalArea : Area;
    in allowableStress : Pressure;
    require constraint { abs(axialForce) / crossSectionalArea <= allowableStress }
  }

  constraint def MemberUtilizationLimit {
    in utilizationRatio : Ratio;
    in limitRatio : Ratio = 1.0;
    require constraint { utilizationRatio <= limitRatio }
  }

  constraint def VerticalEquilibrium {
    in appliedVerticalForce : Force;
    in leftVerticalReaction : Force;
    in rightVerticalReaction : Force;
    require constraint { leftVerticalReaction + rightVerticalReaction >= appliedVerticalForce }
  }

  constraint def DeflectionLimit {
    in actualDeflection : Length;
    in span : Length;
    in denominator : Real = 360.0;
    require constraint { actualDeflection <= span / denominator }
  }

  constraint def NaturalFrequencyLimit {
    in firstVerticalFrequency : Frequency;
    in minimumFrequency : Frequency = 3.0;
    require constraint { firstVerticalFrequency >= minimumFrequency }
  }

  calc def EstimateMidspanDeflection {
    in totalVerticalForce : Force;
    in span : Length;
    in elasticModulus : Pressure;
    in chordArea : Area;
    in trussDepth : Length;
    return estimatedDeflection : Length;
    constraint { estimatedDeflection == totalVerticalForce * span * span * span / (48.0 * elasticModulus * chordArea * trussDepth * trussDepth) }
  }

  action def CollectDeckLoad {
    in item loadCase : LoadCase;
    out item panel0 : PanelPointLoad;
    out item panel1 : PanelPointLoad;
    out item panel2 : PanelPointLoad;
    out item panel3 : PanelPointLoad;
    out item panel4 : PanelPointLoad;
    out item panel5 : PanelPointLoad;
    out item panel6 : PanelPointLoad;
  }

  action def ResolveTrussForces {
    in item panel0 : PanelPointLoad;
    in item panel1 : PanelPointLoad;
    in item panel2 : PanelPointLoad;
    in item panel3 : PanelPointLoad;
    in item panel4 : PanelPointLoad;
    in item panel5 : PanelPointLoad;
    in item panel6 : PanelPointLoad;
    out item memberForce[25] : AxialMemberForce;
    out item reactions : ReactionSet;
  }

  action def TransferLoadToFoundations {
    in item reactions : ReactionSet;
    out item leftBearingReaction : SupportReaction;
    out item rightBearingReaction : SupportReaction;
  }

  action def AssessStructuralHealth {
    in item memberForce[25] : AxialMemberForce;
    in measuredDeflection : Length;
    in corrosionLossRatio : Ratio;
    out item health : HealthStatus;
  }

  action def PrimaryTrussFunction {
    doc "Primary high-level function: receive external loads over a span, distribute them to panel points, carry them mainly as axial tension and compression through truss members, and deliver balanced reactions to end supports while maintaining serviceable deflection and structural integrity."
    in item serviceLoad : LoadCase;
    in measuredMidspanDeflection : Length;
    in corrosionLossRatio : Ratio;
    out item supportReactions : ReactionSet;
    out item health : HealthStatus;

    action collect : CollectDeckLoad;
    action resolve : ResolveTrussForces;
    action transfer : TransferLoadToFoundations;
    action assess : AssessStructuralHealth;

    flow serviceLoad to collect.loadCase;
    flow collect.panel0 to resolve.panel0;
    flow collect.panel1 to resolve.panel1;
    flow collect.panel2 to resolve.panel2;
    flow collect.panel3 to resolve.panel3;
    flow collect.panel4 to resolve.panel4;
    flow collect.panel5 to resolve.panel5;
    flow collect.panel6 to resolve.panel6;
    flow resolve.reactions to transfer.reactions;
    flow resolve.reactions to supportReactions;
    flow resolve.memberForce to assess.memberForce;
    flow measuredMidspanDeflection to assess.measuredDeflection;
    flow corrosionLossRatio to assess.corrosionLossRatio;
    flow assess.health to health;

    first start;
    then collect;
    then resolve;
    then transfer;
    then assess;
    then done;
  }

  state def TrussServiceStateMachine {
    state Unloaded;
    state Loading;
    state ServiceLoadBearing;
    state OverloadDetected;
    state InspectionRequired;
    state RepairLockedOut;

    transition initialToUnloaded first start then Unloaded;
    transition beginLoading first Unloaded then Loading accept LoadCase;
    transition loadingToService first Loading then ServiceLoadBearing;
    transition removeLoad first ServiceLoadBearing then Unloaded;
    transition overload first ServiceLoadBearing then OverloadDetected;
    transition overloadInspection first OverloadDetected then InspectionRequired;
    transition damageFound first InspectionRequired then RepairLockedOut;
    transition inspectionPass first InspectionRequired then Unloaded;
    transition repairComplete first RepairLockedOut then Unloaded;
  }

  part def StructuralMaterial {
    attribute grade : MaterialGrade;
    attribute density : Density;
    attribute elasticModulus : Pressure;
    attribute yieldStrength : Pressure;
    attribute ultimateStrength : Pressure;
    attribute thermalExpansionCoefficient : Real;
  }

  part def TrussMember {
    attribute memberId : String;
    attribute role : MemberRole;
    attribute length : Length;
    attribute crossSectionalArea : Area;
    attribute radiusOfGyration : Length;
    attribute mass : Mass;
    attribute allowableTension : Force;
    attribute allowableCompression : Force;
    attribute axialStiffness : Stiffness;
    attribute currentAxialForce : Force = 0.0;
    attribute utilization : Ratio = 0.0;
    attribute corrosionAllowanceRatio : Ratio = 0.05;

    part material : StructuralMaterial;

    port endA : StructuralPinPort;
    port endB : StructuralPinPort;

    constraint stressOk : AxialStressLimit {
      in axialForce = currentAxialForce;
      in crossSectionalArea = crossSectionalArea;
      in allowableStress = material.yieldStrength;
    }

    constraint utilizationOk : MemberUtilizationLimit {
      in utilizationRatio = utilization;
    }
  }

  part def ChordSegment :> TrussMember {
    attribute role : MemberRole = MemberRole::chord;
    attribute flangeWidth : Length;
    attribute webThickness : Length;
    attribute primaryForceMode : String = "axial tension or axial compression along the span";
  }

  part def WebSegment :> TrussMember {
    attribute role : MemberRole;
    attribute slendernessRatio : Ratio;
    attribute primaryForceMode : String = "axial force between upper and lower panel points";
  }

  part def LateralBrace :> TrussMember {
    attribute role : MemberRole = MemberRole::lateralBrace;
    attribute primaryForceMode : String = "lateral stabilization and out-of-plane buckling restraint";
  }

  part def GussetJoint {
    attribute jointId : String;
    attribute plateThickness : Length;
    attribute boltCount : Integer;
    attribute boltDiameter : Length;
    attribute jointCapacity : Force;
    attribute jointUtilization : Ratio = 0.0;

    port member1 : StructuralPinPort;
    port member2 : StructuralPinPort;
    port member3 : StructuralPinPort;
    port member4 : StructuralPinPort;
    port member5 : StructuralPinPort;
    port member6 : StructuralPinPort;
    port loadPort : JointLoadPort;
    port supportPort : BearingReactionPort;

    constraint jointUtilizationOk : MemberUtilizationLimit {
      in utilizationRatio = jointUtilization;
    }
  }

  part def ElastomericBearing {
    attribute bearingId : String;
    attribute verticalStiffness : Stiffness;
    attribute horizontalStiffness : Stiffness;
    attribute rotationCapacity : Ratio;
    attribute verticalCapacity : Force;
    attribute horizontalCapacity : Force;

    port structurePort : BearingReactionPort;
    port foundationPort : FoundationPort;
  }

  part def FoundationInterface {
    attribute foundationId : String;
    attribute allowableBearingPressure : Pressure;
    attribute settlementLimit : Length;
    attribute currentSettlement : Length = 0.0;

    port bearingPort : FoundationPort;
  }

  part def DeckLoadCollector {
    attribute deckLength : Length;
    attribute tributaryWidth : Length;
    attribute deadLoadIntensity : DistributedLoad;
    attribute liveLoadIntensity : DistributedLoad;
    attribute wearingSurfaceLoad : DistributedLoad;
    attribute loadDistributionDescription : String = "Deck loads are idealized as vertical panel point loads applied at lower chord joints.";

    port loadInput : LoadInputPort;
    port panelPoint0 : PanelLoadPort;
    port panelPoint1 : PanelLoadPort;
    port panelPoint2 : PanelLoadPort;
    port panelPoint3 : PanelLoadPort;
    port panelPoint4 : PanelLoadPort;
    port panelPoint5 : PanelLoadPort;
    port panelPoint6 : PanelLoadPort;
  }

  part def TrussHealthMonitor {
    attribute samplePeriod : TimeDuration;
    attribute deflectionAlarmThreshold : Length;
    attribute utilizationAlarmThreshold : Ratio;
    attribute corrosionAlarmThreshold : Ratio;
    attribute currentHealth : HealthStatus;

    port healthPort : HealthMonitoringPort;
  }

  part def TrussSupportSystem {
    doc "A truss-based structural support system whose primary function is to span between two supports and transfer applied deck, environmental, and service loads to the foundations through triangulated axial-force members."

    attribute span : Length = 30.0;
    attribute trussDepth : Length = 4.5;
    attribute panelLength : Length = 5.0;
    attribute numberOfPanels : Integer = 6;
    attribute designVerticalLoadCapacity : Force = 1800.0;
    attribute serviceVerticalLoad : Force = 1200.0;
    attribute maximumServiceDeflection : Length = 0.083;
    attribute firstVerticalNaturalFrequency : Frequency = 4.2;
    attribute designLife : TimeDuration = 1576800000.0;
    attribute primaryFunctionStatement : String = "Support loads across a clear span by converting bending demand into axial forces in chord and web members, then transfer reactions into end bearings and foundations.";

    port externalLoadPort : LoadInputPort;
    port leftFoundationPort : FoundationPort;
    port rightFoundationPort : FoundationPort;
    port healthOutputPort : HealthMonitoringPort;
    port environmentPort : EnvironmentPort;

    part steelS355 : StructuralMaterial {
      :>> grade = MaterialGrade::structuralSteelS355;
      :>> density = 7850.0;
      :>> elasticModulus = 210000.0;
      :>> yieldStrength = 355.0;
      :>> ultimateStrength = 510.0;
      :>> thermalExpansionCoefficient = 0.000012;
    }

    part deck : DeckLoadCollector {
      :>> deckLength = 30.0;
      :>> tributaryWidth = 3.0;
      :>> deadLoadIntensity = 18.0;
      :>> liveLoadIntensity = 22.0;
      :>> wearingSurfaceLoad = 4.0;
    }

    part monitor : TrussHealthMonitor {
      :>> samplePeriod = 1.0;
      :>> deflectionAlarmThreshold = 0.083;
      :>> utilizationAlarmThreshold = 0.95;
      :>> corrosionAlarmThreshold = 0.10;
    }

    part leftBearing : ElastomericBearing {
      :>> bearingId = "BRG-L";
      :>> verticalStiffness = 250000.0;
      :>> horizontalStiffness = 15000.0;
      :>> rotationCapacity = 0.035;
      :>> verticalCapacity = 1200.0;
      :>> horizontalCapacity = 250.0;
    }

    part rightBearing : ElastomericBearing {
      :>> bearingId = "BRG-R";
      :>> verticalStiffness = 250000.0;
      :>> horizontalStiffness = 8000.0;
      :>> rotationCapacity = 0.035;
      :>> verticalCapacity = 1200.0;
      :>> horizontalCapacity = 250.0;
    }

    part leftFoundation : FoundationInterface {
      :>> foundationId = "FDN-L";
      :>> allowableBearingPressure = 450.0;
      :>> settlementLimit = 0.020;
    }

    part rightFoundation : FoundationInterface {
      :>> foundationId = "FDN-R";
      :>> allowableBearingPressure = 450.0;
      :>> settlementLimit = 0.020;
    }

    part jointL0 : GussetJoint { :>> jointId = "L0"; :>> plateThickness = 0.020; :>> boltCount = 16; :>> boltDiameter = 0.024; :>> jointCapacity = 900.0; }
    part jointL1 : GussetJoint { :>> jointId = "L1"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointL2 : GussetJoint { :>> jointId = "L2"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointL3 : GussetJoint { :>> jointId = "L3"; :>> plateThickness = 0.018; :>> boltCount = 16; :>> boltDiameter = 0.024; :>> jointCapacity = 840.0; }
    part jointL4 : GussetJoint { :>> jointId = "L4"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointL5 : GussetJoint { :>> jointId = "L5"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointL6 : GussetJoint { :>> jointId = "L6"; :>> plateThickness = 0.020; :>> boltCount = 16; :>> boltDiameter = 0.024; :>> jointCapacity = 900.0; }

    part jointU0 : GussetJoint { :>> jointId = "U0"; :>> plateThickness = 0.018; :>> boltCount = 12; :>> boltDiameter = 0.024; :>> jointCapacity = 720.0; }
    part jointU1 : GussetJoint { :>> jointId = "U1"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointU2 : GussetJoint { :>> jointId = "U2"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointU3 : GussetJoint { :>> jointId = "U3"; :>> plateThickness = 0.020; :>> boltCount = 16; :>> boltDiameter = 0.024; :>> jointCapacity = 840.0; }
    part jointU4 : GussetJoint { :>> jointId = "U4"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointU5 : GussetJoint { :>> jointId = "U5"; :>> plateThickness = 0.018; :>> boltCount = 14; :>> boltDiameter = 0.024; :>> jointCapacity = 780.0; }
    part jointU6 : GussetJoint { :>> jointId = "U6"; :>> plateThickness = 0.018; :>> boltCount = 12; :>> boltDiameter = 0.024; :>> jointCapacity = 720.0; }

    part lowerChord01 : ChordSegment { :>> memberId = "LC01"; :>> length = 5.0; :>> crossSectionalArea = 0.018; :>> radiusOfGyration = 0.095; :>> allowableTension = 1650.0; :>> allowableCompression = 1400.0; :>> axialStiffness = 756000.0; :>> flangeWidth = 0.300; :>> webThickness = 0.014; part redefines material = steelS355; }
    part lowerChord12 : ChordSegment { :>> memberId = "LC12"; :>> length = 5.0; :>> crossSectionalArea = 0.018; :>> radiusOfGyration = 0.095; :>> allowableTension = 1650.0; :>> allowableCompression = 1400.0; :>> axialStiffness = 756000.0; :>> flangeWidth = 0.300; :>> webThickness = 0.014; part redefines material = steelS355; }
    part lowerChord23 : ChordSegment { :>> memberId = "LC23"; :>> length = 5.0; :>> crossSectionalArea = 0.020; :>> radiusOfGyration = 0.100; :>> allowableTension = 1800.0; :>> allowableCompression = 1500.0; :>> axialStiffness = 840000.0; :>> flangeWidth = 0.320; :>> webThickness = 0.016; part redefines material = steelS355; }
    part lowerChord34 : ChordSegment { :>> memberId = "LC34"; :>> length = 5.0; :>> crossSectionalArea = 0.020; :>> radiusOfGyration = 0.100; :>> allowableTension = 1800.0; :>> allowableCompression = 1500.0; :>> axialStiffness = 840000.0; :>> flangeWidth = 0.320; :>> webThickness = 0.016; part redefines material = steelS355; }
    part lowerChord45 : ChordSegment { :>> memberId = "LC45"; :>> length = 5.0; :>> crossSectionalArea = 0.018; :>> radiusOfGyration = 0.095; :>> allowableTension = 1650.0; :>> allowableCompression = 1400.0; :>> axialStiffness = 756000.0; :>> flangeWidth = 0.300; :>> webThickness = 0.014; part redefines material = steelS355; }
    part lowerChord56 : ChordSegment { :>> memberId = "LC56"; :>> length = 5.0; :>> crossSectionalArea = 0.018; :>> radiusOfGyration = 0.095; :>> allowableTension = 1650.0; :>> allowableCompression = 1400.0; :>> axialStiffness = 756000.0; :>> flangeWidth = 0.300; :>> webThickness = 0.014; part redefines material = steelS355; }

    part upperChord01 : ChordSegment { :>> memberId = "UC01"; :>> length = 5.0; :>> crossSectionalArea = 0.020; :>> radiusOfGyration = 0.110; :>> allowableTension = 1750.0; :>> allowableCompression = 1650.0; :>> axialStiffness = 840000.0; :>> flangeWidth = 0.340; :>> webThickness = 0.016; part redefines material = steelS355; }
    part upperChord12 : ChordSegment { :>> memberId = "UC12"; :>> length = 5.0; :>> crossSectionalArea = 0.022; :>> radiusOfGyration = 0.115; :>> allowableTension = 1900.0; :>> allowableCompression = 1750.0; :>> axialStiffness = 924000.0; :>> flangeWidth = 0.360; :>> webThickness = 0.018; part redefines material = steelS355; }
    part upperChord23 : ChordSegment { :>> memberId = "UC23"; :>> length = 5.0; :>> crossSectionalArea = 0.024; :>> radiusOfGyration = 0.120; :>> allowableTension = 2050.0; :>> allowableCompression = 1850.0; :>> axialStiffness = 1008000.0; :>> flangeWidth = 0.380; :>> webThickness = 0.018; part redefines material = steelS355; }
    part upperChord34 : ChordSegment { :>> memberId = "UC34"; :>> length = 5.0; :>> crossSectionalArea = 0.024; :>> radiusOfGyration = 0.120; :>> allowableTension = 2050.0; :>> allowableCompression = 1850.0; :>> axialStiffness = 1008000.0; :>> flangeWidth = 0.380; :>> webThickness = 0.018; part redefines material = steelS355; }
    part upperChord45 : ChordSegment { :>> memberId = "UC45"; :>> length = 5.0; :>> crossSectionalArea = 0.022; :>> radiusOfGyration = 0.115; :>> allowableTension = 1900.0; :>> allowableCompression = 1750.0; :>> axialStiffness = 924000.0; :>> flangeWidth = 0.360; :>> webThickness = 0.018; part redefines material = steelS355; }
    part upperChord56 : ChordSegment { :>> memberId = "UC56"; :>> length = 5.0; :>> crossSectionalArea = 0.020; :>> radiusOfGyration = 0.110; :>> allowableTension = 1750.0; :>> allowableCompression = 1650.0; :>> axialStiffness = 840000.0; :>> flangeWidth = 0.340; :>> webThickness = 0.016; part redefines material = steelS355; }

    part vertical0 : WebSegment { :>> memberId = "V0"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.010; :>> radiusOfGyration = 0.070; :>> allowableTension = 900.0; :>> allowableCompression = 650.0; :>> axialStiffness = 466667.0; :>> slendernessRatio = 64.3; part redefines material = steelS355; }
    part vertical1 : WebSegment { :>> memberId = "V1"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.010; :>> radiusOfGyration = 0.070; :>> allowableTension = 900.0; :>> allowableCompression = 650.0; :>> axialStiffness = 466667.0; :>> slendernessRatio = 64.3; part redefines material = steelS355; }
    part vertical2 : WebSegment { :>> memberId = "V2"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.075; :>> allowableTension = 1050.0; :>> allowableCompression = 750.0; :>> axialStiffness = 560000.0; :>> slendernessRatio = 60.0; part redefines material = steelS355; }
    part vertical3 : WebSegment { :>> memberId = "V3"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.075; :>> allowableTension = 1050.0; :>> allowableCompression = 750.0; :>> axialStiffness = 560000.0; :>> slendernessRatio = 60.0; part redefines material = steelS355; }
    part vertical4 : WebSegment { :>> memberId = "V4"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.075; :>> allowableTension = 1050.0; :>> allowableCompression = 750.0; :>> axialStiffness = 560000.0; :>> slendernessRatio = 60.0; part redefines material = steelS355; }
    part vertical5 : WebSegment { :>> memberId = "V5"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.010; :>> radiusOfGyration = 0.070; :>> allowableTension = 900.0; :>> allowableCompression = 650.0; :>> axialStiffness = 466667.0; :>> slendernessRatio = 64.3; part redefines material = steelS355; }
    part vertical6 : WebSegment { :>> memberId = "V6"; :>> role = MemberRole::verticalWeb; :>> length = 4.5; :>> crossSectionalArea = 0.010; :>> radiusOfGyration = 0.070; :>> allowableTension = 900.0; :>> allowableCompression = 650.0; :>> axialStiffness = 466667.0; :>> slendernessRatio = 64.3; part redefines material = steelS355; }

    part diagonal01 : WebSegment { :>> memberId = "D01"; :>> role = MemberRole::diagonalWeb; :>> length = 6.73; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.080; :>> allowableTension = 1050.0; :>> allowableCompression = 720.0; :>> axialStiffness = 374443.0; :>> slendernessRatio = 84.1; part redefines material = steelS355; }
    part diagonal12 : WebSegment { :>> memberId = "D12"; :>> role = MemberRole::diagonalWeb; :>> length = 6.73; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.080; :>> allowableTension = 1050.0; :>> allowableCompression = 720.0; :>> axialStiffness = 374443.0; :>> slendernessRatio = 84.1; part redefines material = steelS355; }
    part diagonal23 : WebSegment { :>> memberId = "D23"; :>> role = MemberRole::diagonalWeb; :>> length = 6.73; :>> crossSectionalArea = 0.014; :>> radiusOfGyration = 0.085; :>> allowableTension = 1250.0; :>> allowableCompression = 850.0; :>> axialStiffness = 436850.0; :>> slendernessRatio = 79.2; part redefines material = steelS355; }
    part diagonal34 : WebSegment { :>> memberId = "D34"; :>> role = MemberRole::diagonalWeb; :>> length = 6.73; :>> crossSectionalArea = 0.014; :>> radiusOfGyration = 0.085; :>> allowableTension = 1250.0; :>> allowableCompression = 850.0; :>> axialStiffness = 436850.0; :>> slendernessRatio = 79.2; part redefines material = steelS355; }
    part diagonal45 : WebSegment { :>> memberId = "D45"; :>> role = MemberRole::diagonalWeb; :>> length = 6.73; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.080; :>> allowableTension = 1050.0; :>> allowableCompression = 720.0; :>> axialStiffness = 374443.0; :>> slendernessRatio = 84.1; part redefines material = steelS355; }
    part diagonal56 : WebSegment { :>> memberId = "D56"; :>> role = MemberRole::diagonalWeb; :>> length = 6.73; :>> crossSectionalArea = 0.012; :>> radiusOfGyration = 0.080; :>> allowableTension = 1050.0; :>> allowableCompression = 720.0; :>> axialStiffness = 374443.0; :>> slendernessRatio = 84.1; part redefines material = steelS355; }

    part topLateralBraceA : LateralBrace { :>> memberId = "TLB-A"; :>> length = 30.0; :>> crossSectionalArea = 0.006; :>> radiusOfGyration = 0.055; :>> allowableTension = 420.0; :>> allowableCompression = 240.0; :>> axialStiffness = 42000.0; part redefines material = steelS355; }
    part bottomLateralBraceA : LateralBrace { :>> memberId = "BLB-A"; :>> length = 30.0; :>> crossSectionalArea = 0.006; :>> radiusOfGyration = 0.055; :>> allowableTension = 420.0; :>> allowableCompression = 240.0; :>> axialStiffness = 42000.0; part redefines material = steelS355; }

    perform action supportLoads : PrimaryTrussFunction;
    exhibit state serviceStates : TrussServiceStateMachine;

    constraint staticVerticalEquilibrium : VerticalEquilibrium {
      in appliedVerticalForce = serviceVerticalLoad;
      in leftVerticalReaction = serviceVerticalLoad / 2.0;
      in rightVerticalReaction = serviceVerticalLoad / 2.0;
    }

    constraint deflectionServiceLimit : DeflectionLimit {
      in actualDeflection = maximumServiceDeflection;
      in span = span;
      in denominator = 360.0;
    }

    constraint vibrationServiceLimit : NaturalFrequencyLimit {
      in firstVerticalFrequency = firstVerticalNaturalFrequency;
      in minimumFrequency = 3.0;
    }

    connect externalLoadPort to deck.loadInput;

    connect deck.panelPoint0 to jointL0.loadPort;
    connect deck.panelPoint1 to jointL1.loadPort;
    connect deck.panelPoint2 to jointL2.loadPort;
    connect deck.panelPoint3 to jointL3.loadPort;
    connect deck.panelPoint4 to jointL4.loadPort;
    connect deck.panelPoint5 to jointL5.loadPort;
    connect deck.panelPoint6 to jointL6.loadPort;

    connect leftBearing.structurePort to jointL0.supportPort;
    connect rightBearing.structurePort to jointL6.supportPort;
    connect leftBearing.foundationPort to leftFoundation.bearingPort;
    connect rightBearing.foundationPort to rightFoundation.bearingPort;
    connect leftFoundation.bearingPort to leftFoundationPort;
    connect rightFoundation.bearingPort to rightFoundationPort;

    connect lowerChord01.endA to jointL0.member1;
    connect lowerChord01.endB to jointL1.member1;
    connect lowerChord12.endA to jointL1.member2;
    connect lowerChord12.endB to jointL2.member1;
    connect lowerChord23.endA to jointL2.member2;
    connect lowerChord23.endB to jointL3.member1;
    connect lowerChord34.endA to jointL3.member2;
    connect lowerChord34.endB to jointL4.member1;
    connect lowerChord45.endA to jointL4.member2;
    connect lowerChord45.endB to jointL5.member1;
    connect lowerChord56.endA to jointL5.member2;
    connect lowerChord56.endB to jointL6.member1;

    connect upperChord01.endA to jointU0.member1;
    connect upperChord01.endB to jointU1.member1;
    connect upperChord12.endA to jointU1.member2;
    connect upperChord12.endB to jointU2.member1;
    connect upperChord23.endA to jointU2.member2;
    connect upperChord23.endB to jointU3.member1;
    connect upperChord34.endA to jointU3.member2;
    connect upperChord34.endB to jointU4.member1;
    connect upperChord45.endA to jointU4.member2;
    connect upperChord45.endB to jointU5.member1;
    connect upperChord56.endA to jointU5.member2;
    connect upperChord56.endB to jointU6.member1;

    connect vertical0.endA to jointL0.member2;
    connect vertical0.endB to jointU0.member2;
    connect vertical1.endA to jointL1.member3;
    connect vertical1.endB to jointU1.member3;
    connect vertical2.endA to jointL2.member3;
    connect vertical2.endB to jointU2.member3;
    connect vertical3.endA to jointL3.member3;
    connect vertical3.endB to jointU3.member3;
    connect vertical4.endA to jointL4.member3;
    connect vertical4.endB to jointU4.member3;
    connect vertical5.endA to jointL5.member3;
    connect vertical5.endB to jointU5.member3;
    connect vertical6.endA to jointL6.member2;
    connect vertical6.endB to jointU6.member2;

    connect diagonal01.endA to jointL0.member3;
    connect diagonal01.endB to jointU1.member4;
    connect diagonal12.endA to jointU1.member5;
    connect diagonal12.endB to jointL2.member4;
    connect diagonal23.endA to jointL2.member5;
    connect diagonal23.endB to jointU3.member4;
    connect diagonal34.endA to jointU3.member5;
    connect diagonal34.endB to jointL4.member4;
    connect diagonal45.endA to jointL4.member5;
    connect diagonal45.endB to jointU5.member4;
    connect diagonal56.endA to jointU5.member5;
    connect diagonal56.endB to jointL6.member3;

    connect topLateralBraceA.endA to jointU0.member3;
    connect topLateralBraceA.endB to jointU6.member3;
    connect bottomLateralBraceA.endA to jointL0.member4;
    connect bottomLateralBraceA.endB to jointL6.member4;

    connect monitor.healthPort to healthOutputPort;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The truss-based system shall provide a high-level structural support function by spanning between end supports, receiving external loads, distributing them to panel points, carrying those loads primarily as axial member forces, and transferring reactions into foundations."
    subject system : TrussSupportSystem;
    require constraint { system.designVerticalLoadCapacity >= system.serviceVerticalLoad }
  }

  requirement def SpanRequirement {
    doc "The truss shall provide a clear structural span suitable for the supported deck."
    subject system : TrussSupportSystem;
    attribute minimumSpan : Length = 30.0;
    require constraint { system.span >= minimumSpan }
  }

  requirement def ServiceDeflectionRequirement {
    doc "The truss shall limit vertical service deflection under service load."
    subject system : TrussSupportSystem;
    attribute limitDenominator : Real = 360.0;
    require constraint { system.maximumServiceDeflection <= system.span / limitDenominator }
  }

  requirement def LoadCapacityRequirement {
    doc "The truss shall carry the specified vertical service load with capacity margin."
    subject system : TrussSupportSystem;
    attribute requiredCapacityFactor : Ratio = 1.5;
    require constraint { system.designVerticalLoadCapacity >= requiredCapacityFactor * system.serviceVerticalLoad }
  }

  requirement def VibrationRequirement {
    doc "The truss shall maintain a first vertical natural frequency above the minimum serviceability threshold."
    subject system : TrussSupportSystem;
    attribute minimumFirstVerticalFrequency : Frequency = 3.0;
    require constraint { system.firstVerticalNaturalFrequency >= minimumFirstVerticalFrequency }
  }

  requirement def HealthMonitoringRequirement {
    doc "The truss shall provide health status information including deflection, utilization, corrosion loss, and serviceability indication."
    subject system : TrussSupportSystem;
    require constraint { system.monitor.samplePeriod <= 5.0 }
  }

  part trussSpanSupport : TrussSupportSystem {
    :>> span = 30.0;
    :>> trussDepth = 4.5;
    :>> panelLength = 5.0;
    :>> designVerticalLoadCapacity = 1800.0;
    :>> serviceVerticalLoad = 1200.0;
    :>> maximumServiceDeflection = 0.075;
    :>> firstVerticalNaturalFrequency = 4.2;
  }

  requirement primaryFunctionReq : PrimaryFunctionRequirement {
    subject system = trussSpanSupport;
  }

  requirement spanReq : SpanRequirement {
    subject system = trussSpanSupport;
  }

  requirement deflectionReq : ServiceDeflectionRequirement {
    subject system = trussSpanSupport;
  }

  requirement capacityReq : LoadCapacityRequirement {
    subject system = trussSpanSupport;
  }

  requirement vibrationReq : VibrationRequirement {
    subject system = trussSpanSupport;
  }

  requirement monitoringReq : HealthMonitoringRequirement {
    subject system = trussSpanSupport;
  }

  satisfy primaryFunctionReq by trussSpanSupport;
  satisfy spanReq by trussSpanSupport;
  satisfy deflectionReq by trussSpanSupport;
  satisfy capacityReq by trussSpanSupport;
  satisfy vibrationReq by trussSpanSupport;
  satisfy monitoringReq by trussSpanSupport;
}
