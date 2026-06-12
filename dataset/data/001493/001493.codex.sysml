package MatterBasedResidentialClimateSystem {
    import ScalarValues::*;
    import SI::*;

    attribute def Temperature_C :> Real {
        doc /* Temperature measured in degrees Celsius. */
    }

    attribute def RelativeHumidity_pct :> Real {
        doc /* Relative humidity measured in percent. */
    }

    attribute def Power_W :> Real {
        doc /* Electrical power measured in watts. */
    }

    attribute def Energy_kWh :> Real {
        doc /* Electrical energy measured in kilowatt-hours. */
    }

    attribute def Time_s :> Real {
        doc /* Time measured in seconds. */
    }

    attribute def AirFlow_m3_per_h :> Real {
        doc /* Air flow rate measured in cubic meters per hour. */
    }

    item def MatterMessage {
        attribute fabricId : String;
        attribute nodeId : String;
        attribute endpointId : Integer;
        attribute clusterId : String;
        attribute commandId : String;
        attribute payload : String;
        attribute timestamp : Time_s;
    }

    item def ClimateSetpoint {
        attribute heatingTarget : Temperature_C;
        attribute coolingTarget : Temperature_C;
        attribute humidityTarget : RelativeHumidity_pct;
    }

    item def ClimateMeasurement {
        attribute roomTemperature : Temperature_C;
        attribute roomHumidity : RelativeHumidity_pct;
        attribute outdoorTemperature : Temperature_C;
        attribute timestamp : Time_s;
    }

    item def ElectricalPower {
        attribute instantaneousPower : Power_W;
        attribute accumulatedEnergy : Energy_kWh;
    }

    port def MatterPort {
        in command : MatterMessage;
        out event : MatterMessage;
        out telemetry : MatterMessage;
    }

    port def SensorPort {
        out measurement : ClimateMeasurement;
    }

    port def SetpointPort {
        in setpoint : ClimateSetpoint;
    }

    port def PowerPort {
        in supplyPower : ElectricalPower;
        out consumedPower : ElectricalPower;
    }

    port def AirPort {
        in returnAirTemperature : Temperature_C;
        out supplyAirTemperature : Temperature_C;
        out supplyAirFlow : AirFlow_m3_per_h;
    }

    port def ActuatorCommandPort {
        out compressorEnable : Boolean;
        out heaterEnable : Boolean;
        out fanSpeedPercent : Real;
        out humidifierEnable : Boolean;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use Matter connectivity to monitor residential climate conditions and automatically regulate heating, cooling, airflow, and humidity to maintain user-defined comfort setpoints. */
    }

    requirement def MatterInteroperabilityRequirement {
        doc /* The system shall expose climate control status, measurements, and commands through a Matter-compliant node on a commissioned Matter fabric. */
    }

    requirement def ComfortControlRequirement {
        doc /* The system shall maintain room temperature within 1.0 degC of the active heating or cooling setpoint during normal operation. */
        attribute allowableTemperatureError : Temperature_C = 1.0;
    }

    requirement def EnergyReportingRequirement {
        doc /* The system shall report instantaneous power and accumulated energy consumption through Matter telemetry. */
    }

    requirement def SafeShutdownRequirement {
        doc /* The system shall disable heating, cooling, humidification, and forced airflow when a fault state requiring shutdown is detected. */
    }

    action def CommissionMatterNode {
        in commissioningCommand : MatterMessage;
        out commissioned : Boolean;
        out fabricIdentifier : String;
    }

    action def ReadClimateSensors {
        out measurement : ClimateMeasurement;
    }

    action def ComputeClimateDemand {
        in measurement : ClimateMeasurement;
        in setpoint : ClimateSetpoint;
        out heatingDemand : Boolean;
        out coolingDemand : Boolean;
        out humidityDemand : Boolean;
        out fanDemandPercent : Real;
    }

    action def DriveClimateActuators {
        in heatingDemand : Boolean;
        in coolingDemand : Boolean;
        in humidityDemand : Boolean;
        in fanDemandPercent : Real;
        out actuatorPower : ElectricalPower;
    }

    action def PublishMatterTelemetry {
        in measurement : ClimateMeasurement;
        in power : ElectricalPower;
        out telemetryMessage : MatterMessage;
    }

    state def ClimateControllerStateMachine {
        state uncommissioned;
        state commissioning;
        state standby;
        state monitoring;
        state heating;
        state cooling;
        state humidifying;
        state faulted;
        state safeShutdown;

        transition first uncommissioned;
        transition uncommissioned_to_commissioning
            first uncommissioned then commissioning;

        transition commissioning_to_standby
            first commissioning then standby;

        transition standby_to_monitoring
            first standby then monitoring;

        transition monitoring_to_heating
            first monitoring then heating;

        transition monitoring_to_cooling
            first monitoring then cooling;

        transition monitoring_to_humidifying
            first monitoring then humidifying;

        transition active_to_monitoring
            first heating then monitoring;

        transition cooling_to_monitoring
            first cooling then monitoring;

        transition humidifying_to_monitoring
            first humidifying then monitoring;

        transition any_fault_to_faulted
            first monitoring then faulted;

        transition faulted_to_safeShutdown
            first faulted then safeShutdown;
    }

    part def MatterClimateController {
        port matter : MatterPort;
        port sensors : SensorPort;
        port setpoints : SetpointPort;
        port actuatorCommands : ActuatorCommandPort;
        port power : PowerPort;

        attribute activeSetpoint : ClimateSetpoint;
        attribute latestMeasurement : ClimateMeasurement;
        attribute commissioned : Boolean = false;
        attribute controlLoopPeriod : Time_s = 5.0;

        perform commission : CommissionMatterNode;
        perform readSensors : ReadClimateSensors;
        perform computeDemand : ComputeClimateDemand;
        perform driveOutputs : DriveClimateActuators;
        perform publishTelemetry : PublishMatterTelemetry;

        exhibit stateMachine : ClimateControllerStateMachine;

        satisfy PrimaryFunctionRequirement;
        satisfy MatterInteroperabilityRequirement;
        satisfy ComfortControlRequirement;
        satisfy EnergyReportingRequirement;
        satisfy SafeShutdownRequirement;
    }

    part def MatterFabricInterface {
        port fabricPort : MatterPort;

        attribute vendorId : String = "ResidentialClimateVendor";
        attribute productId : String = "MatterClimateHub";
        attribute supportsThermostatCluster : Boolean = true;
        attribute supportsTemperatureMeasurementCluster : Boolean = true;
        attribute supportsElectricalEnergyMeasurementCluster : Boolean = true;
    }

    part def TemperatureHumiditySensor {
        port sensorOut : SensorPort;
        port power : PowerPort;

        attribute temperatureAccuracy : Temperature_C = 0.2;
        attribute humidityAccuracy : RelativeHumidity_pct = 2.0;
        attribute samplePeriod : Time_s = 2.0;
    }

    part def OutdoorTemperatureSensor {
        port sensorOut : SensorPort;
        port power : PowerPort;

        attribute temperatureAccuracy : Temperature_C = 0.5;
        attribute samplePeriod : Time_s = 10.0;
    }

    part def HeatPumpUnit {
        port air : AirPort;
        port commands : ActuatorCommandPort;
        port power : PowerPort;

        attribute ratedHeatingPower : Power_W = 3500.0;
        attribute ratedCoolingPower : Power_W = 3200.0;
        attribute minimumSupplyAirFlow : AirFlow_m3_per_h = 250.0;
        attribute maximumSupplyAirFlow : AirFlow_m3_per_h = 850.0;
    }

    part def HumidifierUnit {
        port commands : ActuatorCommandPort;
        port power : PowerPort;

        attribute ratedPower : Power_W = 450.0;
        attribute maximumHumidityContribution : RelativeHumidity_pct = 8.0;
    }

    part def PowerMonitor {
        port monitoredPower : PowerPort;
        port matter : MatterPort;

        attribute reportingInterval : Time_s = 60.0;
        attribute accumulatedEnergy : Energy_kWh;
    }

    part def UserMatterClient {
        port matter : MatterPort;

        attribute preferredHeatingTarget : Temperature_C = 20.0;
        attribute preferredCoolingTarget : Temperature_C = 24.0;
        attribute preferredHumidityTarget : RelativeHumidity_pct = 45.0;
    }

    part def MatterBasedResidentialClimateSystem {
        doc /* A Matter-based residential climate system whose primary high-level function is to provide interoperable smart-home climate regulation by sensing indoor conditions, accepting user setpoints over Matter, commanding HVAC equipment, and reporting status and energy use. */

        part controller : MatterClimateController;
        part matterInterface : MatterFabricInterface;
        part indoorSensor : TemperatureHumiditySensor;
        part outdoorSensor : OutdoorTemperatureSensor;
        part heatPump : HeatPumpUnit;
        part humidifier : HumidifierUnit;
        part powerMonitor : PowerMonitor;
        part userClient : UserMatterClient;

        port homeMatterPort : MatterPort;
        port conditionedAir : AirPort;
        port mainsPower : PowerPort;

        connect homeMatterPort to matterInterface.fabricPort;
        connect matterInterface.fabricPort to controller.matter;
        connect userClient.matter to homeMatterPort;

        connect indoorSensor.sensorOut to controller.sensors;
        connect outdoorSensor.sensorOut to controller.sensors;

        connect controller.actuatorCommands to heatPump.commands;
        connect controller.actuatorCommands to humidifier.commands;

        connect heatPump.air to conditionedAir;

        connect mainsPower to controller.power;
        connect mainsPower to indoorSensor.power;
        connect mainsPower to outdoorSensor.power;
        connect mainsPower to heatPump.power;
        connect mainsPower to humidifier.power;
        connect mainsPower to powerMonitor.monitoredPower;

        connect powerMonitor.matter to homeMatterPort;

        attribute nominalControlTemperatureBand : Temperature_C = 1.0;
        attribute nominalHumidityBand : RelativeHumidity_pct = 5.0;
        attribute maximumSystemPower : Power_W = 5200.0;

        satisfy PrimaryFunctionRequirement;
        satisfy MatterInteroperabilityRequirement;
        satisfy ComfortControlRequirement;
        satisfy EnergyReportingRequirement;
        satisfy SafeShutdownRequirement;
    }
}