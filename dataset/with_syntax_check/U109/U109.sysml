package 'Replogle Tube System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SuctionPressure :> PressureValue;
    attribute def TubeDiameter :> LengthValue;
    attribute def FluidVolume :> VolumeValue;
    attribute def FlowRate :> VolumeFlowRateValue;
    
    item def GastricFluid {
        attribute volume : VolumeValue;
        attribute viscosity : DynamicViscosityValue;
    }
    
    item def Air {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }
    
    item def Saline {
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    port def SuctionPort {
        in item gastricContent : GastricFluid;
        in item swallowedAir : Air;
        attribute appliedPressure : SuctionPressure;
    }
    
    port def VentPort {
        out item atmosphericAir : Air;
        attribute isOpen : Boolean;
    }
    
    port def IrrigationPort {
        in item irrigationFluid : Saline;
        attribute flowRate : FlowRate;
    }
    
    port def GastricPort {
        out item gastricFluid : GastricFluid;
        out item air : Air;
        attribute pressure : PressureValue;
    }
    
    part def ReplogleTube {
        attribute outerDiameter : TubeDiameter;
        attribute length : LengthValue;
        attribute frenchSize : Real;
        
        part suctionLumen {
            attribute diameter : TubeDiameter;
            port proximal : SuctionPort;
            port distal : GastricPort;
        }
        
        part ventLumen {
            attribute diameter : TubeDiameter;
            port atmospheric : VentPort;
            port gastric : GastricPort;
        }
        
        part distalTip {
            attribute numberOfOpenings : Integer;
        }
        
        part ventOpening {
            attribute position : LengthValue;
        }
    }
    
    part def SuctionApparatus {
        attribute targetPressure : SuctionPressure;
        attribute maxPressure : SuctionPressure;
        attribute minPressure : SuctionPressure;
        
        port vacuumPort : SuctionPort;
        
        part vacuumSource {
            attribute power : PowerValue;
        }
        
        part collectionContainer {
            attribute capacity : FluidVolume;
            attribute currentLevel : FluidVolume;
        }
        
        part pressureRegulator {
            attribute setPressure : SuctionPressure;
        }
    }
    
    part def IrrigationSystem {
        attribute flushVolume : FluidVolume;
        attribute flushInterval : TimeValue;
        
        port fluidPort : IrrigationPort;
        
        part salineReservoir {
            attribute capacity : FluidVolume;
            attribute remainingVolume : FluidVolume;
        }
        
        part deliveryPump {
            attribute flowRate : FlowRate;
        }
    }
    
    part def PatientStomach {
        attribute gastricVolume : FluidVolume;
        attribute intragastricPressure : PressureValue;
        
        port gastricInterface : GastricPort;
    }
    
    action def ApplyContinuousSuction {
        in targetPressure : SuctionPressure;
        in duration : TimeValue;
        out volumeRemoved : FluidVolume;
        out pressureAchieved : SuctionPressure;
    }
    
    action def VentSwallowedAir {
        in ventPort : VentPort;
        out airVented : FluidVolume;
        out pressureRelieved : PressureValue;
    }
    
    action def IrrigateLumen {
        in flushVolume : FluidVolume;
        in irrigationPort : IrrigationPort;
        out returnVolume : FluidVolume;
    }
    
    action def MonitorVentPatency {
        in ventPort : VentPort;
        out isPatent : Boolean;
        out requiresIrrigation : Boolean;
    }
    
    action def PerformGastricDecompression {
        in targetPressure : SuctionPressure;
        in flushVolume : FluidVolume;
        
        first start;
        then merge continuousOperation;
        
        action parallelDecompression {
            action applySuction : ApplyContinuousSuction {
                in targetPressure : SuctionPressure;
                in duration : TimeValue;
                out volumeRemoved : FluidVolume;
                out pressureAchieved : SuctionPressure;
            }
            
            action ventAir : VentSwallowedAir {
                in ventPort : VentPort;
                out airVented : FluidVolume;
                out pressureRelieved : PressureValue;
            }
            
            action monitorVent : MonitorVentPatency {
                in ventPort : VentPort;
                out isPatent : Boolean;
                out requiresIrrigation : Boolean;
            }
        }
        
        then decide;
            if parallelDecompression.monitorVent.isPatent then continuousOperation;
            if not parallelDecompression.monitorVent.isPatent then performIrrigation;
        
        action performIrrigation : IrrigateLumen {
            in flushVolume : FluidVolume;
            in irrigationPort : IrrigationPort;
            out returnVolume : FluidVolume;
        }
        then continuousOperation;
    }
    
    requirement def <'REQ-001'> PrimaryFunctionRequirement {
        doc /* The Replogle tube system shall continuously decompress the stomach 
             by simultaneously removing gastric contents and swallowed air through 
             dual-lumen suction while maintaining atmospheric venting to prevent 
             mucosal injury from excessive negative pressure. */
        
        subject system : ReplogleNasogastricTubeSystem;
        
        require constraint {
            system.suctionDevice.targetPressure >= system.suctionDevice.minPressure and
            system.suctionDevice.targetPressure <= system.suctionDevice.maxPressure
        }
        
        require constraint {
            system.tube.ventLumen.atmospheric.isOpen == true
        }
    }
    
    requirement def <'REQ-002'> DualLumenDesignRequirement {
        doc /* The tube shall incorporate two independent lumens: a larger suction 
             lumen for gastric content removal and a smaller vent lumen for 
             atmospheric air communication. */
        
        subject tube : ReplogleTube;
        
        require constraint {
            tube.suctionLumen.diameter > tube.ventLumen.diameter
        }
    }
    
    requirement def <'REQ-003'> SafeSuctionRequirement {
        doc /* The suction pressure shall be maintained between 40 mmHg and 80 mmHg 
             to ensure effective decompression without causing tissue damage. */
        
        subject suctionDevice : SuctionApparatus;
        
        require constraint {
            suctionDevice.minPressure == 5333.0[Pa] and
            suctionDevice.maxPressure == 10666.0[Pa]
        }
    }
    
    requirement def <'REQ-004'> VentPatencyRequirement {
        doc /* The vent lumen shall remain continuously open to atmosphere to 
             prevent excessive negative pressure on gastric mucosa. */
        
        subject ventLumen;
        
        require constraint {
            ventLumen.atmospheric.isOpen == true
        }
    }
    
    part def ReplogleNasogastricTubeSystem {
        part tube : ReplogleTube;
        part suctionDevice : SuctionApparatus;
        part irrigationSystem : IrrigationSystem;
        part patient : PatientStomach;
        
        perform action decompress : PerformGastricDecompression;
    }
    
    part replogleSystem : ReplogleNasogastricTubeSystem {
        part tube : ReplogleTube {
            attribute outerDiameter = 3.3[mm];
            attribute length = 120[cm];
            attribute frenchSize = 10.0;
            
            part redefines suctionLumen {
                attribute diameter = 2.0[mm];
            }
            
            part redefines ventLumen {
                attribute diameter = 1.0[mm];
            }
            
            part redefines distalTip {
                attribute numberOfOpenings = 4;
            }
            
            part redefines ventOpening {
                attribute position = 50[cm];
            }
        }
        
        part suctionDevice : SuctionApparatus {
            attribute targetPressure = 8000.0[Pa];
            attribute maxPressure = 10666.0[Pa];
            attribute minPressure = 5333.0[Pa];
            
            part redefines vacuumSource {
                attribute power = 50[W];
            }
            
            part redefines collectionContainer {
                attribute capacity = 2000[mL];
                attribute currentLevel = 0[mL];
            }
            
            part redefines pressureRegulator {
                attribute setPressure = 8000.0[Pa];
            }
        }
        
        part irrigationSystem : IrrigationSystem {
            attribute flushVolume = 10[mL];
            attribute flushInterval = 4[h];
            
            part redefines salineReservoir {
                attribute capacity = 500[mL];
                attribute remainingVolume = 500[mL];
            }
            
            part redefines deliveryPump {
                attribute flowRate = 5[mL/s];
            }
        }
        
        part patient : PatientStomach {
            attribute gastricVolume = 300[mL];
            attribute intragastricPressure = 1066.0[Pa];
        }
        
        connect tube.suctionLumen.proximal to suctionDevice.vacuumPort;
        connect tube.suctionLumen.distal to patient.gastricInterface;
        connect tube.ventLumen.gastric to patient.gastricInterface;
        
        perform action decompress : PerformGastricDecompression {
            in targetPressure = suctionDevice.targetPressure;
            in flushVolume = irrigationSystem.flushVolume;
        }
        
        satisfy primaryFunction by decompress;
        satisfy dualLumenDesign by tube;
        satisfy safeSuction by suctionDevice;
        satisfy ventPatency by tube.ventLumen;
    }
    
    requirement primaryFunction : PrimaryFunctionRequirement {
        subject replogleSystem;
    }
    
    requirement dualLumenDesign : DualLumenDesignRequirement {
        subject replogleSystem.tube;
    }
    
    requirement safeSuction : SafeSuctionRequirement {
        subject replogleSystem.suctionDevice;
    }
    
    requirement ventPatency : VentPatencyRequirement {
        subject replogleSystem.tube.ventLumen;
    }
}
