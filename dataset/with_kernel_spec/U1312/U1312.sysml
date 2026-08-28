package 'Rotimatic Automated Flatbread Maker' {
	private import ScalarValues::*;

	attribute def MassValue :> Real;
	attribute def VolumeValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def DurationValue :> Real;
	attribute def LengthValue :> Real;

	enum def RecipeType {
		roti;
		chapati;
		tortilla;
	}

	item def Ingredient;
	item def Flour :> Ingredient {
		attribute mass : MassValue;
	}
	item def Water :> Ingredient {
		attribute volume : VolumeValue;
	}
	item def Oil :> Ingredient {
		attribute volume : VolumeValue;
	}
	item def Dough {
		attribute mass : MassValue;
		attribute consistency : Real;
	}
	item def DoughBall {
		attribute mass : MassValue;
		attribute diameter : LengthValue;
	}
	item def RawFlatbread {
		attribute diameter : LengthValue;
		attribute thickness : LengthValue;
	}
	item def CookedFlatbread :> RawFlatbread {
		attribute cookingTemperature : TemperatureValue;
		attribute cookingDuration : DurationValue;
	}

	item def Command;
	item def UserRequest {
		attribute recipe : RecipeType;
		attribute quantity : Integer;
	}
	item def DispenseFlourCommand :> Command {
		attribute targetMass : MassValue;
	}
	item def DispenseWaterCommand :> Command {
		attribute targetVolume : VolumeValue;
	}
	item def DispenseOilCommand :> Command {
		attribute targetVolume : VolumeValue;
	}
	item def MixCommand :> Command {
		attribute duration : DurationValue;
	}
	item def KneadCommand :> Command {
		attribute duration : DurationValue;
	}
	item def DivideCommand :> Command {
		attribute targetMass : MassValue;
	}
	item def RollCommand :> Command {
		attribute targetThickness : LengthValue;
		attribute targetDiameter : LengthValue;
	}
	item def CookCommand :> Command {
		attribute targetTemperature : TemperatureValue;
		attribute duration : DurationValue;
	}
	item def EjectCommand :> Command;

	part def FlourDispenser {
		port cmdPort { in command : DispenseFlourCommand; }
		port outPort { out flour : Flour; }
	}
	part def WaterDispenser {
		port cmdPort { in command : DispenseWaterCommand; }
		port outPort { out water : Water; }
	}
	part def OilDispenser {
		port cmdPort { in command : DispenseOilCommand; }
		port outPort { out oil : Oil; }
	}
	part def MixingUnit {
		port flourInPort { in flour : Flour; }
		port waterInPort { in water : Water; }
		port oilInPort { in oil : Oil; }
		port cmdPort { in command : MixCommand; }
		port outPort { out dough : Dough; }
	}
	part def KneadingUnit {
		port inPort { in dough : Dough; }
		port cmdPort { in command : KneadCommand; }
		port outPort { out dough : Dough; }
	}
	part def Divider {
		port inPort { in dough : Dough; }
		port cmdPort { in command : DivideCommand; }
		port outPort { out doughBall : DoughBall; }
	}
	part def RollingUnit {
		port inPort { in doughBall : DoughBall; }
		port cmdPort { in command : RollCommand; }
		port outPort { out rawFlatbread : RawFlatbread; }
	}
	part def CookingPlate {
		port inPort { in rawFlatbread : RawFlatbread; }
		port cmdPort { in command : CookCommand; }
		port outPort { out cookedFlatbread : CookedFlatbread; }
		attribute currentTemperature : TemperatureValue;
		attribute remainingCookTime : DurationValue;
	}
	part def OutputTray {
		port inPort { in cookedFlatbread : CookedFlatbread; }
		port cmdPort { in command : EjectCommand; }
	}

	part def Controller {
		port requestPort { in request : UserRequest; }
		port flourCmdPort { out command : DispenseFlourCommand; }
		port waterCmdPort { out command : DispenseWaterCommand; }
		port oilCmdPort { out command : DispenseOilCommand; }
		port mixCmdPort { out command : MixCommand; }
		port kneadCmdPort { out command : KneadCommand; }
		port divideCmdPort { out command : DivideCommand; }
		port rollCmdPort { out command : RollCommand; }
		port cookCmdPort { out command : CookCommand; }
		port ejectCmdPort { out command : EjectCommand; }
		attribute remainingCount : Integer;
	}

	part def Rotimatic {
		port requestPort { in request : UserRequest; }

		perform action makeBatch[*] ordered {
			in item request : UserRequest;
			action dispenseFlour;
			action dispenseWater;
			action dispenseOil;
			then action mixDough;
			then action kneadDough;
			then action portionDough;
			then action rollDough;
			then action cookFlatbread;
			then action ejectFlatbread;
		}

		part controller : Controller;
		part flourDispenser : FlourDispenser {
			perform makeBatch.dispenseFlour;
		}
		part waterDispenser : WaterDispenser {
			perform makeBatch.dispenseWater;
		}
		part oilDispenser : OilDispenser {
			perform makeBatch.dispenseOil;
		}
		part mixingUnit : MixingUnit {
			perform makeBatch.mixDough;
		}
		part kneadingUnit : KneadingUnit {
			perform makeBatch.kneadDough;
		}
		part divider : Divider {
			perform makeBatch.portionDough;
		}
		part rollingUnit : RollingUnit {
			perform makeBatch.rollDough;
		}
		part cookingPlate : CookingPlate {
			perform makeBatch.cookFlatbread;
		}
		part outputTray : OutputTray {
			perform makeBatch.ejectFlatbread;
		}

		bind requestPort = controller.requestPort;
		bind controller.flourCmdPort = flourDispenser.cmdPort;
		bind controller.waterCmdPort = waterDispenser.cmdPort;
		bind controller.oilCmdPort = oilDispenser.cmdPort;
		bind controller.mixCmdPort = mixingUnit.cmdPort;
		bind controller.kneadCmdPort = kneadingUnit.cmdPort;
		bind controller.divideCmdPort = divider.cmdPort;
		bind controller.rollCmdPort = rollingUnit.cmdPort;
		bind controller.cookCmdPort = cookingPlate.cmdPort;
		bind controller.ejectCmdPort = outputTray.cmdPort;

		flow flourFlow of Flour
			from flourDispenser.outPort.flour to mixingUnit.flourInPort.flour;
		flow waterFlow of Water
			from waterDispenser.outPort.water to mixingUnit.waterInPort.water;
		flow oilFlow of Oil
			from oilDispenser.outPort.oil to mixingUnit.oilInPort.oil;
		flow mixedDoughFlow of Dough
			from mixingUnit.outPort.dough to kneadingUnit.inPort.dough;
		flow kneadedDoughFlow of Dough
			from kneadingUnit.outPort.dough to divider.inPort.dough;
		flow doughBallFlow of DoughBall
			from divider.outPort.doughBall to rollingUnit.inPort.doughBall;
		flow rawFlatbreadFlow of RawFlatbread
			from rollingUnit.outPort.rawFlatbread to cookingPlate.inPort.rawFlatbread;
		flow cookedFlatbreadFlow of CookedFlatbread
			from cookingPlate.outPort.cookedFlatbread to outputTray.inPort.cookedFlatbread;
	}

	requirement def AutomatedOperationRequirement {
		doc /* The Rotimatic shall automatically produce cooked flatbreads from raw ingredients without manual intervention during operation. */
	}
	requirement def CyclicProductionRequirement {
		doc /* The system shall automatically portion, roll, and cook successive flatbreads from bulk dough until the batch quantity is fulfilled. */
	}
	requirement def ConsistentQualityRequirement {
		doc /* Each flatbread shall be produced with consistent size, thickness, and cooking level as defined by the selected recipe. */
	}
	requirement def TemperatureControlRequirement {
		doc /* The cooking plate shall maintain a specific temperature for a set duration during the cooking phase. */
	}

	part rotimaticInstance : Rotimatic {
		satisfy AutomatedOperationRequirement;
		satisfy CyclicProductionRequirement;
		satisfy ConsistentQualityRequirement;
		satisfy TemperatureControlRequirement;
	}
}
