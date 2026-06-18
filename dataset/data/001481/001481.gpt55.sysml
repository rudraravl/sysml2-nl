package JECE_SmartMicrogridEnergyManagementSystem {

    import ScalarValues::*;
    import SI::*;

    comment PrimaryFunctionComment
        about SmartMicrogridEMS
        /* The primary function of this system is to coordinate sensing, forecasting, optimization, and real-time control of distributed electrical resources in a smart microgrid so that critical and flexible loads are served reliably, efficiently, and safely while maximizing renewable-energy utilization. The model is based on common research themes from the Journal of Electrical and Computer Engineering, including intelligent power electronics, embedded monitoring, communication networks, optimization-based control, and resilient cyber-physical energy systems. */

    attribute def Voltage {
        attribute value: Real;
        attribute unit: String = "V";
    }

    attribute def Current {
        attribute value: Real;
        attribute unit: String = "A";
    }

    attribute def Power {
        attribute value: Real;
        attribute unit: String = "W";
    }

    attribute def Energy {
        attribute value: Real;
        attribute unit: String = "kWh";
    }

    attribute def Frequency {
        attribute value: Real;
        attribute unit: String = "Hz";
    }

    attribute def Temperature {
        attribute value: Real;
        attribute unit: String = "degC";
    }

    attribute def StateOfCharge {
        attribute value: Real;
        attribute unit: String = "%";
    }

    attribute def Irradiance {
        attribute value: Real;
        attribute unit: String = "W/m^2";
    }

    attribute def DataRate {
        attribute value: Real;
        attribute unit: String = "Mb/s";
    }

    attribute def Latency {
        attribute value: Real;
        attribute unit: String = "ms";
    }

    attribute def Reliability {
        attribute value: Real;
        attribute unit: "%";
    }

    attribute def CostRate {
        attribute value: Real;
        attribute unit: "USD/kWh";
    }

    item def ElectricPowerFlow {
        attribute voltage: Voltage;
        attribute current: Current;
        attribute realPower: Power;
        attribute frequency: Frequency;
    }

    item def DcPowerFlow :> ElectricPowerFlow {
        attribute voltage: Voltage = (value = 750.0; unit = "V");
        attribute frequency: Frequency = (value = 0.0; unit = "Hz");
    }

    item def AcPowerFlow :> ElectricPowerFlow {
        attribute voltage: Voltage = (value = 480.0; unit = "V");
        attribute frequency: Frequency = (value = 60.0; unit = "Hz");
    }

    item def SensorSample {
        attribute timestamp_s: Real;
        attribute sourceId: String;
        attribute measuredVoltage: Voltage;
        attribute measuredCurrent: Current;
        attribute measuredPower: Power;
        attribute measuredTemperature: Temperature;
    }

    item def WeatherForecast {
        attribute forecastHorizon_h: Real;
        attribute solarIrradiance: Irradiance;
        attribute ambientTemperature: Temperature;
        attribute probabilityOfCloudCover: Real;
    }

    item def LoadForecast {
        attribute forecastHorizon_h: Real;
        attribute expectedCriticalLoad: Power;
        attribute expectedFlexibleLoad: Power;
        attribute uncertaintyPercent: Real;
    }

    item def DispatchCommand {
        attribute commandId: String;
        attribute targetDeviceId: String;
        attribute activePowerSetpoint: Power;
        attribute reactivePowerSetpoint_var: Real;
        attribute enable: Boolean;
        attribute priority: Integer;
    }

    item def ProtectionTripSignal {
        attribute tripReason: String;
        attribute tripIssued: Boolean;
        attribute detectedFaultCurrent: Current;
        attribute isolationZone: String;
    }

    item def MarketPriceSignal {
        attribute importTariff: CostRate;
        attribute exportTariff: CostRate;
        attribute demandChargeRate: Real;
    }

    port def DcPowerPort {
        inout item dcPower: DcPowerFlow;
    }

    port def AcPowerPort {
        inout item acPower: AcPowerFlow;
    }

    port def SensorDataOutPort {
        out item sample: SensorSample;
    }

    port def SensorDataInPort {
        in item sample: SensorSample;
    }

    port def ForecastOutPort {
        out item weatherForecast: WeatherForecast;
        out item loadForecast: LoadForecast;
    }

    port def ForecastInPort {
        in item weatherForecast: WeatherForecast;
        in item loadForecast: LoadForecast;
    }

    port def ControlCommandOutPort {
        out item command: DispatchCommand;
    }

    port def ControlCommandInPort {
        in item command: DispatchCommand;
    }

    port def ProtectionSignalOutPort {
        out item trip: ProtectionTripSignal;
    }

    port def ProtectionSignalInPort {
        in item trip: ProtectionTripSignal;
    }

    port def MarketSignalInPort {
        in item price: MarketPriceSignal;
    }

    port def CommunicationPort {
        inout item sample: SensorSample;
        inout item command: DispatchCommand;
        inout item trip: ProtectionTripSignal;
        attribute nominalDataRate: DataRate;
        attribute maximumLatency: Latency;
    }

    action def AcquireMeasurements {
        in item sensorInput: SensorSample;
        out item validatedSample: SensorSample;
        attribute validationWindow_ms: Real = 100.0;
    }

    action def ForecastRenewableGeneration {
        in item weather: WeatherForecast;
        out attribute predictedPvPower: Power;
        attribute modelUpdateInterval_min: Real = 15.0;
    }

    action def ForecastDemand {
        in item loadHistory: SensorSample;
        out item loadForecast: LoadForecast;
        attribute forecastHorizon_h: Real = 24.0;
    }

    action def OptimizeDispatch {
        in item weatherForecast: WeatherForecast;
        in item loadForecast: LoadForecast;
        in item price: MarketPriceSignal;
        out item command: DispatchCommand;
        attribute objective: String = "minimize cost, unmet load, and battery degradation while maximizing renewable utilization";
    }

    action def ExecuteDeviceControl {
        in item command: DispatchCommand;
        out attribute accepted: Boolean;
        attribute commandTimeout_ms: Real = 250.0;
    }

    action def DetectElectricalFault {
        in item sample: SensorSample;
        out item trip: ProtectionTripSignal;
        attribute overCurrentThreshold: Current = (value = 1200.0; unit = "A");
        attribute underVoltageThreshold: Voltage = (value = 432.0; unit = "V");
    }

    action def IslandMicrogrid {
        in item trip: ProtectionTripSignal;
        out attribute islanded: Boolean;
        attribute maximumTransferTime_ms: Real = 100.0;
    }

    action def ResynchronizeGridConnection {
        in attribute gridFrequency: Frequency;
        in attribute microgridFrequency: Frequency;
        out attribute synchronized: Boolean;
        attribute maximumPhaseError_deg: Real = 10.0;
    }

    state def EnergyManagementOperatingState {
        entry action AcquireMeasurements;

        state Initializing;
        state GridConnectedMonitoring;
        state ForecastingAndOptimization;
        state Dispatching;
        state IslandedOperation;
        state FaultIsolation;
        state Resynchronizing;
        state SafeShutdown;

        transition initialize
            first Initializing
            then GridConnectedMonitoring;

        transition periodicPlanning
            first GridConnectedMonitoring
            then ForecastingAndOptimization;

        transition optimizedPlanReady
            first ForecastingAndOptimization
            then Dispatching;

        transition dispatchComplete
            first Dispatching
            then GridConnectedMonitoring;

        transition gridFaultDetected
            first GridConnectedMonitoring
            then FaultIsolation;

        transition severeFaultDuringDispatch
            first Dispatching
            then FaultIsolation;

        transition isolated
            first FaultIsolation
            then IslandedOperation;

        transition gridRestored
            first IslandedOperation
            then Resynchronizing;

        transition synchronized
            first Resynchronizing
            then GridConnectedMonitoring;

        transition unrecoverableFault
            first FaultIsolation
            then SafeShutdown;
    }

    part def PhotovoltaicArray {
        attribute ratedPower: Power = (value = 500000.0; unit = "W");
        attribute nominalDcVoltage: Voltage = (value = 750.0; unit = "V");
        attribute maximumIrradiance: Irradiance = (value = 1000.0; unit = "W/m^2");
        attribute moduleTemperature: Temperature;
        port dcOutput: DcPowerPort;
        port telemetry: SensorDataOutPort;
    }

    part def BatteryEnergyStorageSystem {
        attribute ratedEnergy: Energy = (value = 1200.0; unit = "kWh");
        attribute maximumChargePower: Power = (value = 400000.0; unit = "W");
        attribute maximumDischargePower: Power = (value = 400000.0; unit = "W");
        attribute soc: StateOfCharge = (value = 65.0; unit = "%");
        attribute minimumAllowedSoc: StateOfCharge = (value = 20.0; unit = "%");
        attribute maximumAllowedSoc: StateOfCharge = (value = 95.0; unit = "%");
        port dcPort: DcPowerPort;
        port commandIn: ControlCommandInPort;
        port telemetry: SensorDataOutPort;
        perform action ExecuteDeviceControl;
    }

    part def BidirectionalInverter {
        attribute ratedAcPower: Power = (value = 600000.0; unit = "W");
        attribute dcVoltageRangeMin: Voltage = (value = 600.0; unit = "V");
        attribute dcVoltageRangeMax: Voltage = (value = 900.0; unit = "V");
        attribute acVoltage: Voltage = (value = 480.0; unit = "V");
        attribute nominalFrequency: Frequency = (value = 60.0; unit = "Hz");
        attribute conversionEfficiency_percent: Real = 97.5;
        port dcSide: DcPowerPort;
        port acSide: AcPowerPort;
        port commandIn: ControlCommandInPort;
        port telemetry: SensorDataOutPort;
        perform action ExecuteDeviceControl;
    }

    part def CriticalLoadBank {
        attribute nominalDemand: Power = (value = 300000.0; unit = "W");
        attribute minimumServiceReliability: Reliability = (value = 99.9; unit = "%");
        port acInput: AcPowerPort;
        port telemetry: SensorDataOutPort;
    }

    part def FlexibleLoadBank {
        attribute nominalDemand: Power = (value = 250000.0; unit = "W");
        attribute shedPriority: Integer = 3;
        attribute maximumCurtailmentDuration_min: Real = 30.0;
        port acInput: AcPowerPort;
        port commandIn: ControlCommandInPort;
        port telemetry: SensorDataOutPort;
        perform action ExecuteDeviceControl;
    }

    part def UtilityGridInterface {
        attribute nominalVoltage: Voltage = (value = 480.0; unit = "V");
        attribute nominalFrequency: Frequency = (value = 60.0; unit = "Hz");
        attribute maximumImportPower: Power = (value = 1000000.0; unit = "W");
        attribute maximumExportPower: Power = (value = 500000.0; unit = "W");
        port acPort: AcPowerPort;
        port protectionIn: ProtectionSignalInPort;
        port telemetry: SensorDataOutPort;
    }

    part def SolidStateCircuitBreaker {
        attribute interruptionTime_ms: Real = 5.0;
        attribute continuousCurrentRating: Current = (value = 1000.0; unit = "A");
        attribute faultCurrentThreshold: Current = (value = 1200.0; unit = "A");
        port sourceSide: AcPowerPort;
        port loadSide: AcPowerPort;
        port tripIn: ProtectionSignalInPort;
        port telemetry: SensorDataOutPort;
        perform action ExecuteDeviceControl;
    }

    part def ProtectionController {
        attribute tripDecisionLatency: Latency = (value = 10.0; unit = "ms");
        attribute samplingRate_Hz: Real = 10000.0;
        port measurementIn: SensorDataInPort;
        port tripOut: ProtectionSignalOutPort;
        perform action DetectElectricalFault;
    }

    part def PowerQualityMeter {
        attribute voltageAccuracy_percent: Real = 0.2;
        attribute currentAccuracy_percent: Real = 0.5;
        attribute samplePeriod_ms: Real = 20.0;
        port measuredAcPort: AcPowerPort;
        port sensorOut: SensorDataOutPort;
    }

    part def WeatherAndLoadForecaster {
        attribute forecastHorizon_h: Real = 24.0;
        attribute updatePeriod_min: Real = 15.0;
        port measurementIn: SensorDataInPort;
        port forecastOut: ForecastOutPort;
        perform action ForecastRenewableGeneration;
        perform action ForecastDemand;
    }

    part def DispatchOptimizer {
        attribute optimizationPeriod_min: Real = 5.0;
        attribute maximumSolveTime_s: Real = 2.0;
        attribute renewableUtilizationTarget_percent: Real = 85.0;
        port forecastIn: ForecastInPort;
        port marketIn: MarketSignalInPort;
        port commandOut: ControlCommandOutPort;
        perform action OptimizeDispatch;
    }

    part def EmbeddedEnergyManagementController {
        attribute processor: String = "quad-core ARM real-time processor";
        attribute controlCycle_ms: Real = 100.0;
        attribute localStorage_GB: Real = 128.0;
        attribute cybersecurityMode: String = "authenticated encrypted fieldbus";
        port sensorIn: SensorDataInPort;
        port forecastIn: ForecastInPort;
        port marketIn: MarketSignalInPort;
        port commandOut: ControlCommandOutPort;
        port protectionIn: ProtectionSignalInPort;
        exhibit state EnergyManagementOperatingState;
        perform action AcquireMeasurements;
        perform action OptimizeDispatch;
        perform action IslandMicrogrid;
        perform action ResynchronizeGridConnection;
    }

    part def IndustrialCommunicationNetwork {
        attribute topology: String = "redundant switched Ethernet ring";
        attribute nominalDataRate: DataRate = (value = 100.0; unit = "Mb/s");
        attribute maximumLatency: Latency = (value = 20.0; unit = "ms");
        attribute packetDeliveryReliability: Reliability = (value = 99.99; unit = "%");
        port controllerPort: CommunicationPort;
        port inverterPort: CommunicationPort;
        port batteryPort: CommunicationPort;
        port loadPort: CommunicationPort;
        port protectionPort: CommunicationPort;
        port meterPort: CommunicationPort;
    }

    part def SmartMicrogridEMS {
        attribute primaryFunction: String =
            "Coordinate distributed electrical generation, storage, loads, protection, forecasting, and communication to deliver reliable and efficient microgrid operation.";
        attribute nominalAcVoltage: Voltage = (value = 480.0; unit = "V");
        attribute nominalFrequency: Frequency = (value = 60.0; unit = "Hz");
        attribute peakServedLoad: Power = (value = 550000.0; unit = "W");
        attribute renewablePenetrationTarget_percent: Real = 70.0;
        attribute blackoutRideThroughDuration_h: Real = 2.0;

        part pvArray: PhotovoltaicArray;
        part battery: BatteryEnergyStorageSystem;
        part inverter: BidirectionalInverter;
        part criticalLoads: CriticalLoadBank;
        part flexibleLoads: FlexibleLoadBank;
        part gridInterface: UtilityGridInterface;
        part breaker: SolidStateCircuitBreaker;
        part meterAtBus: PowerQualityMeter;
        part protectionController: ProtectionController;
        part forecaster: WeatherAndLoadForecaster;
        part optimizer: DispatchOptimizer;
        part emsController: EmbeddedEnergyManagementController;
        part communicationNetwork: IndustrialCommunicationNetwork;

        port gridPort: AcPowerPort;
        port criticalLoadPort: AcPowerPort;
        port flexibleLoadPort: AcPowerPort;
        port marketInput: MarketSignalInPort;

        connect pvArray.dcOutput to inverter.dcSide;
        connect battery.dcPort to inverter.dcSide;
        connect inverter.acSide to breaker.loadSide;
        connect breaker.sourceSide to gridInterface.acPort;
        connect breaker.loadSide to criticalLoads.acInput;
        connect breaker.loadSide to flexibleLoads.acInput;
        connect breaker.loadSide to meterAtBus.measuredAcPort;
        connect gridInterface.acPort to gridPort;
        connect criticalLoads.acInput to criticalLoadPort;
        connect flexibleLoads.acInput to flexibleLoadPort;

        connect pvArray.telemetry to emsController.sensorIn;
        connect battery.telemetry to emsController.sensorIn;
        connect inverter.telemetry to emsController.sensorIn;
        connect criticalLoads.telemetry to emsController.sensorIn;
        connect flexibleLoads.telemetry to emsController.sensorIn;
        connect gridInterface.telemetry to emsController.sensorIn;
        connect meterAtBus.sensorOut to protectionController.measurementIn;
        connect meterAtBus.sensorOut to forecaster.measurementIn;
        connect protectionController.tripOut to breaker.tripIn;
        connect protectionController.tripOut to emsController.protectionIn;
        connect forecaster.forecastOut to optimizer.forecastIn;
        connect forecaster.forecastOut to emsController.forecastIn;
        connect marketInput to optimizer.marketIn;
        connect marketInput to emsController.marketIn;
        connect optimizer.commandOut to emsController.commandOut;
        connect emsController.commandOut to inverter.commandIn;
        connect emsController.commandOut to battery.commandIn;
        connect emsController.commandOut to flexibleLoads.commandIn;

        connect communicationNetwork.controllerPort to communicationNetwork.inverterPort;
        connect communicationNetwork.controllerPort to communicationNetwork.batteryPort;
        connect communicationNetwork.controllerPort to communicationNetwork.loadPort;
        connect communicationNetwork.controllerPort to communicationNetwork.protectionPort;
        connect communicationNetwork.controllerPort to communicationNetwork.meterPort;

        exhibit state EnergyManagementOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        subject system: SmartMicrogridEMS;
        attribute requiredFunction: String =
            "The system shall provide high-level intelligent microgrid energy management by monitoring electrical conditions, forecasting supply and demand, optimizing dispatch, commanding devices, and protecting the microgrid.";
        require constraint {
            system.renewablePenetrationTarget_percent >= 70.0
        }
    }

    requirement def CriticalLoadReliabilityRequirement {
        subject system: SmartMicrogridEMS;
        attribute requiredReliability: Reliability = (value = 99.9; unit = "%");
        require constraint {
            system.criticalLoads.minimumServiceReliability.value >= requiredReliability.value
        }
    }

    requirement def DispatchLatencyRequirement {
        subject system: SmartMicrogridEMS;
        attribute maximumAllowedControlCycle_ms: Real = 100.0;
        require constraint {
            system.emsController.controlCycle_ms <= maximumAllowedControlCycle_ms
        }
    }

    requirement def ProtectionTripRequirement {
        subject system: SmartMicrogridEMS;
        attribute maximumTripDecisionLatency: Latency = (value = 10.0; unit = "ms");
        attribute maximumBreakerInterruptionTime_ms: Real = 5.0;
        require constraint {
            system.protectionController.tripDecisionLatency.value <= maximumTripDecisionLatency.value and
            system.breaker.interruptionTime_ms <= maximumBreakerInterruptionTime_ms
        }
    }

    requirement def BatteryReserveRequirement {
        subject system: SmartMicrogridEMS;
        attribute minimumReserveSoc: StateOfCharge = (value = 20.0; unit = "%");
        require constraint {
            system.battery.minimumAllowedSoc.value >= minimumReserveSoc.value
        }
    }

    requirement def CommunicationPerformanceRequirement {
        subject system: SmartMicrogridEMS;
        attribute requiredDataRate: DataRate = (value = 100.0; unit = "Mb/s");
        attribute maximumNetworkLatency: Latency = (value = 20.0; unit = "ms");
        require constraint {
            system.communicationNetwork.nominalDataRate.value >= requiredDataRate.value and
            system.communicationNetwork.maximumLatency.value <= maximumNetworkLatency.value
        }
    }

    requirement def RenewableUtilizationRequirement {
        subject system: SmartMicrogridEMS;
        attribute minimumRenewableUtilization_percent: Real = 85.0;
        require constraint {
            system.optimizer.renewableUtilizationTarget_percent >= minimumRenewableUtilization_percent
        }
    }

    satisfy PrimaryFunctionRequirement by SmartMicrogridEMS;
    satisfy CriticalLoadReliabilityRequirement by SmartMicrogridEMS::criticalLoads;
    satisfy DispatchLatencyRequirement by SmartMicrogridEMS::emsController;
    satisfy ProtectionTripRequirement by SmartMicrogridEMS::protectionController;
    satisfy ProtectionTripRequirement by SmartMicrogridEMS::breaker;
    satisfy BatteryReserveRequirement by SmartMicrogridEMS::battery;
    satisfy CommunicationPerformanceRequirement by SmartMicrogridEMS::communicationNetwork;
    satisfy RenewableUtilizationRequirement by SmartMicrogridEMS::optimizer;

    part smartMicrogridEnergyManagementSystem: SmartMicrogridEMS;

}
