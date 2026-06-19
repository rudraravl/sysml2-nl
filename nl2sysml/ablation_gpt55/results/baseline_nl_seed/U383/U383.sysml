package SerbianBarrelModel {
    import ScalarValues::*;

    attribute def VolumeValue {
        attribute magnitude : Real;
        attribute unit : String = "L";
    }

    attribute def MassValue {
        attribute magnitude : Real;
        attribute unit : String = "kg";
    }

    attribute def LengthValue {
        attribute magnitude : Real;
        attribute unit : String = "mm";
    }

    attribute def PressureValue {
        attribute magnitude : Real;
        attribute unit : String = "kPa";
    }

    attribute def TemperatureValue {
        attribute magnitude : Real;
        attribute unit : String = "degC";
    }

    attribute def TimeValue {
        attribute magnitude : Real;
        attribute unit : String = "day";
    }

    attribute def PercentValue {
        attribute magnitude : Real;
        attribute unit : String = "%";
    }

    attribute def FlowRateValue {
        attribute magnitude : Real;
        attribute unit : String = "L/min";
    }

    item def Beverage {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute alcoholByVolume : PercentValue;
        attribute oakAromaLevel : PercentValue;
        attribute clarity : PercentValue;
    }

    item def Rakija :> Beverage {
        attribute fruitBase : String = "plum";
        attribute traditionalName : String = "sljivovica";
    }

    item def CleaningWater {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
    }

    item def Air {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute relativeHumidity : PercentValue;
    }

    item def OakAromaCompounds {
        attribute extractionLevel : PercentValue;
    }

    item def Sediment {
        attribute mass : MassValue;
    }

    port def LiquidPort {
        in item liquidIn : Beverage;
        out item liquidOut : Beverage;
    }

    port def WaterPort {
        in item waterIn : CleaningWater;
        out item waterOut : CleaningWater;
    }

    port def GasPort {
        in item gasIn : Air;
        out item gasOut : Air;
    }

    port def AromaExchangePort {
        out item aromaOut : OakAromaCompounds;
    }

    port def SedimentPort {
        out item sedimentOut : Sediment;
    }

    connection def LiquidPassage {
        end source : LiquidPort;
        end target : LiquidPort;
    }

    connection def GasPassage {
        end source : GasPort;
        end target : GasPort;
    }

    connection def AromaInterface {
        end oakSide : AromaExchangePort;
        end liquidSide : AromaExchangePort;
    }

    part def OakStave {
        attribute staveCount : Integer = 32;
        attribute woodSpecies : String = "Serbian oak";
        attribute length : LengthValue {
            :>> magnitude = 780.0;
            :>> unit = "mm";
        }
        attribute thickness : LengthValue {
            :>> magnitude = 28.0;
            :>> unit = "mm";
        }
        attribute moistureContent : PercentValue {
            :>> magnitude = 12.0;
            :>> unit = "%";
        }
        port innerOakSurface : AromaExchangePort;
    }

    part def BarrelHead {
        attribute diameter : LengthValue {
            :>> magnitude = 520.0;
            :>> unit = "mm";
        }
        attribute thickness : LengthValue {
            :>> magnitude = 32.0;
            :>> unit = "mm";
        }
        port headOakSurface : AromaExchangePort;
    }

    part def SteelHoop {
        attribute hoopCount : Integer = 6;
        attribute bandWidth : LengthValue {
            :>> magnitude = 45.0;
            :>> unit = "mm";
        }
        attribute clampingPreload : PressureValue {
            :>> magnitude = 180.0;
            :>> unit = "kPa";
        }
    }

    part def BungStopper {
        attribute material : String = "seasoned oak";
        attribute diameter : LengthValue {
            :>> magnitude = 48.0;
            :>> unit = "mm";
        }
        attribute sealingCompression : PercentValue {
            :>> magnitude = 8.0;
            :>> unit = "%";
        }
        port ventSide : GasPort;
    }

    part def BrassSpigot {
        attribute material : String = "brass";
        attribute maximumDispenseRate : FlowRateValue {
            :>> magnitude = 1.8;
            :>> unit = "L/min";
        }
        attribute closedLeakRate : FlowRateValue {
            :>> magnitude = 0.0;
            :>> unit = "L/min";
        }
        port barrelSide : LiquidPort;
        port servingSide : LiquidPort;
    }

    part def WoodenStand {
        attribute material : String = "beech";
        attribute supportedMass : MassValue {
            :>> magnitude = 180.0;
            :>> unit = "kg";
        }
        attribute elevation : LengthValue {
            :>> magnitude = 420.0;
            :>> unit = "mm";
        }
    }

    part def InteriorCavity {
        attribute usableVolume : VolumeValue {
            :>> magnitude = 120.0;
            :>> unit = "L";
        }
        attribute ullageVolume : VolumeValue {
            :>> magnitude = 4.0;
            :>> unit = "L";
        }
        attribute internalPressure : PressureValue {
            :>> magnitude = 101.3;
            :>> unit = "kPa";
        }
        attribute storageTemperature : TemperatureValue {
            :>> magnitude = 14.0;
            :>> unit = "degC";
        }
        attribute fillFraction : PercentValue {
            :>> magnitude = 0.0;
            :>> unit = "%";
        }
        port inlet : LiquidPort;
        port outlet : LiquidPort;
        port vent : GasPort;
        port oakContact : AromaExchangePort;
        port sedimentDrain : SedimentPort;
    }

    action def FillBarrel {
        in item beverageIn : Rakija;
        out item containedBeverage : Rakija;
        attribute commandedFillVolume : VolumeValue {
            :>> magnitude = 110.0;
            :>> unit = "L";
        }
        attribute maximumFillRate : FlowRateValue {
            :>> magnitude = 8.0;
            :>> unit = "L/min";
        }
    }

    action def SealBarrel {
        in item airBeforeSeal : Air;
        out item trappedAir : Air;
        attribute targetUllageVolume : VolumeValue {
            :>> magnitude = 4.0;
            :>> unit = "L";
        }
    }

    action def MatureInOak {
        in item beverageIn : Rakija;
        in item aroma : OakAromaCompounds;
        out item maturedBeverage : Rakija;
        attribute maturationDuration : TimeValue {
            :>> magnitude = 180.0;
            :>> unit = "day";
        }
        attribute targetOakAromaLevel : PercentValue {
            :>> magnitude = 65.0;
            :>> unit = "%";
        }
        attribute targetClarity : PercentValue {
            :>> magnitude = 90.0;
            :>> unit = "%";
        }
    }

    action def DispenseBeverage {
        in item beverageIn : Rakija;
        out item beverageOut : Rakija;
        attribute servingFlowRate : FlowRateValue {
            :>> magnitude = 1.2;
            :>> unit = "L/min";
        }
    }

    action def RinseAndPrepare {
        in item rinseWater : CleaningWater;
        out item usedWater : CleaningWater;
        out item removedSediment : Sediment;
        attribute rinseVolume : VolumeValue {
            :>> magnitude = 15.0;
            :>> unit = "L";
        }
    }

    action def SerbianBarrelPrimaryFunction {
        in item freshRakija : Rakija;
        in item cellarAir : Air;
        out item servedRakija : Rakija;

        action fill : FillBarrel;
        action seal : SealBarrel;
        action mature : MatureInOak;
        action dispense : DispenseBeverage;

        flow freshRakija to fill.beverageIn;
        flow fill.containedBeverage to mature.beverageIn;
        flow cellarAir to seal.airBeforeSeal;
        flow mature.maturedBeverage to dispense.beverageIn;
        flow dispense.beverageOut to servedRakija;
    }

    state def BarrelOperatingStates {
        state empty;
        state filling;
        state sealed;
        state maturing;
        state readyToServe;
        state dispensing;
        state cleaning;

        transition initialize first empty;
        transition beginFill first empty then filling;
        transition completeFill first filling then sealed;
        transition beginMaturation first sealed then maturing;
        transition maturationComplete first maturing then readyToServe;
        transition openSpigot first readyToServe then dispensing;
        transition closeSpigot first dispensing then readyToServe;
        transition emptyForCleaning first readyToServe then cleaning;
        transition rinseComplete first cleaning then empty;
    }

    part def SerbianBarrel {
        doc /* Primary high-level function: receive traditional Serbian fruit brandy, contain it safely in an oak barrel, condition it through controlled oak contact and cellar storage, and dispense it for serving. */

        attribute localName : String = "srpsko hrastovo bure";
        attribute intendedBeverage : String = "sljivovica rakija";
        attribute nominalCapacity : VolumeValue {
            :>> magnitude = 120.0;
            :>> unit = "L";
        }
        attribute emptyMass : MassValue {
            :>> magnitude = 42.0;
            :>> unit = "kg";
        }
        attribute serviceTemperature : TemperatureValue {
            :>> magnitude = 14.0;
            :>> unit = "degC";
        }
        attribute designStorageDuration : TimeValue {
            :>> magnitude = 180.0;
            :>> unit = "day";
        }
        attribute allowablePressure : PressureValue {
            :>> magnitude = 115.0;
            :>> unit = "kPa";
        }

        port fillPort : LiquidPort;
        port dispensePort : LiquidPort;
        port ventPort : GasPort;
        port cleaningPort : WaterPort;

        part staves : OakStave;
        part frontHead : BarrelHead;
        part rearHead : BarrelHead;
        part hoops : SteelHoop;
        part bung : BungStopper;
        part spigot : BrassSpigot;
        part stand : WoodenStand;
        part storageChamber : InteriorCavity;

        connection fillPath : LiquidPassage connect fillPort to storageChamber.inlet;
        connection chamberToSpigot : LiquidPassage connect storageChamber.outlet to spigot.barrelSide;
        connection spigotToServing : LiquidPassage connect spigot.servingSide to dispensePort;
        connection ventPath : GasPassage connect ventPort to bung.ventSide;
        connection bungToChamber : GasPassage connect bung.ventSide to storageChamber.vent;
        connection staveAromaPath : AromaInterface connect staves.innerOakSurface to storageChamber.oakContact;
        connection frontHeadAromaPath : AromaInterface connect frontHead.headOakSurface to storageChamber.oakContact;
        connection rearHeadAromaPath : AromaInterface connect rearHead.headOakSurface to storageChamber.oakContact;

        perform action primaryFunction : SerbianBarrelPrimaryFunction;
        perform action cleaningFunction : RinseAndPrepare;

        exhibit state operatingStates : BarrelOperatingStates;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide the high-level function of storing, oak-conditioning, protecting, and dispensing Serbian rakija from a traditional oak barrel. */
        subject barrel : SerbianBarrel;
        require constraint {
            barrel.nominalCapacity.magnitude >= 50.0 and
            barrel.nominalCapacity.magnitude <= 200.0 and
            barrel.storageChamber.usableVolume.magnitude <= barrel.nominalCapacity.magnitude and
            barrel.spigot.maximumDispenseRate.magnitude >= 1.0 and
            barrel.designStorageDuration.magnitude >= 90.0
        }
    }

    requirement def ContainmentRequirement {
        doc /* The barrel shall maintain liquid containment during sealed maturation at cellar pressure and temperature. */
        subject barrel : SerbianBarrel;
        require constraint {
            barrel.allowablePressure.magnitude >= 110.0 and
            barrel.storageChamber.internalPressure.magnitude <= barrel.allowablePressure.magnitude and
            barrel.spigot.closedLeakRate.magnitude == 0.0
        }
    }

    requirement def TraditionalMaterialRequirement {
        doc /* Beverage-contacting structural elements shall use oak to support traditional aroma extraction. */
        subject barrel : SerbianBarrel;
        require constraint {
            barrel.staves.moistureContent.magnitude >= 8.0 and
            barrel.staves.moistureContent.magnitude <= 16.0 and
            barrel.frontHead.thickness.magnitude >= 25.0 and
            barrel.rearHead.thickness.magnitude >= 25.0
        }
    }

    part def SerbianBarrelCellarSystem {
        attribute location : String = "cellar";
        attribute ambientTemperature : TemperatureValue {
            :>> magnitude = 14.0;
            :>> unit = "degC";
        }
        attribute ambientHumidity : PercentValue {
            :>> magnitude = 70.0;
            :>> unit = "%";
        }

        port productInlet : LiquidPort;
        port servingOutlet : LiquidPort;
        port ambientVent : GasPort;

        part barrel : SerbianBarrel;

        connection cellarFillConnection : LiquidPassage connect productInlet to barrel.fillPort;
        connection cellarServingConnection : LiquidPassage connect barrel.dispensePort to servingOutlet;
        connection cellarVentConnection : GasPassage connect ambientVent to barrel.ventPort;
    }

    part serbianBarrelCellar : SerbianBarrelCellarSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject barrel = serbianBarrelCellar.barrel;
    }

    requirement containment : ContainmentRequirement {
        subject barrel = serbianBarrelCellar.barrel;
    }

    requirement traditionalMaterial : TraditionalMaterialRequirement {
        subject barrel = serbianBarrelCellar.barrel;
    }
}
