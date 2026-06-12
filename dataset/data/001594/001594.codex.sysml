package TechnologicalEvolutionModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Efficiency {
    :> scalar;
    unit = "%";
  }

  attribute def EnergyDensity {
    :> scalar;
    unit = "Wh/kg";
  }

  attribute def CarbonIntensity {
    :> scalar;
    unit = "gCO2/km";
  }

  attribute def Distance {
    :> scalar;
    unit = "km";
  }

  attribute def Speed {
    :> scalar;
    unit = "km/h";
  }

  attribute def Energy {
    :> scalar;
    unit = "kWh";
  }

  attribute def Time {
    :> scalar;
    unit = "min";
  }

  attribute def AutonomyLevel {
    :> scalar;
    unit = "SAE-level";
  }

  item def Passenger {
    attribute mass : Mass;
    attribute destinationDistance : Distance;
  }

  item def Cargo {
    attribute mass : Mass;
    attribute handlingPriority : Integer;
  }

  item def MobilityDemand {
    attribute requestedRange : Distance;
    attribute requestedArrivalTime : Time;
    attribute passengerCount : Integer;
    attribute cargoMass : Mass;
  }

  item def MotionCommand {
    attribute targetSpeed : Speed;
    attribute targetDistance : Distance;
  }

  item def EnergyFlow {
    attribute energyAmount : Energy;
    attribute deliveryRate : Power;
  }

  item def EmissionFlow {
    attribute carbonPerDistance : CarbonIntensity;
  }

  item def RoutePlan {
    attribute plannedDistance : Distance;
    attribute estimatedTravelTime : Time;
    attribute expectedEnergyUse : Energy;
  }

  enum def EvolutionStageKind {
    enum HorseDrawn;
    enum InternalCombustion;
    enum HybridElectric;
    enum BatteryElectric;
    enum AutonomousConnectedElectric;
  }

  port def PassengerPort {
    in item passengers : Passenger;
    out item transportedPassengers : Passenger;
  }

  port def CargoPort {
    in item cargo : Cargo;
    out item deliveredCargo : Cargo;
  }

  port def DemandPort {
    in item demand : MobilityDemand;
  }

  port def CommandPort {
    out item command : MotionCommand;
  }

  port def EnergyPort {
    in item suppliedEnergy : EnergyFlow;
    out item consumedEnergy : EnergyFlow;
  }

  port def EmissionPort {
    out item emissions : EmissionFlow;
  }

  port def RoutePort {
    out item routePlan : RoutePlan;
  }

  part def TransportTechnology {
    attribute stage : EvolutionStageKind;
    attribute averageSpeed : Speed;
    attribute range : Distance;
    attribute propulsionEfficiency : Efficiency;
    attribute carbonIntensity : CarbonIntensity;
    attribute energyDensity : EnergyDensity;
    attribute automationCapability : AutonomyLevel;

    port demandPort : DemandPort;
    port passengerPort : PassengerPort;
    port cargoPort : CargoPort;
    port energyPort : EnergyPort;
    port emissionPort : EmissionPort;
    port commandPort : CommandPort;
  }

  part def HorseDrawnTransport :> TransportTechnology {
    attribute :>> stage = EvolutionStageKind::HorseDrawn;
    attribute :>> averageSpeed = 12 [km/h];
    attribute :>> range = 35 [km];
    attribute :>> propulsionEfficiency = 8 [%];
    attribute :>> carbonIntensity = 0 [gCO2/km];
    attribute :>> energyDensity = 1 [Wh/kg];
    attribute :>> automationCapability = 0 [SAE-level];
  }

  part def InternalCombustionVehicle :> TransportTechnology {
    attribute :>> stage = EvolutionStageKind::InternalCombustion;
    attribute :>> averageSpeed = 85 [km/h];
    attribute :>> range = 650 [km];
    attribute :>> propulsionEfficiency = 25 [%];
    attribute :>> carbonIntensity = 180 [gCO2/km];
    attribute :>> energyDensity = 12000 [Wh/kg];
    attribute :>> automationCapability = 1 [SAE-level];
  }

  part def HybridElectricVehicle :> TransportTechnology {
    attribute :>> stage = EvolutionStageKind::HybridElectric;
    attribute :>> averageSpeed = 90 [km/h];
    attribute :>> range = 800 [km];
    attribute :>> propulsionEfficiency = 38 [%];
    attribute :>> carbonIntensity = 95 [gCO2/km];
    attribute :>> energyDensity = 250 [Wh/kg];
    attribute :>> automationCapability = 2 [SAE-level];
  }

  part def BatteryElectricVehicle :> TransportTechnology {
    attribute :>> stage = EvolutionStageKind::BatteryElectric;
    attribute :>> averageSpeed = 95 [km/h];
    attribute :>> range = 500 [km];
    attribute :>> propulsionEfficiency = 82 [%];
    attribute :>> carbonIntensity = 35 [gCO2/km];
    attribute :>> energyDensity = 300 [Wh/kg];
    attribute :>> automationCapability = 3 [SAE-level];
  }

  part def AutonomousConnectedElectricVehicle :> TransportTechnology {
    attribute :>> stage = EvolutionStageKind::AutonomousConnectedElectric;
    attribute :>> averageSpeed = 100 [km/h];
    attribute :>> range = 650 [km];
    attribute :>> propulsionEfficiency = 88 [%];
    attribute :>> carbonIntensity = 20 [gCO2/km];
    attribute :>> energyDensity = 420 [Wh/kg];
    attribute :>> automationCapability = 4 [SAE-level];

    port routePort : RoutePort;
  }

  part def EvolutionKnowledgeBase {
    attribute selectedStage : EvolutionStageKind;
    attribute minimumAcceptableEfficiency : Efficiency = 80 [%];
    attribute maximumAcceptableCarbonIntensity : CarbonIntensity = 50 [gCO2/km];
    attribute targetAutonomy : AutonomyLevel = 4 [SAE-level];

    port demandInput : DemandPort;
    port selectedCommand : CommandPort;
    port plannedRoute : RoutePort;
  }

  part def TechnologicalEvolutionTransportSystem {
    attribute primaryFunction = "Transport passengers and cargo by selecting and applying progressively more capable mobility technology that improves speed, energy efficiency, automation, and environmental performance.";

    port mobilityDemand : DemandPort;
    port passengerInterface : PassengerPort;
    port cargoInterface : CargoPort;
    port externalEnergy : EnergyPort;
    port environmentalOutput : EmissionPort;

    part horseTransport : HorseDrawnTransport;
    part combustionVehicle : InternalCombustionVehicle;
    part hybridVehicle : HybridElectricVehicle;
    part electricVehicle : BatteryElectricVehicle;
    part autonomousVehicle : AutonomousConnectedElectricVehicle;
    part evolutionController : EvolutionKnowledgeBase;

    connect mobilityDemand to evolutionController.demandInput;
    connect passengerInterface to autonomousVehicle.passengerPort;
    connect cargoInterface to autonomousVehicle.cargoPort;
    connect externalEnergy to autonomousVehicle.energyPort;
    connect autonomousVehicle.emissionPort to environmentalOutput;
    connect evolutionController.selectedCommand to autonomousVehicle.commandPort;
    connect evolutionController.plannedRoute to autonomousVehicle.routePort;
  }

  action def AssessMobilityDemand {
    in item demand : MobilityDemand;
    out attribute requiredRange : Distance;
    out attribute requiredCapacity : Mass;
  }

  action def CompareTechnologyStages {
    in attribute requiredRange : Distance;
    in attribute carbonLimit : CarbonIntensity;
    out attribute selectedStage : EvolutionStageKind;
  }

  action def PlanRoute {
    in item demand : MobilityDemand;
    in attribute selectedStage : EvolutionStageKind;
    out item route : RoutePlan;
  }

  action def ExecuteTransport {
    in item route : RoutePlan;
    in item passengers : Passenger;
    in item cargo : Cargo;
    out item transportedPassengers : Passenger;
    out item deliveredCargo : Cargo;
    out item emissions : EmissionFlow;
  }

  action def FulfillMobilityFunction {
    in item demand : MobilityDemand;
    in item passengers : Passenger;
    in item cargo : Cargo;
    out item transportedPassengers : Passenger;
    out item deliveredCargo : Cargo;
    out item emissions : EmissionFlow;

    action assess : AssessMobilityDemand;
    action compare : CompareTechnologyStages;
    action plan : PlanRoute;
    action execute : ExecuteTransport;

    flow demand to assess.demand;
    flow assess.requiredRange to compare.requiredRange;
    flow demand to plan.demand;
    flow compare.selectedStage to plan.selectedStage;
    flow plan.route to execute.route;
    flow passengers to execute.passengers;
    flow cargo to execute.cargo;
    flow execute.transportedPassengers to transportedPassengers;
    flow execute.deliveredCargo to deliveredCargo;
    flow execute.emissions to emissions;
  }

  state def TechnologyEvolutionLifecycle {
    entry action initializeBaseline;
    state ManualBiologicalTransport;
    state MechanizedCombustionTransport;
    state ElectrifiedAssistTransport;
    state ZeroTailpipeEmissionTransport;
    state AutonomousOptimizedTransport;
    state RetiredLegacyTechnology;

    transition first ManualBiologicalTransport;

    transition t1
      first ManualBiologicalTransport
      then MechanizedCombustionTransport
      accept after 60 [year];

    transition t2
      first MechanizedCombustionTransport
      then ElectrifiedAssistTransport
      accept when fuelEfficiencyPressure == true;

    transition t3
      first ElectrifiedAssistTransport
      then ZeroTailpipeEmissionTransport
      accept when batteryEnergyDensity >= 250 [Wh/kg];

    transition t4
      first ZeroTailpipeEmissionTransport
      then AutonomousOptimizedTransport
      accept when automationCapability >= 4 [SAE-level];

    transition retire
      first MechanizedCombustionTransport
      then RetiredLegacyTechnology
      accept when carbonIntensity > 150 [gCO2/km];
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide high-level mobility by transporting passengers and cargo from origin to destination using the most advanced feasible technology stage in the modeled evolution. */
  }

  requirement def EfficiencyEvolutionRequirement {
    doc /* Each later propulsion technology shall improve useful energy conversion efficiency relative to the immediately preceding mechanized technology stage. */
  }

  requirement def EmissionsReductionRequirement {
    doc /* The selected contemporary technology shall limit operational carbon intensity to no more than 50 gCO2/km for the modeled transport mission. */
  }

  requirement def AutomationRequirement {
    doc /* The final evolution stage shall support connected autonomous route planning and motion execution at SAE automation level 4 or higher. */
  }

  requirement def RangeRequirement {
    doc /* The selected transport technology shall provide a mission range of at least 500 km without interrupting the passenger or cargo delivery function. */
  }

  satisfy PrimaryFunctionRequirement by TechnologicalEvolutionTransportSystem;
  satisfy EfficiencyEvolutionRequirement by BatteryElectricVehicle;
  satisfy EmissionsReductionRequirement by AutonomousConnectedElectricVehicle;
  satisfy AutomationRequirement by AutonomousConnectedElectricVehicle;
  satisfy RangeRequirement by AutonomousConnectedElectricVehicle;

  analysis def EvolutionPerformanceAnalysis {
    subject system : TechnologicalEvolutionTransportSystem;

    objective minimize system.autonomousVehicle.carbonIntensity;
    objective maximize system.autonomousVehicle.propulsionEfficiency;
    objective maximize system.autonomousVehicle.automationCapability;

    constraint rangeConstraint {
      system.autonomousVehicle.range >= 500 [km]
    }

    constraint emissionsConstraint {
      system.autonomousVehicle.carbonIntensity <= 50 [gCO2/km]
    }

    constraint automationConstraint {
      system.autonomousVehicle.automationCapability >= 4 [SAE-level]
    }
  }

}