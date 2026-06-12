package DomusResidentialSystem {

  import ScalarValues::*;
  import SI::*;

  value type AreaValue :> Real;
  value type VolumeValue :> Real;
  value type FlowRateValue :> Real;
  value type TemperatureValue :> Real;
  value type IlluminanceValue :> Real;
  value type PersonCountValue :> Integer;
  value type SecurityLevelValue :> Integer;

  item def Person {
    attribute role : String;
    attribute mobilityNeed : String;
  }

  item def RainWater {
    attribute volume : VolumeValue;
    attribute potable : Boolean;
  }

  item def GreyWater {
    attribute volume : VolumeValue;
  }

  item def FreshAir {
    attribute temperature : TemperatureValue;
    attribute flowRate : FlowRateValue;
  }

  item def Daylight {
    attribute illuminance : IlluminanceValue;
  }

  item def FoodSupply {
    attribute storageVolume : VolumeValue;
  }

  item def HouseholdWaste {
    attribute volume : VolumeValue;
  }

  port def PersonAccessPort {
    in item arrivingPerson : Person;
    out item departingPerson : Person;
  }

  port def WaterPort {
    in item suppliedWater : RainWater;
    out item dischargedWater : GreyWater;
  }

  port def AirPort {
    in item incomingAir : FreshAir;
    out item outgoingAir : FreshAir;
  }

  port def LightPort {
    in item daylight : Daylight;
  }

  port def FoodPort {
    in item food : FoodSupply;
  }

  port def WastePort {
    out item waste : HouseholdWaste;
  }

  port def SecurityPort {
    in attribute accessAuthorized : Boolean;
    out attribute intrusionDetected : Boolean;
  }

  part def Vestibulum {
    attribute area : AreaValue = 10.0;
    attribute securityLevel : SecurityLevelValue = 4;
    port streetAccess : PersonAccessPort;
    port houseAccess : PersonAccessPort;
    port securityInterface : SecurityPort;
  }

  part def Fauces {
    attribute area : AreaValue = 8.0;
    port entryFlow : PersonAccessPort;
    port atriumFlow : PersonAccessPort;
  }

  part def Atrium {
    attribute area : AreaValue = 80.0;
    attribute socialCapacity : PersonCountValue = 24;
    port occupantFlow : PersonAccessPort;
    port airExchange : AirPort;
    port daylightInput : LightPort;
    port waterCollection : WaterPort;
  }

  part def Compluvium {
    attribute openingArea : AreaValue = 16.0;
    port daylightCapture : LightPort;
    port rainCapture : WaterPort;
    port ventilationOpening : AirPort;
  }

  part def Impluvium {
    attribute basinArea : AreaValue = 12.0;
    attribute storageVolume : VolumeValue = 6.0;
    port collectedWater : WaterPort;
  }

  part def Tablinum {
    attribute area : AreaValue = 30.0;
    attribute archiveCapacity : VolumeValue = 4.0;
    port patronAccess : PersonAccessPort;
    port daylightInput : LightPort;
  }

  part def Peristylum {
    attribute gardenArea : AreaValue = 120.0;
    attribute shadedWalkwayArea : AreaValue = 60.0;
    port familyAccess : PersonAccessPort;
    port airExchange : AirPort;
    port daylightInput : LightPort;
  }

  part def Cubiculum {
    attribute area : AreaValue = 14.0;
    attribute sleepingCapacity : PersonCountValue = 2;
    port residentAccess : PersonAccessPort;
    port airExchange : AirPort;
  }

  part def Triclinium {
    attribute area : AreaValue = 36.0;
    attribute diningCapacity : PersonCountValue = 9;
    port guestAccess : PersonAccessPort;
    port foodService : FoodPort;
    port airExchange : AirPort;
  }

  part def Culina {
    attribute area : AreaValue = 20.0;
    attribute cookingCapacity : PersonCountValue = 4;
    port foodInput : FoodPort;
    port mealOutput : FoodPort;
    port smokeVent : AirPort;
    port wasteOutput : WastePort;
  }

  part def Latrina {
    attribute area : AreaValue = 8.0;
    port userAccess : PersonAccessPort;
    port waterFlush : WaterPort;
    port wasteDischarge : WastePort;
  }

  part def StorageRoom {
    attribute area : AreaValue = 18.0;
    attribute dryStorageVolume : VolumeValue = 20.0;
    port supplyInput : FoodPort;
    port supplyOutput : FoodPort;
  }

  action def AdmitAuthorizedVisitor {
    in item visitor : Person;
    in attribute authorized : Boolean;
    out item admittedVisitor : Person;
  }

  action def CollectRainwater {
    in item rainfall : RainWater;
    out item storedWater : RainWater;
  }

  action def VentilateHouse {
    in item exteriorAir : FreshAir;
    out item interiorAir : FreshAir;
  }

  action def HostReception {
    in item clients : Person;
    out attribute receptionComplete : Boolean;
  }

  action def SupportDailyHouseholdLiving {
    in item householdMembers : Person;
    in item guests : Person;
    in item foodSupply : FoodSupply;
    out item waste : HouseholdWaste;
    out item dischargedWater : GreyWater;

    first start;
    then admitVisitors : AdmitAuthorizedVisitor;
    then receiveGuests : HostReception;
    then ventilate : VentilateHouse;
    then collectWater : CollectRainwater;
    then finish;
  }

  state def DomusOperatingStateMachine {
    entry;
    state Closed;
    state MorningReception;
    state DomesticActivity;
    state Dining;
    state NightRest;
    state Maintenance;

    transition entry then Closed;
    transition Closed to MorningReception
      accept when accessAuthorized == true;
    transition MorningReception to DomesticActivity
      accept after 3 [h];
    transition DomesticActivity to Dining
      accept when mealPrepared == true;
    transition Dining to NightRest
      accept after 2 [h];
    transition NightRest to MorningReception
      accept after 8 [h];
    transition DomesticActivity to Maintenance
      accept when waterStorageLow == true or wasteRemovalRequired == true;
    transition Maintenance to DomesticActivity
      accept when serviceRestored == true;
  }

  part def Domus {
    attribute totalArea : AreaValue = 430.0;
    attribute enclosedArea : AreaValue = 250.0;
    attribute openCourtyardArea : AreaValue = 180.0;
    attribute normalOccupantCapacity : PersonCountValue = 16;
    attribute receptionCapacity : PersonCountValue = 24;
    attribute minimumIndoorIlluminance : IlluminanceValue = 150.0;
    attribute targetIndoorTemperature : TemperatureValue = 295.15;
    attribute primaryFunction : String =
      "Provide a secure, climate-moderated, socially organized household environment for Roman family life, patron-client reception, dining, rest, storage, sanitation, daylighting, and rainwater management.";

    port streetInterface : PersonAccessPort;
    port municipalWaterInterface : WaterPort;
    port drainageInterface : WaterPort;
    port exteriorAirInterface : AirPort;
    port solarLightInterface : LightPort;
    port supplyDeliveryInterface : FoodPort;
    port refuseRemovalInterface : WastePort;
    port securityInterface : SecurityPort;

    part vestibulum : Vestibulum;
    part fauces : Fauces;
    part atrium : Atrium;
    part compluvium : Compluvium;
    part impluvium : Impluvium;
    part tablinum : Tablinum;
    part peristylum : Peristylum;
    part masterCubiculum : Cubiculum {
      attribute area = 18.0;
    }
    part familyCubiculum1 : Cubiculum;
    part familyCubiculum2 : Cubiculum;
    part guestCubiculum : Cubiculum;
    part triclinium : Triclinium;
    part culina : Culina;
    part latrina : Latrina;
    part storage : StorageRoom;

    connect streetInterface to vestibulum.streetAccess;
    connect vestibulum.houseAccess to fauces.entryFlow;
    connect fauces.atriumFlow to atrium.occupantFlow;
    connect atrium.occupantFlow to tablinum.patronAccess;
    connect atrium.occupantFlow to peristylum.familyAccess;
    connect peristylum.familyAccess to masterCubiculum.residentAccess;
    connect peristylum.familyAccess to familyCubiculum1.residentAccess;
    connect peristylum.familyAccess to familyCubiculum2.residentAccess;
    connect peristylum.familyAccess to guestCubiculum.residentAccess;
    connect peristylum.familyAccess to triclinium.guestAccess;
    connect peristylum.familyAccess to latrina.userAccess;

    connect solarLightInterface to compluvium.daylightCapture;
    connect compluvium.daylightCapture to atrium.daylightInput;
    connect peristylum.daylightInput to tablinum.daylightInput;

    connect exteriorAirInterface to compluvium.ventilationOpening;
    connect compluvium.ventilationOpening to atrium.airExchange;
    connect atrium.airExchange to peristylum.airExchange;
    connect peristylum.airExchange to triclinium.airExchange;
    connect peristylum.airExchange to masterCubiculum.airExchange;
    connect peristylum.airExchange to familyCubiculum1.airExchange;
    connect peristylum.airExchange to familyCubiculum2.airExchange;
    connect culina.smokeVent to exteriorAirInterface;

    connect municipalWaterInterface to compluvium.rainCapture;
    connect compluvium.rainCapture to impluvium.collectedWater;
    connect impluvium.collectedWater to atrium.waterCollection;
    connect impluvium.collectedWater to latrina.waterFlush;
    connect latrina.waterFlush to drainageInterface;

    connect supplyDeliveryInterface to storage.supplyInput;
    connect storage.supplyOutput to culina.foodInput;
    connect culina.mealOutput to triclinium.foodService;
    connect culina.wasteOutput to refuseRemovalInterface;
    connect latrina.wasteDischarge to refuseRemovalInterface;

    perform dailyLiving : SupportDailyHouseholdLiving;
    exhibit stateMachine : DomusOperatingStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    subject domus : Domus;
    require constraint {
      domus.normalOccupantCapacity >= 12 and
      domus.receptionCapacity >= 20 and
      domus.enclosedArea >= 200.0
    }
  }

  requirement def SecurityRequirement {
    subject domus : Domus;
    require constraint {
      domus.vestibulum.securityLevel >= 4
    }
  }

  requirement def WaterManagementRequirement {
    subject domus : Domus;
    require constraint {
      domus.impluvium.storageVolume >= 5.0 and
      domus.compluvium.openingArea >= 12.0
    }
  }

  requirement def SocialOrganizationRequirement {
    subject domus : Domus;
    require constraint {
      domus.atrium.socialCapacity >= domus.receptionCapacity and
      domus.triclinium.diningCapacity >= 9
    }
  }

  requirement def HabitabilityRequirement {
    subject domus : Domus;
    require constraint {
      domus.minimumIndoorIlluminance >= 150.0 and
      domus.targetIndoorTemperature >= 291.15 and
      domus.targetIndoorTemperature <= 299.15
    }
  }

  part domusSystem : Domus;

}