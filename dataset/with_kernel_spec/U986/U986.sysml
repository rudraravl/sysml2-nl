package 'Automated Restaurant System' {
	doc
	/*
	 * Fully automated restaurant system managing the entire dining process
	 * from customer ordering to meal delivery without direct human intervention.
	 */
	private import ScalarValues::*;
	private import ISQ::*;
	private import Time::TimeInstantValue;
	private import Time::DurationOf;
	private import SI::min;

	// ---- Event signals ----
	attribute def OrderConfirmed;
	attribute def PrepStarted;
	attribute def MealReadyEvent;
	attribute def DeliveryCompleteEvent;
	attribute def StockLow;
	attribute def RestockCompleteEvent;

	// ---- Payload definitions ----
	attribute def MenuItem {
		attribute name : String;
		attribute quantity : Integer;
	}
	attribute def Order {
		attribute id : String;
		attribute items : MenuItem[1..*];
		attribute specialInstructions : String[0..*];
		attribute priority : Integer;
	}
	attribute def PrepRequest {
		attribute order : Order;
	}
	attribute def MealReady {
		attribute order : Order;
		attribute servingTemperature : TemperatureValue;
	}
	attribute def DeliveryRequest {
		attribute order : Order;
		attribute destinationTable : Integer;
	}
	attribute def DeliveryComplete {
		attribute order : Order;
		attribute deliveredAt : TimeInstantValue;
	}
	attribute def IngredientUsage {
		attribute ingredientId : String;
		attribute amountUsed : MassValue;
	}
	attribute def StockLevel {
		attribute ingredientId : String;
		attribute quantityOnHand : MassValue;
		attribute reorderThreshold : MassValue;
	}
	attribute def RestockOrder {
		attribute ingredientId : String;
		attribute quantity : MassValue;
		attribute supplier : String;
	}
	attribute def RestockComplete {
		attribute ingredientId : String;
		attribute quantityRestocked : MassValue;
	}

	// ---- Action definitions ----
	action def 'Process Payment' {
		in order : Order;
		out confirmation : OrderConfirmed;
	}
	action def 'Schedule Order' {
		in order : Order;
		out prepReq : PrepRequest;
	}
	action def 'Prepare Meal' {
		in prepReq : PrepRequest;
		out mealReady : MealReady;
		out usage : IngredientUsage;
		action 'retrieve ingredients';
		then action 'cook to temperature';
		then action 'assemble meal';
		then action 'quality check';
	}
	action def 'Deliver Meal' {
		in deliveryReq : DeliveryRequest;
		out deliveryComplete : DeliveryComplete;
		action 'navigate to table';
		then action 'drop off meal';
	}
	action def 'Monitor Stock' {
		in usage : IngredientUsage;
		out stock : StockLevel;
	}
	action def 'Place Restock Order' {
		in stock : StockLevel;
		out restockOrder : RestockOrder;
	}

	// ---- Part definitions ----
	part def OrderKiosk {
		port orderOut { out order : Order; }
		perform action 'process payment': 'Process Payment';
	}

	part def OrderCoordinator {
		port orderIn { in order : Order; }
		port prepOut { out prepReq : PrepRequest; }
		port mealReadyIn { in mealReady : MealReady; }
		port deliveryOut { out deliveryReq : DeliveryRequest; }
		port deliveryIn { in deliveryComplete : DeliveryComplete; }
		attribute maxConcurrentOrders : Integer = 60;
		attribute activeOrders : Order[0..*];
		perform action 'schedule order': 'Schedule Order';
	}

	part def CookingUnit {
		attribute currentTemp : TemperatureValue;
	}
	part def IngredientDispenser {
		attribute dispenserId : Integer;
	}
	part def RoboticArm {
		attribute axisCount : Integer = 6;
	}

	part def KitchenStation {
		port prepIn { in prepReq : PrepRequest; }
		port mealReadyOut { out mealReady : MealReady; }
		port usageOut { out usage : IngredientUsage; }
		part cookingUnits : CookingUnit[6];
		part dispensers : IngredientDispenser[12];
		part roboticArms : RoboticArm[3];
		perform action 'prepare meal': 'Prepare Meal';
	}

	part def NavigationSystem {
		attribute currentLocation : String;
	}
	part def RestaurantMap {
		attribute mapData : String;
	}
	part def DeliveryRobot {
		port deliveryIn { in deliveryReq : DeliveryRequest; }
		port mealIn { in mealReady : MealReady; }
		port deliveryOut { out deliveryComplete : DeliveryComplete; }
		part navigation : NavigationSystem;
		part map : RestaurantMap;
		perform action 'deliver meal': 'Deliver Meal';
	}

	part def InventoryManager {
		port usageIn { in usage : IngredientUsage; }
		port restockOut { out restockOrder : RestockOrder; }
		port restockIn { in restockComplete : RestockComplete; }
		attribute stockLevels : StockLevel[0..*];
		perform action 'monitor stock': 'Monitor Stock';
		perform action 'place restock order': 'Place Restock Order';
		state inventoryStates {
			entry; then normal;
			state normal {
				do 'monitor stock';
			}
			accept StockLow then restocking;
			state restocking {
				do 'place restock order';
			}
			accept RestockCompleteEvent then normal;
		}
	}

	part def Supplier {
		port restockIn { in restockOrder : RestockOrder; }
		port restockOut { out restockComplete : RestockComplete; }
	}

	// ---- System assembly ----
	part restaurantSystem {
		part kiosks : OrderKiosk[4];
		part coordinator : OrderCoordinator;
		part kitchen : KitchenStation;
		part deliveryRobots : DeliveryRobot[5];
		part inventoryManager : InventoryManager;
		part supplier : Supplier;

		flow orderFlow of Order
			from kiosks.orderOut.order to coordinator.orderIn.order;
		flow prepReqFlow of PrepRequest
			from coordinator.prepOut.prepReq to kitchen.prepIn.prepReq;
		flow mealReadyFlow of MealReady
			from kitchen.mealReadyOut.mealReady to coordinator.mealReadyIn.mealReady;
		flow mealToRobotFlow of MealReady
			from kitchen.mealReadyOut.mealReady to deliveryRobots.mealIn.mealReady;
		flow deliveryReqFlow of DeliveryRequest
			from coordinator.deliveryOut.deliveryReq to deliveryRobots.deliveryIn.deliveryReq;
		flow deliveryCompleteFlow of DeliveryComplete
			from deliveryRobots.deliveryOut.deliveryComplete to coordinator.deliveryIn.deliveryComplete;
		flow usageFlow of IngredientUsage
			from kitchen.usageOut.usage to inventoryManager.usageIn.usage;
		flow restockOrderFlow of RestockOrder
			from inventoryManager.restockOut.restockOrder to supplier.restockIn.restockOrder;
		flow restockCompleteFlow of RestockComplete
			from supplier.restockOut.restockComplete to inventoryManager.restockIn.restockComplete;

		state systemStates {
			entry; then idle;
			state idle;
			accept OrderConfirmed then receiving;
			state receiving;
			accept PrepStarted then preparing;
			state preparing {
				assert constraint { DurationOf(preparing) <= 12 [min] }
			}
			accept MealReadyEvent then delivering;
			state delivering {
				assert constraint { DurationOf(delivering) < 3 [min] }
			}
			accept DeliveryCompleteEvent then idle;
		}
	}

	// ---- Requirements ----
	requirement def ConcurrencyRequirement {
		doc /* The system shall handle up to 60 concurrent customer orders. */
		attribute maxConcurrentOrders : Integer;
		constraint { maxConcurrentOrders <= 60 }
	}
	requirement def PrepTimeRequirement {
		doc /* A standard meal shall be prepared within 12 minutes. */
		attribute maxPrepTime : DurationValue;
		constraint { maxPrepTime <= 12 [min] }
	}
	requirement def DeliveryTimeRequirement {
		doc /* Delivery from kitchen to table shall take less than 3 minutes. */
		attribute maxDeliveryTime : DurationValue;
		constraint { maxDeliveryTime < 3 [min] }
	}
	requirement def HardwareConfigRequirement {
		doc /* The system shall be configured with the specified automated hardware. */
		attribute kiosksCount : Integer;
		attribute cookingUnitsCount : Integer;
		attribute dispensersCount : Integer;
		attribute roboticArmsCount : Integer;
		attribute robotsCount : Integer;
		constraint { kiosksCount == 4 }
		constraint { cookingUnitsCount == 6 }
		constraint { dispensersCount == 12 }
		constraint { roboticArmsCount == 3 }
		constraint { robotsCount == 5 }
	}
	requirement restaurantRequirements {
		requirement concurrencyReq : ConcurrencyRequirement {
			attribute :>> maxConcurrentOrders = 60;
		}
		requirement prepTimeReq : PrepTimeRequirement {
			attribute :>> maxPrepTime = 12 [min];
		}
		requirement deliveryTimeReq : DeliveryTimeRequirement {
			attribute :>> maxDeliveryTime = 3 [min];
		}
		requirement hardwareReq : HardwareConfigRequirement {
			attribute :>> kiosksCount = 4;
			attribute :>> cookingUnitsCount = 6;
			attribute :>> dispensersCount = 12;
			attribute :>> roboticArmsCount = 3;
			attribute :>> robotsCount = 5;
		}
	}
}
