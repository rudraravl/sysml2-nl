package DrinkingStrawSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def LengthValue :> Real { unit 'm'; }
    attribute def DiameterValue :> Real { unit 'm'; }
    attribute def PressureValue :> Real { unit 'Pa'; }
    attribute def VolumeValue :> Real { unit 'm3'; }
    attribute def DensityValue :> Real { unit 'kg/m3'; }
    attribute def ViscosityValue :> Real { unit 'Pa*s'; }
    attribute def TemperatureValue :> Real { unit 'K'; }
    attribute def FlowRateValue :> Real { unit 'm3/s'; }
    attribute def MassValue :> Real { unit 'kg'; }
    attribute def DurationValue :> Real { unit 's'; }

    // ---- Item definitions ----
    item def Beverage {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
    }

    // ---- Port definitions ----
    port def FluidPort {
        out item beverage : Beverage;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def SuctionPort {
        out attribute suctionPressure : PressureValue;
    }

    // ---- Requirements ----
    requirement def TransferLiquidReq {
        doc "The system shall transfer liquid from the container to the user's mouth through suction."
        attribute minFlowRate : FlowRateValue = 1.0e-6;
        subject system : DrinkingStrawSystem;
        require constraint { system.deliveredFlowRate >= minFlowRate }
    }

    requirement def PrimeTimeReq {
        doc "The straw shall prime within 2 seconds of suction application."
        attribute maxPrimeTime : DurationValue = 2.0;
        subject straw : DrinkingStraw;
        require constraint { straw.primeTime <= maxPrimeTime }
    }

    requirement def CollapseResistanceReq {
        doc "The straw shall withstand suction pressure without collapsing."
        attribute maxSuctionPressure : PressureValue = 50000.0;
        subject straw : DrinkingStraw;
        require constraint { straw.collapsePressure >= maxSuctionPressure }
    }

    requirement def BeverageCapacityReq {
        doc "The container shall hold a minimum volume of beverage."
        attribute minCapacity : VolumeValue = 0.250;
        subject container : BeverageContainer;
        require constraint { container.capacity >= minCapacity }
    }

    // ---- Parts ----
    part def HumanUser {
        attribute maxMouthSuction : PressureValue = 80000.0;
        attribute appliedSuction : PressureValue;
        attribute swallowRate : FlowRateValue;
        attribute isApplyingSuction : Boolean;

        port suctionOut : SuctionPort;
        port mouthIn : FluidPort;

        item consumedBeverage : Beverage;

        action def ApplySuction {
            out suction : PressureValue;
        }

        action def Swallow {
            in liquid : Beverage;
        }

        perform action applySuction : ApplySuction {
            out suction = appliedSuction;
        }
        perform action swallow : Swallow;
    }

    part def BeverageContainer {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute ambientPressure : PressureValue = 101325.0;
        attribute fillLevel : Real;

        port liquidOut : FluidPort;

        item storedBeverage : Beverage {
            attribute volume = currentVolume;
        }

        action def DispenseLiquid {
            out liquid : Beverage;
            attribute outFlowRate : FlowRateValue;
        }

        perform action dispense : DispenseLiquid;
    }

    part def DrinkingStraw {
        attribute length : LengthValue = 0.20;
        attribute innerDiameter : DiameterValue = 0.006;
        attribute outerDiameter : DiameterValue = 0.008;
        attribute material : String = "polypropylene";
        attribute flowResistance : Real;
        attribute collapsePressure : PressureValue;
        attribute primeTime : DurationValue;
        attribute currentFlowRate : FlowRateValue;
        attribute isBlocked : Boolean;

        port bottomEnd : FluidPort;
        port topEnd : FluidPort;

        action def DrawLiquid {
            in suction : PressureValue;
            in ambient : PressureValue;
            out liquid : Beverage;
            out flowRate : FlowRateValue;
        }

        perform action draw : DrawLiquid;
    }

    // ---- State machine ----
    state def DrinkingProcess {
        attribute suctionSufficient : Boolean;
        attribute obstructionDetected : Boolean;

        entry; then idle;

        state idle {
            entry { straw.currentFlowRate = 0.0; user.isApplyingSuction = false; }
        }

        state priming {
            entry { straw.primeTime = 0.0; }
            do { straw.draw(); }
        }

        state flowing {
            entry { straw.currentFlowRate > 0.0; }
            do { user.swallow(); }
        }

        state blocked {
            entry { straw.isBlocked = true; straw.currentFlowRate = 0.0; }
        }

        transition idle to priming
            when user.appliedSuction > 0.0;

        transition priming to flowing
            when suctionSufficient and straw.currentFlowRate > 0.0;

        transition priming to blocked
            when obstructionDetected;

        transition flowing to idle
            when user.appliedSuction == 0.0;

        transition flowing to blocked
            when obstructionDetected;

        transition blocked to idle
            when user.appliedSuction == 0.0 and !obstructionDetected;
    }

    // ---- System ----
    part def DrinkingStrawSystem {
        attribute deliveredFlowRate : FlowRateValue;
        attribute obstructionDetected : Boolean;
        attribute suctionSufficient : Boolean;
        attribute totalConsumedVolume : VolumeValue;

        part user : HumanUser {
            attribute appliedSuction : PressureValue;
        }
        part container : BeverageContainer {
            attribute capacity : VolumeValue = 0.330;
            attribute currentVolume : VolumeValue = 0.300;
        }
        part straw : DrinkingStraw {
            attribute flowResistance = 1.0e6;
            attribute collapsePressure : PressureValue = 60000.0;
        }

        connection userSuction connect user.suctionOut to straw.topEnd;
        connection fluidIntake connect straw.bottomEnd to container.liquidOut;
        connection mouthDelivery connect straw.topEnd to user.mouthIn;

        exhibit state drinkingProcess : DrinkingProcess;

        satisfy TransferLiquidReq by drinkingProcess;
        satisfy PrimeTimeReq by straw;
        satisfy CollapseResistanceReq by straw;
        satisfy BeverageCapacityReq by container;
    }
}
