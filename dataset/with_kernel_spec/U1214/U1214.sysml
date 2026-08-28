package 'Smart Electrical Metering System' {
    private import ScalarValues::*;
    
    attribute def Voltage;
    attribute def Current;
    attribute def Power;
    attribute def Energy;
    attribute def TariffRate;
    attribute def Cost;
    attribute def PowerThreshold;
    attribute def TimeStamp;
    
    item def ElectricalFlow {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    item def MeasurementData {
        attribute timestamp : TimeStamp;
        attribute measuredVoltage : Voltage;
        attribute measuredCurrent : Current;
        attribute instantaneousPower : Power;
        attribute cumulativeEnergy : Energy;
    }
    
    item def ProcessedUsageData {
        attribute timestamp : TimeStamp;
        attribute averagePower : Power;
        attribute peakPower : Power;
        attribute totalEnergy : Energy;
        attribute anomalyDetected : Boolean;
    }
    
    item def TariffUpdate {
        attribute effectiveTime : TimeStamp;
        attribute rate : TariffRate;
    }
    
    item def BillingData {
        attribute timestamp : TimeStamp;
        attribute energyConsumed : Energy;
        attribute appliedRate : TariffRate;
        attribute runningCost : Cost;
    }
    
    item def PowerAlert {
        attribute timestamp : TimeStamp;
        attribute observedPower : Power;
        attribute threshold : PowerThreshold;
        attribute severity : String;
    }
    
    item def RelayCommand {
        attribute timestamp : TimeStamp;
        attribute disconnect : Boolean;
    }
    
    item def UsageReport {
        attribute timestamp : TimeStamp;
        item processedData : ProcessedUsageData;
        item billingData : BillingData;
    }
    
    port def GridSupplyPort {
        out item suppliedPower : ElectricalFlow;
    }
    
    port def GridInputPort {
        in item incomingPower : ElectricalFlow;
    }
    
    port def LoadSupplyPort {
        out item deliveredPower : ElectricalFlow;
    }
    
    port def LoadInputPort {
        in item deliveredPower : ElectricalFlow;
    }
    
    port def MeasurementPort {
        out item measurement : MeasurementData;
    }
    
    port def ProcessorInputPort {
        in item rawMeasurement : MeasurementData;
    }
    
    port def ProcessorOutputPort {
        out item processedUsage : ProcessedUsageData;
    }
    
    port def MonitorPort {
        in item measurement : MeasurementData;
    }
    
    port def AlertPort {
        out item alert : PowerAlert;
    }
    
    port def BillingInputPort {
        in item measurement : MeasurementData;
        in item tariff : TariffUpdate;
    }
    
    port def BillingOutputPort {
        out item billing : BillingData;
    }
    
    port def CommunicationInPort {
        in item usage : ProcessedUsageData;
        in item billing : BillingData;
        in item alert : PowerAlert;
    }
    
    port def CommunicationBidirectionalPort {
        out item usageReport : UsageReport;
        in item tariffUpdate : TariffUpdate;
        in item relayCommand : RelayCommand;
    }
    
    port def RelayControlPort {
        in item command : RelayCommand;
    }
    
    port def UtilityPort {
        in item usageReport : UsageReport;
        out item tariffUpdate : TariffUpdate;
        out item relayCommand : RelayCommand;
    }
    
    part def UtilityGrid {
        port gridServicePort : GridSupplyPort;
    }
    
    part def CustomerPremises {
        port premisesLoadPort : LoadInputPort;
    }
    
    part def UtilityCentralSystem {
        port utilityInterfacePort : UtilityPort;
    }
    
    part def MeteringModule {
        attribute samplingInterval : Real;
        port meteringPort : MeasurementPort;
    }
    
    part def DataProcessor {
        port inputPort : ProcessorInputPort;
        port outputPort : ProcessorOutputPort;
    }
    
    part def AlertManager {
        attribute safetyThreshold : PowerThreshold;
        port monitorPort : MonitorPort;
        port alertPort : AlertPort;
    }
    
    part def BillingCalculator {
        attribute currentCost : Cost;
        port inputPort : BillingInputPort;
        port outputPort : BillingOutputPort;
    }
    
    part def CommunicationModule {
        port internalPort : CommunicationInPort;
        port externalPort : CommunicationBidirectionalPort;
    }
    
    state def RelayControlStates {
        entry; then connected;
        
        state connected {
            entry action enablePowerFlow;
        }
        
        transition disconnectTransition
            first connected
            accept cmd : RelayCommand
            then disconnected;
        
        state disconnected {
            entry action cutPowerFlow;
        }
        
        transition reconnectTransition
            first disconnected
            accept cmd : RelayCommand
            then connected;
    }
    
    part def Relay {
        attribute connected : Boolean;
        port gridSidePort : GridInputPort;
        port premisesSidePort : LoadSupplyPort;
        port controlPort : RelayControlPort;
        
        exhibit relayState : RelayControlStates;
    }
    
    action def MeasureElectricity {
        in electricalFlow : ElectricalFlow;
        out measurement : MeasurementData;
        
        action sampleVoltage {
            out voltage : Voltage;
        }
        then action sampleCurrent {
            out current : Current;
        }
        then action calculatePower {
            in voltage : Voltage;
            in current : Current;
            out power : Power;
        }
        then action accumulateEnergy {
            in power : Power;
            out energy : Energy;
        }
    }
    
    action def ProcessUsageData {
        in rawMeasurement : MeasurementData;
        out processedUsage : ProcessedUsageData;
        
        action analyzePatterns {
            in measurement : MeasurementData;
            out patterns : Real;
        }
        then action detectAnomalies {
            in patterns : Real;
            out anomalies : Boolean;
        }
        then action aggregateData {
            in measurement : MeasurementData;
            out aggregated : ProcessedUsageData;
        }
    }
    
    action def MonitorPowerConsumption {
        in measurement : MeasurementData;
        in threshold : PowerThreshold;
        out alert : PowerAlert;
        
        loop action continuousMonitoring {
            if measurement.instantaneousPower > threshold {
                action generateAlert {
                    out alert : PowerAlert;
                }
            }
        }
    }
    
    action def CalculateBilling {
        in measurement : MeasurementData;
        in tariff : TariffUpdate;
        out billing : BillingData;
        
        action computeCost {
            in energy : Energy;
            in rate : TariffRate;
            out cost : Cost;
        }
        then action prepareBillingData {
            in cost : Cost;
            out billing : BillingData;
        }
    }
    
    action def TransmitToUtility {
        in usage : ProcessedUsageData;
        in billing : BillingData;
        in alert : PowerAlert;
        out report : UsageReport;
    }
    
    action def ReceiveFromUtility {
        out tariff : TariffUpdate;
        out command : RelayCommand;
    }
    
    action def ControlRelay {
        in command : RelayCommand;
        
        if command.disconnect {
            action disconnectPower;
        }
        if not command.disconnect {
            action reconnectPower;
        }
    }
    
    action def SmartMeterOperation {
        in threshold : PowerThreshold;
        
        loop action operationCycle {
            action measure : MeasureElectricity;
            
            then action processData : ProcessUsageData {
                in rawMeasurement = measure.measurement;
            }
            
            then action monitorPower : MonitorPowerConsumption {
                in measurement = measure.measurement;
                in threshold;
            }
            
            then action receive : ReceiveFromUtility;
            
            then action calculateBilling : CalculateBilling {
                in measurement = measure.measurement;
                in tariff = receive.tariff;
            }
            
            then action controlRelay : ControlRelay {
                in command = receive.command;
            }
            
            then action transmit : TransmitToUtility {
                in usage = processData.processedUsage;
                in billing = calculateBilling.billing;
                in alert = monitorPower.alert;
            }
        }
    }
    
    part def SmartMeter {
        attribute meterIdentifier : String;
        attribute overloadThreshold : PowerThreshold;
        
        part meteringModule : MeteringModule;
        part dataProcessor : DataProcessor;
        part alertManager : AlertManager;
        part billingCalculator : BillingCalculator;
        part communicationModule : CommunicationModule;
        part relay : Relay;
        
        flow measurementToProcessorFlow of MeasurementData
            from meteringModule.meteringPort.measurement
            to dataProcessor.inputPort.rawMeasurement;
        
        flow measurementToAlertFlow of MeasurementData
            from meteringModule.meteringPort.measurement
            to alertManager.monitorPort.measurement;
        
        flow measurementToBillingFlow of MeasurementData
            from meteringModule.meteringPort.measurement
            to billingCalculator.inputPort.measurement;
        
        flow processedUsageFlow of ProcessedUsageData
            from dataProcessor.outputPort.processedUsage
            to communicationModule.internalPort.usage;
        
        flow alertFlow of PowerAlert
            from alertManager.alertPort.alert
            to communicationModule.internalPort.alert;
        
        flow billingFlow of BillingData
            from billingCalculator.outputPort.billing
            to communicationModule.internalPort.billing;
        
        flow tariffFlow of TariffUpdate
            from communicationModule.externalPort.tariffUpdate
            to billingCalculator.inputPort.tariff;
        
        flow relayCommandFlow of RelayCommand
            from communicationModule.externalPort.relayCommand
            to relay.controlPort.command;
    }
    
    part meteringSystem {
        part utilityGrid : UtilityGrid;
        part smartMeter : SmartMeter;
        part customerPremises : CustomerPremises;
        part utilityCentral : UtilityCentralSystem;
        
        flow gridSupplyFlow of ElectricalFlow
            from utilityGrid.gridServicePort.suppliedPower
            to smartMeter.relay.gridSidePort.incomingPower;
        
        flow premisesSupplyFlow of ElectricalFlow
            from smartMeter.relay.premisesSidePort.deliveredPower
            to customerPremises.premisesLoadPort.deliveredPower;
        
        interface meterToUtilityInterface connect smartMeter.communicationModule.externalPort to utilityCentral.utilityInterfacePort {
            flow usageReportUplink of UsageReport
                from smartMeter.communicationModule.externalPort.usageReport
                to utilityCentral.utilityInterfacePort.usageReport;
            
            flow tariffUpdateDownlink of TariffUpdate
                from utilityCentral.utilityInterfacePort.tariffUpdate
                to smartMeter.communicationModule.externalPort.tariffUpdate;
            
            flow relayCommandDownlink of RelayCommand
                from utilityCentral.utilityInterfacePort.relayCommand
                to smartMeter.communicationModule.externalPort.relayCommand;
        }
    }
    
    requirement def ContinuousMeasurementRequirement {
        doc /* The metering module shall continuously measure voltage and current 
             to calculate instantaneous power and cumulative energy consumption. */
        subject meter : SmartMeter;
        require constraint { meter.meteringModule.samplingInterval <= 1.0 }
    }
    
    requirement def UsageDataProcessingRequirement {
        doc /* The data processor shall analyze raw measurement data to identify
             usage patterns and detect potential anomalies. */
        subject meter : SmartMeter;
    }
    
    requirement def BillingCalculationRequirement {
        doc /* The billing calculator shall use measured energy consumption and
             current tariff rates to calculate running electricity cost. */
        subject meter : SmartMeter;
        require constraint { meter.billingCalculator.currentCost >= 0.0 }
    }
    
    requirement def AlertGenerationRequirement {
        doc /* The alert manager shall monitor power consumption and generate
             alerts when consumption exceeds the safety threshold. */
        subject meter : SmartMeter;
    }
    
    requirement def UtilityCommunicationRequirement {
        doc /* The communication module shall transmit usage information to the
             utility and receive tariff updates and relay commands. */
        subject meter : SmartMeter;
    }
    
    requirement def RemoteControlRequirement {
        doc /* The relay shall support remote disconnect and reconnect of power
             supply based on commands from the utility. */
        subject meter : SmartMeter;
    }
}
