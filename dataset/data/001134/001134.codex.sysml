package MagneticCompassSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def DirectionAngle :> ISQ::planeAngle {
    doc "Horizontal direction angle measured clockwise from true north.";
    unit = SI::degree;
  }

  attribute def MagneticFieldStrength :> ISQ::magneticFluxDensity {
    doc "Local magnetic flux density sensed by the compass magnet.";
    unit = SI::microtesla;
  }

  attribute def HeadingAccuracy :> ISQ::planeAngle {
    unit = SI::degree;
  }

  attribute def DampingTime :> ISQ::time {
    unit = SI::second;
  }

  attribute def TiltAngle :> ISQ::planeAngle {
    unit = SI::degree;
  }

  item def EarthMagneticField {
    attribute horizontalComponent : MagneticFieldStrength;
    attribute declination : DirectionAngle;
    attribute inclination : DirectionAngle;
  }

  item def HeadingIndication {
    attribute magneticHeading : DirectionAngle;
    attribute correctedTrueHeading : DirectionAngle;
    attribute confidence : Real;
  }

  item def UserAlignmentInput {
    attribute observerLineOfSight : DirectionAngle;
  }

  port def MagneticFieldPort {
    in item field : EarthMagneticField;
  }

  port def HeadingDisplayPort {
    out item heading : HeadingIndication;
  }

  port def AlignmentPort {
    in item alignment : UserAlignmentInput;
  }

  part def MagnetizedNeedle {
    doc "Freely rotating magnetic element that aligns with the horizontal component of Earth's magnetic field.";

    port magneticInput : MagneticFieldPort;

    attribute magneticMoment : Real;
    attribute pivotFrictionTorque : Real;
    attribute angularPosition : DirectionAngle;
    attribute angularVelocity : Real;
    attribute settled : Boolean;

    action alignToMagneticField {
      in item field : EarthMagneticField;
      out attribute needleHeading : DirectionAngle;

      first start;
      then computeTorque;
      then rotateNeedle;
      then dampOscillation;
      then publishHeading;

      action computeTorque;
      action rotateNeedle;
      action dampOscillation;
      action publishHeading;
    }

    state def NeedleOperatingState {
      state stowed;
      state seekingNorth;
      state oscillating;
      state settled;

      entry;
      first stowed;

      transition deploy
        first stowed
        then seekingNorth;

      transition detectField
        first seekingNorth
        then oscillating;

      transition dampingComplete
        first oscillating
        then settled
        accept when settled == true;

      transition fieldDisturbed
        first settled
        then oscillating
        accept when settled == false;
    }
  }

  part def PivotBearing {
    doc "Low-friction mechanical support allowing the needle to rotate in the horizontal plane.";

    attribute frictionCoefficient : Real;
    attribute maximumTilt : TiltAngle = 10 [SI::degree];
    attribute levelWithinLimit : Boolean;

    action supportRotation {
      in attribute tilt : TiltAngle;
      out attribute rotationPermitted : Boolean;
    }
  }

  part def DampingFluid {
    doc "Viscous medium that reduces needle oscillation after movement or disturbance.";

    attribute viscosity : Real;
    attribute nominalDampingTime : DampingTime = 3.0 [SI::second];

    action dampNeedleMotion {
      in attribute angularVelocity : Real;
      out attribute reducedAngularVelocity : Real;
    }
  }

  part def CompassCard {
    doc "Graduated circular scale that maps needle orientation to cardinal and numeric heading.";

    attribute northMark : DirectionAngle = 0 [SI::degree];
    attribute eastMark : DirectionAngle = 90 [SI::degree];
    attribute southMark : DirectionAngle = 180 [SI::degree];
    attribute westMark : DirectionAngle = 270 [SI::degree];
    attribute graduationInterval : DirectionAngle = 2 [SI::degree];

    action resolveMagneticHeading {
      in attribute needleHeading : DirectionAngle;
      out item heading : HeadingIndication;
    }
  }

  part def DeclinationAdjuster {
    doc "Manual offset mechanism used to compensate local magnetic declination and report approximate true heading.";

    attribute declinationOffset : DirectionAngle;
    attribute adjustmentRangeMin : DirectionAngle = -30 [SI::degree];
    attribute adjustmentRangeMax : DirectionAngle = 30 [SI::degree];

    action applyDeclinationCorrection {
      in attribute magneticHeading : DirectionAngle;
      in attribute declinationOffset : DirectionAngle;
      out attribute correctedTrueHeading : DirectionAngle;
    }
  }

  part def SightWindow {
    doc "Visual alignment feature allowing the user to align the compass with a target direction.";

    port alignmentInput : AlignmentPort;

    attribute sightLine : DirectionAngle;

    action alignWithTarget {
      in item userAlignment : UserAlignmentInput;
      out attribute sightLine : DirectionAngle;
    }
  }

  part def Housing {
    doc "Protective non-magnetic enclosure that keeps the compass level and isolates components from handling loads.";

    attribute materialMagneticPermeability : Real;
    attribute waterResistant : Boolean = true;
    attribute transparentLidOpen : Boolean;

    action protectCompassAssembly;
  }

  part def MagneticCompass {
    doc "Portable magnetic compass system whose primary function is to indicate horizontal direction by aligning a magnetized needle with Earth's magnetic field.";

    port earthFieldInput : MagneticFieldPort;
    port headingOutput : HeadingDisplayPort;
    port userAlignmentInput : AlignmentPort;

    part needle : MagnetizedNeedle;
    part bearing : PivotBearing;
    part damping : DampingFluid;
    part card : CompassCard;
    part declinationAdjuster : DeclinationAdjuster;
    part sight : SightWindow;
    part housing : Housing;

    attribute operatingTilt : TiltAngle;
    attribute magneticHeading : DirectionAngle;
    attribute trueHeading : DirectionAngle;
    attribute displayedConfidence : Real;
    attribute nominalAccuracy : HeadingAccuracy = 2 [SI::degree];
    attribute maximumSettlingTime : DampingTime = 5 [SI::second];

    connect earthFieldInput.field to needle.magneticInput.field;
    connect userAlignmentInput.alignment to sight.alignmentInput.alignment;

    action indicateDirection {
      doc "Primary high-level function: receive Earth's magnetic field, align the needle with magnetic north, damp motion, resolve heading against the compass card, apply declination correction, and output a usable direction indication.";

      in item field : EarthMagneticField;
      in item alignment : UserAlignmentInput;
      out item displayedHeading : HeadingIndication;

      first receiveMagneticField;
      then alignNeedle;
      then stabilizeNeedle;
      then readCompassCard;
      then correctForDeclination;
      then emitHeading;

      action receiveMagneticField {
        out item sensedField : EarthMagneticField;
      }

      action alignNeedle {
        in item sensedField : EarthMagneticField;
        out attribute needleHeading : DirectionAngle;
      }

      action stabilizeNeedle {
        in attribute needleHeading : DirectionAngle;
        out attribute stableNeedleHeading : DirectionAngle;
      }

      action readCompassCard {
        in attribute stableNeedleHeading : DirectionAngle;
        out attribute magneticHeading : DirectionAngle;
      }

      action correctForDeclination {
        in attribute magneticHeading : DirectionAngle;
        out attribute correctedTrueHeading : DirectionAngle;
      }

      action emitHeading {
        in attribute magneticHeading : DirectionAngle;
        in attribute correctedTrueHeading : DirectionAngle;
        out item displayedHeading : HeadingIndication;
      }
    }

    state def CompassOperationalState {
      state stored;
      state deployed;
      state acquiringField;
      state stabilizing;
      state indicatingHeading;
      state disturbed;
      state unusable;

      entry;
      first stored;

      transition openLid
        first stored
        then deployed;

      transition beginUse
        first deployed
        then acquiringField;

      transition fieldDetected
        first acquiringField
        then stabilizing;

      transition stable
        first stabilizing
        then indicatingHeading;

      transition magneticDisturbance
        first indicatingHeading
        then disturbed;

      transition recover
        first disturbed
        then stabilizing;

      transition excessiveTilt
        first deployed
        then unusable
        accept when operatingTilt > bearing.maximumTilt;

      transition closeLid
        first indicatingHeading
        then stored;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc "The magnetic compass shall indicate horizontal direction by using Earth's magnetic field as the directional reference.";
    subject compass : MagneticCompass;

    require constraint {
      compass.headingOutput.heading.confidence >= 0.8
    }
  }

  requirement def MagneticHeadingAccuracyRequirement {
    doc "The compass shall provide magnetic heading within the specified nominal accuracy when level and free from local magnetic disturbance.";
    subject compass : MagneticCompass;

    require constraint {
      compass.nominalAccuracy <= 2 [SI::degree]
    }
  }

  requirement def SettlingTimeRequirement {
    doc "The needle shall settle to a readable indication within the specified maximum settling time after deployment or disturbance.";
    subject compass : MagneticCompass;

    require constraint {
      compass.maximumSettlingTime <= 5 [SI::second]
    }
  }

  requirement def LevelOperationRequirement {
    doc "The compass shall operate only when the housing and pivot support keep the needle within the allowable tilt range.";
    subject compass : MagneticCompass;

    require constraint {
      compass.operatingTilt <= compass.bearing.maximumTilt
    }
  }

  requirement def DeclinationCorrectionRequirement {
    doc "The compass shall support manual declination correction so that a user may estimate true heading from magnetic heading.";
    subject compass : MagneticCompass;

    require constraint {
      compass.declinationAdjuster.declinationOffset >= compass.declinationAdjuster.adjustmentRangeMin and
      compass.declinationAdjuster.declinationOffset <= compass.declinationAdjuster.adjustmentRangeMax
    }
  }

  part earthEnvironment {
    item localField : EarthMagneticField {
      attribute horizontalComponent = 45 [SI::microtesla];
      attribute declination = 6 [SI::degree];
      attribute inclination = 67 [SI::degree];
    }
  }

  part handheldCompass : MagneticCompass {
    attribute operatingTilt = 3 [SI::degree];
    attribute displayedConfidence = 0.95;
    attribute magneticHeading = 18 [SI::degree];
    attribute trueHeading = 24 [SI::degree];

    part declinationAdjuster {
      attribute declinationOffset = 6 [SI::degree];
    }

    part housing {
      attribute materialMagneticPermeability = 1.0;
      attribute transparentLidOpen = true;
    }

    part needle {
      attribute magneticMoment = 0.08;
      attribute pivotFrictionTorque = 0.00001;
      attribute angularPosition = 18 [SI::degree];
      attribute angularVelocity = 0.0;
      attribute settled = true;
    }
  }

  satisfy PrimaryFunctionRequirement by handheldCompass;
  satisfy MagneticHeadingAccuracyRequirement by handheldCompass;
  satisfy SettlingTimeRequirement by handheldCompass;
  satisfy LevelOperationRequirement by handheldCompass;
  satisfy DeclinationCorrectionRequirement by handheldCompass;
}