package XanaduHouse {
    package ValueTypes {
        attribute def TemperatureValue :> Real { unit 'C'; }
        attribute def HumidityValue :> Real { unit '%'; }
        attribute def BrightnessValue :> Real { unit 'lm'; }
        attribute def ColorTempValue :> Real { unit 'K'; }
        attribute def TintValue :> Real { unit '%'; }
        attribute def PowerValue :> Real { unit 'W'; }
        attribute def EnergyValue :> Real { unit 'Wh'; }
        
        enum def OccupancyState { occupied; unoccupied; sleeping; }
        enum def ClimateMode { heating; cooling; ventilating; dehumidifying; idle; }
        enum def LightingMode { normal; dim; off; }
        enum def PowerSource { solar; battery; grid; }
    }
    
    package Items {
        item def SensorData {
            attribute temp : ValueTypes::TemperatureValue;
            attribute humidity : ValueTypes::HumidityValue;
            attribute motionDetected : Boolean;
        }
        item def ClimateCommand {
            attribute mode : ValueTypes::ClimateMode;
            attribute targetTemp : ValueTypes::TemperatureValue;
        }
        item def LightingCommand {
            attribute mode : ValueTypes::LightingMode;
            attribute brightness : ValueTypes::BrightnessValue;
            attribute colorTemp : ValueTypes::ColorTempValue;
        }
        item def WindowCommand {
            attribute open : Boolean;
            attribute tint : ValueTypes::TintValue;
        }
        item def ElectricalPower {
            attribute power : ValueTypes::PowerValue;
            attribute source : ValueTypes::PowerSource;
        }
    }
    
    package Components {
        part def EnvironmentalSensor {
            port dataOut : out Items::SensorData;
            attribute id : String;
        }
        
        part def CentralController {
            port sensorIn : in Items::SensorData;
            port climateCmdOut : out Items::ClimateCommand;
            port lightingCmdOut : out Items::LightingCommand;
            port windowCmdOut : out Items::WindowCommand;
            
            attribute currentOccupancy : ValueTypes::OccupancyState;
            
            state def OccupancyBehavior {
                entry; then unoccupied;
                
                state unoccupied;
                state occupied;
                state sleeping;
                
                transition unoccupied_to_occupied
                    first unoccupied
                    accept s : Items::SensorData
                    if s.motionDetected == true
                    then occupied;
                
                transition occupied_to_unoccupied
                    first occupied
                    accept s : Items::SensorData
                    if s.motionDetected == false
                    then unoccupied;
                
                transition occupied_to_sleeping
                    first occupied
                    accept s : Items::SensorData
                    if s.motionDetected == false and s.temp < 20
                    then sleeping;
            }
            
            exhibit state OccupancyBehavior;
        }
        
        part def ClimateControlUnit {
            port cmdIn : in Items::ClimateCommand;
            port powerIn : in Items::ElectricalPower;
            attribute currentMode : ValueTypes::ClimateMode;
        }
        
        part def LightingSystem {
            port cmdIn : in Items::LightingCommand;
            port powerIn : in Items::ElectricalPower;
            attribute currentMode : ValueTypes::LightingMode;
        }
        
        part def AutomatedWindow {
            port cmdIn : in Items::WindowCommand;
            port powerIn : in Items::ElectricalPower;
            attribute currentTint : ValueTypes::TintValue;
            attribute isOpen : Boolean;
        }
        
        part def SolarEnergySystem {
            port powerOut : out Items::ElectricalPower;
            attribute generationRate : ValueTypes::PowerValue;
        }
        
        part def EnergyStorageSystem {
            port powerIn : in Items::ElectricalPower;
            port powerOut : out Items::ElectricalPower;
            attribute capacity : ValueTypes::EnergyValue;
            attribute currentCharge : ValueTypes::EnergyValue;
        }
        
        part def GridPower {
            port powerOut : out Items::ElectricalPower;
        }
        
        part def FoamStructure {
            attribute insulationRValue : Real;
        }
    }
    
    package System {
        part def XanaduHouseSystem {
            part structure : Components::FoamStructure;
            
            part controller : Components::CentralController;
            part sensors[8] : Components::EnvironmentalSensor;
            part hvac : Components::ClimateControlUnit;
            part lighting : Components::LightingSystem;
            part windows[16] : Components::AutomatedWindow;
            part solar : Components::SolarEnergySystem;
            part battery : Components::EnergyStorageSystem;
            part grid : Components::GridPower;
            
            connect sensors.dataOut to controller.sensorIn;
            connect controller.climateCmdOut to hvac.cmdIn;
            connect controller.lightingCmdOut to lighting.cmdIn;
            connect controller.windowCmdOut to windows.cmdIn;
            
            connect solar.powerOut to battery.powerIn;
            connect solar.powerOut to hvac.powerIn;
            connect solar.powerOut to lighting.powerIn;
            connect solar.powerOut to windows.powerIn;
            
            connect battery.powerOut to hvac.powerIn;
            connect battery.powerOut to lighting.powerIn;
            connect battery.powerOut to windows.powerIn;
            
            connect grid.powerOut to hvac.powerIn;
            connect grid.powerOut to lighting.powerIn;
            connect grid.powerOut to windows.powerIn;
        }
    }
    
    package Requirements {
        requirement def EnergyEfficiency {
            doc /* The house must minimize energy consumption through intelligent automation, renewable energy generation, and superior insulation. */
        }
        requirement def ComfortableLiving {
            doc /* The house must provide a comfortable living environment. */
        }
        requirement def AutomatedControl {
            doc /* The Central Controller must orchestrate all systems based on occupancy state. */
        }
        requirement def RenewableEnergy {
            doc /* The house must generate its own electrical power using a Solar Energy System. */
        }
        requirement def AdaptiveLearning {
            doc /* The system must learn occupant habits over time to optimize comfort and energy use. */
        }
    }
}
