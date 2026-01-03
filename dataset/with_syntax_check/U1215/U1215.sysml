package SmartRefrigeratorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
	attribute def HumidityLevel :> Real;
	attribute def FreshnessScore :> Real;
	
	item def FoodItem {
		attribute itemName : String;
		attribute expirationDate : String;
		attribute quantity : Real;
		attribute category : String;
		attribute mass : ISQ::MassValue;
	}
	
	item def InventoryData {
		attribute items : FoodItem[*];
		attribute totalCount : Integer;
	}
	
	item def TemperatureReading {
		attribute compartmentId : String;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute timestamp : String;
	}
	
	item def AlertMessage {
		attribute alertType : String;
		attribute messageText : String;
		attribute severity : String;
	}
	
	item def UserCommand {
		attribute commandType : String;
		attribute parameters : String[*];
	}
	
	item def ShoppingList {
		attribute recommendedItems : String[*];
		attribute lowStockItems : String[*];
	}
	
	port def TemperatureSensorPort {
		out item reading : TemperatureReading;
	}
	
	port def CoolingControlPort {
		in item powerLevel : Real;
	}
	
	port def UserInterfacePort {
		in item command : UserCommand;
		out item notification : AlertMessage;
		out item displayData : String;
	}
	
	port def NetworkPort {
		in item remoteCommand : UserCommand;
		out item statusData : String;
		out item shoppingList : ShoppingList;
	}
	
	port def InventoryPort {
		in item scannedItem : FoodItem;
		out item inventoryUpdate : InventoryData;
	}
	
	part def TemperatureSensor {
		port sensorPort : TemperatureSensorPort;
		attribute compartmentName : String;
		
		action def MeasureTemperature {
			in compartmentId : String;
			out temperature : ISQ::ThermodynamicTemperatureValue;
		}
	}
	
	part def CoolingSystem {
		port controlPort : CoolingControlPort;
		attribute currentPowerLevel : Real;
		attribute maxPowerLevel : Real;
		
		action def AdjustCooling {
			in targetPower : Real;
			out actualPower : Real;
		}
		
		action def ActivateDefrost {
			out defrostComplete : Boolean;
		}
	}
	
	part def InventoryManager {
		port inventoryPort : InventoryPort;
		attribute storedInventory : FoodItem[*];
		attribute expirationThreshold : ISQ::TimeValue;
		
		action def AddItem {
			in newItem : FoodItem;
			out success : Boolean;
		}
		
		action def RemoveItem {
			in itemName : String;
			out success : Boolean;
		}
		
		action def CheckExpiration {
			out expiredItems : FoodItem[*];
			out expiringItems : FoodItem[*];
		}
		
		action def GenerateShoppingList {
			in minimumQuantity : Real;
			out list : ShoppingList;
		}
	}
	
	part def TemperatureController {
		attribute fridgeSetpoint : TemperatureSetpoint;
		attribute freezerSetpoint : TemperatureSetpoint;
		attribute temperatureTolerance : ISQ::ThermodynamicTemperatureValue;
		
		action def RegulateTemperature {
			in currentTemp : ISQ::ThermodynamicTemperatureValue;
			in setpoint : TemperatureSetpoint;
			in tolerance : ISQ::ThermodynamicTemperatureValue;
			out coolingPower : Real;
			
			first start;
			then decide;
				if currentTemp > setpoint + tolerance then increaseCooling;
				if currentTemp < setpoint - tolerance then decreaseCooling;
				if currentTemp >= setpoint - tolerance and currentTemp <= setpoint + tolerance then maintainCooling;
			
			action increaseCooling {
				out coolingPower = 1.0;
			}
			
			action decreaseCooling {
				out coolingPower = 0.2;
			}
			
			action maintainCooling {
				out coolingPower = 0.5;
			}
			
			then done;
		}
	}
	
	part def UserInterface {
		port uiPort : UserInterfacePort;
		
		action def DisplayStatus {
			in statusInfo : String;
		}
		
		action def ProcessUserInput {
			in command : UserCommand;
			out response : String;
		}
		
		action def ShowAlert {
			in alert : AlertMessage;
		}
	}
	
	part def NetworkModule {
		port networkPort : NetworkPort;
		
		action def SendNotification {
			in notification : AlertMessage;
		}
		
		action def ReceiveRemoteCommand {
			out command : UserCommand;
		}
		
		action def TransmitShoppingList {
			in list : ShoppingList;
		}
	}
	
	part def SmartRefrigerator {
		attribute fridgeTargetTemp : TemperatureSetpoint = ISQ::ThermodynamicTemperatureValue(277.15);
		attribute freezerTargetTemp : TemperatureSetpoint = ISQ::ThermodynamicTemperatureValue(255.15);
		attribute tempTolerance : ISQ::ThermodynamicTemperatureValue = ISQ::ThermodynamicTemperatureValue(1.0);
		
		part fridgeSensor : TemperatureSensor {
			port :>> sensorPort;
			attribute :>> compartmentName = "Fridge";
		}
		
		part freezerSensor : TemperatureSensor {
			port :>> sensorPort;
			attribute :>> compartmentName = "Freezer";
		}
		
		part coolingSystem : CoolingSystem {
			port :>> controlPort;
			attribute :>> maxPowerLevel = 1.0;
		}
		
		part inventoryManager : InventoryManager {
			port :>> inventoryPort;
			attribute :>> expirationThreshold = ISQ::TimeValue(86400.0);
		}
		
		part temperatureController : TemperatureController {
			attribute :>> fridgeSetpoint = fridgeTargetTemp;
			attribute :>> freezerSetpoint = freezerTargetTemp;
			attribute :>> temperatureTolerance = tempTolerance;
		}
		
		part userInterface : UserInterface {
			port :>> uiPort;
		}
		
		part networkModule : NetworkModule {
			port :>> networkPort;
		}
		
		connection fridgeTempConnection connect fridgeSensor.sensorPort to temperatureController;
		connection freezerTempConnection connect freezerSensor.sensorPort to temperatureController;
		connection coolingConnection connect temperatureController to coolingSystem.controlPort;
		connection userConnection connect userInterface.uiPort to inventoryManager.inventoryPort;
		connection networkConnection connect networkModule.networkPort to inventoryManager.inventoryPort;
	}
	
	action def MonitorFoodFreshness {
		in inventory : FoodItem[*];
		in currentDate : String;
		out alerts : AlertMessage[*];
		out expiredCount : Integer;
	}
	
	action def OptimizeEnergyUsage {
		in currentTemperatures : TemperatureReading[*];
		in usagePattern : String;
		in timeOfDay : String;
		out powerAdjustment : Real;
	}
	
	state def RefrigeratorOperationalStates {
		attribute currentMode : String;
		
		entry; then idle;
		
		state idle {
			entry assign currentMode := "Standby";
		}
		
		state activeCooling {
			entry assign currentMode := "Cooling";
		}
		
		state defrosting {
			entry assign currentMode := "Defrost";
		}
		
		state energySaving {
			entry assign currentMode := "EcoMode";
		}
		
		state alertMode {
			entry assign currentMode := "Alert";
		}
		
		transition idle_to_cooling
			first idle
			accept temperatureRise
			then activeCooling;
		
		transition cooling_to_idle
			first activeCooling
			accept targetReached
			then idle;
		
		transition idle_to_defrost
			first idle
			accept defrostScheduled
			then defrosting;
		
		transition defrost_to_idle
			first defrosting
			accept defrostComplete
			then idle;
		
		transition to_energySaving
			first idle
			accept ecoModeEnabled
			then energySaving;
		
		transition energySaving_to_idle
			first energySaving
			accept ecoModeDisabled
			then idle;
		
		transition to_alertMode
			first idle, activeCooling, energySaving
			accept criticalAlert
			then alertMode;
		
		transition alertMode_to_idle
			first alertMode
			accept alertAcknowledged
			then idle;
	}
	
	action def ManageRefrigeratorOperation {
		first start;
		then merge continuousOperation;
		
		then action monitorTemperatures {
			out fridgeTemp : ISQ::ThermodynamicTemperatureValue;
			out freezerTemp : ISQ::ThermodynamicTemperatureValue;
		}
		
		then decide temperatureCheck;
			if monitorTemperatures.fridgeTemp > ISQ::ThermodynamicTemperatureValue(278.15) or 
			   monitorTemperatures.freezerTemp > ISQ::ThermodynamicTemperatureValue(256.15) 
			then activateCooling;
			if monitorTemperatures.fridgeTemp <= ISQ::ThermodynamicTemperatureValue(278.15) and 
			   monitorTemperatures.freezerTemp <= ISQ::ThermodynamicTemperatureValue(256.15) 
			then checkInventory;
		
		action activateCooling {
			in fridgeTemp : ISQ::ThermodynamicTemperatureValue = monitorTemperatures.fridgeTemp;
			in freezerTemp : ISQ::ThermodynamicTemperatureValue = monitorTemperatures.freezerTemp;
		}
		then checkInventory;
		
		action checkInventory : MonitorFoodFreshness {
			in currentDate : String;
			out expirationAlerts : AlertMessage[*];
			out expiredCount : Integer;
		}
		
		then decide inventoryStatus;
			if checkInventory.expiredCount > 0 then sendAlerts;
			if checkInventory.expiredCount == 0 then optimizeEnergy;
		
		action sendAlerts {
			in alerts : AlertMessage[*] = checkInventory.expirationAlerts;
		}
		then optimizeEnergy;
		
		action optimizeEnergy : OptimizeEnergyUsage {
			in timeOfDay : String;
			out energyAdjustment : Real;
		}
		
		then decide energyDecision;
			if optimizeEnergy.energyAdjustment < 0.5 then enterEcoMode;
			if optimizeEnergy.energyAdjustment >= 0.5 then continuousOperation;
		
		action enterEcoMode;
		then continuousOperation;
	}
	
	requirement def <'REQ-001'> FoodPreservationRequirement {
		doc /* The smart refrigerator shall maintain optimal temperature 
		       ranges to preserve food freshness and minimize spoilage. */
		
		subject smartFridge : SmartRefrigerator;
		
		require constraint {
			smartFridge.fridgeTargetTemp >= ISQ::ThermodynamicTemperatureValue(275.15) and
			smartFridge.fridgeTargetTemp <= ISQ::ThermodynamicTemperatureValue(278.15)
		}
		
		require constraint {
			smartFridge.freezerTargetTemp >= ISQ::ThermodynamicTemperatureValue(253.15) and
			smartFridge.freezerTargetTemp <= ISQ::ThermodynamicTemperatureValue(258.15)
		}
	}
	
	requirement def <'REQ-002'> InventoryManagementRequirement {
		doc /* The smart refrigerator shall track food inventory, monitor 
		       expiration dates, and alert users about expiring items. */
		
		subject tracker : InventoryManager;
		
		require constraint {
			tracker.storedInventory->size() >= 0
		}
		
		require constraint {
			tracker.expirationThreshold > ISQ::TimeValue(0.0)
		}
	}
	
	requirement def <'REQ-003'> EnergyEfficiencyRequirement {
		doc /* The smart refrigerator shall optimize energy consumption 
		       based on usage patterns, time of day, and contents. */
		
		subject cooling : CoolingSystem;
		
		require constraint {
			cooling.currentPowerLevel >= 0.0 and
			cooling.currentPowerLevel <= cooling.maxPowerLevel
		}
	}
	
	requirement def <'REQ-004'> UserConnectivityRequirement {
		doc /* The smart refrigerator shall provide remote monitoring, 
		       control capabilities, and shopping list generation through 
		       network connectivity. */
		
		subject network : NetworkModule;
	}
	
	requirement def <'REQ-005'> TemperatureControlRequirement {
		doc /* The smart refrigerator shall maintain temperature within 
		       specified tolerance ranges for both fridge and freezer 
		       compartments. */
		
		subject controller : TemperatureController;
		
		require constraint {
			controller.temperatureTolerance > ISQ::ThermodynamicTemperatureValue(0.0) and
			controller.temperatureTolerance <= ISQ::ThermodynamicTemperatureValue(2.0)
		}
	}
	
	requirement <'SYS-001'> smartRefrigeratorMission {
		doc /* The smart refrigerator system shall autonomously manage 
		       food preservation through precise temperature control, 
		       track inventory with expiration monitoring, optimize energy 
		       consumption, and provide user connectivity for remote 
		       monitoring and automated shopping list generation. */
		
		assume constraint validEnvironment {
			doc /* Ambient temperature is within operational range 
			       (10°C to 35°C) and power supply is stable. */
		}
		
		require <'REQ-001'> foodPreservation : FoodPreservationRequirement;
		require <'REQ-002'> inventoryManagement : InventoryManagementRequirement;
		require <'REQ-003'> energyEfficiency : EnergyEfficiencyRequirement;
		require <'REQ-004'> userConnectivity : UserConnectivityRequirement;
		require <'REQ-005'> temperatureControl : TemperatureControlRequirement;
	}
	
	part smartRefrigeratorInstance : SmartRefrigerator {
		perform action primaryOperation : ManageRefrigeratorOperation;
		exhibit state operationalBehavior : RefrigeratorOperationalStates;
		
		satisfy smartRefrigeratorMission by self;
	}
}
