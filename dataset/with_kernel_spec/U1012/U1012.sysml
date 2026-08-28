package ClothesDryerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def Air {
            attribute temperature : ISQ::temperature;
            attribute humidity : ScalarValues::Real;
        }
        item def Lint;
        
        attribute def CycleSelection;
        attribute def StartSignal;
        attribute def StopSignal;
        attribute def DoorOpenSignal;
        attribute def DoorClosedSignal;
        attribute def TargetDrynessReached;
        attribute def OverTempAlert;
        attribute def CooldownComplete;
        
        part def Drum {
            port airInPort { in air : Air; }
            port airOutPort { out humidAir : Air; }
            port drivePort { in torque : ISQ::torque; }
            attribute capacity : ISQ::mass;
        }
        
        part def DriveMotor {
            port drivePort { out torque : ISQ::torque; }
            port controlPort { in controlSignal : Boolean; }
            attribute speed : ISQ::angularVelocity;
        }
        
        part def Blower {
            port airIntakePort { in ambientAir : Air; }
            port airOutputPort { out air : Air; }
            port controlPort { in controlSignal : Boolean; }
            attribute flowRate : ISQ::volumeFlowRate;
        }
        
        part def HeatingElement {
            port airInPort { in air : Air; }
            port airOutPort { out heatedAir : Air; }
            port controlPort { in controlSignal : Boolean; }
            attribute powerOutput : ISQ::power;
        }
        
        part def LintFilter {
            port airInPort { in humidAir : Air; }
            port airOutPort { out filteredAir : Air; }
            port lintPort { out lint : Lint; }
        }
        
        part def ExhaustDuct {
            port airInPort { in air : Air; }
        }
        
        part def ControlModule {
            port panelPort { in selection : CycleSelection; }
            port tempPort { in tempReading : ISQ::temperature; }
            port moisturePort { in moistureReading : ScalarValues::Real; }
            port doorPort { in doorStatus : Boolean; }
            port motorControlPort { out motorControl : Boolean; }
            port heaterControlPort { out heaterControl : Boolean; }
            port blowerControlPort { out blowerControl : Boolean; }
        }
        
        part def ControlPanel {
            port outputPort { out selection : CycleSelection; }
        }
        
        part def TemperatureSensor {
            port outputPort { out tempReading : ISQ::temperature; }
            attribute temperature : ISQ::temperature;
        }
        
        part def MoistureSensor {
            port outputPort { out moistureReading : ScalarValues::Real; }
            attribute moisture : ScalarValues::Real;
        }
        
        part def Door {
            attribute closed : Boolean;
            port statusPort { out doorStatus : Boolean; }
        }
        
        action def TumbleDrum {
            in drum : Drum;
            in motor : DriveMotor;
        }
        
        action def HeatAir {
            in element : HeatingElement;
            in blower : Blower;
        }
        
        action def CirculateAir {
            in blower : Blower;
            in drum : Drum;
        }
        
        action def CoolDown {
            in blower : Blower;
            in drum : Drum;
            in motor : DriveMotor;
        }
        
        requirement def DrynessRequirement {
            doc /* The dryer shall reduce the moisture level of the laundry to the user-selected target dryness. */
            attribute targetDryness : ScalarValues::Real;
            attribute actualMoisture : ScalarValues::Real;
            assert constraint { actualMoisture <= targetDryness }
        }
        
        requirement def DoorSafetyRequirement {
            doc /* The dryer shall not operate if the door is open, and shall immediately stop if the door is opened during operation. */
            attribute doorClosed : Boolean;
            attribute systemOperating : Boolean;
            assert constraint { systemOperating implies doorClosed }
        }
        
        requirement def OverheatRequirement {
            doc /* The heating element shall not exceed the maximum safe operating temperature. */
            attribute currentTemperature : ISQ::temperature;
            attribute maxTemperature : ISQ::temperature;
            assert constraint { currentTemperature <= maxTemperature }
        }
        
        requirement def CooldownRequirement {
            doc /* At the end of the drying cycle, a cool-down phase shall run to reduce the temperature of the laundry. */
            attribute coolDownDuration : ISQ::duration;
            assert constraint { coolDownDuration >= 300 [s] }
        }
        
        part def ClothesDryer {
            attribute targetDryness : ScalarValues::Real;
            attribute currentMoisture : ScalarValues::Real;
            attribute currentTemp : ISQ::temperature;
            attribute maxTemp : ISQ::temperature;
            attribute doorClosed : Boolean;
            
            part drum : Drum;
            part driveMotor : DriveMotor;
            part blower : Blower;
            part heatingElement : HeatingElement;
            part lintFilter : LintFilter;
            part exhaustDuct : ExhaustDuct;
            part controlModule : ControlModule;
            part controlPanel : ControlPanel;
            part tempSensor : TemperatureSensor;
            part moistureSensor : MoistureSensor;
            part door : Door;
            
            flow ambientAirFlow of Air from blower.airOutputPort to heatingElement.airInPort;
            flow heatedAirFlow of Air from heatingElement.airOutPort to drum.airInPort;
            flow humidAirFlow of Air from drum.airOutPort to lintFilter.airInPort;
            flow filteredAirFlow of Air from lintFilter.airOutPort to exhaustDuct.airInPort;
            
            connect tempSensor.outputPort to controlModule.tempPort;
            connect moistureSensor.outputPort to controlModule.moisturePort;
            connect controlPanel.outputPort to controlModule.panelPort;
            connect door.statusPort to controlModule.doorPort;
            connect controlModule.motorControlPort to driveMotor.controlPort;
            connect controlModule.heaterControlPort to heatingElement.controlPort;
            connect controlModule.blowerControlPort to blower.controlPort;
            
            perform action tumbleDrum;
            perform action heatAir;
            perform action circulateAir;
            perform action coolDown;
            
            exhibit state dryerStates {
                entry; then idle;
                state idle;
                accept StartSignal if door.closed then drying;
                state drying;
                accept TargetDrynessReached then cooldown;
                accept DoorOpenSignal then idle;
                accept OverTempAlert then cooldown;
                state cooldown;
                accept CooldownComplete then done;
                accept DoorOpenSignal then idle;
                state done;
                accept StopSignal then idle;
            }
            
            requirement drynessReq : DrynessRequirement;
            requirement doorSafetyReq : DoorSafetyRequirement;
            requirement overheatReq : OverheatRequirement;
            requirement cooldownReq : CooldownRequirement;
            
            satisfy drynessReq;
            satisfy doorSafetyReq;
            satisfy overheatReq;
            satisfy cooldownReq;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part dryerSystem : ClothesDryer {
            attribute targetDryness = 0.15;
            attribute maxTemp = 150.0 [degC];
            attribute doorClosed = true;
            
            part :>> drum : Drum {
                attribute capacity = 10.0 [kg];
            }
            part :>> driveMotor : DriveMotor {
                attribute speed = 5.24 [rad/s];
            }
            part :>> blower : Blower {
                attribute flowRate = 0.1 [m^3/s];
            }
            part :>> heatingElement : HeatingElement {
                attribute powerOutput = 5000.0 [W];
            }
            part :>> lintFilter : LintFilter;
            part :>> exhaustDuct : ExhaustDuct;
            part :>> controlModule : ControlModule;
            part :>> controlPanel : ControlPanel;
            part :>> tempSensor : TemperatureSensor {
                attribute temperature = 22.0 [degC];
            }
            part :>> moistureSensor : MoistureSensor {
                attribute moisture = 0.80;
            }
            part :>> door : Door {
                attribute closed = true;
            }
        }
    }
}
