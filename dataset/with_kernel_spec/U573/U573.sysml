package TrompeSystem {
    private import SI::*;
    private import ScalarValues::*;

    item def Water;
    item def Air;
    item def AeratedMixture;
    item def CompressedAir;

    port def WaterIntakePort {
        in waterFlow : Water;
        in airFlow : Air;
    }
    port def MixtureOutPort {
        out mixtureFlow : AeratedMixture;
    }
    port def MixtureInPort {
        in mixtureFlow : AeratedMixture;
    }
    port def CompressedAirOutPort {
        out compressedAirFlow : CompressedAir;
    }
    port def WaterOutPort {
        out waterFlow : Water;
    }
    port def WaterInPort {
        in waterFlow : Water;
    }

    part def IntakeSection {
        port waterIntake : WaterIntakePort;
        port mixtureOut : MixtureOutPort;
        attribute intakeHeight : LengthValue;
    }

    part def VerticalShaft {
        port mixtureIn : MixtureInPort;
        port mixtureOut : MixtureOutPort;
        attribute shaftDepth : LengthValue;
    }

    part def SeparationVessel {
        port mixtureIn : MixtureInPort;
        port airOut : CompressedAirOutPort;
        port waterOut : WaterOutPort;
        attribute vesselVolume : VolumeValue;
    }

    part def TailraceOutlet {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    action def EntrainAir {
        in water : Water;
        in air : Air;
        out mixture : AeratedMixture;
    }

    action def CompressAir {
        in mixtureIn : AeratedMixture;
        out mixtureOut : AeratedMixture;
    }

    action def SeparateMixture {
        in mixtureIn : AeratedMixture;
        out airOut : CompressedAir;
        out waterOut : Water;
    }

    action def DischargeWater {
        in waterIn : Water;
        out waterOut : Water;
    }

    action def OperateTrompe {
        in waterIn : Water;
        in airIn : Air;
        out airOut : CompressedAir;
        out waterOut : Water;

        action entrain : EntrainAir {
            in water = OperateTrompe::waterIn;
            in air = OperateTrompe::airIn;
        }
        flow entrain.mixture to compress.mixtureIn;

        action compress : CompressAir;
        flow compress.mixtureOut to separate.mixtureIn;

        action separate : SeparateMixture;
        flow separate.waterOut to discharge.waterIn;

        action discharge : DischargeWater;
        bind discharge.waterOut = OperateTrompe::waterOut;
        bind separate.airOut = OperateTrompe::airOut;
    }

    requirement def PassiveOperation {
        doc /* The system must operate continuously without moving parts or external electricity. */
        attribute hasMovingParts : Boolean = false;
        attribute usesExternalElectricity : Boolean = false;
        constraint noMovingParts { hasMovingParts == false }
        constraint noExternalElectricity { usesExternalElectricity == false }
    }

    requirement def PerformanceDetermination {
        doc /* Performance is determined by the height of the water source and the depth of the vertical shaft. */
        attribute sourceHeight : LengthValue;
        attribute shaftDepth : LengthValue;
        attribute outputPressure : PressureValue;
        constraint pressureRelation { outputPressure > 0 [Pa] }
    }

    part trompeSystem {
        part intake : IntakeSection {
            attribute intakeHeight = 10 [m];
        }
        part shaft : VerticalShaft {
            attribute shaftDepth = 50 [m];
        }
        part vessel : SeparationVessel {
            attribute vesselVolume = 100 [m^3];
        }
        part tailrace : TailraceOutlet;

        flow intake.mixtureOut.mixtureFlow to shaft.mixtureIn.mixtureFlow;
        flow shaft.mixtureOut.mixtureFlow to vessel.mixtureIn.mixtureFlow;
        flow vessel.waterOut.waterFlow to tailrace.waterIn.waterFlow;

        requirement passiveOp : PassiveOperation;
        requirement perfDet : PerformanceDetermination;
        satisfy passiveOp;
        satisfy perfDet;

        perform action operate : OperateTrompe {
            in waterIn = intake.waterIntake.waterFlow;
            in airIn = intake.waterIntake.airFlow;
            out airOut = vessel.airOut.compressedAirFlow;
            out waterOut = tailrace.waterOut.waterFlow;
        }
    }
}
