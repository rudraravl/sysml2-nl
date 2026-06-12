package LonWorksBuildingAutomationSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percent : Real {
    unit = "%";
  }

  attribute def TemperatureCelsius : Real {
    unit = "degC";
  }

  attribute def RelativeHumidity : Real {
    unit = "%RH";
  }

  attribute def IlluminanceLux : Real {
    unit = "lx";
  }

  attribute def PowerWatt : Real {
    unit = "W";
  }

  attribute def VoltageVolt : Real {
    unit = "V";
  }

  attribute def TimeSecond : Real {
    unit = "s";
  }

  attribute def AirFlowRate : Real {
    unit = "m^3/s";
  }

  enum def NodeHealth {
    enum operational;
    enum degraded;
    enum failed;
    enum offline;
  }

  enum def OccupancyState {
    enum occupied;
    enum unoccupied;
  }

  enum def NetworkPriority {
    enum normal;
    enum urgent;
    enum alarm;
  }

  item def LonTalkFrame {
    attribute sourceNodeId : String;
    attribute destinationNodeId : String;
    attribute networkVariableId : String;
    attribute priority : NetworkPriority;
    attribute payloadSizeBytes : Integer;
    attribute checksumValid : Boolean;
  }

  item def TemperatureReading {
    attribute value : TemperatureCelsius;
    attribute sensorId : String;
    attribute valid : Boolean;
  }

  item def HumidityReading {
    attribute value : RelativeHumidity;
    attribute sensorId : String;
    attribute valid : Boolean;
  }

  item def OccupancyReading {
    attribute value : OccupancyState;
    attribute sensorId : String;
    attribute valid : Boolean;
  }

  item def LightingCommand {
    attribute dimLevel : Percent;
    attribute zoneId : String;
  }

  item def DamperCommand {
    attribute position : Percent;
    attribute zoneId : String;
  }

  item def FanCommand {
    attribute speed : Percent;
  }

  item def AlarmMessage {
    attribute alarmId : String;
    attribute severity : NetworkPriority;
    attribute description : String;
  }

  port def LonWorksPort {
    in item receivedFrame : LonTalkFrame;
    out item transmittedFrame : LonTalkFrame;
  }

  port def SensorDataPort {
    out item temperature : TemperatureReading;
    out item humidity : HumidityReading;
    out item occupancy : OccupancyReading;
  }

  port def LightingControlPort {
    in item command : LightingCommand;
  }

  port def AirControlPort {
    in item damperCommand : DamperCommand;
    in item fanCommand : FanCommand;
  }

  port def AlarmPort {
    out item alarm : AlarmMessage;
  }

  port def PowerPort {
    in attribute supplyVoltage : VoltageVolt;
    in attribute availablePower : PowerWatt;
  }

  part def LonWorksAutomationSystem {
    attribute primaryFunction : String = "Coordinate distributed building sensors, controllers, and actuators over a LonWorks field network to maintain comfort, lighting efficiency, ventilation, and fault reporting.";
    attribute operatingVoltage : VoltageVolt = 24.0;
    attribute maxNetworkLatency : TimeSecond = 1.0;
    attribute targetTemperature : TemperatureCelsius = 22.0;
    attribute occupiedLightLevel : IlluminanceLux = 500.0;
    attribute unoccupiedLightLevel : IlluminanceLux = 50.0;

    port power : PowerPort;
    port alarmOut : AlarmPort;

    part network : LonWorksFieldNetwork;
    part supervisor : BuildingSupervisor;
    part zoneA : ControlledZone {
      attribute zoneId = "Zone-A";
      attribute nominalAirFlow = 0.75;
    }
    part zoneB : ControlledZone {
      attribute zoneId = "Zone-B";
      attribute nominalAirFlow = 0.60;
    }
    part gateway : EnterpriseGateway;

    connect network.supervisorPort to supervisor.lonPort;
    connect network.zoneAPort to zoneA.controller.lonPort;
    connect network.zoneBPort to zoneB.controller.lonPort;
    connect network.gatewayPort to gateway.lonPort;
    connect supervisor.alarmOut to alarmOut;

    perform action startup : SystemStartup;
    perform action normalControl : DistributedComfortControl;
    perform action faultResponse : FaultIsolationAndAlarm;

    state machine systemState {
      state initializing;
      state commissioning;
      state operational;
      state degraded;
      state safeShutdown;

      initial then initializing;

      transition initializing_to_commissioning
        first initializing
        then commissioning
        accept after 5.0 [s];

      transition commissioning_to_operational
        first commissioning
        then operational
        if network.allConfigured == true and supervisor.health == NodeHealth::operational;

      transition operational_to_degraded
        first operational
        then degraded
        if network.failedNodeCount > 0;

      transition degraded_to_operational
        first degraded
        then operational
        if network.failedNodeCount == 0;

      transition any_to_safeShutdown
        first operational
        then safeShutdown
        if power.supplyVoltage < 18.0;
    }
  }

  part def LonWorksFieldNetwork {
    attribute channelType : String = "TP/FT-10 free topology twisted pair";
    attribute bitRateKbps : Integer = 78;
    attribute maxNodeCount : Integer = 64;
    attribute failedNodeCount : Integer;
    attribute allConfigured : Boolean;

    port supervisorPort : LonWorksPort;
    port zoneAPort : LonWorksPort;
    port zoneBPort : LonWorksPort;
    port gatewayPort : LonWorksPort;

    action routeFrame {
      in item inputFrame : LonTalkFrame;
      out item outputFrame : LonTalkFrame;
      assert inputFrame.checksumValid == true;
    }

    action monitorNodeHeartbeat {
      out attribute failedNodes : Integer;
      assert failedNodes <= maxNodeCount;
    }
  }

  part def BuildingSupervisor {
    attribute nodeId : String = "SUP-001";
    attribute health : NodeHealth;
    attribute globalTemperatureSetpoint : TemperatureCelsius = 22.0;
    attribute occupiedVentilationMinimum : AirFlowRate = 0.35;
    attribute alarmCount : Integer;

    port lonPort : LonWorksPort;
    port alarmOut : AlarmPort;

    action evaluateNetworkHealth {
      in item statusFrame : LonTalkFrame;
      out item alarm : AlarmMessage;
    }

    action publishSchedules {
      out item scheduleFrame : LonTalkFrame;
    }

    state machine supervisorState {
      state booting;
      state bindingNetworkVariables;
      state supervising;
      state alarming;

      initial then booting;

      transition boot_to_binding
        first booting
        then bindingNetworkVariables
        accept after 2.0 [s];

      transition binding_to_supervising
        first bindingNetworkVariables
        then supervising
        if health == NodeHealth::operational;

      transition supervising_to_alarming
        first supervising
        then alarming
        if alarmCount > 0;

      transition alarming_to_supervising
        first alarming
        then supervising
        if alarmCount == 0;
    }
  }

  part def EnterpriseGateway {
    attribute nodeId : String = "GW-001";
    attribute protocolNorthbound : String = "BACnet/IP";
    attribute protocolSouthbound : String = "LonTalk";
    attribute health : NodeHealth;

    port lonPort : LonWorksPort;

    action translateLonNetworkVariables {
      in item lonFrame : LonTalkFrame;
      out item enterpriseMessage : LonTalkFrame;
    }
  }

  part def ControlledZone {
    attribute zoneId : String;
    attribute nominalAirFlow : AirFlowRate;
    attribute occupiedTemperatureSetpoint : TemperatureCelsius = 22.0;
    attribute unoccupiedTemperatureSetpoint : TemperatureCelsius = 18.0;

    part sensor : ZoneSensor;
    part controller : LonWorksZoneController;
    part lighting : DimmableLightingActuator;
    part damper : VavDamperActuator;
    part fanCoil : FanCoilUnit;

    connect sensor.dataOut to controller.sensorIn;
    connect controller.lightOut to lighting.controlIn;
    connect controller.airOut to damper.controlIn;
    connect controller.fanOut to fanCoil.controlIn;
  }

  part def ZoneSensor {
    attribute nodeId : String;
    attribute measuredTemperature : TemperatureCelsius;
    attribute measuredHumidity : RelativeHumidity;
    attribute measuredIlluminance : IlluminanceLux;
    attribute occupancy : OccupancyState;
    attribute health : NodeHealth;

    port dataOut : SensorDataPort;
    port power : PowerPort;

    action sampleEnvironment {
      out item temperature : TemperatureReading;
      out item humidity : HumidityReading;
      out item occupancyReading : OccupancyReading;
    }
  }

  part def LonWorksZoneController {
    attribute nodeId : String;
    attribute health : NodeHealth;
    attribute localTemperatureSetpoint : TemperatureCelsius = 22.0;
    attribute lastFrameAge : TimeSecond;
    attribute comfortDeadband : TemperatureCelsius = 1.0;

    port lonPort : LonWorksPort;
    port sensorIn : SensorDataPort;
    port lightOut : LightingControlPort;
    port airOut : AirControlPort;
    port fanOut : AirControlPort;

    action computeLightingCommand {
      in item occupancy : OccupancyReading;
      out item command : LightingCommand;
    }

    action computeVentilationCommand {
      in item temperature : TemperatureReading;
      in item occupancy : OccupancyReading;
      out item damperCommand : DamperCommand;
      out item fanCommand : FanCommand;
    }

    action publishNetworkVariables {
      out item statusFrame : LonTalkFrame;
    }

    state machine controllerState {
      state offline;
      state joiningNetwork;
      state idle;
      state occupiedControl;
      state unoccupiedSetback;
      state faulted;

      initial then offline;

      transition offline_to_joining
        first offline
        then joiningNetwork
        if health != NodeHealth::failed;

      transition joining_to_idle
        first joiningNetwork
        then idle
        accept after 3.0 [s];

      transition idle_to_occupied
        first idle
        then occupiedControl
        if sensorIn.occupancy.value == OccupancyState::occupied;

      transition occupied_to_unoccupied
        first occupiedControl
        then unoccupiedSetback
        if sensorIn.occupancy.value == OccupancyState::unoccupied;

      transition unoccupied_to_occupied
        first unoccupiedSetback
        then occupiedControl
        if sensorIn.occupancy.value == OccupancyState::occupied;

      transition any_to_faulted
        first occupiedControl
        then faulted
        if lastFrameAge > 30.0;
    }
  }

  part def DimmableLightingActuator {
    attribute nodeId : String;
    attribute dimLevel : Percent;
    attribute ratedPower : PowerWatt = 250.0;
    attribute health : NodeHealth;

    port controlIn : LightingControlPort;
    port power : PowerPort;

    action setDimLevel {
      in item command : LightingCommand;
      assert command.dimLevel >= 0.0 and command.dimLevel <= 100.0;
    }
  }

  part def VavDamperActuator {
    attribute nodeId : String;
    attribute position : Percent;
    attribute minimumOccupiedPosition : Percent = 25.0;
    attribute maximumPosition : Percent = 100.0;
    attribute health : NodeHealth;

    port controlIn : AirControlPort;
    port power : PowerPort;

    action positionDamper {
      in item command : DamperCommand;
      assert command.position >= 0.0 and command.position <= maximumPosition;
    }
  }

  part def FanCoilUnit {
    attribute nodeId : String;
    attribute fanSpeed : Percent;
    attribute coolingCapacity : PowerWatt = 3500.0;
    attribute heatingCapacity : PowerWatt = 3000.0;
    attribute health : NodeHealth;

    port controlIn : AirControlPort;
    port power : PowerPort;

    action setFanSpeed {
      in item command : FanCommand;
      assert command.speed >= 0.0 and command.speed <= 100.0;
    }
  }

  action def SystemStartup {
    out attribute networkReady : Boolean;
    out attribute controllersReady : Boolean;

    first startPowerValidation;
    then loadLonWorksBindings;
    then verifyNodeHeartbeat;
    then enableDistributedControl;

    action startPowerValidation;
    action loadLonWorksBindings;
    action verifyNodeHeartbeat;
    action enableDistributedControl;
  }

  action def DistributedComfortControl {
    in item temperature : TemperatureReading;
    in item occupancy : OccupancyReading;
    out item lightingCommand : LightingCommand;
    out item damperCommand : DamperCommand;
    out item fanCommand : FanCommand;

    first readBoundNetworkVariables;
    then calculateZoneDemand;
    then publishActuatorCommands;

    action readBoundNetworkVariables;
    action calculateZoneDemand;
    action publishActuatorCommands;
  }

  action def FaultIsolationAndAlarm {
    in item failedFrame : LonTalkFrame;
    out item alarm : AlarmMessage;

    first detectCommunicationFault;
    then isolateAffectedNode;
    then publishAlarm;
    then applyFallbackControl;

    action detectCommunicationFault;
    action isolateAffectedNode;
    action publishAlarm;
    action applyFallbackControl;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall use a LonWorks field network to coordinate distributed building automation nodes for sensing, local control, actuation, supervision, and alarm reporting. */
    subject system : LonWorksAutomationSystem;
    require system.network.channelType == "TP/FT-10 free topology twisted pair";
  }

  requirement def LatencyRequirement {
    doc /* Network-variable updates for comfort and lighting control shall be delivered within one second during normal operation. */
    subject system : LonWorksAutomationSystem;
    require system.maxNetworkLatency <= 1.0;
  }

  requirement def DistributedControlRequirement {
    doc /* Each controlled zone shall continue local temperature and lighting control if the enterprise gateway is unavailable. */
    subject controller : LonWorksZoneController;
    require controller.health != NodeHealth::failed;
  }

  requirement def OccupiedComfortRequirement {
    doc /* When a zone is occupied, the local controller shall maintain the measured zone temperature within the configured deadband around the occupied setpoint. */
    subject controller : LonWorksZoneController;
    require controller.comfortDeadband <= 1.0;
  }

  requirement def LightingEnergyRequirement {
    doc /* When a zone is unoccupied, lighting shall be commanded to no more than ten percent unless overridden by a supervisory schedule. */
    subject lighting : DimmableLightingActuator;
    require lighting.dimLevel <= 10.0;
  }

  requirement def FaultAlarmRequirement {
    doc /* A missing node heartbeat for more than thirty seconds shall create an alarm message and place affected local control into a degraded fallback mode. */
    subject controller : LonWorksZoneController;
    require controller.lastFrameAge <= 30.0;
  }

  satisfy PrimaryFunctionRequirement by LonWorksAutomationSystem;
  satisfy LatencyRequirement by LonWorksFieldNetwork;
  satisfy DistributedControlRequirement by LonWorksZoneController;
  satisfy OccupiedComfortRequirement by LonWorksZoneController;
  satisfy LightingEnergyRequirement by DimmableLightingActuator;
  satisfy FaultAlarmRequirement by FaultIsolationAndAlarm;
}