package SerbianBarrel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def Water;

    part def Stave {
        attribute height: LengthValue = 1.0 [m];
        attribute thickness: LengthValue = 0.02 [m];
        attribute intact: Boolean = true;
    }

    part def Hoop {
        attribute diameter: LengthValue = 0.6 [m];
        attribute width: LengthValue = 0.005 [m];
    }

    part def Base {
        attribute diameter: LengthValue = 0.6 [m];
        attribute thickness: LengthValue = 0.05 [m];
    }

    port def InletPort {
        in item water: Water;
    }

    port def OutletPort {
        out item water: Water;
    }

    port def OverflowPort {
        out item water: Water;
    }

    action def 'Determine Capacity' {
        in staves: Stave[24];
        out shortestHeight: LengthValue;
        out capacity: VolumeValue;
    }

    action def 'Inspect Staves' {
        in staves: Stave[24];
        out allIntact: Boolean;
    }

    state def BarrelStateMachine {
        state empty;
        state filling;
        state partiallyFull;
        state full;
        state draining;

        transition empty_to_filling first empty then filling;
        transition filling_to_partiallyFull first filling then partiallyFull;
        transition partiallyFull_to_full first partiallyFull then full;
        transition full_to_draining first full then draining;
        transition draining_to_partiallyFull first draining then partiallyFull;
        transition draining_to_empty first draining then empty;
    }

    part def Barrel {
        attribute waterLevel: LengthValue = 0.0 [m];
        attribute minStaveHeight: LengthValue;
        attribute baseArea: AreaValue;
        attribute capacity: VolumeValue;
        attribute structuralIntegrity: Boolean = true;

        port inlet: InletPort;
        port outlet: OutletPort;
        port overflow: OverflowPort;

        part stave01 : Stave;
        part stave02 : Stave;
        part stave03 : Stave;
        part stave04 : Stave;
        part stave05 : Stave;
        part stave06 : Stave;
        part stave07 : Stave;
        part stave08 : Stave;
        part stave09 : Stave;
        part stave10 : Stave;
        part stave11 : Stave;
        part stave12 : Stave;
        part stave13 : Stave;
        part stave14 : Stave;
        part stave15 : Stave;
        part stave16 : Stave;
        part stave17 : Stave;
        part stave18 : Stave;
        part stave19 : Stave;
        part stave20 : Stave;
        part stave21 : Stave;
        part stave22 : Stave;
        part stave23 : Stave;
        part stave24 : Stave;

        part hoop01 : Hoop;
        part hoop02 : Hoop;
        part hoop03 : Hoop;
        part hoop04 : Hoop;

        part base : Base;

        constraint capacityConstraint {
            capacity == baseArea * minStaveHeight and
            waterLevel <= minStaveHeight and
            waterLevel >= 0.0 [m]
        }

        exhibit barrelStates : BarrelStateMachine;

        perform action 'analyze stave heights': 'Determine Capacity';
        perform action 'inspect staves': 'Inspect Staves';
    }

    part serbianBarrel : Barrel {
        attribute :>> minStaveHeight = 0.8 [m];
        attribute :>> baseArea = 0.282743 [m^2];
        attribute :>> capacity = 0.226194 [m^3];
        attribute :>> waterLevel = 0.0 [m];
        attribute :>> structuralIntegrity = true;

        part :>> stave01 { attribute :>> height = 1.0 [m]; }
        part :>> stave02 { attribute :>> height = 1.0 [m]; }
        part :>> stave03 { attribute :>> height = 1.0 [m]; }
        part :>> stave04 { attribute :>> height = 1.0 [m]; }
        part :>> stave05 { attribute :>> height = 1.0 [m]; }
        part :>> stave06 { attribute :>> height = 1.0 [m]; }
        part :>> stave07 { attribute :>> height = 1.0 [m]; }
        part :>> stave08 { attribute :>> height = 1.0 [m]; }
        part :>> stave09 { attribute :>> height = 1.0 [m]; }
        part :>> stave10 { attribute :>> height = 1.0 [m]; }
        part :>> stave11 { attribute :>> height = 1.0 [m]; }
        part :>> stave12 { attribute :>> height = 0.8 [m]; }
        part :>> stave13 { attribute :>> height = 1.0 [m]; }
        part :>> stave14 { attribute :>> height = 1.0 [m]; }
        part :>> stave15 { attribute :>> height = 1.0 [m]; }
        part :>> stave16 { attribute :>> height = 1.0 [m]; }
        part :>> stave17 { attribute :>> height = 1.0 [m]; }
        part :>> stave18 { attribute :>> height = 1.0 [m]; }
        part :>> stave19 { attribute :>> height = 1.0 [m]; }
        part :>> stave20 { attribute :>> height = 1.0 [m]; }
        part :>> stave21 { attribute :>> height = 1.0 [m]; }
        part :>> stave22 { attribute :>> height = 1.0 [m]; }
        part :>> stave23 { attribute :>> height = 1.0 [m]; }
        part :>> stave24 { attribute :>> height = 1.0 [m]; }

        part :>> base { attribute :>> diameter = 0.6 [m]; }

        port :>> inlet;
        port :>> outlet;
        port :>> overflow;
    }

    requirement def ShortestStaveCapacityRequirement {
        doc /* The effective water capacity of a wooden barrel is limited by the shortest stave height. */
        attribute minStaveHeight: LengthValue;
        attribute baseArea: AreaValue;
        attribute capacity: VolumeValue;
        require constraint {
            capacity == baseArea * minStaveHeight
        }
    }

    requirement shortestStaveCapacity : ShortestStaveCapacityRequirement {
        subject barrel: Barrel;
        attribute :>> minStaveHeight = barrel.minStaveHeight;
        attribute :>> baseArea = barrel.baseArea;
        attribute :>> capacity = barrel.capacity;
    }

    requirement def OverflowManagementRequirement {
        doc /* Water level shall never exceed the effective capacity of the barrel; excess water is managed via the overflow port. */
        attribute waterLevel: LengthValue;
        attribute minStaveHeight: LengthValue;
        require constraint {
            waterLevel <= minStaveHeight
        }
    }

    requirement overflowManagement : OverflowManagementRequirement {
        subject barrel: Barrel;
        attribute :>> waterLevel = barrel.waterLevel;
        attribute :>> minStaveHeight = barrel.minStaveHeight;
    }

    requirement def StructuralIntegrityRequirement {
        doc /* All staves and hoops shall be structurally sound so the barrel can safely contain water. */
        attribute structuralIntegrity: Boolean;
        require constraint {
            structuralIntegrity == true
        }
    }

    requirement structuralIntegrity : StructuralIntegrityRequirement {
        subject barrel: Barrel;
        attribute :>> structuralIntegrity = barrel.structuralIntegrity;
    }
}
