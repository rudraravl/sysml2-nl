package SmartMeteringSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    package ValueTypes {
        value def VoltageValue :> Real { unit 'V'; }
        value def CurrentValue :> Real { unit 'A'; }
        value def PowerValue :> Real { unit 'W'; }
        value def EnergyValue :> Real { unit 'kW.h'; }
        value def FrequencyValue :> Real { unit 'Hz'; }
        value def MonetaryValue :> Real { unit 'USD'; }
        value def TariffRateValue :> Real { unit 'USD/(kW.h)'; }
        value def PowerThresholdValue :> Real { unit 'W'; }
        value def TimeInterval :> Real { unit 'h'; }
    }

    package ItemDefs {
        import ValueTypes::*;

        item def RawMeasurement {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute instantaneousPower : PowerValue;
            attribute cumulativeEnergy : EnergyValue;
            attribute timestamp : String;
        }

        item def ProcessedData {
            attribute cumulativeEnergy : EnergyValue;
            attribute averagePower : PowerValue;
            attribute peakPower : PowerValue;
            attribute anomalyDetected : Boolean;
            attribute timestamp : String;
        }

        item def Alert {
            attribute alertType : String;
            attribute powerValue : PowerValue;
            attribute threshold : PowerThresholdValue;
            attribute timestamp : String;
        }

        item def TariffUpdate {
            attribute tariffRate : TariffRateValue;
            attribute effectiveTimestamp : String;
        }

        item def BillingRecord {
            attribute energyConsumed : EnergyValue;
            attribute tariffRate : TariffRateValue;
            attribute periodCost : MonetaryValue;
            attribute cumulativeCost : MonetaryValue;
            attribute timestamp : String;
        }

        item def ControlCommand {
            attribute command : String;
        }

        item def RelayStatus {
            attribute connected : Boolean;
            attribute timestamp : String;
        }
    }

    package PortDefs {
        import ItemDefs::*;
        import ValueTypes::*;

        port def ElectricalPowerIn {
            in voltage : VoltageValue;
            in current : CurrentValue;
        }
        port def ElectricalPowerOut {
            out voltage : VoltageValue;
            out current : CurrentValue;
        }
        port def RawMeasurementOut { out rawMeasurement : RawMeasurement; }
        port def RawMeasurementIn { in rawMeasurement : RawMeasurement; }
        port def ProcessedDataOut { out processedData : ProcessedData; }
        port def ProcessedDataIn { in processedData : ProcessedData; }
        port def AlertOut { out alert : Alert; }
        port def AlertIn { in alert : Alert; }
        port def TariffOut { out tariffUpdate : TariffUpdate; }
        port def TariffIn { in tariffUpdate : TariffUpdate; }
        port def BillingOut { out billingRecord : BillingRecord; }
        port def BillingIn { in billingRecord : BillingRecord; }
        port def ControlCommandOut { out controlCommand : ControlCommand; }
        port def ControlCommandIn { in controlCommand : ControlCommand; }
        port def RelayStatusOut { out relayStatus : RelayStatus; }
        port def RelayStatusIn { in relayStatus : RelayStatus; }

        port def UtilityInterface {
            out processedData : ProcessedData;
            out alert : Alert;
            out billingRecord : BillingRecord;
            out relayStatus : RelayStatus;
            in tariffUpdate : TariffUpdate;
            in controlCommand : ControlCommand;
        }
    }

    package Requirements {
        import ValueTypes::*;

        requirement def SmartMeteringRequirement {
            doc /* The smart metering system shall measure, process, communicate, and bill electricity consumption while monitoring for abnormal conditions. */
        }

        requirement def MeasurementRequirement :> SmartMeteringRequirement {
            doc /* The metering module shall continuously measure voltage and current from the grid. */
            attribute voltageAccuracy : VoltageValue = 0.5;
            attribute currentAccuracy : CurrentValue = 0.1;
            subject meteringModule;
            objective {
                doc /* Ensure accurate and continuous measurement of grid voltage and current. */
            }
        }

        requirement def ProcessingRequirement :> SmartMeteringRequirement {
            doc /* The data processor shall analyze raw measurements to identify usage patterns and detect anomalies. */
            subject dataProcessor;
        }

        requirement def CommunicationRequirement :> SmartMeteringRequirement {
            doc /* The communication module shall transmit usage data to the utility and receive tariff updates and control commands. */
            subject communicationModule;
        }

        requirement def AlertRequirement :> SmartMeteringRequirement {
            doc /* The alert manager shall generate an alert when instantaneous power exceeds the safety threshold. */
            attribute safetyThreshold : PowerThresholdValue = 20000;
            subject alertManager;
        }

        requirement def BillingRequirement :> SmartMeteringRequirement {
            doc /* The billing calculator shall compute running cost from measured energy and received tariff rates. */
            subject billingCalculator;
        }

        requirement def RelayRequirement :> SmartMeteringRequirement {
            doc /* The relay shall allow remote connect and disconnect of the power supply to the premises. */
            subject relay;
        }
    }

    package Components {
        import ValueTypes::*;
        import ItemDefs::*;
        import PortDefs::*;

        part def MeteringModule {
            port powerIn : ElectricalPowerIn;
            port powerOut : ElectricalPowerOut;
            port rawOut : RawMeasurementOut;
            attribute measuredVoltage : VoltageValue;
            attribute measuredCurrent : CurrentValue;
            attribute instantaneousPower : PowerValue;
            attribute cumulativeEnergy : EnergyValue := 0;
            attribute samplingInterval : TimeInterval := 0.001;

            action def MeasureVoltageCurrent {
                out voltage : VoltageValue;
                out current : CurrentValue;
            }
            action def ComputePower {
                in voltage : VoltageValue;
                in current : CurrentValue;
                out power : PowerValue;
            }
            action def AccumulateEnergy {
                in power : PowerValue;
                in interval : TimeInterval;
                out energy : EnergyValue;
            }

            action def MeasureCycle {
                action measure : MeasureVoltageCurrent;
                action compute : ComputePower {
                    in voltage = measure.voltage;
                    in current = measure.current;
                }
                action accumulate : AccumulateEnergy {
                    in power = compute.power;
                    in interval = samplingInterval;
                }
                then send rawOut.rawMeasurement;
            }

            perform MeasureCycle continuously;
        }

        part def DataProcessor {
            port rawIn : RawMeasurementIn;
            port processedOut : ProcessedDataOut;
            attribute windowBuffer : RawMeasurement[0..*];
            attribute anomalyDetected : Boolean := false;
            attribute windowSize : Integer := 60;

            action def IngestMeasurement {
                in measurement : RawMeasurement;
                out stored : RawMeasurement;
            }
            action def AnalyzePatterns {
                in buffer : RawMeasurement[0..*];
                out averagePower : PowerValue;
                out peakPower : PowerValue;
            }
            action def DetectAnomaly {
                in measurement : RawMeasurement;
                out anomaly : Boolean;
            }
            action def EmitProcessedData {
                out processedData : ProcessedData;
            }

            action def ProcessingCycle {
                action ingest : IngestMeasurement;
                action analyze : AnalyzePatterns {
                    in buffer = windowBuffer;
                }
                action detect : DetectAnomaly {
                    in measurement = ingest.stored;
                }
                action emit : EmitProcessedData;
                then send processedOut.processedData;
            }

            perform ProcessingCycle when rawIn.rawMeasurement received;
        }

        part def CommunicationModule {
            port dataIn : ProcessedDataIn;
            port alertIn : AlertIn;
            port billingIn : BillingIn;
            port relayStatusIn : RelayStatusIn;
            port tariffOut : TariffOut;
            port commandOut : ControlCommandOut;
            port utilityPort : UtilityInterface;

            action def TransmitToUtility {
                in data : ProcessedData;
            }
            action def ReceiveTariff {
                out tariffUpdate : TariffUpdate;
            }
            action def ReceiveCommand {
                out controlCommand : ControlCommand;
            }
            action def TransmitAlert {
                in alert : Alert;
            }
            action def TransmitBilling {
                in billingRecord : BillingRecord;
            }
            action def TransmitRelayStatus {
                in relayStatus : RelayStatus;
            }

            action def CommunicationCycle {
                action transmitData : TransmitToUtility {
                    in data = dataIn.processedData;
                }
                action transmitAlert : TransmitAlert {
                    in alert = alertIn.alert;
                }
                action transmitBilling : TransmitBilling {
                    in billingRecord = billingIn.billingRecord;
                }
                action transmitRelayStatus : TransmitRelayStatus {
                    in relayStatus = relayStatusIn.relayStatus;
                }
                action receiveTariff : ReceiveTariff;
                action receiveCommand : ReceiveCommand;
                then send tariffOut.tariffUpdate;
                then send commandOut.controlCommand;
            }

            perform CommunicationCycle continuously;
        }

        part def AlertManager {
            port powerIn : RawMeasurementIn;
            port alertOut : AlertOut;
            attribute safetyThreshold : PowerThresholdValue := 20000;
            attribute lastAlertTime : String;
            attribute alertCooldown : TimeInterval := 0.1;

            action def MonitorPower {
                in measurement : RawMeasurement;
            }
            action def EvaluateThreshold {
                in power : PowerValue;
                in threshold : PowerThresholdValue;
                out alert : Alert;
            }

            action def MonitoringCycle {
                action monitor : MonitorPower;
                action evaluate : EvaluateThreshold {
                    in power = monitor.measurement.instantaneousPower;
                    in threshold = safetyThreshold;
                }
                then send alertOut.alert;
            }

            perform MonitoringCycle when powerIn.rawMeasurement received;
        }

        part def BillingCalculator {
            port energyIn : RawMeasurementIn;
            port tariffIn : TariffIn;
            port billingOut : BillingOut;
            attribute currentTariff : TariffRateValue := 0.12;
            attribute cumulativeCost : MonetaryValue := 0;
            attribute lastEnergy : EnergyValue := 0;

            action def UpdateTariff {
                in tariff : TariffUpdate;
                out rate : TariffRateValue;
            }
            action def ComputeCost {
                in energy : EnergyValue;
                in tariff : TariffRateValue;
                out periodCost : MonetaryValue;
                out cumulativeCost : MonetaryValue;
            }

            action def BillingCycle {
                action updateTariff : UpdateTariff;
                action computeCost : ComputeCost {
                    in energy = energyIn.rawMeasurement.cumulativeEnergy;
                    in tariff = currentTariff;
                }
                then send billingOut.billingRecord;
            }

            perform BillingCycle when energyIn.rawMeasurement received;
        }

        part def Relay {
            port powerIn : ElectricalPowerIn;
            port powerOut : ElectricalPowerOut;
            port commandIn : ControlCommandIn;
            port statusOut : RelayStatusOut;
            attribute connected : Boolean := true;

            state def RelayState {
                entry;
                state Connected {
                    entry action { assign connected = true; }
                }
                state Disconnected {
                    entry action { assign connected = false; }
                }
                transition from Connected to Disconnected
                    when commandIn.controlCommand.command == "disconnect";
                transition from Disconnected to Connected
                    when commandIn.controlCommand.command == "connect";
            }

            exhibit RelayState;

            action def ReportStatus {
                out relayStatus : RelayStatus;
            }

            perform ReportStatus when commandIn.controlCommand received;
        }
    }

    package SystemModel {
        import ValueTypes::*;
        import ItemDefs::*;
        import PortDefs::*;
        import Components::*;
        import Requirements::*;

        part def SmartMeter {
            port gridPort : ElectricalPowerIn;
            port premisesPort : ElectricalPowerOut;
            port utilityPort : UtilityInterface;

            part meteringModule : MeteringModule {
                satisfy MeasurementRequirement;
            }
            part dataProcessor : DataProcessor {
                satisfy ProcessingRequirement;
            }
            part communicationModule : CommunicationModule {
                satisfy CommunicationRequirement;
            }
            part alertManager : AlertManager {
                satisfy AlertRequirement;
            }
            part billingCalculator : BillingCalculator {
                satisfy BillingRequirement;
            }
            part relay : Relay {
                satisfy RelayRequirement;
            }

            connection gridToMetering
                connect gridPort to meteringModule.powerIn;
            connection meteringToRelay
                connect meteringModule.powerOut to relay.powerIn;
            connection relayToPremises
                connect relay.powerOut to premisesPort;

            connection rawToProcessor
                connect meteringModule.rawOut to dataProcessor.rawIn;
            connection rawToAlert
                connect meteringModule.rawOut to alertManager.powerIn;
            connection rawToBilling
                connect meteringModule.rawOut to billingCalculator.energyIn;
            connection processedToComm
                connect dataProcessor.processedOut to communicationModule.dataIn;
            connection alertToComm
                connect alertManager.alertOut to communicationModule.alertIn;
            connection tariffToBilling
                connect communicationModule.tariffOut to billingCalculator.tariffIn;
            connection billingToComm
                connect billingCalculator.billingOut to communicationModule.billingIn;
            connection commandToRelay
                connect communicationModule.commandOut to relay.commandIn;
            connection statusToComm
                connect relay.statusOut to communicationModule.relayStatusIn;

            state def OperationalState {
                state Initializing;
                state NormalOperation;
                state AlertActive;
                state ServiceDisconnected;

                transition from Initializing to NormalOperation;
                transition from NormalOperation to AlertActive
                    when alertManager.alertOut.alert sent;
                transition from AlertActive to NormalOperation;
                transition from NormalOperation to ServiceDisconnected
                    when relay.commandIn.controlCommand.command == "disconnect";
                transition from ServiceDisconnected to NormalOperation
                    when relay.commandIn.controlCommand.command == "connect";
            }

            exhibit OperationalState;

            satisfy SmartMeteringRequirement;
        }

        part def UtilityCentralSystem {
            port utilityPort : ~UtilityInterface;
            attribute systemId : String;
            attribute currentTariff : TariffRateValue := 0.12;
        }

        part def CustomerPremises {
            port premisesPort : ElectricalPowerOut;
            attribute premisesId : String;
            attribute premisesType : String;
        }

        part def ElectricalGrid {
            port gridPort : ElectricalPowerOut;
            attribute nominalVoltage : VoltageValue := 230;
            attribute nominalFrequency : FrequencyValue := 50;
        }

        part smartMeteringSystem {
            part grid : ElectricalGrid;
            part smartMeter : SmartMeter;
            part utility : UtilityCentralSystem;
            part premises : CustomerPremises;

            connection gridToMeter
                connect grid.gridPort to smartMeter.gridPort;
            connection meterToPremises
                connect smartMeter.premisesPort to premises.premisesPort;
            connection utilityToMeter
                connect utility.utilityPort to smartMeter.utilityPort;
        }
    }
}
