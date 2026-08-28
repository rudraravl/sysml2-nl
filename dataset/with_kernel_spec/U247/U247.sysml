package 'Hot Water Bottle System' {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def Water {
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
    }

    attribute def Fill;
    attribute def FillComplete;
    attribute def Seal;
    attribute def Apply;
    attribute def Empty;

    port def WaterPort {
        in item water : Water;
    }

    part def RubberContainer {
        attribute volumeCapacity : VolumeValue;
        attribute wallThickness : LengthValue;
        attribute maxOperatingTemp : TemperatureValue;
        attribute minOperatingTemp : TemperatureValue;
        attribute thermalConductivity : Real;
        port fillPort : ~WaterPort;
        item storedWater : Water;
    }

    part def ScrewCap {
        attribute sealEffectiveness : Real;
        port capPort : WaterPort;
    }

    part def FabricCover {
        attribute material : String;
        attribute thermalResistance : Real;
        attribute maxSafeSurfaceTemp : TemperatureValue;
    }

    interface def CapContainerInterface {
        end capEnd : WaterPort;
        end containerEnd : ~WaterPort;
    }

    action def FillWater {
        in waterIn : Water;
        out waterStored : Water;
    }

    action def SealCap;

    action def RadiateHeat {
        out heatRate : PowerValue;
    }

    action def EmptyWater {
        in waterStored : Water;
        out waterOut : Water;
    }

    state def BottleLifecycle {
        action 'fill water' : FillWater;
        action 'seal cap' : SealCap;
        action 'radiate heat' : RadiateHeat;
        action 'empty water' : EmptyWater;

        entry; then empty;

        state empty;
        accept Fill
            do 'fill water'
            then filling;

        state filling {
            do 'fill water';
        }
        accept FillComplete
            then filled;

        state filled;
        accept Seal
            do 'seal cap'
            then sealed;

        state sealed {
            entry 'seal cap';
        }
        accept Apply
            then active;

        state active {
            do 'radiate heat';
        }
        accept Empty
            do 'empty water'
            then empty;
    }

    part def HotWaterBottle {
        attribute roomTemp : TemperatureValue = 293.15 [K];
        attribute therapeuticTemp : TemperatureValue = 313.15 [K];
        attribute therapeuticDuration : DurationValue = 2 [h];
        attribute currentTemp : TemperatureValue;

        part container : RubberContainer;
        part cap : ScrewCap;
        part cover : FabricCover;

        interface capConnection : CapContainerInterface
            connect cap.capPort to container.fillPort;

        exhibit state lifecycle : BottleLifecycle;
    }

    requirement def TherapeuticWarmthRequirement {
        subject bottle : HotWaterBottle;
        doc /* The hot water bottle shall retain a therapeutic level of warmth for at least 2 hours. */
        attribute actualRetentionTime : DurationValue;
        attribute requiredRetentionTime : DurationValue = 2 [h];
        require constraint { actualRetentionTime >= requiredRetentionTime }
    }

    requirement def CapacitySafetyRequirement {
        subject bottle : HotWaterBottle;
        doc /* The water volume shall not exceed the container capacity. */
        attribute actualVolume : VolumeValue;
        attribute maxCapacity : VolumeValue;
        require constraint { actualVolume <= maxCapacity }
    }

    requirement def SealIntegrityRequirement {
        subject bottle : HotWaterBottle;
        doc /* The screw cap shall maintain a leak-tight seal. */
        attribute minSealEffectiveness : Real = 0.9;
        attribute actualSealEffectiveness : Real;
        require constraint { actualSealEffectiveness >= minSealEffectiveness }
    }

    requirement def SafeSurfaceTempRequirement {
        subject bottle : HotWaterBottle;
        doc /* The external surface temperature shall not exceed a safe contact temperature. */
        attribute maxContactTemp : TemperatureValue;
        attribute actualSurfaceTemp : TemperatureValue;
        require constraint { actualSurfaceTemp <= maxContactTemp }
    }

    requirement def OperatingTempRangeRequirement {
        subject bottle : HotWaterBottle;
        doc /* The rubber container shall withstand the operating temperature range without degrading. */
        attribute actualTemp : TemperatureValue;
        attribute maxOpTemp : TemperatureValue;
        attribute minOpTemp : TemperatureValue;
        require constraint { actualTemp >= minOpTemp and actualTemp <= maxOpTemp }
    }

    part bottleSystem : HotWaterBottle {
        attribute :>> currentTemp = 293.15 [K];

        part :>> container : RubberContainer {
            attribute :>> volumeCapacity = 2 [L];
            attribute :>> wallThickness = 2 [mm];
            attribute :>> maxOperatingTemp = 373.15 [K];
            attribute :>> minOperatingTemp = 273.15 [K];
            attribute :>> thermalConductivity = 0.13;
        }

        part :>> cap : ScrewCap {
            attribute :>> sealEffectiveness = 0.99;
        }

        part :>> cover : FabricCover {
            attribute :>> material = "Cotton Fleece";
            attribute :>> thermalResistance = 0.5;
            attribute :>> maxSafeSurfaceTemp = 318.15 [K];
        }
    }

    requirement therapeuticWarmthReq : TherapeuticWarmthRequirement {
        subject :>> bottle = bottleSystem;
        attribute :>> actualRetentionTime = 2.5 [h];
    }

    requirement capacityReq : CapacitySafetyRequirement {
        subject :>> bottle = bottleSystem;
        attribute :>> actualVolume = bottleSystem.container.storedWater.volume;
        attribute :>> maxCapacity = bottleSystem.container.volumeCapacity;
    }

    requirement sealReq : SealIntegrityRequirement {
        subject :>> bottle = bottleSystem;
        attribute :>> actualSealEffectiveness = bottleSystem.cap.sealEffectiveness;
    }

    requirement safeSurfaceReq : SafeSurfaceTempRequirement {
        subject :>> bottle = bottleSystem;
        attribute :>> maxContactTemp = bottleSystem.cover.maxSafeSurfaceTemp;
        attribute :>> actualSurfaceTemp = bottleSystem.currentTemp;
    }

    requirement operatingTempReq : OperatingTempRangeRequirement {
        subject :>> bottle = bottleSystem;
        attribute :>> actualTemp = bottleSystem.currentTemp;
        attribute :>> maxOpTemp = bottleSystem.container.maxOperatingTemp;
        attribute :>> minOpTemp = bottleSystem.container.minOperatingTemp;
    }
}
