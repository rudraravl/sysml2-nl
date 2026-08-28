package SmartdustSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def TemperatureValue :> Real {
        unit :> TemperatureUnit { }
    }
    value def HumidityValue :> Real {
        doc /* Relative humidity, 0..100 */
        unit :> DimensionlessUnit { }
    }
    value def PressureValue :> Real {
        unit :> PressureUnit { }
    }
    value def LightLevelValue :> Real {
        unit :> IlluminanceUnit { }
    }
    value def BatteryChargeValue :> Real {
        unit :> EnergyUnit { }
    }
    value def EnergyValue :> Real {
        unit :> EnergyUnit { }
    }
    value def PowerValue :> Real {
        unit :> PowerUnit { }
    }
    value def FrequencyValue :> Real {
        unit :> FrequencyUnit { }
    }
    value def DataRateValue :> Real {
        unit :> FrequencyUnit { }
    }

    // ---- Item types ----
    item def EnvironmentalReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute pressure : PressureValue;
        attribute lightLevel : LightLevelValue;
        attribute sourceId : String;
        attribute timestamp : TimeValue;
    }

    item def DataPacket {
        attribute packetId : String;
        attribute sourceId : String;
        attribute hopCount : Integer;
        attribute payload : EnvironmentalReading;
    }

    item def AggregatedReport {
        attribute averageTemperature : TemperatureValue;
        attribute averageHumidity : HumidityValue;
        attribute averagePressure : PressureValue;
        attribute averageLightLevel : LightLevelValue;
        attribute moteCount : Integer;
        attribute alertTriggered : Boolean;
    }

    item def NetworkCommand {
        attribute commandId : String;
        attribute targetId : String;
        attribute commandType : String;
    }

    // ---- Interfaces ----
    interface def RFLink {
        end rfTx : DataPacket;
        end rfRx : DataPacket;
    }

    interface def SolarFlux {
        end lightIn : LightLevelValue;
    }

    interface def VibrationFlux {
        end vibrationIn : FrequencyValue;
    }

    // ---- Port definitions ----
    port def RfPort {
        out rfTx : DataPacket;
        in rfRx : DataPacket;
    }

    port def SolarPort {
        in lightIn : LightLevelValue;
    }

    port def VibrationPort {
        in vibrationIn : FrequencyValue;
    }

    // ---- Requirements ----
    requirement def EnvironmentalMonitoringRequirement {
        doc /* Each mote shall measure temperature, humidity, pressure, and ambient light. */
        subject mote : SmartdustMote;
        attribute measurementRate : FrequencyValue = 1.0 [Hz];
        require { mote.sensorSuite.temperatureSensor.measurementAccuracy <= 0.5 [K]; }
        require { mote.sensorSuite.humiditySensor.measurementAccuracy <= 2.0; }
        require { mote.sensorSuite.pressureSensor.measurementAccuracy <= 0.5 [hPa]; }
        require { mote.sensorSuite.lightSensor.measurementAccuracy <= 10.0 [lx]; }
    }

    requirement def EnergyAutonomyRequirement {
        doc /* Each mote shall harvest solar and vibration energy and store it in a battery. */
        subject mote : SmartdustMote;
        attribute minBatteryCapacity : BatteryChargeValue = 100.0 [J];
        require { mote.harvester.solarEfficiency >= 0.15; }
        require { mote.harvester.vibrationEfficiency >= 0.05; }
        require { mote.battery.capacity >= minBatteryCapacity; }
        require { mote.battery.charge >= 5.0 [J] implies mote.canTransmit; }
    }

    requirement def MeshNetworkingRequirement {
        doc /* Motes shall form a wireless mesh network and relay packets to the Base Station. */
        subject network : SmartdustNetwork;
        attribute maxHops : Integer = 8;
        require { network.motes->size() >= 2; }
        require { forall m in network.motes { m.radio.maxRange >= 30.0 [m]; } }
    }

    requirement def DataAggregationRequirement {
        doc /* The Base Station shall aggregate readings and compute area-wide averages. */
        subject baseStation : BaseStation;
        attribute reportingInterval : TimeValue = 60.0 [s];
        require { baseStation.aggregator.averageTemperature >= 0.0 [K]; }
        require { baseStation.aggregator.moteCount >= 1; }
    }

    // ---- Sensor subcomponents ----
    part def TemperatureSensor {
        attribute measurementAccuracy : TemperatureValue;
        out reading : TemperatureValue;
        action def takeReading() { out value : TemperatureValue; }
    }

    part def HumiditySensor {
        attribute measurementAccuracy : HumidityValue;
        out reading : HumidityValue;
        action def takeReading() { out value : HumidityValue; }
    }

    part def PressureSensor {
        attribute measurementAccuracy : PressureValue;
        out reading : PressureValue;
        action def takeReading() { out value : PressureValue; }
    }

    part def LightSensor {
        attribute measurementAccuracy : LightLevelValue;
        out reading : LightLevelValue;
        action def takeReading() { out value : LightLevelValue; }
    }

    part def SensorSuite {
        part temperatureSensor : TemperatureSensor {
            attribute measurementAccuracy : TemperatureValue = 0.5 [K];
        }
        part humiditySensor : HumiditySensor {
            attribute measurementAccuracy : HumidityValue = 2.0;
        }
        part pressureSensor : PressureSensor {
            attribute measurementAccuracy : PressureValue = 0.5 [hPa];
        }
        part lightSensor : LightSensor {
            attribute measurementAccuracy : LightLevelValue = 10.0 [lx];
        }

        action def sampleAll(out r : EnvironmentalReading) {
            action t : temperatureSensor.takeReading();
            action h : humiditySensor.takeReading();
            action p : pressureSensor.takeReading();
            action l : lightSensor.takeReading();
            then assign r.temperature := t.value;
            then assign r.humidity := h.value;
            then assign r.pressure := p.value;
            then assign r.lightLevel := l.value;
        }
    }

    // ---- Energy subsystem ----
    part def EnergyHarvester {
        attribute solarEfficiency : Real = 0.18;
        attribute vibrationEfficiency : Real = 0.06;
        in lightIn : LightLevelValue;
        in vibrationIn : FrequencyValue;
        out harvestedEnergy : EnergyValue;

        action def harvest() {
            in light : LightLevelValue;
            in vibration : FrequencyValue;
            out energy : EnergyValue;
            assign energy := solarEfficiency * light * 0.001 [J] + vibrationEfficiency * vibration * 0.0001 [J];
        }
    }

    part def Battery {
        attribute capacity : BatteryChargeValue = 200.0 [J];
        attribute charge : BatteryChargeValue = 150.0 [J];
        attribute criticalThreshold : BatteryChargeValue = 5.0 [J];
        in incomingEnergy : EnergyValue;
        out availableCharge : BatteryChargeValue;

        action def charge(in e : EnergyValue) {
            then assign charge := min(capacity, charge + e);
        }

        action def consume(in e : EnergyValue) {
            then assign charge := max(0.0 [J], charge - e);
        }

        action def isCritical() : Boolean {
            return charge <= criticalThreshold;
        }
    }

    // ---- Radio ----
    part def RadioModule {
        attribute maxRange : Real = 50.0 [m];
        attribute dataRate : DataRateValue = 250.0 [kb/s];
        attribute txPower : PowerValue = 0.001 [W];
        port rfPort : RfPort;

        action def transmit(in p : DataPacket) {
            send p via rfPort.rfTx;
        }

        action def receive(out p : DataPacket) {
            receive p via rfPort.rfRx;
        }
    }

    // ---- Microcontroller ----
    part def Microcontroller {
        attribute clockSpeed : FrequencyValue = 1.0 [MHz];
        attribute activePower : PowerValue = 0.0005 [W];
        attribute sleepPower : PowerValue = 0.00001 [W];

        action def processReading(in r : EnvironmentalReading, out p : DataPacket) {
            assign p.payload := r;
            assign p.hopCount := 0;
        }

        action def relayPacket(in pIn : DataPacket, out pOut : DataPacket) {
            assign pOut := pIn;
            assign pOut.hopCount := pIn.hopCount + 1;
        }
    }

    // ---- Mote state machine ----
    state automaton MoteStateMachine {
        entry action { /* initialize */ }

        state sleep {
            entry action { /* enter low-power mode */ }
        }

        state harvest {
            entry action { /* harvest energy */ }
        }

        state wake {
            entry action { /* power up sensors and MCU */ }
        }

        state sense {
            entry action { /* sample sensors */ }
        }

        state process {
            entry action { /* process reading */ }
        }

        state transmit {
            entry action { /* transmit packet */ }
        }

        state criticalSleep {
            entry action { /* battery critically low, skip transmit */ }
        }

        transition init from sleep to harvest;
        transition from harvest to wake when battery.charge > battery.criticalThreshold;
        transition from wake to sense;
        transition from sense to process;
        transition from process to transmit when battery.charge > battery.criticalThreshold;
        transition from process to criticalSleep when battery.charge <= battery.criticalThreshold;
        transition from transmit to sleep;
        transition from criticalSleep to sleep;
    }

    // ---- Smartdust Mote ----
    part def SmartdustMote {
        attribute moteId : String;
        attribute canTransmit : Boolean = true;

        port solarPort : SolarPort;
        port vibrationPort : VibrationPort;
        port rfPort : RfPort;

        part sensorSuite : SensorSuite;
        part harvester : EnergyHarvester;
        part battery : Battery;
        part mcu : Microcontroller;
        part radio : RadioModule;

        // Internal energy flow
        connection harvester.harvestedEnergy to battery.incomingEnergy;
        connection battery.availableCharge to mcu.activePower;

        // Environmental inputs to harvester
        connection solarPort.lightIn to harvester.lightIn;
        connection vibrationPort.vibrationIn to harvester.vibrationIn;

        // Sensor readings to MCU
        flow from sensorSuite.temperatureSensor.reading to mcu.processReading.r.temperature;
        flow from sensorSuite.humiditySensor.reading to mcu.processReading.r.humidity;
        flow from sensorSuite.pressureSensor.reading to mcu.processReading.r.pressure;
        flow from sensorSuite.lightSensor.reading to mcu.processReading.r.lightLevel;

        // MCU to radio
        flow from mcu.processReading.p to radio.transmit.p;

        // Radio port binding
        connection rfPort to radio.rfPort;

        // State machine behavior
        part behavior : MoteStateMachine;

        satisfy EnvironmentalMonitoringRequirement by sensorSuite;
        satisfy EnergyAutonomyRequirement by self;
    }

    // ---- Base Station ----
    part def DataAggregator {
        attribute averageTemperature : TemperatureValue;
        attribute averageHumidity : HumidityValue;
        attribute averagePressure : PressureValue;
        attribute averageLightLevel : LightLevelValue;
        attribute moteCount : Integer = 0;
        attribute alertTriggered : Boolean = false;
        attribute alertThreshold : TemperatureValue = 308.15 [K];

        in incomingPacket : DataPacket;
        out report : AggregatedReport;

        action def aggregate(in p : DataPacket) {
            then assign moteCount := moteCount + 1;
            then assign averageTemperature := averageTemperature + p.payload.temperature / moteCount;
            then assign averageHumidity := averageHumidity + p.payload.humidity / moteCount;
            then assign averagePressure := averagePressure + p.payload.pressure / moteCount;
            then assign averageLightLevel := averageLightLevel + p.payload.lightLevel / moteCount;
            then assign alertTriggered := averageTemperature >= alertThreshold;
        }

        action def generateReport(out r : AggregatedReport) {
            assign r.averageTemperature := averageTemperature;
            assign r.averageHumidity := averageHumidity;
            assign r.averagePressure := averagePressure;
            assign r.averageLightLevel := averageLightLevel;
            assign r.moteCount := moteCount;
            assign r.alertTriggered := alertTriggered;
        }
    }

    part def BaseStation {
        attribute stationId : String = "BS-001";
        port rfPort : RfPort;

        part aggregator : DataAggregator;
        part radio : RadioModule {
            attribute maxRange : Real = 500.0 [m];
        }

        connection rfPort to radio.rfPort;
        flow from radio.receive.p to aggregator.incomingPacket;

        action def listenContinuously() {
            loop {
                action r : radio.receive();
                action a : aggregator.aggregate(r.p);
                action g : aggregator.generateReport();
            }
        }

        satisfy DataAggregationRequirement by self;
    }

    // ---- Smartdust Network ----
    part def SmartdustNetwork {
        attribute networkId : String;
        part baseStation : BaseStation;
        part motes : SmartdustMote[*];

        // Mesh connections: each mote can communicate with base station and other motes
        connection meshLinks : RFLink connect motes.rfPort to motes.rfPort;
        connection uplink : RFLink connect motes.rfPort to baseStation.rfPort;

        satisfy MeshNetworkingRequirement by self;
    }

    // ---- Top-level system ----
    part smartdustSystem : SmartdustNetwork {
        attribute deploymentArea : String = "Monitored Region A";

        part baseStation : BaseStation {
            attribute stationId : String = "BS-001";
        }

        part motes : SmartdustMote[10] {
            attribute moteId : String = "Mote-" + (index + 1);
        }

        // Mesh connectivity
        connection meshLinks : RFLink connect motes.rfPort to motes.rfPort;
        connection uplink : RFLink connect motes.rfPort to baseStation.rfPort;
    }
}
