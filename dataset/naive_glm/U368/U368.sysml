package RheotraumaTestSystem {
    import SI::*;
    
    value type FlowRateValue :> Real { unit "L/min"; }
    value type ShearStressValue :> Real { unit "Pa"; }
    value type TemperatureValue :> Real { unit "degC"; }
    value type DamageIndexValue :> Real { unit "1"; }
    value type ViabilityValue :> Real { unit "%"; }
    value type PumpSpeedValue :> Real { unit "RPM"; }
    
    item def BaseFluid;
    item def BloodSample;
    item def SensorData {
        attribute value : Real;
        attribute unit : String;
    }
    
    port def FluidPort {
        in item fluidIn : BaseFluid;
        out item fluidOut : BaseFluid;
    }
    port def BloodPort {
        in item bloodIn : BloodSample;
        out item bloodOut : BloodSample;
    }
    port def SensorOutPort {
        out item sensorData : SensorData;
    }
    port def SensorInPort {
        in item sensorData : SensorData;
    }
    port def ControlOutPort {
        out item controlSignal : Real;
    }
    port def ControlInPort {
        in item controlSignal : Real;
    }
    
    requirement def RheotraumaTestSystemRequirements {
        requirement MaintainShearStress {
            doc /* The system shall maintain the target shear stress within +/- 5%. */
        }
        requirement MaintainTemperature {
            doc /* The system shall maintain the temperature at 37 degC +/- 0.5 degC. */
        }
        requirement EmergencyShutdown {
            doc /* The system shall perform an emergency shutdown if critical faults are detected. */
        }
    }
    
    part def FluidReservoir {
        port fluidOutPort : FluidPort;
        port fluidInPort : FluidPort;
        attribute volume : Real;
    }
    
    part def PrecisionPump {
        port fluidInPort : FluidPort;
        port fluidOutPort : FluidPort;
        port controlInPort : ControlInPort;
        attribute speed : PumpSpeedValue;
    }
    
    part def ShearChamber {
        port fluidInPort : FluidPort;
        port fluidOutPort : FluidPort;
        port bloodInPort : BloodPort;
        port bloodOutPort : BloodPort;
        attribute currentShearStress : ShearStressValue;
    }
    
    part def DamageAnalyzer {
        port bloodInPort : BloodPort;
        port sensorOutPort : SensorOutPort;
        attribute damageIndex : DamageIndexValue;
        attribute cellViability : ViabilityValue;
        
        action def AnalyzeSample {
            in sample : BloodSample;
            out index : DamageIndexValue;
            out viability : ViabilityValue;
        }
    }
    
    part def ShearStressSensor {
        port sensorOutPort : SensorOutPort;
        attribute measuredStress : ShearStressValue;
    }
    
    part def FlowRateSensor {
        port sensorOutPort : SensorOutPort;
        attribute measuredFlowRate : FlowRateValue;
    }
    
    part def TemperatureController {
        port controlInPort : ControlInPort;
        port sensorOutPort : SensorOutPort;
        attribute currentTemp : TemperatureValue;
    }
    
    part def SystemController {
        port shearStressSensorPort : SensorInPort;
        port flowRateSensorPort : SensorInPort;
        port tempSensorPort : SensorInPort;
        port analyzerSensorPort : SensorInPort;
        
        port pumpControlPort : ControlOutPort;
        port tempControlPort : ControlOutPort;
        
        attribute targetShearStress : ShearStressValue = 10.0 [Pa];
        attribute targetTemperature : TemperatureValue = 37.0 [degC];
        
        state machine def ControllerStates {
            state Initialization;
            state Calibration;
            state Running;
            state DataProcessing;
            state Standby;
            state EmergencyShutdown;
            
            transition initial to Initialization;
            transition from Initialization to Calibration;
            transition from Calibration to Running;
            transition from Running to DataProcessing;
            transition from DataProcessing to Standby;
            transition from Standby to Running;
            transition from Running to EmergencyShutdown;
        }
    }
    
    part def RheotraumaTestSystem {
        requirement systemRequirements : RheotraumaTestSystemRequirements;
        
        part reservoir : FluidReservoir;
        part pump : PrecisionPump;
        part chamber : ShearChamber;
        part analyzer : DamageAnalyzer;
        part shearSensor : ShearStressSensor;
        part flowSensor : FlowRateSensor;
        part tempController : TemperatureController;
        part controller : SystemController;
        
        connection fluidConn1 connect reservoir.fluidOutPort to pump.fluidInPort;
        connection fluidConn2 connect pump.fluidOutPort to chamber.fluidInPort;
        connection fluidConn3 connect chamber.fluidOutPort to reservoir.fluidInPort;
        
        connection bloodConn1 connect chamber.bloodOutPort to analyzer.bloodInPort;
        
        connection sensorConn1 connect shearSensor.sensorOutPort to controller.shearStressSensorPort;
        connection sensorConn2 connect flowSensor.sensorOutPort to controller.flowRateSensorPort;
        connection tempConn1 connect tempController.sensorOutPort to controller.tempSensorPort;
        connection tempConn2 connect controller.tempControlPort to tempController.controlInPort;
        connection pumpConn connect controller.pumpControlPort to pump.controlInPort;
        connection analyzerConn connect analyzer.sensorOutPort to controller.analyzerSensorPort;
        
        satisfy systemRequirements by controller;
    }
}
