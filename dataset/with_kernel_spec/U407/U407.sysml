package 'Sterile Surgical Lubricant Delivery System' {
    private import ScalarValues::*;

    package ValueTypes {
        value def Viscosity :> Real;
        value def Temperature :> Real;
        value def FlowRate :> Real;
        value def FrictionCoefficient :> Real;
        value def Volume :> Real;
    }

    package Items {
        private import ValueTypes::*;

        item def SterileLubricantGel {
            attribute isSterile : Boolean = true;
            attribute isBiocompatible : Boolean = true;
            attribute isWaterSoluble : Boolean = true;
            attribute viscosity : Viscosity;
            attribute temperature : Temperature;
        }

        item def DispenseCommand {
            attribute targetFlowRate : FlowRate;
        }

        item def FrictionMeasurement {
            attribute surfaceFrictionReduction : FrictionCoefficient;
        }

        item def TemperatureAdjustment {
            attribute targetTemperature : Temperature;
        }

        attribute def PrimingCompleteSignal;
        attribute def ProcedureCompleteSignal;
        attribute def CleaningCompleteSignal;
        attribute def StartDispensingSignal;
        attribute def StopDispensingSignal;
    }

    package Behaviors {
        private import ValueTypes::*;
        private import Items::*;

        action def PrimeSystem {
            in gel : SterileLubricantGel;
            out primedGel : SterileLubricantGel;
        }

        action def MonitorViscosity {
            in gel : SterileLubricantGel;
            out viscosity : Viscosity;
        }

        action def AdjustTemperature {
            in gel : SterileLubricantGel;
            in targetTemp : Temperature;
            out adjustedGel : SterileLubricantGel;
        }

        action def EvaluateEffectiveness {
            in gel : SterileLubricantGel;
            out frictionReduction : FrictionMeasurement;
        }
    }

    package Components {
        private import ValueTypes::*;
        private import Items::*;
        private import Behaviors::*;

        part def DisposableLubricantCartridge {
            attribute prefilledVolume : Volume;
            port lubricantOutPort {
                out gel : SterileLubricantGel;
            }
        }

        part def PrecisionPumpMechanism {
            port lubricantInPort {
                in gel : SterileLubricantGel;
            }
            port lubricantOutPort {
                out gel : SterileLubricantGel;
            }
            port pumpCommandInPort {
                in command : DispenseCommand;
            }
        }

        part def ElectronicFlowController {
            port operatorCommandInPort {
                in command : DispenseCommand;
            }
            port pumpControlOutPort {
                out command : DispenseCommand;
            }
            port viscosityFeedbackInPort {
                in viscosity : Viscosity;
            }
            port temperatureControlOutPort {
                out adjustment : TemperatureAdjustment;
            }
            attribute presetProgramFlowRate : FlowRate;
        }

        part def ApplicationNozzle {
            attribute tipTaperAngle : Real;
            port lubricantInPort {
                in gel : SterileLubricantGel;
            }
            port appliedLubricantOutPort {
                out gel : SterileLubricantGel;
            }
            port frictionEstimateOutPort {
                out frictionEstimate : FrictionMeasurement;
            }
        }

        part def SurgicalInstrument {
            port lubricantAppliedPort {
                in gel : SterileLubricantGel;
            }
        }

        part def TissueSurface {
            port lubricantAppliedPort {
                in gel : SterileLubricantGel;
            }
        }

        state def DeliveryStates {
            action primeAction : PrimeSystem;
            action monitorAction : MonitorViscosity;
            action adjustAction : AdjustTemperature;
            action evaluateAction : EvaluateEffectiveness;

            entry; then idle;
            state idle;
            accept StartDispensingSignal then priming;
            state priming {
                do primeAction;
            }
            accept PrimingCompleteSignal then operating;
            state operating {
                do monitorAction;
                do adjustAction;
                do evaluateAction;
            }
            accept StopDispensingSignal then cleaning;
            state cleaning;
            accept CleaningCompleteSignal then idle;
        }

        part def SterileLubricantDeliverySystem {
            part cartridge : DisposableLubricantCartridge;
            part pump : PrecisionPumpMechanism;
            part controller : ElectronicFlowController;
            part nozzle : ApplicationNozzle;
            part targetInstrument : SurgicalInstrument;
            part targetTissue : TissueSurface;

            flow gelFlow1 of SterileLubricantGel 
                from cartridge.lubricantOutPort.gel to pump.lubricantInPort.gel;
            flow gelFlow2 of SterileLubricantGel 
                from pump.lubricantOutPort.gel to nozzle.lubricantInPort.gel;
            flow commandFlow of DispenseCommand 
                from controller.pumpControlOutPort.command to pump.pumpCommandInPort.command;
            flow appliedLubricantFlow of SterileLubricantGel 
                from nozzle.appliedLubricantOutPort.gel to targetTissue.lubricantAppliedPort.gel;

            exhibit state deliveryStates : DeliveryStates;
        }
    }

    package Requirements {
        private import Components::*;
        private import Items::*;

        requirement def MinimizeTissueTrauma {
            doc << "The system must reduce friction to minimize trauma to patient tissues and allow for precise manipulation." >>
            subject deliverySystem : SterileLubricantDeliverySystem;
        }

        requirement def EnsureSterility {
            doc << "The lubricant must be sterile and biocompatible." >>
            subject gel : SterileLubricantGel;
        }

        requirement def MaintainOptimalPerformance {
            doc << "The system must adjust temperature and monitor viscosity to maintain optimal performance." >>
            subject controller : ElectronicFlowController;
        }

        requirement def LaparoscopySuitability {
            doc << "The system shall be suitable for use in laparoscopic procedures." >>
            subject deliverySystem : SterileLubricantDeliverySystem;
        }
    }
}
