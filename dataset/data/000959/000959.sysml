package WoodScrewPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def Fluid {
            attribute density : Real = 1000.0;
            attribute viscosity : Real = 0.001;
            attribute temperature : Real = 293.15;
        }
        
        attribute def VolumeFlowRate :> Real;
        attribute def Pressure :> Real;
        attribute def AngularVelocity :> Real;
        attribute def Power :> Real;
        attribute def Length :> Real;
        attribute def Volume :> Real;
        attribute def Torque :> Real;
        
        port def FluidPort {
            out item fluid : Fluid;
            attribute pressure : Pressure;
            attribute flowRate : VolumeFlowRate;
        }
        
        port def MechanicalPowerPort {
            attribute torque : Torque;
            attribute angularVelocity : AngularVelocity;
            attribute power : Power;
        }
        
        part def SumpReservoir {
            attribute capacity : Volume = 5000.0;
            attribute currentLevel : Length = 1.5;
            attribute minLevel : Length = 0.2;
            attribute maxLevel : Length = 2.5;
            
            port outletPort : FluidPort;
            
            item storedFluid : Fluid {
                attribute volume : Volume;
            }
            
            flow from storedFluid to outletPort.fluid;
            
            assert constraint levelConstraint {
                currentLevel >= minLevel and currentLevel <= maxLevel
            }
        }
        
        part def WoodScrewPump {
            attribute screwDiameter : Length = 0.4;
            attribute screwLength : Length = 3.0;
            attribute pitchAngle : Real = 38.0;
            attribute inclinationAngle : Real = 35.0;
            attribute numberOfFlights : Integer = 4;
            attribute rotationalSpeed : AngularVelocity = 60.0;
            attribute efficiency : Real = 0.75;
            attribute displacementPerRevolution : Volume = 0.025;
            
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port driveShaft : MechanicalPowerPort;
            
            action def PumpFluid {
                in fluidIn : Fluid;
                in shaftSpeed : AngularVelocity;
                out fluidOut : Fluid;
                out actualFlowRate : VolumeFlowRate;
                out requiredTorque : Torque;
            }
            
            perform action pumpOperation : PumpFluid {
                in fluidIn = inletPort.fluid;
                in shaftSpeed = driveShaft.angularVelocity;
                out fluidOut = outletPort.fluid;
                out actualFlowRate = outletPort.flowRate;
                out requiredTorque = driveShaft.torque;
            }
            
            exhibit state pumpStates {
                entry; then idle;
                
                state idle;
                
                transition idle_to_starting
                    first idle
                    accept StartCommand
                    then starting;
                
                state starting;
                
                transition starting_to_running
                    first starting
                    accept SpeedReached
                    then running;
                
                state running;
                
                transition running_to_stopping
                    first running
                    accept StopCommand
                    then stopping;
                
                state stopping;
                
                transition stopping_to_idle
                    first stopping
                    accept SpeedZero
                    then idle;
            }
            
            assert constraint geometricConstraint {
                inclinationAngle >= 30.0 and inclinationAngle <= 40.0
            }
            
            assert constraint efficiencyConstraint {
                efficiency > 0.0 and efficiency <= 0.85
            }
        }
        
        part def ElectricMotor {
            attribute ratedPower : Power = 5000.0;
            attribute nominalSpeed : AngularVelocity = 60.0;
            attribute currentSpeed : AngularVelocity = 0.0;
            attribute maxTorque : Torque = 800.0;
            
            port outputShaft : ~MechanicalPowerPort;
            
            exhibit state motorController {
                entry; then off;
                
                state off;
                
                transition off_to_accelerating
                    first off
                    accept RunCommand
                    then accelerating;
                
                state accelerating;
                
                transition accelerating_to_running
                    first accelerating
                    accept NominalSpeedReached
                    then running;
                
                state running;
                
                transition running_to_decelerating
                    first running
                    accept StopCommand
                    then decelerating;
                
                state decelerating;
                
                transition decelerating_to_off
                    first decelerating
                    accept MotorStopped
                    then off;
            }
        }
        
        part def DischargeTank {
            attribute capacity : Volume = 3000.0;
            attribute currentLevel : Length = 0.5;
            attribute maxLevel : Length = 2.0;
            
            port inletPort : ~FluidPort;
            
            item storedFluid : Fluid {
                attribute volume : Volume;
            }
            
            flow from inletPort.fluid to storedFluid;
            
            assert constraint overflowProtection {
                currentLevel <= maxLevel
            }
        }
        
        part def FlowMeter {
            attribute measuredFlowRate : VolumeFlowRate;
            attribute accuracy : Real = 0.02;
            
            port sensingPort : ~FluidPort;
            
            action def MeasureFlow {
                in fluidFlow : Fluid;
                out flowRate : VolumeFlowRate;
            }
            
            perform action measure : MeasureFlow {
                in fluidFlow = sensingPort.fluid;
                out flowRate = measuredFlowRate;
            }
        }
        
        interface def MechanicalCoupling {
            end port driverPort : ~MechanicalPowerPort;
            end port drivenPort : MechanicalPowerPort;
        }
        
        requirement def PumpingSystemRequirements {
            subject subsystem : PumpingSubsystem;
            
            require flowCapacity {
                doc "The subsystem shall deliver minimum flow rate of 80 L/min";
            }
            
            require reliability {
                doc "The subsystem shall operate continuously for 8 hours minimum";
            }
            
            require efficiency {
                doc "The pump efficiency shall be at least 65%";
            }
        }
        
        requirement def FlowCapacityRequirement {
            attribute minFlowRate : VolumeFlowRate = 80.0;
            attribute maxFlowRate : VolumeFlowRate = 150.0;
            
            assert constraint {
                measuredFlow >= minFlowRate and measuredFlow <= maxFlowRate
            }
        }
    }
    
    package Usages {
        part pumpingSubsystem : PumpingSubsystem {
            part sump : SumpReservoir {
                :>> capacity = 5000.0;
                :>> currentLevel = 1.5;
                :>> minLevel = 0.2;
                :>> maxLevel = 2.5;
            }
            
            part woodScrew : WoodScrewPump {
                :>> screwDiameter = 0.4;
                :>> screwLength = 3.0;
                :>> pitchAngle = 38.0;
                :>> inclinationAngle = 35.0;
                :>> numberOfFlights = 4;
                :>> rotationalSpeed = 60.0;
                :>> efficiency = 0.75;
                :>> displacementPerRevolution = 0.025;
            }
            
            part motor : ElectricMotor {
                :>> ratedPower = 5000.0;
                :>> nominalSpeed = 60.0;
                :>> maxTorque = 800.0;
            }
            
            part dischargeTank : DischargeTank {
                :>> capacity = 3000.0;
                :>> currentLevel = 0.5;
                :>> maxLevel = 2.0;
            }
            
            part flowMeter : FlowMeter {
                :>> accuracy = 0.02;
            }
            
            item processFluid : Fluid {
                :>> density = 1000.0;
                :>> viscosity = 0.001;
                :>> temperature = 293.15;
            }
            
            flow of processFluid : Fluid
                from sump.outletPort.fluid to woodScrew.inletPort.fluid;
            
            flow of processFluid : Fluid
                from woodScrew.outletPort.fluid to flowMeter.sensingPort.fluid;
            
            flow of processFluid : Fluid
                from flowMeter.sensingPort.fluid to dischargeTank.inletPort.fluid;
            
            interface driveCoupling : MechanicalCoupling
                connect driverPort ::> motor.outputShaft
                to drivenPort ::> woodScrew.driveShaft;
            
            bind woodScrew.driveShaft.angularVelocity = motor.outputShaft.angularVelocity;
            bind motor.outputShaft.torque = woodScrew.driveShaft.torque;
            
            satisfy systemRequirements : PumpingSystemRequirements {
                subject subsystem = pumpingSubsystem;
                
                satisfy :>> flowCapacity by woodScrew.pumpOperation {
                    doc "Wood screw pump delivers 90 L/min at nominal speed";
                }
                
                satisfy :>> reliability by woodScrew {
                    doc "Pump designed for continuous operation with minimal wear";
                }
                
                satisfy :>> efficiency by woodScrew {
                    doc "Pump efficiency of 75% exceeds minimum requirement";
                }
            }
            
            satisfy flowRequirement : FlowCapacityRequirement {
                attribute measuredFlow = flowMeter.measuredFlowRate;
            }
            
            assert constraint operatingConstraint {
                woodScrew.rotationalSpeed > 0.0 implies motor.currentSpeed > 0.0
            }
            
            assert constraint flowConstraint {
                flowMeter.measuredFlowRate >= 80.0
            }
        }
        
        part def PumpingSubsystem {
            part sump : SumpReservoir;
            part woodScrew : WoodScrewPump;
            part motor : ElectricMotor;
            part dischargeTank : DischargeTank;
            part flowMeter : FlowMeter;
        }
    }
}
