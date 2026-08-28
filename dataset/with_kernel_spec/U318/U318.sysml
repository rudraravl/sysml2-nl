package MurphyDripIVInfusionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    unit def mL;
    unit def 'mL/min';
    unit def 'drops/min';
    unit def mmHg;
    unit def cm;
    
    value def Volume :> Real { :>> unit = mL; }
    value def FlowRate :> Real { :>> unit = 'mL/min'; }
    value def DropRate :> Real { :>> unit = 'drops/min'; }
    value def Pressure :> Real { :>> unit = mmHg; }
    value def Length :> Real { :>> unit = cm; }
    
    item def IVFluid;
    item def Air;
    
    attribute def PrimeSignal;
    attribute def StartInfusionSignal;
    attribute def StopInfusionSignal;
    attribute def CompleteSignal;
    attribute def ResetSignal;
    
    port def FluidOutPort {
        out item fluid : IVFluid;
        attribute pressure : Pressure;
    }
    
    port def FluidInPort {
        in item fluid : IVFluid;
        attribute pressure : Pressure;
    }
    
    part def IVBag {
        attribute capacity : Volume = 1000 [mL];
        attribute currentVolume : Volume;
        attribute bagHeight : Length;
        port fluidOutPort : FluidOutPort;
        exhibit state 'bag fill states' {
            entry; then notEmpty;
            state notEmpty;
            accept when currentVolume == 0 [mL]
                then empty;
            state empty;
        }
    }
    
    part def SpikeAdapter {
        port spikeInPort : FluidInPort;
        port spikeOutPort : FluidOutPort;
    }
    
    part def DripChamber {
        attribute fluidLevel : Volume;
        attribute minFluidLevel : Volume = 1 [mL];
        attribute dropCount : Integer;
        attribute dropRate : DropRate;
        port chamberInPort : FluidInPort;
        port chamberOutPort : FluidOutPort;
        action def CountDrops {
            out count : Integer;
            out rate : DropRate;
        }
        perform action countDrops : CountDrops;
        exhibit state 'chamber states' {
            entry; then hasFluid;
            state hasFluid;
            accept when fluidLevel == 0 [mL]
                then dry;
            state dry;
        }
    }
    
    part def IVTubing {
        attribute tubingLength : Length = 180 [cm];
        attribute innerDiameter : Length;
        port tubingInPort : FluidInPort;
        port tubingOutPort : FluidOutPort;
    }
    
    part def RollerClamp {
        attribute clampPosition : Real;
        attribute flowRestriction : Real;
        port clampInPort : FluidInPort;
        port clampOutPort : FluidOutPort;
        action def AdjustClamp {
            in position : Real;
            out restriction : Real;
        }
        perform action adjustClamp : AdjustClamp;
    }
    
    part def IVCatheter {
        attribute gauge : Integer;
        port catheterInPort : FluidInPort;
        port patientPort : FluidOutPort;
    }
    
    part def Patient {
        attribute bloodPressure : Pressure;
        port veinPort : FluidInPort;
    }
    
    interface def FluidConnection {
        end supplierPort : FluidOutPort;
        end consumerPort : FluidInPort;
    }
    
    requirement def 'Prevent Air Embolism' {
        subject dripChamber : DripChamber;
        doc /* The drip chamber must never run dry during infusion to prevent air from entering the patient's bloodstream. */
    }
    
    requirement def 'Controlled Flow Rate' {
        subject rollerClamp : RollerClamp;
        doc /* The roller clamp shall allow manual adjustment of the infusion flow rate from fully closed to fully open. */
    }
    
    requirement def 'Gravity Fed Operation' {
        subject ivBag : IVBag;
        doc /* The system shall operate on a gravity-fed principle where the height of the IV bag relative to the patient creates the pressure needed to infuse fluid. */
    }
    
    requirement def 'Priming Procedure' {
        subject system : MurphyDripIVInfusionSystem;
        doc /* The system shall be primed before use by opening the clamp and allowing fluid to fill the drip chamber and tubing to purge all air. */
    }
    
    action def PrimeSystem;
    action def StartInfusion;
    action def StopInfusion;
    action def CompleteInfusion;
    
    part def MurphyDripIVInfusionSystem {
        perform action primeSystem : PrimeSystem;
        perform action startInfusion : StartInfusion;
        perform action stopInfusion : StopInfusion;
        perform action completeInfusion : CompleteInfusion;
        
        part ivBag : IVBag {
            :>> currentVolume = 1000 [mL];
            :>> bagHeight = 100 [cm];
        }
        part spikeAdapter : SpikeAdapter;
        part dripChamber : DripChamber {
            :>> fluidLevel = 5 [mL];
            :>> dropRate = 20 [drops/min];
        }
        part ivTubing : IVTubing;
        part rollerClamp : RollerClamp {
            :>> clampPosition = 0.5;
        }
        part ivCatheter : IVCatheter {
            :>> gauge = 20;
        }
        part patient : Patient {
            :>> bloodPressure = 8 [mmHg];
        }
        
        interface : FluidConnection connect
            supplierPort ::> ivBag.fluidOutPort to
            consumerPort ::> spikeAdapter.spikeInPort;
        
        interface : FluidConnection connect
            supplierPort ::> spikeAdapter.spikeOutPort to
            consumerPort ::> dripChamber.chamberInPort;
        
        interface : FluidConnection connect
            supplierPort ::> dripChamber.chamberOutPort to
            consumerPort ::> ivTubing.tubingInPort;
        
        interface : FluidConnection connect
            supplierPort ::> ivTubing.tubingOutPort to
            consumerPort ::> rollerClamp.clampInPort;
        
        interface : FluidConnection connect
            supplierPort ::> rollerClamp.clampOutPort to
            consumerPort ::> ivCatheter.catheterInPort;
        
        interface : FluidConnection connect
            supplierPort ::> ivCatheter.patientPort to
            consumerPort ::> patient.veinPort;
        
        exhibit state 'infusion states' {
            entry; then notReady;
            
            state notReady;
            
            transition notReady_to_ready
                first notReady
                accept PrimeSignal
                do primeSystem
                then ready;
            
            state ready;
            
            transition ready_to_infusing
                first ready
                accept StartInfusionSignal
                do startInfusion
                then infusing;
            
            state infusing {
                do dripChamber.countDrops;
            }
            
            transition infusing_to_ready
                first infusing
                accept StopInfusionSignal
                do stopInfusion
                then ready;
            
            transition infusing_to_complete
                first infusing
                accept CompleteSignal
                do completeInfusion
                then complete;
            
            transition infusing_to_complete_empty
                first infusing
                accept when ivBag.currentVolume == 0 [mL]
                do completeInfusion
                then complete;
            
            state complete;
            
            transition complete_to_notReady
                first complete
                accept ResetSignal
                then notReady;
        }
    }
}
