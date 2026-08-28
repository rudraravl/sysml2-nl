package AutomatedRestaurantModel {

    import ScalarValues::*;

    // ============================================================
    // Units & Value Types
    // ============================================================

    unit minute;
    unit second;
    unit celsius;
    unit gram;
    unit count;

    value type TimeValueMin :> Real {
        doc /* Elapsed time expressed in minutes */
        unit minute;
    }

    value type TimeValueSec :> Real {
        doc /* Elapsed time expressed in seconds */
        unit second;
    }

    value type TemperatureValue :> Real {
        doc /* Temperature expressed in degrees Celsius */
        unit celsius;
    }

    value type MassValue :> Real {
        doc /* Mass expressed in grams */
        unit gram;
    }

    value type CountValue :> Real {
        doc /* Discrete count of items */
        unit count;
    }

    value type PriorityValue :> Integer {
        doc /* Priority ranking where lower numbers denote higher urgency */
    }

    value type CurrencyValue :> Real {
        doc /* Monetary amount */
        attribute currency : String;
    }

    // ============================================================
    // Item Definitions
    // ============================================================

    item def SpecialInstructions {
        attribute notes : String;
        attribute allergenAlerts : String[0..*];
    }

    item def Ingredient {
        attribute id : String;
        attribute name : String;
        attribute typicalPortionSize : MassValue;
        attribute reorderThreshold : MassValue;
        attribute unitCost : CurrencyValue;
        attribute supplierId : String;
    }

    item def MenuItem {
        attribute id : String;
        attribute name : String;
        attribute price : CurrencyValue;
        attribute targetCookingTemperature : TemperatureValue;
        attribute requiredCookingTime : TimeValueMin;
        attribute baseIngredients : Ingredient[1..*];
        attribute category : String;
    }

    item def OrderLineItem {
        attribute item : MenuItem;
        attribute quantity : CountValue;
        attribute specialInstructions : SpecialInstructions[0..*];
    }

    item def Payment {
        attribute amount : CurrencyValue;
        attribute method : String;
        attribute transactionId : String;
        attribute timestamp : TimeValueSec;
        attribute approved : Boolean;
    }

    item def ConfirmedOrder {
        attribute orderId : String;
        attribute customerId : String;
        attribute tableId : String;
        attribute lineItems : OrderLineItem[1..*];
        attribute payment : Payment;
        attribute priority : PriorityValue;
        attribute submittedAt : TimeValueSec;
        attribute status : String;
    }

    item def IngredientUsage {
        attribute ingredientId : String;
        attribute amountUsed : MassValue;
        attribute usageTimestamp : TimeValueSec;
    }

    item def PreparedMeal {
        attribute mealId : String;
        attribute orderId : String;
        attribute tableId : String;
        attribute lineItems : OrderLineItem[1..*];
        attribute cookingTemperature : TemperatureValue;
        attribute qualityCheckPassed : Boolean;
        attribute finishedAt : TimeValueSec;
    }

    item def DeliveryRequest {
        attribute requestId : String;
        attribute mealId : String;
        attribute tableId : String;
        attribute priority : PriorityValue;
        attribute robotAssignment : String;
    }

    item def RestockOrder {
        attribute restockOrderId : String;
        attribute ingredientId : String;
        attribute quantity : MassValue;
        attribute supplierId : String;
        attribute priority : PriorityValue;
        attribute status : String;
        attribute placedAt : TimeValueSec;
    }

    item def DeliveryStatus {
        attribute requestId : String;
        attribute robotId : String;
        attribute status : String;
        attribute deliveredAt : TimeValueSec;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def OrderSubmissionPort {
        out item confirmedOrder : ConfirmedOrder;
        in item orderAck : String;
    }

    port def OrderReceptionPort {
        in item confirmedOrder : ConfirmedOrder;
        out item orderAck : String;
    }

    port def KitchenCommandPort {
        out item confirmedOrder : ConfirmedOrder;
        in item preparedMeal : PreparedMeal;
        in item ingredientUsage : IngredientUsage;
    }

    port def KitchenAcceptancePort {
        in item confirmedOrder : ConfirmedOrder;
        out item preparedMeal : PreparedMeal;
        out item ingredientUsage : IngredientUsage;
    }

    port def DeliveryDispatchPort {
        out item deliveryRequest : DeliveryRequest;
        out item mealForDelivery : PreparedMeal;
        in item deliveryStatus : DeliveryStatus;
    }

    port def DeliveryAcceptancePort {
        in item deliveryRequest : DeliveryRequest;
        in item mealForDelivery : PreparedMeal;
        out item deliveryStatus : DeliveryStatus;
    }

    port def InventoryMonitorPort {
        in item ingredientUsage : IngredientUsage;
        out item restockOrder : RestockOrder;
        in item restockConfirmation : String;
    }

    port def InventorySignalPort {
        out item ingredientUsage : IngredientUsage;
        in item restockOrder : RestockOrder;
        out item restockConfirmation : String;
    }

    // ============================================================
    // State Machine Definitions
    // ============================================================

    state def OrderKioskState {
        state Idle;
        state MenuBrowsing;
        state ItemSelection;
        state SpecialInstructionsEntry;
        state PaymentProcessing;
        state OrderConfirmation;
        state Fault;
        transition from Idle to MenuBrowsing when userStart;
        transition from MenuBrowsing to ItemSelection when menuItemSelected;
        transition from ItemSelection to ItemSelection when additionalItemAdded;
        transition from ItemSelection to SpecialInstructionsEntry when instructionsRequired;
        transition from SpecialInstructionsEntry to ItemSelection when instructionsRecorded;
        transition from ItemSelection to PaymentProcessing when checkoutInitiated;
        transition from PaymentProcessing to OrderConfirmation when paymentApproved;
        transition from PaymentProcessing to Fault when paymentDeclined;
        transition from OrderConfirmation to Idle when orderConfirmed;
        transition from Fault to Idle when operatorReset;
    }

    state def OrderCoordinatorState {
        state Idle;
        state ReceivingOrders;
        state Scheduling;
        state CoordinatingPreparation;
        state DispatchingDelivery;
        state MaintainingInventory;
        transition from Idle to ReceivingOrders when orderArrival;
        transition from ReceivingOrders to Scheduling when queueUpdated;
        transition from Scheduling to CoordinatingPreparation when scheduleReady;
        transition from CoordinatingPreparation to DispatchingDelivery when mealReady;
        transition from DispatchingDelivery to MaintainingInventory when mealDispatched;
        transition from MaintainingInventory to ReceivingOrders when inventoryUpdated;
        transition from ReceivingOrders to Idle when queueEmpty;
        transition from Scheduling to ReceivingOrders when newOrderReceived;
    }

    state def KitchenStationState {
        state Idle;
        state RetrievingIngredients;
        state Cooking;
        state Assembling;
        state QualityCheck;
        state Fault;
        transition from Idle to RetrievingIngredients when orderAccepted;
        transition from RetrievingIngredients to Cooking when ingredientsReady;
        transition from Cooking to Assembling when targetTemperatureReached;
        transition from Assembling to QualityCheck when assemblyDone;
        transition from QualityCheck to Idle when mealReleased;
        transition from QualityCheck to Fault when qualityCheckFailed;
        transition from Fault to Idle when resetCommand;
    }

    state def DeliveryRobotState {
        state Idle;
        state Navigating;
        state Delivering;
        state Returning;
        state Charging;
        transition from Idle to Navigating when deliveryRequest;
        transition from Navigating to Delivering when arrivalAtTable;
        transition from Delivering to Returning when mealHanded;
        transition from Returning to Idle when returnToDock;
        transition from Idle to Charging when batteryLow;
        transition from Charging to Idle when batteryFull;
    }

    state def InventoryManagerState {
        state Idle;
        state Monitoring;
        state Reordering;
        state Restocking;
        transition from Idle to Monitoring when usageEvent;
        transition from Monitoring to Idle when stockSufficient;
        transition from Monitoring to Reordering when stockBelowThreshold;
        transition from Reordering to Restocking when supplierConfirmed;
        transition from Restocking to Idle when inventoryReplenished;
    }

    // ============================================================
    // Action Definitions
    // ============================================================

    action def AssembleConfirmedOrder {
        in lineItems : OrderLineItem[1..*];
        in payment : Payment;
        in tableId : String;
        in priority : PriorityValue;
        out confirmedOrder : ConfirmedOrder;
    }

    action def ScheduleOrder {
        in order : ConfirmedOrder;
        in currentQueueSize : Integer;
        out scheduledOrder : ConfirmedOrder;
    }

    action def DispatchDelivery {
        in meal : PreparedMeal;
        out request : DeliveryRequest;
    }

    action def PrepareMeal {
        in order : ConfirmedOrder;
        out meal : PreparedMeal;
        out ingredientUsage : IngredientUsage[1..*];
    }

    action def PerformQualityCheck {
        in meal : PreparedMeal;
        out passed : Boolean;
        out validatedMeal : PreparedMeal;
    }

    action def MonitorStock {
        in usage : IngredientUsage;
        in currentLevel : MassValue;
        in threshold : MassValue;
        out reorderNeeded : Boolean;
        out restockOrder : RestockOrder;
    }

    action def PlaceRestockOrder {
        in ingredientId : String;
        in quantity : MassValue;
        in supplierId : String;
        out order : RestockOrder;
    }

    // ============================================================
    // Subordinate Component Part Definitions
    // ============================================================

    part def Display {
        attribute resolution : String;
        attribute sizeInches : Real;
        attribute touchEnabled : Boolean;
    }

    part def PaymentTerminal {
        attribute supportedMethods : String[1..*];
        attribute encryption : String;
        attribute cardReaderActive : Boolean;
    }

    part def OrderAssembler {
        attribute maxItems : CountValue;
    }

    part def OrderQueue {
        attribute capacity : Integer = 60;
        attribute currentOrders : ConfirmedOrder[0..*];
        attribute headIndex : Integer;
        attribute tailIndex : Integer;
    }

    part def Scheduler {
        attribute algorithm : String;
        attribute priorityLevels : Integer;
    }

    part def CookingUnit {
        attribute id : Integer;
        attribute maxTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute utilization : Real;
    }

    part def IngredientDispenser {
        attribute id : Integer;
        attribute dispensedIngredientId : String;
        attribute remainingStock : MassValue;
        attribute refillCapacity : MassValue;
    }

    part def MultiAxisRoboticArm {
        attribute id : Integer;
        attribute axisCount : Integer;
        attribute payloadCapacity : MassValue;
        attribute reachLength : MassValue;
    }

    part def MealAssembler {
        attribute assemblyStations : Integer;
        attribute throughput : CountValue;
    }

    part def QualityStation {
        attribute sensorSuite : String[1..*];
        attribute calibrationDate : TimeValueSec;
        attribute accuracyRating : Real;
    }

    part def NavigationSystem {
        attribute mapVersion : String;
        attribute localizationAccuracy : MassValue;
        attribute pathPlanner : String;
    }

    part def MealCompartment {
        attribute insulationRating : TemperatureValue;
        attribute capacity : CountValue;
        attribute heated : Boolean;
    }

    part def MotorAssembly {
        attribute maxSpeed : TimeValueSec;
        attribute motorCount : Integer;
    }

    part def Battery {
        attribute capacityWHr : Real;
        attribute currentLevelPct : Real;
        attribute cycleCount : CountValue;
    }

    part def StockDatabase {
        attribute entries : IngredientStockEntry[1..*];
    }

    part def IngredientStockEntry {
        attribute ingredientId : String;
        attribute name : String;
        attribute currentLevel : MassValue;
        attribute threshold : MassValue;
        attribute unitCost : CurrencyValue;
        attribute supplierId : String;
    }

    part def ReorderSystem {
        attribute preferredSuppliers : String[1..*];
        attribute leadTimeMin : TimeValueMin;
        attribute automaticRestockEnabled : Boolean;
    }

    // ============================================================
    // Major Component Part Definitions
    // ============================================================

    part def OrderKiosk {
        attribute id : String;
        attribute location : String;
        attribute status : String;
        port orderOut : OrderSubmissionPort;
        exhibit OrderKioskState;
        part display : Display;
        part paymentTerminal : PaymentTerminal;
        part orderAssembler : OrderAssembler;
        action assembleOrder : AssembleConfirmedOrder;
    }

    part def OrderCoordinator {
        attribute maxConcurrentOrders : Integer = 60;
        attribute currentQueueSize : Integer;
        attribute uptime : TimeValueSec;
        port orderIn : OrderReceptionPort;
        port kitchenOut : KitchenCommandPort;
        port deliveryOut : DeliveryDispatchPort;
        port inventoryOut : InventoryMonitorPort;
        exhibit OrderCoordinatorState;
        part orderQueue : OrderQueue;
        part scheduler : Scheduler;
        action schedule : ScheduleOrder;
        action dispatchDelivery : DispatchDelivery;
    }

    part def KitchenStation {
        attribute id : String;
        attribute mealPreparationTimeLimit : TimeValueMin = 12;
        port kitchenIn : KitchenAcceptancePort;
        port inventorySignal : InventorySignalPort;
        exhibit KitchenStationState;
        part cookingUnits : CookingUnit[6];
        part dispensers : IngredientDispenser[12];
        part roboticArms : MultiAxisRoboticArm[3];
        part mealAssembler : MealAssembler;
        part qualityStation : QualityStation;
        action prepareMeal : PrepareMeal;
        action performQualityCheck : PerformQualityCheck;
    }

    part def DeliveryRobot {
        attribute id : String;
        attribute maxDeliveryTimeMin : TimeValueMin = 3;
        attribute batteryLevel : Real;
        attribute currentLoad : PreparedMeal[0..1];
        port deliveryIn : DeliveryAcceptancePort;
        exhibit DeliveryRobotState;
        part navigationSystem : NavigationSystem;
        part mealCompartment : MealCompartment;
        part motorAssembly : MotorAssembly;
        part battery : Battery;
        action deliver : DispatchDelivery;
    }

    part def InventoryManager {
        attribute monitoredItemsCount : Integer;
        attribute reorderThresholdDefault : MassValue;
        port inventoryIn : InventoryMonitorPort;
        exhibit InventoryManagerState;
        part stockDatabase : StockDatabase;
        part reorderSystem : ReorderSystem;
        action monitorStock : MonitorStock;
        action placeRestockOrder : PlaceRestockOrder;
    }

    // ============================================================
    // Top-Level System
    // ============================================================

    part def AutomatedRestaurant {
        attribute restaurantId : String;
        attribute location : String;
        attribute operatingHours : String;
        attribute totalThroughputPerHour : CountValue;

        part kiosks : OrderKiosk[4];
        part coordinator : OrderCoordinator;
        part kitchen : KitchenStation;
        part deliveryFleet : DeliveryRobot[5];
        part inventoryManager : InventoryManager;

        connection orderFlow connect kiosks.orderOut to coordinator.orderIn;
        connection kitchenFlow connect coordinator.kitchenOut to kitchen.kitchenIn;
        connection deliveryFlow connect coordinator.deliveryOut to deliveryFleet.deliveryIn;
        connection inventoryFlow connect kitchen.inventorySignal to inventoryManager.inventoryIn;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def AutomatedOperationRequirement {
        doc /* The restaurant shall operate without direct human intervention for the entire dining process. */
        subject system : AutomatedRestaurant;
    }

    requirement def KioskCountRequirement {
        doc /* The system shall include exactly four customer-facing Order Kiosks. */
        subject kiosks : OrderKiosk[4];
        attribute requiredCount : Integer = 4;
    }

    requirement def ConcurrentOrderCapacityRequirement {
        doc /* The Order Coordinator shall support up to 60 concurrent customer orders. */
        subject coordinator : OrderCoordinator;
        attribute maxConcurrentOrders : Integer = 60;
    }

    requirement def MealPreparationTimeRequirement {
        doc /* Standard meal preparation shall complete within 12 minutes. */
        subject kitchen : KitchenStation;
        attribute maxPreparationTimeMin : TimeValueMin = 12;
    }

    requirement def DeliveryTimeRequirement {
        doc /* Delivery from kitchen to customer table shall complete within three minutes. */
        subject deliveryFleet : DeliveryRobot[5];
        attribute maxDeliveryTimeMin : TimeValueMin = 3;
    }

    requirement def DeliveryAccuracyRequirement {
        doc /* Each delivered meal shall arrive at the correct customer table. */
        subject deliveryFleet : DeliveryRobot[5];
        attribute targetAccuracyPct : Real = 99.9;
    }

    requirement def KitchenHardwareRequirement {
        doc /* The Kitchen Station shall include six cooking units, twelve automated ingredient dispensers, and three multi-axis robotic arms. */
        subject kitchen : KitchenStation;
        attribute cookingUnitsCount : Integer = 6;
        attribute dispensersCount : Integer = 12;
        attribute roboticArmsCount : Integer = 3;
    }

    requirement def DeliveryFleetSizeRequirement {
        doc /* The restaurant shall operate exactly five delivery robots. */
        subject deliveryFleet : DeliveryRobot[5];
        attribute requiredCount : Integer = 5;
    }

    requirement def InventoryRestockRequirement {
        doc /* When an ingredient stock level falls below its predetermined threshold, the system shall automatically place a restock order with the appropriate supplier to ensure the kitchen never runs out of essential ingredients. */
        subject inventoryManager : InventoryManager;
        attribute reorderThreshold : MassValue;
        attribute automaticOrder : Boolean = true;
    }

    requirement def ContinuousServiceRequirement {
        doc /* The system shall cycle through the states of idle, receiving orders, preparing meals, delivering, and restocking inventory to provide a seamless and continuous flow of service. */
        subject system : AutomatedRestaurant;
    }

    requirement def OrderRoutingRequirement {
        doc /* Each confirmed order from a kiosk shall be routed to the central Order Coordinator and from there to the Kitchen Station. */
        subject system : AutomatedRestaurant;
    }

    requirement AutomatedRestaurantSpecification {
        doc /* Top-level specification aggregating all functional requirements for the Automated Restaurant. */
        subject system : AutomatedRestaurant;

        requirement automatedOperation : AutomatedOperationRequirement;
        requirement kioskCount : KioskCountRequirement;
        requirement concurrentOrders : ConcurrentOrderCapacityRequirement;
        requirement mealPrepTime : MealPreparationTimeRequirement;
        requirement deliveryTime : DeliveryTimeRequirement;
        requirement deliveryAccuracy : DeliveryAccuracyRequirement;
        requirement kitchenHardware : KitchenHardwareRequirement;
        requirement deliveryFleetSize : DeliveryFleetSizeRequirement;
        requirement inventoryRestock : InventoryRestockRequirement;
        requirement continuousService : ContinuousServiceRequirement;
        requirement orderRouting : OrderRoutingRequirement;
    }

}
