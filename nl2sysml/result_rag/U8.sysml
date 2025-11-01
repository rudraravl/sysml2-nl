// Create a coffee machine system with a user interface, water heater, and milk frother.
package CoffeeMachineSystem {

	package Definitions {
		private import ScalarValues::*;
		
		// Value and Unit Definitions
		unit celsius;
		value def Temperature {
			value : Real { unit = celsius; }
		}
		
		unit milliliter;
		value def Volume {
			value : Integer { unit = milliliter; }
		}

		// Item and Enumeration Definitions
		enum def CoffeeSelection { Espresso, Latte, Cappuccino }
		enum def MachineStatus { Idle, Grinding, Heating, Frothing, Brewing, Complete, Error }

		item def Water;
		item def Milk;
		item def CoffeeBeans;
		item def GroundCoffee;
		
		item def HeatedWater {
			attribute temp : Temperature;
		}
		item def FrothedMilk;
		
		item def CoffeeDrink {
			attribute selection : CoffeeSelection;
			attribute volume : Volume;
		}

		// Control Signal Definitions
		item def StartCommand {
			attribute selection : CoffeeSelection;
		}
		item def ComponentCommand {
			attribute command : Boolean; // true = start, false = stop
		}
		item def StatusUpdate {
			attribute status : MachineStatus;
		}

		// Component Part Definitions
		part def UserInterface {
			out port commandPort : StartCommand;
			in port statusPort : StatusUpdate;
		}

		part def WaterHeater {
			in port controlPort : ComponentCommand;
			out port statusPort : StatusUpdate;
			in port waterIn : Water;
			out port waterOut : HeatedWater;
			
			action heat(in water : Water) returns (hotWater : HeatedWater) {
				// Simulates heating process
				let targetTemp = new Temperature(92.0);
				hotWater.temp = targetTemp;
			}
		}

		part def MilkFrother {
			in port controlPort : ComponentCommand;
			out port statusPort : StatusUpdate;
			in port milkIn : Milk;
			out port milkOut : FrothedMilk;
			
			action froth(in milk : Milk) returns (frothedMilk : FrothedMilk) {
				// Simulates frothing process
			}
		}
		
		part def Grinder {
			in port controlPort : ComponentCommand;
			out port statusPort : StatusUpdate;
			in port beansIn : CoffeeBeans;
			out port groundsOut : GroundCoffee;
			
			action grind(in beans : CoffeeBeans) returns (grounds : GroundCoffee) {
				// Simulates grinding process
			}
		}

		part def BrewingUnit {
			in port controlPort : ComponentCommand;
			out port statusPort : StatusUpdate;
			in port hotWaterIn : HeatedWater;
			in port groundsIn : GroundCoffee;
			in port frothedMilkIn : FrothedMilk;
			out port coffeeOut : CoffeeDrink;
			
			action brewEspresso(in water : HeatedWater, in grounds : GroundCoffee) 
			returns (drink : CoffeeDrink) {
				drink.selection = CoffeeSelection::Espresso;
				drink.volume = new Volume(30);
			}
			
			action brewLatte(in water : HeatedWater, in grounds : GroundCoffee, in milk : FrothedMilk) 
			returns (drink : CoffeeDrink) {
				drink.selection = CoffeeSelection::Latte;
				drink.volume = new Volume(250);
			}
		}
	}

	package Requirements {
		requirement WaterTempRequirement {
			doc "The water heater shall heat water to a temperature between 90 and 96 degrees Celsius for brewing.";
			attribute targetMinTemp : Real = 90.0;
			attribute targetMaxTemp : Real = 96.0;
		}

		requirement BrewTimeRequirement {
			doc "The machine shall prepare and dispense an espresso in under 60 seconds from user command.";
			attribute maxTime : Integer = 60; // seconds
		}
		
		requirement StatusFeedbackRequirement {
			doc "The user interface shall provide real-time status updates during the coffee-making process.";
		}
	}

	package Assembly {
		private import Definitions::*;
		private import Requirements::*;

		part def CoffeeMachine {
			// External Ports
			out port dispenser : CoffeeDrink;
			
			// Component Usages
			part ui : UserInterface;
			part heater : WaterHeater;
			part frother : MilkFrother;
			part grinder : Grinder;
			part brewer : BrewingUnit;
			
			// Internal Connections for Item Flows
			// Note: These connections model physical paths for ingredients.
			// The actual flow is triggered by the state machine logic.
			connect grinder.groundsOut to brewer.groundsIn;
			connect heater.waterOut to brewer.hotWaterIn;
			connect frother.milkOut to brewer.frothedMilkIn;
			connect brewer.coffeeOut to dispenser;
			
			// State Machine for Control Logic
			state machine CoffeeMakerLogic {
				attribute currentSelection : CoffeeSelection;
				
				initial state Idle;
				state Grinding;
				state Heating;
				state Frothing;
				state Brewing;
				state Complete;
				
				transition from Idle to Grinding on accept cmd : StartCommand from ui.commandPort {
					currentSelection = cmd.selection;
					send new ComponentCommand(true) to grinder.controlPort;
					send new StatusUpdate(MachineStatus::Grinding) to ui.statusPort;
				}
				
				transition from Grinding to Heating on accept status : StatusUpdate from grinder.statusPort
				where status.status == MachineStatus::Complete {
					send new ComponentCommand(true) to heater.controlPort;
					send new StatusUpdate(MachineStatus::Heating) to ui.statusPort;
				}
				
				transition from Heating to choice needsMilk on accept status : StatusUpdate from heater.statusPort
				where status.status == MachineStatus::Complete;
				
				transition from needsMilk to Frothing 
				when currentSelection == CoffeeSelection::Latte or currentSelection == CoffeeSelection::Cappuccino {
					send new ComponentCommand(true) to frother.controlPort;
					send new StatusUpdate(MachineStatus::Frothing) to ui.statusPort;
				}
				
				transition from needsMilk to Brewing
				when currentSelection == CoffeeSelection::Espresso {
					send new ComponentCommand(true) to brewer.controlPort;
					send new StatusUpdate(MachineStatus::Brewing) to ui.statusPort;
				}
				
				transition from Frothing to Brewing on accept status : StatusUpdate from frother.statusPort
				where status.status == MachineStatus::Complete {
					send new ComponentCommand(true) to brewer.controlPort;
					send new StatusUpdate(MachineStatus::Brewing) to ui.statusPort;
				}
				
				transition from Brewing to Complete on accept status : StatusUpdate from brewer.statusPort
				where status.status == MachineStatus::Complete {
					send new StatusUpdate(MachineStatus::Complete) to ui.statusPort;
				}
				
				transition from Complete to Idle after 5s;
			}
			
			// Requirements Satisfaction
			satisfy WaterTempRequirement by heater;
			satisfy BrewTimeRequirement by CoffeeMakerLogic;
			satisfy StatusFeedbackRequirement by ui, CoffeeMakerLogic;
		}
	}
}
