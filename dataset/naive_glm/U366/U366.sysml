package ReflexExaminationSystem {
  import SI::*;
  import ScalarValues::*;

  value type LengthValue :> Real {
    unit m;
  }
  value type MassValue :> Real {
    unit kg;
  }
  value type ForceValue :> Real {
    unit N;
  }
  value type TimeValue :> Real {
    unit s;
  }
  value type HardnessValue :> Real {
    unit 'Shore A';
  }
  value type VelocityValue :> Real {
    unit 'm/s';
  }

  enum ReflexGrade :> Integer {
    absent = 0;
    hypoactive = 1;
    normal = 2;
    brisk = 3;
    hyperactive = 4;
  }

  enum Tendon {
    patellar;
    achilles;
    biceps;
    brachioradialis;
    triceps;
  }

  item def Strike {
    attribute targetTendon : Tendon;
    attribute impactForce : ForceValue;
    attribute impactDuration : TimeValue;
    attribute approachVelocity : VelocityValue;
  }

  item def ReflexResponse {
    attribute targetTendon : Tendon;
    attribute latency : TimeValue;
    attribute magnitude : ForceValue;
    attribute grade : ReflexGrade;
  }

  port def StrikeOutPort {
    out strike : Strike;
  }

  port def StrikeInPort {
    in strike : Strike;
  }

  port def ResponseOutPort {
    out response : ReflexResponse;
  }

  port def ResponseInPort {
    in response : ReflexResponse;
  }

  part def Head {
    attribute material : String = "Medical-grade rubber";
    attribute hardness : HardnessValue = 50;
    attribute diameter : LengthValue = 0.03;
    attribute mass : MassValue = 0.04;
  }

  part def Handle {
    attribute length : LengthValue = 0.15;
    attribute diameter : LengthValue = 0.02;
    attribute gripTexture : String = "knurled";
    attribute mass : MassValue = 0.11;
  }

  part def ReflexHammer {
    attribute mass : MassValue = 0.15;
    attribute length : LengthValue = 0.25;
    part head : Head;
    part handle : Handle;
    port strikePort : StrikeOutPort;

    action def deliverStrike {
      in targetTendon : Tendon;
      out strike : Strike;
    }
  }

  part def Tendon {
    attribute name : Tendon;
    port strikeInPort : StrikeInPort;
    port responseOutPort : ResponseOutPort;

    action def generateReflex {
      in strike : Strike;
      out response : ReflexResponse;
    }
  }

  part def Patient {
    part patellarTendon : Tendon { attribute name = Tendon::patellar; }
    part achillesTendon : Tendon { attribute name = Tendon::achilles; }
    part bicepsTendon : Tendon { attribute name = Tendon::biceps; }
    part brachioradialisTendon : Tendon { attribute name = Tendon::brachioradialis; }
    part tricepsTendon : Tendon { attribute name = Tendon::triceps; }
  }

  part def Clinician {
    attribute identifier : String;
    port observationPort : ResponseInPort;

    action def performStrike {
      in targetTendon : Tendon;
      out strike : Strike;
    }

    action def observeResponse {
      in response : ReflexResponse;
      out grade : ReflexGrade;
    }

    action def gradeResponse {
      in response : ReflexResponse;
      out grade : ReflexGrade;
    }
  }

  connection def HammerToTendon {
    end hammerStrike : StrikeOutPort;
    end tendonStrike : StrikeInPort;
  }

  connection def TendonToClinician {
    end tendonResponse : ResponseOutPort;
    end clinicianObservation : ResponseInPort;
  }

  part def ReflexExaminationSystem {
    part clinician : Clinician;
    part patient : Patient;
    part hammer : ReflexHammer;

    connection hammerToPatellar : HammerToTendon {
      hammerStrike :>> hammer.strikePort;
      tendonStrike :>> patient.patellarTendon.strikeInPort;
    }
    connection hammerToAchilles : HammerToTendon {
      hammerStrike :>> hammer.strikePort;
      tendonStrike :>> patient.achillesTendon.strikeInPort;
    }
    connection hammerToBiceps : HammerToTendon {
      hammerStrike :>> hammer.strikePort;
      tendonStrike :>> patient.bicepsTendon.strikeInPort;
    }
    connection hammerToBrachioradialis : HammerToTendon {
      hammerStrike :>> hammer.strikePort;
      tendonStrike :>> patient.brachioradialisTendon.strikeInPort;
    }
    connection hammerToTriceps : HammerToTendon {
      hammerStrike :>> hammer.strikePort;
      tendonStrike :>> patient.tricepsTendon.strikeInPort;
    }

    connection patellarToClinician : TendonToClinician {
      tendonResponse :>> patient.patellarTendon.responseOutPort;
      clinicianObservation :>> clinician.observationPort;
    }
    connection achillesToClinician : TendonToClinician {
      tendonResponse :>> patient.achillesTendon.responseOutPort;
      clinicianObservation :>> clinician.observationPort;
    }
    connection bicepsToClinician : TendonToClinician {
      tendonResponse :>> patient.bicepsTendon.responseOutPort;
      clinicianObservation :>> clinician.observationPort;
    }
    connection brachioradialisToClinician : TendonToClinician {
      tendonResponse :>> patient.brachioradialisTendon.responseOutPort;
      clinicianObservation :>> clinician.observationPort;
    }
    connection tricepsToClinician : TendonToClinician {
      tendonResponse :>> patient.tricepsTendon.responseOutPort;
      clinicianObservation :>> clinician.observationPort;
    }

    state machine ExaminationProcedure {
      state idle {
        entry action { /* system ready, clinician and patient prepared */ }
      }
      state positioning {
        entry action { /* clinician positions hammer over selected tendon */ }
      }
      state striking {
        entry action { /* clinician delivers controlled mechanical strike */ }
      }
      state observing {
        entry action { /* clinician observes latency and magnitude of reflex */ }
      }
      state grading {
        entry action { /* clinician assigns grade on five-point scale */ }
      }
      state complete {
        entry action { /* examination concluded, results recorded */ }
      }

      transition from idle to positioning when true;
      transition from positioning to striking when true;
      transition from striking to observing when true;
      transition from observing to grading when true;
      transition from grading to complete when true;
    }

    requirement hammerMassReq : HammerMassRequirement {
      attribute mass = hammer.mass;
    }
    requirement hammerLengthReq : HammerLengthRequirement {
      attribute length = hammer.length;
    }
    requirement headHardnessReq : HeadHardnessRequirement {
      attribute hardness = hammer.head.hardness;
    }
    requirement handleErgonomicsReq : HandleErgonomicsRequirement {
      attribute length = hammer.handle.length;
      attribute diameter = hammer.handle.diameter;
      attribute gripTexture = hammer.handle.gripTexture;
    }
    requirement strikeControlReq : StrikeControlRequirement {
      attribute impactForce = Strike::impactForce;
    }
    requirement gradingScaleReq : GradingScaleRequirement {
      attribute grade = ReflexResponse::grade;
    }

    satisfy hammerMassReq by hammer;
    satisfy hammerLengthReq by hammer;
    satisfy headHardnessReq by hammer.head;
    satisfy handleErgonomicsReq by hammer.handle;
    satisfy strikeControlReq by clinician;
    satisfy gradingScaleReq by clinician;
  }

  requirement def HammerMassRequirement {
    doc "The reflex hammer mass shall be balanced for precise handling.";
    attribute mass : MassValue;
    constraint { mass >= 0.10 and mass <= 0.20 }
  }

  requirement def HammerLengthRequirement {
    doc "The reflex hammer length shall support controlled strikes.";
    attribute length : LengthValue;
    constraint { length >= 0.20 and length <= 0.30 }
  }

  requirement def HeadHardnessRequirement {
    doc "The head hardness shall ensure safe but effective impact on the tendon.";
    attribute hardness : HardnessValue;
    constraint { hardness >= 40 and hardness <= 60 }
  }

  requirement def HandleErgonomicsRequirement {
    doc "The handle shall be ergonomic with a textured grip to minimize clinician fatigue.";
    attribute length : LengthValue;
    attribute diameter : LengthValue;
    attribute gripTexture : String;
    constraint { length >= 0.12 and length <= 0.18 }
    constraint { diameter >= 0.015 and diameter <= 0.025 }
    constraint { gripTexture != "smooth" }
  }

  requirement def StrikeControlRequirement {
    doc "The clinician shall deliver a controlled mechanical strike to elicit a reflex.";
    attribute impactForce : ForceValue;
    constraint { impactForce >= 1.0 and impactForce <= 10.0 }
  }

  requirement def GradingScaleRequirement {
    doc "The reflex response shall be graded on a standard five-point clinical scale.";
    attribute grade : ReflexGrade;
    constraint { grade >= ReflexGrade::absent and grade <= ReflexGrade::hyperactive }
  }
}
