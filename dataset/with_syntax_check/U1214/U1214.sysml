package SmartMeterSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MeterID;
	attribute def Timestamp;
	attribute def TariffRate;
	attribute def AlertLevel;
	
	attribute def EnergyConsumption {
		attribute value : Real;
		attribute unit : EnergyUnit;
	}
	
	attribute def ElectricalPower {
		attribute value : Real;
		attribute unit : PowerUnit;
	}
	
	attribute def ElectricalVoltage {
		attribute value : Real;
		attribute unit : VoltageUnit;
	}
	
	attribute def ElectricalCurrent {
		attribute value : Real;
		attribute unit : CurrentUnit;
	}
	
	attribute def EnergyUnit;
	attribute def PowerUnit;
	attribute def VoltageUnit;
	attribute def CurrentUnit;
	
	port def PowerInputPort {
		in attribute voltage : ElectricalVoltage;
		in attribute current : ElectricalCurrent;
	}
	
	port def PowerOutputPort {
		out attribute voltage : ElectricalVoltage;
		out attribute current : ElectricalCurrent;
	}
	
	port def CommunicationPort {
		out attribute consumptionData : EnergyConsumption;
		in attribute tariffData : TariffRate;
		out attribute alerts : AlertLevel;
	}
	
	part def MeteringModule {
		port powerIn : PowerInputPort;
		out attribute instantaneousPower : ElectricalPower;
		out attribute cumulativeEnergy : EnergyConsumption;
		
		action measurePower {
			in voltage : ElectricalVoltage;
			in current : ElectricalCurrent;
			out power : ElectricalPower;
		}
		
		action accumulateEnergy {
			in power : ElectricalPower;
			in deltaTime : Real;
			in previousEnergy : EnergyConsumption;
			out totalEnergy : EnergyConsumption;
		}
	}
	
	part def DataProcessor {
		in attribute rawPower : ElectricalPower;
		in attribute rawEnergy : EnergyConsumption;
		out attribute processedEnergy : EnergyConsumption;
		out attribute usagePattern : Real;
		
		action analyzeConsumption {
			in energyData : EnergyConsumption;
			in timeInterval : Real;
			out pattern : Real;
			out anomalyDetected : Boolean;
		}
	}
	
	part def CommunicationModule {
		port commPort : CommunicationPort;
		in attribute dataToSend : EnergyConsumption;
		in attribute alertsToSend : AlertLevel;
		out attribute receivedTariff : TariffRate;
		
		action transmitData {
			in data : EnergyConsumption;
			out transmissionStatus : Boolean;
		}
		
		action receiveTariffUpdate {
			out tariff : TariffRate;
		}
		
		action sendAlert {
			in alert : AlertLevel;
			out alertStatus : Boolean;
		}
	}
	
	part def BillingCalculator {
		in attribute consumption : EnergyConsumption;
		in attribute tariff : TariffRate;
		out attribute cost : Real;
		
		action calculateCost {
			in energy : EnergyConsumption;
			in rate : TariffRate;
			out totalCost : Real;
		}
	}
	
	part def AlertManager {
		in attribute currentPower : ElectricalPower;
		in attribute threshold : ElectricalPower;
		out attribute alert : AlertLevel;
		
		action monitorThreshold {
			in power : ElectricalPower;
			in limit : ElectricalPower;
			out alertLevel : AlertLevel;
		}
	}
	
	part def Relay {
		in attribute controlSignal : Boolean;
		out attribute relayState : Boolean;
		
		action controlRelay {
			in disconnect : Boolean;
			out closed : Boolean;
		}
	}
	
	action def MeasureEnergy {
		in voltage : ElectricalVoltage;
		in current : ElectricalCurrent;
		in samplingInterval : Real;
		in previousEnergy : EnergyConsumption;
		out power : ElectricalPower;
		out energy : EnergyConsumption;
	}
	
	action def ProcessData {
		in rawEnergy : EnergyConsumption;
		in rawPower : ElectricalPower;
		out processedEnergy : EnergyConsumption;
	}
	
	action def TransmitToUtility {
		in data : EnergyConsumption;
		out transmissionComplete : Boolean;
	}
	
	action def CalculateBilling {
		in consumption : EnergyConsumption;
		in tariff : TariffRate;
		out billingAmount : Real;
	}
	
	action def MonitorAndAlert {
		in power : ElectricalPower;
		in threshold : ElectricalPower;
		out alert : AlertLevel;
	}
	
	part def SmartMeter {
		attribute meterID : MeterID;
		attribute samplingRate : Real;
		attribute powerThreshold : ElectricalPower;
		
		port gridInput : PowerInputPort;
		port customerOutput : PowerOutputPort;
		port communication : CommunicationPort;
		
		part metering : MeteringModule {
			port redefines powerIn = gridInput;
		}
		
		part processor : DataProcessor;
		
		part commModule : CommunicationModule {
			port redefines commPort = communication;
		}
		
		part billing : BillingCalculator;
		
		part alertMgr : AlertManager;
		
		part relay : Relay;
		
		connection sensorToProcessor connect 
			metering.instantaneousPower to processor.rawPower;
		connection sensorToProcessorEnergy connect 
			metering.cumulativeEnergy to processor.rawEnergy;
		connection processorToComm connect 
			processor.processedEnergy to commModule.dataToSend;
		connection sensorToBilling connect 
			metering.cumulativeEnergy to billing.consumption;
		connection commToBilling connect 
			commModule.receivedTariff to billing.tariff;
		connection sensorToAlert connect 
			metering.instantaneousPower to alertMgr.currentPower;
		connection alertToComm connect 
			alertMgr.alert to commModule.alertsToSend;
		
		perform action monitorAndReportUsage {
			first start;
			then merge continuousMonitoring;
			
			action measure : MeasureEnergy {
				in voltage = gridInput.voltage;
				in current = gridInput.current;
				in samplingInterval = samplingRate;
				in previousEnergy;
				out power;
				out energy;
			}
			
			then action process : ProcessData {
				in rawEnergy = measure.energy;
				in rawPower = measure.power;
				out processedEnergy;
			}
			
			then action checkThreshold : MonitorAndAlert {
				in power = measure.power;
				in threshold = powerThreshold;
				out alert;
			}
			
			then decide;
				if checkThreshold.alert != null then sendAlert;
				then transmit;
			
			action sendAlert {
				in alertData = checkThreshold.alert;
			}
			
			action transmit : TransmitToUtility {
				in data = process.processedEnergy;
				out transmissionComplete;
			}
			
			then action calculateBill : CalculateBilling {
				in consumption = measure.energy;
				in tariff = communication.tariffData;
				out billingAmount;
			}
			
			then continuousMonitoring;
		}
	}
	
	part def UtilityGrid {
		port powerSupply : PowerOutputPort;
	}
	
	part def CustomerPremises {
		port powerInlet : PowerInputPort;
	}
	
	part def UtilityHeadEnd {
		port comms : CommunicationPort;
	}
	
	part meteringSystem {
		part grid : UtilityGrid;
		part meter : SmartMeter;
		part premises : CustomerPremises;
		part headEnd : UtilityHeadEnd;
		
		connection gridToMeter connect grid.powerSupply to meter.gridInput;
		connection meterToPremises connect meter.customerOutput to premises.powerInlet;
		connection meterToUtility connect meter.communication to headEnd.comms;
	}
	
	requirement <'SM-001'> accurateMeasurement {
		doc /* The smart meter shall measure energy consumption with an accuracy of +/- 1% */
		subject meter : SmartMeter;
	}
	
	requirement <'SM-002'> realTimeCommunication {
		doc /* The smart meter shall transmit consumption data to the utility at intervals not exceeding 15 minutes */
		subject meter : SmartMeter;
	}
	
	requirement <'SM-003'> powerThresholdAlert {
		doc /* The smart meter shall generate alerts when instantaneous power exceeds configured threshold */
		subject meter : SmartMeter;
	}
	
	requirement <'SM-004'> bidirectionalCommunication {
		doc /* The smart meter shall receive and process tariff updates from the utility */
		subject meter : SmartMeter;
	}
	
	requirement <'SM-005'> remoteDisconnect {
		doc /* The smart meter shall support remote disconnect and reconnect operations */
		subject meter : SmartMeter;
	}
	
	requirement smartMeterMission {
		doc /* The smart meter system shall continuously monitor electrical energy consumption, 
		       process usage data, communicate with utility infrastructure, calculate billing information, 
		       and alert users to abnormal consumption patterns */
		
		assume constraint {
			doc /* Power supply is stable and within operational voltage range */
		}
		
		assume constraint {
			doc /* Communication network is available for data transmission */
		}
		
		require accurateMeasurement;
		require realTimeCommunication;
		require powerThresholdAlert;
		require bidirectionalCommunication;
		require remoteDisconnect;
	}
}
