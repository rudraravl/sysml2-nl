package HotWaterBottleSystem {
    import ScalarValues::*;

    // ---- Units ----
    unit mm;
    unit cm;
    unit m = 1000 mm;
    unit cm3;
    unit L = 1000 cm3;
    unit K;
    unit degC;
    unit Pa;
    unit W;
    unit J;
    unit s;
    unit min = 60 s;
    unit h = 60 min;
    unit W_per_mK;
    unit J_per_K;
    unit W_per_m2K;

    // ---- Value types ----
    value def Length : Real { unit mm; }
    value def Thickness : Real { unit mm; }
    value def Volume : Real { unit L; }
    value def Temperature : Real { unit degC; }
    value def ThermalConductivity : Real { unit W_per_mK; }
    value def HeatCapacity : Real { unit J_per_K; }
    value def Power : Real { unit W; }
    value def Energy : Real { unit J; }
    value def Duration : Real { unit h; }
    value def Pressure : Real { unit Pa; }
    value def HeatTransferCoefficient : Real { unit W_per_m2K; }
    value def Mass : Real { unit 'kg'; }

    // ---- Items ----
    item def Water {
        attribute temperature : Temperature;
        attribute volume : Volume;
        attribute mass : Mass;
        attribute specificHeat : Real = 4180; // J/(kg.K)
    }
    item def HotWater :> Water;

    // ---- Material definitions ----
    attribute def RubberMaterial {
        attribute thermalConductivity : ThermalConductivity = 0.15;
        attribute maxOperatingTemp : Temperature = 90;
        attribute minOperatingTemp : Temperature = -10;
        attribute tensileStrength : Pressure = 21e6;
    }
    attribute def CottonFleece {
        attribute thermalConductivity : ThermalConductivity = 0.04;
        attribute thickness : Thickness = 4.0;
    }

    // ---- Ports ----
    port def ThermalPort {
        attribute temperature : Temperature;
        out item heatFlow : Energy;
    }
    port def WaterFlowPort {
        in out item water : Water;
    }

    // ---- Parts ----
    part def RubberContainer {
        attribute material : RubberMaterial;
        attribute capacity : Volume = 2.0;
        attribute wallThickness : Thickness = 2.5;
        attribute currentVolume : Volume;
        attribute currentTemp : Temperature;
        attribute operatingTempMin : Temperature = 0;
        attribute operatingTempMax : Temperature = 85;

        port fillingOpening : WaterFlowPort;
        port outerSurface : ThermalPort;
        port innerSurface : ThermalPort;

        requirement def ContainerIntegrity {
            subject container : RubberContainer;
            require container.currentTemp <= container.operatingTempMax
                and container.currentTemp >= container.operatingTempMin;
        }

        exhibit ContainerIntegrity;

        action def Fill {
            in item water : HotWater;
            attribute filledVolume : Volume;
        }
        action def Empty {
            out item water : Water;
        }
    }

    part def ScrewCap {
        attribute threadDiameter : Length = 35.0;
        attribute sealIntegrity : Real = 1.0; // 0..1, 1 = perfect seal
        attribute maxPressure : Pressure = 50e3;

        port def CapInterface {
            in out item water : Water;
        }
        port attachment : CapInterface;

        requirement def SealEffectiveness {
            subject cap : ScrewCap;
            require cap.sealIntegrity >= 0.95;
        }

        exhibit SealEffectiveness;

        action def Seal {
            attribute sealed : Boolean = true;
        }
        action def Unseal {
            attribute sealed : Boolean = false;
        }
    }

    part def FabricCover {
        attribute material : CottonFleece;
        attribute insulationThickness : Thickness = 4.0;
        attribute externalSurfaceTemp : Temperature;
        attribute comfortableTempMax : Temperature = 45;

        port innerSide : ThermalPort;
        port outerSide : ThermalPort;

        requirement def ComfortableSurface {
            subject cover : FabricCover;
            require cover.externalSurfaceTemp <= cover.comfortableTempMax;
        }

        exhibit ComfortableSurface;
    }

    // ---- Assembly ----
    part def HotWaterBottle {
        attribute roomTemp : Temperature = 22;
        attribute therapeuticTempMin : Temperature = 40;
        attribute minRetentionDuration : Duration = 2.0;
        attribute currentWaterTemp : Temperature;
        attribute currentWaterVolume : Volume;

        part container : RubberContainer {
            redefines capacity = 2.0;
            redefines wallThickness = 2.5;
        }
        part cap : ScrewCap;
        part cover : FabricCover;

        connection container.fillingOpening to cap.attachment {
            item water : Water;
        }
        connection container.outerSurface to cover.innerSide {
            item heatFlow : Energy;
        }

        requirement def TherapeuticRetention {
            subject bottle : HotWaterBottle;
            require bottle.currentWaterTemp >= bottle.therapeuticTempMin
                for bottle.minRetentionDuration;
        }

        exhibit TherapeuticRetention;

        // ---- Lifecycle state machine ----
        state def Lifecycle {
            entry; then Empty;

            state Empty {
                entry assign container.currentVolume = 0;
                entry assign container.currentTemp = roomTemp;
                transition Empty -> Filling
                    when container.fillingOpening.water.volume > 0
                    do Fill;
            }

            state Filling {
                do action Fill {
                    in item hotWater : HotWater;
                    attribute targetVolume : Volume = container.capacity;
                    constraint container.currentVolume <= container.capacity;
                }
                transition Filling -> Sealed
                    when container.currentVolume > 0
                    do Seal;
            }

            state Sealed {
                do action Seal {
                    attribute cap.sealIntegrity = 1.0;
                }
                transition Sealed -> Active
                    when cap.sealIntegrity >= 0.95;
            }

            state Active {
                entry assign currentWaterTemp = container.currentTemp;
                do action RadiateHeat {
                    attribute heatLossRate : Power;
                    constraint cover.externalSurfaceTemp <= cover.comfortableTempMax;
                }
                transition Active -> Cooling
                    when currentWaterTemp < therapeuticTempMin;
            }

            state Cooling {
                do action CoolDown {
                    attribute coolingRate : Real; // degC per h
                }
                transition Cooling -> Empty
                    when currentWaterTemp <= roomTemp + 2
                    do Empty;
            }
        }

        exhibit Lifecycle;

        action def Fill {
            in item hotWater : HotWater;
            attribute filledVolume : Volume;
            constraint filledVolume <= container.capacity;
        }
        action def Seal {
            attribute sealed : Boolean = true;
        }
        action def RadiateHeat {
            out item heatFlow : Energy;
            attribute duration : Duration;
        }
        action def Empty {
            out item water : Water;
        }
    }

    // ---- Top-level requirements ----
    requirement def HotWaterBottleRequirements {
        subject bottle : HotWaterBottle;

        requirement CapacityRequirement {
            require bottle.container.capacity == 2.0;
        }
        requirement OperatingTemperatureRequirement {
            require bottle.container.operatingTempMax >= 85;
            require bottle.container.operatingTempMin <= 0;
        }
        requirement SealIntegrityRequirement {
            require bottle.cap.sealIntegrity >= 0.95;
        }
        requirement ComfortableSurfaceRequirement {
            require bottle.cover.externalSurfaceTemp <= bottle.cover.comfortableTempMax;
        }
        requirement TherapeuticRetentionRequirement {
            require bottle.currentWaterTemp >= bottle.therapeuticTempMin
                for bottle.minRetentionDuration;
        }
        requirement NoLeakRequirement {
            require bottle.cap.maxPressure >= 50e3;
        }
    }

    part bottleInstance : HotWaterBottle {
        satisfy HotWaterBottleRequirements by bottleInstance;
    }
}
