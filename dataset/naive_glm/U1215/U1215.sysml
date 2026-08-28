package SmartRefrigeratorSystem {
	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	item def FoodItem {
		attribute name : String;
		attribute quantity : Real;
		attribute unit : String;
		attribute expirationDate : Date;
		attribute category : String;
	}

	item def ShoppingListEntry {
		attribute itemName : String;
		attribute neededQuantity : Real;
		attribute unit : String;
		attribute priority : Integer;
	}

	item def Notification {
		attribute message : String;
		attribute severity : Integer;
		attribute timestamp : DateTime;
	}

	value type TemperatureValue = Real { unit 'K'; }
	value type PowerLevel = Real { unit 'W'; }
	value type EnergyConsumption = Real { unit 'J'; }
	value type Tolerance = Real { unit 'K'; }

	port def TempReadingPort {
		out attribute temp : TemperatureValue;
	}

	port def ControlCmdPort {
		in attribute powerCmd : PowerLevel;
		in attribute defrostCmd : Boolean;
	}

	port def InventoryDataPort {
		out attribute items : FoodItem[*];
		out attribute shoppingList : ShoppingListEntry[*];
		out attribute expiringSoon : FoodItem[*];
	}

	port def UIPort {
		in attribute status : String;
		in attribute notifications : Notification[*];
		in attribute inventoryDisplay : FoodItem[*];
		out attribute userCommands : String[*];
	}

	port def NetworkPort {
		in attribute remoteCommands : String[*];
		out attribute remoteAlerts : Notification[*];
		out attribute remoteShoppingList : ShoppingListEntry[*];
		out attribute remoteStatus : String;
	}

	part def TemperatureSensor {
		attribute sensorId : String;
		attribute currentTemp : TemperatureValue;
		port tempOut : TempReadingPort;
		action def ReadTemperature {
			in sensor : TemperatureSensor;
			out reading : TemperatureValue;
		}
		action readTemp : ReadTemperature {
			out reading = tempOut.temp;
		}
	}

	part def TemperatureController {
		attribute fridgeSetpoint : TemperatureValue = 277.15;
		attribute freezerSetpoint : TemperatureValue = 255.37;
		attribute tolerance : Tolerance = 1.0;
		attribute fridgeActual : TemperatureValue;
		attribute freezerActual : TemperatureValue;
		port fridgeTempIn : TempReadingPort;
		port freezerTempIn : TempReadingPort;
		port coolingCmdOut : ControlCmdPort;
		action def CompareAndCommand {
			in fridgeReading : TemperatureValue;
			in freezerReading : TemperatureValue;
			out powerCmd : PowerLevel;
		}
		action regulate : CompareAndCommand {
			in fridgeReading = fridgeTempIn.temp;
			in freezerReading = freezerTempIn.temp;
			out powerCmd = coolingCmdOut.powerCmd;
		}
	}

	part def CoolingSystem {
		attribute currentPower : PowerLevel;
		attribute maxPower : PowerLevel = 200.0;
		attribute defrostActive : Boolean = false;
		port cmdIn : ControlCmdPort;
		action def ActivateCooling {
			in power : PowerLevel;
			out actualPower : PowerLevel;
		}
		action def PerformDefrost {
			out status : Boolean;
		}
		action cool : ActivateCooling {
			in power = cmdIn.powerCmd;
			out actualPower = currentPower;
		}
	}

	part def FridgeCompartment {
		attribute volume : Real { unit 'm3'; } = 0.4;
		attribute doorOpen : Boolean = false;
		part tempSensor : TemperatureSensor {
			attribute sensorId = "fridgeSensor";
		}
	}

	part def FreezerCompartment {
		attribute volume : Real { unit 'm3'; } = 0.15;
		attribute doorOpen : Boolean = false;
		part tempSensor : TemperatureSensor {
			attribute sensorId = "freezerSensor";
		}
	}

	part def InventoryManager {
		attribute inventory : FoodItem[*];
		attribute shoppingList : ShoppingListEntry[*];
		attribute expiringSoon : FoodItem[*];
		port inventoryOut : InventoryDataPort;
		action def AddItem {
			in item : FoodItem;
			out updatedInventory : FoodItem[*];
		}
		action def RemoveItem {
			in itemName : String;
			out updatedInventory : FoodItem[*];
		}
		action def CheckExpirations {
			in items : FoodItem[*];
			out expiring : FoodItem[*];
		}
		action def UpdateShoppingList {
			in items : FoodItem[*];
			out list : ShoppingListEntry[*];
		}
		action monitorExpirations : CheckExpirations {
			in items = inventory;
			out expiring = expiringSoon;
		}
		action generateShoppingList : UpdateShoppingList {
			in items = inventory;
			out list = shoppingList;
		}
	}

	part def UserInterface {
		attribute displayStatus : String;
		attribute activeNotifications : Notification[*];
		port uiPort : UIPort;
		action def DisplayStatus {
			in status : String;
		}
		action def ShowNotification {
			in notification : Notification;
		}
		action def AcceptUserCommand {
			out command : String;
		}
		action updateDisplay : DisplayStatus {
			in status = uiPort.status;
		}
	}

	part def NetworkModule {
		attribute connected : Boolean = false;
		attribute ipAddress : String;
		port netPort : NetworkPort;
		action def SendRemoteAlert {
			in alert : Notification;
		}
		action def ReceiveRemoteCommand {
			out command : String;
		}
		action syncShoppingList {
			out netPort.remoteShoppingList;
		}
	}

	part def SmartRefrigerator {
		attribute systemId : String;
		attribute energyMode : String;
		attribute totalEnergyConsumed : EnergyConsumption = 0.0;

		part fridge : FridgeCompartment;
		part freezer : FreezerCompartment;
		part controller : TemperatureController;
		part cooling : CoolingSystem;
		part inventory : InventoryManager;
		part ui : UserInterface;
		part network : NetworkModule;

		connection fridgeTempFlow connect fridge.tempSensor.tempOut to controller.fridgeTempIn;
		connection freezerTempFlow connect freezer.tempSensor.tempOut to controller.freezerTempIn;
		connection coolingCmdFlow connect controller.coolingCmdOut to cooling.cmdIn;
		connection inventoryToUI connect inventory.inventoryOut to ui.uiPort;
		connection uiToNetwork connect ui.uiPort to network.netPort;

		state def RefrigeratorStateMachine {
			state idle;
			state activeCooling;
			state energySaving;
			state defrosting;
			state alert;

			entry action initAction {
				// Initialize system
			}

			transition idle_to_active first idle if controller.fridgeActual > controller.fridgeSetpoint + controller.tolerance or controller.freezerActual > controller.freezerSetpoint + controller.tolerance then activeCooling;
			transition active_to_idle first activeCooling if controller.fridgeActual <= controller.fridgeSetpoint and controller.freezerActual <= controller.freezerSetpoint then idle;
			transition idle_to_energySaving first idle if energyMode == "eco" then energySaving;
			transition energySaving_to_idle first energySaving if energyMode == "normal" then idle;
			transition any_to_defrost first idle if cooling.defrostActive == true then defrosting;
			transition defrost_to_idle first defrosting if cooling.defrostActive == false then idle;
			transition any_to_alert first idle if inventory.expiringSoon->size() > 0 then alert;
			transition alert_to_idle first alert if inventory.expiringSoon->size() == 0 then idle;
		}

		state machine : RefrigeratorStateMachine;
	}

	requirement def FoodPreservationRequirement {
		subject refrigerator : SmartRefrigerator;
		objective {
			doc "The refrigerator shall autonomously maintain fridge and freezer temperatures within specified tolerance of setpoints."
		}
		require constraint { controller.fridgeActual >= controller.fridgeSetpoint - controller.tolerance and controller.fridgeActual <= controller.fridgeSetpoint + controller.tolerance }
		require constraint { controller.freezerActual >= controller.freezerSetpoint - controller.tolerance and controller.freezerActual <= controller.freezerSetpoint + controller.tolerance }
	}

	requirement def FoodWasteReductionRequirement {
		subject inventoryManager : InventoryManager;
		objective {
			doc "The system shall track food item expiration dates and notify users of items about to expire to reduce food waste."
		}
		require constraint { inventoryManager.expiringSoon->forAll(item | item.expirationDate <= Now + 3 days) }
	}

	requirement def EnergyOptimizationRequirement {
		subject refrigerator : SmartRefrigerator;
		objective {
			doc "The system shall provide an energy-saving mode that reduces power consumption while maintaining safe food storage temperatures."
		}
		require constraint { refrigerator.energyMode == "eco" implies refrigerator.cooling.currentPower <= refrigerator.cooling.maxPower * 0.6 }
	}

	requirement def RemoteAccessRequirement {
		subject network : NetworkModule;
		objective {
			doc "The system shall enable remote monitoring and control via a smartphone app, including alerts and shopping list access."
		}
		require constraint { network.connected == true implies network.netPort.remoteStatus != "" }
	}

	requirement def GrocerySimplificationRequirement {
		subject inventoryManager : InventoryManager;
		objective {
			doc "The system shall automatically generate a shopping list of items that are running low or used up."
		}
		require constraint { inventoryManager.shoppingList->forAll(entry | entry.neededQuantity > 0) }
	}

	requirement refrigeratorPreservationReq : FoodPreservationRequirement {
		subject refrigerator = SmartRefrigerator;
	}

	requirement refrigeratorWasteReductionReq : FoodWasteReductionRequirement {
		subject inventoryManager = SmartRefrigerator.inventory;
	}

	requirement refrigeratorEnergyReq : EnergyOptimizationRequirement {
		subject refrigerator = SmartRefrigerator;
	}

	requirement refrigeratorRemoteReq : RemoteAccessRequirement {
		subject network = SmartRefrigerator.network;
	}

	requirement refrigeratorGroceryReq : GrocerySimplificationRequirement {
		subject inventoryManager = SmartRefrigerator.inventory;
	}
}
