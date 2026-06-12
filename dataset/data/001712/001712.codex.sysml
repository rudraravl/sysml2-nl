package IkeaHomeFurnishingRetailModel {

  import ScalarValues::*;
  import SI::*;

  enum def ChannelKind {
    enum showroom;
    enum marketplace;
    enum clickAndCollect;
    enum homeDelivery;
  }

  enum def OrderStatusKind {
    enum created;
    enum reserved;
    enum paid;
    enum picked;
    enum packed;
    enum shipped;
    enum collected;
    enum delivered;
    enum returned;
    enum cancelled;
  }

  attribute def Money {
    attribute amount : Real;
    attribute currency : String = "USD";
  }

  attribute def Volume {
    attribute value : Real;
    attribute unit : String = "m^3";
  }

  attribute def Area {
    attribute value : Real;
    attribute unit : String = "m^2";
  }

  attribute def Mass {
    attribute value : Real;
    attribute unit : String = "kg";
  }

  attribute def Distance {
    attribute value : Real;
    attribute unit : String = "km";
  }

  attribute def Duration {
    attribute value : Real;
    attribute unit : String = "min";
  }

  attribute def Count {
    attribute value : Integer;
    attribute unit : String = "item";
  }

  item def CustomerProfile {
    attribute customerId : String;
    attribute householdNeed : String;
    attribute preferredChannel : ChannelKind;
    attribute deliveryRadius : Distance;
  }

  item def FurnitureProduct {
    attribute sku : String;
    attribute name : String;
    attribute roomCategory : String;
    attribute assembledMass : Mass;
    attribute packagedVolume : Volume;
    attribute sellingPrice : Money;
    attribute assemblyTime : Duration;
    attribute recyclableContentPercent : Real;
  }

  item def FlatPackPackage {
    attribute packageId : String;
    attribute sku : String;
    attribute mass : Mass;
    attribute volume : Volume;
    attribute barcode : String;
    attribute damageDetected : Boolean;
  }

  item def InventoryRecord {
    attribute sku : String;
    attribute availableQuantity : Count;
    attribute reservedQuantity : Count;
    attribute minimumDisplayQuantity : Count;
    attribute reorderPoint : Count;
  }

  item def ShoppingCart {
    attribute cartId : String;
    attribute itemCount : Count;
    attribute estimatedTotal : Money;
    attribute selectedChannel : ChannelKind;
  }

  item def CustomerOrder {
    attribute orderId : String;
    attribute status : OrderStatusKind;
    attribute totalPrice : Money;
    attribute packageCount : Count;
    attribute requestedDeliveryDistance : Distance;
  }

  item def PaymentAuthorization {
    attribute authorizationId : String;
    attribute approved : Boolean;
    attribute amount : Money;
  }

  item def PickingTask {
    attribute taskId : String;
    attribute aisle : String;
    attribute bin : String;
    attribute sku : String;
    attribute quantity : Count;
  }

  item def DeliveryManifest {
    attribute manifestId : String;
    attribute orderCount : Count;
    attribute routeDistance : Distance;
    attribute plannedDuration : Duration;
  }

  port def CustomerInteractionPort {
    in customerProfile : CustomerProfile;
    in cart : ShoppingCart;
    out productRecommendation : FurnitureProduct;
    out orderConfirmation : CustomerOrder;
  }

  port def ProductFlowPort {
    in productIn : FlatPackPackage;
    out productOut : FlatPackPackage;
  }

  port def InventoryDataPort {
    in inventoryUpdate : InventoryRecord;
    out inventoryAvailability : InventoryRecord;
  }

  port def PaymentPort {
    in paymentRequest : CustomerOrder;
    out paymentAuthorization : PaymentAuthorization;
  }

  port def FulfillmentPort {
    in orderForFulfillment : CustomerOrder;
    out fulfillmentStatus : CustomerOrder;
    out deliveryManifest : DeliveryManifest;
  }

  part def Showroom {
    attribute displayArea : Area;
    attribute roomSettingsCount : Count;
    attribute averageVisitDuration : Duration;

    port customerAccess : CustomerInteractionPort;
    port inventoryQuery : InventoryDataPort;

    action recommendHomeSolution {
      in profile : CustomerProfile;
      in availability : InventoryRecord;
      out recommendation : FurnitureProduct;

      first start;
      then classifyNeed;
      then matchRoomCategory;
      then verifyAvailability;
      then publishRecommendation;
      then done;

      action classifyNeed;
      action matchRoomCategory;
      action verifyAvailability;
      action publishRecommendation;
    }
  }

  part def MarketplaceApplication {
    attribute concurrentSessionCapacity : Count;
    attribute averageSearchLatency : Duration;

    port customerUi : CustomerInteractionPort;
    port inventoryQuery : InventoryDataPort;
    port checkout : PaymentPort;
    port fulfillmentRequest : FulfillmentPort;

    action buildDigitalCart {
      in profile : CustomerProfile;
      out cart : ShoppingCart;

      first start;
      then searchCatalog;
      then compareOptions;
      then addFlatPackItems;
      then calculateEstimate;
      then done;

      action searchCatalog;
      action compareOptions;
      action addFlatPackItems;
      action calculateEstimate;
    }
  }

  part def Warehouse {
    attribute storageVolume : Volume;
    attribute dailyPickCapacity : Count;
    attribute safetyStockTarget : Count;

    port receiving : ProductFlowPort;
    port shipping : ProductFlowPort;
    port inventoryData : InventoryDataPort;
    port fulfillment : FulfillmentPort;

    part selfServeRack {
      attribute aisleCount : Count;
      attribute binCount : Count;
      port rackFlow : ProductFlowPort;
    }

    part backroomStorage {
      attribute palletPositionCount : Count;
      port backroomFlow : ProductFlowPort;
    }

    action pickFlatPackOrder {
      in order : CustomerOrder;
      out pickedOrder : CustomerOrder;

      first start;
      then createPickingTasks;
      then retrievePackages;
      then scanBarcodes;
      then stageForCheckoutOrDispatch;
      then done;

      action createPickingTasks;
      action retrievePackages;
      action scanBarcodes;
      action stageForCheckoutOrDispatch;
    }

    state def InventoryLifecycle {
      state receiving;
      state available;
      state reserved;
      state picked;
      state shipped;
      state returned;
      state quarantine;

      entry; then receiving;

      transition receiveToAvailable
        first receiving
        accept receivedPackage
        if not productIn.damageDetected
        then available;

      transition receiveToQuarantine
        first receiving
        accept receivedPackage
        if productIn.damageDetected
        then quarantine;

      transition reserveStock
        first available
        accept orderReserved
        then reserved;

      transition pickStock
        first reserved
        accept pickingCompleted
        then picked;

      transition shipStock
        first picked
        accept dispatchCompleted
        then shipped;

      transition returnStock
        first shipped
        accept customerReturn
        then returned;

      transition inspectReturn
        first returned
        accept inspectionPassed
        then available;
    }
  }

  part def CheckoutAndPayment {
    attribute staffedLaneCount : Count;
    attribute selfCheckoutCount : Count;
    attribute averagePaymentTime : Duration;

    port customerCheckout : CustomerInteractionPort;
    port paymentGateway : PaymentPort;
    port inventoryUpdate : InventoryDataPort;

    action authorizeAndCapturePayment {
      in order : CustomerOrder;
      out authorization : PaymentAuthorization;

      first start;
      then validateOrderTotal;
      then requestAuthorization;
      then captureApprovedPayment;
      then issueReceipt;
      then done;

      action validateOrderTotal;
      action requestAuthorization;
      action captureApprovedPayment;
      action issueReceipt;
    }
  }

  part def FulfillmentCenter {
    attribute packingStationCount : Count;
    attribute dailyHomeDeliveryCapacity : Count;
    attribute clickAndCollectCapacity : Count;

    port orderInput : FulfillmentPort;
    port warehouseOutput : ProductFlowPort;
    port carrierOutput : ProductFlowPort;

    action fulfillCustomerOrder {
      in paidOrder : CustomerOrder;
      out fulfilledOrder : CustomerOrder;
      out manifest : DeliveryManifest;

      first start;
      then reserveInventory;
      then pickPackages;
      then packAndLabel;
      then chooseFulfillmentChannel;
      then releaseToCustomerOrCarrier;
      then done;

      action reserveInventory;
      action pickPackages;
      action packAndLabel;
      action chooseFulfillmentChannel;
      action releaseToCustomerOrCarrier;
    }

    state def OrderLifecycle {
      state created;
      state reserved;
      state paid;
      state picked;
      state packed;
      state shipped;
      state collected;
      state delivered;
      state returned;
      state cancelled;

      entry; then created;

      transition reserve
        first created
        accept inventoryAvailable
        then reserved;

      transition pay
        first reserved
        accept paymentApproved
        then paid;

      transition pick
        first paid
        accept pickingDone
        then picked;

      transition pack
        first picked
        accept packingDone
        then packed;

      transition dispatch
        first packed
        accept homeDeliverySelected
        then shipped;

      transition collect
        first packed
        accept clickAndCollectPickup
        then collected;

      transition deliver
        first shipped
        accept carrierProofOfDelivery
        then delivered;

      transition return
        first delivered
        accept returnRequested
        then returned;

      transition cancelBeforePayment
        first reserved
        accept customerCancellation
        then cancelled;
    }
  }

  part def DeliveryService {
    attribute vehicleCount : Count;
    attribute maxDeliveryRadius : Distance;
    attribute averageRouteDuration : Duration;

    port pickup : ProductFlowPort;
    port deliveryPlanning : FulfillmentPort;

    action deliverFlatPackOrder {
      in manifest : DeliveryManifest;
      out completedManifest : DeliveryManifest;

      first start;
      then sequenceStops;
      then loadVehicle;
      then navigateRoute;
      then handOverPackages;
      then recordProofOfDelivery;
      then done;

      action sequenceStops;
      action loadVehicle;
      action navigateRoute;
      action handOverPackages;
      action recordProofOfDelivery;
    }
  }

  part def IkeaHomeFurnishingSystem {
    attribute primaryFunction : String =
      "Provide affordable, well-designed flat-pack home furnishing solutions by helping customers discover, purchase, collect, assemble, or receive products through integrated showroom, digital commerce, inventory, payment, and fulfillment services.";

    attribute storeDisplayArea : Area = (value = 32000.0; unit = "m^2");
    attribute warehouseVolume : Volume = (value = 85000.0; unit = "m^3");
    attribute dailyOrderCapacity : Count = (value = 12000; unit = "order");
    attribute maxHomeDeliveryRadius : Distance = (value = 80.0; unit = "km");

    part showroom : Showroom {
      attribute displayArea = (value = 32000.0; unit = "m^2");
      attribute roomSettingsCount = (value = 64; unit = "room setting");
      attribute averageVisitDuration = (value = 75.0; unit = "min");
    }

    part marketplace : MarketplaceApplication {
      attribute concurrentSessionCapacity = (value = 250000; unit = "session");
      attribute averageSearchLatency = (value = 0.3; unit = "s");
    }

    part warehouse : Warehouse {
      attribute storageVolume = (value = 85000.0; unit = "m^3");
      attribute dailyPickCapacity = (value = 18000; unit = "package");
      attribute safetyStockTarget = (value = 14; unit = "day");
    }

    part checkout : CheckoutAndPayment {
      attribute staffedLaneCount = (value = 18; unit = "lane");
      attribute selfCheckoutCount = (value = 42; unit = "station");
      attribute averagePaymentTime = (value = 4.0; unit = "min");
    }

    part fulfillment : FulfillmentCenter {
      attribute packingStationCount = (value = 36; unit = "station");
      attribute dailyHomeDeliveryCapacity = (value = 3000; unit = "order");
      attribute clickAndCollectCapacity = (value = 5000; unit = "order");
    }

    part delivery : DeliveryService {
      attribute vehicleCount = (value = 55; unit = "vehicle");
      attribute maxDeliveryRadius = (value = 80.0; unit = "km");
      attribute averageRouteDuration = (value = 240.0; unit = "min");
    }

    connect showroom.inventoryQuery to warehouse.inventoryData;
    connect marketplace.inventoryQuery to warehouse.inventoryData;
    connect marketplace.checkout to checkout.paymentGateway;
    connect marketplace.fulfillmentRequest to fulfillment.orderInput;
    connect checkout.inventoryUpdate to warehouse.inventoryData;
    connect warehouse.fulfillment to fulfillment.orderInput;
    connect warehouse.shipping to fulfillment.warehouseOutput;
    connect fulfillment.carrierOutput to delivery.pickup;
    connect fulfillment.orderInput to delivery.deliveryPlanning;

    action provideHomeFurnishingSolution {
      in customer : CustomerProfile;
      out completedOrder : CustomerOrder;

      first start;
      then discoverNeed;
      then recommendProduct;
      then configureCart;
      then verifyInventory;
      then acceptPayment;
      then fulfillOrder;
      then supportAssembly;
      then done;

      action discoverNeed {
        in customer : CustomerProfile;
        out shoppingIntent : CustomerProfile;
      }

      action recommendProduct {
        in shoppingIntent : CustomerProfile;
        out selectedProduct : FurnitureProduct;
      }

      action configureCart {
        in selectedProduct : FurnitureProduct;
        out cart : ShoppingCart;
      }

      action verifyInventory {
        in cart : ShoppingCart;
        out reservedOrder : CustomerOrder;
      }

      action acceptPayment {
        in reservedOrder : CustomerOrder;
        out paidOrder : CustomerOrder;
      }

      action fulfillOrder {
        in paidOrder : CustomerOrder;
        out completedOrder : CustomerOrder;
      }

      action supportAssembly {
        in completedOrder : CustomerOrder;
        out assemblyGuidanceProvided : Boolean;
      }
    }
  }

  requirement def AffordableDesignRequirement {
    subject system : IkeaHomeFurnishingSystem;
    require constraint {
      system.primaryFunction != ""
    }
    doc
      /* The system shall provide affordable, well-designed home furnishing products through a retail experience that supports discovery, purchase, fulfillment, and assembly. */
  }

  requirement def InventoryAvailabilityRequirement {
    subject warehouse : Warehouse;
    require constraint {
      warehouse.dailyPickCapacity.value >= 12000
    }
    doc
      /* The warehouse shall support sufficient daily picking capacity for normal store and online demand. */
  }

  requirement def FlatPackFulfillmentRequirement {
    subject fulfillment : FulfillmentCenter;
    require constraint {
      fulfillment.dailyHomeDeliveryCapacity.value + fulfillment.clickAndCollectCapacity.value >= 7000
    }
    doc
      /* The fulfillment capability shall support both home delivery and click-and-collect channels for flat-pack products. */
  }

  requirement def DeliveryRadiusRequirement {
    subject delivery : DeliveryService;
    require constraint {
      delivery.maxDeliveryRadius.value >= 50.0
    }
    doc
      /* The delivery service shall support regional home delivery within a practical urban and suburban service radius. */
  }

  requirement def ShowroomExperienceRequirement {
    subject showroom : Showroom;
    require constraint {
      showroom.roomSettingsCount.value >= 40
    }
    doc
      /* The showroom shall present enough furnished room settings to help customers understand product use in realistic homes. */
  }

  satisfy AffordableDesignRequirement by IkeaHomeFurnishingSystem;
  satisfy InventoryAvailabilityRequirement by IkeaHomeFurnishingSystem::warehouse;
  satisfy FlatPackFulfillmentRequirement by IkeaHomeFurnishingSystem::fulfillment;
  satisfy DeliveryRadiusRequirement by IkeaHomeFurnishingSystem::delivery;
  satisfy ShowroomExperienceRequirement by IkeaHomeFurnishingSystem::showroom;
}