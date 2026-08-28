package WirelessEnvironmentalTemperatureMonitoringSystem {
    private import ScalarValues::*;
    private import SI::K;
    private import SI::V;
    private import SI::Hz;
    private import SI::s;

    value def TemperatureValue :> Real {
        unit K;
    }
    value def BatteryLevelValue :> Real;
    value def VoltageValue :> Real {
        unit V;
    }
    value def FrequencyValue :> Real {
        unit Hz;
    }
    value def TimeDurationValue :> Real {
        unit s;
    }

    item def SensorDataPacket {
        attribute sensorID : String;
        attribute temperature : TemperatureValue;
        attribute batteryLevel : BatteryLevelValue;
        attribute sequenceNumber : Integer;
    }

    item def AggregatedTemperatureReport {
        attribute averageTemperature : TemperatureValue;
        attribute minimumTemperature : TemperatureValue;
        attribute maximumTemperature : TemperatureValue;
        attribute sampleCount : Integer;
        attribute aggregationPeriod : TimeDurationValue;
    }

    port def TempOutPort {
        out attribute temperature : TemperatureValue;
    }

    port def TempInPort {
        in attribute temperature : TemperatureValue;
    }

    port def PacketTxPort {
        out item packet : SensorDataPacket;
    }

    port def PacketRxPort {
        in item packet : SensorDataPacket;
    }

    port def PowerOutPort {
        out attribute voltage : VoltageValue;
    }

    port def PowerInPort {
        in attribute voltage : VoltageValue;
    }

    action def MeasureTemperature {
        out temperature : TemperatureValue;
    }

    action def CheckBatteryLevel {
        out batteryLevel : BatteryLevelValue;
    }

    action def PackageSensorData {
        in temperature : TemperatureValue;
        in batteryLevel : BatteryLevelValue;
        in sensorID : String;
        in sequenceNumber : Integer;
        out packet : SensorDataPacket;
    }

    action def TransmitSensorPacket {
        in packet : SensorDataPacket;
    }

    action def ExtractTemperatureSamples {
        in packets : SensorDataPacket[*];
        out temperatures : TemperatureValue[*];
    }

    action def ComputeSummaryStatistics {
        in temperatures : TemperatureValue[*];
        out averageTemperature : TemperatureValue;
        out minimumTemperature : TemperatureValue;
        out maximumTemperature : TemperatureValue;
        out sampleCount : Integer;
    }

    action def GenerateReport {
        in averageTemperature : TemperatureValue;
        in minimumTemperature : TemperatureValue;
        in maximumTemperature : TemperatureValue;
        in sampleCount : Integer;
        in aggregationPeriod : TimeDurationValue;
        out report : AggregatedTemperatureReport;
    }

    state def SensorNodeStateMachine {
        state sleeping;
        state sensing;
        state processing;
        state transmitting;
        transition sleeping_to_sensing first sleeping then sensing;
        transition sensing_to_processing first sensing then processing;
        transition processing_to_transmitting first processing then transmitting;
        transition transmitting_to_sleeping first transmitting then sleeping;
    }

    state def CoordinatorStateMachine {
        state idle;
        state receiving;
        state aggregating;
        transition idle_to_receiving first idle then receiving;
        transition receiving_to_aggregating first receiving then aggregating;
        transition aggregating_to_idle first aggregating then idle;
    }

    part def Battery {
        attribute nominalVoltage : VoltageValue;
        port powerOut : PowerOutPort;
    }

    part def CoinCellBattery :> Battery {
        attribute :>> nominalVoltage = 3.0 [V];
        attribute remainingLevel : BatteryLevelValue = 100.0;
    }

    part def RechargeableBattery :> Battery {
        attribute :>> nominalVoltage = 3.7 [V];
        attribute remainingLevel : BatteryLevelValue = 100.0;
        attribute chargeCycleCount : Integer = 0;
    }

    part def Thermistor {
        attribute calibrationOffset : TemperatureValue = 0.0 [K];
        port sense : TempOutPort;
        port power : PowerInPort;
    }

    part def Microcontroller {
        attribute firmwareVersion : String = "1.0.0";
        port tempIn : TempInPort;
        port packetOut : PacketTxPort;
        port power : PowerInPort;
    }

    part def RadioTransceiver {
        attribute centerFrequency : FrequencyValue = 2400000000.0 [Hz];
        port packetIn : PacketRxPort;
        port radio : PacketTxPort;
        port power : PowerInPort;
    }

    part def RadioReceiver {
        port antenna : PacketRxPort;
        port dataOut : PacketTxPort;
        port power : PowerInPort;
    }

    part def ProcessingUnit {
        port packetIn : PacketRxPort;
        port power : PowerInPort;
    }

    part def SensorNode {
        attribute sensorID : String;
        attribute location : String;
        attribute sequenceCounter : Integer = 0;

        part thermistor : Thermistor;
        part microcontroller : Microcontroller;
        part transceiver : RadioTransceiver;
        part battery : CoinCellBattery;

        state powerCycle : SensorNodeStateMachine;

        perform measureTemperature : MeasureTemperature;
        perform checkBatteryLevel : CheckBatteryLevel;
        perform packageData : PackageSensorData;
        perform transmitPacket : TransmitSensorPacket;

        connect thermistor.sense to microcontroller.tempIn;
        connect microcontroller.packetOut to transceiver.packetIn;
        connect battery.powerOut to thermistor.power;
        connect battery.powerOut to microcontroller.power;
        connect battery.powerOut to transceiver.power;
    }

    part def CoordinatorNode {
        attribute coordinatorID : String;
        attribute aggregationPeriod : TimeDurationValue = 300.0 [s];

        part receiver : RadioReceiver;
        part processingUnit : ProcessingUnit;
        part battery : RechargeableBattery;

        state coordinatorState : CoordinatorStateMachine;

        perform extractSamples : ExtractTemperatureSamples;
        perform computeStatistics : ComputeSummaryStatistics;
        perform generateReport : GenerateReport;

        connect receiver.dataOut to processingUnit.packetIn;
        connect battery.powerOut to receiver.power;
        connect battery.powerOut to processingUnit.power;
    }

    requirement def LowPowerOperation {
        doc /* Sensor nodes shall cycle through sleeping, sensing, processing, and transmitting states to conserve battery energy. */
    }

    requirement def TemperatureMeasurementAccuracy {
        doc /* Each sensor node shall provide local temperature measurements with an accuracy better than or equal to 0.5 Kelvin. */
        attribute accuracy : TemperatureValue = 0.5 [K];
    }

    requirement def WirelessPacketContent {
        doc /* Each sensor data packet shall include the unique sensor ID, measured temperature, and battery level. */
    }

    requirement def DataAggregationRequirement {
        doc /* The coordinator shall aggregate received temperature samples over a configurable period and compute average, minimum, and maximum temperatures. */
        attribute aggregationPeriod : TimeDurationValue = 300.0 [s];
    }

    requirement def SensorBatteryLife {
        doc /* Sensor nodes shall operate for at least one year on a coin cell battery under normal cyclic operation. */
        attribute minimumBatteryLife : TimeDurationValue = 31536000.0 [s];
    }

    part def WirelessMonitoringSystem {
        part coordinator : CoordinatorNode;
        part sensorNodes : SensorNode[1..*];

        connect sensorNodes.transceiver.radio to coordinator.receiver.antenna;
    }

    part monitoringSystem : WirelessMonitoringSystem;
}
