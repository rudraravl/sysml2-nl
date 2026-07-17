package WaterTurbineSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def FlowRateValue :> Real;
    attribute def RotationalSpeedValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def EfficiencyValue :> Real;
    attribute def AngleValue :> Real;
    
    item def Water {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute velocity : SpeedValue;
        attribute kineticEnergy : EnergyValue;
        attribute potentialEnergy : EnergyValue;
    }
    
    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute power : PowerValue;
    }
    
    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : PowerValue;
        attribute frequency : Real;
    }
    
    port def WaterInletPort {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute headHeight : LengthValue;
    }
    
    port def WaterOutletPort {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute power : PowerValue;
    }
    
    port def ElectricalPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : PowerValue;
    }
    
    port def ControlPort {
        attribute targetSpeed : RotationalSpeedValue;
        attribute currentSpeed : RotationalSpeedValue;
        attribute gatePosition : AngleValue;
    }
    
    part def SpiralCasing {
        attribute inletDiameter : LengthValue;
        attribute m :> mass;
        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
    }
    
    part def GuideVane {
        attribute vaneAngle : AngleValue;
        attribute maxAngle : AngleValue = 90.0;
        attribute minAngle : AngleValue = 0.0;
    }
    
    part def RunnerBlade {
        attribute bladeAngle : AngleValue;
        attribute bladeSurface : AreaValue;
        attribute m :> mass;
    }
    
    part def Runner {
        attribute diameter : LengthValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute m :> mass;
        part blades : RunnerBlade[16];
        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
        port mechanicalOut : MechanicalPort;
    }
    
    part def DraftTube {
        attribute outletDiameter : LengthValue;
        attribute length : LengthValue;
        attribute m :> mass;
        port waterIn : WaterOutletPort;
        port waterOut : WaterOutletPort;
    }
    
    part def Shaft {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
        attribute m :> mass;
        attribute rotationalSpeed : RotationalSpeedValue;
        port mechanicalIn : MechanicalPort;
        port mechanicalOut : MechanicalPort;
    }
    
    part def Generator {
        attribute ratedPower : PowerValue;
        attribute efficiency : EfficiencyValue;
        attribute voltage : Real;
        attribute frequency : Real;
        attribute m :> mass;
        port mechanicalIn : MechanicalPort;
        port electricalOut : ElectricalPort;
    }
    
    part def GovernorSystem {
        attribute responseTime : DurationValue;
        attribute proportionalGain : Real;
        attribute integralGain : Real;
        port speedSensor : ControlPort;
        port vaneControl : ControlPort;
    }
    
    part def BearingAssembly {
        attribute bearingType : String;
        attribute loadCapacity : ForceValue;
        attribute m :> mass;
    }
    
    action def MonitorWaterFlow {
        in waterInlet : WaterInletPort;
        out measuredFlowRate : FlowRateValue;
        out measuredPressure : PressureValue;
        out measuredHead : LengthValue;
    }
    
    action def CalculateHydraulicPower {
        in flowRate : FlowRateValue;
        in headHeight : LengthValue;
        out hydraulicPower : PowerValue;
    }
    
    action def ControlGuideVanes {
        in targetSpeed : RotationalSpeedValue;
        in currentSpeed : RotationalSpeedValue;
        in powerDemand : PowerValue;
        out vaneAngle : AngleValue;
    }
    
    action def ConvertHydraulicToMechanical {
        in hydraulicPower : PowerValue;
        in turbineEfficiency : EfficiencyValue;
        out mechanicalPower : PowerValue;
        out torque : TorqueValue;
        out rotationalSpeed : RotationalSpeedValue;
    }
    
    action def GenerateElectricity {
        in mechanicalPower : PowerValue;
        in generatorEfficiency : EfficiencyValue;
        out electricalPower : PowerValue;
    }
    
    action def TurbineOperation {
        first start;
        then merge continuousOperation;
        
        action monitorFlow : MonitorWaterFlow {
            out measuredFlowRate;
            out measuredPressure;
            out measuredHead;
        }
        
        then action calculatePower : CalculateHydraulicPower {
            in flowRate = monitorFlow.measuredFlowRate;
            in headHeight = monitorFlow.measuredHead;
            out hydraulicPower;
        }
        
        then action controlVanes : ControlGuideVanes {
            out vaneAngle;
        }
        
        then action convertEnergy : ConvertHydraulicToMechanical {
            in hydraulicPower = calculatePower.hydraulicPower;
            out mechanicalPower;
            out torque;
            out rotationalSpeed;
        }
        
        then action generatePower : GenerateElectricity {
            in mechanicalPower = convertEnergy.mechanicalPower;
            out electricalPower;
        }
        
        then continuousOperation;
        then done;
    }
    
    part def WaterTurbine {
        attribute ratedPower : PowerValue;
        attribute ratedHead : LengthValue;
        attribute ratedFlowRate : FlowRateValue;
        attribute ratedSpeed : RotationalSpeedValue;
        attribute overallEfficiency : EfficiencyValue;
        attribute totalMass : MassValue;
        
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port mechanicalOutput : MechanicalPort;
        port electricalOutput : ElectricalPort;
        port controlInterface : ControlPort;
        
        part spiralCasing : SpiralCasing {
            attribute :>> inletDiameter = 3.2 [m];
            attribute :>> m = 7500 [kg];
        }
        
        part guideVanes : GuideVane[20] {
            attribute :>> maxAngle = 90.0;
            attribute :>> minAngle = 0.0;
        }
        
        part runner : Runner {
            attribute :>> diameter = 2.5 [m];
            attribute :>> m = 10000 [kg];
        }
        
        part draftTube : DraftTube {
            attribute :>> outletDiameter = 4.0 [m];
            attribute :>> length = 5.5 [m];
            attribute :>> m = 5500 [kg];
        }
        
        part shaft : Shaft {
            attribute :>> diameter = 0.4 [m];
            attribute :>> length = 7.0 [m];
            attribute :>> m = 2800 [kg];
        }
        
        part bearings : BearingAssembly[2] {
            attribute :>> bearingType = "Hydrodynamic";
            attribute :>> loadCapacity = 450000 [N];
            attribute :>> m = 800 [kg];
        }
        
        part generator : Generator {
            attribute :>> ratedPower = 40000000 [W];
            attribute :>> efficiency = 0.96;
            attribute :>> voltage = 13800;
            attribute :>> frequency = 60;
            attribute :>> m = 8500 [kg];
        }
        
        part governor : GovernorSystem {
            attribute :>> responseTime = 4.5 [s];
            attribute :>> proportionalGain = 0.8;
            attribute :>> integralGain = 0.3;
        }
        
        connect waterInlet to spiralCasing.waterIn;
        connect spiralCasing.waterOut to runner.waterIn;
        connect runner.waterOut to draftTube.waterIn;
        connect draftTube.waterOut to waterOutlet;
        connect runner.mechanicalOut to shaft.mechanicalIn;
        connect shaft.mechanicalOut to generator.mechanicalIn;
        connect generator.electricalOut to electricalOutput;
        connect governor.speedSensor to controlInterface;
        
        perform action turbineOperation : TurbineOperation;
    }
    
    part waterTurbineSystem : WaterTurbine {
        attribute :>> ratedPower = 40000000 [W];
        attribute :>> ratedHead = 75.0 [m];
        attribute :>> ratedFlowRate = 60.0;
        attribute :>> ratedSpeed = 140.0;
        attribute :>> overallEfficiency = 0.91;
        attribute :>> totalMass = spiralCasing.m + runner.m + draftTube.m + shaft.m + 2 * bearings.m + generator.m + 1500 [kg];
        
        assert constraint massLimit {
            totalMass <= 38000 [kg]
        }
        
        assert constraint efficiencyRequirement {
            overallEfficiency >= 0.88
        }
        
        assert constraint powerOutput {
            electricalOutput.power >= 0.93 * ratedPower
        }
    }
    
    requirement <'REQ-WT-001'> primaryFunction {
        doc /* The water turbine system shall convert the kinetic and potential 
             * energy of flowing water into rotational mechanical energy, which 
             * drives an electrical generator to produce electrical power for 
             * distribution to the power grid.
             */
        subject turbine : WaterTurbine;
    }
    
    requirement <'REQ-WT-002'> efficiencyRequirement {
        doc /* The water turbine shall achieve a minimum overall efficiency of 88% 
             * at rated operating conditions to ensure effective energy conversion.
             */
        subject turbine :>> waterTurbineSystem;
        assert constraint {
            turbine.overallEfficiency >= 0.88
        }
    }
    
    requirement <'REQ-WT-003'> powerOutputRequirement {
        doc /* The water turbine shall deliver rated electrical power output of 
             * 40 MW at rated head and flow conditions.
             */
        subject turbine :>> waterTurbineSystem;
        assert constraint {
            turbine.ratedPower == 40000000 [W]
        }
    }
    
    requirement <'REQ-WT-004'> massConstraint {
        doc /* The total mass of the water turbine assembly shall not exceed 
             * 38,000 kg to meet installation and structural requirements.
             */
        subject turbine :>> waterTurbineSystem;
        assert constraint {
            turbine.totalMass <= 38000 [kg]
        }
    }
    
    requirement <'REQ-WT-005'> speedRegulation {
        doc /* The governor system shall maintain rotational speed within ±2% 
             * of rated speed under varying load conditions.
             */
        subject governor :>> waterTurbineSystem.governor;
    }
    
    satisfy primaryFunction by waterTurbineSystem;
    satisfy efficiencyRequirement by waterTurbineSystem;
    satisfy powerOutputRequirement by waterTurbineSystem;
    satisfy massConstraint by waterTurbineSystem;
    satisfy speedRegulation by waterTurbineSystem.governor;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import WaterTurbineSystem::*;

    action orchestrator {
        action monitorFlowProbe : MonitorWaterFlow {
            // TODO(human): unsupported input type for waterInlet: WaterInletPort (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first monitorFlowProbe;
    }
}
