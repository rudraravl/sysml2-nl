package 'EnOcean Wireless Sensor Network System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ProtocolStandard {
        attribute frequency : FrequencyValue;
        attribute modulation : String;
        attribute dataRate : Real;
    }
    
    attribute def HarvestingSource {
        attribute sourceType : String;
        attribute efficiency : Real;
    }
    
    item def KineticEnergy {
        attribute force : ISQ::ForceValue;
        attribute displacement : ISQ::LengthValue;
        attribute energy : ISQ::EnergyValue;
    }
    
    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute power : ISQ::PowerValue;
    }
    
    item def SensorPayload {
        attribute temperature : ISQ::TemperatureValue;
        attribute occupancy : Boolean;
        attribute lightLevel : Real;
        attribute timestamp : Real;
    }
    
    item def RadioTelegram {
        attribute sourceAddress : Integer;
        attribute destinationAddress : Integer;
        attribute payload : SensorPayload;
        attribute rssi : Real;
        attribute checksum : Integer;
    }
    
    port def EnergyHarvestingPort {
        out item harvestedPower : ElectricalPower;
    }
    
    port def PowerSupplyPort {
        in item inputPower : ElectricalPower;
        out item regulatedPower : ElectricalPower;
    }
    
    port def SensingPort {
        in item power : ElectricalPower;
        out item data : SensorPayload;
    }
    
    port def RadioPort {
        in item txPower : ElectricalPower;
        in item txData : SensorPayload;
        out item txSignal : RadioTelegram;
    }
    
    port def ReceiverPort {
        in item rxSignal : RadioTelegram;
        out item rxData : SensorPayload;
    }
    
    port def NetworkPort {
        out item sensorData : SensorPayload;
        in item controlCommand : String;
    }
    
    part def PiezoelectricHarvester {
        attribute material : String;
        attribute area : ISQ::AreaValue;
        attribute harvestingEfficiency : Real;
        
        port energyOutput : EnergyHarvestingPort;
        
        action def ConvertMechanicalToElectrical {
            in mechanicalInput : KineticEnergy;
            out electricalOutput : ElectricalPower;
            
            first start;
            then action applyStress {
                in force : ISQ::ForceValue = mechanicalInput.force;
                out strain : Real;
            }
            then action generateCharge {
                in strain : Real = applyStress.strain;
                out voltage : ISQ::ElectricPotentialValue;
                out current : ISQ::ElectricCurrentValue;
            }
            then action outputPower {
                in voltage : ISQ::ElectricPotentialValue = generateCharge.voltage;
                in current : ISQ::ElectricCurrentValue = generateCharge.current;
                assign electricalOutput.voltage := voltage;
                assign electricalOutput.current := current;
                assign electricalOutput.power := voltage * current;
            }
            then done;
        }
    }
    
    part def SolarHarvester {
        attribute cellType : String;
        attribute area : ISQ::AreaValue;
        attribute conversionEfficiency : Real;
        
        port energyOutput : EnergyHarvestingPort;
        
        action def ConvertLightToElectrical {
            in irradiance : ISQ::PowerValue;
            out electricalOutput : ElectricalPower;
            
            first start;
            then action capturePhotons {
                in lightPower : ISQ::PowerValue = irradiance;
                out capturedEnergy : ISQ::EnergyValue;
            }
            then action generateCurrent {
                in energy : ISQ::EnergyValue = capturePhotons.capturedEnergy;
                out voltage : ISQ::ElectricPotentialValue;
                out current : ISQ::ElectricCurrentValue;
            }
            then action outputPower {
                in voltage : ISQ::ElectricPotentialValue = generateCurrent.voltage;
                in current : ISQ::ElectricCurrentValue = generateCurrent.current;
                assign electricalOutput.voltage := voltage;
                assign electricalOutput.current := current;
                assign electricalOutput.power := voltage * current;
            }
            then done;
        }
    }
    
    part def EnergyStorageCapacitor {
        attribute capacitance : Real;
        attribute maxVoltage : ISQ::ElectricPotentialValue;
        attribute storedEnergy : ISQ::EnergyValue;
        attribute chargeLevel : Real;
        
        port storagePort : PowerSupplyPort;
        
        action def ManageEnergy {
            in inputPower : ISQ::PowerValue;
            in requestedPower : ISQ::PowerValue;
            inout energy : ISQ::EnergyValue;
            out suppliedPower : ISQ::PowerValue;
            
            first start;
            then merge continuousManagement;
            
            then decide;
                if energy < 0.1[SI::J] then chargeMode;
                if energy >= 0.8[SI::J] then readyMode;
                if energy >= 0.5[SI::J] then dischargeMode;
                
            action chargeMode {
                assign energy := energy + inputPower * 1.0[SI::s];
            }
            then continuousManagement;
            
            action readyMode {
                assign suppliedPower := 0.0[SI::W];
            }
            then continuousManagement;
            
            action dischargeMode {
                assign energy := energy - requestedPower * 1.0[SI::s];
                assign suppliedPower := requestedPower;
            }
            then continuousManagement;
        }
    }
    
    part def MultiSensor {
        attribute sensorID : Integer;
        attribute measurementInterval : ISQ::TimeValue;
        
        port sensingPort : SensingPort;
        
        action def AcquireSensorData {
            in powerSupply : ISQ::PowerValue;
            out measurements : SensorPayload;
            
            first start;
            then action measureTemperature {
                out temp : ISQ::TemperatureValue;
            }
            then action detectOccupancy {
                out occupied : Boolean;
            }
            then action measureLight {
                out lightIntensity : Real;
            }
            then action assembleMeasurements {
                in temp : ISQ::TemperatureValue = measureTemperature.temp;
                in occupied : Boolean = detectOccupancy.occupied;
                in light : Real = measureLight.lightIntensity;
                
                assign measurements.temperature := temp;
                assign measurements.occupancy := occupied;
                assign measurements.lightLevel := light;
                assign measurements.timestamp := 0.0;
            }
            then done;
        }
    }
    
    part def EnOceanRadioModule {
        attribute operatingFrequency : FrequencyValue;
        attribute transmitPower : ISQ::PowerValue;
        attribute range : ISQ::LengthValue;
        attribute protocol : ProtocolStandard;
        
        port transmitPort : RadioPort;
        
        action def TransmitTelegram {
            in powerSupply : ISQ::PowerValue;
            in sensorData : SensorPayload;
            in sourceAddr : Integer;
            in destAddr : Integer;
            out telegram : RadioTelegram;
            
            first start;
            then action encodePayload {
                in data : SensorPayload = sensorData;
                out encodedData : SensorPayload;
                
                assign encodedData := data;
            }
            then action buildTelegram {
                in encoded : SensorPayload = encodePayload.encodedData;
                in src : Integer = sourceAddr;
                in dest : Integer = destAddr;
                out message : RadioTelegram;
                
                assign message.sourceAddress := src;
                assign message.destinationAddress := dest;
                assign message.payload := encoded;
                assign message.checksum := 0;
            }
            then action transmitSignal {
                in message : RadioTelegram = buildTelegram.message;
                in txPower : ISQ::PowerValue = powerSupply;
                out signal : RadioTelegram;
                
                assign signal := message;
                assign signal.rssi := -50.0;
            }
            then action outputTelegram {
                in signal : RadioTelegram = transmitSignal.signal;
                assign telegram := signal;
            }
            then done;
        }
    }
    
    part def PowerManagementIC {
        attribute minOperatingVoltage : ISQ::ElectricPotentialValue;
        attribute maxOperatingVoltage : ISQ::ElectricPotentialValue;
        attribute regulatedOutputVoltage : ISQ::ElectricPotentialValue;
        
        action def RegulateAndDistribute {
            in harvestedPower : ISQ::PowerValue;
            in storedEnergy : ISQ::EnergyValue;
            out sensorPower : ISQ::PowerValue;
            out radioPower : ISQ::PowerValue;
            out chargingPower : ISQ::PowerValue;
            
            first start;
            then decide;
                if storedEnergy >= 0.1[SI::J] then allocatePower;
                if storedEnergy < 0.1[SI::J] then chargeOnly;
                
            action allocatePower {
                in available : ISQ::PowerValue = harvestedPower;
                assign sensorPower := 0.0001[SI::W];
                assign radioPower := 0.001[SI::W];
                assign chargingPower := available - sensorPower - radioPower;
            }
            then done;
            
            action chargeOnly {
                in available : ISQ::PowerValue = harvestedPower;
                assign sensorPower := 0.0[SI::W];
                assign radioPower := 0.0[SI::W];
                assign chargingPower := available;
            }
            then done;
        }
    }
    
    part def EnOceanSensorNode {
        attribute nodeID : Integer;
        attribute nodeLocation : String;
        
        part piezoHarvester : PiezoelectricHarvester {
            attribute material = "PZT-5H";
            attribute area = 0.0001[SI::m^2];
            attribute harvestingEfficiency = 0.25;
        }
        
        part solarHarvester : SolarHarvester {
            attribute cellType = "Amorphous Silicon";
            attribute area = 0.0004[SI::m^2];
            attribute conversionEfficiency = 0.12;
        }
        
        part energyStorage : EnergyStorageCapacitor {
            attribute capacitance = 0.001;
            attribute maxVoltage = 3.6[SI::V];
            attribute storedEnergy = 0.0[SI::J];
            attribute chargeLevel = 0.0;
        }
        
        part powerMgmt : PowerManagementIC {
            attribute minOperatingVoltage = 1.8[SI::V];
            attribute maxOperatingVoltage = 3.6[SI::V];
            attribute regulatedOutputVoltage = 3.0[SI::V];
        }
        
        part multiSensor : MultiSensor {
            attribute sensorID = nodeID;
            attribute measurementInterval = 60.0[SI::s];
        }
        
        part radioModule : EnOceanRadioModule {
            attribute operatingFrequency = 868[SI::MHz];
            attribute transmitPower = 0.001[SI::W];
            attribute range = 300[SI::m];
        }
        
        connect piezoHarvester.energyOutput to energyStorage.storagePort;
        connect solarHarvester.energyOutput to energyStorage.storagePort;
        connect energyStorage.storagePort to multiSensor.sensingPort;
        connect energyStorage.storagePort to radioModule.transmitPort;
        connect multiSensor.sensingPort to radioModule.transmitPort;
    }
    
    part def EnOceanGateway {
        attribute gatewayID : Integer;
        attribute maxConnectedNodes : Integer;
        
        port receiverPort : ReceiverPort;
        port networkPort : NetworkPort;
        
        action def ReceiveAndProcess {
            in receivedSignal : RadioTelegram;
            out processedData : SensorPayload;
            
            first start;
            then action validateTelegram {
                in telegram : RadioTelegram = receivedSignal;
                out valid : Boolean;
                out extractedPayload : SensorPayload;
                
                assign valid := true;
                assign extractedPayload := telegram.payload;
            }
            then decide;
                if validateTelegram.valid then processPayload;
                
            action processPayload {
                in payload : SensorPayload = validateTelegram.extractedPayload;
                assign processedData := payload;
            }
            then done;
        }
        
        action def ForwardToNetwork {
            in sensorData : SensorPayload;
            out networkData : SensorPayload;
            
            assign networkData := sensorData;
        }
    }
    
    part def BuildingManagementSystem {
        attribute systemID : Integer;
        attribute controlStrategy : String;
        
        port dataInput : NetworkPort;
        
        action def ProcessSensorData {
            in incomingData : SensorPayload;
            out controlDecision : String;
            
            first start;
            then action analyzeTemperature {
                in temp : ISQ::TemperatureValue = incomingData.temperature;
                out hvacCommand : String;
            }
            then action analyzeOccupancy {
                in occupied : Boolean = incomingData.occupancy;
                out lightingCommand : String;
            }
            then action generateControl {
                in hvac : String = analyzeTemperature.hvacCommand;
                in lighting : String = analyzeOccupancy.lightingCommand;
                assign controlDecision := hvac;
            }
            then done;
        }
    }
    
    action def EnOceanSystemOperation {
        first start;
        then merge continuousOperation;
        
        action harvestEnergy {
            action harvestPiezo {
                out piezoPower : ISQ::PowerValue;
            }
            action harvestSolar {
                out solarPower : ISQ::PowerValue;
            }
        }
        
        then action storeEnergy {
            in totalPower : ISQ::PowerValue;
            inout storedEnergy : ISQ::EnergyValue;
        }
        
        then decide;
            if storeEnergy.storedEnergy >= 0.15[SI::J] then operateSensor;
            if storeEnergy.storedEnergy < 0.15[SI::J] then continuousOperation;
            
        action operateSensor {
            action acquireData {
                out sensorData : SensorPayload;
            }
            then action transmitData {
                in data : SensorPayload = acquireData.sensorData;
                out telegram : RadioTelegram;
            }
            then action receiveAtGateway {
                in telegram : RadioTelegram = transmitData.telegram;
                out receivedData : SensorPayload;
            }
            then action forwardToManagement {
                in data : SensorPayload = receiveAtGateway.receivedData;
            }
        }
        
        then continuousOperation;
    }
    
    part enOceanWirelessSystem {
        part sensorNode1 : EnOceanSensorNode {
            attribute nodeID = 1001;
            attribute nodeLocation = "Conference Room A";
            
            perform action nodeOperation : EnOceanSystemOperation;
        }
        
        part sensorNode2 : EnOceanSensorNode {
            attribute nodeID = 1002;
            attribute nodeLocation = "Office 205";
            
            perform action nodeOperation : EnOceanSystemOperation;
        }
        
        part gateway : EnOceanGateway {
            attribute gatewayID = 5000;
            attribute maxConnectedNodes = 50;
        }
        
        part buildingMgmt : BuildingManagementSystem {
            attribute systemID = 9000;
            attribute controlStrategy = "Adaptive Energy Optimization";
        }
        
        connect sensorNode1.radioModule.transmitPort to gateway.receiverPort;
        connect sensorNode2.radioModule.transmitPort to gateway.receiverPort;
        connect gateway.networkPort to buildingMgmt.dataInput;
    }
    
    requirement def EnergyAutonomyRequirement {
        doc /* The sensor nodes shall operate autonomously without batteries or external 
             power by harvesting energy from ambient sources including mechanical motion 
             and solar radiation. */
        
        subject node : EnOceanSensorNode;
        
        require constraint {
            node.energyStorage.storedEnergy >= 0.0[SI::J]
        }
    }
    
    requirement def WirelessCommunicationRequirement {
        doc /* The system shall provide reliable wireless communication using the EnOcean 
             protocol at 868 MHz with a minimum range of 300 meters in open space. */
        
        subject radio : EnOceanRadioModule;
        
        require constraint {
            radio.operatingFrequency == 868[SI::MHz] and
            radio.range >= 300[SI::m]
        }
    }
    
    requirement def UltraLowPowerRequirement {
        doc /* The sensor node shall operate with ultra-low power consumption, with total 
             active power not exceeding 2 milliwatts during sensing and transmission. */
        
        subject node : EnOceanSensorNode;
    }
    
    requirement def MaintenanceFreeRequirement {
        doc /* The system shall provide maintenance-free operation for at least 10 years 
             under normal building automation conditions. */
    }
    
    requirement def DataIntegrityRequirement {
        doc /* The system shall ensure data integrity through error detection and correction 
             mechanisms with a packet error rate below 0.1%. */
    }
    
    requirement <'ENO-SYS-001'> enOceanSystemRequirement {
        doc /* The EnOcean wireless sensor network system shall provide battery-free, 
             maintenance-free building automation by harvesting ambient energy and 
             transmitting sensor data wirelessly to enable intelligent control of 
             lighting, HVAC, and other building systems. */
        
        subject enOceanWirelessSystem;
        
        require EnergyAutonomyRequirement;
        require WirelessCommunicationRequirement;
        require UltraLowPowerRequirement;
        require MaintenanceFreeRequirement;
        require DataIntegrityRequirement;
    }
}
