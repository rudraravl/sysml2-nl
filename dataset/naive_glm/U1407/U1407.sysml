package EspressoMachineSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQTime::*;
    import ISQVolume::*;
    import ISQMass::*;
    import ISQThermodynamics::*;
    import ISQForce::*;

    // ---- Value Types ----
    value def BrewingTemp :> TemperatureValue { 
        attribute unit : String = "degC"; 
    }
    value def BrewingPressure :> PressureValue { 
        attribute unit : String = "bar"; 
    }
    value def ShotVolume :> VolumeValue { 
        attribute unit : String = "mL"; 
    }
    value def GrindFineness :> Real { 
        attribute unit : String = "um"; 
    }
    value def BrewTime :> TimeValue { 
        attribute unit : String = "s"; 
    }
    value def ReservoirCapacity :> VolumeValue { 
        attribute unit : String = "L"; 
    }
    value def BeanDose :> MassValue { 
        attribute unit : String = "g"; 
    }
    value def PowerState :> String;
    value def ShotSelection :> String;

    // ---- Item Types ----
    item def ColdWater {
        attribute temperature : BrewingTemp = 20 [degC];
        attribute volume : ShotVolume;
    }
    item def PressurizedWater {
        attribute pressure : BrewingPressure;
        attribute temperature : BrewingTemp;
    }
    item def HotWater {
        attribute temperature : BrewingTemp;
        attribute pressure : BrewingPressure;
    }
    item def Steam {
        attribute temperature : BrewingTemp;
        attribute pressure : BrewingPressure;
    }
    item def CoffeeBeans {
        attribute mass : BeanDose;
        attribute roastLevel : String;
    }
    item def CoffeeGrounds {
        attribute mass : BeanDose;
        attribute fineness : GrindFineness;
    }
    item def EspressoShot {
        attribute volume : ShotVolume;
        attribute temperature : BrewingTemp;
        attribute extractionTime : BrewTime;
    }
    item def Milk {
        attribute volume : ShotVolume;
        attribute temperature : BrewingTemp;
    }
    item def FrothedMilk {
        attribute volume : ShotVolume;
        attribute temperature : BrewingTemp;
    }

    // ---- Port / Interface Definitions ----
    port def WaterFlowPort {
        out item water : ColdWater;
    }
    port def PressurizedWaterPort {
        in item water : ColdWater;
        out item pressurizedWater : PressurizedWater;
    }
    port def HotWaterPort {
        in item pressurizedWater : PressurizedWater;
        out item hotWater : HotWater;
    }
    port def SteamPort {
        out item steam : Steam;
    }
    port def BeanPort {
        in item beans : CoffeeBeans;
    }
    port def GroundsPort {
        out item grounds : CoffeeGrounds;
    }
    port def GroupHeadPort {
        in item hotWater : HotWater;
        in item grounds : CoffeeGrounds;
        out item espresso : EspressoShot;
    }
    port def MilkPort {
        in item steam : Steam;
        in item milk : Milk;
        out item frothedMilk : FrothedMilk;
    }
    port def ControlSignalPort {
        out attribute powerOn : Boolean;
        out attribute targetVolume : ShotVolume;
        out attribute targetTemp : BrewingTemp;
        out attribute targetPressure : BrewingPressure;
        out attribute startBrew : Boolean;
        out attribute startSteam : Boolean;
    }
    port def SensorPort {
        in attribute currentTemp : BrewingTemp;
        in attribute currentPressure : BrewingPressure;
        in attribute waterLevel : ReservoirCapacity;
    }

    // ---- Component Parts ----
    part def WaterReservoir {
        attribute capacity : ReservoirCapacity = 2.5 [L];
        attribute currentLevel : ReservoirCapacity;
        port waterOut : WaterFlowPort;
        
        action def DispenseWater {
            in attribute amount : ShotVolume;
            out item water : ColdWater;
        }
    }

    part def Pump {
        attribute nominalPressure : BrewingPressure = 9.0 [bar];
        attribute flowRate : ShotVolume = 60.0 [mL];
        port waterIn : WaterFlowPort;
        port waterOut : PressurizedWaterPort;
        
        action def Pressurize {
            in item water : ColdWater;
            out item pressurizedWater : PressurizedWater;
        }
    }

    part def Boiler {
        attribute targetTemp : BrewingTemp = 93.0 [degC];
        attribute currentTemp : BrewingTemp;
        attribute heatingElementPower : Real = 1500;
        port waterIn : PressurizedWaterPort;
        port hotWaterOut : HotWaterPort;
        port steamOut : SteamPort;
        port sensorOut : SensorPort;
        
        action def HeatWater {
            in item pressurizedWater : PressurizedWater;
            out item hotWater : HotWater;
            out item steam : Steam;
        }
    }

    part def Grinder {
        attribute grindFineness : GrindFineness = 400.0;
        attribute dose : BeanDose = 18.0 [g];
        port beanIn : BeanPort;
        port groundsOut : GroundsPort;
        
        action def GrindBeans {
            in item beans : CoffeeBeans;
            out item grounds : CoffeeGrounds;
        }
    }

    part def Portafilter {
        attribute basketCapacity : BeanDose = 22.0 [g];
        attribute isAttached : Boolean = false;
        attribute isFilled : Boolean = false;
        port groundsIn : GroundsPort;
        port groupHeadInterface : GroupHeadPort;
        
        action def ReceiveGrounds {
            in item grounds : CoffeeGrounds;
        }
        action def AttachToGroupHead {
            out attribute attached : Boolean;
        }
    }

    part def GroupHead {
        attribute dispersionPlateDiameter : Real = 58.0;
        port hotWaterIn : HotWaterPort;
        port portafilterInterface : GroupHeadPort;
        port espressoOut : GroupHeadPort;
        
        action def BrewEspresso {
            in item hotWater : HotWater;
            in item grounds : CoffeeGrounds;
            out item espresso : EspressoShot;
        }
    }

    part def SteamWand {
        attribute valveOpen : Boolean = false;
        port steamIn : SteamPort;
        port milkOut : MilkPort;
        
        action def FrothMilk {
            in item steam : Steam;
            in item milk : Milk;
            out item frothedMilk : FrothedMilk;
        }
    }

    part def ControlPanel {
        attribute isPoweredOn : Boolean = false;
        attribute selectedVolume : ShotVolume = 30.0 [mL];
        attribute selectedTemp : BrewingTemp = 93.0 [degC];
        attribute selectedPressure : BrewingPressure = 9.0 [bar];
        port controlOut : ControlSignalPort;
        port sensorIn : SensorPort;
        
        action def PowerOn {
            out attribute powerOn : Boolean = true;
        }
        action def SelectSettings {
            in attribute volume : ShotVolume;
            in attribute temp : BrewingTemp;
            in attribute pressure : BrewingPressure;
            out attribute targetVolume : ShotVolume;
            out attribute targetTemp : BrewingTemp;
            out attribute targetPressure : BrewingPressure;
        }
        action def StartBrew {
            out attribute startBrew : Boolean = true;
        }
        action def StartSteam {
            out attribute startSteam : Boolean = true;
        }
    }

    // ---- State Machine for Espresso Machine Operation ----
    state def EspressoMachineStates {
        entry attribute poweredOn : Boolean;
        
        state warmup {
            entry attribute boilerHeating : Boolean = true;
            transition warmup_to_ready 
                first warmup 
                then ready 
                if boiler.currentTemp >= boiler.targetTemp;
        }
        state ready {
            entry attribute readyForUse : Boolean = true;
            transition ready_to_grinding 
                first ready 
                then grinding 
                if controlPanel.startBrew == true;
            transition ready_to_off 
                first ready 
                then poweredOff 
                if controlPanel.isPoweredOn == false;
        }
        state grinding {
            entry action grinder.GrindBeans;
            transition grinding_to_brewing 
                first grinding 
                then brewing 
                if portafilter.isFilled == true;
        }
        state brewing {
            entry action groupHead.BrewEspresso;
            transition brewing_to_dispensing 
                first brewing 
                then dispensing 
                if groupHead.espressoOut.espresso.volume >= controlPanel.selectedVolume;
        }
        state dispensing {
            entry action dispenseEspresso;
            transition dispensing_to_ready 
                first dispensing 
                then ready;
        }
        state poweredOff {
            entry attribute poweredOn : Boolean = false;
            transition off_to_warmup 
                first poweredOff 
                then warmup 
                if controlPanel.isPoweredOn == true;
        }
        
        action def dispenseEspresso {
            out item espresso : EspressoShot;
        }
    }

    // ---- Composite Espresso Machine ----
    part def EspressoMachine {
        attribute machineId : String;
        attribute manufacturer : String;
        attribute model : String;
        
        part reservoir : WaterReservoir {
            attribute currentLevel : ReservoirCapacity = 2.5 [L];
        }
        part pump : Pump;
        part boiler : Boiler {
            attribute currentTemp : BrewingTemp = 20.0 [degC];
        }
        part grinder : Grinder;
        part portafilter : Portafilter;
        part groupHead : GroupHead;
        part steamWand : SteamWand;
        part controlPanel : ControlPanel;
        
        // Connections
        connection reservoirToPump : WaterFlowPort 
            connect reservoir.waterOut to pump.waterIn;
        connection pumpToBoiler : PressurizedWaterPort 
            connect pump.waterOut to boiler.waterIn;
        connection boilerToGroupHead : HotWaterPort 
            connect boiler.hotWaterOut to groupHead.hotWaterIn;
        connection boilerToSteamWand : SteamPort 
            connect boiler.steamOut to steamWand.steamIn;
        connection grinderToPortafilter : GroundsPort 
            connect grinder.groundsOut to portafilter.groundsIn;
        connection portafilterToGroupHead : GroupHeadPort 
            connect portafilter.groupHeadInterface to groupHead.portafilterInterface;
        connection groupHeadOutput : GroupHeadPort 
            connect groupHead.espressoOut to portafilter.groupHeadInterface;
        connection controlToPump : ControlSignalPort 
            connect controlPanel.controlOut to pump;
        connection controlToBoiler : ControlSignalPort 
            connect controlPanel.controlOut to boiler;
        connection controlToGrinder : ControlSignalPort 
            connect controlPanel.controlOut to grinder;
        connection boilerSensorToControl : SensorPort 
            connect boiler.sensorOut to controlPanel.sensorIn;
        
        // State machine instance
        exhibit state operation : EspressoMachineStates;
        
        // Operational actions
        action def FullBrewCycle {
            in item beans : CoffeeBeans;
            in item water : ColdWater;
            out item espresso : EspressoShot;
            
            then action grindStep : grinder.GrindBeans {
                in item beans = beans;
                out item grounds;
            }
            then action fillPortafilter : portafilter.ReceiveGrounds {
                in item grounds = grindStep.grounds;
            }
            then action attachPortafilter : portafilter.AttachToGroupHead;
            then action pressurizeStep : pump.Pressurize {
                in item water = water;
                out item pressurizedWater;
            }
            then action heatStep : boiler.HeatWater {
                in item pressurizedWater = pressurizeStep.pressurizedWater;
                out item hotWater;
            }
            then action brewStep : groupHead.BrewEspresso {
                in item hotWater = heatStep.hotWater;
                in item grounds = grindStep.grounds;
                out item espresso;
            }
        }
        
        action def FrothingCycle {
            in item milk : Milk;
            out item frothedMilk : FrothedMilk;
            
            then action generateSteam : boiler.HeatWater {
                out item steam;
            }
            then action frothStep : steamWand.FrothMilk {
                in item steam = generateSteam.steam;
                in item milk = milk;
                out item frothedMilk;
            }
        }
    }

    // ---- Requirements ----
    requirement def BrewingTemperatureRequirement {
        attribute targetTemp : BrewingTemp = 93.0 [degC];
        attribute tolerance : BrewingTemp = 2.0 [degC];
        require { boiler.currentTemp >= targetTemp - tolerance and boiler.currentTemp <= targetTemp + tolerance }
    }

    requirement def BrewingPressureRequirement {
        attribute targetPressure : BrewingPressure = 9.0 [bar];
        attribute tolerance : BrewingPressure = 0.5 [bar];
        require { pump.nominalPressure >= targetPressure - tolerance and pump.nominalPressure <= targetPressure + tolerance }
    }

    requirement def ShotVolumeRequirement {
        attribute targetVolume : ShotVolume;
        attribute tolerance : ShotVolume = 2.0 [mL];
        require { groupHead.espressoOut.espresso.volume >= targetVolume - tolerance and groupHead.espressoOut.espresso.volume <= targetVolume + tolerance }
    }

    requirement def BrewTimeRequirement {
        attribute targetTime : BrewTime = 25.0 [s];
        attribute tolerance : BrewTime = 5.0 [s];
        require { espresso.extractionTime >= targetTime - tolerance and espresso.extractionTime <= targetTime + tolerance }
    }

    requirement def GrindFinenessRequirement {
        attribute targetFineness : GrindFineness = 400.0;
        attribute tolerance : GrindFineness = 50.0;
        require { grinder.grindFineness >= targetFineness - tolerance and grinder.grindFineness <= targetFineness + tolerance }
    }

    requirement def WarmupTimeRequirement {
        attribute maxWarmupTime : BrewTime = 60.0 [s];
        require { warmup.duration <= maxWarmupTime }
    }

    requirement def ReservoirCapacityRequirement {
        attribute minCapacity : ReservoirCapacity = 2.0 [L];
        require { reservoir.capacity >= minCapacity }
    }

    requirement def SteamPressureRequirement {
        attribute minSteamPressure : BrewingPressure = 1.5 [bar];
        require { boiler.steamOut.steam.pressure >= minSteamPressure }
    }

    requirement def EspressoMachineRequirements {
        requirement tempReq : BrewingTemperatureRequirement;
        requirement pressureReq : BrewingPressureRequirement;
        requirement volumeReq : ShotVolumeRequirement;
        requirement timeReq : BrewTimeRequirement;
        requirement grindReq : GrindFinenessRequirement;
        requirement warmupReq : WarmupTimeRequirement;
        requirement reservoirReq : ReservoirCapacityRequirement;
        requirement steamReq : SteamPressureRequirement;
    }

    // ---- Verification ----
    verification def VerifyBrewingTemperature {
        objective { Verify that the boiler reaches and maintains the target brewing temperature within tolerance. }
    }
    verification def VerifyBrewingPressure {
        objective { Verify that the pump delivers water at the target brewing pressure within tolerance. }
    }
    verification def VerifyShotVolume {
        objective { Verify that the dispensed espresso shot volume matches the user-selected target within tolerance. }
    }
    verification def VerifyBrewTime {
        objective { Verify that the total extraction time falls within the acceptable range for optimal espresso quality. }
    }
    verification def VerifyWarmupTime {
        objective { Verify that the machine reaches ready state from power-on within the maximum warmup time. }
    }
}
