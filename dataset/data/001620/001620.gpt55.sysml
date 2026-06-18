package VendingMachineHighLevelModel {

  enum def CurrencyUnit {
    enum USD;
  }

  enum def MassUnit {
    enum gram;
    enum kilogram;
  }

  enum def VolumeUnit {
    enum milliliter;
    enum liter;
  }

  enum def TemperatureUnit {
    enum degreeCelsius;
  }

  enum def VoltageUnit {
    enum volt;
  }

  enum def PowerUnit {
    enum watt;
  }

  enum def EnergyUnit {
    enum kilowattHour;
  }

  enum def TimeUnit {
    enum second;
    enum minute;
    enum hour;
  }

  enum def LengthUnit {
    enum millimeter;
    enum centimeter;
  }

  enum def ProductCategory {
    enum coldDrink;
    enum snack;
    enum water;
    enum juice;
    enum confectionery;
  }

  enum def PaymentMethodKind {
    enum coin;
    enum bill;
    enum contactlessCard;
    enum mobileWallet;
    enum storedValueCard;
  }

  enum def MachineMode {
    enum off;
    enum initializing;
    enum ready;
    enum selecting;
    enum acceptingPayment;
    enum authorizingPayment;
    enum dispensing;
    enum returningChange;
    enum refunding;
    enum maintenance;
    enum outOfService;
  }

  enum def FaultKind {
    enum none;
    enum productJam;
    enum paymentDeviceFailure;
    enum cardNetworkUnavailable;
    enum insufficientChange;
    enum inventoryEmpty;
    enum deliveryDoorStuck;
    enum refrigerationFault;
    enum powerFault;
    enum controllerFault;
  }

  attribute def MoneyAmount {
    attribute value : Real;
    attribute unit : CurrencyUnit = CurrencyUnit::USD;
  }

  attribute def MassQuantity {
    attribute value : Real;
    attribute unit : MassUnit;
  }

  attribute def VolumeQuantity {
    attribute value : Real;
    attribute unit : VolumeUnit;
  }

  attribute def TemperatureQuantity {
    attribute value : Real;
    attribute unit : TemperatureUnit = TemperatureUnit::degreeCelsius;
  }

  attribute def VoltageQuantity {
    attribute value : Real;
    attribute unit : VoltageUnit = VoltageUnit::volt;
  }

  attribute def PowerQuantity {
    attribute value : Real;
    attribute unit : PowerUnit = PowerUnit::watt;
  }

  attribute def EnergyQuantity {
    attribute value : Real;
    attribute unit : EnergyUnit = EnergyUnit::kilowattHour;
  }

  attribute def TimeQuantity {
    attribute value : Real;
    attribute unit : TimeUnit;
  }

  attribute def LengthQuantity {
    attribute value : Real;
    attribute unit : LengthUnit;
  }

  attribute def CountQuantity {
    attribute value : Integer;
    attribute unit : String = "count";
  }

  item def PackagedProduct {
    attribute sku : String;
    attribute displayName : String;
    attribute category : ProductCategory;
    attribute price : MoneyAmount;
    attribute packageMass : MassQuantity;
    attribute packageVolume : VolumeQuantity;
    attribute targetStorageTemperature : TemperatureQuantity;
    attribute expirationDate : String;
    attribute lotCode : String;
  }

  item def ProductSelection {
    attribute selectedSku : String;
    attribute shelfColumn : Integer;
    attribute shelfRow : Integer;
    attribute requestedQuantity : CountQuantity;
  }

  item def VendPriceQuote {
    attribute sku : String;
    attribute quotedPrice : MoneyAmount;
    attribute availableQuantity : CountQuantity;
    attribute validFor : TimeQuantity;
  }

  item def PaymentTender {
    attribute method : PaymentMethodKind;
    attribute amount : MoneyAmount;
    attribute accountToken : String;
    attribute tenderIdentifier : String;
  }

  item def PaymentAuthorization {
    attribute authorized : Boolean;
    attribute authorizedAmount : MoneyAmount;
    attribute authorizationCode : String;
    attribute reasonText : String;
  }

  item def ChangeReturn {
    attribute changeAmount : MoneyAmount;
    attribute returnedAsCoins : Boolean;
    attribute returnedAsElectronicCredit : Boolean;
  }

  item def Refund {
    attribute refundAmount : MoneyAmount;
    attribute refundReason : String;
  }

  item def Receipt {
    attribute transactionId : String;
    attribute purchasedSku : String;
    attribute paidAmount : MoneyAmount;
    attribute changeAmount : MoneyAmount;
    attribute timestamp : String;
  }

  item def ElectricalPower {
    attribute nominalVoltage : VoltageQuantity;
    attribute maximumPower : PowerQuantity;
  }

  item def UserCommand {
    attribute commandName : String;
    attribute commandValue : String;
  }

  item def DisplayMessage {
    attribute line1 : String;
    attribute line2 : String;
    attribute visibleFor : TimeQuantity;
  }

  item def InventoryReport {
    attribute sku : String;
    attribute quantityOnHand : CountQuantity;
    attribute binRow : Integer;
    attribute binColumn : Integer;
    attribute isVendable : Boolean;
  }

  item def MotorCommand {
    attribute actuatorId : String;
    attribute rotationDegrees : Real;
    attribute maximumDuration : TimeQuantity;
  }

  item def MotorStatus {
    attribute actuatorId : String;
    attribute commandedComplete : Boolean;
    attribute measuredCurrent : Real;
    attribute faultDetected : Boolean;
  }

  item def SensorSignal {
    attribute sensorId : String;
    attribute signalName : String;
    attribute booleanValue : Boolean;
    attribute numericValue : Real;
  }

  item def FaultReport {
    attribute fault : FaultKind;
    attribute severity : Integer;
    attribute description : String;
    attribute recoverable : Boolean;
  }

  item def ServiceCommand {
    attribute serviceAction : String;
    attribute credentialId : String;
  }

  item def TelemetryPacket {
    attribute machineId : String;
    attribute mode : MachineMode;
    attribute activeFault : FaultKind;
    attribute energyConsumedToday : EnergyQuantity;
    attribute cashOnHand : MoneyAmount;
  }

  port def CustomerInteractionPort {
    in item selection : ProductSelection;
    in item tender : PaymentTender;
    in item command : UserCommand;
    out item priceQuote : VendPriceQuote;
    out item display : DisplayMessage;
    out item receipt : Receipt;
    out item refund : Refund;
  }

  port def ProductDeliveryPort {
    out item deliveredProduct : PackagedProduct;
  }

  port def PaymentCollectionPort {
    in item tender : PaymentTender;
    out item authorization : PaymentAuthorization;
    out item change : ChangeReturn;
    out item refund : Refund;
  }

  port def ProductTransferPort {
    in item productIn : PackagedProduct;
    out item productOut : PackagedProduct;
  }

  port def InventoryControlPort {
    in item vendRequest : ProductSelection;
    out item inventoryStatus : InventoryReport;
    out item releasedProduct : PackagedProduct;
    out item fault : FaultReport;
  }

  port def ActuatorControlPort {
    in item command : MotorCommand;
    out item status : MotorStatus;
  }

  port def SensorPort {
    out item signal : SensorSignal;
  }

  port def ElectricalPowerPort {
    in item suppliedPower : ElectricalPower;
  }

  port def LowVoltagePowerPort {
    in item suppliedPower : ElectricalPower;
    out item distributedPower : ElectricalPower;
  }

  port def ControllerDataPort {
    in item incomingStatus : SensorSignal;
    in item inventory : InventoryReport;
    in item paymentAuthorization : PaymentAuthorization;
    in item motorStatus : MotorStatus;
    in item serviceCommand : ServiceCommand;
    out item outgoingCommand : UserCommand;
    out item display : DisplayMessage;
    out item motorCommand : MotorCommand;
    out item vendRequest : ProductSelection;
    out item telemetry : TelemetryPacket;
    out item fault : FaultReport;
  }

  port def MaintenancePort {
    in item command : ServiceCommand;
    out item report : TelemetryPacket;
    out item fault : FaultReport;
  }

  port def NetworkPort {
    in item serviceCommand : ServiceCommand;
    out item telemetry : TelemetryPacket;
    out item authorizationRequest : PaymentTender;
    in item authorizationResponse : PaymentAuthorization;
  }

  port def ThermalControlPort {
    in item targetTemperature : TemperatureQuantity;
    out item measuredTemperature : TemperatureQuantity;
    out item fault : FaultReport;
  }

  constraint def PaymentCoversPrice {
    in paid : MoneyAmount;
    in price : MoneyAmount;
    constraint paymentIsSufficient { paid.value >= price.value }
  }

  constraint def StorageTemperatureWithinLimit {
    in measured : TemperatureQuantity;
    in target : TemperatureQuantity;
    constraint withinColdProductLimit { measured.value <= target.value + 3.0 }
  }

  constraint def VendTimeWithinLimit {
    in elapsed : TimeQuantity;
    constraint vendCompletesPromptly { elapsed.value <= 45.0 }
  }

  action def AcceptProductSelection {
    in item customerSelection : ProductSelection;
    out item acceptedSelection : ProductSelection;
    out item message : DisplayMessage;
  }

  action def QuoteSelectedProductPrice {
    in item selection : ProductSelection;
    in item inventory : InventoryReport;
    out item quote : VendPriceQuote;
    out item message : DisplayMessage;
  }

  action def CollectAndAuthorizePayment {
    in item quote : VendPriceQuote;
    in item tender : PaymentTender;
    out item authorization : PaymentAuthorization;
    out item paidAmount : MoneyAmount;
  }

  action def ReleaseProductFromInventory {
    in item selection : ProductSelection;
    in item authorization : PaymentAuthorization;
    out item releasedProduct : PackagedProduct;
    out item motorCommand : MotorCommand;
    out item inventoryReport : InventoryReport;
  }

  action def DeliverProductToCustomer {
    in item releasedProduct : PackagedProduct;
    out item deliveredProduct : PackagedProduct;
    out item deliveryDetected : SensorSignal;
  }

  action def ReturnChangeOrRefund {
    in item price : MoneyAmount;
    in item paidAmount : MoneyAmount;
    in item authorization : PaymentAuthorization;
    out item change : ChangeReturn;
    out item refund : Refund;
  }

  action def RecordTransaction {
    in item selection : ProductSelection;
    in item authorization : PaymentAuthorization;
    in item deliveredProduct : PackagedProduct;
    in item change : ChangeReturn;
    out item receipt : Receipt;
    out item telemetry : TelemetryPacket;
  }

  action def ProvideSelfServiceRetailVend {
    in item customerSelection : ProductSelection;
    in item customerTender : PaymentTender;
    out item dispensedProduct : PackagedProduct;
    out item customerReceipt : Receipt;
    out item returnedChange : ChangeReturn;
    out item refundIssued : Refund;

    action acceptSelection : AcceptProductSelection;
    action quotePrice : QuoteSelectedProductPrice;
    action authorizePayment : CollectAndAuthorizePayment;
    action releaseProduct : ReleaseProductFromInventory;
    action deliverProduct : DeliverProductToCustomer;
    action settlePayment : ReturnChangeOrRefund;
    action recordVend : RecordTransaction;

    succession first acceptSelection then quotePrice;
    succession quotePrice then authorizePayment;
    succession authorizePayment then releaseProduct;
    succession releaseProduct then deliverProduct;
    succession deliverProduct then settlePayment;
    succession settlePayment then recordVend;
  }

  action def DetectAndReportFault {
    in item sensor : SensorSignal;
    in item motor : MotorStatus;
    out item fault : FaultReport;
    out item message : DisplayMessage;
  }

  action def ReconcileInventory {
    in item serviceCommand : ServiceCommand;
    out item inventory : InventoryReport;
    out item telemetry : TelemetryPacket;
  }

  action def MaintainColdStorage {
    in item targetTemperature : TemperatureQuantity;
    out item measuredTemperature : TemperatureQuantity;
    out item refrigerationFault : FaultReport;
  }

  state def VendingMachineOperatingStates {
    state off;
    state initializing;
    state ready;
    state selecting;
    state acceptingPayment;
    state authorizingPayment;
    state dispensing;
    state returningChange;
    state refunding;
    state maintenance;
    state outOfService;

    transition powerApplied first off then initializing;
    transition initializationComplete first initializing then ready;
    transition customerTouchesPanel first ready then selecting;
    transition validSelectionMade first selecting then acceptingPayment;
    transition tenderReceived first acceptingPayment then authorizingPayment;
    transition paymentApproved first authorizingPayment then dispensing;
    transition paymentDenied first authorizingPayment then refunding;
    transition productDelivered first dispensing then returningChange;
    transition settlementComplete first returningChange then ready;
    transition refundComplete first refunding then ready;
    transition serviceDoorOpened first ready then maintenance;
    transition serviceComplete first maintenance then initializing;
    transition unrecoverableFaultFromAnyState first ready then outOfService;
    transition recoverFault first outOfService then initializing;
    transition powerRemoved first ready then off;
  }

  part def TouchDisplayPanel {
    port customer : CustomerInteractionPort;
    port controller : ControllerDataPort;
    attribute screenDiagonal : LengthQuantity = (value = 254.0, unit = LengthUnit::millimeter);
    attribute supportsAudioPrompts : Boolean = true;
    attribute idleMessage : String = "Select a product";
  }

  part def PaymentSubsystem {
    port customerPayment : PaymentCollectionPort;
    port controller : ControllerDataPort;
    port network : NetworkPort;
    port power : LowVoltagePowerPort;

    attribute acceptedCoinValue : MoneyAmount = (value = 0.25, unit = CurrencyUnit::USD);
    attribute maximumBillAccepted : MoneyAmount = (value = 20.00, unit = CurrencyUnit::USD);
    attribute minimumCardAmount : MoneyAmount = (value = 0.50, unit = CurrencyUnit::USD);
    attribute cashCapacity : MoneyAmount = (value = 400.00, unit = CurrencyUnit::USD);
    attribute changeFloat : MoneyAmount = (value = 50.00, unit = CurrencyUnit::USD);

    perform action authorize : CollectAndAuthorizePayment;
    perform action settle : ReturnChangeOrRefund;
  }

  part def TransactionController {
    port data : ControllerDataPort;
    port customer : CustomerInteractionPort;
    port payment : PaymentCollectionPort;
    port inventory : InventoryControlPort;
    port actuator : ActuatorControlPort;
    port maintenance : MaintenancePort;
    port network : NetworkPort;
    port power : LowVoltagePowerPort;

    attribute machineMode : MachineMode = MachineMode::off;
    attribute activeFault : FaultKind = FaultKind::none;
    attribute transactionTimeout : TimeQuantity = (value = 120.0, unit = TimeUnit::second);
    attribute maximumVendDuration : TimeQuantity = (value = 45.0, unit = TimeUnit::second);
    attribute currentTransactionId : String = "none";

    exhibit state operatingState : VendingMachineOperatingStates;
    perform action primaryVendFunction : ProvideSelfServiceRetailVend;
    perform action faultDetection : DetectAndReportFault;
  }

  part def InventoryRack {
    port control : InventoryControlPort;
    port productTransfer : ProductTransferPort;
    port sensor : SensorPort;
    port power : LowVoltagePowerPort;

    attribute totalSpiralChannels : CountQuantity = (value = 48, unit = "count");
    attribute maximumProductsPerChannel : CountQuantity = (value = 12, unit = "count");
    attribute currentVendableCount : CountQuantity = (value = 384, unit = "count");
    attribute minimumReorderCount : CountQuantity = (value = 48, unit = "count");

    item colaCan : PackagedProduct {
      :>> sku = "DRK-COLA-355";
      :>> displayName = "Cola 355 mL";
      :>> category = ProductCategory::coldDrink;
      :>> price = (value = 1.75, unit = CurrencyUnit::USD);
      :>> packageMass = (value = 390.0, unit = MassUnit::gram);
      :>> packageVolume = (value = 355.0, unit = VolumeUnit::milliliter);
      :>> targetStorageTemperature = (value = 4.0, unit = TemperatureUnit::degreeCelsius);
      :>> expirationDate = "2026-12-31";
      :>> lotCode = "C355A";
    }

    item chipsBag : PackagedProduct {
      :>> sku = "SNK-CHIP-050";
      :>> displayName = "Potato Chips 50 g";
      :>> category = ProductCategory::snack;
      :>> price = (value = 1.50, unit = CurrencyUnit::USD);
      :>> packageMass = (value = 55.0, unit = MassUnit::gram);
      :>> packageVolume = (value = 400.0, unit = VolumeUnit::milliliter);
      :>> targetStorageTemperature = (value = 20.0, unit = TemperatureUnit::degreeCelsius);
      :>> expirationDate = "2026-08-31";
      :>> lotCode = "P050B";
    }

    perform action releaseProduct : ReleaseProductFromInventory;
    perform action reconcile : ReconcileInventory;
  }

  part def DispenseMechanism {
    port controller : ActuatorControlPort;
    port productIn : ProductTransferPort;
    port productOut : ProductTransferPort;
    port positionSensor : SensorPort;
    port power : LowVoltagePowerPort;

    attribute motorRatedPower : PowerQuantity = (value = 25.0, unit = PowerUnit::watt);
    attribute spiralRotationForSingleVend : Real = 360.0;
    attribute jamDetectionCurrentLimit : Real = 1.8;
    attribute maximumActuationTime : TimeQuantity = (value = 8.0, unit = TimeUnit::second);

    perform action deliverProduct : DeliverProductToCustomer;
  }

  part def DeliveryBin {
    port productIn : ProductTransferPort;
    port customerProduct : ProductDeliveryPort;
    port doorSensor : SensorPort;

    attribute binHeight : LengthQuantity = (value = 180.0, unit = LengthUnit::millimeter);
    attribute binWidth : LengthQuantity = (value = 420.0, unit = LengthUnit::millimeter);
    attribute binDepth : LengthQuantity = (value = 220.0, unit = LengthUnit::millimeter);
    attribute antiTheftFlapInstalled : Boolean = true;
  }

  part def RefrigerationUnit {
    port thermal : ThermalControlPort;
    port power : LowVoltagePowerPort;

    attribute compressorRatedPower : PowerQuantity = (value = 180.0, unit = PowerUnit::watt);
    attribute targetCabinetTemperature : TemperatureQuantity = (value = 4.0, unit = TemperatureUnit::degreeCelsius);
    attribute maximumAllowedCabinetTemperature : TemperatureQuantity = (value = 8.0, unit = TemperatureUnit::degreeCelsius);

    perform action maintainTemperature : MaintainColdStorage;
  }

  part def PowerSupply {
    port acInput : ElectricalPowerPort;
    port dcOutput : LowVoltagePowerPort;

    attribute inputVoltage : VoltageQuantity = (value = 120.0, unit = VoltageUnit::volt);
    attribute dcOutputVoltage : VoltageQuantity = (value = 24.0, unit = VoltageUnit::volt);
    attribute maximumOutputPower : PowerQuantity = (value = 600.0, unit = PowerUnit::watt);
    attribute dailyEnergyBudget : EnergyQuantity = (value = 4.8, unit = EnergyUnit::kilowattHour);
  }

  part def Cabinet {
    port powerFeedthrough : ElectricalPowerPort;
    port maintenance : MaintenancePort;
    port customerDelivery : ProductDeliveryPort;
    port customerInteraction : CustomerInteractionPort;

    attribute exteriorHeight : LengthQuantity = (value = 1830.0, unit = LengthUnit::millimeter);
    attribute exteriorWidth : LengthQuantity = (value = 890.0, unit = LengthUnit::millimeter);
    attribute exteriorDepth : LengthQuantity = (value = 810.0, unit = LengthUnit::millimeter);
    attribute emptyMass : MassQuantity = (value = 275.0, unit = MassUnit::kilogram);
    attribute serviceDoorLocked : Boolean = true;
  }

  part def RemoteOperationsGateway {
    port controller : NetworkPort;
    port maintenance : MaintenancePort;
    attribute supportsCellular : Boolean = true;
    attribute supportsEthernet : Boolean = true;
    attribute telemetryPeriod : TimeQuantity = (value = 15.0, unit = TimeUnit::minute);
  }

  part def VendingMachine {
    port customer : CustomerInteractionPort;
    port deliveredProduct : ProductDeliveryPort;
    port utilityPower : ElectricalPowerPort;
    port maintainer : MaintenancePort;
    port remoteNetwork : NetworkPort;

    attribute machineId : String = "VM-URBAN-001";
    attribute nominalInputVoltage : VoltageQuantity = (value = 120.0, unit = VoltageUnit::volt);
    attribute maximumOperatingPower : PowerQuantity = (value = 600.0, unit = PowerUnit::watt);
    attribute minimumOperatingTemperature : TemperatureQuantity = (value = 0.0, unit = TemperatureUnit::degreeCelsius);
    attribute maximumOperatingTemperature : TemperatureQuantity = (value = 40.0, unit = TemperatureUnit::degreeCelsius);
    attribute expectedVendCompletionTime : TimeQuantity = (value = 30.0, unit = TimeUnit::second);
    attribute operationalAvailabilityTarget : Real = 0.98;

    part cabinet : Cabinet;
    part panel : TouchDisplayPanel;
    part paymentSubsystem : PaymentSubsystem;
    part controller : TransactionController;
    part inventoryRack : InventoryRack;
    part dispenseMechanism : DispenseMechanism;
    part deliveryBin : DeliveryBin;
    part refrigerationUnit : RefrigerationUnit;
    part powerSupply : PowerSupply;
    part gateway : RemoteOperationsGateway;

    connection externalCustomerInterface connect customer to panel.customer;
    connection cabinetCustomerInterface connect cabinet.customerInteraction to panel.customer;
    connection customerDeliveryPath connect deliveryBin.customerProduct to deliveredProduct;
    connection cabinetDeliveryOpening connect cabinet.customerDelivery to deliveryBin.customerProduct;

    connection utilityToCabinet connect utilityPower to cabinet.powerFeedthrough;
    connection cabinetToPowerSupply connect cabinet.powerFeedthrough to powerSupply.acInput;
    connection powerToController connect powerSupply.dcOutput to controller.power;
    connection powerToPanel connect powerSupply.dcOutput to panel.controller;
    connection powerToPayment connect powerSupply.dcOutput to paymentSubsystem.power;
    connection powerToInventory connect powerSupply.dcOutput to inventoryRack.power;
    connection powerToDispense connect powerSupply.dcOutput to dispenseMechanism.power;
    connection powerToRefrigeration connect powerSupply.dcOutput to refrigerationUnit.power;

    connection panelToControllerCustomer connect panel.customer to controller.customer;
    connection panelDataToController connect panel.controller to controller.data;

    connection paymentToController connect paymentSubsystem.customerPayment to controller.payment;
    connection paymentDataToController connect paymentSubsystem.controller to controller.data;
    connection paymentNetworkToGateway connect paymentSubsystem.network to gateway.controller;

    connection controllerToInventory connect controller.inventory to inventoryRack.control;
    connection inventoryToDispenseProduct connect inventoryRack.productTransfer to dispenseMechanism.productIn;
    connection dispenseToDeliveryBin connect dispenseMechanism.productOut to deliveryBin.productIn;
    connection controllerToDispenseActuator connect controller.actuator to dispenseMechanism.controller;

    connection inventorySensorToController connect inventoryRack.sensor to controller.data;
    connection dispenseSensorToController connect dispenseMechanism.positionSensor to controller.data;
    connection deliveryDoorSensorToController connect deliveryBin.doorSensor to controller.data;

    connection controllerToRefrigeration connect controller.data to refrigerationUnit.thermal;
    connection maintainerToCabinet connect maintainer to cabinet.maintenance;
    connection maintainerToController connect maintainer to controller.maintenance;
    connection gatewayToController connect gateway.controller to controller.network;
    connection remoteToGateway connect remoteNetwork to gateway.controller;

    perform action vendingFunction : ProvideSelfServiceRetailVend;
    exhibit state modeState : VendingMachineOperatingStates;
  }

  requirement def PrimaryFunctionRequirement {
    subject machine : VendingMachine;
    doc /* The vending machine shall provide self-service retail vending by accepting a customer's product selection and payment, verifying product availability and payment sufficiency, dispensing the selected packaged product, and returning change, refund, receipt, or status information without attendant intervention. */
  }

  requirement def PaymentValidationRequirement {
    subject machine : VendingMachine;
    doc /* The vending machine shall dispense a product only when authorized payment is greater than or equal to the selected product price. */
    require constraint paymentCoverage : PaymentCoversPrice;
  }

  requirement def ProductAvailabilityRequirement {
    subject rack : InventoryRack;
    doc /* The inventory rack shall report whether the selected SKU is vendable before the controller commands product release. */
  }

  requirement def VendTimeRequirement {
    subject machine : VendingMachine;
    doc /* The vending machine shall complete an approved vend from payment authorization to product delivery within 45 seconds. */
    require constraint vendDuration : VendTimeWithinLimit;
  }

  requirement def ChangeAndRefundRequirement {
    subject payment : PaymentSubsystem;
    doc /* The payment subsystem shall return change after a successful cash transaction and shall issue a refund if payment is denied, the selected product is unavailable, or a product jam prevents delivery. */
  }

  requirement def FaultSafetyRequirement {
    subject controller : TransactionController;
    doc /* The transaction controller shall place the machine out of service for unrecoverable product jams, payment device failures, refrigeration faults, power faults, and controller faults. */
  }

  requirement def ColdStorageRequirement {
    subject refrigeration : RefrigerationUnit;
    doc /* The refrigeration unit shall maintain cold drink storage temperature at or below 7 degrees Celsius during normal operation. */
    require constraint coldLimit : StorageTemperatureWithinLimit;
  }

  requirement def MaintenanceTelemetryRequirement {
    subject gateway : RemoteOperationsGateway;
    doc /* The remote operations gateway shall transmit machine mode, active fault, energy usage, cash-on-hand, and inventory-related telemetry at least every 15 minutes. */
  }

  part vendingMachineSystem : VendingMachine;

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject machine = vendingMachineSystem;
  }

  requirement paymentValidation : PaymentValidationRequirement {
    subject machine = vendingMachineSystem;
  }

  requirement productAvailability : ProductAvailabilityRequirement {
    subject rack = vendingMachineSystem.inventoryRack;
  }

  requirement vendTime : VendTimeRequirement {
    subject machine = vendingMachineSystem;
  }

  requirement changeAndRefund : ChangeAndRefundRequirement {
    subject payment = vendingMachineSystem.paymentSubsystem;
  }

  requirement faultSafety : FaultSafetyRequirement {
    subject controller = vendingMachineSystem.controller;
  }

  requirement coldStorage : ColdStorageRequirement {
    subject refrigeration = vendingMachineSystem.refrigerationUnit;
  }

  requirement telemetry : MaintenanceTelemetryRequirement {
    subject gateway = vendingMachineSystem.gateway;
  }

  satisfy primaryFunction by vendingMachineSystem;
  satisfy paymentValidation by vendingMachineSystem.controller;
  satisfy paymentValidation by vendingMachineSystem.paymentSubsystem;
  satisfy productAvailability by vendingMachineSystem.inventoryRack;
  satisfy vendTime by vendingMachineSystem.dispenseMechanism;
  satisfy changeAndRefund by vendingMachineSystem.paymentSubsystem;
  satisfy faultSafety by vendingMachineSystem.controller;
  satisfy coldStorage by vendingMachineSystem.refrigerationUnit;
  satisfy telemetry by vendingMachineSystem.gateway;
}
