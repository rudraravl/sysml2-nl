package WaveSolderingSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def StartSignal;
    attribute def PreheatCompleteSignal;
    attribute def ShutdownSignal;
    attribute def ShutdownCompleteSignal;
    attribute def FaultSignal;
    attribute def ResetSignal;

    value def ConveyorSpeedValue :> ISQ::SpeedValue;
    value def FluxDensityValue :> ISQ::MassDensityValue;
    value def WaveHeightValue :> ISQ::LengthValue;
    value def SolderTempValue :> ISQ::TemperatureValue;

    item def PCB;
    item def FluxedPCB :> PCB;
    item def PreheatedPCB :> FluxedPCB;
    item def SolderedPCB :> PreheatedPCB;
    item def CooledPCB :> SolderedPCB;
    item def AcceptedPCB :> CooledPCB;
    item def RejectedPCB :> CooledPCB;

    item def LiquidFlux;
    item def MoltenSolder;

    part def SprayNozzle;
    part def HeatingElement;
    part def Fan;
    part def VisionSystem;
    part def WaveGenerator;
    part def SolderPot;
    part def HeatingSystem;

    port def PCBPort;

    part def ConveyorBelt {
        attribute speed : ConveyorSpeedValue = 1.5 [cm/s];
        in port pcbIn : PCBPort;
        out port pcbOut : PCBPort;
    }

    part def FluxingUnit {
        part sprayNozzles : SprayNozzle[1..*];
        attribute fluxDensity : FluxDensityValue = 0.8 [g/cm^3];
        item flux : LiquidFlux;
        in port pcbIn : PCBPort;
        out port pcbOut : PCBPort;
    }

    part def PreheatingZone {
        part heatingElements : HeatingElement[1..*];
        attribute targetTemp : SolderTempValue = 110 [degC];
        in port pcbIn : PCBPort;
        out port pcbOut : PCBPort;
    }

    part def WaveSolderingUnit {
        part solderPot : SolderPot {
            item moltenSolder : MoltenSolder;
        }
        part heatingSystem : HeatingSystem;
        part waveGenerator : WaveGenerator;
        attribute solderTemp : SolderTempValue = 260 [degC];
        attribute waveHeight : WaveHeightValue = 12 [mm];
        in port pcbIn : PCBPort;
        out port pcbOut : PCBPort;
    }

    part def CoolingZone {
        part fans : Fan[1..*];
        in port pcbIn : PCBPort;
        out port pcbOut : PCBPort;
    }

    part def InspectionStation {
        part visionSystem : VisionSystem;
        in port pcbIn : PCBPort;
        out port acceptedPcbOut : PCBPort;
        out port rejectedPcbOut : PCBPort;
    }

    action def ProcessPCB {
        in item rawPcb : PCB;
        out item acceptedPcb : AcceptedPCB;
        out item rejectedPcb : RejectedPCB;

        action loadPCB {
            in item pcb : PCB = rawPcb;
            out item loadedPcb : PCB;
        }
        action applyFlux {
            in item pcb : PCB;
            out item fluxedPcb : FluxedPCB;
        }
        action preheat {
            in item pcb : FluxedPCB;
            out item preheatedPcb : PreheatedPCB;
        }
        action waveSolder {
            in item pcb : PreheatedPCB;
            out item solderedPcb : SolderedPCB;
        }
        action cool {
            in item pcb : SolderedPCB;
            out item cooledPcb : CooledPCB;
        }
        action inspect {
            in item pcb : CooledPCB;
            out item accepted : AcceptedPCB;
            out item rejected : RejectedPCB;
        }

        flow loadPCB.loadedPcb to applyFlux.pcb;
        flow applyFlux.fluxedPcb to preheat.pcb;
        flow preheat.preheatedPcb to waveSolder.pcb;
        flow waveSolder.solderedPcb to cool.pcb;
        flow cool.cooledPcb to inspect.pcb;

        bind acceptedPcb = inspect.accepted;
        bind rejectedPcb = inspect.rejected;
    }

    state def SystemStates;

    part def AutomatedWaveSolderingSystem {
        attribute conveyorSpeed : ConveyorSpeedValue = 1.5 [cm/s];
        attribute fluxDensity : FluxDensityValue = 0.8 [g/cm^3];
        attribute preheatingTemp : SolderTempValue = 110 [degC];
        attribute solderTemp : SolderTempValue = 260 [degC];
        attribute solderWaveHeight : WaveHeightValue = 12 [mm];

        part conveyorBelt : ConveyorBelt {
            attribute speed := conveyorSpeed;
        }
        part fluxingUnit : FluxingUnit {
            attribute fluxDensity := fluxDensity;
        }
        part preheatingZone : PreheatingZone {
            attribute targetTemp := preheatingTemp;
        }
        part waveSolderingUnit : WaveSolderingUnit {
            attribute solderTemp := solderTemp;
            attribute waveHeight := solderWaveHeight;
        }
        part coolingZone : CoolingZone;
        part inspectionStation : InspectionStation;

        flow conveyorBelt.pcbOut to fluxingUnit.pcbIn;
        flow fluxingUnit.pcbOut to preheatingZone.pcbIn;
        flow preheatingZone.pcbOut to waveSolderingUnit.pcbIn;
        flow waveSolderingUnit.pcbOut to coolingZone.pcbIn;
        flow coolingZone.pcbOut to inspectionStation.pcbIn;

        state systemStates : SystemStates {
            entry; then idle;
            state idle;
            accept StartSignal then preheating;
            state preheating;
            accept PreheatCompleteSignal then operational;
            state operational;
            accept ShutdownSignal then shutdown;
            accept FaultSignal then faulted;
            state shutdown;
            accept ShutdownCompleteSignal then idle;
            state faulted;
            accept ResetSignal then idle;
        }
    }

    requirement solderQualityRequirement {
        doc /* The system must create reliable electrical and mechanical connections by soldering electronic components onto PCBs. */;
    }
    requirement defectInspectionRequirement {
        doc /* The system must automatically separate boards into accepted and rejected batches based on vision system results. */;
    }
    requirement processControlRequirement {
        doc /* Conveyor speed, flux density, preheating temperature, and solder wave height must be carefully controlled to ensure consistent, high-quality manufacturing. */;
    }

    part systemInstance : AutomatedWaveSolderingSystem;

    satisfy solderQualityRequirement by systemInstance.waveSolderingUnit;
    satisfy defectInspectionRequirement by systemInstance.inspectionStation;
    satisfy processControlRequirement by systemInstance;
}
