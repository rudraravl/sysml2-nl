package SubmersiblePumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
        }
        
        attribute def VolumeValue :> Real;
        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def PowerValue :> Real;
        attribute def LengthValue :> Real;
        attribute def FrequencyValue :> Real;
        
        port def FluidPort {
            out item fluid : Fluid;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
        }
        
        part def Sump {
            port outletPort : FluidPort;
            attribute capacity : VolumeValue;
            attribute currentLevel : LengthValue;
            attribute maxLevel : LengthValue;
            attribute minLevel : LengthValue;
            
            item storedFluid : Fluid {
                attribute volume : VolumeValue;
            }
            
            assert constraint levelConstraint {
                currentLevel >= minLevel and currentLevel <= maxLevel
            }
        }
        
        part def SubmersiblePump {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port powerInput;
            
            attribute ratedPower : PowerValue;
            attribute ratedFlowRate : FlowRateValue;
            attribute ratedHead : LengthValue;
            attribute efficiency : Real;
            attribute motorSpeed : FrequencyValue;
            attribute isOperating : Boolean;
            attribute currentPower : PowerValue;
            
            perform action pumpingAction : PumpFluid;
            
            exhibit state pumpController : PumpStateMachine;
        }
        
        part def DischargePipe {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            
            attribute length : LengthValue;
            attribute diameter : LengthValue;
            attribute material : String;
            attribute roughness : Real;
        }
        
        part def DischargePoint {
            port inletPort : ~FluidPort;
            
            attribute elevation : LengthValue;
            attribute requiredPressure : PressureValue;
        }
        
        part def LevelSensor {
            attribute measuredLevel : LengthValue;
            attribute highSetpoint : LengthValue;
            attribute lowSetpoint : LengthValue;
            attribute highLevelReached : Boolean;
            attribute lowLevelReached : Boolean;
        }
        
        part def ControlPanel {
            attribute operatingMode : String;
            attribute autoModeEnabled : Boolean;
            attribute levelHigh : Boolean;
            attribute levelLow : Boolean;
            attribute startCommand : Boolean;
            attribute stopCommand : Boolean;
        }
        
        action def PumpFluid {
            in fluidIn : Fluid;
            in requiredHead : LengthValue;
            out fluidOut : Fluid;
            out achievedFlowRate : FlowRateValue;
            
            action calculatePressure {
                in head : LengthValue;
                in fluidDensity : Real;
                out pressure : PressureValue;
            }
            
            action transferFluid {
                in sourceFluid : Fluid;
                in flowRate : FlowRateValue;
                out deliveredFluid : Fluid;
            }
            
            first start;
            then calculatePressure;
            then transferFluid;
            then done;
        }
        
        state def PumpStateMachine {
            in attribute ratedPower : PowerValue;
            in attribute ratedFlowRate : FlowRateValue;
            attribute isOperating : Boolean;
            attribute currentPower : PowerValue;
            attribute motorSpeed : FrequencyValue;
            
            entry; then off;
            
            state off;
            
            state starting;
            
            state running {
                state steadyState;
                
                state variableSpeed;
                
                transition first steadyState;
                
                transition toVariable
                    first steadyState
                    accept demandChange
                    then variableSpeed;
                
                transition toSteady
                    first variableSpeed
                    accept demandChange
                    then steadyState;
            }
            
            state stopping;
            
            state alarm;
            
            transition offToStarting
                first off
                accept startSignal
                then starting;
            
            transition startingToRunning
                first starting
                accept speedReached
                then running;
            
            transition runningToStopping
                first running
                accept stopSignal
                then stopping;
            
            transition stoppingToOff
                first stopping
                accept motorStopped
                then off;
            
            transition toAlarm
                accept faultCondition
                then alarm;
            
            transition alarmToOff
                first alarm
                accept faultCleared
                then off;
        }
        
        requirement def PumpingSubsystemRequirements {
            subject subsystem : PumpingSubsystem;
            
            require minimumFlowRate {
                doc /* The subsystem shall deliver a minimum flow rate of 50 m³/h */
                assume actualFlow : FlowRateValue;
                require constraint { actualFlow >= 50.0 }
            }
            
            require dischargeHead {
                doc /* The subsystem shall provide a discharge head of at least 30 meters */
                assume head : LengthValue;
                require constraint { head >= 30.0 }
            }
            
            require submersibleOperation {
                doc /* The pump shall operate fully submerged in the fluid */
                assume pumpDepth : LengthValue;
                assume fluidDepth : LengthValue;
                require constraint { pumpDepth <= fluidDepth }
            }
            
            require efficiency {
                doc /* The pump shall operate at minimum 70% efficiency at rated conditions */
                assume pumpEfficiency : Real;
                require constraint { pumpEfficiency >= 0.70 }
            }
            
            require automaticControl {
                doc /* The subsystem shall automatically start and stop based on fluid level */
            }
        }
    }
    
    package Usages {
        part pumpingSubsystem : PumpingSubsystem {
            
            part sump : Sump {
                attribute :>> capacity = 10000.0;
                attribute :>> currentLevel = 2.5;
                attribute :>> maxLevel = 4.0;
                attribute :>> minLevel = 1.0;
                
                item :>> storedFluid : Fluid {
                    attribute :>> density = 1000.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 20.0;
                    attribute :>> volume = 5000.0;
                }
            }
            
            part levelSensor : LevelSensor {
                attribute :>> highSetpoint = 3.5;
                attribute :>> lowSetpoint = 1.5;
                
                bind measuredLevel = sump.currentLevel;
            }
            
            part controlPanel : ControlPanel {
                attribute :>> operatingMode = "Automatic";
                attribute :>> autoModeEnabled = true;
                
                bind levelHigh = levelSensor.highLevelReached;
                bind levelLow = levelSensor.lowLevelReached;
            }
            
            part submersiblePump : SubmersiblePump {
                attribute :>> ratedPower = 15000.0;
                attribute :>> ratedFlowRate = 75.0;
                attribute :>> ratedHead = 35.0;
                attribute :>> efficiency = 0.78;
                attribute :>> motorSpeed = 0.0;
                attribute :>> isOperating = false;
                attribute :>> currentPower = 0.0;
            }
            
            part dischargePipe : DischargePipe {
                attribute :>> length = 100.0;
                attribute :>> diameter = 0.15;
                attribute :>> material = "Stainless Steel";
                attribute :>> roughness = 0.00015;
            }
            
            part dischargePoint : DischargePoint {
                attribute :>> elevation = 25.0;
                attribute :>> requiredPressure = 2.0;
            }
            
            flow fluidFromSump : Fluid
                from sump.outletPort.fluid
                to submersiblePump.inletPort.fluid;
            
            flow fluidFromPump : Fluid
                from submersiblePump.outletPort.fluid
                to dischargePipe.inletPort.fluid;
            
            flow fluidToDischarge : Fluid
                from dischargePipe.outletPort.fluid
                to dischargePoint.inletPort.fluid;
            
            perform action operateSubsystem : OperateSubsystem {
                in sourceFluid = sump.storedFluid;
                in targetHead = dischargePoint.elevation;
                out deliveredFluid : Fluid;
            }
            
            satisfy subsystemRequirements : PumpingSubsystemRequirements;
        }
        
        action def OperateSubsystem {
            in sourceFluid : Fluid;
            in targetHead : LengthValue;
            out deliveredFluid : Fluid;
            
            first start;
            then merge monitoringLoop;
            
            then action monitorLevel {
                in currentLevel : LengthValue;
                in highSetpoint : LengthValue;
                in lowSetpoint : LengthValue;
                out shouldStart : Boolean;
                out shouldStop : Boolean;
            }
            
            then decide;
                if monitorLevel.shouldStart then startPumping;
                if monitorLevel.shouldStop then stopPumping;
                else monitoringLoop;
            
            action startPumping {
                action activatePump : PumpFluid {
                    in fluidIn = sourceFluid;
                    in requiredHead = targetHead;
                    out fluidOut = deliveredFluid;
                }
            }
            then monitoringLoop;
            
            action stopPumping {
                action deactivatePump;
            }
            then monitoringLoop;
        }
        
        requirement subsystemRequirements : PumpingSubsystemRequirements {
            subject subsystem = pumpingSubsystem;
        }
    }
}
