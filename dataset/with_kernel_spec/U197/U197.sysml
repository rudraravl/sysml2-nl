package 'Cutting Balloon Catheter System' {
    private import SI::*;
    private import ScalarValues::*;
    
    value def Length :> Real;
    value def Pressure :> Real;
    value def Volume :> Real;
    
    item def ContrastMedium;
    item def ArterialPlaque;
    item def IncisionPattern {
        attribute numberOfIncisions : Integer;
        attribute incisionDepth : Length;
        attribute incisionLength : Length;
    }
    
    port def FluidPort {
        attribute pressure : Pressure;
        attribute volumeFlowRate : Volume;
    }
    
    port def GuidewirePort {
        attribute position : Length;
    }
    
    part def Guidewire {
        attribute length : Length;
        port proximalPort : GuidewirePort;
        port distalPort : GuidewirePort;
    }
    
    part def Atherotome {
        attribute bladeLength : Length;
        attribute sharpness : Real;
    }
    
    part def BalloonMembrane {
        attribute nominalDiameter : Length;
        attribute currentDiameter : Length;
        attribute nominalLength : Length;
        part atherotomes : Atherotome[3..4];
        port inflationInlet : FluidPort;
        port guidewireExit : GuidewirePort;
    }
    
    part def CatheterHub {
        port inflationAccess : FluidPort;
        port guidewireAccess : GuidewirePort;
    }
    
    part def CatheterShaft {
        part guidewireLumen {
            port proximalPort : GuidewirePort;
            port distalPort : GuidewirePort;
        }
        part inflationLumen {
            port proximalPort : FluidPort;
            port distalPort : FluidPort;
        }
    }
    
    part def CuttingBalloonCatheter {
        part shaft : CatheterShaft;
        part hub : CatheterHub;
        part balloon : BalloonMembrane;
        
        port inflationPort : FluidPort;
        port guidewirePort : GuidewirePort;
        
        connect inflationPort to hub.inflationAccess;
        connect guidewirePort to hub.guidewireAccess;
        connect hub.inflationAccess to shaft.inflationLumen.proximalPort;
        connect shaft.inflationLumen.distalPort to balloon.inflationInlet;
        connect hub.guidewireAccess to shaft.guidewireLumen.proximalPort;
        connect shaft.guidewireLumen.distalPort to balloon.guidewireExit;
    }
    
    part def SyringeAssembly {
        attribute volume : Volume;
        port fluidPort : FluidPort;
    }
    
    part def PressureGauge {
        attribute maxPressure : Pressure;
        port pressurePort : FluidPort;
    }
    
    part def InflationDevice {
        part syringe : SyringeAssembly;
        part gauge : PressureGauge;
        port outputPort : FluidPort;
        
        connect syringe.fluidPort to outputPort;
        connect gauge.pressurePort to outputPort;
    }
    
    part def CuttingBalloonCatheterSystem {
        part catheter : CuttingBalloonCatheter;
        part inflationDevice : InflationDevice;
        part guidewire : Guidewire;
        item contrastMedium : ContrastMedium;
        
        connect inflationDevice.outputPort to catheter.inflationPort;
        connect guidewire.distalPort to catheter.guidewirePort;
        
        state machine operatingStates {
            initial state idle;
            state navigating;
            state positionedAtLesion;
            state inflating;
            state scoring;
            state deflating;
            final state withdrawn;
            
            transition from idle to navigating;
            transition from navigating to positionedAtLesion;
            transition from positionedAtLesion to inflating;
            transition from inflating to scoring;
            transition from scoring to deflating;
            transition from deflating to withdrawn;
        }
    }
    
    action def NavigateAction {
        in ref guidewire : Guidewire;
    }
    action def PositionAction {
        in ref catheter : CuttingBalloonCatheter;
    }
    action def InjectContrastAction {
        in ref syringe : SyringeAssembly;
        in fluid : ContrastMedium;
        out dispensedFluid : ContrastMedium;
    }
    action def InflateAction {
        in ref balloon : BalloonMembrane;
        in fluid : ContrastMedium;
    }
    action def ScorePlaqueAction {
        in ref balloon : BalloonMembrane;
        in plaque : ArterialPlaque;
        out incisions : IncisionPattern;
    }
    action def DeflateAction {
        in ref balloon : BalloonMembrane;
    }
    action def WithdrawAction {
        in ref catheter : CuttingBalloonCatheter;
    }
    
    action def CuttingProcedure {
        in ref catheterRef : CuttingBalloonCatheter;
        in ref inflationDeviceRef : InflationDevice;
        in ref guidewireRef : Guidewire;
        in fluidRef : ContrastMedium;
        in plaqueRef : ArterialPlaque;
        
        action navigate : NavigateAction {
            in ref guidewire :>> guidewireRef;
        }
        then action position : PositionAction {
            in ref catheter :>> catheterRef;
        }
        then action injectContrast : InjectContrastAction {
            in ref syringe :>> inflationDeviceRef.syringe;
            in fluid :>> fluidRef;
        }
        then action inflate : InflateAction {
            in ref balloon :>> catheterRef.balloon;
            in fluid :>> injectContrast.dispensedFluid;
        }
        then action score : ScorePlaqueAction {
            in ref balloon :>> catheterRef.balloon;
            in plaque :>> plaqueRef;
        }
        then action deflate : DeflateAction {
            in ref balloon :>> catheterRef.balloon;
        }
        then action withdraw : WithdrawAction {
            in ref catheter :>> catheterRef;
        }
    }
    
    requirement def DilateVesselRequirement {
        subject system : CuttingBalloonCatheterSystem;
        objective {
            /* The system shall dilate narrowed arteries to their nominal diameter. */
        }
        require system.catheter.balloon.currentDiameter >= system.catheter.balloon.nominalDiameter;
    }
    
    requirement def ControlledIncisionsRequirement {
        subject system : CuttingBalloonCatheterSystem;
        objective {
            /* The atherotomes shall create controlled longitudinal incisions in arterial plaque. */
        }
        require system.catheter.balloon.atherotomes->size() >= 3;
    }
    
    requirement def ReduceElasticRecoilRequirement {
        subject system : CuttingBalloonCatheterSystem;
        objective {
            /* The system shall reduce elastic recoil of the vessel post-procedure. */
        }
    }
}
