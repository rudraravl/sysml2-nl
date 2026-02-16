package 'Automated Restaurant System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OrderID;
    attribute def TableNumber;
    attribute def MenuItemName;
    attribute def PaymentMethod;
    
    item def OrderItem {
        attribute itemName : MenuItemName;
        attribute quantity : Integer;
        attribute specialInstructions : String;
    }
    
    item def CustomerOrder {
        attribute orderId : OrderID;
        attribute tableNumber : TableNumber;
        attribute items : OrderItem[1..*] ordered;
        attribute totalPrice : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def PreparedMeal {
        attribute orderId : OrderID;
        attribute items : OrderItem[*] ordered;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute readyTime : ISQ::TimeValue;
    }
    
    item def DeliveryRequest {
        attribute orderId : OrderID;
        attribute destination : TableNumber;
        attribute meal : PreparedMeal;
    }
    
    port def OrderInputPort {
        in item orderData : CustomerOrder;
    }
    
    port def OrderOutputPort {
        out item orderData : CustomerOrder;
    }
    
    port def MealInputPort {
        in item mealData : PreparedMeal;
    }
    
    port def MealOutputPort {
        out item mealData : PreparedMeal;
    }
    
    port def DeliveryPort {
        in item deliveryData : DeliveryRequest;
    }
    
    part def OrderKiosk {
        port orderOut : OrderOutputPort;
        
        attribute activeOrders : CustomerOrder[*];
        
        action def CaptureOrder {
            in tableNum : TableNumber;
            in selections : OrderItem[1..*];
            out order : CustomerOrder;
        }
        
        action def ConfirmPayment {
            in order : CustomerOrder;
            in paymentMethod : PaymentMethod;
            out confirmed : Boolean;
        }
    }
    
    part def KitchenStation {
        port orderIn : OrderInputPort;
        port mealOut : MealOutputPort;
        
        part cookingUnit[6] {
            attribute unitId : Integer;
            attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
            attribute maxCapacity : Integer;
        }
        
        part ingredientDispenser[12] {
            attribute ingredientType : String;
            attribute stockLevel : ISQ::MassValue;
            attribute dispensingRate : Real;
        }
        
        part roboticArm[3] {
            attribute armId : Integer;
            attribute reachRadius : ISQ::LengthValue;
            attribute graspForce : ISQ::ForceValue;
            attribute currentPosition : ISQ::LengthValue[3];
        }
        
        action def PrepareMeal {
            in order : CustomerOrder;
            out meal : PreparedMeal;
            
            first start;
            then action retrieveIngredients {
                in orderItems = order.items;
                out ingredients : String[*];
            }
            then action cookItems {
                in ingredients;
                in cookTemp : ISQ::ThermodynamicTemperatureValue;
                in cookTime : ISQ::TimeValue;
                out cookedItems : OrderItem[*];
            }
            then action assembleMeal {
                in cookedItems;
                out assembledMeal : PreparedMeal;
            }
            then action qualityCheck {
                in assembledMeal = assembleMeal.assembledMeal;
                out approved : Boolean;
            }
            then assign meal := assembleMeal.assembledMeal;
            then done;
        }
    }
    
    part def DeliveryRobot {
        port deliveryIn : DeliveryPort;
        
        attribute robotId : Integer;
        attribute currentLocation : ISQ::LengthValue[2];
        attribute batteryLevel : Real;
        attribute maxSpeed : ISQ::SpeedValue;
        attribute carryCapacity : ISQ::MassValue;
        attribute navigationMap : String;
        
        action def NavigateToTable {
            in targetTable : TableNumber;
            in startPosition : ISQ::LengthValue[2];
            out finalPosition : ISQ::LengthValue[2];
            out travelTime : ISQ::TimeValue;
        }
        
        action def DeliverMeal {
            in deliveryReq : DeliveryRequest;
            out deliveryComplete : Boolean;
            
            first start;
            then action loadMeal {
                in meal = deliveryReq.meal;
                out loaded : Boolean;
            }
            then action navigate : NavigateToTable {
                in targetTable = deliveryReq.destination;
                in startPosition = currentLocation;
                out finalPosition;
                out travelTime;
            }
            then action serveMeal {
                in tableNum = deliveryReq.destination;
                out served : Boolean;
            }
            then action returnToStation {
                out returned : Boolean;
            }
            then assign deliveryComplete := true;
            then done;
        }
    }
    
    part def OrderCoordinator {
        attribute pendingOrders : CustomerOrder[*];
        attribute activePreparations : CustomerOrder[*];
        attribute completedOrders : CustomerOrder[*];
        
        action def RouteOrder {
            in newOrder : CustomerOrder;
            out routedOrder : CustomerOrder;
        }
        
        action def SchedulePreparation {
            in orders : CustomerOrder[*];
            out schedule : CustomerOrder[*] ordered;
        }
        
        action def AssignDelivery {
            in meal : PreparedMeal;
            in tableNum : TableNumber;
            out deliveryReq : DeliveryRequest;
        }
    }
    
    part def InventoryManager {
        attribute stockLevels : ISQ::MassValue[*];
        attribute reorderPoints : ISQ::MassValue[*];
        attribute ingredientNames : String[*];
        
        action def MonitorStock {
            out lowStockItems : String[*];
            out criticalItems : String[*];
        }
        
        action def UpdateInventory {
            in itemUsed : String;
            in quantityUsed : ISQ::MassValue;
            out newLevel : ISQ::MassValue;
        }
        
        action def PlaceRestockOrder {
            in items : String[*];
            in quantities : ISQ::MassValue[*];
            out orderConfirmed : Boolean;
        }
    }
    
    part automatedRestaurant {
        part orderKiosks : OrderKiosk[4] {
            port orderOut;
        }
        
        part kitchenStation : KitchenStation {
            port orderIn;
            port mealOut;
        }
        
        part deliveryFleet : DeliveryRobot[5] {
            port deliveryIn;
        }
        
        part coordinator : OrderCoordinator;
        
        part inventory : InventoryManager;
        
        connection kioskToKitchen 
            connect orderKiosks.orderOut to kitchenStation.orderIn;
        
        perform action operateRestaurant {
            first start;
            then merge acceptingOrders;
            
            action receiveCustomerOrder {
                first action captureOrder : orderKiosks[1]::CaptureOrder {
                    in tableNum;
                    in selections;
                    out order;
                }
                then action confirmPayment : orderKiosks[1]::ConfirmPayment {
                    in order = captureOrder.order;
                    in paymentMethod;
                    out confirmed;
                }
                then action routeOrder : coordinator::RouteOrder {
                    in newOrder = captureOrder.order;
                    out routedOrder;
                }
            }
            
            then action scheduleWork : coordinator::SchedulePreparation {
                in orders = coordinator.pendingOrders;
                out schedule;
            }
            
            then decide;
                if scheduleWork.schedule->size() > 0 then processOrders;
                if scheduleWork.schedule->size() == 0 then acceptingOrders;
            
            action processOrders {
                for customerOrder in scheduleWork.schedule {
                    perform action prepareMeal : kitchenStation::PrepareMeal {
                        in order = customerOrder;
                        out meal;
                    }
                    then action assignDelivery : coordinator::AssignDelivery {
                        in meal = prepareMeal.meal;
                        in tableNum = customerOrder.tableNumber;
                        out deliveryReq;
                    }
                    then action deliverToTable : deliveryFleet[1]::DeliverMeal {
                        in deliveryReq = assignDelivery.deliveryReq;
                        out deliveryComplete;
                    }
                    then action updateStock : inventory::UpdateInventory {
                        in itemUsed;
                        in quantityUsed;
                        out newLevel;
                    }
                }
            }
            
            then action checkInventory : inventory::MonitorStock {
                out lowStockItems;
                out criticalItems;
            }
            
            then decide;
                if checkInventory.criticalItems->size() > 0 then restockSupplies;
                else acceptingOrders;
            
            action restockSupplies : inventory::PlaceRestockOrder {
                in items = checkInventory.criticalItems;
                in quantities;
                out orderConfirmed;
            }
            
            then acceptingOrders;
        }
    }
    
    state def RestaurantOperationalState {
        entry; then idle;
        
        state idle;
        state receivingOrders;
        state preparingMeals;
        state deliveringMeals;
        state restocking;
        
        transition idleToReceiving
            first idle
            accept at orderKiosks.orderOut
            then receivingOrders;
        
        transition receivingToPreparing
            first receivingOrders
            if coordinator.pendingOrders->size() > 0
            then preparingMeals;
        
        transition preparingToDelivering
            first preparingMeals
            accept at kitchenStation.mealOut
            then deliveringMeals;
        
        transition deliveringToIdle
            first deliveringMeals
            if deliveryFleet[1].batteryLevel > 20.0
            then idle;
        
        transition deliveringToRestocking
            first deliveringMeals
            if inventory.stockLevels->exists(level | level < 5.0 @ kg)
            then restocking;
        
        transition restockingToIdle
            first restocking
            then idle;
    }
    
    requirement def SystemRequirement;
    
    requirement def PerformanceRequirement :> SystemRequirement;
    
    requirement def CapacityRequirement :> SystemRequirement;
    
    requirement <'REQ-001'> orderThroughput : PerformanceRequirement {
        doc /* The system shall process customer orders within 45 seconds from order placement to kitchen routing. */
        
        subject automatedRestaurant.coordinator;
        
        require constraint {
            attribute maxOrderProcessingTime : ISQ::TimeValue;
            maxOrderProcessingTime <= 45.0 @ s;
        }
    }
    
    requirement <'REQ-002'> preparationTime : PerformanceRequirement {
        doc /* The kitchen station shall prepare meals within 12 minutes for standard menu items. */
        
        subject automatedRestaurant.kitchenStation;
        
        require constraint {
            attribute maxPrepTime : ISQ::TimeValue;
            maxPrepTime <= 12.0 @ min;
        }
    }
    
    requirement <'REQ-003'> deliverySpeed : PerformanceRequirement {
        doc /* Delivery robots shall deliver meals to tables within 3 minutes of meal completion. */
        
        subject automatedRestaurant.deliveryFleet;
        
        require constraint {
            attribute maxDeliveryTime : ISQ::TimeValue;
            maxDeliveryTime <= 3.0 @ min;
        }
    }
    
    requirement <'REQ-004'> concurrentCapacity : CapacityRequirement {
        doc /* The system shall handle up to 60 concurrent customer orders across all kiosks. */
        
        subject automatedRestaurant;
        
        require constraint {
            attribute maxConcurrentOrders : Integer;
            maxConcurrentOrders >= 60;
        }
    }
    
    requirement <'REQ-005'> inventoryMonitoring : SystemRequirement {
        doc /* The inventory system shall monitor stock levels continuously and alert when levels fall below reorder points. */
        
        subject automatedRestaurant.inventory;
        
        require constraint {
            attribute monitoringInterval : ISQ::TimeValue;
            monitoringInterval <= 2.0 @ min;
        }
    }
    
    requirement <'REQ-006'> deliveryAccuracy : PerformanceRequirement {
        doc /* Delivery robots shall achieve 99.8% accuracy in delivering meals to the correct table. */
        
        subject automatedRestaurant.deliveryFleet;
        
        require constraint {
            attribute accuracyRate : Real;
            accuracyRate >= 0.998;
        }
    }
    
    requirement primaryMission {
        doc /* The automated restaurant system shall provide end-to-end food service from order capture through meal preparation to table delivery without human intervention. */
        
        subject automatedRestaurant;
        
        assume constraint {
            doc /* Customers interact with order kiosks to place orders and make payments. */
        }
        
        require orderThroughput;
        require preparationTime;
        require deliverySpeed;
        require concurrentCapacity;
        require inventoryMonitoring;
        require deliveryAccuracy;
    }
}
