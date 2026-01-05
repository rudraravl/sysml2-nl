package RefrigeratorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> ISQ::TemperatureValue;
    attribute def HumidityLevel :> Real;
    
    attribute def DoorState {
        attribute isOpen : Boolean;
    }
    
    attribute def CompressorState {
        attribute isRunning : Boolean;
        attribute speed : Real;
    }
    
    item def Refrigerant {
        attribute pressure :> ISQ::PressureValue;
        attribute temperature :> ISQ::TemperatureValue;
        attribute flowRate :> ISQ::VolumeFlowRateValue;
        attribute phase : String;
    }
    
    port def ThermalPort {
        attribute temperature :> ISQ::TemperatureValue;
        attribute heatTransferRate :> ISQ::PowerValue;
    }
    
    port def ElectricalPort {
        attribute voltage :> ISQ::VoltageValue;
        attribute current :> ISQ::ElectricCurrentValue;
        attribute power :> ISQ::PowerValue;
    }
    
    port def RefrigerantPort {
        item refrigerant : Refrigerant;
    }
    
    part def Compressor {
        port electricalIn : ElectricalPort;
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        
        attribute state : CompressorState;
        attribute efficiency : Real;
        attribute powerConsumption :> ISQ::PowerValue;
        attribute compressionRatio : Real;
    }
    
    part def Condenser {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port ambientExchange : ThermalPort;
        
        attribute heatRejectionRate :> ISQ::PowerValue;
        attribute surfaceArea :> ISQ::AreaValue;
    }
    
    part def ExpansionValve {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        
        attribute openingPercentage : Real;
        attribute pressureDrop :> ISQ::PressureValue;
    }
    
    part def Evaporator {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port interiorExchange : ThermalPort;
        
        attribute heatAbsorptionRate :> ISQ::PowerValue;
        attribute surfaceArea :> ISQ::AreaValue;
        attribute frostLevel : Real;
    }
    
    part def TemperatureSensor {
        port sensingPoint : ThermalPort;
        
        attribute measuredTemperature :> ISQ::TemperatureValue;
        attribute accuracy :> ISQ::TemperatureValue;
        attribute sampleRate :> ISQ::FrequencyValue;
    }
    
    part def DoorSensor {
        attribute doorState : DoorState;
        attribute switchType : String;
    }
    
    part def Controller {
        port powerIn : ElectricalPort;
        
        attribute targetTemperature :> ISQ::TemperatureValue;
        attribute currentTemperature :> ISQ::TemperatureValue;
        attribute temperatureHysteresis :> ISQ::TemperatureValue;
        attribute doorOpen : Boolean;
        attribute compressorCommand : CompressorState;
        attribute defrostTimer :> ISQ::TimeValue;
    }
    
    part def InteriorCompartment {
        port thermalBoundary : ThermalPort;
        
        attribute volume :> ISQ::VolumeValue;
        attribute temperature :> ISQ::TemperatureValue;
        attribute humidity : HumidityLevel;
        attribute airCirculationRate :> ISQ::VolumeFlowRateValue;
    }
    
    part def InsulationSystem {
        attribute thermalResistance : Real;
        attribute thickness :> ISQ::LengthValue;
        attribute material : String;
    }
    
    part def Fan {
        port electricalIn : ElectricalPort;
        
        attribute speed :> ISQ::AngularVelocityValue;
        attribute airFlowRate :> ISQ::VolumeFlowRateValue;
        attribute isRunning : Boolean;
    }
    
    action def MonitorTemperature {
        in currentTemp :> ISQ::TemperatureValue;
        in setpoint :> ISQ::TemperatureValue;
        in hysteresis :> ISQ::TemperatureValue;
        out temperatureDelta :> ISQ::TemperatureValue;
        out needsCooling : Boolean;
    }
    
    action def CheckDoorStatus {
        in doorSensor : DoorState;
        out isDoorOpen : Boolean;
    }
    
    action def ControlCompressor {
        in needsCooling : Boolean;
        in doorOpen : Boolean;
        in currentState : CompressorState;
        out newState : CompressorState;
    }
    
    action def CirculateRefrigerant {
        in compressorState : CompressorState;
        in evaporatorTemp :> ISQ::TemperatureValue;
        in condenserTemp :> ISQ::TemperatureValue;
        out coolingPower :> ISQ::PowerValue;
    }
    
    action def ManageFan {
        in compressorRunning : Boolean;
        in interiorTemp :> ISQ::TemperatureValue;
        out fanSpeed :> ISQ::AngularVelocityValue;
    }
    
    action def MaintainTemperature {
        in setpoint :> ISQ::TemperatureValue;
        in hysteresis :> ISQ::TemperatureValue;
        in doorState : DoorState;
        out interiorTemp :> ISQ::TemperatureValue;
        out powerUsed :> ISQ::PowerValue;
        
        first start;
        then merge continueCycle;
        
        then action monitorTemp : MonitorTemperature {
            in currentTemp;
            in setpoint = MaintainTemperature::setpoint;
            in hysteresis = MaintainTemperature::hysteresis;
            out temperatureDelta;
            out needsCooling;
        }
        
        then action checkDoor : CheckDoorStatus {
            in doorSensor = doorState;
            out isDoorOpen;
        }
        
        then decide;
            if monitorTemp.needsCooling and not checkDoor.isDoorOpen then startCooling;
            if not monitorTemp.needsCooling then stopCooling;
            else continueCycle;
        
        action startCooling : ControlCompressor {
            in needsCooling = monitorTemp.needsCooling;
            in doorOpen = checkDoor.isDoorOpen;
            in currentState;
            out newState;
        }
        then action circulate : CirculateRefrigerant {
            in compressorState = startCooling.newState;
            in evaporatorTemp;
            in condenserTemp;
            out coolingPower;
        }
        then action manageFan : ManageFan {
            in compressorRunning = startCooling.newState.isRunning;
            in interiorTemp;
            out fanSpeed;
        }
        then continueCycle;
        
        action stopCooling : ControlCompressor {
            in needsCooling = false;
            in doorOpen = checkDoor.isDoorOpen;
            in currentState;
            out newState;
        }
        then continueCycle;
    }
    
    part def Refrigerator {
        attribute targetTemp : TemperatureSetpoint;
        attribute tempHysteresis :> ISQ::TemperatureValue;
        attribute maxPowerConsumption :> ISQ::PowerValue;
        attribute nominalVoltage :> ISQ::VoltageValue;
        
        part interior : InteriorCompartment;
        part insulation : InsulationSystem;
        part compressor : Compressor;
        part condenser : Condenser;
        part expansionValve : ExpansionValve;
        part evaporator : Evaporator;
        part interiorFan : Fan;
        part condenserFan : Fan;
        part tempSensor : TemperatureSensor;
        part doorSensor : DoorSensor;
        part controller : Controller;
        part powerSupply {
            port electricalOut : ElectricalPort;
        }
    }
    
    part refrigerator : Refrigerator {
        attribute targetTemp = 277.15[K];
        attribute tempHysteresis = 1.0[K];
        attribute maxPowerConsumption = 200.0[W];
        attribute nominalVoltage = 120.0[V];
        
        part interior : InteriorCompartment {
            attribute volume = 0.35[m^3];
            attribute temperature = 277.15[K];
            attribute humidity = 0.65;
        }
        
        part insulation : InsulationSystem {
            attribute thickness = 0.06[m];
            attribute material = "Polyurethane Foam";
            attribute thermalResistance = 4.5;
        }
        
        part compressor : Compressor {
            attribute efficiency = 0.82;
            attribute compressionRatio = 4.5;
        }
        
        part condenser : Condenser {
            attribute surfaceArea = 1.2[m^2];
        }
        
        part expansionValve : ExpansionValve {
            attribute openingPercentage = 45.0;
        }
        
        part evaporator : Evaporator {
            attribute surfaceArea = 0.8[m^2];
            attribute frostLevel = 0.0;
        }
        
        part interiorFan : Fan {
            attribute airFlowRate = 0.05[m^3/s];
        }
        
        part condenserFan : Fan {
            attribute airFlowRate = 0.08[m^3/s];
        }
        
        part tempSensor : TemperatureSensor {
            attribute accuracy = 0.5[K];
            attribute sampleRate = 0.1[Hz];
        }
        
        part doorSensor : DoorSensor {
            attribute switchType = "Magnetic Reed";
        }
        
        part controller : Controller {
            attribute targetTemperature = targetTemp;
            attribute temperatureHysteresis = tempHysteresis;
        }
        
        part powerSupply {
            port electricalOut : ElectricalPort {
                attribute voltage = nominalVoltage;
            }
        }
        
        connect compressor.refrigerantOut to condenser.refrigerantIn;
        connect condenser.refrigerantOut to expansionValve.refrigerantIn;
        connect expansionValve.refrigerantOut to evaporator.refrigerantIn;
        connect evaporator.refrigerantOut to compressor.refrigerantIn;
        
        connect evaporator.interiorExchange to interior.thermalBoundary;
        connect tempSensor.sensingPoint to interior.thermalBoundary;
        
        connect powerSupply.electricalOut to compressor.electricalIn;
        connect powerSupply.electricalOut to controller.powerIn;
        connect powerSupply.electricalOut to interiorFan.electricalIn;
        connect powerSupply.electricalOut to condenserFan.electricalIn;
        
        perform action maintainTemp : MaintainTemperature {
            in setpoint = targetTemp;
            in hysteresis = tempHysteresis;
            in doorState = doorSensor.doorState;
            out interiorTemp;
            out powerUsed;
        }
    }
    
    requirement def FoodPreservationRequirement {
        doc /* The refrigerator shall preserve food by maintaining a controlled low temperature environment. */
        
        subject refrigeratorSystem : Refrigerator;
        
        require constraint temperatureRange {
            refrigeratorSystem.interior.temperature >= 275.15[K] and
            refrigeratorSystem.interior.temperature <= 279.15[K]
        }
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The refrigerator shall operate within maximum power consumption limits. */
        
        subject refrigeratorSystem : Refrigerator;
        
        require constraint powerLimit {
            refrigeratorSystem.compressor.powerConsumption <= refrigeratorSystem.maxPowerConsumption
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The refrigerator shall operate safely under all conditions. */
        
        subject refrigeratorSystem : Refrigerator;
        
        require constraint pressureSafety {
            refrigeratorSystem.compressor.refrigerantOut.refrigerant.pressure <= 2.8[MPa]
        }
        
        require constraint temperatureSafety {
            refrigeratorSystem.condenser.refrigerantIn.refrigerant.temperature <= 358.15[K]
        }
    }
    
    requirement <'REF-001'> primaryFunctionRequirement : FoodPreservationRequirement {
        doc /* The refrigerator system shall preserve perishable food items by maintaining a stable, controlled low temperature environment through continuous vapor-compression refrigeration cycle operation. */
        
        subject refrigerator;
        
        assume constraint ambientConditions {
            refrigerator.condenser.ambientExchange.temperature >= 291.15[K] and
            refrigerator.condenser.ambientExchange.temperature <= 308.15[K]
        }
        
        assume constraint normalOperation {
            refrigerator.doorSensor.doorState.isOpen == false
        }
        
        require constraint coolingPerformance {
            refrigerator.interior.temperature >= 275.15[K] and
            refrigerator.interior.temperature <= 279.15[K]
        }
        
        require constraint humidityControl {
            refrigerator.interior.humidity >= 0.55 and
            refrigerator.interior.humidity <= 0.75
        }
        
        require energyEfficiency : EnergyEfficiencyRequirement;
        require safety : SafetyRequirement;
    }
}
