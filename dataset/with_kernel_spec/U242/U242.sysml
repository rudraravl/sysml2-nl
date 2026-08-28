package HirtzMagneticCompass {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def HeadingAngle :> PlaneAngleValue;
    attribute def AngularResolution :> PlaneAngleValue;
    attribute def FrictionCoefficient :> Real;
    attribute def DampingRatio :> Real;
    attribute def Viscosity :> Real;
    attribute def Density :> Real;
    attribute def MagneticMoment :> Real;
    attribute def OpticalClarity :> Real;
    attribute def LeakRate :> Real;

    attribute def AlignSignal;
    attribute def SettleSignal;
    attribute def DisturbSignal;
    attribute def ClearSignal;

    item def EarthMagneticField;
    item def MagneticInterference;
    item def DampingFluid;

    enum def CardinalDirection {
        N;
        S;
        E;
        W;
        NE;
        NW;
        SE;
        SW;
    }

    part def SapphireBearing {
        attribute frictionCoefficient : FrictionCoefficient;
    }

    part def MagnetizedNeedle {
        attribute magneticMoment : MagneticMoment;
        attribute currentAlignment : HeadingAngle;
    }

    part def PivotAssembly {
        attribute friction : FrictionCoefficient;
        part bearing : SapphireBearing;
    }

    part def CompassCard {
        attribute angularResolution : AngularResolution;
        attribute graduations : HeadingAngle[0..*];
        attribute cardinalPoints : CardinalDirection[0..*];
    }

    part def LubberLine {
        attribute fixedAlignment : HeadingAngle;
    }

    part def MineralOil :> DampingFluid {
        attribute viscosity : Viscosity;
        attribute density : Density;
    }

    part def DampingChamber {
        part fluid : MineralOil;
        attribute dampingRatio : DampingRatio;
    }

    part def GlassWindow {
        attribute opticalClarity : OpticalClarity;
    }

    part def HermeticSeal {
        attribute leakRate : LeakRate;
    }

    part def ProtectiveHousing {
        attribute material : String = "Brass";
        attribute sealed : Boolean = true;
        part window : GlassWindow;
        part seal : HermeticSeal;
    }

    port def EnvironmentPort {
        in item field : EarthMagneticField;
        in item interference : MagneticInterference[0..*];
    }

    port def HeadingPort {
        attribute heading : HeadingAngle;
    }

    state def CompassOperationStates {
        entry; then seeking;
        state seeking;
        transition seeking_to_settling
            first seeking
            accept AlignSignal
            then settling;
        state settling;
        transition settling_to_stable
            first settling
            accept SettleSignal
            then stable;
        state stable;
        transition stable_to_disturbed
            first stable
            accept DisturbSignal
            then disturbed;
        state disturbed;
        transition disturbed_to_seeking
            first disturbed
            accept ClearSignal
            then seeking;
    }

    action def DetermineHeading {
        in item field : EarthMagneticField;
        in item interference : MagneticInterference[0..*];
        out attribute heading : HeadingAngle;

        action seek {
            in item field : EarthMagneticField;
            out attribute alignment : HeadingAngle;
        }
        flow seek.alignment to settle.alignment;
        action settle {
            in attribute alignment : HeadingAngle;
            out attribute stableHeading : HeadingAngle;
        }
        bind heading = settle.stableHeading;
    }

    part def HirtzMagneticCompass {
        port environmentPort : EnvironmentPort;
        port headingPort : HeadingPort;

        part needle : MagnetizedNeedle;
        part pivot : PivotAssembly;
        part card : CompassCard;
        part lubberLine : LubberLine;
        part chamber : DampingChamber;
        part housing : ProtectiveHousing;

        attribute currentHeading : HeadingAngle;

        connection needleToPivot connect needle to pivot;
        connection needleToCard connect needle to card;
        connection chamberToHousing connect chamber to housing;
        connection lubberLineToHousing connect lubberLine to housing;

        perform action determineHeading : DetermineHeading {
            in item field = environmentPort.field;
            in item interference = environmentPort.interference;
        }
        bind currentHeading = determineHeading.heading;
        bind headingPort.heading = currentHeading;

        state compassState : CompassOperationStates;
    }

    requirement def StableHeadingRequirement {
        doc /* The compass shall provide a stable heading indication within 2 degrees after settling. */
        attribute maxError : HeadingAngle = 2.0;
    }

    requirement def LowFrictionPivotRequirement {
        doc /* The pivot assembly shall provide a coefficient of friction no greater than 0.05 to ensure needle sensitivity. */
        attribute maxFriction : FrictionCoefficient = 0.05;
    }

    requirement def DampingPerformanceRequirement {
        doc /* The damping fluid shall reduce needle oscillations by 90 percent within 5 seconds. */
        attribute settlingTime : TimeValue = 5.0;
        attribute reductionPercent : Real = 90.0;
    }

    requirement def HermeticSealingRequirement {
        doc /* The protective housing shall be hermetically sealed to prevent moisture and contaminant ingress. */
        attribute ingressProtection : String = "IP68";
    }

    requirement def MagneticHeadingAccuracyRequirement {
        doc /* The compass shall indicate magnetic heading with an accuracy of plus or minus 1 degree in stable conditions. */
        attribute accuracy : HeadingAngle = 1.0;
    }

    requirement def NonElectronicOperationRequirement {
        doc /* The instrument shall operate without external electrical power or electronic components. */
        attribute powerSource : String = "Magnetic";
    }

    requirement stableHeadingReq : StableHeadingRequirement;
    requirement lowFrictionPivotReq : LowFrictionPivotRequirement;
    requirement dampingPerformanceReq : DampingPerformanceRequirement;
    requirement hermeticSealingReq : HermeticSealingRequirement;
    requirement magneticHeadingAccuracyReq : MagneticHeadingAccuracyRequirement;
    requirement nonElectronicOperationReq : NonElectronicOperationRequirement;

    part compass : HirtzMagneticCompass {
        part needle : MagnetizedNeedle {
            magneticMoment = 1.2;
        }
        part pivot : PivotAssembly {
            friction = 0.02;
            part bearing : SapphireBearing {
                frictionCoefficient = 0.01;
            }
        }
        part card : CompassCard {
            angularResolution = 2.0;
            cardinalPoints = (CardinalDirection::N, CardinalDirection::S, CardinalDirection::E, CardinalDirection::W, CardinalDirection::NE, CardinalDirection::NW, CardinalDirection::SE, CardinalDirection::SW);
        }
        part lubberLine : LubberLine {
            fixedAlignment = 0.0;
        }
        part chamber : DampingChamber {
            dampingRatio = 0.7;
            part fluid : MineralOil {
                viscosity = 0.05;
                density = 850;
            }
        }
        part housing : ProtectiveHousing {
            material = "Brass";
            sealed = true;
            part window : GlassWindow {
                opticalClarity = 0.95;
            }
            part seal : HermeticSeal {
                leakRate = 0.0;
            }
        }
    }

    satisfy stableHeadingReq by compass;
    satisfy lowFrictionPivotReq by compass;
    satisfy dampingPerformanceReq by compass;
    satisfy hermeticSealingReq by compass;
    satisfy magneticHeadingAccuracyReq by compass;
    satisfy nonElectronicOperationReq by compass;
}
