package LiquidCoolingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def TemperatureThreshold :> TemperatureValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;

    item def Coolant {
        attribute density : MassDensityValue;
        attribute specificHeat : SpecificHeatCapacityValue;
        attribute currentTemperature : TemperatureValue;
    }

    port def CoolantPort {
        in item coolantIn : Coolant;
        out item coolantOut : Coolant;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    part def HeatSource {
        attribute operatingTemperature : TemperatureValue;
        attribute heatGeneration : PowerValue;
        port thermalInterface : CoolantPort;
    }

    part def TemperatureSensor {
        in attribute measuredTemp : TemperatureValue;
        out attribute sensorReading : TemperatureValue;
        action def ReadTemperature {
            in temp : TemperatureValue;
            out reading : TemperatureValue = temp;
        }
    }

    part def Pump {
        attribute nominalFlowRate : FlowRateValue;
        attribute currentSpeed : ScalarValues::Real;
        attribute powerConsumption : PowerValue;
        port inlet : CoolantPort;
        port outlet : CoolantPort;
        
        state def PumpOperationStates {
            entry; then Standby;
            state Standby;
            state Running;
            state HighSpeed;
            
            transition first Standby
                accept at Standby
                if currentSpeed > 0.0
                then Running;
            transition
                accept at Running
                if currentSpeed > 0.8
                then HighSpeed;
            transition
                accept at HighSpeed
                if currentSpeed <= 0.8
                then Running;
            transition
                accept at Running
                if currentSpeed == 0.0
                then Standby;
        }
        
        action def SetSpeed {
            in targetSpeed : ScalarValues::Real;
            out appliedSpeed : ScalarValues::Real = targetSpeed;
        }
    }

    part def HeatExchanger {
        attribute coolingCapacity : PowerValue;
        attribute ambientTemperature : TemperatureValue;
        port coolantInlet : CoolantPort;
        port coolantOutlet : CoolantPort;
        
        action def DissipateHeat {
            in inletTemp : TemperatureValue;
            in flowRate : FlowRateValue;
            out outletTemp : TemperatureValue;
        }
    }

    part def FlowValve {
        attribute position : ScalarValues::Real;
        port inlet : CoolantPort;
        port outlet : CoolantPort;
        
        action def AdjustPosition {
            in targetPosition : ScalarValues::Real;
            out actualPosition : ScalarValues::Real = targetPosition;
        }
    }

    part def CoolingController {
        attribute targetTemperature : TemperatureThreshold;
        attribute currentTemperature : TemperatureValue;
        attribute maxTemperature : TemperatureThreshold;
        
        state def ThermalControlStates {
            entry; then Monitoring;
            state Monitoring;
            state CoolingActive;
            state MaxCooling;
            state Shutdown;
            
            transition first Monitoring
                accept at Monitoring
                if currentTemperature > targetTemperature
                then CoolingActive;
            transition
                accept at CoolingActive
                if currentTemperature > maxTemperature - 10.0[K]
                then MaxCooling;
            transition
                accept at MaxCooling
                if currentTemperature <= targetTemperature + 5.0[K]
                then CoolingActive;
            transition
                accept at CoolingActive
                if currentTemperature <= targetTemperature - 5.0[K]
                then Monitoring;
            transition
                accept at MaxCooling
                if currentTemperature > maxTemperature
                then Shutdown;
        }
        
        action def RegulateTemperature {
            in measuredTemp : TemperatureValue;
            in target : TemperatureThreshold;
            out pumpSpeed : ScalarValues::Real;
            out valvePosition : ScalarValues::Real;
        }
    }

    constraint def TemperatureLimit {
        in actualTemp : TemperatureValue;
        in maxTemp : TemperatureThreshold;
        actualTemp <= maxTemp
    }

    constraint def FlowRateRange {
        in flowRate : FlowRateValue;
        in minFlow : FlowRateValue;
        in maxFlow : FlowRateValue;
        flowRate >= minFlow and flowRate <= maxFlow
    }

    action def MonitorAndControl {
        in source : HeatSource;
        in sensor : TemperatureSensor;
        in controller : CoolingController;
        in pump : Pump;
        in valve : FlowValve;
        
        first start;
        then merge controlLoop;
        then action readTemp : TemperatureSensor::ReadTemperature {
            in temp = source.operatingTemperature;
        }
        then decide;
            if controller.currentTemperature > controller.targetTemperature then activateCooling;
            if controller.currentTemperature <= controller.targetTemperature then maintainCooling;
        action activateCooling : CoolingController::RegulateTemperature {
            in measuredTemp = controller.currentTemperature;
            in target = controller.targetTemperature;
        }
        then action setPump : Pump::SetSpeed {
            in targetSpeed = activateCooling.pumpSpeed;
        }
        then action setValve : FlowValve::AdjustPosition {
            in targetPosition = activateCooling.valvePosition;
        }
        then controlLoop;
        action maintainCooling : CoolingController::RegulateTemperature {
            in measuredTemp = controller.currentTemperature;
            in target = controller.targetTemperature;
        }
        then controlLoop;
    }

    connection def CoolantLine {
        end source : CoolantPort;
        end destination : CoolantPort;
    }

    part def LiquidCoolingSystem {
        attribute systemTemperature : TemperatureValue;
        attribute systemFlowRate : FlowRateValue;
        
        part heatSource : HeatSource {
            attribute :>> operatingTemperature : TemperatureValue;
            attribute :>> heatGeneration = 250.0[W];
        }
        
        part tempSensor : TemperatureSensor {
            in :>> measuredTemp = heatSource.operatingTemperature;
        }
        
        part controller : CoolingController {
            attribute :>> targetTemperature = 348.15[K];
            attribute :>> maxTemperature = 368.15[K];
            in :>> currentTemperature = tempSensor.sensorReading;
        }
        
        part pump : Pump {
            attribute :>> nominalFlowRate = 0.00003333[m^3/s];
            attribute :>> currentSpeed = 0.0;
            attribute :>> powerConsumption = 15.0[W];
        }
        
        part valve : FlowValve {
            attribute :>> position = 0.5;
        }
        
        part heatExchanger : HeatExchanger {
            attribute :>> coolingCapacity = 300.0[W];
            attribute :>> ambientTemperature = 298.15[K];
        }
        
        connection line1 : CoolantLine {
            end source = pump.outlet;
            end destination = heatSource.thermalInterface;
        }
        
        connection line2 : CoolantLine {
            end source = heatSource.thermalInterface;
            end destination = valve.inlet;
        }
        
        connection line3 : CoolantLine {
            end source = valve.outlet;
            end destination = heatExchanger.coolantInlet;
        }
        
        connection line4 : CoolantLine {
            end source = heatExchanger.coolantOutlet;
            end destination = pump.inlet;
        }
        
        perform action systemControl : MonitorAndControl {
            in source = heatSource;
            in sensor = tempSensor;
            in controller = controller;
            in pump = pump;
            in valve = valve;
        }
        
        assert constraint tempLimit : TemperatureLimit {
            in actualTemp = heatSource.operatingTemperature;
            in maxTemp = controller.maxTemperature;
        }
        
        assert constraint flowLimit : FlowRateRange {
            in flowRate = systemFlowRate;
            in minFlow = 0.0000083333[m^3/s];
            in maxFlow = 0.0000833333[m^3/s];
        }
    }

    requirement <'REQ-100'> primaryCoolingFunction {
        doc /* The liquid cooling system shall maintain the heat source temperature 
             * at or below the target operating temperature by circulating coolant 
             * through a closed loop with active thermal regulation. */
        subject system : LiquidCoolingSystem;
        require constraint {
            system.heatSource.operatingTemperature <= system.controller.targetTemperature + 10.0[K]
        }
    }

    requirement <'REQ-101'> temperatureSafety {
        doc /* The system shall prevent the heat source from exceeding the maximum 
             * safe operating temperature under all operating conditions. */
        subject source :>> LiquidCoolingSystem::heatSource;
        require constraint {
            source.operatingTemperature <= 368.15[K]
        }
    }

    requirement <'REQ-102'> flowRegulation {
        doc /* The system shall maintain coolant flow rate within specified operational 
             * limits to ensure effective heat transfer. */
        subject system :>> LiquidCoolingSystem;
        require constraint {
            system.systemFlowRate >= 0.0000083333[m^3/s] and system.systemFlowRate <= 0.0000833333[m^3/s]
        }
    }

    part coolingSystemInstance : LiquidCoolingSystem;
    
    satisfy primaryCoolingFunction by coolingSystemInstance;
    satisfy temperatureSafety by coolingSystemInstance.heatSource;
    satisfy flowRegulation by coolingSystemInstance;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import LiquidCoolingSystem::*;

    part testSubject : HeatSource {
        exhibit state sm : PumpOperationStates;
    }

    action orchestrator {
        action activateCoolingProbe : CoolingController {
            // TODO(human): unsupported input type for measuredTemp: unknown (missing declared type)
            // TODO(human): unsupported input type for target: unknown (missing declared type)
        }
        first activateCoolingProbe;
    }
}
