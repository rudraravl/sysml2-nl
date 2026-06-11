package ElmerAndElsieSystem {
    import ScalarValues::*;
    import SI::*;

    attribute def Volume_L : Real {
        unit = "L";
    }

    attribute def Mass_kg : Real {
        unit = "kg";
    }

    attribute def FlowRate_L_per_min : Real {
        unit = "L/min";
    }

    attribute def Temperature_C : Real {
        unit = "degC";
    }

    attribute def Duration_min : Real {
        unit = "min";
    }

    attribute def Percent : Real {
        unit = "%";
    }

    item def RawMilk {
        attribute volume : Volume_L;
        attribute temperature : Temperature_C;
        attribute butterfat : Percent;
        attribute protein : Percent;
    }

    item def PasteurizedMilk {
        attribute volume : Volume_L;
        attribute temperature : Temperature_C;
        attribute safetyScore : Percent;
    }

    item def FeedRation {
        attribute mass : Mass_kg;
        attribute proteinContent : Percent;
    }

    item def CareAlert {
        attribute priority : Integer;
        attribute message : String;
    }

    item def VisitorMessage {
        attribute title : String;
        attribute body : String;
    }

    port def FeedPort {
        in item ration : FeedRation;
    }

    port def MilkOutputPort {
        out item milk : RawMilk;
    }

    port def MilkInputPort {
        in item milk : RawMilk;
    }

    port def ProcessedMilkPort {
        out item milk : PasteurizedMilk;
    }

    port def AlertPort {
        out item alert : CareAlert;
    }

    port def MessagePort {
        out item message : VisitorMessage;
    }

    port def CareCommandPort {
        in item alert : CareAlert;
    }

    action def GrazeAndProduceMilk {
        in item ration : FeedRation;
        out item milk : RawMilk;
        attribute grazingDuration : Duration_min = 360;
        attribute expectedYield : Volume_L = 28;
    }

    action def MonitorAnimalWellbeing {
        out item alert : CareAlert;
        attribute hydrationLevel : Percent;
        attribute comfortIndex : Percent;
    }

    action def CollectMilk {
        in item milkIn : RawMilk;
        out item milkOut : RawMilk;
        attribute collectionRate : FlowRate_L_per_min = 8;
        attribute maxCollectionTime : Duration_min = 12;
    }

    action def PasteurizeMilk {
        in item raw : RawMilk;
        out item processed : PasteurizedMilk;
        attribute targetTemperature : Temperature_C = 72;
        attribute holdTime : Duration_min = 0.25;
    }

    action def PresentBrandStory {
        out item message : VisitorMessage;
        attribute educationDuration : Duration_min = 5;
    }

    state def HerdMemberState {
        entry action MonitorAnimalWellbeing;

        state Resting;
        state Grazing;
        state ReadyForMilking;
        state Milking;
        state CareRequired;

        transition first Resting;
        transition Resting_to_Grazing
            first Resting then Grazing;

        transition Grazing_to_ReadyForMilking
            first Grazing then ReadyForMilking;

        transition ReadyForMilking_to_Milking
            first ReadyForMilking then Milking;

        transition Milking_to_Resting
            first Milking then Resting;

        transition Any_to_CareRequired
            first Resting then CareRequired;

        transition CareRequired_to_Resting
            first CareRequired then Resting;
    }

    state def DairyProcessState {
        state Idle;
        state ReceivingRawMilk;
        state Pasteurizing;
        state Cooling;
        state ReadyForDistribution;

        transition initial_to_idle
            first Idle;

        transition receive
            first Idle then ReceivingRawMilk;

        transition process
            first ReceivingRawMilk then Pasteurizing;

        transition cool
            first Pasteurizing then Cooling;

        transition release
            first Cooling then ReadyForDistribution;

        transition reset
            first ReadyForDistribution then Idle;
    }

    part def Elmer {
        attribute bodyMass : Mass_kg = 820;
        attribute dailyFeedNeed : Mass_kg = 24;
        attribute comfortIndex : Percent;

        port feedIn : FeedPort;
        port careAlertOut : AlertPort;
        port visitorMessageOut : MessagePort;

        perform action monitor : MonitorAnimalWellbeing;
        perform action story : PresentBrandStory;

        exhibit state lifecycle : HerdMemberState;
    }

    part def Elsie {
        attribute bodyMass : Mass_kg = 620;
        attribute dailyFeedNeed : Mass_kg = 18;
        attribute nominalDailyMilkYield : Volume_L = 30;
        attribute comfortIndex : Percent;

        port feedIn : FeedPort;
        port milkOut : MilkOutputPort;
        port careAlertOut : AlertPort;
        port visitorMessageOut : MessagePort;

        perform action production : GrazeAndProduceMilk;
        perform action monitor : MonitorAnimalWellbeing;
        perform action story : PresentBrandStory;

        exhibit state lifecycle : HerdMemberState;
    }

    part def FeedingStation {
        attribute storedFeedMass : Mass_kg = 500;
        attribute dispenseRate : FlowRate_L_per_min = 2;

        port elmerFeedOut : FeedPort;
        port elsieFeedOut : FeedPort;
    }

    part def MilkingStation {
        attribute collectionRate : FlowRate_L_per_min = 8;
        attribute sanitationLevel : Percent = 99.5;

        port rawMilkIn : MilkInputPort;
        port rawMilkOut : MilkOutputPort;

        perform action collect : CollectMilk;
    }

    part def Pasteurizer {
        attribute operatingTemperature : Temperature_C = 72;
        attribute holdTime : Duration_min = 0.25;
        attribute thermalEfficiency : Percent = 91;

        port rawMilkIn : MilkInputPort;
        port processedMilkOut : ProcessedMilkPort;

        perform action pasteurize : PasteurizeMilk;
        exhibit state processState : DairyProcessState;
    }

    part def AnimalCareConsole {
        attribute responseTarget : Duration_min = 10;

        port elmerAlertIn : CareCommandPort;
        port elsieAlertIn : CareCommandPort;
    }

    part def VisitorEducationDisplay {
        attribute messageRefreshPeriod : Duration_min = 15;

        port elmerStoryIn : MessagePort;
        port elsieStoryIn : MessagePort;
    }

    part def ElmerElsieDairyExperience {
        attribute primaryFunction : String =
            "Coordinate Elmer and Elsie as a paired dairy stewardship and education system that cares for the animals, produces safe milk, and communicates the dairy story to visitors.";

        part elmer : Elmer;
        part elsie : Elsie;
        part feeder : FeedingStation;
        part milkingStation : MilkingStation;
        part pasteurizer : Pasteurizer;
        part careConsole : AnimalCareConsole;
        part visitorDisplay : VisitorEducationDisplay;

        connection feedElmer
            connect feeder.elmerFeedOut to elmer.feedIn;

        connection feedElsie
            connect feeder.elsieFeedOut to elsie.feedIn;

        connection milkElsie
            connect elsie.milkOut to milkingStation.rawMilkIn;

        connection collectedMilk
            connect milkingStation.rawMilkOut to pasteurizer.rawMilkIn;

        connection elmerCareAlert
            connect elmer.careAlertOut to careConsole.elmerAlertIn;

        connection elsieCareAlert
            connect elsie.careAlertOut to careConsole.elsieAlertIn;

        connection elmerStory
            connect elmer.visitorMessageOut to visitorDisplay.elmerStoryIn;

        connection elsieStory
            connect elsie.visitorMessageOut to visitorDisplay.elsieStoryIn;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use the Elmer and Elsie pairing to provide a high-level dairy stewardship function: animal care, milk production, milk safety processing, and visitor education. */
    }

    requirement def AnimalWelfareRequirement {
        attribute minComfortIndex : Percent = 85;
        doc /* Elmer and Elsie shall be monitored continuously and shall generate a care alert when comfort index falls below the minimum threshold. */
    }

    requirement def MilkProductionRequirement {
        attribute minDailyRawMilkVolume : Volume_L = 25;
        doc /* Elsie shall provide raw milk to the milking station with a nominal daily volume greater than or equal to the specified minimum. */
    }

    requirement def MilkSafetyRequirement {
        attribute requiredPasteurizationTemperature : Temperature_C = 72;
        attribute requiredHoldTime : Duration_min = 0.25;
        attribute minSafetyScore : Percent = 99;
        doc /* Raw milk shall be pasteurized at the required temperature and hold time before release as processed milk. */
    }

    requirement def VisitorEducationRequirement {
        attribute maxRefreshPeriod : Duration_min = 15;
        doc /* The visitor display shall present current Elmer and Elsie messages within the maximum refresh period. */
    }

    requirement primaryFunctionReq : PrimaryFunctionRequirement;
    requirement welfareReq : AnimalWelfareRequirement;
    requirement productionReq : MilkProductionRequirement;
    requirement safetyReq : MilkSafetyRequirement;
    requirement educationReq : VisitorEducationRequirement;

    part system : ElmerElsieDairyExperience;

    satisfy primaryFunctionReq by system;
    satisfy welfareReq by system.elmer;
    satisfy welfareReq by system.elsie;
    satisfy productionReq by system.elsie;
    satisfy safetyReq by system.pasteurizer;
    satisfy educationReq by system.visitorDisplay;
}