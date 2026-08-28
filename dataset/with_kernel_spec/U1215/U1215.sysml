package SmartRefrigeratorSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def TemperatureValue :> Real;
		attribute def PowerValue :> Real;

		item def TemperatureReading {
			attribute temp : TemperatureValue;
			attribute compartmentId : String;
		}
		attribute def FoodItem {
			attribute name : String;
			attribute quantity : Integer;
			attribute expirationDate : String;
			attribute compartmentId : String;
		}
		item def ShoppingListItem {
			attribute name : String;
			attribute neededQuantity : Integer;
		}
		item def ExpirationAlert {
			attribute itemName : String;
			attribute daysRemaining : Integer;
		}
		item def CoolingCommand {
			attribute powerLevel : PowerValue;
			attribute compartmentId : String;
		}
		item def StatusReport {
			attribute fridgeTemp : TemperatureValue;
			attribute freezerTemp : TemperatureValue;
			attribute powerConsumption : PowerValue;
		}
		item def UserCommand {
			attribute commandType : String;
			attribute targetTemp : TemperatureValue;
		}
		item def RemoteCommand {
			attribute commandType : String;
			attribute targetTemp : TemperatureValue;
		}

		attribute def 'Temperature High';
		attribute def 'Temperature Normal';
		attribute def 'Enter Energy Saving';
		attribute def 'Exit Energy Saving';
		attribute def 'Defrost Required';
		attribute def 'Defrost Complete';
		attribute def 'Critical Issue';
		attribute def 'Issue Resolved';
		attribute def 'Item Low';
		attribute def 'Continue';

		port def TempSensorPort {
			out tempReading : TemperatureReading;
		}
		port def ControllerTempPort {
			in tempReading : TemperatureReading;
		}
		port def CoolingCommandPort {
			in coolingCommand : CoolingCommand;
		}
		port def CoolingOutputPort {
			out coolingCommand : CoolingCommand;
		}
		port def InventoryOutputPort {
			out statusReport : StatusReport;
			out expirationAlert : ExpirationAlert;
			out shoppingListItem : ShoppingListItem;
		}
		port def UIPort {
			in statusReport : StatusReport;
			in expirationAlert : ExpirationAlert;
			in shoppingListItem : ShoppingListItem;
			out userCommand : UserCommand;
		}
		port def NetworkPort {
			in remoteCommand : RemoteCommand;
			out internalCommand : RemoteCommand;
			out remoteStatus : StatusReport;
			out remoteShoppingList : ShoppingListItem;
		}
		port def CommandInputPort {
			in userCommand : UserCommand;
			in remoteCommand : RemoteCommand;
		}

		action def 'Cool' {
			in command : CoolingCommand;
		}
		action def 'Defrost Cycle';
		action def 'Track Inventory' {
			out items : FoodItem[0..*];
		}
		action def 'Generate Shopping List' {
			out shoppingList : ShoppingListItem[0..*];
		}
		action def 'Check Expiration' {
			out alerts : ExpirationAlert[0..*];
		}
		action def 'Display Status' {
			in status : StatusReport;
		}
		action def 'Sync Remote Data';

		state def 'Refrigerator States';
		state def 'Controller States';
		state def 'Cooling States';
		state def 'Inventory States';

		part def FridgeCompartment {
			attribute setTemp : TemperatureValue;
			port tempSensorPort : TempSensorPort;
		}
		part def FreezerCompartment {
			attribute setTemp : TemperatureValue;
			port tempSensorPort : TempSensorPort;
		}
		part def TemperatureController {
			attribute fridgeSetTemp : TemperatureValue;
			attribute freezerSetTemp : TemperatureValue;
			attribute tolerance : TemperatureValue;
			port fridgeTempInputPort : ControllerTempPort;
			port freezerTempInputPort : ControllerTempPort;
			port coolingOutputPort : CoolingOutputPort;
			port commandInputPort : CommandInputPort;
			exhibit state 'controller states' : 'Controller States';
		}
		part def CoolingSystem {
			attribute currentPower : PowerValue;
			attribute defrostIntervalHours : Integer;
			port coolingInputPort : CoolingCommandPort;
			perform action 'defrost cycle' : 'Defrost Cycle';
			perform action 'cool' : 'Cool';
			exhibit state 'cooling states' : 'Cooling States';
		}
		part def InventoryManager {
			attribute foodItems : FoodItem[0..*];
			port inventoryOutputPort : InventoryOutputPort;
			perform action 'track inventory' : 'Track Inventory';
			perform action 'generate shopping list' : 'Generate Shopping List';
			perform action 'check expiration' : 'Check Expiration';
			exhibit state 'inventory states' : 'Inventory States';
		}
		part def UserInterface {
			port uiPort : UIPort;
			perform action 'display status' : 'Display Status';
		}
		part def NetworkModule {
			port networkPort : NetworkPort;
			perform action 'sync remote data' : 'Sync Remote Data';
		}
		part def SmartRefrigerator {
			attribute defrostTimerHours : Integer;
			part fridgeCompartment : FridgeCompartment;
			part freezerCompartment : FreezerCompartment;
			part tempController : TemperatureController;
			part coolingSystem : CoolingSystem;
			part inventoryManager : InventoryManager;
			part userInterface : UserInterface;
			part networkModule : NetworkModule;
			exhibit state 'refrigerator states' : 'Refrigerator States';
		}

		requirement def TemperatureControlReqDef {
			doc /* The refrigerator shall maintain compartment temperatures within a precise tolerance of the set value. */
			attribute setTemperature : TemperatureValue;
			attribute actualTemperature : TemperatureValue;
			attribute tolerance : TemperatureValue;
			require constraint { actualTemperature <= setTemperature + tolerance and actualTemperature >= setTemperature - tolerance }
		}
		requirement def FoodPreservationReqDef {
			doc /* The refrigerator shall preserve food by maintaining appropriate temperatures in fridge and freezer compartments. */
			attribute fridgeTemp : TemperatureValue;
			attribute freezerTemp : TemperatureValue;
			attribute maxFridgeTemp : TemperatureValue;
			attribute maxFreezerTemp : TemperatureValue;
			require constraint { fridgeTemp <= maxFridgeTemp and freezerTemp <= maxFreezerTemp }
		}
		requirement def EnergyOptimizationReqDef {
			doc /* The refrigerator shall optimize energy usage through energy-saving mode and efficient cooling. */
			attribute powerConsumption : PowerValue;
			attribute maxPowerConsumption : PowerValue;
			require constraint { powerConsumption <= maxPowerConsumption }
		}
		requirement def InventoryManagementReqDef {
			doc /* The refrigerator shall track all food items and automatically generate shopping lists for low or used-up items. */
			attribute trackedItems : Integer;
			attribute totalItems : Integer;
			require constraint { trackedItems == totalItems }
		}
		requirement def ExpirationTrackingReqDef {
			doc /* The refrigerator shall monitor food expiration dates and alert users before items expire. */
			attribute daysBeforeAlert : Integer;
			attribute minDaysBeforeAlert : Integer;
			require constraint { daysBeforeAlert >= minDaysBeforeAlert }
		}
		requirement def RemoteAccessReqDef {
			doc /* The refrigerator shall provide remote monitoring and control via a smartphone app through the network module. */
			attribute remoteAccessEnabled : Boolean;
			require constraint { remoteAccessEnabled == true }
		}
		requirement def DefrostReqDef {
			doc /* The cooling system shall perform automatic defrost cycles to maintain efficiency. */
			attribute defrostCycleIntervalHours : Integer;
			attribute maxDefrostCycleIntervalHours : Integer;
			require constraint { defrostCycleIntervalHours <= maxDefrostCycleIntervalHours }
		}
	}

	import Definitions::*;

	package Usages {
		private import Definitions::*;

		action 'cool' : 'Cool';
		action 'defrost cycle' : 'Defrost Cycle';
		action 'track inventory' : 'Track Inventory';
		action 'generate shopping list' : 'Generate Shopping List';
		action 'check expiration' : 'Check Expiration';
		action 'display status' : 'Display Status';
		action 'sync remote data' : 'Sync Remote Data';

		part smartFridge : SmartRefrigerator {
			attribute defrostTimerHours = 24;

			part fridgeCompartment : FridgeCompartment {
				attribute setTemp = 4.0;
				port tempSensorPort : TempSensorPort;
			}

			part freezerCompartment : FreezerCompartment {
				attribute setTemp = -18.0;
				port tempSensorPort : TempSensorPort;
			}

			part tempController : TemperatureController {
				attribute fridgeSetTemp = 4.0;
				attribute freezerSetTemp = -18.0;
				attribute tolerance = 1.0;
				port fridgeTempInputPort : ControllerTempPort;
				port freezerTempInputPort : ControllerTempPort;
				port coolingOutputPort : CoolingOutputPort;
				port commandInputPort : CommandInputPort;

				exhibit state 'controller states' : 'Controller States' parallel {
					state 'fridge control' {
						entry; then 'fridge idle';
						state 'fridge idle';
						accept when fridgeTempInputPort.tempReading.temp > fridgeSetTemp + tolerance
							then 'fridge increase cooling';
						state 'fridge increase cooling';
						accept when fridgeTempInputPort.tempReading.temp <= fridgeSetTemp
							then 'fridge idle';
					}
					state 'freezer control' {
						entry; then 'freezer idle';
						state 'freezer idle';
						accept when freezerTempInputPort.tempReading.temp > freezerSetTemp + tolerance
							then 'freezer increase cooling';
						state 'freezer increase cooling';
						accept when freezerTempInputPort.tempReading.temp <= freezerSetTemp
							then 'freezer idle';
					}
				}
			}

			part coolingSystem : CoolingSystem {
				attribute currentPower = 0.0;
				attribute defrostIntervalHours = 24;
				port coolingInputPort : CoolingCommandPort;

				exhibit state 'cooling states' : 'Cooling States' {
					entry; then idle;
					state idle;
					accept when coolingInputPort.coolingCommand.powerLevel > 0
						do 'cool'
						then 'active cooling';
					state 'active cooling' {
						do 'cool';
					}
					accept when coolingInputPort.coolingCommand.powerLevel == 0
						then idle;
					accept 'Defrost Required'
						do 'defrost cycle'
						then defrosting;
					state defrosting {
						do 'defrost cycle';
					}
					accept 'Defrost Complete'
						then idle;
				}
			}

			part inventoryManager : InventoryManager {
				attribute foodItems : FoodItem[0..*];
				port inventoryOutputPort : InventoryOutputPort;

				exhibit state 'inventory states' : 'Inventory States' {
					entry; then monitoring;
					state monitoring {
						entry 'track inventory';
						do 'check expiration';
					}
					accept 'Item Low'
						do 'generate shopping list'
						then 'list generated';
					state 'list generated';
					accept 'Continue'
						then monitoring;
				}
			}

			part userInterface : UserInterface {
				port uiPort : UIPort;
				perform action 'display status' : 'Display Status';
			}

			part networkModule : NetworkModule {
				port networkPort : NetworkPort;
				perform action 'sync remote data' : 'Sync Remote Data';
			}

			flow fridgeTempFlow of TemperatureReading
				from fridgeCompartment.tempSensorPort.tempReading to tempController.fridgeTempInputPort.tempReading;
			flow freezerTempFlow of TemperatureReading
				from freezerCompartment.tempSensorPort.tempReading to tempController.freezerTempInputPort.tempReading;
			flow coolingCommandFlow of CoolingCommand
				from tempController.coolingOutputPort.coolingCommand to coolingSystem.coolingInputPort.coolingCommand;
			flow userCommandFlow of UserCommand
				from userInterface.uiPort.userCommand to tempController.commandInputPort.userCommand;
			flow remoteCommandFlow of RemoteCommand
				from networkModule.networkPort.internalCommand to tempController.commandInputPort.remoteCommand;
			flow statusFlowUI of StatusReport
				from inventoryManager.inventoryOutputPort.statusReport to userInterface.uiPort.statusReport;
			flow expirationAlertFlowUI of ExpirationAlert
				from inventoryManager.inventoryOutputPort.expirationAlert to userInterface.uiPort.expirationAlert;
			flow shoppingListFlowUI of ShoppingListItem
				from inventoryManager.inventoryOutputPort.shoppingListItem to userInterface.uiPort.shoppingListItem;
			flow statusFlowNet of StatusReport
				from inventoryManager.inventoryOutputPort.statusReport to networkModule.networkPort.remoteStatus;
			flow shoppingListFlowNet of ShoppingListItem
				from inventoryManager.inventoryOutputPort.shoppingListItem to networkModule.networkPort.remoteShoppingList;

			exhibit state 'refrigerator states' : 'Refrigerator States' {
				entry; then idle;
				state idle;
				accept 'Temperature High'
					then 'active cooling';
				accept 'Enter Energy Saving'
					then 'energy saving';
				accept 'Defrost Required'
					then defrosting;
				accept 'Critical Issue'
					then alert;
				state 'active cooling' {
					do 'cool';
				}
				accept 'Temperature Normal'
					then idle;
				accept 'Enter Energy Saving'
					then 'energy saving';
				accept 'Critical Issue'
					then alert;
				state 'energy saving';
				accept 'Temperature High'
					then 'active cooling';
				accept 'Exit Energy Saving'
					then idle;
				accept 'Critical Issue'
					then alert;
				state defrosting {
					do 'defrost cycle';
				}
				accept 'Defrost Complete'
					then idle;
				state alert;
				accept 'Issue Resolved'
					then idle;
			}
		}

		requirement 'Temperature Control Req' : TemperatureControlReqDef {
			attribute setTemperature = 4.0;
			attribute actualTemperature = 4.0;
			attribute tolerance = 1.0;
		}
		requirement 'Food Preservation Req' : FoodPreservationReqDef {
			attribute fridgeTemp = 4.0;
			attribute freezerTemp = -18.0;
			attribute maxFridgeTemp = 5.0;
			attribute maxFreezerTemp = -17.0;
		}
		requirement 'Energy Optimization Req' : EnergyOptimizationReqDef {
			attribute powerConsumption = 150.0;
			attribute maxPowerConsumption = 200.0;
		}
		requirement 'Inventory Management Req' : InventoryManagementReqDef {
			attribute trackedItems = 50;
			attribute totalItems = 50;
		}
		requirement 'Expiration Tracking Req' : ExpirationTrackingReqDef {
			attribute daysBeforeAlert = 3;
			attribute minDaysBeforeAlert = 2;
		}
		requirement 'Remote Access Req' : RemoteAccessReqDef {
			attribute remoteAccessEnabled = true;
		}
		requirement 'Defrost Req' : DefrostReqDef {
			attribute defrostCycleIntervalHours = 24;
			attribute maxDefrostCycleIntervalHours = 48;
		}
	}
}
