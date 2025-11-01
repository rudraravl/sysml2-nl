// Create a coffee machine system with a user interface, water heater, and milk frother.
package 'Coffee Machine System' {
	
	package Types {
		import ISQ::*;
		
		// Value Types for physical quantities
		value def Temperature :> TemperatureValue;
		value def Volume :> VolumeValue;
		value def Duration :> TimeValue;
		
		// Enumerations for selections and states
		enum DrinkType { espresso, cappuccino }
		enum SystemStatus { idle, heating, frothing, brewing, ready, error }
		
		// Item definitions for physical flows
		item def Water;
		item def HeatedWater :> Water;
		item def Milk;
		item def FrothedMilk :> Milk;
		item def CoffeeGrounds;
		item def CoffeeBeverage;
		
		// Attribute definitions for commands and status messages
		attribute def SelectDrink {
			attribute drink : DrinkType;
		}
		
		attribute def SetPower {
			attribute on : Boolean;
		}
		
		attribute def UpdateStatus {
			attribute status : SystemStatus;
		}
	}
	
	package Components {
		private import Types::*;
		
		part def UserInterface {
			port selectionOut;
			port statusIn;
		}
		
		part def WaterHeater {
			port waterIn;
			port heatedWaterOut;
			port controlIn;
			
			attribute targetTemperature : Temperature = 92.0[C];
		}
		
		part def MilkFrother {
			port milkIn;
			port frothedMilkOut;
			port controlIn;
		}
		
		part def BrewingUnit {
			port waterIn;
			port groundsIn; // Assumes grounds are pre-loaded
			port beverageOut;
		}
		
		part def ControlUnit {
			port uiIn;
			port statusOut;
			port heaterControlOut;
			port frotherControlOut;
		}
	}
	
	package Behaviors {
		private import Types::*;
		
		state machine def CoffeeMakerLogic {
			port selectionPort;
			port statusPort;
			port heaterPort;
			port frotherPort;
			
			attribute selectedDrink : DrinkType;
			
			initial state Idle {
				entry do send new UpdateStatus(status := SystemStatus::idle) via statusPort;
				
				transition on accept cmd : SelectDrink via selectionPort to Heating {
					doc "User selects a drink"
					then do selectedDrink = cmd.drink;
				}
			}
			
			state Heating {
				entry do {
					send new UpdateStatus(status := SystemStatus::heating) via statusPort;
					send new SetPower(on := true) via heaterPort;
				}
				
				transition to Frothing after 25[s] {
					guard selectedDrink == DrinkType::cappuccino;
					doc "If cappuccino, froth milk after heating water"
				}
				
				transition to Brewing after 25[s] {
					guard selectedDrink == DrinkType::espresso;
					doc "If espresso, go straight to brewing"
				}
				
				exit do send new SetPower(on := false) via heaterPort;
			}
			
			state Frothing {
				entry do {
					send new UpdateStatus(status := SystemStatus::frothing) via statusPort;
					send new SetPower(on := true) via frotherPort;
				}
				
				transition to Brewing after 15[s];
				
				exit do send new SetPower(on := false) via frotherPort;
			}
			
			state Brewing {
				entry do send new UpdateStatus(status := SystemStatus::brewing) via statusPort;
				
				transition to Ready after 20[s];
			}
			
			state Ready {
				entry do send new UpdateStatus(status := SystemStatus::ready) via statusPort;
				
				transition to Idle after 60[s];
			}
		}
	}
	
	package Requirements {
		import Types::Temperature;
		import Types::Duration;
		
		requirement def BrewTemperature {
			id = "R1";
			text "The water heater must heat water to a temperature between 89°C and 95°C for brewing.";
			
			require constraint { 89.0[C] <= heater.targetTemperature and heater.targetTemperature <= 95.0[C] }
		}
		
		requirement def BrewTime {
			id = "R2";
			text "The system shall prepare an espresso in under 50 seconds from selection.";
			
			require constraint { logic.Heating.to_Brewing.after <= 50[s] }
		}
		
		requirement def UserFeedback {
			id = "R3";
			text "The user interface shall display the current status of the machine.";
		}
	}
	
	package Assembly {
		private import Components::*;
		private import Behaviors::*;
		private import Requirements::*;
		
		part def CoffeeMachine {
			// Component Parts
			part ui : UserInterface;
			part heater : WaterHeater;
			part frother : MilkFrother;
			part brewer : BrewingUnit;
			
			part controller : ControlUnit {
				exhibit logic : CoffeeMakerLogic {
					// Bind state machine ports to the controller's ports
					connect selectionPort to self.uiIn;
					connect statusPort to self.statusOut;
					connect heaterPort to self.heaterControlOut;
					connect frotherPort to self.frotherControlOut;
				}
			}
			
			// External Interface Ports
			port waterSource;
			port milkSource;
			port coffeeDispenser;
			
			// Connections
			// Control flow
			connect ui.selectionOut to controller.uiIn;
			connect controller.statusOut to ui.statusIn;
			connect controller.heaterControlOut to heater.controlIn;
			connect controller.frotherControlOut to frother.controlIn;
			
			// Physical flow
			connect waterSource to heater.waterIn;
			connect milkSource to frother.milkIn;
			connect heater.heatedWaterOut to brewer.waterIn;
			// Note: Connection from frother to brewer is omitted for simplicity,
			// assuming manual combination or a separate mixing stage.
			connect brewer.beverageOut to coffeeDispenser;
			
			// Requirements Satisfaction
			satisfy brewTempReq : BrewTemperature by heater;
			satisfy brewTimeReq : BrewTime by controller.logic;
			satisfy userFeedbackReq : UserFeedback by ui, controller;
		}
		
		part myMachine : CoffeeMachine;
	}
}
