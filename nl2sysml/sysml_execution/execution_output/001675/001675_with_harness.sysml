package OpenHANEnergyManagementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceID :> String;
    attribute def MessageID :> String;
    attribute def PriceRate :> Real;
    attribute def DemandLevel :> Integer;
    
    enum def DeviceStatus {
        enum online;
        enum offline;
        enum standby;
        enum active;
    }
    
    enum def DemandResponseMode {
        enum normal;
        enum moderate;
        enum critical;
    }
    
    value def EnergyMeasurement {
        attribute consumption : EnergyValue;
        attribute timestamp : String;
        attribute deviceID : DeviceID;
        attribute instantaneousPower : PowerValue;
    }
    
    value def PricingSignal {
        attribute currentRate : PriceRate;
        attribute peakRate : PriceRate;
        attribute offPeakRate : PriceRate;
        attribute effectiveTime : String;
    }
    
    value def DemandResponseSignal {
        attribute mode : DemandResponseMode;
        attribute targetReduction : PowerValue;
        attribute duration : TimeValue;
        attribute priority : Integer;
    }
    
    value def ControlCommand {
        attribute targetDevice : DeviceID;
        attribute commandType : String;
        attribute powerLimit : PowerValue;
        attribute scheduledTime : String;
    }
    
    value def DeviceRegistration {
        attribute deviceID : DeviceID;
        attribute deviceType : String;
        attribute maxPower : PowerValue;
        attribute controllable : Boolean;
    }
    
    port def HAN_CommunicationPort {
        out energyData : EnergyMeasurement;
        out statusReport : DeviceStatus;
        in controlCmd : ControlCommand;
        in configData : String;
    }
    
    port def UtilityInterfacePort {
        in pricingInfo : PricingSignal;
        in demandResponse : DemandResponseSignal;
        out aggregatedConsumption : EnergyMeasurement;
        out networkStatus : String;
    }
    
    port def MeterInterfacePort {
        in readRequest : String;
        out meterData : EnergyMeasurement;
        in calibrationCmd : String;
    }
    
    port def ApplianceControlPort {
        out controlSignal : ControlCommand;
        in applianceStatus : DeviceStatus;
        in powerUsage : PowerValue;
    }
    
    part def SmartElectricMeter {
        attribute meterID : DeviceID;
        attribute totalConsumption : EnergyValue;
        attribute currentDraw : PowerValue;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        
        port meterPort : MeterInterfacePort;
        port commPort : HAN_CommunicationPort;
        
        perform action measureEnergy {
            out measurement : EnergyMeasurement;
        }
        
        perform action reportUsage {
            in interval : TimeValue;
            out data : EnergyMeasurement;
        }
    }
    
    part def HomeAreaNetworkGateway {
        attribute gatewayID : DeviceID;
        attribute registeredDevices : Integer;
        attribute networkCapacity : Integer;
        attribute securityEnabled : Boolean;
        
        port utilityLink : UtilityInterfacePort;
        port meterLink[1..*] : MeterInterfacePort;
        port deviceLink[*] : HAN_CommunicationPort;
        port applianceControl[*] : ApplianceControlPort;
        
        perform action aggregateConsumption {
            in meterReadings : EnergyMeasurement[*];
            out totalUsage : EnergyMeasurement;
        }
        
        perform action distributeDemandResponse {
            in drSignal : DemandResponseSignal;
            out commands : ControlCommand[*];
        }
        
        perform action managePricing {
            in pricing : PricingSignal;
            out optimizationCmd : ControlCommand[*];
        }
    }
    
    part def UtilityManagementSystem {
        attribute utilityID : String;
        attribute connectedHomes : Integer;
        attribute gridLoad : PowerValue;
        
        port homeGatewayInterface[*] : UtilityInterfacePort;
        
        perform action monitorGrid {
            in currentLoad : PowerValue;
            out drSignal : DemandResponseSignal;
        }
        
        perform action broadcastPricing {
            in marketRate : PriceRate;
            out pricing : PricingSignal;
        }
        
        perform action collectBillingData {
            in consumption : EnergyMeasurement[*];
            out billingRecords : EnergyMeasurement[*];
        }
    }
    
    part def SmartThermostat {
        attribute thermostatID : DeviceID;
        attribute currentTemp : TemperatureValue;
        attribute setpointTemp : TemperatureValue;
        attribute hvacPower : PowerValue;
        attribute operatingMode : String;
        
        port controlInterface : HAN_CommunicationPort;
        
        perform action adjustTemperature {
            in targetTemp : TemperatureValue;
            in priceSignal : PriceRate;
            out newSetpoint : TemperatureValue;
        }
        
        perform action respondToDemand {
            in drMode : DemandResponseMode;
            out reducedSetpoint : TemperatureValue;
        }
    }
    
    part def SmartWaterHeater {
        attribute heaterID : DeviceID;
        attribute waterTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        attribute heatingPower : PowerValue;
        attribute tankCapacity : VolumeValue;
        
        port controlInterface : HAN_CommunicationPort;
        
        perform action scheduleHeating {
            in pricing : PricingSignal;
            in currentTemp : TemperatureValue;
            out heatingSchedule : String;
        }
    }
    
    part def SmartDryer {
        attribute dryerID : DeviceID;
        attribute cycleTime : TimeValue;
        attribute powerConsumption : PowerValue;
        attribute cycleStatus : DeviceStatus;
        
        port controlInterface : HAN_CommunicationPort;
        
        perform action delayCycle {
            in pricing : PricingSignal;
            in maxDelay : TimeValue;
            out startTime : String;
        }
    }
    
    action def MeasureConsumption {
        in deviceID : DeviceID;
        in samplingRate : TimeValue;
        out reading : EnergyMeasurement;
    }
    
    action def TransmitData {
        in data : EnergyMeasurement;
        in destination : DeviceID;
        out success : Boolean;
    }
    
    action def ProcessDemandResponse {
        in signal : DemandResponseSignal;
        in currentLoad : PowerValue;
        out controlActions : ControlCommand[*];
    }
    
    action def OptimizeLoadSchedule {
        in pricing : PricingSignal;
        in deviceList : DeviceRegistration[*];
        out schedule : ControlCommand[*];
    }
    
    action def AuthenticateDevice {
        in deviceID : DeviceID;
        in credentials : String;
        out authenticated : Boolean;
    }
    
    state def GatewayOperationStates {
        entry action initialize;
        
        state Initializing;
        
        transition first Initializing;
        
        state Initializing {
            entry action registerDevices;
            accept authenticated;
            then NormalOperation;
        }
        
        state NormalOperation {
            entry action startMonitoring;
            
            do action continuousMonitoring {
                action collectData : MeasureConsumption;
                then action transmit : TransmitData {
                    in data = collectData.reading;
                }
            }
            
            accept drReceived;
            then DemandResponseActive;
            
            accept pricingUpdate;
            then PricingOptimization;
        }
        
        state DemandResponseActive {
            entry action activateDR;
            
            do action manageDemand : ProcessDemandResponse {
                out controlActions : ControlCommand[*];
            }
            
            accept drComplete;
            then NormalOperation;
        }
        
        state PricingOptimization {
            entry action analyzePricing;
            
            do action optimizeSchedule : OptimizeLoadSchedule {
                out schedule : ControlCommand[*];
            }
            
            accept optimizationComplete;
            then NormalOperation;
        }
        
        state Fault {
            entry action logError;
            accept reset;
            then Initializing;
        }
    }
    
    part openHANSystem : OpenHANResidentialNetwork {
        doc /* 
            OpenHAN (Open Home Area Network) residential energy management system.
            Primary function: Enable intelligent, automated coordination of home energy 
            consumption by facilitating secure bidirectional communication between utility 
            providers and smart home devices. The system monitors real-time energy usage, 
            responds to utility demand response signals and dynamic pricing, and optimizes 
            appliance operation to reduce costs and support grid stability while maintaining 
            occupant comfort and convenience.
        */
        
        part utilityBackend : UtilityManagementSystem {
            attribute utilityID = "UTILITY-MAIN-001";
            attribute connectedHomes = 2500;
            attribute gridLoad = 15000.0[kW];
        }
        
        part homeGateway : HomeAreaNetworkGateway {
            attribute gatewayID = "HAN-GW-12345";
            attribute registeredDevices = 6;
            attribute networkCapacity = 32;
            attribute securityEnabled = true;
            
            exhibit state gatewayStates : GatewayOperationStates;
        }
        
        part electricMeter : SmartElectricMeter {
            attribute meterID = "METER-ELEC-001";
            attribute totalConsumption = 5420.5[kW*h];
            attribute currentDraw = 3.8[kW];
            attribute voltage = 240.0[V];
            attribute current = 15.8[A];
        }
        
        part thermostat : SmartThermostat {
            attribute thermostatID = "THERMO-001";
            attribute currentTemp = 22.0[°C];
            attribute setpointTemp = 21.0[°C];
            attribute hvacPower = 2.5[kW];
            attribute operatingMode = "cooling";
        }
        
        part waterHeater : SmartWaterHeater {
            attribute heaterID = "WH-001";
            attribute waterTemp = 55.0[°C];
            attribute targetTemp = 60.0[°C];
            attribute heatingPower = 4.5[kW];
            attribute tankCapacity = 200.0[L];
        }
        
        part dryer : SmartDryer {
            attribute dryerID = "DRYER-001";
            attribute cycleTime = 60.0[min];
            attribute powerConsumption = 3.0[kW];
            attribute cycleStatus = DeviceStatus::standby;
        }
        
        connect electricMeter.commPort to homeGateway.deviceLink[1];
        connect electricMeter.meterPort to homeGateway.meterLink[1];
        connect thermostat.controlInterface to homeGateway.deviceLink[2];
        connect waterHeater.controlInterface to homeGateway.deviceLink[3];
        connect dryer.controlInterface to homeGateway.deviceLink[4];
        connect homeGateway.utilityLink to utilityBackend.homeGatewayInterface[1];
        
        perform action operateOpenHAN {
            first start;
            then merge mainLoop;
            
            action monitorConsumption : MeasureConsumption {
                in deviceID = "HAN-GW-12345";
                in samplingRate = 15.0[min];
                out reading : EnergyMeasurement;
            }
            
            then action aggregateData : homeGateway.aggregateConsumption {
                in meterReadings : EnergyMeasurement[1];
                out totalUsage : EnergyMeasurement;
            }
            
            then action transmitToUtility : TransmitData {
                in data = aggregateData.totalUsage;
                in destination = "UTILITY-MAIN-001";
                out success : Boolean;
            }
            
            then decide;
                if transmitToUtility.success then checkDemandResponse;
                if not transmitToUtility.success then retryTransmission;
            
            action retryTransmission {
                action retry : TransmitData {
                    in data = aggregateData.totalUsage;
                    in destination = "UTILITY-MAIN-001";
                    out success : Boolean;
                }
            }
            then mainLoop;
            
            action checkDemandResponse {
                action receiveDR {
                    out drSignal : DemandResponseSignal;
                }
                then decide;
                    if receiveDR.drSignal.mode == DemandResponseMode::critical then executeDR;
                    if receiveDR.drSignal.mode == DemandResponseMode::moderate then executeDR;
                    if receiveDR.drSignal.mode == DemandResponseMode::normal then checkPricing;
                
                action executeDR : ProcessDemandResponse {
                    in signal = receiveDR.drSignal;
                    in currentLoad = 3.8[kW];
                    out controlActions : ControlCommand[*];
                }
                then mainLoop;
            }
            
            action checkPricing {
                action receivePricing {
                    out pricing : PricingSignal;
                }
                then action optimize : OptimizeLoadSchedule {
                    in pricing = receivePricing.pricing;
                    out schedule : ControlCommand[*];
                }
            }
            then mainLoop;
            
            merge mainLoop;
            then monitorConsumption;
        }
    }
    
    requirement def OpenHANSystemRequirements {
        doc /* Requirements for OpenHAN residential energy management system */
        
        requirement communicationReliability {
            doc /* System shall maintain minimum 99.5% communication uptime between gateway and utility */
            subject openHANSystem.homeGateway;
        }
        
        requirement dataSecurityRequirement {
            doc /* All communications shall use AES-256 encryption and mutual authentication */
            subject openHANSystem.homeGateway;
            require constraint {
                openHANSystem.homeGateway.securityEnabled == true
            }
        }
        
        requirement meteringAccuracy {
            doc /* Smart meter shall measure energy consumption with accuracy within ±2% */
            subject openHANSystem.electricMeter;
        }
        
        requirement demandResponseLatency {
            doc /* System shall execute demand response commands within 10 seconds of receipt */
            subject openHANSystem.homeGateway;
        }
        
        requirement deviceInteroperability {
            doc /* System shall support IEEE 2030.5, ZigBee SEP 2.0, and OpenADR 2.0b protocols */
            subject openHANSystem;
        }
        
        requirement loadReduction {
            doc /* System shall achieve minimum 30% load reduction during critical demand response events */
            subject openHANSystem;
        }
        
        requirement userComfort {
            doc /* Automated control shall maintain indoor temperature within ±2°C of user setpoint */
            subject openHANSystem.thermostat;
        }
        
        requirement scalability {
            doc /* Gateway shall support minimum 32 simultaneously connected devices */
            subject openHANSystem.homeGateway;
            require constraint {
                openHANSystem.homeGateway.networkCapacity >= 32
            }
        }
    }
    
    requirement openHANMissionRequirement {
        doc /* 
            The OpenHAN system shall provide an intelligent, secure, and interoperable 
            platform for residential energy management that enables real-time monitoring, 
            dynamic pricing response, demand response participation, and automated load 
            optimization to reduce energy costs, improve grid reliability, and support 
            sustainable energy distribution while maintaining occupant comfort.
        */
        
        require OpenHANSystemRequirements::communicationReliability;
        require OpenHANSystemRequirements::dataSecurityRequirement;
        require OpenHANSystemRequirements::meteringAccuracy;
        require OpenHANSystemRequirements::demandResponseLatency;
        require OpenHANSystemRequirements::deviceInteroperability;
        require OpenHANSystemRequirements::loadReduction;
        require OpenHANSystemRequirements::userComfort;
        require OpenHANSystemRequirements::scalability;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import OpenHANEnergyManagementSystem::*;

    part homeGateway : SmartElectricMeter {
        exhibit state sm : GatewayOperationStates;
    }

    action orchestrator {
        attribute testDeviceID : DeviceID = "";
        attribute testSamplingRate : TimeValue;
        action collectDataProbe : MeasureConsumption {
            in deviceID = testDeviceID;
            in samplingRate = testSamplingRate;
        }
        first collectDataProbe;
    }
}
