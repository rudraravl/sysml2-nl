package PlagueDoctorCostumeSystem {
    import ScalarValues::*;
    import ISQ::*;

    value type Length :> Real { unit "m"; }
    value type Mass :> Real { unit "kg"; }
    value type Area :> Real { unit "m2"; }
    value type Potency :> Real { unit "%"; }

    item def AromaticMixture {
        attribute composition : String;
        attribute mass : Mass;
        attribute potency : Potency;
    }
    item def ContagiousAir {
        attribute contaminationLevel : Real;
    }
    item def PurifiedAir {
        attribute aromaLevel : Real;
    }
    item def PhysicalContact;

    requirement def ProtectionRequirement {
        subject costume : PlagueDoctorCostume;
        objective {
            doc "The costume must protect the wearer from contagion via miasmatic air and physical contact."
        }
    }

    requirement def AirPurificationRequirement {
        subject mask : BeakedMask;
        attribute minBeakLength : Length = 0.15;
        objective {
            mask.beakLength >= minBeakLength
        }
    }

    part def PlagueDoctorCostume {
        port airIntakePort : ContagiousAir;
        port physicalContactPort : PhysicalContact;
        
        part beakedMask : BeakedMask {
            port in contagiousAirPort : ContagiousAir;
            port out purifiedAirPort : PurifiedAir;
        }
        part waxedLeatherCoat : WaxedLeatherCoat;
        part thickLeatherGloves : ThickLeatherGloves;
        part highLeatherBoots : HighLeatherBoots;
        part wideBrimmedHat : WideBrimmedHat;
        part woodenCane : WoodenCane;
        
        attribute coverageArea : Area;
        
        connect airIntakePort to beakedMask.contagiousAirPort;
        
        action donCostume : DonCostume;
        action doffCostume : DoffCostume;
        action maintainCostume : MaintainCostume;
        
        state machine CostumeLifecycle {
            state Stored;
            state Donning {
                entry { donCostume; }
            }
            state Operational {
                do { beakedMask.filterAir; }
            }
            state Maintenance {
                entry { maintainCostume; }
            }
            state Doffing {
                entry { doffCostume; }
            }
            
            transition Stored -> Donning;
            transition Donning -> Operational;
            transition Operational -> Maintenance;
            transition Maintenance -> Operational;
            transition Operational -> Doffing;
            transition Doffing -> Stored;
        }
    }

    action def DonCostume {
        action donBoots;
        action donCoat;
        action donGloves;
        action donHat;
        action donMask;
    }
    action def DoffCostume {
        action doffMask;
        action doffHat;
        action doffGloves;
        action doffCoat;
        action doffBoots;
    }
    action def MaintainCostume {
        action replenishHerbs {
            in out aromaticMixture : AromaticMixture;
        }
        action rewaxCoat {
            in out waxedLeatherCoat : WaxedLeatherCoat;
        }
    }

    part def BeakedMask {
        attribute beakLength : Length;
        part aromaticChamber {
            item aromaticMixture : AromaticMixture;
        }
        part eyepieces {
            attribute material : String = "Glass";
        }
        part leatherHarness;
        
        port in contagiousAirPort : ContagiousAir;
        port out purifiedAirPort : PurifiedAir;
        
        action filterAir {
            in contagiousAir : ContagiousAir;
            out purifiedAir : PurifiedAir;
        }
        
        connect contagiousAirPort to filterAir.contagiousAir;
        connect filterAir.purifiedAir to purifiedAirPort;
    }

    part def WaxedLeatherCoat {
        attribute waxCoating : Boolean = true;
        attribute length : Length;
    }

    part def ThickLeatherGloves {
        attribute thickness : Length;
    }

    part def HighLeatherBoots {
        attribute height : Length;
    }

    part def WideBrimmedHat {
        attribute brimWidth : Length;
    }

    part def WoodenCane {
        attribute length : Length = 1.0;
        action examinePatient;
    }
}
