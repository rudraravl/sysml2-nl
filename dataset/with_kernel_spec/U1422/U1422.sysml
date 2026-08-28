package 'Automated Gasoline Additive System' {
    private import ScalarValues::*;
    
    attribute def OctaneRating :> Real;
    attribute def AdditiveConcentration :> Real;
    attribute def AdditiveVolume :> Real;
    attribute def FlowRate :> Real;
    
    item def Fuel;
    item def BaseGasoline :> Fuel;
    item def Additive;
    item def BlendedFuel :> Fuel;
    
    attribute def FlowStartSignal;
    attribute def FlowStopSignal;
    attribute def QualityCheckSignal;
    
    port def FuelOutPort { out fuel : Fuel; }
    port def FuelInPort { in fuel : Fuel; }
    port def AdditiveOutPort { out additive : Additive; }
    port def AdditiveInPort { in additive : Additive; }
    port def FlowSignalOutPort { out flowRate : FlowRate; }
    port def FlowSignalInPort { in flowRate : FlowRate; }
    port def QualitySignalOutPort { 
        out octane : OctaneRating; 
        out concentration : AdditiveConcentration; 
    }
    port def QualitySignalInPort { 
        in octane : OctaneRating; 
        in concentration : AdditiveConcentration; 
    }
    port def CommandOutPort { out volume : AdditiveVolume; }
    port def CommandInPort { in volume : AdditiveVolume; }
    
    part def FuelTank {
        port fuelOut : FuelOutPort;
    }
    part def AdditiveReservoir {
        port additiveOut : AdditiveOutPort;
    }
    part def FlowSensor {
        port fuelIn : FuelInPort;
        port fuelOut : FuelOutPort;
        port signalOut : FlowSignalOutPort;
    }
    part def QualitySensor {
        port fuelIn : FuelInPort;
        port fuelOut : FuelOutPort;
        port signalOut : QualitySignalOutPort;
    }
    part def DosingPump {
        port additiveIn : AdditiveInPort;
        port additiveOut : AdditiveOutPort;
        port commandIn : CommandInPort;
    }
    part def MixingChamber {
        port fuelIn : FuelInPort;
        port additiveIn : AdditiveInPort;
        port fuelOut : FuelOutPort;
    }
    
    part def SystemController {
        port flowSignalIn : FlowSignalInPort;
        port qualitySignalIn : QualitySignalInPort;
        port commandOut : CommandOutPort;
        
        attribute targetOctane : OctaneRating = 93;
        attribute targetConcentration : AdditiveConcentration = 0.1;
        
        state def ControllerStates;
        state controllerStates : ControllerStates {
            entry; then idle;
            state idle;
            accept FlowStartSignal then monitoring;
            state monitoring;
            accept QualityCheckSignal if qualitySignalIn.octane < targetOctane then treating;
            accept FlowStopSignal then idle;
            state treating {
                entry action calculateDosage {
                    in currentOctane : OctaneRating = qualitySignalIn.octane;
                    in target : OctaneRating = targetOctane;
                    out dosage : AdditiveVolume;
                }
                do action injectAdditive {
                    in dosage : AdditiveVolume = calculateDosage.dosage;
                }
            }
            accept QualityCheckSignal if qualitySignalIn.octane >= targetOctane and qualitySignalIn.concentration >= targetConcentration then monitoring;
            accept QualityCheckSignal if qualitySignalIn.octane < targetOctane then treating;
            accept FlowStopSignal then idle;
        }
    }
    
    part additiveSystem {
        part fuelTank : FuelTank;
        part additiveReservoir : AdditiveReservoir;
        part flowSensor : FlowSensor;
        part qualitySensor : QualitySensor;
        part dosingPump : DosingPump;
        part mixingChamber : MixingChamber;
        part controller : SystemController;
        
        flow of BaseGasoline from fuelTank.fuelOut.fuel to flowSensor.fuelIn.fuel;
        flow of BaseGasoline from flowSensor.fuelOut.fuel to mixingChamber.fuelIn.fuel;
        flow of Additive from additiveReservoir.additiveOut.additive to dosingPump.additiveIn.additive;
        flow of Additive from dosingPump.additiveOut.additive to mixingChamber.additiveIn.additive;
        flow of BlendedFuel from mixingChamber.fuelOut.fuel to qualitySensor.fuelIn.fuel;
        
        flow of FlowRate from flowSensor.signalOut.flowRate to controller.flowSignalIn.flowRate;
        flow of OctaneRating from qualitySensor.signalOut.octane to controller.qualitySignalIn.octane;
        flow of AdditiveConcentration from qualitySensor.signalOut.concentration to controller.qualitySignalIn.concentration;
        flow of AdditiveVolume from controller.commandOut.volume to dosingPump.commandIn.volume;
    }
    
    requirement def Req_OctaneTarget {
        doc /* The system shall maintain a minimum octane rating of 93 for the blended fuel. */
    }
    requirement def Req_FeedbackControl {
        doc /* The controller shall adjust additive dosage based on real-time quality sensor readings until specifications are met. */
    }
    requirement def Req_SafetyMixing {
        doc /* The mixing chamber shall ensure thorough and efficient blending of additives into the base gasoline. */
    }
    
    requirement octaneTarget : Req_OctaneTarget {
        satisfiedBy additiveSystem.controller;
    }
    requirement feedbackControl : Req_FeedbackControl {
        satisfiedBy additiveSystem.controller;
        satisfiedBy additiveSystem.dosingPump;
        satisfiedBy additiveSystem.qualitySensor;
    }
    requirement safetyMixing : Req_SafetyMixing {
        satisfiedBy additiveSystem.mixingChamber;
    }
}
