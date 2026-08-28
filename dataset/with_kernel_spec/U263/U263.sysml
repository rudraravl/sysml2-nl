package GastroenterologyEndoscopySystem {
    doc /* Complete medical endoscopy system for gastroenterology procedures, designed for minimally invasive examination, diagnosis, and treatment of the gastrointestinal tract. */

    private import ScalarValues::*;
    private import ISQ::*;

    unit def mmHg;
    unit def L_per_min;
    unit def pixel;

    attribute def PressureValue :> Real { :>> unit = mmHg; }
    attribute def FlowRateValue :> Real { :>> unit = L_per_min; }
    attribute def ResolutionValue :> Real { :>> unit = pixel; }

    item def LightBeam;
    item def VideoSignal;
    item def ProcessedVideoSignal;
    item def CO2Gas;
    item def IrrigationFluid;
    item def ControlSignal;
    item def BiopsyInstrument;
    item def TissueSample;

    port def LightOutPort { out light : LightBeam; }
    port def LightInPort { in light : LightBeam; }
    port def VideoOutPort { out video : VideoSignal; }
    port def VideoInPort { in video : VideoSignal; }
    port def ProcessedVideoOutPort { out video : ProcessedVideoSignal; }
    port def ProcessedVideoInPort { in video : ProcessedVideoSignal; }
    port def GasOutPort { out gas : CO2Gas; }
    port def GasInPort { in gas : CO2Gas; }
    port def FluidOutPort { out fluid : IrrigationFluid; }
    port def FluidInPort { in fluid : IrrigationFluid; }
    port def ControlOutPort { out signal : ControlSignal; }
    port def ControlInPort { in signal : ControlSignal; }
    port def WorkingChannelPort { in instrument : BiopsyInstrument; out specimen : TissueSample; }
    port def InstrumentPort { out instrument : BiopsyInstrument; in specimen : TissueSample; }

    action def checkEquipment;
    action def navigateScope;
    action def illuminateAndCapture;
    action def performBiopsy;
    action def retractScope;

    part def Camera {
        port videoOut : VideoOutPort;
        attribute resolution : ResolutionValue;
    }

    part def LightChannel {
        port lightIn : LightInPort;
        port lightOut : LightOutPort;
    }

    part def WorkingChannel {
        port gasIn : GasInPort;
        port fluidIn : FluidInPort;
        port instrumentPort : WorkingChannelPort;
    }

    part def InsertionTube {
        port lightIn : LightInPort;
        port videoOut : VideoOutPort;
        port gasIn : GasInPort;
        port fluidIn : FluidInPort;
        port workingChannelPort : WorkingChannelPort;

        part camera : Camera;
        part lightChannel : LightChannel;
        part workingChannel : WorkingChannel;

        connect lightIn to lightChannel.lightIn;
        connect camera.videoOut to videoOut;
        connect gasIn to workingChannel.gasIn;
        connect fluidIn to workingChannel.fluidIn;
        connect workingChannelPort to workingChannel.instrumentPort;
    }

    part def Endoscope {
        doc /* Flexible insertion tube navigated into the patient's digestive system, containing a high-definition camera, light channel, and working channel for instrument passage. */
        port lightIn : LightInPort;
        port videoOut : VideoOutPort;
        port gasIn : GasInPort;
        port fluidIn : FluidInPort;
        port workingChannel : WorkingChannelPort;
        port controlIn : ControlInPort;
        attribute isSterile : Boolean;
        attribute insertionLength : Real;

        part insertionTube : InsertionTube;

        connect lightIn to insertionTube.lightIn;
        connect insertionTube.videoOut to videoOut;
        connect gasIn to insertionTube.gasIn;
        connect fluidIn to insertionTube.fluidIn;
        connect workingChannel to insertionTube.workingChannelPort;
    }

    part def LightSource {
        port lightOut : LightOutPort;
        port controlIn : ControlInPort;
        attribute intensity : Real;
    }

    part def VideoProcessor {
        port videoIn : VideoInPort;
        port videoOut : ProcessedVideoOutPort;
        port controlIn : ControlInPort;
        attribute processingLatency : Real;
    }

    part def DisplayMonitor {
        port videoIn : ProcessedVideoInPort;
        port controlIn : ControlInPort;
        attribute resolution : ResolutionValue;
    }

    part def InsufflationUnit {
        port gasOut : GasOutPort;
        port controlIn : ControlInPort;
        attribute pressureSetting : PressureValue;
        attribute maxSafePressure : PressureValue = 30.0;
    }

    part def IrrigationPump {
        port fluidOut : FluidOutPort;
        port controlIn : ControlInPort;
        attribute flowRate : FlowRateValue;
    }

    part def BiopsyForceps {
        port instrumentPort : InstrumentPort;
        attribute jawSize : Real;
    }

    part def CentralControlUnit {
        port lightControl : ControlOutPort;
        port videoControl : ControlOutPort;
        port gasControl : ControlOutPort;
        port fluidControl : ControlOutPort;
        port instrumentControl : ControlOutPort;
        port displayControl : ControlOutPort;
    }

    part def EndoscopySystem {
        part endoscope : Endoscope;
        part lightSource : LightSource;
        part videoProcessor : VideoProcessor;
        part displayMonitor : DisplayMonitor;
        part insufflationUnit : InsufflationUnit;
        part irrigationPump : IrrigationPump;
        part biopsyForceps : BiopsyForceps;
        part controlUnit : CentralControlUnit;

        connect lightSource.lightOut to endoscope.lightIn;
        connect endoscope.videoOut to videoProcessor.videoIn;
        connect videoProcessor.videoOut to displayMonitor.videoIn;
        connect insufflationUnit.gasOut to endoscope.gasIn;
        connect irrigationPump.fluidOut to endoscope.fluidIn;
        connect biopsyForceps.instrumentPort to endoscope.workingChannel;
        connect controlUnit.lightControl to lightSource.controlIn;
        connect controlUnit.videoControl to videoProcessor.controlIn;
        connect controlUnit.gasControl to insufflationUnit.controlIn;
        connect controlUnit.fluidControl to irrigationPump.controlIn;
        connect controlUnit.instrumentControl to endoscope.controlIn;
        connect controlUnit.displayControl to displayMonitor.controlIn;

        requirement patientSafetyReq {
            doc /* The system must ensure patient safety by limiting gas pressure to prevent organ perforation. */
            attribute maxPressure : PressureValue = 30.0;
            constraint { insufflationUnit.maxSafePressure <= maxPressure }
        }

        requirement imageQualityReq {
            doc /* The system must provide high-definition image quality for accurate diagnosis. */
            attribute minResolution : ResolutionValue = 1920.0;
            constraint { displayMonitor.resolution >= minResolution }
        }

        requirement sterilityReq {
            doc /* All patient-contacting components must maintain sterility throughout the procedure. */
            constraint { endoscope.isSterile == true }
        }

        satisfy patientSafetyReq by insufflationUnit;
        satisfy imageQualityReq by videoProcessor;
        satisfy imageQualityReq by displayMonitor;
        satisfy imageQualityReq by endoscope;
        satisfy sterilityReq by endoscope;
        satisfy sterilityReq by biopsyForceps;
    }

    state machine def EndoscopicProcedure {
        state EquipmentChecks {
            entry action checkEquipment;
        }
        state Insertion {
            entry action navigateScope;
        }
        state Examination {
            entry action illuminateAndCapture;
        }
        state Intervention {
            entry action performBiopsy;
        }
        state Withdrawal {
            entry action retractScope;
        }
        state Complete;

        transition t1 from EquipmentChecks to Insertion;
        transition t2 from Insertion to Examination;
        transition t3 from Examination to Intervention;
        transition t4 from Intervention to Examination;
        transition t5 from Examination to Withdrawal;
        transition t6 from Withdrawal to Complete;
    }

    part endoscopySystem : EndoscopySystem;
}
