package MHDSensingUnitModel {
    doc /* Industrial Magnetohydrodynamic (MHD) Sensing Unit model. */
    import ScalarValues::*;
    
    attribute def Voltage :> Real;
    attribute def MagneticFluxDensity :> Real;
    attribute def FluidVelocity :> Real;
    attribute def VolumeFlowRate :> Real;
    attribute def TubeDiameter :> Real;
    
    item def ConductiveFluid {
        attribute conductivity : Real;
    }
    
    attribute def PowerOnSignal;
    attribute def InitCompleteSignal;
    attribute def StartMeasurementSignal;
    attribute def StopMeasurementSignal;
    attribute def DiagnosticModeSignal;
    attribute def PowerOffSignal;
    
    port def FluidPort {
        in item fluid : ConductiveFluid;
    }
    port def DataOutputPort {
        out velocity : FluidVelocity;
        out flowRate : VolumeFlowRate;
    }
    
    part def MeasurementTube {
        attribute diameter : TubeDiameter;
        attribute material : String = "Stainless Steel";
        attribute liner : String = "PTFE";
        port fluidIn : FluidPort;
        port fluidOut : ~FluidPort;
    }
    
    part def Electromagnet {
        attribute fieldStrength : MagneticFluxDensity;
    }
    
    part def Electrode {
        attribute material : String = "Hastelloy C";
    }
    
    part def SignalConditioningModule {
        attribute gain : Real;
    }
    
    part def Processor;
    
    action def GenerateMagneticField {
        out field : MagneticFluxDensity;
    }
    action def AcquireInducedVoltage {
        in field : MagneticFluxDensity;
        in fluid : ConductiveFluid;
        out rawVoltage : Voltage;
    }
    action def ConditionSignal {
        in rawVoltage : Voltage;
        out conditionedVoltage : Voltage;
    }
    action def ProcessData {
        in conditionedVoltage : Voltage;
        in field : MagneticFluxDensity;
        out velocity : FluidVelocity;
        out flowRate : VolumeFlowRate;
    }
    action def MeasureFlow {
        in fluid : ConductiveFluid;
        in field : MagneticFluxDensity;
        out velocity : FluidVelocity;
        out flowRate : VolumeFlowRate;
        action generateField : GenerateMagneticField {
            out field : MagneticFluxDensity;
        }
        action acquireVoltage : AcquireInducedVoltage {
            in field = generateField.field;
            in fluid = MeasureFlow::fluid;
            out rawVoltage : Voltage;
        }
        action conditionSignal : ConditionSignal {
            in rawVoltage = acquireVoltage.rawVoltage;
            out conditionedVoltage : Voltage;
        }
        action processData : ProcessData {
            in conditionedVoltage = conditionSignal.conditionedVoltage;
            in field = generateField.field;
            out velocity : FluidVelocity;
            out flowRate : VolumeFlowRate;
        }
    }
    action def CheckSystem;
    action def RunSelfTest;
    
    state def OperationalStates {
        entry; then off;
        state off;
        transition off_to_initializing
            first off
            accept PowerOnSignal
            then initializing;
        state initializing {
            entry action checkSystem : CheckSystem;
        }
        transition initializing_to_ready
            first initializing
            accept InitCompleteSignal
            then ready;
        state ready;
        transition ready_to_measuring
            first ready
            accept StartMeasurementSignal
            then measuring;
        transition ready_to_diagnostic
            first ready
            accept DiagnosticModeSignal
            then diagnostic;
        transition ready_to_off
            first ready
            accept PowerOffSignal
            then off;
        state measuring {
            do action measureFlow : MeasureFlow;
        }
        transition measuring_to_ready
            first measuring
            accept StopMeasurementSignal
            then ready;
        transition measuring_to_off
            first measuring
            accept PowerOffSignal
            then off;
        state diagnostic {
            entry action runSelfTest : RunSelfTest;
        }
        transition diagnostic_to_ready
            first diagnostic
            accept StopMeasurementSignal
            then ready;
        transition diagnostic_to_off
            first diagnostic
            accept PowerOffSignal
            then off;
    }
    
    part def MHDSensingUnit {
        attribute measuredVelocity : FluidVelocity;
        attribute measuredFlowRate : VolumeFlowRate;
        
        port fluidIn : FluidPort;
        port fluidOut : ~FluidPort;
        port dataOut : DataOutputPort;
        
        part measurementTube : MeasurementTube;
        part electromagnet1 : Electromagnet;
        part electromagnet2 : Electromagnet;
        part electrode1 : Electrode;
        part electrode2 : Electrode;
        part signalConditioning : SignalConditioningModule;
        part processor : Processor;
        
        connect fluidIn to measurementTube.fluidIn;
        connect measurementTube.fluidOut to fluidOut;
        
        exhibit state operationalStates : OperationalStates;
    }
    
    requirement def MeasurementAccuracy {
        doc /* The system shall accurately measure the velocity and volumetric flow rate of conductive fluids. The calculated flow rate shall be within +/- 0.5% of the actual flow rate. */
        subject sensingUnit : MHDSensingUnit;
    }
    
    requirement def MaterialRequirements {
        doc /* The measurement tube liner shall be PTFE and electrodes shall be Hastelloy C for corrosion resistance. */
        subject sensingUnit : MHDSensingUnit;
    }
    
    requirement def FaradayLawCompliance {
        doc /* The induced voltage shall be directly proportional to the fluid velocity and magnetic field strength. */
        subject sensingUnit : MHDSensingUnit;
    }
    
    part mhdUnit : MHDSensingUnit {
        satisfy req1 : MeasurementAccuracy by mhdUnit;
        satisfy req2 : MaterialRequirements by mhdUnit;
        satisfy req3 : FaradayLawCompliance by mhdUnit;
    }
}
