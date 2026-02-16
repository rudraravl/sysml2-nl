package XanaduHouseSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def EnergyValue :> ISQ::EnergyValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def VolumeFlowValue :> VolumeFlowRateValue;
    attribute def AreaValue :> ISQ::AreaValue;
    
    enum def OccupancyState {
        unoccupied;
        occupied;
        sleeping;
        away;
    }
    
    enum def ClimateMode {
        off;
        heating;
        cooling;
        ventilating;
        dehumidifying;
    }
    
    enum def LightingMode {
        off;
        dim;
        normal;
        bright;
    }
    
    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    item def ConditionedAir {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute flowRate : VolumeFlowValue;
    }
    
    item def Occupant {
        attribute name : String;
        attribute present : Boolean;
        attribute preferredTemperature : TemperatureValue;
    }
    
    port def PowerPort {
        in item power : ElectricalPower;
    }
    
    port def AirPort {
        in out item air : ConditionedAir;
    }
    
    port def SensorDataPort {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute occupancy : Boolean;
    }
    
    port def ControlPort {
        attribute targetTemperature : TemperatureValue;
        attribute mode : ClimateMode;
        attribute status : String;
    }
    
    part def EnvironmentalSensor {
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute motionDetected : Boolean;
        
        port sensorOutput : SensorDataPort {
            attribute :>> temperature = currentTemperature;
            attribute :>> humidity = currentHumidity;
            attribute :>> occupancy = motionDetected;
        }
    }
    
    part def FoamStructure {
        attribute wallThickness : LengthValue;
        attribute thermalResistance : Real;
        attribute structuralStrength : PressureValue;
        attribute sprayedInPlace : Boolean;
        
        assert constraint {
            thermalResistance >= 6.0
        }
    }
    
    part def ClimateControlUnit {
        attribute operatingMode : ClimateMode;
        attribute setpoint : TemperatureValue;
        attribute powerConsumption : PowerValue;
        
        port powerIn : PowerPort;
        port airSupply : AirPort;
        port airReturn : AirPort;
        port control : ControlPort;
        
        perform action regulateClimate;
    }
    
    part def AutomatedWindow {
        attribute position : Real;
        attribute tintLevel : Real;
        attribute isOpen : Boolean;
        
        exhibit state windowControl : WindowStateMachine;
    }
    
    part def LightingSystem {
        attribute brightness : Real;
        attribute colorTemperature : Real;
        attribute currentMode : LightingMode;
        attribute energyUsage : PowerValue;
        
        port powerIn : PowerPort;
    }
    
    part def SolarEnergySystem {
        attribute panelArea : AreaValue;
        attribute efficiency : Real;
        attribute currentGeneration : PowerValue;
        attribute peakGeneration : PowerValue;
        
        port powerOut : PowerPort;
    }
    
    part def EnergyStorageSystem {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute chargeRate : PowerValue;
        attribute dischargeRate : PowerValue;
        
        port gridConnection : PowerPort;
        port houseConnection : PowerPort;
    }
    
    part def CentralController {
        attribute systemState : OccupancyState;
        attribute learningEnabled : Boolean;
        attribute energyOptimizationActive : Boolean;
        
        perform action orchestrateHouse;
        exhibit state houseOperation : HouseOperationStateMachine;
    }
    
    state def WindowStateMachine {
        entry; then closed;
        
        state closed {
            do assign position = 0.0;
            do assign isOpen = false;
        }
        
        state opening;
        transition closed to opening accept openCommand;
        
        state open {
            do assign position = 1.0;
            do assign isOpen = true;
        }
        transition opening to open;
        
        state closing;
        transition open to closing accept closeCommand;
        transition closing to closed;
    }
    
    state def HouseOperationStateMachine {
        entry; then initialization;
        
        state initialization {
            do action startupSystems;
        }
        then normalOperation;
        
        state normalOperation {
            entry; then monitoring;
            
            state monitoring {
                do action monitorEnvironment;
            }
            then decide;
            
            state decide;
            if occupancyDetected then activeMode;
            if noOccupancyDetected then economyMode;
            
            state activeMode {
                do action maintainComfort;
                do action optimizeLighting;
            }
            then monitoring;
            
            state economyMode {
                do action minimizeEnergy;
            }
            then monitoring;
        }
        
        state emergency;
        transition normalOperation to emergency accept emergencySignal;
        transition emergency to normalOperation accept resetSignal;
    }
    
    action def MonitorEnvironment {
        in sensorData : SensorDataPort;
        out environmentStatus : String;
        out occupancyStatus : OccupancyState;
    }
    
    action def MaintainComfort {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in currentHumidity : HumidityValue;
        out climateCommand : ClimateMode;
        
        first start;
        then decide;
            if currentTemp < targetTemp - 2.0[K] then activateHeating;
            if currentTemp > targetTemp + 2.0[K] then activateCooling;
            if currentHumidity > 0.65 then activateDehumidifying;
            else maintainVentilation;
        
        action activateHeating {
            out command : ClimateMode = ClimateMode::heating;
        }
        then merge complete;
        
        action activateCooling {
            out command : ClimateMode = ClimateMode::cooling;
        }
        then complete;
        
        action activateDehumidifying {
            out command : ClimateMode = ClimateMode::dehumidifying;
        }
        then complete;
        
        action maintainVentilation {
            out command : ClimateMode = ClimateMode::ventilating;
        }
        then complete;
        
        merge complete;
        then done;
    }
    
    action def OptimizeEnergy {
        in solarGeneration : PowerValue;
        in houseConsumption : PowerValue;
        in batteryCharge : EnergyValue;
        out energyStrategy : String;
        
        first start;
        then decide;
            if solarGeneration > houseConsumption then storeSurplus;
            if solarGeneration < houseConsumption and batteryCharge > 1000.0[W*h] then useBattery;
            else useGrid;
        
        action storeSurplus;
        then merge end;
        
        action useBattery;
        then end;
        
        action useGrid;
        then end;
        
        merge end;
        then done;
    }
    
    action def OrchestrateHouse {
        first start;
        then merge continuousControl;
        
        then action monitor : MonitorEnvironment;
        
        then decide;
            if monitor.occupancyStatus == OccupancyState::occupied then activeControl;
            if monitor.occupancyStatus == OccupancyState::unoccupied then passiveControl;
        
        action activeControl {
            action comfort : MaintainComfort;
            action energy : OptimizeEnergy;
        }
        then continuousControl;
        
        action passiveControl {
            action energy : OptimizeEnergy;
        }
        then continuousControl;
    }
    
    part def XanaduHouse {
        doc /* The Xanadu House is an automated, energy-efficient dwelling 
             * constructed from sprayed polyurethane foam. Its primary function 
             * is to provide comfortable, affordable living through intelligent 
             * environmental control, renewable energy integration, and adaptive 
             * automation that learns occupant preferences while minimizing 
             * energy consumption and operating costs.
             */
        
        attribute houseIdentifier : String;
        attribute totalFloorArea : AreaValue;
        attribute numberOfRooms : Integer;
        attribute currentOccupancy : OccupancyState;
        
        part structure : FoamStructure {
            attribute :>> wallThickness = 150.0[mm];
            attribute :>> thermalResistance = 7.5;
            attribute :>> structuralStrength = 200.0[kPa];
            attribute :>> sprayedInPlace = true;
        }
        
        part sensors : EnvironmentalSensor[8] {
            attribute :>> currentTemperature : TemperatureValue;
            attribute :>> currentHumidity : HumidityValue;
            attribute :>> motionDetected : Boolean;
        }
        
        part climate : ClimateControlUnit {
            attribute :>> operatingMode = ClimateMode::off;
            attribute :>> setpoint = 294.15[K];
            attribute :>> powerConsumption : PowerValue;
        }
        
        part windows : AutomatedWindow[16] {
            attribute :>> position = 0.0;
            attribute :>> tintLevel = 0.3;
            attribute :>> isOpen = false;
        }
        
        part lighting : LightingSystem {
            attribute :>> brightness = 0.6;
            attribute :>> colorTemperature = 3500.0;
            attribute :>> currentMode = LightingMode::normal;
            attribute :>> energyUsage : PowerValue;
        }
        
        part solar : SolarEnergySystem {
            attribute :>> panelArea = 50.0[m^2];
            attribute :>> efficiency = 0.22;
            attribute :>> peakGeneration = 8000.0[W];
            attribute :>> currentGeneration : PowerValue;
        }
        
        part battery : EnergyStorageSystem {
            attribute :>> capacity = 15000.0[W*h];
            attribute :>> currentCharge : EnergyValue;
            attribute :>> chargeRate = 3000.0[W];
            attribute :>> dischargeRate = 5000.0[W];
        }
        
        part controller : CentralController {
            attribute :>> systemState = OccupancyState::unoccupied;
            attribute :>> learningEnabled = true;
            attribute :>> energyOptimizationActive = true;
            
            perform action houseControl : OrchestrateHouse;
        }
        
        item occupants : Occupant[0..6] {
            attribute :>> name : String;
            attribute :>> present : Boolean;
            attribute :>> preferredTemperature = 294.15[K];
        }
        
        connection sensorToController connect sensors[1].sensorOutput to controller;
        connection climateControl connect controller to climate.control;
        connection solarToBattery connect solar.powerOut to battery.gridConnection;
        connection batteryToHouse connect battery.houseConnection to climate.powerIn;
        connection batteryToLighting connect battery.houseConnection to lighting.powerIn;
    }
    
    requirement <'XAN-REQ-001'> primaryFunction {
        doc /* The Xanadu House system shall provide an automated, comfortable, 
             * and energy-efficient living environment through intelligent 
             * environmental control and renewable energy integration.
             */
        subject house : XanaduHouse;
    }
    
    requirement <'XAN-REQ-002'> thermalPerformance {
        doc /* The foam structure shall provide superior thermal insulation 
             * with a minimum R-value of 6.0 to minimize heating and cooling loads.
             */
        subject structure : XanaduHouse::structure;
        
        assert constraint {
            structure.thermalResistance >= 6.0
        }
    }
    
    requirement <'XAN-REQ-003'> climateControl {
        doc /* The climate control system shall maintain interior temperature 
             * within ±2K of the setpoint during occupied periods.
             */
        subject climate : XanaduHouse::climate;
        
        assert constraint {
            climate.setpoint >= 291.15[K] and climate.setpoint <= 297.15[K]
        }
    }
    
    requirement <'XAN-REQ-004'> energyIndependence {
        doc /* The solar energy system shall generate sufficient power to meet 
             * average daily household consumption with battery storage for 
             * nighttime and cloudy conditions.
             */
        subject energySystem : XanaduHouse;
        
        assert constraint {
            energySystem.solar.peakGeneration >= 6000.0[W] and
            energySystem.battery.capacity >= 12000.0[W*h]
        }
    }
    
    requirement <'XAN-REQ-005'> automation {
        doc /* The central controller shall automatically adjust all house 
             * systems based on occupancy patterns, environmental conditions, 
             * and learned preferences.
             */
        subject controller : XanaduHouse::controller;
        
        assert constraint {
            controller.learningEnabled == true and
            controller.energyOptimizationActive == true
        }
    }
    
    requirement <'XAN-REQ-006'> affordability {
        doc /* The construction method using sprayed foam shall reduce 
             * building costs while maintaining structural integrity.
             */
        subject structure : XanaduHouse::structure;
        
        assert constraint {
            structure.sprayedInPlace == true and
            structure.structuralStrength >= 150.0[kPa]
        }
    }
    
    part xanaduPrototype : XanaduHouse {
        attribute :>> houseIdentifier = "XANADU-PROTO-001";
        attribute :>> totalFloorArea = 185.0[m^2];
        attribute :>> numberOfRooms = 4;
        attribute :>> currentOccupancy = OccupancyState::occupied;
        
        part :>> structure {
            attribute :>> wallThickness = 200.0[mm];
            attribute :>> thermalResistance = 8.2;
        }
        
        part :>> climate {
            attribute :>> setpoint = 293.15[K];
            attribute :>> operatingMode = ClimateMode::heating;
        }
        
        part :>> solar {
            attribute :>> currentGeneration = 6500.0[W];
        }
        
        part :>> battery {
            attribute :>> currentCharge = 12000.0[W*h];
        }
    }
    
    satisfy primaryFunction by xanaduPrototype;
    satisfy thermalPerformance by xanaduPrototype.structure;
    satisfy climateControl by xanaduPrototype.climate;
    satisfy energyIndependence by xanaduPrototype;
    satisfy automation by xanaduPrototype.controller;
    satisfy affordability by xanaduPrototype.structure;
}
