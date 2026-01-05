package 'Jet Aeration System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DissolvedOxygenConcentration :> ISQ::MassConcentrationValue;
    
    attribute def WaterFlowRate :> ISQ::VolumetricFlowRateValue;
    
    attribute def AirFlowRate :> ISQ::VolumetricFlowRateValue;
    
    attribute def PressureValue :> ISQ::PressureValue;
    
    attribute def PowerValue :> ISQ::PowerValue;
    
    attribute def EfficiencyValue :> Real;
    
    attribute def WaterQuality {
        attribute dissolvedOxygen : DissolvedOxygenConcentration;
        attribute temperature : ISQ::TemperatureValue;
        attribute pH : Real;
    }
    
    item def Wastewater {
        attribute quality : WaterQuality;
        attribute flowRate : WaterFlowRate;
    }
    
    item def CompressedAir {
        attribute flowRate : AirFlowRate;
        attribute pressure : PressureValue;
    }
    
    port def WaterInletPort {
        in item wastewater : Wastewater;
    }
    
    port def WaterOutletPort {
        out item treatedWater : Wastewater;
    }
    
    port def AirSupplyPort {
        in item compressedAir : CompressedAir;
    }
    
    port def PowerSupplyPort {
        in attribute power : PowerValue;
    }
    
    part def WaterPump {
        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
        port powerIn : PowerSupplyPort;
        
        attribute designFlowRate : WaterFlowRate;
        attribute dischargePressure : PressureValue;
        attribute efficiency : EfficiencyValue;
        attribute powerConsumption : PowerValue;
    }
    
    part def AirCompressor {
        port airIn {
            in attribute atmosphericAir : AirFlowRate;
        }
        port airOut : AirSupplyPort;
        port powerIn : PowerSupplyPort;
        
        attribute compressionRatio : Real;
        attribute deliveryPressure : PressureValue;
        attribute airDeliveryRate : AirFlowRate;
        attribute powerConsumption : PowerValue;
    }
    
    part def JetNozzle {
        port waterIn : WaterOutletPort;
        port airIn : AirSupplyPort;
        port mixedOut {
            out item aeratedWater : Wastewater;
        }
        
        attribute nozzleDiameter : ISQ::LengthValue;
        attribute throatVelocity : ISQ::SpeedValue;
        attribute mixingEfficiency : EfficiencyValue;
        attribute oxygenTransferRate : Real;
    }
    
    part def AerationBasin {
        port mixedIn {
            in item aeratedWater : Wastewater;
        }
        port treatedOut : WaterOutletPort;
        
        attribute basinVolume : ISQ::VolumeValue;
        attribute retentionTime : ISQ::TimeValue;
        attribute currentDO : DissolvedOxygenConcentration;
        attribute targetDO : DissolvedOxygenConcentration;
    }
    
    part def DOSensor {
        port sampleIn {
            in item waterSample : Wastewater;
        }
        port measurementOut {
            out attribute measuredDO : DissolvedOxygenConcentration;
        }
        
        attribute sensorAccuracy : Real;
        attribute responseTime : ISQ::TimeValue;
    }
    
    part def ControlSystem {
        port doInput {
            in attribute currentDO : DissolvedOxygenConcentration;
        }
        port setpointInput {
            in attribute targetDO : DissolvedOxygenConcentration;
        }
        port airFlowOutput {
            out attribute commandedAirFlow : AirFlowRate;
        }
        port pumpOutput {
            out attribute pumpCommand : Boolean;
        }
        
        attribute controlMode : String;
        attribute pidParameters : Real[3];
    }
    
    action def CompressAir {
        in atmosphericAir : AirFlowRate;
        in targetPressure : PressureValue;
        out compressedAir : CompressedAir;
        out powerUsed : PowerValue;
    }
    
    action def PumpWater {
        in influentWater : Wastewater;
        in targetFlowRate : WaterFlowRate;
        out pressurizedWater : Wastewater;
        out powerUsed : PowerValue;
    }
    
    action def MixAirAndWater {
        in pressurizedWater : Wastewater;
        in compressedAir : CompressedAir;
        out aeratedMixture : Wastewater;
        out oxygenTransferred : Real;
    }
    
    action def DiffuseOxygen {
        in aeratedMixture : Wastewater;
        in retentionTime : ISQ::TimeValue;
        in basinVolume : ISQ::VolumeValue;
        out treatedWater : Wastewater;
        out finalDO : DissolvedOxygenConcentration;
    }
    
    action def MeasureDO {
        in waterSample : Wastewater;
        out measuredDO : DissolvedOxygenConcentration;
    }
    
    action def ControlAeration {
        in measuredDO : DissolvedOxygenConcentration;
        in targetDO : DissolvedOxygenConcentration;
        out airFlowAdjustment : AirFlowRate;
        out pumpControl : Boolean;
    }
    
    action def PerformJetAeration {
        in influentWater : Wastewater;
        in targetOxygenLevel : DissolvedOxygenConcentration;
        out effluentWater : Wastewater;
        
        first start;
        then merge continuousOperation;
        
        then action compressAir : CompressAir {
            in atmosphericAir;
            in targetPressure;
            out compressedAir;
            out powerUsed;
        }
        
        flow compressAir.compressedAir to mixAirWater.compressedAir;
        
        then action pumpWater : PumpWater {
            in influentWater = PerformJetAeration::influentWater;
            in targetFlowRate;
            out pressurizedWater;
            out powerUsed;
        }
        
        flow pumpWater.pressurizedWater to mixAirWater.pressurizedWater;
        
        then action mixAirWater : MixAirAndWater {
            in pressurizedWater;
            in compressedAir;
            out aeratedMixture;
            out oxygenTransferred;
        }
        
        flow mixAirWater.aeratedMixture to diffuseOxygen.aeratedMixture;
        
        then action diffuseOxygen : DiffuseOxygen {
            in aeratedMixture;
            in retentionTime;
            in basinVolume;
            out treatedWater;
            out finalDO;
        }
        
        flow diffuseOxygen.treatedWater to measureDO.waterSample;
        
        then action measureDO : MeasureDO {
            in waterSample;
            out measuredDO;
        }
        
        flow measureDO.measuredDO to controlAeration.measuredDO;
        
        then action controlAeration : ControlAeration {
            in measuredDO;
            in targetDO = targetOxygenLevel;
            out airFlowAdjustment;
            out pumpControl;
        }
        
        then decide;
            if measureDO.measuredDO < targetOxygenLevel then continuousOperation;
            if measureDO.measuredDO >= targetOxygenLevel then done;
    }
    
    part def JetAeratorSystem {
        attribute operatingMode : String;
        attribute systemEfficiency : EfficiencyValue;
        
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port atmosphericAirIntake {
            in attribute ambientAir : AirFlowRate;
        }
        port electricalPower : PowerSupplyPort;
        
        part waterPump : WaterPump;
        part airCompressor : AirCompressor;
        part jetNozzle : JetNozzle;
        part aerationBasin : AerationBasin;
        part doSensor : DOSensor;
        part controller : ControlSystem;
        
        connect waterInlet to waterPump.waterIn;
        connect waterPump.waterOut to jetNozzle.waterIn;
        connect atmosphericAirIntake to airCompressor.airIn;
        connect airCompressor.airOut to jetNozzle.airIn;
        connect jetNozzle.mixedOut to aerationBasin.mixedIn;
        connect aerationBasin.treatedOut to waterOutlet;
        connect aerationBasin.treatedOut to doSensor.sampleIn;
        connect doSensor.measurementOut to controller.doInput;
        connect controller.airFlowOutput to airCompressor.airOut;
        connect controller.pumpOutput to waterPump.powerIn;
        connect electricalPower to waterPump.powerIn;
        connect electricalPower to airCompressor.powerIn;
        
        perform action aerationProcess : PerformJetAeration {
            in influentWater;
            in targetOxygenLevel = aerationBasin.targetDO;
            out effluentWater;
        }
    }
    
    part jetAeratorSystem : JetAeratorSystem {
        attribute :>> operatingMode = "Continuous";
        attribute :>> systemEfficiency = 0.82;
    }
    
    requirement def OxygenTransferRequirement {
        doc /* The jet aerator system shall achieve a minimum oxygen transfer efficiency 
               of 80% under standard operating conditions to ensure effective wastewater treatment. */
        
        subject system : JetAeratorSystem;
        
        require constraint {
            system.jetNozzle.mixingEfficiency >= 0.80
        }
    }
    
    requirement def DissolvedOxygenTargetRequirement {
        doc /* The system shall maintain dissolved oxygen concentration in the aeration basin 
               at a minimum of 2.0 mg/L to support aerobic biological processes. */
        
        subject system : JetAeratorSystem;
        
        require constraint {
            system.aerationBasin.currentDO >= 2.0
        }
    }
    
    requirement def WaterTreatmentCapacityRequirement {
        doc /* The system shall process a minimum water flow rate of 500 cubic meters per hour 
               to meet the facility treatment capacity requirements. */
        
        subject system : JetAeratorSystem;
        
        require constraint {
            system.waterPump.designFlowRate >= 500.0
        }
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall operate with an overall energy efficiency of at least 75% 
               to minimize operational costs and environmental impact. */
        
        subject system : JetAeratorSystem;
        
        require constraint {
            system.systemEfficiency >= 0.75
        }
    }
    
    requirement def SystemReliabilityRequirement {
        doc /* The jet aerator system shall maintain continuous operation with a minimum 
               uptime of 95% to ensure consistent wastewater treatment performance. */
        
        subject system : JetAeratorSystem;
    }
    
    requirement primarySystemRequirements {
        doc /* Top-level requirements for the jet aerator system to effectively oxygenate 
               wastewater through high-velocity jet mixing for biological treatment processes. */
        
        require oxygenTransferReq : OxygenTransferRequirement;
        require doTargetReq : DissolvedOxygenTargetRequirement;
        require treatmentCapacityReq : WaterTreatmentCapacityRequirement;
        require energyEfficiencyReq : EnergyEfficiencyRequirement;
        require systemReliabilityReq : SystemReliabilityRequirement;
    }
}
