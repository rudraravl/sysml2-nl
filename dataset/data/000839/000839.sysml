package 'Acid Egg System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        alias Pressure for ISQ::PressureValue;
        alias Volume for ISQ::VolumeValue;
        alias FlowRate for ISQ::VolumeFlowRateValue;
        
        attribute def FillCommand;
        attribute def PressurizeCommand;
        attribute def DischargeCommand;
        attribute def VentCommand;
        attribute def EmergencyStop;
        
        item def CorrosiveFluid {
            attribute concentration : Real;
            attribute volume : Volume;
        }
        
        item def PressurizedGas {
            attribute pressure : Pressure;
        }
        
        port def FluidPort {
            in item fluidIn : CorrosiveFluid;
            out item fluidOut : CorrosiveFluid;
        }
        
        port def GasPort {
            in item gasIn : PressurizedGas;
            out item gasOut : PressurizedGas;
        }
        
        port def ControlPort {
            in fillCmd : FillCommand;
            in pressurizeCmd : PressurizeCommand;
            in dischargeCmd : DischargeCommand;
            in ventCmd : VentCommand;
            in emergencyStop : EmergencyStop;
        }
        
        part def Valve {
            attribute isOpen : Boolean := false;
            port inlet;
            port outlet;
        }
        
        part def PressureVessel {
            attribute capacity : Volume;
            attribute currentVolume : Volume;
            attribute currentPressure : Pressure;
            attribute maxPressure : Pressure;
            port fluidInlet : FluidPort;
            port fluidOutlet : FluidPort;
            port gasInlet : GasPort;
            port gasVent : GasPort;
        }
        
        part def GasSupply {
            attribute supplyPressure : Pressure;
            port gasOutput : GasPort;
        }
        
        part def PressureSensor {
            attribute reading : Pressure;
            port measurementPoint : GasPort;
        }
        
        part def LevelSensor {
            attribute reading : Volume;
            port measurementPoint : FluidPort;
        }
        
        action def OpenValve {
            in valve : Valve;
            out valveState : Boolean;
        }
        
        action def CloseValve {
            in valve : Valve;
            out valveState : Boolean;
        }
        
        action def FillVessel {
            in targetVolume : Volume;
            in currentVolume : Volume;
            out filled : Boolean;
        }
        
        action def PressurizeVessel {
            in targetPressure : Pressure;
            in currentPressure : Pressure;
            out pressurized : Boolean;
        }
        
        action def DischargeFluid {
            in currentVolume : Volume;
            out discharged : Boolean;
        }
        
        action def VentPressure {
            in currentPressure : Pressure;
            out vented : Boolean;
        }
        
        action def TransferCorrosiveFluid {
            in targetVolume : Volume;
            in operatingPressure : Pressure;
            out transferComplete : Boolean;
            
            first start;
            then merge continueOperation;
            
            then action fillPhase : FillVessel {
                in targetVolume;
                in currentVolume;
                out filled;
            }
            
            then action openInletValve : OpenValve {
                in valve;
                out valveState;
            }
            
            then action waitForFill;
            
            then action closeInletValve : CloseValve {
                in valve;
                out valveState;
            }
            
            then action pressurizePhase : PressurizeVessel {
                in targetPressure = operatingPressure;
                in currentPressure;
                out pressurized;
            }
            
            then action openGasValve : OpenValve {
                in valve;
                out valveState;
            }
            
            then action waitForPressure;
            
            then action dischargePhase : DischargeFluid {
                in currentVolume;
                out discharged;
            }
            
            then action openOutletValve : OpenValve {
                in valve;
                out valveState;
            }
            
            then action waitForDischarge;
            
            then action closeOutletValve : CloseValve {
                in valve;
                out valveState;
            }
            
            then action closeGasValve : CloseValve {
                in valve;
                out valveState;
            }
            
            then action ventPhase : VentPressure {
                in currentPressure;
                out vented;
            }
            
            then action openVentValve : OpenValve {
                in valve;
                out valveState;
            }
            
            then action waitForVent;
            
            then action closeVentValve : CloseValve {
                in valve;
                out valveState;
            }
            
            then assign transferComplete := true;
            then continueOperation;
            then done;
        }
        
        requirement def SafetyRequirement;
        requirement def OperationalRequirement;
        
        requirement materialCompatibility : SafetyRequirement {
            doc /* All wetted components shall be constructed from materials 
                   resistant to the corrosive fluid being transferred. */
        }
        
        requirement pressureSafety : SafetyRequirement {
            in maxOperatingPressure : Pressure;
            in vesselRating : Pressure;
            in safetyFactor : Real = 1.5;
            
            doc /* The pressure vessel shall be rated to withstand at least 
                   1.5 times the maximum operating pressure. */
            
            require constraint {
                maxOperatingPressure * safetyFactor <= vesselRating
            }
        }
        
        requirement transferAccuracy : OperationalRequirement {
            in targetVolume : Volume;
            in actualVolume : Volume;
            in tolerance : Real = 0.02;
            
            doc /* The system shall transfer fluid within ±2% of the target volume. */
            
            require constraint {
                (actualVolume - targetVolume).abs() <= targetVolume * tolerance
            }
        }
        
        part def AcidEgg {
            attribute operatingPressure : Pressure;
            attribute transferVolume : Volume;
            
            port fluidSource : FluidPort;
            port fluidDestination : FluidPort;
            port gasSource : GasPort;
            port gasVentPort : GasPort;
            port controlInterface : ControlPort;
            
            part vessel : PressureVessel;
            
            part inletValve : Valve;
            part outletValve : Valve;
            part gasValve : Valve;
            part ventValve : Valve;
            
            part gasSupply : GasSupply;
            
            part pressureSensor : PressureSensor;
            part levelSensor : LevelSensor;
            
            connect fluidSource to inletValve.inlet;
            connect inletValve.outlet to vessel.fluidInlet;
            connect vessel.fluidOutlet to outletValve.inlet;
            connect outletValve.outlet to fluidDestination;
            
            connect gasSupply.gasOutput to gasValve.inlet;
            connect gasValve.outlet to vessel.gasInlet;
            connect vessel.gasVent to ventValve.inlet;
            connect ventValve.outlet to gasVentPort;
            
            connect pressureSensor.measurementPoint to vessel.gasInlet;
            connect levelSensor.measurementPoint to vessel.fluidInlet;
            
            perform action transferFluid[*] ordered : TransferCorrosiveFluid {
                in targetVolume = transferVolume;
                in operatingPressure = operatingPressure;
                out transferComplete;
            }
        }
    }
    
    package Usages {
        import Definitions::*;
        
        part acidEggSystem : AcidEgg {
            :>> operatingPressure;
            :>> transferVolume;
            
            must satisfy materialCompatibility;
            must satisfy pressureSafety;
            must satisfy transferAccuracy;
        }
    }
}
