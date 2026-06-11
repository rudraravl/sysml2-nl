package CoronaryStentModel {
  import ScalarValues::*;
  import SI::*;

  attribute def Length;
  attribute def Diameter :> Length;
  attribute def Thickness :> Length;
  attribute def Area;
  attribute def Pressure;
  attribute def Force;
  attribute def FlowRate;
  attribute def Percent;
  attribute def Time;
  attribute def Mass;
  attribute def Temperature;

  enum def StentLifecycleKind {
    enum crimped;
    enum advancedToLesion;
    enum positioned;
    enum expanded;
    enum apposed;
    enum endothelializing;
    enum serviceInVessel;
  }

  enum def MaterialKind {
    enum cobaltChromium;
    enum platinumChromium;
    enum nitinol;
    enum stainlessSteel316L;
    enum biodegradablePolymer;
    enum durableFluoropolymer;
    enum sirolimus;
    enum everolimus;
  }

  item def ArterialBlood {
    attribute temperature : Temperature = 37 [degC];
    attribute oxygenSaturation : Percent = 97 [%];
    attribute nominalFlow : FlowRate;
    attribute pulsatilePressure : Pressure;
  }

  item def MechanicalExpansionEnergy {
    attribute radialForce : Force;
    attribute deploymentPressure : Pressure;
    attribute inflationDuration : Time;
  }

  item def AntiproliferativeDrug {
    attribute activeCompound : MaterialKind;
    attribute dose : Mass;
    attribute elutionHalfLife : Time;
  }

  port def BloodPassagePort {
    inout item blood : ArterialBlood;
    attribute hydraulicDiameter : Diameter;
    attribute pressureDrop : Pressure;
  }

  port def VesselWallInterfacePort {
    out item radialSupport : MechanicalExpansionEnergy;
    attribute contactPressure : Pressure;
    attribute appositionCoverage : Percent;
  }

  port def DrugElutionPort {
    out item drug : AntiproliferativeDrug;
    attribute releaseDuration : Time;
    attribute releaseUniformity : Percent;
  }

  port def DeliveryInterfacePort {
    in item expansionEnergy : MechanicalExpansionEnergy;
    attribute compatibleBalloonDiameter : Diameter;
    attribute compatibleGuidewireDiameter : Diameter = 0.014 [in];
  }

  part def CoronaryStentSystem {
    attribute lifecycle : StentLifecycleKind = StentLifecycleKind::crimped;
    attribute nominalExpandedDiameter : Diameter = 3.0 [mm];
    attribute nominalLength : Length = 18.0 [mm];
    attribute crimpedDiameter : Diameter = 1.05 [mm];
    attribute strutThickness : Thickness = 81 [um];
    attribute foreshortening : Percent <= 3 [%];
    attribute recoilAfterDeployment : Percent <= 5 [%];
    attribute radialStrength : Pressure >= 85 [kPa];
    attribute openCellArea : Area;
    attribute intendedServiceLife : Time = 10 [yr];

    port proximalLumen : BloodPassagePort;
    port distalLumen : BloodPassagePort;
    port vesselWall : VesselWallInterfacePort;
    port deliveryMount : DeliveryInterfacePort;
    port drugSurface : DrugElutionPort;

    part scaffold : MetallicScaffold;
    part coating : DrugPolymerCoating;
    part radiopaqueMarkers[2] : RadiopaqueMarker;
    part lumenEnvelope : RestoredLumenEnvelope;

    connection bloodPath connect proximalLumen to distalLumen;
    connection scaffoldToWall connect scaffold.outerSurface to vesselWall;
    connection coatingToBlood connect coating.elutionSurface to drugSurface;
    connection deliveryToScaffold connect deliveryMount to scaffold.expansionInput;

    perform action RestoreCoronaryLumen;
    exhibit state StentLifecycle;
  }

  part def MetallicScaffold {
    attribute material : MaterialKind = MaterialKind::cobaltChromium;
    attribute ringCount : Integer = 12;
    attribute connectorCount : Integer = 24;
    attribute strutWidth : Length = 90 [um];
    attribute strutThickness : Length = 81 [um];
    attribute expandedOuterDiameter : Diameter = 3.0 [mm];
    attribute fatigueCyclesRequired : Integer = 400000000;
    attribute minimumFreeArea : Percent >= 82 [%];

    port expansionInput : DeliveryInterfacePort;
    port outerSurface : VesselWallInterfacePort;

    part rings[12] : CircumferentialRing;
    part links[24] : FlexibleConnector;
  }

  part def CircumferentialRing {
    attribute crownCount : Integer = 8;
    attribute peakRadius : Length = 55 [um];
    attribute plasticExpansionLimit : Percent = 12 [%];
  }

  part def FlexibleConnector {
    attribute connectorLength : Length = 0.75 [mm];
    attribute connectorWidth : Length = 75 [um];
    attribute bendCompliance : Percent;
  }

  part def DrugPolymerCoating {
    attribute polymer : MaterialKind = MaterialKind::durableFluoropolymer;
    attribute drug : MaterialKind = MaterialKind::everolimus;
    attribute coatingThickness : Thickness = 7 [um];
    attribute totalDrugDose : Mass = 100 [ug];
    attribute releaseDuration : Time = 90 [d];

    port elutionSurface : DrugElutionPort;
  }

  part def RadiopaqueMarker {
    attribute material : MaterialKind = MaterialKind::platinumChromium;
    attribute markerLength : Length = 0.35 [mm];
    attribute markerWidth : Length = 0.10 [mm];
    attribute visibilityUnderFluoroscopy : Percent >= 95 [%];
  }

  part def RestoredLumenEnvelope {
    attribute targetDiameter : Diameter = 3.0 [mm];
    attribute minimumPostDeploymentDiameter : Diameter >= 2.7 [mm];
    attribute maximumPressureDrop : Pressure <= 2 [mmHg];
    attribute minimumAreaGain : Percent >= 50 [%];

    port inflow : BloodPassagePort;
    port outflow : BloodPassagePort;

    connection lumenContinuity connect inflow to outflow;
  }

  action def RestoreCoronaryLumen {
    in item stenosedSegment : CoronaryArterySegment;
    in item deploymentEnergy : MechanicalExpansionEnergy;
    out item treatedSegment : CoronaryArterySegment;

    first start;
    then positionStent;
    then expandScaffold;
    then pressPlaqueAndWall;
    then establishOpenLumen;
    then beginDrugElution;
    then done;

    action positionStent {
      in item stenosedSegment : CoronaryArterySegment;
      out attribute alignmentError : Length <= 0.5 [mm];
    }

    action expandScaffold {
      in item deploymentEnergy : MechanicalExpansionEnergy;
      out attribute expandedDiameter : Diameter = 3.0 [mm];
      out attribute residualRecoil : Percent <= 5 [%];
    }

    action pressPlaqueAndWall {
      out attribute wallApposition : Percent >= 95 [%];
      out attribute acuteGain : Diameter >= 1.5 [mm];
    }

    action establishOpenLumen {
      out item treatedSegment : CoronaryArterySegment;
      out attribute finalTIMIFlowGrade : Integer = 3;
    }

    action beginDrugElution {
      out item drug : AntiproliferativeDrug;
      out attribute restenosisMitigationDuration : Time >= 90 [d];
    }
  }

  item def CoronaryArterySegment {
    attribute referenceVesselDiameter : Diameter;
    attribute lesionLength : Length;
    attribute preTreatmentLumenDiameter : Diameter;
    attribute postTreatmentLumenDiameter : Diameter;
    attribute stenosisSeverity : Percent;
    attribute plaqueBurden : Percent;
    attribute bloodFlow : FlowRate;
  }

  state def StentLifecycle {
    entry action initializeCrimped;

    state crimped;
    state advancedToLesion;
    state positioned;
    state expanded;
    state apposed;
    state endothelializing;
    state serviceInVessel;

    transition t1 first crimped then advancedToLesion;
    transition t2 first advancedToLesion then positioned;
    transition t3 first positioned then expanded
      accept DeploymentPressureApplied;
    transition t4 first expanded then apposed
      if appositionCoverage >= 95 [%];
    transition t5 first apposed then endothelializing
      after 7 [d];
    transition t6 first endothelializing then serviceInVessel
      after 90 [d];
  }

  item def DeploymentPressureApplied {
    attribute pressure : Pressure >= 8 [atm];
    attribute duration : Time >= 10 [s];
  }

  requirement def PrimaryFunctionRequirement {
    subject stent : CoronaryStentSystem;

    doc /* The coronary stent shall restore and maintain patency of a narrowed coronary artery by expanding at the lesion, pressing plaque against the vessel wall, supporting the arterial lumen, and permitting blood to flow through the treated segment. */

    require constraint {
      stent.nominalExpandedDiameter >= 2.25 [mm] and
      stent.nominalExpandedDiameter <= 4.50 [mm] and
      stent.radialStrength >= 85 [kPa]
    }
  }

  requirement def LumenPatencyRequirement {
    subject lumen : RestoredLumenEnvelope;

    doc /* The deployed stent shall provide a continuous internal flow path with low pressure drop across the treated coronary segment. */

    require constraint {
      lumen.minimumPostDeploymentDiameter >= 0.90 * lumen.targetDiameter and
      lumen.maximumPressureDrop <= 2 [mmHg]
    }
  }

  requirement def VesselAppositionRequirement {
    subject stent : CoronaryStentSystem;

    doc /* The expanded scaffold shall contact the vessel wall sufficiently to prevent migration and minimize malapposition. */

    require constraint {
      stent.vesselWall.appositionCoverage >= 95 [%] and
      stent.recoilAfterDeployment <= 5 [%]
    }
  }

  requirement def DeliverabilityRequirement {
    subject stent : CoronaryStentSystem;

    doc /* The crimped stent shall be deliverable through coronary vasculature on a balloon catheter over a standard coronary guidewire. */

    require constraint {
      stent.crimpedDiameter <= 1.20 [mm] and
      stent.deliveryMount.compatibleGuidewireDiameter == 0.014 [in]
    }
  }

  requirement def DrugElutionRequirement {
    subject coating : DrugPolymerCoating;

    doc /* When drug eluting, the coating shall release antiproliferative drug over the early healing period to reduce restenosis risk. */

    require constraint {
      coating.totalDrugDose >= 50 [ug] and
      coating.releaseDuration >= 30 [d] and
      coating.releaseDuration <= 180 [d]
    }
  }

  requirement def FatigueDurabilityRequirement {
    subject scaffold : MetallicScaffold;

    doc /* The scaffold shall withstand cyclic coronary loading for long-term implantation without strut fracture. */

    require constraint {
      scaffold.fatigueCyclesRequired >= 400000000 and
      scaffold.minimumFreeArea >= 82 [%]
    }
  }

  part coronaryStent : CoronaryStentSystem {
    attribute nominalExpandedDiameter = 3.0 [mm];
    attribute nominalLength = 18.0 [mm];
    attribute crimpedDiameter = 1.05 [mm];
    attribute intendedServiceLife = 10 [yr];
  }

  item exampleTargetLesion : CoronaryArterySegment {
    attribute referenceVesselDiameter = 3.0 [mm];
    attribute lesionLength = 14.0 [mm];
    attribute preTreatmentLumenDiameter = 0.9 [mm];
    attribute postTreatmentLumenDiameter = 2.8 [mm];
    attribute stenosisSeverity = 70 [%];
    attribute plaqueBurden = 65 [%];
  }
}