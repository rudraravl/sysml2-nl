package 'Vacuum Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package DomainModel {
        attribute def PressureValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def PowerValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def RPMValue :> Real;
        
        enum def PumpOperatingMode {
            enum idle;
            enum startup;
            enum evacuating;
            enum maintaining;
            enum shutdown;
            enum fault;
        }
        
        enum def ValvePosition {
            enum open;
            enum closed;
            enum throttled;
        }
        
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : TemperatureValue;
            attribute volume : VolumeValue;
        }
        
        port def FluidInletPort {
            in item fluidIn : Fluid;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
        }
        
        port def FluidOutletPort {
            out item fluidOut : Fluid;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
        }
        
        port def PowerInputPort {
            attribute voltage : Real;
            attribute current : Real;
            attribute power : PowerValue;
        }
        
        port def ControlSignalPort {
            in attribute commandedMode : PumpOperatingMode;
            out attribute actualMode : PumpOperatingMode;
            out attribute statusCode : Integer;
        }
        
        port def SensorPort {
            out attribute measuredValue : Real;
            attribute accuracy : Real;
        }
        
        part def VacuumPump {
            attribute nominalFlowRate : FlowRateValue;
            attribute maxVacuumPressure : PressureValue;
            attribute ratedPower : PowerValue;
            attribute motorSpeed : RPMValue;
            attribute currentMode : PumpOperatingMode;
            attribute inletPressure : PressureValue;
            attribute dischargePressure : PressureValue;
            attribute actualFlowRate : FlowRateValue;
            
            port suctionPort : FluidInletPort;
            port dischargePort : FluidOutletPort;
            port powerInput : PowerInputPort;
            port controlInterface : ControlSignalPort;
            
            perform action pumpOperation : VacuumPumpOperation;
            exhibit state pumpStateMachine : VacuumPumpBehavior;
        }
        
        part def SourceVessel {
            attribute capacity : VolumeValue;
            attribute currentPressure : PressureValue;
            attribute currentVolume : VolumeValue;
            
            port outletPort : FluidOutletPort;
            
            item containedFluid : Fluid {
                attribute :>> volume;
            }
        }
        
        part def ReceivingVessel {
            attribute capacity : VolumeValue;
            attribute currentPressure : PressureValue;
            attribute currentVolume : VolumeValue;
            attribute maxPressure : PressureValue;
            
            port inletPort : FluidInletPort;
            
            item storedFluid : Fluid {
                attribute :>> volume;
            }
        }
        
        part def IsolationValve {
            attribute position : ValvePosition;
            attribute flowCoefficient : Real;
            
            port inletPort : FluidInletPort;
            port outletPort : FluidOutletPort;
            
            perform action actuateValve : ValveActuation;
        }
        
        part def PressureTransducer {
            attribute measuredPressure : PressureValue;
            attribute accuracy : Real;
            attribute range : PressureValue;
            
            port sensingPort : FluidInletPort;
            port signalPort : SensorPort;
        }
        
        part def FlowTransducer {
            attribute measuredFlowRate : FlowRateValue;
            attribute accuracy : Real;
            attribute range : FlowRateValue;
            
            port sensingPort : FluidInletPort;
            port signalPort : SensorPort;
        }
        
        part def VacuumController {
            attribute targetPressure : PressureValue;
            attribute pressureTolerance : PressureValue;
            attribute currentPressure : PressureValue;
            attribute pumpCommand : PumpOperatingMode;
            
            port controlOutput : ControlSignalPort;
            
            perform action controlLogic : VacuumControlAlgorithm;
        }
        
        part def SafetyReliefValve {
            attribute setPoint : PressureValue;
            attribute isOpen : Boolean;
            
            port inletPort : FluidInletPort;
            port reliefPort : FluidOutletPort;
        }
        
        action def VacuumPumpOperation {
            in incomingFluid : Fluid;
            in operatingMode : PumpOperatingMode;
            in suctionPressure : PressureValue;
            out dischargedFluid : Fluid;
            out achievedFlowRate : FlowRateValue;
            out dischargePressure : PressureValue;
            
            action checkOperatingConditions {
                in mode : PumpOperatingMode;
                in pressure : PressureValue;
                out isValid : Boolean;
            }
            
            action evacuateFluid {
                in fluid : Fluid;
                in vacuumLevel : PressureValue;
                out evacuatedFluid : Fluid;
                out flowRate : FlowRateValue;
            }
            
            action monitorPerformance {
                in currentFlow : FlowRateValue;
                in currentPressure : PressureValue;
                out performanceStatus : Boolean;
            }
        }
        
        action def VacuumControlAlgorithm {
            in targetPressure : PressureValue;
            in measuredPressure : PressureValue;
            in tolerance : PressureValue;
            out pumpCommand : PumpOperatingMode;
            
            first start;
            then merge evaluatePressure;
            
            then action calculateError {
                in target : PressureValue = targetPressure;
                in measured : PressureValue = measuredPressure;
                out error : Real;
            }
            
            then decide;
                if calculateError.error > 10.0 then commandEvacuating;
                if calculateError.error > 1.0 and calculateError.error <= 10.0 then commandMaintaining;
                if calculateError.error <= 1.0 then commandIdle;
            
            action commandEvacuating {
                out cmd : PumpOperatingMode = PumpOperatingMode::evacuating;
            }
            then evaluatePressure;
            
            action commandMaintaining {
                out cmd : PumpOperatingMode = PumpOperatingMode::maintaining;
            }
            then evaluatePressure;
            
            action commandIdle {
                out cmd : PumpOperatingMode = PumpOperatingMode::idle;
            }
            then done;
        }
        
        action def ValveActuation {
            in commandedPosition : ValvePosition;
            out actualPosition : ValvePosition;
            
            action moveValve {
                in target : ValvePosition;
                out position : ValvePosition;
            }
        }
        
        state def VacuumPumpBehavior {
            entry; then off;
            
            state off;
            
            transition offToStarting
                first off
                accept at off
                if controlInterface.commandedMode == PumpOperatingMode::startup
                then starting;
            
            state starting;
            
            transition startingToEvacuating
                first starting
                accept at starting
                if inletPressure > maxVacuumPressure
                then evacuating;
            
            transition startingToFaulted
                first starting
                accept at starting
                if inletPressure <= maxVacuumPressure
                then faulted;
            
            state evacuating;
            
            transition evacuatingToMaintaining
                first evacuating
                accept at evacuating
                if inletPressure <= (maxVacuumPressure + 5.0)
                then maintaining;
            
            transition evacuatingToShuttingDown
                first evacuating
                accept at evacuating
                if controlInterface.commandedMode == PumpOperatingMode::shutdown
                then shuttingDown;
            
            transition evacuatingToFaulted
                first evacuating
                accept at evacuating
                if motorSpeed < 100.0
                then faulted;
            
            state maintaining;
            
            transition maintainingToEvacuating
                first maintaining
                accept at maintaining
                if inletPressure > (maxVacuumPressure + 15.0)
                then evacuating;
            
            transition maintainingToShuttingDown
                first maintaining
                accept at maintaining
                if controlInterface.commandedMode == PumpOperatingMode::shutdown
                then shuttingDown;
            
            transition maintainingToFaulted
                first maintaining
                accept at maintaining
                if motorSpeed < 100.0
                then faulted;
            
            state shuttingDown;
            
            transition shuttingDownToOff
                first shuttingDown
                accept at shuttingDown
                then off;
            
            state faulted;
            
            transition faultedToOff
                first faulted
                accept at faulted
                if controlInterface.commandedMode == PumpOperatingMode::idle
                then off;
        }
        
        requirement def VacuumPumpingSystemRequirement {
            subject system : VacuumPumpingSystem;
            
            require achieveTargetVacuum : TargetVacuumRequirement {
                assume initialPressure : PressureValue;
                require targetVacuumPressure : PressureValue;
                require achievementTime : Real;
            }
            
            require maintainFlowRate : MinimumFlowRateRequirement {
                require minimumFlowRate : FlowRateValue;
            }
            
            require operateSafely : SafeOperationRequirement {
                require maxPressureDifferential : PressureValue;
                require maxOperatingPressure : PressureValue;
            }
        }
        
        requirement def TargetVacuumRequirement {
            doc /* The system shall reduce pressure from initial to target vacuum level within specified time */
            
            attribute initialPressure : PressureValue;
            attribute targetVacuumPressure : PressureValue;
            attribute achievementTime : Real;
            
            require constraint {
                targetVacuumPressure < initialPressure and achievementTime > 0.0
            }
        }
        
        requirement def MinimumFlowRateRequirement {
            doc /* The pump shall maintain minimum flow rate during evacuation */
            
            attribute minimumFlowRate : FlowRateValue;
            
            require constraint {
                minimumFlowRate >= 5.0
            }
        }
        
        requirement def SafeOperationRequirement {
            doc /* The system shall operate within safe pressure limits */
            
            attribute maxPressureDifferential : PressureValue;
            attribute maxOperatingPressure : PressureValue;
            
            require constraint {
                maxPressureDifferential <= 120.0 and maxOperatingPressure <= 150.0
            }
        }
        
        part def VacuumPumpingSystem;
    }
    
    package SystemImplementation {
        import DomainModel::*;
        
        part vacuumPumpingSystem : VacuumPumpingSystem {
            
            part sourceVessel : SourceVessel {
                attribute :>> capacity = 100.0;
                attribute :>> currentPressure = 101.325;
                attribute :>> currentVolume = 75.0;
            }
            
            part suctionValve : IsolationValve {
                attribute :>> position = ValvePosition::closed;
                attribute :>> flowCoefficient = 0.85;
            }
            
            part vacuumPump : VacuumPump {
                attribute :>> nominalFlowRate = 50.0;
                attribute :>> maxVacuumPressure = 0.01;
                attribute :>> ratedPower = 3000.0;
                attribute :>> motorSpeed = 3600.0;
                attribute :>> currentMode = PumpOperatingMode::idle;
            }
            
            part dischargeValve : IsolationValve {
                attribute :>> position = ValvePosition::closed;
                attribute :>> flowCoefficient = 0.85;
            }
            
            part receivingVessel : ReceivingVessel {
                attribute :>> capacity = 150.0;
                attribute :>> currentPressure = 101.325;
                attribute :>> currentVolume = 0.0;
                attribute :>> maxPressure = 150.0;
            }
            
            part suctionPressureSensor : PressureTransducer {
                attribute :>> accuracy = 0.25;
                attribute :>> range = 120.0;
            }
            
            part dischargePressureSensor : PressureTransducer {
                attribute :>> accuracy = 0.25;
                attribute :>> range = 200.0;
            }
            
            part flowSensor : FlowTransducer {
                attribute :>> accuracy = 1.0;
                attribute :>> range = 100.0;
            }
            
            part systemController : VacuumController {
                attribute :>> targetPressure = 5.0;
                attribute :>> pressureTolerance = 1.0;
            }
            
            part reliefValve : SafetyReliefValve {
                attribute :>> setPoint = 145.0;
                attribute :>> isOpen = false;
            }
            
            flow sourceToSuctionValve : Fluid
                from sourceVessel.outletPort.fluidOut
                to suctionValve.inletPort.fluidIn;
            
            flow suctionValveToPump : Fluid
                from suctionValve.outletPort.fluidOut
                to vacuumPump.suctionPort.fluidIn;
            
            flow pumpToDischargeValve : Fluid
                from vacuumPump.dischargePort.fluidOut
                to dischargeValve.inletPort.fluidIn;
            
            flow dischargeValveToReceiver : Fluid
                from dischargeValve.outletPort.fluidOut
                to receivingVessel.inletPort.fluidIn;
            
            bind suctionPressureSensor.measuredPressure = vacuumPump.inletPressure;
            bind dischargePressureSensor.measuredPressure = vacuumPump.dischargePressure;
            bind flowSensor.measuredFlowRate = vacuumPump.actualFlowRate;
            bind systemController.currentPressure = suctionPressureSensor.measuredPressure;
            bind systemController.pumpCommand = vacuumPump.controlInterface.commandedMode;
            
            connection controlConnection
                connect systemController.controlOutput to vacuumPump.controlInterface;
            
            requirement systemRequirement : VacuumPumpingSystemRequirement {
                subject systemSubject = vacuumPumpingSystem;
                
                require :>> achieveTargetVacuum {
                    assume :>> initialPressure = sourceVessel.currentPressure;
                    require :>> targetVacuumPressure = systemController.targetPressure;
                    require :>> achievementTime = 300.0;
                }
                
                require :>> maintainFlowRate {
                    require :>> minimumFlowRate = 10.0;
                }
                
                require :>> operateSafely {
                    require :>> maxPressureDifferential = 100.0;
                    require :>> maxOperatingPressure = reliefValve.setPoint;
                }
            }
        }
    }
}
