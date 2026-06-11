package TuohyNeedleModel {

  import ScalarValues::*;
  import ISQ::*;

  value def Millimeter :> length;
  value def Degree :> planeAngle;
  value def Newton :> force;
  value def Milliliter :> volume;
  value def Gauge;
  value def FrenchSize;
  value def SterilityLevel;
  value def Pressure;

  item def SterileBarrier;
  item def EpiduralCatheter;
  item def SalineOrAirMedium;
  item def ClinicianHandForce;
  item def TissueContact;
  item def LumenPath;
  item def PositionIndication;
  item def DisposalContainment;

  port def HandInterfacePort {
    in item appliedForce : ClinicianHandForce;
    out item tactileResponse : PositionIndication;
  }

  port def DistalTissuePort {
    out item tipContact : TissueContact;
    in item tissueResistance : Pressure;
  }

  port def LumenPort {
    inout item medium : SalineOrAirMedium;
    inout item catheter : EpiduralCatheter;
    out item guidedPath : LumenPath;
  }

  port def SterilePackagePort {
    inout item barrier : SterileBarrier;
  }

  port def SharpsDisposalPort {
    out item containedNeedle : DisposalContainment;
  }

  part def CurvedTuohyTip {
    attribute bevelAngle : Degree = 30;
    attribute curvatureRadius : Millimeter = 1.2;
    attribute distalOpeningOffset : Millimeter = 0.8;

    port tissuePort : DistalTissuePort;

    requirement def RoundedTipGeometry {
      doc /* The distal tip shall provide a curved, blunt-leading geometry that supports directional catheter exit and reduces cutting behavior relative to a sharp cutting bevel. */
      require constraint {
        bevelAngle >= 20 and bevelAngle <= 40
      }
    }
  }

  part def NeedleCannula {
    attribute gauge : Gauge = 17;
    attribute usableLength : Millimeter = 80;
    attribute outerDiameter : Millimeter = 1.47;
    attribute innerDiameter : Millimeter = 1.07;

    part tip : CurvedTuohyTip;

    port proximalLumen : LumenPort;
    port distalLumen : LumenPort;
    port distalTissue : DistalTissuePort;

    connection distalLumenToTip connect distalLumen to tip.tissuePort;
    connection tissueExposure connect distalTissue to tip.tissuePort;

    requirement def ContinuousLumen {
      doc /* The cannula shall maintain a continuous internal lumen from the proximal hub to the distal curved opening to allow medium flow and catheter passage. */
      require constraint {
        innerDiameter > 0.9
      }
    }
  }

  part def Stylet {
    attribute insertedLength : Millimeter = 82;
    attribute tipFlushOffset : Millimeter = 0.0;

    port proximalGrip : HandInterfacePort;
    port lumenOccupancy : LumenPort;

    requirement def OccludeLumenDuringInsertion {
      doc /* The stylet shall occupy the cannula lumen during initial handling and advancement to reduce tissue coring. */
      require constraint {
        tipFlushOffset >= -0.2 and tipFlushOffset <= 0.2
      }
    }
  }

  part def NeedleHub {
    attribute luerCompatibility : Boolean = true;
    attribute wingWidth : Millimeter = 24;
    attribute transparentBody : Boolean = true;

    port handPort : HandInterfacePort;
    port lumenPort : LumenPort;
  }

  part def DepthMarkingSet {
    attribute firstMarkDistance : Millimeter = 10;
    attribute markSpacing : Millimeter = 10;
    attribute maximumMarkedDepth : Millimeter = 80;

    port visualIndication : HandInterfacePort;
  }

  part def SterilePackaging {
    attribute sterility : SterilityLevel = 1;
    attribute packageIntegrityVerified : Boolean = true;

    port sterilePort : SterilePackagePort;
  }

  part def CatheterCompatibilityEnvelope {
    attribute minimumCatheterSize : FrenchSize = 19;
    attribute maximumCatheterSize : FrenchSize = 20;
    attribute minimumBendRadius : Millimeter = 1.0;

    port catheterPassage : LumenPort;
  }

  part def TuohyNeedleSystem {
    doc /* A Tuohy needle system is a sterile, curved-tip epidural access device whose primary high-level function is to create and maintain a controlled path to the epidural region so that an epidural catheter can be guided through its lumen. */

    attribute nominalGauge : Gauge = 17;
    attribute nominalLength : Millimeter = 80;
    attribute singleUse : Boolean = true;
    attribute maximumManualForce : Newton = 35;

    part package : SterilePackaging;
    part hub : NeedleHub;
    part cannula : NeedleCannula;
    part stylet : Stylet;
    part markings : DepthMarkingSet;
    part catheterEnvelope : CatheterCompatibilityEnvelope;

    port clinicianInterface : HandInterfacePort;
    port distalPatientInterface : DistalTissuePort;
    port internalLumen : LumenPort;
    port sterileBoundary : SterilePackagePort;
    port disposalInterface : SharpsDisposalPort;

    connection clinicianToHub connect clinicianInterface to hub.handPort;
    connection hubToCannulaLumen connect hub.lumenPort to cannula.proximalLumen;
    connection cannulaToSystemDistal connect cannula.distalTissue to distalPatientInterface;
    connection lumenToSystem connect internalLumen to hub.lumenPort;
    connection styletWithinLumen connect stylet.lumenOccupancy to internalLumen;
    connection catheterEnvelopeToLumen connect catheterEnvelope.catheterPassage to internalLumen;
    connection sterilePackageBoundary connect sterileBoundary to package.sterilePort;
    connection markingsToClinician connect markings.visualIndication to clinicianInterface;

    action def PrepareNeedle {
      in item sterileBarrier : SterileBarrier;
      out item preparedNeedle : TuohyNeedleSystem;

      first start;
      then verifyPackageIntegrity;
      then removeFromSterileBarrier;
      then confirmStyletSeated;
      then prepared;
    }

    action def ProvideControlledEpiduralAccess {
      doc /* High-level primary behavior: accept clinician handling input, transmit the curved cannula through tissue, indicate loss of resistance through the lumen interface, and preserve a guided lumen path for catheter placement. */

      in item handForce : ClinicianHandForce;
      inout item medium : SalineOrAirMedium;
      out item guidedCatheterPath : LumenPath;
      out item tactileIndication : PositionIndication;

      first receiveClinicianForce;
      then advanceCurvedTip;
      then senseTissueResistance;
      then indicateEpiduralSpace;
      then maintainOpenLumen;
      then guideCatheterPath;
      then completeAccessPath;
    }

    action def GuideEpiduralCatheter {
      in item catheter : EpiduralCatheter;
      out item guidedPath : LumenPath;

      first alignCatheterWithHub;
      then passCatheterThroughLumen;
      then directCatheterAtCurvedTip;
      then releaseCatheterIntoTargetRegion;
    }

    state def UseLifecycle {
      entry action prepare : PrepareNeedle;

      state sterilePackaged;
      state prepared;
      state advancing;
      state epiduralSpaceIndicated;
      state catheterGuiding;
      state needleWithdrawn;
      state disposed;

      transition openPackage
        first sterilePackaged
        then prepared;

      transition beginAdvancement
        first prepared
        then advancing;

      transition lossOfResistanceDetected
        first advancing
        then epiduralSpaceIndicated;

      transition insertCatheter
        first epiduralSpaceIndicated
        then catheterGuiding;

      transition removeNeedleOverCatheter
        first catheterGuiding
        then needleWithdrawn;

      transition placeInSharpsContainer
        first needleWithdrawn
        then disposed;
    }

    requirement def PrimaryFunctionRequirement {
      subject needle : TuohyNeedleSystem;
      doc /* The system shall provide controlled epidural access by maintaining a patent curved lumen that enables identification of an access path and guidance of an epidural catheter. */
      require constraint {
        needle.cannula.innerDiameter >= 1.0 and needle.hub.luerCompatibility == true
      }
    }

    requirement def CatheterGuidanceRequirement {
      subject needle : TuohyNeedleSystem;
      doc /* The curved distal opening shall direct a compatible epidural catheter from the cannula lumen while limiting abrupt bending. */
      require constraint {
        needle.catheterEnvelope.maximumCatheterSize <= 20 and
        needle.cannula.tip.curvatureRadius >= needle.catheterEnvelope.minimumBendRadius
      }
    }

    requirement def DepthAwarenessRequirement {
      subject needle : TuohyNeedleSystem;
      doc /* The cannula shall include visible depth markings that support clinician awareness of insertion depth. */
      require constraint {
        needle.markings.markSpacing == 10 and
        needle.markings.maximumMarkedDepth >= needle.nominalLength
      }
    }

    requirement def SterileSingleUseRequirement {
      subject needle : TuohyNeedleSystem;
      doc /* The system shall be supplied sterile and intended for single use with sharps disposal after use. */
      require constraint {
        needle.singleUse == true and
        needle.package.packageIntegrityVerified == true
      }
    }

    requirement def ManualControlRequirement {
      subject needle : TuohyNeedleSystem;
      doc /* The hub and cannula assembly shall transmit clinician handling inputs while preserving tactile response relevant to high-level access positioning. */
      require constraint {
        needle.maximumManualForce <= 35 and
        needle.hub.wingWidth >= 20
      }
    }
  }

  part tuohyNeedle : TuohyNeedleSystem;

}