package GallonPerWattHourSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import USCustomaryUnits::*;
    
    attribute <h> hour : TimeUnit = 3600 * s;
    attribute <Wh> wattHour : EnergyUnit = W * h;
    attribute <gal> gallon : VolumeUnit;
    attribute <'gal/Wh'> gallonPerWattHour : DerivedUnit = gal / Wh;
    attribute <'gal/h'> gallonPerHour : DerivedUnit = gal / h;
    
    attribute def VolumeValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeUnit;
    }
    
    attribute def EnergyValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : EnergyUnit;
    }
    
    attribute def VolumePerEnergyValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : DerivedUnit;
    }
    
    attribute def PowerValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : PowerUnit;
    }
    
    attribute def FlowRateValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : DerivedUnit;
    }
    
    item def Water;
    item def ElectricalPower;
    item def ControlSignal;
    
    port def WaterPort {
        in item water : Water;
        attribute flowRate : FlowRateValue;
        attribute pressure : Real;
    }
    
    port def PowerPort {
        in item power : ElectricalPower;
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def ControlPort {
        in item signal : ControlSignal;
        attribute commandValue : Real;
    }
    
    port def DataPort {
        attribute dataValue : Real;
    }
    
    part def WaterReservoir {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        out port waterOutput : WaterPort;
    }
    
    part def PumpUnit {
        attribute maxFlowRate : FlowRateValue;
        attribute ratedPower : PowerValue;
        attribute currentSpeed : Real;
        
        in port waterInput : WaterPort;
        out port waterOutput : WaterPort;
        in port powerInput : PowerPort;
        in port speedControl : ControlPort;
    }
    
    part def EnergyMonitor {
        attribute totalEnergyConsumed : EnergyValue;
        attribute instantaneousPower : PowerValue;
        attribute samplingInterval : Real;
        
        in port powerMeasurement : PowerPort;
        out port energyData : DataPort;
    }
    
    part def FlowMonitor {
        attribute totalVolumeDelivered : VolumeValue;
        attribute instantaneousFlow : FlowRateValue;
        attribute samplingInterval : Real;
        
        in port flowMeasurement : WaterPort;
        out port volumeData : DataPort;
    }
    
    part def EfficiencyAnalyzer {
        attribute currentEfficiency : VolumePerEnergyValue;
        attribute averageEfficiency : VolumePerEnergyValue;
        attribute targetEfficiency : VolumePerEnergyValue;
        
        in port energyInput : DataPort;
        in port volumeInput : DataPort;
        out port efficiencyOutput : DataPort;
    }
    
    part def SystemController {
        attribute operatingMode : String;
        attribute optimizationEnabled : Boolean;
        attribute pumpSpeedSetpoint : Real;
        
        in port efficiencyFeedback : DataPort;
        in port startCommand;
        in port stopCommand;
        out port pumpControl : ControlPort;
    }
    
    part def DistributionNetwork {
        attribute networkPressure : Real;
        attribute deliveryPoints : Integer;
        
        in port waterInput : WaterPort;
        out port waterDelivery : WaterPort;
    }
    
    action def MeasureEnergyConsumption {
        in voltage : Real;
        in current : Real;
        in duration : Real;
        out energyConsumed : Real;
    }
    
    action def MeasureVolumeDelivered {
        in flowRate : Real;
        in duration : Real;
        out volumeDelivered : Real;
    }
    
    action def ComputeEfficiency {
        in totalVolume : Real;
        in totalEnergy : Real;
        out efficiency : Real;
    }
    
    action def OptimizePumpSpeed {
        in currentEfficiency : Real;
        in targetEfficiency : Real;
        in currentSpeed : Real;
        out adjustedSpeed : Real;
    }
    
    action def SystemOperation {
        first start;
        then merge operationLoop;
        
        then action measureEnergy : MeasureEnergyConsumption {
            in voltage;
            in current;
            in duration;
            out energyReading : Real;
        }
        
        then action measureVolume : MeasureVolumeDelivered {
            in flowRate;
            in duration;
            out volumeReading : Real;
        }
        
        then action computeEff : ComputeEfficiency {
            in totalVolume = measureVolume.volumeReading;
            in totalEnergy = measureEnergy.energyReading;
            out currentEfficiency : Real;
        }
        
        then decide;
            if computeEff.currentEfficiency < 2.0 then optimize;
            if computeEff.currentEfficiency >= 2.0 then maintain;
        
        action optimize : OptimizePumpSpeed {
            in currentEfficiency = computeEff.currentEfficiency;
            in targetEfficiency;
            in currentSpeed;
            out newSpeed : Real;
        }
        then operationLoop;
        
        action maintain;
        then operationLoop;
    }
    
    part def WaterDeliverySystem {
        doc /* An energy-efficient water delivery system that optimizes the volume 
             * of water delivered per unit of electrical energy consumed. The system 
             * continuously monitors energy consumption and water flow to maintain 
             * optimal efficiency measured in gallons per watt-hour. */
        
        attribute systemEfficiency : VolumePerEnergyValue;
        attribute targetEfficiency : VolumePerEnergyValue;
        attribute totalVolumeDelivered : VolumeValue;
        attribute totalEnergyConsumed : EnergyValue;
        attribute operationalStatus : String;
        
        part reservoir : WaterReservoir {
            attribute :>> capacity : VolumeValue;
            attribute :>> currentLevel : VolumeValue;
        }
        
        part pump : PumpUnit {
            attribute :>> maxFlowRate : FlowRateValue;
            attribute :>> ratedPower : PowerValue;
            attribute :>> currentSpeed : Real;
        }
        
        part energyMonitor : EnergyMonitor {
            attribute :>> totalEnergyConsumed : EnergyValue;
            attribute :>> instantaneousPower : PowerValue;
            attribute :>> samplingInterval : Real;
        }
        
        part flowMonitor : FlowMonitor {
            attribute :>> totalVolumeDelivered : VolumeValue;
            attribute :>> instantaneousFlow : FlowRateValue;
            attribute :>> samplingInterval : Real;
        }
        
        part analyzer : EfficiencyAnalyzer {
            attribute :>> currentEfficiency : VolumePerEnergyValue;
            attribute :>> averageEfficiency : VolumePerEnergyValue;
            attribute :>> targetEfficiency : VolumePerEnergyValue;
        }
        
        part controller : SystemController {
            attribute :>> operatingMode : String;
            attribute :>> optimizationEnabled : Boolean;
            attribute :>> pumpSpeedSetpoint : Real;
        }
        
        part distribution : DistributionNetwork {
            attribute :>> networkPressure : Real;
            attribute :>> deliveryPoints : Integer;
        }
        
        connection waterPath1 connect reservoir.waterOutput to pump.waterInput;
        connection waterPath2 connect pump.waterOutput to flowMonitor.flowMeasurement;
        connection waterPath3 connect flowMonitor.flowMeasurement to distribution.waterInput;
        
        connection powerMonitoring connect pump.powerInput to energyMonitor.powerMeasurement;
        
        connection energyDataFlow connect energyMonitor.energyData to analyzer.energyInput;
        connection volumeDataFlow connect flowMonitor.volumeData to analyzer.volumeInput;
        connection efficiencyFeedback connect analyzer.efficiencyOutput to controller.efficiencyFeedback;
        connection controlSignal connect controller.pumpControl to pump.speedControl;
        
        perform action operation : SystemOperation;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The water delivery system shall maximize the volume of water delivered 
             * per unit of electrical energy consumed, achieving optimal efficiency 
             * measured in gallons per watt-hour. */
        
        subject system : WaterDeliverySystem;
    }
    
    requirement def MinimumEfficiencyRequirement {
        doc /* The system shall maintain a minimum operational efficiency to ensure 
             * cost-effective water delivery. */
        
        subject system : WaterDeliverySystem;
        
        attribute minEfficiency : Real;
        
        require constraint {
            system.systemEfficiency.num >= minEfficiency
        }
    }
    
    requirement def TargetEfficiencyRequirement {
        doc /* The system shall achieve and maintain a target efficiency under 
             * normal operating conditions. */
        
        subject system : WaterDeliverySystem;
        
        require constraint {
            system.systemEfficiency.num >= system.targetEfficiency.num
        }
    }
    
    requirement def EnergyLimitRequirement {
        doc /* The system shall not exceed maximum energy consumption during 
             * a standard operating period. */
        
        subject system : WaterDeliverySystem;
        
        attribute maxEnergyPerCycle : Real;
        
        require constraint {
            system.totalEnergyConsumed.num <= maxEnergyPerCycle
        }
    }
    
    requirement def VolumeDeliveryRequirement {
        doc /* The system shall deliver a minimum volume of water during 
             * a standard operating period. */
        
        subject system : WaterDeliverySystem;
        
        attribute minVolumePerCycle : Real;
        
        require constraint {
            system.totalVolumeDelivered.num >= minVolumePerCycle
        }
    }
    
    requirement <'SYS-REQ-001'> systemLevelRequirement {
        doc /* The water delivery system shall operate as an energy-efficient 
             * solution for water distribution, optimizing the ratio of water 
             * volume delivered to electrical energy consumed. The system shall 
             * continuously monitor performance and adjust operating parameters 
             * to maintain optimal efficiency measured in gallons per watt-hour. */
        
        subject deliverySystem : WaterDeliverySystem;
        
        require primaryFunction : PrimaryFunctionRequirement {
            subject system :>> deliverySystem;
        }
        
        require minEfficiency : MinimumEfficiencyRequirement {
            subject system :>> deliverySystem;
            attribute :>> minEfficiency = 2.0;
        }
        
        require targetEfficiency : TargetEfficiencyRequirement {
            subject system :>> deliverySystem;
        }
        
        require energyLimit : EnergyLimitRequirement {
            subject system :>> deliverySystem;
            attribute :>> maxEnergyPerCycle = 2000.0;
        }
        
        require volumeDelivery : VolumeDeliveryRequirement {
            subject system :>> deliverySystem;
            attribute :>> minVolumePerCycle = 4000.0;
        }
    }
    
    part operationalSystem : WaterDeliverySystem {
        attribute :>> systemEfficiency : VolumePerEnergyValue {
            attribute :>> num = 2.7;
        }
        attribute :>> targetEfficiency : VolumePerEnergyValue {
            attribute :>> num = 2.5;
        }
        attribute :>> totalVolumeDelivered : VolumeValue {
            attribute :>> num = 4860.0;
        }
        attribute :>> totalEnergyConsumed : EnergyValue {
            attribute :>> num = 1800.0;
        }
        attribute :>> operationalStatus = "Active";
        
        part :>> reservoir {
            attribute :>> capacity : VolumeValue {
                attribute :>> num = 5000.0;
            }
            attribute :>> currentLevel : VolumeValue {
                attribute :>> num = 4140.0;
            }
        }
        
        part :>> pump {
            attribute :>> maxFlowRate : FlowRateValue {
                attribute :>> num = 500.0;
            }
            attribute :>> ratedPower : PowerValue {
                attribute :>> num = 200.0;
            }
            attribute :>> currentSpeed = 80.0;
        }
        
        part :>> energyMonitor {
            attribute :>> totalEnergyConsumed : EnergyValue {
                attribute :>> num = 1800.0;
            }
            attribute :>> instantaneousPower : PowerValue {
                attribute :>> num = 180.0;
            }
            attribute :>> samplingInterval = 1.0;
        }
        
        part :>> flowMonitor {
            attribute :>> totalVolumeDelivered : VolumeValue {
                attribute :>> num = 4860.0;
            }
            attribute :>> instantaneousFlow : FlowRateValue {
                attribute :>> num = 486.0;
            }
            attribute :>> samplingInterval = 1.0;
        }
        
        part :>> analyzer {
            attribute :>> currentEfficiency : VolumePerEnergyValue {
                attribute :>> num = 2.7;
            }
            attribute :>> averageEfficiency : VolumePerEnergyValue {
                attribute :>> num = 2.65;
            }
            attribute :>> targetEfficiency : VolumePerEnergyValue {
                attribute :>> num = 2.5;
            }
        }
        
        part :>> controller {
            attribute :>> operatingMode = "Automatic";
            attribute :>> optimizationEnabled = true;
            attribute :>> pumpSpeedSetpoint = 80.0;
        }
        
        part :>> distribution {
            attribute :>> networkPressure = 60.0;
            attribute :>> deliveryPoints = 12;
        }
    }
    
    satisfy systemLevelRequirement by operationalSystem;
}
