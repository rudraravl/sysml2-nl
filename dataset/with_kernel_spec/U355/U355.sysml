package PlagueDoctorCostumeSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    private import NumericalFunctions::*;

    item def AromaticMixture {
        attribute camphor : MassValue;
        attribute mint : MassValue;
        attribute cloves : MassValue;
        attribute potency : Real;
    }

    item def Air {
        attribute quality : String;
    }

    item def BadAir :> Air {
        attribute pathogenConcentration : Real;
    }

    item def PurifiedAir :> Air {
        attribute pathogenConcentration : Real;
    }

    port def AirIntakePort {
        in item airIn : BadAir;
    }

    port def AirOutletPort {
        out item airOut : PurifiedAir;
    }

    action def FilterAir {
        in badAir : BadAir;
        in herbs : AromaticMixture;
        out purifiedAir : PurifiedAir;
        constraint {
            purifiedAir.pathogenConcentration <= badAir.pathogenConcentration * (1.0 - herbs.potency / 100.0)
        }
    }

    action def ReWax {
        out integrity : Real;
    }

    action def ExaminePatient {
        in distance : LengthValue;
    }

    action def DonCostume {
        in part costume : PlagueDoctorCostume;
    }

    action def DoffCostume {
        in part costume : PlagueDoctorCostume;
    }

    action def MaintainCostume {
        in part mask : BeakedMask;
        in part coat : WaxedLeatherCoat;
    }

    part def BeakedMask {
        attribute maskMass : MassValue;
        attribute beakLength : LengthValue;
        attribute sealIntegrity : Real;

        part aromaticChamber {
            item aromatics : AromaticMixture;
            attribute fillLevel : Real;
        }
        part eyepieces {
            attribute material : String = "Glass";
            attribute transparency : Real;
        }
        part harness {
            attribute material : String = "Leather";
            attribute tension : Real;
        }

        port airIntakePort : AirIntakePort;
        port airOutletPort : AirOutletPort;

        perform filterAir : FilterAir;
    }

    part def WaxedLeatherCoat {
        attribute coatMass : MassValue;
        attribute length : LengthValue;
        attribute waxIntegrity : Real;
        attribute waterRepellency : Real;
        perform reWaxAction : ReWax;
    }

    part def ThickLeatherGloves {
        attribute gloveMass : MassValue;
        attribute thickness : LengthValue;
        attribute punctureResistance : Real;
    }

    part def HighLeatherBoots {
        attribute bootMass : MassValue;
        attribute height : LengthValue;
        attribute waterResistance : Real;
    }

    part def WideBrimmedHat {
        attribute hatMass : MassValue;
        attribute brimWidth : LengthValue;
        attribute headCoverage : Real;
    }

    part def WoodenCane {
        attribute caneMass : MassValue;
        attribute length : LengthValue;
        attribute reachDistance : LengthValue;
        perform examinePatientAction : ExaminePatient;
    }

    part def PlagueDoctorCostume {
        attribute totalMass : MassValue;
        attribute protectionLevel : Real;
        attribute deploymentStatus : String;

        part mask : BeakedMask;
        part coat : WaxedLeatherCoat;
        part gloves : ThickLeatherGloves;
        part boots : HighLeatherBoots;
        part hat : WideBrimmedHat;
        part cane : WoodenCane;

        perform donCostumeAction : DonCostume {
            in costume = self;
        }
        perform doffCostumeAction : DoffCostume {
            in costume = self;
        }
        perform maintainCostumeAction : MaintainCostume {
            in mask = mask;
            in coat = coat;
        }

        exhibit costumeStates : CostumeStates {
            in costume = self;
        }
    }

    state def CostumeStates {
        in costume : PlagueDoctorCostume;

        state Stored;
        state Donning {
            entry perform costume.donCostumeAction;
        }
        state Operational {
            do perform costume.mask.filterAir;
        }
        state Maintenance {
            entry perform costume.maintainCostumeAction;
        }
        state Doffing {
            entry perform costume.doffCostumeAction;
        }

        transition from Stored to Donning when costume.deploymentStatus == "InitiateDonning";
        transition from Donning to Operational when costume.deploymentStatus == "Donned";
        transition from Operational to Maintenance when costume.mask.aromaticChamber.aromatics.potency < 50.0 or costume.coat.waxIntegrity < 80.0;
        transition from Maintenance to Operational when costume.deploymentStatus == "Maintained";
        transition from Operational to Doffing when costume.deploymentStatus == "InitiateDoffing";
        transition from Doffing to Stored when costume.deploymentStatus == "Doffed";
    }

    requirement def ProtectWearer {
        subject costume : PlagueDoctorCostume;
        doc /* The costume must protect the wearer from contagion. */
    }

    requirement def FilterBadAir {
        subject mask : BeakedMask;
        attribute minFiltrationEfficiency : Real = 0.9;
        doc /* The mask must filter bad air using aromatics to reduce pathogen concentration by at least 90%. */
        verify FilterAir;
    }

    requirement def ProvidePhysicalBarrier {
        subject coat : WaxedLeatherCoat;
        attribute minBarrierIntegrity : Real = 95.0;
        doc /* The costume must provide a physical barrier against fluids. */
    }

    requirement def EnablePhysicalDistancing {
        subject cane : WoodenCane;
        attribute minDistance : LengthValue = 1.0;
        doc /* The cane must allow examination from a minimum distance of 1 meter. */
        verify ExaminePatient;
    }

    requirement def TotalMassLimit {
        subject costume : PlagueDoctorCostume;
        attribute maxMass : MassValue = 15.0;
        doc /* The total mass of the costume shall not exceed 15 kg. */
    }

    part plagueDoctorCostume : PlagueDoctorCostume {
        part mask : BeakedMask {
            attribute maskMass = 1.5;
            attribute beakLength = 0.3;
            attribute sealIntegrity = 98.0;
            part aromaticChamber {
                item aromatics : AromaticMixture {
                    attribute camphor = 0.05;
                    attribute mint = 0.03;
                    attribute cloves = 0.02;
                    attribute potency = 100.0;
                }
                attribute fillLevel = 1.0;
            }
            part eyepieces {
                attribute transparency = 95.0;
            }
            part harness {
                attribute tension = 50.0;
            }
        }
        part coat : WaxedLeatherCoat {
            attribute coatMass = 4.5;
            attribute length = 1.4;
            attribute waxIntegrity = 100.0;
            attribute waterRepellency = 98.0;
        }
        part gloves : ThickLeatherGloves {
            attribute gloveMass = 0.8;
            attribute thickness = 0.005;
            attribute punctureResistance = 95.0;
        }
        part boots : HighLeatherBoots {
            attribute bootMass = 2.5;
            attribute height = 0.45;
            attribute waterResistance = 98.0;
        }
        part hat : WideBrimmedHat {
            attribute hatMass = 0.6;
            attribute brimWidth = 0.3;
            attribute headCoverage = 98.0;
        }
        part cane : WoodenCane {
            attribute caneMass = 0.7;
            attribute length = 1.5;
            attribute reachDistance = 1.2;
        }
        attribute deploymentStatus = "Stored";
    }

    calc def MassSum {
        in partMasses : MassValue[0..*];
        return totalMass : MassValue = sum(partMasses);
    }

    calc costumeMassCalc : MassSum {
        in partMasses = (plagueDoctorCostume.mask.maskMass, plagueDoctorCostume.coat.coatMass, plagueDoctorCostume.gloves.gloveMass, plagueDoctorCostume.boots.bootMass, plagueDoctorCostume.hat.hatMass, plagueDoctorCostume.cane.caneMass);
        return totalMass;
    }

    attribute actualTotalMass : MassValue = costumeMassCalc.totalMass;
}
