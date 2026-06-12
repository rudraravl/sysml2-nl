package DaintreeNetworkSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Percent :> Real;
  attribute def Address64 :> String;
  attribute def NetworkId :> String;
  attribute def SecurityKey :> String;

  enum def DeviceHealth {
    nominal;
    degraded;
    unreachable;
    joining;
    commissioned;
    retired;
  }

  enum def OccupancyState {
    occupied;
    vacant;
    unknown;
  }

  enum def LightingCommandKind {
    on;
    off;
    dim;
    identify;
    emergencyOn;
  }

  enum def SensorReportKind {
    occupancy;
    illuminance;
    temperature;
    energy;
    fault;
  }

  item def WirelessFrame {
    attribute sourceAddress : Address64;
    attribute destinationAddress : Address64;
    attribute networkId : NetworkId;
    attribute payloadSize : Integer;
    attribute encrypted : Boolean;
    attribute linkQuality : Percent;
  }

  item def LightingCommand {
    attribute command : LightingCommandKind;
    attribute targetLevel : Percent;
    attribute transitionTime_s : Real;
  }

  item def SensorReport {
    attribute reportKind : SensorReportKind;
    attribute occupancy : OccupancyState;
    attribute illuminance_lx : Real;
    attribute temperature_degC : Real;
    attribute activePower_W : Real;
  }

  item def BuildingControlEvent {
    attribute eventTime_s : Real;
    attribute priority : Integer;
    attribute acknowledged : Boolean;
  }

  port def WirelessMeshPort {
    in item inboundFrame : WirelessFrame;
    out item outboundFrame : WirelessFrame;
  }

  port def CommandPort {
    in item commandIn : LightingCommand;
    out item commandAck : BuildingControlEvent;
  }

  port def SensorPort {
    out item reportOut : SensorReport;
  }

  port def EthernetPort {
    in item inboundPacket : WirelessFrame;
    out item outboundPacket : WirelessFrame;
  }

  port def PowerPort {
    in attribute voltage_V : Real;
    in attribute current_A : Real;
    out attribute activePower_W : Real;
  }

  part def DaintreeWirelessNode {
    attribute nodeAddress : Address64;
    attribute health : DeviceHealth;
    attribute linkQuality : Percent;
    attribute batteryLevel : Percent;
    attribute commissioned : Boolean;
    attribute supportsRouting : Boolean;

    port mesh : WirelessMeshPort;
    port power : PowerPort;
  }

  part def WirelessGateway :> DaintreeWirelessNode {
    attribute gatewayName : String;
    attribute ipAddress : String;
    attribute managedNetworkId : NetworkId;
    attribute maxSupportedNodes : Integer = 500;
    attribute uplinkLatency_ms : Real;

    port ethernet : EthernetPort;
  }

  part def AreaController :> DaintreeWirelessNode {
    attribute zoneId : String;
    attribute fallbackLightLevel : Percent = 60.0;
    attribute scheduleEnabled : Boolean;
    attribute demandResponseActive : Boolean;

    port command : CommandPort;
  }

  part def OccupancySensor :> DaintreeWirelessNode {
    attribute detectionRange_m : Real = 9.0;
    attribute vacancyTimeout_s : Real = 900.0;
    attribute currentOccupancy : OccupancyState;

    port sensing : SensorPort;
  }

  part def DaylightSensor :> DaintreeWirelessNode {
    attribute measuredIlluminance_lx : Real;
    attribute targetIlluminance_lx : Real = 500.0;
    attribute calibrationOffset_lx : Real;

    port sensing : SensorPort;
  }

  part def SmartLuminaire :> DaintreeWirelessNode {
    attribute luminaireId : String;
    attribute dimLevel : Percent;
    attribute ratedPower_W : Real = 42.0;
    attribute measuredPower_W : Real;
    attribute emergencyMode : Boolean;

    port command : CommandPort;
    port sensing : SensorPort;
  }

  part def EnergyMeter :> DaintreeWirelessNode {
    attribute measuredVoltage_V : Real;
    attribute measuredCurrent_A : Real;
    attribute measuredPower_W : Real;
    attribute accumulatedEnergy_kWh : Real;

    port sensing : SensorPort;
  }

  part def NetworkManager {
    attribute networkId : NetworkId;
    attribute securityKey : SecurityKey;
    attribute onlineNodeCount : Integer;
    attribute averageLinkQuality : Percent;
    attribute primaryFunction : String =
      "Provide centralized monitoring, secure wireless mesh communication, and automated building lighting control for connected luminaires, sensors, meters, and area controllers.";

    port gatewayLink : EthernetPort;
  }

  part def DaintreeBuildingNetwork {
    attribute siteName : String = "Commercial Building Daintree Network";
    attribute networkId : NetworkId = "DAINTREE-BLDG-001";
    attribute nominalFrequency_MHz : Real = 2400.0;
    attribute encryptedCommunication : Boolean = true;
    attribute primaryFunction : String =
      "Coordinate a Daintree-style wireless mesh network that senses occupancy, daylight, and energy use, then issues lighting commands to reduce energy consumption while maintaining occupant comfort.";

    part manager : NetworkManager {
      attribute networkId = "DAINTREE-BLDG-001";
      attribute onlineNodeCount = 8;
    }

    part gateway : WirelessGateway {
      attribute gatewayName = "Main Daintree Gateway";
      attribute nodeAddress = "00-13-A2-00-00-01-00-01";
      attribute managedNetworkId = "DAINTREE-BLDG-001";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 98.0;
      attribute commissioned = true;
      attribute supportsRouting = true;
      attribute ipAddress = "10.20.30.15";
    }

    part floorController : AreaController {
      attribute nodeAddress = "00-13-A2-00-00-01-10-01";
      attribute zoneId = "Floor-1";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 94.0;
      attribute commissioned = true;
      attribute supportsRouting = true;
      attribute scheduleEnabled = true;
    }

    part openOfficeOccupancy : OccupancySensor {
      attribute nodeAddress = "00-13-A2-00-00-01-20-01";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 91.0;
      attribute commissioned = true;
      attribute supportsRouting = false;
      attribute currentOccupancy = OccupancyState::unknown;
    }

    part conferenceOccupancy : OccupancySensor {
      attribute nodeAddress = "00-13-A2-00-00-01-20-02";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 89.0;
      attribute commissioned = true;
      attribute supportsRouting = false;
      attribute currentOccupancy = OccupancyState::unknown;
    }

    part daylightSensor : DaylightSensor {
      attribute nodeAddress = "00-13-A2-00-00-01-30-01";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 92.0;
      attribute commissioned = true;
      attribute supportsRouting = false;
      attribute measuredIlluminance_lx = 420.0;
    }

    part luminaireA : SmartLuminaire {
      attribute nodeAddress = "00-13-A2-00-00-01-40-01";
      attribute luminaireId = "OpenOffice-L1";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 96.0;
      attribute commissioned = true;
      attribute supportsRouting = true;
      attribute dimLevel = 70.0;
    }

    part luminaireB : SmartLuminaire {
      attribute nodeAddress = "00-13-A2-00-00-01-40-02";
      attribute luminaireId = "OpenOffice-L2";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 95.0;
      attribute commissioned = true;
      attribute supportsRouting = true;
      attribute dimLevel = 70.0;
    }

    part meter : EnergyMeter {
      attribute nodeAddress = "00-13-A2-00-00-01-50-01";
      attribute health = DeviceHealth::nominal;
      attribute linkQuality = 93.0;
      attribute commissioned = true;
      attribute supportsRouting = true;
      attribute accumulatedEnergy_kWh = 1842.5;
    }

    connect manager.gatewayLink to gateway.ethernet;
    connect gateway.mesh to floorController.mesh;
    connect floorController.mesh to openOfficeOccupancy.mesh;
    connect floorController.mesh to conferenceOccupancy.mesh;
    connect floorController.mesh to daylightSensor.mesh;
    connect floorController.mesh to luminaireA.mesh;
    connect floorController.mesh to luminaireB.mesh;
    connect luminaireA.mesh to meter.mesh;
    connect luminaireB.mesh to meter.mesh;
    connect floorController.command to luminaireA.command;
    connect floorController.command to luminaireB.command;
  }

  action def CommissionNode {
    in item joiningFrame : WirelessFrame;
    in attribute authorizedAddress : Address64;
    out attribute commissioned : Boolean;
    out attribute assignedNetworkId : NetworkId;

    first start;
    then validateAddress;
    then assignSecurity;
    then bindToGateway;
    then complete;

    action validateAddress;
    action assignSecurity;
    action bindToGateway;
    action complete;
  }

  action def ProcessSensorReports {
    in item occupancyReport : SensorReport;
    in item daylightReport : SensorReport;
    in item energyReport : SensorReport;
    out item lightingCommand : LightingCommand;

    first receiveReports;
    then evaluateOccupancy;
    then evaluateDaylightContribution;
    then calculateTargetDimLevel;
    then publishLightingCommand;

    action receiveReports;
    action evaluateOccupancy;
    action evaluateDaylightContribution;
    action calculateTargetDimLevel;
    action publishLightingCommand;
  }

  action def RouteMeshMessage {
    in item inputFrame : WirelessFrame;
    out item routedFrame : WirelessFrame;
    out attribute routeAccepted : Boolean;

    first receiveFrame;
    then verifyNetworkId;
    then verifyEncryption;
    then selectNextHop;
    then transmitFrame;

    action receiveFrame;
    action verifyNetworkId;
    action verifyEncryption;
    action selectNextHop;
    action transmitFrame;
  }

  state def NodeLifecycle {
    entry; then Uncommissioned;

    state Uncommissioned;
    state Joining;
    state Commissioned;
    state Operational;
    state Degraded;
    state Offline;
    state Retired;

    transition first Uncommissioned to Joining;
    transition Joining to Commissioned
      accept BuildingControlEvent
      if acknowledged == true;
    transition Commissioned to Operational;
    transition Operational to Degraded
      if linkQuality < 50.0;
    transition Degraded to Operational
      if linkQuality >= 70.0;
    transition Operational to Offline
      if health == DeviceHealth::unreachable;
    transition Offline to Operational
      if health == DeviceHealth::nominal;
    transition Operational to Retired
      if commissioned == false;
  }

  state def LightingControlStateMachine {
    entry; then Standby;

    state Standby;
    state OccupiedNormal;
    state DaylightHarvesting;
    state VacancyDimmed;
    state EmergencyOverride;
    state FaultHold;

    transition Standby to OccupiedNormal
      if currentOccupancy == OccupancyState::occupied;

    transition OccupiedNormal to DaylightHarvesting
      if measuredIlluminance_lx >= targetIlluminance_lx;

    transition DaylightHarvesting to OccupiedNormal
      if measuredIlluminance_lx < targetIlluminance_lx;

    transition OccupiedNormal to VacancyDimmed
      if currentOccupancy == OccupancyState::vacant;

    transition VacancyDimmed to OccupiedNormal
      if currentOccupancy == OccupancyState::occupied;

    transition OccupiedNormal to EmergencyOverride
      if emergencyMode == true;

    transition DaylightHarvesting to EmergencyOverride
      if emergencyMode == true;

    transition VacancyDimmed to EmergencyOverride
      if emergencyMode == true;

    transition EmergencyOverride to OccupiedNormal
      if emergencyMode == false;

    transition OccupiedNormal to FaultHold
      if health == DeviceHealth::degraded;

    transition FaultHold to OccupiedNormal
      if health == DeviceHealth::nominal;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The Daintree building network shall provide high-level centralized wireless monitoring and control of lighting, sensors, meters, and area controllers through a secure mesh network. */
  }

  requirement def SecureMeshCommunicationRequirement {
    doc
      /* All operational wireless frames shall be associated with the configured network identifier and shall be encrypted before transmission across the building mesh. */

    require constraint {
      encryptedCommunication == true
    }
  }

  requirement def OccupancyBasedLightingRequirement {
    doc
      /* The system shall command luminaires to reduce output after a vacancy timeout when the associated occupancy sensors report vacant space. */

    require constraint {
      openOfficeOccupancy.vacancyTimeout_s <= 900.0
    }
  }

  requirement def DaylightHarvestingRequirement {
    doc
      /* The system shall reduce commanded luminaire output when measured daylight is sufficient to maintain the configured target illuminance. */

    require constraint {
      daylightSensor.targetIlluminance_lx >= 300.0 and daylightSensor.targetIlluminance_lx <= 750.0
    }
  }

  requirement def MeshCapacityRequirement {
    doc
      /* The gateway shall support at least five hundred commissioned wireless nodes for scalable building deployment. */

    require constraint {
      gateway.maxSupportedNodes >= 500
    }
  }

  requirement def LinkQualityRequirement {
    doc
      /* Operational routing nodes shall maintain link quality of at least seventy percent during normal operation. */

    require constraint {
      gateway.linkQuality >= 70.0 and
      floorController.linkQuality >= 70.0 and
      luminaireA.linkQuality >= 70.0 and
      luminaireB.linkQuality >= 70.0 and
      meter.linkQuality >= 70.0
    }
  }

  satisfy PrimaryFunctionRequirement by DaintreeBuildingNetwork;
  satisfy SecureMeshCommunicationRequirement by DaintreeBuildingNetwork;
  satisfy OccupancyBasedLightingRequirement by DaintreeBuildingNetwork;
  satisfy DaylightHarvestingRequirement by DaintreeBuildingNetwork;
  satisfy MeshCapacityRequirement by DaintreeBuildingNetwork;
  satisfy LinkQualityRequirement by DaintreeBuildingNetwork;
}