package AspirationTherapySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    package Definitions {
        package ItemDefinitions {
            item def GastricContent;
            item def StartTherapySignal;
            item def ConnectionsSecureSignal;
            item def StopTherapySignal;
            item def SafetyAlertSignal;
            item def ResetSignal;
        }
        
        package PortDefinitions {
            port def VacuumFlowPort {
                out vacuum : PressureValue;
            }
            port def FluidFlowPort {
                flow fluid : GastricContent;
            }
            port def PressureReadingPort {
                out pressure : PressureValue;
            }
            port def FillLevelPort {
                out fillLevel : VolumeValue;
            }
            port def ControlPort {
                in activate : Boolean;
                in targetPressure : PressureValue;
            }
            port def UIPort {
                in config : String;
                out status : String;
            }
        }
        
        package ActionDefinitions {
            action def GenerateVacuum {
                in targetPressure : PressureValue;
                out vacuum : PressureValue;
            }
            action def MeasurePressure {
                in vacuum : PressureValue;
                out pressure : PressureValue;
            }
            action def DeactivateVacuum;
            action def DisplayStatus;
            action def AlertUser;
        }
        
        package StateDefinitions {
            private import ItemDefinitions::*;
            private import PartDefinitions::*;
            private import ActionDefinitions::*;
            
            state def ControlStates {
                in controlUnit : TherapyControlUnit;
                in ui : UserInterfaceModule;
                in vacuumPump : VacuumGenerationUnit;
                
                entry; then Standby;
                
                state Standby;
                accept StartTherapySignal
                    then Preparation;
                
                state Preparation;
                accept ConnectionsSecureSignal
                    then ActiveAspiration;
                
                state ActiveAspiration {
                    entry; then Suction;
                    state Suction;
                    accept after 30 [s]
                        then Wait;
                    state Wait;
                    accept after 5 [s]
                        then Suction;
                }
                accept when controlUnit.currentVolume >= controlUnit.targetVolume
                    then SessionComplete;
                accept when controlUnit.elapsedTime >= controlUnit.maxDuration
                    then SessionComplete;
                accept when controlUnit.currentPressure > controlUnit.maxSafePressure
                    then SafetyHold;
                accept when controlUnit.reservoirFill >= controlUnit.targetVolume
                    then SessionComplete;
                
                state SafetyHold;
                entry do send new SafetyAlertSignal() to ui;
                accept ResetSignal
                    then Standby;
                
                state SessionComplete;
                accept after 10 [s]
                    then Standby;
            }
        }
        
        package PartDefinitions {
            private import ItemDefinitions::*;
            private import PortDefinitions::*;
            private import ActionDefinitions::*;
            private import StateDefinitions::*;
            
            part def TherapyControlUnit {
                attribute targetVolume : VolumeValue;
                attribute maxDuration : DurationValue;
                attribute maxSafePressure : PressureValue;
                attribute currentVolume : VolumeValue;
                attribute elapsedTime : DurationValue;
                attribute currentPressure : PressureValue;
                attribute reservoirFill : VolumeValue;
                
                port uiPort : UIPort;
                port vacuumControlPort : ControlPort;
                port pressureInputPort : PressureReadingPort;
                port reservoirInputPort : FillLevelPort;
                
                exhibit state controlStates : ControlStates;
            }
            
            part def VacuumGenerationUnit {
                port controlPort : ControlPort;
                port vacuumPort : VacuumFlowPort;
                perform action generateVacuum : GenerateVacuum;
                perform action deactivateVacuum : DeactivateVacuum;
            }
            
            part def AspirationCatheterAssembly {
                port vacuumPort : VacuumFlowPort;
                port fluidInPort : FluidFlowPort;
                port fluidOutPort : FluidFlowPort;
            }
            
            part def PressureMonitoringSubsystem {
                port vacuumPort : VacuumFlowPort;
                port pressureOutputPort : PressureReadingPort;
                perform action measurePressure : MeasurePressure;
            }
            
            part def CollectionReservoir {
                port fluidPort : FluidFlowPort;
                port fillLevelOutputPort : FillLevelPort;
                attribute maxCapacity : VolumeValue;
            }
            
            part def UserInterfaceModule {
                port uiPort : UIPort;
                perform action displayStatus : DisplayStatus;
                perform action alertUser : AlertUser;
            }
            
            part def Patient {
                port stomachPort : FluidFlowPort;
            }
        }
        
        package RequirementDefinitions {
            private import PartDefinitions::*;
            
            requirement def SafetyRequirements {
                requirement PressureLimit {
                    subject controlUnit : TherapyControlUnit;
                    assert constraint {
                        controlUnit.currentPressure <= controlUnit.maxSafePressure
                    }
                }
                requirement VolumeLimit {
                    subject controlUnit : TherapyControlUnit;
                    assert constraint {
                        controlUnit.currentVolume <= controlUnit.targetVolume
                    }
                }
                requirement DurationLimit {
                    subject controlUnit : TherapyControlUnit;
                    assert constraint {
                        controlUnit.elapsedTime <= controlUnit.maxDuration
                    }
                }
            }
        }
    }
    
    package Usages {
        private import Definitions::ItemDefinitions::*;
        private import Definitions::PortDefinitions::*;
        private import Definitions::ActionDefinitions::*;
        private import Definitions::PartDefinitions::*;
        private import Definitions::StateDefinitions::*;
        private import Definitions::RequirementDefinitions::*;
        
        part aspirationTherapySystem {
            part controlUnit : TherapyControlUnit;
            part ui : UserInterfaceModule;
            part vacuumPump : VacuumGenerationUnit;
            part catheter : AspirationCatheterAssembly;
            part pressureMonitor : PressureMonitoringSubsystem;
            part reservoir : CollectionReservoir;
            part patient : Patient;
            
            connect controlUnit.uiPort to ui.uiPort;
            connect controlUnit.vacuumControlPort to vacuumPump.controlPort;
            connect controlUnit.pressureInputPort to pressureMonitor.pressureOutputPort;
            connect controlUnit.reservoirInputPort to reservoir.fillLevelOutputPort;
            
            interface vacuumInterface connect vacuumPump.vacuumPort to catheter.vacuumPort {
                flow vacuumFlow of PressureValue 
                    from vacuumPump.vacuumPort.vacuum to catheter.vacuumPort.vacuum;
            }
            interface pressureTap connect vacuumPump.vacuumPort to pressureMonitor.vacuumPort {
                flow pressureTapFlow of PressureValue 
                    from vacuumPump.vacuumPort.vacuum to pressureMonitor.vacuumPort.vacuum;
            }
            interface aspirationInterface connect patient.stomachPort to catheter.fluidInPort {
                flow gastricFlow of GastricContent 
                    from patient.stomachPort.fluid to catheter.fluidInPort.fluid;
            }
            interface collectionInterface connect catheter.fluidOutPort to reservoir.fluidPort {
                flow collectedFlow of GastricContent 
                    from catheter.fluidOutPort.fluid to reservoir.fluidPort.fluid;
            }
            
            exhibit state controlStates : ControlStates {
                in controlUnit = controlUnit;
                in ui = ui;
                in vacuumPump = vacuumPump;
            }
        }
    }
}
