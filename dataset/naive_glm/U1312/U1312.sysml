package Rotimatic {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    def Thickness :> Real { :>> unit = 'mm'; }
    def Temperature :> Real { :>> unit = 'degC'; }
    def Duration :> Real { :>> unit = 's'; }
    def Mass :> Real { :>> unit = 'g'; }
    def Volume :> Real { :>> unit = 'mL'; }
    def Diameter :> Real { :>> unit = 'mm'; }
    def Count :> Integer;

    // ---- Item Types ----
    item def Flour {
        attribute mass : Mass;
    }
    item def Water {
        attribute volume : Volume;
    }
    item def Oil {
        attribute volume : Volume;
    }
    item def Dough {
        attribute mass : Mass;
        attribute consistency : Real; // 0..1 scale
        attribute elasticity : Real;  // 0..1 scale
    }
    item def DoughBall {
        attribute mass : Mass;
        attribute targetMass : Mass;
    }
    item def Flatbread {
        attribute diameter : Diameter;
        attribute thickness : Thickness;
        attribute cooked : Boolean;
    }

    // ---- Port definitions ----
    port def FlourPort { in item : Flour; }
    port def WaterPort { in item : Water; }
    port def OilPort { in item : Oil; }
    port def DoughPort { in item : Dough; }
    port def DoughBallPort { in item : DoughBall; }
    port def FlatbreadPort { in item : Flatbread; }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ---- Components ----
    part def FlourDispenser {
        port flourOut : FlourPort;
        attribute capacity : Mass = 2000 [g];
        attribute currentLevel : Mass;
        attribute dispenseAmount : Mass;
        
        action def Dispense {
            in amount : Mass;
            out item : Flour;
        }
    }

    part def WaterDispenser {
        port waterOut : WaterPort;
        attribute capacity : Volume = 1000 [mL];
        attribute currentLevel : Volume;
        attribute dispenseAmount : Volume;
        
        action def Dispense {
            in amount : Volume;
            out item : Water;
        }
    }

    part def OilDispenser {
        port oilOut : OilPort;
        attribute capacity : Volume = 500 [mL];
        attribute currentLevel : Volume;
        attribute dispenseAmount : Volume;
        
        action def Dispense {
            in amount : Volume;
            out item : Oil;
        }
    }

    part def MixingUnit {
        port flourIn : FlourPort;
        port waterIn : WaterPort;
        port oilIn : OilPort;
        port doughOut : DoughPort;
        attribute mixDuration : Duration = 30 [s];
        
        action def Mix {
            in flour : Flour;
            in water : Water;
            in oil : Oil;
            out dough : Dough;
        }
    }

    part def KneadingUnit {
        port doughIn : DoughPort;
        port doughOut : DoughPort;
        attribute kneadDuration : Duration = 60 [s];
        attribute targetConsistency : Real = 0.85;
        attribute targetElasticity : Real = 0.80;
        
        action def Knead {
            in roughDough : Dough;
            out kneadedDough : Dough;
        }
    }

    part def Divider {
        port doughIn : DoughPort;
        port ballOut : DoughBallPort;
        attribute ballTargetMass : Mass = 40 [g];
        
        action def Divide {
            in bulkDough : Dough;
            out ball : DoughBall;
        }
    }

    part def RollingUnit {
        port ballIn : DoughBallPort;
        port flatbreadOut : FlatbreadPort;
        attribute targetDiameter : Diameter = 150 [mm];
        attribute targetThickness : Thickness = 1.5 [mm];
        attribute rollDuration : Duration = 15 [s];
        
        action def Roll {
            in ball : DoughBall;
            out flatbread : Flatbread;
        }
    }

    part def CookingPlate {
        port flatbreadIn : FlatbreadPort;
        port flatbreadOut : FlatbreadPort;
        attribute cookingTemp : Temperature = 220 [degC];
        attribute cookingDuration : Duration = 45 [s];
        attribute currentTemp : Temperature;
        
        action def Cook {
            in rawFlatbread : Flatbread;
            out cookedFlatbread : Flatbread;
        }
    }

    part def OutputTray {
        port flatbreadIn : FlatbreadPort;
        attribute capacity : Count = 10;
        attribute currentCount : Count;
    }

    part def SystemController {
        port controlFlour : ControlPort;
        port controlWater : ControlPort;
        port controlOil : ControlPort;
        port controlMix : ControlPort;
        port controlKnead : ControlPort;
        port controlDivide : ControlPort;
        port controlRoll : ControlPort;
        port controlCook : ControlPort;
        
        attribute selectedRecipe : String;
        attribute batchQuantity : Count;
        attribute completedCount : Count;
        
        state machine def ControlStateMachine {
            state Idle;
            state Dispensing;
            state Mixing;
            state Kneading;
            state Dividing;
            state Rolling;
            state Cooking;
            state Ejecting;
            state BatchComplete;
            
            transition Idle -> Dispensing when (selectedRecipe != null && batchQuantity > 0);
            transition Dispensing -> Mixing;
            transition Mixing -> Kneading;
            transition Kneading -> Dividing;
            transition Dividing -> Rolling;
            transition Rolling -> Cooking;
            transition Cooking -> Ejecting;
            transition Ejecting -> Dividing when (completedCount < batchQuantity);
            transition Ejecting -> BatchComplete when (completedCount >= batchQuantity);
            transition BatchComplete -> Idle;
        }
    }

    // ---- Recipe definition ----
    item def Recipe {
        attribute name : String;
        attribute flourAmount : Mass;
        attribute waterAmount : Volume;
        attribute oilAmount : Volume;
        attribute ballMass : Mass;
        attribute flatbreadDiameter : Diameter;
        attribute flatbreadThickness : Thickness;
        attribute cookingTemp : Temperature;
        attribute cookingDuration : Duration;
    }

    // ---- Top-level Rotimatic assembly ----
    part def Rotimatic {
        port userInterface : ControlPort;
        
        part controller : SystemController;
        part flourDispenser : FlourDispenser;
        part waterDispenser : WaterDispenser;
        part oilDispenser : OilDispenser;
        part mixingUnit : MixingUnit;
        part kneadingUnit : KneadingUnit;
        part divider : Divider;
        part rollingUnit : RollingUnit;
        part cookingPlate : CookingPlate;
        part outputTray : OutputTray;
        
        // Control connections
        connection controller.controlFlour to flourDispenser.flourOut;
        connection controller.controlWater to waterDispenser.waterOut;
        connection controller.controlOil to oilDispenser.oilOut;
        connection controller.controlMix to mixingUnit.doughOut;
        connection controller.controlKnead to kneadingUnit.doughOut;
        connection controller.controlDivide to divider.ballOut;
        connection controller.controlRoll to rollingUnit.flatbreadOut;
        connection controller.controlCook to cookingPlate.flatbreadOut;
        
        // Material flow connections
        connection flourDispenser.flourOut to mixingUnit.flourIn;
        connection waterDispenser.waterOut to mixingUnit.waterIn;
        connection oilDispenser.oilOut to mixingUnit.oilIn;
        connection mixingUnit.doughOut to kneadingUnit.doughIn;
        connection kneadingUnit.doughOut to divider.doughIn;
        connection divider.ballOut to rollingUnit.ballIn;
        connection rollingUnit.flatbreadOut to cookingPlate.flatbreadIn;
        connection cookingPlate.flatbreadOut to outputTray.flatbreadIn;
        
        // Orchestrated behavior
        action def ProduceBatch {
            in recipe : Recipe;
            in quantity : Count;
            
            perform flourDispenser.Dispense(amount = recipe.flourAmount);
            perform waterDispenser.Dispense(amount = recipe.waterAmount);
            perform oilDispenser.Dispense(amount = recipe.oilAmount);
            
            perform mixingUnit.Mix(
                flour = flourDispenser.flourOut.item,
                water = waterDispenser.waterOut.item,
                oil = oilDispenser.oilOut.item
            );
            
            perform kneadingUnit.Knead(roughDough = mixingUnit.doughOut.item);
            
            then for i in 1..quantity {
                perform divider.Divide(bulkDough = kneadingUnit.doughOut.item);
                perform rollingUnit.Roll(ball = divider.ballOut.item);
                perform cookingPlate.Cook(rawFlatbread = rollingUnit.flatbreadOut.item);
                // Eject to output tray
            }
        }
    }

    // ---- Requirements ----
    requirement def FullyAutomatedOperation {
        subject rotimatic : Rotimatic;
        requirement {
            /* The system shall produce flatbreads from raw ingredients without manual intervention during operation. */
        }
    }

    requirement def AccurateDispensing {
        subject dispenser;
        requirement {
            /* Each dispenser shall measure and release ingredients within ±2% of the specified amount. */
        }
    }

    requirement def ConsistentDoughBall {
        subject divider : Divider;
        requirement {
            /* The divider shall portion dough balls of consistent mass within ±1g of target. */
        }
    }

    requirement def UniformFlatbreadGeometry {
        subject rollingUnit : RollingUnit;
        requirement {
            /* The rolling unit shall produce flatbreads of pre-set thickness within ±0.2mm and diameter within ±3mm. */
        }
    }

    requirement def ControlledCooking {
        subject cookingPlate : CookingPlate;
        requirement {
            /* The cooking plate shall cook each flatbread at the specified temperature within ±5°C for the set duration. */
        }
    }

    requirement def CyclicBatchProduction {
        subject controller : SystemController;
        requirement {
            /* The controller shall automatically repeat dividing, rolling, and cooking until the entire batch is complete. */
        }
    }

    requirement def ConsistentQuality {
        subject rotimatic : Rotimatic;
        requirement {
            /* Each flatbread shall be produced with consistent size, thickness, and cooking level across the batch. */
        }
    }

    // ---- Default recipe ----
    item def DefaultRotiRecipe :> Recipe {
        :>> name = "Roti";
        :>> flourAmount = 40 [g];
        :>> waterAmount = 25 [mL];
        :>> oilAmount = 3 [mL];
        :>> ballMass = 40 [g];
        :>> flatbreadDiameter = 150 [mm];
        :>> flatbreadThickness = 1.5 [mm];
        :>> cookingTemp = 220 [degC];
        :>> cookingDuration = 45 [s];
    }
}
