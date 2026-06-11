package GastricBalloonSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Volume {
    :> scalar;
    unit = L;
  }

  attribute def Pressure {
    :> scalar;
    unit = kPa;
  }

  attribute def Mass {
    :> scalar;
    unit = kg;
  }

  attribute def TimeDuration {
    :> scalar;
    unit = s;
  }

  attribute def Temperature {
    :> scalar;
    unit = degC;
  }

  attribute def Force {
    :> scalar;
    unit = N;
  }

  attribute def Length {
    :> scalar;
    unit = mm;
  }

  item def SalineFluid {
    attribute volume : Volume;
    attribute temperature : Temperature;
    attribute sterilityLevel : Real;
  }

  item def Air {
    attribute volume : Volume;
    attribute pressure : Pressure;
  }

  item def GastricContents {
    attribute occupiedVolume : Volume;
    attribute acidityPH : Real;
  }

  item def PatientSignal {
    attribute nauseaLevel : Real;
    attribute painLevel : Real;
    attribute satietyLevel : Real;
  }

  item def EndoscopicCommand {
    attribute inflateRequested : Boolean;
    attribute deflateRequested : Boolean;
    attribute removeRequested : Boolean;
  }

  port def FillPort {
    in item fillMedium : SalineFluid;
    out item displacedAir : Air;
  }

  port def ValvePort {
    in item command : EndoscopicCommand;
    in item fillMedium : SalineFluid;
    out item withdrawnMedium : SalineFluid;
  }

  port def GastricContactPort {
    inout item gastricContents : GastricContents;
    out item patientSignal : PatientSignal;
  }

  port def ClinicalAccessPort {
    in item command : EndoscopicCommand;
    inout item fillMedium : SalineFluid;
  }

  part def ElasticBalloonEnvelope {
    attribute materialName : String = "medical grade silicone elastomer";
    attribute wallThickness : Length = 0.6 [mm];
    attribute maximumDiameter : Length = 125 [mm];
    attribute ratedBurstPressure : Pressure = 35 [kPa];
    attribute currentInternalPressure : Pressure;
    attribute currentVolume : Volume;
    attribute integrityOk : Boolean;

    port fillPort : FillPort;
    port contactPort : GastricContactPort;

    perform action expand {
      in item medium : SalineFluid;
      out attribute finalVolume : Volume;
      finalVolume = currentVolume + medium.volume;
    }

    perform action compressByStomach {
      in attribute gastricForce : Force;
      out attribute pressureRise : Pressure;
    }
  }

  part def SelfSealingValve {
    attribute leakRate : Volume = 0.0 [L];
    attribute closingForce : Force = 3.0 [N];
    attribute open : Boolean = false;

    port valvePort : ValvePort;
    port balloonFillPort : FillPort;

    perform action openValve {
      open = true;
    }

    perform action closeValve {
      open = false;
    }

    perform action transferFillMedium {
      in item medium : SalineFluid;
      out item deliveredMedium : SalineFluid;
      deliveredMedium.volume = medium.volume;
      deliveredMedium.temperature = medium.temperature;
      deliveredMedium.sterilityLevel = medium.sterilityLevel;
    }
  }

  part def RadiopaqueMarker {
    attribute materialName : String = "platinum-iridium";
    attribute markerLength : Length = 3 [mm];
    attribute visibleUnderFluoroscopy : Boolean = true;
  }

  part def GastricCavityInterface {
    attribute availableGastricVolume : Volume = 1.2 [L];
    attribute occupiedByBalloon : Volume;
    attribute averageContactForce : Force;
    attribute gastricPH : Real = 2.0;

    port contactPort : GastricContactPort;

    perform action reduceAvailableFoodVolume {
      in attribute balloonVolume : Volume;
      out attribute remainingVolume : Volume;
      remainingVolume = availableGastricVolume - balloonVolume;
    }

    perform action stimulateSatiety {
      in attribute balloonVolume : Volume;
      out item signal : PatientSignal;
      signal.satietyLevel = balloonVolume / 0.7 [L];
      signal.nauseaLevel = 0.2;
      signal.painLevel = 0.1;
    }
  }

  part def InflationCatheter {
    attribute outerDiameter : Length = 2.7 [mm];
    attribute usableLength : Length = 1800 [mm];
    attribute primed : Boolean;

    port clinicalPort : ClinicalAccessPort;
    port valvePort : ValvePort;

    perform action primeCatheter {
      in item sterileSaline : SalineFluid;
      primed = true;
    }

    perform action injectSaline {
      in item prescribedFill : SalineFluid;
      out item deliveredFill : SalineFluid;
      deliveredFill.volume = prescribedFill.volume;
      deliveredFill.temperature = prescribedFill.temperature;
      deliveredFill.sterilityLevel = prescribedFill.sterilityLevel;
    }

    perform action aspirateSaline {
      in attribute targetVolume : Volume;
      out item removedFill : SalineFluid;
      removedFill.volume = targetVolume;
      removedFill.temperature = 37 [degC];
      removedFill.sterilityLevel = 1.0;
    }
  }

  part def EndoscopicDeliveryTool {
    attribute compatibleEndoscopeChannelDiameter : Length = 3.2 [mm];
    attribute positioningAccuracy : Length = 5 [mm];

    port clinicalPort : ClinicalAccessPort;

    perform action positionBalloonInStomach {
      out attribute positioned : Boolean;
      positioned = true;
    }

    perform action retrieveCollapsedBalloon {
      out attribute retrieved : Boolean;
      retrieved = true;
    }
  }

  part def GastricBalloon {
    attribute intendedFillVolume : Volume = 0.55 [L];
    attribute minimumEffectiveVolume : Volume = 0.4 [L];
    attribute maximumAllowedVolume : Volume = 0.7 [L];
    attribute deployedMass : Mass = 0.09 [kg];
    attribute residenceTimeLimit : TimeDuration = 15552000 [s];
    attribute implanted : Boolean = false;
    attribute inflated : Boolean = false;
    attribute removed : Boolean = false;

    part envelope : ElasticBalloonEnvelope;
    part valve : SelfSealingValve;
    part marker : RadiopaqueMarker;

    port valveAccess : ValvePort;
    port gastricInterface : GastricContactPort;

    connect valveAccess to valve.valvePort;
    connect valve.balloonFillPort to envelope.fillPort;
    connect gastricInterface to envelope.contactPort;

    perform action occupyGastricVolume {
      in item fill : SalineFluid;
      out attribute occupiedVolume : Volume;
      occupiedVolume = fill.volume;
    }

    perform action provideSatietyEffect {
      in attribute occupiedVolume : Volume;
      out item signal : PatientSignal;
      signal.satietyLevel = occupiedVolume / maximumAllowedVolume;
      signal.nauseaLevel = 0.15;
      signal.painLevel = 0.05;
    }

    state def BalloonLifecycle {
      state Unpackaged;
      state Collapsed;
      state PositionedInStomach;
      state Inflating;
      state TherapeuticResidence;
      state Deflating;
      state Removed;
      state Fault;

      entry action initialize {
        implanted = false;
        inflated = false;
        removed = false;
        envelope.currentVolume = 0.03 [L];
        envelope.currentInternalPressure = 0.0 [kPa];
        envelope.integrityOk = true;
      }

      transition first Unpackaged then Collapsed;

      transition Collapsed then PositionedInStomach
        accept EndoscopicCommand
        if command.inflateRequested == true
        do {
          implanted = true;
        }

      transition PositionedInStomach then Inflating
        accept SalineFluid
        if fillMedium.volume >= minimumEffectiveVolume and fillMedium.volume <= maximumAllowedVolume
        do {
          valve.openValve();
          envelope.currentVolume = fillMedium.volume;
        }

      transition Inflating then TherapeuticResidence
        if envelope.currentVolume >= minimumEffectiveVolume and envelope.currentVolume <= maximumAllowedVolume
        do {
          valve.closeValve();
          inflated = true;
        }

      transition TherapeuticResidence then Deflating
        accept EndoscopicCommand
        if command.deflateRequested == true
        do {
          valve.openValve();
          inflated = false;
        }

      transition Deflating then Removed
        accept EndoscopicCommand
        if command.removeRequested == true
        do {
          implanted = false;
          removed = true;
          envelope.currentVolume = 0.03 [L];
        }

      transition TherapeuticResidence then Fault
        if envelope.currentInternalPressure > envelope.ratedBurstPressure or envelope.integrityOk == false;

      transition Fault then Removed
        accept EndoscopicCommand
        if command.removeRequested == true
        do {
          implanted = false;
          inflated = false;
          removed = true;
        }
    }
  }

  part def ClinicalGastricBalloonSystem {
    attribute primaryFunction : String =
      "Occupy a controlled portion of stomach volume to promote early satiety and support weight reduction therapy.";

    part balloon : GastricBalloon;
    part catheter : InflationCatheter;
    part deliveryTool : EndoscopicDeliveryTool;
    part stomachInterface : GastricCavityInterface;

    port clinicianAccess : ClinicalAccessPort;
    port patientGastricContact : GastricContactPort;

    connect clinicianAccess to catheter.clinicalPort;
    connect catheter.valvePort to balloon.valveAccess;
    connect clinicianAccess to deliveryTool.clinicalPort;
    connect balloon.gastricInterface to stomachInterface.contactPort;
    connect patientGastricContact to stomachInterface.contactPort;

    perform action deployAndFill {
      in item prescribedFill : SalineFluid;
      out item patientResponse : PatientSignal;

      deliveryTool.positionBalloonInStomach();
      catheter.primeCatheter(prescribedFill);
      catheter.injectSaline(prescribedFill);
      balloon.occupyGastricVolume(prescribedFill);
      stomachInterface.reduceAvailableFoodVolume(balloon.envelope.currentVolume);
      stomachInterface.stimulateSatiety(balloon.envelope.currentVolume);
    }

    perform action maintainTherapy {
      in attribute elapsedResidenceTime : TimeDuration;
      out attribute therapyAllowed : Boolean;

      therapyAllowed =
        elapsedResidenceTime <= balloon.residenceTimeLimit
        and balloon.inflated == true
        and balloon.envelope.integrityOk == true;
    }

    perform action deflateAndRemove {
      out item removedFill : SalineFluid;
      out attribute retrievalComplete : Boolean;

      catheter.aspirateSaline(balloon.envelope.currentVolume);
      deliveryTool.retrieveCollapsedBalloon();
      retrievalComplete = true;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     The system shall provide a temporary intragastric balloon that occupies
     a controlled stomach volume to increase satiety and reduce available
     gastric capacity during supervised therapy.
    */

    subject system : ClinicalGastricBalloonSystem;

    require constraint {
      system.balloon.envelope.currentVolume >= system.balloon.minimumEffectiveVolume
      and system.balloon.envelope.currentVolume <= system.balloon.maximumAllowedVolume
      and system.balloon.implanted == true
      and system.balloon.inflated == true
    }
  }

  requirement def FillVolumeSafetyRequirement {
    doc
    /*
     The balloon shall accept only a fill volume between 0.4 L and 0.7 L.
    */

    subject balloon : GastricBalloon;

    require constraint {
      balloon.envelope.currentVolume >= 0.4 [L]
      and balloon.envelope.currentVolume <= 0.7 [L]
    }
  }

  requirement def LeakIntegrityRequirement {
    doc
    /*
     The valve and envelope shall maintain fill medium with no clinically
     significant leakage during the intended residence period.
    */

    subject balloon : GastricBalloon;

    require constraint {
      balloon.valve.leakRate <= 0.005 [L]
      and balloon.envelope.integrityOk == true
    }
  }

  requirement def PressureSafetyRequirement {
    doc
    /*
     Internal pressure shall remain below the rated burst pressure of the
     balloon envelope during normal gastric compression.
    */

    subject balloon : GastricBalloon;

    require constraint {
      balloon.envelope.currentInternalPressure < balloon.envelope.ratedBurstPressure
    }
  }

  requirement def RemovabilityRequirement {
    doc
    /*
     The system shall support endoscopic deflation and retrieval at or before
     the maximum residence time.
    */

    subject system : ClinicalGastricBalloonSystem;

    require constraint {
      system.balloon.residenceTimeLimit <= 15552000 [s]
      and system.balloon.removed == true
    }
  }

  satisfy PrimaryFunctionRequirement by ClinicalGastricBalloonSystem;
  satisfy FillVolumeSafetyRequirement by GastricBalloon;
  satisfy LeakIntegrityRequirement by GastricBalloon;
  satisfy PressureSafetyRequirement by GastricBalloon;
  satisfy RemovabilityRequirement by ClinicalGastricBalloonSystem;

  part gastricBalloonTherapySystem : ClinicalGastricBalloonSystem {
    balloon.intendedFillVolume = 0.55 [L];
    balloon.minimumEffectiveVolume = 0.4 [L];
    balloon.maximumAllowedVolume = 0.7 [L];
    balloon.envelope.currentVolume = 0.55 [L];
    balloon.envelope.currentInternalPressure = 12 [kPa];
    balloon.envelope.integrityOk = true;
    stomachInterface.occupiedByBalloon = 0.55 [L];
    stomachInterface.averageContactForce = 2.5 [N];
  }
}