package 'Drum Pumping System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        item def Fluid;
        
        port def FluidPort {
            out item fluid : Fluid;
        }
        
        part def SourceDrum {
            port fluidOutPort : FluidPort;
            attribute capacity : VolumeValue;
            attribute currentVolume : VolumeValue;
        }
        
        part def DestinationTank {
            port fluidInPort : ~FluidPort;
            attribute capacity : VolumeValue;
            attribute currentVolume : VolumeValue;
        }
        
        part def SuctionPipe {
            port inPort : ~FluidPort;
            port outPort : FluidPort;
        }
        
        part def DischargePipe {
            port inPort : ~FluidPort;
            port outPort : FluidPort;
        }
        
        part def ElectricDriveMotor {
            attribute speed : AngularVelocityValue;
        }
        
        part def DrumRotor {
            attribute speed : AngularVelocityValue;
        }
        
        part def MechanicalSeal {
            attribute integrityOK : Boolean = true;
        }
        
        part def DrumPumpAssembly {
            port suctionPort : ~FluidPort;
            port dischargePort : FluidPort;
            part motor : ElectricDriveMotor;
            part rotor : DrumRotor;
            part seal : MechanicalSeal;
            attribute dischargePressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
            connector motorToRotor from motor to rotor;
        }
        
        state def PumpStates;
        
        action def PrimePump {
            in pump : DrumPumpAssembly;
        }
        action def RunPump {
            in pump : DrumPumpAssembly;
        }
        action def StopPump {
            in pump : DrumPumpAssembly;
        }
        action def MonitorFlowRate {
            in pump : DrumPumpAssembly;
            out flowRate : VolumeFlowRateValue;
        }
        action def MonitorPressure {
            in pump : DrumPumpAssembly;
            out pressure : PressureValue;
        }
        action def DetectCavitation {
            in pressure : PressureValue;
            in flowRate : VolumeFlowRateValue;
            out cavitation : Boolean;
        }
        action def CheckSourceLevel {
            in source : SourceDrum;
            out ok : Boolean;
        }
        action def CheckDestinationSpace {
            in dest : DestinationTank;
            out ok : Boolean;
        }
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def PrimingCompleteSignal;
        attribute def StoppedSignal;
        attribute def ResetCommand;
        
        requirement def 'Safe Pump Operation' {
            doc /* The pump shall not start unless the source drum has sufficient fluid and the destination tank has sufficient empty space. */
        }
        requirement def 'Cavitation Protection' {
            doc /* The pump shall stop automatically if cavitation is detected. */
        }
        requirement def 'Overflow Prevention' {
            doc /* The pump shall stop automatically when the destination tank is nearly full. */
        }
        
        part def DrumPumpingSystem {
            part sourceDrum : SourceDrum;
            part destinationTank : DestinationTank;
            part suctionPipe : SuctionPipe;
            part dischargePipe : DischargePipe;
            part pumpAssembly : DrumPumpAssembly;
            
            attribute minSourceLevel : VolumeValue;
            attribute minDestinationSpace : VolumeValue;
            attribute sourceLevelOK : Boolean = false;
            attribute destinationSpaceOK : Boolean = false;
            attribute cavitationDetected : Boolean = false;
            
            flow of fluid : Fluid from sourceDrum.fluidOutPort.fluid to suctionPipe.inPort.fluid;
            flow of fluid : Fluid from suctionPipe.outPort.fluid to pumpAssembly.suctionPort.fluid;
            flow of fluid : Fluid from pumpAssembly.dischargePort.fluid to dischargePipe.inPort.fluid;
            flow of fluid : Fluid from dischargePipe.outPort.fluid to destinationTank.fluidInPort.fluid;
            
            action primePump : PrimePump {
                in pump = pumpAssembly;
            }
            action runPump : RunPump {
                in pump = pumpAssembly;
            }
            action stopPump : StopPump {
                in pump = pumpAssembly;
            }
            action monitorFlowRate : MonitorFlowRate {
                in pump = pumpAssembly;
                out flowRate = pumpAssembly.flowRate;
            }
            action monitorPressure : MonitorPressure {
                in pump = pumpAssembly;
                out pressure = pumpAssembly.dischargePressure;
            }
            action detectCavitation : DetectCavitation {
                in pressure = pumpAssembly.dischargePressure;
                in flowRate = pumpAssembly.flowRate;
                out cavitation = cavitationDetected;
            }
            action checkSourceLevel : CheckSourceLevel {
                in source = sourceDrum;
                out ok = sourceLevelOK;
            }
            action checkDestinationSpace : CheckDestinationSpace {
                in dest = destinationTank;
                out ok = destinationSpaceOK;
            }
            
            exhibit state pumpStates : PumpStates {
                entry; then idle;
                
                state idle {
                    do checkSourceLevel;
                    do checkDestinationSpace;
                }
                
                accept StartCommand
                    if sourceLevelOK and destinationSpaceOK
                    do primePump
                    then priming;
                
                state priming {
                    entry primePump;
                    do monitorFlowRate;
                }
                
                accept PrimingCompleteSignal
                    then running;
                
                state running {
                    entry runPump;
                    do monitorFlowRate;
                    do monitorPressure;
                    do detectCavitation;
                }
                
                accept when cavitationDetected
                    do stopPump
                    then faulted;
                
                accept when destinationTank.currentVolume >= destinationTank.capacity - minDestinationSpace
                    do stopPump
                    then stopping;
                
                accept StopCommand
                    do stopPump
                    then stopping;
                
                state stopping {
                    entry stopPump;
                }
                
                accept StoppedSignal
                    then idle;
                
                state faulted {
                    entry stopPump;
                }
                
                accept ResetCommand
                    then idle;
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part drumPumpingSystem : DrumPumpingSystem;
        
        requirement 'safe pump operation' : 'Safe Pump Operation';
        requirement 'cavitation protection' : 'Cavitation Protection';
        requirement 'overflow prevention' : 'Overflow Prevention';
    }
}
