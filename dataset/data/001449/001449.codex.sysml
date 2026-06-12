package HomeEnergyMonitorModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    alias kWh for EnergyValue;
    alias W for PowerValue;
    alias V for ElectricPotentialValue;
    alias A for ElectricCurrentValue;
    alias Hz for FrequencyValue;
    alias degC for TemperatureValue;
    alias s for TimeValue;
    alias percent for Real;

    item def ElectricalEnergy {
        attribute amount : kWh;
        attribute intervalStart : TimeValue;
        attribute intervalEnd : TimeValue;
    }

    item def ElectricalPowerSample {
        attribute realPower : W;
        attribute apparentPower : W;
        attribute reactivePower : W;
        attribute voltage : V;
        attribute current : A;
        attribute frequency : Hz;
        attribute powerFactor : Real;
        attribute timestamp : TimeValue;
    }

    item def CircuitPowerSample :> ElectricalPowerSample {
        attribute circuitId : String;
        attribute circuitName : String;
    }

    item def EnergyAlert {
        attribute severity : AlertSeverity;
        attribute message : String;
        attribute measuredPower : W;
        attribute thresholdPower : W;
        attribute timestamp : TimeValue;
    }

    enum def AlertSeverity {
        enum low;
        enum medium;
        enum high;
        enum critical;
    }

    item def UsageReport {
        attribute totalEnergyToday : kWh;
        attribute peakPowerToday : W;
        attribute averagePowerToday : W;
        attribute estimatedCostToday : Real;
        attribute generatedAt : TimeValue;
    }

    item def TariffSchedule {
        attribute currencyCode : String;
        attribute offPeakRatePerKWh : Real;
        attribute peakRatePerKWh : Real;
        attribute peakStartHour : Integer;
        attribute peakEndHour : Integer;
    }

    value def SamplingInterval {
        :>> unit = s;
    }

    value def DataRetentionPeriod {
        :>> unit = s;
    }

    port def SplitCoreCurrentTransformerPort {
        out sample : ElectricalPowerSample;
        in calibrationCommand : String;
    }

    port def VoltageTapPort {
        out voltageSample : ElectricalPowerSample;
    }

    port def CircuitSensorPort {
        out circuitSample : CircuitPowerSample;
    }

    port def WirelessNetworkPort {
        out telemetry : UsageReport;
        out alert : EnergyAlert;
        in tariff : TariffSchedule;
        in configurationCommand : String;
    }

    port def DisplayPort {
        out currentPower : ElectricalPowerSample;
        out report : UsageReport;
        out activeAlert : EnergyAlert;
    }

    port def PowerSupplyPort {
        in lineVoltage : V;
        out regulatedDcVoltage : V;
    }

    action def MeasureElectricalService {
        in serviceVoltage : V;
        in serviceCurrent : A;
        in lineFrequency : Hz;
        out sample : ElectricalPowerSample;

        action computeRealPower;
        action computeApparentPower;
        action computePowerFactor;

        first start;
        then computeRealPower;
        then computeApparentPower;
        then computePowerFactor;
        then done;
    }

    action def AggregateEnergyUsage {
        in sample : ElectricalPowerSample;
        in previousEnergy : ElectricalEnergy;
        in interval : SamplingInterval;
        out updatedEnergy : ElectricalEnergy;

        action integratePowerOverInterval;
        action updateDailyTotal;

        first start;
        then integratePowerOverInterval;
        then updateDailyTotal;
        then done;
    }

    action def DetectAbnormalConsumption {
        in sample : ElectricalPowerSample;
        in highPowerThreshold : W;
        in standbyThreshold : W;
        out alert : EnergyAlert;

        action evaluatePeakDemand;
        action evaluateUnexpectedStandbyLoad;
        action createAlert;

        first start;
        then evaluatePeakDemand;
        then evaluateUnexpectedStandbyLoad;
        then createAlert;
        then done;
    }

    action def PublishEnergyTelemetry {
        in report : UsageReport;
        in alert : EnergyAlert;
        out cloudMessage : UsageReport;
        out userNotification : EnergyAlert;

        action formatReport;
        action encryptPayload;
        action transmitToNetwork;

        first start;
        then formatReport;
        then encryptPayload;
        then transmitToNetwork;
        then done;
    }

    state def MonitorOperatingState {
        state initializing;
        state calibrating;
        state monitoring;
        state alerting;
        state offline;
        state fault;

        transition first initializing;
        transition initializing then calibrating;
        transition calibrating then monitoring;

        transition monitoring then alerting
            accept EnergyAlert
            if guardAlertIsHigh;

        transition alerting then monitoring
            accept String
            if guardAlertAcknowledged;

        transition monitoring then offline
            accept String
            if guardNetworkUnavailable;

        transition offline then monitoring
            accept String
            if guardNetworkRestored;

        transition monitoring then fault
            accept String
            if guardSensorFailure;

        transition fault then initializing
            accept String
            if guardResetCommand;

        attribute guardAlertIsHigh : Boolean;
        attribute guardAlertAcknowledged : Boolean;
        attribute guardNetworkUnavailable : Boolean;
        attribute guardNetworkRestored : Boolean;
        attribute guardSensorFailure : Boolean;
        attribute guardResetCommand : Boolean;
    }

    part def CurrentTransformerSensor {
        port ctPort : SplitCoreCurrentTransformerPort;

        attribute ratedCurrent : A = 200 [A];
        attribute measurementAccuracy : percent = 1.0;
        attribute sampleRate : Hz = 1 [Hz];
        attribute installedOnConductor : String;

        perform measureCurrent;
    }

    part def VoltageReferenceModule {
        port voltagePort : VoltageTapPort;
        port supplyPort : PowerSupplyPort;

        attribute nominalLineVoltage : V = 120 [V];
        attribute maximumLineVoltage : V = 264 [V];
        attribute frequencyRangeLow : Hz = 50 [Hz];
        attribute frequencyRangeHigh : Hz = 60 [Hz];

        perform measureVoltage;
    }

    part def CircuitChannelSensor {
        port circuitPort : CircuitSensorPort;

        attribute circuitId : String;
        attribute circuitName : String;
        attribute breakerRating : A;
        attribute maximumObservedPower : W;
        attribute enabled : Boolean = true;

        perform measureBranchCircuitPower;
    }

    part def MeasurementProcessor {
        in rawServiceSample : ElectricalPowerSample;
        in rawCircuitSample : CircuitPowerSample;
        out validatedServiceSample : ElectricalPowerSample;
        out validatedCircuitSample : CircuitPowerSample;

        attribute samplingInterval : SamplingInterval = 1 [s];
        attribute calibrationOffsetVoltage : V = 0 [V];
        attribute calibrationOffsetCurrent : A = 0 [A];
        attribute minimumPowerFactor : Real = 0.0;
        attribute maximumPowerFactor : Real = 1.0;

        perform serviceMeasurement : MeasureElectricalService;
    }

    part def EnergyAnalyticsEngine {
        in validatedSample : ElectricalPowerSample;
        in circuitSample : CircuitPowerSample;
        in tariffSchedule : TariffSchedule;
        out usageReport : UsageReport;
        out energyAlert : EnergyAlert;

        attribute highPowerThreshold : W = 9000 [W];
        attribute standbyThreshold : W = 300 [W];
        attribute dailyEnergyBudget : kWh = 35 [kWh];
        attribute dataRetention : DataRetentionPeriod = 31536000 [s];
        attribute totalEnergyToday : kWh;
        attribute peakPowerToday : W;
        attribute estimatedCostToday : Real;

        perform aggregateUsage : AggregateEnergyUsage;
        perform detectAbnormalConsumption : DetectAbnormalConsumption;
    }

    part def LocalDisplay {
        port displayPort : DisplayPort;

        attribute refreshInterval : SamplingInterval = 5 [s];
        attribute showsInstantPower : Boolean = true;
        attribute showsDailyEnergy : Boolean = true;
        attribute showsCostEstimate : Boolean = true;
        attribute brightness : percent = 75.0;
    }

    part def CommunicationsGateway {
        port networkPort : WirelessNetworkPort;

        attribute wifiSignalStrength : percent;
        attribute encryptedTransportEnabled : Boolean = true;
        attribute telemetryPublishInterval : SamplingInterval = 60 [s];
        attribute cloudEndpoint : String = "energy.example.home/api/telemetry";

        perform publishTelemetry : PublishEnergyTelemetry;
    }

    part def HomeElectricalPanel {
        port serviceCurrentOutput : SplitCoreCurrentTransformerPort;
        port serviceVoltageOutput : VoltageTapPort;

        attribute serviceVoltage : V = 240 [V];
        attribute serviceCurrentLimit : A = 200 [A];
        attribute serviceFrequency : Hz = 60 [Hz];

        part kitchenCircuit : CircuitChannelSensor {
            :>> circuitId = "CIR-01";
            :>> circuitName = "Kitchen";
            :>> breakerRating = 20 [A];
        }

        part hvacCircuit : CircuitChannelSensor {
            :>> circuitId = "CIR-02";
            :>> circuitName = "HVAC";
            :>> breakerRating = 40 [A];
        }

        part laundryCircuit : CircuitChannelSensor {
            :>> circuitId = "CIR-03";
            :>> circuitName = "Laundry";
            :>> breakerRating = 30 [A];
        }

        part lightingCircuit : CircuitChannelSensor {
            :>> circuitId = "CIR-04";
            :>> circuitName = "Lighting";
            :>> breakerRating = 15 [A];
        }
    }

    part def HomeEnergyMonitor {
        doc
        /*
         * Primary high-level function:
         * continuously measure household electrical consumption at the service
         * entrance and selected branch circuits, convert raw voltage and current
         * measurements into power and energy usage, detect abnormal consumption,
         * estimate cost, and present actionable usage information to occupants
         * locally and through a network service.
         */

        port serviceCurrentInput : SplitCoreCurrentTransformerPort;
        port serviceVoltageInput : VoltageTapPort;
        port userDisplay : DisplayPort;
        port wirelessNetwork : WirelessNetworkPort;
        port mainsPower : PowerSupplyPort;

        attribute nominalSupplyVoltage : V = 120 [V];
        attribute maximumMeasuredPower : W = 48000 [W];
        attribute samplingInterval : SamplingInterval = 1 [s];
        attribute reportInterval : SamplingInterval = 60 [s];
        attribute operatingTemperatureLow : degC = -10 [K];
        attribute operatingTemperatureHigh : degC = 50 [K];

        part currentSensor : CurrentTransformerSensor {
            :>> ratedCurrent = 200 [A];
            :>> installedOnConductor = "Main service conductor";
        }

        part voltageModule : VoltageReferenceModule;
        part processor : MeasurementProcessor;
        part analytics : EnergyAnalyticsEngine;
        part display : LocalDisplay;
        part gateway : CommunicationsGateway;

        state operatingState : MonitorOperatingState;

        connection serviceCurrentConnection
            connect serviceCurrentInput to currentSensor.ctPort;

        connection serviceVoltageConnection
            connect serviceVoltageInput to voltageModule.voltagePort;

        connection processorServiceMeasurement
            connect currentSensor.ctPort.sample to processor.rawServiceSample;

        connection processorVoltageReference
            connect voltageModule.voltagePort.voltageSample to processor.rawServiceSample;

        connection analyticsInputConnection
            connect processor.validatedServiceSample to analytics.validatedSample;

        connection displayPowerConnection
            connect processor.validatedServiceSample to display.displayPort.currentPower;

        connection displayReportConnection
            connect analytics.usageReport to display.displayPort.report;

        connection displayAlertConnection
            connect analytics.energyAlert to display.displayPort.activeAlert;

        connection networkReportConnection
            connect analytics.usageReport to gateway.networkPort.telemetry;

        connection networkAlertConnection
            connect analytics.energyAlert to gateway.networkPort.alert;

        connection tariffConfigurationConnection
            connect gateway.networkPort.tariff to analytics.tariffSchedule;

        connection userDisplayConnection
            connect display.displayPort to userDisplay;

        connection wirelessConnection
            connect gateway.networkPort to wirelessNetwork;

        connection supplyConnection
            connect mainsPower to voltageModule.supplyPort;

        perform continuousMonitoring {
            action acquireSample : MeasureElectricalService;
            action aggregateEnergy : AggregateEnergyUsage;
            action evaluateUsage : DetectAbnormalConsumption;
            action publishReport : PublishEnergyTelemetry;

            first start;
            then acquireSample;
            then aggregateEnergy;
            then evaluateUsage;
            then publishReport;
            then done;
        }
    }

    part homePanel : HomeElectricalPanel;
    part monitor : HomeEnergyMonitor;

    connection installedCurrentSensor
        connect homePanel.serviceCurrentOutput to monitor.serviceCurrentInput;

    connection installedVoltageReference
        connect homePanel.serviceVoltageOutput to monitor.serviceVoltageInput;

    connection kitchenCircuitTelemetry
        connect homePanel.kitchenCircuit.circuitPort.circuitSample
            to monitor.processor.rawCircuitSample;

    connection hvacCircuitTelemetry
        connect homePanel.hvacCircuit.circuitPort.circuitSample
            to monitor.processor.rawCircuitSample;

    connection laundryCircuitTelemetry
        connect homePanel.laundryCircuit.circuitPort.circuitSample
            to monitor.processor.rawCircuitSample;

    connection lightingCircuitTelemetry
        connect homePanel.lightingCircuit.circuitPort.circuitSample
            to monitor.processor.rawCircuitSample;

    requirement def MeasureWholeHomeConsumptionRequirement {
        doc "The home energy monitor shall measure whole-home real power consumption at the electrical service entrance.";
        subject monitor : HomeEnergyMonitor;
        require constraint {
            monitor.maximumMeasuredPower >= 48000 [W]
        }
    }

    requirement def SamplingFrequencyRequirement {
        doc "The home energy monitor shall update electrical measurements at least once per second.";
        subject monitor : HomeEnergyMonitor;
        require constraint {
            monitor.samplingInterval <= 1 [s]
        }
    }

    requirement def UsageReportingRequirement {
        doc "The home energy monitor shall provide daily energy, peak power, average power, and estimated cost in a usage report.";
        subject analytics : EnergyAnalyticsEngine;
        require constraint {
            analytics.dataRetention >= 31536000 [s]
        }
    }

    requirement def AbnormalUsageAlertRequirement {
        doc "The home energy monitor shall generate an alert when measured power exceeds the configured high-power threshold.";
        subject analytics : EnergyAnalyticsEngine;
        require constraint {
            analytics.highPowerThreshold <= 9000 [W]
        }
    }

    requirement def LocalAndRemoteAccessRequirement {
        doc "The home energy monitor shall make energy usage information available on a local display and through a wireless network interface.";
        subject monitor : HomeEnergyMonitor;
        require constraint {
            monitor.display.showsInstantPower == true and
            monitor.gateway.encryptedTransportEnabled == true
        }
    }

    satisfy MeasureWholeHomeConsumptionRequirement by monitor;
    satisfy SamplingFrequencyRequirement by monitor;
    satisfy UsageReportingRequirement by monitor.analytics;
    satisfy AbnormalUsageAlertRequirement by monitor.analytics;
    satisfy LocalAndRemoteAccessRequirement by monitor;

}