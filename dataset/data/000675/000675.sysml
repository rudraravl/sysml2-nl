package MechanicalPowerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
        attribute def Torque :> ISQ::TorqueValue;
        attribute def MechanicalPower :> ISQ::PowerValue;
        attribute def Efficiency :> Real;
        attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
        
        attribute def StartSignal;
        attribute def StopSignal;
        
        port def MechanicalInputPort {
            in attribute inputTorque : Torque;
            in attribute inputSpeed : RotationalSpeed;
        }
        
        port def MechanicalOutputPort {
            out attribute outputTorque : Torque;
            out attribute outputSpeed : RotationalSpeed;
        }
        
        port def ControlPort {
            in attribute throttleCommand : Real;
            out attribute statusFeedback : Real;
        }
        
        item def CouplingShaft {
            attribute diameter : ISQ::LengthValue;
            attribute length : ISQ::LengthValue;
            attribute maxTorque : Torque;
        }
        
        item def GearSet {
            attribute gearRatio : Real;
            attribute efficiency : Efficiency;
            attribute maxInputTorque : Torque;
        }
        
        part def PrimeMover {
            port mechanicalOutput : MechanicalOutputPort;
            port controlInput : ControlPort;
            
            attribute ratedPower : MechanicalPower;
            attribute operatingSpeed : RotationalSpeed;
            attribute currentTorque : Torque;
            attribute operatingTemperature : Temperature;
        }
        
        part def TransmissionSystem {
            port mechanicalInput : MechanicalInputPort;
            port mechanicalOutput : MechanicalOutputPort;
            
            part gearSet : GearSet;
            part inputShaft : CouplingShaft;
            part outputShaft : CouplingShaft;
            
            attribute overallRatio : Real;
            attribute transmissionEfficiency : Efficiency;
        }
        
        part def LoadMechanism {
            port mechanicalInput : MechanicalInputPort;
            
            attribute requiredTorque : Torque;
            attribute operatingSpeed : RotationalSpeed;
            attribute inertia : ISQ::MomentOfInertiaValue;
        }
        
        part def ControlSystem {
            port controlOutput : ControlPort;
            
            attribute targetSpeed : RotationalSpeed;
            attribute currentSpeed : RotationalSpeed;
            attribute controlGain : Real;
        }
        
        action def ComputePower {
            in torque : Torque;
            in speed : RotationalSpeed;
            out power : MechanicalPower;
        }
        
        action def TransmitTorque {
            in inputTorque : Torque;
            in inputSpeed : RotationalSpeed;
            in ratio : Real;
            in efficiency : Efficiency;
            out outputTorque : Torque;
            out outputSpeed : RotationalSpeed;
        }
        
        action def RegulateSpeed {
            in targetSpeed : RotationalSpeed;
            in currentSpeed : RotationalSpeed;
            in gain : Real;
            out throttleCommand : Real;
        }
        
        action def MonitorPerformance {
            in currentPower : MechanicalPower;
            in currentSpeed : RotationalSpeed;
            in currentTorque : Torque;
            out performanceStatus : Real;
        }
        
        state def PowerSystemStates {
            in attribute systemPower : Real;
            in attribute speedStabilized : Boolean;
            in attribute loadChanged : Boolean;
            in attribute loadStable : Boolean;
            in attribute speedZero : Boolean;
            
            entry; then standby;
            
            state standby {
                entry assign systemPower := 0.0;
            }
            
            transition standby_to_startup
                first standby
                accept start : StartSignal
                then startup;
            
            state startup {
                entry assign systemPower := 0.3;
            }
            
            transition startup_to_operational
                first startup
                if speedStabilized
                then operational;
            
            state operational {
                entry assign systemPower := 1.0;
                
                state steadyState;
                state transient;
                
                transition steady_to_transient
                    first steadyState
                    if loadChanged
                    then transient;
                
                transition transient_to_steady
                    first transient
                    if loadStable
                    then steadyState;
            }
            
            transition operational_to_shutdown
                first operational
                accept stop : StopSignal
                then shutdown;
            
            state shutdown {
                entry assign systemPower := 0.1;
            }
            
            transition shutdown_to_standby
                first shutdown
                if speedZero
                then standby;
        }
        
        action def DeliverMechanicalPower {
            doc /* Primary function: Convert input energy into controlled mechanical 
                 * power and deliver it to a load through a transmission system.
                 * The system continuously monitors performance and adjusts operation
                 * to maintain desired speed and torque output.
                 */
            
            in targetSpeed : RotationalSpeed;
            in loadTorque : Torque;
            out deliveredPower : MechanicalPower;
            out deliveredTorque : Torque;
            
            first start;
            then merge operationLoop;
            
            then action monitor : MonitorPerformance {
                in currentPower;
                in currentSpeed;
                in currentTorque;
                out performanceStatus;
            }
            
            then decide;
                if monitor.performanceStatus < 0.7 then adjustOperation;
                if monitor.performanceStatus >= 0.7 then continueOperation;
            
            action adjustOperation : RegulateSpeed {
                in targetSpeed = DeliverMechanicalPower::targetSpeed;
                in currentSpeed;
                in gain = 2.0;
                out throttleCommand;
            }
            then operationLoop;
            
            action continueOperation {
                action calculatePower : ComputePower {
                    in torque;
                    in speed;
                    out power;
                }
                
                then action transmit : TransmitTorque {
                    in inputTorque;
                    in inputSpeed;
                    in ratio = 4.0;
                    in efficiency = 0.92;
                    out outputTorque;
                    out outputSpeed;
                }
                
                flow transmit.outputTorque to DeliverMechanicalPower::deliveredTorque;
                flow calculatePower.power to DeliverMechanicalPower::deliveredPower;
            }
            then operationLoop;
        }
    }
    
    package Requirements {
        requirement <'REQ-2000'> primaryPowerDelivery {
            doc /* The mechanical power system shall convert input energy into 
                 * controlled rotational mechanical power and deliver it continuously 
                 * to a load mechanism through a transmission system.
                 */
            subject system : SystemArchitecture::powerSystem;
        }
        
        requirement <'REQ-2001'> transmissionEfficiency {
            doc /* The transmission system shall maintain minimum efficiency 
                 * of 90% during normal operating conditions.
                 */
            subject transmission :>> SystemArchitecture::powerSystem.transmission;
            
            assert constraint {
                transmission.transmissionEfficiency >= 0.90
            }
        }
        
        requirement <'REQ-2002'> speedRegulation {
            doc /* The control system shall maintain load speed within 3% 
                 * of target speed during steady-state operation.
                 */
            subject controller :>> SystemArchitecture::powerSystem.controller;
        }
        
        requirement <'REQ-2003'> torqueCapacity {
            doc /* The transmission shall handle input torque up to 
                 * 600 Nm without mechanical failure.
                 */
            subject transmission :>> SystemArchitecture::powerSystem.transmission;
            
            assert constraint {
                transmission.gearSet.maxInputTorque >= 600.0
            }
        }
        
        requirement <'REQ-2004'> ratedPowerOutput {
            doc /* The prime mover shall deliver rated power of at least 
                 * 100 kW at nominal operating speed.
                 */
            subject primeMover :>> SystemArchitecture::powerSystem.primeMover;
            
            assert constraint {
                primeMover.ratedPower >= 100000.0
            }
        }
    }
    
    package SystemArchitecture {
        part powerSystem {
            part primeMover : Definitions::PrimeMover {
                attribute ratedPower = 120000.0;
                attribute operatingSpeed = 1800.0;
                attribute currentTorque = 636.6;
                attribute operatingTemperature = 363.15;
            }
            
            part transmission : Definitions::TransmissionSystem {
                attribute overallRatio = 4.0;
                attribute transmissionEfficiency = 0.92;
                
                part redefines gearSet {
                    attribute gearRatio = 4.0;
                    attribute efficiency = 0.92;
                    attribute maxInputTorque = 700.0;
                }
                
                part redefines inputShaft {
                    attribute diameter = 0.09;
                    attribute length = 0.5;
                    attribute maxTorque = 700.0;
                }
                
                part redefines outputShaft {
                    attribute diameter = 0.14;
                    attribute length = 0.6;
                    attribute maxTorque = 2800.0;
                }
            }
            
            part load : Definitions::LoadMechanism {
                attribute requiredTorque = 2400.0;
                attribute operatingSpeed = 450.0;
                attribute inertia = 35.0;
            }
            
            part controller : Definitions::ControlSystem {
                attribute targetSpeed = 450.0;
                attribute currentSpeed = 450.0;
                attribute controlGain = 2.0;
            }
            
            connect primeMover.mechanicalOutput to transmission.mechanicalInput;
            connect transmission.mechanicalOutput to load.mechanicalInput;
            connect controller.controlOutput to primeMover.controlInput;
            
            perform action systemOperation : Definitions::DeliverMechanicalPower {
                in targetSpeed = controller.targetSpeed;
                in loadTorque = load.requiredTorque;
                out deliveredPower;
                out deliveredTorque;
            }
        }
        
        satisfy Requirements::primaryPowerDelivery by powerSystem;
        satisfy Requirements::transmissionEfficiency by powerSystem.transmission;
        satisfy Requirements::speedRegulation by powerSystem.controller;
        satisfy Requirements::torqueCapacity by powerSystem.transmission;
        satisfy Requirements::ratedPowerOutput by powerSystem.primeMover;
    }
}
