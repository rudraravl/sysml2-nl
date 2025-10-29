// Create a coffee machine system with a user interface, water heater, and milk frother.
package 'Coffee Machine System' {
	package Definitions {
		part def CoffeeMachine;
		part def UserInterface;
		part def WaterHeater;
		part def MilkFrother;
	}
	package Usages {
		private import Definitions::*;
		part coffeeMachineSystem : CoffeeMachine {
			part userInterface : UserInterface;
			part waterHeater : WaterHeater;
			part milkFrother : MilkFrother;
		}
	}
}
