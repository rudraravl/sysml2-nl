package MunicipalSewageTreatmentPlant {
    import ISQ::*;
    import ScalarValues::*;

    value type VolumeFlowRate :> Real {
        unit m^3/s;
    }
    value type MassFlowRate :> Real {
        unit kg/s;
    }
    value type Concentration :> Real {
        unit mg/L;
    }
    value type MassFraction :> Real {
        unit kg/kg;
    }

    item def Wastewater {
        attribute flowRate : VolumeFlowRate;
        attribute bod : Concentration; 
        attribute tss : Concentration; 
    }
    
    item def RawSewage :> Wastewater;
    item def ScreenedWastewater :> Wastewater;
    item def PrimaryEffluent :> Wastewater;
    item def BiologicalEffluent :> Wastewater;
    item def TreatedEffluent :> Wastewater {
        constraint { self.bod <= 10 [mg/L] and self.tss <= 15 [mg/L] }
    }

    item def Sludge {
        attribute massFlowRate : MassFlowRate;
        attribute solidsContent : MassFraction;
    }
    item def PrimarySludge :> Sludge;
    item def ActivatedSludge :> Sludge;
    item def WasteSludge :> Sludge;
    item def DigestedSludge :> Sludge {
        constraint { self.solidsContent >= 0.3 }
    }

    item def Grit;
    item def Air;
    item def Chemical;

    port def WastewaterInPort {
        in wastewater : Wastewater;
    }
    port def WastewaterOutPort {
        out wastewater : Wastewater;
    }
    port def SludgeOutPort {
        out sludge : Sludge;
    }
    port def SludgeInPort {
        in sludge : Sludge;
    }
    port def AirInPort {
        in air : Air;
    }
    port def ChemicalInPort {
        in chemical : Chemical;
    }
    port def GritOutPort {
        out grit : Grit;
    }

    part def ScreeningUnit {
        port inWastewater : WastewaterInPort;
        port outWastewater : WastewaterOutPort;
        port outGrit : GritOutPort;
    }

    part def GritChamber {
        port inWastewater : WastewaterInPort;
        port outWastewater : WastewaterOutPort;
        port outGrit : GritOutPort;
    }

    part def PrimaryClarifier {
        port inWastewater : WastewaterInPort;
        port outEffluent : WastewaterOutPort;
        port outSludge : SludgeOutPort;
    }

    part def AerationBasin {
        port inWastewater : WastewaterInPort;
        port inReturnSludge : SludgeInPort;
        port inAir : AirInPort;
        port outWastewater : WastewaterOutPort;
    }

    part def SecondaryClarifier {
        port inWastewater : WastewaterInPort;
        port outEffluent : WastewaterOutPort;
        port outReturnSludge : SludgeOutPort;
        port outWasteSludge : SludgeOutPort;
    }

    part def DisinfectionChamber {
        port inWastewater : WastewaterInPort;
        port inChemical : ChemicalInPort;
        port outEffluent : WastewaterOutPort;
    }

    part def AnaerobicDigester {
        port inPrimarySludge : SludgeInPort;
        port inWasteSludge : SludgeInPort;
        port outDigestedSludge : SludgeOutPort;
    }

    part def TreatmentPlant {
        port rawSewageIn : WastewaterInPort;
        port treatedWaterOut : WastewaterOutPort;
        port gritDisposal : GritOutPort;
        port sludgeDisposal : SludgeOutPort;
        port airIntake : AirInPort;
        port chemicalIntake : ChemicalInPort;

        part screeningUnit : ScreeningUnit;
        part gritChamber : GritChamber;
        part primaryClarifier : PrimaryClarifier;
        part aerationBasin : AerationBasin;
        part secondaryClarifier : SecondaryClarifier;
        part disinfectionChamber : DisinfectionChamber;
        part anaerobicDigester : AnaerobicDigester;

        connection rawSewageToScreening connect rawSewageIn to screeningUnit.inWastewater;
        connection screeningToGrit connect screeningUnit.outWastewater to gritChamber.inWastewater;
        connection gritToPrimary connect gritChamber.outWastewater to primaryClarifier.inWastewater;
        connection primaryToAeration connect primaryClarifier.outEffluent to aerationBasin.inWastewater;
        connection aerationToSecondary connect aerationBasin.outWastewater to secondaryClarifier.inWastewater;
        connection secondaryToDisinfection connect secondaryClarifier.outEffluent to disinfectionChamber.inWastewater;
        connection disinfectionToOut connect disinfectionChamber.outEffluent to treatedWaterOut;

        connection screeningGritOut connect screeningUnit.outGrit to gritDisposal;
        connection gritChamberGritOut connect gritChamber.outGrit to gritDisposal;

        connection primarySludgeToDigester connect primaryClarifier.outSludge to anaerobicDigester.inPrimarySludge;
        connection wasteSludgeToDigester connect secondaryClarifier.outWasteSludge to anaerobicDigester.inWasteSludge;
        connection digestedSludgeOut connect anaerobicDigester.outDigestedSludge to sludgeDisposal;

        connection returnSludge connect secondaryClarifier.outReturnSludge to aerationBasin.inReturnSludge;
        
        connection airSupply connect airIntake to aerationBasin.inAir;
        connection chemicalSupply connect chemicalIntake to disinfectionChamber.inChemical;

        attribute startCommand : Boolean = false;
        attribute systemReady : Boolean = false;
        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute systemPurged : Boolean = false;

        state def Lifecycle {
            state offline;
            state startup;
            state operational;
            state maintenance;
            state shutdown;

            transition from offline to startup when startCommand;
            transition from startup to operational when systemReady;
            transition from operational to maintenance when maintenanceRequested;
            transition from maintenance to operational when maintenanceComplete;
            transition from operational to shutdown when stopCommand;
            transition from shutdown to offline when systemPurged;
        }

        exhibit state lifecycle : Lifecycle;
    }

    requirement def DischargeWaterQuality {
        subject treatedEffluent : TreatedEffluent;
        constraint { treatedEffluent.bod <= 10 [mg/L] }
        constraint { treatedEffluent.tss <= 15 [mg/L] }
        constraint { treatedEffluent.flowRate >= 0.5 [m^3/s] }
    }

    requirement def SludgeStability {
        subject digestedSludge : DigestedSludge;
        constraint { digestedSludge.solidsContent >= 0.3 }
        constraint { digestedSludge.massFlowRate <= 10 [kg/s] }
    }

    requirement def PlantOperation {
        subject plant : TreatmentPlant;
        requirement waterQuality : DischargeWaterQuality {
            subject = plant.treatedWaterOut.wastewater;
        }
        requirement sludgeQuality : SludgeStability {
            subject = plant.sludgeDisposal.sludge;
        }
    }
}
