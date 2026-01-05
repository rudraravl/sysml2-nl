package 'FoamPumpingSubsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def PowerValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def RPMValue :> Real;
        
        item def Foam {
            attribute density : Real;
            attribute viscosity : Real;
            attribute expansionRatio : Real;
            attribute temperature : TemperatureValue;
        }
        
        port def FoamPort {
            out item foam : Foam;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
        }
        
        port def PowerPort {
            out attribute voltage : Real;
            out attribute current : Real;
        }
        
        port def ControlPort {
            in attribute commandSignal : Real;
            out attribute statusSignal : Real;
        }
        
        port def SignalPort {
            out attribute value : Real;
        }
        
        part def FoamReservoir {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute minLevel : VolumeValue;
            
            port outletPort : FoamPort;
            
            item storedFoam : Foam {
                attribute volume : VolumeValue;
            }
            
            assert constraint levelConstraint {
                currentLevel >= minLevel & currentLevel <= capacity
            }
        }
        
        state def PumpStateMachine {
            entry; then off;
            
            state off {
                entry action initializePump;
            }
            transition off_to_startup
                first off
                accept StartCommand
                then startup;
            
            state startup {
                entry; then priming;
                state priming {
                    entry action primePump;
                }
                transition priming_to_accelerating
                    first priming
                    if primingComplete
                    then accelerating;
                state accelerating {
                    entry action rampUpSpeed;
                }
                transition accelerating_to_running
                    first accelerating
                    if targetSpeedReached
                    then running;
                state running;
            }
            transition startup_to_operating
                first startup
                if startupComplete
                then operating;
            
            state operating {
                entry; then normalOperation;
                state normalOperation {
                    do action pumpContinuously;
                }
                transition normal_to_overPressure
                    first normalOperation
                    if pressureExceeded
                    then overPressureMode;
                state overPressureMode {
                    entry action reduceSpeed;
                }
                transition overPressure_to_normal
                    first overPressureMode
                    if pressureNormalized
                    then normalOperation;
                transition normal_to_cavitation
                    first normalOperation
                    if cavitationDetected
                    then cavitationMode;
                state cavitationMode {
                    entry action adjustInletConditions;
                }
                transition cavitation_to_normal
                    first cavitationMode
                    if cavitationCleared
                    then normalOperation;
            }
            
            transition operating_to_shutdown
                first operating
                accept StopCommand
                then shutdown;
            
            state shutdown {
                entry action coastDown;
            }
            transition shutdown_to_off
                first shutdown
                if speedZero
                then off;
        }
        
        part def FoamPump {
            attribute ratedFlowRate : FlowRateValue;
            attribute maxPressure : PressureValue;
            attribute motorPower : PowerValue;
            attribute efficiency : Real;
            attribute operatingSpeed : RPMValue;
            
            port inletPort : ~FoamPort;
            port outletPort : FoamPort;
            port powerInput : ~PowerPort;
            port controlPort : ~ControlPort;
            
            perform action pumpFoam : PumpFoamAction {
                in foamIn = inletPort.foam;
                out foamOut = outletPort.foam;
            }
            
            exhibit state pumpStateMachine : PumpStateMachine;
        }
        
        part def DischargeManifold {
            attribute numberOfOutlets : Integer;
            attribute manifoldPressure : PressureValue;
            
            port inletPort : ~FoamPort;
            port outletPort : FoamPort;
            
            assert constraint pressureBalance {
                outletPort.pressure <= inletPort.pressure
            }
        }
        
        part def PressureSensor {
            attribute measurementRange : PressureValue;
            attribute accuracy : Real;
            attribute calibrationDate : String;
            
            port sensingPort : ~FoamPort;
            port signalOutput : SignalPort;
            
            perform action measurePressure : MeasurePressureAction {
                in sensedPressure = sensingPort.pressure;
                out pressureReading = signalOutput.value;
            }
        }
        
        part def FlowSensor {
            attribute measurementRange : FlowRateValue;
            attribute accuracy : Real;
            
            port sensingPort : ~FoamPort;
            port signalOutput : SignalPort;
            
            perform action measureFlow : MeasureFlowAction {
                in sensedFlow = sensingPort.flowRate;
                out flowReading = signalOutput.value;
            }
        }
        
        state def ControllerStateMachine {
            entry; then standby;
            
            state standby {
                entry action initializeController;
            }
            transition standby_to_active
                first standby
                accept ActivateCommand
                then active;
            
            state active {
                entry; then monitoring;
                state monitoring {
                    entry; then readSensors;
                    state readSensors {
                        do action acquireData;
                    }
                    transition read_to_process
                        first readSensors
                        if dataValid
                        then processData;
                    state processData {
                        do action computeControl;
                    }
                    transition process_to_output
                        first processData
                        if controlComputed
                        then outputCommand;
                    state outputCommand {
                        do action sendCommand;
                    }
                    transition output_to_read
                        first outputCommand
                        then readSensors;
                }
                transition monitoring_to_alarm
                    first monitoring
                    if criticalCondition
                    then alarm;
                state alarm {
                    entry action triggerAlarm;
                }
                transition alarm_to_monitoring
                    first alarm
                    if conditionCleared
                    then monitoring;
            }
            
            transition active_to_standby
                first active
                accept DeactivateCommand
                then standby;
        }
        
        part def PumpController {
            attribute targetFlowRate : FlowRateValue;
            attribute maxPressureLimit : PressureValue;
            attribute controlGain : Real;
            
            port pressureInput : ~SignalPort;
            port flowInput : ~SignalPort;
            port pumpControl : ControlPort;
            port powerControl : PowerPort;
            
            perform action controlLoop : ControlLoopAction {
                in pressureSignal = pressureInput.value;
                in flowSignal = flowInput.value;
                out commandOutput = pumpControl.commandSignal;
            }
            
            exhibit state controllerStateMachine : ControllerStateMachine;
        }
        
        part def PowerSupply {
            attribute nominalVoltage : Real;
            attribute maxCurrent : Real;
            attribute powerRating : PowerValue;
            
            port powerOutput : PowerPort;
            
            assert constraint powerLimit {
                powerOutput.voltage * powerOutput.current <= powerRating
            }
        }
        
        state def ReliefValveStateMachine {
            entry; then closed;
            
            state closed;
            transition closed_to_opening
                first closed
                if pressureAboveCracking
                then opening;
            
            state opening;
            transition opening_to_open
                first opening
                if pressureAboveFull
                then open;
            
            state open {
                do action relievePressure;
            }
            transition open_to_closing
                first open
                if pressureBelowCracking
                then closing;
            
            state closing;
            transition closing_to_closed
                first closing
                if valveSeated
                then closed;
        }
        
        part def ReliefValve {
            attribute crackingPressure : PressureValue;
            attribute fullOpenPressure : PressureValue;
            
            port inletPort : ~FoamPort;
            port reliefPort : FoamPort;
            
            exhibit state valveStateMachine : ReliefValveStateMachine;
        }
        
        action def PumpFoamAction {
            in foamIn : Foam;
            out foamOut : Foam;
            
            first start;
            then action checkInlet {
                in foam = foamIn;
            }
            then decide;
                if checkInlet.foam.viscosity < 100.0 then normalPumping;
                if checkInlet.foam.viscosity >= 100.0 then highViscosityPumping;
            action normalPumping {
                in foam = foamIn;
                out pumpedFoam : Foam = foam;
            }
            then merge complete;
            action highViscosityPumping {
                in foam = foamIn;
                out pumpedFoam : Foam = foam;
            }
            then complete;
            then done;
        }
        
        action def MeasurePressureAction {
            in sensedPressure : PressureValue;
            out pressureReading : Real;
        }
        
        action def MeasureFlowAction {
            in sensedFlow : FlowRateValue;
            out flowReading : Real;
        }
        
        action def ControlLoopAction {
            in pressureSignal : Real;
            in flowSignal : Real;
            out commandOutput : Real;
            
            first start;
            then action evaluateInputs {
                in pressure = pressureSignal;
                in flow = flowSignal;
            }
            then decide;
                if evaluateInputs.pressure > 700.0 then emergencyShutdown;
                if evaluateInputs.flow < 80.0 & evaluateInputs.pressure <= 700.0 then increaseSpeed;
                if evaluateInputs.flow >= 80.0 & evaluateInputs.flow <= 120.0 & evaluateInputs.pressure <= 700.0 then maintainSpeed;
                if evaluateInputs.flow > 120.0 & evaluateInputs.pressure <= 700.0 then decreaseSpeed;
            action emergencyShutdown {
                out command : Real = 0.0;
            }
            then merge output;
            action increaseSpeed {
                out command : Real = 1.3;
            }
            then output;
            action decreaseSpeed {
                out command : Real = 0.7;
            }
            then output;
            action maintainSpeed {
                out command : Real = 1.0;
            }
            then output;
            action output {
                in cmd : Real;
                out finalCommand : Real = cmd;
            }
            then done;
        }
        
        interface def FoamFlowInterface {
            end port source : FoamPort;
            end port sink : ~FoamPort;
        }
    }
    
    package Requirements {
        requirement def SystemRequirements {
            doc /* The foam pumping subsystem shall safely and reliably move foam from reservoir to discharge. */
            
            subject subsystem : FoamPumpingSystem;
            
            requirement flowCapabilityReq {
                doc /* The system shall deliver foam at minimum flow rate of 100 L/min. */
                
                require constraint {
                    subsystem.pump.ratedFlowRate >= 100.0
                }
            }
            
            requirement pressureRangeReq {
                doc /* The system shall maintain discharge pressure between 300 and 650 kPa. */
                
                require constraint {
                    subsystem.pump.outletPort.pressure >= 300.0 &
                    subsystem.pump.outletPort.pressure <= 650.0
                }
            }
            
            requirement safetyReq {
                doc /* The system shall include overpressure protection. */
                
                require constraint {
                    subsystem.reliefValve != null
                }
            }
            
            requirement monitoringReq {
                doc /* The system shall continuously monitor pressure and flow. */
                
                require constraint {
                    subsystem.pressureSensor != null &
                    subsystem.flowSensor != null
                }
            }
            
            requirement controlReq {
                doc /* The system shall automatically regulate pump operation. */
                
                require constraint {
                    subsystem.controller != null
                }
            }
            
            requirement reliabilityReq {
                doc /* The pump shall operate with minimum 85% efficiency. */
                
                require constraint {
                    subsystem.pump.efficiency >= 0.85
                }
            }
        }
    }
    
    package Usages {
        import Definitions::*;
        import Requirements::*;
        
        part def FoamPumpingSystem {
            part reservoir : FoamReservoir;
            part pump : FoamPump;
            part manifold : DischargeManifold;
            part pressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part controller : PumpController;
            part powerSupply : PowerSupply;
            part reliefValve : ReliefValve;
        }
        
        part foamPumpingSystem : FoamPumpingSystem {
            
            part :>> reservoir {
                attribute :>> capacity = 2000.0;
                attribute :>> currentLevel = 1500.0;
                attribute :>> minLevel = 200.0;
                
                item :>> storedFoam {
                    attribute :>> density = 48.0;
                    attribute :>> viscosity = 65.0;
                    attribute :>> expansionRatio = 12.0;
                    attribute :>> temperature = 20.0;
                    attribute :>> volume = 1500.0;
                }
            }
            
            interface reservoirToPump : FoamFlowInterface
                connect source ::> reservoir.outletPort
                to sink ::> pump.inletPort;
            
            part :>> pump {
                attribute :>> ratedFlowRate = 150.0;
                attribute :>> maxPressure = 800.0;
                attribute :>> motorPower = 7500.0;
                attribute :>> efficiency = 0.88;
                attribute :>> operatingSpeed = 1750.0;
            }
            
            interface pumpToManifold : FoamFlowInterface
                connect source ::> pump.outletPort
                to sink ::> manifold.inletPort;
            
            part :>> manifold {
                attribute :>> numberOfOutlets = 4;
                attribute :>> manifoldPressure = 500.0;
            }
            
            part :>> pressureSensor {
                attribute :>> measurementRange = 1000.0;
                attribute :>> accuracy = 0.015;
                attribute :>> calibrationDate = "2024-01-15";
            }
            
            bind pressureSensor.sensingPort.pressure = pump.outletPort.pressure;
            
            part :>> flowSensor {
                attribute :>> measurementRange = 250.0;
                attribute :>> accuracy = 0.02;
            }
            
            bind flowSensor.sensingPort.flowRate = pump.outletPort.flowRate;
            
            part :>> controller {
                attribute :>> targetFlowRate = 120.0;
                attribute :>> maxPressureLimit = 650.0;
                attribute :>> controlGain = 1.5;
            }
            
            connect pressureSensor.signalOutput to controller.pressureInput;
            connect flowSensor.signalOutput to controller.flowInput;
            connect controller.pumpControl to pump.controlPort;
            
            part :>> powerSupply {
                attribute :>> nominalVoltage = 480.0;
                attribute :>> maxCurrent = 20.0;
                attribute :>> powerRating = 9600.0;
            }
            
            connect powerSupply.powerOutput to controller.powerControl;
            connect controller.powerControl to pump.powerInput;
            
            part :>> reliefValve {
                attribute :>> crackingPressure = 700.0;
                attribute :>> fullOpenPressure = 750.0;
            }
            
            bind reliefValve.inletPort.pressure = pump.outletPort.pressure;
            
            satisfy systemRequirements : SystemRequirements {
                subject subsystem = foamPumpingSystem;
            }
        }
    }
}
