package AstronautPrimaryFunctionModel {

  import ScalarValues::*;

  attribute def Mass_kg :> Real;
  attribute def Pressure_kPa :> Real;
  attribute def Temperature_C :> Real;
  attribute def FlowRate_L_per_min :> Real;
  attribute def Power_W :> Real;
  attribute def Energy_Wh :> Real;
  attribute def Time_min :> Real;
  attribute def Distance_m :> Real;
  attribute def Percentage :> Real;
  attribute def HeartRate_bpm :> Real;

  enum def AstronautMode {
    enum preparing;
    enum translating;
    enum performingTask;
    enum contingency;
    enum returning;
    enum recovered;
  }

  enum def HealthState {
    enum nominal;
    enum fatigued;
    enum injured;
    enum incapacitated;
  }

  enum def SuitIntegrityState {
    enum sealed;
    enum degraded;
    enum leaking;
    enum failed;
  }

  item def OxygenMixture {
    attribute oxygenPartialPressure : Pressure_kPa;
    attribute flowRate : FlowRate_L_per_min;
    attribute temperature : Temperature_C;
  }

  item def CarbonDioxideStream {
    attribute carbonDioxidePartialPressure : Pressure_kPa;
    attribute flowRate : FlowRate_L_per_min;
  }

  item def ThermalFluid {
    attribute temperature : Temperature_C;
    attribute flowRate : FlowRate_L_per_min;
  }

  item def VoiceSignal {
    attribute signalStrength : Percentage;
  }

  item def TelemetryPacket {
    attribute oxygenPressure : Pressure_kPa;
    attribute carbonDioxidePressure : Pressure_kPa;
    attribute heartRate : HeartRate_bpm;
    attribute suitPressure : Pressure_kPa;
    attribute batteryEnergy : Energy_Wh;
    attribute currentMode : AstronautMode;
  }

  item def MissionCommand {
    attribute priority : Integer;
    attribute commandText : String;
  }

  item def ToolForce {
    attribute magnitude : Real;
  }

  item def CrewMotion {
    attribute translationDistance : Distance_m;
    attribute duration : Time_min;
  }

  item def VisualObservation {
    attribute description : String;
    attribute confidence : Percentage;
  }

  item def TaskResult {
    attribute completed : Boolean;
    attribute quality : Percentage;
    attribute elapsedTime : Time_min;
  }

  port def BreathingGasPort {
    in item oxygen : OxygenMixture;
    out item exhaledGas : CarbonDioxideStream;
  }

  port def ThermalControlPort {
    in item cooledFluid : ThermalFluid;
    out item warmedFluid : ThermalFluid;
  }

  port def CommunicationPort {
    in item command : MissionCommand;
    out item voice : VoiceSignal;
    out item telemetry : TelemetryPacket;
  }

  port def MobilityPort {
    out item movement : CrewMotion;
  }

  port def ManipulationPort {
    out item force : ToolForce;
    in item observation : VisualObservation;
  }

  port def StructuralInterfacePort {
    in item restraintLoad : ToolForce;
    out item appliedLoad : ToolForce;
  }

  part def HumanOperator {
    attribute mass : Mass_kg;
    attribute metabolicHeat : Power_W;
    attribute heartRate : HeartRate_bpm;
    attribute health : HealthState;

    port respiration : BreathingGasPort;
    port bodyCooling : ThermalControlPort;
    port speechAndHearing : CommunicationPort;
    port limbs : ManipulationPort;
    port locomotion : MobilityPort;

    action def ObserveWorksite {
      in item visualScene : VisualObservation;
      out item interpretedObservation : VisualObservation;
    }

    action def ExecuteMissionTask {
      in item command : MissionCommand;
      in item worksiteObservation : VisualObservation;
      out item result : TaskResult;
    }
  }

  part def PressureGarment {
    attribute internalPressure : Pressure_kPa;
    attribute leakRate : FlowRate_L_per_min;
    attribute integrity : SuitIntegrityState;

    port breathingLoop : BreathingGasPort;
    port coolingLoop : ThermalControlPort;
    port crewSide : StructuralInterfacePort;
    port environmentSide : StructuralInterfacePort;
  }

  part def PortableLifeSupportSystem {
    attribute oxygenStoragePressure : Pressure_kPa;
    attribute carbonDioxideCapacityRemaining : Percentage;
    attribute batteryEnergyRemaining : Energy_Wh;
    attribute supplyPower : Power_W;

    port crewGas : BreathingGasPort;
    port suitThermal : ThermalControlPort;
    port telemetryOut : CommunicationPort;

    action def RegulateBreathingGas {
      in item exhaledGas : CarbonDioxideStream;
      out item oxygen : OxygenMixture;
    }

    action def RemoveCarbonDioxide {
      in item exhaledGas : CarbonDioxideStream;
      out item scrubbedGas : OxygenMixture;
    }

    action def ControlThermalLoop {
      in item warmedFluid : ThermalFluid;
      out item cooledFluid : ThermalFluid;
    }
  }

  part def CommunicationSubsystem {
    attribute transmitPower : Power_W;
    attribute linkMargin : Percentage;

    port crewAudio : CommunicationPort;
    port missionLink : CommunicationPort;

    action def RelayVoiceAndTelemetry {
      in item crewVoice : VoiceSignal;
      in item telemetry : TelemetryPacket;
      out item downlinkTelemetry : TelemetryPacket;
      out item downlinkVoice : VoiceSignal;
    }

    action def ReceiveMissionCommand {
      in item uplinkCommand : MissionCommand;
      out item crewCommand : MissionCommand;
    }
  }

  part def BiomedicalMonitor {
    attribute measuredHeartRate : HeartRate_bpm;
    attribute oxygenSaturation : Percentage;
    attribute fatigueIndex : Percentage;

    port telemetryPort : CommunicationPort;

    action def AssessCrewHealth {
      out item healthTelemetry : TelemetryPacket;
    }
  }

  part def ToolSet {
    attribute toolMass : Mass_kg;
    attribute availablePower : Power_W;

    port handInterface : ManipulationPort;
    port worksiteInterface : StructuralInterfacePort;

    action def ApplyToolToWorksite {
      in item operatorForce : ToolForce;
      out item taskResult : TaskResult;
    }
  }

  part def AstronautSystem {
    attribute totalMass : Mass_kg;
    attribute plannedEvaDuration : Time_min;
    attribute currentMode : AstronautMode;

    part crew : HumanOperator {
      attribute mass = 82.0;
      attribute metabolicHeat = 420.0;
      attribute heartRate = 72.0;
      attribute health = HealthState::nominal;
    }

    part suit : PressureGarment {
      attribute internalPressure = 29.6;
      attribute leakRate = 0.02;
      attribute integrity = SuitIntegrityState::sealed;
    }

    part lifeSupport : PortableLifeSupportSystem {
      attribute oxygenStoragePressure = 20700.0;
      attribute carbonDioxideCapacityRemaining = 100.0;
      attribute batteryEnergyRemaining = 1200.0;
      attribute supplyPower = 180.0;
    }

    part communications : CommunicationSubsystem {
      attribute transmitPower = 12.0;
      attribute linkMargin = 85.0;
    }

    part biomedicalMonitor : BiomedicalMonitor {
      attribute measuredHeartRate = 72.0;
      attribute oxygenSaturation = 98.0;
      attribute fatigueIndex = 12.0;
    }

    part tools : ToolSet {
      attribute toolMass = 14.0;
      attribute availablePower = 150.0;
    }

    port missionControl : CommunicationPort;
    port spacecraftInterface : StructuralInterfacePort;
    port worksite : StructuralInterfacePort;
    port mobilityOutput : MobilityPort;

    connect lifeSupport.crewGas to suit.breathingLoop;
    connect suit.breathingLoop to crew.respiration;
    connect lifeSupport.suitThermal to suit.coolingLoop;
    connect suit.coolingLoop to crew.bodyCooling;
    connect crew.speechAndHearing to communications.crewAudio;
    connect communications.missionLink to missionControl;
    connect biomedicalMonitor.telemetryPort to communications.crewAudio;
    connect crew.limbs to tools.handInterface;
    connect tools.worksiteInterface to worksite;
    connect suit.environmentSide to spacecraftInterface;
    connect crew.locomotion to mobilityOutput;

    action def SustainAstronaut {
      out item telemetry : TelemetryPacket;

      first lifeSupport.RegulateBreathingGas;
      then lifeSupport.RemoveCarbonDioxide;
      then lifeSupport.ControlThermalLoop;
      then biomedicalMonitor.AssessCrewHealth;
      then communications.RelayVoiceAndTelemetry;
    }

    action def ConductMissionTask {
      in item command : MissionCommand;
      in item observation : VisualObservation;
      out item result : TaskResult;

      first communications.ReceiveMissionCommand;
      then crew.ObserveWorksite;
      then crew.ExecuteMissionTask;
      then tools.ApplyToolToWorksite;
    }

    action def PrimaryFunction {
      in item assignedCommand : MissionCommand;
      out item taskResult : TaskResult;
      out item statusTelemetry : TelemetryPacket;

      first SustainAstronaut;
      then ConductMissionTask;
    }

    state def AstronautOperationalStates {
      entry action initialize {
        currentMode = AstronautMode::preparing;
      }

      state PreEgress;
      state TranslateToWorksite;
      state PerformAssignedTask;
      state MonitorAndSustain;
      state ContingencyResponse;
      state ReturnToAirlock;
      state Recovered;

      transition initial then PreEgress;

      transition PreEgress_to_TranslateToWorksite
        first PreEgress
        then TranslateToWorksite
        accept MissionCommand
        if lifeSupport.batteryEnergyRemaining > 900.0;

      transition TranslateToWorksite_to_PerformAssignedTask
        first TranslateToWorksite
        then PerformAssignedTask
        accept VisualObservation;

      transition PerformAssignedTask_to_MonitorAndSustain
        first PerformAssignedTask
        then MonitorAndSustain;

      transition MonitorAndSustain_to_PerformAssignedTask
        first MonitorAndSustain
        then PerformAssignedTask
        if crew.health == HealthState::nominal and suit.integrity == SuitIntegrityState::sealed;

      transition Any_to_ContingencyResponse
        first PreEgress
        then ContingencyResponse
        if crew.health == HealthState::injured or suit.integrity == SuitIntegrityState::leaking or lifeSupport.batteryEnergyRemaining < 240.0;

      transition ContingencyResponse_to_ReturnToAirlock
        first ContingencyResponse
        then ReturnToAirlock;

      transition PerformAssignedTask_to_ReturnToAirlock
        first PerformAssignedTask
        then ReturnToAirlock
        if lifeSupport.batteryEnergyRemaining < 360.0;

      transition ReturnToAirlock_to_Recovered
        first ReturnToAirlock
        then Recovered;
    }
  }

  requirement def PrimaryAstronautFunctionRequirement {
    doc
    /* The astronaut system shall enable a human crew member to survive, communicate, move, observe, and manipulate mission equipment while performing assigned mission tasks in an external hazardous environment. */

    subject astronaut : AstronautSystem;

    require constraint {
      astronaut.lifeSupport.oxygenStoragePressure >= 3500.0
    }

    require constraint {
      astronaut.suit.internalPressure >= 26.0 and astronaut.suit.internalPressure <= 31.0
    }

    require constraint {
      astronaut.lifeSupport.carbonDioxideCapacityRemaining >= 10.0
    }

    require constraint {
      astronaut.lifeSupport.batteryEnergyRemaining >= 240.0
    }

    require constraint {
      astronaut.crew.health != HealthState::incapacitated
    }
  }

  requirement def CommunicationRequirement {
    subject astronaut : AstronautSystem;

    require constraint {
      astronaut.communications.linkMargin >= 30.0
    }
  }

  requirement def MobilityAndTaskRequirement {
    subject astronaut : AstronautSystem;

    require constraint {
      astronaut.tools.availablePower >= 25.0
    }

    require constraint {
      astronaut.plannedEvaDuration <= 480.0
    }
  }

  part astronautBasedMissionSystem : AstronautSystem {
    attribute totalMass = 145.0;
    attribute plannedEvaDuration = 390.0;
    attribute currentMode = AstronautMode::preparing;
  }

  satisfy PrimaryAstronautFunctionRequirement by astronautBasedMissionSystem;
  satisfy CommunicationRequirement by astronautBasedMissionSystem;
  satisfy MobilityAndTaskRequirement by astronautBasedMissionSystem;
}