package DenisBrowneBarSystem {

  import ISQ::*;
  import ScalarValues::*;

  package Units {
    value type Length :> ISQ::Length { unit mm; }
    value type Angle :> ISQ::PlaneAngle { unit deg; }
    value type Duration :> ISQ::Time { unit h; }
    value type Force :> ISQ::Force { unit N; }
    value type Mass :> ISQ::Mass { unit kg; }
    value type Pressure :> ISQ::Pressure { unit kPa; }
  }

  package Items {
    item def Foot;
    item def Infant {
      attribute age : Duration;
      attribute weight : Mass;
      attribute shoulderWidth : Units::Length;
      part feet : Foot[2];
    }
  }

  port def BarEnd {
    attribute attachmentDiameter : Units::Length;
    attribute lockingPinDiameter : Units::Length;
  }

  port def ShoeMount {
    attribute fastenerType : String;
    attribute threadSize : String;
  }

  part def MetalBar {
    attribute length : Units::Length = 150 [mm];
    attribute material : String = "aluminum";
    attribute maxBendingForce : Units::Force = 50 [N];
    attribute mass : Units::Mass;
    port leftEnd : BarEnd;
    port rightEnd : BarEnd;
  }

  part def Footplate {
    attribute rotationAngle : Units::Angle = 70 [deg];
    attribute locked : Boolean = true;
    attribute adjustmentRangeMin : Units::Angle = 0 [deg];
    attribute adjustmentRangeMax : Units::Angle = 90 [deg];
    attribute plateWidth : Units::Length = 40 [mm];
    port barConnection : BarEnd;
    port shoeMount : ShoeMount;

    action def AdjustAngle {
      in newAngle : Units::Angle;
      out appliedAngle : Units::Angle;
    }

    action def LockPlate {
      in requestedLock : Boolean;
      out lockState : Boolean;
    }

    perform action adjust : AdjustAngle {
      if newAngle >= adjustmentRangeMin & newAngle <= adjustmentRangeMax then {
        rotationAngle := newAngle;
        appliedAngle := newAngle;
      } else {
        appliedAngle := rotationAngle;
      }
    }

    perform action lock : LockPlate {
      locked := requestedLock;
      lockState := requestedLock;
    }
  }

  part def OrthopedicShoe {
    attribute size : Units::Length;
    attribute side : String;
    attribute strapTension : Units::Force = 5 [N];
    attribute soleMaterial : String = "rigid polymer";
    attribute linerMaterial : String = "soft foam";
    port plateMount : ShoeMount;
  }

  part def DenisBrowneBar {
    attribute shoulderWidth : Units::Length;
    attribute leftRotation : Units::Angle = 70 [deg];
    attribute rightRotation : Units::Angle = 70 [deg];
    attribute dailyWear : Units::Duration;
    attribute fittingComplete : Boolean = false;
    attribute correctionStable : Boolean = false;
    attribute monthsInMaintenance : Integer = 0;
    attribute weaningComplete : Boolean = false;

    part bar : MetalBar {
      attribute :>> length = shoulderWidth;
    }
    part leftFootplate : Footplate {
      attribute :>> rotationAngle = leftRotation;
    }
    part rightFootplate : Footplate {
      attribute :>> rotationAngle = rightRotation;
    }
    part leftShoe : OrthopedicShoe {
      attribute :>> side = "left";
      attribute :>> size = 90 [mm];
    }
    part rightShoe : OrthopedicShoe {
      attribute :>> side = "right";
      attribute :>> size = 90 [mm];
    }

    connection barLeftEnd connects bar.leftEnd to leftFootplate.barConnection;
    connection barRightEnd connects bar.rightEnd to rightFootplate.barConnection;
    connection leftShoeMount connects leftFootplate.shoeMount to leftShoe.plateMount;
    connection rightShoeMount connects rightFootplate.shoeMount to rightShoe.plateMount;

    perform state treatmentPlan : TreatmentPlan;
  }

  requirement def MaintainCorrection {
    doc "The brace shall maintain the corrected outwardly rotated alignment of both feet.";
    subject brace : DenisBrowneBar;
    objective {
      brace.leftFootplate.rotationAngle >= 60 [deg] &
      brace.rightFootplate.rotationAngle >= 60 [deg] &
      brace.leftFootplate.locked == true &
      brace.rightFootplate.locked == true
    }
  }

  requirement def BarLengthRequirement {
    doc "The rigid metal bar length shall match the infant's shoulder width.";
    subject bar : MetalBar;
    attribute shoulderWidth : Units::Length;
    objective { bar.length == shoulderWidth }
  }

  requirement def FootplateAdjustability {
    doc "Each footplate shall be adjustable and lockable within the external rotation range.";
    subject plate : Footplate;
    objective {
      plate.adjustmentRangeMin == 0 [deg] &
      plate.adjustmentRangeMax >= 70 [deg]
    }
  }

  requirement def WearScheduleRequirement {
    doc "The brace shall be worn per the treatment plan schedule, near full-time during active correction.";
    subject brace : DenisBrowneBar;
    objective { brace.dailyWear >= 12 [h] }
  }

  requirement def ShoeFitRequirement {
    doc "Each orthopedic shoe shall securely hold the infant's foot without excessive pressure.";
    subject shoe : OrthopedicShoe;
    objective { shoe.strapTension <= 10 [N] }
  }

  state def TreatmentPlan {
    entry { dailyWear := 0 [h]; }

    state InitialFitting {
      entry { fittingComplete := false; }
      exit { fittingComplete := true; }
    }

    state ActiveCorrection {
      entry { dailyWear := 23 [h]; }
      exit { correctionStable := true; }
    }

    state Maintenance {
      entry { dailyWear := 14 [h]; monthsInMaintenance := 0; }
      do { monthsInMaintenance := monthsInMaintenance + 1; }
    }

    state Weaning {
      entry { dailyWear := 12 [h]; }
      exit { weaningComplete := true; }
    }

    state Completed {
      entry { dailyWear := 0 [h]; }
    }

    transition from InitialFitting to ActiveCorrection
      when { fittingComplete == true };

    transition from ActiveCorrection to Maintenance
      when { correctionStable == true };

    transition from Maintenance to Weaning
      when { monthsInMaintenance >= 3 };

    transition from Weaning to Completed
      when { weaningComplete == true };
  }

  part def DenisBrowneBarAssembly :> DenisBrowneBar {
    item infant : Items::Infant {
      attribute :>> shoulderWidth = 140 [mm];
    }
    attribute :>> shoulderWidth = infant.shoulderWidth;
    satisfy MaintainCorrection;
    satisfy BarLengthRequirement {
      attribute :>> shoulderWidth = infant.shoulderWidth;
    }
    satisfy WearScheduleRequirement;
  }

}
